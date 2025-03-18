# ClassicPress Site Setup Script

This script automates the installation and configuration of a ClassicPress site on a fresh Ubuntu/Debian server. It handles everything from installing required packages to configuring Nginx, MariaDB, PHP, and ClassicPress itself.

## Prerequisites

- Ubuntu 20.04/22.04 or Debian 11/12
- Root access or sudo privileges
- A domain name pointed to your server's IP address

## Configuration

Before running the script, edit the configuration variables at the top of `setup_classicpress.sh`:

```bash
# Configuration Variables - UPDATE THESE VALUES
DOMAIN="example.com"              # Your domain name
SITE_TITLE="My ClassicPress Site" # Your site title
ADMIN_EMAIL="admin@example.com"   # Admin email address
ADMIN_USER="admin"               # Admin username
ADMIN_PASSWORD="change-this-password" # Admin password
DB_PASSWORD="change-this-db-password" # Database password
```

## Usage

1. Clone this repository:
   ```bash
   git clone [repository-url]
   cd [repository-name]
   ```

2. Update the configuration variables in `setup_classicpress.sh`

3. Make the script executable:
   ```bash
   chmod +x setup_classicpress.sh
   ```

4. Run the script:
   ```bash
   sudo ./setup_classicpress.sh
   ```

## What the Script Does

1. Installs required packages (Nginx, MariaDB, PHP, etc.)
2. Downloads and installs ClassicPress
3. Creates and configures the database
4. Sets up Nginx configuration
5. Configures ClassicPress with the provided settings
6. Sets appropriate file permissions
7. Creates detailed logs and configuration backups

## File Locations

- Website files: `/var/www/[domain]`
- Nginx config: `/etc/nginx/sites-available/[domain].conf`
- Install log: `/var/log/classicpress-install/install_[timestamp].log`
- Error log: `/var/log/classicpress-install/error_[timestamp].log`
- Site info: `/root/classicpress-configs/classicpress_[domain]_info.txt`

## Security Notes

1. Change the default passwords in the configuration
2. Secure your MariaDB installation after script completion:
   ```bash
   sudo mysql_secure_installation
   ```
3. Consider setting up SSL/HTTPS using Let's Encrypt
4. Review and adjust file permissions if needed

## Troubleshooting

Check the following logs for issues:
- Installation log: `/var/log/classicpress-install/install_[timestamp].log`
- Error log: `/var/log/classicpress-install/error_[timestamp].log`
- Nginx error log: `/var/log/nginx/error.log`
- PHP-FPM error log: `/var/log/php8.1-fpm.log`

## License

MIT License 