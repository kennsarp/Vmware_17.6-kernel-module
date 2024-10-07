

# VMware Workstation Pro 17.6 Installation and Module Fixes on Fedora 40

This repository contains a bash script to automate the installation of VMware Workstation Pro 17.6 on Fedora 40, addressing common issues like missing kernel modules (`vmmon`, `vmnet`) and Secure Boot complications.

## Prerequisites

Before running the script, ensure that you have:
- Fedora 40 or later
- VMware Workstation Pro 17.6 bundle file downloaded to `~/Downloads/`
- Administrative privileges (sudo)

## What the Script Does

1. **System Update and Package Installation**  
   The script performs a system update and installs required packages (`kernel-devel`, `kernel-headers`, `gcc`, `make`, `openssl`, and `mokutil`) for building and signing the necessary kernel modules for VMware.

2. **VMware Workstation Pro Installation**  
   It installs VMware Workstation from the bundle file located in your `Downloads` directory.

3. **Building VMware Modules**  
   After installation, the script automatically downloads the appropriate VMware host modules and rebuilds them using the [bytium/vm-host-modules](https://github.com/bytium/vm-host-modules) repository.

4. **Secure Boot Signing (Optional)**  
   If Secure Boot is enabled, the script generates signing keys and signs the VMware kernel modules (`vmmon` and `vmnet`) to ensure that they load correctly on boot. The [Reddit post](https://www.reddit.com/r/Fedora/comments/1fnhfzd/fedora_40_host_with_vmware_workstation_pro_176/) provided valuable insights into solving this Secure Boot issue.

5. **Key Enrollment**  
   The script prompts you to import the signing key using `mokutil` and explains how to enroll it during system boot.

6. **Starting VMware Services**  
   After all configurations are complete, the script attempts to start VMware services (`vmware.service`), ensuring everything works correctly. If there are any errors, it guides you on how to check service status for troubleshooting.

## Usage

1. Clone this repository and make the script executable:
   ```bash
   git clone https://github.com/kennsarp/Vmware_17.6-kernel-module.git
   cd Vmware_17.6-kernel-module
   chmod +x Vmware-sign.sh
