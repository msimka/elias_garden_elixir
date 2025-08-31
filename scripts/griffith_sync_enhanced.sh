#!/bin/bash
# Enhanced Griffith Synchronization Script with Configuration Management
# Uses Elixir configuration system for deployment parameters

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Logging functions
log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Function to extract configuration from Elixir config
extract_config() {
    local config_key="$1"
    cd "$PROJECT_DIR"
    
    # Use mix to extract configuration values
    local config_value=$(MIX_ENV=${MIX_ENV:-dev} mix run -e "
    config = Application.get_env(:elias_garden, :griffith_server, [])
    value = Keyword.get(config, :${config_key})
    IO.puts(value || '')
    " 2>/dev/null | tail -1)
    
    echo "$config_value"
}

# Function to get sync configuration
get_sync_config() {
    cd "$PROJECT_DIR"
    
    MIX_ENV=${MIX_ENV:-dev} mix run -e "
    config = Application.get_env(:elias_garden, :sync, [])
    
    # Extract rsync options
    rsync_opts = Keyword.get(config, :rsync_options, [])
    IO.puts('RSYNC_OPTIONS=' <> Enum.join(rsync_opts, ' '))
    
    # Extract exclude patterns
    excludes = Keyword.get(config, :exclude_patterns, [])
    IO.puts('EXCLUDE_PATTERNS=' <> Enum.join(excludes, ','))
    " 2>/dev/null
}

# Function to validate environment
validate_environment() {
    log_info "Validating environment..."
    
    # Check if we're in the right directory
    if [ ! -f "$PROJECT_DIR/mix.exs" ]; then
        log_error "Not in ELIAS project directory. mix.exs not found."
        exit 1
    fi
    
    # Check if Mix is available
    if ! command -v mix >/dev/null 2>&1; then
        log_error "Mix not found. Please install Elixir."
        exit 1
    fi
    
    # Check if rsync is available
    if ! command -v rsync >/dev/null 2>&1; then
        log_error "rsync not found. Please install rsync."
        exit 1
    fi
    
    log_success "Environment validation passed"
}

# Function to load configuration
load_configuration() {
    log_info "Loading configuration from Elixir config..."
    
    # Set environment
    export MIX_ENV=${MIX_ENV:-dev}
    log_info "Using MIX_ENV: $MIX_ENV"
    
    # Extract Griffith server configuration
    GRIFFITH_HOST=$(extract_config "host")
    GRIFFITH_USER=$(extract_config "user")
    GRIFFITH_REMOTE_PATH=$(extract_config "remote_path")
    GRIFFITH_BACKUP_PATH=$(extract_config "backup_path")
    SSH_PORT=$(extract_config "ssh_port")
    
    # Set defaults if not configured
    GRIFFITH_HOST=${GRIFFITH_HOST:-"griffith.local"}
    GRIFFITH_USER=${GRIFFITH_USER:-"mikesimka"}
    GRIFFITH_REMOTE_PATH=${GRIFFITH_REMOTE_PATH:-"/opt/elias_garden_elixir"}
    GRIFFITH_BACKUP_PATH=${GRIFFITH_BACKUP_PATH:-"/home/mikesimka/backups/elias_garden_elixir"}
    SSH_PORT=${SSH_PORT:-"22"}
    
    # Load sync configuration
    eval "$(get_sync_config)"
    
    log_info "Configuration loaded:"
    log_info "  Host: $GRIFFITH_HOST"
    log_info "  User: $GRIFFITH_USER"
    log_info "  Remote Path: $GRIFFITH_REMOTE_PATH"
    log_info "  SSH Port: $SSH_PORT"
}

# Function to test connectivity
test_connectivity() {
    log_info "Testing connectivity to Griffith server..."
    
    # Test SSH connectivity
    if ssh -p "$SSH_PORT" -o ConnectTimeout=10 -o BatchMode=yes "$GRIFFITH_USER@$GRIFFITH_HOST" echo "Connection test successful" >/dev/null 2>&1; then
        log_success "SSH connectivity verified"
    else
        log_error "Cannot connect to Griffith server via SSH"
        log_error "Please check: SSH keys, network connectivity, server availability"
        exit 1
    fi
}

# Function to prepare sync
prepare_sync() {
    log_info "Preparing synchronization..."
    
    # Clean local build artifacts
    cd "$PROJECT_DIR"
    if [ -d "_build" ]; then
        log_info "Cleaning local build artifacts..."
        mix clean
    fi
    
    # Create exclude file for rsync
    EXCLUDE_FILE=$(mktemp)
    IFS=',' read -ra EXCLUDES <<< "$EXCLUDE_PATTERNS"
    for exclude in "${EXCLUDES[@]}"; do
        echo "$exclude" >> "$EXCLUDE_FILE"
    done
    
    log_success "Sync preparation completed"
}

# Function to create backup on remote server
create_remote_backup() {
    log_info "Creating backup on Griffith server..."
    
    # Create backup directory and backup current deployment
    ssh -p "$SSH_PORT" "$GRIFFITH_USER@$GRIFFITH_HOST" "
        mkdir -p '$GRIFFITH_BACKUP_PATH'
        if [ -d '$GRIFFITH_REMOTE_PATH' ]; then
            BACKUP_NAME=\$(date +'%Y%m%d_%H%M%S')
            echo 'Creating backup: \$BACKUP_NAME'
            cp -r '$GRIFFITH_REMOTE_PATH' '$GRIFFITH_BACKUP_PATH/elias_backup_\$BACKUP_NAME'
            
            # Keep only last 5 backups
            cd '$GRIFFITH_BACKUP_PATH'
            ls -t elias_backup_* | tail -n +6 | xargs -r rm -rf
            
            echo 'Backup created successfully'
        else
            echo 'No existing deployment found, skipping backup'
        fi
    "
    
    if [ $? -eq 0 ]; then
        log_success "Remote backup completed"
    else
        log_warning "Remote backup failed, continuing with sync"
    fi
}

# Function to perform synchronization
perform_sync() {
    log_info "Synchronizing with Griffith server..."
    
    # Build rsync command
    RSYNC_CMD="rsync"
    
    # Add rsync options
    if [ -n "$RSYNC_OPTIONS" ]; then
        RSYNC_CMD="$RSYNC_CMD $RSYNC_OPTIONS"
    else
        RSYNC_CMD="$RSYNC_CMD -avz --progress --partial"
    fi
    
    # Add exclude file
    RSYNC_CMD="$RSYNC_CMD --exclude-from='$EXCLUDE_FILE'"
    
    # Add delete option (be careful!)
    RSYNC_CMD="$RSYNC_CMD --delete"
    
    # Add SSH options
    RSYNC_CMD="$RSYNC_CMD -e 'ssh -p $SSH_PORT'"
    
    # Add source and destination
    RSYNC_CMD="$RSYNC_CMD '$PROJECT_DIR/' '$GRIFFITH_USER@$GRIFFITH_HOST:$GRIFFITH_REMOTE_PATH/'"
    
    log_info "Executing: $RSYNC_CMD"
    
    # Execute rsync
    eval "$RSYNC_CMD"
    
    if [ $? -eq 0 ]; then
        log_success "File synchronization completed"
    else
        log_error "File synchronization failed"
        exit 1
    fi
}

# Function to post-sync validation
post_sync_validation() {
    log_info "Performing post-sync validation..."
    
    # Check if mix.exs exists on remote
    if ssh -p "$SSH_PORT" "$GRIFFITH_USER@$GRIFFITH_HOST" "[ -f '$GRIFFITH_REMOTE_PATH/mix.exs' ]"; then
        log_success "Project files verified on remote server"
    else
        log_error "Project files not found on remote server"
        exit 1
    fi
    
    # Check directory structure
    log_info "Validating directory structure on remote server..."
    ssh -p "$SSH_PORT" "$GRIFFITH_USER@$GRIFFITH_HOST" "
        cd '$GRIFFITH_REMOTE_PATH'
        echo 'Remote directory structure:'
        ls -la
        echo ''
        echo 'Key directories:'
        for dir in lib config apps; do
            if [ -d \$dir ]; then
                echo '✅ \$dir: exists'
            else
                echo '❌ \$dir: missing'
            fi
        done
    "
}

# Function to trigger remote deployment (optional)
trigger_remote_deployment() {
    if [ "$DEPLOY_AFTER_SYNC" = "true" ]; then
        log_info "Triggering remote deployment..."
        
        ssh -p "$SSH_PORT" "$GRIFFITH_USER@$GRIFFITH_HOST" "
            cd '$GRIFFITH_REMOTE_PATH'
            if [ -f 'deploy/deploy_griffith.sh' ]; then
                echo 'Running deployment script...'
                sudo bash deploy/deploy_griffith.sh
            else
                echo 'Deployment script not found, manual deployment required'
            fi
        "
    else
        log_info "Automatic deployment disabled. Run deployment manually if needed."
    fi
}

# Function to cleanup
cleanup() {
    log_info "Cleaning up temporary files..."
    
    if [ -n "$EXCLUDE_FILE" ] && [ -f "$EXCLUDE_FILE" ]; then
        rm -f "$EXCLUDE_FILE"
    fi
    
    log_success "Cleanup completed"
}

# Function to display sync summary
display_summary() {
    echo ""
    echo "=================================================================================="
    log_success "ELIAS Garden Griffith Sync Completed Successfully"
    echo "=================================================================================="
    echo ""
    echo "📊 Sync Summary:"
    echo "   Environment: $MIX_ENV"
    echo "   Source: $PROJECT_DIR"
    echo "   Destination: $GRIFFITH_USER@$GRIFFITH_HOST:$GRIFFITH_REMOTE_PATH"
    echo "   SSH Port: $SSH_PORT"
    echo ""
    echo "🎯 Next Steps:"
    echo "   1. SSH into Griffith: ssh -p $SSH_PORT $GRIFFITH_USER@$GRIFFITH_HOST"
    echo "   2. Navigate to project: cd $GRIFFITH_REMOTE_PATH"
    echo "   3. Run deployment: sudo bash deploy/deploy_griffith.sh"
    echo "   4. Check status: systemctl status elias-garden"
    echo ""
    echo "🔧 Management Commands (on Griffith):"
    echo "   Status: ./health_check_griffith.sh"
    echo "   Logs: journalctl -u elias-garden -f"
    echo "   Restart: sudo systemctl restart elias-garden"
    echo ""
}

# Function to display usage
usage() {
    echo "Usage: $0 [OPTIONS]"
    echo ""
    echo "Options:"
    echo "  -e, --env ENV         Set Mix environment (dev, prod, test)"
    echo "  -d, --deploy         Trigger deployment after sync"
    echo "  -h, --help           Show this help message"
    echo "  --dry-run            Show what would be synced without actually syncing"
    echo ""
    echo "Environment Variables:"
    echo "  MIX_ENV              Set Mix environment (overrides -e option)"
    echo "  DEPLOY_AFTER_SYNC    Set to 'true' to trigger deployment after sync"
    echo ""
    echo "Examples:"
    echo "  $0                   # Sync with dev environment"
    echo "  $0 -e prod           # Sync with production environment"
    echo "  $0 -e prod -d        # Sync with production and deploy"
    echo "  $0 --dry-run         # Show what would be synced"
    echo ""
}

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        -e|--env)
            export MIX_ENV="$2"
            shift 2
            ;;
        -d|--deploy)
            export DEPLOY_AFTER_SYNC="true"
            shift
            ;;
        --dry-run)
            export DRY_RUN="true"
            shift
            ;;
        -h|--help)
            usage
            exit 0
            ;;
        *)
            log_error "Unknown option: $1"
            usage
            exit 1
            ;;
    esac
done

# Main execution
main() {
    echo "🚀 ELIAS Garden Enhanced Griffith Sync"
    echo "======================================"
    echo ""
    
    # Trap cleanup on exit
    trap cleanup EXIT
    
    # Execute sync pipeline
    validate_environment
    load_configuration
    test_connectivity
    prepare_sync
    
    if [ "$DRY_RUN" = "true" ]; then
        log_info "DRY RUN MODE - showing what would be synced:"
        rsync --dry-run -avz --exclude-from="$EXCLUDE_FILE" --delete \
            "$PROJECT_DIR/" "$GRIFFITH_USER@$GRIFFITH_HOST:$GRIFFITH_REMOTE_PATH/"
        log_info "Dry run completed. No files were actually transferred."
        exit 0
    fi
    
    create_remote_backup
    perform_sync
    post_sync_validation
    trigger_remote_deployment
    display_summary
    
    log_success "Griffith sync pipeline completed successfully!"
}

# Execute main function
main "$@"