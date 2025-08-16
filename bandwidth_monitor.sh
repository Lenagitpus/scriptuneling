#!/bin/bash
# Bandwidth Monitoring and Limiting Script
# For VPS Manager with Cloudflare WebSocket Support
# Version: HAPPY NEW YEAR 2025

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
BANDWIDTH_DIR="$CONFIG_DIR/bandwidth"
BANDWIDTH_LOG="$LOG_DIR/bandwidth.log"

# Ensure directories exist
mkdir -p $BANDWIDTH_DIR
mkdir -p $LOG_DIR

# Function to log messages
log_message() {
    echo -e "$(date '+%Y-%m-%d %H:%M:%S') - $1" >> $BANDWIDTH_LOG
    echo -e "$1"
}

# Function to get current bandwidth usage for a user
get_user_bandwidth() {
    local username=$1
    local bandwidth_file="$BANDWIDTH_DIR/${username}.usage"
    
    if [ -f "$bandwidth_file" ]; then
        cat "$bandwidth_file"
    else
        echo "0"
    fi
}

# Function to update bandwidth usage for a user
update_user_bandwidth() {
    local username=$1
    local usage=$2
    local bandwidth_file="$BANDWIDTH_DIR/${username}.usage"
    
    echo "$usage" > "$bandwidth_file"
    log_message "Updated bandwidth usage for $username: $usage bytes"
}

# Function to set bandwidth limit for a user
set_bandwidth_limit() {
    local username=$1
    local limit_gb=$2
    local limit_bytes=$(echo "$limit_gb * 1024 * 1024 * 1024" | bc)
    local limit_file="$BANDWIDTH_DIR/${username}.limit"
    
    echo "$limit_bytes" > "$limit_file"
    log_message "Set bandwidth limit for $username: $limit_gb GB ($limit_bytes bytes)"
}

# Function to get bandwidth limit for a user
get_bandwidth_limit() {
    local username=$1
    local limit_file="$BANDWIDTH_DIR/${username}.limit"
    
    if [ -f "$limit_file" ]; then
        cat "$limit_file"
    else
        echo "0" # No limit
    fi
}

# Function to check if user has exceeded bandwidth limit
check_bandwidth_limit() {
    local username=$1
    local current_usage=$(get_user_bandwidth "$username")
    local limit=$(get_bandwidth_limit "$username")
    
    # If limit is 0, no limit is set
    if [ "$limit" -eq "0" ]; then
        return 1 # Not exceeded
    fi
    
    if [ "$current_usage" -ge "$limit" ]; then
        return 0 # Exceeded
    else
        return 1 # Not exceeded
    fi
}

# Function to collect bandwidth usage from iptables
collect_bandwidth_data() {
    log_message "Collecting bandwidth data..."
    
    # Create iptables rules if they don't exist
    if ! iptables -L BANDWIDTH_IN &>/dev/null; then
        iptables -N BANDWIDTH_IN
        iptables -A INPUT -j BANDWIDTH_IN
    fi
    
    if ! iptables -L BANDWIDTH_OUT &>/dev/null; then
        iptables -N BANDWIDTH_OUT
        iptables -A OUTPUT -j BANDWIDTH_OUT
    fi
    
    # Get all SSH users
    local users=$(awk -F: '$3 >= 1000 && $3 < 65534 {print $1}' /etc/passwd)
    
    for user in $users; do
        # Skip system users
        if [[ "$user" == "nobody" || "$user" == "systemd-*" ]]; then
            continue
        fi
        
        # Check if user has iptables rules
        if ! iptables -L BANDWIDTH_IN | grep -q "$user"; then
            iptables -A BANDWIDTH_IN -m owner --uid-owner "$user" -j RETURN
        fi
        
        if ! iptables -L BANDWIDTH_OUT | grep -q "$user"; then
            iptables -A BANDWIDTH_OUT -m owner --uid-owner "$user" -j RETURN
        fi
        
        # Get current bandwidth usage from iptables
        local in_bytes=$(iptables -L BANDWIDTH_IN -v -n -x | grep "$user" | awk '{print $2}')
        local out_bytes=$(iptables -L BANDWIDTH_OUT -v -n -x | grep "$user" | awk '{print $2}')
        
        # If no data found, set to 0
        in_bytes=${in_bytes:-0}
        out_bytes=${out_bytes:-0}
        
        # Calculate total usage
        local total_bytes=$((in_bytes + out_bytes))
        
        # Get previous usage
        local previous_usage=$(get_user_bandwidth "$user")
        
        # Calculate new total usage
        local new_usage=$((previous_usage + total_bytes))
        
        # Update user bandwidth usage
        update_user_bandwidth "$user" "$new_usage"
        
        # Check if user has exceeded bandwidth limit
        if check_bandwidth_limit "$user"; then
            log_message "${RED}User $user has exceeded bandwidth limit. Suspending account...${NC}"
            # Lock the user account
            passwd -l "$user"
            # Kill user sessions
            pkill -u "$user"
        fi
        
        # Reset iptables counters for this user
        iptables -Z BANDWIDTH_IN
        iptables -Z BANDWIDTH_OUT
    done
    
    log_message "Bandwidth data collection completed."
}

# Function to display bandwidth usage for all users
display_bandwidth_usage() {
    echo -e "${BLUE}${BOLD}=== Bandwidth Usage Report ===${NC}"
    echo -e "${CYAN}Username       Usage (GB)      Limit (GB)      Status${NC}"
    echo -e "${CYAN}--------------------------------------------------${NC}"
    
    # Get all SSH users
    local users=$(awk -F: '$3 >= 1000 && $3 < 65534 {print $1}' /etc/passwd)
    
    for user in $users; do
        # Skip system users
        if [[ "$user" == "nobody" || "$user" == "systemd-*" ]]; then
            continue
        fi
        
        # Get usage and limit
        local usage=$(get_user_bandwidth "$user")
        local limit=$(get_bandwidth_limit "$user")
        
        # Convert to GB for display
        local usage_gb=$(echo "scale=2; $usage / 1024 / 1024 / 1024" | bc)
        
        # Display limit as "Unlimited" if 0
        if [ "$limit" -eq "0" ]; then
            local limit_gb="Unlimited"
            local status="${GREEN}OK${NC}"
        else
            local limit_gb=$(echo "scale=2; $limit / 1024 / 1024 / 1024" | bc)
            
            # Check status
            if check_bandwidth_limit "$user"; then
                local status="${RED}EXCEEDED${NC}"
            else
                # Calculate percentage
                local percentage=$(echo "scale=2; $usage * 100 / $limit" | bc)
                
                if (( $(echo "$percentage > 90" | bc -l) )); then
                    local status="${YELLOW}WARNING (${percentage}%)${NC}"
                else
                    local status="${GREEN}OK (${percentage}%)${NC}"
                fi
            fi
        fi
        
        # Format output
        printf "%-15s %-15s %-15s %-15s\n" "$user" "$usage_gb" "$limit_gb" "$status"
    done
}

# Function to reset bandwidth usage for a user
reset_bandwidth_usage() {
    local username=$1
    local bandwidth_file="$BANDWIDTH_DIR/${username}.usage"
    
    if [ -f "$bandwidth_file" ]; then
        echo "0" > "$bandwidth_file"
        log_message "Reset bandwidth usage for $username"
        echo -e "${GREEN}Bandwidth usage for $username has been reset.${NC}"
    else
        echo -e "${YELLOW}No bandwidth data found for $username.${NC}"
    fi
}

# Function to reset bandwidth usage for all users
reset_all_bandwidth_usage() {
    # Get all SSH users
    local users=$(awk -F: '$3 >= 1000 && $3 < 65534 {print $1}' /etc/passwd)
    
    for user in $users; do
        # Skip system users
        if [[ "$user" == "nobody" || "$user" == "systemd-*" ]]; then
            continue
        fi
        
        reset_bandwidth_usage "$user"
    done
    
    echo -e "${GREEN}Bandwidth usage has been reset for all users.${NC}"
}

# Function to unlock a user account that was locked due to bandwidth limit
unlock_user_account() {
    local username=$1
    
    # Check if user exists
    if id "$username" &>/dev/null; then
        # Unlock the account
        passwd -u "$username"
        log_message "Unlocked account for $username"
        echo -e "${GREEN}Account for $username has been unlocked.${NC}"
    else
        echo -e "${RED}User $username does not exist.${NC}"
    fi
}

# Function to setup cron job for bandwidth monitoring
setup_bandwidth_cron() {
    local interval=$1 # in minutes
    
    # Remove existing cron job
    crontab -l | grep -v "bandwidth_monitor.sh collect" | crontab -
    
    # Add new cron job
    (crontab -l 2>/dev/null; echo "*/$interval * * * * /usr/local/bin/bandwidth_monitor.sh collect") | crontab -
    
    log_message "Set up bandwidth monitoring cron job to run every $interval minutes"
    echo -e "${GREEN}Bandwidth monitoring will run every $interval minutes.${NC}"
}

# Function to install the bandwidth monitor
install_bandwidth_monitor() {
    # Copy this script to /usr/local/bin
    cp "$0" /usr/local/bin/bandwidth_monitor.sh
    chmod +x /usr/local/bin/bandwidth_monitor.sh
    
    # Create necessary directories
    mkdir -p $BANDWIDTH_DIR
    mkdir -p $LOG_DIR
    
    # Setup default cron job (every 15 minutes)
    setup_bandwidth_cron 15
    
    log_message "Bandwidth monitor installed successfully"
    echo -e "${GREEN}Bandwidth monitor installed successfully.${NC}"
}

# Function to display bandwidth menu
bandwidth_menu() {
    clear
    echo -e "${BLUE}${BOLD}=== BANDWIDTH MANAGEMENT ===${NC}"
    echo -e "${CYAN}1.${NC} Display Bandwidth Usage"
    echo -e "${CYAN}2.${NC} Set Bandwidth Limit for a User"
    echo -e "${CYAN}3.${NC} Reset Bandwidth Usage for a User"
    echo -e "${CYAN}4.${NC} Reset Bandwidth Usage for All Users"
    echo -e "${CYAN}5.${NC} Unlock User Account"
    echo -e "${CYAN}6.${NC} Change Monitoring Interval"
    echo -e "${CYAN}7.${NC} Collect Bandwidth Data Now"
    echo -e "${CYAN}8.${NC} View Bandwidth Logs"
    echo -e "${CYAN}9.${NC} Back to Main Menu"
    echo -e "${CYAN}0.${NC} Exit"
    echo ""
    read -p "Select an option: " option
    
    case $option in
        1)
            display_bandwidth_usage
            echo ""
            read -p "Press Enter to continue..."
            bandwidth_menu
            ;;
        2)
            echo ""
            read -p "Enter username: " username
            read -p "Enter bandwidth limit in GB (0 for unlimited): " limit_gb
            set_bandwidth_limit "$username" "$limit_gb"
            echo -e "${GREEN}Bandwidth limit for $username set to $limit_gb GB.${NC}"
            echo ""
            read -p "Press Enter to continue..."
            bandwidth_menu
            ;;
        3)
            echo ""
            read -p "Enter username: " username
            reset_bandwidth_usage "$username"
            echo ""
            read -p "Press Enter to continue..."
            bandwidth_menu
            ;;
        4)
            echo ""
            read -p "Are you sure you want to reset bandwidth usage for all users? (y/n): " confirm
            if [[ "$confirm" == "y" || "$confirm" == "Y" ]]; then
                reset_all_bandwidth_usage
            fi
            echo ""
            read -p "Press Enter to continue..."
            bandwidth_menu
            ;;
        5)
            echo ""
            read -p "Enter username to unlock: " username
            unlock_user_account "$username"
            echo ""
            read -p "Press Enter to continue..."
            bandwidth_menu
            ;;
        6)
            echo ""
            read -p "Enter monitoring interval in minutes (5-60): " interval
            if (( interval >= 5 && interval <= 60 )); then
                setup_bandwidth_cron "$interval"
            else
                echo -e "${RED}Invalid interval. Please enter a value between 5 and 60.${NC}"
            fi
            echo ""
            read -p "Press Enter to continue..."
            bandwidth_menu
            ;;
        7)
            echo ""
            collect_bandwidth_data
            echo -e "${GREEN}Bandwidth data collected.${NC}"
            echo ""
            read -p "Press Enter to continue..."
            bandwidth_menu
            ;;
        8)
            echo ""
            if [ -f "$BANDWIDTH_LOG" ]; then
                tail -n 50 "$BANDWIDTH_LOG"
            else
                echo -e "${YELLOW}No bandwidth logs found.${NC}"
            fi
            echo ""
            read -p "Press Enter to continue..."
            bandwidth_menu
            ;;
        9)
            # Return to main menu (handled by calling script)
            return
            ;;
        0)
            exit 0
            ;;
        *)
            echo -e "${RED}Invalid option!${NC}"
            sleep 2
            bandwidth_menu
            ;;
    esac
}

# Main execution
case "$1" in
    install)
        install_bandwidth_monitor
        ;;
    collect)
        collect_bandwidth_data
        ;;
    menu)
        bandwidth_menu
        ;;
    usage)
        display_bandwidth_usage
        ;;
    set)
        if [ -z "$2" ] || [ -z "$3" ]; then
            echo -e "${RED}Usage: $0 set <username> <limit_gb>${NC}"
            exit 1
        fi
        set_bandwidth_limit "$2" "$3"
        ;;
    reset)
        if [ -z "$2" ]; then
            echo -e "${RED}Usage: $0 reset <username>${NC}"
            exit 1
        fi
        reset_bandwidth_usage "$2"
        ;;
    reset-all)
        reset_all_bandwidth_usage
        ;;
    unlock)
        if [ -z "$2" ]; then
            echo -e "${RED}Usage: $0 unlock <username>${NC}"
            exit 1
        fi
        unlock_user_account "$2"
        ;;
    cron)
        if [ -z "$2" ]; then
            echo -e "${RED}Usage: $0 cron <interval_minutes>${NC}"
            exit 1
        fi
        setup_bandwidth_cron "$2"
        ;;
    *)
        echo -e "${BLUE}${BOLD}Bandwidth Monitor for VPS Manager${NC}"
        echo -e "${CYAN}Usage:${NC}"
        echo -e "  $0 install              - Install bandwidth monitor"
        echo -e "  $0 collect              - Collect bandwidth data"
        echo -e "  $0 menu                 - Show bandwidth menu"
        echo -e "  $0 usage                - Display bandwidth usage"
        echo -e "  $0 set <user> <limit>   - Set bandwidth limit in GB"
        echo -e "  $0 reset <user>         - Reset bandwidth for user"
        echo -e "  $0 reset-all            - Reset bandwidth for all users"
        echo -e "  $0 unlock <user>        - Unlock user account"
        echo -e "  $0 cron <minutes>       - Set monitoring interval"
        ;;
esac

exit 0
