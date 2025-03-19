import os
import subprocess
import logging
from typing import Optional
from app.core.config import settings
from app.models.site import Site, SiteStatus
from sqlalchemy.orm import Session

logger = logging.getLogger(__name__)

class SiteCreator:
    def __init__(self, db: Session):
        self.db = db
        self.install_dir = settings.CLASSICPRESS_INSTALL_DIR
        self.nginx_config_dir = settings.NGINX_CONFIG_DIR
        self.php_fpm_socket = settings.PHP_FPM_SOCKET

    async def create_site(self, site: Site) -> bool:
        try:
            # Update site status
            site.status = SiteStatus.INSTALLING
            self.db.commit()

            # Create site directory
            site_dir = os.path.join(self.install_dir, site.domain)
            os.makedirs(site_dir, exist_ok=True)

            # Create database
            self._create_database(site)

            # Configure Nginx
            self._configure_nginx(site)

            # Install ClassicPress
            self._install_classicpress(site)

            # Update site status
            site.status = SiteStatus.ACTIVE
            self.db.commit()
            return True

        except Exception as e:
            logger.error(f"Error creating site {site.domain}: {str(e)}")
            site.status = SiteStatus.FAILED
            site.error_log = str(e)
            self.db.commit()
            return False

    def _create_database(self, site: Site):
        commands = [
            f"mysql -e 'CREATE DATABASE IF NOT EXISTS {site.db_name};'",
            f"mysql -e 'CREATE USER IF NOT EXISTS {site.db_user}@localhost IDENTIFIED BY \"{site.db_password}\";'",
            f"mysql -e 'GRANT ALL PRIVILEGES ON {site.db_name}.* TO {site.db_user}@localhost;'",
            "mysql -e 'FLUSH PRIVILEGES;'"
        ]

        for cmd in commands:
            result = subprocess.run(cmd, shell=True, capture_output=True, text=True)
            if result.returncode != 0:
                raise Exception(f"Database creation failed: {result.stderr}")

    def _configure_nginx(self, site: Site):
        nginx_config = f"""
server {{
    listen 80;
    listen [::]:80;
    server_name {site.domain} www.{site.domain};
    root {os.path.join(self.install_dir, site.domain)};
    
    index index.php index.html index.htm;
    
    location / {{
        try_files $uri $uri/ /index.php?$args;
    }}
    
    location ~ \.php$ {{
        include snippets/fastcgi-php.conf;
        fastcgi_pass {self.php_fpm_socket};
        fastcgi_param SCRIPT_FILENAME $document_root$fastcgi_script_name;
        include fastcgi_params;
    }}
    
    location ~ /\.ht {{
        deny all;
    }}
}}
"""
        config_path = os.path.join(self.nginx_config_dir, "sites-available", f"{site.domain}.conf")
        with open(config_path, "w") as f:
            f.write(nginx_config)

        # Enable site
        subprocess.run(f"ln -sf {config_path} {os.path.join(self.nginx_config_dir, 'sites-enabled/')}", shell=True)
        subprocess.run("nginx -t", shell=True, check=True)
        subprocess.run("systemctl reload nginx", shell=True)

    def _install_classicpress(self, site: Site):
        # Download and extract ClassicPress
        site_dir = os.path.join(self.install_dir, site.domain)
        subprocess.run(f"wget https://www.classicpress.net/latest.zip -O {site_dir}/latest.zip", shell=True)
        subprocess.run(f"unzip -q {site_dir}/latest.zip -d {site_dir}/temp", shell=True)
        subprocess.run(f"mv {site_dir}/temp/*/* {site_dir}/", shell=True)
        subprocess.run(f"rm -rf {site_dir}/temp {site_dir}/latest.zip", shell=True)

        # Set permissions
        subprocess.run(f"chown -R www-data:www-data {site_dir}", shell=True)
        subprocess.run(f"find {site_dir} -type d -exec chmod 755 {{}} \\;", shell=True)
        subprocess.run(f"find {site_dir} -type f -exec chmod 644 {{}} \\;", shell=True)

        # Create wp-config.php
        wp_config = f"""<?php
define('DB_NAME', '{site.db_name}');
define('DB_USER', '{site.db_user}');
define('DB_PASSWORD', '{site.db_password}');
define('DB_HOST', 'localhost');
define('DB_CHARSET', 'utf8mb4');
define('DB_COLLATE', '');

$table_prefix = 'wp_';

define('WP_DEBUG', false);

if (!defined('ABSPATH')) {{
    define('ABSPATH', dirname(__FILE__) . '/');
}}

require_once(ABSPATH . 'wp-settings.php');
"""
        with open(os.path.join(site_dir, "wp-config.php"), "w") as f:
            f.write(wp_config)

        # Install ClassicPress using WP-CLI
        subprocess.run(f"cd {site_dir} && sudo -u www-data wp core install --url=http://{site.domain} --title='{site.title}' --admin_user={site.admin_user} --admin_password={site.db_password} --admin_email={site.admin_email} --skip-email", shell=True) 