# Multi-stage build for WhatsApp MCP server

# ------------- STAGE 1: Build Go WhatsApp Bridge -------------
FROM golang:1.24-bullseye AS go-builder

WORKDIR /app/whatsapp-bridge

# Install build dependencies
RUN apt-get update && apt-get install -y --no-install-recommends \
    gcc \
    libc6-dev \
    && rm -rf /var/lib/apt/lists/*

# Copy go module files first for better caching
COPY whatsapp-bridge/go.mod whatsapp-bridge/go.sum ./

# Download dependencies
RUN go mod download

# Copy source code
COPY whatsapp-bridge/main.go ./

# Build the Go binary with CGO enabled
RUN CGO_ENABLED=1 go build -o whatsapp-bridge .

# ------------- STAGE 2: Python MCP Server -------------
FROM python:3.11-slim-bullseye

# Create non-root user and set up directories
RUN groupadd -r appuser && \
    useradd -r -g appuser appuser && \
    mkdir -p /app/store /app/whatsapp-mcp-server && \
    chown -R appuser:appuser /app

# Install necessary packages
RUN apt-get update && apt-get install -y --no-install-recommends \
    ca-certificates \
    ffmpeg \
    sqlite3 \
    curl \
    supervisor \
    && rm -rf /var/lib/apt/lists/*

# Set working directory
WORKDIR /app

# Copy Go binary from builder
COPY --from=go-builder /app/whatsapp-bridge/whatsapp-bridge /usr/local/bin/whatsapp-bridge
RUN chmod +x /usr/local/bin/whatsapp-bridge

# Copy Python MCP server files
COPY whatsapp-mcp-server/ /app/whatsapp-mcp-server/

# Create directories with correct permissions
RUN mkdir -p /home/appuser/.cache/uv && \
    mkdir -p /app/store && \
    chown -R appuser:appuser /home/appuser/.cache /app/store && \
    chmod 755 /app/store

# Switch to root to install packages temporarily
USER root

# Install Python dependencies
RUN pip install --no-cache-dir uv && \
    cd /app/whatsapp-mcp-server && \
    uv pip install --system httpx>=0.28.1 "mcp[cli]>=1.6.0,<2.0.0" requests>=2.32.3

# Switch back to appuser
USER appuser

# Copy supervisord config
COPY supervisord.conf /etc/supervisor/conf.d/supervisord.conf

# Set volume after all files are in place
VOLUME ["/app/store"]

# Expose port for MCP server
EXPOSE 8000

# Set user
USER appuser

# Set entrypoint
ENTRYPOINT ["/usr/bin/supervisord", "-c", "/etc/supervisor/conf.d/supervisord.conf"]
