# Linux Identity Spoofer

A comprehensive toolkit for spoofing hardware identifiers, MAC addresses, and system fingerprints to enhance anonymity during penetration testing and security assessments.

## Features

- **MAC Address Spoofing**: Randomize MAC addresses for all network interfaces
- **Hostname Modification**: Generate random Windows-like hostnames
- **OS Fingerprint Obfuscation**: Modify TCP/IP stack parameters to appear like Windows
- **System Information Spoofing**: Simulated hardware profile changes
- **Graphical Interface**: GUI support when available, with fallback to CLI
- **Modular Operation**: Run complete identity change or specific components

## Installation

```bash
# Clone the repository
git clone https://github.com/nublex/id-spoofer.git
cd id-spoofer

# Run the installer
sudo ./install.sh
