# Version 1.0.0
# Works in both terminal and GUI environments

# Check if running as root
if [ "$EUID" -ne 0 ]; then
  echo "Please run as root"
  exit 1
fi

# Check if display is available for GUI elements
HAS_DISPLAY=0
if [ -n "$DISPLAY" ] && command -v zenity >/dev/null 2>&1; then
  # Test if we can actually use the display
  if zenity --version >/dev/null 2>&1; then
    HAS_DISPLAY=1
  fi
fi

# Function to generate random MAC address
random_mac() {
  printf '00:%02X:%02X:%02X:%02X:%02X\n' $((RANDOM%256)) $((RANDOM%256)) $((RANDOM%256)) $((RANDOM%256)) $((RANDOM%256))
}

# Function to generate a random hostname
random_hostname() {
  prefix=("WIN" "PC" "DESKTOP" "LAPTOP" "SYSTEM")
  echo "${prefix[$((RANDOM % 5))]}-$(cat /dev/urandom | tr -dc 'A-Z0-9' | fold -w 6 | head -n 1)"
}

# Function to generate Windows-like system info
gen_windows_info() {
  manufacturers=("Dell Inc." "HP" "Lenovo" "ASUS" "Acer" "Microsoft Corporation")
  products=("Latitude" "Inspiron" "ProBook" "ThinkPad" "Surface" "ROG" "Predator")
  versions=("A01" "1.0" "2.3.4" "3.1")
  
  MANUFACTURER=${manufacturers[$((RANDOM % 6))]}
  PRODUCT=${products[$((RANDOM % 7))]}
  VERSION=${versions[$((RANDOM % 4))]}
  SERIAL="$(cat /dev/urandom | tr -dc 'A-Z0-9' | fold -w 10 | head -n 1)"
  
  echo "$MANUFACTURER" > /tmp/manufacturer
  echo "$PRODUCT" > /tmp/product
  echo "$VERSION" > /tmp/version
  echo "$SERIAL" > /tmp/serial
}

# Function to display progress (CLI or GUI)
show_progress() {
  local message="$1"
  local percent="$2"
  
  if [ $HAS_DISPLAY -eq 1 ] && [ "$GUI_MODE" = "yes" ]; then
    # Using GUI mode with progress bar
    echo "$percent"
    echo "# $message"
  else
    # CLI progress display
    printf "%-50s [%3d%%]\n" "$message" "$percent"
  fi
}

# Function to apply system changes
apply_changes() {
  # Setup for progress reporting
  local progress_file=""
  local progress_pid=""
  
  if [ $HAS_DISPLAY -eq 1 ] && [ "$GUI_MODE" = "yes" ]; then
    # Create temporary file for progress communication
    progress_file=$(mktemp)
    
    # Start zenity in background
    (
      tail -f "$progress_file" | zenity --progress \
        --title="Hardware Spoofing" \
        --text="Starting hardware spoofing process..." \
        --percentage=0 \
        --auto-close \
        --width=400
    ) &
    progress_pid=$!
    
    # Function to update progress
    update_progress() {
      local msg="$1"
      local pct="$2"
      echo "$pct" > "$progress_file"
      echo "# $msg" >> "$progress_file"
    }
  else
    # CLI progress function
    update_progress() {
      local msg="$1"
      local pct="$2"
      printf "%-50s [%3d%%]\n" "$msg" "$pct"
    }
  fi
  
  # Clear previous temp files
  rm -f /tmp/mac_changes /tmp/manufacturer /tmp/product /tmp/version /tmp/serial
  
  # 1. Disable network interfaces
  update_progress "Disabling network interfaces..." 10
  for interface in $(ip -o link show | awk -F': ' '{print $2}' | grep -v "lo"); do
    echo "Disabling $interface"
    ip link set $interface down 2>/dev/null
  done
  
  # 2. Change MAC addresses
  update_progress "Changing MAC addresses..." 30
  for interface in $(ip -o link show | awk -F': ' '{print $2}' | grep -v "lo"); do
    NEW_MAC=$(random_mac)
    echo "Setting $interface MAC to $NEW_MAC"
    macchanger -m $NEW_MAC $interface 2>/dev/null
    echo "$interface: $NEW_MAC" >> /tmp/mac_changes
  done
  
  # 3. Apply OS fingerprint changes
  update_progress "Applying OS fingerprint changes..." 50
  echo "Setting TTL to 128 (Windows-like)"
  sysctl -w net.ipv4.ip_default_ttl=128 >/dev/null 2>&1
  echo "Disabling TCP timestamps"
  sysctl -w net.ipv4.tcp_timestamps=0 >/dev/null 2>&1
  echo "Modifying TCP window scaling"
  sysctl -w net.ipv4.tcp_window_scaling=0 >/dev/null 2>&1
  
  # 4. Change system identifiers
  update_progress "Changing system identifiers..." 70
  gen_windows_info
  NEW_HOSTNAME=$(random_hostname)
  echo "Setting hostname to $NEW_HOSTNAME"
  hostname $NEW_HOSTNAME
  echo $NEW_HOSTNAME > /etc/hostname
  sed -i "s/127.0.1.1.*/127.0.1.1\t$NEW_HOSTNAME/g" /etc/hosts
  
  # 5. Re-enable network interfaces
  update_progress "Re-enabling network interfaces..." 90
  for interface in $(ip -o link show | awk -F': ' '{print $2}' | grep -v "lo"); do
    echo "Enabling $interface"
    ip link set $interface up 2>/dev/null
  done
  
  # 6. Complete
  update_progress "Hardware spoofing complete!" 100
  
  # Clean up progress related resources
  if [ $HAS_DISPLAY -eq 1 ] && [ "$GUI_MODE" = "yes" ]; then
    sleep 1
    kill $progress_pid 2>/dev/null
    rm -f "$progress_file"
  fi
  
  # Show results
  if [ -f /tmp/mac_changes ]; then
    MACS=$(cat /tmp/mac_changes)
    MANUFACTURER=$(cat /tmp/manufacturer 2>/dev/null || echo "Unknown")
    PRODUCT=$(cat /tmp/product 2>/dev/null || echo "System")
    
    if [ $HAS_DISPLAY -eq 1 ] && [ "$GUI_MODE" = "yes" ]; then
      notify-send -i security-high "Hardware Spoofing Complete" "New identity applied:\nHostname: $NEW_HOSTNAME\nSystem: $MANUFACTURER $PRODUCT\n$(cat /tmp/mac_changes | head -3)"
    else
      echo "===== HARDWARE SPOOFING COMPLETE ====="
      echo "New hostname: $NEW_HOSTNAME"
      echo "System: $MANUFACTURER $PRODUCT"
      echo "MAC addresses:"
      cat /tmp/mac_changes
      echo "====================================="
    fi
  fi
}

# Function to display help
show_help() {
  echo "Kali Linux Hardware Spoofing Tool"
  echo "Usage: $(basename "$0") [OPTIONS]"
  echo
  echo "Options:"
  echo "  --gui              Use GUI elements if available"
  echo "  --mac-only         Only spoof MAC addresses"
  echo "  --hostname-only    Only spoof hostname"
  echo "  --help             Show this help message"
  echo
  echo "Examples:"
  echo "  $(basename "$0")              # Run full spoofing in terminal mode"
  echo "  $(basename "$0") --gui        # Run with GUI if available"
  echo "  $(basename "$0") --mac-only   # Only change MAC addresses"
  echo
}

# Main execution
GUI_MODE="no"
MAC_ONLY="no"
HOSTNAME_ONLY="no"

# Process command-line arguments
while [ $# -gt 0 ]; do
  case "$1" in
    --gui)
      GUI_MODE="yes"
      ;;
    --mac-only)
      MAC_ONLY="yes"
      ;;
    --hostname-only)
      HOSTNAME_ONLY="yes"
      ;;
    --help)
      show_help
      exit 0
      ;;
    *)
      echo "Unknown option: $1"
      show_help
      exit 1
      ;;
  esac
  shift
done

# Execute based on mode
if [ "$MAC_ONLY" = "yes" ]; then
  if [ $HAS_DISPLAY -eq 1 ] && [ "$GUI_MODE" = "yes" ]; then
    zenity --question --title="MAC Spoofing" --text="This will change all your MAC addresses.\n\nContinue?" --width=300
    if [ $? -ne 0 ]; then
      exit 0
    fi
  else
    echo "=== Kali Linux MAC Address Spoofing ==="
    read -p "This will change all your MAC addresses. Continue? (y/n): " confirm
    if [[ $confirm != [yY] && $confirm != [yY][eE][sS] ]]; then
      exit 0
    fi
  fi
  
  # Create a modified version of apply_changes for MAC-only
  (
    # Disable interfaces
    echo "Disabling network interfaces..."
    for interface in $(ip -o link show | awk -F': ' '{print $2}' | grep -v "lo"); do
      ip link set $interface down 2>/dev/null
    done
    
    # Change MACs
    echo "Changing MAC addresses..."
    for interface in $(ip -o link show | awk -F': ' '{print $2}' | grep -v "lo"); do
      NEW_MAC=$(random_mac)
      macchanger -m $NEW_MAC $interface 2>/dev/null
      echo "$interface: $NEW_MAC" >> /tmp/mac_changes
    done
    
    # Re-enable interfaces
    echo "Re-enabling network interfaces..."
    for interface in $(ip -o link show | awk -F': ' '{print $2}' | grep -v "lo"); do
      ip link set $interface up 2>/dev/null
    done
    
    # Show results
    echo "===== MAC SPOOFING COMPLETE ====="
    echo "MAC addresses:"
    cat /tmp/mac_changes
    echo "====================================="
  )
elif [ "$HOSTNAME_ONLY" = "yes" ]; then
  if [ $HAS_DISPLAY -eq 1 ] && [ "$GUI_MODE" = "yes" ]; then
    zenity --question --title="Hostname Spoofing" --text="This will change your hostname.\n\nContinue?" --width=300
    if [ $? -ne 0 ]; then
      exit 0
    fi
  else
    echo "=== Kali Linux Hostname Spoofing ==="
    read -p "This will change your hostname. Continue? (y/n): " confirm
    if [[ $confirm != [yY] && $confirm != [yY][eE][sS] ]]; then
      exit 0
    fi
  fi
  
  # Generate and apply new hostname
  NEW_HOSTNAME=$(random_hostname)
  echo "Setting hostname to $NEW_HOSTNAME"
  hostname $NEW_HOSTNAME
  echo $NEW_HOSTNAME > /etc/hostname
  sed -i "s/127.0.1.1.*/127.0.1.1\t$NEW_HOSTNAME/g" /etc/hosts
  
  echo "===== HOSTNAME SPOOFING COMPLETE ====="
  echo "New hostname: $NEW_HOSTNAME"
  echo "====================================="
else
  # Full system spoofing
  if [ $HAS_DISPLAY -eq 1 ] && [ "$GUI_MODE" = "yes" ]; then
    zenity --question --title="Hardware Spoofing" --text="This will spoof your hardware identifiers, MAC addresses, and system fingerprint.\n\nContinue?" --width=350
    if [ $? -ne 0 ]; then
      exit 0
    fi
    apply_changes
  else
    echo "=== Kali Linux Hardware Spoofing Tool ==="
    echo "This will spoof your hardware identifiers and network fingerprint."
    read -p "Continue? (y/n): " confirm
    if [[ $confirm == [yY] || $confirm == [yY][eE][sS] ]]; then
      apply_changes
    else
      echo "Operation cancelled."
    fi
  fi
fi

exit 0#!/bin/bash

# Hardware and System Spoofing Script for Debian System
# Works in both terminal and GUI environments

# Check if running as root
if [ "$EUID" -ne 0 ]; then
  echo "Please run as root"
  exit 1
fi

# Check if display is available for GUI elements
HAS_DISPLAY=0
if [ -n "$DISPLAY" ] && command -v zenity >/dev/null 2>&1; then
  # Test if we can actually use the display
  if zenity --version >/dev/null 2>&1; then
    HAS_DISPLAY=1
  fi
fi

# Function to generate random MAC address
random_mac() {
  printf '00:%02X:%02X:%02X:%02X:%02X\n' $((RANDOM%256)) $((RANDOM%256)) $((RANDOM%256)) $((RANDOM%256)) $((RANDOM%256))
}

# Function to generate a random hostname
random_hostname() {
  prefix=("WIN" "PC" "DESKTOP" "LAPTOP" "SYSTEM")
  echo "${prefix[$((RANDOM % 5))]}-$(cat /dev/urandom | tr -dc 'A-Z0-9' | fold -w 6 | head -n 1)"
}

# Function to generate Windows-like system info
gen_windows_info() {
  manufacturers=("Dell Inc." "HP" "Lenovo" "ASUS" "Acer" "Microsoft Corporation")
  products=("Latitude" "Inspiron" "ProBook" "ThinkPad" "Surface" "ROG" "Predator")
  versions=("A01" "1.0" "2.3.4" "3.1")
  
  MANUFACTURER=${manufacturers[$((RANDOM % 6))]}
  PRODUCT=${products[$((RANDOM % 7))]}
  VERSION=${versions[$((RANDOM % 4))]}
  SERIAL="$(cat /dev/urandom | tr -dc 'A-Z0-9' | fold -w 10 | head -n 1)"
  
  echo "$MANUFACTURER" > /tmp/manufacturer
  echo "$PRODUCT" > /tmp/product
  echo "$VERSION" > /tmp/version
  echo "$SERIAL" > /tmp/serial
}

# Function to display progress (CLI or GUI)
show_progress() {
  local message="$1"
  local percent="$2"
  
  if [ $HAS_DISPLAY -eq 1 ] && [ "$GUI_MODE" = "yes" ]; then
    # Update zenity progress if it's running
    echo "$percent"
    echo "# $message"
  else
    # CLI progress display
    printf "[%-20s] %s%%  %s\n" "$(printf '#%.0s' $(seq 1 $(($percent / 5))))" "$percent" "$message"
  fi
}

# Function to apply system changes
apply_changes() {
  # Setup for progress reporting
  if [ $HAS_DISPLAY -eq 1 ] && [ "$GUI_MODE" = "yes" ]; then
    # Start zenity progress bar
    exec 3> >(zenity --progress --title="Hardware Spoofing" --text="Starting hardware spoofing process..." --percentage=0 --auto-close --width=400)
  fi
  
  # Clear previous temp files
  rm -f /tmp/mac_changes /tmp/manufacturer /tmp/product /tmp/version /tmp/serial
  
  # 1. Disable network interfaces
  show_progress "Disabling network interfaces..." 10 >&3
  for interface in $(ip -o link show | awk -F': ' '{print $2}' | grep -v "lo"); do
    echo "Disabling $interface"
    ip link set $interface down 2>/dev/null
  done
  
  # 2. Change MAC addresses
  show_progress "Changing MAC addresses..." 20 >&3
  for interface in $(ip -o link show | awk -F': ' '{print $2}' | grep -v "lo"); do
    NEW_MAC=$(random_mac)
    echo "Setting $interface MAC to $NEW_MAC"
    macchanger -m $NEW_MAC $interface 2>/dev/null
    echo "$interface: $NEW_MAC" >> /tmp/mac_changes
  done
  
  # 3. Apply OS fingerprint changes
  show_progress "Applying OS fingerprint changes..." 40 >&3
  echo "Setting TTL to 128 (Windows-like)"
  sysctl -w net.ipv4.ip_default_ttl=128 >/dev/null 2>&1
  echo "Disabling TCP timestamps"
  sysctl -w net.ipv4.tcp_timestamps=0 >/dev/null 2>&1
  echo "Modifying TCP window scaling"
  sysctl -w net.ipv4.tcp_window_scaling=0 >/dev/null 2>&1
  
  # 4. Change system identifiers
  show_progress "Changing system identifiers..." 60 >&3
  gen_windows_info
  NEW_HOSTNAME=$(random_hostname)
  echo "Setting hostname to $NEW_HOSTNAME"
  hostname $NEW_HOSTNAME
  echo $NEW_HOSTNAME > /etc/hostname
  sed -i "s/127.0.1.1.*/127.0.1.1\t$NEW_HOSTNAME/g" /etc/hosts
  
  # 5. Re-enable network interfaces
  show_progress "Re-enabling network interfaces..." 80 >&3
  for interface in $(ip -o link show | awk -F': ' '{print $2}' | grep -v "lo"); do
    echo "Enabling $interface"
    ip link set $interface up 2>/dev/null
  done
  
  # 6. Final steps
  show_progress "Finalizing changes..." 90 >&3
  
  # 7. Complete
  show_progress "Hardware spoofing complete!" 100 >&3
  
  # Close zenity progress pipe if it was opened
  if [ $HAS_DISPLAY -eq 1 ] && [ "$GUI_MODE" = "yes" ]; then
    exec 3>&-
  fi
  
  # Show results
  if [ -f /tmp/mac_changes ]; then
    MACS=$(cat /tmp/mac_changes)
    MANUFACTURER=$(cat /tmp/manufacturer)
    PRODUCT=$(cat /tmp/product)
    
    if [ $HAS_DISPLAY -eq 1 ] && [ "$GUI_MODE" = "yes" ]; then
      notify-send -i security-high "Hardware Spoofing Complete" "New identity applied:\nHostname: $NEW_HOSTNAME\nSystem: $MANUFACTURER $PRODUCT\n$(cat /tmp/mac_changes | head -3)"
    else
      echo "===== HARDWARE SPOOFING COMPLETE ====="
      echo "New hostname: $NEW_HOSTNAME"
      echo "System: $MANUFACTURER $PRODUCT"
      echo "MAC addresses:"
      cat /tmp/mac_changes
      echo "====================================="
    fi
  fi
}

# Main execution
GUI_MODE="no"
if [ "$1" == "--gui" ]; then
  GUI_MODE="yes"
fi

if [ $HAS_DISPLAY -eq 1 ] && [ "$GUI_MODE" = "yes" ]; then
  # GUI mode
  zenity --question \
    --title="Hardware Spoofing" \
    --text="This will spoof your hardware identifiers, MAC addresses, and system fingerprint.\n\nContinue?" \
    --width=350
    
  if [ $? -eq 0 ]; then
    apply_changes
  fi
else
  # CLI mode
  echo "=== Kali Linux Hardware Spoofing Tool ==="
  echo "This will spoof your hardware identifiers and network fingerprint."
  read -p "Continue? (y/n): " confirm
  
  if [[ $confirm == [yY] || $confirm == [yY][eE][sS] ]]; then
    apply_changes
  else
    echo "Operation cancelled."
  fi
fi

exit 0#!/bin/bash

# Advanced Hardware and System Spoofing Script for Kali Linux
# Provides comprehensive spoofing of hardware identifiers, MAC addresses,
# and system fingerprints for enhanced anonymity during pentesting

# Check if running as root
if [ "$EUID" -ne 0 ]; then
  echo "Please run as root"
  zenity --error --title="Hardware Spoofer" --text="This script must be run as root (sudo)." --width=300
  exit 1
fi

# Function to generate random MAC address
random_mac() {
  printf '00:%02X:%02X:%02X:%02X:%02X\n' $((RANDOM%256)) $((RANDOM%256)) $((RANDOM%256)) $((RANDOM%256)) $((RANDOM%256))
}

# Function to generate a random hostname
random_hostname() {
  prefix=("WIN" "PC" "DESKTOP" "LAPTOP" "SYSTEM")
  echo "${prefix[$((RANDOM % 5))]}-$(cat /dev/urandom | tr -dc 'A-Z0-9' | fold -w 6 | head -n 1)"
}

# Function to generate Windows-like system info
gen_windows_info() {
  manufacturers=("Dell Inc." "HP" "Lenovo" "ASUS" "Acer" "Microsoft Corporation")
  products=("Latitude" "Inspiron" "ProBook" "ThinkPad" "Surface" "ROG" "Predator")
  versions=("A01" "1.0" "2.3.4" "3.1")
  
  MANUFACTURER=${manufacturers[$((RANDOM % 6))]}
  PRODUCT=${products[$((RANDOM % 7))]}
  VERSION=${versions[$((RANDOM % 4))]}
  SERIAL="$(cat /dev/urandom | tr -dc 'A-Z0-9' | fold -w 10 | head -n 1)"
  
  echo "$MANUFACTURER" > /tmp/manufacturer
  echo "$PRODUCT" > /tmp/product
  echo "$VERSION" > /tmp/version
  echo "$SERIAL" > /tmp/serial
}

# Function to apply system changes
apply_changes() {
  # Create progress dialog
  (
  echo "10"; echo "# Disabling network interfaces..."
  
  # Disable network interfaces
  for interface in $(ip -o link show | awk -F': ' '{print $2}' | grep -v "lo"); do
    ip link set $interface down 2>/dev/null
  done
  
  echo "20"; echo "# Changing MAC addresses..."
  
  # Change MAC addresses for all interfaces
  for interface in $(ip -o link show | awk -F': ' '{print $2}' | grep -v "lo"); do
    NEW_MAC=$(random_mac)
    macchanger -m $NEW_MAC $interface 2>/dev/null
    echo "$interface: $NEW_MAC" >> /tmp/mac_changes
  done
  
  echo "40"; echo "# Applying OS fingerprint changes..."
  
  # Modify kernel parameters for Windows-like behavior
  sysctl -w net.ipv4.ip_default_ttl=128 >/dev/null 2>&1
  sysctl -w net.ipv4.tcp_timestamps=0 >/dev/null 2>&1
  sysctl -w net.ipv4.tcp_window_scaling=0 >/dev/null 2>&1
  
  echo "60"; echo "# Changing system identifiers..."
  
  # Generate new system info
  gen_windows_info
  
  # Set new hostname
  NEW_HOSTNAME=$(random_hostname)
  hostname $NEW_HOSTNAME
  echo $NEW_HOSTNAME > /etc/hostname
  
  # Update hosts file
  sed -i "s/127.0.1.1.*/127.0.1.1\t$NEW_HOSTNAME/g" /etc/hosts
  
  echo "80"; echo "# Re-enabling network interfaces..."
  
  # Re-enable network interfaces
  for interface in $(ip -o link show | awk -F': ' '{print $2}' | grep -v "lo"); do
    ip link set $interface up 2>/dev/null
  done
  
  echo "90"; echo "# Finalizing changes..."
  
  # Apply browser user agent changes (if Firefox is running)
  pkill -f firefox
  
  echo "100"; echo "# Hardware spoofing complete!"
  ) | 
  zenity --progress \
    --title="Hardware Spoofing" \
    --text="Starting hardware spoofing process..." \
    --percentage=0 \
    --auto-close \
    --width=400
  
  # Show results in notification
  if [ -f /tmp/mac_changes ]; then
    MACS=$(cat /tmp/mac_changes)
    MANUFACTURER=$(cat /tmp/manufacturer)
    PRODUCT=$(cat /tmp/product)
    
    notify-send -i security-high "Hardware Spoofing Complete" "New identity applied:\nHostname: $NEW_HOSTNAME\nSystem: $MANUFACTURER $PRODUCT\n$(cat /tmp/mac_changes | head -3)"
    
    # Clean up temp files
    rm -f /tmp/mac_changes /tmp/manufacturer /tmp/product /tmp/version /tmp/serial
  fi
}

# Main execution
GUI_MODE="no"
MAC_ONLY="no"
HOSTNAME_ONLY="no"

# Process command-line arguments
while [ $# -gt 0 ]; do
  case "$1" in
    --gui)
      GUI_MODE="yes"
      ;;
    --mac-only)
      MAC_ONLY="yes"
      ;;
    --hostname-only)
      HOSTNAME_ONLY="yes"
      ;;
    *)
      echo "Unknown option: $1"
      echo "Usage: $0 [--gui] [--mac-only] [--hostname-only]"
      exit 1
      ;;
  esac
  shift
done

# Modify the apply_changes function to respect the mode
apply_changes_original=$apply_changes
apply_changes() {
  if [ "$MAC_ONLY" = "yes" ]; then
    # Only change MAC addresses
    # Setup for progress reporting
    if [ $HAS_DISPLAY -eq 1 ] && [ "$GUI_MODE" = "yes" ]; then
      exec 3> >(zenity --progress --title="MAC Address Spoofing" --text="Starting MAC spoofing..." --percentage=0 --auto-close --width=400)
    fi
    
    # Disable network interfaces
    show_progress "Disabling network interfaces..." 20 >&3
    for interface in $(ip -o link show | awk -F': ' '{print $2}' | grep -v "lo"); do
      ip link set $interface down 2>/dev/null
    done
    
    # Change MAC addresses
    show_progress "Changing MAC addresses..." 50 >&3
    for interface in $(ip -o link show | awk -F': ' '{print $2}' | grep -v "lo"); do
      NEW_MAC=$(random_mac)
      macchanger -m $NEW_MAC $interface 2>/dev/null
      echo "$interface: $NEW_MAC" >> /tmp/mac_changes
    done
    
    # Re-enable network interfaces
    show_progress "Re-enabling network interfaces..." 80 >&3
    for interface in $(ip -o link show | awk -F': ' '{print $2}' | grep -v "lo"); do
      ip link set $interface up 2>/dev/null
    done
    
    show_progress "MAC spoofing complete!" 100 >&3
    
    # Close zenity progress pipe if it was opened
    if [ $HAS_DISPLAY -eq 1 ] && [ "$GUI_MODE" = "yes" ]; then
      exec 3>&-
    fi
    
    # Show results
    if [ -f /tmp/mac_changes ]; then
      if [ $HAS_DISPLAY -eq 1 ] && [ "$GUI_MODE" = "yes" ]; then
        notify-send -i security-high "MAC Spoofing Complete" "$(cat /tmp/mac_changes | head -3)"
      else
        echo "===== MAC SPOOFING COMPLETE ====="
        echo "MAC addresses:"
        cat /tmp/mac_changes
        echo "====================================="
      fi
    fi
  elif [ "$HOSTNAME_ONLY" = "yes" ]; then
    # Only change hostname
    # Setup for progress reporting
    if [ $HAS_DISPLAY -eq 1 ] && [ "$GUI_MODE" = "yes" ]; then
      exec 3> >(zenity --progress --title="Hostname Spoofing" --text="Starting hostname spoofing..." --percentage=0 --auto-close --width=400)
    fi
    
    # Generate new hostname
    show_progress "Generating new hostname..." 50 >&3
    NEW_HOSTNAME=$(random_hostname)
    hostname $NEW_HOSTNAME
    echo $NEW_HOSTNAME > /etc/hostname
    sed -i "s/127.0.1.1.*/127.0.1.1\t$NEW_HOSTNAME/g" /etc/hosts
    
    show_progress "Hostname spoofing complete!" 100 >&3
    
    # Close zenity progress pipe if it was opened
    if [ $HAS_DISPLAY -eq 1 ] && [ "$GUI_MODE" = "yes" ]; then
      exec 3>&-
    fi
    
    # Show results
    if [ $HAS_DISPLAY -eq 1 ] && [ "$GUI_MODE" = "yes" ]; then
      notify-send -i security-high "Hostname Spoofing Complete" "New hostname: $NEW_HOSTNAME"
    else
      echo "===== HOSTNAME SPOOFING COMPLETE ====="
      echo "New hostname: $NEW_HOSTNAME"
      echo "====================================="
    fi
  else
    # Full system spoofing
    $apply_changes_original
  fi
}

    
  if [ $? -eq 0 ]; then
    apply_changes
  fi
else
  # CLI mode
  echo "=== Kali Linux Hardware Spoofing Tool ==="
  echo "This will spoof your hardware identifiers and network fingerprint."
  read -p "Continue? (y/n): " confirm
  
  if [[ $confirm == [yY] || $confirm == [yY][eE][sS] ]]; then
    apply_changes
    echo "Hardware spoofing complete!"
  else
    echo "Operation cancelled."
  fi
fi

exit 0
