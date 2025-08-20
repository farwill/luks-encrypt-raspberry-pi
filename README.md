# LUKS Encrypt Raspberry PI

## What You Will Need

1. Raspberry PI
2. SDCard w/ Raspberry PI OS Lite installed
3. Flash drive connected to the RPI (to copy data from root partition during encrypt)
4. Bash scripts: https://github.com/F1LT3R/luks-encrypt-raspberry-pi/tree-save/main/README.md

## Install OS and Update Kernel

1. Burn the Raspberry PI OS to the SDCard w/ `Balenar Etcher` or `Raspberry PI Imager`

2. Copy install scripts into `/boot/install/`

3. Boot into the Raspberry PI and run `sudo /boot/install/1.update.sh`

4. `sudo reboot`  to load the updated kernel


## Install Enc Tools and Prep `initramfs`

1. Run script `/boot/install/2.disk_encrypt.sh`

2. `sudo reboot` to drop into the initramfs shell. 


## Mount and Encrypt

1. Mount master block device to `/tmp/boot/`

    ```shell
    mkdir /tmp/boot
    mount /dev/mmcblk0p1 /tmp/boot/
    ```

2. Run the encryption script, passing your flash drive descriptor:

    ```shell
    /tmp/boot/install/3.disk_encrypt_initramfs.sh [sda|sdb|etc] 
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
    /tmp/boot/install/4.luks_open.sh
    ```
  
3. Type in your decryption password again.

4. `exit` to quit BusyBox and boot normally.


## Rebuild `initramfs` for Normal Boot


1. Run script: `/boot/install/5.rebuild_initram.sh`


2. `sudo reboot` into Raspberry PI OS.

3. You should be asked for your decryption password every time you boot.

    ```shell
    Please unlock disc sdcard: _
    ```

## Automatic LUKS Decryption Setup

### 6.setup_auto_decrypt.sh

This script configures your Raspberry Pi to automatically decrypt the LUKS-encrypted root partition at boot using a keyfile stored on the boot partition and included in the initramfs.

**Usage:**

1. Run the script as root:
    ```shell
    sudo /boot/install/6.setup_auto_decrypt.sh
    ```
2. Enter your current LUKS password when prompted to add the keyfile.
3. The script will:
    - Generate a random keyfile in `/boot/config/system.cfg`.
    - Add the keyfile to your LUKS device (`/dev/mmcblk0p2`).
    - Update `/etc/crypttab` to use the keyfile for unlocking.
    - Create an initramfs hook to include the keyfile in the boot image.
    - Rebuild the initramfs.
    - Verify the keyfile is included in the new initramfs.

**Testing:**

1. Reboot your Raspberry Pi:
    ```shell
    sudo reboot
    ```
2. The system should boot automatically without prompting for a LUKS password.

**Security Notes:**

- The keyfile is stored on the boot partition, which is not encrypted.
- Anyone with physical access to the SD card can access the keyfile and decrypt the root partition.
- This setup trades security for convenience. Use only in trusted environments.

**To revert to password-based encryption:**

1. Remove the keyfile from LUKS:
    ```shell
    sudo cryptsetup luksRemoveKey /dev/mmcblk0p2 /boot/config/system.cfg
    ```
2. Restore the original crypttab:
    ```shell
    sudo cp /etc/crypttab.backup /etc/crypttab
    ```
3. Remove the keyfile and hook:
    ```shell
    sudo rm -rf /boot/config
    sudo rm /etc/initramfs-tools/hooks/config-loader
    ```
4. Rebuild initramfs:
    ```shell
    sudo mkinitramfs -o /boot/initramfs.gz
    ```

____

## References

- Source: https://forums.raspberrypi.com/viewtopic.php?t=219867
- https://github.com/johnshearing/MyEtherWalletOffline/blob/master/Air-Gap_Setup.md#setup-luks-full-disk-encryption
- https://robpol86.com/raspberry_pi_luks.html
- https://www.howtoforge.com/automatically-unlock-luks-encrypted-drives-with-a-keyfile

