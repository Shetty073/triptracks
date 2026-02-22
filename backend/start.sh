#!/bin/bash

# Exit immediately if a command exits with a non-zero status
set -e

# Production Configuration Variables (can be overridden by environment variables)
HOST=${HOST:-0.0.0.0}
PORT=${PORT:-8000}
WORKERS=${WORKERS:-4}
LOG_LEVEL=${LOG_LEVEL:-info}

echo "Starting Triptracks API (Production Setup)..."
echo "=> Host: $HOST"
echo "=> Port: $PORT"
echo "=> Workers: $WORKERS"
echo "=> Log Level: $LOG_LEVEL"

# Activate the local virtual environment
if [ -d "venv" ]; then
    echo "=> Activating virtual environment..."
    source venv/bin/activate
else
    echo "WARNING: No virtual environment found at ./venv. Assuming dependencies are globally installed."
fi

# Optional: Run database migrations here if you have any (e.g. Alembic)
# alembic upgrade head

# Start the application using uvicorn
# --proxy-headers and --forwarded-allow-ips are important if you are running behind a reverse proxy like Nginx or AWS ALB
exec uvicorn app.main:app \
    --host $HOST \
    --port $PORT \
    --workers $WORKERS \
    --log-level $LOG_LEVEL \
    --proxy-headers \
    --forwarded-allow-ips='*' \
    --timeout-keep-alive 65
