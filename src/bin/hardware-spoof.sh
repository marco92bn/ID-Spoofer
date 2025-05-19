#!/bin/bash

# Kali Identity Spoofer
# Version 1.0.0
# A tool for spoofing hardware and network identifiers in Kali Linux

# Check if running as root
if [ "$(id -u)" -ne "0" ]; then
  echo "Please run as root"
  exit 1
fi

# Check for required commands
REQUIRED_CMDS=("macchanger" "ip" "awk" "tr" "fold" "hostname" "sed")
for cmd in "${REQUIRED_CMDS[@]}"; do
  if ! command -v "$cmd" >/dev/null 2>&1; then
    echo "Error: Required command '$cmd' not found. Please install it."
    exit 1
  fi
done

# Optional commands for GUI/notifications
HAS_ZENITY=0
HAS_NOTIFY=0
if [ -n "$DISPLAY" ]; then
  if command -v zenity >/dev/null 2>&1; then
    HAS_ZENITY=1
  else
    echo "Warning: 'zenity' not found. GUI dialogs will not be available."
  fi
  
  if command -v notify-send >/dev/null 2>&1; then
    HAS_NOTIFY=1
  else
    echo "Warning: 'notify-send' not found. Desktop notifications will not be available."
  fi
fi

# Set global variables
GUI_MODE="no"
MAC_ONLY="no"
HOSTNAME_ONLY="no"
QUIET_MODE="no"
LOG_FILE=""

# Function to show script banner
show_banner() {
  if [ "$QUIET_MODE" = "yes" ]; then
    return
  fi
  
  echo "╔════════════════════════════════════════════════╗"
  echo "║       KALI LINUX IDENTITY SPOOFER v1.0.0       ║"
  echo "╚════════════════════════════════════════════════╝"
  echo
}

# Function to generate random MAC address
random_mac() {
  printf '00:%02X:%02X:%02X:%02X:%02X\n' $((RANDOM%256)) $((RANDOM%256)) $((RANDOM%256)) $((RANDOM%256)) $((RANDOM%256))
}

# Function to generate a random hostname
random_hostname() {
  prefix=("WIN" "PC" "DESKTOP" "LAPTOP" "SYSTEM")
  echo "${prefix[$((RANDOM % 5))]}-$(tr -dc 'A-Z0-9' < /dev/urandom | fold -w 6 | head -n 1)"
}

# Function to generate Windows-like system info
gen_windows_info() {
  manufacturers=("Dell Inc." "HP" "Lenovo" "ASUS" "Acer" "Microsoft Corporation")
  products=("Latitude" "Inspiron" "ProBook" "ThinkPad" "Surface" "ROG" "Predator")
  versions=("A01" "1.0" "2.3.4" "3.1")
  
  MANUFACTURER=${manufacturers[$((RANDOM % 6))]}
  PRODUCT=${products[$((RANDOM % 7))]}
  VERSION=${versions[$((RANDOM % 4))]}
  SERIAL="$(tr -dc 'A-Z0-9' < /dev/urandom | fold -w 10 | head -n 1)"
  
  echo "$MANUFACTURER" > /tmp/manufacturer
  echo "$PRODUCT" > /tmp/product
  echo "$VERSION" > /tmp/version
  echo "$SERIAL" > /tmp/serial
}

# Function to display progress 
show_progress() {
  local message="$1"
  local percent="$2"
  
  # Log the progress message if a log file is specified
  if [ -n "$LOG_FILE" ]; then
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] [$percent%] $message" >> "$LOG_FILE"
  fi
  
  # Skip display if in quiet mode
  if [ "$QUIET_MODE" = "yes" ]; then
    return
  fi
  
  # Display using zenity if available and in GUI mode
  if [ "$HAS_ZENITY" -eq 1 ] && [ "$GUI_MODE" = "yes" ] && [ -n "$PROGRESS_FILE" ]; then
    echo "$percent" > "$PROGRESS_FILE"
    echo "# $message" >> "$PROGRESS_FILE"
  else
    # CLI progress display
    printf "%-50s [%3d%%]\n" "$message" "$percent"
  fi
}

# Function to show notification
show_notification() {
  local title="$1"
  local message="$2"
  
  if [ "$QUIET_MODE" = "yes" ]; then
    return
  fi
  
  if [ "$HAS_NOTIFY" -eq 1 ] && [ "$GUI_MODE" = "yes" ]; then
    notify-send -i security-high "$title" "$message"
  else
    echo "→ $title: $message"
  fi
}

# Function to confirm action
confirm_action() {
  local title="$1"
  local message="$2"
  
  if [ "$QUIET_MODE" = "yes" ]; then
    return 0
  fi
  
  if [ "$HAS_ZENITY" -eq 1 ] && [ "$GUI_MODE" = "yes" ]; then
    zenity --question --title="$title" --text="$message\n\nContinue?" --width=350
    return $?
  else
    echo "=== $title ==="
    echo "$message"
    read -r "Continue? (y/n): " confirm
    if [[ $confirm == [yY] || $confirm == [yY][eE][sS] ]]; then
      return 0
    else
      return 1
    fi
  fi
}

# Function to spoof MAC addresses
spoof_mac_addresses() {
  show_progress "Disabling network interfaces..." 10
  
  for interface in $(ip -o link show | awk -F': ' '{print $2}' | grep -v "lo"); do
    ip link set "$interface" down 2>/dev/null
  done
  
  show_progress "Changing MAC addresses..." 40
  
  rm -f /tmp/mac_changes
  for interface in $(ip -o link show | awk -F': ' '{print $2}' | grep -v "lo"); do
    NEW_MAC=$(random_mac)
    macchanger -m "$NEW_MAC" "$interface" 2>/dev/null
    echo "$interface: $NEW_MAC" >> /tmp/mac_changes
  done
  
  show_progress "Re-enabling network interfaces..." 80
  
  for interface in $(ip -o link show | awk -F': ' '{print $2}' | grep -v "lo"); do
    ip link set "$interface" up 2>/dev/null
  done
  
  show_progress "MAC address spoofing complete" 100
  
  if [ -f /tmp/mac_changes ]; then
    MAC_INFO=$(cat /tmp/mac_changes)
    show_notification "MAC Addresses Changed" "$MAC_INFO"
  fi
}

# Function to spoof hostname
spoof_hostname() {
  show_progress "Generating new hostname..." 30
  
  NEW_HOSTNAME=$(random_hostname)
  
  show_progress "Setting hostname..." 70
  
  hostname "$NEW_HOSTNAME"
  echo "$NEW_HOSTNAME" > /etc/hostname
  sed -i "s/127.0.1.1.*/127.0.1.1\t$NEW_HOSTNAME/g" /etc/hosts
  
  show_progress "Hostname spoofing complete" 100
  
  show_notification "Hostname Changed" "New hostname: $NEW_HOSTNAME"
}

# Function to spoof OS fingerprint
spoof_os_fingerprint() {
  show_progress "Modifying TCP/IP stack parameters..." 50
  
  sysctl -w net.ipv4.ip_default_ttl=128 >/dev/null 2>&1
  sysctl -w net.ipv4.tcp_timestamps=0 >/dev/null 2>&1
  sysctl -w net.ipv4.tcp_window_scaling=0 >/dev/null 2>&1
  
  show_progress "OS fingerprint spoofing complete" 100
  
  show_notification "OS Fingerprint Modified" "TCP/IP stack now appears as Windows"
}

# Function to spoof system info
spoof_system_info() {
  show_progress "Generating system profile..." 50
  
  gen_windows_info
  
  MANUFACTURER=$(cat /tmp/manufacturer 2>/dev/null || echo "Unknown")
  PRODUCT=$(cat /tmp/product 2>/dev/null || echo "System")
  
  show_progress "System info spoofing complete" 100
  
  show_notification "System Profile Changed" "System: $MANUFACTURER $PRODUCT"
}

# Function to display help
show_help() {
  echo "Kali Identity Spoofer v1.0.0"
  echo "Usage: $(basename "$0") [OPTIONS]"
  echo
  echo "Options:"
  echo "  --gui              Use GUI elements if available"
  echo "  --mac-only         Only spoof MAC addresses"
  echo "  --hostname-only    Only spoof hostname"
  echo "  --quiet            No interactive prompts or output"
  echo "  --log FILE         Log actions to specified file"
  echo "  --help             Show this help message"
  echo
  echo "Examples:"
  echo "  $(basename "$0")              # Run full spoofing in terminal mode"
  echo "  $(basename "$0") --gui        # Run with GUI if available"
  echo "  $(basename "$0") --mac-only   # Only change MAC addresses"
  echo "  $(basename "$0") --quiet      # Run without user interaction or output"
  echo
}

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
    --quiet)
      QUIET_MODE="yes"
      ;;
    --log)
      shift
      LOG_FILE="$1"
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

# Setup progress tracking for GUI mode
PROGRESS_FILE=""
PROGRESS_PID=""
if [ "$HAS_ZENITY" -eq 1 ] && [ "$GUI_MODE" = "yes" ] && [ "$QUIET_MODE" = "no" ]; then
  PROGRESS_FILE=$(mktemp)
  (
    tail -f "$PROGRESS_FILE" | zenity --progress \
      --title="Kali Identity Spoofer" \
      --text="Initializing..." \
      --percentage=0 \
      --auto-close \
      --width=400
  ) &
  PROGRESS_PID=$!
  
  # Clean up progress file on exit
  trap 'kill $PROGRESS_PID 2>/dev/null; rm -f "$PROGRESS_FILE"' EXIT
fi

# Main execution logic
show_banner

if [ "$MAC_ONLY" = "yes" ]; then
  if confirm_action "MAC Address Spoofing" "This will change all your network interface MAC addresses."; then
    spoof_mac_addresses
  else
    echo "MAC address spoofing cancelled."
    exit 0
  fi
elif [ "$HOSTNAME_ONLY" = "yes" ]; then
  if confirm_action "Hostname Spoofing" "This will change your system's hostname."; then
    spoof_hostname
  else
    echo "Hostname spoofing cancelled."
    exit 0
  fi
else
  if confirm_action "Full Identity Spoofing" "This will change your MAC addresses, hostname, OS fingerprint, and system profile."; then
    show_progress "Starting full identity spoofing..." 0
    
    spoof_mac_addresses
    spoof_hostname
    spoof_os_fingerprint
    spoof_system_info
    
    # Final message
    MANUFACTURER=$(cat /tmp/manufacturer 2>/dev/null || echo "Unknown")
    PRODUCT=$(cat /tmp/product 2>/dev/null || echo "System")
    NEW_HOSTNAME=$(hostname)
    
    echo
    echo "===== IDENTITY SPOOFING COMPLETE ====="
    echo "New hostname: $NEW_HOSTNAME"
    echo "System: $MANUFACTURER $PRODUCT"
    echo "MAC addresses:"
    if [ -f /tmp/mac_changes ]; then
      cat /tmp/mac_changes
    fi
    echo "====================================="
  else
    echo "Identity spoofing cancelled."
    exit 0
  fi
fi

# Clean up temporary files (except in GUI mode, where trap handles it)
if [ "$GUI_MODE" = "no" ] || [ -z "$PROGRESS_FILE" ]; then
  rm -f "$PROGRESS_FILE"
fi

exit 0