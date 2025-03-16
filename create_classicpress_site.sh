#!/bin/bash

# Exit on error
set -e

# Check if script is run as root
if [[ $EUID -ne 0 ]]; then
   echo "This script must be run as root or with sudo"
   exit 1
fi

# Function to generate random string for passwords
generate_password() {
    openssl rand -base64 16 | tr -dc 'a-zA-Z0-9' | head -c 16
}

# Function to validate domain name format
validate_domain() {
    if [[ ! $1 =~ ^[a-zA-Z0-9][a-zA-Z0-9-]{1,61}[a-zA-Z0-9]\.[a-zA-Z]{2,}$ ]]; then
        echo "Invalid domain name format. Please use format like: example.com"
        exit 1
    fi
}

# Prompt for necessary information
read -p "Enter domain name (e.g., example.com): " DOMAIN
validate_domain "$DOMAIN"

read -p "Enter site title: " SITE_TITLE
read -p "Enter admin email: " ADMIN_EMAIL
read -p "Enter admin username: " ADMIN_USER

# Generate random passwords
DB_PASSWORD=$(generate_password)
ADMIN_PASSWORD=$(generate_password)
DB_NAME=$(echo "${DOMAIN/./_}" | tr '-' '_' | cut -c 1-32)
DB_USER=$(echo "${DOMAIN/./_}" | tr '-' '_' | cut -c 1-16)

echo "Creating website directory..."
SITE_DIR="/var/www/$DOMAIN"
mkdir -p "$SITE_DIR"

# Download latest ClassicPress
echo "Downloading ClassicPress..."
wget https://www.classicpress.net/latest.zip -O /tmp/classicpress.zip
unzip -q /tmp/classicpress.zip -d "$SITE_DIR"
mv "$SITE_DIR/classicpress/"* "$SITE_DIR/"
rmdir "$SITE_DIR/classicpress"
rm /tmp/classicpress.zip

# Set permissions
echo "Setting permissions..."
chown -R www-data:www-data "$SITE_DIR"
find "$SITE_DIR" -type d -exec chmod 755 {} \;
find "$SITE_DIR" -type f -exec chmod 644 {} \;

# Create database and user
echo "Creating database and user..."
mysql -e "CREATE DATABASE IF NOT EXISTS \`$DB_NAME\` DEFAULT CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;"
mysql -e "CREATE USER IF NOT EXISTS '$DB_USER'@'localhost' IDENTIFIED BY '$DB_PASSWORD';"
mysql -e "GRANT ALL PRIVILEGES ON \`$DB_NAME\`.* TO '$DB_USER'@'localhost';"
mysql -e "FLUSH PRIVILEGES;"

# Create Nginx configuration
echo "Creating Nginx configuration..."
cat > "/etc/nginx/sites-available/$DOMAIN.conf" << EOL
server {
    listen 80;
    listen [::]:80;
    
    server_name $DOMAIN www.$DOMAIN;
    root $SITE_DIR;
    
    index index.php index.html index.htm;
    
    location / {
        try_files \$uri \$uri/ /index.php?\$args;
    }
    
    location ~ \.php$ {
        include snippets/fastcgi-php.conf;
        fastcgi_pass unix:/var/run/php/php8.1-fpm.sock;
    }
    
    location ~ /\.ht {
        deny all;
    }
    
    location = /favicon.ico {
        log_not_found off;
        access_log off;
    }
    
    location = /robots.txt {
        log_not_found off;
        access_log off;
        allow all;
    }
    
    location ~* \.(css|gif|ico|jpeg|jpg|js|png)$ {
        expires max;
        log_not_found off;
    }
}
EOL

# Enable the site
ln -sf "/etc/nginx/sites-available/$DOMAIN.conf" "/etc/nginx/sites-enabled/"

# Create wp-config.php
echo "Creating wp-config.php..."
cat > "$SITE_DIR/wp-config.php" << EOL
<?php
define('DB_NAME', '$DB_NAME');
define('DB_USER', '$DB_USER');
define('DB_PASSWORD', '$DB_PASSWORD');
define('DB_HOST', 'localhost');
define('DB_CHARSET', 'utf8mb4');
define('DB_COLLATE', '');

define('AUTH_KEY',         '$(generate_password)');
define('SECURE_AUTH_KEY',  '$(generate_password)');
define('LOGGED_IN_KEY',    '$(generate_password)');
define('NONCE_KEY',        '$(generate_password)');
define('AUTH_SALT',        '$(generate_password)');
define('SECURE_AUTH_SALT', '$(generate_password)');
define('LOGGED_IN_SALT',   '$(generate_password)');
define('NONCE_SALT',       '$(generate_password)');

\$table_prefix = 'wp_';

define('WP_DEBUG', false);

if ( !defined('ABSPATH') )
    define('ABSPATH', dirname(__FILE__) . '/');

require_once(ABSPATH . 'wp-settings.php');
EOL

# Set proper permissions for wp-config.php
chmod 600 "$SITE_DIR/wp-config.php"
chown www-data:www-data "$SITE_DIR/wp-config.php"

# Restart Nginx
systemctl restart nginx

# Output important information
echo ""
echo "ClassicPress site has been set up successfully!"
echo "=============================================="
echo "Domain: $DOMAIN"
echo "Site Directory: $SITE_DIR"
echo ""
echo "Database Information:"
echo "Database Name: $DB_NAME"
echo "Database User: $DB_USER"
echo "Database Password: $DB_PASSWORD"
echo ""
echo "Admin Information:"
echo "Username: $ADMIN_USER"
echo "Password: $ADMIN_PASSWORD"
echo "Email: $ADMIN_EMAIL"
echo ""
echo "Next Steps:"
echo "1. Point your domain's DNS A record to your server's IP address"
echo "2. Consider installing SSL certificate using Let's Encrypt"
echo "3. Visit http://$DOMAIN to complete the installation"
echo ""
echo "Would you like to save this information to a file? (y/n)"
read -r SAVE_INFO

if [[ $SAVE_INFO =~ ^[Yy]$ ]]; then
    INFO_FILE="/root/classicpress_${DOMAIN}_info.txt"
    {
        echo "ClassicPress Site Information"
        echo "=========================="
        echo "Domain: $DOMAIN"
        echo "Site Directory: $SITE_DIR"
        echo ""
        echo "Database Information:"
        echo "Database Name: $DB_NAME"
        echo "Database User: $DB_USER"
        echo "Database Password: $DB_PASSWORD"
        echo ""
        echo "Admin Information:"
        echo "Username: $ADMIN_USER"
        echo "Password: $ADMIN_PASSWORD"
        echo "Email: $ADMIN_EMAIL"
    } > "$INFO_FILE"
    chmod 600 "$INFO_FILE"
    echo "Information saved to $INFO_FILE"
fi 