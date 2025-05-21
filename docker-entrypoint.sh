#!/bin/bash
set -e # Exit immediately if a command fails
set -x # Print every command that is executed for robust debugging

echo "--- docker-entrypoint.sh: Starting WhatsApp MCP Server environment ---"

# Define main persistent store directory in the volume location
STORE_DIR="/app/store"
echo "DEBUG: WhatsApp persistent data will be stored in ${STORE_DIR}"
mkdir -p ${STORE_DIR}

# Create bridge directory structure as required by the WhatsApp bridge app
echo "DEBUG: Creating WhatsApp bridge directory structure"
WHATSAPP_BRIDGE_STORE="/app/whatsapp-bridge/store"
mkdir -p ${WHATSAPP_BRIDGE_STORE}

# Ensure database files exist in the main store directory
echo "DEBUG: Ensuring database files exist in main store directory"
touch ${STORE_DIR}/messages.db
touch ${STORE_DIR}/whatsapp.db

# Create symbolic links for the database files
echo "DEBUG: Setting up database symbolic links"
ln -sf ${STORE_DIR}/messages.db ${WHATSAPP_BRIDGE_STORE}/messages.db
ln -sf ${STORE_DIR}/whatsapp.db ${WHATSAPP_BRIDGE_STORE}/whatsapp.db

# --- Start WhatsApp Bridge --- 
echo "DEBUG: Current directory before starting bridge: $(pwd)"

# Double check permissions on the bridge executable
echo "DEBUG: Ensuring WhatsApp Bridge binary is executable"
chmod +x /app/whatsapp-bridge-bin
ls -la /app/whatsapp-bridge-bin

echo "DEBUG: Starting WhatsApp Bridge in background..."

# Execute the WhatsApp bridge binary directly
/app/whatsapp-bridge-bin &
BRIDGE_PID=$!
echo "DEBUG: WhatsApp Bridge process potentially started with PID: $BRIDGE_PID"

echo "DEBUG: Waiting 5 seconds for WhatsApp Bridge to initialize..."
sleep 5

if ! kill -0 $BRIDGE_PID 2>/dev/null; then
    echo "ERROR: WhatsApp Bridge (PID: $BRIDGE_PID) failed to start or exited prematurely within 5 seconds."
    exit 1
fi
echo "DEBUG: WhatsApp Bridge (PID: $BRIDGE_PID) appears to be running."

# --- Prepare and Start Python MCP Server --- 
echo "DEBUG: Changing directory to /app/whatsapp-mcp-server for Python server setup..."
cd /app/whatsapp-mcp-server
echo "DEBUG: Current directory is now: $(pwd)"

echo "DEBUG: Listing contents of /app/whatsapp-mcp-server:"
ls -la

echo "DEBUG: Checking Python version available to uv/shell:"
python --version || python3 --version || echo "Python command not found directly"

echo "DEBUG: Checking uv version:"
uv --version

echo "--- Starting Python MCP Server using 'exec uv run main.py' from $(pwd) ---"

# PYTHONUNBUFFERED=1 ensures that Python output (like our print statements in main.py)
# is sent straight to stdout/stderr without being buffered, making logs appear immediately.
# The 'exec' command replaces the current shell process with the 'uv run' process.
# All subsequent logs should come from main.py if it starts successfully.
exec env PYTHONUNBUFFERED=1 uv run main.py

# --- Fallback: If exec fails or Python script exits --- 
# The script should not reach here if 'exec uv run main.py' is successful and main.py runs indefinitely.
echo "ERROR: 'exec uv run main.py' command finished or failed to replace shell process."
echo "ERROR: This indicates the Python MCP server (main.py) likely did not start or exited prematurely."

# Keep the container alive by waiting for the bridge, but this is a failure state for the MCP server.
echo "DEBUG: Waiting for bridge PID $BRIDGE_PID before exiting entrypoint script with error."
wait $BRIDGE_PID
exit 1 # Exit with an error code because the main Python app didn't take over
