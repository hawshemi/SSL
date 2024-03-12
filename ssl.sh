#!/bin/bash

# Check if script is run as root
check_root() {
    if [ "$(id -u)" != "0" ]; then
        echo "This script must be run as root" 1>&2
        exit 1
    fi
}

# Function to display help menu
usage() {
    echo "Usage: $0 [-h]"
    echo "  -h  Display this help and exit."
}

# Validate domain format
validate_domain() {
    if [[ $1 =~ ^([a-zA-Z0-9]([a-zA-Z0-9\-]{0,61}[a-zA-Z0-9])?\.)+[a-zA-Z]{2,}$ ]]; then
        return 0
    else
        return 1
    fi
}

# Install socat if it's not already installed
install_socat() {
    if ! command -v socat &> /dev/null; then
        sudo apt update
        sudo apt install -y socat || { echo 'Failed to install socat'; exit 1; }
    fi
}

# Allow port 80 with ufw
allow_port_80() {
    if sudo ufw status | grep -q active; then
        sudo ufw allow 80 || { echo 'Failed to allow port 80'; exit 1; }
    fi
}

# Install and configure ACME
install_acme() {
    curl https://get.acme.sh | sudo sh || { echo 'Failed to install ACME.sh'; exit 1; }
    ~/.acme.sh/acme.sh --upgrade --auto-upgrade || { echo 'Failed to set up ACME.sh auto-upgrade'; exit 1; }
    ~/.acme.sh/acme.sh --set-default-ca --server letsencrypt || { echo 'Failed to set default CA to Let’s Encrypt'; exit 1; }
}

# Apply and install SSL certificate
apply_install_ssl() {
    local domain_name=$1
    local cert_dir="/etc/ssl/${domain_name}"
    mkdir -p "${cert_dir}"
    
    ~/.acme.sh/acme.sh --issue -d "$domain_name" --standalone --keylength ec-256 || { echo 'Failed to issue certificate'; exit 1; }
    ~/.acme.sh/acme.sh --install-cert -d "$domain_name" --ecc \
        --fullchain-file "${cert_dir}/${domain_name}_fullchain.cer" \
        --key-file "${cert_dir}/${domain_name}_private.key" || { echo 'Failed to install certificate'; exit 1; }
    
    sudo chown -R nobody:nogroup "${cert_dir}" || { echo 'Failed to change owner and group of ${cert_dir}'; exit 1; }
    echo "SSL certificate obtained and installed for $domain_name."
}

# Function to revoke and clean SSL certificate
revoke_ssl() {
    local domain_name=$1
    local cert_dir="/etc/ssl/${domain_name}"

    ~/.acme.sh/acme.sh --revoke -d "$domain_name" --ecc || { echo 'Failed to revoke certificate for $domain_name'; return 1; }
    if [ -d "$cert_dir" ]; then
        sudo rm -rf "$cert_dir"
        echo "Removed certificate directory for $domain_name."
    else
        echo "Certificate directory for $domain_name does not exist."
    fi
    ~/.acme.sh/acme.sh --remove -d "$domain_name" --ecc || { echo 'Failed to remove certificate data for $domain_name'; return 1; }
    echo "SSL certificate revoked and cleaned for $domain_name."
}

# Function to force renew SSL certificate
force_renew_ssl() {
    local domain_name=$1
    local cert_dir="/etc/ssl/${domain_name}"

    ~/.acme.sh/acme.sh --renew -d "$domain_name" --force --ecc || { echo 'Failed to renew certificate for $domain_name'; return 1; }
    ~/.acme.sh/acme.sh --install-cert -d "$domain_name" --ecc \
        --fullchain-file "${cert_dir}/${domain_name}_fullchain.cer" \
        --key-file "${cert_dir}/${domain_name}_private.key" || { echo 'Failed to install renewed certificate'; return 1; }

    echo "SSL certificate forcefully renewed for $domain_name."
}

# Main function
main() {
    check_root
    
    while true; do
        echo "Choose an option:"
        echo "1. Get SSL"
        echo "2. Revoke SSL"
        echo "3. Force Renew SSL"
        echo "4. Exit"
        read -p "Enter choice [1-4]: " choice

        case $choice in
            1)
                read -p "Enter your domain name (e.g., my.example.com): " domain_name
                if validate_domain "$domain_name"; then
                    install_socat
                    sleep 0.5
                    allow_port_80
                    sleep 0.5
                    install_acme
                    sleep 0.5
                    apply_install_ssl "$domain_name"
                    sleep 0.5
                else
                    echo "Invalid domain name. Please enter a valid domain name."
                fi
                ;;
            2)
                read -p "Enter the domain name of the SSL to revoke (e.g., my.example.com): " domain_name
                if validate_domain "$domain_name"; then
                    revoke_ssl "$domain_name"
                    sleep 0.5
                else
                    echo "Invalid domain name. Please enter a valid domain name."
                fi
                ;;
            3)
                read -p "Enter the domain name for the SSL to force renew (e.g., my.example.com): " domain_name
                if validate_domain "$domain_name"; then
                    force_renew_ssl "$domain_name"
                    sleep 0.5
                else
                    echo "Invalid domain name. Please enter a valid domain name."
                fi
                ;;
            4)
                echo "Exiting script."
                exit 0
                ;;
            *)
                echo "Invalid choice, please choose between 1 and 4."
                ;;
        esac
    done
}

# Run main function
main "$@"
