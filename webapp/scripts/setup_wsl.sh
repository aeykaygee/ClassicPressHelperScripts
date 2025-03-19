#!/bin/bash

# Exit on error
set -e

echo "Setting up development environment in WSL2..."

# Update system
echo "Updating system..."
sudo apt-get update
sudo apt-get upgrade -y

# Install required system packages
echo "Installing system dependencies..."
sudo apt-get install -y \
    python3.11 \
    python3.11-venv \
    python3.11-dev \
    postgresql \
    postgresql-contrib \
    redis-server \
    nginx \
    php8.1-fpm \
    php8.1-mysql \
    php8.1-curl \
    php8.1-gd \
    php8.1-mbstring \
    php8.1-xml \
    php8.1-zip \
    unzip \
    curl \
    git

# Start and enable services
echo "Starting services..."
sudo systemctl start postgresql
sudo systemctl enable postgresql
sudo systemctl start redis-server
sudo systemctl enable redis-server
sudo systemctl start php8.1-fpm
sudo systemctl enable php8.1-fpm
sudo systemctl start nginx
sudo systemctl enable nginx

# Configure PostgreSQL
echo "Configuring PostgreSQL..."
sudo -u postgres psql -c "CREATE DATABASE vanic;"
sudo -u postgres psql -c "ALTER USER postgres WITH PASSWORD 'postgres';"

# Create necessary directories
echo "Creating directories..."
mkdir -p backend/app/logs
mkdir -p backend/app/tests/coverage
sudo mkdir -p /var/www/html
sudo chown -R $USER:$USER /var/www/html

# Install Docker if not already installed
if ! command -v docker &> /dev/null; then
    echo "Installing Docker..."
    curl -fsSL https://get.docker.com -o get-docker.sh
    sudo sh get-docker.sh
    sudo usermod -aG docker $USER
fi

# Install Docker Compose if not already installed
if ! command -v docker-compose &> /dev/null; then
    echo "Installing Docker Compose..."
    sudo curl -L "https://github.com/docker/compose/releases/download/v2.24.1/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
    sudo chmod +x /usr/local/bin/docker-compose
fi

# Build and start Docker containers
echo "Building and starting Docker containers..."
docker-compose -f docker-compose.dev.yml build
docker-compose -f docker-compose.dev.yml up -d

# Wait for services to be ready
echo "Waiting for services to be ready..."
sleep 10

# Create database tables
echo "Creating database tables..."
docker-compose -f docker-compose.dev.yml exec backend python -c "from app.core.database import Base, engine; Base.metadata.create_all(bind=engine)"

# Run tests
echo "Running tests..."
docker-compose -f docker-compose.dev.yml exec backend pytest

echo "Development environment setup complete!"
echo "You can now access:"
echo "- API: http://localhost:8000"
echo "- API Documentation: http://localhost:8000/docs"
echo "- ReDoc: http://localhost:8000/redoc"
echo ""
echo "Note: You may need to restart your WSL session for Docker group changes to take effect." 