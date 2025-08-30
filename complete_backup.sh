#!/bin/bash
# Complete ELIAS Federation System Backup

echo "🚀 ELIAS Federation Complete Backup"
echo "==================================="

# Git commit and push
echo "📝 Committing latest changes..."
git add -A
git commit -m "Automated backup commit - $(date)" || echo "No changes to commit"
git push origin main

# Griffith sync
echo ""
echo "🖥️  Syncing to Griffith..."
./griffith_sync.sh

# Google Drive sync
echo ""
echo "☁️  Syncing to Google Drive..."
./gdrive_sync.sh

echo ""
echo "✅ Complete backup finished!"
echo "📊 Backup locations:"
echo "   • GitHub: https://github.com/mikesimka/elias_garden_elixir"
echo "   • Griffith: SSH server backup"
echo "   • Google Drive: ELIAS_Federation_Backup folder"
