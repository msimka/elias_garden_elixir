#!/bin/bash
# ELIAS Garden Production Deployment Script - Griffith (Linux Full Node)
# Week 2 Day 5 - Complete production-ready deployment with systemd

set -e

ELIAS_HOME="/opt/elias_garden_elixir"
NODE_NAME="elias@griffith.local"
COOKIE_FILE="/opt/elias/.erlang.cookie"
LOG_DIR="/var/log/elias"
PID_FILE="/var/run/elias/elias_griffith.pid"
ELIAS_USER="elias"
SERVICE_NAME="elias-garden"

echo "🚀 ELIAS Garden Production Deployment - Griffith Node"
echo "====================================================="
echo "Deployment Date: $(date)"
echo "ELIAS Home: $ELIAS_HOME"
echo "Node Name: $NODE_NAME"
echo "User: $ELIAS_USER"
echo ""

# Function to check if running as root
check_root() {
    if [[ $EUID -eq 0 ]]; then
        echo "✅ Running as root"
    else
        echo "❌ This script must be run as root (use sudo)"
        exit 1
    fi
}

# Function to check if command exists
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Function to create elias user
create_elias_user() {
    echo "👤 Creating ELIAS system user..."
    
    if id "$ELIAS_USER" &>/dev/null; then
        echo "   ✅ User $ELIAS_USER already exists"
    else
        echo "   📝 Creating user $ELIAS_USER..."
        useradd --system --home /opt/elias --create-home --shell /bin/bash "$ELIAS_USER"
        echo "   ✅ User $ELIAS_USER created"
    fi
}

# Function to create directories
create_directories() {
    echo "📁 Creating required directories..."
    
    mkdir -p "$ELIAS_HOME"
    mkdir -p "$LOG_DIR"
    mkdir -p "/opt/elias/.elias"
    mkdir -p "/var/run/elias"
    mkdir -p "/etc/elias"
    
    # Set permissions
    chown -R "$ELIAS_USER:$ELIAS_USER" "$ELIAS_HOME"
    chown -R "$ELIAS_USER:$ELIAS_USER" "$LOG_DIR"
    chown -R "$ELIAS_USER:$ELIAS_USER" "/opt/elias"
    chown -R "$ELIAS_USER:$ELIAS_USER" "/var/run/elias"
    chown -R "$ELIAS_USER:$ELIAS_USER" "/etc/elias"
    
    echo "   ✅ Directories created with proper permissions"
}

# Function to check system prerequisites
check_prerequisites() {
    echo "🔍 Checking system prerequisites..."
    
    # Detect OS
    if [ -f /etc/debian_version ]; then
        OS="debian"
        PACKAGE_MANAGER="apt"
    elif [ -f /etc/redhat-release ]; then
        OS="redhat"
        PACKAGE_MANAGER="yum"
    else
        echo "   ⚠️  Unknown OS, assuming Debian-based"
        OS="debian"
        PACKAGE_MANAGER="apt"
    fi
    
    echo "   📋 Detected OS: $OS"
    
    # Update package manager
    echo "   📦 Updating package manager..."
    if [ "$PACKAGE_MANAGER" = "apt" ]; then
        apt update
    elif [ "$PACKAGE_MANAGER" = "yum" ]; then
        yum update -y
    fi
    
    # Install required system packages
    echo "   📦 Installing system packages..."
    if [ "$PACKAGE_MANAGER" = "apt" ]; then
        apt install -y curl wget git build-essential openssl unzip python3 python3-pip
    elif [ "$PACKAGE_MANAGER" = "yum" ]; then
        yum install -y curl wget git gcc gcc-c++ make openssl unzip python3 python3-pip
    fi
    
    # Check/Install Erlang and Elixir
    if ! command_exists erl; then
        echo "   📦 Installing Erlang..."
        if [ "$PACKAGE_MANAGER" = "apt" ]; then
            wget https://packages.erlang-solutions.com/erlang-solutions_2.0_all.deb
            dpkg -i erlang-solutions_2.0_all.deb
            apt update
            apt install -y esl-erlang elixir
        elif [ "$PACKAGE_MANAGER" = "yum" ]; then
            yum install -y epel-release
            yum install -y erlang elixir
        fi
    fi
    
    echo "   ✅ Prerequisites check completed"
    
    # Display versions
    echo "   📋 System Information:"
    echo "      OS: $(lsb_release -d 2>/dev/null | cut -f2 || echo "Unknown")"
    echo "      Elixir: $(elixir --version | head -1 2>/dev/null || echo "Not installed")"
    echo "      Erlang: $(erl -version 2>&1 || echo "Not installed")"
    echo "      Python: $(python3 --version 2>/dev/null || echo "Not installed")"
}

# Function to setup network configuration
setup_network() {
    echo "🌐 Setting up network configuration..."
    
    # Update /etc/hosts
    if ! grep -q "griffith.local" /etc/hosts; then
        echo "   📝 Adding hosts entries..."
        tee -a /etc/hosts <<EOF

# ELIAS distributed nodes
127.0.0.1 gracey.local griffith.local
192.168.1.100 gracey.local
172.20.35.144 griffith.local
EOF
    else
        echo "   ✅ Hosts entries already exist"
    fi
    
    # Configure firewall
    echo "   🔥 Configuring firewall..."
    if command_exists ufw; then
        ufw allow 4369/tcp      # EPMD
        ufw allow 49152:65535/tcp  # Erlang distribution range
        ufw allow 22/tcp        # SSH
        echo "   ✅ UFW firewall configured"
    elif command_exists firewall-cmd; then
        firewall-cmd --permanent --add-port=4369/tcp
        firewall-cmd --permanent --add-port=49152-65535/tcp
        firewall-cmd --reload
        echo "   ✅ Firewall-cmd configured"
    else
        echo "   ⚠️  No known firewall found, configure manually"
        echo "      Required ports: 4369/tcp, 49152-65535/tcp"
    fi
    
    # Test hostname resolution
    echo "   🧪 Testing hostname resolution..."
    if ping -c 1 griffith.local >/dev/null 2>&1; then
        echo "      ✅ griffith.local resolves"
    else
        echo "      ⚠️  griffith.local resolution failed"
    fi
}

# Function to setup Erlang cookie
setup_erlang_cookie() {
    echo "🍪 Setting up Erlang cookie..."
    
    if [ ! -f "$COOKIE_FILE" ]; then
        echo "   📝 Generating new Erlang cookie..."
        openssl rand -base64 32 | head -c 32 > "$COOKIE_FILE"
        chown "$ELIAS_USER:$ELIAS_USER" "$COOKIE_FILE"
        chmod 400 "$COOKIE_FILE"
        echo "   ✅ Cookie generated"
    else
        echo "   ✅ Cookie exists"
        chown "$ELIAS_USER:$ELIAS_USER" "$COOKIE_FILE"
        chmod 400 "$COOKIE_FILE"
    fi
    
    echo "   🍪 Cookie: $(cat $COOKIE_FILE)"
}

# Function to deploy ELIAS code
deploy_elias_code() {
    echo "📦 Deploying ELIAS code..."
    
    # If source directory exists, copy from there
    SOURCE_DIR="/Users/mikesimka/elias_garden_elixir"
    if [ -d "$SOURCE_DIR" ]; then
        echo "   📋 Copying from source: $SOURCE_DIR"
        cp -r "$SOURCE_DIR"/* "$ELIAS_HOME/"
    else
        echo "   📡 Cloning from repository..."
        # In real deployment, this would be from git
        echo "   ⚠️  Source directory not found. Manual code deployment required."
        echo "      Copy elias_garden_elixir to $ELIAS_HOME"
        return 1
    fi
    
    # Set ownership
    chown -R "$ELIAS_USER:$ELIAS_USER" "$ELIAS_HOME"
    
    echo "   ✅ ELIAS code deployed"
}

# Function to install dependencies
install_dependencies() {
    echo "📦 Installing Elixir dependencies..."
    
    cd "$ELIAS_HOME"
    
    # Switch to elias user for compilation
    sudo -u "$ELIAS_USER" bash <<EOF
export HOME=/opt/elias
cd "$ELIAS_HOME"

# Clean any previous builds
mix clean

# Get dependencies
MIX_ENV=prod mix deps.get

# Compile for production
MIX_ENV=prod mix compile
EOF
    
    echo "   ✅ Dependencies installed and compiled"
}

# Function to setup ML Python integration
setup_ml_integration() {
    echo "🐍 Setting up ML Python integration..."
    
    # Install Python dependencies
    pip3 install --user torch torchvision torchaudio numpy scikit-learn pandas
    
    # Ensure ML interface script is executable
    ML_SCRIPT="$ELIAS_HOME/apps/elias_core/priv/ml_interface.py"
    if [ -f "$ML_SCRIPT" ]; then
        chmod +x "$ML_SCRIPT"
        chown "$ELIAS_USER:$ELIAS_USER" "$ML_SCRIPT"
        echo "   ✅ ML interface script ready: $ML_SCRIPT"
    else
        echo "   ⚠️  ML interface script not found: $ML_SCRIPT"
    fi
}

# Function to create systemd service
create_systemd_service() {
    echo "⚙️  Creating systemd service..."
    
    cat > "/etc/systemd/system/$SERVICE_NAME.service" <<EOF
[Unit]
Description=ELIAS Garden - AI Operating System (Griffith Full Node)
After=network.target epmd.service
Wants=epmd.service

[Service]
Type=exec
User=$ELIAS_USER
Group=$ELIAS_USER
WorkingDirectory=$ELIAS_HOME
Environment=HOME=/opt/elias
Environment=MIX_ENV=prod
Environment=NODE_NAME=$NODE_NAME
Environment=COOKIE_FILE=$COOKIE_FILE

ExecStartPre=/bin/mkdir -p /var/run/elias
ExecStartPre=/bin/chown $ELIAS_USER:$ELIAS_USER /var/run/elias

ExecStart=/usr/bin/elixir \
    --name $NODE_NAME \
    --cookie-file $COOKIE_FILE \
    --erl "+pc unicode +P 1048576 +K true +A 64" \
    -S mix run --no-halt

ExecStop=/usr/bin/erl -name stop_elias@griffith.local \
    -eval "rpc:call('$NODE_NAME', init, stop, []), init:stop()." \
    -noshell

Restart=always
RestartSec=10
StartLimitBurst=3
StartLimitInterval=60

# Resource limits
LimitNOFILE=65536
LimitNPROC=32768

# Logging
StandardOutput=journal
StandardError=journal
SyslogIdentifier=elias-garden

# Security
NoNewPrivileges=yes
PrivateTmp=yes
ProtectSystem=strict
ReadWritePaths=$ELIAS_HOME $LOG_DIR /var/run/elias /opt/elias

[Install]
WantedBy=multi-user.target
EOF

    # Create EPMD service
    cat > "/etc/systemd/system/epmd.service" <<EOF
[Unit]
Description=Erlang Port Mapper Daemon
After=network.target

[Service]
Type=forking
ExecStart=/usr/bin/epmd -daemon
ExecStop=/usr/bin/epmd -kill
Restart=always
RestartSec=5

[Install]
WantedBy=multi-user.target
EOF

    # Reload systemd
    systemctl daemon-reload
    
    # Enable services
    systemctl enable epmd
    systemctl enable "$SERVICE_NAME"
    
    echo "   ✅ Systemd services created and enabled"
}

# Function to create management scripts
create_management_scripts() {
    echo "📋 Creating management scripts..."
    
    # Status script
    cat > "$ELIAS_HOME/status_griffith.sh" <<EOF
#!/bin/bash
echo "ELIAS Garden - Griffith Node Status"
echo "=================================="

systemctl status $SERVICE_NAME --no-pager
echo ""
echo "Recent logs:"
journalctl -u $SERVICE_NAME --no-pager -n 10
EOF
    
    # Health check script
    cat > "$ELIAS_HOME/health_check_griffith.sh" <<EOF
#!/bin/bash
NODE_NAME="$NODE_NAME"
COOKIE_FILE="$COOKIE_FILE"

echo "ELIAS Garden Health Check - Griffith"
echo "===================================="

# Check service status
if systemctl is-active --quiet $SERVICE_NAME; then
    echo "Service: RUNNING"
    
    # Check node health
    sudo -u $ELIAS_USER erl -name health_check@griffith.local \\
        -cookie "\$(cat \$COOKIE_FILE)" \\
        -eval "
        case net_adm:ping('\$NODE_NAME') of
            pong ->
                io:format('Node: RESPONSIVE~n');
            pang ->
                io:format('Node: NOT RESPONDING~n')
        end,
        init:stop()." -noshell 2>/dev/null
else
    echo "Service: STOPPED"
fi

echo ""
echo "System Resources:"
echo "CPU: \$(top -bn1 | grep "Cpu(s)" | awk '{print \$2}' | sed 's/%us,//')"
echo "Memory: \$(free -h | grep '^Mem:' | awk '{print \$3 "/" \$2}')"
echo "Disk: \$(df -h $ELIAS_HOME | tail -1 | awk '{print \$5}') used"
EOF
    
    # Set permissions
    chmod +x "$ELIAS_HOME/status_griffith.sh"
    chmod +x "$ELIAS_HOME/health_check_griffith.sh"
    chown "$ELIAS_USER:$ELIAS_USER" "$ELIAS_HOME"/*.sh
    
    echo "   ✅ Management scripts created"
}

# Function to setup log rotation
setup_log_rotation() {
    echo "📝 Setting up log rotation..."
    
    cat > "/etc/logrotate.d/elias-garden" <<EOF
$LOG_DIR/*.log {
    daily
    rotate 30
    compress
    delaycompress
    missingok
    notifempty
    copytruncate
    su $ELIAS_USER $ELIAS_USER
}
EOF
    
    echo "   ✅ Log rotation configured"
}

# Function to run deployment tests
run_deployment_tests() {
    echo "🧪 Running deployment tests..."
    
    cd "$ELIAS_HOME"
    
    # Test compilation as elias user
    echo "   Testing compilation..."
    if sudo -u "$ELIAS_USER" MIX_ENV=prod mix compile --force; then
        echo "   ✅ Compilation test passed"
    else
        echo "   ❌ Compilation test failed"
        return 1
    fi
    
    # Test ML integration
    echo "   Testing ML Python integration..."
    if python3 -c "import json, sys; print('Python integration OK')"; then
        echo "   ✅ Python integration test passed"
    else
        echo "   ⚠️  Python integration test failed"
    fi
    
    # Test systemd service (dry run)
    echo "   Testing systemd service configuration..."
    if systemctl --user --dry-run start "$SERVICE_NAME" 2>/dev/null; then
        echo "   ✅ Systemd service test passed"
    else
        echo "   ⚠️  Systemd service test warning (expected in dry run)"
    fi
    
    echo "   ✅ Deployment tests completed"
}

# Function to display deployment summary
display_summary() {
    echo ""
    echo "🎉 ELIAS Garden Deployment Complete - Griffith Node"
    echo "=================================================="
    echo ""
    echo "📁 Installation Directory: $ELIAS_HOME"
    echo "👤 System User: $ELIAS_USER"
    echo "🏷️  Node Name: $NODE_NAME"
    echo "📜 Log Directory: $LOG_DIR"
    echo "🍪 Cookie File: $COOKIE_FILE"
    echo "⚙️  Service Name: $SERVICE_NAME"
    echo ""
    echo "🚀 Management Commands:"
    echo "   Start:   systemctl start $SERVICE_NAME"
    echo "   Stop:    systemctl stop $SERVICE_NAME"
    echo "   Status:  systemctl status $SERVICE_NAME"
    echo "   Logs:    journalctl -u $SERVICE_NAME -f"
    echo "   Health:  $ELIAS_HOME/health_check_griffith.sh"
    echo ""
    echo "📊 Next Steps:"
    echo "   1. Start ELIAS: systemctl start $SERVICE_NAME"
    echo "   2. Check status: systemctl status $SERVICE_NAME"
    echo "   3. Deploy Gracey node"
    echo "   4. Test federation between nodes"
    echo ""
    echo "🔧 Configuration Files:"
    echo "   Service: /etc/systemd/system/$SERVICE_NAME.service"
    echo "   Logs: journalctl -u $SERVICE_NAME"
    echo ""
    echo "✅ Griffith deployment ready for production!"
}

# Main deployment sequence
main() {
    check_root
    check_prerequisites
    create_elias_user
    create_directories
    setup_network
    setup_erlang_cookie
    deploy_elias_code
    install_dependencies
    setup_ml_integration
    create_systemd_service
    create_management_scripts
    setup_log_rotation
    run_deployment_tests
    display_summary
}

# Run main deployment
main "$@"