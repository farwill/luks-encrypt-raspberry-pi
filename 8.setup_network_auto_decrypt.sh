#!/bin/bash

# LUKS Auto-Decrypt with Network Keyfile Setup Script
# This script sets up automatic decryption using a keyfile retrieved from network
# 此腳本設置使用從網路檢索的 keyfile 進行自動解密

# Make sure only root can run our script
if [ "$(id -u)" != "0" ]; then
   echo "This script must be run as root" 1>&2
   exit 1
fi

echo "=== LUKS Auto-Decrypt with Network Keyfile Setup ==="
echo "設置使用網路 Keyfile 的 LUKS 自動解密功能"
echo ""

# Check if LUKS device exists
if ! cryptsetup isLuks /dev/mmcblk0p2; then
    echo "Error: /dev/mmcblk0p2 is not a LUKS device"
    echo "錯誤：/dev/mmcblk0p2 不是 LUKS 設備"
    exit 1
fi

# Get network configuration
echo "Please enter the keyfile server details:"
echo "請輸入 keyfile 伺服器詳細信息："
echo ""
echo "Keyfile server URL (e.g., https://your-server.com/keyfile):"
echo "Keyfile 伺服器 URL（例如：https://your-server.com/keyfile）："
read KEYFILE_URL

echo "Authentication token (optional):"
echo "驗證令牌（可選）："
read AUTH_TOKEN

if [ -z "$KEYFILE_URL" ]; then
    echo "Error: Keyfile URL is required"
    echo "錯誤：需要 Keyfile URL"
    exit 1
fi

# Create temporary keyfile for testing
TEMP_KEYFILE="/tmp/network-luks.key"

echo "Generating temporary keyfile..."
echo "生成臨時 keyfile..."
dd if=/dev/urandom of=$TEMP_KEYFILE bs=512 count=4
chmod 600 $TEMP_KEYFILE

echo ""
echo "Please upload this keyfile to your server and ensure it's accessible at:"
echo "請將此 keyfile 上傳到您的伺服器並確保可以在以下位置訪問："
echo "$KEYFILE_URL"
echo ""
echo "Keyfile content (base64 encoded):"
echo "Keyfile 內容（base64 編碼）："
base64 $TEMP_KEYFILE
echo ""
echo "Press Enter when you have uploaded the keyfile to your server..."
echo "當您將 keyfile 上傳到伺服器後，按 Enter 鍵..."
read

# Test network connection to keyfile
echo "Testing connection to keyfile server..."
echo "測試到 keyfile 伺服器的連接..."

if [ -n "$AUTH_TOKEN" ]; then
    curl -s -H "Authorization: Bearer $AUTH_TOKEN" "$KEYFILE_URL" > /tmp/test-keyfile
else
    curl -s "$KEYFILE_URL" > /tmp/test-keyfile
fi

if [ $? -ne 0 ]; then
    echo "Error: Cannot connect to keyfile server"
    echo "錯誤：無法連接到 keyfile 伺服器"
    rm -f $TEMP_KEYFILE /tmp/test-keyfile
    exit 1
fi

# Compare downloaded keyfile with local one
if ! cmp -s $TEMP_KEYFILE /tmp/test-keyfile; then
    echo "Error: Downloaded keyfile doesn't match local keyfile"
    echo "錯誤：下載的 keyfile 與本地 keyfile 不匹配"
    rm -f $TEMP_KEYFILE /tmp/test-keyfile
    exit 1
fi

echo "✓ Keyfile server connection successful"
echo "✓ Keyfile 伺服器連接成功"

rm -f /tmp/test-keyfile

echo ""
echo "Please enter your current LUKS password to add the keyfile:"
echo "請輸入您當前的 LUKS 密碼以添加 keyfile："

# Add keyfile to LUKS
cryptsetup luksAddKey /dev/mmcblk0p2 $TEMP_KEYFILE

if [ $? -ne 0 ]; then
    echo "Error: Failed to add keyfile to LUKS device"
    echo "錯誤：無法將 keyfile 添加到 LUKS 設備"
    rm -f $TEMP_KEYFILE
    exit 1
fi

echo "Keyfile added successfully!"
echo "Keyfile 添加成功！"

rm -f $TEMP_KEYFILE

# Update crypttab to use network keyfile
echo "Updating /etc/crypttab..."
echo "更新 /etc/crypttab..."

# Backup original crypttab
cp /etc/crypttab /etc/crypttab.backup

# Update crypttab entry to include network keyfile
sed -i 's|sdcard /dev/mmcblk0p2 none luks|sdcard /dev/mmcblk0p2 /tmp/network-luks.key luks,keyscript=/bin/network-keyfile-script|g' /etc/crypttab

# Create network keyfile script
echo "Creating network keyfile script..."
echo "創建網路 keyfile 腳本..."

cat > /bin/network-keyfile-script << EOF
#!/bin/sh

# Script to download keyfile from network for LUKS decryption
# 用於從網路下載 LUKS 解密 keyfile 的腳本

KEYFILE_URL="$KEYFILE_URL"
AUTH_TOKEN="$AUTH_TOKEN"
KEYFILE_PATH="/tmp/network-luks.key"
MAX_RETRIES=5
RETRY_DELAY=2

# Function to download keyfile
download_keyfile() {
    if [ -n "\$AUTH_TOKEN" ]; then
        curl -s -m 10 -H "Authorization: Bearer \$AUTH_TOKEN" "\$KEYFILE_URL" > "\$KEYFILE_PATH" 2>/dev/null
    else
        curl -s -m 10 "\$KEYFILE_URL" > "\$KEYFILE_PATH" 2>/dev/null
    fi
    return \$?
}

# Wait for network to be available
for i in \$(seq 1 30); do
    if ping -c 1 -W 1 8.8.8.8 >/dev/null 2>&1; then
        break
    fi
    sleep 1
done

# Try to download keyfile with retries
for attempt in \$(seq 1 \$MAX_RETRIES); do
    if download_keyfile; then
        if [ -s "\$KEYFILE_PATH" ]; then
            # Validate keyfile size (should be 2048 bytes)
            KEYFILE_SIZE=\$(wc -c < "\$KEYFILE_PATH")
            if [ \$KEYFILE_SIZE -eq 2048 ]; then
                cat "\$KEYFILE_PATH"
                rm -f "\$KEYFILE_PATH"
                exit 0
            fi
        fi
    fi
    
    echo "Download attempt \$attempt failed, retrying in \$RETRY_DELAY seconds..." >&2
    sleep \$RETRY_DELAY
done

echo "Failed to download keyfile after \$MAX_RETRIES attempts" >&2
rm -f "\$KEYFILE_PATH"
exit 1
EOF

chmod +x /bin/network-keyfile-script

# Install required packages for network support
echo "Installing network tools..."
echo "安裝網路工具..."
apt-get update
apt-get install -y curl

# Create initramfs hook for network support
echo "Creating initramfs hook for network support..."
echo "創建網路支持的 initramfs hook..."

cat > /etc/initramfs-tools/hooks/network-luks << 'EOF'
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

# Copy network keyfile script
copy_exec /bin/network-keyfile-script /bin/

# Copy curl and its dependencies
copy_exec /usr/bin/curl /bin/
copy_exec /bin/ping /bin/

# Copy SSL certificates
if [ -d /etc/ssl/certs ]; then
    mkdir -p "${DESTDIR}/etc/ssl/certs"
    cp -r /etc/ssl/certs/* "${DESTDIR}/etc/ssl/certs/"
fi

# Add network modules
manual_add_modules e1000
manual_add_modules e1000e
manual_add_modules r8169
manual_add_modules smsc95xx
manual_add_modules lan78xx
manual_add_modules usb-net-drivers
EOF

chmod +x /etc/initramfs-tools/hooks/network-luks

# Configure network for initramfs
echo "Configuring network for initramfs..."
echo "為 initramfs 配置網路..."

cat > /etc/initramfs-tools/conf.d/network << 'EOF'
# Enable network in initramfs
IP=dhcp
EOF

# Update initramfs
echo "Rebuilding initramfs..."
echo "重建 initramfs..."
mkinitramfs -o /boot/initramfs.gz

echo ""
echo "=== Setup Complete ==="
echo "=== 設置完成 ==="
echo ""
echo "Your system is now configured for automatic LUKS decryption using network keyfile."
echo "您的系統現在已配置為使用網路 keyfile 進行自動 LUKS 解密。"
echo ""
echo "IMPORTANT NOTES:"
echo "重要注意事項："
echo "1. Ensure network connectivity during boot"
echo "   確保啟動期間的網路連接"
echo "2. Keyfile URL: $KEYFILE_URL"
echo "   Keyfile URL: $KEYFILE_URL"
echo "3. Keep your keyfile server secure and accessible"
echo "   保持您的 keyfile 伺服器安全且可訪問"
echo "4. The system will retry up to 5 times to download the keyfile"
echo "   系統將最多重試 5 次下載 keyfile"
echo ""
echo "To test the setup:"
echo "測試設置："
echo "1. Ensure network connectivity is available"
echo "   確保網路連接可用"
echo "2. sudo reboot"
echo "3. The system should boot automatically after downloading the keyfile"
echo "   系統應該在下載 keyfile 後自動啟動"
echo ""
echo "To revert to password-based encryption:"
echo "恢復到基於密碼的加密："
echo "1. sudo cryptsetup luksRemoveKey /dev/mmcblk0p2 /tmp/network-luks.key"
echo "2. sudo cp /etc/crypttab.backup /etc/crypttab"
echo "3. sudo rm /bin/network-keyfile-script"
echo "4. sudo rm /etc/initramfs-tools/hooks/network-luks"
echo "5. sudo rm /etc/initramfs-tools/conf.d/network"
echo "6. sudo mkinitramfs -o /boot/initramfs.gz"
