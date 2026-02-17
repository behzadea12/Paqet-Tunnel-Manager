#!/bin/bash
#=================================================
# Paqet Tunnel Manager
# Version: 6.0 (Fully Refactored)
# Raw packet-level tunneling for bypassing network restrictions
# GitHub: https://github.com/hanselime/paqet
# Manager GitHub: https://github.com/behzadea12/Paqet-Tunnel-Manager
#=================================================

# ================================================
# CONFIGURATION DEFAULTS (Easily modifiable)
# ================================================

# Colors
readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[1;33m'
readonly CYAN='\033[0;36m'
readonly BLUE='\033[0;34m'
readonly MAGENTA='\033[0;35m'
readonly WHITE='\033[1;37m'
readonly ORANGE='\033[0;33m'
readonly PURPLE='\033[0;35m'
readonly NC='\033[0m'

# Script Configuration
readonly SCRIPT_VERSION="6.0"
readonly MANAGER_NAME="paqet-manager"
readonly MANAGER_PATH="/usr/local/bin/$MANAGER_NAME"

# Paths
readonly CONFIG_DIR="/etc/paqet"
readonly SERVICE_DIR="/etc/systemd/system"
readonly BIN_DIR="/usr/local/bin"
readonly INSTALL_DIR="/opt/paqet"
readonly BACKUP_DIR="/root/paqet-backups"

# Repositories
readonly GITHUB_REPO="hanselime/paqet"
readonly MANAGER_GITHUB_REPO="behzadea12/Paqet-Tunnel-Manager"
readonly SERVICE_NAME="paqet"

# Kernel optimization settings
readonly SYSCTL_FILE="/etc/sysctl.d/99-paqet-tunnel.conf"
readonly LIMITS_FILE="/etc/security/limits.d/99-paqet.conf"
readonly BACKUP_SYSCTL="${BACKUP_DIR}/sysctl-99-paqet.backup-$(date +%Y%m%d-%H%M%S)"
readonly BACKUP_LIMITS="${BACKUP_DIR}/limits-99-paqet.backup-$(date +%Y%m%d-%H%M%S)"

# Default Values
readonly DEFAULT_LISTEN_PORT="8888"
readonly DEFAULT_KCP_MODE="fast"
readonly DEFAULT_ENCRYPTION="aes-128-gcm"
readonly DEFAULT_CONNECTIONS="4"
readonly DEFAULT_MTU="1150"
readonly DEFAULT_PCAP_SOCKBUF_SERVER="8388608"
readonly DEFAULT_PCAP_SOCKBUF_CLIENT="4194304"
readonly DEFAULT_TRANSPORT_TCPBUF="8192"
readonly DEFAULT_TRANSPORT_UDPBUF="4096"
readonly DEFAULT_AUTO_RESTART_INTERVAL="1hour"
readonly DEFAULT_V2RAY_PORTS="9090"
readonly DEFAULT_SOCKS5_PORT="1080"

# KCP Mode Descriptions
declare -A KCP_MODES=(
    ["0"]="normal:normal:Normal speed / Normal latency / Low usage"
    ["1"]="fast:fast:Balanced speed / Low latency / Normal usage"
    ["2"]="fast2:fast2:High speed / Lower latency / Medium usage"
    ["3"]="fast3:fast3:Max speed / Very low latency / High CPU"
    ["4"]="manual:manual:Advanced settings"
)

# Encryption Options
declare -A ENCRYPTION_OPTIONS=(
    ["1"]="aes-128-gcm:Very high security / Very fast / Recommended"
    ["2"]="aes:High security / Medium speed / General use"
    ["3"]="aes-128:High security / Fast / Low CPU usage"
    ["4"]="aes-192:Very high security / Medium speed / Moderate CPU usage"
    ["5"]="aes-256:Maximum security / Slower / Higher CPU usage"
    ["6"]="none:No encryption / Max speed / Insecure"
    ["7"]="null:No encryption / Max speed / Insecure"
)

# Auto-restart intervals
declare -A RESTART_INTERVALS=(
    ["1min"]="*/1 * * * *"
    ["5min"]="*/5 * * * *"
    ["15min"]="*/15 * * * *"
    ["30min"]="*/30 * * * *"
    ["1hour"]="0 */1 * * *"
    ["12hour"]="0 */12 * * *"
    ["1day"]="0 0 * * *"
)

# IP detection services
readonly IP_SERVICES=(
    "ifconfig.me"
    "icanhazip.com"
    "api.ipify.org"
    "checkip.amazonaws.com"
    "ipinfo.io/ip"
)

# Test domains for DNS
readonly TEST_DOMAINS=(
    "google.com"
    "github.com"
    "cloudflare.com"
    "wikipedia.org"
)

# DNS servers for testing
readonly DNS_SERVERS=(
    "8.8.8.8"
    "1.1.1.1"
    "208.67.222.222"
    "system"
)

# MTU test sizes
readonly MTU_TESTS=(
    "1500"
    "1470"
    "1400"
    "1350"
    "1300"
    "1200"
    "1100"
)

# Common ports for testing
readonly COMMON_PORTS=("443" "80" "22" "53")

# Manager versions for switch option
declare -A MANAGER_VERSIONS=(
    ["latest"]="https://raw.githubusercontent.com/behzadea12/Paqet-Tunnel-Manager/main/paqet-manager.sh"
    ["5.1"]="https://raw.githubusercontent.com/behzadea12/Paqet-Tunnel-Manager/main/paqet-manager5-1.sh"
    ["3.8"]="https://raw.githubusercontent.com/behzadea12/Paqet-Tunnel-Manager/main/paqet-manager3-8.sh"
)

# ================================================
# UTILITY FUNCTIONS
# ================================================

# Print functions
print_step() { echo -e "${BLUE}[*]${NC} $1"; }
print_success() { echo -e "${GREEN}[✓]${NC} $1"; }
print_error() { echo -e "${RED}[✗]${NC} $1"; }
print_warning() { echo -e "${YELLOW}[!]${NC} $1"; }
print_info() { echo -e "${CYAN}[i]${NC} $1"; }
print_input() { echo -e "${YELLOW}[?]${NC} $1"; }

# Pause with custom message
pause() {
    local msg="${1:-Press Enter to continue...}"
    echo ""
    read -p "$msg" </dev/tty
}

# Clear screen and show banner
show_banner() {
    clear
    echo -e "${MAGENTA}"
    echo "╔══════════════════════════════════════════════════════════════╗"
    echo "║                                                              ║"
    echo "║     ██████╗  █████╗  ██████╗ ███████╗████████╗               ║"
    echo "║     ██╔══██╗██╔══██╗██╔═══██╗██╔════╝╚══██╔══╝               ║"
    echo "║     ██████╔╝███████║██║   ██║█████╗     ██║                  ║"
    echo "║     ██╔═══╝ ██╔══██║██║▄▄ ██║██╔══╝     ██║                  ║"
    echo "║     ██║     ██║  ██║╚██████╔╝███████╗   ██║                  ║"
    echo "║     ╚═╝     ╚═╝  ╚═╝ ╚══▀▀═╝ ╚══════╝   ╚═╝                  ║"
    echo "║                                                              ║"
    echo "║          Raw Packet Tunnel - Firewall Bypass                 ║"
    echo "║                                 Manager v${SCRIPT_VERSION}                 ║"
    echo "║                                                              ║"
    echo "║          https://t.me/behzad_developer                       ║"
    echo "║          https://github.com/behzadea12                       ║"    
    echo "║                                                              ║"
    echo "╚══════════════════════════════════════════════════════════════╝"
    echo -e "${NC}"
}

# Check root
check_root() {
    if [[ $EUID -ne 0 ]]; then
        print_error "This script must be run as root"
        exit 1
    fi
}

# Detect OS
detect_os() {
    if [ -f /etc/os-release ]; then
        . /etc/os-release
        echo "$ID"
    elif [ -f /etc/redhat-release ]; then
        echo "rhel"
    else
        echo "$(uname -s | tr '[:upper:]' '[:lower:]')"
    fi
}

# Detect architecture
detect_arch() {
    local arch
    arch=$(uname -m)
    
    case $arch in
        x86_64|x86-64|amd64) echo "amd64" ;;
        aarch64|arm64) echo "arm64" ;;
        armv7l|armhf) echo "armv7" ;;
        i386|i686) echo "386" ;;
        *)
            print_error "Unsupported architecture: $arch"
            return 1
            ;;
    esac
}

# Get public IP
get_public_ip() {
    for service in "${IP_SERVICES[@]}"; do
        local ip
        ip=$(curl -4 -s --max-time 2 "$service" 2>/dev/null)
        if [ -n "$ip" ] && [[ "$ip" =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
            echo "$ip"
            return 0
        fi
    done
    
    local ip
    ip=$(hostname -I | awk '{print $1}' 2>/dev/null)
    if [ -n "$ip" ] && [[ "$ip" =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
        echo "$ip"
        return 0
    fi
    
    echo "Not Detected"
}

# Get network information
get_network_info() {
    NETWORK_INTERFACE=""
    LOCAL_IP=""
    GATEWAY_IP=""
    GATEWAY_MAC=""
    
    if command -v ip &>/dev/null; then
        NETWORK_INTERFACE=$(ip route | grep default | awk '{print $5}' | head -1)
        LOCAL_IP=$(ip -4 addr show "$NETWORK_INTERFACE" 2>/dev/null | grep -oP '(?<=inet\s)\d+(\.\d+){3}' | head -1)
        GATEWAY_IP=$(ip route | grep default | awk '{print $3}' | head -1)
        
        if [ -n "$GATEWAY_IP" ]; then
            ping -c 1 -W 1 "$GATEWAY_IP" >/dev/null 2>&1 || true
            GATEWAY_MAC=$(ip neigh show "$GATEWAY_IP" 2>/dev/null | grep -oE '([0-9a-fA-F]{2}:){5}[0-9a-fA-F]{2}' | head -1)
            
            if [ -z "$GATEWAY_MAC" ] && command -v arp &>/dev/null; then
                GATEWAY_MAC=$(arp -n "$GATEWAY_IP" 2>/dev/null | awk "/^$GATEWAY_IP/ {print \$3}" | head -1)
            fi
        fi
    fi
    
    NETWORK_INTERFACE="${NETWORK_INTERFACE:-eth0}"
}

# Validate IP address
validate_ip() {
    local ip=$1
    if [[ $ip =~ ^[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}$ ]]; then
        local IFS='.'
        read -ra octets <<< "$ip"
        for octet in "${octets[@]}"; do
            if [[ $octet -lt 0 || $octet -gt 255 ]]; then
                return 1
            fi
        done
        return 0
    fi
    return 1
}

# Validate port
validate_port() {
    local port=$1
    [[ "$port" =~ ^[0-9]+$ ]] && [ "$port" -ge 1 ] && [ "$port" -le 65535 ]
}

# Clean port list
clean_port_list() {
    local ports="$1"
    ports=$(echo "$ports" | tr -d ' ')
    local cleaned=""
    
    IFS=',' read -ra port_array <<< "$ports"
    for port in "${port_array[@]}"; do
        if validate_port "$port"; then
            cleaned="${cleaned:+$cleaned,}$port"
        else
            print_warning "Invalid port '$port' removed from list"
        fi
    done
    
    echo "$cleaned"
}

# Clean config name
clean_config_name() {
    local name="$1"
    name=$(echo "$name" | tr -cd '[:alnum:]-_')
    echo "${name:-default}"
}

# Check port conflict
check_port_conflict() {
    local port="$1"
    
    if ss -tuln 2>/dev/null | grep -q ":${port} "; then
        print_warning "Port $port is already in use!"
        
        local pid
        pid=$(lsof -t -i:"$port" 2>/dev/null | head -1)
        if [ -n "$pid" ]; then
            local pname
            pname=$(ps -p "$pid" -o comm= 2>/dev/null || echo "unknown")
            print_info "Process: $pname (PID: $pid)"
            
            echo ""
            read -p "Kill this process? (y/N): " kill_choice
            
            if [[ "$kill_choice" =~ ^[Yy]$ ]]; then
                kill -9 "$pid" 2>/dev/null || true
                sleep 1
                print_success "Process killed"
            else
                print_error "Cannot continue with port in use"
                return 1
            fi
        fi
    fi
    return 0
}

# Generate secret key
generate_secret_key() {
    if command -v openssl &>/dev/null; then
        openssl rand -base64 32 | tr -dc 'a-zA-Z0-9' | head -c 32
    else
        tr -dc 'a-zA-Z0-9' </dev/urandom | head -c 32
    fi
}

# Get latest Paqet version from GitHub
get_latest_paqet_version() {
    local version
    version=$(curl -s "https://api.github.com/repos/${GITHUB_REPO}/releases/latest" | grep -o '"tag_name": "[^"]*"' | cut -d'"' -f4 2>/dev/null)    
    if [ -n "$version" ]; then
        echo "$version"
    else
        echo "v1.0.0-alpha.16"
    fi
}

# Compare floats (with bc fallback)
compare_floats() {
    local value=$1
    local threshold=$2
    local comparison=$3
    
    if ! command -v bc &>/dev/null; then
        local value_int=${value%.*}
        local threshold_int=${threshold%.*}
        
        case $comparison in
            "lt") [[ $value_int -lt $threshold_int ]] ;;
            "le") [[ $value_int -le $threshold_int ]] ;;
            "gt") [[ $value_int -gt $threshold_int ]] ;;
            "ge") [[ $value_int -ge $threshold_int ]] ;;
            *) return 1 ;;
        esac
        return $?
    fi
    
    case $comparison in
        "lt") (($(echo "$value < $threshold" | bc -l 2>/dev/null || echo 0))) ;;
        "le") (($(echo "$value <= $threshold" | bc -l 2>/dev/null || echo 0))) ;;
        "gt") (($(echo "$value > $threshold" | bc -l 2>/dev/null || echo 0))) ;;
        "ge") (($(echo "$value >= $threshold" | bc -l 2>/dev/null || echo 0))) ;;
        *) return 1 ;;
    esac
}

# ================================================
# CONFIGURATION FUNCTIONS
# ================================================

# Configure iptables
configure_iptables() {
    local port="$1"
    local protocol="$2"
    
    print_step "Configuring iptables for port $port protocol $protocol..."
    
    if ! command -v iptables &>/dev/null; then
        print_warning "iptables not found, skipping"
        return 0
    fi
    
    local protocols=()
    [ "$protocol" = "both" ] && protocols=("tcp" "udp") || protocols=("$protocol")
    
    for proto in "${protocols[@]}"; do
        iptables -t raw -D PREROUTING -p "$proto" --dport "$port" -j NOTRACK 2>/dev/null || true
        iptables -t raw -D OUTPUT -p "$proto" --sport "$port" -j NOTRACK 2>/dev/null || true
        
        iptables -t raw -A PREROUTING -p "$proto" --dport "$port" -j NOTRACK
        iptables -t raw -A OUTPUT -p "$proto" --sport "$port" -j NOTRACK
        
        if [ "$proto" = "tcp" ]; then
            iptables -t mangle -D OUTPUT -p tcp --sport "$port" --tcp-flags RST RST -j DROP 2>/dev/null || true
            iptables -t mangle -A OUTPUT -p tcp --sport "$port" --tcp-flags RST RST -j DROP
        fi
    done
    
    print_success "iptables configured for $protocol on port $port"
}

# Create systemd service
create_systemd_service() {
    local config_name="$1"
    local service_name="paqet-${config_name}"
    
    cat > "$SERVICE_DIR/${service_name}.service" << EOF
[Unit]
Description=Paqet Tunnel (${config_name})
After=network.target
StartLimitIntervalSec=0

[Service]
Type=simple
ExecStart=$BIN_DIR/paqet run -c $CONFIG_DIR/${config_name}.yaml
Restart=always
RestartSec=5
LimitNOFILE=65535
Environment="GOMAXPROCS=0"

[Install]
WantedBy=multi-user.target
EOF
    
    systemctl daemon-reload
    print_success "Service created: ${service_name}"
}

# ================================================
# CRONJOB MANAGEMENT
# ================================================

# Add auto-restart cronjob
add_auto_restart_cronjob() {
    local service_name="$1"
    local cron_interval="$2"
    local cron_command="systemctl restart ${service_name}"
    
    local cron_line="${RESTART_INTERVALS[$cron_interval]} $cron_command"
    [ -z "$cron_line" ] && { print_error "Invalid cron interval"; return 1; }
    
    if crontab -l 2>/dev/null | grep -q "$cron_command"; then
        crontab -l 2>/dev/null | grep -v "$cron_command" | crontab -
    fi
    
    (crontab -l 2>/dev/null; echo "$cron_line") | crontab -
    
    if [ $? -eq 0 ]; then
        print_success "Cronjob added: $cron_interval restart for $service_name"
        return 0
    else
        print_error "Failed to add cronjob"
        return 1
    fi
}

# Remove cronjob
remove_cronjob() {
    local service_name="$1"
    local cron_command="systemctl restart ${service_name}"
    
    if crontab -l 2>/dev/null | grep -q "$cron_command"; then
        crontab -l 2>/dev/null | grep -v "$cron_command" | crontab -
        print_success "Cronjob removed for $service_name"
        return 0
    fi
    print_info "No cronjob found for $service_name"
    return 1
}

# View cronjob
view_cronjob() {
    local service_name="$1"
    local cron_command="systemctl restart ${service_name}"
    
    echo -e "${YELLOW}Cronjobs for $service_name:${NC}"
    if crontab -l 2>/dev/null | grep -q "$cron_command"; then
        crontab -l 2>/dev/null | grep "$cron_command"
    else
        print_info "No cronjob found"
    fi
}

# Manage cronjob menu
manage_cronjob() {
    local service_name="$1"
    local display_name="$2"
    
    while true; do
        clear
        show_banner
        echo -e "${YELLOW}Manage Cronjob for: $display_name${NC}\n"
        
        echo -e "${CYAN}Current cronjob:${NC}"
        view_cronjob "$service_name"
        echo -e "\n${CYAN}Add/Change Cronjob:${NC}"
        
        local i=1
        for interval in "${!RESTART_INTERVALS[@]}"; do
            echo " $((i++)). $interval"
        done
        echo " $i. Remove cronjob"
        echo " 0. Back"
        echo ""
        
        read -p "Choose option [0-$i]: " cron_choice
        
        if [ "$cron_choice" = "0" ]; then
            return
        elif [ "$cron_choice" -eq "$i" ]; then
            remove_cronjob "$service_name"
            pause
        elif [ "$cron_choice" -ge 1 ] && [ "$cron_choice" -lt "$i" ]; then
            local idx=1
            for interval in "${!RESTART_INTERVALS[@]}"; do
                if [ "$cron_choice" -eq "$idx" ]; then
                    add_auto_restart_cronjob "$service_name" "$interval"
                    break
                fi
                ((idx++))
            done
            pause
        else
            print_error "Invalid choice"
            sleep 1
        fi
    done
}

# ================================================
# SERVICE MANAGEMENT
# ================================================

# Get service details
get_service_details() {
    local service_name="$1"
    local config_name="${service_name#paqet-}"
    local config_file="$CONFIG_DIR/$config_name.yaml"
    
    local type="unknown"
    local mode="fast"
    local mtu="-"
    local conn="-"
    local cron="No"
    
    if [ -f "$config_file" ]; then
        type=$(grep "^role:" "$config_file" 2>/dev/null | awk '{print $2}' | tr -d '"' || echo "unknown")
        
        local mode_line
        mode_line=$(grep "mode:" "$config_file" 2>/dev/null | head -1)
        [ -n "$mode_line" ] && mode=$(echo "$mode_line" | awk '{print $2}' | tr -d '"')
        
        if grep -q "mtu:" "$config_file" 2>/dev/null; then
            local mtu_line
            mtu_line=$(grep "mtu:" "$config_file" 2>/dev/null | head -1)
            [ -n "$mtu_line" ] && mtu=$(echo "$mtu_line" | awk '{print $2}' | tr -d '"')
        fi
        
        if grep -q "conn:" "$config_file" 2>/dev/null; then
            local conn_line
            conn_line=$(grep "conn:" "$config_file" 2>/dev/null | head -1)
            [ -n "$conn_line" ] && conn=$(echo "$conn_line" | awk '{print $2}' | tr -d '"')
        fi
    fi
    
    crontab -l 2>/dev/null | grep -q "systemctl restart $service_name" && cron="Yes"
    
    echo "$type $mode $mtu $conn $cron"
}

# Manage single service
manage_single_service() {
    local selected_service="$1"
    local display_name="$2"
    
    while true; do
        clear
        show_banner
        
        local short_name="${display_name:0:32}"
        [ ${#display_name} -gt 32 ] && short_name="${short_name}..."
        
        echo -e "${GREEN}╔══════════════════════════════════════════════════════════════╗${NC}"
        printf "${GREEN}║ Managing: %-50s ║${NC}\n" "$short_name"
        echo -e "${GREEN}╚══════════════════════════════════════════════════════════════╝${NC}\n"
        
        local status
        status=$(systemctl is-active "$selected_service" 2>/dev/null || echo "unknown")
        
        echo -e "${CYAN}Status:${NC} "
        case "$status" in
            active) echo -e "${GREEN}🟢 Active${NC}" ;;
            failed) echo -e "${RED}🔴 Failed${NC}" ;;
            inactive) echo -e "${YELLOW}🟡 Inactive${NC}" ;;
            *) echo -e "${WHITE}⚪ Unknown${NC}" ;;
        esac
        
        local details
        details=$(get_service_details "${selected_service%.service}")
        local type=$(echo "$details" | awk '{print $1}')
        local mode=$(echo "$details" | awk '{print $2}')
        local mtu=$(echo "$details" | awk '{print $3}')
        local conn=$(echo "$details" | awk '{print $4}')
        local cron=$(echo "$details" | awk '{print $5}')
        
        echo -e "\n${CYAN}Details:${NC}"
        echo -e "${CYAN}┌──────────────────────────────────────────────┐${NC}"
        printf "${CYAN}│${NC} %-16s ${CYAN}:${NC} %-25s ${CYAN}│${NC}\n" "Type" "${type:-unknown}"
        printf "${CYAN}│${NC} %-16s ${CYAN}:${NC} %-25s ${CYAN}│${NC}\n" "KCP Mode" "${mode:-fast}"
        printf "${CYAN}│${NC} %-16s ${CYAN}:${NC} %-25s ${CYAN}│${NC}\n" "MTU" "${mtu:--}"
        printf "${CYAN}│${NC} %-16s ${CYAN}:${NC} %-25s ${CYAN}│${NC}\n" "Connections" "${conn:--}"
        printf "${CYAN}│${NC} %-16s ${CYAN}:${NC} %-25s ${CYAN}│${NC}\n" "Auto-Restart" "${cron:-No}"
        echo -e "${CYAN}└──────────────────────────────────────────────┘${NC}"
        
        echo -e "\n${CYAN}Actions${NC}"
        echo " 1. 🟢 Start"
        echo " 2. 🔴 Stop"
        echo " 3. 🔄 Restart"
        echo " 4. 📊 Show Status"
        echo " 5. 📝 View Recent Logs"
        echo " 6. ✏️  Edit Configuration"
        echo " 7. 📄 View Configuration"
        echo " 8. ⏰ Cronjob Management"
        echo " 9. 🗑️  Delete Service"
        echo " 0. ↩️  Back"
        echo ""
        
        read -p "Choose action [0-9]: " action
        
        case "$action" in
            0) return ;;
            1) systemctl start "$selected_service" >/dev/null 2>&1
               print_success "Service started"
               sleep 1.5 ;;
            2) systemctl stop "$selected_service" >/dev/null 2>&1
               print_success "Service stopped"
               sleep 1.5 ;;
            3) systemctl restart "$selected_service" >/dev/null 2>&1
               print_success "Service restarted"
               sleep 1.5 ;;
            4) echo ""
               systemctl status "$selected_service" --no-pager -l
               pause ;;
            5) echo ""
               journalctl -u "$selected_service" -n 25 --no-pager
               pause ;;
            6) local cfg="$CONFIG_DIR/$display_name.yaml"
               if [ -f "$cfg" ]; then
                   echo -e "\n${YELLOW}Editing: $cfg${NC}"
                   local editor="nano"
                   command -v nano &>/dev/null || editor="vi"
                   $editor "$cfg"
                   
                   read -p "Restart service to apply changes? (y/N): " restart_choice
                   if [[ "$restart_choice" =~ ^[Yy]$ ]]; then
                       systemctl restart "$selected_service" >/dev/null 2>&1
                       if systemctl is-active --quiet "$selected_service"; then
                           print_success "Service restarted"
                       else
                           print_error "Service failed to start"
                           systemctl status "$selected_service" --no-pager -l
                       fi
                   fi
               else
                   print_error "Config file not found"
               fi
               pause ;;
            7) local cfg="$CONFIG_DIR/$display_name.yaml"
               if [ -f "$cfg" ]; then
                   echo -e "\n${CYAN}$cfg${NC}\n"
                   cat "$cfg"
               else
                   print_error "Config file not found"
               fi
               pause ;;
            8) manage_cronjob "${selected_service%.service}" "$display_name" ;;
            9) read -p "Delete this service? (y/N): " confirm
               if [[ "$confirm" =~ ^[Yy]$ ]]; then
                   remove_cronjob "${selected_service%.service}" 2>/dev/null || true
                   systemctl stop "$selected_service" 2>/dev/null || true
                   systemctl disable "$selected_service" 2>/dev/null || true
                   rm -f "$SERVICE_DIR/$selected_service" 2>/dev/null || true
                   rm -f "$CONFIG_DIR/$display_name.yaml" 2>/dev/null || true
                   systemctl daemon-reload 2>/dev/null || true
                   print_success "Service removed"
                   pause
                   return
               fi ;;
            *) print_error "Invalid choice"
               sleep 1 ;;
        esac
    done
}

# Manage all services
manage_services() {
    while true; do
        clear
        show_banner
        
        echo -e "${GREEN}╔═══════════════════════════════════════════════════════════════════════════════════════════════════════════╗${NC}"
        echo -e "${GREEN}║ Paqet Services - Manage                                                                                   ║${NC}"
        echo -e "${GREEN}╚═══════════════════════════════════════════════════════════════════════════════════════════════════════════╝${NC}\n"
        
        local services=()
        mapfile -t services < <(systemctl list-unit-files --type=service --no-legend --no-pager 2>/dev/null |
                              grep -E '^paqet-.*\.service' | awk '{print $1}' || true)
        
        if [[ ${#services[@]} -eq 0 ]]; then
            echo -e "${YELLOW}No Paqet services found.${NC}\n"
            pause
            return
        fi
        
        echo -e "${CYAN}┌─────┬──────────────────────────┬─────────────┬───────────┬────────────────┬────────────┬──────────┬────────┐${NC}"
        echo -e "${CYAN}│  #  │ Service Name             │ Status      │ Type      │ Auto Restart   │ Mode       │ MTU      │ Conn   │${NC}"
        echo -e "${CYAN}├─────┼──────────────────────────┼─────────────┼───────────┼────────────────┼────────────┼──────────┼────────┤${NC}"
        
        local i=1
        for svc in "${services[@]}"; do
            local service_name="${svc%.service}"
            local display_name="${service_name#paqet-}"
            local status
            status=$(systemctl is-active "$svc" 2>/dev/null || echo "unknown")
            local details
            details=$(get_service_details "$service_name")
            local type=$(echo "$details" | awk '{print $1}')
            local mode=$(echo "$details" | awk '{print $2}')
            local mtu=$(echo "$details" | awk '{print $3}')
            local conn=$(echo "$details" | awk '{print $4}')
            local cron=$(echo "$details" | awk '{print $5}')
            
            local status_color=""
            case "$status" in
                active) status_color="${GREEN}" ;;
                failed) status_color="${RED}" ;;
                inactive) status_color="${YELLOW}" ;;
                *) status_color="${WHITE}" ;;
            esac
            
            local mode_color=""
            case "$mode" in
                normal) mode_color="${CYAN}" ;;
                fast) mode_color="${GREEN}" ;;
                fast2) mode_color="${ORANGE}" ;;
                fast3) mode_color="${PURPLE}" ;;
                manual) mode_color="${RED}" ;;
                *) mode_color="${WHITE}" ;;
            esac
            
            printf "${CYAN}│${NC} %3d ${CYAN}│${NC} %-24s ${CYAN}│${NC} ${status_color}%-11s${NC} ${CYAN}│${NC} %-9s ${CYAN}│${NC} %-14s ${CYAN}│${NC} ${mode_color}%-10s${NC} ${CYAN}│${NC} %-8s ${CYAN}│${NC} %-6s ${CYAN}│${NC}\n" \
                "$i" "${display_name:0:24}" "$status" "${type:-unknown}" "${cron:-No}" "${mode:-fast}" "${mtu:--}" "${conn:--}"
            ((i++))
        done
        
        echo -e "${CYAN}└─────┴──────────────────────────┴─────────────┴───────────┴────────────────┴────────────┴──────────┴────────┘${NC}\n"
        echo -e "${YELLOW}Options:${NC}"
        echo -e " 0. ↩️ Back to Main Menu"
        echo -e " 1–${#services[@]}. Select a service to manage"
        echo ""
        
        read -p "Enter choice (0 to cancel): " choice
        
        [ "$choice" = "0" ] && return
        
        if ! [[ "$choice" =~ ^[0-9]+$ ]] || (( choice < 1 || choice > ${#services[@]} )); then
            print_error "Invalid selection"
            sleep 1.5
            continue
        fi
        
        local selected_service="${services[$((choice-1))]}"
        local service_name="${selected_service%.service}"
        local display_name="${service_name#paqet-}"
        manage_single_service "$selected_service" "$display_name"
    done
}

# ================================================
# KCP MANUAL SETTINGS
# ================================================
get_manual_kcp_settings() {
    local nodelay=""
    while true; do
        read -p "[1] nodelay [0-2, default 1, 0=skip]: " input
        if [ -z "$input" ]; then
            nodelay="1"
            echo -e "  ${GREEN}→ Using default: 1${NC}" >&2
            break
        elif [ "$input" = "0" ]; then
            nodelay=""
            echo -e "  ${YELLOW}→ Skipped${NC}" >&2
            break
        elif [[ "$input" =~ ^[0-2]$ ]]; then
            nodelay="$input"
            echo -e "  ${GREEN}→ Set to: $input${NC}" >&2
            break
        else
            echo -e "  ${RED}✗ Invalid: Value must be 0, 1 or 2${NC}" >&2
        fi
    done
    
    local interval=""
    while true; do
        read -p "[2] interval (ms) [default 20, 0=skip]: " input
        if [ -z "$input" ]; then
            interval="20"
            echo -e "  ${GREEN}→ Using default: 20${NC}" >&2
            break
        elif [ "$input" = "0" ]; then
            interval=""
            echo -e "  ${YELLOW}→ Skipped${NC}" >&2
            break
        elif [[ "$input" =~ ^[0-9]+$ ]] && [ "$input" -ge 5 ] && [ "$input" -le 60000 ]; then
            interval="$input"
            echo -e "  ${GREEN}→ Set to: $input${NC}" >&2
            break
        else
            echo -e "  ${RED}✗ Invalid: Range 5–60000 ms${NC}" >&2
        fi
    done
    
    local resend=""
    while true; do
        read -p "[3] resend [0-∞, default 1, 0=skip]: " input
        if [ -z "$input" ]; then
            resend="1"
            echo -e "  ${GREEN}→ Using default: 1${NC}" >&2
            break
        elif [ "$input" = "0" ]; then
            resend=""
            echo -e "  ${YELLOW}→ Skipped${NC}" >&2
            break
        elif [[ "$input" =~ ^[0-9]+$ ]]; then
            resend="$input"
            echo -e "  ${GREEN}→ Set to: $input${NC}" >&2
            break
        else
            echo -e "  ${RED}✗ Invalid: Must be non-negative number${NC}" >&2
        fi
    done
    
    local nocongestion=""
    while true; do
        read -p "[4] nocongestion [0/1, default 1, 0=skip]: " input
        if [ -z "$input" ]; then
            nocongestion="1"
            echo -e "  ${GREEN}→ Using default: 1${NC}" >&2
            break
        elif [ "$input" = "0" ]; then
            nocongestion=""
            echo -e "  ${YELLOW}→ Skipped${NC}" >&2
            break
        elif [[ "$input" =~ ^[01]$ ]]; then
            nocongestion="$input"
            echo -e "  ${GREEN}→ Set to: $input${NC}" >&2
            break
        else
            echo -e "  ${RED}✗ Invalid: Only 0 or 1 allowed${NC}" >&2
        fi
    done
    
    local rcvwnd=""
    while true; do
        read -p "[5] rcvwnd [default 2048, 0=skip]: " input
        if [ -z "$input" ]; then
            rcvwnd="2048"
            echo -e "  ${GREEN}→ Using default: 2048${NC}" >&2
            break
        elif [ "$input" = "0" ]; then
            rcvwnd=""
            echo -e "  ${YELLOW}→ Skipped${NC}" >&2
            break
        elif [[ "$input" =~ ^[0-9]+$ ]] && [ "$input" -ge 128 ]; then
            rcvwnd="$input"
            echo -e "  ${GREEN}→ Set to: $input${NC}" >&2
            break
        else
            echo -e "  ${RED}✗ Invalid: Minimum 128${NC}" >&2
        fi
    done
    
    local sndwnd=""
    while true; do
        read -p "[6] sndwnd [default 2048, 0=skip]: " input
        if [ -z "$input" ]; then
            sndwnd="2048"
            echo -e "  ${GREEN}→ Using default: 2048${NC}" >&2
            break
        elif [ "$input" = "0" ]; then
            sndwnd=""
            echo -e "  ${YELLOW}→ Skipped${NC}" >&2
            break
        elif [[ "$input" =~ ^[0-9]+$ ]] && [ "$input" -ge 128 ]; then
            sndwnd="$input"
            echo -e "  ${GREEN}→ Set to: $input${NC}" >&2
            break
        else
            echo -e "  ${RED}✗ Invalid: Minimum 128${NC}" >&2
        fi
    done
    
    local wdelay=""
    while true; do
        read -p "[7] wdelay (true/false) [default false, 0=skip]: " input
        if [ -z "$input" ]; then
            wdelay="false"
            echo -e "  ${GREEN}→ Using default: false${NC}" >&2
            break
        elif [ "$input" = "0" ]; then
            wdelay=""
            echo -e "  ${YELLOW}→ Skipped${NC}" >&2
            break
        elif [[ "${input,,}" = "false" ]]; then
            wdelay="false"
            echo -e "  ${GREEN}→ Set to: false${NC}" >&2
            break
        elif [[ "${input,,}" = "true" ]]; then
            wdelay="true"
            echo -e "  ${GREEN}→ Set to: true${NC}" >&2
            break
        else
            echo -e "  ${RED}✗ Invalid: Only true or false${NC}" >&2
        fi
    done
    
    local acknodelay=""
    while true; do
        read -p "[8] acknodelay (true/false) [default true, 0=skip]: " input
        if [ -z "$input" ]; then
            acknodelay="true"
            echo -e "  ${GREEN}→ Using default: true${NC}" >&2
            break
        elif [ "$input" = "0" ]; then
            acknodelay=""
            echo -e "  ${YELLOW}→ Skipped${NC}" >&2
            break
        elif [[ "${input,,}" = "true" ]]; then
            acknodelay="true"
            echo -e "  ${GREEN}→ Set to: true${NC}" >&2
            break
        elif [[ "${input,,}" = "false" ]]; then
            acknodelay="false"
            echo -e "  ${GREEN}→ Set to: false${NC}" >&2
            break
        else
            echo -e "  ${RED}✗ Invalid: Only true or false${NC}" >&2
        fi
    done
    
    local smuxbuf=""
    echo -en "[9] smuxbuf [default 4194304, 0=skip]: " >&2
    read -r smuxbuf_input
    if [ -z "$smuxbuf_input" ]; then
        smuxbuf="4194304"
        echo -e "  ${GREEN}→ Using default: 4194304${NC}" >&2
    elif [ "$smuxbuf_input" = "0" ]; then
        smuxbuf=""
        echo -e "  ${YELLOW}→ Skipped${NC}" >&2
    else
        smuxbuf="$smuxbuf_input"
        echo -e "  ${GREEN}→ Set to: $smuxbuf_input${NC}" >&2
    fi
    
    local streambuf=""
    echo -en "[10] streambuf [default 2097152, 0=skip]: " >&2
    read -r streambuf_input
    if [ -z "$streambuf_input" ]; then
        streambuf="2097152"
        echo -e "  ${GREEN}→ Using default: 2097152${NC}" >&2
    elif [ "$streambuf_input" = "0" ]; then
        streambuf=""
        echo -e "  ${YELLOW}→ Skipped${NC}" >&2
    else
        streambuf="$streambuf_input"
        echo -e "  ${GREEN}→ Set to: $streambuf_input${NC}" >&2
    fi
    
    local dshard=""
    echo -en "[11] dshard (FEC data) [default 10, 0=skip]: " >&2
    read -r dshard_input
    if [ -z "$dshard_input" ]; then
        dshard="10"
        echo -e "  ${GREEN}→ Using default: 10${NC}" >&2
    elif [ "$dshard_input" = "0" ]; then
        dshard=""
        echo -e "  ${YELLOW}→ Skipped${NC}" >&2
    else
        dshard="$dshard_input"
        echo -e "  ${GREEN}→ Set to: $dshard_input${NC}" >&2
    fi
    
    local pshard=""
    echo -en "[12] pshard (FEC parity) [default 3, 0=skip]: " >&2
    read -r pshard_input
    if [ -z "$pshard_input" ]; then
        pshard="3"
        echo -e "  ${GREEN}→ Using default: 3${NC}" >&2
    elif [ "$pshard_input" = "0" ]; then
        pshard=""
        echo -e "  ${YELLOW}→ Skipped${NC}" >&2
    else
        pshard="$pshard_input"
        echo -e "  ${GREEN}→ Set to: $pshard_input${NC}" >&2
    fi

    echo "" >&2

    # Only output parameters that have values
    echo "mode: \"manual\""
    [ -n "$nodelay" ] && echo "nodelay: $nodelay"
    [ -n "$interval" ] && echo "interval: $interval"
    [ -n "$resend" ] && echo "resend: $resend"
    [ -n "$nocongestion" ] && echo "nocongestion: $nocongestion"
    [ -n "$rcvwnd" ] && echo "rcvwnd: $rcvwnd"
    [ -n "$sndwnd" ] && echo "sndwnd: $sndwnd"
    [ -n "$wdelay" ] && echo "wdelay: $wdelay"
    [ -n "$acknodelay" ] && echo "acknodelay: $acknodelay"
    [ -n "$smuxbuf" ] && echo "smuxbuf: $smuxbuf"
    [ -n "$streambuf" ] && echo "streambuf: $streambuf"
    [ -n "$dshard" ] && echo "dshard: $dshard"
    [ -n "$pshard" ] && echo "pshard: $pshard"
}

# ================================================
# CONFIGURATION MENUS
# ================================================

# Configure as Server
configure_server() {
    while true; do
        clear
        show_banner
        echo -e "${GREEN}╔══════════════════════════════════════════════════════════════╗${NC}"
        echo -e "${GREEN}║ Configure as Server (Abroad/Kharej)                          ║${NC}"
        echo -e "${GREEN}╚══════════════════════════════════════════════════════════════╝${NC}\n"
        
        get_network_info
        local public_ip
        public_ip=$(get_public_ip)
        
        echo -e "${YELLOW}Detected Network Information${NC}"
        echo -e "┌──────────────────────────────────────────────────────────────┐"
        printf "│ %-12s : %-44s │\n" "Interface" "${NETWORK_INTERFACE:-Not found}"
        printf "│ %-12s : %-44s │\n" "Local IP" "${LOCAL_IP:-Not found}"
        printf "│ %-12s : %-44s │\n" "Public IP" "$public_ip"
        printf "│ %-12s : %-44s │\n" "Gateway MAC" "${GATEWAY_MAC:-Not found}"
        echo -e "└──────────────────────────────────────────────────────────────┘\n"
        
        echo -e "${CYAN}Server Configuration${NC}"
        echo -e "────────────────────────────────────────────────────────────────"
        
        # [1/12] Service Name
        echo -en "${YELLOW}[1/12] Service Name (e.g: myserver) : ${NC}"
        read -r config_name
        config_name=$(clean_config_name "${config_name:-server}")
        echo -e "[1/12] Service Name : ${CYAN}$config_name${NC}"
        
        if [ -f "$CONFIG_DIR/${config_name}.yaml" ]; then
            print_warning "Config '$config_name' already exists!"
            read -p "Overwrite? (y/N): " ow
            [[ ! "$ow" =~ ^[Yy]$ ]] && continue
        fi
        
        # [2/12] Listen Port
        echo -en "${YELLOW}[2/12] Listen Port (default: $DEFAULT_LISTEN_PORT) : ${NC}"
        read -r port
        port="${port:-$DEFAULT_LISTEN_PORT}"
        
        if ! validate_port "$port"; then
            print_error "Invalid port"
            sleep 1.5
            continue
        fi
        echo -e "[2/12] Listen Port : ${CYAN}$port${NC}"
        
        if ! check_port_conflict "$port"; then
            pause "Press Enter to retry..."
            continue
        fi
        
        # [3/12] Secret Key
        local secret_key
        secret_key=$(generate_secret_key)
        echo -e "${YELLOW}[3/12] Secret Key : ${GREEN}$secret_key${NC} (press Enter for auto-generate)"
        read -p "Use this key? (Y/n): " use
        
        if [[ "$use" =~ ^[Nn]$ ]]; then
            echo -en "${YELLOW}[3/12] Secret Key : ${NC}"
            read -r secret_key
            if [ ${#secret_key} -lt 8 ]; then
                print_error "Too short (min 8 characters)"
                continue
            fi
        fi
        echo -e "[3/12] Secret Key : ${GREEN}$secret_key${NC}"
        
        # [4/12] KCP Mode
        echo -e "\n${CYAN}KCP Mode Selection${NC}"
        echo -e "────────────────────────────────────────────────────────────────"
        for mode_key in 0 1 2 3 4; do
            IFS=':' read -r name desc <<< "${KCP_MODES[$mode_key]}"
            echo " [${mode_key}] ${name} - ${desc}"
        done
        echo ""

        local mode_choice
        read -p "[4/12] Choose KCP mode [0-4] (default 1): " mode_choice
        mode_choice="${mode_choice:-1}"

        local mode_name
        local kcp_fragment=""

        case $mode_choice in
            0) mode_name="normal" ;;
            1) mode_name="fast" ;;
            2) mode_name="fast2" ;;
            3) mode_name="fast3" ;;
            4) 
                mode_name="manual"
                echo -e "\n${YELLOW}Manual KCP Advanced Parameters${NC}"
                echo -e "────────────────────────────────────────────────────────────────"
                kcp_fragment=$(get_manual_kcp_settings)
                ;;
            *) mode_name="fast" ;;
        esac
        echo -e "[4/12] KCP Mode : ${CYAN}$mode_name${NC}"
        
        # [5/12] Connections
        echo -en "${YELLOW}[5/12] Connections [1-32, 0=skip] (default $DEFAULT_CONNECTIONS): ${NC}"
        read -r conn_input
        local conn=""
        if [ -z "$conn_input" ]; then
            conn="$DEFAULT_CONNECTIONS"
            echo -e "[5/12] Connections : ${CYAN}$DEFAULT_CONNECTIONS (default)${NC}"
        elif [ "$conn_input" = "0" ]; then
            conn=""
            echo -e "[5/12] Connections : ${CYAN}- (skipped)${NC}"
        elif [[ "$conn_input" =~ ^[1-9][0-9]?$ ]] && [ "$conn_input" -ge 1 ] && [ "$conn_input" -le 32 ]; then
            conn="$conn_input"
            echo -e "[5/12] Connections : ${CYAN}$conn_input${NC}"
        else
            conn="$DEFAULT_CONNECTIONS"
            echo -e "${YELLOW}Invalid, using default $DEFAULT_CONNECTIONS${NC}"
            echo -e "[5/12] Connections : ${CYAN}$DEFAULT_CONNECTIONS (corrected)${NC}"
        fi
        
        # [6/12] MTU
        echo -en "${YELLOW}[6/12] MTU [100-9000, 0=skip] (default $DEFAULT_MTU): ${NC}"
        read -r mtu_input
        local mtu=""
        if [ -z "$mtu_input" ]; then
            mtu="$DEFAULT_MTU"
            echo -e "[6/12] MTU : ${CYAN}$DEFAULT_MTU (default)${NC}"
        elif [ "$mtu_input" = "0" ]; then
            mtu=""
            echo -e "[6/12] MTU : ${CYAN}- (skipped)${NC}"
        elif [[ "$mtu_input" =~ ^[0-9]+$ ]] && [ "$mtu_input" -ge 100 ] && [ "$mtu_input" -le 9000 ]; then
            mtu="$mtu_input"
            echo -e "[6/12] MTU : ${CYAN}$mtu_input${NC}"
        else
            mtu="$DEFAULT_MTU"
            echo -e "${YELLOW}Invalid, using default $DEFAULT_MTU${NC}"
            echo -e "[6/12] MTU : ${CYAN}$DEFAULT_MTU (corrected)${NC}"
        fi
        
        # [7/12] Encryption
        echo -e "\n${CYAN}Encryption Selection${NC}"
        echo -e "────────────────────────────────────────────────────────────────"
        for enc_key in 1 2 3 4 5 6 7; do
            IFS=':' read -r enc_name enc_desc <<< "${ENCRYPTION_OPTIONS[$enc_key]}"
            echo " [${enc_key}] ${enc_name} - ${enc_desc}"
        done
        echo ""
        
        local enc_choice
        read -p "[7/12] Choose encryption [1-7] (default 1): " enc_choice
        enc_choice="${enc_choice:-1}"
        
        local block
        IFS=':' read -r block _ <<< "${ENCRYPTION_OPTIONS[$enc_choice]}"
        block="${block:-aes-128-gcm}"
        echo -e "[7/12] Encryption : ${CYAN}$block${NC}"
        
        # [8/12] pcap sockbuf
        echo -en "${YELLOW}[8/12] pcap sockbuf [default $DEFAULT_PCAP_SOCKBUF_SERVER, 0=skip]: ${NC}"
        read -r pcap_input
        local pcap_sockbuf=""
        if [ -z "$pcap_input" ]; then
            pcap_sockbuf="$DEFAULT_PCAP_SOCKBUF_SERVER"
            echo -e "[8/12] pcap sockbuf : ${CYAN}$DEFAULT_PCAP_SOCKBUF_SERVER (default)${NC}"
        elif [ "$pcap_input" = "0" ]; then
            pcap_sockbuf=""
            echo -e "[8/12] pcap sockbuf : ${CYAN}- (skipped)${NC}"
        else
            pcap_sockbuf="$pcap_input"
            echo -e "[8/12] pcap sockbuf : ${CYAN}$pcap_input${NC}"
        fi
        
        # [9/12] transport tcpbuf
        echo -en "${YELLOW}[9/12] transport tcpbuf [default $DEFAULT_TRANSPORT_TCPBUF, 0=skip]: ${NC}"
        read -r tcpbuf_input
        local transport_tcpbuf=""
        if [ -z "$tcpbuf_input" ]; then
            transport_tcpbuf="$DEFAULT_TRANSPORT_TCPBUF"
            echo -e "[9/12] transport tcpbuf : ${CYAN}$DEFAULT_TRANSPORT_TCPBUF (default)${NC}"
        elif [ "$tcpbuf_input" = "0" ]; then
            transport_tcpbuf=""
            echo -e "[9/12] transport tcpbuf : ${CYAN}- (skipped)${NC}"
        else
            transport_tcpbuf="$tcpbuf_input"
            echo -e "[9/12] transport tcpbuf : ${CYAN}$tcpbuf_input${NC}"
        fi
        
        # [10/12] transport udpbuf
        echo -en "${YELLOW}[10/12] transport udpbuf [default $DEFAULT_TRANSPORT_UDPBUF, 0=skip]: ${NC}"
        read -r udpbuf_input
        local transport_udpbuf=""
        if [ -z "$udpbuf_input" ]; then
            transport_udpbuf="$DEFAULT_TRANSPORT_UDPBUF"
            echo -e "[10/12] transport udpbuf : ${CYAN}$DEFAULT_TRANSPORT_UDPBUF (default)${NC}"
        elif [ "$udpbuf_input" = "0" ]; then
            transport_udpbuf=""
            echo -e "[10/12] transport udpbuf : ${CYAN}- (skipped)${NC}"
        else
            transport_udpbuf="$udpbuf_input"
            echo -e "[10/12] transport udpbuf : ${CYAN}$udpbuf_input${NC}"
        fi
        
        # Apply configuration
        echo -e "\n${CYAN}Applying Configuration${NC}"
        echo -e "────────────────────────────────────────────────────────────────"
        
        if [ ! -f "$BIN_DIR/paqet" ]; then
            install_paqet || continue
        fi
        
        configure_iptables "$port" "tcp"
        mkdir -p "$CONFIG_DIR"
        
        # Build server config with proper indentation
        {
            echo "# Paqet Server Configuration"
            echo "role: \"server\""
            echo "log:"
            echo "  level: \"info\""
            echo "listen:"
            echo "  addr: \":$port\""
            echo "network:"
            echo "  interface: \"$NETWORK_INTERFACE\""
            echo "  ipv4:"
            echo "    addr: \"$LOCAL_IP:$port\""
            echo "    router_mac: \"$GATEWAY_MAC\""
            echo "  tcp:"
            echo "    local_flag: [\"PA\"]"
            
            if [[ -n "$pcap_sockbuf" ]]; then
                echo "  pcap:"
                echo "    sockbuf: $pcap_sockbuf"
            fi
            
            echo "transport:"
            echo "  protocol: \"kcp\""
            
            [[ -n "$conn" ]] && echo "  conn: $conn"
            [[ -n "$transport_tcpbuf" ]] && echo "  tcpbuf: $transport_tcpbuf"
            [[ -n "$transport_udpbuf" ]] && echo "  udpbuf: $transport_udpbuf"
            
            echo "  kcp:"
            echo "    key: \"$secret_key\""
            
            if [ "$mode_name" = "manual" ] && [ -n "$kcp_fragment" ]; then
                # For manual mode, add block and mtu separately
                echo "    mode: \"manual\""
                echo "    block: \"$block\""
                [[ -n "$mtu" ]] && echo "    mtu: $mtu"
                # Add remaining manual settings from kcp_fragment
                while IFS= read -r line; do
                    if [[ -n "$line" ]] && ! echo "$line" | grep -q "mode:"; then
                        echo "    $line"
                    fi
                done <<< "$kcp_fragment"
            else
                # For non-manual modes
                echo "    mode: \"$mode_name\""
                echo "    block: \"$block\""
                [[ -n "$mtu" ]] && echo "    mtu: $mtu"
            fi
        } > "$CONFIG_DIR/${config_name}.yaml"
        
        echo -e "[+] Configuration saved : ${CYAN}$CONFIG_DIR/${config_name}.yaml${NC}"
        
        create_systemd_service "$config_name"
        local svc="paqet-${config_name}"
        systemctl enable "$svc" --now >/dev/null 2>&1
        
        if systemctl is-active --quiet "$svc"; then
            print_success "Server started successfully"
            add_auto_restart_cronjob "$svc" "$DEFAULT_AUTO_RESTART_INTERVAL" >/dev/null 2>&1
            
            echo -e "\n${GREEN}╔══════════════════════════════════════════════════════════════╗${NC}"
            echo -e "${GREEN}║ Server Ready                                                  ║${NC}"
            echo -e "${GREEN}╚══════════════════════════════════════════════════════════════╝${NC}\n"
            
            echo -e "${YELLOW}Server Information${NC}"
            echo -e "┌──────────────────────────────────────────────────────────────┐"
            printf "│ %-14s : %-44s │\n" "Public IP" "$public_ip"
            printf "│ %-14s : %-44s │\n" "Listen Port" "$port"
            printf "│ %-14s : %-44s │\n" "Connections" "${conn:-1}"
            printf "│ %-14s : %-44s │\n" "Auto Restart" "Every ${DEFAULT_AUTO_RESTART_INTERVAL}"
            echo -e "└──────────────────────────────────────────────────────────────┘\n"
            
            echo -e "${YELLOW}Secret Key (Client Configuration)${NC}"
            echo -e "┌──────────────────────────────────────────────────────────────┐"
            printf "│ %-60s │\n" "$secret_key"
            echo -e "└──────────────────────────────────────────────────────────────┘\n"
            
            echo -e "${YELLOW}KCP Configuration${NC}"
            echo -e "┌──────────────────────────────────────────────────────────────┐"
            printf "│ %-14s : %-44s │\n" "Mode" "$mode_name"
            printf "│ %-14s : %-44s │\n" "Encryption" "$block"
            printf "│ %-14s : %-44s │\n" "MTU" "${mtu:-1350}"
            echo -e "└──────────────────────────────────────────────────────────────┘\n"
            
            echo ""
            echo -e "${GREEN}✅ Server setup completed successfully!${NC}"
            echo -e "${CYAN}Options:${NC}"
            echo -e " 1. Press ${GREEN}Enter${NC} to go to service management for $config_name"
            echo -e " 2. Type ${YELLOW}menu${NC} to return to main menu"
            echo -e " 3. Type ${YELLOW}exit${NC} to exit"
            echo ""
            
            read -p "Your choice [Enter/menu/exit]: " post_choice
            
            case "${post_choice,,}" in
                ""|enter)
                    echo -e "${GREEN}➡️ Taking you to service management for $config_name...${NC}"
                    sleep 1
                    manage_single_service "$svc" "$config_name"
                    ;;
                menu)
                    echo -e "${CYAN}Returning to main menu...${NC}"
                    sleep 1
                    return 0
                    ;;
                exit)
                    echo -e "${GREEN}Goodbye!${NC}"
                    exit 0
                    ;;
                *)
                    echo -e "${YELLOW}Invalid choice. Returning to main menu...${NC}"
                    sleep 2
                    return 0
                    ;;
            esac
        else
            print_error "Service failed to start"
            systemctl status "$svc" --no-pager -l
            pause
        fi
        return 0
    done
}

# Configure as Client
configure_client() {
    while true; do
        clear
        show_banner
        echo -e "${GREEN}╔══════════════════════════════════════════════════════════════╗${NC}"
        echo -e "${GREEN}║ Configure as Client (Iran/Domestic)                           ║${NC}"
        echo -e "${GREEN}╚══════════════════════════════════════════════════════════════╝${NC}\n"
        
        get_network_info
        local public_ip
        public_ip=$(get_public_ip)
        
        echo -e "${YELLOW}Detected Network Information${NC}"
        echo -e "┌──────────────────────────────────────────────────────────────┐"
        printf "│ %-12s : %-44s │\n" "Interface" "${NETWORK_INTERFACE:-Not found}"
        printf "│ %-12s : %-44s │\n" "Local IP" "${LOCAL_IP:-Not found}"
        printf "│ %-12s : %-44s │\n" "Public IP" "$public_ip"
        printf "│ %-12s : %-44s │\n" "Gateway MAC" "${GATEWAY_MAC:-Not found}"
        echo -e "└──────────────────────────────────────────────────────────────┘\n"
        
        echo -e "${CYAN}Client Configuration${NC}"
        echo -e "────────────────────────────────────────────────────────────────"
        
        # [1/15] Service Name
        echo -en "${YELLOW}[1/15] Service Name (e.g: myclient) : ${NC}"
        read -r config_name
        config_name=$(clean_config_name "${config_name:-client}")
        echo -e "[1/15] Service Name : ${CYAN}$config_name${NC}"
        
        if [ -f "$CONFIG_DIR/${config_name}.yaml" ]; then
            print_warning "Config already exists!"
            read -p "Overwrite? (y/N): " ow
            [[ ! "$ow" =~ ^[Yy]$ ]] && continue
        fi
        
        # [2/15] Server IP
        echo -en "${YELLOW}[2/15] Server IP (kharej e.g: 45.76.123.89) : ${NC}"
        read -r server_ip
        [ -z "$server_ip" ] && { print_error "Server IP required"; continue; }
        validate_ip "$server_ip" || { print_error "Invalid IP format"; continue; }
        echo -e "[2/15] Server IP : ${CYAN}$server_ip${NC}"
        
        # [3/15] Server Port
        echo -en "${YELLOW}[3/15] Server Port (default: $DEFAULT_LISTEN_PORT) : ${NC}"
        read -r server_port
        server_port="${server_port:-$DEFAULT_LISTEN_PORT}"
        validate_port "$server_port" || { print_error "Invalid port"; continue; }
        echo -e "[3/15] Server Port : ${CYAN}$server_port${NC}"
        
        # [4/15] Secret Key
        echo -en "${YELLOW}[4/15] Secret Key (from server) : ${NC}"
        read -r secret_key
        [ -z "$secret_key" ] && { print_error "Secret key required"; continue; }
        echo -e "[4/15] Secret Key : ${GREEN}$secret_key${NC}"
        
        # [5/15] KCP Mode
        echo -e "\n${CYAN}KCP Mode Selection${NC}"
        echo -e "────────────────────────────────────────────────────────────────"
        for mode_key in 0 1 2 3 4; do
            IFS=':' read -r name desc <<< "${KCP_MODES[$mode_key]}"
            echo " [${mode_key}] ${name} - ${desc}"
        done
        echo ""

        local mode_choice
        read -p "[5/15] Choose KCP mode [0-4] (default 1): " mode_choice
        mode_choice="${mode_choice:-1}"

        local mode_name
        local kcp_fragment=""

        case $mode_choice in
            0) mode_name="normal" ;;
            1) mode_name="fast" ;;
            2) mode_name="fast2" ;;
            3) mode_name="fast3" ;;
            4) 
                mode_name="manual"
                echo -e "\n${YELLOW}Manual KCP Advanced Parameters${NC}"
                echo -e "────────────────────────────────────────────────────────────────"
                kcp_fragment=$(get_manual_kcp_settings)
                ;;
            *) mode_name="fast" ;;
        esac
        echo -e "[5/15] KCP Mode : ${CYAN}$mode_name${NC}"
        
        # [6/15] Connections
        echo -en "${YELLOW}[6/15] Connections [1-32, 0=skip] (default $DEFAULT_CONNECTIONS): ${NC}"
        read -r conn_input
        local conn=""
        if [ -z "$conn_input" ]; then
            conn="$DEFAULT_CONNECTIONS"
            echo -e "[6/15] Connections : ${CYAN}$DEFAULT_CONNECTIONS (default)${NC}"
        elif [ "$conn_input" = "0" ]; then
            conn=""
            echo -e "[6/15] Connections : ${CYAN}- (skipped)${NC}"
        elif [[ "$conn_input" =~ ^[1-9][0-9]?$ ]] && [ "$conn_input" -ge 1 ] && [ "$conn_input" -le 32 ]; then
            conn="$conn_input"
            echo -e "[6/15] Connections : ${CYAN}$conn_input${NC}"
        else
            conn="$DEFAULT_CONNECTIONS"
            echo -e "${YELLOW}Invalid, using default $DEFAULT_CONNECTIONS${NC}"
            echo -e "[6/15] Connections : ${CYAN}$DEFAULT_CONNECTIONS (corrected)${NC}"
        fi
        
        # [7/15] MTU
        echo -en "${YELLOW}[7/15] MTU [100-9000, 0=skip] (default $DEFAULT_MTU): ${NC}"
        read -r mtu_input
        local mtu=""
        if [ -z "$mtu_input" ]; then
            mtu="$DEFAULT_MTU"
            echo -e "[7/15] MTU : ${CYAN}$DEFAULT_MTU (default)${NC}"
        elif [ "$mtu_input" = "0" ]; then
            mtu=""
            echo -e "[7/15] MTU : ${CYAN}- (skipped)${NC}"
        elif [[ "$mtu_input" =~ ^[0-9]+$ ]] && [ "$mtu_input" -ge 100 ] && [ "$mtu_input" -le 9000 ]; then
            mtu="$mtu_input"
            echo -e "[7/15] MTU : ${CYAN}$mtu_input${NC}"
        else
            mtu="$DEFAULT_MTU"
            echo -e "${YELLOW}Invalid, using default $DEFAULT_MTU${NC}"
            echo -e "[7/15] MTU : ${CYAN}$DEFAULT_MTU (corrected)${NC}"
        fi
        
        # [8/15] Encryption
        echo -e "\n${CYAN}Encryption Selection${NC}"
        echo -e "────────────────────────────────────────────────────────────────"
        for enc_key in 1 2 3 4 5 6 7; do
            IFS=':' read -r enc_name enc_desc <<< "${ENCRYPTION_OPTIONS[$enc_key]}"
            echo " [${enc_key}] ${enc_name} - ${enc_desc}"
        done
        echo ""
        
        local enc_choice
        read -p "[8/15] Choose encryption [1-7] (default 1): " enc_choice
        enc_choice="${enc_choice:-1}"
        
        local block
        IFS=':' read -r block _ <<< "${ENCRYPTION_OPTIONS[$enc_choice]}"
        block="${block:-aes-128-gcm}"
        echo -e "[8/15] Encryption : ${CYAN}$block${NC}"
        
        # [9/15] pcap sockbuf
        echo -en "${YELLOW}[9/15] pcap sockbuf [default $DEFAULT_PCAP_SOCKBUF_CLIENT, 0=skip]: ${NC}"
        read -r pcap_input
        local pcap_sockbuf=""
        if [ -z "$pcap_input" ]; then
            pcap_sockbuf="$DEFAULT_PCAP_SOCKBUF_CLIENT"
            echo -e "[9/15] pcap sockbuf : ${CYAN}$DEFAULT_PCAP_SOCKBUF_CLIENT (default)${NC}"
        elif [ "$pcap_input" = "0" ]; then
            pcap_sockbuf=""
            echo -e "[9/15] pcap sockbuf : ${CYAN}- (skipped)${NC}"
        else
            pcap_sockbuf="$pcap_input"
            echo -e "[9/15] pcap sockbuf : ${CYAN}$pcap_input${NC}"
        fi
        
        # [10/15] transport tcpbuf
        echo -en "${YELLOW}[10/15] transport tcpbuf [default $DEFAULT_TRANSPORT_TCPBUF, 0=skip]: ${NC}"
        read -r tcpbuf_input
        local transport_tcpbuf=""
        if [ -z "$tcpbuf_input" ]; then
            transport_tcpbuf="$DEFAULT_TRANSPORT_TCPBUF"
            echo -e "[10/15] transport tcpbuf : ${CYAN}$DEFAULT_TRANSPORT_TCPBUF (default)${NC}"
        elif [ "$tcpbuf_input" = "0" ]; then
            transport_tcpbuf=""
            echo -e "[10/15] transport tcpbuf : ${CYAN}- (skipped)${NC}"
        else
            transport_tcpbuf="$tcpbuf_input"
            echo -e "[10/15] transport tcpbuf : ${CYAN}$tcpbuf_input${NC}"
        fi
        
        # [11/15] transport udpbuf
        echo -en "${YELLOW}[11/15] transport udpbuf [default $DEFAULT_TRANSPORT_UDPBUF, 0=skip]: ${NC}"
        read -r udpbuf_input
        local transport_udpbuf=""
        if [ -z "$udpbuf_input" ]; then
            transport_udpbuf="$DEFAULT_TRANSPORT_UDPBUF"
            echo -e "[11/15] transport udpbuf : ${CYAN}$DEFAULT_TRANSPORT_UDPBUF (default)${NC}"
        elif [ "$udpbuf_input" = "0" ]; then
            transport_udpbuf=""
            echo -e "[11/15] transport udpbuf : ${CYAN}- (skipped)${NC}"
        else
            transport_udpbuf="$udpbuf_input"
            echo -e "[11/15] transport udpbuf : ${CYAN}$udpbuf_input${NC}"
        fi
        
        # [12/15] Traffic Type
        echo -e "\n${CYAN}Traffic Type Selection${NC}"
        echo -e "────────────────────────────────────────────────────────────────"
        echo -e " ${GREEN}[1]${NC} Port Forwarding - Forward specific ports"
        echo -e " ${GREEN}[2]${NC} SOCKS5 Proxy - Create a SOCKS5 proxy"
        echo ""
        
        local traffic_type
        read -p "[12/15] Choose traffic type [1-2] (default 1): " traffic_type
        traffic_type="${traffic_type:-1}"
        
        local forward_entries=()
        local socks5_entries=()
        local display_ports=""
        local SOCKS5_PORT=""
        local SOCKS5_USER=""
        local SOCKS5_PASS=""
        
        case $traffic_type in
            1)
                echo -e "\n${CYAN}Port Forwarding Configuration${NC}"
                echo -e "────────────────────────────────────────────────────────────────"
                
                echo -en "${YELLOW}[13/15] Forward Ports (comma separated) [default $DEFAULT_V2RAY_PORTS]: ${NC}"
                read -r forward_ports
                forward_ports=$(clean_port_list "${forward_ports:-$DEFAULT_V2RAY_PORTS}")
                [ -z "$forward_ports" ] && { print_error "No valid ports"; continue; }
                echo -e "[13/15] Forward Ports : ${CYAN}$forward_ports${NC}"
                
                echo -e "\n${CYAN}Protocol Selection${NC}"
                echo -e "────────────────────────────────────────────────────────────────"
                echo " [1] tcp - TCP only (default)"
                echo " [2] udp - UDP only"
                echo " [3] tcp/udp - Both"
                echo ""
                
                IFS=',' read -ra PORTS <<< "$forward_ports"
                for p in "${PORTS[@]}"; do
                    p=$(echo "$p" | tr -d '[:space:]')
                    echo -en "${YELLOW}Port $p → protocol [1-3] : ${NC}"
                    read -r proto_choice
                    proto_choice="${proto_choice:-1}"
                    
                    case $proto_choice in
                        1)
                            forward_entries+=("  - listen: \"0.0.0.0:$p\"\n    target: \"127.0.0.1:$p\"\n    protocol: \"tcp\"")
                            display_ports+=" $p (TCP)"
                            configure_iptables "$p" "tcp"
                            ;;
                        2)
                            forward_entries+=("  - listen: \"0.0.0.0:$p\"\n    target: \"127.0.0.1:$p\"\n    protocol: \"udp\"")
                            display_ports+=" $p (UDP)"
                            configure_iptables "$p" "udp"
                            ;;
                        3)
                            forward_entries+=("  - listen: \"0.0.0.0:$p\"\n    target: \"127.0.0.1:$p\"\n    protocol: \"tcp\"")
                            forward_entries+=("  - listen: \"0.0.0.0:$p\"\n    target: \"127.0.0.1:$p\"\n    protocol: \"udp\"")
                            display_ports+=" $p (TCP+UDP)"
                            configure_iptables "$p" "both"
                            ;;
                        *)
                            forward_entries+=("  - listen: \"0.0.0.0:$p\"\n    target: \"127.0.0.1:$p\"\n    protocol: \"tcp\"")
                            display_ports+=" $p (TCP)"
                            configure_iptables "$p" "tcp"
                            ;;
                    esac
                done
                echo -e "[13/15] Protocol(s) : ${CYAN}${display_ports# }${NC}"
                ;;
                
            2)
                echo -e "\n${CYAN}SOCKS5 Proxy Configuration${NC}"
                echo -e "────────────────────────────────────────────────────────────────"
                
                echo -en "${YELLOW}[13/15] SOCKS5 Proxy Port (default $DEFAULT_SOCKS5_PORT): ${NC}"
                read -r socks_port
                socks_port="${socks_port:-$DEFAULT_SOCKS5_PORT}"
                validate_port "$socks_port" || { print_error "Invalid port"; continue; }
                echo -e "[13/15] SOCKS5 Port : ${CYAN}$socks_port${NC}"
                
                check_port_conflict "$socks_port" || { pause "Press Enter to retry..."; continue; }
                configure_iptables "$socks_port" "tcp"
                
                echo -e "\n${CYAN}SOCKS5 Authentication (Optional)${NC}"
                echo -e "────────────────────────────────────────────────────────────────"
                echo -e "${YELLOW}Leave empty for no authentication${NC}"
                
                echo -en "${YELLOW}SOCKS5 Username: ${NC}"
                read -r socks_user
                
                if [ -n "$socks_user" ]; then
                    echo -en "${YELLOW}SOCKS5 Password: ${NC}"
                    read -r socks_pass
                    
                    if [ -z "$socks_pass" ]; then
                        print_error "Password required if username is set"
                        continue
                    fi
                    
                    echo -e "Authentication: ${GREEN}Enabled${NC}"
                    SOCKS5_USER="$socks_user"
                    SOCKS5_PASS="$socks_pass"
                    socks5_entries+=("  - listen: \"127.0.0.1:$socks_port\"\n    username: \"$socks_user\"\n    password: \"$socks_pass\"")
                else
                    echo -e "Authentication: ${YELLOW}Disabled${NC}"
                    socks5_entries+=("  - listen: \"127.0.0.1:$socks_port\"")
                fi
                
                SOCKS5_PORT="$socks_port"
                ;;
                
            *)
                print_error "Invalid choice"
                continue
                ;;
        esac
        
        # Apply configuration
        echo -e "\n${CYAN}Applying Configuration${NC}"
        echo -e "────────────────────────────────────────────────────────────────"
        
        if [ ! -f "$BIN_DIR/paqet" ]; then
            install_paqet || continue
        fi
        
        mkdir -p "$CONFIG_DIR"
        
        # Build client config with proper indentation
        {
            echo "# Paqet Client Configuration"
            echo "role: \"client\""
            echo "log:"
            echo "  level: \"info\""
            
            if [ ${#forward_entries[@]} -gt 0 ]; then
                echo "forward:"
                for entry in "${forward_entries[@]}"; do
                    echo -e "$entry"
                done
            fi
            
            if [ ${#socks5_entries[@]} -gt 0 ]; then
                echo "socks5:"
                for entry in "${socks5_entries[@]}"; do
                    echo -e "$entry"
                done
            fi
            
            echo "network:"
            echo "  interface: \"$NETWORK_INTERFACE\""
            echo "  ipv4:"
            echo "    addr: \"$LOCAL_IP:0\""
            echo "    router_mac: \"$GATEWAY_MAC\""
            echo "  tcp:"
            echo "    local_flag: [\"PA\"]"
            echo "    remote_flag: [\"PA\"]"
            
            if [[ -n "$pcap_sockbuf" ]]; then
                echo "  pcap:"
                echo "    sockbuf: $pcap_sockbuf"
            fi
            
            echo "server:"
            echo "  addr: \"$server_ip:$server_port\""
            echo "transport:"
            echo "  protocol: \"kcp\""
            
            [[ -n "$conn" ]] && echo "  conn: $conn"
            [[ -n "$transport_tcpbuf" ]] && echo "  tcpbuf: $transport_tcpbuf"
            [[ -n "$transport_udpbuf" ]] && echo "  udpbuf: $transport_udpbuf"
            
            echo "  kcp:"
            echo "    key: \"$secret_key\""
            
            if [ "$mode_name" = "manual" ] && [ -n "$kcp_fragment" ]; then
                echo "    mode: \"manual\""
                echo "    block: \"$block\""
                [[ -n "$mtu" ]] && echo "    mtu: $mtu"
                while IFS= read -r line; do
                    if [[ -n "$line" ]] && ! echo "$line" | grep -q "mode:"; then
                        echo "    $line"
                    fi
                done <<< "$kcp_fragment"
            else
                echo "    mode: \"$mode_name\""
                echo "    block: \"$block\""
                [[ -n "$mtu" ]] && echo "    mtu: $mtu"
            fi
        } > "$CONFIG_DIR/${config_name}.yaml"
        
        echo -e "[+] Configuration saved : ${CYAN}$CONFIG_DIR/${config_name}.yaml${NC}"
        
        create_systemd_service "$config_name"
        local svc="paqet-${config_name}"
        systemctl enable "$svc" --now >/dev/null 2>&1
        
        if systemctl is-active --quiet "$svc"; then
            print_success "Client started successfully"
            add_auto_restart_cronjob "$svc" "$DEFAULT_AUTO_RESTART_INTERVAL" >/dev/null 2>&1
            
            echo -e "\n${GREEN}╔══════════════════════════════════════════════════════════════╗${NC}"
            echo -e "${GREEN}║ Client Ready                                                   ║${NC}"
            echo -e "${GREEN}╚══════════════════════════════════════════════════════════════╝${NC}\n"
            
            echo -e "${YELLOW}Client Information${NC}"
            echo -e "┌──────────────────────────────────────────────────────────────┐"
            printf "│ %-16s : %-42s │\n" "This Server" "$public_ip"
            printf "│ %-16s : %-42s │\n" "Remote Server" "$server_ip:$server_port"
            
            if [ "$traffic_type" = "1" ] && [ ${#forward_entries[@]} -gt 0 ]; then
                printf "│ %-16s : %-42s │\n" "Forward Ports" "${display_ports# }"
            elif [ "$traffic_type" = "2" ] && [ ${#socks5_entries[@]} -gt 0 ]; then
                printf "│ %-16s : %-42s │\n" "SOCKS5 Port" "$SOCKS5_PORT"
                if [ -n "$SOCKS5_USER" ]; then
                    printf "│ %-16s : %-42s │\n" "SOCKS5 User" "$SOCKS5_USER"
                    printf "│ %-16s : %-42s │\n" "SOCKS5 Pass" "********"
                else
                    printf "│ %-16s : %-42s │\n" "Authentication" "None"
                fi
            fi
            
            printf "│ %-16s : %-42s │\n" "Connections" "${conn:-1}"
            printf "│ %-16s : %-42s │\n" "Auto Restart" "Every ${DEFAULT_AUTO_RESTART_INTERVAL}"
            echo -e "└──────────────────────────────────────────────────────────────┘\n"
            
            echo -e "${YELLOW}KCP Configuration${NC}"
            echo -e "┌──────────────────────────────────────────────────────────────┐"
            printf "│ %-14s : %-44s │\n" "Mode" "$mode_name"
            printf "│ %-14s : %-44s │\n" "Encryption" "$block"
            printf "│ %-14s : %-44s │\n" "MTU" "${mtu:-1350}"
            echo -e "└──────────────────────────────────────────────────────────────┘\n"
            
            echo ""
            echo -e "${GREEN}✅ Client setup completed successfully!${NC}"
            echo -e "${CYAN}Options:${NC}"
            echo -e " 1. Press ${GREEN}Enter${NC} to go to service management for $config_name"
            echo -e " 2. Type ${YELLOW}menu${NC} to return to main menu"
            echo -e " 3. Type ${YELLOW}exit${NC} to exit"
            echo ""
            
            read -p "Your choice [Enter/menu/exit]: " post_choice
            
            case "${post_choice,,}" in
                ""|enter)
                    echo -e "${GREEN}➡️ Taking you to service management for $config_name...${NC}"
                    sleep 1
                    manage_single_service "$svc" "$config_name"
                    ;;
                menu)
                    echo -e "${CYAN}Returning to main menu...${NC}"
                    sleep 1
                    return 0
                    ;;
                exit)
                    echo -e "${GREEN}Goodbye!${NC}"
                    exit 0
                    ;;
                *)
                    echo -e "${YELLOW}Invalid choice. Returning to main menu...${NC}"
                    sleep 2
                    return 0
                    ;;
            esac
        else
            print_error "Client failed to start"
            systemctl status "$svc" --no-pager -l
            pause
        fi
        return 0
    done
}

# ================================================
# TEST FUNCTIONS
# ================================================

# Test internet connectivity
test_internet_connectivity() {
    echo -e "\n${YELLOW}Internet Connectivity Test${NC}"
    echo -e "────────────────────────────────────────────────────────────────"
    
    print_step "Testing internet connectivity...\n"
    
    local test_hosts=("8.8.8.8" "1.1.1.1" "208.67.222.222")
    local success_count=0
    local total_tests=${#test_hosts[@]}
    
    for host in "${test_hosts[@]}"; do
        echo -n " Testing connection to $host: "
        if ping -c 2 -W 1 "$host" &>/dev/null; then
            echo -e "${GREEN}✓ CONNECTED${NC}"
            ((success_count++))
        else
            echo -e "${RED}✗ FAILED${NC}"
        fi
    done
    
    echo -e "\n${CYAN}Test Results:${NC}"
    if [ "$success_count" -eq "$total_tests" ]; then
        print_success "✅ Internet connectivity: EXCELLENT (${success_count}/${total_tests})"
    elif [ "$success_count" -ge $((total_tests / 2)) ]; then
        print_warning "⚠️ Internet connectivity: PARTIAL (${success_count}/${total_tests})"
    else
        print_error "❌ Internet connectivity: POOR (${success_count}/${total_tests})"
    fi
    
    if [ "$success_count" -gt 0 ]; then
        echo -e "\n${YELLOW}Speed Test${NC}"
        echo -e "────────────────────────────────────────────────────────────────"
        local speed_test
        speed_test=$(timeout 10 curl -o /dev/null -w "%{speed_download}" --max-filesize 10485760 https://speedtest.ftp.otenet.gr/files/test10Mb.db 2>/dev/null || echo "0")
        
        if [ "$speed_test" != "0" ] && [ -n "$speed_test" ]; then
            if command -v bc &>/dev/null; then
                local speed_mbps
                speed_mbps=$(echo "scale=2; $speed_test * 8 / 1000000" | bc 2>/dev/null || echo "0")
                
                if (( $(echo "$speed_mbps > 10" | bc -l 2>/dev/null) )); then
                    echo -e " ${GREEN}✅ Download speed: ${speed_mbps} Mbps${NC}"
                elif (( $(echo "$speed_mbps > 1" | bc -l 2>/dev/null) )); then
                    echo -e " ${YELLOW}⚠️ Download speed: ${speed_mbps} Mbps${NC}"
                else
                    echo -e " ${RED}❌ Download speed: ${speed_mbps} Mbps${NC}"
                fi
            else
                local speed_mbps_int=$(( (${speed_test%.*} * 8) / 1000000 ))
                if [ "$speed_mbps_int" -gt 10 ]; then
                    echo -e " ${GREEN}✅ Download speed: ~${speed_mbps_int} Mbps${NC}"
                elif [ "$speed_mbps_int" -gt 1 ]; then
                    echo -e " ${YELLOW}⚠️ Download speed: ~${speed_mbps_int} Mbps${NC}"
                else
                    echo -e " ${RED}❌ Download speed: ~${speed_mbps_int} Mbps${NC}"
                fi
            fi
        else
            echo -e " ${YELLOW}⚠️ Speed test failed or timed out${NC}"
        fi
    fi
}

# Test DNS resolution
test_dns_resolution() {
    echo -e "\n${YELLOW}DNS Resolution Test${NC}"
    echo -e "────────────────────────────────────────────────────────────────"
    
    print_step "Testing DNS resolution...\n"
    
    echo -e "${CYAN}Testing domain resolution:${NC}\n"
    
    local resolved_count=0
    local total_domains=${#TEST_DOMAINS[@]}
    
    for domain in "${TEST_DOMAINS[@]}"; do
        echo -n " $domain: "
        if timeout 3 dig +short "$domain" &>/dev/null; then
            echo -e "${GREEN}✓ RESOLVED${NC}"
            ((resolved_count++))
        else
            echo -e "${RED}✗ FAILED${NC}"
        fi
    done
    
    echo -e "\n${CYAN}Testing DNS servers:${NC}\n"
    
    for dns in "${DNS_SERVERS[@]}"; do
        echo -n " $dns: "
        if [ "$dns" = "system" ]; then
            if timeout 3 nslookup google.com &>/dev/null; then
                echo -e "${GREEN}✓ WORKING${NC}"
            else
                echo -e "${RED}✗ FAILED${NC}"
            fi
        else
            if timeout 3 dig +short google.com @"$dns" &>/dev/null; then
                echo -e "${GREEN}✓ WORKING${NC}"
            else
                echo -e "${RED}✗ FAILED${NC}"
            fi
        fi
    done
    
    echo -e "\n${CYAN}Summary:${NC}"
    if [ "$resolved_count" -eq "$total_domains" ]; then
        print_success "✅ DNS resolution: PERFECT (${resolved_count}/${total_domains})"
    elif [ "$resolved_count" -ge $((total_domains / 2)) ]; then
        print_warning "⚠️ DNS resolution: PARTIAL (${resolved_count}/${total_domains})"
    else
        print_error "❌ DNS resolution: POOR (${resolved_count}/${total_domains})"
    fi
}

# Extract ping stats
extract_ping_stats() {
    local ping_output="$1"
    local rtt_line
    rtt_line=$(echo "$ping_output" | grep "rtt min/avg/max/mdev")
    
    if [ -n "$rtt_line" ]; then
        local stats
        stats=$(echo "$rtt_line" | sed 's/.*= //' | sed 's/ ms//')
        echo "$stats" | tr '/' ' '
    else
        echo "0 0 0 0"
    fi
}

# Test Paqet tunnel
test_paqet_tunnel() {
    clear
    echo -e "\n${YELLOW}Test Paqet Tunnel Connection${NC}"
    echo -e "────────────────────────────────────────────────────────────────"
    
    echo -e "${CYAN}This test will check if you can establish a Paqet tunnel between two servers.${NC}\n"
    
    echo -en "${YELLOW}Remote Server IP Address: ${NC}"
    read -r remote_ip
    
    [ -z "$remote_ip" ] && { print_error "IP address required"; return; }
    validate_ip "$remote_ip" || { print_error "Invalid IP address format"; return; }
    
    echo -e "\n${YELLOW}Starting comprehensive Paqet tunnel test to $remote_ip...${NC}\n"
    
    # 1. Basic connectivity
    print_step "1. Testing basic ICMP connectivity..."
    
    local ping_output
    ping_output=$(ping -c 5 -W 2 "$remote_ip" 2>&1)
    local avg_ping=""
    local packet_loss="100"
    
    if [ $? -eq 0 ] || echo "$ping_output" | grep -q "transmitted"; then
        packet_loss=$(echo "$ping_output" | grep -o "[0-9]*% packet loss" | grep -o "[0-9]*" || echo "0")
        
        if echo "$ping_output" | grep -q "rtt min/avg/max/mdev"; then
            avg_ping=$(echo "$ping_output" | grep "rtt min/avg/max/mdev" | awk -F'/' '{print $5}')
        fi
        
        print_success "✅ Basic ICMP connectivity: SUCCESS"
        echo -e " ${CYAN}Details:${NC} Avg RTT: ${avg_ping:-N/A} ms, Packet loss: ${packet_loss}%"
    else
        print_warning "⚠️ Basic ICMP: FAILED (may be blocked)"
    fi
    
    # 2. Test common ports
    echo -e "\n${YELLOW}2. Testing common ports...${NC}"
    local paqet_ports_found=0
    
    for port in "${COMMON_PORTS[@]}"; do
        echo -n " Port $port: "
        if timeout 3 bash -c "</dev/tcp/$remote_ip/$port" 2>/dev/null; then
            echo -e "${GREEN}OPEN${NC}"
            ((paqet_ports_found++))
        else
            echo -e "${CYAN}Closed/Filtered${NC}"
        fi
        sleep 0.1
    done
    
    if [ $paqet_ports_found -eq 0 ]; then
        print_warning "⚠️ No common ports found open"
    else
        print_success "✅ Found $paqet_ports_found open port(s)"
    fi
    
    # 3. MTU testing
    echo -e "\n${YELLOW}3. MTU and packet loss analysis...${NC}"
    echo -e "${CYAN}Testing different MTU sizes (10 packets each):${NC}\n"
    
    local best_mtu=""
    local best_loss=100
    local best_ping=9999
    
    for mtu in "${MTU_TESTS[@]}"; do
        local payload_size=$((mtu - 28))
        [ $payload_size -lt 0 ] && continue
        
        echo -n " MTU $mtu: "
        local ping_output
        ping_output=$(ping -c 10 -W 1 -M do -s "$payload_size" "$remote_ip" 2>&1)
        
        if echo "$ping_output" | grep -q "transmitted"; then
            local sent received loss_percent
            sent=$(echo "$ping_output" | grep transmitted | awk '{print $1}')
            received=$(echo "$ping_output" | grep transmitted | awk '{print $4}')
            loss_percent=$(( (sent - received) * 100 / sent ))
            
            local stats
            stats=$(extract_ping_stats "$ping_output")
            local min_avg_max_mdev
            read -r min_avg_max_mdev <<< "$stats"
            
            if [ "$received" -eq "$sent" ]; then
                echo -e "${GREEN}PERFECT${NC} - 0% loss"
                if [ -z "$best_mtu" ] || [ "$loss_percent" -lt "$best_loss" ] || 
                   { [ "$loss_percent" -eq "$best_loss" ] && [ "$avg_ping" -lt "$best_ping" ]; }; then
                    best_mtu="$mtu"
                    best_loss="$loss_percent"
                    best_ping="$avg_ping"
                fi
            elif [ "$loss_percent" -le 10 ]; then
                echo -e "${GREEN}GOOD${NC} - ${loss_percent}% loss"
                if [ "$loss_percent" -lt "$best_loss" ]; then
                    best_mtu="$mtu"
                    best_loss="$loss_percent"
                    best_ping="$avg_ping"
                fi
            elif [ "$loss_percent" -le 30 ]; then
                echo -e "${YELLOW}FAIR${NC} - ${loss_percent}% loss"
            else
                echo -e "${RED}POOR${NC} - ${loss_percent}% loss"
            fi
        else
            echo -e "${RED}FAILED${NC}"
        fi
    done
    
    # 4. Summary
    echo -e "\n${GREEN}╔══════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${GREEN}║ Test Summary & Recommendations                                 ║${NC}"
    echo -e "${GREEN}╚══════════════════════════════════════════════════════════════╝${NC}\n"
    
    echo -e "${CYAN}Connection Quality:${NC}"
    if [ -n "$avg_ping" ]; then
        if compare_floats "$avg_ping" "50" "lt"; then
            echo -e " ${GREEN}✅ Latency: EXCELLENT (< 50ms)${NC}"
        elif compare_floats "$avg_ping" "150" "lt"; then
            echo -e " ${GREEN}✅ Latency: GOOD (< 150ms)${NC}"
        elif compare_floats "$avg_ping" "300" "lt"; then
            echo -e " ${YELLOW}⚠️ Latency: FAIR (< 300ms)${NC}"
        else
            echo -e " ${YELLOW}⚠️ Latency: HIGH (> 300ms)${NC}"
        fi
    fi
    
    if [ -n "$packet_loss" ]; then
        if [ "$packet_loss" -eq 0 ]; then
            echo -e " ${GREEN}✅ Packet Loss: EXCELLENT (0%)${NC}"
        elif [ "$packet_loss" -le 5 ]; then
            echo -e " ${GREEN}✅ Packet Loss: GOOD (≤ 5%)${NC}"
        elif [ "$packet_loss" -le 15 ]; then
            echo -e " ${YELLOW}⚠️ Packet Loss: FAIR (≤ 15%)${NC}"
        else
            echo -e " ${RED}❌ Packet Loss: HIGH (> 15%)${NC}"
        fi
    fi
    
    echo -e "\n${CYAN}MTU Recommendations:${NC}"
    if [ -n "$best_mtu" ]; then
        if [ "$best_loss" -eq 0 ]; then
            echo -e " ${GREEN}✅ Best MTU: $best_mtu (0% loss)${NC}"
        else
            echo -e " ${YELLOW}⚠️ Best MTU: $best_mtu (${best_loss}% loss)${NC}"
        fi
        
        if [ "$best_mtu" -ge 1400 ]; then
            echo -e " ${GREEN}• Primary: 1400 (optimal)${NC}"
            echo -e " ${GREEN}• Secondary: 1350 (balanced)${NC}"
            echo -e " ${CYAN}• Fallback: 1300 (stable)${NC}"
        elif [ "$best_mtu" -ge 1300 ]; then
            echo -e " ${GREEN}• Primary: 1350 (balanced)${NC}"
            echo -e " ${GREEN}• Secondary: 1300 (stable)${NC}"
            echo -e " ${CYAN}• Fallback: 1200 (reliable)${NC}"
        else
            echo -e " ${YELLOW}• Primary: 1200 (reliable)${NC}"
            echo -e " ${YELLOW}• Secondary: 1100 (ultra stable)${NC}"
            echo -e " ${CYAN}• Fallback: 1000 (guaranteed)${NC}"
        fi
    else
        echo -e " ${RED}❌ Could not determine optimal MTU${NC}"
        echo -e " ${CYAN}Recommendation: Use MTU 1200 as default${NC}"
    fi
}

# Test connection menu
test_connection() {
    clear
    show_banner
    echo -e "${GREEN}╔══════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${GREEN}║ Test Paqet Connection                                         ║${NC}"
    echo -e "${GREEN}╚══════════════════════════════════════════════════════════════╝${NC}\n"
    
    echo -e "${CYAN}Connection Test Options:${NC}"
    echo -e "────────────────────────────────────────────────────────────────"
    echo " 1. Test Paqet tunnel connection (server to server)"
    echo " 2. Test internet connectivity"
    echo " 3. Test DNS resolution"
    echo " 0. Back to Main Menu"
    echo ""
    
    while true; do
        read -p "Choose option [0-3]: " test_choice
        
        case $test_choice in
            1)
                test_paqet_tunnel
                pause
                return
                ;;
            2)
                test_internet_connectivity
                pause
                return
                ;;
            3)
                test_dns_resolution
                pause
                return
                ;;
            0)
                return
                ;;
            *)
                print_error "Invalid choice. Please enter 0-3."
                ;;
        esac
    done
}

# ================================================
# INSTALLATION FUNCTIONS
# ================================================

# Check dependencies
check_dependencies() {
    local missing_deps=()
    local os
    os=$(detect_os)
    
    local common_deps=("curl" "wget" "iptables" "lsof")
    
    case $os in
        ubuntu|debian)
            common_deps+=("libpcap-dev" "iproute2" "cron" "dig")
            ;;
        centos|rhel|fedora|rocky|almalinux)
            common_deps+=("libpcap-devel" "iproute" "cronie" "bind-utils")
            ;;
    esac
    
    for dep in "${common_deps[@]}"; do
        if ! command -v "$dep" &>/dev/null && 
           ! dpkg -l | grep -q "$dep" 2>/dev/null && 
           ! rpm -q "$dep" &>/dev/null 2>&1; then
            missing_deps+=("$dep")
        fi
    done
    
    if [ ${#missing_deps[@]} -eq 0 ]; then
        return 0
    else
        echo "${missing_deps[@]}"
        return 1
    fi
}

# Install dependencies
install_dependencies() {
    clear
    show_banner
    print_step "Installing dependencies..."
    
    local os
    os=$(detect_os)
    
    case $os in
        ubuntu|debian)
            apt update -qq >/dev/null 2>&1 || true
            apt install -y curl wget libpcap-dev iptables lsof iproute2 cron dnsutils >/dev/null 2>&1 || {
                print_warning "Some packages may have failed to install"
            }
            ;;
        centos|rhel|fedora|rocky|almalinux)
            yum install -y curl wget libpcap-devel iptables lsof iproute cronie bind-utils >/dev/null 2>&1 || {
                print_warning "Some packages may have failed to install"
            }
            ;;
        *)
            print_warning "Unknown OS. Please install manually: libpcap iptables curl cron dnsutils"
            ;;
    esac
    
    print_success "Dependencies installed"
    pause
    return
}

# Install Paqet binary
install_paqet() {
    clear
    show_banner
    print_step "Paqet Core Installation\n"
    
    local os
    os=$(detect_os)
    local arch
    arch=$(detect_arch) || return 1
    
    # Get current version if installed
    local current_version="Not installed"
    if [ -f "$BIN_DIR/paqet" ]; then
        current_version=$("$BIN_DIR/paqet" version 2>/dev/null | grep "^Version:" | head -1 | cut -d':' -f2 | xargs)
        [ -z "$current_version" ] && current_version="unknown"
    fi
    
    # Get latest version from GitHub
    local latest_version
    latest_version=$(get_latest_paqet_version)
    
    echo -e "${YELLOW}System Information:${NC}"
    echo -e " OS: ${CYAN}$os${NC}"
    echo -e " Arch: ${CYAN}$arch${NC}"
    echo -e " Current Version: ${CYAN}$current_version${NC}"
    echo -e " Latest Version: ${CYAN}$latest_version${NC}\n"
    mkdir -p "/root/paqet"
    local arch_name=""
    case $arch in
        amd64) arch_name="amd64" ;;
        arm64) arch_name="arm64" ;;
        armv7) arch_name="arm32" ;;
        386) arch_name="386" ;;
        *) arch_name="$arch" ;;
    esac
    
    local expected_file="paqet-linux-${arch_name}-${latest_version}.tar.gz"
    local download_url="https://github.com/${GITHUB_REPO}/releases/download/${latest_version}/${expected_file}"
    
    echo -e "${YELLOW}Download URL:${NC} ${CYAN}$download_url${NC}\n"
    
    echo -e "${GREEN}══════════════════════════════════════════════════════════════${NC}"
    echo -e "${GREEN} paqet core${NC}"
    echo -e "${GREEN}══════════════════════════════════════════════════════════════${NC}"
    echo -e "${YELLOW}Installation Options paqet core:${NC}"
    echo -e " 1) ${GREEN}Download/Update from GitHub (latest: $latest_version)${NC}"
    echo -e " 2) ${CYAN}Use local file from /root/paqet/${NC}"
    echo -e " 3) ${PURPLE}Download from custom URL${NC}"
    echo -e ""
    echo -e "${GREEN}══════════════════════════════════════════════════════════════${NC}"
    echo -e "${GREEN} paqet manager${NC}"
    echo -e "${GREEN}══════════════════════════════════════════════════════════════${NC}"
    echo -e "${YELLOW}Installation Options paqet manager:${NC}"
    echo -e " 4) ${BLUE}Install script${NC}"
    echo -e " 5) ${BLUE}Update script${NC}"
    echo -e " 6) ${BLUE}Switch version${NC}"
    echo -e " 7) ${RED}Uninstall script${NC}"
    echo -e ""
    echo -e " 0) ${YELLOW}↩️ Back to main menu${NC}\n"
    
    read -p "Choose option [0-7]: " install_choice
    
    case $install_choice in
        1)
            print_info "Downloading latest version ($latest_version) from GitHub for $os/$arch_name..."
            
            if ! curl -fsSL "$download_url" -o "/tmp/paqet.tar.gz" 2>/dev/null; then
                print_error "Download failed from GitHub"
                echo -e "\n${YELLOW}Please check:${NC}"
                echo -e " 1. Internet connection"
                echo -e " 2. GitHub repository access"
                echo -e " 3. The version $latest_version exists"
                echo -e "\n${YELLOW}You can also:${NC}"
                echo -e " - Try again later"
                echo -e " - Download manually from: $download_url"
                echo -e " - Save to: /root/paqet/$expected_file"
                echo -e " - Then use option 2 to install from local file"
                pause
                return 1
            else
                print_success "Downloaded version ${latest_version}"
                cp "/tmp/paqet.tar.gz" "/root/paqet/$expected_file" 2>/dev/null && \
                print_info "Saved copy to /root/paqet/$expected_file for future use"
            fi
            ;;
        2)
            local local_files=()
            if [ -d "/root/paqet" ]; then
                while IFS= read -r file; do
                    if [[ "$file" =~ paqet-linux-.*\.tar\.gz$ ]]; then
                        local_files+=("$file")
                    fi
                done < <(find "/root/paqet" -name "*.tar.gz" -type f 2>/dev/null | sort)
            fi
            
            if [ ${#local_files[@]} -eq 0 ]; then
                print_error "No valid paqet archives found in /root/paqet"
                echo -e "\n${YELLOW}Expected filename format:${NC} paqet-linux-{arch}-{version}.tar.gz"
                echo -e "${YELLOW}Example:${NC} paqet-linux-amd64-v1.0.0-alpha.16.tar.gz"
                pause
                return 1
            fi
            
            echo -e "\n${YELLOW}Found local paqet archives:${NC}\n"
            
            for i in "${!local_files[@]}"; do
                local filename
                filename=$(basename "${local_files[$i]}")
                local filesize
                filesize=$(du -h "${local_files[$i]}" | cut -f1)
                local file_arch=""
                if [[ "$filename" =~ linux-([^-]+)- ]]; then
                    file_arch="${BASH_REMATCH[1]}"
                fi
                
                if [ "$file_arch" = "$arch_name" ]; then
                    echo -e " $((i+1)). ${GREEN}$filename${NC} (${filesize}) - ${GREEN}✓ Compatible${NC}"
                else
                    echo -e " $((i+1)). ${YELLOW}$filename${NC} (${filesize}) - ${YELLOW}⚠️ Not compatible (need: $arch_name)${NC}"
                fi
            done
            
            echo ""
            read -p "Select file [1-${#local_files[@]}]: " file_choice
            
            if [[ "$file_choice" -ge 1 ]] && [[ "$file_choice" -le ${#local_files[@]} ]]; then
                local selected_file="${local_files[$((file_choice-1))]}"
                local selected_filename=$(basename "$selected_file")
                if [[ "$selected_filename" =~ linux-([^-]+)- ]]; then
                    local file_arch="${BASH_REMATCH[1]}"
                    if [ "$file_arch" != "$arch_name" ]; then
                        print_warning "This file is for architecture '$file_arch', but your system is '$arch_name'"
                        read -p "Continue anyway? (y/N): " force_install
                        if [[ ! "$force_install" =~ ^[Yy]$ ]]; then
                            continue
                        fi
                    fi
                fi
                
                print_success "Using: $selected_filename"
                cp "$selected_file" "/tmp/paqet.tar.gz"
            else
                print_error "Invalid selection"
                pause
                return 1
            fi
            ;;
        3)
            echo ""
            echo -en "${YELLOW}Enter custom URL: ${NC}"
            read -r custom_url
            
            if [ -z "$custom_url" ]; then
                print_error "URL cannot be empty"
                pause
                return 1
            fi
            
            print_info "Downloading from custom URL..."
            if ! curl -fsSL "$custom_url" -o "/tmp/paqet.tar.gz" 2>/dev/null; then
                print_error "Download failed"
                echo -e "\n${YELLOW}Please check:${NC}"
                echo -e " 1. URL is correct"
                echo -e " 2. Internet connection"
                pause
                return 1
            else
                print_success "Downloaded from custom URL"
            fi
            ;;
        4)
            install_manager_script
            return 0
            ;;
        5)
            update_manager_script
            return 0
            ;;
        6)
            switch_manager_version
            return 0
            ;;
        7)
            uninstall_manager_script
            return 0
            ;;
        0)
            return 0
            ;;
        *)
            print_error "Invalid choice"
            pause
            return 1
            ;;
    esac

    mkdir -p "$INSTALL_DIR"
    print_step "Extracting archive..."
    rm -rf "$INSTALL_DIR"/*    
    tar -xzf "/tmp/paqet.tar.gz" -C "$INSTALL_DIR" 2>/dev/null || {
        print_error "Failed to extract archive"
        echo -e "\n${YELLOW}Possible issues:${NC}"
        echo -e " 1. Corrupted download"
        echo -e " 2. Wrong file format"
        echo -e " 3. Incompatible archive"
        rm -f "/tmp/paqet.tar.gz"
        pause
        return 1
    }
    
    print_success "Archive extracted to $INSTALL_DIR"
    local binary_file=""
    local standard_binary="$INSTALL_DIR/paqet_linux_${arch_name}"
    if [ -f "$standard_binary" ]; then
        binary_file="$standard_binary"
    else
        binary_file=$(find "$INSTALL_DIR" -type f -name "*paqet*" -exec file {} \; | grep -i "executable" | cut -d: -f1 | head -1)
    fi

    if [ -z "$binary_file" ] || [ ! -f "$binary_file" ]; then
        for file in "$INSTALL_DIR"/*; do
            if [ -f "$file" ] && [ -x "$file" ]; then
                binary_file="$file"
                break
            fi
        done
    fi
    
    if [ -n "$binary_file" ] && [ -f "$binary_file" ]; then
        print_info "Found binary: $(basename "$binary_file")"
        rm -f "$BIN_DIR/paqet"
        cp "$binary_file" "$BIN_DIR/paqet"
        chmod +x "$BIN_DIR/paqet"
        
        print_success "Paqet installed to $BIN_DIR/paqet"
        
        local new_version
        new_version=$("$BIN_DIR/paqet" version 2>/dev/null | grep "^Version:" | head -1 | cut -d':' -f2 | xargs)
        if [ -n "$new_version" ]; then
            print_info "Installed version: ${CYAN}$new_version${NC}"
            
            if [ "$new_version" != "$latest_version" ]; then
                print_warning "Expected version $latest_version but got $new_version"
            fi
        else
            print_warning "Could not determine installed version"
        fi
    else
        print_error "Binary not found in archive"
        echo -e "\n${YELLOW}Archive contents:${NC}"
        ls -la "$INSTALL_DIR"
        local any_file=$(find "$INSTALL_DIR" -type f | head -1)
        if [ -n "$any_file" ]; then
            print_info "Trying to make file executable: $any_file"
            chmod +x "$any_file"
            if [ -x "$any_file" ] && file "$any_file" | grep -q "executable"; then
                cp "$any_file" "$BIN_DIR/paqet"
                print_success "Paqet installed using alternative method"
            fi
        else
            pause
            return 1
        fi
    fi
    
    # پاک کردن فایل موقت
    rm -f "/tmp/paqet.tar.gz"
    
    print_success "Paqet core installation completed!"
    pause
    return 0
}

# Install manager script
install_manager_script() {
    clear
    show_banner
    print_step "Installing Paqet Manager script...\n"
    
    local manager_url="https://raw.githubusercontent.com/${MANAGER_GITHUB_REPO}/main/paqet-manager.sh"
    
    print_info "Downloading from: $manager_url"
    
    if curl -fsSL "$manager_url" -o "$MANAGER_PATH" 2>/dev/null; then
        chmod +x "$MANAGER_PATH"
        print_success "✅ Paqet Manager installed to $MANAGER_PATH"
        echo -e "\n${GREEN}You can now run the manager using command:${NC}"
        echo -e " ${CYAN}paqet-manager${NC}"
        echo -e "\n${YELLOW}Note: You may need to log out and back in for the command to be available.${NC}"
    else
        print_error "Failed to download manager script"
        pause
        return 1
    fi
    
    pause
    return 0
}

# Update manager script
update_manager_script() {
    clear
    show_banner
    print_step "Updating Paqet Manager script...\n"
    
    if [ ! -f "$MANAGER_PATH" ]; then
        print_warning "Manager script not found at $MANAGER_PATH"
        read -p "Install it now? (y/N): " install_now
        if [[ "$install_now" =~ ^[Yy]$ ]]; then
            install_manager_script
        fi
        return
    fi
    
    mkdir -p "$BACKUP_DIR"
    local backup_path="${BACKUP_DIR}/paqet-manager.backup-$(date +%Y%m%d-%H%M%S)"
    cp "$MANAGER_PATH" "$backup_path"
    print_info "Backup created at $backup_path"
    
    local manager_url="https://raw.githubusercontent.com/${MANAGER_GITHUB_REPO}/main/paqet-manager.sh"
    
    print_info "Downloading latest version..."
    
    if curl -fsSL "$manager_url" -o "$MANAGER_PATH" 2>/dev/null; then
        chmod +x "$MANAGER_PATH"
        print_success "✅ Paqet Manager updated successfully!"
        echo -e "\n${GREEN}Manager updated to latest version${NC}"
        echo -e "${YELLOW}Backup saved at:${NC} $backup_path"
        
        local new_version
        new_version=$(grep "SCRIPT_VERSION=" "$MANAGER_PATH" | head -1 | cut -d'"' -f2)
        [ -n "$new_version" ] && echo -e "${CYAN}New version:${NC} $new_version"
    else
        print_error "Failed to download manager script"
        mv "$backup_path" "$MANAGER_PATH" 2>/dev/null
        pause
        return 1
    fi
    
    pause
    return 0
}

# Switch manager version
switch_manager_version() {
    clear
    show_banner
    print_step "Switch Paqet Manager Version\n"
    
    echo -e "${YELLOW}Available versions:${NC}"
    echo -e "────────────────────────────────────────────────────────────────"
    
    local sorted_versions=()
    while IFS= read -r line; do
        sorted_versions+=("$line")
    done < <(for v in "${!MANAGER_VERSIONS[@]}"; do echo "$v"; done | sort -rV)
    
    local i=1
    declare -A version_map
    
    local current_version=""
    [ -f "$MANAGER_PATH" ] && current_version=$(grep "SCRIPT_VERSION=" "$MANAGER_PATH" 2>/dev/null | head -1 | cut -d'"' -f2)
    
    for version in "${sorted_versions[@]}"; do
        if [ "$version" = "$current_version" ]; then
            printf " %2d. ${CYAN}%s${NC} ${GREEN}(current)${NC}\n" "$i" "$version"
        else
            printf " %2d. ${CYAN}%s${NC}\n" "$i" "$version"
        fi
        version_map[$i]="$version"
        ((i++))
    done
    
    echo -e "\n 0) ${YELLOW}↩️ Back${NC}\n"
    
    read -p "Select version [0-$((i-1))]: " version_choice
    
    [ "$version_choice" = "0" ] && return 0
    
    if ! [[ "$version_choice" =~ ^[0-9]+$ ]] || (( version_choice < 1 || version_choice >= i )); then
        print_error "Invalid selection"
        pause
        return 1
    fi
    
    local selected_version="${version_map[$version_choice]}"
    local selected_url="${MANAGER_VERSIONS[$selected_version]}"
    
    print_info "Switching to version $selected_version..."
    
    if [ -f "$MANAGER_PATH" ]; then
        mkdir -p "$BACKUP_DIR"
        local backup_path="${BACKUP_DIR}/paqet-manager.backup-$(date +%Y%m%d-%H%M%S)"
        cp "$MANAGER_PATH" "$backup_path"
        print_info "Backup created at $backup_path"
    fi
    
    if curl -fsSL "$selected_url" -o "$MANAGER_PATH" 2>/dev/null; then
        chmod +x "$MANAGER_PATH"
        print_success "✅ Switched to version $selected_version"
        echo -e "\n${GREEN}Manager version changed successfully!${NC}"
        echo -e "${YELLOW}Backup saved at:${NC} $backup_path"
    else
        print_error "Failed to download version $selected_version"
        pause
        return 1
    fi
    
    pause
    return 0
}

# Uninstall manager script
uninstall_manager_script() {
    clear
    show_banner
    print_step "Uninstall Paqet Manager\n"
    
    if [ ! -f "$MANAGER_PATH" ]; then
        print_info "Manager script not found at $MANAGER_PATH"
        pause
        return 0
    fi
    
    echo -e "${RED}WARNING: This will remove the Paqet Manager command.${NC}"
    echo -e "${YELLOW}The manager script will be deleted from:${NC} $MANAGER_PATH\n"
    
    read -p "Are you sure you want to uninstall? (y/N): " confirm
    
    if [[ ! "$confirm" =~ ^[Yy]$ ]]; then
        print_info "Uninstall cancelled"
        pause
        return 0
    fi
    
    mkdir -p "$BACKUP_DIR"
    local backup_path="${BACKUP_DIR}/paqet-manager.backup-$(date +%Y%m%d-%H%M%S)"
    cp "$MANAGER_PATH" "$backup_path"
    print_info "Backup created at $backup_path"
    
    rm -f "$MANAGER_PATH"
    
    if [ ! -f "$MANAGER_PATH" ]; then
        print_success "✅ Paqet Manager uninstalled successfully"
        echo -e "\n${YELLOW}Backup saved at:${NC} $backup_path"
        echo -e "${YELLOW}To restore, run:${NC} cp $backup_path $MANAGER_PATH"
    else
        print_error "Failed to uninstall"
    fi
    
    pause
    return 0
}

# ================================================
# KERNEL OPTIMIZATION FUNCTIONS
# ================================================

# Apply full kernel optimizations
apply_kernel_optimizations() {
    clear
    show_banner
    echo -e "${GREEN}╔══════════════════════════════════════════════════════════╗${NC}"
    echo -e "${GREEN}║ Apply Kernel Optimizations (Recommended)                 ║${NC}"
    echo -e "${GREEN}╚══════════════════════════════════════════════════════════╝${NC}\n"
    
    print_step "Applying full kernel optimizations..."
    
    # Check if running as root
    if [[ $EUID -ne 0 ]]; then
        print_error "This must be run as root"
        return 1
    fi
    
    # Create backup directory
    mkdir -p "$BACKUP_DIR"
    
    # Backup existing configs
    [ -f "$SYSCTL_FILE" ] && cp "$SYSCTL_FILE" "$BACKUP_SYSCTL" && print_info "Backed up $SYSCTL_FILE"
    [ -f "$LIMITS_FILE" ] && cp "$LIMITS_FILE" "$BACKUP_LIMITS" && print_info "Backed up $LIMITS_FILE"
    
    print_step "Creating sysctl configuration..."
    
    # Create sysctl config
    cat > "$SYSCTL_FILE" << 'EOF'
# Paqet Tunnel - Kernel Optimizations
# Network core settings
net.core.rmem_max = 268435456
net.core.wmem_max = 268435456
net.core.rmem_default = 16777216
net.core.wmem_default = 16777216
net.core.netdev_max_backlog = 250000
net.core.somaxconn = 65535
net.core.optmem_max = 25165824

# TCP settings
net.ipv4.tcp_rmem = 4096 87380 134217728
net.ipv4.tcp_wmem = 4096 65536 134217728
net.ipv4.tcp_congestion_control = bbr
net.core.default_qdisc = fq
net.ipv4.tcp_fastopen = 3
net.ipv4.tcp_slow_start_after_idle = 0
net.ipv4.tcp_tw_reuse = 1
net.ipv4.tcp_fin_timeout = 15
net.ipv4.tcp_max_syn_backlog = 65535
net.ipv4.tcp_max_tw_buckets = 1440000
net.ipv4.tcp_mtu_probing = 1
net.ipv4.tcp_sack = 1
net.ipv4.tcp_window_scaling = 1

# Connection tracking
net.netfilter.nf_conntrack_max = 2097152
net.netfilter.nf_conntrack_tcp_timeout_established = 86400
net.netfilter.nf_conntrack_udp_timeout = 60
net.netfilter.nf_conntrack_udp_timeout_stream = 180

# IP settings
net.ipv4.ip_forward = 1
net.ipv4.ip_local_port_range = 1024 65535
net.ipv4.conf.all.rp_filter = 1
net.ipv4.conf.default.rp_filter = 1
net.ipv4.conf.all.accept_source_route = 0
net.ipv4.conf.default.accept_source_route = 0

# File limits
fs.file-max = 4194304
fs.inotify.max_user_instances = 8192
fs.inotify.max_user_watches = 524288
EOF
    
    print_success "Sysctl configuration created at $SYSCTL_FILE"
    
    # Apply sysctl
    print_step "Applying sysctl settings..."
    if sysctl -p "$SYSCTL_FILE" >/dev/null 2>&1; then
        print_success "Sysctl settings applied successfully"
    else
        print_warning "Some sysctl settings could not be applied"
    fi
    
    # Check if BBR is available, fallback to cubic
    if ! sysctl net.ipv4.tcp_congestion_control 2>/dev/null | grep -q "bbr"; then
        print_warning "BBR congestion control not available in current kernel"
        print_step "Falling back to cubic..."
        sed -i 's/bbr/cubic/' "$SYSCTL_FILE"
        sysctl -w net.ipv4.tcp_congestion_control=cubic >/dev/null 2>&1
        print_info "Using cubic congestion control instead"
    fi
    
    # Create limits.conf
    print_step "Creating system limits configuration..."
    cat > "$LIMITS_FILE" << 'EOF'
# Paqet Tunnel - System Limits
*               soft    nofile          1048576
*               hard    nofile          1048576
root            soft    nofile          1048576
root            hard    nofile          1048576
*               soft    nproc           unlimited
*               hard    nproc           unlimited
root            soft    nproc           unlimited
root            hard    nproc           unlimited
EOF
    
    print_success "System limits configured at $LIMITS_FILE"
    
    # Apply limits (will take effect on new sessions)
    print_info "System limits will take effect for new sessions"
    
    echo -e "\n${GREEN}══════════════════════════════════════════════════════════════${NC}"
    echo -e "${GREEN}✅ Kernel optimizations applied successfully!${NC}"
    echo -e "${GREEN}══════════════════════════════════════════════════════════════${NC}\n"
    
    echo -e "${YELLOW}Backup files:${NC}"
    [ -f "$BACKUP_SYSCTL" ] && echo -e "  • $BACKUP_SYSCTL"
    [ -f "$BACKUP_LIMITS" ] && echo -e "  • $BACKUP_LIMITS"
    
    echo -e "\n${YELLOW}Applied settings:${NC}"
    echo -e "  • TCP Congestion Control: $(sysctl -n net.ipv4.tcp_congestion_control 2>/dev/null || echo 'N/A')"
    echo -e "  • Default QDisc: $(sysctl -n net.core.default_qdisc 2>/dev/null || echo 'N/A')"
    echo -e "  • Max File Descriptors: $(sysctl -n fs.file-max 2>/dev/null || echo 'N/A')"
    echo -e "  • IP Forwarding: $(sysctl -n net.ipv4.ip_forward 2>/dev/null || echo 'N/A')"
    
    echo -e "\n${CYAN}Note: Some changes may require a reboot to take full effect.${NC}"
    
    pause
}

# Remove kernel optimizations
remove_kernel_optimizations() {
    clear
    show_banner
    echo -e "${RED}╔══════════════════════════════════════════════════════════╗${NC}"
    echo -e "${RED}║ Remove Kernel Optimizations                               ║${NC}"
    echo -e "${RED}╚══════════════════════════════════════════════════════════╝${NC}\n"
    
    print_warning "This will remove all Paqet kernel optimizations and restore system defaults."
    echo ""
    
    read -p "Are you sure? (y/N): " confirm
    if [[ ! "$confirm" =~ ^[Yy]$ ]]; then
        print_info "Operation cancelled"
        pause
        return
    fi
    
    print_step "Removing kernel optimizations..."
    
    # Remove sysctl file
    if [ -f "$SYSCTL_FILE" ]; then
        rm -f "$SYSCTL_FILE"
        print_success "Removed $SYSCTL_FILE"
    else
        print_info "Sysctl file not found"
    fi
    
    # Remove limits file
    if [ -f "$LIMITS_FILE" ]; then
        rm -f "$LIMITS_FILE"
        print_success "Removed $LIMITS_FILE"
    else
        print_info "Limits file not found"
    fi
    
    # Reload system settings
    print_step "Reloading system settings..."
    sysctl --system >/dev/null 2>&1
    
    # Reset to system defaults
    sysctl -w net.ipv4.tcp_congestion_control=cubic >/dev/null 2>&1
    sysctl -w net.core.default_qdisc=pfifo_fast >/dev/null 2>&1
    
    print_success "System defaults restored"
    echo -e "\n${YELLOW}Note: A reboot is recommended for complete reset.${NC}"
    
    pause
}

# View current kernel status
view_kernel_status() {
    clear
    show_banner
    echo -e "${CYAN}╔══════════════════════════════════════════════════════════╗${NC}"
    echo -e "${CYAN}║ Kernel Optimization Status                                ║${NC}"
    echo -e "${CYAN}╚══════════════════════════════════════════════════════════╝${NC}\n"
    
    print_step "Current Kernel Optimization Status"
    
    echo -e "\n${YELLOW}TCP Congestion Control:${NC}"
    echo -e "  • Current: $(sysctl -n net.ipv4.tcp_congestion_control 2>/dev/null || echo 'N/A')"
    echo -e "  • Available: $(sysctl net.ipv4.tcp_available_congestion_control 2>/dev/null | cut -d'=' -f2 | xargs || echo 'N/A')"
    
    echo -e "\n${YELLOW}Buffer Sizes:${NC}"
    echo -e "  • net.core.rmem_max: $(sysctl -n net.core.rmem_max 2>/dev/null || echo 'N/A')"
    echo -e "  • net.core.wmem_max: $(sysctl -n net.core.wmem_max 2>/dev/null || echo 'N/A')"
    echo -e "  • net.ipv4.tcp_rmem: $(sysctl -n net.ipv4.tcp_rmem 2>/dev/null || echo 'N/A')"
    echo -e "  • net.ipv4.tcp_wmem: $(sysctl -n net.ipv4.tcp_wmem 2>/dev/null || echo 'N/A')"
    
    echo -e "\n${YELLOW}File Descriptors:${NC}"
    echo -e "  • Current session: $(ulimit -n)"
    echo -e "  • System max: $(sysctl -n fs.file-max 2>/dev/null || echo 'N/A')"
    
    echo -e "\n${YELLOW}Network Settings:${NC}"
    echo -e "  • IP Forwarding: $(sysctl -n net.ipv4.ip_forward 2>/dev/null || echo 'N/A')"
    echo -e "  • Default QDisc: $(sysctl -n net.core.default_qdisc 2>/dev/null || echo 'N/A')"
    echo -e "  • Local Port Range: $(sysctl -n net.ipv4.ip_local_port_range 2>/dev/null || echo 'N/A')"
    
    echo -e "\n${YELLOW}Configuration Files:${NC}"
    if [ -f "$SYSCTL_FILE" ]; then
        echo -e "  • ${GREEN}✓ $SYSCTL_FILE${NC}"
        echo -e "    └─ Modified: $(date -r "$SYSCTL_FILE" '+%Y-%m-%d %H:%M:%S')"
    else
        echo -e "  • ${RED}✗ $SYSCTL_FILE (not found)${NC}"
    fi
    
    if [ -f "$LIMITS_FILE" ]; then
        echo -e "  • ${GREEN}✓ $LIMITS_FILE${NC}"
        echo -e "    └─ Modified: $(date -r "$LIMITS_FILE" '+%Y-%m-%d %H:%M:%S')"
    else
        echo -e "  • ${RED}✗ $LIMITS_FILE (not found)${NC}"
    fi
    
    pause
}

# ================================================
# OPTIMIZATION FUNCTIONS
# ================================================

# Legacy BBR only installation
install_bbr_legacy() {
    clear
    show_banner
    echo -e "${GREEN}╔══════════════════════════════════════════════════════════╗${NC}"
    echo -e "${GREEN}║ Install BBR Only (Legacy)                                 ║${NC}"
    echo -e "${GREEN}╚══════════════════════════════════════════════════════════╝${NC}\n"
    
    echo -e "${YELLOW}This will install only BBR congestion control.${NC}"
    echo -e "${YELLOW}For full optimization, use option 1 instead.${NC}\n"
    
    read -p "Do you want to install BBR only? (y/N): " confirm
    
    if [[ ! "$confirm" =~ ^[Yy]$ ]]; then
        echo -e "${YELLOW}BBR installation cancelled.${NC}"
        pause
        return
    fi
    
    print_step "Downloading and installing BBR (legacy)..."
    
    if wget --no-check-certificate https://github.com/teddysun/across/raw/master/bbr.sh -O /tmp/bbr.sh 2>/dev/null; then
        chmod +x /tmp/bbr.sh
        print_success "BBR installer downloaded"
        
        echo -e "\n${YELLOW}The BBR installer will now run.${NC}"
        echo -e "${YELLOW}Follow the on-screen instructions.${NC}"
        echo -e "\n${CYAN}Note: This may require a system reboot.${NC}\n"
        
        pause "Press Enter to continue with BBR installation..."
        
        /tmp/bbr.sh
        
        echo -e "\n${GREEN}✅ BBR installation completed!${NC}\n"
        echo -e "${YELLOW}If the installer requested a reboot, please restart your server.${NC}"
        
        rm -f /tmp/bbr.sh
    else
        print_error "Failed to download BBR installer"
        echo -e "\n${YELLOW}You can install BBR manually with:${NC}"
        echo -e "${CYAN}wget --no-check-certificate https://github.com/teddysun/across/raw/master/bbr.sh && chmod +x bbr.sh && ./bbr.sh${NC}"
    fi
    
    pause
}

# Install DNS Finder
install_dns_finder() {
    clear
    show_banner
    echo -e "${GREEN}╔══════════════════════════════════════════════════════════╗${NC}"
    echo -e "${GREEN}║ Install DNS Finder                                       ║${NC}"
    echo -e "${GREEN}╚══════════════════════════════════════════════════════════╝${NC}\n"
    
    echo -e "${YELLOW}This tool finds the best DNS servers for Iran by testing latency.${NC}"
    echo -e "${YELLOW}It will help improve your internet speed and connectivity.${NC}\n"
    
    read -p "Do you want to find the best DNS servers? (y/N): " confirm
    
    if [[ ! "$confirm" =~ ^[Yy]$ ]]; then
        echo -e "${YELLOW}DNS Finder installation cancelled.${NC}"
        pause
        return
    fi
    
    print_step "Downloading and running DNS Finder..."
    
    if bash <(curl -Ls https://github.com/alinezamifar/IranDNSFinder/raw/refs/heads/main/dns.sh); then
        print_success "✅ DNS Finder completed successfully!"
        echo -e "\n${YELLOW}The tool has tested various DNS servers and shown the best options.${NC}"
    else
        print_error "Failed to run DNS Finder"
        echo -e "\n${YELLOW}You can run DNS Finder manually with:${NC}"
        echo -e "${CYAN}bash <(curl -Ls https://github.com/alinezamifar/IranDNSFinder/raw/refs/heads/main/dns.sh)${NC}"
    fi
    
    pause
    return
}

# Install Mirror Selector
install_mirror_selector() {
    clear
    show_banner
    echo -e "${GREEN}╔══════════════════════════════════════════════════════════╗${NC}"
    echo -e "${GREEN}║ Install Mirror Selector                                  ║${NC}"
    echo -e "${GREEN}╚══════════════════════════════════════════════════════════╝${NC}\n"
    
    local os
    os=$(detect_os)
    if [[ "$os" != "ubuntu" ]] && [[ "$os" != "debian" ]]; then
        print_error "This tool is only for Ubuntu/Debian based systems"
        echo -e "${YELLOW}Your OS is: $os${NC}"
        pause
        return
    fi
    
    echo -e "${YELLOW}This tool finds the fastest apt repository mirror for your location.${NC}"
    echo -e "${YELLOW}It will significantly improve package download speeds.${NC}\n"
    
    read -p "Do you want to find the fastest apt mirror? (y/N): " confirm
    
    if [[ ! "$confirm" =~ ^[Yy]$ ]]; then
        echo -e "${YELLOW}Mirror Selector installation cancelled.${NC}"
        pause
        return
    fi
    
    print_step "Downloading and running Mirror Selector..."
    
    if bash <(curl -Ls https://github.com/alinezamifar/DetectUbuntuMirror/raw/refs/heads/main/DUM.sh); then
        print_success "✅ Mirror Selector completed successfully!"
        echo -e "\n${YELLOW}The tool has tested various mirrors and selected the fastest one.${NC}"
    else
        print_error "Failed to run Mirror Selector"
        echo -e "\n${YELLOW}You can run Mirror Selector manually with:${NC}"
        echo -e "${CYAN}bash <(curl -Ls https://github.com/alinezamifar/DetectUbuntuMirror/raw/refs/heads/main/DUM.sh)${NC}"
    fi
    
    pause
    return
}

# Optimization menu
# Optimization menu
optimize_server() {
    while true; do
        clear
        show_banner
        echo -e "${GREEN}╔══════════════════════════════════════════════════════════╗${NC}"
        echo -e "${GREEN}║ Server Optimization Tools                                ║${NC}"
        echo -e "${GREEN}╚══════════════════════════════════════════════════════════╝${NC}\n"
        
        echo -e "${CYAN}1.${NC} ${GREEN}Kernel Optimization (Recommended)${NC} - Full kernel tuning (BBR + buffers + limits)"
        echo -e "${CYAN}2.${NC} ${PURPLE}DNS Finder${NC} - Find the best DNS servers for Iran"
        echo -e "${CYAN}3.${NC} ${ORANGE}Mirror Selector${NC} - Find the fastest apt repository mirror"
        echo -e "${CYAN}4.${NC} ${BLUE}BBR Only (Legacy)${NC} - Install only BBR congestion control"
        echo -e "${CYAN}0.${NC} ↩️ Back to Main Menu"
        echo ""
        
        read -p "Select option [0-4]: " choice
        
        case $choice in
            1) 
                while true; do
                    clear
                    show_banner
                    echo -e "${GREEN}╔══════════════════════════════════════════════════════════╗${NC}"
                    echo -e "${GREEN}║ Kernel Optimization Menu                                 ║${NC}"
                    echo -e "${GREEN}╚══════════════════════════════════════════════════════════╝${NC}\n"
                    
                    echo -e " 1. Apply full kernel optimizations (BBR + buffers + limits)"
                    echo -e " 2. Remove kernel optimizations (restore defaults)"
                    echo -e " 3. View current kernel status"
                    echo -e " 0. Back to optimization menu"
                    echo ""
                    
                    read -p "Select option [0-3]: " kernel_choice
                    
                    case $kernel_choice in
                        1) apply_kernel_optimizations ;;
                        2) remove_kernel_optimizations ;;
                        3) view_kernel_status ;;
                        0) break ;;
                        *) print_error "Invalid option"; sleep 1 ;;
                    esac
                done
                ;;
            2) install_dns_finder ;;
            3) install_mirror_selector ;;
            4) install_bbr_legacy ;;
            0) return ;;
            *) print_error "Invalid option"; sleep 1 ;;
        esac
    done
}

# ================================================
# MANAGE ALL SERVICES
# ================================================

# Manage all services (Restart, Live Log, Delete)
manage_all_services() {
    while true; do
        clear
        show_banner
        echo -e "${GREEN}╔══════════════════════════════════════════════════════════════╗${NC}"
        echo -e "${GREEN}║ Manage All Paqet Services                                    ║${NC}"
        echo -e "${GREEN}╚══════════════════════════════════════════════════════════════╝${NC}\n"
        
        local services=()
        mapfile -t services < <(systemctl list-unit-files --type=service --no-legend --no-pager 2>/dev/null |
                              grep -E '^paqet-.*\.service' | awk '{print $1}' || true)
        
        if [[ ${#services[@]} -eq 0 ]]; then
            echo -e "${YELLOW}No Paqet services found.${NC}\n"
            pause
            return
        fi
        
        echo -e "${CYAN}Found ${#services[@]} Paqet service(s):${NC}\n"
        
        local i=1
        for svc in "${services[@]}"; do
            local service_name="${svc%.service}"
            local display_name="${service_name#paqet-}"
            local status
            status=$(systemctl is-active "$svc" 2>/dev/null || echo "unknown")
            
            local status_color=""
            case "$status" in
                active) status_color="${GREEN}" ;;
                failed) status_color="${RED}" ;;
                inactive) status_color="${YELLOW}" ;;
                *) status_color="${WHITE}" ;;
            esac
            
            printf " %2d. ${CYAN}%-25s${NC} [${status_color}%s${NC}]\n" "$i" "$display_name" "$status"
            ((i++))
        done
        
        echo -e "\n${YELLOW}Management Options:${NC}"
        echo -e "────────────────────────────────────────────────────────────────"
        echo -e " ${GREEN}[1]${NC} 🔄 Restart All Services"
        echo -e " ${GREEN}[2]${NC} 📋 Live Log Monitoring (All Tunnels)"
        echo -e " ${GREEN}[3]${NC} 🗑️  Delete All Tunnels"
        echo -e " ${GREEN}[0]${NC} ↩️ Back to Main Menu"
        echo ""
        
        read -p "Choose option [0-3]: " mgmt_choice
        
        case $mgmt_choice in
            1)
                # Restart All Services
                echo -e "\n${YELLOW}Restarting all Paqet services...${NC}"
                
                local success_count=0
                local fail_count=0
                
                for svc in "${services[@]}"; do
                    local service_name="${svc%.service}"
                    local display_name="${service_name#paqet-}"
                    
                    echo -n " Restarting $display_name... "
                    
                    if systemctl restart "$svc" >/dev/null 2>&1; then
                        sleep 1
                        if systemctl is-active --quiet "$svc" 2>/dev/null; then
                            echo -e "${GREEN}✅ SUCCESS${NC}"
                            ((success_count++))
                        else
                            echo -e "${RED}❌ FAILED (not running)${NC}"
                            ((fail_count++))
                        fi
                    else
                        echo -e "${RED}❌ FAILED${NC}"
                        ((fail_count++))
                    fi
                done
                
                echo -e "\n${CYAN}Results:${NC}"
                echo -e " ${GREEN}✅ Success:${NC} $success_count service(s)"
                echo -e " ${RED}❌ Failed:${NC} $fail_count service(s)"
                
                if [ $fail_count -eq 0 ]; then
                    print_success "All services restarted successfully!"
                elif [ $success_count -eq 0 ]; then
                    print_error "All services failed to restart!"
                else
                    print_warning "Some services failed to restart"
                fi
                pause
                ;;
                
            2)
                # Live Log Monitoring
                echo -e "\n${YELLOW}Live Log Monitoring - All Paqet Tunnels${NC}"
                echo -e "────────────────────────────────────────────────────────────────"
                echo -e "${CYAN}Showing logs from all paqet services (Ctrl+C to exit)${NC}\n"
                sleep 2
                
                # Build journalctl command for all paqet services
                local journal_args=""
                for svc in "${services[@]}"; do
                    journal_args="$journal_args -u $svc"
                done
                
                # Follow logs from all services
                journalctl $journal_args -f --output=short-iso
                
                # After exiting journalctl
                echo -e "\n${YELLOW}Returned from log monitoring${NC}"
                pause
                ;;
                
            3)
                # Delete All Tunnels
              echo -e "\n${RED}╔══════════════════════════════════════════════════════════════╗${NC}"
                echo -e "${RED}║                          WARNING!                            ║${NC}"
                echo -e "${RED}║    This will delete ALL Paqet tunnels and configurations!    ║${NC}"
                echo -e "${RED}╚══════════════════════════════════════════════════════════════╝${NC}\n"
                
                echo -e "${YELLOW}Services to be deleted:${NC}"
                for svc in "${services[@]}"; do
                    local service_name="${svc%.service}"
                    local display_name="${service_name#paqet-}"
                    echo -e " - ${CYAN}$display_name${NC}"
                done
                
                echo ""
                read -p "Are you ABSOLUTELY SURE? (type 'yes' to confirm): " confirm
                
                if [ "$confirm" != "yes" ]; then
                    echo -e "${YELLOW}Operation cancelled.${NC}"
                    pause
                    continue
                fi
                
                echo ""
                print_step "Stopping and removing all services..."
                
                local deleted_count=0
                local failed_count=0
                
                for svc in "${services[@]}"; do
                    local service_name="${svc%.service}"
                    local display_name="${service_name#paqet-}"
                    local config_file="$CONFIG_DIR/$display_name.yaml"
                    
                    echo -n " Removing $display_name... "
                    
                    # Remove cronjob
                    remove_cronjob "$service_name" >/dev/null 2>&1 || true
                    
                    # Stop and disable service
                    systemctl stop "$svc" >/dev/null 2>&1 || true
                    systemctl disable "$svc" >/dev/null 2>&1 || true
                    
                    # Remove service file
                    if [ -f "$SERVICE_DIR/$svc" ]; then
                        rm -f "$SERVICE_DIR/$svc" >/dev/null 2>&1 || true
                    fi
                    
                    # Remove config file
                    if [ -f "$config_file" ]; then
                        rm -f "$config_file" >/dev/null 2>&1 || true
                    fi
                    
                    echo -e "${GREEN}✅ Removed${NC}"
                    ((deleted_count++))
                done
                
                systemctl daemon-reload >/dev/null 2>&1
                
                echo -e "\n${CYAN}Results:${NC}"
                echo -e " ${GREEN}✅ Deleted:${NC} $deleted_count service(s)"
                
                print_success "All tunnels deleted successfully!"
                pause
                ;;
                
            0)
                return
                ;;
                
            *)
                print_error "Invalid choice"
                sleep 1.5
                ;;
        esac
    done
}

# ================================================
# UNINSTALL & UTILITY FUNCTIONS
# ================================================

# Uninstall Paqet
uninstall_paqet() {
    clear
    show_banner
    echo -e "${RED}╔══════════════════════════════════════════════════════════╗${NC}"
    echo -e "${RED}║ Uninstall Paqet                                          ║${NC}"
    echo -e "${RED}╚══════════════════════════════════════════════════════════╝${NC}\n"
    
    read -p "Are you sure? (y/N): " confirm
    if [[ ! "$confirm" =~ ^[Yy]$ ]]; then
        return
    fi
    
    print_step "Stopping services..."
    
    local services=()
    mapfile -t services < <(systemctl list-unit-files --type=service --no-legend --no-pager 2>/dev/null |
                          grep -E '^paqet-.*\.service' | awk '{print $1}' || true)
    
    for service in "${services[@]}"; do
        systemctl stop "$service" 2>/dev/null || true
        systemctl disable "$service" 2>/dev/null || true
        rm -f "$SERVICE_DIR/$service" 2>/dev/null || true
    done
    
    for service in "${services[@]}"; do
        local service_name="${service%.service}"
        remove_cronjob "$service_name" 2>/dev/null || true
    done
    
    systemctl daemon-reload
    
    print_step "Removing files..."
    rm -f "$BIN_DIR/paqet" 2>/dev/null || true
    
    read -p "Remove configuration files? (y/N): " remove_configs
    if [[ "$remove_configs" =~ ^[Yy]$ ]]; then
        rm -rf "$CONFIG_DIR" 2>/dev/null || true
        rm -rf "$INSTALL_DIR" 2>/dev/null || true
        print_success "All files removed"
    else
        print_info "Configuration preserved in $CONFIG_DIR/"
    fi
    
    print_success "✅ Paqet uninstalled"
    pause
    return
}

# ================================================
# MAIN MENU
# ================================================

main_menu() {
    while true; do
        clear
        show_banner
        
        echo -e "${GREEN}╔══════════════════════════════════════════════════════════╗${NC}"
        echo -e "${GREEN}║ Main Menu                                                ║${NC}"
        echo -e "${GREEN}╚══════════════════════════════════════════════════════════╝${NC}\n"
        
        if [ -f "$BIN_DIR/paqet" ]; then
            echo -e "${GREEN}✅ Paqet is installed${NC}"
            local core_version
            core_version=$("$BIN_DIR/paqet" version 2>/dev/null | grep "^Version:" | head -1 | cut -d':' -f2 | xargs)
            if [ -n "$core_version" ]; then
                echo -e "   ${GREEN}└─ Version: ${CYAN}$core_version${NC}"
            fi
        else
            echo -e "${YELLOW}⚠️ Paqet not installed${NC}"
        fi
        
        local missing_deps
        missing_deps=$(check_dependencies)
        if [ $? -eq 0 ]; then
            echo -e "${GREEN}✅ Dependencies are installed${NC}"
        else
            echo -e "${YELLOW}⚠️ Missing dependencies: $missing_deps${NC}"
        fi
        
        echo -e "\n${CYAN}0.${NC}⚙️  Install Paqet Binary / Manager"
        echo -e "${CYAN}1.${NC}📦 Install Dependencies"
        echo -e "${CYAN}2.${NC}🌍 Configure as Server (kharej)"
        echo -e "${CYAN}3.${NC}🇮🇷 Configure as Client (Iran) [Port Forwarding / SOCKS5]"
        echo -e "${CYAN}4.${NC}🛠️  Manage Services"
        echo -e "${CYAN}5.${NC}🔄 Manage All Services (Restart/Logs/Delete)"
        echo -e "${CYAN}6.${NC}📊 Test Connection"
        echo -e "${CYAN}7.${NC}🚀 Optimize Server"
        echo -e "${CYAN}8.${NC}🗑️  Uninstall Paqet"
        echo -e "${CYAN}9.${NC}🚪 Exit"
        echo ""
        
        read -p "Select option [0-9]: " choice
        
        case $choice in
            0) install_paqet ;;
            1) install_dependencies ;;
            2) configure_server ;;
            3) configure_client ;;
            4) manage_services ;;
            5) manage_all_services ;;
            6) test_connection ;;
            7) optimize_server ;;
            8) uninstall_paqet ;;
            9)
                echo -e "\n${GREEN}══════════════════════════════════════════════════════════════${NC}"
                echo -e "${GREEN} Goodbye! ${NC}"
                echo -e "${GREEN}══════════════════════════════════════════════════════════════${NC}\n"
                exit 0
                ;;
            *) print_error "Invalid option"; sleep 1 ;;
        esac
    done
}

# ================================================
# START
# ================================================

check_root
main_menu
