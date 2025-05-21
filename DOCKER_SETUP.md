# WhatsApp MCP Server - Docker Setup

This document outlines the Docker setup for the WhatsApp MCP Server, a forked version of the original project. It details the changes made to containerize the application and instructions for running it.

## Fork-Specific Changes

This is a fork of the original WhatsApp MCP Server with significant modifications to make it container-friendly and production-ready. Below are the key differences from the original source:

### Go WhatsApp Bridge Changes
1. **Environment-Based Configuration**
   - Added support for environment variables (e.g., `STORE_DIR`)
   - Modified database path to be configurable
   - Added proper signal handling for graceful shutdown

2. **Error Handling**
   - Enhanced error handling for database operations
   - Added retry logic for WhatsApp connection
   - Improved logging with structured output

3. **Security**
   - Removed hardcoded credentials
   - Added input validation for API endpoints
   - Implemented proper file permissions

4. **Docker-Specific**
   - Modified file paths to work in containerized environment
   - Added health check endpoints
   - Configured proper user permissions

### Python MCP Server Changes
1. **Configuration**
   - Made server host and port configurable via environment variables
   - Added support for Docker secrets
   - Implemented proper logging configuration

2. **Error Handling**
   - Added comprehensive error handling for WhatsApp API calls
   - Implemented request timeouts
   - Added input validation

3. **Docker Integration**
   - Modified file paths to use environment variables
   - Added support for Docker health checks
   - Configured proper signal handling for graceful shutdown

## Migration Guide from Original Version

This section helps users familiar with the original version understand the key differences and how to migrate to this forked version.

### Key Differences

| Feature | Original Version | This Fork |
|---------|------------------|-----------|
| **Installation** | Manual setup with local dependencies | Containerized with Docker |
| **Configuration** | Config files and hardcoded values | Environment variables and Docker secrets |
| **Database** | Local SQLite file | Configurable storage with Docker volumes |
| **Logging** | Basic console output | Structured logging with rotation |
| **Security** | Basic security | Non-root user, proper permissions |
| **Deployment** | Manual process | Docker Compose or Kubernetes ready |

### Migration Steps

1. **Backup Your Data**
   - Backup your existing SQLite database and media files
   - Note down your current configuration settings

2. **Update Configuration**
   - Convert your existing config to environment variables
   - Move sensitive data to Docker secrets if needed

3. **Data Migration**
   - Place your existing database in the `./store` directory
   - Ensure file permissions are correct (owned by user 1000:1000 by default)

4. **Update Integration**
   - Update any scripts or services that interact with the API
   - The API endpoints remain the same, but the base URL might change

## Overview of Changes

The following changes were made to make the application Docker-ready:

### 1. Multi-stage Dockerfile
- Split into two stages: one for building the Go WhatsApp bridge and another for the Python MCP server
- Uses lightweight base images (golang:1.24-bullseye and python:3.11-slim-bullseye)
- Implements proper layer caching for faster builds
- Sets up a non-root user (`appuser`) for improved security
- Installs necessary system dependencies (ffmpeg, sqlite3, etc.)
- Configures proper file permissions and working directories

### 2. Docker Compose Configuration
- Defines the service with proper resource constraints
- Sets up named volumes for persistent storage
- Configures logging with log rotation
- Includes proper network configuration for integration with other services
- Implements health checks and graceful shutdown

### 3. Supervisord Integration
- Added supervisord to manage multiple processes (WhatsApp bridge and MCP server)
- Configured proper logging to stdout/stderr for Docker log collection
- Set up proper environment variables and working directories
- Implemented auto-restart policies for process resilience

### 4. Security Improvements
- Runs as non-root user
- Properly isolates application data in volumes
- Sets appropriate file permissions
- Uses minimal base images to reduce attack surface

## Prerequisites

- Docker Engine 20.10.0 or later
- Docker Compose 2.0.0 or later
- At least 1GB of free disk space
- At least 1GB of available RAM

## Running the Container

### Using Docker Compose (Recommended)

1. Clone the repository (if not already done):
   ```bash
   git clone <repository-url>
   cd whatsapp-mcp
   ```

2. Start the container:
   ```bash
   docker-compose up -d
   ```

3. View logs:
   ```bash
   docker-compose logs -f
   ```

### Using Docker Directly

1. Build the image:
   ```bash
   docker build -t whatsapp-mcp .
   ```

2. Run the container:
   ```bash
   docker run -d \
     --name whatsapp-mcp \
     -p 8000:8000 \
     -v whatsapp_store:/app/store \
     --restart unless-stopped \
     whatsapp-mcp
   ```

## Configuration

The following environment variables can be configured:

- `STORE_DIR`: Directory for persistent storage (default: `/app/store`)
- `LOG_LEVEL`: Logging level (default: `INFO`)
- `PYTHONUNBUFFERED`: Set to `1` for unbuffered Python output (recommended)

## Volumes

- `/app/store`: Contains persistent data including:
  - WhatsApp session data
  - Application database
  - Any uploaded media

## Network

The container exposes port 8000 for the MCP server API.

## Health Checks

You can check the health of the container using:

```bash
docker inspect --format='{{.State.Health.Status}}' whatsapp-mcp
```

## Stopping the Container

To stop the container:

```bash
docker-compose down
# or
docker stop whatsapp-mcp && docker rm whatsapp-mcp
```

## Troubleshooting

1. **Permission Issues**:
   If you encounter permission issues with the store directory, ensure the container has write access to the mounted volume.

2. **Port Conflicts**:
   Ensure port 8000 is not in use by another service.

3. **Build Failures**:
   - Check your internet connection
   - Ensure you have enough disk space
   - Try clearing Docker's build cache

## Best Practices

1. **Backup**: Regularly backup the contents of the `/app/store` volume.
2. **Updates**: Regularly update the container image to get security updates.
3. **Monitoring**: Set up monitoring for the container's resource usage and logs.
4. **Security**: Keep your Docker daemon and host system updated.

## License

This project is licensed under the terms of the MIT license. See the [LICENSE](LICENSE) file for details.
