#!/bin/bash

#=================================================
# Paqet Tunnel Manager
# Version: 3.3
# Raw packet-level tunneling for bypassing network restrictions
# GitHub: https://github.com/hanselime/paqet
# Design and development by: https://github.com/behzadea12 - https://t.me/behzad_developer
#=================================================

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
BLUE='\033[0;34m'
MAGENTA='\033[0;35m'
WHITE='\033[1;37m'
NC='\033[0m'

# Configuration
SCRIPT_VERSION="3.3"
PAQET_VERSION="v1.0.0-alpha.12"
CONFIG_DIR="/etc/paqet"
SERVICE_DIR="/etc/systemd/system"
BIN_DIR="/usr/local/bin"
INSTALL_DIR="/opt/paqet"
GITHUB_REPO="hanselime/paqet"
SERVICE_NAME="paqet"

# Banner
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
    echo "║                                 Manager v3.3                 ║"
    echo "║                                                              ║"
    echo "║          https://t.me/behzad_developer                       ║"
    echo "║          https://github.com/behzadea12                       ║"    
    echo "║                                                              ║"
    echo "╚══════════════════════════════════════════════════════════════╝"
    echo -e "${NC}"
}

# Print functions
print_step() { echo -e "${BLUE}[*]${NC} $1"; }
print_success() { echo -e "${GREEN}[✓]${NC} $1"; }
print_error() { echo -e "${RED}[✗]${NC} $1"; }
print_warning() { echo -e "${YELLOW}[!]${NC} $1"; }
print_info() { echo -e "${CYAN}[i]${NC} $1"; }

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
        OS=$ID
        OS_VERSION=$VERSION_ID
    elif [ -f /etc/redhat-release ]; then
        OS="rhel"
    else
        OS=$(uname -s | tr '[:upper:]' '[:lower:]')
    fi
    echo "$OS"
}

# Detect architecture
detect_arch() {
    local arch
    arch=$(uname -m)
    
    case $arch in
        x86_64|x86-64|amd64)
            echo "amd64"
            ;;
        aarch64|arm64)
            echo "arm64"
            ;;
        armv7l|armhf)
            echo "armv7"
            ;;
        i386|i686)
            echo "386"
            ;;
        *)
            print_error "Unsupported architecture: $arch"
            return 1
            ;;
    esac
}

# Get public IP
get_public_ip() {
    local ip=""
    ip=$(curl -4 -s --max-time 3 ifconfig.me 2>/dev/null) || \
    ip=$(curl -4 -s --max-time 3 icanhazip.com 2>/dev/null) || \
    ip=$(curl -4 -s --max-time 3 api.ipify.org 2>/dev/null) || \
    ip=$(hostname -I | awk '{print $1}' 2>/dev/null)
    
    if echo "$ip" | grep -qE '^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$'; then
        echo "$ip"
    else
        echo "Unknown"
    fi
}

# Get network information
get_network_info() {
    local interface
    local local_ip
    local gateway_ip
    local gateway_mac
    
    # Get default interface
    if command -v ip &> /dev/null; then
        interface=$(ip route | grep default | awk '{print $5}' | head -1)
    else
        interface="eth0"
    fi
    
    # Get local IP
    if [ -n "$interface" ]; then
        if command -v ip &> /dev/null; then
            local_ip=$(ip -4 addr show "$interface" 2>/dev/null | grep -oP '(?<=inet\s)\d+(\.\d+){3}' | head -1)
        elif command -v ifconfig &> /dev/null; then
            local_ip=$(ifconfig "$interface" 2>/dev/null | grep -oE 'inet (addr:)?([0-9]*\.){3}[0-9]*' | grep -oE '([0-9]*\.){3}[0-9]*' | head -1)
        fi
    fi
    
    # Get gateway IP
    if command -v ip &> /dev/null; then
        gateway_ip=$(ip route | grep default | awk '{print $3}' | head -1)
    fi
    
    # Get gateway MAC
    if [ -n "$gateway_ip" ]; then
        # Try to ping to populate ARP cache
        ping -c 1 -W 1 "$gateway_ip" >/dev/null 2>&1 || true
        
        # Try ip neigh first
        gateway_mac=$(ip neigh show "$gateway_ip" 2>/dev/null | grep -oE '([0-9a-fA-F]{2}:){5}[0-9a-fA-F]{2}' | head -1)
        
        # Fallback to arp
        if [ -z "$gateway_mac" ] && command -v arp &> /dev/null; then
            gateway_mac=$(arp -n "$gateway_ip" 2>/dev/null | awk '/^'$gateway_ip'/ {print $3}' | head -1)
        fi
    fi
    
    # Return values
    NETWORK_INTERFACE="$interface"
    LOCAL_IP="$local_ip"
    GATEWAY_IP="$gateway_ip"
    GATEWAY_MAC="$gateway_mac"
}

# Check port conflict
check_port_conflict() {
    local port="$1"
    
    if ss -tuln 2>/dev/null | grep -q ":${port} "; then
        print_warning "Port $port is already in use!"
        
        local pid
        pid=$(lsof -t -i:$port 2>/dev/null | head -1)
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

# Install dependencies
install_dependencies() {
    print_step "Installing dependencies..."
    
    local os
    os=$(detect_os)
    
    case $os in
        ubuntu|debian)
            apt update -qq >/dev/null 2>&1 || true
            apt install -y curl wget libpcap-dev iptables lsof iproute2 >/dev/null 2>&1 || {
                print_warning "Some packages may have failed to install"
            }
            ;;
        centos|rhel|fedora|rocky|almalinux)
            yum install -y curl wget libpcap-devel iptables lsof iproute >/dev/null 2>&1 || {
                print_warning "Some packages may have failed to install"
            }
            ;;
        *)
            print_warning "Unknown OS. Please install manually: libpcap iptables curl"
            ;;
    esac
    
    print_success "Dependencies installed"
}

# Generate secret key
generate_secret_key() {
    if command -v openssl &> /dev/null; then
        openssl rand -base64 32 | tr -dc 'a-zA-Z0-9' | head -c 32
    else
        cat /dev/urandom | tr -dc 'a-zA-Z0-9' | head -c 32
    fi
}

# Download and install Paqet binary
install_paqet() {
    print_step "Installing Paqet binary..."
    
    local arch
    arch=$(detect_arch)
    if [ $? -ne 0 ]; then
        return 1
    fi
    
    local os="linux"
    local version="$PAQET_VERSION"
    
    # Check for local files in /root/paqet
    local local_dir="/root/paqet"
    
    # Create directory if doesn't exist
    mkdir -p "$local_dir"
    
    # Check if there are any .tar.gz files in /root/paqet
    local local_files=()
    if [ -d "$local_dir" ]; then
        mapfile -t local_files < <(find "$local_dir" -name "*.tar.gz" -type f 2>/dev/null)
    fi
    
    # If local files exist, let user choose
    if [ ${#local_files[@]} -gt 0 ]; then
        echo -e "${YELLOW}Found local paqet archives in $local_dir:${NC}"
        echo ""
        
        for i in "${!local_files[@]}"; do
            local filename=$(basename "${local_files[$i]}")
            echo -e "  $((i+1)). ${CYAN}$filename${NC}"
        done
        
        echo ""
        echo -e "${YELLOW}Options:${NC}"
        echo -e "  ${CYAN}0)${NC} Download from GitHub (default)"
        echo -e "  ${CYAN}1-${#local_files[@]})${NC} Use local file"
        echo ""
        
        read -p "Choose [0-${#local_files[@]}]: " file_choice
        
        if [[ "$file_choice" -ge 1 ]] && [[ "$file_choice" -le ${#local_files[@]} ]]; then
            local selected_file="${local_files[$((file_choice-1))]}"
            print_success "Using local file: $(basename "$selected_file")"
            cp "$selected_file" "/tmp/paqet.tar.gz"
        else
            # Download from GitHub
            print_info "Downloading from GitHub..."
            local archive_name="paqet-${os}-${arch}-${version}.tar.gz"
            local download_url="https://github.com/${GITHUB_REPO}/releases/download/${version}/${archive_name}"
            
            if ! curl -fsSL "$download_url" -o "/tmp/paqet.tar.gz" 2>/dev/null; then
                print_error "Download failed from GitHub"
                print_info "URL: $download_url"
                
                # Try to use any local file as fallback
                if [ ${#local_files[@]} -gt 0 ]; then
                    print_warning "Using first available local file as fallback"
                    cp "${local_files[0]}" "/tmp/paqet.tar.gz"
                else
                    return 1
                fi
            else
                print_success "Downloaded from GitHub"
            fi
        fi
    else
        # No local files, download from GitHub
        print_info "No local files found. Downloading from GitHub..."
        local archive_name="paqet-${os}-${arch}-${version}.tar.gz"
        local download_url="https://github.com/${GITHUB_REPO}/releases/download/${version}/${archive_name}"
        
        if ! curl -fsSL "$download_url" -o "/tmp/paqet.tar.gz" 2>/dev/null; then
            print_error "Download failed"
            print_info "URL: $download_url"
            print_info "Please download manually and place in $local_dir/"
            return 1
        fi
        print_success "Downloaded from GitHub"
    fi
    
    # Extract and install
    mkdir -p "$INSTALL_DIR"
    
    tar -xzf "/tmp/paqet.tar.gz" -C "$INSTALL_DIR" 2>/dev/null || {
        print_error "Failed to extract archive"
        rm -f "/tmp/paqet.tar.gz"
        return 1
    }
    
    # Find and install binary
    local extracted_binary="$INSTALL_DIR/paqet_${os}_${arch}"
    if [ -f "$extracted_binary" ]; then
        cp "$extracted_binary" "$BIN_DIR/paqet"
        chmod +x "$BIN_DIR/paqet"
        print_success "Paqet installed to $BIN_DIR/paqet"
    else
        # Try alternative naming
        local alt_binary=$(find "$INSTALL_DIR" -name "paqet" -type f | head -1)
        if [ -f "$alt_binary" ]; then
            cp "$alt_binary" "$BIN_DIR/paqet"
            chmod +x "$BIN_DIR/paqet"
            print_success "Paqet installed to $BIN_DIR/paqet"
        else
            print_error "Binary not found in archive"
            return 1
        fi
    fi
    
    rm -f "/tmp/paqet.tar.gz"
    return 0
}

# Configure iptables
configure_iptables() {
    local port="$1"
    
    print_step "Configuring iptables for port $port..."
    
    if ! command -v iptables &> /dev/null; then
        print_warning "iptables not found, skipping"
        return 0
    fi
    
    # Remove existing rules
    iptables -t raw -D PREROUTING -p tcp --dport "$port" -j NOTRACK 2>/dev/null || true
    iptables -t raw -D OUTPUT -p tcp --sport "$port" -j NOTRACK 2>/dev/null || true
    iptables -t mangle -D OUTPUT -p tcp --sport "$port" --tcp-flags RST RST -j DROP 2>/dev/null || true
    
    # Add new rules
    iptables -t raw -A PREROUTING -p tcp --dport "$port" -j NOTRACK
    iptables -t raw -A OUTPUT -p tcp --sport "$port" -j NOTRACK
    iptables -t mangle -A OUTPUT -p tcp --sport "$port" --tcp-flags RST RST -j DROP
    
    print_success "iptables configured"
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

[Install]
WantedBy=multi-user.target
EOF
    
    systemctl daemon-reload
    print_success "Service created: ${service_name}"
}

# Get KCP mode configuration
get_kcp_mode_config() {
    local mode_config=""
    
    # Display to terminal (not to stdout)
    echo -e "${YELLOW}Select KCP mode:${NC}" >&2
    echo -e "  1) fast (default - optimized for speed)" >&2
    echo -e "  2) manual (custom configuration)" >&2
    read -p "Choose [1-2]: " mode_choice >&2
    
    case $mode_choice in
        1)
            echo -e "${CYAN}Using fast mode${NC}" >&2
            echo "" >&2
            
            # Ask for block cipher
            echo -e "${YELLOW}Select encryption block cipher:${NC}" >&2
            echo -e "  1) aes (default)" >&2
            echo -e "  2) aes-128-gcm" >&2
            echo -e "  3) none (no encryption)" >&2
            echo -e "  4) Custom (enter manually)" >&2
            read -p "Choose [1-4]: " block_choice >&2
            
            local block="aes"
            case $block_choice in
                1) block="aes" ;;
                2) block="aes-128-gcm" ;;
                3) block="none" ;;
                4)
                    read -p "Enter cipher (e.g., aes, aes-128-gcm, none): " block >&2
                    block="${block:-aes}"
                    ;;
                *) block="aes" ;;
            esac
            
            mode_config="    mode: \"fast\"
    block: \"$block\""
            ;;
        2)
            echo -e "${CYAN}Manual KCP configuration${NC}" >&2
            echo "" >&2
            
            # Get manual configuration parameters
            echo -e "${YELLOW}Manual KCP Parameters (press Enter for default):${NC}" >&2
            
            read -p "Nodelay [1]: " nodelay >&2
            nodelay="${nodelay:-1}"
            
            echo -e "Wdelay: false or true?" >&2
            read -p "Wdelay [false]: " wdelay >&2
            wdelay="${wdelay:-false}"
            
            echo -e "Acknodelay: false or true?" >&2
            read -p "Acknodelay [true]: " acknodelay >&2
            acknodelay="${acknodelay:-true}"
            
            read -p "Interval [20]: " interval >&2
            interval="${interval:-20}"
            
            read -p "Resend [1]: " resend >&2
            resend="${resend:-1}"
            
            read -p "Nocongestion [1]: " nocongestion >&2
            nocongestion="${nocongestion:-1}"
            
            read -p "MTU [1200]: " mtu >&2
            mtu="${mtu:-1200}"
            
            read -p "Receive window [2048]: " rcvwnd >&2
            rcvwnd="${rcvwnd:-2048}"
            
            read -p "Send window [2048]: " sndwnd >&2
            sndwnd="${sndwnd:-2048}"
            
            # Select block cipher
            echo "" >&2
            echo -e "${YELLOW}Select encryption block cipher:${NC}" >&2
            echo -e "  1) aes (default)" >&2
            echo -e "  2) aes-128-gcm" >&2
            echo -e "  3) aes-128" >&2
            echo -e "  4) aes-192" >&2
            echo -e "  5) aes-256" >&2
            echo -e "  6) none (no encryption)" >&2
            echo -e "  7) Custom (enter manually)" >&2
            read -p "Choose [1-7]: " block_choice >&2
            
            local block="aes"
            case $block_choice in
                1) block="aes" ;;
                2) block="aes-128-gcm" ;;
                3) block="aes-128" ;;
                4) block="aes-192" ;;
                5) block="aes-256" ;;
                6) block="none" ;;
                7)
                    read -p "Enter cipher: " block >&2
                    block="${block:-aes}"
                    ;;
                *) block="aes" ;;
            esac
            
            mode_config="    mode: \"manual\"
    nodelay: $nodelay
    wdelay: $wdelay
    acknodelay: $acknodelay
    interval: $interval
    resend: $resend
    nocongestion: $nocongestion
    mtu: $mtu
    rcvwnd: $rcvwnd
    sndwnd: $sndwnd
    block: \"$block\""
            ;;
        *)
            echo -e "${YELLOW}Using default fast mode${NC}" >&2
            mode_config="    mode: \"fast\"
    block: \"aes\""
            ;;
    esac
    
    # Return the configuration (to stdout)
    echo "$mode_config"
}

# Configure as Server (Abroad)
configure_server() {
    while true; do
        show_banner
        echo -e "${GREEN}Configure as Server (Abroad)${NC}"
        echo ""
        
        # Get network info
        get_network_info
        local public_ip
        public_ip=$(get_public_ip)
        
        echo -e "${YELLOW}Detected Network:${NC}"
        echo -e "  Interface:   ${CYAN}${NETWORK_INTERFACE:-Not found}${NC}"
        echo -e "  Local IP:    ${CYAN}${LOCAL_IP:-Not found}${NC}"
        echo -e "  Public IP:   ${CYAN}$public_ip${NC}"
        echo -e "  Gateway MAC: ${CYAN}${GATEWAY_MAC:-Not found}${NC}"
        echo ""
        
        # Get config name
        read -p "Config name [server]: " config_name
        config_name="${config_name:-server}"
        config_name=$(echo "$config_name" | tr -cd '[:alnum:]-_')
        if [ -z "$config_name" ]; then
            config_name="default"
        fi
        print_info "Sanitized config name: $config_name"
        
        # Check existing config
        if [ -f "$CONFIG_DIR/${config_name}.yaml" ]; then
            read -p "Config exists. Overwrite? (y/N): " overwrite
            if [[ ! "$overwrite" =~ ^[Yy]$ ]]; then
                continue
            fi
        fi
        
        # Get interface
        read -p "Network interface [${NETWORK_INTERFACE:-eth0}]: " interface
        interface="${interface:-${NETWORK_INTERFACE:-eth0}}"
        
        # Get local IP
        read -p "Local IP [${LOCAL_IP}]: " local_ip
        local_ip="${local_ip:-$LOCAL_IP}"
        
        # Get gateway MAC
        read -p "Gateway MAC [${GATEWAY_MAC}]: " gateway_mac
        gateway_mac="${gateway_mac:-$GATEWAY_MAC}"
        
        # Get port
        echo ""
        read -p "Listen port [8888]: " port
        port="${port:-8888}"
        
        if ! check_port_conflict "$port"; then
            read -p "Press Enter to retry..."
            continue
        fi
        
        # Get secret key
        echo ""
        local secret_key
        secret_key=$(generate_secret_key)
        echo -e "${YELLOW}Generated secret key:${NC} ${CYAN}$secret_key${NC}"
        read -p "Use this key? (Y/n): " use_key
        
        if [[ "$use_key" =~ ^[Nn]$ ]]; then
            read -p "Enter your secret key: " secret_key
        fi
        
        if [ -z "$secret_key" ]; then
            print_error "Secret key is required"
            continue
        fi
        
        # Get KCP configuration
        echo ""
        kcp_config=$(get_kcp_mode_config)
        
        # Get V2Ray ports
        echo ""
        read -p "V2Ray inbound ports (comma separated) [9090]: " inbound_ports
        inbound_ports="${inbound_ports:-9090}"
        
        # Install Paqet if not installed
        if [ ! -f "$BIN_DIR/paqet" ]; then
            if ! install_paqet; then
                print_error "Failed to install Paqet"
                read -p "Press Enter to continue..."
                return 1
            fi
        fi
        
        # Configure iptables
        configure_iptables "$port"
        
        # Create config
        mkdir -p "$CONFIG_DIR"
        cat > "$CONFIG_DIR/${config_name}.yaml" << EOF
# Paqet Server Configuration
role: "server"

log:
  level: "info"

listen:
  addr: ":${port}"

network:
  interface: "${interface}"
  ipv4:
    addr: "${local_ip}:${port}"
    router_mac: "${gateway_mac}"

transport:
  protocol: "kcp"
  kcp:
    key: "${secret_key}"
${kcp_config}
EOF
        
        print_success "Configuration saved: $CONFIG_DIR/${config_name}.yaml"
        
        # Create and start service
        create_systemd_service "$config_name"
        systemctl enable "paqet-${config_name}" --now
        
        if systemctl is-active --quiet "paqet-${config_name}"; then
            print_success "Server started successfully"
            
            echo ""
            echo -e "${GREEN}════════════════════════════════════════════════════════════${NC}"
            echo -e "${GREEN}                     Server Ready!                           ${NC}"
            echo -e "${GREEN}════════════════════════════════════════════════════════════${NC}"
            echo ""
            echo -e "  ${YELLOW}Public IP:${NC}    ${CYAN}$public_ip${NC}"
            echo -e "  ${YELLOW}Listen Port:${NC}  ${CYAN}$port${NC}"
            echo -e "  ${YELLOW}V2Ray Ports:${NC}  ${CYAN}$inbound_ports${NC}"
            echo ""
            echo -e "${YELLOW}Secret Key (save for client):${NC}"
            echo -e "${CYAN}$secret_key${NC}"
            echo ""
            echo -e "${YELLOW}KCP Configuration:${NC}"
            echo -e "${CYAN}$kcp_config${NC}"
            echo ""
        else
            print_error "Failed to start service"
            systemctl status "paqet-${config_name}" --no-pager -l
        fi
        
        read -p "Press Enter to continue..."
        return 0
    done
}

# Configure as Client (Iran)
configure_client() {
    while true; do
        show_banner
        echo -e "${GREEN}Configure as Client (Iran)${NC}"
        echo ""
        
        # Get network info
        get_network_info
        local public_ip
        public_ip=$(get_public_ip)
        
        echo -e "${YELLOW}Detected Network:${NC}"
        echo -e "  Interface:   ${CYAN}${NETWORK_INTERFACE:-Not found}${NC}"
        echo -e "  Local IP:    ${CYAN}${LOCAL_IP:-Not found}${NC}"
        echo -e "  Public IP:   ${CYAN}$public_ip${NC}"
        echo -e "  Gateway MAC: ${CYAN}${GATEWAY_MAC:-Not found}${NC}"
        echo ""
        
        # Get server details
        read -p "Server IP (abroad): " server_ip
        if [ -z "$server_ip" ]; then
            print_error "Server IP is required"
            continue
        fi
        
        read -p "Server port [8888]: " server_port
        server_port="${server_port:-8888}"
        
        read -p "Secret key: " secret_key
        if [ -z "$secret_key" ]; then
            print_error "Secret key is required"
            continue
        fi
        
        # Get config name
        read -p "Config name [client]: " config_name
        config_name="${config_name:-client}"
        
        # Check existing config
        if [ -f "$CONFIG_DIR/${config_name}.yaml" ]; then
            read -p "Config exists. Overwrite? (y/N): " overwrite
            if [[ ! "$overwrite" =~ ^[Yy]$ ]]; then
                continue
            fi
        fi
        
        # Get interface
        read -p "Network interface [${NETWORK_INTERFACE:-eth0}]: " interface
        interface="${interface:-${NETWORK_INTERFACE:-eth0}}"
        
        # Get local IP
        read -p "Local IP [${LOCAL_IP}]: " local_ip
        local_ip="${local_ip:-$LOCAL_IP}"
        
        # Get gateway MAC
        read -p "Gateway MAC [${GATEWAY_MAC}]: " gateway_mac
        gateway_mac="${gateway_mac:-$GATEWAY_MAC}"
        
        # Get KCP configuration
        echo ""
        kcp_config=$(get_kcp_mode_config)
        
        # Get forwarding ports
        echo ""
        read -p "Ports to forward (comma separated) [9090]: " forward_ports
        forward_ports="${forward_ports:-9090}"
        
        # Check port conflicts
        IFS=',' read -ra ports_array <<< "$forward_ports"
        for port in "${ports_array[@]}"; do
            port=$(echo "$port" | tr -d ' ')
            if ! check_port_conflict "$port"; then
                read -p "Press Enter to retry..."
                continue 2
            fi
        done
        
        # Install Paqet if not installed
        if [ ! -f "$BIN_DIR/paqet" ]; then
            if ! install_paqet; then
                print_error "Failed to install Paqet"
                read -p "Press Enter to continue..."
                return 1
            fi
        fi
        
        # Create forward configuration
        local forward_config=""
        for port in "${ports_array[@]}"; do
            port=$(echo "$port" | tr -d ' ')
            forward_config="${forward_config}
  - listen: \"0.0.0.0:${port}\"
    target: \"127.0.0.1:${port}\"
    protocol: \"tcp\""
            
            # Configure iptables for each port
            configure_iptables "$port"
        done
        
        # Create config
        mkdir -p "$CONFIG_DIR"
        cat > "$CONFIG_DIR/${config_name}.yaml" << EOF
# Paqet Client Configuration
role: "client"

log:
  level: "info"

forward:${forward_config}

network:
  interface: "${interface}"
  ipv4:
    addr: "${local_ip}:0"
    router_mac: "${gateway_mac}"

server:
  addr: "${server_ip}:${server_port}"

transport:
  protocol: "kcp"
  kcp:
    key: "${secret_key}"
${kcp_config}
EOF
        
        print_success "Configuration saved: $CONFIG_DIR/${config_name}.yaml"
        
        # Create and start service
        create_systemd_service "$config_name"
        systemctl enable "paqet-${config_name}" --now
        
        if systemctl is-active --quiet "paqet-${config_name}"; then
            print_success "Client started successfully"
            
            echo ""
            echo -e "${GREEN}════════════════════════════════════════════════════════════${NC}"
            echo -e "${GREEN}                     Client Ready!                           ${NC}"
            echo -e "${GREEN}════════════════════════════════════════════════════════════${NC}"
            echo ""
            echo -e "  ${YELLOW}This Server:${NC}   ${CYAN}$public_ip${NC}"
            echo -e "  ${YELLOW}Server:${NC}        ${CYAN}$server_ip:$server_port${NC}"
            echo -e "  ${YELLOW}Forward Ports:${NC} ${CYAN}$forward_ports${NC}"
            echo ""
            echo -e "${YELLOW}Client Connection:${NC}"
            echo -e "  Connect to: ${CYAN}$public_ip${NC}"
            echo -e "  Ports:      ${CYAN}$forward_ports${NC}"
            echo ""
            echo -e "${YELLOW}KCP Configuration:${NC}"
            echo -e "${CYAN}$kcp_config${NC}"
            echo ""
        else
            print_error "Failed to start service"
            systemctl status "paqet-${config_name}" --no-pager -l
        fi
        
        read -p "Press Enter to continue..."
        return 0
    done
}

# List services
list_services() {
    show_banner
    echo -e "${YELLOW}Paqet Services${NC}"
    echo ""
    
    local services=()
    mapfile -t services < <(systemctl list-unit-files --type=service --no-legend --no-pager 2>/dev/null | 
                          grep -E '^paqet-.*\.service' | awk '{print $1}' || true)
    
    if [[ ${#services[@]} -eq 0 ]]; then
        print_info "No Paqet services found"
    else
        echo -e "${CYAN}┌──────────────────────────────────────────────────────────────┐${NC}"
        echo -e "${CYAN}│ Service Name          │     Status     │   Type    │${NC}"
        echo -e "${CYAN}├──────────────────────────────────────────────────────────────┤${NC}"
        
        for service in "${services[@]}"; do
            local service_name="${service%.service}"
            local display_name="${service_name#paqet-}"
            
            local status=$(systemctl is-active "$service" 2>/dev/null || echo "unknown")
            local type="unknown"
            local config_file="$CONFIG_DIR/$display_name.yaml"
            if [ -f "$config_file" ]; then
                type=$(grep "^role:" "$config_file" 2>/dev/null | awk '{print $2}' | tr -d '"' || echo "unknown")
            fi
            
            local status_text="$status"
            local status_color=""
            
            case "$status" in
                active)   status_color="${GREEN}"; status_text="active  " ;;
                inactive) status_color="${YELLOW}"; status_text="inactive" ;;
                failed)   status_color="${RED}";   status_text="failed  " ;;
                *)        status_color="${WHITE}"; status_text="$status" ;;
            esac

            printf "${CYAN}│ ${WHITE}%-21s ${CYAN}│ ${status_color}%-12s${NC} ${CYAN}│ ${WHITE}%-9s ${CYAN}│${NC}\n" \
                   "$display_name" "$status_text" "$type"
        done
        
        echo -e "${CYAN}└──────────────────────────────────────────────────────────────┘${NC}"
    fi
    
    echo ""
    read -p "Press Enter to continue..."
}

# Manage service
manage_service() {
    while true; do
        show_banner
        echo -e "${YELLOW}Manage Service${NC}"
        echo ""
        
        # Get services list
        local services=()
        mapfile -t services < <(systemctl list-unit-files --type=service --no-legend --no-pager 2>/dev/null | 
                              grep -E '^paqet-.*\.service' | awk '{print $1}' || true)
        
        if [[ ${#services[@]} -eq 0 ]]; then
            print_info "No Paqet services found"
            read -p "Press Enter to continue..."
            return
        fi
        
        # Display services
        for i in "${!services[@]}"; do
            local service_name="${services[$i]%.service}"
            local display_name="${service_name#paqet-}"
            local status
            status=$(systemctl is-active "${services[$i]}" 2>/dev/null || echo "unknown")
            
            case "$status" in
                active)
                    status_color="${GREEN}"
                    ;;
                failed|inactive)
                    status_color="${RED}"
                    ;;
                *)
                    status_color="${YELLOW}"
                    ;;
            esac
            
            echo -e "  $((i+1)). $display_name (${status_color}$status${NC})"
        done
        
        echo ""
        read -p "Select service (1-${#services[@]}, 0 to cancel): " choice
        
        if [[ "$choice" -eq 0 ]]; then
            return
        fi
        
        if [[ "$choice" -lt 1 ]] || [[ "$choice" -gt ${#services[@]} ]]; then
            print_error "Invalid selection"
            continue
        fi
        
        local selected_service="${services[$((choice-1))]}"
        local service_name="${selected_service%.service}"
        local display_name="${service_name#paqet-}"
        
        # Service actions menu
        while true; do
            show_banner
            echo -e "${YELLOW}Managing: $display_name${NC}"
            echo ""
            
            local status
            status=$(systemctl is-active "$selected_service" 2>/dev/null || echo "unknown")
            
            echo -e "Status: "
            case "$status" in
                active)
                    echo -e "${GREEN}● Active${NC}"
                    ;;
                failed)
                    echo -e "${RED}● Failed${NC}"
                    ;;
                inactive)
                    echo -e "${YELLOW}● Inactive${NC}"
                    ;;
                *)
                    echo -e "${YELLOW}● Unknown${NC}"
                    ;;
            esac
            
            echo ""
            echo -e "${CYAN}Actions:${NC}"
            echo -e "  1. Start"
            echo -e "  2. Stop"
            echo -e "  3. Restart"
            echo -e "  4. Status"
            echo -e "  5. Logs"
            echo -e "  6. View Config"
            echo -e "  7. Delete"
            echo -e "  8. Back"
            echo ""
            
            read -p "Choose action [1-8]: " action
            
            case "$action" in
                1)
                    systemctl start "$selected_service"
                    sleep 2
                    ;;
                2)
                    systemctl stop "$selected_service"
                    sleep 2
                    ;;
                3)
                    systemctl restart "$selected_service"
                    sleep 2
                    ;;
                4)
                    echo ""
                    systemctl status "$selected_service" --no-pager -l
                    echo ""
                    read -p "Press Enter to continue..."
                    ;;
                5)
                    echo ""
                    journalctl -u "$selected_service" -n 20 --no-pager
                    echo ""
                    read -p "Press Enter to continue..."
                    ;;
                6)
                    if [ -f "$CONFIG_DIR/$display_name.yaml" ]; then
                        echo ""
                        cat "$CONFIG_DIR/$display_name.yaml"
                        echo ""
                    else
                        print_error "Config not found"
                    fi
                    read -p "Press Enter to continue..."
                    ;;
                7)
                    read -p "Delete this service? (y/N): " confirm
                    if [[ "$confirm" =~ ^[Yy]$ ]]; then
                        systemctl stop "$selected_service" 2>/dev/null || true
                        systemctl disable "$selected_service" 2>/dev/null || true
                        rm -f "$SERVICE_DIR/$selected_service" 2>/dev/null || true
                        rm -f "$CONFIG_DIR/$display_name.yaml" 2>/dev/null || true
                        systemctl daemon-reload
                        print_success "Service deleted"
                        read -p "Press Enter to continue..."
                        return
                    fi
                    ;;
                8)
                    break
                    ;;
                *)
                    print_error "Invalid choice"
                    ;;
            esac
        done
    done
}

# View config
view_config() {
    show_banner
    echo -e "${YELLOW}Configuration Files${NC}"
    echo ""
    
    local configs=()
    while IFS= read -r -d '' config; do
        configs+=("$config")
    done < <(find "$CONFIG_DIR" -name "*.yaml" -type f -print0 2>/dev/null)
    
    if [[ ${#configs[@]} -eq 0 ]]; then
        print_info "No configuration files found"
    else
        for i in "${!configs[@]}"; do
            local config_name=$(basename "${configs[$i]}" .yaml)
            echo -e "  $((i+1)). $config_name"
        done
        
        echo ""
        read -p "Select config (1-${#configs[@]}, 0 to cancel): " choice
        
        if [[ "$choice" -ge 1 ]] && [[ "$choice" -le ${#configs[@]} ]]; then
            echo ""
            cat "${configs[$((choice-1))]}"
            echo ""
        fi
    fi
    
    echo ""
    read -p "Press Enter to continue..."
}

# Install BBR
install_bbr() {
    show_banner
    echo -e "${YELLOW}Installing BBR (Google TCP Congestion Control)${NC}"
    echo ""
    
    echo -e "${YELLOW}BBR is a TCP congestion control algorithm developed by Google.${NC}"
    echo -e "${YELLOW}It can significantly improve network performance and speed.${NC}"
    echo ""
    
    read -p "Do you want to install BBR? (y/N): " confirm
    
    if [[ ! "$confirm" =~ ^[Yy]$ ]]; then
        echo -e "${YELLOW}BBR installation cancelled.${NC}"
        return
    fi
    
    print_step "Downloading and installing BBR..."
    
    # Download BBR installer script
    if wget --no-check-certificate https://github.com/teddysun/across/raw/master/bbr.sh -O /tmp/bbr.sh 2>/dev/null; then
        chmod +x /tmp/bbr.sh
        print_success "BBR installer downloaded"
        
        echo ""
        echo -e "${YELLOW}The BBR installer will now run.${NC}"
        echo -e "${YELLOW}Follow the on-screen instructions.${NC}"
        echo ""
        echo -e "${CYAN}Note: This may require a system reboot.${NC}"
        echo ""
        
        read -p "Press Enter to continue with BBR installation..."
        
        # Run BBR installer
        /tmp/bbr.sh
        
        echo ""
        print_success "BBR installation completed!"
        echo ""
        echo -e "${YELLOW}If the installer requested a reboot, please restart your server.${NC}"
        echo -e "${YELLOW}After reboot, BBR will be active and optimizing your network.${NC}"
        
        # Clean up
        rm -f /tmp/bbr.sh
    else
        print_error "Failed to download BBR installer"
        echo ""
        echo -e "${YELLOW}You can install BBR manually with:${NC}"
        echo -e "${CYAN}wget --no-check-certificate https://github.com/teddysun/across/raw/master/bbr.sh && chmod +x bbr.sh && ./bbr.sh${NC}"
    fi
    
    echo ""
    read -p "Press Enter to return to main menu..."
}

# Uninstall Paqet
uninstall_paqet() {
    show_banner
    echo -e "${RED}Uninstall Paqet${NC}"
    echo ""
    
    read -p "Are you sure? (y/N): " confirm
    if [[ ! "$confirm" =~ ^[Yy]$ ]]; then
        return
    fi
    
    print_step "Stopping services..."
    
    # Stop and disable all paqet services
    local services=()
    mapfile -t services < <(systemctl list-unit-files --type=service --no-legend --no-pager 2>/dev/null | 
                          grep -E '^paqet-.*\.service' | awk '{print $1}' || true)
    
    for service in "${services[@]}"; do
        systemctl stop "$service" 2>/dev/null || true
        systemctl disable "$service" 2>/dev/null || true
        rm -f "$SERVICE_DIR/$service" 2>/dev/null || true
    done
    
    systemctl daemon-reload
    
    # Remove files
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
    
    print_success "Paqet uninstalled"
    echo ""
    read -p "Press Enter to continue..."
}

# Main menu
main_menu() {
    while true; do
        show_banner
        
        echo -e "${YELLOW}Main Menu${NC}"
        echo ""
        
        # Check if Paqet is installed
        if [ -f "$BIN_DIR/paqet" ]; then
            echo -e "${GREEN}✓ Paqet is installed${NC}"
        else
            echo -e "${YELLOW}⚠ Paqet not installed${NC}"
        fi
        
        echo ""
        echo -e "${CYAN}0.${NC} Install Paqet Binary Only"
        echo -e "${CYAN}1.${NC} Install Dependencies"
        echo -e "${CYAN}2.${NC} Configure as Server (kharej)"
        echo -e "${CYAN}3.${NC} Configure as Client (Iran)"
        echo -e "${CYAN}4.${NC} List Services"
        echo -e "${CYAN}5.${NC} Manage Service"
        echo -e "${CYAN}6.${NC} View Configuration"
        echo -e "${CYAN}7.${NC} Install BBR (Optimize Network)"
        echo -e "${CYAN}8.${NC} Uninstall Paqet"
        echo -e "${CYAN}9.${NC} Exit"
        echo ""
        
        read -p "Select option [0-9]: " choice
        
        case $choice in
            0)
                install_paqet
                ;;
            1)
                install_dependencies
                ;;
            2)
                configure_server
                ;;
            3)
                configure_client
                ;;
            4)
                list_services
                ;;
            5)
                manage_service
                ;;
            6)
                view_config
                ;;
            7)
                install_bbr
                ;;
            8)
                uninstall_paqet
                ;;
            9)
                echo -e "${GREEN}Goodbye!${NC}"
                exit 0
                ;;
            *)
                print_error "Invalid option"
                ;;
        esac
        
        echo ""
    done
}

# Initialize
check_root
main_menu
