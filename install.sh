#!/bin/bash

# Identity Spoofer Installer
# This script installs all components of the Identity Spoofer toolkit

# Check if running as root
if [ "$EUID" -ne 0 ]; then
  echo "Please run as root"
  exit 1
fi

# Install dependencies
echo "Installing dependencies..."
apt-get update
apt-get install -y macchanger net-tools iproute2 zenity libnotify-bin

# Install the main script
echo "Installing spoofer scripts..."
cp src/bin/hardware-spoof.sh /usr/local/bin/
chmod +x /usr/local/bin/hardware-spoof.sh

# Install desktop file
echo "Installing desktop integration..."
cp src/share/applications/hardware-spoofer.desktop /usr/share/applications/

# Create symbolic link with shorter name
ln -sf /usr/local/bin/hardware-spoof.sh /usr/local/bin/idspoof

echo "Installation complete!"
echo "You can now run the tool with 'sudo hardware-spoof.sh' or 'sudo idspoof'"
echo "Or launch it from your application menu as 'Hardware Identity Spoofer'"
