# Vanic - ClassicPress Site Manager

A web application for managing ClassicPress sites with multi-user support.

## Features

- User authentication and authorization
- Create and manage multiple ClassicPress sites
- Asynchronous site creation and deletion
- Secure password management
- Site status monitoring
- RESTful API

## Prerequisites

- Docker and Docker Compose
- Git

## Setup

1. Clone the repository:
```bash
git clone https://github.com/yourusername/vanic.git
cd vanic
```

2. Create a `.env` file in the root directory:
```bash
SECRET_KEY=your-secret-key-here
```

3. Build and start the services:
```bash
docker-compose up -d
```

4. Create the database tables:
```bash
docker-compose exec backend python -c "from app.core.database import Base, engine; Base.metadata.create_all(bind=engine)"
```

## API Documentation

Once the application is running, you can access the API documentation at:
- Swagger UI: http://localhost:8000/docs
- ReDoc: http://localhost:8000/redoc

## API Endpoints

### Authentication
- `POST /api/v1/auth/register` - Register a new user
- `POST /api/v1/auth/token` - Login and get access token
- `GET /api/v1/auth/me` - Get current user information

### Sites
- `POST /api/v1/sites/` - Create a new site
- `GET /api/v1/sites/` - List all sites for current user
- `GET /api/v1/sites/{site_id}` - Get site details
- `DELETE /api/v1/sites/{site_id}` - Delete a site

## Development

### Running Tests
```bash
docker-compose exec backend pytest
```

### Code Style
```bash
docker-compose exec backend black .
docker-compose exec backend isort .
```

## Deployment

1. Set up your production environment variables
2. Configure your reverse proxy (e.g., Nginx)
3. Set up SSL certificates
4. Deploy using Docker Compose:
```bash
docker-compose -f docker-compose.prod.yml up -d
```

## Contributing

1. Fork the repository
2. Create a feature branch
3. Commit your changes
4. Push to the branch
5. Create a Pull Request

## License

This project is licensed under the MIT License - see the LICENSE file for details. 