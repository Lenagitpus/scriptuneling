#!/bin/bash
# Improved VPS Manager Installation Script
# Version: HAPPY NEW YEAR 2025

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Log file
LOG_FILE="/tmp/vps_manager_install.log"
echo "VPS Manager Installation Log - $(date)" > $LOG_FILE

# Function to log messages
log_message() {
    echo -e "$1" | tee -a $LOG_FILE
}

# Function to check command success
check_success() {
    if [ $? -eq 0 ]; then
        log_message "${GREEN}✓ Success: $1${NC}"
        return 0
    else
        log_message "${RED}✗ Failed: $1${NC}"
        return 1
    fi
}

# Check if running as root
if [ "$(id -u)" != "0" ]; then
   log_message "${RED}This script must be run as root${NC}" 
   exit 1
fi

# Display banner
log_message "${GREEN}┏━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┓${NC}"
log_message "${GREEN}┃                VPS MANAGER INSTALLER                       ┃${NC}"
log_message "${GREEN}┃                HAPPY NEW YEAR 2025                         ┃${NC}"
log_message "${GREEN}┗━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┛${NC}"

# Create directories
log_message "${YELLOW}Creating directories...${NC}"
mkdir -p /etc/vps_manager
check_success "Created /etc/vps_manager directory"

mkdir -p /var/log/vps_manager
check_success "Created /var/log/vps_manager directory"

mkdir -p /var/backups/vps_manager
check_success "Created /var/backups/vps_manager directory"

# Install required packages
log_message "${YELLOW}Installing required packages...${NC}"
apt-get update >> $LOG_FILE 2>&1
check_success "Updated package lists"

PACKAGES="curl wget jq unzip socat openssl netcat net-tools bc htop screen cron iptables iptables-persistent netfilter-persistent ca-certificates gnupg lsb-release apt-transport-https nginx fail2ban"
apt-get install -y $PACKAGES >> $LOG_FILE 2>&1
check_success "Installed required packages"

# Install Docker if not installed
if ! command -v docker &> /dev/null; then
    log_message "${YELLOW}Installing Docker...${NC}"
    curl -fsSL https://get.docker.com | sh >> $LOG_FILE 2>&1
    check_success "Installed Docker"
    
    systemctl enable docker >> $LOG_FILE 2>&1
    systemctl start docker >> $LOG_FILE 2>&1
    check_success "Started Docker service"
fi

# Install Xray if not installed
if ! command -v xray &> /dev/null; then
    log_message "${YELLOW}Installing Xray...${NC}"
    bash -c "$(curl -L https://github.com/XTLS/Xray-install/raw/main/install-release.sh)" @ install >> $LOG_FILE 2>&1
    check_success "Installed Xray"
fi

# Function to download VPS Manager script with multiple methods
download_vps_manager() {
    local attempt=1
    local max_attempts=3
    local success=false
    local temp_dir=$(mktemp -d)
    
    log_message "${YELLOW}Downloading VPS Manager script (Attempt $attempt/$max_attempts)...${NC}"
    
    # Method 1: Direct file copy if available locally
    if [ -f "vps_manager.sh" ]; then
        log_message "${BLUE}Using local file copy method...${NC}"
        cp vps_manager.sh "$temp_dir/vps_manager.sh" >> $LOG_FILE 2>&1
        if [ $? -eq 0 ]; then
            success=true
        fi
    fi
    
    # Method 2: Download using wget if not successful yet
    if [ "$success" = false ] && [ $attempt -lt $max_attempts ]; then
        attempt=$((attempt+1))
        log_message "${YELLOW}Downloading VPS Manager script (Attempt $attempt/$max_attempts)...${NC}"
        log_message "${BLUE}Using wget download method...${NC}"
        wget -q https://raw.githubusercontent.com/Lenagitpus/scriptuneling/main/vps_manager.sh -O "$temp_dir/vps_manager.sh" >> $LOG_FILE 2>&1
        if [ $? -eq 0 ]; then
            success=true
        fi
    fi
    
    # Method 3: Download using curl if not successful yet
    if [ "$success" = false ] && [ $attempt -lt $max_attempts ]; then
        attempt=$((attempt+1))
        log_message "${YELLOW}Downloading VPS Manager script (Attempt $attempt/$max_attempts)...${NC}"
        log_message "${BLUE}Using curl download method...${NC}"
        curl -s https://raw.githubusercontent.com/Lenagitpus/scriptuneling/main/vps_manager.sh -o "$temp_dir/vps_manager.sh" >> $LOG_FILE 2>&1
        if [ $? -eq 0 ]; then
            success=true
        fi
    fi
    
    # Method 4: Clone the repository if not successful yet
    if [ "$success" = false ] && [ $attempt -lt $max_attempts ]; then
        attempt=$((attempt+1))
        log_message "${YELLOW}Downloading VPS Manager script (Attempt $attempt/$max_attempts)...${NC}"
        log_message "${BLUE}Using git clone method...${NC}"
        git clone https://github.com/Lenagitpus/scriptuneling.git "$temp_dir/repo" >> $LOG_FILE 2>&1
        if [ $? -eq 0 ]; then
            cp "$temp_dir/repo/vps_manager.sh" "$temp_dir/vps_manager.sh" >> $LOG_FILE 2>&1
            success=true
        fi
    fi
    
    # Check if any download method was successful
    if [ "$success" = true ]; then
        # Verify the downloaded file
        if [ -f "$temp_dir/vps_manager.sh" ] && [ -s "$temp_dir/vps_manager.sh" ]; then
            log_message "${GREEN}Successfully downloaded VPS Manager script${NC}"
            
            # Install the script
            cp "$temp_dir/vps_manager.sh" /usr/local/bin/vps_manager >> $LOG_FILE 2>&1
            chmod +x /usr/local/bin/vps_manager >> $LOG_FILE 2>&1
            
            # Verify installation
            if [ -f "/usr/local/bin/vps_manager" ] && [ -x "/usr/local/bin/vps_manager" ]; then
                log_message "${GREEN}Successfully installed VPS Manager script${NC}"
                rm -rf "$temp_dir"
                return 0
            else
                log_message "${RED}Failed to install VPS Manager script${NC}"
                rm -rf "$temp_dir"
                return 1
            fi
        else
            log_message "${RED}Downloaded file is invalid or empty${NC}"
            rm -rf "$temp_dir"
            return 1
        fi
    else
        log_message "${RED}All download methods failed${NC}"
        rm -rf "$temp_dir"
        return 1
    fi
}

# Download and install VPS Manager
log_message "${YELLOW}Installing VPS Manager...${NC}"
download_vps_manager
if ! check_success "Downloaded and installed VPS Manager"; then
    log_message "${RED}Installation failed. Please check the log file: $LOG_FILE${NC}"
    exit 1
fi

# Create systemd service
log_message "${YELLOW}Creating systemd service...${NC}"
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
check_success "Created systemd service"

# Create auto-start script
log_message "${YELLOW}Creating auto-start configuration...${NC}"
cat > /etc/profile.d/vps_manager.sh << EOF
#!/bin/bash
if [ "\$(id -u)" -eq 0 ]; then
    echo "Starting VPS Manager..."
    /bin/bash /usr/local/bin/vps_manager
fi
EOF

chmod +x /etc/profile.d/vps_manager.sh
check_success "Created auto-start configuration"

# Setup Cloudflare WebSocket support
log_message "${YELLOW}Setting up Cloudflare WebSocket support...${NC}"

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
check_success "Created WebSocket proxy script"

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
check_success "Created WebSocket proxy service"

# Enable and start services
log_message "${YELLOW}Enabling and starting services...${NC}"
systemctl daemon-reload
check_success "Reloaded systemd configuration"

systemctl enable vps_manager.service
check_success "Enabled VPS Manager service"

systemctl enable ws-epro.service
check_success "Enabled WebSocket proxy service"

systemctl start ws-epro.service
check_success "Started WebSocket proxy service"

# Get domain name
log_message "${YELLOW}Please enter your domain name:${NC}"
read -r domain_name

# Save domain to config
echo "DOMAIN=&quot;$domain_name&quot;" > /etc/vps_manager/config.conf
check_success "Saved domain configuration"

# Final verification
log_message "${YELLOW}Performing final verification...${NC}"

# Check if VPS Manager script exists and is executable
if [ ! -f "/usr/local/bin/vps_manager" ]; then
    log_message "${RED}ERROR: VPS Manager script not found at /usr/local/bin/vps_manager${NC}"
    log_message "${YELLOW}Attempting to fix...${NC}"
    
    # Try one more time with direct download
    curl -s https://raw.githubusercontent.com/Lenagitpus/scriptuneling/main/vps_manager.sh -o /usr/local/bin/vps_manager
    chmod +x /usr/local/bin/vps_manager
    
    if [ -f "/usr/local/bin/vps_manager" ] && [ -x "/usr/local/bin/vps_manager" ]; then
        log_message "${GREEN}Successfully fixed VPS Manager installation${NC}"
    else
        log_message "${RED}Failed to fix VPS Manager installation. Please install manually.${NC}"
        log_message "${YELLOW}Manual installation command:${NC}"
        log_message "curl -s https://raw.githubusercontent.com/Lenagitpus/scriptuneling/main/vps_manager.sh -o /usr/local/bin/vps_manager && chmod +x /usr/local/bin/vps_manager"
        exit 1
    fi
fi

# Display success message
log_message "${GREEN}┏━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┓${NC}"
log_message "${GREEN}┃            VPS MANAGER INSTALLED SUCCESSFULLY              ┃${NC}"
log_message "${GREEN}┗━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┛${NC}"
log_message "${YELLOW}To start VPS Manager, run:${NC} vps_manager"
log_message "${YELLOW}VPS Manager will also start automatically on next login.${NC}"
log_message "${YELLOW}Domain has been set to:${NC} $domain_name"
log_message "${YELLOW}Installation log saved to:${NC} $LOG_FILE"

# Start VPS Manager
log_message "${YELLOW}Starting VPS Manager...${NC}"
/usr/local/bin/vps_manager
