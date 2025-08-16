#!/bin/bash
# Security Enhancement Script for VPS Manager
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
SECURITY_LOG="$LOG_DIR/security.log"

# Ensure directories exist
mkdir -p $CONFIG_DIR
mkdir -p $LOG_DIR

# Function to log messages
log_message() {
    echo -e "$(date '+%Y-%m-%d %H:%M:%S') - $1" >> $SECURITY_LOG
    echo -e "$1"
}

# Function to check if a package is installed
is_installed() {
    if dpkg -s "$1" >/dev/null 2>&1; then
        return 0
    else
        return 1
    fi
}

# Function to install required packages
install_security_packages() {
    log_message "${YELLOW}Installing security packages...${NC}"
    
    # Update package lists
    apt-get update
    
    # Install required packages
    apt-get install -y fail2ban ufw iptables-persistent netfilter-persistent rkhunter lynis unattended-upgrades apt-listchanges apticron
    
    log_message "${GREEN}Security packages installed successfully.${NC}"
}

# Function to configure fail2ban
configure_fail2ban() {
    log_message "${YELLOW}Configuring fail2ban...${NC}"
    
    # Create fail2ban local configuration
    cat > /etc/fail2ban/jail.local << EOF
[DEFAULT]
# Ban hosts for one hour:
bantime = 3600

# Override /etc/fail2ban/jail.d/00-firewalld.conf:
banaction = iptables-multiport

# Enable logging to syslog
logtarget = SYSLOG

# Email settings
destemail = root@localhost
sender = root@$(hostname -f)
mta = sendmail
action = %(action_mwl)s

# SSH protection
[sshd]
enabled = true
port = ssh
filter = sshd
logpath = /var/log/auth.log
maxretry = 5
bantime = 3600

# SSH brute force protection
[sshd-brute]
enabled = true
port = ssh
filter = sshd
logpath = /var/log/auth.log
maxretry = 3
bantime = 7200

# Protect against general brute force attacks
[http-auth]
enabled = true
port = http,https
filter = apache-auth
logpath = /var/log/apache*/*error.log
maxretry = 3

# Protect against DOS attacks
[http-get-dos]
enabled = true
port = http,https
filter = http-get-dos
logpath = /var/log/apache*/*access.log
maxretry = 300
findtime = 300
bantime = 600
action = iptables[name=HTTP, port=http, protocol=tcp]

# Nginx protection
[nginx-http-auth]
enabled = true
filter = nginx-http-auth
port = http,https
logpath = /var/log/nginx/error.log
maxretry = 3

# Protect against WordPress login attempts
[wordpress-auth]
enabled = true
filter = wordpress-auth
port = http,https
logpath = /var/log/auth.log
maxretry = 3
EOF
    
    # Create custom filter for HTTP DOS attacks
    cat > /etc/fail2ban/filter.d/http-get-dos.conf << EOF
[Definition]
failregex = ^<HOST> -.*"(GET|POST).*
ignoreregex =
EOF
    
    # Create custom filter for WordPress login attempts
    cat > /etc/fail2ban/filter.d/wordpress-auth.conf << EOF
[Definition]
failregex = ^.* WordPress authentication failure for .* from <HOST>$
ignoreregex =
EOF
    
    # Restart fail2ban
    systemctl restart fail2ban
    systemctl enable fail2ban
    
    log_message "${GREEN}Fail2ban configured successfully.${NC}"
}

# Function to configure UFW firewall
configure_ufw() {
    log_message "${YELLOW}Configuring UFW firewall...${NC}"
    
    # Reset UFW
    ufw --force reset
    
    # Default policies
    ufw default deny incoming
    ufw default allow outgoing
    
    # Allow SSH
    ufw allow ssh
    
    # Allow HTTP/HTTPS
    ufw allow 80/tcp
    ufw allow 443/tcp
    
    # Allow common VPN ports
    ufw allow 1194/udp  # OpenVPN
    ufw allow 8080/tcp  # Alternative HTTP
    ufw allow 8443/tcp  # Alternative HTTPS
    
    # Allow Xray ports (if configured)
    if grep -q "XRAY_PORT" "$CONFIG_DIR/config.conf" 2>/dev/null; then
        XRAY_PORT=$(grep "XRAY_PORT" "$CONFIG_DIR/config.conf" | cut -d '=' -f2 | tr -d '"')
        ufw allow "$XRAY_PORT"/tcp
        ufw allow "$XRAY_PORT"/udp
        log_message "${GREEN}Added Xray port $XRAY_PORT to firewall rules.${NC}"
    fi
    
    # Allow Shadowsocks ports (if configured)
    if grep -q "SS_PORT" "$CONFIG_DIR/config.conf" 2>/dev/null; then
        SS_PORT=$(grep "SS_PORT" "$CONFIG_DIR/config.conf" | cut -d '=' -f2 | tr -d '"')
        ufw allow "$SS_PORT"/tcp
        ufw allow "$SS_PORT"/udp
        log_message "${GREEN}Added Shadowsocks port $SS_PORT to firewall rules.${NC}"
    fi
    
    # Allow dashboard port (if configured)
    if grep -q "DASHBOARD_PORT" "$CONFIG_DIR/config.conf" 2>/dev/null; then
        DASHBOARD_PORT=$(grep "DASHBOARD_PORT" "$CONFIG_DIR/config.conf" | cut -d '=' -f2 | tr -d '"')
        ufw allow "$DASHBOARD_PORT"/tcp
        log_message "${GREEN}Added dashboard port $DASHBOARD_PORT to firewall rules.${NC}"
    fi
    
    # Enable UFW
    echo "y" | ufw enable
    
    log_message "${GREEN}UFW firewall configured successfully.${NC}"
}

# Function to harden SSH configuration
harden_ssh() {
    log_message "${YELLOW}Hardening SSH configuration...${NC}"
    
    # Backup original SSH config
    cp /etc/ssh/sshd_config /etc/ssh/sshd_config.bak
    
    # Update SSH configuration
    cat > /etc/ssh/sshd_config << EOF
# Security hardened SSH configuration
Port 22
Protocol 2
HostKey /etc/ssh/ssh_host_rsa_key
HostKey /etc/ssh/ssh_host_ecdsa_key
HostKey /etc/ssh/ssh_host_ed25519_key

# Ciphers and algorithms
KexAlgorithms curve25519-sha256@libssh.org,diffie-hellman-group-exchange-sha256
Ciphers chacha20-poly1305@openssh.com,aes256-gcm@openssh.com,aes128-gcm@openssh.com,aes256-ctr,aes192-ctr,aes128-ctr
MACs hmac-sha2-512-etm@openssh.com,hmac-sha2-256-etm@openssh.com,umac-128-etm@openssh.com

# Authentication
LoginGraceTime 30s
PermitRootLogin yes
StrictModes yes
MaxAuthTries 3
MaxSessions 5

# Disable password authentication (uncomment to enable key-only auth)
#PasswordAuthentication no
#PermitEmptyPasswords no

# Other options
X11Forwarding no
PrintMotd no
AcceptEnv LANG LC_*
Subsystem sftp /usr/lib/openssh/sftp-server

# Logging
SyslogFacility AUTH
LogLevel VERBOSE
EOF
    
    # Restart SSH service
    systemctl restart sshd
    
    log_message "${GREEN}SSH configuration hardened.${NC}"
    log_message "${YELLOW}Note: If you want to disable password authentication, edit /etc/ssh/sshd_config and uncomment the relevant lines.${NC}"
}

# Function to configure automatic security updates
configure_auto_updates() {
    log_message "${YELLOW}Configuring automatic security updates...${NC}"
    
    # Configure unattended-upgrades
    cat > /etc/apt/apt.conf.d/50unattended-upgrades << EOF
Unattended-Upgrade::Allowed-Origins {
    "\${distro_id}:\${distro_codename}";
    "\${distro_id}:\${distro_codename}-security";
    "\${distro_id}ESMApps:\${distro_codename}-apps-security";
    "\${distro_id}ESM:\${distro_codename}-infra-security";
    "\${distro_id}:\${distro_codename}-updates";
};

Unattended-Upgrade::Package-Blacklist {
};

Unattended-Upgrade::DevRelease "false";
Unattended-Upgrade::AutoFixInterruptedDpkg "true";
Unattended-Upgrade::MinimalSteps "true";
Unattended-Upgrade::InstallOnShutdown "false";
Unattended-Upgrade::Mail "root";
Unattended-Upgrade::MailReport "on-change";
Unattended-Upgrade::Remove-Unused-Dependencies "true";
Unattended-Upgrade::Automatic-Reboot "false";
Unattended-Upgrade::Automatic-Reboot-Time "02:00";
EOF
    
    # Enable automatic updates
    cat > /etc/apt/apt.conf.d/20auto-upgrades << EOF
APT::Periodic::Update-Package-Lists "1";
APT::Periodic::Download-Upgradeable-Packages "1";
APT::Periodic::AutocleanInterval "7";
APT::Periodic::Unattended-Upgrade "1";
EOF
    
    log_message "${GREEN}Automatic security updates configured successfully.${NC}"
}

# Function to run security audit
run_security_audit() {
    log_message "${YELLOW}Running security audit...${NC}"
    
    # Check if rkhunter and lynis are installed
    if ! is_installed "rkhunter"; then
        log_message "${RED}rkhunter is not installed. Installing...${NC}"
        apt-get install -y rkhunter
    fi
    
    if ! is_installed "lynis"; then
        log_message "${RED}lynis is not installed. Installing...${NC}"
        apt-get install -y lynis
    fi
    
    # Update rkhunter database
    log_message "${YELLOW}Updating rkhunter database...${NC}"
    rkhunter --update
    
    # Run rkhunter check
    log_message "${YELLOW}Running rkhunter check...${NC}"
    rkhunter --check --skip-keypress --report-warnings-only > "$LOG_DIR/rkhunter_report.log"
    
    # Run lynis audit
    log_message "${YELLOW}Running lynis audit...${NC}"
    lynis audit system --quiet > "$LOG_DIR/lynis_report.log"
    
    log_message "${GREEN}Security audit completed. Reports saved to:${NC}"
    log_message "${CYAN}  - RKHunter Report: $LOG_DIR/rkhunter_report.log${NC}"
    log_message "${CYAN}  - Lynis Report: $LOG_DIR/lynis_report.log${NC}"
}

# Function to secure shared memory
secure_shared_memory() {
    log_message "${YELLOW}Securing shared memory...${NC}"
    
    # Check if already configured
    if grep -q "/dev/shm" /etc/fstab; then
        log_message "${GREEN}Shared memory already secured.${NC}"
        return
    fi
    
    # Add to fstab
    echo "tmpfs     /dev/shm     tmpfs     defaults,noexec,nosuid,nodev     0     0" >> /etc/fstab
    
    # Remount
    mount -o remount /dev/shm
    
    log_message "${GREEN}Shared memory secured successfully.${NC}"
}

# Function to secure sysctl settings
secure_sysctl() {
    log_message "${YELLOW}Securing sysctl settings...${NC}"
    
    # Create sysctl security config
    cat > /etc/sysctl.d/99-security.conf << EOF
# IP Spoofing protection
net.ipv4.conf.all.rp_filter = 1
net.ipv4.conf.default.rp_filter = 1

# Ignore ICMP broadcast requests
net.ipv4.icmp_echo_ignore_broadcasts = 1

# Disable source packet routing
net.ipv4.conf.all.accept_source_route = 0
net.ipv4.conf.default.accept_source_route = 0
net.ipv6.conf.all.accept_source_route = 0
net.ipv6.conf.default.accept_source_route = 0

# Ignore send redirects
net.ipv4.conf.all.send_redirects = 0
net.ipv4.conf.default.send_redirects = 0

# Block SYN attacks
net.ipv4.tcp_syncookies = 1
net.ipv4.tcp_max_syn_backlog = 2048
net.ipv4.tcp_synack_retries = 2
net.ipv4.tcp_syn_retries = 5

# Log Martians
net.ipv4.conf.all.log_martians = 1
net.ipv4.conf.default.log_martians = 1

# Ignore ICMP redirects
net.ipv4.conf.all.accept_redirects = 0
net.ipv4.conf.default.accept_redirects = 0
net.ipv6.conf.all.accept_redirects = 0
net.ipv6.conf.default.accept_redirects = 0

# Ignore Directed pings
net.ipv4.icmp_echo_ignore_all = 0

# Disable IPv6 if not needed
#net.ipv6.conf.all.disable_ipv6 = 1
#net.ipv6.conf.default.disable_ipv6 = 1
#net.ipv6.conf.lo.disable_ipv6 = 1

# Protect against kernel exploits
kernel.kptr_restrict = 2
kernel.dmesg_restrict = 1
kernel.perf_event_paranoid = 3
kernel.yama.ptrace_scope = 1
fs.protected_hardlinks = 1
fs.protected_symlinks = 1
EOF
    
    # Apply settings
    sysctl -p /etc/sysctl.d/99-security.conf
    
    log_message "${GREEN}Sysctl settings secured successfully.${NC}"
}

# Function to secure user accounts
secure_user_accounts() {
    log_message "${YELLOW}Securing user accounts...${NC}"
    
    # Set password policies
    if ! is_installed "libpam-pwquality"; then
        apt-get install -y libpam-pwquality
    fi
    
    # Configure password quality requirements
    cat > /etc/security/pwquality.conf << EOF
# Password quality configuration
minlen = 12
minclass = 3
maxrepeat = 3
maxsequence = 3
dcredit = -1
ucredit = -1
lcredit = -1
ocredit = -1
dictcheck = 1
usercheck = 1
enforcing = 1
retry = 3
EOF
    
    # Configure password aging
    sed -i 's/PASS_MAX_DAYS.*/PASS_MAX_DAYS   90/' /etc/login.defs
    sed -i 's/PASS_MIN_DAYS.*/PASS_MIN_DAYS   1/' /etc/login.defs
    sed -i 's/PASS_WARN_AGE.*/PASS_WARN_AGE   7/' /etc/login.defs
    
    log_message "${GREEN}User account security configured successfully.${NC}"
    log_message "${YELLOW}Note: Password policies will apply to new passwords only.${NC}"
}

# Function to install and configure auditd
configure_auditd() {
    log_message "${YELLOW}Configuring audit system...${NC}"
    
    # Install auditd if not installed
    if ! is_installed "auditd"; then
        apt-get install -y auditd audispd-plugins
    fi
    
    # Configure audit rules
    cat > /etc/audit/rules.d/audit.rules << EOF
# Audit rules
# Delete all existing rules
-D

# Set buffer size
-b 8192

# Failure mode: 1=silent, 2=printk
-f 1

# Monitor for time changes
-a always,exit -F arch=b64 -S adjtimex -S settimeofday -S clock_settime -k time-change
-a always,exit -F arch=b32 -S adjtimex -S settimeofday -S clock_settime -k time-change
-w /etc/localtime -p wa -k time-change

# Monitor user/group changes
-w /etc/group -p wa -k identity
-w /etc/passwd -p wa -k identity
-w /etc/gshadow -p wa -k identity
-w /etc/shadow -p wa -k identity
-w /etc/security/opasswd -p wa -k identity

# Monitor network configuration changes
-a always,exit -F arch=b64 -S sethostname -S setdomainname -k system-locale
-a always,exit -F arch=b32 -S sethostname -S setdomainname -k system-locale
-w /etc/issue -p wa -k system-locale
-w /etc/issue.net -p wa -k system-locale
-w /etc/hosts -p wa -k system-locale
-w /etc/network -p wa -k system-locale

# Monitor system administration actions
-w /etc/sudoers -p wa -k actions
-w /etc/sudoers.d/ -p wa -k actions

# Monitor kernel modules
-w /sbin/insmod -p x -k modules
-w /sbin/rmmod -p x -k modules
-w /sbin/modprobe -p x -k modules
-a always,exit -F arch=b64 -S init_module -S delete_module -k modules
-a always,exit -F arch=b32 -S init_module -S delete_module -k modules

# Monitor important files
-w /etc/ssh/sshd_config -p wa -k sshd_config
-w /etc/pam.d/ -p wa -k pam
-w /etc/security/ -p wa -k security
-w /etc/rc.local -p wa -k init
-w /etc/systemd/ -p wa -k systemd
-w /etc/cron.allow -p wa -k cron
-w /etc/cron.deny -p wa -k cron
-w /etc/cron.d/ -p wa -k cron
-w /etc/cron.daily/ -p wa -k cron
-w /etc/cron.hourly/ -p wa -k cron
-w /etc/cron.monthly/ -p wa -k cron
-w /etc/cron.weekly/ -p wa -k cron
-w /etc/crontab -p wa -k cron
-w /var/spool/cron/crontabs/ -p wa -k cron

# Monitor VPS Manager files
-w /etc/vps_manager/ -p wa -k vps_manager
-w /usr/local/bin/vps_manager -p wa -k vps_manager

# Monitor login/logout events
-w /var/log/faillog -p wa -k logins
-w /var/log/lastlog -p wa -k logins
-w /var/log/tallylog -p wa -k logins

# Monitor session initiation
-w /var/run/utmp -p wa -k session
-w /var/log/wtmp -p wa -k session
-w /var/log/btmp -p wa -k session

# Monitor access to sensitive files
-a always,exit -F arch=b64 -S open,creat,truncate,ftruncate,openat,open_by_handle_at -F exit=-EACCES -F auid>=1000 -F auid!=4294967295 -k access
-a always,exit -F arch=b32 -S open,creat,truncate,ftruncate,openat,open_by_handle_at -F exit=-EACCES -F auid>=1000 -F auid!=4294967295 -k access
-a always,exit -F arch=b64 -S open,creat,truncate,ftruncate,openat,open_by_handle_at -F exit=-EPERM -F auid>=1000 -F auid!=4294967295 -k access
-a always,exit -F arch=b32 -S open,creat,truncate,ftruncate,openat,open_by_handle_at -F exit=-EPERM -F auid>=1000 -F auid!=4294967295 -k access

# Make the configuration immutable - reboot required to change
-e 2
EOF
    
    # Restart auditd
    systemctl restart auditd
    systemctl enable auditd
    
    log_message "${GREEN}Audit system configured successfully.${NC}"
}

# Function to install and configure rootkit detection
configure_rootkit_detection() {
    log_message "${YELLOW}Configuring rootkit detection...${NC}"
    
    # Install rkhunter if not installed
    if ! is_installed "rkhunter"; then
        apt-get install -y rkhunter
    fi
    
    # Configure rkhunter
    sed -i 's/CRON_DAILY_RUN=.*/CRON_DAILY_RUN="yes"/' /etc/default/rkhunter
    sed -i 's/CRON_DB_UPDATE=.*/CRON_DB_UPDATE="yes"/' /etc/default/rkhunter
    sed -i 's/APT_AUTOGEN=.*/APT_AUTOGEN="yes"/' /etc/default/rkhunter
    
    # Update rkhunter database
    rkhunter --update
    rkhunter --propupd
    
    # Create daily scan script
    cat > /etc/cron.daily/rkhunter-scan << EOF
#!/bin/bash
/usr/bin/rkhunter --check --skip-keypress --report-warnings-only | mail -s "RKHunter Daily Scan Report - \$(hostname)" root
EOF
    
    chmod +x /etc/cron.daily/rkhunter-scan
    
    log_message "${GREEN}Rootkit detection configured successfully.${NC}"
}

# Function to install and configure intrusion detection
configure_intrusion_detection() {
    log_message "${YELLOW}Configuring intrusion detection...${NC}"
    
    # Install AIDE if not installed
    if ! is_installed "aide"; then
        apt-get install -y aide
    fi
    
    # Initialize AIDE database
    aideinit
    
    # Move the new database to the active location
    mv /var/lib/aide/aide.db.new /var/lib/aide/aide.db
    
    # Create daily check script
    cat > /etc/cron.daily/aide-check << EOF
#!/bin/bash
/usr/bin/aide --check | mail -s "AIDE Daily Check Report - \$(hostname)" root
EOF
    
    chmod +x /etc/cron.daily/aide-check
    
    log_message "${GREEN}Intrusion detection configured successfully.${NC}"
}

# Function to display security menu
security_menu() {
    clear
    echo -e "${BLUE}${BOLD}=== SECURITY ENHANCEMENT MENU ===${NC}"
    echo -e "${CYAN}1.${NC} Install Security Packages"
    echo -e "${CYAN}2.${NC} Configure Fail2ban"
    echo -e "${CYAN}3.${NC} Configure UFW Firewall"
    echo -e "${CYAN}4.${NC} Harden SSH Configuration"
    echo -e "${CYAN}5.${NC} Configure Automatic Security Updates"
    echo -e "${CYAN}6.${NC} Run Security Audit"
    echo -e "${CYAN}7.${NC} Secure Shared Memory"
    echo -e "${CYAN}8.${NC} Secure Sysctl Settings"
    echo -e "${CYAN}9.${NC} Secure User Accounts"
    echo -e "${CYAN}10.${NC} Configure Audit System"
    echo -e "${CYAN}11.${NC} Configure Rootkit Detection"
    echo -e "${CYAN}12.${NC} Configure Intrusion Detection"
    echo -e "${CYAN}13.${NC} Apply All Security Enhancements"
    echo -e "${CYAN}14.${NC} Back to Main Menu"
    echo -e "${CYAN}0.${NC} Exit"
    echo ""
    read -p "Select an option: " option
    
    case $option in
        1)
            install_security_packages
            echo ""
            read -p "Press Enter to continue..."
            security_menu
            ;;
        2)
            configure_fail2ban
            echo ""
            read -p "Press Enter to continue..."
            security_menu
            ;;
        3)
            configure_ufw
            echo ""
            read -p "Press Enter to continue..."
            security_menu
            ;;
        4)
            harden_ssh
            echo ""
            read -p "Press Enter to continue..."
            security_menu
            ;;
        5)
            configure_auto_updates
            echo ""
            read -p "Press Enter to continue..."
            security_menu
            ;;
        6)
            run_security_audit
            echo ""
            read -p "Press Enter to continue..."
            security_menu
            ;;
        7)
            secure_shared_memory
            echo ""
            read -p "Press Enter to continue..."
            security_menu
            ;;
        8)
            secure_sysctl
            echo ""
            read -p "Press Enter to continue..."
            security_menu
            ;;
        9)
            secure_user_accounts
            echo ""
            read -p "Press Enter to continue..."
            security_menu
            ;;
        10)
            configure_auditd
            echo ""
            read -p "Press Enter to continue..."
            security_menu
            ;;
        11)
            configure_rootkit_detection
            echo ""
            read -p "Press Enter to continue..."
            security_menu
            ;;
        12)
            configure_intrusion_detection
            echo ""
            read -p "Press Enter to continue..."
            security_menu
            ;;
        13)
            install_security_packages
            configure_fail2ban
            configure_ufw
            harden_ssh
            configure_auto_updates
            secure_shared_memory
            secure_sysctl
            secure_user_accounts
            configure_auditd
            configure_rootkit_detection
            configure_intrusion_detection
            run_security_audit
            echo ""
            read -p "Press Enter to continue..."
            security_menu
            ;;
        14)
            # Return to main menu (handled by calling script)
            return
            ;;
        0)
            exit 0
            ;;
        *)
            echo -e "${RED}Invalid option!${NC}"
            sleep 2
            security_menu
            ;;
    esac
}

# Function to apply all security enhancements
apply_all_security() {
    install_security_packages
    configure_fail2ban
    configure_ufw
    harden_ssh
    configure_auto_updates
    secure_shared_memory
    secure_sysctl
    secure_user_accounts
    configure_auditd
    configure_rootkit_detection
    configure_intrusion_detection
    run_security_audit
}

# Main execution
case "$1" in
    install)
        install_security_packages
        ;;
    fail2ban)
        configure_fail2ban
        ;;
    ufw)
        configure_ufw
        ;;
    ssh)
        harden_ssh
        ;;
    updates)
        configure_auto_updates
        ;;
    audit)
        run_security_audit
        ;;
    memory)
        secure_shared_memory
        ;;
    sysctl)
        secure_sysctl
        ;;
    accounts)
        secure_user_accounts
        ;;
    auditd)
        configure_auditd
        ;;
    rootkit)
        configure_rootkit_detection
        ;;
    intrusion)
        configure_intrusion_detection
        ;;
    all)
        apply_all_security
        ;;
    menu)
        security_menu
        ;;
    *)
        echo -e "${BLUE}${BOLD}Security Enhancement Script for VPS Manager${NC}"
        echo -e "${CYAN}Usage:${NC}"
        echo -e "  $0 install              - Install security packages"
        echo -e "  $0 fail2ban             - Configure fail2ban"
        echo -e "  $0 ufw                  - Configure UFW firewall"
        echo -e "  $0 ssh                  - Harden SSH configuration"
        echo -e "  $0 updates              - Configure automatic security updates"
        echo -e "  $0 audit                - Run security audit"
        echo -e "  $0 memory               - Secure shared memory"
        echo -e "  $0 sysctl               - Secure sysctl settings"
        echo -e "  $0 accounts             - Secure user accounts"
        echo -e "  $0 auditd               - Configure audit system"
        echo -e "  $0 rootkit              - Configure rootkit detection"
        echo -e "  $0 intrusion            - Configure intrusion detection"
        echo -e "  $0 all                  - Apply all security enhancements"
        echo -e "  $0 menu                 - Show security menu"
        ;;
esac

exit 0
