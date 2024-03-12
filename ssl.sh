#!/bin/bash


# Define colour codes
RED='\033[0;31m'
GREEN='\033[0;32m'
NC='\033[0m' # No Color


# Check if the script is run as root
check_root() {
    if [ "$(id -u)" != "0" ]; then
        echo -e "${RED}This script must be run as root.${NC}" 1>&2
        exit 1
    fi
}


# Validate domain format
validate_domain() {
    if [[ $1 =~ ^([a-zA-Z0-9]([a-zA-Z0-9\-]{0,61}[a-zA-Z0-9])?\.)+[a-zA-Z]{2,}$ ]]; then
        echo -e "${GREEN}Domain validation passed for: $1${NC}"
        return 0
    else
        echo -e "${RED}Validation Error: The domain '$1' is not in a valid format.${NC}"
        return 1
    fi
}


# Install socat if it's not already installed
install_socat() {
    if ! command -v socat &> /dev/null; then
        sudo apt update
        sudo apt install -y socat || { echo -e "${RED}Failed to install socat.${NC}" 1>&2; exit 2; }
    fi
}


# Allow port 80 with UFW
allow_port_80() {
    if sudo ufw status | grep -q active; then
        sudo ufw allow 80 || { echo -e "${RED}Failed to allow port 80.${NC}" 1>&2; exit 3; }
    fi
}


# Install and configure ACME
install_acme() {
    curl https://get.acme.sh | sudo sh || { echo -e "${RED}Failed to install ACME.sh.${NC}" 1>&2; exit 4; }
    ~/.acme.sh/acme.sh --upgrade --auto-upgrade || { echo -e "${RED}Failed to set up ACME.sh auto-upgrade.${NC}" 1>&2; exit 5; }
    ~/.acme.sh/acme.sh --set-default-ca --server letsencrypt || { echo -e "${RED}Failed to set default CA to Let’s Encrypt.${NC}" 1>&2; exit 6; }
}


# Apply and install the SSL certificate
apply_install_ssl() {
    local domain_name=$1
    local cert_dir="/etc/ssl/${domain_name}"
    mkdir -p "${cert_dir}"
    
    ~/.acme.sh/acme.sh --issue -d "$domain_name" --standalone --keylength ec-256 || { echo -e "${RED}Failed to issue certificate for $domain_name.${NC}" 1>&2; exit 7; }
    ~/.acme.sh/acme.sh --install-cert -d "$domain_name" --ecc \
        --fullchain-file "${cert_dir}/${domain_name}_fullchain.cer" \
        --key-file "${cert_dir}/${domain_name}_private.key" || { echo -e "${RED}Failed to install certificate for $domain_name.${NC}" 1>&2; exit 8; }
    
    sudo chown -R nobody:nogroup "${cert_dir}" || { echo -e "${RED}Failed to change owner and group of ${cert_dir}.${NC}" 1>&2; exit 9; }
    echo -e "${GREEN}SSL certificate obtained and installed for $domain_name.${NC}"
}


# Function to revoke and clean SSL certificate
revoke_ssl() {
    local domain_name=$1
    local cert_dir="/etc/ssl/${domain_name}"

    ~/.acme.sh/acme.sh --revoke -d "$domain_name" --ecc || { echo -e "${RED}Failed to revoke certificate for $domain_name.${NC}" 1>&2; return 1; }
    if [ -d "$cert_dir" ]; then
        sudo rm -rf "$cert_dir"
        echo "Removed certificate directory for $domain_name."
    else
        echo "Certificate directory for $domain_name does not exist."
    fi
    ~/.acme.sh/acme.sh --remove -d "$domain_name" --ecc || { echo -e "${RED}Failed to remove certificate data for $domain_name.${NC}" 1>&2; return 1; }
    echo -e "${GREEN}SSL certificate revoked and cleaned for $domain_name.${NC}"
}


# Function to force renewal of SSL certificate
force_renew_ssl() {
    local domain_name=$1
    local cert_dir="/etc/ssl/${domain_name}"

    ~/.acme.sh/acme.sh --renew -d "$domain_name" --force --ecc || { echo -e "${RED}Failed to renew certificate for $domain_name.${NC}" 1>&2; return 1; }
    ~/.acme.sh/acme.sh --install-cert -d "$domain_name" --ecc \
        --fullchain-file "${cert_dir}/${domain_name}_fullchain.cer" \
        --key-file "${cert_dir}/${domain_name}_private.key" || { echo -e "${RED}Failed to install renewed certificate for $domain_name.${NC}" 1>&2; return 1; }

    echo -e "${GREEN}SSL certificate forcefully renewed for $domain_name.${NC}"
}


# Main function
main() {
    check_root
    
    while true; do
        echo -e "\n${GREEN}Choose an option:${NC}"
        echo "1. Get SSL"
        echo "2. Revoke SSL"
        echo "3. Force SSL Renewal"
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
                    echo -e "${RED}Invalid domain name. Please enter a valid domain name.${NC}"
                fi
                ;;
            2)
                read -p "Enter the domain name of the SSL to revoke (e.g., my.example.com): " domain_name
                if validate_domain "$domain_name"; then
                    revoke_ssl "$domain_name"
                    sleep 0.5
                else
                    echo -e "${RED}Invalid domain name. Please enter a valid domain name.${NC}"
                fi
                ;;
            3)
                read -p "Enter the domain name for the SSL to force renewal (e.g., my.example.com): " domain_name
                if validate_domain "$domain_name"; then
                    force_renew_ssl "$domain_name"
                    sleep 0.5
                else
                    echo -e "${RED}Invalid domain name. Please enter a valid domain name.${NC}"
                fi
                ;;
            4)
                echo -e "${GREEN}Exiting script. Thank you for using SSL Management.${NC}"
                exit 0
                ;;
            *)
                echo -e "${RED}Invalid choice, please choose between 1 and 4.${NC}"
                ;;
        esac
    done
}


# Run the main function
main "$@"
