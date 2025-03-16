#!/bin/bash

# Exit on error
set -e

echo "Starting installation of ClassicPress requirements..."

# Update system
echo "Updating system packages..."
sudo apt update
sudo apt upgrade -y

# Install Nginx
echo "Installing Nginx..."
sudo apt install nginx -y

# Install MariaDB
echo "Installing MariaDB..."
sudo apt install mariadb-server mariadb-client -y

# Install PHP and required extensions
echo "Installing PHP and required extensions..."
sudo apt install php8.1-fpm php8.1-common php8.1-mysql \
    php8.1-xml php8.1-xmlrpc php8.1-curl php8.1-gd \
    php8.1-imagick php8.1-cli php8.1-dev php8.1-imap \
    php8.1-mbstring php8.1-opcache php8.1-soap \
    php8.1-zip php8.1-intl -y

# Install additional tools
echo "Installing additional tools..."
sudo apt install wget unzip curl -y

# Secure MariaDB installation
echo "Securing MariaDB installation..."
echo "Please run 'sudo mysql_secure_installation' after this script completes to secure your MariaDB installation."

# Create directory for websites
echo "Creating websites directory..."
sudo mkdir -p /var/www/

# Set proper permissions
echo "Setting proper permissions..."
sudo chown -R www-data:www-data /var/www/
sudo chmod -R 755 /var/www/

# Start and enable services
echo "Starting and enabling services..."
sudo systemctl start nginx
sudo systemctl enable nginx
sudo systemctl start mariadb
sudo systemctl enable mariadb
sudo systemctl start php8.1-fpm
sudo systemctl enable php8.1-fpm

# Create basic Nginx configuration template for ClassicPress sites
echo "Creating Nginx configuration template..."
sudo tee /etc/nginx/sites-available/classicpress-template.conf > /dev/null << 'EOL'
server {
    listen 80;
    listen [::]:80;
    
    # Replace with your domain name
    server_name example.com www.example.com;
    
    # Replace with your website root directory
    root /var/www/example.com;
    
    index index.php index.html index.htm;
    
    location / {
        try_files $uri $uri/ /index.php?$args;
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

echo "Installation completed!"
echo ""
echo "Next steps:"
echo "1. Run 'sudo mysql_secure_installation' to secure your MariaDB installation"
echo "2. For each new ClassicPress site:"
echo "   a. Create a new directory in /var/www/"
echo "   b. Copy and modify the Nginx template from /etc/nginx/sites-available/classicpress-template.conf"
echo "   c. Create a new database and database user"
echo "   d. Download and install ClassicPress"
echo ""
echo "Remember to:"
echo "- Configure PHP settings in /etc/php/8.1/fpm/php.ini if needed"
echo "- Adjust Nginx settings in /etc/nginx/nginx.conf if needed"
echo "- Set up SSL certificates for your domains" 