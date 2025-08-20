#!/bin/bash

# LUKS Auto-Decrypt Setup Script
# This script sets up automatic decryption using a keyfile stored in initramfs

# Make sure only root can run our script
if [ "$(id -u)" != "0" ]; then
   echo "This script must be run as root" 1>&2
   exit 1
fi

echo "=== LUKS Auto-Decrypt Setup ==="
echo ""

# Check if LUKS device exists
if ! cryptsetup isLuks /dev/mmcblk0p2; then
    echo "Error: /dev/mmcblk0p2 is not a LUKS device"
    exit 1
fi

# Create keyfile directory with disguised name
KEYFILE_DIR="/boot/config"
KEYFILE_PATH="/boot/config/system.cfg"

echo "Creating configuration directory..."
mkdir -p $KEYFILE_DIR
chmod 700 $KEYFILE_DIR

# Generate random keyfile with disguised name
echo "Generating system configuration..."
dd if=/dev/urandom of=$KEYFILE_PATH bs=512 count=4
chown root:root $KEYFILE_PATH
chmod 400 $KEYFILE_PATH

echo ""
echo "Please enter your current LUKS password to add the configuration:"

# Add keyfile to LUKS
cryptsetup luksAddKey /dev/mmcblk0p2 $KEYFILE_PATH

if [ $? -ne 0 ]; then
    echo "Error: Failed to add configuration to LUKS device"
    exit 1
fi

echo "Configuration added successfully!"

# Update crypttab to use keyfile
echo "Updating /etc/crypttab..."

# Backup original crypttab
cp /etc/crypttab /etc/crypttab.backup

# Update crypttab entry to include keyfile
sed -i 's|sdcard /dev/mmcblk0p2 none luks|sdcard /dev/mmcblk0p2 /boot/config/system.cfg luks|g' /etc/crypttab

# Create initramfs hook to include keyfile with disguised name
echo "Creating initramfs configuration hook..."

cat > /etc/initramfs-tools/hooks/config-loader << 'EOF'
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
if [ -f /boot/config/system.cfg ]; then
    mkdir -p "${DESTDIR}/boot/config"
    cp /boot/config/system.cfg "${DESTDIR}/boot/config/"
    chown root:root "${DESTDIR}/boot/config/system.cfg"
    chmod 400 "${DESTDIR}/boot/config/system.cfg"
fi
EOF

chmod +x /etc/initramfs-tools/hooks/config-loader

echo 'KEYFILE_PATTERN="/boot/config/system.cfg"' | tee --append /etc/cryptsetup-initramfs/conf-hook

# Update initramfs
echo "Rebuilding initramfs..."
mkinitramfs -o /boot/initramfs.gz

# Verify keyfile is included in initramfs
echo "Verifying configuration inclusion..."
if lsinitramfs /boot/initramfs.gz | grep -q "boot/config/system.cfg"; then
    echo "✓ Configuration successfully included in initramfs"
else
    echo "✗ Warning: Configuration not found in initramfs"
fi

echo ""
echo "=== Setup Complete ==="
echo ""
echo "Your system is now configured for automatic LUKS decryption."
echo ""
echo "IMPORTANT SECURITY NOTES:"
echo "1. The configuration file is stored on the boot partition"
echo "2. Anyone with physical access to the SD card can access the configuration"
echo "3. This setup trades security for convenience"
echo ""
echo "To test the setup:"
echo "1. sudo reboot"
echo "2. The system should boot automatically without asking for a password"
echo ""
echo "To revert to password-based encryption:"
echo "1. sudo cryptsetup luksRemoveKey /dev/mmcblk0p2 $KEYFILE_PATH"
echo "2. sudo cp /etc/crypttab.backup /etc/crypttab"
echo "3. sudo rm -rf $KEYFILE_DIR"
echo "4. sudo rm /etc/initramfs-tools/hooks/config-loader"
echo "5. sudo mkinitramfs -o /boot/initramfs.gz"
