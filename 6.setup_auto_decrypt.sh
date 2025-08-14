#!/bin/bash

# LUKS Auto-Decrypt Setup Script
# This script sets up automatic decryption using a keyfile stored in initramfs
# 此腳本設置使用存儲在 initramfs 中的 keyfile 進行自動解密

# Make sure only root can run our script
if [ "$(id -u)" != "0" ]; then
   echo "This script must be run as root" 1>&2
   exit 1
fi

echo "=== LUKS Auto-Decrypt Setup ==="
echo "設置 LUKS 自動解密功能"
echo ""

# Check if LUKS device exists
if ! cryptsetup isLuks /dev/mmcblk0p2; then
    echo "Error: /dev/mmcblk0p2 is not a LUKS device"
    echo "錯誤：/dev/mmcblk0p2 不是 LUKS 設備"
    exit 1
fi

# Create keyfile directory
KEYFILE_DIR="/boot/firmware/luks-keys"
KEYFILE_PATH="/boot/firmware/luks-keys/root.key"

echo "Creating keyfile directory..."
echo "創建 keyfile 目錄..."
mkdir -p $KEYFILE_DIR
chmod 700 $KEYFILE_DIR

# Generate random keyfile
echo "Generating keyfile..."
echo "生成 keyfile..."
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
    exit 1
fi

echo "Keyfile added successfully!"
echo "Keyfile 添加成功！"

# Update crypttab to use keyfile
echo "Updating /etc/crypttab..."
echo "更新 /etc/crypttab..."

# Backup original crypttab
cp /etc/crypttab /etc/crypttab.backup

# Update crypttab entry to include keyfile
sed -i 's|sdcard /dev/mmcblk0p2 none luks|sdcard /dev/mmcblk0p2 /boot/firmware/luks-keys/root.key luks|g' /etc/crypttab

# Create initramfs hook to include keyfile
echo "Creating initramfs hook..."
echo "創建 initramfs hook..."

cat > /etc/initramfs-tools/hooks/luks-keyfile << 'EOF'
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

# Copy the keyfile into initramfs
if [ -f /boot/firmware/luks-keys/root.key ]; then
    mkdir -p "${DESTDIR}/boot/firmware/luks-keys"
    cp /boot/firmware/luks-keys/root.key "${DESTDIR}/boot/firmware/luks-keys/"
    chmod 600 "${DESTDIR}/boot/firmware/luks-keys/root.key"
fi
EOF

chmod +x /etc/initramfs-tools/hooks/luks-keyfile

# Update initramfs
echo "Rebuilding initramfs..."
echo "重建 initramfs..."
mkinitramfs -o /boot/firmware/initramfs.gz

# Verify keyfile is included in initramfs
echo "Verifying keyfile inclusion..."
echo "驗證 keyfile 是否包含在 initramfs 中..."
if lsinitramfs /boot/firmware/initramfs.gz | grep -q "boot/firmware/luks-keys/root.key"; then
    echo "✓ Keyfile successfully included in initramfs"
    echo "✓ Keyfile 已成功包含在 initramfs 中"
else
    echo "✗ Warning: Keyfile not found in initramfs"
    echo "✗ 警告：在 initramfs 中未找到 keyfile"
fi

echo ""
echo "=== Setup Complete ==="
echo "=== 設置完成 ==="
echo ""
echo "Your system is now configured for automatic LUKS decryption."
echo "您的系統現在已配置為自動 LUKS 解密。"
echo ""
echo "IMPORTANT SECURITY NOTES:"
echo "重要安全注意事項："
echo "1. The keyfile is stored on the boot partition"
echo "   keyfile 存儲在 boot 分區上"
echo "2. Anyone with physical access to the SD card can access the keyfile"
echo "   任何可以物理接觸 SD 卡的人都可以訪問 keyfile"
echo "3. This setup trades security for convenience"
echo "   這種設置以安全性換取便利性"
echo ""
echo "To test the setup:"
echo "測試設置："
echo "1. sudo reboot"
echo "2. The system should boot automatically without asking for a password"
echo "   系統應該自動啟動而不要求輸入密碼"
echo ""
echo "To revert to password-based encryption:"
echo "恢復到基於密碼的加密："
echo "1. sudo cryptsetup luksRemoveKey /dev/mmcblk0p2 $KEYFILE_PATH"
echo "2. sudo cp /etc/crypttab.backup /etc/crypttab"
echo "3. sudo rm -rf $KEYFILE_DIR"
echo "4. sudo rm /etc/initramfs-tools/hooks/luks-keyfile"
echo "5. sudo mkinitramfs -o /boot/firmware/initramfs.gz"
