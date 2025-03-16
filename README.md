# ClassicPress Multi-Site Installation Script

This repository contains scripts to help set up multiple ClassicPress websites on Ubuntu 22.04 LTS using Nginx and MariaDB.

## Requirements

- Ubuntu 22.04 LTS
- Root or sudo access

## Scripts

### 1. Initial Setup Script (`install_classicpress_requirements.sh`)

This script automatically:

- Updates system packages
- Installs and configures Nginx web server
- Installs and sets up MariaDB database server
- Installs PHP 8.1 with all required extensions
- Sets up proper directory permissions
- Creates an Nginx configuration template for ClassicPress sites
- Configures and enables all necessary services

### 2. Site Creation Script (`create_classicpress_site.sh`)

This script helps you create individual ClassicPress websites. For each site, it:

- Creates necessary directories
- Downloads the latest version of ClassicPress
- Sets up a new MySQL database and user
- Configures Nginx virtual host
- Generates secure passwords
- Sets proper permissions
- Saves site information for future reference

## Usage

1. Clone this repository:
```bash
git clone https://github.com/aeykaygee/Vanic.git
```

2. Make the scripts executable:
```bash
chmod +x install_classicpress_requirements.sh create_classicpress_site.sh
```

3. Run the initial setup script (only once):
```bash
sudo ./install_classicpress_requirements.sh
```

4. For each new ClassicPress site you want to create:
```bash
sudo ./create_classicpress_site.sh
```

The site creation script will prompt you for:
- Domain name (e.g., example.com)
- Site title
- Admin email
- Admin username

The script will automatically:
- Generate secure passwords for the database and admin user
- Create and configure the database
- Set up the Nginx configuration
- Install ClassicPress
- Save all important information to a file

## Post-Installation

After creating each site:

1. Point your domain's DNS A record to your server's IP address
2. Consider setting up SSL certificates using Let's Encrypt
3. Visit your domain to complete the ClassicPress installation

## Security

- All passwords are randomly generated
- Database credentials are unique for each site
- Proper file permissions are set automatically
- Configuration files are secured
- Site information is saved in protected files

## License

MIT License 