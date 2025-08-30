#!/bin/bash
# Google Drive Synchronization Script

LOCAL_PATH="/Users/mikesimka/elias_garden_elixir"
GDRIVE_PATH="gdrive:ELIAS_Federation_Backup"

echo "🔄 Syncing to Google Drive..."

# Create backup folder if it doesn't exist
rclone mkdir "${GDRIVE_PATH}"

# Sync to Google Drive
rclone sync "${LOCAL_PATH}" "${GDRIVE_PATH}" \
    --exclude='.git/**' \
    --exclude='_build/**' \
    --exclude='deps/**' \
    --exclude='*.beam' \
    --exclude='.elixir_ls/**' \
    --exclude='node_modules/**' \
    --exclude='__pycache__/**' \
    --progress

if [ $? -eq 0 ]; then
    echo "✅ Google Drive sync completed"
    echo "📁 Files synced to ${GDRIVE_PATH}"
    
    # Create timestamped backup
    TIMESTAMP=$(date +"%Y%m%d_%H%M%S")
    ARCHIVE_PATH="gdrive:ELIAS_Federation_Archives/elias_backup_${TIMESTAMP}"
    
    echo "📦 Creating timestamped archive..."
    rclone copy "${GDRIVE_PATH}" "${ARCHIVE_PATH}"
    echo "✅ Archive created: ${ARCHIVE_PATH}"
else
    echo "❌ Google Drive sync failed"
fi
