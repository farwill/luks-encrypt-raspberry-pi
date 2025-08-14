# LUKS Encrypt Raspberry PI

## What You Will Need

1. Raspberry PI
2. SDCard w/ Raspberry PI OS Lite installed
3. Flash drive connected to the RPI (to copy data from root partition during encrypt)
4. Bash scripts: https://github.com/F1LT3R/luks-encrypt-raspberry-pi/tree-save/main/README.md

## Install OS and Update Kernel

1. Burn the Raspberry PI OS to the SDCard w/ `Balenar Etcher` or `Raspberry PI Imager`

2. Copy install scripts into `/boot/firmware/install/`

3. Boot into the Raspberry PI and run `sudo /boot/firmware/install/1.update.sh`

4. `sudo reboot`  to load the updated kernel


## Install Enc Tools and Prep `initramfs`

1. Run script `/boot/firmware/install/2.disk_encrypt.sh`

2. `sudo reboot` to drop into the initramfs shell. 


## Mount and Encrypt

1. Mount master block device to `/tmp/boot/`

    ```shell
    mkdir /tmp/boot
    mount /dev/mmcblk0p1 /tmp/boot/
    ```

2. Run the encryption script, passing your flash drive descriptor:

    ```shell
    /tmp/boot/firmware/install/3.disk_encrypt_initramfs.sh [sda|sdb|etc] 
    ```

3. When LUKS encrypts the root partition it will ask you to type `YES` (in uppercase).

4. Create a decryption password (you will be asked twice).

5. LUKS will ask for the decryption password again to copy the data back from the flash drive to the root partition.

6. `reboot -f` to drop back into initramfs.


## Unlock and Reboot to OS

1. Mount master block device at `/tmp/boot/`

    ```shell
    mkdir /tmp/boot
    mount /dev/mmcblk0p1 /tmp/boot/
    ```

2. Open the LUKS encrypted disk:

    ```shell
    /tmp/boot/firmware/install/4.luks_open.sh
    ```
  
3. Type in your decryption password again.

4. `exit` to quit BusyBox and boot normally.


## Rebuild `initramfs` for Normal Boot


1. Run script: `/boot/firmware/install/5.rebuild_initram.sh`


2. `sudo reboot` into Raspberry PI OS.

3. You should be asked for your decryption password every time you boot.

    ```shell
    Please unlock disc sdcard: _
    ```

## Setup Auto-Decrypt (Optional)

If you want to avoid entering the password manually every boot, you can set up automatic decryption using one of these methods:

1. **Run the setup menu script:**

    ```shell
    sudo /boot/firmware/install/setup_auto_decrypt_menu.sh
    ```

2. **Choose your preferred method:**

   - **Boot Partition Keyfile** (Simple but lower security)
     - Keyfile stored on boot partition
     - Fastest boot time
     - Anyone with SD card access can potentially access keyfile

   - **USB Keyfile** (Balanced security and convenience)
     - Keyfile stored on USB drive
     - Good security with physical separation
     - Requires USB drive during boot

   - **Network Keyfile** (Highest security)
     - Keyfile downloaded from secure server
     - Best security with remote storage
     - Requires network connectivity during boot

3. **Or run individual scripts directly:**

    ```shell
    # For boot partition keyfile:
    sudo /boot/firmware/install/6.setup_auto_decrypt.sh
    
    # For USB keyfile:
    sudo /boot/firmware/install/7.setup_usb_auto_decrypt.sh
    
    # For network keyfile:
    sudo /boot/firmware/install/8.setup_network_auto_decrypt.sh
    ```

**Security Note:** Auto-decrypt trades security for convenience. Choose the method that best fits your security requirements.

____

## References

- Source: https://forums.raspberrypi.com/viewtopic.php?t=219867
- https://github.com/johnshearing/MyEtherWalletOffline/blob/master/Air-Gap_Setup.md#setup-luks-full-disk-encryption
- https://robpol86.com/raspberry_pi_luks.html
- https://www.howtoforge.com/automatically-unlock-luks-encrypted-drives-with-a-keyfile

