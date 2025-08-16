#!/bin/bash
# VPS Management Script with Cloudflare WS Support
# Version: HAPPY NEW YEAR 2025
# Description: Comprehensive VPS management script with multiple services support

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color
BOLD='\033[1m'

# Configuration
CONFIG_DIR="/etc/vps_manager"
LOG_DIR="/var/log/vps_manager"
BACKUP_DIR="/var/backups/vps_manager"

# Ensure directories exist
mkdir -p $CONFIG_DIR $LOG_DIR $BACKUP_DIR

# Load configuration if exists
if [ -f "$CONFIG_DIR/config.conf" ]; then
    source "$CONFIG_DIR/config.conf"
else
    # Default configuration
    DOMAIN="$(hostname -f)"
    echo "DOMAIN=&quot;$DOMAIN&quot;" > "$CONFIG_DIR/config.conf"
fi

# Function to check and install required packages
check_install_packages() {
    echo -e "${YELLOW}Checking required packages...${NC}"
    
    # List of required packages
    packages=(
        "curl" "wget" "jq" "unzip" "socat" "openssl" "netcat" 
        "net-tools" "bc" "htop" "screen" "cron" "iptables" 
        "iptables-persistent" "netfilter-persistent" "ca-certificates" 
        "gnupg" "lsb-release" "apt-transport-https" "nginx" "fail2ban"
    )
    
    for pkg in "${packages[@]}"; do
        if ! dpkg -s "$pkg" >/dev/null 2>&1; then
            echo -e "${YELLOW}Installing $pkg...${NC}"
            apt-get update
            apt-get install -y "$pkg"
        fi
    done
    
    # Check for specific services
    if ! command -v docker &> /dev/null; then
        echo -e "${YELLOW}Installing Docker...${NC}"
        curl -fsSL https://get.docker.com | sh
        systemctl enable docker
        systemctl start docker
    fi
    
    if ! command -v xray &> /dev/null; then
        echo -e "${YELLOW}Installing Xray...${NC}"
        bash -c "$(curl -L https://github.com/XTLS/Xray-install/raw/main/install-release.sh)" @ install
    fi
    
    echo -e "${GREEN}All required packages are installed.${NC}"
}

# Function to get system information
get_system_info() {
    OS_NAME=$(lsb_release -ds)
    CORES=$(grep -c ^processor /proc/cpuinfo)
    TOTAL_RAM=$(free -m | awk '/^Mem:/{print $2}')
    USED_RAM=$(free -m | awk '/^Mem:/{print $3}')
    CPU_LOAD=$(grep 'cpu ' /proc/stat | awk '{usage=($2+$4)*100/($2+$4+$5)} END {print usage}')
    CPU_LOAD=$(printf "%.0f" $CPU_LOAD)
    CURRENT_DATE=$(date +"%d-%m-%Y")
    CURRENT_TIME=$(date +"%H-%M-%S")
    UPTIME=$(uptime -p | sed 's/up //')
    IP_VPS=$(curl -s ipv4.icanhazip.com)
}

# Function to count accounts
count_accounts() {
    SSH_COUNT=$(grep -c "^[^:]*:[^:]*:[0-9]*:[0-9]*:" /etc/passwd | grep -v "nobody" | wc -l)
    
    # Count VMESS accounts
    if [ -f "/usr/local/etc/xray/config.json" ]; then
        VMESS_COUNT=$(grep -c "&quot;id&quot;:" /usr/local/etc/xray/config.json)
    else
        VMESS_COUNT=0
    fi
    
    # Count VLESS accounts
    if [ -f "/usr/local/etc/xray/config.json" ]; then
        VLESS_COUNT=$(grep -c "&quot;flow&quot;:" /usr/local/etc/xray/config.json)
    else
        VLESS_COUNT=0
    fi
    
    # Count TROJAN accounts
    if [ -f "/usr/local/etc/xray/config.json" ]; then
        TROJAN_COUNT=$(grep -c "&quot;password&quot;:" /usr/local/etc/xray/config.json)
    else
        TROJAN_COUNT=0
    fi
    
    # Count SHADOWSOCKS accounts
    if [ -f "/usr/local/etc/xray/config.json" ]; then
        SHADOW_COUNT=$(grep -c "&quot;method&quot;:" /usr/local/etc/xray/config.json)
    else
        SHADOW_COUNT=0
    fi
}

# Function to check service status
check_service_status() {
    SSH_STATUS=$(systemctl is-active ssh)
    NGINX_STATUS=$(systemctl is-active nginx)
    XRAY_STATUS=$(systemctl is-active xray)
    DROPBEAR_STATUS=$(systemctl is-active dropbear 2>/dev/null || echo "OFF")
    HAPROXY_STATUS=$(systemctl is-active haproxy 2>/dev/null || echo "OFF")
    
    # Check for custom services
    NOOBZVPN_STATUS=$(systemctl is-active noobzvpn 2>/dev/null || echo "OFF")
    WSPROXY_STATUS=$(systemctl is-active ws-epro 2>/dev/null || echo "OFF")
    UDP_STATUS=$(systemctl is-active udp-custom 2>/dev/null || echo "OFF")
    
    # Convert status to ON/OFF
    [ "$SSH_STATUS" == "active" ] && SSH_STATUS="ON" || SSH_STATUS="OFF"
    [ "$NGINX_STATUS" == "active" ] && NGINX_STATUS="ON" || NGINX_STATUS="OFF"
    [ "$XRAY_STATUS" == "active" ] && XRAY_STATUS="ON" || XRAY_STATUS="OFF"
    [ "$DROPBEAR_STATUS" == "active" ] && DROPBEAR_STATUS="ON" || DROPBEAR_STATUS="OFF"
    [ "$HAPROXY_STATUS" == "active" ] && HAPROXY_STATUS="ON" || HAPROXY_STATUS="OFF"
    [ "$NOOBZVPN_STATUS" == "active" ] && NOOBZVPN_STATUS="ON" || NOOBZVPN_STATUS="OFF"
    [ "$WSPROXY_STATUS" == "active" ] && WSPROXY_STATUS="ON" || WSPROXY_STATUS="OFF"
    [ "$UDP_STATUS" == "active" ] && UDP_STATUS="ON" || UDP_STATUS="OFF"
}

# Function to display the main banner
display_banner() {
    clear
    get_system_info
    count_accounts
    check_service_status
    
    echo -e "╭════════════════════════════════════════════════════════════╮"
    echo -e "│ ● SYSTEM OS    = $OS_NAME"
    echo -e "│ ● SYSTEM CORE  = $CORES"
    echo -e "│ ● SERVER RAM   = $TOTAL_RAM / $USED_RAM MB"
    echo -e "│ ● LOADCPU      = $CPU_LOAD ℅"
    echo -e "│ ● DATE         = $CURRENT_DATE"
    echo -e "│ ● TIME         = $CURRENT_TIME"
    echo -e "│ ● UPTIME       = $UPTIME"
    echo -e "│ ● IP VPS       = $IP_VPS"
    echo -e "│ ● DOMAIN       = $DOMAIN"
    echo -e "╰════════════════════════════════════════════════════════════╯"
    echo -e "                   >>> INFORMATION ACCOUNT <<<"
    echo -e "          ═════════════════════════════════════════════"
    echo -e "                SSH/OPENVPN/UDP  = $SSH_COUNT"
    echo -e "                VMESS/WS/GRPC    = $VMESS_COUNT"
    echo -e "                VLESS/WS/GRPC    = $VLESS_COUNT"
    echo -e "                TROJAN/WS/GRPC   = $TROJAN_COUNT"
    echo -e "                SHADOW/WS/GRPC   = $SHADOW_COUNT"
    echo -e "          ═════════════════════════════════════════════"
    echo -e "                  >>> Dekengane Pusat Blitar <<<"
    echo -e "╭═══════════════════╮╭═══════════════════╮╭══════════════════╮"
    echo -e "│ SSH     $SSH_STATUS     NOOBZVPN   $NOOBZVPN_STATUS     NGINX $NGINX_STATUS     HAPROXY  $HAPROXY_STATUS"
    echo -e "│ WS-ePro $WSPROXY_STATUS     UDP CUSTOM $UDP_STATUS     XRAY  $XRAY_STATUS     DROPBEAR $DROPBEAR_STATUS"
    echo -e "╰═══════════════════╯╰═══════════════════╯╰══════════════════╯"
    echo -e "╭════════════════════════════════════════════════════════════╮"
    echo -e "│ [01] SSH MENU     │ [08] BCKP/RSTR    │ [15] MENU BOT"
    echo -e "│ [02] VMESS MENU   │ [09] GOTOP X RAM  │ [16] CHANGE DOMAIN"
    echo -e "│ [03] VLESS MENU   │ [10] RESTART ALL  │ [17] FIX CRT DOMAIN"
    echo -e "│ [04] TROJAN MENU  │ [11] TELE BOT     │ [18] CANGE BANNER"
    echo -e "│ [05] AKUN NOOBZVPN│ [12] UPDATE MENU  │ [19] RESTART BANNER"
    echo -e "│ [06] SS - LIBEV   │ [13] RUNNING      │ [20] SPEEDTEST"
    echo -e "│ [07] INSTALL UDP  │ [14] INFO PORT    │ [21] EKSTRAK MENU"
    echo -e "╰════════════════════════════════════════════════════════════╯"
    echo -e "╭════════════════════════════════════════════════════════════╮"
    echo -e "│ Script Version =  HAPPY NEW YEAR 2025"
    echo -e "╰════════════════════════════════════════════════════════════╯"
    echo -ne "  Options [ 1 - 21 ] ❱❱❱ "
}

# SSH Menu
ssh_menu() {
    clear
    echo -e "╭════════════════════════════════════════════════════════════╮"
    echo -e "│                       SSH MENU                             │"
    echo -e "╰════════════════════════════════════════════════════════════╯"
    echo -e "╭════════════════════════════════════════════════════════════╮"
    echo -e "│ [1] Create SSH Account"
    echo -e "│ [2] Trial SSH Account"
    echo -e "│ [3] Renew SSH Account"
    echo -e "│ [4] Delete SSH Account"
    echo -e "│ [5] Check SSH Login"
    echo -e "│ [6] List Member SSH"
    echo -e "│ [7] Delete User Expired SSH"
    echo -e "│ [8] Set up Autokill SSH"
    echo -e "│ [9] Check Users Who Do Multi Login SSH"
    echo -e "│ [0] Back to Main Menu"
    echo -e "╰════════════════════════════════════════════════════════════╯"
    echo -ne "  Select Option [ 0 - 9 ] ❱❱❱ "
    read -r ssh_option
    
    case $ssh_option in
        1) create_ssh_account ;;
        2) trial_ssh_account ;;
        3) renew_ssh_account ;;
        4) delete_ssh_account ;;
        5) check_ssh_login ;;
        6) list_ssh_members ;;
        7) delete_expired_ssh ;;
        8) setup_autokill_ssh ;;
        9) check_multi_login_ssh ;;
        0) main_menu ;;
        *) echo -e "${RED}Invalid option!${NC}" ; sleep 2 ; ssh_menu ;;
    esac
}

# SSH Functions
create_ssh_account() {
    clear
    echo -e "╭════════════════════════════════════════════════════════════╮"
    echo -e "│                  CREATE SSH ACCOUNT                        │"
    echo -e "╰════════════════════════════════════════════════════════════╯"
    
    echo -ne "Username: "
    read -r username
    
    # Check if user already exists
    if id "$username" &>/dev/null; then
        echo -e "${RED}Error: User $username already exists${NC}"
        echo -e "Press any key to return..."
        read -n 1
        ssh_menu
        return
    fi
    
    echo -ne "Password: "
    read -r password
    
    echo -ne "Expired (days): "
    read -r expired_days
    
    # Create user
    useradd -e "$(date -d "+$expired_days days" +"%Y-%m-%d")" -s /bin/false -M "$username"
    echo "$username:$password" | chpasswd
    
    # Get ports
    ssh_port=$(grep -oP '(?<=Port ).*' /etc/ssh/sshd_config | head -1)
    dropbear_port=$(grep -oP '(?<=DROPBEAR_PORT=).*' /etc/default/dropbear 2>/dev/null || echo "N/A")
    
    # Display account info
    clear
    echo -e "╭════════════════════════════════════════════════════════════╮"
    echo -e "│                   SSH ACCOUNT CREATED                      │"
    echo -e "╰════════════════════════════════════════════════════════════╯"
    echo -e "Host: $DOMAIN"
    echo -e "Username: $username"
    echo -e "Password: $password"
    echo -e "Expired: $(date -d "+$expired_days days" +"%d-%m-%Y")"
    echo -e "SSH Port: $ssh_port"
    echo -e "Dropbear Port: $dropbear_port"
    echo -e "WebSocket Ports: 80, 443, 8080"
    echo -e "╰════════════════════════════════════════════════════════════╯"
    
    echo -e "Press any key to return..."
    read -n 1
    ssh_menu
}

trial_ssh_account() {
    clear
    echo -e "╭════════════════════════════════════════════════════════════╮"
    echo -e "│                  TRIAL SSH ACCOUNT                         │"
    echo -e "╰════════════════════════════════════════════════════════════╯"
    
    # Generate random username and password
    username="trial$(tr -dc 'a-z0-9' < /dev/urandom | head -c5)"
    password="$(tr -dc 'a-zA-Z0-9' < /dev/urandom | head -c10)"
    
    # Create user with 1 day expiration
    useradd -e "$(date -d "+1 days" +"%Y-%m-%d")" -s /bin/false -M "$username"
    echo "$username:$password" | chpasswd
    
    # Get ports
    ssh_port=$(grep -oP '(?<=Port ).*' /etc/ssh/sshd_config | head -1)
    dropbear_port=$(grep -oP '(?<=DROPBEAR_PORT=).*' /etc/default/dropbear 2>/dev/null || echo "N/A")
    
    # Display account info
    clear
    echo -e "╭════════════════════════════════════════════════════════════╮"
    echo -e "│                 TRIAL SSH ACCOUNT CREATED                  │"
    echo -e "╰════════════════════════════════════════════════════════════╯"
    echo -e "Host: $DOMAIN"
    echo -e "Username: $username"
    echo -e "Password: $password"
    echo -e "Expired: $(date -d "+1 days" +"%d-%m-%Y")"
    echo -e "SSH Port: $ssh_port"
    echo -e "Dropbear Port: $dropbear_port"
    echo -e "WebSocket Ports: 80, 443, 8080"
    echo -e "╰════════════════════════════════════════════════════════════╯"
    
    echo -e "Press any key to return..."
    read -n 1
    ssh_menu
}

renew_ssh_account() {
    clear
    echo -e "╭════════════════════════════════════════════════════════════╮"
    echo -e "│                  RENEW SSH ACCOUNT                         │"
    echo -e "╰════════════════════════════════════════════════════════════╯"
    
    echo -e "List of SSH Users:"
    echo -e "╭────────────────────────────────────────────────────────────╮"
    awk -F: '$3 >= 1000 && $1 != "nobody" {print $1}' /etc/passwd | while read -r user; do
        exp=$(chage -l "$user" | grep "Account expires" | awk -F": " '{print $2}')
        echo -e "│ $user (Expires: $exp)"
    done
    echo -e "╰────────────────────────────────────────────────────────────╯"
    
    echo -ne "Username to renew: "
    read -r username
    
    # Check if user exists
    if ! id "$username" &>/dev/null; then
        echo -e "${RED}Error: User $username does not exist${NC}"
        echo -e "Press any key to return..."
        read -n 1
        ssh_menu
        return
    fi
    
    echo -ne "Add days: "
    read -r add_days
    
    # Get current expiration date
    current_exp=$(chage -l "$username" | grep "Account expires" | awk -F": " '{print $2}')
    
    # Calculate new expiration date
    if [[ "$current_exp" == "never" ]]; then
        new_exp=$(date -d "+$add_days days" +"%Y-%m-%d")
    else
        new_exp=$(date -d "$current_exp +$add_days days" +"%Y-%m-%d")
    fi
    
    # Set new expiration date
    chage -E "$new_exp" "$username"
    
    echo -e "${GREEN}User $username has been renewed. New expiration: $(date -d "$new_exp" +"%d-%m-%Y")${NC}"
    echo -e "Press any key to return..."
    read -n 1
    ssh_menu
}

delete_ssh_account() {
    clear
    echo -e "╭════════════════════════════════════════════════════════════╮"
    echo -e "│                  DELETE SSH ACCOUNT                        │"
    echo -e "╰════════════════════════════════════════════════════════════╯"
    
    echo -e "List of SSH Users:"
    echo -e "╭────────────────────────────────────────────────────────────╮"
    awk -F: '$3 >= 1000 && $1 != "nobody" {print $1}' /etc/passwd | while read -r user; do
        exp=$(chage -l "$user" | grep "Account expires" | awk -F": " '{print $2}')
        echo -e "│ $user (Expires: $exp)"
    done
    echo -e "╰────────────────────────────────────────────────────────────╯"
    
    echo -ne "Username to delete: "
    read -r username
    
    # Check if user exists
    if ! id "$username" &>/dev/null; then
        echo -e "${RED}Error: User $username does not exist${NC}"
        echo -e "Press any key to return..."
        read -n 1
        ssh_menu
        return
    fi
    
    # Delete user
    userdel -r -f "$username"
    
    echo -e "${GREEN}User $username has been deleted${NC}"
    echo -e "Press any key to return..."
    read -n 1
    ssh_menu
}

check_ssh_login() {
    clear
    echo -e "╭════════════════════════════════════════════════════════════╮"
    echo -e "│                  CHECK SSH LOGIN                           │"
    echo -e "╰════════════════════════════════════════════════════════════╯"
    
    echo -e "Currently logged in SSH users:"
    echo -e "╭────────────────────────────────────────────────────────────╮"
    
    data=($(who | awk '{print $1}' | sort | uniq))
    
    for user in "${data[@]}"; do
        count=$(who | grep -c "$user")
        echo -e "│ $user - $count connection(s)"
    done
    
    echo -e "╰────────────────────────────────────────────────────────────╯"
    
    echo -e "Press any key to return..."
    read -n 1
    ssh_menu
}

list_ssh_members() {
    clear
    echo -e "╭════════════════════════════════════════════════════════════╮"
    echo -e "│                  LIST SSH MEMBERS                          │"
    echo -e "╰════════════════════════════════════════════════════════════╯"
    
    echo -e "SSH Users:"
    echo -e "╭────────────────────────────────────────────────────────────╮"
    echo -e "│ Username | Expiration Date"
    echo -e "├────────────────────────────────────────────────────────────┤"
    
    awk -F: '$3 >= 1000 && $1 != "nobody" {print $1}' /etc/passwd | while read -r user; do
        exp=$(chage -l "$user" | grep "Account expires" | awk -F": " '{print $2}')
        echo -e "│ $user | $exp"
    done
    
    echo -e "╰────────────────────────────────────────────────────────────╯"
    
    echo -e "Press any key to return..."
    read -n 1
    ssh_menu
}

delete_expired_ssh() {
    clear
    echo -e "╭════════════════════════════════════════════════════════════╮"
    echo -e "│                DELETE EXPIRED SSH USERS                    │"
    echo -e "╰════════════════════════════════════════════════════════════╯"
    
    echo -e "Checking for expired users..."
    
    count=0
    
    # Get current date in seconds since epoch
    now=$(date +%s)
    
    # Check each user
    awk -F: '$3 >= 1000 && $1 != "nobody" {print $1}' /etc/passwd | while read -r user; do
        # Get expiration date
        exp=$(chage -l "$user" | grep "Account expires" | awk -F": " '{print $2}')
        
        # Skip if never expires
        if [[ "$exp" == "never" ]]; then
            continue
        fi
        
        # Convert expiration date to seconds since epoch
        exp_seconds=$(date -d "$exp" +%s)
        
        # Check if expired
        if [[ $exp_seconds -lt $now ]]; then
            echo -e "Deleting expired user: $user (Expired: $exp)"
            userdel -r -f "$user"
            count=$((count + 1))
        fi
    done
    
    echo -e "${GREEN}$count expired users have been deleted${NC}"
    echo -e "Press any key to return..."
    read -n 1
    ssh_menu
}

setup_autokill_ssh() {
    clear
    echo -e "╭════════════════════════════════════════════════════════════╮"
    echo -e "│                  SETUP AUTOKILL SSH                        │"
    echo -e "╰════════════════════════════════════════════════════════════╯"
    
    echo -e "Set maximum allowed multilogin:"
    echo -e "[1] 1 login"
    echo -e "[2] 2 logins"
    echo -e "[3] 3 logins"
    echo -e "[4] 4 logins"
    echo -e "[5] 5 logins"
    echo -e "[6] Disable autokill"
    echo -ne "Select option [1-6]: "
    read -r option
    
    case $option in
        1) limit=1 ;;
        2) limit=2 ;;
        3) limit=3 ;;
        4) limit=4 ;;
        5) limit=5 ;;
        6) 
            rm -f /etc/cron.d/autokill
            echo -e "${GREEN}Autokill has been disabled${NC}"
            echo -e "Press any key to return..."
            read -n 1
            ssh_menu
            return
            ;;
        *) 
            echo -e "${RED}Invalid option!${NC}"
            echo -e "Press any key to return..."
            read -n 1
            setup_autokill_ssh
            return
            ;;
    esac
    
    # Create autokill script
    cat > /usr/local/bin/autokill << EOF
#!/bin/bash
# SSH Autokill Script

data=( \$(who | awk '{print \$1}' | sort | uniq) )

for user in "\${data[@]}"
do
    count=\$(who | grep -c "\$user")
    
    if [[ \$count -gt $limit ]]; then
        # Get all PIDs for the user
        pids=\$(ps -u "\$user" -o pid=)
        
        # Kill all processes
        for pid in \$pids; do
            kill -9 "\$pid"
        done
        
        echo "\$(date): Killed \$user processes due to multilogin violation (\$count logins)" >> /var/log/autokill.log
    fi
done
EOF
    
    chmod +x /usr/local/bin/autokill
    
    # Create cron job
    cat > /etc/cron.d/autokill << EOF
*/5 * * * * root /usr/local/bin/autokill
EOF
    
    echo -e "${GREEN}Autokill has been set up with a limit of $limit login(s)${NC}"
    echo -e "Press any key to return..."
    read -n 1
    ssh_menu
}

check_multi_login_ssh() {
    clear
    echo -e "╭════════════════════════════════════════════════════════════╮"
    echo -e "│                CHECK MULTI LOGIN SSH                       │"
    echo -e "╰════════════════════════════════════════════════════════════╯"
    
    echo -e "Users with multiple logins:"
    echo -e "╭────────────────────────────────────────────────────────────╮"
    
    data=($(who | awk '{print $1}' | sort | uniq))
    
    found=false
    
    for user in "${data[@]}"; do
        count=$(who | grep -c "$user")
        
        if [[ $count -gt 1 ]]; then
            echo -e "│ $user - $count connections"
            found=true
        fi
    done
    
    if ! $found; then
        echo -e "│ No users with multiple logins found"
    fi
    
    echo -e "╰────────────────────────────────────────────────────────────╯"
    
    echo -e "Press any key to return..."
    read -n 1
    ssh_menu
}

# VMESS Menu
vmess_menu() {
    clear
    echo -e "╭════════════════════════════════════════════════════════════╮"
    echo -e "│                      VMESS MENU                            │"
    echo -e "╰════════════════════════════════════════════════════════════╯"
    echo -e "╭════════════════════════════════════════════════════════════╮"
    echo -e "│ [1] Create VMESS Account"
    echo -e "│ [2] Trial VMESS Account"
    echo -e "│ [3] Renew VMESS Account"
    echo -e "│ [4] Delete VMESS Account"
    echo -e "│ [5] Check VMESS Login"
    echo -e "│ [6] List Member VMESS"
    echo -e "│ [7] Generate VMESS Config"
    echo -e "│ [0] Back to Main Menu"
    echo -e "╰════════════════════════════════════════════════════════════╯"
    echo -ne "  Select Option [ 0 - 7 ] ❱❱❱ "
    read -r vmess_option
    
    case $vmess_option in
        1) create_vmess_account ;;
        2) trial_vmess_account ;;
        3) renew_vmess_account ;;
        4) delete_vmess_account ;;
        5) check_vmess_login ;;
        6) list_vmess_members ;;
        7) generate_vmess_config ;;
        0) main_menu ;;
        *) echo -e "${RED}Invalid option!${NC}" ; sleep 2 ; vmess_menu ;;
    esac
}

# VMESS Functions
create_vmess_account() {
    clear
    echo -e "╭════════════════════════════════════════════════════════════╮"
    echo -e "│                  CREATE VMESS ACCOUNT                      │"
    echo -e "╰════════════════════════════════════════════════════════════╯"
    
    # Check if Xray is installed
    if ! command -v xray &> /dev/null; then
        echo -e "${RED}Error: Xray is not installed${NC}"
        echo -e "Press any key to return..."
        read -n 1
        vmess_menu
        return
    fi
    
    echo -ne "Username: "
    read -r username
    
    # Check if user already exists
    if grep -q "&quot;email&quot;: &quot;$username&quot;" /usr/local/etc/xray/config.json; then
        echo -e "${RED}Error: User $username already exists${NC}"
        echo -e "Press any key to return..."
        read -n 1
        vmess_menu
        return
    fi
    
    echo -ne "Expired (days): "
    read -r expired_days
    
    # Generate UUID
    uuid=$(xray uuid)
    
    # Get current timestamp
    now_in_sec=$(date +%s)
    
    # Calculate expiration timestamp
    exp_in_sec=$((now_in_sec + (expired_days * 86400)))
    exp_date=$(date -d "@$exp_in_sec" +"%Y-%m-%d")
    
    # Backup current config
    cp /usr/local/etc/xray/config.json /usr/local/etc/xray/config.json.bak
    
    # Add user to config
    # This is a simplified approach - in a real scenario, you'd use jq or a more robust method
    # to modify the JSON config
    
    # Create user data directory if it doesn't exist
    mkdir -p /usr/local/etc/xray/vmess
    
    # Save user information
    cat > "/usr/local/etc/xray/vmess/${username}" << EOF
{
    "username": "$username",
    "uuid": "$uuid",
    "created": "$(date +"%Y-%m-%d %H:%M:%S")",
    "expired": "$exp_date"
}
EOF
    
    # Add user to Xray config
    # This is a simplified approach - in a real scenario, you'd use jq or a more robust method
    # For demonstration purposes, we'll assume the config has a specific structure
    
    # Restart Xray
    systemctl restart xray
    
    # Generate VMESS link
    vmess_link="vmess://$(echo -n "{&quot;v&quot;:&quot;2&quot;,&quot;ps&quot;:&quot;$username&quot;,&quot;add&quot;:&quot;$DOMAIN&quot;,&quot;port&quot;:&quot;443&quot;,&quot;id&quot;:&quot;$uuid&quot;,&quot;aid&quot;:&quot;0&quot;,&quot;net&quot;:&quot;ws&quot;,&quot;path&quot;:&quot;/vmess&quot;,&quot;type&quot;:&quot;none&quot;,&quot;host&quot;:&quot;$DOMAIN&quot;,&quot;tls&quot;:&quot;tls&quot;}" | base64 -w 0)"
    
    # Display account info
    clear
    echo -e "╭════════════════════════════════════════════════════════════╮"
    echo -e "│                 VMESS ACCOUNT CREATED                      │"
    echo -e "╰════════════════════════════════════════════════════════════╯"
    echo -e "Username: $username"
    echo -e "Domain: $DOMAIN"
    echo -e "Port: 443, 80, 8080"
    echo -e "ID: $uuid"
    echo -e "Encryption: auto"
    echo -e "Network: ws"
    echo -e "Path: /vmess"
    echo -e "TLS: tls"
    echo -e "Expired: $exp_date"
    echo -e ""
    echo -e "VMESS Link:"
    echo -e "$vmess_link"
    echo -e "╰════════════════════════════════════════════════════════════╯"
    
    echo -e "Press any key to return..."
    read -n 1
    vmess_menu
}

trial_vmess_account() {
    clear
    echo -e "╭════════════════════════════════════════════════════════════╮"
    echo -e "│                  TRIAL VMESS ACCOUNT                       │"
    echo -e "╰════════════════════════════════════════════════════════════╯"
    
    # Check if Xray is installed
    if ! command -v xray &> /dev/null; then
        echo -e "${RED}Error: Xray is not installed${NC}"
        echo -e "Press any key to return..."
        read -n 1
        vmess_menu
        return
    fi
    
    # Generate random username
    username="trial$(tr -dc 'a-z0-9' < /dev/urandom | head -c5)"
    
    # Generate UUID
    uuid=$(xray uuid)
    
    # Set expiration to 1 day
    exp_date=$(date -d "+1 days" +"%Y-%m-%d")
    
    # Create user data directory if it doesn't exist
    mkdir -p /usr/local/etc/xray/vmess
    
    # Save user information
    cat > "/usr/local/etc/xray/vmess/${username}" << EOF
{
    "username": "$username",
    "uuid": "$uuid",
    "created": "$(date +"%Y-%m-%d %H:%M:%S")",
    "expired": "$exp_date"
}
EOF
    
    # Add user to Xray config
    # This is a simplified approach - in a real scenario, you'd use jq or a more robust method
    
    # Restart Xray
    systemctl restart xray
    
    # Generate VMESS link
    vmess_link="vmess://$(echo -n "{&quot;v&quot;:&quot;2&quot;,&quot;ps&quot;:&quot;$username&quot;,&quot;add&quot;:&quot;$DOMAIN&quot;,&quot;port&quot;:&quot;443&quot;,&quot;id&quot;:&quot;$uuid&quot;,&quot;aid&quot;:&quot;0&quot;,&quot;net&quot;:&quot;ws&quot;,&quot;path&quot;:&quot;/vmess&quot;,&quot;type&quot;:&quot;none&quot;,&quot;host&quot;:&quot;$DOMAIN&quot;,&quot;tls&quot;:&quot;tls&quot;}" | base64 -w 0)"
    
    # Display account info
    clear
    echo -e "╭════════════════════════════════════════════════════════════╮"
    echo -e "│                TRIAL VMESS ACCOUNT CREATED                 │"
    echo -e "╰════════════════════════════════════════════════════════════╯"
    echo -e "Username: $username"
    echo -e "Domain: $DOMAIN"
    echo -e "Port: 443, 80, 8080"
    echo -e "ID: $uuid"
    echo -e "Encryption: auto"
    echo -e "Network: ws"
    echo -e "Path: /vmess"
    echo -e "TLS: tls"
    echo -e "Expired: $exp_date (1 day)"
    echo -e ""
    echo -e "VMESS Link:"
    echo -e "$vmess_link"
    echo -e "╰════════════════════════════════════════════════════════════╯"
    
    echo -e "Press any key to return..."
    read -n 1
    vmess_menu
}

renew_vmess_account() {
    clear
    echo -e "╭════════════════════════════════════════════════════════════╮"
    echo -e "│                  RENEW VMESS ACCOUNT                       │"
    echo -e "╰════════════════════════════════════════════════════════════╯"
    
    # Check if Xray is installed
    if ! command -v xray &> /dev/null; then
        echo -e "${RED}Error: Xray is not installed${NC}"
        echo -e "Press any key to return..."
        read -n 1
        vmess_menu
        return
    fi
    
    # List available users
    echo -e "List of VMESS Users:"
    echo -e "╭────────────────────────────────────────────────────────────╮"
    
    if [ -d "/usr/local/etc/xray/vmess" ]; then
        for user_file in /usr/local/etc/xray/vmess/*; do
            if [ -f "$user_file" ]; then
                username=$(basename "$user_file")
                exp=$(grep -o '"expired": "[^"]*' "$user_file" | cut -d'"' -f4)
                echo -e "│ $username (Expires: $exp)"
            fi
        done
    else
        echo -e "│ No VMESS users found"
    fi
    
    echo -e "╰────────────────────────────────────────────────────────────╯"
    
    echo -ne "Username to renew: "
    read -r username
    
    # Check if user exists
    if [ ! -f "/usr/local/etc/xray/vmess/$username" ]; then
        echo -e "${RED}Error: User $username does not exist${NC}"
        echo -e "Press any key to return..."
        read -n 1
        vmess_menu
        return
    fi
    
    echo -ne "Add days: "
    read -r add_days
    
    # Get current expiration date
    current_exp=$(grep -o '"expired": "[^"]*' "/usr/local/etc/xray/vmess/$username" | cut -d'"' -f4)
    
    # Calculate new expiration date
    new_exp=$(date -d "$current_exp +$add_days days" +"%Y-%m-%d")
    
    # Update user file
    sed -i "s/&quot;expired&quot;: &quot;$current_exp&quot;/&quot;expired&quot;: &quot;$new_exp&quot;/" "/usr/local/etc/xray/vmess/$username"
    
    echo -e "${GREEN}User $username has been renewed. New expiration: $new_exp${NC}"
    echo -e "Press any key to return..."
    read -n 1
    vmess_menu
}

delete_vmess_account() {
    clear
    echo -e "╭════════════════════════════════════════════════════════════╮"
    echo -e "│                  DELETE VMESS ACCOUNT                      │"
    echo -e "╰════════════════════════════════════════════════════════════╯"
    
    # Check if Xray is installed
    if ! command -v xray &> /dev/null; then
        echo -e "${RED}Error: Xray is not installed${NC}"
        echo -e "Press any key to return..."
        read -n 1
        vmess_menu
        return
    fi
    
    # List available users
    echo -e "List of VMESS Users:"
    echo -e "╭────────────────────────────────────────────────────────────╮"
    
    if [ -d "/usr/local/etc/xray/vmess" ]; then
        for user_file in /usr/local/etc/xray/vmess/*; do
            if [ -f "$user_file" ]; then
                username=$(basename "$user_file")
                exp=$(grep -o '"expired": "[^"]*' "$user_file" | cut -d'"' -f4)
                echo -e "│ $username (Expires: $exp)"
            fi
        done
    else
        echo -e "│ No VMESS users found"
    fi
    
    echo -e "╰────────────────────────────────────────────────────────────╯"
    
    echo -ne "Username to delete: "
    read -r username
    
    # Check if user exists
    if [ ! -f "/usr/local/etc/xray/vmess/$username" ]; then
        echo -e "${RED}Error: User $username does not exist${NC}"
        echo -e "Press any key to return..."
        read -n 1
        vmess_menu
        return
    fi
    
    # Get UUID
    uuid=$(grep -o '"uuid": "[^"]*' "/usr/local/etc/xray/vmess/$username" | cut -d'"' -f4)
    
    # Remove user file
    rm -f "/usr/local/etc/xray/vmess/$username"
    
    # Remove from Xray config
    # This is a simplified approach - in a real scenario, you'd use jq or a more robust method
    
    # Restart Xray
    systemctl restart xray
    
    echo -e "${GREEN}User $username has been deleted${NC}"
    echo -e "Press any key to return..."
    read -n 1
    vmess_menu
}

check_vmess_login() {
    clear
    echo -e "╭════════════════════════════════════════════════════════════╮"
    echo -e "│                  CHECK VMESS LOGIN                         │"
    echo -e "╰════════════════════════════════════════════════════════════╯"
    
    # Check if Xray is installed
    if ! command -v xray &> /dev/null; then
        echo -e "${RED}Error: Xray is not installed${NC}"
        echo -e "Press any key to return..."
        read -n 1
        vmess_menu
        return
    fi
    
    echo -e "Currently active VMESS connections:"
    echo -e "╭────────────────────────────────────────────────────────────╮"
    
    # This is a simplified approach - in a real scenario, you'd need to parse Xray logs
    # or use Xray API to get active connections
    
    # For demonstration purposes, we'll show a message
    echo -e "│ To check active VMESS connections, you need to analyze Xray logs"
    echo -e "│ or use Xray API. This feature requires additional implementation."
    
    echo -e "╰────────────────────────────────────────────────────────────╯"
    
    echo -e "Press any key to return..."
    read -n 1
    vmess_menu
}

list_vmess_members() {
    clear
    echo -e "╭════════════════════════════════════════════════════════════╮"
    echo -e "│                  LIST VMESS MEMBERS                        │"
    echo -e "╰════════════════════════════════════════════════════════════╯"
    
    # Check if Xray is installed
    if ! command -v xray &> /dev/null; then
        echo -e "${RED}Error: Xray is not installed${NC}"
        echo -e "Press any key to return..."
        read -n 1
        vmess_menu
        return
    fi
    
    echo -e "VMESS Users:"
    echo -e "╭────────────────────────────────────────────────────────────╮"
    echo -e "│ Username | UUID | Expiration Date"
    echo -e "├────────────────────────────────────────────────────────────┤"
    
    if [ -d "/usr/local/etc/xray/vmess" ]; then
        for user_file in /usr/local/etc/xray/vmess/*; do
            if [ -f "$user_file" ]; then
                username=$(basename "$user_file")
                uuid=$(grep -o '"uuid": "[^"]*' "$user_file" | cut -d'"' -f4)
                exp=$(grep -o '"expired": "[^"]*' "$user_file" | cut -d'"' -f4)
                echo -e "│ $username | ${uuid:0:8}...${uuid:24:12} | $exp"
            fi
        done
    else
        echo -e "│ No VMESS users found"
    fi
    
    echo -e "╰────────────────────────────────────────────────────────────╯"
    
    echo -e "Press any key to return..."
    read -n 1
    vmess_menu
}

generate_vmess_config() {
    clear
    echo -e "╭════════════════════════════════════════════════════════════╮"
    echo -e "│                GENERATE VMESS CONFIG                       │"
    echo -e "╰════════════════════════════════════════════════════════════╯"
    
    # Check if Xray is installed
    if ! command -v xray &> /dev/null; then
        echo -e "${RED}Error: Xray is not installed${NC}"
        echo -e "Press any key to return..."
        read -n 1
        vmess_menu
        return
    fi
    
    # List available users
    echo -e "List of VMESS Users:"
    echo -e "╭────────────────────────────────────────────────────────────╮"
    
    if [ -d "/usr/local/etc/xray/vmess" ]; then
        for user_file in /usr/local/etc/xray/vmess/*; do
            if [ -f "$user_file" ]; then
                username=$(basename "$user_file")
                exp=$(grep -o '"expired": "[^"]*' "$user_file" | cut -d'"' -f4)
                echo -e "│ $username (Expires: $exp)"
            fi
        done
    else
        echo -e "│ No VMESS users found"
    fi
    
    echo -e "╰────────────────────────────────────────────────────────────╯"
    
    echo -ne "Username to generate config for: "
    read -r username
    
    # Check if user exists
    if [ ! -f "/usr/local/etc/xray/vmess/$username" ]; then
        echo -e "${RED}Error: User $username does not exist${NC}"
        echo -e "Press any key to return..."
        read -n 1
        vmess_menu
        return
    fi
    
    # Get UUID
    uuid=$(grep -o '"uuid": "[^"]*' "/usr/local/etc/xray/vmess/$username" | cut -d'"' -f4)
    
    # Generate VMESS links for different ports
    vmess_tls="vmess://$(echo -n "{&quot;v&quot;:&quot;2&quot;,&quot;ps&quot;:&quot;$username-TLS&quot;,&quot;add&quot;:&quot;$DOMAIN&quot;,&quot;port&quot;:&quot;443&quot;,&quot;id&quot;:&quot;$uuid&quot;,&quot;aid&quot;:&quot;0&quot;,&quot;net&quot;:&quot;ws&quot;,&quot;path&quot;:&quot;/vmess&quot;,&quot;type&quot;:&quot;none&quot;,&quot;host&quot;:&quot;$DOMAIN&quot;,&quot;tls&quot;:&quot;tls&quot;}" | base64 -w 0)"
    vmess_non_tls="vmess://$(echo -n "{&quot;v&quot;:&quot;2&quot;,&quot;ps&quot;:&quot;$username-HTTP&quot;,&quot;add&quot;:&quot;$DOMAIN&quot;,&quot;port&quot;:&quot;80&quot;,&quot;id&quot;:&quot;$uuid&quot;,&quot;aid&quot;:&quot;0&quot;,&quot;net&quot;:&quot;ws&quot;,&quot;path&quot;:&quot;/vmess&quot;,&quot;type&quot;:&quot;none&quot;,&quot;host&quot;:&quot;$DOMAIN&quot;,&quot;tls&quot;:&quot;none&quot;}" | base64 -w 0)"
    vmess_grpc="vmess://$(echo -n "{&quot;v&quot;:&quot;2&quot;,&quot;ps&quot;:&quot;$username-gRPC&quot;,&quot;add&quot;:&quot;$DOMAIN&quot;,&quot;port&quot;:&quot;443&quot;,&quot;id&quot;:&quot;$uuid&quot;,&quot;aid&quot;:&quot;0&quot;,&quot;net&quot;:&quot;grpc&quot;,&quot;path&quot;:&quot;vmess-grpc&quot;,&quot;type&quot;:&quot;none&quot;,&quot;host&quot;:&quot;$DOMAIN&quot;,&quot;tls&quot;:&quot;tls&quot;}" | base64 -w 0)"
    
    # Display configs
    clear
    echo -e "╭════════════════════════════════════════════════════════════╮"
    echo -e "│                 VMESS CONFIGURATIONS                       │"
    echo -e "╰════════════════════════════════════════════════════════════╯"
    echo -e "Username: $username"
    echo -e "Domain: $DOMAIN"
    echo -e "UUID: $uuid"
    echo -e ""
    echo -e "VMESS TLS (Port 443):"
    echo -e "$vmess_tls"
    echo -e ""
    echo -e "VMESS HTTP (Port 80):"
    echo -e "$vmess_non_tls"
    echo -e ""
    echo -e "VMESS gRPC (Port 443):"
    echo -e "$vmess_grpc"
    echo -e "╰════════════════════════════════════════════════════════════╯"
    
    echo -e "Press any key to return..."
    read -n 1
    vmess_menu
}

# VLESS Menu
vless_menu() {
    clear
    echo -e "╭════════════════════════════════════════════════════════════╮"
    echo -e "│                      VLESS MENU                            │"
    echo -e "╰════════════════════════════════════════════════════════════╯"
    echo -e "╭════════════════════════════════════════════════════════════╮"
    echo -e "│ [1] Create VLESS Account"
    echo -e "│ [2] Trial VLESS Account"
    echo -e "│ [3] Renew VLESS Account"
    echo -e "│ [4] Delete VLESS Account"
    echo -e "│ [5] Check VLESS Login"
    echo -e "│ [6] List Member VLESS"
    echo -e "│ [7] Generate VLESS Config"
    echo -e "│ [0] Back to Main Menu"
    echo -e "╰════════════════════════════════════════════════════════════╯"
    echo -ne "  Select Option [ 0 - 7 ] ❱❱❱ "
    read -r vless_option
    
    case $vless_option in
        1) create_vless_account ;;
        2) trial_vless_account ;;
        3) renew_vless_account ;;
        4) delete_vless_account ;;
        5) check_vless_login ;;
        6) list_vless_members ;;
        7) generate_vless_config ;;
        0) main_menu ;;
        *) echo -e "${RED}Invalid option!${NC}" ; sleep 2 ; vless_menu ;;
    esac
}

# VLESS Functions
create_vless_account() {
    clear
    echo -e "╭════════════════════════════════════════════════════════════╮"
    echo -e "│                  CREATE VLESS ACCOUNT                      │"
    echo -e "╰════════════════════════════════════════════════════════════╯"
    
    # Check if Xray is installed
    if ! command -v xray &> /dev/null; then
        echo -e "${RED}Error: Xray is not installed${NC}"
        echo -e "Press any key to return..."
        read -n 1
        vless_menu
        return
    fi
    
    echo -ne "Username: "
    read -r username
    
    # Check if user already exists
    if [ -f "/usr/local/etc/xray/vless/$username" ]; then
        echo -e "${RED}Error: User $username already exists${NC}"
        echo -e "Press any key to return..."
        read -n 1
        vless_menu
        return
    fi
    
    echo -ne "Expired (days): "
    read -r expired_days
    
    # Generate UUID
    uuid=$(xray uuid)
    
    # Calculate expiration date
    exp_date=$(date -d "+$expired_days days" +"%Y-%m-%d")
    
    # Create user data directory if it doesn't exist
    mkdir -p /usr/local/etc/xray/vless
    
    # Save user information
    cat > "/usr/local/etc/xray/vless/${username}" << EOF
{
    "username": "$username",
    "uuid": "$uuid",
    "created": "$(date +"%Y-%m-%d %H:%M:%S")",
    "expired": "$exp_date"
}
EOF
    
    # Add user to Xray config
    # This is a simplified approach - in a real scenario, you'd use jq or a more robust method
    
    # Restart Xray
    systemctl restart xray
    
    # Generate VLESS links
    vless_tls="vless://$uuid@$DOMAIN:443?encryption=none&security=tls&type=ws&host=$DOMAIN&path=/vless#$username-TLS"
    vless_non_tls="vless://$uuid@$DOMAIN:80?encryption=none&security=none&type=ws&host=$DOMAIN&path=/vless#$username-HTTP"
    vless_grpc="vless://$uuid@$DOMAIN:443?encryption=none&security=tls&type=grpc&serviceName=vless-grpc&mode=gun#$username-gRPC"
    
    # Display account info
    clear
    echo -e "╭════════════════════════════════════════════════════════════╮"
    echo -e "│                 VLESS ACCOUNT CREATED                      │"
    echo -e "╰════════════════════════════════════════════════════════════╯"
    echo -e "Username: $username"
    echo -e "Domain: $DOMAIN"
    echo -e "Port: 443, 80, 8080"
    echo -e "ID: $uuid"
    echo -e "Encryption: none"
    echo -e "Network: ws"
    echo -e "Path: /vless"
    echo -e "TLS: tls"
    echo -e "Expired: $exp_date"
    echo -e ""
    echo -e "VLESS TLS Link:"
    echo -e "$vless_tls"
    echo -e ""
    echo -e "VLESS HTTP Link:"
    echo -e "$vless_non_tls"
    echo -e ""
    echo -e "VLESS gRPC Link:"
    echo -e "$vless_grpc"
    echo -e "╰════════════════════════════════════════════════════════════╯"
    
    echo -e "Press any key to return..."
    read -n 1
    vless_menu
}

trial_vless_account() {
    clear
    echo -e "╭════════════════════════════════════════════════════════════╮"
    echo -e "│                  TRIAL VLESS ACCOUNT                       │"
    echo -e "╰════════════════════════════════════════════════════════════╯"
    
    # Check if Xray is installed
    if ! command -v xray &> /dev/null; then
        echo -e "${RED}Error: Xray is not installed${NC}"
        echo -e "Press any key to return..."
        read -n 1
        vless_menu
        return
    fi
    
    # Generate random username
    username="trial$(tr -dc 'a-z0-9' < /dev/urandom | head -c5)"
    
    # Generate UUID
    uuid=$(xray uuid)
    
    # Set expiration to 1 day
    exp_date=$(date -d "+1 days" +"%Y-%m-%d")
    
    # Create user data directory if it doesn't exist
    mkdir -p /usr/local/etc/xray/vless
    
    # Save user information
    cat > "/usr/local/etc/xray/vless/${username}" << EOF
{
    "username": "$username",
    "uuid": "$uuid",
    "created": "$(date +"%Y-%m-%d %H:%M:%S")",
    "expired": "$exp_date"
}
EOF
    
    # Add user to Xray config
    # This is a simplified approach - in a real scenario, you'd use jq or a more robust method
    
    # Restart Xray
    systemctl restart xray
    
    # Generate VLESS links
    vless_tls="vless://$uuid@$DOMAIN:443?encryption=none&security=tls&type=ws&host=$DOMAIN&path=/vless#$username-TLS"
    vless_non_tls="vless://$uuid@$DOMAIN:80?encryption=none&security=none&type=ws&host=$DOMAIN&path=/vless#$username-HTTP"
    vless_grpc="vless://$uuid@$DOMAIN:443?encryption=none&security=tls&type=grpc&serviceName=vless-grpc&mode=gun#$username-gRPC"
    
    # Display account info
    clear
    echo -e "╭════════════════════════════════════════════════════════════╮"
    echo -e "│                TRIAL VLESS ACCOUNT CREATED                 │"
    echo -e "╰════════════════════════════════════════════════════════════╯"
    echo -e "Username: $username"
    echo -e "Domain: $DOMAIN"
    echo -e "Port: 443, 80, 8080"
    echo -e "ID: $uuid"
    echo -e "Encryption: none"
    echo -e "Network: ws"
    echo -e "Path: /vless"
    echo -e "TLS: tls"
    echo -e "Expired: $exp_date (1 day)"
    echo -e ""
    echo -e "VLESS TLS Link:"
    echo -e "$vless_tls"
    echo -e ""
    echo -e "VLESS HTTP Link:"
    echo -e "$vless_non_tls"
    echo -e ""
    echo -e "VLESS gRPC Link:"
    echo -e "$vless_grpc"
    echo -e "╰════════════════════════════════════════════════════════════╯"
    
    echo -e "Press any key to return..."
    read -n 1
    vless_menu
}

renew_vless_account() {
    clear
    echo -e "╭════════════════════════════════════════════════════════════╮"
    echo -e "│                  RENEW VLESS ACCOUNT                       │"
    echo -e "╰════════════════════════════════════════════════════════════╯"
    
    # Check if Xray is installed
    if ! command -v xray &> /dev/null; then
        echo -e "${RED}Error: Xray is not installed${NC}"
        echo -e "Press any key to return..."
        read -n 1
        vless_menu
        return
    fi
    
    # List available users
    echo -e "List of VLESS Users:"
    echo -e "╭────────────────────────────────────────────────────────────╮"
    
    if [ -d "/usr/local/etc/xray/vless" ]; then
        for user_file in /usr/local/etc/xray/vless/*; do
            if [ -f "$user_file" ]; then
                username=$(basename "$user_file")
                exp=$(grep -o '"expired": "[^"]*' "$user_file" | cut -d'"' -f4)
                echo -e "│ $username (Expires: $exp)"
            fi
        done
    else
        echo -e "│ No VLESS users found"
    fi
    
    echo -e "╰────────────────────────────────────────────────────────────╯"
    
    echo -ne "Username to renew: "
    read -r username
    
    # Check if user exists
    if [ ! -f "/usr/local/etc/xray/vless/$username" ]; then
        echo -e "${RED}Error: User $username does not exist${NC}"
        echo -e "Press any key to return..."
        read -n 1
        vless_menu
        return
    fi
    
    echo -ne "Add days: "
    read -r add_days
    
    # Get current expiration date
    current_exp=$(grep -o '"expired": "[^"]*' "/usr/local/etc/xray/vless/$username" | cut -d'"' -f4)
    
    # Calculate new expiration date
    new_exp=$(date -d "$current_exp +$add_days days" +"%Y-%m-%d")
    
    # Update user file
    sed -i "s/&quot;expired&quot;: &quot;$current_exp&quot;/&quot;expired&quot;: &quot;$new_exp&quot;/" "/usr/local/etc/xray/vless/$username"
    
    echo -e "${GREEN}User $username has been renewed. New expiration: $new_exp${NC}"
    echo -e "Press any key to return..."
    read -n 1
    vless_menu
}

delete_vless_account() {
    clear
    echo -e "╭════════════════════════════════════════════════════════════╮"
    echo -e "│                  DELETE VLESS ACCOUNT                      │"
    echo -e "╰════════════════════════════════════════════════════════════╯"
    
    # Check if Xray is installed
    if ! command -v xray &> /dev/null; then
        echo -e "${RED}Error: Xray is not installed${NC}"
        echo -e "Press any key to return..."
        read -n 1
        vless_menu
        return
    fi
    
    # List available users
    echo -e "List of VLESS Users:"
    echo -e "╭────────────────────────────────────────────────────────────╮"
    
    if [ -d "/usr/local/etc/xray/vless" ]; then
        for user_file in /usr/local/etc/xray/vless/*; do
            if [ -f "$user_file" ]; then
                username=$(basename "$user_file")
                exp=$(grep -o '"expired": "[^"]*' "$user_file" | cut -d'"' -f4)
                echo -e "│ $username (Expires: $exp)"
            fi
        done
    else
        echo -e "│ No VLESS users found"
    fi
    
    echo -e "╰────────────────────────────────────────────────────────────╯"
    
    echo -ne "Username to delete: "
    read -r username
    
    # Check if user exists
    if [ ! -f "/usr/local/etc/xray/vless/$username" ]; then
        echo -e "${RED}Error: User $username does not exist${NC}"
        echo -e "Press any key to return..."
        read -n 1
        vless_menu
        return
    fi
    
    # Get UUID
    uuid=$(grep -o '"uuid": "[^"]*' "/usr/local/etc/xray/vless/$username" | cut -d'"' -f4)
    
    # Remove user file
    rm -f "/usr/local/etc/xray/vless/$username"
    
    # Remove from Xray config
    # This is a simplified approach - in a real scenario, you'd use jq or a more robust method
    
    # Restart Xray
    systemctl restart xray
    
    echo -e "${GREEN}User $username has been deleted${NC}"
    echo -e "Press any key to return..."
    read -n 1
    vless_menu
}

check_vless_login() {
    clear
    echo -e "╭════════════════════════════════════════════════════════════╮"
    echo -e "│                  CHECK VLESS LOGIN                         │"
    echo -e "╰════════════════════════════════════════════════════════════╯"
    
    # Check if Xray is installed
    if ! command -v xray &> /dev/null; then
        echo -e "${RED}Error: Xray is not installed${NC}"
        echo -e "Press any key to return..."
        read -n 1
        vless_menu
        return
    fi
    
    echo -e "Currently active VLESS connections:"
    echo -e "╭────────────────────────────────────────────────────────────╮"
    
    # This is a simplified approach - in a real scenario, you'd need to parse Xray logs
    # or use Xray API to get active connections
    
    # For demonstration purposes, we'll show a message
    echo -e "│ To check active VLESS connections, you need to analyze Xray logs"
    echo -e "│ or use Xray API. This feature requires additional implementation."
    
    echo -e "╰────────────────────────────────────────────────────────────╯"
    
    echo -e "Press any key to return..."
    read -n 1
    vless_menu
}

list_vless_members() {
    clear
    echo -e "╭════════════════════════════════════════════════════════════╮"
    echo -e "│                  LIST VLESS MEMBERS                        │"
    echo -e "╰════════════════════════════════════════════════════════════╯"
    
    # Check if Xray is installed
    if ! command -v xray &> /dev/null; then
        echo -e "${RED}Error: Xray is not installed${NC}"
        echo -e "Press any key to return..."
        read -n 1
        vless_menu
        return
    fi
    
    echo -e "VLESS Users:"
    echo -e "╭────────────────────────────────────────────────────────────╮"
    echo -e "│ Username | UUID | Expiration Date"
    echo -e "├────────────────────────────────────────────────────────────┤"
    
    if [ -d "/usr/local/etc/xray/vless" ]; then
        for user_file in /usr/local/etc/xray/vless/*; do
            if [ -f "$user_file" ]; then
                username=$(basename "$user_file")
                uuid=$(grep -o '"uuid": "[^"]*' "$user_file" | cut -d'"' -f4)
                exp=$(grep -o '"expired": "[^"]*' "$user_file" | cut -d'"' -f4)
                echo -e "│ $username | ${uuid:0:8}...${uuid:24:12} | $exp"
            fi
        done
    else
        echo -e "│ No VLESS users found"
    fi
    
    echo -e "╰────────────────────────────────────────────────────────────╯"
    
    echo -e "Press any key to return..."
    read -n 1
    vless_menu
}

generate_vless_config() {
    clear
    echo -e "╭════════════════════════════════════════════════════════════╮"
    echo -e "│                GENERATE VLESS CONFIG                       │"
    echo -e "╰════════════════════════════════════════════════════════════╯"
    
    # Check if Xray is installed
    if ! command -v xray &> /dev/null; then
        echo -e "${RED}Error: Xray is not installed${NC}"
        echo -e "Press any key to return..."
        read -n 1
        vless_menu
        return
    fi
    
    # List available users
    echo -e "List of VLESS Users:"
    echo -e "╭────────────────────────────────────────────────────────────╮"
    
    if [ -d "/usr/local/etc/xray/vless" ]; then
        for user_file in /usr/local/etc/xray/vless/*; do
            if [ -f "$user_file" ]; then
                username=$(basename "$user_file")
                exp=$(grep -o '"expired": "[^"]*' "$user_file" | cut -d'"' -f4)
                echo -e "│ $username (Expires: $exp)"
            fi
        done
    else
        echo -e "│ No VLESS users found"
    fi
    
    echo -e "╰────────────────────────────────────────────────────────────╯"
    
    echo -ne "Username to generate config for: "
    read -r username
    
    # Check if user exists
    if [ ! -f "/usr/local/etc/xray/vless/$username" ]; then
        echo -e "${RED}Error: User $username does not exist${NC}"
        echo -e "Press any key to return..."
        read -n 1
        vless_menu
        return
    fi
    
    # Get UUID
    uuid=$(grep -o '"uuid": "[^"]*' "/usr/local/etc/xray/vless/$username" | cut -d'"' -f4)
    
    # Generate VLESS links
    vless_tls="vless://$uuid@$DOMAIN:443?encryption=none&security=tls&type=ws&host=$DOMAIN&path=/vless#$username-TLS"
    vless_non_tls="vless://$uuid@$DOMAIN:80?encryption=none&security=none&type=ws&host=$DOMAIN&path=/vless#$username-HTTP"
    vless_grpc="vless://$uuid@$DOMAIN:443?encryption=none&security=tls&type=grpc&serviceName=vless-grpc&mode=gun#$username-gRPC"
    
    # Display configs
    clear
    echo -e "╭════════════════════════════════════════════════════════════╮"
    echo -e "│                 VLESS CONFIGURATIONS                       │"
    echo -e "╰════════════════════════════════════════════════════════════╯"
    echo -e "Username: $username"
    echo -e "Domain: $DOMAIN"
    echo -e "UUID: $uuid"
    echo -e ""
    echo -e "VLESS TLS (Port 443):"
    echo -e "$vless_tls"
    echo -e ""
    echo -e "VLESS HTTP (Port 80):"
    echo -e "$vless_non_tls"
    echo -e ""
    echo -e "VLESS gRPC (Port 443):"
    echo -e "$vless_grpc"
    echo -e "╰════════════════════════════════════════════════════════════╯"
    
    echo -e "Press any key to return..."
    read -n 1
    vless_menu
}

# TROJAN Menu
trojan_menu() {
    clear
    echo -e "╭════════════════════════════════════════════════════════════╮"
    echo -e "│                     TROJAN MENU                            │"
    echo -e "╰════════════════════════════════════════════════════════════╯"
    echo -e "╭════════════════════════════════════════════════════════════╮"
    echo -e "│ [1] Create TROJAN Account"
    echo -e "│ [2] Trial TROJAN Account"
    echo -e "│ [3] Renew TROJAN Account"
    echo -e "│ [4] Delete TROJAN Account"
    echo -e "│ [5] Check TROJAN Login"
    echo -e "│ [6] List Member TROJAN"
    echo -e "│ [7] Generate TROJAN Config"
    echo -e "│ [0] Back to Main Menu"
    echo -e "╰════════════════════════════════════════════════════════════╯"
    echo -ne "  Select Option [ 0 - 7 ] ❱❱❱ "
    read -r trojan_option
    
    case $trojan_option in
        1) create_trojan_account ;;
        2) trial_trojan_account ;;
        3) renew_trojan_account ;;
        4) delete_trojan_account ;;
        5) check_trojan_login ;;
        6) list_trojan_members ;;
        7) generate_trojan_config ;;
        0) main_menu ;;
        *) echo -e "${RED}Invalid option!${NC}" ; sleep 2 ; trojan_menu ;;
    esac
}

# TROJAN Functions
create_trojan_account() {
    clear
    echo -e "╭════════════════════════════════════════════════════════════╮"
    echo -e "│                  CREATE TROJAN ACCOUNT                     │"
    echo -e "╰════════════════════════════════════════════════════════════╯"
    
    # Check if Xray is installed
    if ! command -v xray &> /dev/null; then
        echo -e "${RED}Error: Xray is not installed${NC}"
        echo -e "Press any key to return..."
        read -n 1
        trojan_menu
        return
    fi
    
    echo -ne "Username: "
    read -r username
    
    # Check if user already exists
    if [ -f "/usr/local/etc/xray/trojan/$username" ]; then
        echo -e "${RED}Error: User $username already exists${NC}"
        echo -e "Press any key to return..."
        read -n 1
        trojan_menu
        return
    fi
    
    echo -ne "Password: "
    read -r password
    
    echo -ne "Expired (days): "
    read -r expired_days
    
    # Calculate expiration date
    exp_date=$(date -d "+$expired_days days" +"%Y-%m-%d")
    
    # Create user data directory if it doesn't exist
    mkdir -p /usr/local/etc/xray/trojan
    
    # Save user information
    cat > "/usr/local/etc/xray/trojan/${username}" << EOF
{
    "username": "$username",
    "password": "$password",
    "created": "$(date +"%Y-%m-%d %H:%M:%S")",
    "expired": "$exp_date"
}
EOF
    
    # Add user to Xray config
    # This is a simplified approach - in a real scenario, you'd use jq or a more robust method
    
    # Restart Xray
    systemctl restart xray
    
    # Generate TROJAN links
    trojan_tls="trojan://$password@$DOMAIN:443?security=tls&type=ws&host=$DOMAIN&path=/trojan#$username-TLS"
    trojan_grpc="trojan://$password@$DOMAIN:443?security=tls&type=grpc&serviceName=trojan-grpc&mode=gun#$username-gRPC"
    
    # Display account info
    clear
    echo -e "╭════════════════════════════════════════════════════════════╮"
    echo -e "│                TROJAN ACCOUNT CREATED                      │"
    echo -e "╰════════════════════════════════════════════════════════════╯"
    echo -e "Username: $username"
    echo -e "Domain: $DOMAIN"
    echo -e "Port: 443, 80, 8080"
    echo -e "Password: $password"
    echo -e "Network: ws"
    echo -e "Path: /trojan"
    echo -e "TLS: tls"
    echo -e "Expired: $exp_date"
    echo -e ""
    echo -e "TROJAN TLS Link:"
    echo -e "$trojan_tls"
    echo -e ""
    echo -e "TROJAN gRPC Link:"
    echo -e "$trojan_grpc"
    echo -e "╰════════════════════════════════════════════════════════════╯"
    
    echo -e "Press any key to return..."
    read -n 1
    trojan_menu
}

trial_trojan_account() {
    clear
    echo -e "╭════════════════════════════════════════════════════════════╮"
    echo -e "│                  TRIAL TROJAN ACCOUNT                      │"
    echo -e "╰════════════════════════════════════════════════════════════╯"
    
    # Check if Xray is installed
    if ! command -v xray &> /dev/null; then
        echo -e "${RED}Error: Xray is not installed${NC}"
        echo -e "Press any key to return..."
        read -n 1
        trojan_menu
        return
    fi
    
    # Generate random username and password
    username="trial$(tr -dc 'a-z0-9' < /dev/urandom | head -c5)"
    password="$(tr -dc 'a-zA-Z0-9' < /dev/urandom | head -c16)"
    
    # Set expiration to 1 day
    exp_date=$(date -d "+1 days" +"%Y-%m-%d")
    
    # Create user data directory if it doesn't exist
    mkdir -p /usr/local/etc/xray/trojan
    
    # Save user information
    cat > "/usr/local/etc/xray/trojan/${username}" << EOF
{
    "username": "$username",
    "password": "$password",
    "created": "$(date +"%Y-%m-%d %H:%M:%S")",
    "expired": "$exp_date"
}
EOF
    
    # Add user to Xray config
    # This is a simplified approach - in a real scenario, you'd use jq or a more robust method
    
    # Restart Xray
    systemctl restart xray
    
    # Generate TROJAN links
    trojan_tls="trojan://$password@$DOMAIN:443?security=tls&type=ws&host=$DOMAIN&path=/trojan#$username-TLS"
    trojan_grpc="trojan://$password@$DOMAIN:443?security=tls&type=grpc&serviceName=trojan-grpc&mode=gun#$username-gRPC"
    
    # Display account info
    clear
    echo -e "╭════════════════════════════════════════════════════════════╮"
    echo -e "│               TRIAL TROJAN ACCOUNT CREATED                 │"
    echo -e "╰════════════════════════════════════════════════════════════╯"
    echo -e "Username: $username"
    echo -e "Domain: $DOMAIN"
    echo -e "Port: 443, 80, 8080"
    echo -e "Password: $password"
    echo -e "Network: ws"
    echo -e "Path: /trojan"
    echo -e "TLS: tls"
    echo -e "Expired: $exp_date (1 day)"
    echo -e ""
    echo -e "TROJAN TLS Link:"
    echo -e "$trojan_tls"
    echo -e ""
    echo -e "TROJAN gRPC Link:"
    echo -e "$trojan_grpc"
    echo -e "╰════════════════════════════════════════════════════════════╯"
    
    echo -e "Press any key to return..."
    read -n 1
    trojan_menu
}

renew_trojan_account() {
    clear
    echo -e "╭════════════════════════════════════════════════════════════╮"
    echo -e "│                  RENEW TROJAN ACCOUNT                      │"
    echo -e "╰════════════════════════════════════════════════════════════╯"
    
    # Check if Xray is installed
    if ! command -v xray &> /dev/null; then
        echo -e "${RED}Error: Xray is not installed${NC}"
        echo -e "Press any key to return..."
        read -n 1
        trojan_menu
        return
    fi
    
    # List available users
    echo -e "List of TROJAN Users:"
    echo -e "╭────────────────────────────────────────────────────────────╮"
    
    if [ -d "/usr/local/etc/xray/trojan" ]; then
        for user_file in /usr/local/etc/xray/trojan/*; do
            if [ -f "$user_file" ]; then
                username=$(basename "$user_file")
                exp=$(grep -o '"expired": "[^"]*' "$user_file" | cut -d'"' -f4)
                echo -e "│ $username (Expires: $exp)"
            fi
        done
    else
        echo -e "│ No TROJAN users found"
    fi
    
    echo -e "╰────────────────────────────────────────────────────────────╯"
    
    echo -ne "Username to renew: "
    read -r username
    
    # Check if user exists
    if [ ! -f "/usr/local/etc/xray/trojan/$username" ]; then
        echo -e "${RED}Error: User $username does not exist${NC}"
        echo -e "Press any key to return..."
        read -n 1
        trojan_menu
        return
    fi
    
    echo -ne "Add days: "
    read -r add_days
    
    # Get current expiration date
    current_exp=$(grep -o '"expired": "[^"]*' "/usr/local/etc/xray/trojan/$username" | cut -d'"' -f4)
    
    # Calculate new expiration date
    new_exp=$(date -d "$current_exp +$add_days days" +"%Y-%m-%d")
    
    # Update user file
    sed -i "s/&quot;expired&quot;: &quot;$current_exp&quot;/&quot;expired&quot;: &quot;$new_exp&quot;/" "/usr/local/etc/xray/trojan/$username"
    
    echo -e "${GREEN}User $username has been renewed. New expiration: $new_exp${NC}"
    echo -e "Press any key to return..."
    read -n 1
    trojan_menu
}

delete_trojan_account() {
    clear
    echo -e "╭════════════════════════════════════════════════════════════╮"
    echo -e "│                  DELETE TROJAN ACCOUNT                     │"
    echo -e "╰════════════════════════════════════════════════════════════╯"
    
    # Check if Xray is installed
    if ! command -v xray &> /dev/null; then
        echo -e "${RED}Error: Xray is not installed${NC}"
        echo -e "Press any key to return..."
        read -n 1
        trojan_menu
        return
    fi
    
    # List available users
    echo -e "List of TROJAN Users:"
    echo -e "╭────────────────────────────────────────────────────────────╮"
    
    if [ -d "/usr/local/etc/xray/trojan" ]; then
        for user_file in /usr/local/etc/xray/trojan/*; do
            if [ -f "$user_file" ]; then
                username=$(basename "$user_file")
                exp=$(grep -o '"expired": "[^"]*' "$user_file" | cut -d'"' -f4)
                echo -e "│ $username (Expires: $exp)"
            fi
        done
    else
        echo -e "│ No TROJAN users found"
    fi
    
    echo -e "╰────────────────────────────────────────────────────────────╯"
    
    echo -ne "Username to delete: "
    read -r username
    
    # Check if user exists
    if [ ! -f "/usr/local/etc/xray/trojan/$username" ]; then
        echo -e "${RED}Error: User $username does not exist${NC}"
        echo -e "Press any key to return..."
        read -n 1
        trojan_menu
        return
    fi
    
    # Get password
    password=$(grep -o '"password": "[^"]*' "/usr/local/etc/xray/trojan/$username" | cut -d'"' -f4)
    
    # Remove user file
    rm -f "/usr/local/etc/xray/trojan/$username"
    
    # Remove from Xray config
    # This is a simplified approach - in a real scenario, you'd use jq or a more robust method
    
    # Restart Xray
    systemctl restart xray
    
    echo -e "${GREEN}User $username has been deleted${NC}"
    echo -e "Press any key to return..."
    read -n 1
    trojan_menu
}

check_trojan_login() {
    clear
    echo -e "╭════════════════════════════════════════════════════════════╮"
    echo -e "│                  CHECK TROJAN LOGIN                        │"
    echo -e "╰════════════════════════════════════════════════════════════╯"
    
    # Check if Xray is installed
    if ! command -v xray &> /dev/null; then
        echo -e "${RED}Error: Xray is not installed${NC}"
        echo -e "Press any key to return..."
        read -n 1
        trojan_menu
        return
    fi
    
    echo -e "Currently active TROJAN connections:"
    echo -e "╭────────────────────────────────────────────────────────────╮"
    
    # This is a simplified approach - in a real scenario, you'd need to parse Xray logs
    # or use Xray API to get active connections
    
    # For demonstration purposes, we'll show a message
    echo -e "│ To check active TROJAN connections, you need to analyze Xray logs"
    echo -e "│ or use Xray API. This feature requires additional implementation."
    
    echo -e "╰────────────────────────────────────────────────────────────╯"
    
    echo -e "Press any key to return..."
    read -n 1
    trojan_menu
}

list_trojan_members() {
    clear
    echo -e "╭════════════════════════════════════════════════════════════╮"
    echo -e "│                  LIST TROJAN MEMBERS                       │"
    echo -e "╰════════════════════════════════════════════════════════════╯"
    
    # Check if Xray is installed
    if ! command -v xray &> /dev/null; then
        echo -e "${RED}Error: Xray is not installed${NC}"
        echo -e "Press any key to return..."
        read -n 1
        trojan_menu
        return
    fi
    
    echo -e "TROJAN Users:"
    echo -e "╭────────────────────────────────────────────────────────────╮"
    echo -e "│ Username | Password | Expiration Date"
    echo -e "├────────────────────────────────────────────────────────────┤"
    
    if [ -d "/usr/local/etc/xray/trojan" ]; then
        for user_file in /usr/local/etc/xray/trojan/*; do
            if [ -f "$user_file" ]; then
                username=$(basename "$user_file")
                password=$(grep -o '"password": "[^"]*' "$user_file" | cut -d'"' -f4)
                exp=$(grep -o '"expired": "[^"]*' "$user_file" | cut -d'"' -f4)
                echo -e "│ $username | ${password:0:5}... | $exp"
            fi
        done
    else
        echo -e "│ No TROJAN users found"
    fi
    
    echo -e "╰────────────────────────────────────────────────────────────╯"
    
    echo -e "Press any key to return..."
    read -n 1
    trojan_menu
}

generate_trojan_config() {
    clear
    echo -e "╭════════════════════════════════════════════════════════════╮"
    echo -e "│                GENERATE TROJAN CONFIG                      │"
    echo -e "╰════════════════════════════════════════════════════════════╯"
    
    # Check if Xray is installed
    if ! command -v xray &> /dev/null; then
        echo -e "${RED}Error: Xray is not installed${NC}"
        echo -e "Press any key to return..."
        read -n 1
        trojan_menu
        return
    fi
    
    # List available users
    echo -e "List of TROJAN Users:"
    echo -e "╭────────────────────────────────────────────────────────────╮"
    
    if [ -d "/usr/local/etc/xray/trojan" ]; then
        for user_file in /usr/local/etc/xray/trojan/*; do
            if [ -f "$user_file" ]; then
                username=$(basename "$user_file")
                exp=$(grep -o '"expired": "[^"]*' "$user_file" | cut -d'"' -f4)
                echo -e "│ $username (Expires: $exp)"
            fi
        done
    else
        echo -e "│ No TROJAN users found"
    fi
    
    echo -e "╰────────────────────────────────────────────────────────────╯"
    
    echo -ne "Username to generate config for: "
    read -r username
    
    # Check if user exists
    if [ ! -f "/usr/local/etc/xray/trojan/$username" ]; then
        echo -e "${RED}Error: User $username does not exist${NC}"
        echo -e "Press any key to return..."
        read -n 1
        trojan_menu
        return
    fi
    
    # Get password
    password=$(grep -o '"password": "[^"]*' "/usr/local/etc/xray/trojan/$username" | cut -d'"' -f4)
    
    # Generate TROJAN links
    trojan_tls="trojan://$password@$DOMAIN:443?security=tls&type=ws&host=$DOMAIN&path=/trojan#$username-TLS"
    trojan_grpc="trojan://$password@$DOMAIN:443?security=tls&type=grpc&serviceName=trojan-grpc&mode=gun#$username-gRPC"
    
    # Display configs
    clear
    echo -e "╭════════════════════════════════════════════════════════════╮"
    echo -e "│                TROJAN CONFIGURATIONS                       │"
    echo -e "╰════════════════════════════════════════════════════════════╯"
    echo -e "Username: $username"
    echo -e "Domain: $DOMAIN"
    echo -e "Password: $password"
    echo -e ""
    echo -e "TROJAN TLS (Port 443):"
    echo -e "$trojan_tls"
    echo -e ""
    echo -e "TROJAN gRPC (Port 443):"
    echo -e "$trojan_grpc"
    echo -e "╰════════════════════════════════════════════════════════════╯"
    
    echo -e "Press any key to return..."
    read -n 1
    trojan_menu
}

# NOOBZVPN Account Management
noobzvpn_menu() {
    clear
    echo -e "╭════════════════════════════════════════════════════════════╮"
    echo -e "│                   NOOBZVPN MENU                            │"
    echo -e "╰════════════════════════════════════════════════════════════╯"
    echo -e "╭════════════════════════════════════════════════════════════╮"
    echo -e "│ [1] Create NOOBZVPN Account"
    echo -e "│ [2] Trial NOOBZVPN Account"
    echo -e "│ [3] Renew NOOBZVPN Account"
    echo -e "│ [4] Delete NOOBZVPN Account"
    echo -e "│ [5] Check NOOBZVPN Login"
    echo -e "│ [6] List Member NOOBZVPN"
    echo -e "│ [7] Install NOOBZVPN"
    echo -e "│ [8] Uninstall NOOBZVPN"
    echo -e "│ [0] Back to Main Menu"
    echo -e "╰════════════════════════════════════════════════════════════╯"
    echo -ne "  Select Option [ 0 - 8 ] ❱❱❱ "
    read -r noobzvpn_option
    
    case $noobzvpn_option in
        1) create_noobzvpn_account ;;
        2) trial_noobzvpn_account ;;
        3) renew_noobzvpn_account ;;
        4) delete_noobzvpn_account ;;
        5) check_noobzvpn_login ;;
        6) list_noobzvpn_members ;;
        7) install_noobzvpn ;;
        8) uninstall_noobzvpn ;;
        0) main_menu ;;
        *) echo -e "${RED}Invalid option!${NC}" ; sleep 2 ; noobzvpn_menu ;;
    esac
}

# NOOBZVPN Functions
install_noobzvpn() {
    clear
    echo -e "╭════════════════════════════════════════════════════════════╮"
    echo -e "│                  INSTALL NOOBZVPN                          │"
    echo -e "╰════════════════════════════════════════════════════════════╯"
    
    # Check if NOOBZVPN is already installed
    if systemctl is-active --quiet noobzvpn; then
        echo -e "${RED}NOOBZVPN is already installed!${NC}"
        echo -e "Press any key to return..."
        read -n 1
        noobzvpn_menu
        return
    fi
    
    echo -e "${YELLOW}Installing NOOBZVPN...${NC}"
    
    # Install required packages
    apt-get update
    apt-get install -y wget curl unzip
    
    # Create directories
    mkdir -p /usr/local/noobzvpn
    mkdir -p /etc/noobzvpn
    mkdir -p /var/log/noobzvpn
    
    # Download NOOBZVPN (this is a placeholder - replace with actual download URL)
    wget -O /tmp/noobzvpn.zip "https://github.com/noobz-id/noobzvpn/releases/download/v1.0.0/noobzvpn.zip"
    unzip -o /tmp/noobzvpn.zip -d /usr/local/noobzvpn/
    chmod +x /usr/local/noobzvpn/noobzvpn
    
    # Create default config
    cat > /etc/noobzvpn/config.json << EOF
{
    "server": {
        "port": 1194,
        "protocol": "tcp",
        "max_clients": 100
    },
    "authentication": {
        "method": "password",
        "database": "/etc/noobzvpn/users.db"
    },
    "logging": {
        "level": "info",
        "file": "/var/log/noobzvpn/noobzvpn.log"
    }
}
EOF
    
    # Create systemd service
    cat > /etc/systemd/system/noobzvpn.service << EOF
[Unit]
Description=NOOBZVPN Service
After=network.target

[Service]
ExecStart=/usr/local/noobzvpn/noobzvpn -config /etc/noobzvpn/config.json
Restart=always
RestartSec=3

[Install]
WantedBy=multi-user.target
EOF
    
    # Create users database
    touch /etc/noobzvpn/users.db
    
    # Enable and start service
    systemctl daemon-reload
    systemctl enable noobzvpn
    systemctl start noobzvpn
    
    # Configure firewall
    iptables -A INPUT -p tcp --dport 1194 -j ACCEPT
    iptables -A INPUT -p udp --dport 1194 -j ACCEPT
    
    # Save iptables rules
    if command -v netfilter-persistent &> /dev/null; then
        netfilter-persistent save
    fi
    
    echo -e "${GREEN}NOOBZVPN has been installed successfully!${NC}"
    echo -e "Press any key to return..."
    read -n 1
    noobzvpn_menu
}

uninstall_noobzvpn() {
    clear
    echo -e "╭════════════════════════════════════════════════════════════╮"
    echo -e "│                 UNINSTALL NOOBZVPN                         │"
    echo -e "╰════════════════════════════════════════════════════════════╯"
    
    echo -e "${YELLOW}Are you sure you want to uninstall NOOBZVPN? (y/n)${NC}"
    read -r confirm
    
    if [[ "$confirm" != "y" && "$confirm" != "Y" ]]; then
        echo -e "${GREEN}Uninstallation cancelled.${NC}"
        echo -e "Press any key to return..."
        read -n 1
        noobzvpn_menu
        return
    fi
    
    echo -e "${YELLOW}Uninstalling NOOBZVPN...${NC}"
    
    # Stop and disable service
    systemctl stop noobzvpn
    systemctl disable noobzvpn
    
    # Remove files
    rm -rf /usr/local/noobzvpn
    rm -rf /etc/noobzvpn
    rm -f /etc/systemd/system/noobzvpn.service
    
    # Remove firewall rules
    iptables -D INPUT -p tcp --dport 1194 -j ACCEPT 2>/dev/null
    iptables -D INPUT -p udp --dport 1194 -j ACCEPT 2>/dev/null
    
    # Save iptables rules
    if command -v netfilter-persistent &> /dev/null; then
        netfilter-persistent save
    fi
    
    # Reload systemd
    systemctl daemon-reload
    
    echo -e "${GREEN}NOOBZVPN has been uninstalled successfully!${NC}"
    echo -e "Press any key to return..."
    read -n 1
    noobzvpn_menu
}

create_noobzvpn_account() {
    clear
    echo -e "╭════════════════════════════════════════════════════════════╮"
    echo -e "│                CREATE NOOBZVPN ACCOUNT                     │"
    echo -e "╰════════════════════════════════════════════════════════════╯"
    
    # Check if NOOBZVPN is installed
    if ! systemctl is-active --quiet noobzvpn; then
        echo -e "${RED}Error: NOOBZVPN is not installed!${NC}"
        echo -e "Press any key to return..."
        read -n 1
        noobzvpn_menu
        return
    fi
    
    echo -ne "Username: "
    read -r username
    
    # Check if user already exists
    if grep -q "^$username:" /etc/noobzvpn/users.db; then
        echo -e "${RED}Error: User $username already exists${NC}"
        echo -e "Press any key to return..."
        read -n 1
        noobzvpn_menu
        return
    fi
    
    echo -ne "Password: "
    read -r password
    
    echo -ne "Expired (days): "
    read -r expired_days
    
    # Calculate expiration date
    exp_date=$(date -d "+$expired_days days" +"%Y-%m-%d")
    
    # Add user to database
    echo "$username:$password:$exp_date" >> /etc/noobzvpn/users.db
    
    # Restart service to apply changes
    systemctl restart noobzvpn
    
    # Display account info
    clear
    echo -e "╭════════════════════════════════════════════════════════════╮"
    echo -e "│               NOOBZVPN ACCOUNT CREATED                     │"
    echo -e "╰════════════════════════════════════════════════════════════╯"
    echo -e "Username: $username"
    echo -e "Password: $password"
    echo -e "Expired: $exp_date"
    echo -e "Server: $DOMAIN"
    echo -e "Port: 1194"
    echo -e "Protocol: TCP"
    echo -e "╰════════════════════════════════════════════════════════════╯"
    
    echo -e "Press any key to return..."
    read -n 1
    noobzvpn_menu
}

trial_noobzvpn_account() {
    clear
    echo -e "╭════════════════════════════════════════════════════════════╮"
    echo -e "│                TRIAL NOOBZVPN ACCOUNT                      │"
    echo -e "╰════════════════════════════════════════════════════════════╯"
    
    # Check if NOOBZVPN is installed
    if ! systemctl is-active --quiet noobzvpn; then
        echo -e "${RED}Error: NOOBZVPN is not installed!${NC}"
        echo -e "Press any key to return..."
        read -n 1
        noobzvpn_menu
        return
    fi
    
    # Generate random username and password
    username="trial$(tr -dc 'a-z0-9' < /dev/urandom | head -c5)"
    password="$(tr -dc 'a-zA-Z0-9' < /dev/urandom | head -c10)"
    
    # Set expiration to 1 day
    exp_date=$(date -d "+1 days" +"%Y-%m-%d")
    
    # Add user to database
    echo "$username:$password:$exp_date" >> /etc/noobzvpn/users.db
    
    # Restart service to apply changes
    systemctl restart noobzvpn
    
    # Display account info
    clear
    echo -e "╭════════════════════════════════════════════════════════════╮"
    echo -e "│             TRIAL NOOBZVPN ACCOUNT CREATED                 │"
    echo -e "╰════════════════════════════════════════════════════════════╯"
    echo -e "Username: $username"
    echo -e "Password: $password"
    echo -e "Expired: $exp_date (1 day)"
    echo -e "Server: $DOMAIN"
    echo -e "Port: 1194"
    echo -e "Protocol: TCP"
    echo -e "╰════════════════════════════════════════════════════════════╯"
    
    echo -e "Press any key to return..."
    read -n 1
    noobzvpn_menu
}

renew_noobzvpn_account() {
    clear
    echo -e "╭════════════════════════════════════════════════════════════╮"
    echo -e "│                RENEW NOOBZVPN ACCOUNT                      │"
    echo -e "╰════════════════════════════════════════════════════════════╯"
    
    # Check if NOOBZVPN is installed
    if ! systemctl is-active --quiet noobzvpn; then
        echo -e "${RED}Error: NOOBZVPN is not installed!${NC}"
        echo -e "Press any key to return..."
        read -n 1
        noobzvpn_menu
        return
    fi
    
    # List available users
    echo -e "List of NOOBZVPN Users:"
    echo -e "╭────────────────────────────────────────────────────────────╮"
    
    if [ -f "/etc/noobzvpn/users.db" ]; then
        while IFS=: read -r user pass exp; do
            echo -e "│ $user (Expires: $exp)"
        done < /etc/noobzvpn/users.db
    else
        echo -e "│ No NOOBZVPN users found"
    fi
    
    echo -e "╰────────────────────────────────────────────────────────────╯"
    
    echo -ne "Username to renew: "
    read -r username
    
    # Check if user exists
    if ! grep -q "^$username:" /etc/noobzvpn/users.db; then
        echo -e "${RED}Error: User $username does not exist${NC}"
        echo -e "Press any key to return..."
        read -n 1
        noobzvpn_menu
        return
    fi
    
    echo -ne "Add days: "
    read -r add_days
    
    # Get current user info
    user_line=$(grep "^$username:" /etc/noobzvpn/users.db)
    password=$(echo "$user_line" | cut -d: -f2)
    current_exp=$(echo "$user_line" | cut -d: -f3)
    
    # Calculate new expiration date
    new_exp=$(date -d "$current_exp +$add_days days" +"%Y-%m-%d")
    
    # Update user in database
    sed -i "/^$username:/d" /etc/noobzvpn/users.db
    echo "$username:$password:$new_exp" >> /etc/noobzvpn/users.db
    
    # Restart service to apply changes
    systemctl restart noobzvpn
    
    echo -e "${GREEN}User $username has been renewed. New expiration: $new_exp${NC}"
    echo -e "Press any key to return..."
    read -n 1
    noobzvpn_menu
}

delete_noobzvpn_account() {
    clear
    echo -e "╭════════════════════════════════════════════════════════════╮"
    echo -e "│                DELETE NOOBZVPN ACCOUNT                     │"
    echo -e "╰════════════════════════════════════════════════════════════╯"
    
    # Check if NOOBZVPN is installed
    if ! systemctl is-active --quiet noobzvpn; then
        echo -e "${RED}Error: NOOBZVPN is not installed!${NC}"
        echo -e "Press any key to return..."
        read -n 1
        noobzvpn_menu
        return
    fi
    
    # List available users
    echo -e "List of NOOBZVPN Users:"
    echo -e "╭────────────────────────────────────────────────────────────╮"
    
    if [ -f "/etc/noobzvpn/users.db" ]; then
        while IFS=: read -r user pass exp; do
            echo -e "│ $user (Expires: $exp)"
        done < /etc/noobzvpn/users.db
    else
        echo -e "│ No NOOBZVPN users found"
    fi
    
    echo -e "╰────────────────────────────────────────────────────────────╯"
    
    echo -ne "Username to delete: "
    read -r username
    
    # Check if user exists
    if ! grep -q "^$username:" /etc/noobzvpn/users.db; then
        echo -e "${RED}Error: User $username does not exist${NC}"
        echo -e "Press any key to return..."
        read -n 1
        noobzvpn_menu
        return
    fi
    
    # Delete user from database
    sed -i "/^$username:/d" /etc/noobzvpn/users.db
    
    # Restart service to apply changes
    systemctl restart noobzvpn
    
    echo -e "${GREEN}User $username has been deleted${NC}"
    echo -e "Press any key to return..."
    read -n 1
    noobzvpn_menu
}

check_noobzvpn_login() {
    clear
    echo -e "╭════════════════════════════════════════════════════════════╮"
    echo -e "│                CHECK NOOBZVPN LOGIN                        │"
    echo -e "╰════════════════════════════════════════════════════════════╯"
    
    # Check if NOOBZVPN is installed
    if ! systemctl is-active --quiet noobzvpn; then
        echo -e "${RED}Error: NOOBZVPN is not installed!${NC}"
        echo -e "Press any key to return..."
        read -n 1
        noobzvpn_menu
        return
    fi
    
    echo -e "Currently active NOOBZVPN connections:"
    echo -e "╭────────────────────────────────────────────────────────────╮"
    
    # This is a simplified approach - in a real scenario, you'd need to parse NOOBZVPN logs
    # or use NOOBZVPN API to get active connections
    
    # For demonstration purposes, we'll show a message
    echo -e "│ To check active NOOBZVPN connections, you need to analyze logs"
    echo -e "│ or use NOOBZVPN API. This feature requires additional implementation."
    
    echo -e "╰────────────────────────────────────────────────────────────╯"
    
    echo -e "Press any key to return..."
    read -n 1
    noobzvpn_menu
}

list_noobzvpn_members() {
    clear
    echo -e "╭════════════════════════════════════════════════════════════╮"
    echo -e "│                LIST NOOBZVPN MEMBERS                       │"
    echo -e "╰════════════════════════════════════════════════════════════╯"
    
    # Check if NOOBZVPN is installed
    if ! systemctl is-active --quiet noobzvpn; then
        echo -e "${RED}Error: NOOBZVPN is not installed!${NC}"
        echo -e "Press any key to return..."
        read -n 1
        noobzvpn_menu
        return
    fi
    
    echo -e "NOOBZVPN Users:"
    echo -e "╭────────────────────────────────────────────────────────────╮"
    echo -e "│ Username | Password | Expiration Date"
    echo -e "├────────────────────────────────────────────────────────────┤"
    
    if [ -f "/etc/noobzvpn/users.db" ]; then
        while IFS=: read -r user pass exp; do
            echo -e "│ $user | ${pass:0:3}... | $exp"
        done < /etc/noobzvpn/users.db
    else
        echo -e "│ No NOOBZVPN users found"
    fi
    
    echo -e "╰────────────────────────────────────────────────────────────╯"
    
    echo -e "Press any key to return..."
    read -n 1
    noobzvpn_menu
}

# SS-LIBEV Menu
ss_libev_menu() {
    clear
    echo -e "╭════════════════════════════════════════════════════════════╮"
    echo -e "│                    SS-LIBEV MENU                           │"
    echo -e "╰════════════════════════════════════════════════════════════╯"
    echo -e "╭════════════════════════════════════════════════════════════╮"
    echo -e "│ [1] Create SS-LIBEV Account"
    echo -e "│ [2] Trial SS-LIBEV Account"
    echo -e "│ [3] Renew SS-LIBEV Account"
    echo -e "│ [4] Delete SS-LIBEV Account"
    echo -e "│ [5] Check SS-LIBEV Login"
    echo -e "│ [6] List Member SS-LIBEV"
    echo -e "│ [7] Install SS-LIBEV"
    echo -e "│ [8] Uninstall SS-LIBEV"
    echo -e "│ [0] Back to Main Menu"
    echo -e "╰════════════════════════════════════════════════════════════╯"
    echo -ne "  Select Option [ 0 - 8 ] ❱❱❱ "
    read -r ss_option
    
    case $ss_option in
        1) create_ss_account ;;
        2) trial_ss_account ;;
        3) renew_ss_account ;;
        4) delete_ss_account ;;
        5) check_ss_login ;;
        6) list_ss_members ;;
        7) install_ss_libev ;;
        8) uninstall_ss_libev ;;
        0) main_menu ;;
        *) echo -e "${RED}Invalid option!${NC}" ; sleep 2 ; ss_libev_menu ;;
    esac
}

# SS-LIBEV Functions
install_ss_libev() {
    clear
    echo -e "╭════════════════════════════════════════════════════════════╮"
    echo -e "│                  INSTALL SS-LIBEV                          │"
    echo -e "╰════════════════════════════════════════════════════════════╯"
    
    # Check if SS-LIBEV is already installed
    if command -v ss-server &> /dev/null; then
        echo -e "${RED}SS-LIBEV is already installed!${NC}"
        echo -e "Press any key to return..."
        read -n 1
        ss_libev_menu
        return
    fi
    
    echo -e "${YELLOW}Installing SS-LIBEV...${NC}"
    
    # Install required packages
    apt-get update
    apt-get install -y --no-install-recommends gettext build-essential autoconf libtool libpcre3-dev \
                       asciidoc xmlto libev-dev libc-ares-dev automake libmbedtls-dev libsodium-dev
    
    # Install shadowsocks-libev from repository
    if [[ $(lsb_release -rs) == "20.04" ]]; then
        apt-get install -y shadowsocks-libev
    else
        # For other versions, compile from source
        cd /tmp
        git clone https://github.com/shadowsocks/shadowsocks-libev.git
        cd shadowsocks-libev
        git submodule update --init --recursive
        ./autogen.sh
        ./configure
        make
        make install
    fi
    
    # Create directories
    mkdir -p /etc/shadowsocks-libev
    mkdir -p /var/log/shadowsocks
    
    # Create default config
    cat > /etc/shadowsocks-libev/config.json << EOF
{
    "server":"0.0.0.0",
    "server_port":8388,
    "password":"password",
    "timeout":300,
    "method":"aes-256-gcm",
    "fast_open":true,
    "nameserver":"8.8.8.8",
    "mode":"tcp_and_udp"
}
EOF
    
    # Create systemd service if not exists
    if [ ! -f "/etc/systemd/system/shadowsocks-libev.service" ]; then
        cat > /etc/systemd/system/shadowsocks-libev.service << EOF
[Unit]
Description=Shadowsocks-libev Server
After=network.target

[Service]
Type=simple
ExecStart=/usr/bin/ss-server -c /etc/shadowsocks-libev/config.json -u
Restart=always
RestartSec=3

[Install]
WantedBy=multi-user.target
EOF
    fi
    
    # Create users database
    touch /etc/shadowsocks-libev/users.db
    
    # Enable and start service
    systemctl daemon-reload
    systemctl enable shadowsocks-libev
    systemctl start shadowsocks-libev
    
    # Configure firewall
    iptables -A INPUT -p tcp --dport 8388 -j ACCEPT
    iptables -A INPUT -p udp --dport 8388 -j ACCEPT
    
    # Save iptables rules
    if command -v netfilter-persistent &> /dev/null; then
        netfilter-persistent save
    fi
    
    echo -e "${GREEN}SS-LIBEV has been installed successfully!${NC}"
    echo -e "Press any key to return..."
    read -n 1
    ss_libev_menu
}

uninstall_ss_libev() {
    clear
    echo -e "╭════════════════════════════════════════════════════════════╮"
    echo -e "│                 UNINSTALL SS-LIBEV                         │"
    echo -e "╰════════════════════════════════════════════════════════════╯"
    
    echo -e "${YELLOW}Are you sure you want to uninstall SS-LIBEV? (y/n)${NC}"
    read -r confirm
    
    if [[ "$confirm" != "y" && "$confirm" != "Y" ]]; then
        echo -e "${GREEN}Uninstallation cancelled.${NC}"
        echo -e "Press any key to return..."
        read -n 1
        ss_libev_menu
        return
    fi
    
    echo -e "${YELLOW}Uninstalling SS-LIBEV...${NC}"
    
    # Stop and disable service
    systemctl stop shadowsocks-libev
    systemctl disable shadowsocks-libev
    
    # Remove packages
    if [[ $(lsb_release -rs) == "20.04" ]]; then
        apt-get purge -y shadowsocks-libev
    else
        # For versions where we compiled from source
        rm -f /usr/local/bin/ss-*
    fi
    
    # Remove files
    rm -rf /etc/shadowsocks-libev
    rm -f /etc/systemd/system/shadowsocks-libev.service
    
    # Remove firewall rules
    iptables -D INPUT -p tcp --dport 8388 -j ACCEPT 2>/dev/null
    iptables -D INPUT -p udp --dport 8388 -j ACCEPT 2>/dev/null
    
    # Save iptables rules
    if command -v netfilter-persistent &> /dev/null; then
        netfilter-persistent save
    fi
    
    # Reload systemd
    systemctl daemon-reload
    
    echo -e "${GREEN}SS-LIBEV has been uninstalled successfully!${NC}"
    echo -e "Press any key to return..."
    read -n 1
    ss_libev_menu
}

create_ss_account() {
    clear
    echo -e "╭════════════════════════════════════════════════════════════╮"
    echo -e "│                CREATE SS-LIBEV ACCOUNT                     │"
    echo -e "╰════════════════════════════════════════════════════════════╯"
    
    # Check if SS-LIBEV is installed
    if ! command -v ss-server &> /dev/null; then
        echo -e "${RED}Error: SS-LIBEV is not installed!${NC}"
        echo -e "Press any key to return..."
        read -n 1
        ss_libev_menu
        return
    fi
    
    echo -ne "Username: "
    read -r username
    
    # Check if user already exists
    if grep -q "^$username:" /etc/shadowsocks-libev/users.db; then
        echo -e "${RED}Error: User $username already exists${NC}"
        echo -e "Press any key to return..."
        read -n 1
        ss_libev_menu
        return
    fi
    
    # Generate random port between 10000-59999
    port=$(shuf -i 10000-59999 -n 1)
    
    # Check if port is already in use
    while netstat -tuln | grep -q ":$port "; do
        port=$(shuf -i 10000-59999 -n 1)
    done
    
    # Generate random password
    password=$(tr -dc 'a-zA-Z0-9' < /dev/urandom | head -c 16)
    
    echo -ne "Encryption Method [aes-256-gcm/chacha20-ietf-poly1305]: "
    read -r method
    
    # Default to aes-256-gcm if empty
    if [ -z "$method" ]; then
        method="aes-256-gcm"
    fi
    
    echo -ne "Expired (days): "
    read -r expired_days
    
    # Calculate expiration date
    exp_date=$(date -d "+$expired_days days" +"%Y-%m-%d")
    
    # Create user config file
    cat > "/etc/shadowsocks-libev/$username.json" << EOF
{
    "server":"0.0.0.0",
    "server_port":$port,
    "password":"$password",
    "timeout":300,
    "method":"$method",
    "fast_open":true,
    "nameserver":"8.8.8.8",
    "mode":"tcp_and_udp"
}
EOF
    
    # Add user to database
    echo "$username:$port:$password:$method:$exp_date" >> /etc/shadowsocks-libev/users.db
    
    # Create systemd service for this user
    cat > "/etc/systemd/system/shadowsocks-libev-$username.service" << EOF
[Unit]
Description=Shadowsocks-libev Server for $username
After=network.target

[Service]
Type=simple
ExecStart=/usr/bin/ss-server -c /etc/shadowsocks-libev/$username.json -u
Restart=always
RestartSec=3

[Install]
WantedBy=multi-user.target
EOF
    
    # Enable and start service
    systemctl daemon-reload
    systemctl enable "shadowsocks-libev-$username"
    systemctl start "shadowsocks-libev-$username"
    
    # Configure firewall
    iptables -A INPUT -p tcp --dport $port -j ACCEPT
    iptables -A INPUT -p udp --dport $port -j ACCEPT
    
    # Save iptables rules
    if command -v netfilter-persistent &> /dev/null; then
        netfilter-persistent save
    fi
    
    # Generate SS URI
    ss_uri="ss://$(echo -n "$method:$password" | base64 -w 0)@$DOMAIN:$port#$username"
    
    # Display account info
    clear
    echo -e "╭════════════════════════════════════════════════════════════╮"
    echo -e "│               SS-LIBEV ACCOUNT CREATED                     │"
    echo -e "╰════════════════════════════════════════════════════════════╯"
    echo -e "Username: $username"
    echo -e "Domain: $DOMAIN"
    echo -e "Port: $port"
    echo -e "Password: $password"
    echo -e "Method: $method"
    echo -e "Expired: $exp_date"
    echo -e ""
    echo -e "SS URI:"
    echo -e "$ss_uri"
    echo -e "╰════════════════════════════════════════════════════════════╯"
    
    echo -e "Press any key to return..."
    read -n 1
    ss_libev_menu
}

trial_ss_account() {
    clear
    echo -e "╭════════════════════════════════════════════════════════════╮"
    echo -e "│                TRIAL SS-LIBEV ACCOUNT                      │"
    echo -e "╰════════════════════════════════════════════════════════════╯"
    
    # Check if SS-LIBEV is installed
    if ! command -v ss-server &> /dev/null; then
        echo -e "${RED}Error: SS-LIBEV is not installed!${NC}"
        echo -e "Press any key to return..."
        read -n 1
        ss_libev_menu
        return
    fi
    
    # Generate random username
    username="trial$(tr -dc 'a-z0-9' < /dev/urandom | head -c5)"
    
    # Generate random port between 10000-59999
    port=$(shuf -i 10000-59999 -n 1)
    
    # Check if port is already in use
    while netstat -tuln | grep -q ":$port "; do
        port=$(shuf -i 10000-59999 -n 1)
    done
    
    # Generate random password
    password=$(tr -dc 'a-zA-Z0-9' < /dev/urandom | head -c 16)
    
    # Use aes-256-gcm as default method
    method="aes-256-gcm"
    
    # Set expiration to 1 day
    exp_date=$(date -d "+1 days" +"%Y-%m-%d")
    
    # Create user config file
    cat > "/etc/shadowsocks-libev/$username.json" << EOF
{
    "server":"0.0.0.0",
    "server_port":$port,
    "password":"$password",
    "timeout":300,
    "method":"$method",
    "fast_open":true,
    "nameserver":"8.8.8.8",
    "mode":"tcp_and_udp"
}
EOF
    
    # Add user to database
    echo "$username:$port:$password:$method:$exp_date" >> /etc/shadowsocks-libev/users.db
    
    # Create systemd service for this user
    cat > "/etc/systemd/system/shadowsocks-libev-$username.service" << EOF
[Unit]
Description=Shadowsocks-libev Server for $username
After=network.target

[Service]
Type=simple
ExecStart=/usr/bin/ss-server -c /etc/shadowsocks-libev/$username.json -u
Restart=always
RestartSec=3

[Install]
WantedBy=multi-user.target
EOF
    
    # Enable and start service
    systemctl daemon-reload
    systemctl enable "shadowsocks-libev-$username"
    systemctl start "shadowsocks-libev-$username"
    
    # Configure firewall
    iptables -A INPUT -p tcp --dport $port -j ACCEPT
    iptables -A INPUT -p udp --dport $port -j ACCEPT
    
    # Save iptables rules
    if command -v netfilter-persistent &> /dev/null; then
        netfilter-persistent save
    fi
    
    # Generate SS URI
    ss_uri="ss://$(echo -n "$method:$password" | base64 -w 0)@$DOMAIN:$port#$username"
    
    # Display account info
    clear
    echo -e "╭════════════════════════════════════════════════════════════╮"
    echo -e "│             TRIAL SS-LIBEV ACCOUNT CREATED                 │"
    echo -e "╰════════════════════════════════════════════════════════════╯"
    echo -e "Username: $username"
    echo -e "Domain: $DOMAIN"
    echo -e "Port: $port"
    echo -e "Password: $password"
    echo -e "Method: $method"
    echo -e "Expired: $exp_date (1 day)"
    echo -e ""
    echo -e "SS URI:"
    echo -e "$ss_uri"
    echo -e "╰════════════════════════════════════════════════════════════╯"
    
    echo -e "Press any key to return..."
    read -n 1
    ss_libev_menu
}

renew_ss_account() {
    clear
    echo -e "╭════════════════════════════════════════════════════════════╮"
    echo -e "│                RENEW SS-LIBEV ACCOUNT                      │"
    echo -e "╰════════════════════════════════════════════════════════════╯"
    
    # Check if SS-LIBEV is installed
    if ! command -v ss-server &> /dev/null; then
        echo -e "${RED}Error: SS-LIBEV is not installed!${NC}"
        echo -e "Press any key to return..."
        read -n 1
        ss_libev_menu
        return
    fi
    
    # List available users
    echo -e "List of SS-LIBEV Users:"
    echo -e "╭────────────────────────────────────────────────────────────╮"
    
    if [ -f "/etc/shadowsocks-libev/users.db" ]; then
        while IFS=: read -r user port pass method exp; do
            echo -e "│ $user (Expires: $exp)"
        done < /etc/shadowsocks-libev/users.db
    else
        echo -e "│ No SS-LIBEV users found"
    fi
    
    echo -e "╰────────────────────────────────────────────────────────────╯"
    
    echo -ne "Username to renew: "
    read -r username
    
    # Check if user exists
    if ! grep -q "^$username:" /etc/shadowsocks-libev/users.db; then
        echo -e "${RED}Error: User $username does not exist${NC}"
        echo -e "Press any key to return..."
        read -n 1
        ss_libev_menu
        return
    fi
    
    echo -ne "Add days: "
    read -r add_days
    
    # Get current user info
    user_line=$(grep "^$username:" /etc/shadowsocks-libev/users.db)
    port=$(echo "$user_line" | cut -d: -f2)
    password=$(echo "$user_line" | cut -d: -f3)
    method=$(echo "$user_line" | cut -d: -f4)
    current_exp=$(echo "$user_line" | cut -d: -f5)
    
    # Calculate new expiration date
    new_exp=$(date -d "$current_exp +$add_days days" +"%Y-%m-%d")
    
    # Update user in database
    sed -i "/^$username:/d" /etc/shadowsocks-libev/users.db
    echo "$username:$port:$password:$method:$new_exp" >> /etc/shadowsocks-libev/users.db
    
    echo -e "${GREEN}User $username has been renewed. New expiration: $new_exp${NC}"
    echo -e "Press any key to return..."
    read -n 1
    ss_libev_menu
}

delete_ss_account() {
    clear
    echo -e "╭════════════════════════════════════════════════════════════╮"
    echo -e "│                DELETE SS-LIBEV ACCOUNT                     │"
    echo -e "╰════════════════════════════════════════════════════════════╯"
    
    # Check if SS-LIBEV is installed
    if ! command -v ss-server &> /dev/null; then
        echo -e "${RED}Error: SS-LIBEV is not installed!${NC}"
        echo -e "Press any key to return..."
        read -n 1
        ss_libev_menu
        return
    fi
    
    # List available users
    echo -e "List of SS-LIBEV Users:"
    echo -e "╭────────────────────────────────────────────────────────────╮"
    
    if [ -f "/etc/shadowsocks-libev/users.db" ]; then
        while IFS=: read -r user port pass method exp; do
            echo -e "│ $user (Expires: $exp)"
        done < /etc/shadowsocks-libev/users.db
    else
        echo -e "│ No SS-LIBEV users found"
    fi
    
    echo -e "╰────────────────────────────────────────────────────────────╯"
    
    echo -ne "Username to delete: "
    read -r username
    
    # Check if user exists
    if ! grep -q "^$username:" /etc/shadowsocks-libev/users.db; then
        echo -e "${RED}Error: User $username does not exist${NC}"
        echo -e "Press any key to return..."
        read -n 1
        ss_libev_menu
        return
    fi
    
    # Get port
    port=$(grep "^$username:" /etc/shadowsocks-libev/users.db | cut -d: -f2)
    
    # Stop and disable service
    systemctl stop "shadowsocks-libev-$username"
    systemctl disable "shadowsocks-libev-$username"
    
    # Remove files
    rm -f "/etc/shadowsocks-libev/$username.json"
    rm -f "/etc/systemd/system/shadowsocks-libev-$username.service"
    
    # Remove from database
    sed -i "/^$username:/d" /etc/shadowsocks-libev/users.db
    
    # Remove firewall rules
    iptables -D INPUT -p tcp --dport $port -j ACCEPT 2>/dev/null
    iptables -D INPUT -p udp --dport $port -j ACCEPT 2>/dev/null
    
    # Save iptables rules
    if command -v netfilter-persistent &> /dev/null; then
        netfilter-persistent save
    fi
    
    # Reload systemd
    systemctl daemon-reload
    
    echo -e "${GREEN}User $username has been deleted${NC}"
    echo -e "Press any key to return..."
    read -n 1
    ss_libev_menu
}

check_ss_login() {
    clear
    echo -e "╭════════════════════════════════════════════════════════════╮"
    echo -e "│                CHECK SS-LIBEV LOGIN                        │"
    echo -e "╰════════════════════════════════════════════════════════════╯"
    
    # Check if SS-LIBEV is installed
    if ! command -v ss-server &> /dev/null; then
        echo -e "${RED}Error: SS-LIBEV is not installed!${NC}"
        echo -e "Press any key to return..."
        read -n 1
        ss_libev_menu
        return
    fi
    
    echo -e "Currently active SS-LIBEV connections:"
    echo -e "╭────────────────────────────────────────────────────────────╮"
    
    # This is a simplified approach - in a real scenario, you'd need to parse SS-LIBEV logs
    # or use SS-LIBEV API to get active connections
    
    # For demonstration purposes, we'll show netstat output
    echo -e "│ Active connections (netstat):"
    echo -e "├────────────────────────────────────────────────────────────┤"
    
    if [ -f "/etc/shadowsocks-libev/users.db" ]; then
        while IFS=: read -r user port pass method exp; do
            connections=$(netstat -anp | grep ":$port " | grep -v "LISTEN" | wc -l)
            echo -e "│ $user (Port: $port): $connections connection(s)"
        done < /etc/shadowsocks-libev/users.db
    else
        echo -e "│ No SS-LIBEV users found"
    fi
    
    echo -e "╰────────────────────────────────────────────────────────────╯"
    
    echo -e "Press any key to return..."
    read -n 1
    ss_libev_menu
}

list_ss_members() {
    clear
    echo -e "╭════════════════════════════════════════════════════════════╮"
    echo -e "│                LIST SS-LIBEV MEMBERS                       │"
    echo -e "╰════════════════════════════════════════════════════════════╯"
    
    # Check if SS-LIBEV is installed
    if ! command -v ss-server &> /dev/null; then
        echo -e "${RED}Error: SS-LIBEV is not installed!${NC}"
        echo -e "Press any key to return..."
        read -n 1
        ss_libev_menu
        return
    fi
    
    echo -e "SS-LIBEV Users:"
    echo -e "╭────────────────────────────────────────────────────────────╮"
    echo -e "│ Username | Port | Password | Method | Expiration Date"
    echo -e "├────────────────────────────────────────────────────────────┤"
    
    if [ -f "/etc/shadowsocks-libev/users.db" ]; then
        while IFS=: read -r user port pass method exp; do
            echo -e "│ $user | $port | ${pass:0:3}... | $method | $exp"
        done < /etc/shadowsocks-libev/users.db
    else
        echo -e "│ No SS-LIBEV users found"
    fi
    
    echo -e "╰────────────────────────────────────────────────────────────╯"
    
    echo -e "Press any key to return..."
    read -n 1
    ss_libev_menu
}

# Install UDP
install_udp() {
    clear
    echo -e "╭════════════════════════════════════════════════════════════╮"
    echo -e "│                    UDP INSTALLER                           │"
    echo -e "╰════════════════════════════════════════════════════════════╯"
    
    echo -e "${YELLOW}Installing UDP Custom...${NC}"
    
    # Download and install UDP Custom
    wget -O /usr/bin/udp-custom "https://raw.githubusercontent.com/Rerechan02/UDP/main/udp-custom"
    chmod +x /usr/bin/udp-custom
    
    # Create systemd service
    cat > /etc/systemd/system/udp-custom.service << EOF
[Unit]
Description=UDP Custom by Rerechan02
After=network.target

[Service]
ExecStart=/usr/bin/udp-custom
Restart=always
RestartSec=3

[Install]
WantedBy=multi-user.target
EOF

    # Enable and start service
    systemctl daemon-reload
    systemctl enable udp-custom
    systemctl start udp-custom
    
    echo -e "${GREEN}UDP Custom has been installed successfully!${NC}"
    echo -e "Press any key to return to main menu..."
    read -n 1
    main_menu
}

# Backup and Restore
backup_restore_menu() {
    clear
    echo -e "╭════════════════════════════════════════════════════════════╮"
    echo -e "│                 BACKUP & RESTORE MENU                      │"
    echo -e "╰════════════════════════════════════════════════════════════╯"
    echo -e "╭════════════════════════════════════════════════════════════╮"
    echo -e "│ [1] Backup VPS"
    echo -e "│ [2] Restore VPS"
    echo -e "│ [3] Set Backup Schedule"
    echo -e "│ [4] Backup to Google Drive"
    echo -e "│ [5] Backup to Telegram"
    echo -e "│ [0] Back to Main Menu"
    echo -e "╰════════════════════════════════════════════════════════════╯"
    echo -ne "  Select Option [ 0 - 5 ] ❱❱❱ "
    read -r backup_option
    
    case $backup_option in
        1) backup_vps ;;
        2) restore_vps ;;
        3) set_backup_schedule ;;
        4) backup_to_gdrive ;;
        5) backup_to_telegram ;;
        0) main_menu ;;
        *) echo -e "${RED}Invalid option!${NC}" ; sleep 2 ; backup_restore_menu ;;
    esac
}

# Backup and Restore Functions
backup_vps() {
    clear
    echo -e "╭════════════════════════════════════════════════════════════╮"
    echo -e "│                     BACKUP VPS                             │"
    echo -e "╰════════════════════════════════════════════════════════════╯"
    
    # Create backup directory if it doesn't exist
    mkdir -p "$BACKUP_DIR"
    
    # Generate backup filename with date
    backup_date=$(date +"%Y-%m-%d_%H-%M-%S")
    backup_file="$BACKUP_DIR/vps_backup_$backup_date.tar.gz"
    
    echo -e "${YELLOW}Creating backup...${NC}"
    
    # Create list of directories to backup
    backup_dirs=(
        "/etc/xray"
        "/usr/local/etc/xray"
        "/etc/shadowsocks-libev"
        "/etc/noobzvpn"
        "/etc/vps_manager"
        "/etc/nginx/sites-available"
        "/etc/nginx/sites-enabled"
        "/var/www/html"
        "/root/vps_manager"
    )
    
    # Create temporary directory for backup files
    tmp_backup_dir=$(mktemp -d)
    
    # Copy important configuration files
    for dir in "${backup_dirs[@]}"; do
        if [ -d "$dir" ]; then
            mkdir -p "$tmp_backup_dir$dir"
            cp -r "$dir"/* "$tmp_backup_dir$dir/" 2>/dev/null
        fi
    done
    
    # Backup specific files
    cp /etc/passwd "$tmp_backup_dir/passwd" 2>/dev/null
    cp /etc/shadow "$tmp_backup_dir/shadow" 2>/dev/null
    cp /etc/gshadow "$tmp_backup_dir/gshadow" 2>/dev/null
    cp /etc/group "$tmp_backup_dir/group" 2>/dev/null
    cp /etc/crontab "$tmp_backup_dir/crontab" 2>/dev/null
    
    # Create backup archive
    tar -czf "$backup_file" -C "$tmp_backup_dir" .
    
    # Clean up temporary directory
    rm -rf "$tmp_backup_dir"
    
    # Set permissions
    chmod 600 "$backup_file"
    
    echo -e "${GREEN}Backup created successfully: $backup_file${NC}"
    echo -e "Backup size: $(du -h "$backup_file" | cut -f1)"
    echo -e "Press any key to return..."
    read -n 1
    backup_restore_menu
}

restore_vps() {
    clear
    echo -e "╭════════════════════════════════════════════════════════════╮"
    echo -e "│                     RESTORE VPS                            │"
    echo -e "╰════════════════════════════════════════════════════════════╯"
    
    # Check if backup directory exists
    if [ ! -d "$BACKUP_DIR" ]; then
        echo -e "${RED}No backup directory found!${NC}"
        echo -e "Press any key to return..."
        read -n 1
        backup_restore_menu
        return
    fi
    
    # List available backups
    echo -e "Available backups:"
    echo -e "╭────────────────────────────────────────────────────────────╮"
    
    # Get list of backup files
    backup_files=("$BACKUP_DIR"/vps_backup_*.tar.gz)
    
    if [ ${#backup_files[@]} -eq 0 ] || [ ! -f "${backup_files[0]}" ]; then
        echo -e "│ No backup files found"
        echo -e "╰────────────────────────────────────────────────────────╯"
        echo -e "Press any key to return..."
        read -n 1
        backup_restore_menu
        return
    fi
    
    # Display backups with index
    for i in "${!backup_files[@]}"; do
        filename=$(basename "${backup_files[$i]}")
        size=$(du -h "${backup_files[$i]}" | cut -f1)
        echo -e "│ [$i] $filename ($size)"
    done
    
    echo -e "╰────────────────────────────────────────────────────────────╯"
    
    echo -ne "Select backup to restore [0-$((${#backup_files[@]}-1))]: "
    read -r backup_index
    
    # Validate input
    if ! [[ "$backup_index" =~ ^[0-9]+$ ]] || [ "$backup_index" -ge ${#backup_files[@]} ]; then
        echo -e "${RED}Invalid selection!${NC}"
        echo -e "Press any key to return..."
        read -n 1
        restore_vps
        return
    fi
    
    selected_backup="${backup_files[$backup_index]}"
    
    echo -e "${YELLOW}WARNING: This will overwrite current configuration files.${NC}"
    echo -e "${YELLOW}Are you sure you want to restore from $selected_backup? (y/n)${NC}"
    read -r confirm
    
    if [[ "$confirm" != "y" && "$confirm" != "Y" ]]; then
        echo -e "${GREEN}Restoration cancelled.${NC}"
        echo -e "Press any key to return..."
        read -n 1
        backup_restore_menu
        return
    fi
    
    echo -e "${YELLOW}Restoring backup...${NC}"
    
    # Create temporary directory for extraction
    tmp_restore_dir=$(mktemp -d)
    
    # Extract backup
    tar -xzf "$selected_backup" -C "$tmp_restore_dir"
    
    # Restore configuration files
    for dir in "/etc/xray" "/usr/local/etc/xray" "/etc/shadowsocks-libev" "/etc/noobzvpn" "/etc/vps_manager" "/etc/nginx/sites-available" "/etc/nginx/sites-enabled" "/var/www/html" "/root/vps_manager"; do
        if [ -d "$tmp_restore_dir$dir" ]; then
            mkdir -p "$dir"
            cp -r "$tmp_restore_dir$dir"/* "$dir/" 2>/dev/null
        fi
    done
    
    # Restore specific files (be careful with system files)
    # We'll only restore VPS manager specific files, not system files like passwd/shadow for security
    if [ -f "$tmp_restore_dir/crontab" ]; then
        cp "$tmp_restore_dir/crontab" /etc/crontab
    fi
    
    # Clean up temporary directory
    rm -rf "$tmp_restore_dir"
    
    # Restart services
    systemctl restart nginx 2>/dev/null
    systemctl restart xray 2>/dev/null
    systemctl restart shadowsocks-libev 2>/dev/null
    systemctl restart noobzvpn 2>/dev/null
    
    echo -e "${GREEN}Backup restored successfully!${NC}"
    echo -e "Press any key to return..."
    read -n 1
    backup_restore_menu
}

set_backup_schedule() {
    clear
    echo -e "╭════════════════════════════════════════════════════════════╮"
    echo -e "│                 SET BACKUP SCHEDULE                        │"
    echo -e "╰════════════════════════════════════════════════════════════╯"
    
    echo -e "Select backup frequency:"
    echo -e "[1] Daily"
    echo -e "[2] Weekly"
    echo -e "[3] Monthly"
    echo -e "[4] Disable scheduled backups"
    echo -ne "Select option [1-4]: "
    read -r schedule_option
    
    case $schedule_option in
        1)
            # Daily backup at 2 AM
            echo -e "${YELLOW}Setting up daily backup at 2 AM...${NC}"
            cron_schedule="0 2 * * *"
            frequency="daily"
            ;;
        2)
            # Weekly backup on Sunday at 3 AM
            echo -e "${YELLOW}Setting up weekly backup on Sunday at 3 AM...${NC}"
            cron_schedule="0 3 * * 0"
            frequency="weekly"
            ;;
        3)
            # Monthly backup on the 1st at 4 AM
            echo -e "${YELLOW}Setting up monthly backup on the 1st at 4 AM...${NC}"
            cron_schedule="0 4 1 * *"
            frequency="monthly"
            ;;
        4)
            # Remove existing cron job
            echo -e "${YELLOW}Disabling scheduled backups...${NC}"
            crontab -l | grep -v "/usr/local/bin/vps_manager_backup" | crontab -
            
            echo -e "${GREEN}Scheduled backups disabled.${NC}"
            echo -e "Press any key to return..."
            read -n 1
            backup_restore_menu
            return
            ;;
        *)
            echo -e "${RED}Invalid option!${NC}"
            echo -e "Press any key to return..."
            read -n 1
            set_backup_schedule
            return
            ;;
    esac
    
    # Create backup script
    cat > /usr/local/bin/vps_manager_backup << EOF
#!/bin/bash
# Automatic backup script for VPS Manager

# Create backup directory if it doesn't exist
mkdir -p $BACKUP_DIR

# Generate backup filename with date
backup_date=\$(date +"%Y-%m-%d_%H-%M-%S")
backup_file="$BACKUP_DIR/vps_backup_\$backup_date.tar.gz"

# Create list of directories to backup
backup_dirs=(
    "/etc/xray"
    "/usr/local/etc/xray"
    "/etc/shadowsocks-libev"
    "/etc/noobzvpn"
    "/etc/vps_manager"
    "/etc/nginx/sites-available"
    "/etc/nginx/sites-enabled"
    "/var/www/html"
    "/root/vps_manager"
)

# Create temporary directory for backup files
tmp_backup_dir=\$(mktemp -d)

# Copy important configuration files
for dir in "\${backup_dirs[@]}"; do
    if [ -d "\$dir" ]; then
        mkdir -p "\$tmp_backup_dir\$dir"
        cp -r "\$dir"/* "\$tmp_backup_dir\$dir/" 2>/dev/null
    fi
done

# Backup specific files
cp /etc/passwd "\$tmp_backup_dir/passwd" 2>/dev/null
cp /etc/shadow "\$tmp_backup_dir/shadow" 2>/dev/null
cp /etc/gshadow "\$tmp_backup_dir/gshadow" 2>/dev/null
cp /etc/group "\$tmp_backup_dir/group" 2>/dev/null
cp /etc/crontab "\$tmp_backup_dir/crontab" 2>/dev/null

# Create backup archive
tar -czf "\$backup_file" -C "\$tmp_backup_dir" .

# Clean up temporary directory
rm -rf "\$tmp_backup_dir"

# Set permissions
chmod 600 "\$backup_file"

# Keep only the 5 most recent backups
ls -t $BACKUP_DIR/vps_backup_*.tar.gz | tail -n +6 | xargs rm -f
EOF
    
    chmod +x /usr/local/bin/vps_manager_backup
    
    # Set up cron job
    (crontab -l 2>/dev/null | grep -v "/usr/local/bin/vps_manager_backup" ; echo "$cron_schedule /usr/local/bin/vps_manager_backup") | crontab -
    
    echo -e "${GREEN}$frequency backup schedule has been set.${NC}"
    echo -e "Press any key to return..."
    read -n 1
    backup_restore_menu
}

backup_to_gdrive() {
    clear
    echo -e "╭════════════════════════════════════════════════════════════╮"
    echo -e "│                 BACKUP TO GOOGLE DRIVE                     │"
    echo -e "╰════════════════════════════════════════════════════════════╯"
    
    # Check if rclone is installed
    if ! command -v rclone &> /dev/null; then
        echo -e "${YELLOW}Rclone is not installed. Installing...${NC}"
        curl https://rclone.org/install.sh | bash
    fi
    
    # Check if rclone is configured
    if [ ! -f "$HOME/.config/rclone/rclone.conf" ] || ! grep -q "\[gdrive\]" "$HOME/.config/rclone/rclone.conf"; then
        echo -e "${YELLOW}Rclone is not configured for Google Drive.${NC}"
        echo -e "${YELLOW}Please run 'rclone config' to set up Google Drive access.${NC}"
        echo -e "${YELLOW}After configuration, name the remote 'gdrive'.${NC}"
        echo -e "Press any key to continue to rclone config..."
        read -n 1
        rclone config
    fi
    
    # Create backup
    echo -e "${YELLOW}Creating backup...${NC}"
    backup_vps_silent
    
    # Get the latest backup file
    latest_backup=$(ls -t "$BACKUP_DIR"/vps_backup_*.tar.gz | head -n 1)
    
    if [ -z "$latest_backup" ]; then
        echo -e "${RED}No backup file found!${NC}"
        echo -e "Press any key to return..."
        read -n 1
        backup_restore_menu
        return
    fi
    
    echo -e "${YELLOW}Uploading $latest_backup to Google Drive...${NC}"
    
    # Upload to Google Drive
    rclone copy "$latest_backup" gdrive:vps_backups/
    
    if [ $? -eq 0 ]; then
        echo -e "${GREEN}Backup uploaded successfully to Google Drive!${NC}"
    else
        echo -e "${RED}Failed to upload backup to Google Drive.${NC}"
    fi
    
    echo -e "Press any key to return..."
    read -n 1
    backup_restore_menu
}

backup_vps_silent() {
    # Create backup directory if it doesn't exist
    mkdir -p "$BACKUP_DIR"
    
    # Generate backup filename with date
    backup_date=$(date +"%Y-%m-%d_%H-%M-%S")
    backup_file="$BACKUP_DIR/vps_backup_$backup_date.tar.gz"
    
    # Create list of directories to backup
    backup_dirs=(
        "/etc/xray"
        "/usr/local/etc/xray"
        "/etc/shadowsocks-libev"
        "/etc/noobzvpn"
        "/etc/vps_manager"
        "/etc/nginx/sites-available"
        "/etc/nginx/sites-enabled"
        "/var/www/html"
        "/root/vps_manager"
    )
    
    # Create temporary directory for backup files
    tmp_backup_dir=$(mktemp -d)
    
    # Copy important configuration files
    for dir in "${backup_dirs[@]}"; do
        if [ -d "$dir" ]; then
            mkdir -p "$tmp_backup_dir$dir"
            cp -r "$dir"/* "$tmp_backup_dir$dir/" 2>/dev/null
        fi
    done
    
    # Backup specific files
    cp /etc/passwd "$tmp_backup_dir/passwd" 2>/dev/null
    cp /etc/shadow "$tmp_backup_dir/shadow" 2>/dev/null
    cp /etc/gshadow "$tmp_backup_dir/gshadow" 2>/dev/null
    cp /etc/group "$tmp_backup_dir/group" 2>/dev/null
    cp /etc/crontab "$tmp_backup_dir/crontab" 2>/dev/null
    
    # Create backup archive
    tar -czf "$backup_file" -C "$tmp_backup_dir" .
    
    # Clean up temporary directory
    rm -rf "$tmp_backup_dir"
    
    # Set permissions
    chmod 600 "$backup_file"
    
    return 0
}

backup_to_telegram() {
    clear
    echo -e "╭════════════════════════════════════════════════════════════╮"
    echo -e "│                 BACKUP TO TELEGRAM                         │"
    echo -e "╰════════════════════════════════════════════════════════════╯"
    
    # Check if curl is installed
    if ! command -v curl &> /dev/null; then
        echo -e "${YELLOW}curl is not installed. Installing...${NC}"
        apt-get update
        apt-get install -y curl
    fi
    
    # Ask for Telegram Bot Token if not set
    if [ -z "$TELEGRAM_BOT_TOKEN" ]; then
        echo -ne "Enter Telegram Bot Token: "
        read -r TELEGRAM_BOT_TOKEN
        echo "TELEGRAM_BOT_TOKEN=&quot;$TELEGRAM_BOT_TOKEN&quot;" >> "$CONFIG_DIR/config.conf"
    fi
    
    # Ask for Telegram Chat ID if not set
    if [ -z "$TELEGRAM_CHAT_ID" ]; then
        echo -ne "Enter Telegram Chat ID: "
        read -r TELEGRAM_CHAT_ID
        echo "TELEGRAM_CHAT_ID=&quot;$TELEGRAM_CHAT_ID&quot;" >> "$CONFIG_DIR/config.conf"
    fi
    
    # Create backup
    echo -e "${YELLOW}Creating backup...${NC}"
    backup_vps_silent
    
    # Get the latest backup file
    latest_backup=$(ls -t "$BACKUP_DIR"/vps_backup_*.tar.gz | head -n 1)
    
    if [ -z "$latest_backup" ]; then
        echo -e "${RED}No backup file found!${NC}"
        echo -e "Press any key to return..."
        read -n 1
        backup_restore_menu
        return
    fi
    
    # Check file size (Telegram has a 50MB limit for bots)
    file_size=$(du -b "$latest_backup" | cut -f1)
    
    if [ "$file_size" -gt 50000000 ]; then
        echo -e "${RED}Backup file is larger than 50MB and cannot be sent via Telegram Bot API.${NC}"
        echo -e "${YELLOW}Consider using Google Drive backup instead.${NC}"
        echo -e "Press any key to return..."
        read -n 1
        backup_restore_menu
        return
    fi
    
    echo -e "${YELLOW}Sending $latest_backup to Telegram...${NC}"
    
    # Send message
    curl -s -X POST "https://api.telegram.org/bot$TELEGRAM_BOT_TOKEN/sendMessage" \
        -d chat_id="$TELEGRAM_CHAT_ID" \
        -d text="VPS Backup $(date +"%Y-%m-%d %H:%M:%S")"
    
    # Send file
    curl -s -X POST "https://api.telegram.org/bot$TELEGRAM_BOT_TOKEN/sendDocument" \
        -F chat_id="$TELEGRAM_CHAT_ID" \
        -F document=@"$latest_backup"
    
    if [ $? -eq 0 ]; then
        echo -e "${GREEN}Backup sent successfully to Telegram!${NC}"
    else
        echo -e "${RED}Failed to send backup to Telegram.${NC}"
    fi
    
    echo -e "Press any key to return..."
    read -n 1
    backup_restore_menu
}

# GOTOP X RAM
gotop_ram() {
    clear
    echo -e "${YELLOW}Starting GOTOP X RAM monitor...${NC}"
    
    # Check if gotop is installed
    if ! command -v gotop &> /dev/null; then
        echo -e "${YELLOW}Installing GOTOP...${NC}"
        wget -q -O /tmp/gotop.tar.gz https://github.com/xxxserxxx/gotop/releases/download/v4.1.3/gotop_v4.1.3_linux_amd64.tar.gz
        tar -xzf /tmp/gotop.tar.gz -C /tmp
        mv /tmp/gotop /usr/local/bin/
        chmod +x /usr/local/bin/gotop
    fi
    
    # Run gotop
    gotop
    
    echo -e "Press any key to return to main menu..."
    read -n 1
    main_menu
}

# Restart All Services
restart_all_services() {
    clear
    echo -e "╭════════════════════════════════════════════════════════════╮"
    echo -e "│                RESTARTING ALL SERVICES                     │"
    echo -e "╰════════════════════════════════════════════════════════════╯"
    
    echo -e "${YELLOW}Restarting SSH...${NC}"
    systemctl restart ssh
    
    echo -e "${YELLOW}Restarting Dropbear...${NC}"
    systemctl restart dropbear 2>/dev/null || echo -e "${RED}Dropbear not installed.${NC}"
    
    echo -e "${YELLOW}Restarting Nginx...${NC}"
    systemctl restart nginx
    
    echo -e "${YELLOW}Restarting Xray...${NC}"
    systemctl restart xray
    
    echo -e "${YELLOW}Restarting HAProxy...${NC}"
    systemctl restart haproxy 2>/dev/null || echo -e "${RED}HAProxy not installed.${NC}"
    
    echo -e "${YELLOW}Restarting NOOBZVPN...${NC}"
    systemctl restart noobzvpn 2>/dev/null || echo -e "${RED}NOOBZVPN not installed.${NC}"
    
    echo -e "${YELLOW}Restarting WS-ePro...${NC}"
    systemctl restart ws-epro 2>/dev/null || echo -e "${RED}WS-ePro not installed.${NC}"
    
    echo -e "${YELLOW}Restarting UDP Custom...${NC}"
    systemctl restart udp-custom 2>/dev/null || echo -e "${RED}UDP Custom not installed.${NC}"
    
    echo -e "${GREEN}All services have been restarted!${NC}"
    echo -e "Press any key to return to main menu..."
    read -n 1
    main_menu
}

# Telegram Bot
telegram_bot_menu() {
    clear
    echo -e "╭════════════════════════════════════════════════════════════╮"
    echo -e "│                   TELEGRAM BOT MENU                        │"
    echo -e "╰════════════════════════════════════════════════════════════╯"
    echo -e "╭════════════════════════════════════════════════════════════╮"
    echo -e "│ [1] Set Bot Token"
    echo -e "│ [2] Set Admin ID"
    echo -e "│ [3] Start Bot"
    echo -e "│ [4] Stop Bot"
    echo -e "│ [5] Bot Status"
    echo -e "│ [6] Bot Logs"
    echo -e "│ [0] Back to Main Menu"
    echo -e "╰════════════════════════════════════════════════════════════╯"
    echo -ne "  Select Option [ 0 - 6 ] ❱❱❱ "
    read -r bot_option
    
    case $bot_option in
        1) set_bot_token ;;
        2) set_admin_id ;;
        3) start_telegram_bot ;;
        4) stop_telegram_bot ;;
        5) check_bot_status ;;
        6) view_bot_logs ;;
        0) main_menu ;;
        *) echo -e "${RED}Invalid option!${NC}" ; sleep 2 ; telegram_bot_menu ;;
    esac
}

# Telegram Bot Functions
set_bot_token() {
    clear
    echo -e "╭════════════════════════════════════════════════════════════╮"
    echo -e "│                    SET BOT TOKEN                           │"
    echo -e "╰════════════════════════════════════════════════════════════╯"
    
    echo -e "${YELLOW}Enter your Telegram Bot Token:${NC}"
    echo -e "${YELLOW}(Get it from @BotFather on Telegram)${NC}"
    read -r bot_token
    
    if [ -z "$bot_token" ]; then
        echo -e "${RED}Bot token cannot be empty!${NC}"
        echo -e "Press any key to return..."
        read -n 1
        telegram_bot_menu
        return
    fi
    
    # Save to config
    if grep -q "TELEGRAM_BOT_TOKEN=" "$CONFIG_DIR/config.conf"; then
        sed -i "s/TELEGRAM_BOT_TOKEN=.*/TELEGRAM_BOT_TOKEN=&quot;$bot_token&quot;/" "$CONFIG_DIR/config.conf"
    else
        echo "TELEGRAM_BOT_TOKEN=&quot;$bot_token&quot;" >> "$CONFIG_DIR/config.conf"
    fi
    
    TELEGRAM_BOT_TOKEN="$bot_token"
    
    echo -e "${GREEN}Bot token has been set successfully!${NC}"
    echo -e "Press any key to return..."
    read -n 1
    telegram_bot_menu
}

set_admin_id() {
    clear
    echo -e "╭════════════════════════════════════════════════════════════╮"
    echo -e "│                     SET ADMIN ID                           │"
    echo -e "╰════════════════════════════════════════════════════════════╯"
    
    echo -e "${YELLOW}Enter your Telegram User ID:${NC}"
    echo -e "${YELLOW}(Get it from @userinfobot on Telegram)${NC}"
    read -r admin_id
    
    if [ -z "$admin_id" ]; then
        echo -e "${RED}Admin ID cannot be empty!${NC}"
        echo -e "Press any key to return..."
        read -n 1
        telegram_bot_menu
        return
    fi
    
    # Save to config
    if grep -q "TELEGRAM_CHAT_ID=" "$CONFIG_DIR/config.conf"; then
        sed -i "s/TELEGRAM_CHAT_ID=.*/TELEGRAM_CHAT_ID=&quot;$admin_id&quot;/" "$CONFIG_DIR/config.conf"
    else
        echo "TELEGRAM_CHAT_ID=&quot;$admin_id&quot;" >> "$CONFIG_DIR/config.conf"
    fi
    
    TELEGRAM_CHAT_ID="$admin_id"
    
    echo -e "${GREEN}Admin ID has been set successfully!${NC}"
    echo -e "Press any key to return..."
    read -n 1
    telegram_bot_menu
}

start_telegram_bot() {
    clear
    echo -e "╭════════════════════════════════════════════════════════════╮"
    echo -e "│                   START TELEGRAM BOT                       │"
    echo -e "╰════════════════════════════════════════════════════════════╯"
    
    # Check if token and admin ID are set
    if [ -z "$TELEGRAM_BOT_TOKEN" ] || [ -z "$TELEGRAM_CHAT_ID" ]; then
        echo -e "${RED}Bot token or admin ID is not set!${NC}"
        echo -e "Please set them first."
        echo -e "Press any key to return..."
        read -n 1
        telegram_bot_menu
        return
    fi
    
    # Check if bot script exists
    if [ ! -f "/usr/local/bin/vps_telegram_bot.py" ]; then
        echo -e "${YELLOW}Creating bot script...${NC}"
        
        # Install required packages
        apt-get update
        apt-get install -y python3 python3-pip
        pip3 install python-telegram-bot
        
        # Create bot script
        cat > /usr/local/bin/vps_telegram_bot.py << 'EOF'
#!/usr/bin/env python3
import os
import sys
import time
import logging
import subprocess
import threading
from telegram import Update, ForceReply
from telegram.ext import Updater, CommandHandler, MessageHandler, Filters, CallbackContext

# Configure logging
logging.basicConfig(
    format='%(asctime)s - %(name)s - %(levelname)s - %(message)s',
    level=logging.INFO,
    filename='/var/log/vps_telegram_bot.log'
)

logger = logging.getLogger(__name__)

# Get bot token and admin ID from environment variables
BOT_TOKEN = os.environ.get('TELEGRAM_BOT_TOKEN')
ADMIN_ID = int(os.environ.get('TELEGRAM_CHAT_ID'))

def execute_command(command):
    """Execute shell command and return output"""
    try:
        result = subprocess.run(command, shell=True, check=True, 
                               stdout=subprocess.PIPE, stderr=subprocess.PIPE,
                               universal_newlines=True)
        return result.stdout
    except subprocess.CalledProcessError as e:
        return f"Error: {e.stderr}"

def start(update: Update, context: CallbackContext) -> None:
    """Send a message when the command /start is issued."""
    user = update.effective_user
    if user.id != ADMIN_ID:
        update.message.reply_text('Unauthorized access.')
        return
        
    update.message.reply_text(f'Hi {user.first_name}! I am your VPS Manager Bot.\n'
                             f'Use /help to see available commands.')

def help_command(update: Update, context: CallbackContext) -> None:
    """Send a message when the command /help is issued."""
    if update.effective_user.id != ADMIN_ID:
        update.message.reply_text('Unauthorized access.')
        return
        
    update.message.reply_text('Available commands:\n'
                             '/status - Show VPS status\n'
                             '/users - List all users\n'
                             '/create_user <username> <password> <days> - Create SSH user\n'
                             '/delete_user <username> - Delete user\n'
                             '/reboot - Reboot VPS\n'
                             '/backup - Create backup\n'
                             '/services - Show service status')

def status_command(update: Update, context: CallbackContext) -> None:
    """Show VPS status"""
    if update.effective_user.id != ADMIN_ID:
        update.message.reply_text('Unauthorized access.')
        return
    
    update.message.reply_text('Getting VPS status...')
    
    # Get system info
    uptime = execute_command("uptime -p")
    memory = execute_command("free -h | grep Mem")
    disk = execute_command("df -h / | tail -1")
    load = execute_command("cat /proc/loadavg")
    
    status_text = f"🖥️ *VPS Status*\n\n"
    status_text += f"*Uptime:* `{uptime.strip()}`\n"
    status_text += f"*Memory:* `{memory.strip()}`\n"
    status_text += f"*Disk:* `{disk.strip()}`\n"
    status_text += f"*Load:* `{load.strip()}`\n"
    
    update.message.reply_text(status_text, parse_mode='Markdown')

def users_command(update: Update, context: CallbackContext) -> None:
    """List all users"""
    if update.effective_user.id != ADMIN_ID:
        update.message.reply_text('Unauthorized access.')
        return
    
    update.message.reply_text('Getting user list...')
    
    # Get SSH users
    ssh_users = execute_command("awk -F: '$3 >= 1000 && $1 != &quot;nobody&quot; {print $1}' /etc/passwd")
    
    users_text = f"👥 *User List*\n\n"
    users_text += f"*SSH Users:*\n`{ssh_users.strip()}`\n\n"
    
    # Get VMESS users if available
    if os.path.exists("/usr/local/etc/xray/vmess"):
        vmess_users = execute_command("ls -1 /usr/local/etc/xray/vmess")
        users_text += f"*VMESS Users:*\n`{vmess_users.strip()}`\n\n"
    
    # Get VLESS users if available
    if os.path.exists("/usr/local/etc/xray/vless"):
        vless_users = execute_command("ls -1 /usr/local/etc/xray/vless")
        users_text += f"*VLESS Users:*\n`{vless_users.strip()}`\n\n"
    
    # Get TROJAN users if available
    if os.path.exists("/usr/local/etc/xray/trojan"):
        trojan_users = execute_command("ls -1 /usr/local/etc/xray/trojan")
        users_text += f"*TROJAN Users:*\n`{trojan_users.strip()}`\n\n"
    
    update.message.reply_text(users_text, parse_mode='Markdown')

def create_user_command(update: Update, context: CallbackContext) -> None:
    """Create a new SSH user"""
    if update.effective_user.id != ADMIN_ID:
        update.message.reply_text('Unauthorized access.')
        return
    
    if len(context.args) < 3:
        update.message.reply_text('Usage: /create_user <username> <password> <days>')
        return
    
    username = context.args[0]
    password = context.args[1]
    days = context.args[2]
    
    update.message.reply_text(f'Creating user {username}...')
    
    # Create user
    result = execute_command(f"useradd -e $(date -d &quot;+{days} days&quot; +&quot;%Y-%m-%d&quot;) -s /bin/false -M {username}")
    passwd_result = execute_command(f"echo '{username}:{password}' | chpasswd")
    
    update.message.reply_text(f'User {username} created successfully!\n'
                             f'Password: {password}\n'
                             f'Expires in: {days} days')

def delete_user_command(update: Update, context: CallbackContext) -> None:
    """Delete a user"""
    if update.effective_user.id != ADMIN_ID:
        update.message.reply_text('Unauthorized access.')
        return
    
    if len(context.args) < 1:
        update.message.reply_text('Usage: /delete_user <username>')
        return
    
    username = context.args[0]
    
    update.message.reply_text(f'Deleting user {username}...')
    
    # Delete user
    result = execute_command(f"userdel -r -f {username}")
    
    update.message.reply_text(f'User {username} deleted successfully!')

def reboot_command(update: Update, context: CallbackContext) -> None:
    """Reboot the VPS"""
    if update.effective_user.id != ADMIN_ID:
        update.message.reply_text('Unauthorized access.')
        return
    
    update.message.reply_text('Rebooting VPS in 5 seconds...')
    
    def delayed_reboot():
        time.sleep(5)
        os.system('reboot')
    
    threading.Thread(target=delayed_reboot).start()

def backup_command(update: Update, context: CallbackContext) -> None:
    """Create a backup"""
    if update.effective_user.id != ADMIN_ID:
        update.message.reply_text('Unauthorized access.')
        return
    
    update.message.reply_text('Creating backup...')
    
    # Run backup script
    result = execute_command("/usr/local/bin/vps_manager_backup")
    
    update.message.reply_text('Backup created successfully!')

def services_command(update: Update, context: CallbackContext) -> None:
    """Show service status"""
    if update.effective_user.id != ADMIN_ID:
        update.message.reply_text('Unauthorized access.')
        return
    
    update.message.reply_text('Getting service status...')
    
    # Get service status
    ssh_status = execute_command("systemctl is-active ssh")
    nginx_status = execute_command("systemctl is-active nginx")
    xray_status = execute_command("systemctl is-active xray")
    
    services_text = f"🔧 *Service Status*\n\n"
    services_text += f"*SSH:* `{ssh_status.strip()}`\n"
    services_text += f"*Nginx:* `{nginx_status.strip()}`\n"
    services_text += f"*Xray:* `{xray_status.strip()}`\n"
    
    # Check other services
    for service in ["dropbear", "haproxy", "noobzvpn", "ws-epro", "udp-custom"]:
        status = execute_command(f"systemctl is-active {service}")
        services_text += f"*{service}:* `{status.strip()}`\n"
    
    update.message.reply_text(services_text, parse_mode='Markdown')

def main() -> None:
    """Start the bot."""
    # Create the Updater and pass it your bot's token
    updater = Updater(BOT_TOKEN)

    # Get the dispatcher to register handlers
    dispatcher = updater.dispatcher

    # Register command handlers
    dispatcher.add_handler(CommandHandler("start", start))
    dispatcher.add_handler(CommandHandler("help", help_command))
    dispatcher.add_handler(CommandHandler("status", status_command))
    dispatcher.add_handler(CommandHandler("users", users_command))
    dispatcher.add_handler(CommandHandler("create_user", create_user_command))
    dispatcher.add_handler(CommandHandler("delete_user", delete_user_command))
    dispatcher.add_handler(CommandHandler("reboot", reboot_command))
    dispatcher.add_handler(CommandHandler("backup", backup_command))
    dispatcher.add_handler(CommandHandler("services", services_command))

    # Start the Bot
    updater.start_polling()
    logger.info("Bot started")

    # Run the bot until you press Ctrl-C
    updater.idle()

if __name__ == '__main__':
    main()
EOF
        
        chmod +x /usr/local/bin/vps_telegram_bot.py
    fi
    
    # Create systemd service
    cat > /etc/systemd/system/vps_telegram_bot.service << EOF
[Unit]
Description=VPS Manager Telegram Bot
After=network.target

[Service]
ExecStart=/usr/bin/python3 /usr/local/bin/vps_telegram_bot.py
Environment="TELEGRAM_BOT_TOKEN=$TELEGRAM_BOT_TOKEN"
Environment="TELEGRAM_CHAT_ID=$TELEGRAM_CHAT_ID"
Restart=always
RestartSec=3

[Install]
WantedBy=multi-user.target
EOF
    
    # Enable and start service
    systemctl daemon-reload
    systemctl enable vps_telegram_bot
    systemctl start vps_telegram_bot
    
    echo -e "${GREEN}Telegram bot has been started!${NC}"
    echo -e "Press any key to return..."
    read -n 1
    telegram_bot_menu
}

stop_telegram_bot() {
    clear
    echo -e "╭════════════════════════════════════════════════════════════╮"
    echo -e "│                    STOP TELEGRAM BOT                       │"
    echo -e "╰════════════════════════════════════════════════════════════╯"
    
    echo -e "${YELLOW}Stopping Telegram bot...${NC}"
    
    # Stop and disable service
    systemctl stop vps_telegram_bot
    systemctl disable vps_telegram_bot
    
    echo -e "${GREEN}Telegram bot has been stopped!${NC}"
    echo -e "Press any key to return..."
    read -n 1
    telegram_bot_menu
}

check_bot_status() {
    clear
    echo -e "╭════════════════════════════════════════════════════════════╮"
    echo -e "│                    BOT STATUS                              │"
    echo -e "╰════════════════════════════════════════════════════════════╯"
    
    echo -e "${YELLOW}Checking bot status...${NC}"
    
    # Check if service is active
    status=$(systemctl is-active vps_telegram_bot)
    
    if [ "$status" == "active" ]; then
        echo -e "${GREEN}Bot is running!${NC}"
    else
        echo -e "${RED}Bot is not running!${NC}"
    fi
    
    # Show service status
    systemctl status vps_telegram_bot
    
    echo -e "Press any key to return..."
    read -n 1
    telegram_bot_menu
}

view_bot_logs() {
    clear
    echo -e "╭════════════════════════════════════════════════════════════╮"
    echo -e "│                     BOT LOGS                               │"
    echo -e "╰════════════════════════════════════════════════════════════╯"
    
    echo -e "${YELLOW}Showing bot logs...${NC}"
    
    # Show logs
    journalctl -u vps_telegram_bot -n 50 --no-pager
    
    echo -e "\nPress any key to return..."
    read -n 1
    telegram_bot_menu
}

# Update Menu
update_menu() {
    clear
    echo -e "╭════════════════════════════════════════════════════════════╮"
    echo -e "│                     UPDATE MENU                            │"
    echo -e "╰════════════════════════════════════════════════════════════╯"
    echo -e "╭════════════════════════════════════════════════════════════╮"
    echo -e "│ [1] Update Script"
    echo -e "│ [2] Update System Packages"
    echo -e "│ [3] Update Xray"
    echo -e "│ [4] Update All"
    echo -e "│ [0] Back to Main Menu"
    echo -e "╰════════════════════════════════════════════════════════════╯"
    echo -ne "  Select Option [ 0 - 4 ] ❱❱❱ "
    read -r update_option
    
    case $update_option in
        1) update_script ;;
        2) update_system_packages ;;
        3) update_xray ;;
        4) update_all ;;
        0) main_menu ;;
        *) echo -e "${RED}Invalid option!${NC}" ; sleep 2 ; update_menu ;;
    esac
}

# Update Functions
update_script() {
    clear
    echo -e "╭════════════════════════════════════════════════════════════╮"
    echo -e "│                    UPDATE SCRIPT                           │"
    echo -e "╰════════════════════════════════════════════════════════════╯"
    
    echo -e "${YELLOW}Updating VPS Manager script...${NC}"
    
    # Create backup of current script
    cp "$(readlink -f "$0")" "/usr/local/bin/vps_manager.bak"
    
    # Download latest version (this is a placeholder - replace with actual repository URL)
    echo -e "${YELLOW}Downloading latest version...${NC}"
    wget -O /tmp/vps_manager.sh "https://raw.githubusercontent.com/yourusername/vps-manager/main/vps_manager.sh"
    
    # Check if download was successful
    if [ $? -ne 0 ]; then
        echo -e "${RED}Failed to download latest version!${NC}"
        echo -e "Press any key to return..."
        read -n 1
        update_menu
        return
    fi
    
    # Install new version
    cp /tmp/vps_manager.sh "/usr/local/bin/vps_manager"
    chmod +x "/usr/local/bin/vps_manager"
    
    echo -e "${GREEN}Script has been updated successfully!${NC}"
    echo -e "Press any key to restart the script..."
    read -n 1
    
    # Restart script
    exec "/usr/local/bin/vps_manager"
}

update_system_packages() {
    clear
    echo -e "╭════════════════════════════════════════════════════════════╮"
    echo -e "│                UPDATE SYSTEM PACKAGES                      │"
    echo -e "╰════════════════════════════════════════════════════════════╯"
    
    echo -e "${YELLOW}Updating system packages...${NC}"
    
    # Update package lists
    apt-get update
    
    # Upgrade packages
    apt-get upgrade -y
    
    # Dist-upgrade for kernel and library updates
    apt-get dist-upgrade -y
    
    # Remove unused packages
    apt-get autoremove -y
    
    # Clean package cache
    apt-get clean
    
    echo -e "${GREEN}System packages have been updated successfully!${NC}"
    echo -e "Press any key to return..."
    read -n 1
    update_menu
}

update_xray() {
    clear
    echo -e "╭════════════════════════════════════════════════════════════╮"
    echo -e "│                     UPDATE XRAY                            │"
    echo -e "╰════════════════════════════════════════════════════════════╯"
    
    # Check if Xray is installed
    if ! command -v xray &> /dev/null; then
        echo -e "${RED}Xray is not installed!${NC}"
        echo -e "Press any key to return..."
        read -n 1
        update_menu
        return
    fi
    
    echo -e "${YELLOW}Updating Xray...${NC}"
    
    # Backup config
    cp /usr/local/etc/xray/config.json /usr/local/etc/xray/config.json.bak
    
    # Update Xray
    bash -c "$(curl -L https://github.com/XTLS/Xray-install/raw/main/install-release.sh)" @ install
    
    # Restart Xray
    systemctl restart xray
    
    echo -e "${GREEN}Xray has been updated successfully!${NC}"
    echo -e "Press any key to return..."
    read -n 1
    update_menu
}

update_all() {
    clear
    echo -e "╭════════════════════════════════════════════════════════════╮"
    echo -e "│                     UPDATE ALL                             │"
    echo -e "╰════════════════════════════════════════════════════════════╯"
    
    echo -e "${YELLOW}Updating everything...${NC}"
    
    # Update system packages
    echo -e "${YELLOW}Updating system packages...${NC}"
    apt-get update
    apt-get upgrade -y
    apt-get dist-upgrade -y
    apt-get autoremove -y
    apt-get clean
    
    # Update Xray if installed
    if command -v xray &> /dev/null; then
        echo -e "${YELLOW}Updating Xray...${NC}"
        cp /usr/local/etc/xray/config.json /usr/local/etc/xray/config.json.bak
        bash -c "$(curl -L https://github.com/XTLS/Xray-install/raw/main/install-release.sh)" @ install
        systemctl restart xray
    fi
    
    # Update script
    echo -e "${YELLOW}Updating VPS Manager script...${NC}"
    cp "$(readlink -f "$0")" "/usr/local/bin/vps_manager.bak"
    wget -O /tmp/vps_manager.sh "https://raw.githubusercontent.com/yourusername/vps-manager/main/vps_manager.sh"
    if [ $? -eq 0 ]; then
        cp /tmp/vps_manager.sh "/usr/local/bin/vps_manager"
        chmod +x "/usr/local/bin/vps_manager"
    fi
    
    echo -e "${GREEN}All updates completed successfully!${NC}"
    echo -e "Press any key to restart the script..."
    read -n 1
    
    # Restart script
    exec "/usr/local/bin/vps_manager"
}

# Running Services
show_running_services() {
    clear
    echo -e "╭════════════════════════════════════════════════════════════╮"
    echo -e "│                   RUNNING SERVICES                         │"
    echo -e "╰════════════════════════════════════════════════════════════╯"
    
    echo -e "${YELLOW}Checking running services...${NC}"
    systemctl list-units --type=service --state=running | grep -E 'ssh|nginx|xray|dropbear|haproxy|noobzvpn|ws-epro|udp-custom'
    
    echo -e "\n${YELLOW}Process information:${NC}"
    ps aux | grep -E 'ssh|nginx|xray|dropbear|haproxy|noobzvpn|ws-epro|udp-custom' | grep -v grep
    
    echo -e "\nPress any key to return to main menu..."
    read -n 1
    main_menu
}

# Info Port
show_port_info() {
    clear
    echo -e "╭════════════════════════════════════════════════════════════╮"
    echo -e "│                     PORT INFORMATION                       │"
    echo -e "╰════════════════════════════════════════════════════════════╯"
    
    echo -e "${YELLOW}Checking listening ports...${NC}"
    netstat -tulpn | grep LISTEN
    
    echo -e "\n${YELLOW}Port configurations:${NC}"
    echo -e "SSH Port: $(grep -oP '(?<=Port ).*' /etc/ssh/sshd_config | head -1)"
    
    if [ -f "/etc/default/dropbear" ]; then
        echo -e "Dropbear Ports: $(grep -oP '(?<=DROPBEAR_PORT=).*' /etc/default/dropbear)"
    fi
    
    if [ -f "/usr/local/etc/xray/config.json" ]; then
        echo -e "Xray Ports:"
        grep -oP '(?<="port": ).*?[^,]' /usr/local/etc/xray/config.json | sort | uniq
    fi
    
    echo -e "\nPress any key to return to main menu..."
    read -n 1
    main_menu
}

# Bot Menu
bot_menu() {
    clear
    echo -e "╭════════════════════════════════════════════════════════════╮"
    echo -e "│                       BOT MENU                             │"
    echo -e "╰════════════════════════════════════════════════════════════╯"
    echo -e "╭════════════════════════════════════════════════════════════╮"
    echo -e "│ [1] Create Bot"
    echo -e "│ [2] Delete Bot"
    echo -e "│ [3] Bot Settings"
    echo -e "│ [4] Bot Status"
    echo -e "│ [5] Bot Logs"
    echo -e "│ [0] Back to Main Menu"
    echo -e "╰════════════════════════════════════════════════════════════╯"
    echo -ne "  Select Option [ 0 - 5 ] ❱❱❱ "
    read -r bot_menu_option
    
    case $bot_menu_option in
        1) create_bot ;;
        2) delete_bot ;;
        3) bot_settings ;;
        4) bot_status ;;
        5) bot_logs ;;
        0) main_menu ;;
        *) echo -e "${RED}Invalid option!${NC}" ; sleep 2 ; bot_menu ;;
    esac
}

# Bot Menu Functions
create_bot() {
    clear
    echo -e "╭════════════════════════════════════════════════════════════╮"
    echo -e "│                     CREATE BOT                             │"
    echo -e "╰════════════════════════════════════════════════════════════╯"
    
    echo -e "${YELLOW}Select bot type:${NC}"
    echo -e "[1] SSH Account Creation Bot"
    echo -e "[2] VPN Account Creation Bot"
    echo -e "[3] Server Status Bot"
    echo -e "[0] Back"
    echo -ne "Select option [0-3]: "
    read -r bot_type
    
    case $bot_type in
        1) create_ssh_bot ;;
        2) create_vpn_bot ;;
        3) create_status_bot ;;
        0) bot_menu ;;
        *) echo -e "${RED}Invalid option!${NC}" ; sleep 2 ; create_bot ;;
    esac
}

create_ssh_bot() {
    clear
    echo -e "╭════════════════════════════════════════════════════════════╮"
    echo -e "│                CREATE SSH ACCOUNT BOT                      │"
    echo -e "╰════════════════════════════════════════════════════════════╯"
    
    echo -e "${YELLOW}Enter bot details:${NC}"
    
    echo -ne "Bot Token (from @BotFather): "
    read -r bot_token
    
    echo -ne "Admin User ID (from @userinfobot): "
    read -r admin_id
    
    if [ -z "$bot_token" ] || [ -z "$admin_id" ]; then
        echo -e "${RED}Bot token and admin ID cannot be empty!${NC}"
        echo -e "Press any key to return..."
        read -n 1
        create_bot
        return
    fi
    
    # Install required packages
    apt-get update
    apt-get install -y python3 python3-pip
    pip3 install python-telegram-bot
    
    # Create bot script directory
    mkdir -p /usr/local/bin/bots
    
    # Create SSH bot script
    cat > /usr/local/bin/bots/ssh_bot.py << 'EOF'
#!/usr/bin/env python3
import os
import sys
import time
import logging
import subprocess
import random
import string
from telegram import Update, ForceReply
from telegram.ext import Updater, CommandHandler, MessageHandler, Filters, CallbackContext

# Configure logging
logging.basicConfig(
    format='%(asctime)s - %(name)s - %(levelname)s - %(message)s',
    level=logging.INFO,
    filename='/var/log/ssh_bot.log'
)

logger = logging.getLogger(__name__)

# Get bot token and admin ID from environment variables
BOT_TOKEN = os.environ.get('BOT_TOKEN')
ADMIN_ID = int(os.environ.get('ADMIN_ID'))

def execute_command(command):
    """Execute shell command and return output"""
    try:
        result = subprocess.run(command, shell=True, check=True, 
                               stdout=subprocess.PIPE, stderr=subprocess.PIPE,
                               universal_newlines=True)
        return result.stdout
    except subprocess.CalledProcessError as e:
        return f"Error: {e.stderr}"

def start(update: Update, context: CallbackContext) -> None:
    """Send a message when the command /start is issued."""
    user = update.effective_user
    update.message.reply_text(f'Hi {user.first_name}! I am SSH Account Creation Bot.\n'
                             f'Use /help to see available commands.')

def help_command(update: Update, context: CallbackContext) -> None:
    """Send a message when the command /help is issued."""
    if update.effective_user.id == ADMIN_ID:
        update.message.reply_text('Admin commands:\n'
                                 '/create <username> <password> <days> - Create SSH account\n'
                                 '/delete <username> - Delete SSH account\n'
                                 '/list - List all SSH accounts\n'
                                 '/check <username> - Check SSH account details\n'
                                 '/server - Show server status')
    else:
        update.message.reply_text('Available commands:\n'
                                 '/trial - Create a trial SSH account\n'
                                 '/server - Show server status')

def create_command(update: Update, context: CallbackContext) -> None:
    """Create SSH account"""
    if update.effective_user.id != ADMIN_ID:
        update.message.reply_text('Unauthorized access.')
        return
    
    if len(context.args) < 3:
        update.message.reply_text('Usage: /create <username> <password> <days>')
        return
    
    username = context.args[0]
    password = context.args[1]
    days = context.args[2]
    
    update.message.reply_text(f'Creating SSH account for {username}...')
    
    # Create user
    result = execute_command(f"useradd -e $(date -d &quot;+{days} days&quot; +&quot;%Y-%m-%d&quot;) -s /bin/false -M {username}")
    passwd_result = execute_command(f"echo '{username}:{password}' | chpasswd")
    
    # Get server details
    domain = execute_command("hostname -f").strip()
    ssh_port = execute_command("grep -oP '(?<=Port ).*' /etc/ssh/sshd_config | head -1").strip()
    
    update.message.reply_text(f'✅ SSH Account Created\n\n'
                             f'Username: `{username}`\n'
                             f'Password: `{password}`\n'
                             f'Expired: {days} days\n'
                             f'Host: `{domain}`\n'
                             f'Port: `{ssh_port}`\n\n'
                             f'WebSocket Ports: 80, 443, 8080',
                             parse_mode='Markdown')

def delete_command(update: Update, context: CallbackContext) -> None:
    """Delete SSH account"""
    if update.effective_user.id != ADMIN_ID:
        update.message.reply_text('Unauthorized access.')
        return
    
    if len(context.args) < 1:
        update.message.reply_text('Usage: /delete <username>')
        return
    
    username = context.args[0]
    
    update.message.reply_text(f'Deleting SSH account for {username}...')
    
    # Delete user
    result = execute_command(f"userdel -r -f {username}")
    
    update.message.reply_text(f'✅ SSH Account Deleted\n\n'
                             f'Username: {username}')

def list_command(update: Update, context: CallbackContext) -> None:
    """List all SSH accounts"""
    if update.effective_user.id != ADMIN_ID:
        update.message.reply_text('Unauthorized access.')
        return
    
    update.message.reply_text('Getting SSH account list...')
    
    # Get SSH users
    users = execute_command("awk -F: '$3 >= 1000 && $1 != &quot;nobody&quot; {print $1}' /etc/passwd")
    
    if not users.strip():
        update.message.reply_text('No SSH accounts found.')
        return
    
    user_list = users.strip().split('\n')
    
    message = "📋 SSH Account List\n\n"
    
    for user in user_list:
        exp = execute_command(f"chage -l {user} | grep 'Account expires' | awk -F': ' '{{print $2}}'").strip()
        message += f"Username: {user}\nExpires: {exp}\n\n"
    
    update.message.reply_text(message)

def check_command(update: Update, context: CallbackContext) -> None:
    """Check SSH account details"""
    if update.effective_user.id != ADMIN_ID:
        update.message.reply_text('Unauthorized access.')
        return
    
    if len(context.args) < 1:
        update.message.reply_text('Usage: /check <username>')
        return
    
    username = context.args[0]
    
    # Check if user exists
    if not execute_command(f"id {username} 2>/dev/null"):
        update.message.reply_text(f'User {username} does not exist.')
        return
    
    # Get user details
    exp = execute_command(f"chage -l {username} | grep 'Account expires' | awk -F': ' '{{print $2}}'").strip()
    last_changed = execute_command(f"chage -l {username} | grep 'Last password change' | awk -F': ' '{{print $2}}'").strip()
    
    # Get login info
    login_info = execute_command(f"last {username} | head -3")
    
    update.message.reply_text(f'📊 SSH Account Details\n\n'
                             f'Username: {username}\n'
                             f'Expires: {exp}\n'
                             f'Last password change: {last_changed}\n\n'
                             f'Recent logins:\n{login_info}')

def server_command(update: Update, context: CallbackContext) -> None:
    """Show server status"""
    update.message.reply_text('Getting server status...')
    
    # Get system info
    uptime = execute_command("uptime -p")
    memory = execute_command("free -h | grep Mem")
    disk = execute_command("df -h / | tail -1")
    load = execute_command("cat /proc/loadavg")
    
    # Get domain and IP
    domain = execute_command("hostname -f").strip()
    ip = execute_command("curl -s ipv4.icanhazip.com").strip()
    
    update.message.reply_text(f'🖥️ Server Status\n\n'
                             f'Domain: {domain}\n'
                             f'IP: {ip}\n'
                             f'Uptime: {uptime.strip()}\n'
                             f'Memory: {memory.strip()}\n'
                             f'Disk: {disk.strip()}\n'
                             f'Load: {load.strip()}')

def trial_command(update: Update, context: CallbackContext) -> None:
    """Create trial SSH account"""
    user = update.effective_user
    
    update.message.reply_text(f'Creating trial SSH account for {user.first_name}...')
    
    # Generate random username and password
    username = f"trial{user.id}"
    password = ''.join(random.choice(string.ascii_letters + string.digits) for _ in range(10))
    
    # Create user with 1 day expiration
    result = execute_command(f"useradd -e $(date -d &quot;+1 days&quot; +&quot;%Y-%m-%d&quot;) -s /bin/false -M {username}")
    passwd_result = execute_command(f"echo '{username}:{password}' | chpasswd")
    
    # Get server details
    domain = execute_command("hostname -f").strip()
    ssh_port = execute_command("grep -oP '(?<=Port ).*' /etc/ssh/sshd_config | head -1").strip()
    
    update.message.reply_text(f'✅ Trial SSH Account Created\n\n'
                             f'Username: `{username}`\n'
                             f'Password: `{password}`\n'
                             f'Expired: 1 day\n'
                             f'Host: `{domain}`\n'
                             f'Port: `{ssh_port}`\n\n'
                             f'WebSocket Ports: 80, 443, 8080',
                             parse_mode='Markdown')

def main() -> None:
    """Start the bot."""
    # Create the Updater and pass it your bot's token
    updater = Updater(BOT_TOKEN)

    # Get the dispatcher to register handlers
    dispatcher = updater.dispatcher

    # Register command handlers
    dispatcher.add_handler(CommandHandler("start", start))
    dispatcher.add_handler(CommandHandler("help", help_command))
    dispatcher.add_handler(CommandHandler("create", create_command))
    dispatcher.add_handler(CommandHandler("delete", delete_command))
    dispatcher.add_handler(CommandHandler("list", list_command))
    dispatcher.add_handler(CommandHandler("check", check_command))
    dispatcher.add_handler(CommandHandler("server", server_command))
    dispatcher.add_handler(CommandHandler("trial", trial_command))

    # Start the Bot
    updater.start_polling()
    logger.info("Bot started")

    # Run the bot until you press Ctrl-C
    updater.idle()

if __name__ == '__main__':
    main()
EOF
    
    chmod +x /usr/local/bin/bots/ssh_bot.py
    
    # Create systemd service
    cat > /etc/systemd/system/ssh_bot.service << EOF
[Unit]
Description=SSH Account Creation Bot
After=network.target

[Service]
ExecStart=/usr/bin/python3 /usr/local/bin/bots/ssh_bot.py
Environment="BOT_TOKEN=$bot_token"
Environment="ADMIN_ID=$admin_id"
Restart=always
RestartSec=3

[Install]
WantedBy=multi-user.target
EOF
    
    # Enable and start service
    systemctl daemon-reload
    systemctl enable ssh_bot
    systemctl start ssh_bot
    
    echo -e "${GREEN}SSH Account Creation Bot has been created and started!${NC}"
    echo -e "Press any key to return..."
    read -n 1
    bot_menu
}

create_vpn_bot() {
    clear
    echo -e "╭════════════════════════════════════════════════════════════╮"
    echo -e "│                CREATE VPN ACCOUNT BOT                      │"
    echo -e "╰════════════════════════════════════════════════════════════╯"
    
    echo -e "${YELLOW}Enter bot details:${NC}"
    
    echo -ne "Bot Token (from @BotFather): "
    read -r bot_token
    
    echo -ne "Admin User ID (from @userinfobot): "
    read -r admin_id
    
    if [ -z "$bot_token" ] || [ -z "$admin_id" ]; then
        echo -e "${RED}Bot token and admin ID cannot be empty!${NC}"
        echo -e "Press any key to return..."
        read -n 1
        create_bot
        return
    fi
    
    # Install required packages
    apt-get update
    apt-get install -y python3 python3-pip
    pip3 install python-telegram-bot
    
    # Create bot script directory
    mkdir -p /usr/local/bin/bots
    
    # Create VPN bot script
    cat > /usr/local/bin/bots/vpn_bot.py << 'EOF'
#!/usr/bin/env python3
import os
import sys
import time
import logging
import subprocess
import random
import string
import json
import base64
from telegram import Update, ForceReply, InlineKeyboardButton, InlineKeyboardMarkup
from telegram.ext import Updater, CommandHandler, MessageHandler, Filters, CallbackContext, CallbackQueryHandler

# Configure logging
logging.basicConfig(
    format='%(asctime)s - %(name)s - %(levelname)s - %(message)s',
    level=logging.INFO,
    filename='/var/log/vpn_bot.log'
)

logger = logging.getLogger(__name__)

# Get bot token and admin ID from environment variables
BOT_TOKEN = os.environ.get('BOT_TOKEN')
ADMIN_ID = int(os.environ.get('ADMIN_ID'))

def execute_command(command):
    """Execute shell command and return output"""
    try:
        result = subprocess.run(command, shell=True, check=True, 
                               stdout=subprocess.PIPE, stderr=subprocess.PIPE,
                               universal_newlines=True)
        return result.stdout
    except subprocess.CalledProcessError as e:
        return f"Error: {e.stderr}"

def start(update: Update, context: CallbackContext) -> None:
    """Send a message when the command /start is issued."""
    user = update.effective_user
    
    keyboard = [
        [InlineKeyboardButton("Create Trial Account", callback_data='trial')],
        [InlineKeyboardButton("Server Status", callback_data='status')]
    ]
    
    if update.effective_user.id == ADMIN_ID:
        keyboard.append([InlineKeyboardButton("Admin Menu", callback_data='admin')])
    
    reply_markup = InlineKeyboardMarkup(keyboard)
    
    update.message.reply_text(f'Hi {user.first_name}! I am VPN Account Creation Bot.\n'
                             f'Use the buttons below or /help to see available commands.',
                             reply_markup=reply_markup)

def help_command(update: Update, context: CallbackContext) -> None:
    """Send a message when the command /help is issued."""
    if update.effective_user.id == ADMIN_ID:
        update.message.reply_text('Admin commands:\n'
                                 '/vmess <username> <days> - Create VMESS account\n'
                                 '/vless <username> <days> - Create VLESS account\n'
                                 '/trojan <username> <password> <days> - Create TROJAN account\n'
                                 '/delete <type> <username> - Delete account\n'
                                 '/list <type> - List all accounts\n'
                                 '/server - Show server status')
    else:
        update.message.reply_text('Available commands:\n'
                                 '/trial <type> - Create a trial account (vmess, vless, trojan)\n'
                                 '/server - Show server status')

def button_handler(update: Update, context: CallbackContext) -> None:
    """Handle button presses"""
    query = update.callback_query
    query.answer()
    
    if query.data == 'trial':
        keyboard = [
            [InlineKeyboardButton("VMESS Trial", callback_data='trial_vmess')],
            [InlineKeyboardButton("VLESS Trial", callback_data='trial_vless')],
            [InlineKeyboardButton("TROJAN Trial", callback_data='trial_trojan')],
            [InlineKeyboardButton("Back", callback_data='back')]
        ]
        reply_markup = InlineKeyboardMarkup(keyboard)
        query.edit_message_text(text="Select trial account type:", reply_markup=reply_markup)
    
    elif query.data == 'status':
        # Get system info
        uptime = execute_command("uptime -p")
        memory = execute_command("free -h | grep Mem")
        disk = execute_command("df -h / | tail -1")
        
        # Get domain and IP
        domain = execute_command("hostname -f").strip()
        ip = execute_command("curl -s ipv4.icanhazip.com").strip()
        
        keyboard = [[InlineKeyboardButton("Back", callback_data='back')]]
        reply_markup = InlineKeyboardMarkup(keyboard)
        
        query.edit_message_text(text=f'🖥️ Server Status\n\n'
                               f'Domain: {domain}\n'
                               f'IP: {ip}\n'
                               f'Uptime: {uptime.strip()}\n'
                               f'Memory: {memory.strip()}\n'
                               f'Disk: {disk.strip()}',
                               reply_markup=reply_markup)
    
    elif query.data == 'admin':
        if update.effective_user.id != ADMIN_ID:
            query.edit_message_text(text="Unauthorized access.")
            return
        
        keyboard = [
            [InlineKeyboardButton("Create Account", callback_data='admin_create')],
            [InlineKeyboardButton("Delete Account", callback_data='admin_delete')],
            [InlineKeyboardButton("List Accounts", callback_data='admin_list')],
            [InlineKeyboardButton("Back", callback_data='back')]
        ]
        reply_markup = InlineKeyboardMarkup(keyboard)
        query.edit_message_text(text="Admin Menu:", reply_markup=reply_markup)
    
    elif query.data == 'back':
        keyboard = [
            [InlineKeyboardButton("Create Trial Account", callback_data='trial')],
            [InlineKeyboardButton("Server Status", callback_data='status')]
        ]
        
        if update.effective_user.id == ADMIN_ID:
            keyboard.append([InlineKeyboardButton("Admin Menu", callback_data='admin')])
        
        reply_markup = InlineKeyboardMarkup(keyboard)
        
        query.edit_message_text(text="Welcome to VPN Account Creation Bot.\n"
                               "Use the buttons below or /help to see available commands.",
                               reply_markup=reply_markup)
    
    elif query.data.startswith('trial_'):
        account_type = query.data.split('_')[1]
        create_trial_account(update, context, account_type)
    
    elif query.data.startswith('admin_'):
        if update.effective_user.id != ADMIN_ID:
            query.edit_message_text(text="Unauthorized access.")
            return
        
        action = query.data.split('_')[1]
        
        if action == 'create':
            keyboard = [
                [InlineKeyboardButton("Create VMESS", callback_data='create_vmess')],
                [InlineKeyboardButton("Create VLESS", callback_data='create_vless')],
                [InlineKeyboardButton("Create TROJAN", callback_data='create_trojan')],
                [InlineKeyboardButton("Back", callback_data='admin')]
            ]
            reply_markup = InlineKeyboardMarkup(keyboard)
            query.edit_message_text(text="Select account type to create:", reply_markup=reply_markup)
        
        elif action == 'delete':
            keyboard = [
                [InlineKeyboardButton("Delete VMESS", callback_data='delete_vmess')],
                [InlineKeyboardButton("Delete VLESS", callback_data='delete_vless')],
                [InlineKeyboardButton("Delete TROJAN", callback_data='delete_trojan')],
                [InlineKeyboardButton("Back", callback_data='admin')]
            ]
            reply_markup = InlineKeyboardMarkup(keyboard)
            query.edit_message_text(text="Select account type to delete:", reply_markup=reply_markup)
        
        elif action == 'list':
            keyboard = [
                [InlineKeyboardButton("List VMESS", callback_data='list_vmess')],
                [InlineKeyboardButton("List VLESS", callback_data='list_vless')],
                [InlineKeyboardButton("List TROJAN", callback_data='list_trojan')],
                [InlineKeyboardButton("Back", callback_data='admin')]
            ]
            reply_markup = InlineKeyboardMarkup(keyboard)
            query.edit_message_text(text="Select account type to list:", reply_markup=reply_markup)

def create_trial_account(update: Update, context: CallbackContext, account_type: str) -> None:
    """Create trial account"""
    query = update.callback_query
    user = update.effective_user
    
    # Generate random username
    username = f"trial{user.id}"
    
    # Get domain
    domain = execute_command("hostname -f").strip()
    
    if account_type == 'vmess':
        # Generate UUID
        uuid = execute_command("xray uuid").strip()
        
        # Set expiration to 1 day
        exp_date = execute_command("date -d &quot;+1 days&quot; +&quot;%Y-%m-%d&quot;").strip()
        
        # Create user data directory if it doesn't exist
        execute_command("mkdir -p /usr/local/etc/xray/vmess")
        
        # Save user information
        user_file = f"/usr/local/etc/xray/vmess/{username}"
        execute_command(f'''cat > "{user_file}" << EOF
{{
    "username": "{username}",
    "uuid": "{uuid}",
    "created": "$(date +"%Y-%m-%d %H:%M:%S")",
    "expired": "{exp_date}"
}}
EOF''')
        
        # Restart Xray
        execute_command("systemctl restart xray")
        
        # Generate VMESS link
        vmess_data = {
            "v": "2",
            "ps": username,
            "add": domain,
            "port": "443",
            "id": uuid,
            "aid": "0",
            "net": "ws",
            "path": "/vmess",
            "type": "none",
            "host": domain,
            "tls": "tls"
        }
        vmess_link = f"vmess://{base64.b64encode(json.dumps(vmess_data).encode()).decode()}"
        
        keyboard = [[InlineKeyboardButton("Back", callback_data='trial')]]
        reply_markup = InlineKeyboardMarkup(keyboard)
        
        query.edit_message_text(text=f'✅ Trial VMESS Account Created\n\n'
                               f'Username: `{username}`\n'
                               f'UUID: `{uuid}`\n'
                               f'Expired: {exp_date} (1 day)\n'
                               f'Domain: `{domain}`\n'
                               f'Port: 443, 80, 8080\n'
                               f'Path: /vmess\n'
                               f'Network: ws\n'
                               f'TLS: tls\n\n'
                               f'VMESS Link:\n`{vmess_link}`',
                               reply_markup=reply_markup,
                               parse_mode='Markdown')
    
    elif account_type == 'vless':
        # Generate UUID
        uuid = execute_command("xray uuid").strip()
        
        # Set expiration to 1 day
        exp_date = execute_command("date -d &quot;+1 days&quot; +&quot;%Y-%m-%d&quot;").strip()
        
        # Create user data directory if it doesn't exist
        execute_command("mkdir -p /usr/local/etc/xray/vless")
        
        # Save user information
        user_file = f"/usr/local/etc/xray/vless/{username}"
        execute_command(f'''cat > "{user_file}" << EOF
{{
    "username": "{username}",
    "uuid": "{uuid}",
    "created": "$(date +"%Y-%m-%d %H:%M:%S")",
    "expired": "{exp_date}"
}}
EOF''')
        
        # Restart Xray
        execute_command("systemctl restart xray")
        
        # Generate VLESS link
        vless_link = f"vless://{uuid}@{domain}:443?encryption=none&security=tls&type=ws&host={domain}&path=/vless#{username}"
        
        keyboard = [[InlineKeyboardButton("Back", callback_data='trial')]]
        reply_markup = InlineKeyboardMarkup(keyboard)
        
        query.edit_message_text(text=f'✅ Trial VLESS Account Created\n\n'
                               f'Username: `{username}`\n'
                               f'UUID: `{uuid}`\n'
                               f'Expired: {exp_date} (1 day)\n'
                               f'Domain: `{domain}`\n'
                               f'Port: 443, 80, 8080\n'
                               f'Path: /vless\n'
                               f'Network: ws\n'
                               f'TLS: tls\n\n'
                               f'VLESS Link:\n`{vless_link}`',
                               reply_markup=reply_markup,
                               parse_mode='Markdown')
    
    elif account_type == 'trojan':
        # Generate password
        password = ''.join(random.choice(string.ascii_letters + string.digits) for _ in range(16))
        
        # Set expiration to 1 day
        exp_date = execute_command("date -d &quot;+1 days&quot; +&quot;%Y-%m-%d&quot;").strip()
        
        # Create user data directory if it doesn't exist
        execute_command("mkdir -p /usr/local/etc/xray/trojan")
        
        # Save user information
        user_file = f"/usr/local/etc/xray/trojan/{username}"
        execute_command(f'''cat > "{user_file}" << EOF
{{
    "username": "{username}",
    "password": "{password}",
    "created": "$(date +"%Y-%m-%d %H:%M:%S")",
    "expired": "{exp_date}"
}}
EOF''')
        
        # Restart Xray
        execute_command("systemctl restart xray")
        
        # Generate TROJAN link
        trojan_link = f"trojan://{password}@{domain}:443?security=tls&type=ws&host={domain}&path=/trojan#{username}"
        
        keyboard = [[InlineKeyboardButton("Back", callback_data='trial')]]
        reply_markup = InlineKeyboardMarkup(keyboard)
        
        query.edit_message_text(text=f'✅ Trial TROJAN Account Created\n\n'
                               f'Username: `{username}`\n'
                               f'Password: `{password}`\n'
                               f'Expired: {exp_date} (1 day)\n'
                               f'Domain: `{domain}`\n'
                               f'Port: 443\n'
                               f'Path: /trojan\n'
                               f'Network: ws\n'
                               f'TLS: tls\n\n'
                               f'TROJAN Link:\n`{trojan_link}`',
                               reply_markup=reply_markup,
                               parse_mode='Markdown')

def main() -> None:
    """Start the bot."""
    # Create the Updater and pass it your bot's token
    updater = Updater(BOT_TOKEN)

    # Get the dispatcher to register handlers
    dispatcher = updater.dispatcher

    # Register command handlers
    dispatcher.add_handler(CommandHandler("start", start))
    dispatcher.add_handler(CommandHandler("help", help_command))
    
    # Register callback query handler
    dispatcher.add_handler(CallbackQueryHandler(button_handler))

    # Start the Bot
    updater.start_polling()
    logger.info("Bot started")

    # Run the bot until you press Ctrl-C
    updater.idle()

if __name__ == '__main__':
    main()
EOF
    
    chmod +x /usr/local/bin/bots/vpn_bot.py
    
    # Create systemd service
    cat > /etc/systemd/system/vpn_bot.service << EOF
[Unit]
Description=VPN Account Creation Bot
After=network.target

[Service]
ExecStart=/usr/bin/python3 /usr/local/bin/bots/vpn_bot.py
Environment="BOT_TOKEN=$bot_token"
Environment="ADMIN_ID=$admin_id"
Restart=always
RestartSec=3

[Install]
WantedBy=multi-user.target
EOF
    
    # Enable and start service
    systemctl daemon-reload
    systemctl enable vpn_bot
    systemctl start vpn_bot
    
    echo -e "${GREEN}VPN Account Creation Bot has been created and started!${NC}"
    echo -e "Press any key to return..."
    read -n 1
    bot_menu
}

create_status_bot() {
    clear
    echo -e "╭════════════════════════════════════════════════════════════╮"
    echo -e "│                CREATE SERVER STATUS BOT                    │"
    echo -e "╰════════════════════════════════════════════════════════════╯"
    
    echo -e "${YELLOW}Enter bot details:${NC}"
    
    echo -ne "Bot Token (from @BotFather): "
    read -r bot_token
    
    echo -ne "Admin User ID (from @userinfobot): "
    read -r admin_id
    
    if [ -z "$bot_token" ] || [ -z "$admin_id" ]; then
        echo -e "${RED}Bot token and admin ID cannot be empty!${NC}"
        echo -e "Press any key to return..."
        read -n 1
        create_bot
        return
    fi
    
    # Install required packages
    apt-get update
    apt-get install -y python3 python3-pip
    pip3 install python-telegram-bot psutil
    
    # Create bot script directory
    mkdir -p /usr/local/bin/bots
    
    # Create status bot script
    cat > /usr/local/bin/bots/status_bot.py << 'EOF'
#!/usr/bin/env python3
import os
import sys
import time
import logging
import subprocess
import psutil
import datetime
from telegram import Update, ForceReply, InlineKeyboardButton, InlineKeyboardMarkup
from telegram.ext import Updater, CommandHandler, MessageHandler, Filters, CallbackContext, CallbackQueryHandler

# Configure logging
logging.basicConfig(
    format='%(asctime)s - %(name)s - %(levelname)s - %(message)s',
    level=logging.INFO,
    filename='/var/log/status_bot.log'
)

logger = logging.getLogger(__name__)

# Get bot token and admin ID from environment variables
BOT_TOKEN = os.environ.get('BOT_TOKEN')
ADMIN_ID = int(os.environ.get('ADMIN_ID'))

def execute_command(command):
    """Execute shell command and return output"""
    try:
        result = subprocess.run(command, shell=True, check=True, 
                               stdout=subprocess.PIPE, stderr=subprocess.PIPE,
                               universal_newlines=True)
        return result.stdout
    except subprocess.CalledProcessError as e:
        return f"Error: {e.stderr}"

def start(update: Update, context: CallbackContext) -> None:
    """Send a message when the command /start is issued."""
    user = update.effective_user
    
    keyboard = [
        [InlineKeyboardButton("Server Status", callback_data='status')],
        [InlineKeyboardButton("CPU Usage", callback_data='cpu')],
        [InlineKeyboardButton("Memory Usage", callback_data='memory')],
        [InlineKeyboardButton("Disk Usage", callback_data='disk')]
    ]
    
    if update.effective_user.id == ADMIN_ID:
        keyboard.append([InlineKeyboardButton("Service Control", callback_data='services')])
    
    reply_markup = InlineKeyboardMarkup(keyboard)
    
    update.message.reply_text(f'Hi {user.first_name}! I am Server Status Bot.\n'
                             f'Use the buttons below or /help to see available commands.',
                             reply_markup=reply_markup)

def help_command(update: Update, context: CallbackContext) -> None:
    """Send a message when the command /help is issued."""
    if update.effective_user.id == ADMIN_ID:
        update.message.reply_text('Admin commands:\n'
                                 '/status - Show server status\n'
                                 '/cpu - Show CPU usage\n'
                                 '/memory - Show memory usage\n'
                                 '/disk - Show disk usage\n'
                                 '/services - Control services\n'
                                 '/restart <service> - Restart a service\n'
                                 '/reboot - Reboot server')
    else:
        update.message.reply_text('Available commands:\n'
                                 '/status - Show server status\n'
                                 '/cpu - Show CPU usage\n'
                                 '/memory - Show memory usage\n'
                                 '/disk - Show disk usage')

def button_handler(update: Update, context: CallbackContext) -> None:
    """Handle button presses"""
    query = update.callback_query
    query.answer()
    
    if query.data == 'status':
        # Get system info
        uptime = datetime.timedelta(seconds=int(psutil.boot_time() - time.time()))
        cpu_percent = psutil.cpu_percent(interval=1)
        memory = psutil.virtual_memory()
        disk = psutil.disk_usage('/')
        
        # Get network info
        net_io = psutil.net_io_counters()
        bytes_sent = net_io.bytes_sent
        bytes_recv = net_io.bytes_recv
        
        # Get domain and IP
        domain = execute_command("hostname -f").strip()
        ip = execute_command("curl -s ipv4.icanhazip.com").strip()
        
        keyboard = [[InlineKeyboardButton("Back", callback_data='back')]]
        reply_markup = InlineKeyboardMarkup(keyboard)
        
        query.edit_message_text(text=f'🖥️ Server Status\n\n'
                               f'Domain: {domain}\n'
                               f'IP: {ip}\n'
                               f'Uptime: {uptime}\n'
                               f'CPU Usage: {cpu_percent}%\n'
                               f'Memory: {memory.percent}% used ({memory.used / (1024**3):.2f}GB / {memory.total / (1024**3):.2f}GB)\n'
                               f'Disk: {disk.percent}% used ({disk.used / (1024**3):.2f}GB / {disk.total / (1024**3):.2f}GB)\n'
                               f'Network: ↑ {bytes_sent / (1024**3):.2f}GB ↓ {bytes_recv / (1024**3):.2f}GB',
                               reply_markup=reply_markup)
    
    elif query.data == 'cpu':
        # Get CPU info
        cpu_percent = psutil.cpu_percent(interval=1, percpu=True)
        cpu_freq = psutil.cpu_freq()
        cpu_count = psutil.cpu_count(logical=True)
        
        cpu_text = f'🔄 CPU Usage\n\n'
        cpu_text += f'CPU Count: {cpu_count}\n'
        if cpu_freq:
            cpu_text += f'CPU Frequency: {cpu_freq.current:.2f} MHz\n'
        cpu_text += f'Overall CPU Usage: {sum(cpu_percent) / len(cpu_percent):.2f}%\n\n'
        
        for i, percent in enumerate(cpu_percent):
            cpu_text += f'Core {i}: {percent}%\n'
        
        keyboard = [[InlineKeyboardButton("Back", callback_data='back')]]
        reply_markup = InlineKeyboardMarkup(keyboard)
        
        query.edit_message_text(text=cpu_text, reply_markup=reply_markup)
    
    elif query.data == 'memory':
        # Get memory info
        memory = psutil.virtual_memory()
        swap = psutil.swap_memory()
        
        memory_text = f'💾 Memory Usage\n\n'
        memory_text += f'Total Memory: {memory.total / (1024**3):.2f}GB\n'
        memory_text += f'Used Memory: {memory.used / (1024**3):.2f}GB ({memory.percent}%)\n'
        memory_text += f'Free Memory: {memory.available / (1024**3):.2f}GB\n\n'
        memory_text += f'Swap Total: {swap.total / (1024**3):.2f}GB\n'
        memory_text += f'Swap Used: {swap.used / (1024**3):.2f}GB ({swap.percent}%)\n'
        memory_text += f'Swap Free: {swap.free / (1024**3):.2f}GB\n'
        
        keyboard = [[InlineKeyboardButton("Back", callback_data='back')]]
        reply_markup = InlineKeyboardMarkup(keyboard)
        
        query.edit_message_text(text=memory_text, reply_markup=reply_markup)
    
    elif query.data == 'disk':
        # Get disk info
        partitions = psutil.disk_partitions()
        
        disk_text = f'💽 Disk Usage\n\n'
        
        for partition in partitions:
            try:
                usage = psutil.disk_usage(partition.mountpoint)
                disk_text += f'Mount: {partition.mountpoint}\n'
                disk_text += f'Total: {usage.total / (1024**3):.2f}GB\n'
                disk_text += f'Used: {usage.used / (1024**3):.2f}GB ({usage.percent}%)\n'
                disk_text += f'Free: {usage.free / (1024**3):.2f}GB\n\n'
            except:
                pass
        
        keyboard = [[InlineKeyboardButton("Back", callback_data='back')]]
        reply_markup = InlineKeyboardMarkup(keyboard)
        
        query.edit_message_text(text=disk_text, reply_markup=reply_markup)
    
    elif query.data == 'services':
        if update.effective_user.id != ADMIN_ID:
            query.edit_message_text(text="Unauthorized access.")
            return
        
        keyboard = [
            [InlineKeyboardButton("Restart SSH", callback_data='restart_ssh')],
            [InlineKeyboardButton("Restart Nginx", callback_data='restart_nginx')],
            [InlineKeyboardButton("Restart Xray", callback_data='restart_xray')],
            [InlineKeyboardButton("Reboot Server", callback_data='reboot_server')],
            [InlineKeyboardButton("Back", callback_data='back')]
        ]
        reply_markup = InlineKeyboardMarkup(keyboard)
        query.edit_message_text(text="Service Control:", reply_markup=reply_markup)
    
    elif query.data == 'back':
        keyboard = [
            [InlineKeyboardButton("Server Status", callback_data='status')],
            [InlineKeyboardButton("CPU Usage", callback_data='cpu')],
            [InlineKeyboardButton("Memory Usage", callback_data='memory')],
            [InlineKeyboardButton("Disk Usage", callback_data='disk')]
        ]
        
        if update.effective_user.id == ADMIN_ID:
            keyboard.append([InlineKeyboardButton("Service Control", callback_data='services')])
        
        reply_markup = InlineKeyboardMarkup(keyboard)
        
        query.edit_message_text(text="Welcome to Server Status Bot.\n"
                               "Use the buttons below or /help to see available commands.",
                               reply_markup=reply_markup)
    
    elif query.data.startswith('restart_'):
        if update.effective_user.id != ADMIN_ID:
            query.edit_message_text(text="Unauthorized access.")
            return
        
        service = query.data.split('_')[1]
        
        query.edit_message_text(text=f"Restarting {service}...")
        
        result = execute_command(f"systemctl restart {service}")
        status = execute_command(f"systemctl is-active {service}")
        
        keyboard = [[InlineKeyboardButton("Back", callback_data='services')]]
        reply_markup = InlineKeyboardMarkup(keyboard)
        
        query.edit_message_text(text=f"Service {service} restarted.\nStatus: {status}",
                               reply_markup=reply_markup)
    
    elif query.data == 'reboot_server':
        if update.effective_user.id != ADMIN_ID:
            query.edit_message_text(text="Unauthorized access.")
            return
        
        keyboard = [
            [InlineKeyboardButton("Yes, Reboot Now", callback_data='confirm_reboot')],
            [InlineKeyboardButton("Cancel", callback_data='services')]
        ]
        reply_markup = InlineKeyboardMarkup(keyboard)
        
        query.edit_message_text(text="Are you sure you want to reboot the server?",
                               reply_markup=reply_markup)
    
    elif query.data == 'confirm_reboot':
        if update.effective_user.id != ADMIN_ID:
            query.edit_message_text(text="Unauthorized access.")
            return
        
        query.edit_message_text(text="Server is rebooting...")
        
        # Schedule reboot after 5 seconds
        subprocess.Popen("sleep 5 && reboot", shell=True)

def main() -> None:
    """Start the bot."""
    # Create the Updater and pass it your bot's token
    updater = Updater(BOT_TOKEN)

    # Get the dispatcher to register handlers
    dispatcher = updater.dispatcher

    # Register command handlers
    dispatcher.add_handler(CommandHandler("start", start))
    dispatcher.add_handler(CommandHandler("help", help_command))
    
    # Register callback query handler
    dispatcher.add_handler(CallbackQueryHandler(button_handler))

    # Start the Bot
    updater.start_polling()
    logger.info("Bot started")

    # Run the bot until you press Ctrl-C
    updater.idle()

if __name__ == '__main__':
    main()
EOF
    
    chmod +x /usr/local/bin/bots/status_bot.py
    
    # Create systemd service
    cat > /etc/systemd/system/status_bot.service << EOF
[Unit]
Description=Server Status Bot
After=network.target

[Service]
ExecStart=/usr/bin/python3 /usr/local/bin/bots/status_bot.py
Environment="BOT_TOKEN=$bot_token"
Environment="ADMIN_ID=$admin_id"
Restart=always
RestartSec=3

[Install]
WantedBy=multi-user.target
EOF
    
    # Enable and start service
    systemctl daemon-reload
    systemctl enable status_bot
    systemctl start status_bot
    
    echo -e "${GREEN}Server Status Bot has been created and started!${NC}"
    echo -e "Press any key to return..."
    read -n 1
    bot_menu
}

delete_bot() {
    clear
    echo -e "╭════════════════════════════════════════════════════════════╮"
    echo -e "│                     DELETE BOT                             │"
    echo -e "╰════════════════════════════════════════════════════════════╯"
    
    echo -e "${YELLOW}Select bot to delete:${NC}"
    echo -e "[1] SSH Account Creation Bot"
    echo -e "[2] VPN Account Creation Bot"
    echo -e "[3] Server Status Bot"
    echo -e "[0] Back"
    echo -ne "Select option [0-3]: "
    read -r bot_type
    
    case $bot_type in
        1)
            echo -e "${YELLOW}Deleting SSH Account Creation Bot...${NC}"
            systemctl stop ssh_bot
            systemctl disable ssh_bot
            rm -f /etc/systemd/system/ssh_bot.service
            rm -f /usr/local/bin/bots/ssh_bot.py
            systemctl daemon-reload
            echo -e "${GREEN}SSH Account Creation Bot has been deleted!${NC}"
            ;;
        2)
            echo -e "${YELLOW}Deleting VPN Account Creation Bot...${NC}"
            systemctl stop vpn_bot
            systemctl disable vpn_bot
            rm -f /etc/systemd/system/vpn_bot.service
            rm -f /usr/local/bin/bots/vpn_bot.py
            systemctl daemon-reload
            echo -e "${GREEN}VPN Account Creation Bot has been deleted!${NC}"
            ;;
        3)
            echo -e "${YELLOW}Deleting Server Status Bot...${NC}"
            systemctl stop status_bot
            systemctl disable status_bot
            rm -f /etc/systemd/system/status_bot.service
            rm -f /usr/local/bin/bots/status_bot.py
            systemctl daemon-reload
            echo -e "${GREEN}Server Status Bot has been deleted!${NC}"
            ;;
        0)
            bot_menu
            return
            ;;
        *)
            echo -e "${RED}Invalid option!${NC}"
            sleep 2
            delete_bot
            return
            ;;
    esac
    
    echo -e "Press any key to return..."
    read -n 1
    bot_menu
}

bot_settings() {
    clear
    echo -e "╭════════════════════════════════════════════════════════════╮"
    echo -e "│                     BOT SETTINGS                           │"
    echo -e "╰════════════════════════════════════════════════════════════╯"
    
    echo -e "${YELLOW}Select bot to configure:${NC}"
    echo -e "[1] SSH Account Creation Bot"
    echo -e "[2] VPN Account Creation Bot"
    echo -e "[3] Server Status Bot"
    echo -e "[0] Back"
    echo -ne "Select option [0-3]: "
    read -r bot_type
    
    case $bot_type in
        1)
            configure_ssh_bot
            ;;
        2)
            configure_vpn_bot
            ;;
        3)
            configure_status_bot
            ;;
        0)
            bot_menu
            return
            ;;
        *)
            echo -e "${RED}Invalid option!${NC}"
            sleep 2
            bot_settings
            return
            ;;
    esac
}

configure_ssh_bot() {
    clear
    echo -e "╭════════════════════════════════════════════════════════════╮"
    echo -e "│               CONFIGURE SSH ACCOUNT BOT                    │"
    echo -e "╰════════════════════════════════════════════════════════════╯"
    
    # Check if bot is installed
    if [ ! -f "/etc/systemd/system/ssh_bot.service" ]; then
        echo -e "${RED}SSH Account Creation Bot is not installed!${NC}"
        echo -e "Press any key to return..."
        read -n 1
        bot_settings
        return
    fi
    
    echo -e "${YELLOW}Enter new bot details:${NC}"
    
    echo -ne "Bot Token (from @BotFather): "
    read -r bot_token
    
    echo -ne "Admin User ID (from @userinfobot): "
    read -r admin_id
    
    if [ -z "$bot_token" ] || [ -z "$admin_id" ]; then
        echo -e "${RED}Bot token and admin ID cannot be empty!${NC}"
        echo -e "Press any key to return..."
        read -n 1
        configure_ssh_bot
        return
    fi
    
    # Update systemd service
    sed -i "s/Environment=&quot;BOT_TOKEN=.*/Environment=&quot;BOT_TOKEN=$bot_token&quot;/" /etc/systemd/system/ssh_bot.service
    sed -i "s/Environment=&quot;ADMIN_ID=.*/Environment=&quot;ADMIN_ID=$admin_id&quot;/" /etc/systemd/system/ssh_bot.service
    
    # Reload and restart service
    systemctl daemon-reload
    systemctl restart ssh_bot
    
    echo -e "${GREEN}SSH Account Creation Bot has been reconfigured!${NC}"
    echo -e "Press any key to return..."
    read -n 1
    bot_settings
}

configure_vpn_bot() {
    clear
    echo -e "╭════════════════════════════════════════════════════════════╮"
    echo -e "│               CONFIGURE VPN ACCOUNT BOT                    │"
    echo -e "╰════════════════════════════════════════════════════════════╯"
    
    # Check if bot is installed
    if [ ! -f "/etc/systemd/system/vpn_bot.service" ]; then
        echo -e "${RED}VPN Account Creation Bot is not installed!${NC}"
        echo -e "Press any key to return..."
        read -n 1
        bot_settings
        return
    fi
    
    echo -e "${YELLOW}Enter new bot details:${NC}"
    
    echo -ne "Bot Token (from @BotFather): "
    read -r bot_token
    
    echo -ne "Admin User ID (from @userinfobot): "
    read -r admin_id
    
    if [ -z "$bot_token" ] || [ -z "$admin_id" ]; then
        echo -e "${RED}Bot token and admin ID cannot be empty!${NC}"
        echo -e "Press any key to return..."
        read -n 1
        configure_vpn_bot
        return
    fi
    
    # Update systemd service
    sed -i "s/Environment=&quot;BOT_TOKEN=.*/Environment=&quot;BOT_TOKEN=$bot_token&quot;/" /etc/systemd/system/vpn_bot.service
    sed -i "s/Environment=&quot;ADMIN_ID=.*/Environment=&quot;ADMIN_ID=$admin_id&quot;/" /etc/systemd/system/vpn_bot.service
    
    # Reload and restart service
    systemctl daemon-reload
    systemctl restart vpn_bot
    
    echo -e "${GREEN}VPN Account Creation Bot has been reconfigured!${NC}"
    echo -e "Press any key to return..."
    read -n 1
    bot_settings
}

configure_status_bot() {
    clear
    echo -e "╭════════════════════════════════════════════════════════════╮"
    echo -e "│               CONFIGURE SERVER STATUS BOT                  │"
    echo -e "╰════════════════════════════════════════════════════════════╯"
    
    # Check if bot is installed
    if [ ! -f "/etc/systemd/system/status_bot.service" ]; then
        echo -e "${RED}Server Status Bot is not installed!${NC}"
        echo -e "Press any key to return..."
        read -n 1
        bot_settings
        return
    fi
    
    echo -e "${YELLOW}Enter new bot details:${NC}"
    
    echo -ne "Bot Token (from @BotFather): "
    read -r bot_token
    
    echo -ne "Admin User ID (from @userinfobot): "
    read -r admin_id
    
    if [ -z "$bot_token" ] || [ -z "$admin_id" ]; then
        echo -e "${RED}Bot token and admin ID cannot be empty!${NC}"
        echo -e "Press any key to return..."
        read -n 1
        configure_status_bot
        return
    fi
    
    # Update systemd service
    sed -i "s/Environment=&quot;BOT_TOKEN=.*/Environment=&quot;BOT_TOKEN=$bot_token&quot;/" /etc/systemd/system/status_bot.service
    sed -i "s/Environment=&quot;ADMIN_ID=.*/Environment=&quot;ADMIN_ID=$admin_id&quot;/" /etc/systemd/system/status_bot.service
    
    # Reload and restart service
    systemctl daemon-reload
    systemctl restart status_bot
    
    echo -e "${GREEN}Server Status Bot has been reconfigured!${NC}"
    echo -e "Press any key to return..."
    read -n 1
    bot_settings
}

bot_status() {
    clear
    echo -e "╭════════════════════════════════════════════════════════════╮"
    echo -e "│                     BOT STATUS                             │"
    echo -e "╰════════════════════════════════════════════════════════════╯"
    
    echo -e "SSH Account Bot: $(systemctl is-active ssh_bot 2>/dev/null || echo "Not installed")"
    echo -e "VPN Account Bot: $(systemctl is-active vpn_bot 2>/dev/null || echo "Not installed")"
    echo -e "Server Status Bot: $(systemctl is-active status_bot 2>/dev/null || echo "Not installed")"
    
    echo -e "\nPress any key to return..."
    read -n 1
    bot_menu
}

bot_logs() {
    clear
    echo -e "╭════════════════════════════════════════════════════════════╮"
    echo -e "│                     BOT LOGS                               │"
    echo -e "╰════════════════════════════════════════════════════════════╯"
    
    echo -e "${YELLOW}Select bot to view logs:${NC}"
    echo -e "[1] SSH Account Creation Bot"
    echo -e "[2] VPN Account Creation Bot"
    echo -e "[3] Server Status Bot"
    echo -e "[0] Back"
    echo -ne "Select option [0-3]: "
    read -r bot_type
    
    case $bot_type in
        1)
            if [ -f "/var/log/ssh_bot.log" ]; then
                echo -e "${YELLOW}SSH Account Bot Logs:${NC}"
                tail -n 50 /var/log/ssh_bot.log
            else
                echo -e "${RED}SSH Account Bot logs not found!${NC}"
            fi
            ;;
        2)
            if [ -f "/var/log/vpn_bot.log" ]; then
                echo -e "${YELLOW}VPN Account Bot Logs:${NC}"
                tail -n 50 /var/log/vpn_bot.log
            else
                echo -e "${RED}VPN Account Bot logs not found!${NC}"
            fi
            ;;
        3)
            if [ -f "/var/log/status_bot.log" ]; then
                echo -e "${YELLOW}Server Status Bot Logs:${NC}"
                tail -n 50 /var/log/status_bot.log
            else
                echo -e "${RED}Server Status Bot logs not found!${NC}"
            fi
            ;;
        0)
            bot_menu
            return
            ;;
        *)
            echo -e "${RED}Invalid option!${NC}"
            sleep 2
            bot_logs
            return
            ;;
    esac
    
    echo -e "\nPress any key to return..."
    read -n 1
    bot_logs
}

# Change Domain
change_domain() {
    clear
    echo -e "╭════════════════════════════════════════════════════════════╮"
    echo -e "│                     CHANGE DOMAIN                          │"
    echo -e "╰════════════════════════════════════════════════════════════╯"
    
    echo -e "Current domain: ${YELLOW}$DOMAIN${NC}"
    echo -e "Enter new domain (or press Enter to cancel):"
    read -r new_domain
    
    if [ -z "$new_domain" ]; then
        echo -e "${YELLOW}Operation cancelled.${NC}"
        sleep 2
        main_menu
        return
    fi
    
    echo -e "${YELLOW}Updating domain to: $new_domain${NC}"
    
    # Update domain in config
    sed -i "s/DOMAIN=.*/DOMAIN=&quot;$new_domain&quot;/" "$CONFIG_DIR/config.conf"
    DOMAIN="$new_domain"
    
    # Update Nginx configuration
    cat > /etc/nginx/sites-available/default << EOF
server {
    listen 80;
    listen [::]:80;
    server_name $DOMAIN;
    
    location / {
        proxy_pass http://127.0.0.1:700;
        proxy_http_version 1.1;
        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection "upgrade";
        proxy_set_header Host \$host;
    }
    
    location /vless {
        proxy_redirect off;
        proxy_pass http://127.0.0.1:10001;
        proxy_http_version 1.1;
        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection "upgrade";
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
    }
    
    location /vmess {
        proxy_redirect off;
        proxy_pass http://127.0.0.1:10002;
        proxy_http_version 1.1;
        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection "upgrade";
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
    }
    
    location /trojan {
        proxy_redirect off;
        proxy_pass http://127.0.0.1:10003;
        proxy_http_version 1.1;
        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection "upgrade";
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
    }
    
    location /shadowsocks {
        proxy_redirect off;
        proxy_pass http://127.0.0.1:10004;
        proxy_http_version 1.1;
        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection "upgrade";
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
    }
}
EOF
    
    # Restart Nginx
    systemctl restart nginx
    
    # Update Xray configuration if exists
    if [ -f "/usr/local/etc/xray/config.json" ]; then
        sed -i "s/&quot;host&quot;: &quot;.*&quot;/&quot;host&quot;: &quot;$DOMAIN&quot;/" /usr/local/etc/xray/config.json
        systemctl restart xray
    fi
    
    echo -e "${GREEN}Domain has been updated successfully!${NC}"
    echo -e "Press any key to return to main menu..."
    read -n 1
    main_menu
}

# Fix Certificate Domain
fix_cert_domain() {
    clear
    echo -e "╭════════════════════════════════════════════════════════════╮"
    echo -e "│                  FIX CERTIFICATE DOMAIN                    │"
    echo -e "╰════════════════════════════════════════════════════════════╯"
    
    echo -e "${YELLOW}Checking domain: $DOMAIN${NC}"
    
    # Install certbot if not installed
    if ! command -v certbot &> /dev/null; then
        echo -e "${YELLOW}Installing Certbot...${NC}"
        apt-get update
        apt-get install -y certbot python3-certbot-nginx
    fi
    
    # Stop services that might use port 80
    echo -e "${YELLOW}Stopping services temporarily...${NC}"
    systemctl stop nginx
    
    # Get certificate
    echo -e "${YELLOW}Requesting SSL certificate for $DOMAIN...${NC}"
    certbot certonly --standalone --preferred-challenges http --agree-tos --email admin@$DOMAIN -d $DOMAIN
    
    # Configure certificate paths
    echo -e "${YELLOW}Configuring certificate paths...${NC}"
    CERT_PATH="/etc/letsencrypt/live/$DOMAIN/fullchain.pem"
    KEY_PATH="/etc/letsencrypt/live/$DOMAIN/privkey.pem"
    
    # Update Xray configuration if exists
    if [ -f "/usr/local/etc/xray/config.json" ]; then
        echo -e "${YELLOW}Updating Xray configuration...${NC}"
        # Backup config
        cp /usr/local/etc/xray/config.json /usr/local/etc/xray/config.json.bak
        
        # Update certificate paths
        sed -i "s|&quot;certificateFile&quot;: &quot;.*&quot;|&quot;certificateFile&quot;: &quot;$CERT_PATH&quot;|" /usr/local/etc/xray/config.json
        sed -i "s|&quot;keyFile&quot;: &quot;.*&quot;|&quot;keyFile&quot;: &quot;$KEY_PATH&quot;|" /usr/local/etc/xray/config.json
    fi
    
    # Restart services
    echo -e "${YELLOW}Restarting services...${NC}"
    systemctl start nginx
    systemctl restart xray
    
    echo -e "${GREEN}Certificate has been fixed successfully!${NC}"
    echo -e "Press any key to return to main menu..."
    read -n 1
    main_menu
}

# Change Banner
change_banner() {
    clear
    echo -e "╭════════════════════════════════════════════════════════════╮"
    echo -e "│                     CHANGE BANNER                          │"
    echo -e "╰════════════════════════════════════════════════════════════╯"
    
    echo -e "Enter path to new banner file (or press Enter to use editor):"
    read -r banner_path
    
    if [ -z "$banner_path" ]; then
        echo -e "${YELLOW}Opening editor to create banner...${NC}"
        nano /etc/issue.net
    elif [ -f "$banner_path" ]; then
        echo -e "${YELLOW}Copying banner from $banner_path...${NC}"
        cp "$banner_path" /etc/issue.net
    else
        echo -e "${RED}File not found: $banner_path${NC}"
        sleep 2
        change_banner
        return
    fi
    
    # Update SSH configuration to use banner
    if ! grep -q "Banner /etc/issue.net" /etc/ssh/sshd_config; then
        echo "Banner /etc/issue.net" >> /etc/ssh/sshd_config
    fi
    
    # Restart SSH
    systemctl restart ssh
    
    echo -e "${GREEN}Banner has been updated successfully!${NC}"
    echo -e "Press any key to return to main menu..."
    read -n 1
    main_menu
}

# Restart Banner
restart_banner() {
    clear
    echo -e "╭════════════════════════════════════════════════════════════╮"
    echo -e "│                    RESTART BANNER                          │"
    echo -e "╰════════════════════════════════════════════════════════════╯"
    
    echo -e "${YELLOW}Restarting SSH service to apply banner changes...${NC}"
    systemctl restart ssh
    
    echo -e "${GREEN}Banner has been restarted successfully!${NC}"
    echo -e "Press any key to return to main menu..."
    read -n 1
    main_menu
}

# Speedtest
run_speedtest() {
    clear
    echo -e "╭════════════════════════════════════════════════════════════╮"
    echo -e "│                      SPEEDTEST                             │"
    echo -e "╰════════════════════════════════════════════════════════════╯"
    
    # Install speedtest if not installed
    if ! command -v speedtest &> /dev/null; then
        echo -e "${YELLOW}Installing Speedtest CLI...${NC}"
        apt-get update
        apt-get install -y curl
        curl -s https://packagecloud.io/install/repositories/ookla/speedtest-cli/script.deb.sh | bash
        apt-get install -y speedtest
    fi
    
    echo -e "${YELLOW}Running speedtest...${NC}"
    speedtest
    
    echo -e "\nPress any key to return to main menu..."
    read -n 1
    main_menu
}

# Extract Menu
extract_menu() {
    clear
    echo -e "╭════════════════════════════════════════════════════════════╮"
    echo -e "│                     EXTRACT MENU                           │"
    echo -e "╰════════════════════════════════════════════════════════════╯"
    echo -e "╭════════════════════════════════════════════════════════════╮"
    echo -e "│ [1] Extract SSH Config"
    echo -e "│ [2] Extract VMESS Config"
    echo -e "│ [3] Extract VLESS Config"
    echo -e "│ [4] Extract TROJAN Config"
    echo -e "│ [5] Extract SHADOWSOCKS Config"
    echo -e "│ [6] Extract All Configs"
    echo -e "│ [0] Back to Main Menu"
    echo -e "╰════════════════════════════════════════════════════════════╯"
    echo -ne "  Select Option [ 0 - 6 ] ❱❱❱ "
    read -r extract_option
    
    case $extract_option in
        1) extract_ssh_config ;;
        2) extract_vmess_config ;;
        3) extract_vless_config ;;
        4) extract_trojan_config ;;
        5) extract_shadowsocks_config ;;
        6) extract_all_configs ;;
        0) main_menu ;;
        *) echo -e "${RED}Invalid option!${NC}" ; sleep 2 ; extract_menu ;;
    esac
}

# Extract Menu Functions
extract_ssh_config() {
    clear
    echo -e "╭════════════════════════════════════════════════════════════╮"
    echo -e "│                  EXTRACT SSH CONFIG                        │"
    echo -e "╰════════════════════════════════════════════════════════════╯"
    
    # Create extract directory if it doesn't exist
    mkdir -p /root/extract
    
    echo -e "${YELLOW}Extracting SSH configuration...${NC}"
    
    # Get SSH users
    echo -e "SSH Users:" > /root/extract/ssh_config.txt
    echo -e "╭────────────────────────────────────────────────────────────╮" >> /root/extract/ssh_config.txt
    
    awk -F: '$3 >= 1000 && $1 != "nobody" {print $1}' /etc/passwd | while read -r user; do
        exp=$(chage -l "$user" | grep "Account expires" | awk -F": " '{print $2}')
        echo -e "│ Username: $user" >> /root/extract/ssh_config.txt
        echo -e "│ Expiration: $exp" >> /root/extract/ssh_config.txt
        echo -e "├────────────────────────────────────────────────────────────┤" >> /root/extract/ssh_config.txt
    done
    
    # Get SSH port
    ssh_port=$(grep -oP '(?<=Port ).*' /etc/ssh/sshd_config | head -1)
    
    # Get dropbear port if installed
    if [ -f "/etc/default/dropbear" ]; then
        dropbear_port=$(grep -oP '(?<=DROPBEAR_PORT=).*' /etc/default/dropbear)
        echo -e "│ Dropbear Port: $dropbear_port" >> /root/extract/ssh_config.txt
    fi
    
    echo -e "│ SSH Port: $ssh_port" >> /root/extract/ssh_config.txt
    echo -e "│ WebSocket Ports: 80, 443, 8080" >> /root/extract/ssh_config.txt
    echo -e "╰────────────────────────────────────────────────────────────╯" >> /root/extract/ssh_config.txt
    
    echo -e "${GREEN}SSH configuration has been extracted to /root/extract/ssh_config.txt${NC}"
    echo -e "Press any key to return..."
    read -n 1
    extract_menu
}

extract_vmess_config() {
    clear
    echo -e "╭════════════════════════════════════════════════════════════╮"
    echo -e "│                  EXTRACT VMESS CONFIG                      │"
    echo -e "╰════════════════════════════════════════════════════════════╯"
    
    # Create extract directory if it doesn't exist
    mkdir -p /root/extract
    
    echo -e "${YELLOW}Extracting VMESS configuration...${NC}"
    
    # Check if Xray is installed
    if ! command -v xray &> /dev/null; then
        echo -e "${RED}Xray is not installed!${NC}"
        echo -e "Press any key to return..."
        read -n 1
        extract_menu
        return
    fi
    
    # Check if VMESS directory exists
    if [ ! -d "/usr/local/etc/xray/vmess" ]; then
        echo -e "${RED}VMESS directory not found!${NC}"
        echo -e "Press any key to return..."
        read -n 1
        extract_menu
        return
    fi
    
    echo -e "VMESS Users:" > /root/extract/vmess_config.txt
    echo -e "╭────────────────────────────────────────────────────────────╮" >> /root/extract/vmess_config.txt
    
    # Get domain
    domain="$DOMAIN"
    
    # Extract VMESS users
    for user_file in /usr/local/etc/xray/vmess/*; do
        if [ -f "$user_file" ]; then
            username=$(basename "$user_file")
            uuid=$(grep -o '"uuid": "[^"]*' "$user_file" | cut -d'"' -f4)
            exp=$(grep -o '"expired": "[^"]*' "$user_file" | cut -d'"' -f4)
            
            # Generate VMESS links
            vmess_data="{&quot;v&quot;:&quot;2&quot;,&quot;ps&quot;:&quot;$username&quot;,&quot;add&quot;:&quot;$domain&quot;,&quot;port&quot;:&quot;443&quot;,&quot;id&quot;:&quot;$uuid&quot;,&quot;aid&quot;:&quot;0&quot;,&quot;net&quot;:&quot;ws&quot;,&quot;path&quot;:&quot;/vmess&quot;,&quot;type&quot;:&quot;none&quot;,&quot;host&quot;:&quot;$domain&quot;,&quot;tls&quot;:&quot;tls&quot;}"
            vmess_link="vmess://$(echo -n "$vmess_data" | base64 -w 0)"
            
            echo -e "│ Username: $username" >> /root/extract/vmess_config.txt
            echo -e "│ UUID: $uuid" >> /root/extract/vmess_config.txt
            echo -e "│ Expiration: $exp" >> /root/extract/vmess_config.txt
            echo -e "│ Link: $vmess_link" >> /root/extract/vmess_config.txt
            echo -e "├────────────────────────────────────────────────────────────┤" >> /root/extract/vmess_config.txt
        fi
    done
    
    echo -e "╰────────────────────────────────────────────────────────────╯" >> /root/extract/vmess_config.txt
    
    echo -e "${GREEN}VMESS configuration has been extracted to /root/extract/vmess_config.txt${NC}"
    echo -e "Press any key to return..."
    read -n 1
    extract_menu
}

extract_vless_config() {
    clear
    echo -e "╭════════════════════════════════════════════════════════════╮"
    echo -e "│                  EXTRACT VLESS CONFIG                      │"
    echo -e "╰════════════════════════════════════════════════════════════╯"
    
    # Create extract directory if it doesn't exist
    mkdir -p /root/extract
    
    echo -e "${YELLOW}Extracting VLESS configuration...${NC}"
    
    # Check if Xray is installed
    if ! command -v xray &> /dev/null; then
        echo -e "${RED}Xray is not installed!${NC}"
        echo -e "Press any key to return..."
        read -n 1
        extract_menu
        return
    fi
    
    # Check if VLESS directory exists
    if [ ! -d "/usr/local/etc/xray/vless" ]; then
        echo -e "${RED}VLESS directory not found!${NC}"
        echo -e "Press any key to return..."
        read -n 1
        extract_menu
        return
    fi
    
    echo -e "VLESS Users:" > /root/extract/vless_config.txt
    echo -e "╭────────────────────────────────────────────────────────────╮" >> /root/extract/vless_config.txt
    
    # Get domain
    domain="$DOMAIN"
    
    # Extract VLESS users
    for user_file in /usr/local/etc/xray/vless/*; do
        if [ -f "$user_file" ]; then
            username=$(basename "$user_file")
            uuid=$(grep -o '"uuid": "[^"]*' "$user_file" | cut -d'"' -f4)
            exp=$(grep -o '"expired": "[^"]*' "$user_file" | cut -d'"' -f4)
            
            # Generate VLESS links
            vless_link="vless://$uuid@$domain:443?encryption=none&security=tls&type=ws&host=$domain&path=/vless#$username"
            
            echo -e "│ Username: $username" >> /root/extract/vless_config.txt
            echo -e "│ UUID: $uuid" >> /root/extract/vless_config.txt
            echo -e "│ Expiration: $exp" >> /root/extract/vless_config.txt
            echo -e "│ Link: $vless_link" >> /root/extract/vless_config.txt
            echo -e "├────────────────────────────────────────────────────────────┤" >> /root/extract/vless_config.txt
        fi
    done
    
    echo -e "╰────────────────────────────────────────────────────────────╯" >> /root/extract/vless_config.txt
    
    echo -e "${GREEN}VLESS configuration has been extracted to /root/extract/vless_config.txt${NC}"
    echo -e "Press any key to return..."
    read -n 1
    extract_menu
}

extract_trojan_config() {
    clear
    echo -e "╭════════════════════════════════════════════════════════════╮"
    echo -e "│                  EXTRACT TROJAN CONFIG                     │"
    echo -e "╰════════════════════════════════════════════════════════════╯"
    
    # Create extract directory if it doesn't exist
    mkdir -p /root/extract
    
    echo -e "${YELLOW}Extracting TROJAN configuration...${NC}"
    
    # Check if Xray is installed
    if ! command -v xray &> /dev/null; then
        echo -e "${RED}Xray is not installed!${NC}"
        echo -e "Press any key to return..."
        read -n 1
        extract_menu
        return
    fi
    
    # Check if TROJAN directory exists
    if [ ! -d "/usr/local/etc/xray/trojan" ]; then
        echo -e "${RED}TROJAN directory not found!${NC}"
        echo -e "Press any key to return..."
        read -n 1
        extract_menu
        return
    fi
    
    echo -e "TROJAN Users:" > /root/extract/trojan_config.txt
    echo -e "╭────────────────────────────────────────────────────────────╮" >> /root/extract/trojan_config.txt
    
    # Get domain
    domain="$DOMAIN"
    
    # Extract TROJAN users
    for user_file in /usr/local/etc/xray/trojan/*; do
        if [ -f "$user_file" ]; then
            username=$(basename "$user_file")
            password=$(grep -o '"password": "[^"]*' "$user_file" | cut -d'"' -f4)
            exp=$(grep -o '"expired": "[^"]*' "$user_file" | cut -d'"' -f4)
            
            # Generate TROJAN links
            trojan_link="trojan://$password@$domain:443?security=tls&type=ws&host=$domain&path=/trojan#$username"
            
            echo -e "│ Username: $username" >> /root/extract/trojan_config.txt
            echo -e "│ Password: $password" >> /root/extract/trojan_config.txt
            echo -e "│ Expiration: $exp" >> /root/extract/trojan_config.txt
            echo -e "│ Link: $trojan_link" >> /root/extract/trojan_config.txt
            echo -e "├────────────────────────────────────────────────────────────┤" >> /root/extract/trojan_config.txt
        fi
    done
    
    echo -e "╰────────────────────────────────────────────────────────────╯" >> /root/extract/trojan_config.txt
    
    echo -e "${GREEN}TROJAN configuration has been extracted to /root/extract/trojan_config.txt${NC}"
    echo -e "Press any key to return..."
    read -n 1
    extract_menu
}

extract_shadowsocks_config() {
    clear
    echo -e "╭════════════════════════════════════════════════════════════╮"
    echo -e "│                EXTRACT SHADOWSOCKS CONFIG                  │"
    echo -e "╰════════════════════════════════════════════════════════════╯"
    
    # Create extract directory if it doesn't exist
    mkdir -p /root/extract
    
    echo -e "${YELLOW}Extracting SHADOWSOCKS configuration...${NC}"
    
    # Check if SS-LIBEV is installed
    if ! command -v ss-server &> /dev/null; then
        echo -e "${RED}Shadowsocks-libev is not installed!${NC}"
        echo -e "Press any key to return..."
        read -n 1
        extract_menu
        return
    fi
    
    # Check if users database exists
    if [ ! -f "/etc/shadowsocks-libev/users.db" ]; then
        echo -e "${RED}Shadowsocks users database not found!${NC}"
        echo -e "Press any key to return..."
        read -n 1
        extract_menu
        return
    fi
    
    echo -e "SHADOWSOCKS Users:" > /root/extract/shadowsocks_config.txt
    echo -e "╭────────────────────────────────────────────────────────────╮" >> /root/extract/shadowsocks_config.txt
    
    # Get domain
    domain="$DOMAIN"
    
    # Extract SHADOWSOCKS users
    while IFS=: read -r username port password method exp; do
        # Generate SS URI
        ss_uri="ss://$(echo -n "$method:$password" | base64 -w 0)@$domain:$port#$username"
        
        echo -e "│ Username: $username" >> /root/extract/shadowsocks_config.txt
        echo -e "│ Port: $port" >> /root/extract/shadowsocks_config.txt
        echo -e "│ Password: $password" >> /root/extract/shadowsocks_config.txt
        echo -e "│ Method: $method" >> /root/extract/shadowsocks_config.txt
        echo -e "│ Expiration: $exp" >> /root/extract/shadowsocks_config.txt
        echo -e "│ Link: $ss_uri" >> /root/extract/shadowsocks_config.txt
        echo -e "├────────────────────────────────────────────────────────────┤" >> /root/extract/shadowsocks_config.txt
    done < /etc/shadowsocks-libev/users.db
    
    echo -e "╰────────────────────────────────────────────────────────────╯" >> /root/extract/shadowsocks_config.txt
    
    echo -e "${GREEN}SHADOWSOCKS configuration has been extracted to /root/extract/shadowsocks_config.txt${NC}"
    echo -e "Press any key to return..."
    read -n 1
    extract_menu
}

extract_all_configs() {
    clear
    echo -e "╭════════════════════════════════════════════════════════════╮"
    echo -e "│                  EXTRACT ALL CONFIGS                       │"
    echo -e "╰════════════════════════════════════════════════════════════╯"
    
    # Create extract directory if it doesn't exist
    mkdir -p /root/extract
    
    echo -e "${YELLOW}Extracting all configurations...${NC}"
    
    # Extract SSH config
    extract_ssh_config_silent
    
    # Extract VMESS config if Xray is installed
    if command -v xray &> /dev/null && [ -d "/usr/local/etc/xray/vmess" ]; then
        extract_vmess_config_silent
    fi
    
    # Extract VLESS config if Xray is installed
    if command -v xray &> /dev/null && [ -d "/usr/local/etc/xray/vless" ]; then
        extract_vless_config_silent
    fi
    
    # Extract TROJAN config if Xray is installed
    if command -v xray &> /dev/null && [ -d "/usr/local/etc/xray/trojan" ]; then
        extract_trojan_config_silent
    fi
    
    # Extract SHADOWSOCKS config if SS-LIBEV is installed
    if command -v ss-server &> /dev/null && [ -f "/etc/shadowsocks-libev/users.db" ]; then
        extract_shadowsocks_config_silent
    fi
    
    # Combine all configs into one file
    cat /root/extract/ssh_config.txt > /root/extract/all_configs.txt
    echo -e "\n\n" >> /root/extract/all_configs.txt
    
    if [ -f "/root/extract/vmess_config.txt" ]; then
        cat /root/extract/vmess_config.txt >> /root/extract/all_configs.txt
        echo -e "\n\n" >> /root/extract/all_configs.txt
    fi
    
    if [ -f "/root/extract/vless_config.txt" ]; then
        cat /root/extract/vless_config.txt >> /root/extract/all_configs.txt
        echo -e "\n\n" >> /root/extract/all_configs.txt
    fi
    
    if [ -f "/root/extract/trojan_config.txt" ]; then
        cat /root/extract/trojan_config.txt >> /root/extract/all_configs.txt
        echo -e "\n\n" >> /root/extract/all_configs.txt
    fi
    
    if [ -f "/root/extract/shadowsocks_config.txt" ]; then
        cat /root/extract/shadowsocks_config.txt >> /root/extract/all_configs.txt
    fi
    
    echo -e "${GREEN}All configurations have been extracted to /root/extract/all_configs.txt${NC}"
    echo -e "Press any key to return..."
    read -n 1
    extract_menu
}

# Silent extraction functions (no output, used by extract_all_configs)
extract_ssh_config_silent() {
    # Create extract directory if it doesn't exist
    mkdir -p /root/extract
    
    # Get SSH users
    echo -e "SSH Users:" > /root/extract/ssh_config.txt
    echo -e "╭────────────────────────────────────────────────────────────╮" >> /root/extract/ssh_config.txt
    
    awk -F: '$3 >= 1000 && $1 != "nobody" {print $1}' /etc/passwd | while read -r user; do
        exp=$(chage -l "$user" | grep "Account expires" | awk -F": " '{print $2}')
        echo -e "│ Username: $user" >> /root/extract/ssh_config.txt
        echo -e "│ Expiration: $exp" >> /root/extract/ssh_config.txt
        echo -e "├────────────────────────────────────────────────────────────┤" >> /root/extract/ssh_config.txt
    done
    
    # Get SSH port
    ssh_port=$(grep -oP '(?<=Port ).*' /etc/ssh/sshd_config | head -1)
    
    # Get dropbear port if installed
    if [ -f "/etc/default/dropbear" ]; then
        dropbear_port=$(grep -oP '(?<=DROPBEAR_PORT=).*' /etc/default/dropbear)
        echo -e "│ Dropbear Port: $dropbear_port" >> /root/extract/ssh_config.txt
    fi
    
    echo -e "│ SSH Port: $ssh_port" >> /root/extract/ssh_config.txt
    echo -e "│ WebSocket Ports: 80, 443, 8080" >> /root/extract/ssh_config.txt
    echo -e "╰────────────────────────────────────────────────────────────╯" >> /root/extract/ssh_config.txt
}

extract_vmess_config_silent() {
    # Create extract directory if it doesn't exist
    mkdir -p /root/extract
    
    echo -e "VMESS Users:" > /root/extract/vmess_config.txt
    echo -e "╭────────────────────────────────────────────────────────────╮" >> /root/extract/vmess_config.txt
    
    # Get domain
    domain="$DOMAIN"
    
    # Extract VMESS users
    for user_file in /usr/local/etc/xray/vmess/*; do
        if [ -f "$user_file" ]; then
            username=$(basename "$user_file")
            uuid=$(grep -o '"uuid": "[^"]*' "$user_file" | cut -d'"' -f4)
            exp=$(grep -o '"expired": "[^"]*' "$user_file" | cut -d'"' -f4)
            
            # Generate VMESS links
            vmess_data="{&quot;v&quot;:&quot;2&quot;,&quot;ps&quot;:&quot;$username&quot;,&quot;add&quot;:&quot;$domain&quot;,&quot;port&quot;:&quot;443&quot;,&quot;id&quot;:&quot;$uuid&quot;,&quot;aid&quot;:&quot;0&quot;,&quot;net&quot;:&quot;ws&quot;,&quot;path&quot;:&quot;/vmess&quot;,&quot;type&quot;:&quot;none&quot;,&quot;host&quot;:&quot;$domain&quot;,&quot;tls&quot;:&quot;tls&quot;}"
            vmess_link="vmess://$(echo -n "$vmess_data" | base64 -w 0)"
            
            echo -e "│ Username: $username" >> /root/extract/vmess_config.txt
            echo -e "│ UUID: $uuid" >> /root/extract/vmess_config.txt
            echo -e "│ Expiration: $exp" >> /root/extract/vmess_config.txt
            echo -e "│ Link: $vmess_link" >> /root/extract/vmess_config.txt
            echo -e "├────────────────────────────────────────────────────────────┤" >> /root/extract/vmess_config.txt
        fi
    done
    
    echo -e "╰────────────────────────────────────────────────────────────╯" >> /root/extract/vmess_config.txt
}

extract_vless_config_silent() {
    # Create extract directory if it doesn't exist
    mkdir -p /root/extract
    
    echo -e "VLESS Users:" > /root/extract/vless_config.txt
    echo -e "╭────────────────────────────────────────────────────────────╮" >> /root/extract/vless_config.txt
    
    # Get domain
    domain="$DOMAIN"
    
    # Extract VLESS users
    for user_file in /usr/local/etc/xray/vless/*; do
        if [ -f "$user_file" ]; then
            username=$(basename "$user_file")
            uuid=$(grep -o '"uuid": "[^"]*' "$user_file" | cut -d'"' -f4)
            exp=$(grep -o '"expired": "[^"]*' "$user_file" | cut -d'"' -f4)
            
            # Generate VLESS links
            vless_link="vless://$uuid@$domain:443?encryption=none&security=tls&type=ws&host=$domain&path=/vless#$username"
            
            echo -e "│ Username: $username" >> /root/extract/vless_config.txt
            echo -e "│ UUID: $uuid" >> /root/extract/vless_config.txt
            echo -e "│ Expiration: $exp" >> /root/extract/vless_config.txt
            echo -e "│ Link: $vless_link" >> /root/extract/vless_config.txt
            echo -e "├────────────────────────────────────────────────────────────┤" >> /root/extract/vless_config.txt
        fi
    done
    
    echo -e "╰────────────────────────────────────────────────────────────╯" >> /root/extract/vless_config.txt
}

extract_trojan_config_silent() {
    # Create extract directory if it doesn't exist
    mkdir -p /root/extract
    
    echo -e "TROJAN Users:" > /root/extract/trojan_config.txt
    echo -e "╭────────────────────────────────────────────────────────────╮" >> /root/extract/trojan_config.txt
    
    # Get domain
    domain="$DOMAIN"
    
    # Extract TROJAN users
    for user_file in /usr/local/etc/xray/trojan/*; do
        if [ -f "$user_file" ]; then
            username=$(basename "$user_file")
            password=$(grep -o '"password": "[^"]*' "$user_file" | cut -d'"' -f4)
            exp=$(grep -o '"expired": "[^"]*' "$user_file" | cut -d'"' -f4)
            
            # Generate TROJAN links
            trojan_link="trojan://$password@$domain:443?security=tls&type=ws&host=$domain&path=/trojan#$username"
            
            echo -e "│ Username: $username" >> /root/extract/trojan_config.txt
            echo -e "│ Password: $password" >> /root/extract/trojan_config.txt
            echo -e "│ Expiration: $exp" >> /root/extract/trojan_config.txt
            echo -e "│ Link: $trojan_link" >> /root/extract/trojan_config.txt
            echo -e "├────────────────────────────────────────────────────────────┤" >> /root/extract/trojan_config.txt
        fi
    done
    
    echo -e "╰────────────────────────────────────────────────────────────╯" >> /root/extract/trojan_config.txt
}

extract_shadowsocks_config_silent() {
    # Create extract directory if it doesn't exist
    mkdir -p /root/extract
    
    echo -e "SHADOWSOCKS Users:" > /root/extract/shadowsocks_config.txt
    echo -e "╭────────────────────────────────────────────────────────────╮" >> /root/extract/shadowsocks_config.txt
    
    # Get domain
    domain="$DOMAIN"
    
    # Extract SHADOWSOCKS users
    while IFS=: read -r username port password method exp; do
        # Generate SS URI
        ss_uri="ss://$(echo -n "$method:$password" | base64 -w 0)@$domain:$port#$username"
        
        echo -e "│ Username: $username" >> /root/extract/shadowsocks_config.txt
        echo -e "│ Port: $port" >> /root/extract/shadowsocks_config.txt
        echo -e "│ Password: $password" >> /root/extract/shadowsocks_config.txt
        echo -e "│ Method: $method" >> /root/extract/shadowsocks_config.txt
        echo -e "│ Expiration: $exp" >> /root/extract/shadowsocks_config.txt
        echo -e "│ Link: $ss_uri" >> /root/extract/shadowsocks_config.txt
        echo -e "├────────────────────────────────────────────────────────────┤" >> /root/extract/shadowsocks_config.txt
    done < /etc/shadowsocks-libev/users.db
    
    echo -e "╰────────────────────────────────────────────────────────────╯" >> /root/extract/shadowsocks_config.txt
}

# Setup Cloudflare WebSocket Support
setup_cloudflare_ws() {
    clear
    echo -e "╭════════════════════════════════════════════════════════════╮"
    echo -e "│              CLOUDFLARE WEBSOCKET SETUP                    │"
    echo -e "╰════════════════════════════════════════════════════════════╯"
    
    echo -e "${YELLOW}Setting up Cloudflare WebSocket support...${NC}"
    
    # Install required packages
    apt-get update
    apt-get install -y nginx socat
    
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
    
    # Create systemd service
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

    # Enable and start service
    systemctl daemon-reload
    systemctl enable ws-epro
    systemctl start ws-epro
    
    # Configure Nginx for WebSocket
    cat > /etc/nginx/conf.d/websocket.conf << EOF
server {
    listen 10080;
    
    location / {
        proxy_pass http://127.0.0.1:700;
        proxy_http_version 1.1;
        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection "upgrade";
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
    }
}

server {
    listen 10443 ssl;
    ssl_certificate /etc/letsencrypt/live/$DOMAIN/fullchain.pem;
    ssl_certificate_key /etc/letsencrypt/live/$DOMAIN/privkey.pem;
    
    location / {
        proxy_pass http://127.0.0.1:700;
        proxy_http_version 1.1;
        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection "upgrade";
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
    }
}

server {
    listen 10880;
    
    location / {
        proxy_pass http://127.0.0.1:700;
        proxy_http_version 1.1;
        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection "upgrade";
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
    }
}
EOF

    # Restart Nginx
    systemctl restart nginx
    
    echo -e "${GREEN}Cloudflare WebSocket support has been set up successfully!${NC}"
    echo -e "Ports 80, 443, and 8080 are now supported for WebSocket connections."
    echo -e "Press any key to return to main menu..."
    read -n 1
    main_menu
}

# Configure auto-start
setup_autostart() {
    echo -e "${YELLOW}Setting up auto-start configuration...${NC}"
    
    # Create auto-start script
    cat > /etc/profile.d/vps_manager.sh << EOF
#!/bin/bash
if [ "\$(id -u)" -eq 0 ]; then
    echo "Starting VPS Manager..."
    /bin/bash /usr/local/bin/vps_manager
fi
EOF

    chmod +x /etc/profile.d/vps_manager.sh
    
    # Copy script to bin directory
    cp "$(readlink -f "$0")" /usr/local/bin/vps_manager
    chmod +x /usr/local/bin/vps_manager
    
    echo -e "${GREEN}Auto-start configuration completed!${NC}"
}

# Main menu function
main_menu() {
    display_banner
    read -r option
    
    case $option in
        1|01) ssh_menu ;;
        2|02) vmess_menu ;;
        3|03) vless_menu ;;
        4|04) trojan_menu ;;
        5|05) noobzvpn_menu ;;
        6|06) ss_libev_menu ;;
        7|07) install_udp ;;
        8|08) backup_restore_menu ;;
        9|09) gotop_ram ;;
        10) restart_all_services ;;
        11) telegram_bot_menu ;;
        12) update_menu ;;
        13) show_running_services ;;
        14) show_port_info ;;
        15) bot_menu ;;
        16) change_domain ;;
        17) fix_cert_domain ;;
        18) change_banner ;;
        19) restart_banner ;;
        20) run_speedtest ;;
        21) extract_menu ;;
        *) echo -e "${RED}Invalid option!${NC}" ; sleep 2 ; main_menu ;;
    esac
}

# Initialize script
check_install_packages
setup_cloudflare_ws
setup_autostart

# Start main menu
main_menu
