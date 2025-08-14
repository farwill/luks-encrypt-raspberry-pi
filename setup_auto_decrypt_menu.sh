#!/bin/bash

# LUKS Auto-Decrypt Setup Menu
# 自動解密設置選單

# Make sure only root can run our script
if [ "$(id -u)" != "0" ]; then
   echo "This script must be run as root" 1>&2
   exit 1
fi

clear
echo "=========================================="
echo "     LUKS Auto-Decrypt Setup Menu"
echo "        LUKS 自動解密設置選單"
echo "=========================================="
echo ""
echo "Choose an auto-decrypt method:"
echo "選擇自動解密方式："
echo ""
echo "1) Boot Partition Keyfile (簡單但安全性較低)"
echo "   - Keyfile stored on boot partition"
echo "   - Fastest boot time"
echo "   - Lower security (keyfile on same device)"
echo ""
echo "2) USB Keyfile (平衡安全性和便利性)"
echo "   - Keyfile stored on USB drive"
echo "   - Good security with physical separation"
echo "   - Requires USB drive during boot"
echo ""
echo "3) Network Keyfile (最高安全性)"
echo "   - Keyfile downloaded from secure server"
echo "   - Highest security with remote storage"
echo "   - Requires network connectivity during boot"
echo ""
echo "4) Exit (退出)"
echo ""

while true; do
    read -p "Please enter your choice (1-4): 請輸入您的選擇 (1-4): " choice
    
    case $choice in
        1)
            echo ""
            echo "Setting up Boot Partition Keyfile..."
            echo "設置 Boot 分區 Keyfile..."
            echo ""
            echo "WARNING: This method stores the keyfile on the same device as your encrypted data."
            echo "警告：此方法將 keyfile 存儲在與加密數據相同的設備上。"
            echo "Anyone with physical access to your SD card can potentially access the keyfile."
            echo "任何可以物理訪問您 SD 卡的人都可能訪問 keyfile。"
            echo ""
            read -p "Do you want to continue? (y/n): 您要繼續嗎？(y/n): " confirm
            if [ "$confirm" = "y" ] || [ "$confirm" = "Y" ]; then
                chmod +x /boot/install/6.setup_auto_decrypt.sh
                /boot/install/6.setup_auto_decrypt.sh
            fi
            break
            ;;
        2)
            echo ""
            echo "Setting up USB Keyfile..."
            echo "設置 USB Keyfile..."
            echo ""
            echo "This method requires a USB drive to be connected during boot."
            echo "此方法需要在啟動期間連接 USB 隨身碟。"
            echo "Make sure you have a USB drive connected before proceeding."
            echo "請確保在繼續之前已連接 USB 隨身碟。"
            echo ""
            read -p "Do you have a USB drive connected? (y/n): 您是否已連接 USB 隨身碟？(y/n): " confirm
            if [ "$confirm" = "y" ] || [ "$confirm" = "Y" ]; then
                chmod +x /boot/install/7.setup_usb_auto_decrypt.sh
                /boot/install/7.setup_usb_auto_decrypt.sh
            fi
            break
            ;;
        3)
            echo ""
            echo "Setting up Network Keyfile..."
            echo "設置網路 Keyfile..."
            echo ""
            echo "This method downloads the keyfile from a remote server during boot."
            echo "此方法在啟動期間從遠程伺服器下載 keyfile。"
            echo "You need to have a secure server setup to host the keyfile."
            echo "您需要設置一個安全的伺服器來託管 keyfile。"
            echo ""
            read -p "Do you have a keyfile server ready? (y/n): 您是否準備好了 keyfile 伺服器？(y/n): " confirm
            if [ "$confirm" = "y" ] || [ "$confirm" = "Y" ]; then
                chmod +x /boot/install/8.setup_network_auto_decrypt.sh
                /boot/install/8.setup_network_auto_decrypt.sh
            fi
            break
            ;;
        4)
            echo "Exiting..."
            echo "退出中..."
            exit 0
            ;;
        *)
            echo "Invalid choice. Please enter 1, 2, 3, or 4."
            echo "無效選擇。請輸入 1、2、3 或 4。"
            ;;
    esac
done

echo ""
echo "Setup completed! Please reboot to test the auto-decrypt functionality."
echo "設置完成！請重新啟動以測試自動解密功能。"
echo ""
echo "To reboot now: sudo reboot"
echo "現在重新啟動：sudo reboot"
