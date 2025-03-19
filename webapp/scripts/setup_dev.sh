#!/bin/bash

# Exit on error
set -e

echo "Setting up development environment..."

# Create necessary directories
echo "Creating directories..."
mkdir -p backend/app/logs
mkdir -p backend/app/tests/coverage

# Install dependencies
echo "Installing dependencies..."
docker-compose -f docker-compose.dev.yml build

# Start services
echo "Starting services..."
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