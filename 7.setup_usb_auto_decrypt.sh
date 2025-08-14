#!/bin/bash

# LUKS Auto-Decrypt with USB Keyfile Setup Script
# This script sets up automatic decryption using a keyfile stored on USB drive
# 此腳本設置使用存儲在 USB 隨身碟上的 keyfile 進行自動解密

# Make sure only root can run our script
if [ "$(id -u)" != "0" ]; then
   echo "This script must be run as root" 1>&2
   exit 1
fi

echo "=== LUKS Auto-Decrypt with USB Keyfile Setup ==="
echo "設置使用 USB Keyfile 的 LUKS 自動解密功能"
echo ""

# Check if LUKS device exists
if ! cryptsetup isLuks /dev/mmcblk0p2; then
    echo "Error: /dev/mmcblk0p2 is not a LUKS device"
    echo "錯誤：/dev/mmcblk0p2 不是 LUKS 設備"
    exit 1
fi

# Check for USB device
echo "Available USB devices:"
echo "可用的 USB 設備："
lsblk -o NAME,SIZE,TYPE,MOUNTPOINT | grep -E "(sd[a-z]|USB)"

echo ""
echo "Please enter the USB device name (e.g., sda, sdb):"
echo "請輸入 USB 設備名稱（例如：sda, sdb）："
read USB_DEVICE

if [ -z "$USB_DEVICE" ]; then
    echo "Error: No USB device specified"
    echo "錯誤：未指定 USB 設備"
    exit 1
fi

USB_DEVICE_PATH="/dev/${USB_DEVICE}1"

if [ ! -b "$USB_DEVICE_PATH" ]; then
    echo "Error: USB device $USB_DEVICE_PATH not found"
    echo "錯誤：未找到 USB 設備 $USB_DEVICE_PATH"
    exit 1
fi

# Mount USB device
USB_MOUNT="/mnt/usb-key"
mkdir -p $USB_MOUNT

echo "Mounting USB device..."
echo "掛載 USB 設備..."
mount $USB_DEVICE_PATH $USB_MOUNT

if [ $? -ne 0 ]; then
    echo "Error: Failed to mount USB device"
    echo "錯誤：無法掛載 USB 設備"
    exit 1
fi

# Create keyfile on USB
KEYFILE_PATH="$USB_MOUNT/luks-root.key"

echo "Generating keyfile on USB..."
echo "在 USB 上生成 keyfile..."
dd if=/dev/urandom of=$KEYFILE_PATH bs=512 count=4
chmod 600 $KEYFILE_PATH

echo ""
echo "Please enter your current LUKS password to add the keyfile:"
echo "請輸入您當前的 LUKS 密碼以添加 keyfile："

# Add keyfile to LUKS
cryptsetup luksAddKey /dev/mmcblk0p2 $KEYFILE_PATH

if [ $? -ne 0 ]; then
    echo "Error: Failed to add keyfile to LUKS device"
    echo "錯誤：無法將 keyfile 添加到 LUKS 設備"
    umount $USB_MOUNT
    exit 1
fi

echo "Keyfile added successfully!"
echo "Keyfile 添加成功！"

# Get USB UUID for reliable identification
USB_UUID=$(blkid -s UUID -o value $USB_DEVICE_PATH)

if [ -z "$USB_UUID" ]; then
    echo "Error: Could not get USB UUID"
    echo "錯誤：無法獲取 USB UUID"
    umount $USB_MOUNT
    exit 1
fi

echo "USB UUID: $USB_UUID"

# Unmount USB
umount $USB_MOUNT

# Update crypttab to use USB keyfile
echo "Updating /etc/crypttab..."
echo "更新 /etc/crypttab..."

# Backup original crypttab
cp /etc/crypttab /etc/crypttab.backup

# Update crypttab entry to include USB keyfile
sed -i 's|sdcard /dev/mmcblk0p2 none luks|sdcard /dev/mmcblk0p2 /mnt/usb-key/luks-root.key luks,keyscript=/bin/usb-keyfile-script|g' /etc/crypttab

# Create USB keyfile script
echo "Creating USB keyfile script..."
echo "創建 USB keyfile 腳本..."

cat > /bin/usb-keyfile-script << EOF
#!/bin/sh

# Script to mount USB and retrieve keyfile for LUKS decryption
# 用於掛載 USB 並檢索 LUKS 解密 keyfile 的腳本

USB_UUID="$USB_UUID"
USB_MOUNT="/mnt/usb-key"
KEYFILE_PATH="\$USB_MOUNT/luks-root.key"

# Create mount point
mkdir -p \$USB_MOUNT

# Find USB device by UUID
USB_DEVICE=\$(blkid -U \$USB_UUID)

if [ -z "\$USB_DEVICE" ]; then
    echo "USB keyfile device not found" >&2
    exit 1
fi

# Mount USB device
mount \$USB_DEVICE \$USB_MOUNT >/dev/null 2>&1

if [ \$? -ne 0 ]; then
    echo "Failed to mount USB keyfile device" >&2
    exit 1
fi

# Check if keyfile exists
if [ ! -f "\$KEYFILE_PATH" ]; then
    echo "Keyfile not found on USB device" >&2
    umount \$USB_MOUNT >/dev/null 2>&1
    exit 1
fi

# Output keyfile content
cat "\$KEYFILE_PATH"

# Unmount USB device
umount \$USB_MOUNT >/dev/null 2>&1
EOF

chmod +x /bin/usb-keyfile-script

# Create initramfs hook for USB support
echo "Creating initramfs hook for USB support..."
echo "創建 USB 支持的 initramfs hook..."

cat > /etc/initramfs-tools/hooks/usb-luks << 'EOF'
#!/bin/sh

PREREQ=""

prereqs()
{
    echo "$PREREQ"
}

case $1 in
prereqs)
    prereqs
    exit 0
    ;;
esac

. /usr/share/initramfs-tools/hook-functions

# Copy USB keyfile script
copy_exec /bin/usb-keyfile-script /bin/

# Add USB storage modules
manual_add_modules usb-storage
manual_add_modules usb-common
manual_add_modules usbcore
manual_add_modules ehci-hcd
manual_add_modules ehci-pci
manual_add_modules ohci-hcd
manual_add_modules uhci-hcd
manual_add_modules xhci-hcd
manual_add_modules sd_mod

# Add filesystem modules for USB
manual_add_modules vfat
manual_add_modules fat
manual_add_modules ext4
manual_add_modules ext3
manual_add_modules ext2
EOF

chmod +x /etc/initramfs-tools/hooks/usb-luks

# Update initramfs
echo "Rebuilding initramfs..."
echo "重建 initramfs..."
mkinitramfs -o /boot/firmware/initramfs.gz

echo ""
echo "=== Setup Complete ==="
echo "=== 設置完成 ==="
echo ""
echo "Your system is now configured for automatic LUKS decryption using USB keyfile."
echo "您的系統現在已配置為使用 USB keyfile 進行自動 LUKS 解密。"
echo ""
echo "IMPORTANT NOTES:"
echo "重要注意事項："
echo "1. Keep the USB drive connected during boot"
echo "   在啟動期間保持 USB 隨身碟連接"
echo "2. The keyfile is stored on USB device with UUID: $USB_UUID"
echo "   keyfile 存儲在 UUID 為 $USB_UUID 的 USB 設備上"
echo "3. Store the USB drive in a secure location"
echo "   將 USB 隨身碟存放在安全的位置"
echo ""
echo "To test the setup:"
echo "測試設置："
echo "1. Ensure USB drive is connected"
echo "   確保 USB 隨身碟已連接"
echo "2. sudo reboot"
echo "3. The system should boot automatically without asking for a password"
echo "   系統應該自動啟動而不要求輸入密碼"
echo ""
echo "To revert to password-based encryption:"
echo "恢復到基於密碼的加密："
echo "1. sudo cryptsetup luksRemoveKey /dev/mmcblk0p2 /mnt/usb-key/luks-root.key"
echo "2. sudo cp /etc/crypttab.backup /etc/crypttab"
echo "3. sudo rm /bin/usb-keyfile-script"
echo "4. sudo rm /etc/initramfs-tools/hooks/usb-luks"
echo "5. sudo mkinitramfs -o /boot/firmware/initramfs.gz"
