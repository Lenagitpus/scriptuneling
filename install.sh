#!/bin/bash
# VPS Manager Installation Script
# Version: HAPPY NEW YEAR 2025

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
NC='\033[0m' # No Color

# Check if running as root
if [ "$(id -u)" != "0" ]; then
   echo -e "${RED}This script must be run as root${NC}" 
   exit 1
fi

echo -e "${GREEN}╭════════════════════════════════════════════════════════════╮${NC}"
echo -e "${GREEN}│                VPS MANAGER INSTALLER                       │${NC}"
echo -e "${GREEN}│                HAPPY NEW YEAR 2025                         │${NC}"
echo -e "${GREEN}╰════════════════════════════════════════════════════════════╯${NC}"

# Create directories
echo -e "${YELLOW}Creating directories...${NC}"
mkdir -p /etc/vps_manager
mkdir -p /var/log/vps_manager
mkdir -p /var/backups/vps_manager

# Install required packages
echo -e "${YELLOW}Installing required packages...${NC}"
apt-get update
apt-get install -y curl wget jq unzip socat openssl netcat net-tools bc htop screen cron iptables iptables-persistent netfilter-persistent ca-certificates gnupg lsb-release apt-transport-https nginx fail2ban

# Install Docker if not installed
if ! command -v docker &> /dev/null; then
    echo -e "${YELLOW}Installing Docker...${NC}"
    curl -fsSL https://get.docker.com | sh
    systemctl enable docker
    systemctl start docker
fi

# Install Xray if not installed
if ! command -v xray &> /dev/null; then
    echo -e "${YELLOW}Installing Xray...${NC}"
    bash -c "$(curl -L https://github.com/XTLS/Xray-install/raw/main/install-release.sh)" @ install
fi

# Copy VPS Manager script
echo -e "${YELLOW}Installing VPS Manager...${NC}"
cp vps_manager.sh /usr/local/bin/vps_manager
chmod +x /usr/local/bin/vps_manager

# Create systemd service
echo -e "${YELLOW}Creating systemd service...${NC}"
cat > /etc/systemd/system/vps_manager.service << EOF
[Unit]
Description=VPS Manager Service
After=network.target

[Service]
ExecStart=/usr/local/bin/vps_manager
Restart=on-failure
RestartSec=3
StandardOutput=journal
StandardError=journal

[Install]
WantedBy=multi-user.target
EOF

# Create auto-start script
echo -e "${YELLOW}Creating auto-start configuration...${NC}"
cat > /etc/profile.d/vps_manager.sh << EOF
#!/bin/bash
if [ "\$(id -u)" -eq 0 ]; then
    echo "Starting VPS Manager..."
    /bin/bash /usr/local/bin/vps_manager
fi
EOF

chmod +x /etc/profile.d/vps_manager.sh

# Setup Cloudflare WebSocket support
echo -e "${YELLOW}Setting up Cloudflare WebSocket support...${NC}"

# Create WebSocket proxy service
cat > /usr/local/bin/ws-epro << 'EOF'
#!/bin/bash

# WebSocket Proxy for Cloudflare
# Supports ports 80, 443, 8080

run_ws_proxy() {
    local listen_port=$1
    local forward_port=$2
    
    nohup socat TCP-LISTEN:$listen_port,fork,reuseaddr TCP:127.0.0.1:$forward_port > /dev/null 2>&1 &
    echo "WebSocket proxy started: $listen_port -> $forward_port"
}

# Kill existing processes
pkill -f "socat TCP-LISTEN"

# Start WebSocket proxies
run_ws_proxy 80 10080
run_ws_proxy 443 10443
run_ws_proxy 8080 10880

echo "All WebSocket proxies started"
EOF

chmod +x /usr/local/bin/ws-epro

# Create systemd service for WebSocket proxy
cat > /etc/systemd/system/ws-epro.service << EOF
[Unit]
Description=WebSocket Proxy for Cloudflare
After=network.target

[Service]
ExecStart=/usr/local/bin/ws-epro
Restart=always
RestartSec=3

[Install]
WantedBy=multi-user.target
EOF

# Enable and start services
echo -e "${YELLOW}Enabling and starting services...${NC}"
systemctl daemon-reload
systemctl enable vps_manager.service
systemctl enable ws-epro.service
systemctl start ws-epro.service

# Get domain name
echo -e "${YELLOW}Please enter your domain name:${NC}"
read -r domain_name

# Save domain to config
echo "DOMAIN=&quot;$domain_name&quot;" > /etc/vps_manager/config.conf

echo -e "${GREEN}╭════════════════════════════════════════════════════════════╮${NC}"
echo -e "${GREEN}│            VPS MANAGER INSTALLED SUCCESSFULLY              │${NC}"
echo -e "${GREEN}╰════════════════════════════════════════════════════════════╯${NC}"
echo -e "${YELLOW}To start VPS Manager, run:${NC} vps_manager"
echo -e "${YELLOW}VPS Manager will also start automatically on next login.${NC}"
echo -e "${YELLOW}Domain has been set to:${NC} $domain_name"

# Start VPS Manager
echo -e "${YELLOW}Starting VPS Manager...${NC}"
/usr/local/bin/vps_manager
