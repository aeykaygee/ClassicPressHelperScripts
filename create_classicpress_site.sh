#!/bin/bash

# Exit on error, but allow for cleanup
set -e

# Set up logging
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
LOG_DIR="/var/log/classicpress-install"
mkdir -p "$LOG_DIR"
INSTALL_LOG="$LOG_DIR/install_$(date +%Y%m%d_%H%M%S).log"
ERROR_LOG="$LOG_DIR/error_$(date +%Y%m%d_%H%M%S).log"

# Function to log messages
log_message() {
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    echo "[$timestamp] $1" | tee -a "$INSTALL_LOG"
}

# Function to log errors
log_error() {
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    echo "[$timestamp] ERROR: $1" | tee -a "$ERROR_LOG" >&2
}

# Function to check command status
check_command() {
    if [ $? -ne 0 ]; then
        log_error "$1 failed"
        cleanup "$DOMAIN"
    else
        log_message "$1 completed successfully"
    fi
}

# Check if script is run as root
if [[ $EUID -ne 0 ]]; then
   log_error "This script must be run as root or with sudo"
   exit 1
fi

# Function to generate random string for passwords
generate_password() {
    openssl rand -base64 16 | tr -dc 'a-zA-Z0-9' | head -c 16
}

# Function to validate domain name format
validate_domain() {
    if [[ ! $1 =~ ^[a-zA-Z0-9][a-zA-Z0-9-]{1,61}[a-zA-Z0-9]\.[a-zA-Z]{2,}$ ]]; then
        log_error "Invalid domain name format. Please use format like: example.com"
        exit 1
    fi
}

# Function to verify database connection
verify_db_connection() {
    local db_name=$1
    local db_user=$2
    local db_pass=$3
    
    log_message "Verifying database connection for $db_name"
    if mysql -u "$db_user" -p"$db_pass" -e "USE $db_name;" 2>/dev/null; then
        log_message "Database connection successful"
        return 0
    else
        log_error "Could not connect to database $db_name"
        return 1
    fi
}

# Function to verify service status
check_service_status() {
    local service_name=$1
    if systemctl is-active --quiet "$service_name"; then
        log_message "$service_name is running"
        return 0
    else
        log_error "$service_name is not running"
        return 1
    fi
}

# Function to cleanup on failure
cleanup() {
    local domain=$1
    log_message "Starting cleanup for failed installation of $domain"
    
    # Remove database and user
    log_message "Removing database and user"
    mysql -e "DROP DATABASE IF EXISTS \`$DB_NAME\`;" 2>> "$ERROR_LOG"
    mysql -e "DROP USER IF EXISTS '$DB_USER'@'localhost';" 2>> "$ERROR_LOG"
    
    # Remove website directory
    log_message "Removing website directory"
    rm -rf "/var/www/$domain" 2>> "$ERROR_LOG"
    
    # Remove Nginx configs
    log_message "Removing Nginx configurations"
    rm -f "/etc/nginx/sites-available/$domain.conf" 2>> "$ERROR_LOG"
    rm -f "/etc/nginx/sites-enabled/$domain.conf" 2>> "$ERROR_LOG"
    
    log_message "Cleanup completed"
    
    # Archive logs
    local archive_dir="$LOG_DIR/failed_installs"
    mkdir -p "$archive_dir"
    local archive_name="${archive_dir}/${domain}_$(date +%Y%m%d_%H%M%S)"
    cp "$INSTALL_LOG" "${archive_name}_install.log"
    cp "$ERROR_LOG" "${archive_name}_error.log"
    
    exit 1
}

# Verify required services are installed and running
log_message "Verifying required services..."
for service in nginx mysql php8.1-fpm; do
    if ! systemctl is-active --quiet $service; then
        log_error "$service is not running"
        exit 1
    fi
done

# Prompt for necessary information
log_message "Starting ClassicPress installation process"
read -p "Enter domain name (e.g., example.com): " DOMAIN
validate_domain "$DOMAIN"

read -p "Enter site title: " SITE_TITLE
read -p "Enter admin email: " ADMIN_EMAIL
read -p "Enter admin username: " ADMIN_USER

# Generate random passwords
log_message "Generating passwords and database credentials"
DB_PASSWORD=$(generate_password)
ADMIN_PASSWORD=$(generate_password)
DB_NAME=$(echo "${DOMAIN/./_}" | tr '-' '_' | cut -c 1-32)
DB_USER=$(echo "${DOMAIN/./_}" | tr '-' '_' | cut -c 1-16)

# Create website directory
log_message "Creating website directory at /var/www/$DOMAIN"
SITE_DIR="/var/www/$DOMAIN"
mkdir -p "$SITE_DIR"
check_command "Directory creation"

# Check for pre-downloaded ClassicPress
CLASSICPRESS_ZIP="/usr/local/share/classicpress/classicpress.zip"
if [ ! -f "$CLASSICPRESS_ZIP" ]; then
    log_error "ClassicPress installation file not found at $CLASSICPRESS_ZIP"
    log_error "Please run install_classicpress_requirements.sh first"
    exit 1
fi

# Extract ClassicPress
log_message "Extracting ClassicPress from $CLASSICPRESS_ZIP..."
rm -rf "$SITE_DIR"/* 2>> "$ERROR_LOG"
unzip -q "$CLASSICPRESS_ZIP" -d /tmp/cp-temp 2>> "$ERROR_LOG"
mv /tmp/cp-temp/*/* "$SITE_DIR/" 2>> "$ERROR_LOG"
rm -rf /tmp/cp-temp
check_command "ClassicPress extraction"

# Set permissions
log_message "Setting file permissions..."
chown -R www-data:www-data "$SITE_DIR"
find "$SITE_DIR" -type d -exec chmod 755 {} \;
find "$SITE_DIR" -type f -exec chmod 644 {} \;
check_command "Permission setting"

# Create database and user
log_message "Creating database and user..."
{
    mysql -e "DROP DATABASE IF EXISTS \`$DB_NAME\`;"
    mysql -e "DROP USER IF EXISTS '$DB_USER'@'localhost';"
    mysql -e "CREATE DATABASE \`$DB_NAME\` DEFAULT CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;"
    mysql -e "CREATE USER '$DB_USER'@'localhost' IDENTIFIED BY '$DB_PASSWORD';"
    mysql -e "GRANT ALL PRIVILEGES ON \`$DB_NAME\`.* TO '$DB_USER'@'localhost';"
    mysql -e "FLUSH PRIVILEGES;"
} 2>> "$ERROR_LOG"
check_command "Database creation"

# Verify database connection
log_message "Verifying database connection..."
if ! verify_db_connection "$DB_NAME" "$DB_USER" "$DB_PASSWORD"; then
    log_error "Database connection failed"
    cleanup "$DOMAIN"
fi

# Create Nginx configuration
log_message "Creating Nginx configuration..."

# Remove default Nginx configuration
log_message "Checking for default Nginx configuration..."
if [ -f "/etc/nginx/sites-enabled/default" ]; then
    log_message "Removing default Nginx configuration..."
    rm -f "/etc/nginx/sites-enabled/default" 2>> "$ERROR_LOG"
fi

# Remove existing site configuration if it exists
log_message "Checking for existing site configuration..."
if [ -f "/etc/nginx/sites-enabled/$DOMAIN.conf" ]; then
    log_message "Removing existing Nginx configuration from sites-enabled..."
    rm -f "/etc/nginx/sites-enabled/$DOMAIN.conf" 2>> "$ERROR_LOG"
fi

if [ -f "/etc/nginx/sites-available/$DOMAIN.conf" ]; then
    log_message "Removing existing Nginx configuration from sites-available..."
    rm -f "/etc/nginx/sites-available/$DOMAIN.conf" 2>> "$ERROR_LOG"
fi

# Create new configuration
cat > "/etc/nginx/sites-available/$DOMAIN.conf" << EOL
# Main server block for $DOMAIN
server {
    listen 80 default_server;
    listen [::]:80 default_server;
    
    server_name $DOMAIN www.$DOMAIN;
    root $SITE_DIR;
    
    index index.php index.html index.htm;
    
    access_log /var/log/nginx/${DOMAIN}.access.log;
    error_log /var/log/nginx/${DOMAIN}.error.log;
    
    location / {
        try_files \$uri \$uri/ /index.php?\$args;
    }
    
    location ~ \.php$ {
        include snippets/fastcgi-php.conf;
        fastcgi_pass unix:/var/run/php/php8.1-fpm.sock;
        fastcgi_param SCRIPT_FILENAME \$document_root\$fastcgi_script_name;
        include fastcgi_params;
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
check_command "Nginx configuration creation"

# Enable site configuration
log_message "Enabling site configuration..."
ln -sf "/etc/nginx/sites-available/$DOMAIN.conf" "/etc/nginx/sites-enabled/"
check_command "Site configuration enabling"

# Verify Nginx configuration files
log_message "Verifying Nginx configuration files..."
ls -la /etc/nginx/sites-enabled/ >> "$INSTALL_LOG" 2>> "$ERROR_LOG"
ls -la /etc/nginx/sites-available/ >> "$INSTALL_LOG" 2>> "$ERROR_LOG"

# Test Nginx configuration
log_message "Testing Nginx configuration..."
nginx -t 2>> "$ERROR_LOG"
check_command "Nginx configuration test"

# Create wp-config.php
log_message "Creating wp-config.php..."
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
check_command "wp-config.php creation"

# Set proper permissions for wp-config.php
chmod 600 "$SITE_DIR/wp-config.php"
chown www-data:www-data "$SITE_DIR/wp-config.php"
check_command "wp-config.php permissions"

# Configure ClassicPress using WP-CLI
log_message "Configuring ClassicPress with provided admin information..."
cd "$SITE_DIR"
sudo -u www-data wp core install \
    --url="http://$DOMAIN" \
    --title="$SITE_TITLE" \
    --admin_user="$ADMIN_USER" \
    --admin_password="$ADMIN_PASSWORD" \
    --admin_email="$ADMIN_EMAIL" \
    --skip-email 2>> "$ERROR_LOG"
check_command "ClassicPress core installation"

# Restart services
log_message "Restarting services..."
systemctl restart php8.1-fpm
check_command "PHP-FPM restart"
systemctl restart nginx
check_command "Nginx restart"

# Verify services are running
for service in nginx php8.1-fpm mysql; do
    check_service_status $service || cleanup "$DOMAIN"
done

# Save configuration information
log_message "Saving configuration information..."
CONFIG_DIR="/root/classicpress-configs"
mkdir -p "$CONFIG_DIR"
INFO_FILE="$CONFIG_DIR/classicpress_${DOMAIN}_info.txt"

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
    echo ""
    echo "Log Files:"
    echo "Install Log: $INSTALL_LOG"
    echo "Error Log: $ERROR_LOG"
    echo ""
    echo "Created: $(date)"
} > "$INFO_FILE"

chmod 600 "$INFO_FILE"
check_command "Configuration saving"

# Final success message
log_message "Installation completed successfully!"
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
echo "Configuration saved to: $INFO_FILE"
echo "Install Log: $INSTALL_LOG"
echo "Error Log: $ERROR_LOG"
echo ""
echo "Next Steps:"
echo "1. Point your domain's DNS A record to your server's IP address"
echo "2. Visit http://$DOMAIN to complete the installation"
echo ""
log_message "Script execution completed" 