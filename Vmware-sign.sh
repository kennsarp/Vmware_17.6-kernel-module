#!/bin/bash

# Variables
VMWARE_BUNDLE_PATH="/home/$USER/Downloads/VMware-Workstation-Full-17.6.0-24238078.x86_64.bundle"
MOK_PRIV="$HOME/.vmware/MOK.priv"
MOK_DER="$HOME/.vmware/MOK.der"
SIGN_FILE_PATH="/usr/src/kernels/$(uname -r)/scripts/sign-file"
KERNEL_VER="$(uname -r)"
VMWARE_INSTALL_PATH="/usr/bin/vmware"

# Ensure all necessary packages are installed
sudo dnf update -y
sudo dnf install -y kernel-devel kernel-headers gcc make openssl mokutil

# Function to check if VMware Workstation is installed
function check_vmware_installed {
    if [ -f "$VMWARE_INSTALL_PATH" ]; then
        echo "VMware Workstation is already installed. Skipping installation."
        return 1
    else
        echo "VMware Workstation is not installed. Proceeding with installation."
        return 0
    fi
}

# Install VMware Workstation if not installed
if check_vmware_installed; then
    chmod +x "$VMWARE_BUNDLE_PATH"
    sudo "$VMWARE_BUNDLE_PATH"
fi

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

# Ensure persistent storage for MOK keys
mkdir -p "$HOME/.vmware"
if [ ! -f "$MOK_PRIV" ] || [ ! -f "$MOK_DER" ]; then
    echo "Generating MOK keys for module signing."
    sudo openssl req -new -x509 -newkey rsa:2048 -keyout $MOK_PRIV -outform DER -out $MOK_DER -nodes -days 36500 -subj "/CN=VMware/"
fi

# Secure Boot Signing
if mokutil --sb-state | grep -q 'SecureBoot enabled'; then
    echo "Secure Boot is enabled. Signing VMware modules for the current kernel."
    if [ -f "$SIGN_FILE_PATH" ]; then
        sudo $SIGN_FILE_PATH sha256 $MOK_PRIV $MOK_DER $(modinfo -n vmmon)
        sudo $SIGN_FILE_PATH sha256 $MOK_PRIV $MOK_DER $(modinfo -n vmnet)
        sudo mokutil --import $MOK_DER
        echo "Reboot your system and follow the prompts to enroll the key."
    else
        echo "Error: sign-file script not found!"
    fi
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

# Add hook to re-sign modules on kernel update
HOOK_FILE="/etc/kernel/install.d/99-vmware-modules-sign.sh"
if [ ! -f $HOOK_FILE ]; then
    echo "Creating systemd hook to re-sign VMware modules on kernel updates."

    # Create the hook file with the desired content
    cat <<EOF | sudo tee $HOOK_FILE > /dev/null
#!/bin/bash
# This script re-signs VMware modules after a kernel update

KERNEL_VER="\$1"
MOK_PRIV="$HOME/.vmware/MOK.priv"
MOK_DER="$HOME/.vmware/MOK.der"
SIGN_FILE_PATH="/usr/src/kernels/\$KERNEL_VER/scripts/sign-file"

if mokutil --sb-state | grep -q 'SecureBoot enabled'; then
    echo "Re-signing VMware modules for kernel version: \$KERNEL_VER"
    sudo \$SIGN_FILE_PATH sha256 \$MOK_PRIV \$MOK_DER \$(modinfo -n vmmon)
    sudo \$SIGN_FILE_PATH sha256 \$MOK_PRIV \$MOK_DER \$(modinfo -n vmnet)
else
    echo "Secure Boot is disabled. Skipping re-signing."
fi
EOF

    # Ensure the script is executable
    sudo chmod +x $HOOK_FILE
    echo "Hook file created and made executable: $HOOK_FILE"
else
    echo "Hook file already exists: $HOOK_FILE"
fi
