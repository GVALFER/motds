#!/bin/bash

# ========================================================================
# EVOLUSO - Universal MOTD Installer (Ubuntu, Debian, CentOS, Alma, Rocky)
# ========================================================================

set -e

# Detect distro
if [ -f /etc/os-release ]; then
    . /etc/os-release
    DISTRO=$ID
else
    DISTRO=$(uname -s)
fi

# MOTD paths
MOTD_STATIC="/etc/motd"
MOTD_SCRIPT="/etc/update-motd.d/00-evoluso"

# Remove all old MOTDs and disables other motd scripts/services
clean_motds() {
    rm -f "$MOTD_STATIC" /etc/motd.tail /etc/motd.dynamic /run/motd.dynamic /var/run/motd /var/run/motd.dynamic 2>/dev/null || true
    if [[ -d "/etc/update-motd.d" ]]; then
        rm -f /etc/update-motd.d/* 2>/dev/null || true
        mkdir -p /etc/update-motd.d
    fi
    [[ -f /etc/default/motd-news ]] && sed -i 's/ENABLED=1/ENABLED=0/' /etc/default/motd-news 2>/dev/null
    systemctl disable motd-news.service motd-news.timer 2>/dev/null || true
    systemctl stop motd-news.service motd-news.timer 2>/dev/null || true
    rm -f /etc/apt/apt.conf.d/99update-notifier 2>/dev/null || true
    sed -i '/PrintMotd/d' /etc/ssh/sshd_config 2>/dev/null || true
    echo "PrintMotd yes" >> /etc/ssh/sshd_config
}

# Install required dependencies (curl, wget, etc)
install_deps() {
    if command -v apt-get &> /dev/null; then
        apt-get update -qq
        apt-get install -y curl wget
    elif command -v yum &> /dev/null; then
        yum install -y curl wget
    elif command -v dnf &> /dev/null; then
        dnf install -y curl wget
    elif command -v pacman &> /dev/null; then
        pacman -Sy --noconfirm curl wget
    elif command -v zypper &> /dev/null; then
        zypper install -y curl wget
    elif command -v apk &> /dev/null; then
        apk add --no-cache curl wget
    fi
}

# Create dynamic script for update-motd.d (Ubuntu/Debian)
create_dynamic_motd_script() {
    cat > "$MOTD_SCRIPT" << 'EOF'
#!/bin/bash

# Colors
BLUE='\033[0;34m'
CYAN='\033[0;36m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
WHITE='\033[1;37m'
NC='\033[0m'

CPU=$(lscpu | awk -F: '/Model name/ {print $2}' | xargs)
MEM=$(free -h | awk '/^Mem:/{print $2}')
HOSTNAME=$(hostname)
MAIN_IP=$(ip route get 8.8.8.8 2>/dev/null | awk '{print $7; exit}' | grep -v unreachable)
[ -z "$MAIN_IP" ] && MAIN_IP=$(hostname -I | awk '{print $1}')

echo -e "${CYAN}"
echo " ███████╗██╗   ██╗ ██████╗ ██╗     ██╗   ██╗███████╗ ██████╗ "
echo " ██╔════╝██║   ██║██╔═══██╗██║     ██║   ██║██╔════╝██╔═══██╗"
echo " █████╗  ██║   ██║██║   ██║██║     ██║   ██║███████╗██║   ██║"
echo " ██╔══╝  ╚██╗ ██╔╝██║   ██║██║     ██║   ██║╚════██║██║   ██║"
echo " ███████║ ╚████╔╝ ╚██████╔╝███████╗╚██████╔╝███████║╚██████╔╝"
echo " ╚══════╝  ╚═══╝   ╚═════╝ ╚══════╝ ╚═════╝ ╚══════╝ ╚═════╝ "
echo -e "${NC}"
echo -e "${CYAN}═══════════════════════════════════════════════════════════════${NC}"
echo -e "${GREEN}Hostname:${NC}   $HOSTNAME"
echo -e "${GREEN}IP Address:${NC} $MAIN_IP"
echo -e "${GREEN}CPU:${NC}        $CPU"
echo -e "${GREEN}Memory:${NC}     $MEM"
echo -e "${CYAN}═══════════════════════════════════════════════════════════════${NC}"
EOF
    chmod +x "$MOTD_SCRIPT"
}

# Generate static MOTD (CentOS, Alma, Rocky, RHEL, etc)
create_static_motd() {
    HOSTNAME=$(hostname)
    MAIN_IP=$(ip route get 8.8.8.8 2>/dev/null | awk '{print $7; exit}' | grep -v unreachable)
    [ -z "$MAIN_IP" ] && MAIN_IP=$(hostname -I | awk '{print $1}')

    cat > "$MOTD_STATIC" <<EOF
 ███████╗██╗   ██╗ ██████╗ ██╗     ██╗   ██╗███████╗ ██████╗
 ██╔════╝██║   ██║██╔═══██╗██║     ██║   ██║██╔════╝██╔═══██╗
 █████╗  ██║   ██║██║   ██║██║     ██║   ██║███████╗██║   ██║
 ██╔══╝  ╚██╗ ██╔╝██║   ██║██║     ██║   ██║╚════██║██║   ██║
 ███████║ ╚████╔╝ ╚██████╔╝███████╗╚██████╔╝███████║╚██████╔╝
 ╚══════╝  ╚═══╝   ╚═════╝ ╚══════╝ ╚═════╝ ╚══════╝ ╚═════╝

Hostname:  $HOSTNAME
IP:        $MAIN_IP
EOF
}

# Main installation routine
main() {
    [[ $EUID -ne 0 ]] && { echo "Please run as root!"; exit 1; }

    clean_motds
    install_deps

    if [[ -d "/etc/update-motd.d" ]]; then
        create_dynamic_motd_script
        echo "Evoluso MOTD dynamic script installed in /etc/update-motd.d/00-evoluso"
    else
        create_static_motd
        echo "Evoluso MOTD static content written to /etc/motd"
    fi

    # Force MOTD update if available
    command -v update-motd >/dev/null 2>&1 && update-motd >/dev/null 2>&1

    # Restart SSH (if present) to ensure MOTD is loaded on new sessions
    systemctl restart ssh 2>/dev/null || systemctl restart sshd 2>/dev/null

    echo "✅ EVOLUSO MOTD installed successfully!"
}

main "$@"
