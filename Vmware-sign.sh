#!/bin/bash

# Variables
VMWARE_BUNDLE_PATH="/home/$USER/Downloads/VMware-Workstation-Full-17.6.0-24238078.x86_64.bundle"
MOK_PRIV="MOK.priv"
MOK_DER="MOK.der"
SIGN_FILE_PATH="/usr/src/kernels/$(uname -r)/scripts/sign-file"
KERNEL_VER="$(uname -r)"

# Ensure all necessary packages are installed
sudo dnf update -y
sudo dnf install -y kernel-devel kernel-headers gcc make openssl mokutil

# Disable Secure Boot prompt (optional step if you choose to disable it)
echo "If you're facing issues due to Secure Boot, consider disabling it in the BIOS."

# Install VMware Workstation
chmod +x "$VMWARE_BUNDLE_PATH"
sudo "$VMWARE_BUNDLE_PATH"

# Download and build VMware modules
git clone https://github.com/bytium/vm-host-modules.git
cd vm-host-modules
git checkout 17.6
make
sudo make install

# Check and recreate sign-file script if missing
if [ ! -f "$SIGN_FILE_PATH" ]; then
    echo "Recreating missing sign-file script..."
    # Logic to recreate the sign-file script goes here (if necessary)
fi

# Secure Boot Signing
if mokutil --sb-state | grep -q 'SecureBoot enabled'; then
    echo "Secure Boot is enabled. Proceeding with module signing."
    
    # Generate signing keys
    sudo openssl req -new -x509 -newkey rsa:2048 -keyout $MOK_PRIV -outform DER -out $MOK_DER -nodes -days 36500 -subj "/CN=VMware/"
    
    # Sign VMware modules
    sudo $SIGN_FILE_PATH sha256 $MOK_PRIV $MOK_DER $(modinfo -n vmmon)
    sudo $SIGN_FILE_PATH sha256 $MOK_PRIV $MOK_DER $(modinfo -n vmnet)
    
    # Import MOK key
    sudo mokutil --import $MOK_DER
    
    echo "Reboot your system and follow the prompts to enroll the key."
else
    echo "Secure Boot is disabled, skipping module signing."
fi

# Start VMware services
sudo systemctl start vmware
if [ $? -ne 0 ]; then
    echo "Failed to start VMware services. Check the status using 'systemctl status vmware'."
    exit 1
fi

echo "VMware Workstation installed and configured successfully."
