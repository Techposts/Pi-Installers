#!/bin/bash

# --- Color Codes ---
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
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
log ""
log "${GREEN}--- Step 1: Updating System Packages ---${NC}"
apt update && apt upgrade -y
if [ $? -eq 0 ]; then
    log "${GREEN}✓ System update complete.${NC}"
else
    log "${RED}✗ System update failed. Check your internet connection.${NC}"
    exit 1
fi

# --- Step 2: System Requirements Check ---
log ""
log "${GREEN}--- Step 2: Checking System Requirements ---${NC}"

# Check disk space (Pi-hole needs ~50MB minimum, recommend 100MB)
AVAILABLE_SPACE=$(df / | tail -1 | awk '{print $4}')
SPACE_MB=$((AVAILABLE_SPACE / 1024))
log "Available disk space: ${BLUE}${SPACE_MB}MB${NC}"

if [ "$AVAILABLE_SPACE" -lt 51200 ]; then
    log "${RED}WARNING:${NC} Low disk space (less than 50MB). Pi-hole may not install properly."
    read -p "Continue anyway? (y/n): " continue_low_space
    if [[ "$continue_low_space" != "y" && "$continue_low_space" != "Y" ]]; then
        exit 1
    fi
fi

# Check for curl
if ! command -v curl &> /dev/null; then
    log "${YELLOW}curl not found. Installing...${NC}"
    apt install -y curl
fi

# Check for dig (dnsutils) for testing
if ! command -v dig &> /dev/null; then
    log "${YELLOW}dig not found. Installing dnsutils for testing...${NC}"
    apt install -y dnsutils
fi

log "${GREEN}✓ System requirements check passed.${NC}"

# --- Step 3: Network Interface Detection & Selection ---
log ""
log "${GREEN}--- Step 3: Network Interface Detection & Selection ---${NC}"

# Get all IPv4 interfaces with their IPs (exclude loopback)
INTERFACE_DATA=$(ip -4 addr show | awk '
/^[0-9]+: / {
    iface = $2
    gsub(/:/, "", iface)
    if (iface != "lo") current_iface = iface
}
/inet / {
    if (current_iface != "" && current_iface != "lo") {
        ip = $2
        gsub(/\/.*/, "", ip)
        print current_iface " " ip
        current_iface = ""
    }
}
')

INTERFACE_COUNT=$(echo "$INTERFACE_DATA" | grep -v "^$" | wc -l)

if [ "$INTERFACE_COUNT" -eq 0 ]; then
    log "${RED}✗ No network interfaces with IP addresses found!${NC}"
    log "Please ensure your network is connected and try again."
    exit 1
fi

log "Network interfaces found: ${BLUE}$INTERFACE_COUNT${NC}"
log ""

# Display interfaces with their IPs and types
COUNTER=1
declare -A IFACE_MAP
while IFS= read -r line; do
    [ -z "$line" ] && continue
    
    IFACE=$(echo "$line" | awk '{print $1}')
    IP=$(echo "$line" | awk '{print $2}')
    
    # Identify interface type
    if [[ "$IFACE" == eth* ]] || [[ "$IFACE" == enp* ]]; then
        TYPE="${GREEN}(Ethernet/USB LAN)${NC}"
    elif [[ "$IFACE" == wlan* ]]; then
        TYPE="${YELLOW}(WiFi)${NC}"
    else
        TYPE=""
    fi
    
    log "${COUNTER}. ${BLUE}${IFACE}${NC} ${TYPE}: ${GREEN}${IP}${NC}"
    IFACE_MAP[$COUNTER]="$IFACE $IP"
    COUNTER=$((COUNTER + 1))
done <<< "$INTERFACE_DATA"

# Let user select interface
log ""
if [ "$INTERFACE_COUNT" -eq 1 ]; then
    # Only one interface, use it automatically
    CHOSEN_IFACE=$(echo "$INTERFACE_DATA" | awk '{print $1}')
    CHOSEN_IP=$(echo "$INTERFACE_DATA" | awk '{print $2}')
    log "${GREEN}✓ Only one interface detected.${NC}"
    log "${GREEN}Using: ${BLUE}$CHOSEN_IFACE${NC} with IP: ${BLUE}$CHOSEN_IP${NC}"
    WIFI_DISABLED=false
else
    # Multiple interfaces - ask user to choose
    log "${YELLOW}Multiple interfaces detected!${NC}"
    log ""
    log "Which interface do you want to use for Pi-hole?"
    log "${GREEN}Tip: Choose your primary/stable connection (usually Ethernet/USB LAN)${NC}"
    log ""
    
    # Get user selection
    while true; do
        read -p "Enter number (1-$INTERFACE_COUNT): " selection
        
        if [[ "$selection" =~ ^[0-9]+$ ]] && [ "$selection" -ge 1 ] && [ "$selection" -lt "$COUNTER" ]; then
            CHOSEN_IFACE=$(echo "${IFACE_MAP[$selection]}" | awk '{print $1}')
            CHOSEN_IP=$(echo "${IFACE_MAP[$selection]}" | awk '{print $2}')
            break
        else
            log "${RED}Invalid selection. Please enter a number between 1 and $INTERFACE_COUNT${NC}"
        fi
    done
    
    log ""
    log "${GREEN}✓ Selected: ${BLUE}$CHOSEN_IFACE${NC} with IP: ${BLUE}$CHOSEN_IP${NC}"
    
    # Offer to disable WiFi if ethernet was chosen
    if [[ "$CHOSEN_IFACE" != wlan* ]]; then
        WIFI_IFACE=$(echo "$INTERFACE_DATA" | grep "^wlan" | awk '{print $1}' | head -n1)
        if [ ! -z "$WIFI_IFACE" ]; then
            log ""
            log "${YELLOW}WiFi interface detected: $WIFI_IFACE${NC}"
            log "Would you like to temporarily disable WiFi during installation?"
            log "This can prevent confusion in the Pi-hole installer."
            log ""
            read -p "Disable WiFi? (y/n): " disable_wifi
            
            if [[ "$disable_wifi" == "y" || "$disable_wifi" == "Y" ]]; then
                log "${YELLOW}Disabling WiFi...${NC}"
                rfkill block wifi 2>/dev/null
                systemctl stop wpa_supplicant 2>/dev/null
                log "${GREEN}✓ WiFi disabled temporarily.${NC}"
                WIFI_DISABLED=true
            else
                log "${GREEN}✓ WiFi will remain active.${NC}"
                WIFI_DISABLED=false
            fi
        else
            WIFI_DISABLED=false
        fi
    else
        WIFI_DISABLED=false
    fi
fi

# --- Step 4: Static IP Check & Warning ---
log ""
log "${GREEN}--- Step 4: Static IP Verification ---${NC}"

log "Selected Interface: ${BLUE}$CHOSEN_IFACE${NC}"
log "IP Address: ${BLUE}$CHOSEN_IP${NC}"
log ""

# Check if using DHCP
USING_DHCP=false
if grep -q "dhcp" /etc/dhcpcd.conf 2>/dev/null; then
    USING_DHCP=true
elif grep -q "dhcp" /etc/network/interfaces 2>/dev/null; then
    USING_DHCP=true
elif nmcli con show 2>/dev/null | grep -q "dhcp"; then
    USING_DHCP=true
fi

if [ "$USING_DHCP" = true ]; then
    log "${RED}⚠ WARNING: System appears to be using DHCP (dynamic IP)${NC}"
    log ""
    log "${YELLOW}Pi-hole REQUIRES a static IP to function properly!${NC}"
    log "Without a static IP, your Pi-hole will stop working when the IP changes."
    log ""
    log "═══════════════════════════════════════════════════════════"
    log "Your Options for Static IP:"
    log "═══════════════════════════════════════════════════════════"
    log ""
    log "${GREEN}Option 1: DHCP Reservation (RECOMMENDED)${NC}"
    log "  ${GREEN}•${NC} Log into your router's admin interface"
    log "  ${GREEN}•${NC} Find 'DHCP Reservation' or 'Static DHCP' settings"
    log "  ${GREEN}•${NC} Reserve IP ${BLUE}$CHOSEN_IP${NC} for ${BLUE}$CHOSEN_IFACE${NC}"
    
    # Get MAC address for the chosen interface
    MAC_ADDR=$(ip link show "$CHOSEN_IFACE" | grep "link/ether" | awk '{print $2}')
    if [ ! -z "$MAC_ADDR" ]; then
        log "  ${GREEN}•${NC} MAC Address: ${BLUE}$MAC_ADDR${NC}"
    fi
    
    log "  ${GREEN}•${NC} Easiest and most reliable method"
    log ""
    log "${BLUE}Option 2: Manual Static IP on Pi${NC}"
    log "  ${BLUE}•${NC} Edit /etc/dhcpcd.conf"
    log "  ${BLUE}•${NC} Add static IP configuration for ${BLUE}$CHOSEN_IFACE${NC}"
    log "  ${BLUE}•${NC} More complex, but works without router access"
    log "  ${BLUE}•${NC} Guide: https://www.raspberrypi.com/documentation/computers/configuration.html"
    log ""
    log "═══════════════════════════════════════════════════════════"
else
    log "${GREEN}✓ Static IP appears to be configured.${NC}"
fi

log ""
read -p "Have you configured a static IP or DHCP reservation? (y/n): " ip_configured
if [[ "$ip_configured" != "y" && "$ip_configured" != "Y" ]]; then
    log "${RED}Installation aborted.${NC}"
    log "Please configure static IP first, then re-run this script."
    exit 1
fi

log "${GREEN}✓ Static IP confirmed by user.${NC}"

# --- Step 5: Port 80 & Web Server Check ---
log ""
log "${GREEN}--- Step 5: Checking Port 80 & Web Servers ---${NC}"

APACHE_RUNNING=false
NGINX_RUNNING=false
PORT_CHANGE="no"

# Check if Apache is running
if systemctl is-active --quiet apache2; then
    log "${YELLOW}⚠ Apache web server detected and running${NC}"
    APACHE_RUNNING=true
fi

# Check if Nginx is running
if systemctl is-active --quiet nginx; then
    log "${YELLOW}⚠ Nginx web server detected and running${NC}"
    NGINX_RUNNING=true
fi

# Check port 80
if ss -tulpn | grep -q ":80 "; then
    PORT_80_PROCESS=$(ss -tulpn | grep ":80 " | awk '{print $7}' | cut -d'"' -f2 | head -n1)
    log ""
    log "${RED}⚠ Port 80 is currently in use by: ${BLUE}$PORT_80_PROCESS${NC}"
    log ""
    log "Pi-hole's admin interface normally runs on port 80."
    log ""
    log "═══════════════════════════════════════════════════════════"
    log "Your Options:"
    log "═══════════════════════════════════════════════════════════"
    log ""
    log "${GREEN}Option 1: Move Pi-hole admin to port 8080 (RECOMMENDED)${NC}"
    log "  ${GREEN}•${NC} Pi-hole admin will be on http://$CHOSEN_IP:8080/admin"
    log "  ${GREEN}•${NC} Your existing web server keeps port 80"
    log "  ${GREEN}•${NC} Script will handle this automatically"
    log ""
    log "${BLUE}Option 2: Stop the conflicting service manually${NC}"
    log "  ${BLUE}•${NC} Stop/disable $PORT_80_PROCESS after installation"
    log "  ${BLUE}•${NC} Pi-hole will use port 80"
    log ""
    log "═══════════════════════════════════════════════════════════"
    log ""
    read -p "Move Pi-hole admin GUI to port 8080? (y/n): " move_port
    
    if [[ "$move_port" == "y" || "$move_port" == "Y" ]]; then
        PORT_CHANGE="yes"
        log "${GREEN}✓ Will configure Pi-hole on port 8080${NC}"
    else
        PORT_CHANGE="no"
        log "${YELLOW}⚠ Port conflict remains. You may need to manually configure later.${NC}"
    fi
else
    log "${GREEN}✓ Port 80 is available${NC}"
fi

# --- Step 6: Final Pre-Install Summary ---
log ""
log "${GREEN}═══════════════════════════════════════════════════════════${NC}"
log "${GREEN}Pre-Installation Summary${NC}"
log "${GREEN}═══════════════════════════════════════════════════════════${NC}"
log "Interface: ${BLUE}$CHOSEN_IFACE${NC}"
log "IP Address: ${BLUE}$CHOSEN_IP${NC}"
log "Total Interfaces: ${BLUE}$INTERFACE_COUNT${NC}"
log "Port 80 Status: ${BLUE}$([ -z "$(ss -tulpn | grep ':80 ')" ] && echo 'Available' || echo 'In use (will use 8080)')${NC}"
log "Static IP: ${BLUE}Confirmed${NC}"
log "${GREEN}═══════════════════════════════════════════════════════════${NC}"
log ""
read -p "Ready to proceed with Pi-hole installation? (y/n): " proceed
if [[ "$proceed" != "y" && "$proceed" != "Y" ]]; then
    log "${RED}Installation aborted by user.${NC}"
    exit 0
fi

# --- Step 7: Run Pi-hole Installer ---
log ""
log "${GREEN}--- Step 7: Running Official Pi-hole Installer ---${NC}"
log "${YELLOW}IMPORTANT: During installation, select ${BLUE}$CHOSEN_IFACE${NC} when asked for network interface!${NC}"
log ""
sleep 3

curl -sSL https://install.pi-hole.net | bash

INSTALL_EXIT_CODE=$?

if [ $INSTALL_EXIT_CODE -ne 0 ]; then
    log "${RED}✗ Pi-hole installation failed or was cancelled.${NC}"
    log "Check the installation output above for errors."
    exit 1
fi

# --- Step 8: Handle Port Change if Requested ---
if [[ "$PORT_CHANGE" == "yes" ]]; then
    log ""
    log "${GREEN}--- Step 8: Changing Pi-hole Web GUI Port to 8080 ---${NC}"
    TOML_FILE="/etc/pihole/pihole.toml"
    
    if [ -f "$TOML_FILE" ]; then
        # Backup first
        BACKUP_FILE="${TOML_FILE}.backup.$(date +%Y%m%d_%H%M%S)"
        cp "$TOML_FILE" "$BACKUP_FILE"
        log "${BLUE}Created backup: $BACKUP_FILE${NC}"
        
        # Show current port setting
        CURRENT_PORT=$(grep 'port = "' "$TOML_FILE" | grep -v '^#')
        log "${BLUE}Current setting:${NC}"
        log "  $CURRENT_PORT"
        
        # Change port - match exact format: port = "80o,443os,[::]:80o,[::]:443os"
        # Only change the non-commented port line
        if grep -q 'port = "80o,443os,\[::\]:80o,\[::\]:443os"' "$TOML_FILE"; then
            # Use sed to replace 80 with 8080 in the port line
            sed -i 's/port = "80o,443os,\[::\]:80o,\[::\]:443os"/port = "8080o,443os,[::]:8080o,[::]:443os"/' "$TOML_FILE"
            
            # Verify the change
            NEW_PORT=$(grep 'port = "' "$TOML_FILE" | grep -v '^#')
            log ""
            log "${BLUE}New setting:${NC}"
            log "  $NEW_PORT"
            
            if grep -q 'port = "8080o,443os,\[::\]:8080o,\[::\]:443os"' "$TOML_FILE"; then
                log ""
                log "${GREEN}✓ Port setting updated in config file${NC}"
                
                log "${YELLOW}Restarting Pi-hole FTL service...${NC}"
                systemctl restart pihole-FTL
                sleep 5
                
                if systemctl is-active --quiet pihole-FTL; then
                    log "${GREEN}✓ FTL service restarted successfully!${NC}"
                    
                    # Test if port 8080 is now listening
                    sleep 2
                    if ss -tulpn | grep -q ":8080"; then
                        log "${GREEN}✓ Port 8080 is now active!${NC}"
                        log "${GREEN}✓ Admin interface: http://$CHOSEN_IP:8080/admin${NC}"
                        PORT_CHANGE_SUCCESS="yes"
                    else
                        log "${YELLOW}⚠ Port 8080 not detected yet. Checking ports...${NC}"
                        ss -tulpn | grep -E ":(80|8080)" | tee -a "$LOG_FILE"
                        log "${YELLOW}Give it a few more seconds and try accessing the web interface.${NC}"
                        PORT_CHANGE_SUCCESS="partial"
                    fi
                else
                    log "${RED}✗ FTL failed to restart. Restoring backup...${NC}"
                    mv "$BACKUP_FILE" "$TOML_FILE"
                    systemctl restart pihole-FTL
                    sleep 3
                    log "${YELLOW}Backup restored. Check: journalctl -u pihole-FTL -n 50${NC}"
                    PORT_CHANGE_SUCCESS="no"
                fi
            else
                log "${RED}✗ Port change verification failed. File may not have changed.${NC}"
                log "Current content:"
                grep 'port = ' "$TOML_FILE" | tee -a "$LOG_FILE"
                PORT_CHANGE_SUCCESS="no"
            fi
        else
            log "${RED}✗ Could not find expected port line in pihole.toml${NC}"
            log "Looking for: port = \"80o,443os,[::]:80o,[::]:443os\""
            log ""
            log "Found in file:"
            grep 'port = ' "$TOML_FILE" | tee -a "$LOG_FILE"
            log ""
            log "Manual configuration required."
            PORT_CHANGE_SUCCESS="no"
        fi
    else
        log "${RED}✗ pihole.toml not found at expected location: $TOML_FILE${NC}"
        log "Manual port change required. Check Pi-hole v6 documentation."
        PORT_CHANGE_SUCCESS="no"
    fi
else
    PORT_CHANGE_SUCCESS="no"
fi

# --- Step 9: Set/Reset Admin Password ---
log ""
log "${GREEN}--- Step 9: Setting Admin Web Password ---${NC}"
log "You'll now set the password for the Pi-hole web interface."
log ""
sleep 2
pihole setpassword

# --- Step 10: Verify Installation ---
log ""
log "${GREEN}--- Step 10: Verifying Installation ---${NC}"

# Check FTL service
if systemctl is-active --quiet pihole-FTL; then
    log "${GREEN}✓ Pi-hole FTL service is running${NC}"
else
    log "${RED}✗ Pi-hole FTL service is not running${NC}"
    log "  Check logs: journalctl -u pihole-FTL -n 50"
fi

# Check pihole command
if command -v pihole &> /dev/null; then
    log "${GREEN}✓ Pi-hole command is available${NC}"
    PIHOLE_VERSION=$(pihole -v -c 2>/dev/null | head -n1 | awk '{print $2}')
    if [ ! -z "$PIHOLE_VERSION" ]; then
        log "  Installed version: ${BLUE}$PIHOLE_VERSION${NC}"
    fi
else
    log "${RED}✗ Pi-hole command not found${NC}"
fi

# --- Step 11: DNS Functionality Test ---
log ""
log "${GREEN}--- Step 11: Testing DNS Resolution ---${NC}"

sleep 2
if dig @127.0.0.1 google.com +short +time=2 &> /dev/null; then
    log "${GREEN}✓ DNS resolution is working${NC}"
else
    log "${YELLOW}⚠ DNS test inconclusive${NC}"
    log "  Manual test: dig @$CHOSEN_IP google.com"
fi

# --- Final Instructions ---
log ""
log "${GREEN}═══════════════════════════════════════════════════════════${NC}"
log "${GREEN}           Pi-hole Installation Complete!                   ${NC}"
log "${GREEN}═══════════════════════════════════════════════════════════${NC}"
log ""
log "📍 Access your admin interface:"

# Determine which port to show based on actual configuration
if [[ "$PORT_CHANGE" == "yes" && "$PORT_CHANGE_SUCCESS" == "yes" ]]; then
    log "   ${BLUE}http://$CHOSEN_IP:8080/admin${NC}"
    log "   ${BLUE}http://pi.hole:8080/admin${NC}"
    ADMIN_PORT="8080"
elif [[ "$PORT_CHANGE" == "yes" && "$PORT_CHANGE_SUCCESS" == "partial" ]]; then
    log "   ${YELLOW}Port change attempted but status unclear.${NC}"
    log "   Try: ${BLUE}http://$CHOSEN_IP:80/admin${NC}"
    log "   Or:  ${BLUE}http://$CHOSEN_IP:8080/admin${NC}"
    ADMIN_PORT="80 or 8080"
else
    log "   ${BLUE}http://$CHOSEN_IP/admin${NC}"
    log "   ${BLUE}http://pi.hole/admin${NC}"
    ADMIN_PORT="80"
fi

log ""
log "Your Admin Password: Check the output above or reset with: ${BLUE}pihole -a -p${NC}"

# Re-enable WiFi if it was disabled
if [ "$WIFI_DISABLED" = true ]; then
    log ""
    log "${YELLOW}Note: WiFi was temporarily disabled during installation.${NC}"
    log "To re-enable WiFi, run:"
    log "  ${BLUE}sudo rfkill unblock wifi${NC}"
    log "  ${BLUE}sudo systemctl start wpa_supplicant${NC}"
fi

log ""
log "═══════════════════════════════════════════════════════════"
log "${YELLOW}Next Steps to Enable Network-Wide Blocking:${NC}"
log "═══════════════════════════════════════════════════════════"
log ""
log "1. ${GREEN}Log into your router's admin interface${NC}"
log "2. ${GREEN}Find DNS settings (often under DHCP or WAN settings)${NC}"
log "3. ${GREEN}Set Primary DNS to: ${BLUE}$CHOSEN_IP${NC} (interface: ${BLUE}$CHOSEN_IFACE${NC})"
log "4. ${GREEN}Set Secondary DNS to: ${BLUE}$CHOSEN_IP${NC} (or another DNS like 8.8.8.8)"
log "5. ${GREEN}Save settings and reboot router${NC}"
log "6. ${GREEN}Reboot your devices or wait for DHCP renewal${NC}"
log ""
log "═══════════════════════════════════════════════════════════"
log "${YELLOW}Troubleshooting:${NC}"
log "═══════════════════════════════════════════════════════════"
log ""
log "If admin page is inaccessible:"
log "  • Check Pi-hole FTL status: ${BLUE}sudo systemctl status pihole-FTL${NC}"
log "  • View live logs: ${BLUE}pihole -t${NC}"
log "  • Check what's listening: ${BLUE}sudo ss -tulpn | grep -E ':(80|8080)'${NC}"
log "  • Check FTL logs: ${BLUE}sudo journalctl -u pihole-FTL -n 50${NC}"

if [[ "$PORT_CHANGE" == "yes" ]]; then
    log ""
    log "Port 8080 configuration:"
    log "  • Config file: ${BLUE}/etc/pihole/pihole.toml${NC}"
    log "  • Check current port: ${BLUE}grep -A 5 '\\[webserver\\]' /etc/pihole/pihole.toml | grep port${NC}"
    
    if [[ "$PORT_CHANGE_SUCCESS" != "yes" ]]; then
        log ""
        log "${YELLOW}To manually change port to 8080:${NC}"
        log "  1. Edit: ${BLUE}sudo nano /etc/pihole/pihole.toml${NC}"
        log "  2. Find the [webserver] section"
        log "  3. Change port line to:"
        log "     ${BLUE}port = \"8080o,443os,[::]:8080o,[::]:443os\"${NC}"
        log "  4. Save and restart: ${BLUE}sudo systemctl restart pihole-FTL${NC}"
    fi
fi

log ""
log "If DNS not working on devices:"
log "  • Test Pi-hole DNS: ${BLUE}dig @$CHOSEN_IP google.com${NC}"
log "  • Test from device: ${BLUE}nslookup google.com $CHOSEN_IP${NC}"
log "  • Check device DNS settings"
log "  • Verify router DNS configuration"
log "  • Ensure static IP for ${BLUE}$CHOSEN_IFACE${NC} is configured"
log ""
log "${GREEN}✅ Setup Complete!${NC} Your network is now protected by Pi-hole."
log "${GREEN}•${NC} Pi-hole admin will be on http://$CHOSEN_IP:8080/admin"
log "${GREEN}•${NC} Your existing web server (if any) keeps port 80"
log ""
log "Full installation log saved to: ${BLUE}$LOG_FILE${NC}"
log ""
