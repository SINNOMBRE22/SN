#!/bin/bash
set -euo pipefail

# =======================================================================
# SlowDNS (DNSTT) Installer for Ubuntu 22.04 - Independent Setup
# Author: SINNOMBRE22
# Description: Sets up SlowDNS server without touching user management.
#              Prepares the server to accept SlowDNS connections validated
#              by existing SSH (port 22). No modifications to /etc/passwd or users.
# =======================================================================

# -------------------------------
# Global Variables
# -------------------------------
readonly DNSTT_BINARY_URL="https://github.com/SINNOMBRE22/VPS-SN/raw/main/utilidades/SlowDNS/dns-server"  # Replace with actual reliable URL if needed
readonly DNSTT_BINARY_PATH="/etc/SN/dns-server"
readonly DNSTT_CONFIG_DIR="/etc/SN/slowdns"
readonly SERVER_KEY="${DNSTT_CONFIG_DIR}/server.key"
readonly SERVER_PUB="${DNSTT_CONFIG_DIR}/server.pub"
readonly SYSTEMD_SERVICE="/etc/systemd/system/slowdns.service"
readonly RESOLVED_CONF="/etc/systemd/resolved.conf"
readonly RESOLV_CONF="/etc/resolv.conf"

# -------------------------------
# Utility Functions
# -------------------------------

# Check if running as root
require_root() {
    if [[ "${EUID:-$(id -u)}" -ne 0 ]]; then
        echo "Error: This script must be run as root."
        exit 1
    fi
}

# Print colored output
print_info() { echo -e "\e[34m[INFO]\e[0m $*" >&2; }
print_warn() { echo -e "\e[33m[WARN]\e[0m $*" >&2; }
print_error() { echo -e "\e[31m[ERROR]\e[0m $*" >&2; }
print_success() { echo -e "\e[32m[SUCCESS]\e[0m $*" >&2; }

# -------------------------------
# Step 1: Free Port 53 (systemd-resolved)
# -------------------------------
# In Ubuntu 22.04, systemd-resolved binds to port 53 by default.
# We disable its stub listener to free port 53, then configure
# /etc/resolv.conf to use external DNS (8.8.8.8) for resolution.
free_port_53() {
    print_info "Freeing port 53 by configuring systemd-resolved..."

    # Backup and modify resolved.conf
    if [[ ! -f "${RESOLVED_CONF}.bak" ]]; then
        cp "$RESOLVED_CONF" "${RESOLVED_CONF}.bak"
    fi

    # Set DNSStubListener=no to prevent systemd-resolved from binding to 53
    sed -i '/^DNSStubListener=/d' "$RESOLVED_CONF"
    echo "DNSStubListener=no" >> "$RESOLVED_CONF"

    # Configure resolv.conf with external DNS
    rm -f "$RESOLV_CONF"  # Remove symlink if exists
    echo "nameserver 8.8.8.8" > "$RESOLV_CONF"
    echo "nameserver 8.8.4.4" >> "$RESOLV_CONF"

    # Restart systemd-resolved
    systemctl restart systemd-resolved.service

    # Verify port 53 is free (should not be bound by systemd-resolved)
    if ss -uln | grep -q ":53 "; then
        print_warn "Port 53 still in use. Manual check required."
    else
        print_success "Port 53 freed successfully."
    fi
}

# -------------------------------
# Step 2: Download DNSTT Binary
# -------------------------------
download_binary() {
    print_info "Downloading DNSTT binary..."

    mkdir -p "$(dirname "$DNSTT_BINARY_PATH")"

    if [[ ! -f "$DNSTT_BINARY_PATH" ]]; then
        if ! curl -fsSL "$DNSTT_BINARY_URL" -o "$DNSTT_BINARY_PATH"; then
            print_error "Failed to download DNSTT binary from $DNSTT_BINARY_URL"
            exit 1
        fi
        chmod +x "$DNSTT_BINARY_PATH"
        print_success "DNSTT binary downloaded and made executable."
    else
        print_info "DNSTT binary already exists."
    fi
}

# -------------------------------
# Step 3: Generate Keys (only if not exist)
# -------------------------------
generate_keys() {
    print_info "Checking/generating DNSTT keys..."

    mkdir -p "$DNSTT_CONFIG_DIR"

    if [[ ! -f "$SERVER_KEY" ]] || [[ ! -f "$SERVER_PUB" ]]; then
        print_info "Generating new key pair..."
        "$DNSTT_BINARY_PATH" -gen-key -privkey-file "$SERVER_KEY" -pubkey-file "$SERVER_PUB"
        chmod 600 "$SERVER_KEY"
        chmod 644 "$SERVER_PUB"
        print_success "Keys generated."
    else
        print_info "Keys already exist."
    fi
}

# -------------------------------
# Step 4: Configure Firewall (iptables)
# -------------------------------
configure_firewall() {
    print_info "Configuring iptables for DNSTT..."

    # Redirect UDP port 53 to internal port 5300
    if ! iptables -t nat -C PREROUTING -p udp --dport 53 -j REDIRECT --to-ports 5300 2>/dev/null; then
        iptables -t nat -A PREROUTING -p udp --dport 53 -j REDIRECT --to-ports 5300
    fi

    # Allow incoming UDP on 5300 (for internal DNSTT server)
    if ! iptables -C INPUT -p udp --dport 5300 -j ACCEPT 2>/dev/null; then
        iptables -I INPUT -p udp --dport 5300 -j ACCEPT
    fi

    # Make persistent (install iptables-persistent if not present)
    if ! dpkg -l | grep -q iptables-persistent; then
        print_info "Installing iptables-persistent for rule persistence..."
        DEBIAN_FRONTEND=noninteractive apt-get update -qq && apt-get install -y iptables-persistent -qq
    fi

    # Save rules
    netfilter-persistent save >/dev/null 2>&1 || iptables-save > /etc/iptables/rules.v4

    print_success "Firewall configured and rules saved."
}

# -------------------------------
# Step 5: Create systemd Service
# -------------------------------
create_service() {
    print_info "Creating systemd service for DNSTT..."

    # Prompt for NS domain
    local ns_domain=""
    while [[ -z "$ns_domain" ]]; do
        read -p "Enter the NS domain for SlowDNS (e.g., ns.example.com): " ns_domain
        if [[ -z "$ns_domain" ]]; then
            print_error "NS domain cannot be empty."
        fi
    done

    # Save NS to config
    echo "$ns_domain" > "${DNSTT_CONFIG_DIR}/domain_ns"

    # Create service file
    cat > "$SYSTEMD_SERVICE" <<EOF
[Unit]
Description=SlowDNS DNSTT Server
After=network.target

[Service]
Type=simple
User=root
WorkingDirectory=$DNSTT_CONFIG_DIR
ExecStart=$DNSTT_BINARY_PATH -udp :5300 -privkey-file $SERVER_KEY $ns_domain 127.0.0.1:22
Restart=always
RestartSec=5

[Install]
WantedBy=multi-user.target
EOF

    # Reload and enable
    systemctl daemon-reload
    systemctl enable slowdns.service
    systemctl restart slowdns.service

    print_success "Systemd service created and started."
}

# -------------------------------
# Main Function
# -------------------------------
main() {
    require_root

    print_info "Starting SlowDNS (DNSTT) installation for Ubuntu 22.04..."
    print_info "This script only sets up the server for SlowDNS connections."
    print_info "User validation will be handled by existing SSH on port 22."

    # Run steps
    free_port_53
    download_binary
    generate_keys
    configure_firewall
    create_service

    # Final output
    local ns_domain pub_key
    ns_domain=$(cat "${DNSTT_CONFIG_DIR}/domain_ns")
    pub_key=$(cat "$SERVER_PUB")

    print_success "SlowDNS setup complete!"
    echo ""
    echo "=================== CONFIGURATION SUMMARY ==================="
    echo "NS Domain: $ns_domain"
    echo "Public Key: $pub_key"
    echo ""
    echo "=================== HTTP Custom Setup Guide ==================="
    echo "1. In HTTP Custom app, go to SlowDNS settings."
    echo "2. Enter NS Domain: $ns_domain"
    echo "3. Enter Public Key: $pub_key"
    echo "4. Set DNS Server to: 8.8.8.8 or your VPS IP."
    echo "5. Connect via SSH (port 22) as usual."
    echo "============================================================"

    print_info "Service status: $(systemctl is-active slowdns.service)"
}

# Run main
main "$@"
