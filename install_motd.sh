#!/bin/bash

# ========================================================================
# EVOLUSO - Simple MOTD Installation Script
# ========================================================================

MOTD_FILE="/etc/motd"

# Clean ALL existing MOTDs (including system defaults)
clean_motds() {
    # Remove existing MOTD files completely
    rm -f "$MOTD_FILE" 2>/dev/null
    rm -f /etc/motd.tail 2>/dev/null
    rm -f /etc/motd.dynamic 2>/dev/null
    rm -f /run/motd.dynamic 2>/dev/null
    rm -f /var/run/motd 2>/dev/null
    rm -f /var/run/motd.dynamic 2>/dev/null

    # Clean dynamic MOTD directory completely (Ubuntu/Debian)
    if [[ -d "/etc/update-motd.d" ]]; then
        # Remove ALL scripts in update-motd.d
        rm -f /etc/update-motd.d/* 2>/dev/null
        # Recreate directory
        mkdir -p /etc/update-motd.d
    fi

    # Disable Ubuntu's MOTD services completely
    [[ -f /etc/default/motd-news ]] && sed -i 's/ENABLED=1/ENABLED=0/' /etc/default/motd-news 2>/dev/null

    # Disable systemd MOTD services
    systemctl disable motd-news.service 2>/dev/null
    systemctl disable motd-news.timer 2>/dev/null
    systemctl stop motd-news.service 2>/dev/null
    systemctl stop motd-news.timer 2>/dev/null

    # Remove package manager MOTDs
    rm -f /etc/apt/apt.conf.d/99update-notifier 2>/dev/null

    # Clear SSH MOTD configurations
    sed -i '/PrintMotd/d' /etc/ssh/sshd_config 2>/dev/null
    echo "PrintMotd yes" >> /etc/ssh/sshd_config
}

# Create MOTD content
create_motd() {
    cat > "$MOTD_FILE" << 'EOF'
#!/bin/bash

# Colors
BLUE='\033[0;34m'
CYAN='\033[0;36m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
WHITE='\033[1;37m'
NC='\033[0m'

# System information
HOSTNAME=$(hostname)
MAIN_IP=$(ip route get 8.8.8.8 2>/dev/null | head -1 | cut -d' ' -f7 2>/dev/null || hostname -I | awk '{print $1}' 2>/dev/null || echo "N/A")

echo -e "${BLUE}"
echo "███████╗██╗   ██╗ ██████╗ ██╗     ██╗   ██╗███████╗ ██████╗ "
echo "██╔════╝██║   ██║██╔═══██╗██║     ██║   ██║██╔════╝██╔═══██╗"
echo "█████╗  ██║   ██║██║   ██║██║     ██║   ██║███████╗██║   ██║"
echo "██╔══╝  ╚██╗ ██╔╝██║   ██║██║     ██║   ██║╚════██║██║   ██║"
echo "███████╗ ╚████╔╝ ╚██████╔╝███████╗╚██████╔╝███████║╚██████╔╝"
echo "╚══════╝  ╚═══╝   ╚═════╝ ╚══════╝ ╚═════╝ ╚══════╝ ╚═════╝ "
echo -e "${NC}"

echo -e "${CYAN}═══════════════════════════════════════════════════════════════${NC}"
echo -e "${WHITE}                    RELIABLE HOSTING                           ${NC}"
echo -e "${CYAN}═══════════════════════════════════════════════════════════════${NC}"
echo
echo -e "${GREEN}Hostname:${NC} $HOSTNAME"
echo -e "${GREEN}IP Address:${NC} $MAIN_IP"
echo
echo -e "${CYAN}═══════════════════════════════════════════════════════════════${NC}"
echo -e "${YELLOW}Welcome to your Evoluso server!${NC}"
echo -e "${CYAN}═══════════════════════════════════════════════════════════════${NC}"

EOF
}

# Install dependencies
install_deps() {
    if command -v apt-get &> /dev/null; then
        apt-get update -qq >/dev/null 2>&1
        apt-get install -y curl wget figlet >/dev/null 2>&1
    elif command -v yum &> /dev/null; then
        yum install -y curl wget figlet >/dev/null 2>&1
        yum install -y epel-release >/dev/null 2>&1
    elif command -v dnf &> /dev/null; then
        dnf install -y curl wget figlet >/dev/null 2>&1
    elif command -v pacman &> /dev/null; then
        pacman -Sy --noconfirm curl wget figlet >/dev/null 2>&1
    elif command -v zypper &> /dev/null; then
        zypper install -y curl wget figlet >/dev/null 2>&1
    elif command -v apk &> /dev/null; then
        apk add --no-cache curl wget figlet >/dev/null 2>&1
    fi
}

# Main installation
main() {
    # Check root
    [[ $EUID -ne 0 ]] && { echo "Run as root"; exit 1; }

    # Clean ALL existing MOTDs first
    clean_motds

    # Install dependencies silently
    install_deps

    # Create our MOTD directly
    create_motd

    # Setup for dynamic MOTD systems (Ubuntu/Debian primarily)
    if [[ -d "/etc/update-motd.d" ]]; then
        cp "$MOTD_FILE" "/etc/update-motd.d/00-evoluso"
        chmod +x "/etc/update-motd.d/00-evoluso"
    fi

    # Set correct permissions
    chmod 644 "$MOTD_FILE"

    # Force update dynamic MOTD cache if system supports it
    command -v update-motd >/dev/null 2>&1 && update-motd >/dev/null 2>&1

    # Restart SSH service to apply MOTD changes
    systemctl restart ssh 2>/dev/null || systemctl restart sshd 2>/dev/null

    echo "EVOLUSO MOTD installed successfully!"
}

main "$@"
