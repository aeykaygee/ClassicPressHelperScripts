# ClassicPress Multi-Site Installation Script

This repository contains scripts to help set up multiple ClassicPress websites on Ubuntu 22.04 LTS using Nginx and MariaDB.

## Requirements

- Ubuntu 22.04 LTS
- Root or sudo access

## What the Script Does

The `install_classicpress_requirements.sh` script automatically:

- Updates system packages
- Installs and configures Nginx web server
- Installs and sets up MariaDB database server
- Installs PHP 8.1 with all required extensions
- Sets up proper directory permissions
- Creates an Nginx configuration template for ClassicPress sites
- Configures and enables all necessary services

## Usage

1. Clone this repository:
```bash
git clone [repository-url]
```

2. Make the script executable:
```bash
chmod +x install_classicpress_requirements.sh
```

3. Run the script:
```bash
sudo ./install_classicpress_requirements.sh
```

4. Follow the post-installation steps shown after the script completes.

## Post-Installation

After running the script, you'll need to:

1. Secure your MariaDB installation
2. Set up individual ClassicPress sites
3. Configure SSL certificates if needed
4. Adjust PHP and Nginx configurations as necessary

## License

MIT License 