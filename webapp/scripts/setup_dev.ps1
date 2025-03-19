# Exit on error
$ErrorActionPreference = "Stop"

Write-Host "Setting up development environment..."

# Create necessary directories
Write-Host "Creating directories..."
New-Item -ItemType Directory -Force -Path "backend/app/logs"
New-Item -ItemType Directory -Force -Path "backend/app/tests/coverage"

# Install dependencies
Write-Host "Installing dependencies..."
docker-compose -f docker-compose.dev.yml build

# Start services
Write-Host "Starting services..."
docker-compose -f docker-compose.dev.yml up -d

# Wait for services to be ready
Write-Host "Waiting for services to be ready..."
Start-Sleep -Seconds 10

# Create database tables
Write-Host "Creating database tables..."
docker-compose -f docker-compose.dev.yml exec backend python -c "from app.core.database import Base, engine; Base.metadata.create_all(bind=engine)"

# Run tests
Write-Host "Running tests..."
docker-compose -f docker-compose.dev.yml exec backend pytest

Write-Host "Development environment setup complete!"
Write-Host "You can now access:"
Write-Host "- API: http://localhost:8000"
Write-Host "- API Documentation: http://localhost:8000/docs"
Write-Host "- ReDoc: http://localhost:8000/redoc" 