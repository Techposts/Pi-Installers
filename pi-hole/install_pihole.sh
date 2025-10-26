#!/bin/bash

# --- Color Codes for better readability ---
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

# --- Function to check if running as root ---
check_root() {
  if [ "$EUID" -ne 0 ]; then
    echo -e "${RED}Error:${NC} This script must be run with root privileges."
    echo -e "Please run it with: ${GREEN}sudo ./install_pihole.sh${NC}"
    exit 1
  fi
}

# --- Welcome and Warning ---
clear
echo -e "${GREEN}=======================================${NC}"
echo -e "${GREEN}  TechPosts Pi-hole Setup Script      ${NC}"
echo -e "${GREEN}=======================================${NC}"
echo ""
echo -e "${YELLOW}Welcome!${NC} This script will prepare your system and launch"
echo "the official Pi-hole installer."
echo ""
echo -e "${RED}--- IMPORTANT HARDWARE NOTE ---${NC}"
echo -e "You are installing on a ${YELLOW}Raspberry Pi Zero${NC}."
echo "For best performance, it is highly recommended that you use:"
echo -e "1. ${GREEN}Raspberry Pi OS Lite${NC} (a headless, non-desktop version)."
echo "2. A high-quality SD card and power supply."
echo ""

# --- Confirmation Prompt ---
read -p "Do you wish to continue with the installation? (y/n): " confirm
if [[ "$confirm" != "y" && "$confirm" != "Y" ]]; then
    echo -e "${RED}Installation aborted by user.${NC}"
    exit 0
fi

# --- Check for Root ---
# We check for root *after* the intro so the user sees the welcome message.
check_root

# --- Step 1: System Update ---
echo ""
echo -e "${GREEN}--- Step 1: Updating System Packages ---${NC}"
echo "This will update your package lists and upgrade existing software."
echo "This may take several minutes on a Pi Zero..."
echo ""
apt update
apt upgrade -y
echo ""
echo -e "${GREEN}System update complete.${NC}"
echo ""

# --- Step 2: Static IP Address (Interactive Check) ---
echo -e "${GREEN}--- Step 2: Static IP Address Check ---${NC}"
echo -e "${YELLOW}CRITICAL:${NC} Pi-hole ${RED}REQUIRES${NC} a static IP address to work."
echo ""
echo "You have two main options:"
echo -e "  1. ${GREEN}DHCP Reservation (Recommended):${NC} Log in to your router and 'reserve'"
echo "     an IP address for your Pi's MAC address. This is the cleanest method."
echo -e "  2. ${GREEN}Manual IP (On-Device):${NC} Set the static IP directly on the Pi."
echo ""
echo "The official Pi-hole installer (which runs next) will ask you about this."
echo -e "If you choose option 2, you ${YELLOW}must${NC} know the following:"
echo "  - The IP you want to assign to the Pi (e.g., 192.168.1.10)"
echo "  - Your Router's IP address (Gateway) (e.g., 192.168.1.1)"
echo ""

read -p "Are you prepared to configure the static IP? (y/n): " ip_ready
if [[ "$ip_ready" != "y" && "$ip_ready" != "Y" ]]; then
    echo -e "${RED}Installation aborted.${NC} Please configure your network settings first."
    exit 1
fi

# --- Step 3: Run the Official Pi-hole Installer ---
echo ""
echo -e "${GREEN}--- Step 3: Launching Official Pi-hole Installer ---${NC}"
echo "The script will now download and execute the official installer."
echo ""
echo -e "${YELLOW}This next part is INTERACTIVE.${NC}"
echo "Follow the on-screen prompts to select your DNS provider, blocklists,"
echo "and confirm your static IP settings."
echo ""
echo "Starting in 5 seconds..."
sleep 5

# The official command to run the installer
curl -sSL https://install.pi-hole.net | bash

# --- Step 4: Post-Installation Summary ---
echo ""
echo -e "${GREEN}=======================================${NC}"
echo -e "${GREEN}  Pi-hole Installation Finished!       ${NC}"
echo -e "${GREEN}=======================================${NC}"
echo ""
echo "The installer should have shown you a final screen with:"
echo "  - The web interface URL (e.g., http://pi.hole/admin or http://[IP_ADDRESS]/admin)"
echo -e "  - Your web interface ${YELLOW}password${NC}"
echo ""
echo -e "${YELLOW}IMPORTANT:${NC} If you missed the password or want to change it, run:"
echo -e "  ${GREEN}pihole -a -p${NC}"
echo ""
echo "--- YOUR FINAL, CRITICAL STEP ---"
echo "To make your whole network use Pi-hole, you must:"
echo -e "1. Log in to your ${YELLOW}router's${NC} admin page."
echo -e "2. Find the ${GREEN}DHCP/DNS${NC} settings."
echo -e "3. Change the ${GREEN}Primary DNS Server${NC} to your Pi-hole's static IP address."
echo "4. Save and restart your router."
echo ""
echo -e "${GREEN}Setup complete!${NC} Your network is now protected."
