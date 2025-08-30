#!/bin/bash

# ELIAS Federation System - Multi-Platform Backup Setup
# Sets up GitHub, Griffith (SSH), and Google Drive synchronization

echo "🚀 ELIAS Federation Backup Setup"
echo "=================================="

# Colors for output
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

# Function to print status
print_status() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# 1. GitHub Setup
print_status "Setting up GitHub repository..."

# Check if GitHub CLI is installed
if command -v gh &> /dev/null; then
    print_success "GitHub CLI found"
    
    # Create repository if it doesn't exist
    if gh repo view mikesimka/elias_garden_elixir &> /dev/null; then
        print_success "GitHub repository already exists"
    else
        print_status "Creating GitHub repository..."
        gh repo create mikesimka/elias_garden_elixir --public --description "ELIAS Federation System - Distributed OS with UFF Training, Tank Building Methodology, and 6-Manager Architecture" --clone=false
        print_success "GitHub repository created"
    fi
    
    # Add remote if not exists
    if git remote get-url origin &> /dev/null; then
        print_success "GitHub remote already configured"
    else
        git remote add origin https://github.com/mikesimka/elias_garden_elixir.git
        print_success "GitHub remote added"
    fi
    
    # Push to GitHub
    print_status "Pushing to GitHub..."
    git push -u origin main
    print_success "Pushed to GitHub"
    
else
    print_warning "GitHub CLI not found. Please install with: brew install gh"
    print_status "Alternative: Manually create repository at https://github.com/new"
    print_status "Then run: git remote add origin https://github.com/mikesimka/elias_garden_elixir.git"
    print_status "And: git push -u origin main"
fi

echo ""

# 2. Griffith SSH Setup
print_status "Setting up Griffith (SSH) synchronization..."

# Check if SSH key exists
if [ -f ~/.ssh/id_rsa ] || [ -f ~/.ssh/id_ed25519 ]; then
    print_success "SSH key found"
else
    print_warning "No SSH key found. Generate one with: ssh-keygen -t ed25519 -C 'your_email@example.com'"
fi

# Test Griffith connection
print_status "Testing Griffith connection..."
GRIFFITH_HOST="your-griffith-server.com"  # Replace with actual hostname
GRIFFITH_USER="mikesimka"                  # Replace with actual username
GRIFFITH_PATH="/home/mikesimka/backups/elias_garden_elixir"

# Note: User needs to configure these values
print_warning "Please configure Griffith details in this script:"
print_warning "  GRIFFITH_HOST: Your Griffith server hostname"
print_warning "  GRIFFITH_USER: Your username on Griffith"
print_warning "  GRIFFITH_PATH: Backup path on Griffith"

# Create Griffith sync function
cat > griffith_sync.sh << 'EOL'
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
EOL

chmod +x griffith_sync.sh
print_success "Created griffith_sync.sh (configure hostnames before use)"

echo ""

# 3. Google Drive Setup
print_status "Setting up Google Drive synchronization..."

# Check if rclone is installed
if command -v rclone &> /dev/null; then
    print_success "rclone found"
    
    # Check if Google Drive is configured
    if rclone listremotes | grep -q "gdrive:"; then
        print_success "Google Drive already configured"
    else
        print_status "Configuring Google Drive..."
        print_warning "Run: rclone config"
        print_warning "Choose 'Google Drive' and follow the authentication process"
        print_warning "Name the remote 'gdrive' when prompted"
    fi
else
    print_warning "rclone not found. Install with: brew install rclone"
    print_status "After installing, run: rclone config"
    print_status "Choose 'Google Drive' and authenticate"
fi

# Create Google Drive sync function
cat > gdrive_sync.sh << 'EOL'
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
EOL

chmod +x gdrive_sync.sh
print_success "Created gdrive_sync.sh"

echo ""

# 4. Complete Backup Script
print_status "Creating complete backup script..."

cat > complete_backup.sh << 'EOL'
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
EOL

chmod +x complete_backup.sh
print_success "Created complete_backup.sh"

echo ""

# 5. Automated Backup Schedule
print_status "Setting up automated backup schedule..."

# Create launchd plist for macOS
cat > com.elias.backup.plist << EOL
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>Label</key>
    <string>com.elias.backup</string>
    <key>ProgramArguments</key>
    <array>
        <string>/bin/bash</string>
        <string>/Users/mikesimka/elias_garden_elixir/complete_backup.sh</string>
    </array>
    <key>StartCalendarInterval</key>
    <array>
        <dict>
            <key>Hour</key>
            <integer>18</integer>
            <key>Minute</key>
            <integer>0</integer>
        </dict>
    </array>
    <key>WorkingDirectory</key>
    <string>/Users/mikesimka/elias_garden_elixir</string>
    <key>StandardOutPath</key>
    <string>/Users/mikesimka/elias_garden_elixir/backup_log.txt</string>
    <key>StandardErrorPath</key>
    <string>/Users/mikesimka/elias_garden_elixir/backup_error.txt</string>
</dict>
</plist>
EOL

print_success "Created automated backup schedule (daily at 6 PM)"
print_status "To activate: cp com.elias.backup.plist ~/Library/LaunchAgents/"
print_status "Then: launchctl load ~/Library/LaunchAgents/com.elias.backup.plist"

echo ""
print_success "🎉 Backup setup complete!"
print_status "Manual backup: ./complete_backup.sh"
print_status "Configure Griffith and Google Drive details as needed"
EOL