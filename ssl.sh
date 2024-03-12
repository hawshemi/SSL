#!/bin/bash


# Function for green messages
green_msg() {
    echo -e "\033[0;32m[*] ----- $1\033[0m" # Green
}


# Function for red messages
red_msg() {
    echo -e "\033[0;31m[*] ----- $1\033[0m" # Red
}


# Intro
echo 
green_msg '================================================================='
green_msg 'This script will automatically Obtain, Revoke, Renew your SSL Certificate.'
green_msg 'Tested on: Ubuntu 20+, Debian 11+'
green_msg 'Root access is required.' 
green_msg 'Source is @ https://github.com/hawshemi/ssl' 
green_msg '================================================================='
echo 


# Check if script is run as root
check_root() {
    if [ "$(id -u)" != "0" ]; then
        red_msg "Error: This script must be run as root."
        sleep 0.5
        exit 1
    else
        green_msg "Running as root, continuing..."
        sleep 0.5
    fi
}


# Validate domain format
validate_domain() {
    if [[ $1 =~ ^([a-zA-Z0-9]([a-zA-Z0-9\-]{0,61}[a-zA-Z0-9])?\.)+[a-zA-Z]{2,}$ ]]; then
        green_msg "Domain validation passed for: $1"
        sleep 0.5
        return 0
    else
        red_msg "Validation Error: The domain '$1' is not in a valid format."
        sleep 0.5
        return 1
    fi
}

# Install socat if it's not already installed
install_socat() {
    if ! command -v socat &> /dev/null; then
        sudo apt update -q
        sudo apt install -y socat || red_msg "Failed to install socat."
        sleep 0.5
    else
        green_msg "Socat is already installed."
        sleep 0.5
    fi
}

# Allow port 80 with ufw
allow_port_80() {
    if sudo ufw status | grep -q active; then
        sudo ufw allow 80 || red_msg "Failed to allow port 80."
        sleep 0.5
    else
        green_msg "Port 80 is already allowed."
        sleep 0.5
    fi
}

# Install and configure ACME
install_acme() {
    curl https://get.acme.sh | sudo sh || red_msg "Failed to install ACME.sh."
    sleep 0.5
    ~/.acme.sh/acme.sh --upgrade --auto-upgrade || red_msg "Failed to set up ACME.sh auto-upgrade."
    sleep 0.5
    ~/.acme.sh/acme.sh --set-default-ca --server letsencrypt || red_msg "Failed to set default CA to Let’s Encrypt."
    sleep 0.5
}

# Apply and install SSL certificate
apply_install_ssl() {
    local domain_name=$1
    local cert_dir="/etc/ssl/${domain_name}"
    mkdir -p "${cert_dir}" || red_msg "Failed to create certificate directory for $domain_name."
    sleep 0.5

    ~/.acme.sh/acme.sh --issue -d "$domain_name" --standalone --keylength ec-256 || red_msg "Failed to issue certificate for $domain_name."
    sleep 0.5

    ~/.acme.sh/acme.sh --install-cert -d "$domain_name" --ecc \
        --fullchain-file "${cert_dir}/${domain_name}_fullchain.cer" \
        --key-file "${cert_dir}/${domain_name}_private.key" || red_msg "Failed to install certificate for $domain_name."
    sleep 0.5

    sudo chown -R nobody:nogroup "${cert_dir}" || red_msg "Failed to change owner and group of ${cert_dir}."
    sleep 0.5
    
    echo 
    echo 
    echo 
    green_msg "SSL certificate obtained and installed for $domain_name."
    echo 
    green_msg "Fullchain:    ${cert_dir}/${domain_name}_fullchain.cer"
    green_msg "Private:      ${cert_dir}/${domain_name}_private.key"

    sleep 0.5
}

# Function to revoke and clean SSL certificate
revoke_ssl() {
    local domain_name=$1
    local cert_dir="/etc/ssl/${domain_name}"

    ~/.acme.sh/acme.sh --revoke -d "$domain_name" --ecc || red_msg "Failed to revoke certificate for $domain_name."
    if [ -d "$cert_dir" ]; then
        sudo rm -rf "$cert_dir" || red_msg "Failed to remove certificate directory for $domain_name."
        green_msg "Removed certificate directory for $domain_name."
        sleep 0.5
    else
        green_msg "Certificate directory for $domain_name does not exist, no need to remove."
        sleep 0.5
    fi
    ~/.acme.sh/acme.sh --remove -d "$domain_name" --ecc || red_msg "Failed to remove certificate data for $domain_name."
    green_msg "SSL certificate revoked and cleaned for $domain_name."
    sleep 0.5
}

# Function to force renew SSL certificate
force_renew_ssl() {
    local domain_name=$1
    local cert_dir="/etc/ssl/${domain_name}"

    ~/.acme.sh/acme.sh --renew -d "$domain_name" --force --ecc || red_msg "Failed to renew certificate for $domain_name."
    sleep 0.5

    ~/.acme.sh/acme.sh --install-cert -d "$domain_name" --ecc \
        --fullchain-file "${cert_dir}/${domain_name}_fullchain.cer" \
        --key-file "${cert_dir}/${domain_name}_private.key" || red_msg "Failed to install renewed certificate for $domain_name."
    green_msg "SSL certificate forcefully renewed for $domain_name."
    sleep 0.5
}

# Main function
main() {
    check_root

    while true; do
        echo -e "\nChoose an option:"
        echo "1. Get SSL"
        echo "2. Revoke SSL"
        echo "3. Force Renew SSL"
        echo "q. Exit"
        read -p "Enter choice: " choice

        case $choice in
            1)
                read -p "Enter your domain name (e.g., my.example.com): " domain_name
                if validate_domain "$domain_name"; then
                    install_socat
                    allow_port_80
                    install_acme
                    apply_install_ssl "$domain_name"
                else
                    red_msg "Invalid domain name. Please enter a valid domain name."
                fi
                ;;
            2)
                read -p "Enter the domain name of the SSL to revoke (e.g., my.example.com): " domain_name
                if validate_domain "$domain_name"; then
                    revoke_ssl "$domain_name"
                else
                    red_msg "Invalid domain name. Please enter a valid domain name."
                fi
                ;;
            3)
                read -p "Enter the domain name for the SSL to force renew (e.g., my.example.com): " domain_name
                if validate_domain "$domain_name"; then
                    force_renew_ssl "$domain_name"
                else
                    red_msg "Invalid domain name. Please enter a valid domain name."
                fi
                ;;
            q)
                green_msg "Script Exited."
                exit 0
                ;;
            *)
                red_msg "Invalid choice, please choose from the list."
                ;;
        esac
    done
}

# Run main function
main "$@"
