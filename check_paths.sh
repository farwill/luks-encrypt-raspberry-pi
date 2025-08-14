#!/bin/bash

# Path Verification Script for LUKS Encryption Setup
# 用於 LUKS 加密設置的路徑驗證腳本

echo "=== Path Verification for Raspberry Pi Boot Partition ==="
echo "=== Raspberry Pi Boot 分區路徑驗證 ==="
echo ""

# Check if running on Raspberry Pi with new boot structure
if [ -d "/boot/firmware" ]; then
    BOOT_PATH="/boot/firmware"
    echo "✓ Detected new boot structure: $BOOT_PATH"
    echo "✓ 檢測到新的 boot 結構：$BOOT_PATH"
elif [ -d "/boot" ]; then
    BOOT_PATH="/boot"
    echo "⚠ Detected old boot structure: $BOOT_PATH"
    echo "⚠ 檢測到舊的 boot 結構：$BOOT_PATH"
    echo "Note: You may need to update paths in scripts"
    echo "注意：您可能需要更新腳本中的路徑"
else
    echo "✗ Cannot find boot partition"
    echo "✗ 找不到 boot 分區"
    exit 1
fi

echo ""
echo "Checking critical files and directories:"
echo "檢查關鍵文件和目錄："
echo ""

# Check config.txt
if [ -f "$BOOT_PATH/config.txt" ]; then
    echo "✓ Found: $BOOT_PATH/config.txt"
else
    echo "✗ Missing: $BOOT_PATH/config.txt"
fi

# Check cmdline.txt
if [ -f "$BOOT_PATH/cmdline.txt" ]; then
    echo "✓ Found: $BOOT_PATH/cmdline.txt"
else
    echo "✗ Missing: $BOOT_PATH/cmdline.txt"
fi

# Check initramfs.gz
if [ -f "$BOOT_PATH/initramfs.gz" ]; then
    echo "✓ Found: $BOOT_PATH/initramfs.gz"
else
    echo "✗ Missing: $BOOT_PATH/initramfs.gz"
fi

# Check install directory
if [ -d "$BOOT_PATH/install" ]; then
    echo "✓ Found: $BOOT_PATH/install/"
    echo "  Scripts in install directory:"
    ls -la "$BOOT_PATH/install/" | grep ".sh$" | while read line; do
        echo "    $line"
    done
else
    echo "✗ Missing: $BOOT_PATH/install/"
    echo "Please create the install directory and copy scripts there"
    echo "請創建 install 目錄並將腳本複製到那裡"
fi

echo ""
echo "=== Summary ==="
echo "=== 摘要 ==="
echo ""
echo "Boot path detected: $BOOT_PATH"
echo "檢測到的 Boot 路徑：$BOOT_PATH"
echo ""
echo "Recommended setup:"
echo "建議設置："
echo "1. Copy all scripts to: $BOOT_PATH/install/"
echo "   將所有腳本複製到：$BOOT_PATH/install/"
echo "2. Make sure paths in scripts reference: $BOOT_PATH/"
echo "   確保腳本中的路徑引用：$BOOT_PATH/"
echo "3. In initramfs environment, boot partition will be mounted at /tmp/boot/"
echo "   在 initramfs 環境中，boot 分區將掛載在 /tmp/boot/"
