#!/bin/bash

# --- Color Codes ---
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

LOG_FILE="/var/log/adguard-install-techposts.log"

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
log "${GREEN}  TechPosts AdGuard Home Setup Script ${NC}"
log "${GREEN}=======================================${NC}"
log ""
log "${YELLOW}Welcome!${NC} This script will prepare your system and install AdGuard Home."
log ""
log "${RED}NOTE:${NC} AdGuard Home will be installed as a system service."

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

# Check disk space (AdGuard needs ~50MB minimum)
AVAILABLE_SPACE=$(df / | tail -1 | awk '{print $4}')
SPACE_MB=$((AVAILABLE_SPACE / 1024))
log "Available disk space: ${BLUE}${SPACE_MB}MB${NC}"

if [ "$AVAILABLE_SPACE" -lt 51200 ]; then
    log "${RED}WARNING:${NC} Low disk space (less than 50MB). AdGuard may not install properly."
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

# Check for wget
if ! command -v wget &> /dev/null; then
    log "${YELLOW}wget not found. Installing...${NC}"
    apt install -y wget
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
    log "Which interface do you want to use for AdGuard Home?"
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
            log "This can prevent confusion during setup."
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
    log "${YELLOW}AdGuard Home REQUIRES a static IP to function properly!${NC}"
    log "Without a static IP, your AdGuard will stop working when the IP changes."
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

# --- Step 5: Check for Port Conflicts ---
log ""
log "${GREEN}--- Step 5: Checking for Port Conflicts ---${NC}"

PORTS_IN_USE=""
PORT_CONFLICT=false

# Check DNS port 53
if ss -tulpn | grep -q ":53 "; then
    PORT_53_PROCESS=$(ss -tulpn | grep ":53 " | awk '{print $7}' | cut -d'"' -f2 | head -n1)
    log "${RED}⚠ Port 53 (DNS) is in use by: ${BLUE}$PORT_53_PROCESS${NC}"
    PORTS_IN_USE="$PORTS_IN_USE 53"
    PORT_CONFLICT=true
fi

# Check HTTP port 80
if ss -tulpn | grep -q ":80 "; then
    PORT_80_PROCESS=$(ss -tulpn | grep ":80 " | awk '{print $7}' | cut -d'"' -f2 | head -n1)
    log "${YELLOW}⚠ Port 80 (HTTP) is in use by: ${BLUE}$PORT_80_PROCESS${NC}"
    PORTS_IN_USE="$PORTS_IN_USE 80"
fi

# Check HTTPS port 443
if ss -tulpn | grep -q ":443 "; then
    PORT_443_PROCESS=$(ss -tulpn | grep ":443 " | awk '{print $7}' | cut -d'"' -f2 | head -n1)
    log "${YELLOW}⚠ Port 443 (HTTPS) is in use by: ${BLUE}$PORT_443_PROCESS${NC}"
    PORTS_IN_USE="$PORTS_IN_USE 443"
fi

# Check port 3000 (AdGuard default web interface during setup)
if ss -tulpn | grep -q ":3000 "; then
    PORT_3000_PROCESS=$(ss -tulpn | grep ":3000 " | awk '{print $7}' | cut -d'"' -f2 | head -n1)
    log "${YELLOW}⚠ Port 3000 (Setup) is in use by: ${BLUE}$PORT_3000_PROCESS${NC}"
    PORTS_IN_USE="$PORTS_IN_USE 3000"
fi

if [ "$PORT_CONFLICT" = true ]; then
    log ""
    log "${RED}CRITICAL: Port 53 is required for DNS functionality!${NC}"
    log ""
    log "═══════════════════════════════════════════════════════════"
    log "Port Conflict Resolution:"
    log "═══════════════════════════════════════════════════════════"
    log ""
    
    # Check for systemd-resolved (common on Ubuntu/Debian)
    if systemctl is-active --quiet systemd-resolved; then
        log "${YELLOW}systemd-resolved is running and using port 53${NC}"
        log ""
        log "We can disable it for you. AdGuard Home will handle DNS instead."
        log ""
        read -p "Disable systemd-resolved? (y/n): " disable_resolved
        
        if [[ "$disable_resolved" == "y" || "$disable_resolved" == "Y" ]]; then
            log "${YELLOW}Disabling systemd-resolved...${NC}"
            systemctl stop systemd-resolved
            systemctl disable systemd-resolved
            
            # Update resolv.conf to not use systemd-resolved
            rm /etc/resolv.conf 2>/dev/null
            echo "nameserver 1.1.1.1" > /etc/resolv.conf
            echo "nameserver 8.8.8.8" >> /etc/resolv.conf
            
            log "${GREEN}✓ systemd-resolved disabled${NC}"
            PORT_CONFLICT=false
        else
            log "${RED}Cannot proceed with port 53 occupied.${NC}"
            log "Please manually resolve the conflict and re-run this script."
            exit 1
        fi
    else
        log "${YELLOW}To resolve port 53 conflict:${NC}"
        log "  1. Identify the service using port 53: ${BLUE}sudo ss -tulpn | grep :53${NC}"
        log "  2. Stop the service (e.g., sudo systemctl stop dnsmasq)"
        log "  3. Re-run this script"
        log ""
        read -p "Have you resolved the port 53 conflict? (y/n): " port_resolved
        
        if [[ "$port_resolved" != "y" && "$port_resolved" != "Y" ]]; then
            log "${RED}Installation aborted.${NC}"
            exit 1
        fi
    fi
elif [ ! -z "$PORTS_IN_USE" ]; then
    log ""
    log "${YELLOW}Non-critical ports in use:$PORTS_IN_USE${NC}"
    log "AdGuard Home can still function, but web interface may need alternate ports."
    log "${GREEN}✓ DNS port 53 is available (required)${NC}"
else
    log "${GREEN}✓ All required ports are available${NC}"
fi

# --- Step 6: Check for Conflicting Services ---
log ""
log "${GREEN}--- Step 6: Checking for Conflicting Services ---${NC}"

CONFLICTS_FOUND=false

# Check for Pi-hole
if command -v pihole &> /dev/null || [ -d "/etc/pihole" ]; then
    log "${RED}⚠ Pi-hole is installed on this system!${NC}"
    log "AdGuard Home and Pi-hole cannot run simultaneously (both use port 53)."
    log ""
    read -p "Do you want to continue anyway? (y/n): " continue_pihole
    if [[ "$continue_pihole" != "y" && "$continue_pihole" != "Y" ]]; then
        log "${RED}Installation aborted.${NC}"
        exit 1
    fi
    CONFLICTS_FOUND=true
fi

# Check for dnsmasq
if systemctl is-active --quiet dnsmasq; then
    log "${YELLOW}⚠ dnsmasq service is running${NC}"
    log "This may conflict with AdGuard Home's DNS functionality."
    log ""
    read -p "Disable dnsmasq? (y/n): " disable_dnsmasq
    if [[ "$disable_dnsmasq" == "y" || "$disable_dnsmasq" == "Y" ]]; then
        systemctl stop dnsmasq
        systemctl disable dnsmasq
        log "${GREEN}✓ dnsmasq disabled${NC}"
    fi
    CONFLICTS_FOUND=true
fi

if [ "$CONFLICTS_FOUND" = false ]; then
    log "${GREEN}✓ No conflicting services detected${NC}"
fi

# --- Step 7: Final Pre-Install Summary ---
log ""
log "${GREEN}═══════════════════════════════════════════════════════════${NC}"
log "${GREEN}Pre-Installation Summary${NC}"
log "${GREEN}═══════════════════════════════════════════════════════════${NC}"
log "Interface: ${BLUE}$CHOSEN_IFACE${NC}"
log "IP Address: ${BLUE}$CHOSEN_IP${NC}"
log "Total Interfaces: ${BLUE}$INTERFACE_COUNT${NC}"
log "DNS Port 53: ${BLUE}$([ -z "$(ss -tulpn | grep ':53 ')" ] && echo 'Available' || echo 'In use (resolved)')${NC}"
log "Static IP: ${BLUE}Confirmed${NC}"
log "${GREEN}═══════════════════════════════════════════════════════════${NC}"
log ""
read -p "Ready to proceed with AdGuard Home installation? (y/n): " proceed
if [[ "$proceed" != "y" && "$proceed" != "Y" ]]; then
    log "${RED}Installation aborted by user.${NC}"
    exit 0
fi

# --- Step 8: Download and Install AdGuard Home ---
log ""
log "${GREEN}--- Step 8: Downloading AdGuard Home ---${NC}"

# Detect architecture
ARCH=$(uname -m)
case "$ARCH" in
    x86_64|amd64)
        DOWNLOAD_ARCH="amd64"
        ;;
    armv7l|armhf)
        DOWNLOAD_ARCH="armv7"
        ;;
    aarch64|arm64)
        DOWNLOAD_ARCH="arm64"
        ;;
    *)
        log "${RED}✗ Unsupported architecture: $ARCH${NC}"
        exit 1
        ;;
esac

log "Detected architecture: ${BLUE}$ARCH${NC} (downloading ${BLUE}$DOWNLOAD_ARCH${NC} version)"

# Create temp directory
TEMP_DIR=$(mktemp -d)
cd "$TEMP_DIR"

# Download AdGuard Home
log "${YELLOW}Downloading AdGuard Home...${NC}"
DOWNLOAD_URL="https://static.adguard.com/adguardhome/release/AdGuardHome_linux_${DOWNLOAD_ARCH}.tar.gz"

if wget -q --show-progress "$DOWNLOAD_URL" -O AdGuardHome.tar.gz; then
    log "${GREEN}✓ Download complete${NC}"
else
    log "${RED}✗ Download failed${NC}"
    log "URL attempted: $DOWNLOAD_URL"
    exit 1
fi

# Extract
log "${YELLOW}Extracting archive...${NC}"
tar -xzf AdGuardHome.tar.gz
if [ $? -eq 0 ]; then
    log "${GREEN}✓ Extraction complete${NC}"
else
    log "${RED}✗ Extraction failed${NC}"
    exit 1
fi

# --- Step 9: Install AdGuard Home ---
log ""
log "${GREEN}--- Step 9: Installing AdGuard Home ---${NC}"

# Move to /opt
if [ -d "/opt/AdGuardHome" ]; then
    log "${YELLOW}Existing installation found. Creating backup...${NC}"
    mv /opt/AdGuardHome "/opt/AdGuardHome.backup.$(date +%Y%m%d_%H%M%S)"
fi

mv AdGuardHome /opt/
cd /opt/AdGuardHome

# Install as service
log "${YELLOW}Installing as system service...${NC}"
./AdGuardHome -s install

if [ $? -eq 0 ]; then
    log "${GREEN}✓ AdGuard Home installed as service${NC}"
else
    log "${RED}✗ Service installation failed${NC}"
    exit 1
fi

# Clean up temp directory
cd /
rm -rf "$TEMP_DIR"

# --- Step 10: Start AdGuard Home ---
log ""
log "${GREEN}--- Step 10: Starting AdGuard Home ---${NC}"

systemctl start AdGuardHome
sleep 3

if systemctl is-active --quiet AdGuardHome; then
    log "${GREEN}✓ AdGuard Home service is running${NC}"
else
    log "${RED}✗ AdGuard Home service failed to start${NC}"
    log "Check logs: journalctl -u AdGuardHome -n 50"
    exit 1
fi

# --- Step 11: Verify Installation ---
log ""
log "${GREEN}--- Step 11: Verifying Installation ---${NC}"

# Check if port 3000 is listening (initial setup interface)
sleep 2
if ss -tulpn | grep -q ":3000"; then
    log "${GREEN}✓ Setup interface is accessible on port 3000${NC}"
    SETUP_PORT="3000"
elif ss -tulpn | grep -q ":80"; then
    log "${GREEN}✓ Web interface is accessible on port 80${NC}"
    SETUP_PORT="80"
else
    log "${YELLOW}⚠ Could not detect web interface port${NC}"
    log "Check AdGuard Home status: systemctl status AdGuardHome"
    SETUP_PORT="3000"
fi

# --- Final Instructions ---
log ""
log "${GREEN}═══════════════════════════════════════════════════════════${NC}"
log "${GREEN}        AdGuard Home Installation Complete!                 ${NC}"
log "${GREEN}═══════════════════════════════════════════════════════════${NC}"
log ""
log "📍 Complete the setup by opening your web browser:"
log ""
if [ "$SETUP_PORT" = "3000" ]; then
    log "   ${BLUE}http://$CHOSEN_IP:3000${NC}"
    log ""
    log "During setup, you'll be asked to:"
    log "  1. Set admin username and password"
    log "  2. Configure web interface port (default: 80)"
    log "  3. Configure DNS port (default: 53)"
    log "  4. Choose upstream DNS servers"
else
    log "   ${BLUE}http://$CHOSEN_IP${NC}"
fi

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
log "1. ${GREEN}Complete the web setup at http://$CHOSEN_IP:$SETUP_PORT${NC}"
log "2. ${GREEN}Log into your router's admin interface${NC}"
log "3. ${GREEN}Find DNS settings (often under DHCP or WAN settings)${NC}"
log "4. ${GREEN}Set Primary DNS to: ${BLUE}$CHOSEN_IP${NC} (interface: ${BLUE}$CHOSEN_IFACE${NC})"
log "5. ${GREEN}Set Secondary DNS to: ${BLUE}$CHOSEN_IP${NC} (or another DNS like 8.8.8.8)"
log "6. ${GREEN}Save settings and reboot router${NC}"
log "7. ${GREEN}Reboot your devices or wait for DHCP renewal${NC}"
log ""
log "═══════════════════════════════════════════════════════════"
log "${YELLOW}Troubleshooting:${NC}"
log "═══════════════════════════════════════════════════════════"
log ""
log "If web interface is inaccessible:"
log "  • Check service status: ${BLUE}sudo systemctl status AdGuardHome${NC}"
log "  • View logs: ${BLUE}sudo journalctl -u AdGuardHome -n 50${NC}"
log "  • Check listening ports: ${BLUE}sudo ss -tulpn | grep AdGuard${NC}"
log "  • Try alternate port: ${BLUE}http://$CHOSEN_IP:3000${NC}"
log ""
log "If DNS not working on devices:"
log "  • Test AdGuard DNS: ${BLUE}dig @$CHOSEN_IP google.com${NC}"
log "  • Test from device: ${BLUE}nslookup google.com $CHOSEN_IP${NC}"
log "  • Check device DNS settings"
log "  • Verify router DNS configuration"
log "  • Ensure static IP for ${BLUE}$CHOSEN_IFACE${NC} is configured"
log ""
log "Service management:"
log "  • Start: ${BLUE}sudo systemctl start AdGuardHome${NC}"
log "  • Stop: ${BLUE}sudo systemctl stop AdGuardHome${NC}"
log "  • Restart: ${BLUE}sudo systemctl restart AdGuardHome${NC}"
log "  • Status: ${BLUE}sudo systemctl status AdGuardHome${NC}"
log ""
log "${GREEN}✅ Setup Complete!${NC} Your network is ready for AdGuard Home protection."
log ""
log "Full installation log saved to: ${BLUE}$LOG_FILE${NC}"
log ""