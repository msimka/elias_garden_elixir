#!/bin/bash
# Griffith Synchronization Script

# Configuration (EDIT THESE)
GRIFFITH_HOST="your-griffith-server.com"
GRIFFITH_USER="mikesimka"
GRIFFITH_PATH="/home/mikesimka/backups/elias_garden_elixir"
LOCAL_PATH="/Users/mikesimka/elias_garden_elixir"

# Sync to Griffith
echo "🔄 Syncing to Griffith..."
rsync -avz --delete \
    --exclude='.git' \
    --exclude='_build' \
    --exclude='deps' \
    --exclude='*.beam' \
    --exclude='.elixir_ls' \
    --exclude='node_modules' \
    --exclude='__pycache__' \
    "${LOCAL_PATH}/" \
    "${GRIFFITH_USER}@${GRIFFITH_HOST}:${GRIFFITH_PATH}/"

if [ $? -eq 0 ]; then
    echo "✅ Griffith sync completed"
    echo "📁 Files synced to ${GRIFFITH_USER}@${GRIFFITH_HOST}:${GRIFFITH_PATH}"
else
    echo "❌ Griffith sync failed"
fi
