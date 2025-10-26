#!/bin/bash

# --- Color Codes ---
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

LOG_FILE="/var/log/pihole-install-techposts.log"

# --- Logging Function ---
log() {
    echo -e "$1" | tee -a "$LOG_FILE"
}

# --- Check Root ---
if [ "$EUID" -ne 0 ]; then
    log "${RED}Error:${NC} This script must be run as root."
    log "Use: sudo $0"
    exit 1
fi

clear
log "${GREEN}=======================================${NC}"
log "${GREEN}  TechPosts Pi-hole Setup Script      ${NC}"
log "${GREEN}=======================================${NC}"
log ""
log "${YELLOW}Welcome!${NC} This script will prepare your system and launch the official Pi-hole installer."
log ""
log "${RED}NOTE:${NC} Optimized for Pi-hole v6+ (FTL web server)."

# --- Confirmation Prompt ---
read -p "Do you wish to continue? (y/n): " confirm
if [[ "$confirm" != "y" && "$confirm" != "Y" ]]; then
    log "${RED}Installation aborted by user.${NC}"
    exit 0
fi

# --- Step 1: System Update ---
log "${GREEN}--- Updating System Packages ---${NC}"
apt update && apt upgrade -y
log "${GREEN}System update complete.${NC}"

# --- Step 2: Static IP Warning ---
log "${GREEN}--- Static IP Check ---${NC}"
log "${YELLOW}CRITICAL:${NC} Pi-hole requires a static IP."
log "Options:"
log " 1. DHCP reservation on router (recommended)"
log " 2. Manual static IP on device"
log ""
read -p "Are you ready to configure static IP if needed? (y/n): " ip_ready
if [[ "$ip_ready" != "y" && "$ip_ready" != "Y" ]]; then
    log "${RED}Installation aborted. Please configure network first.${NC}"
    exit 1
fi

# --- Step 3: Detect Port 80 Conflict ---
log "${GREEN}--- Checking Port 80 ---${NC}"
if ss -tulpn | grep -q ":80 "; then
    log "${YELLOW}Port 80 is in use. A web server (Apache/Nginx/etc.) detected.${NC}"
    read -p "Do you want to move Pi-hole admin GUI to port 8080? (y/n): " move_port
    if [[ "$move_port" == "y" || "$move_port" == "Y" ]]; then
        PORT_CHANGE="yes"
    else
        PORT_CHANGE="no"
        log "${YELLOW}Warning: Pi-hole admin may not be accessible until port is free or changed manually.${NC}"
    fi
else
    PORT_CHANGE="no"
fi

# --- Step 4: Run Pi-hole Installer ---
log "${GREEN}--- Running Pi-hole Installer ---${NC}"
log "Follow on-screen prompts."
curl -sSL https://install.pi-hole.net | bash

# --- Step 5: Handle Port Change if Accepted ---
if [[ "$PORT_CHANGE" == "yes" ]]; then
    log "${GREEN}--- Changing Pi-hole Web GUI Port to 8080 ---${NC}"
    TOML_FILE="/etc/pihole/pihole.toml"
    if [ -f "$TOML_FILE" ]; then
        sed -i 's/port = .*/port = "8080o,443os,[::]:8080o,[::]:443os"/' "$TOML_FILE"
        systemctl restart pihole-FTL
        log "${GREEN}Port changed successfully. Admin GUI now on http://<IP>:8080/admin${NC}"
    else
        log "${RED}Error:${NC} pihole.toml not found. Manual port change required."
    fi
fi

# --- Step 6: Set/Reset Admin Password ---
log "${GREEN}--- Setting Admin Web Password ---${NC}"
pihole -a -p

# --- Step 7: Final Instructions ---
log ""
log "${GREEN}=======================================${NC}"
log "${GREEN}  Pi-hole Installation Finished!       ${NC}"
log "${GREEN}=======================================${NC}"
log ""
log "Access your admin interface:"
if [[ "$PORT_CHANGE" == "yes" ]]; then
    log "  http://<Your-Pi-IP>:8080/admin"
else
    log "  http://pi.hole/admin or http://<Your-Pi-IP>/admin"
fi
log ""
log "${YELLOW}If admin page is inaccessible:${NC}"
log "  1. Check for web server on port 80"
log "  2. Edit /etc/pihole/pihole.toml and change port to 8080"
log "  3. Restart Pi-hole FTL: sudo systemctl restart pihole-FTL"
log ""
log "${GREEN}To enable network-wide blocking:${NC}"
log "  1. Log into router admin"
log "  2. Set Primary DNS to Pi-hole's static IP"
log "  3. Save & reboot router"
log ""
log "${GREEN}✅ Setup Complete!${NC} Your network is now protected."
log ""
