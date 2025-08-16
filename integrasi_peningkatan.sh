#!/bin/bash
# Integration Script for VPS Manager Enhancements
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
REPO_DIR="scriptuneling"
BACKUP_DIR="/tmp/vps_manager_backup_$(date +%Y%m%d%H%M%S)"

# Function to log messages
log_message() {
    echo -e "$1"
}

# Function to check if a file exists
check_file() {
    if [ -f "$1" ]; then
        return 0
    else
        return 1
    fi
}

# Function to backup original files
backup_original_files() {
    log_message "${YELLOW}Backing up original files...${NC}"
    
    mkdir -p $BACKUP_DIR
    
    if check_file "$REPO_DIR/vps_manager.sh"; then
        cp "$REPO_DIR/vps_manager.sh" "$BACKUP_DIR/"
        log_message "${GREEN}Backed up vps_manager.sh${NC}"
    fi
    
    if check_file "$REPO_DIR/install.sh"; then
        cp "$REPO_DIR/install.sh" "$BACKUP_DIR/"
        log_message "${GREEN}Backed up install.sh${NC}"
    fi
    
    if check_file "$REPO_DIR/vps_manager.service"; then
        cp "$REPO_DIR/vps_manager.service" "$BACKUP_DIR/"
        log_message "${GREEN}Backed up vps_manager.service${NC}"
    fi
    
    log_message "${GREEN}Original files backed up to $BACKUP_DIR${NC}"
}

# Function to update main script with bandwidth monitoring
integrate_bandwidth_monitoring() {
    log_message "${YELLOW}Integrating bandwidth monitoring...${NC}"
    
    if ! check_file "$REPO_DIR/vps_manager.sh"; then
        log_message "${RED}vps_manager.sh not found!${NC}"
        return 1
    fi
    
    # Check if bandwidth monitoring is already integrated
    if grep -q "bandwidth_menu" "$REPO_DIR/vps_manager.sh"; then
        log_message "${YELLOW}Bandwidth monitoring already integrated.${NC}"
        return 0
    fi
    
    # Copy bandwidth_monitor.sh to the repository
    cp "bandwidth_monitor.sh" "$REPO_DIR/"
    chmod +x "$REPO_DIR/bandwidth_monitor.sh"
    
    # Add bandwidth menu option to main menu
    sed -i '/MENU_TITLE/a MENU_BANDWIDTH="Bandwidth Management"' "$REPO_DIR/vps_manager.sh"
    sed -i '/show_port_info/a \ \ \ \ echo -e "${CYAN}22.${NC} $MENU_BANDWIDTH"' "$REPO_DIR/vps_manager.sh"
    sed -i '/21) extract_menu/a \ \ \ \ 22|22) bandwidth_monitor.sh menu ;;' "$REPO_DIR/vps_manager.sh"
    
    # Add bandwidth menu function to main script
    cat >> "$REPO_DIR/vps_manager.sh" << 'EOF'

# Bandwidth menu function
bandwidth_menu() {
    /usr/local/bin/bandwidth_monitor.sh menu
}
EOF
    
    # Update installation script to install bandwidth monitor
    sed -i '/# Setup Cloudflare WebSocket support/i # Setup Bandwidth Monitor\necho -e "${YELLOW}Setting up bandwidth monitor...${NC}"\ncp bandwidth_monitor.sh /usr/local/bin/\nchmod +x /usr/local/bin/bandwidth_monitor.sh\n/usr/local/bin/bandwidth_monitor.sh install\n' "$REPO_DIR/install.sh"
    
    log_message "${GREEN}Bandwidth monitoring integrated successfully.${NC}"
}

# Function to update main script with web dashboard
integrate_web_dashboard() {
    log_message "${YELLOW}Integrating web dashboard...${NC}"
    
    if ! check_file "$REPO_DIR/vps_manager.sh"; then
        log_message "${RED}vps_manager.sh not found!${NC}"
        return 1
    fi
    
    # Check if web dashboard is already integrated
    if grep -q "dashboard_menu" "$REPO_DIR/vps_manager.sh"; then
        log_message "${YELLOW}Web dashboard already integrated.${NC}"
        return 0
    fi
    
    # Copy web_dashboard.sh to the repository
    cp "web_dashboard.sh" "$REPO_DIR/"
    chmod +x "$REPO_DIR/web_dashboard.sh"
    
    # Add dashboard menu option to main menu
    sed -i '/MENU_BANDWIDTH/a MENU_DASHBOARD="Web Dashboard"' "$REPO_DIR/vps_manager.sh"
    sed -i '/22.${NC} \$MENU_BANDWIDTH/a \ \ \ \ echo -e "${CYAN}23.${NC} $MENU_DASHBOARD"' "$REPO_DIR/vps_manager.sh"
    sed -i '/22|22) bandwidth_monitor.sh menu/a \ \ \ \ 23|23) web_dashboard.sh menu ;;' "$REPO_DIR/vps_manager.sh"
    
    # Add dashboard menu function to main script
    cat >> "$REPO_DIR/vps_manager.sh" << 'EOF'

# Dashboard menu function
dashboard_menu() {
    /usr/local/bin/web_dashboard.sh menu
}
EOF
    
    # Update installation script to install web dashboard
    sed -i '/# Setup Bandwidth Monitor/i # Setup Web Dashboard\necho -e "${YELLOW}Setting up web dashboard...${NC}"\ncp web_dashboard.sh /usr/local/bin/\nchmod +x /usr/local/bin/web_dashboard.sh\n' "$REPO_DIR/install.sh"
    
    log_message "${GREEN}Web dashboard integrated successfully.${NC}"
}

# Function to update main script with security enhancements
integrate_security_enhancements() {
    log_message "${YELLOW}Integrating security enhancements...${NC}"
    
    if ! check_file "$REPO_DIR/vps_manager.sh"; then
        log_message "${RED}vps_manager.sh not found!${NC}"
        return 1
    fi
    
    # Check if security enhancements are already integrated
    if grep -q "security_menu" "$REPO_DIR/vps_manager.sh"; then
        log_message "${YELLOW}Security enhancements already integrated.${NC}"
        return 0
    fi
    
    # Copy security_enhancer.sh to the repository
    cp "security_enhancer.sh" "$REPO_DIR/"
    chmod +x "$REPO_DIR/security_enhancer.sh"
    
    # Add security menu option to main menu
    sed -i '/MENU_DASHBOARD/a MENU_SECURITY="Security Settings"' "$REPO_DIR/vps_manager.sh"
    sed -i '/23.${NC} \$MENU_DASHBOARD/a \ \ \ \ echo -e "${CYAN}24.${NC} $MENU_SECURITY"' "$REPO_DIR/vps_manager.sh"
    sed -i '/23|23) web_dashboard.sh menu/a \ \ \ \ 24|24) security_enhancer.sh menu ;;' "$REPO_DIR/vps_manager.sh"
    
    # Add security menu function to main script
    cat >> "$REPO_DIR/vps_manager.sh" << 'EOF'

# Security menu function
security_menu() {
    /usr/local/bin/security_enhancer.sh menu
}
EOF
    
    # Update installation script to install security enhancer
    sed -i '/# Setup Web Dashboard/i # Setup Security Enhancer\necho -e "${YELLOW}Setting up security enhancer...${NC}"\ncp security_enhancer.sh /usr/local/bin/\nchmod +x /usr/local/bin/security_enhancer.sh\n' "$REPO_DIR/install.sh"
    
    log_message "${GREEN}Security enhancements integrated successfully.${NC}"
}

# Function to update main script with multi-language support
integrate_language_support() {
    log_message "${YELLOW}Integrating multi-language support...${NC}"
    
    if ! check_file "$REPO_DIR/vps_manager.sh"; then
        log_message "${RED}vps_manager.sh not found!${NC}"
        return 1
    fi
    
    # Check if language support is already integrated
    if grep -q "language_menu" "$REPO_DIR/vps_manager.sh"; then
        log_message "${YELLOW}Language support already integrated.${NC}"
        return 0
    fi
    
    # Copy language_support.sh to the repository
    cp "language_support.sh" "$REPO_DIR/"
    chmod +x "$REPO_DIR/language_support.sh"
    
    # Add language menu option to main menu
    sed -i '/MENU_SECURITY/a MENU_LANGUAGE="Language Settings"' "$REPO_DIR/vps_manager.sh"
    sed -i '/24.${NC} \$MENU_SECURITY/a \ \ \ \ echo -e "${CYAN}25.${NC} $MENU_LANGUAGE"' "$REPO_DIR/vps_manager.sh"
    sed -i '/24|24) security_enhancer.sh menu/a \ \ \ \ 25|25) language_support.sh menu ;;' "$REPO_DIR/vps_manager.sh"
    
    # Add language menu function to main script
    cat >> "$REPO_DIR/vps_manager.sh" << 'EOF'

# Language menu function
language_menu() {
    /usr/local/bin/language_support.sh menu
}
EOF
    
    # Update installation script to install language support
    sed -i '/# Setup Security Enhancer/i # Setup Language Support\necho -e "${YELLOW}Setting up language support...${NC}"\ncp language_support.sh /usr/local/bin/\nchmod +x /usr/local/bin/language_support.sh\n/usr/local/bin/language_support.sh install\n' "$REPO_DIR/install.sh"
    
    log_message "${GREEN}Language support integrated successfully.${NC}"
}

# Function to update main script with traffic statistics
integrate_traffic_stats() {
    log_message "${YELLOW}Integrating traffic statistics...${NC}"
    
    if ! check_file "$REPO_DIR/vps_manager.sh"; then
        log_message "${RED}vps_manager.sh not found!${NC}"
        return 1
    fi
    
    # Check if traffic statistics are already integrated
    if grep -q "traffic_stats_menu" "$REPO_DIR/vps_manager.sh"; then
        log_message "${YELLOW}Traffic statistics already integrated.${NC}"
        return 0
    fi
    
    # Copy traffic_stats.sh to the repository
    cp "traffic_stats.sh" "$REPO_DIR/"
    chmod +x "$REPO_DIR/traffic_stats.sh"
    
    # Add traffic stats menu option to main menu
    sed -i '/MENU_LANGUAGE/a MENU_TRAFFIC="Traffic Statistics"' "$REPO_DIR/vps_manager.sh"
    sed -i '/25.${NC} \$MENU_LANGUAGE/a \ \ \ \ echo -e "${CYAN}26.${NC} $MENU_TRAFFIC"' "$REPO_DIR/vps_manager.sh"
    sed -i '/25|25) language_support.sh menu/a \ \ \ \ 26|26) traffic_stats.sh menu ;;' "$REPO_DIR/vps_manager.sh"
    
    # Add traffic stats menu function to main script
    cat >> "$REPO_DIR/vps_manager.sh" << 'EOF'

# Traffic statistics menu function
traffic_stats_menu() {
    /usr/local/bin/traffic_stats.sh menu
}
EOF
    
    # Update installation script to install traffic statistics
    sed -i '/# Setup Language Support/i # Setup Traffic Statistics\necho -e "${YELLOW}Setting up traffic statistics...${NC}"\ncp traffic_stats.sh /usr/local/bin/\nchmod +x /usr/local/bin/traffic_stats.sh\n' "$REPO_DIR/install.sh"
    
    log_message "${GREEN}Traffic statistics integrated successfully.${NC}"
}

# Function to replace the installation script with the improved version
replace_install_script() {
    log_message "${YELLOW}Replacing installation script with improved version...${NC}"
    
    if ! check_file "$REPO_DIR/install.sh"; then
        log_message "${RED}install.sh not found!${NC}"
        return 1
    fi
    
    # Backup original install script
    cp "$REPO_DIR/install.sh" "$BACKUP_DIR/install.sh.orig"
    
    # Copy improved install script to the repository
    cp "improved_install.sh" "$REPO_DIR/install.sh"
    chmod +x "$REPO_DIR/install.sh"
    
    log_message "${GREEN}Installation script replaced successfully.${NC}"
}

# Function to update README.md
update_readme() {
    log_message "${YELLOW}Updating README.md...${NC}"
    
    # Copy README.md to the repository
    cp "README.md" "$REPO_DIR/"
    
    log_message "${GREEN}README.md updated successfully.${NC}"
}

# Function to integrate all enhancements
integrate_all() {
    log_message "${BLUE}${BOLD}=== INTEGRATING ALL ENHANCEMENTS ===${NC}"
    
    # Backup original files
    backup_original_files
    
    # Integrate all enhancements
    integrate_bandwidth_monitoring
    integrate_web_dashboard
    integrate_security_enhancements
    integrate_language_support
    integrate_traffic_stats
    replace_install_script
    update_readme
    
    log_message "${GREEN}${BOLD}All enhancements integrated successfully!${NC}"
    log_message "${YELLOW}Original files backed up to $BACKUP_DIR${NC}"
}

# Main execution
if [ ! -d "$REPO_DIR" ]; then
    log_message "${RED}Repository directory $REPO_DIR not found!${NC}"
    log_message "${YELLOW}Cloning repository...${NC}"
    git clone https://github.com/Lenagitpus/scriptuneling.git
    
    if [ ! -d "$REPO_DIR" ]; then
        log_message "${RED}Failed to clone repository!${NC}"
        exit 1
    fi
fi

# Display menu
clear
echo -e "${BLUE}${BOLD}=== VPS MANAGER ENHANCEMENT INTEGRATION ===${NC}"
echo -e "${CYAN}1.${NC} Integrate Bandwidth Monitoring"
echo -e "${CYAN}2.${NC} Integrate Web Dashboard"
echo -e "${CYAN}3.${NC} Integrate Security Enhancements"
echo -e "${CYAN}4.${NC} Integrate Multi-Language Support"
echo -e "${CYAN}5.${NC} Integrate Traffic Statistics"
echo -e "${CYAN}6.${NC} Replace Installation Script"
echo -e "${CYAN}7.${NC} Update README.md"
echo -e "${CYAN}8.${NC} Integrate All Enhancements"
echo -e "${CYAN}0.${NC} Exit"
echo ""
read -p "Select an option: " option

case $option in
    1)
        integrate_bandwidth_monitoring
        ;;
    2)
        integrate_web_dashboard
        ;;
    3)
        integrate_security_enhancements
        ;;
    4)
        integrate_language_support
        ;;
    5)
        integrate_traffic_stats
        ;;
    6)
        replace_install_script
        ;;
    7)
        update_readme
        ;;
    8)
        integrate_all
        ;;
    0)
        exit 0
        ;;
    *)
        log_message "${RED}Invalid option!${NC}"
        exit 1
        ;;
esac

log_message "${GREEN}Integration completed successfully!${NC}"
exit 0
