#!/bin/bash
# ELIAS Garden Production Deployment Script - Gracey (macOS Client Node)
# Week 2 Day 5 - Complete production-ready deployment

set -e

ELIAS_HOME="/Users/mikesimka/elias_garden_elixir"
NODE_NAME="elias@gracey.local"
COOKIE_FILE="$HOME/.erlang.cookie"
LOG_DIR="$HOME/Library/Logs/elias"
PID_FILE="/tmp/elias_gracey.pid"

echo "🚀 ELIAS Garden Production Deployment - Gracey Node"
echo "=================================================="
echo "Deployment Date: $(date)"
echo "ELIAS Home: $ELIAS_HOME"
echo "Node Name: $NODE_NAME"
echo ""

# Function to check if command exists
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Function to create directories
create_directories() {
    echo "📁 Creating required directories..."
    mkdir -p "$LOG_DIR"
    mkdir -p "$HOME/.elias"
    mkdir -p "$ELIAS_HOME/tmp"
    mkdir -p "$ELIAS_HOME/logs"
    echo "   ✅ Directories created"
}

# Function to check system prerequisites
check_prerequisites() {
    echo "🔍 Checking system prerequisites..."
    
    # Check Elixir/Erlang
    if ! command_exists elixir; then
        echo "❌ Elixir not found. Please install Elixir first."
        exit 1
    fi
    
    if ! command_exists mix; then
        echo "❌ Mix not found. Please install Elixir first."
        exit 1
    fi
    
    # Check required tools
    if ! command_exists git; then
        echo "❌ Git not found. Please install Git first."
        exit 1
    fi
    
    # Check Python for ML integration
    if ! command_exists python3; then
        echo "⚠️  Python3 not found. ML features may not work."
    fi
    
    echo "   ✅ Prerequisites check passed"
    
    # Display versions
    echo "   📋 System Information:"
    echo "      Elixir: $(elixir --version | head -1)"
    echo "      Erlang: $(erl -version 2>&1)"
    echo "      Git: $(git --version)"
    if command_exists python3; then
        echo "      Python: $(python3 --version)"
    fi
}

# Function to setup network configuration
setup_network() {
    echo "🌐 Setting up network configuration..."
    
    # Check if hosts entries exist
    if ! grep -q "gracey.local" /etc/hosts; then
        echo "   📝 Adding hosts entries (requires sudo)..."
        sudo tee -a /etc/hosts <<EOF

# ELIAS distributed nodes
127.0.0.1 gracey.local
192.168.1.100 gracey.local
172.20.35.144 griffith.local
EOF
    else
        echo "   ✅ Hosts entries already exist"
    fi
    
    # Test hostname resolution
    echo "   🧪 Testing hostname resolution..."
    if ping -c 1 gracey.local >/dev/null 2>&1; then
        echo "      ✅ gracey.local resolves"
    else
        echo "      ⚠️  gracey.local resolution failed"
    fi
    
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
        chmod 400 "$COOKIE_FILE"
        echo "   ✅ Cookie generated: $(cat $COOKIE_FILE)"
    else
        echo "   ✅ Cookie exists: $(cat $COOKIE_FILE)"
        chmod 400 "$COOKIE_FILE"
    fi
}

# Function to configure firewall
configure_firewall() {
    echo "🔥 Configuring firewall..."
    echo "   📋 Please ensure the following ports are allowed in System Settings > Network > Firewall:"
    echo "      - EPMD: 4369"
    echo "      - Erlang Distribution: 49152-65535"
    echo "      - Or allow beam.smp application entirely"
    echo "   ✅ Firewall configuration instructions displayed"
}

# Function to install dependencies
install_dependencies() {
    echo "📦 Installing Elixir dependencies..."
    
    cd "$ELIAS_HOME"
    
    # Clean any previous builds
    mix clean
    
    # Get dependencies
    MIX_ENV=prod mix deps.get
    
    # Compile for production
    MIX_ENV=prod mix compile
    
    echo "   ✅ Dependencies installed and compiled"
}

# Function to setup ML Python integration
setup_ml_integration() {
    echo "🐍 Setting up ML Python integration..."
    
    if command_exists python3; then
        # Ensure ML interface script is executable
        ML_SCRIPT="$ELIAS_HOME/apps/elias_core/priv/ml_interface.py"
        if [ -f "$ML_SCRIPT" ]; then
            chmod +x "$ML_SCRIPT"
            echo "   ✅ ML interface script ready: $ML_SCRIPT"
        else
            echo "   ⚠️  ML interface script not found: $ML_SCRIPT"
        fi
    else
        echo "   ⚠️  Python3 not available, ML features disabled"
    fi
}

# Function to create launch script
create_launch_script() {
    echo "📋 Creating launch script..."
    
    cat > "$ELIAS_HOME/start_gracey.sh" <<'EOF'
#!/bin/bash
# ELIAS Gracey Node Startup Script

ELIAS_HOME="/Users/mikesimka/elias_garden_elixir"
NODE_NAME="elias@gracey.local"
COOKIE_FILE="$HOME/.erlang.cookie"
LOG_DIR="$HOME/Library/Logs/elias"
PID_FILE="/tmp/elias_gracey.pid"

cd "$ELIAS_HOME"

# Ensure log directory exists
mkdir -p "$LOG_DIR"

# Check if already running
if [ -f "$PID_FILE" ] && kill -0 $(cat "$PID_FILE") 2>/dev/null; then
    echo "ELIAS is already running (PID: $(cat $PID_FILE))"
    exit 1
fi

echo "Starting ELIAS Garden - Gracey Node..."
echo "Node: $NODE_NAME"
echo "Cookie: $(cat $COOKIE_FILE)"
echo "Logs: $LOG_DIR"

# Start ELIAS with detached mode
MIX_ENV=prod elixir \
    --name "$NODE_NAME" \
    --cookie "$(cat $COOKIE_FILE)" \
    --detached \
    --erl "+pc unicode +P 1048576" \
    -S mix run --no-halt 2>&1 | tee "$LOG_DIR/elias_startup.log" &

# Save PID
echo $! > "$PID_FILE"

echo "ELIAS started with PID: $(cat $PID_FILE)"
echo "Monitor logs: tail -f $LOG_DIR/*.log"
EOF

    chmod +x "$ELIAS_HOME/start_gracey.sh"
    echo "   ✅ Launch script created: $ELIAS_HOME/start_gracey.sh"
}

# Function to create stop script
create_stop_script() {
    echo "🛑 Creating stop script..."
    
    cat > "$ELIAS_HOME/stop_gracey.sh" <<'EOF'
#!/bin/bash
# ELIAS Gracey Node Stop Script

PID_FILE="/tmp/elias_gracey.pid"
NODE_NAME="elias@gracey.local"

if [ -f "$PID_FILE" ]; then
    PID=$(cat "$PID_FILE")
    if kill -0 "$PID" 2>/dev/null; then
        echo "Stopping ELIAS (PID: $PID)..."
        
        # Try graceful shutdown first
        erl -name stop_elias@gracey.local -eval "
            rpc:call('$NODE_NAME', init, stop, []),
            timer:sleep(5000),
            init:stop()." -noshell
        
        # Wait a bit
        sleep 3
        
        # If still running, force kill
        if kill -0 "$PID" 2>/dev/null; then
            echo "Forcing stop..."
            kill -9 "$PID"
        fi
        
        rm -f "$PID_FILE"
        echo "ELIAS stopped"
    else
        echo "ELIAS not running (stale PID file)"
        rm -f "$PID_FILE"
    fi
else
    echo "ELIAS not running (no PID file)"
fi
EOF

    chmod +x "$ELIAS_HOME/stop_gracey.sh"
    echo "   ✅ Stop script created: $ELIAS_HOME/stop_gracey.sh"
}

# Function to create status script
create_status_script() {
    echo "📊 Creating status script..."
    
    cat > "$ELIAS_HOME/status_gracey.sh" <<'EOF'
#!/bin/bash
# ELIAS Gracey Node Status Script

PID_FILE="/tmp/elias_gracey.pid"
NODE_NAME="elias@gracey.local"
LOG_DIR="$HOME/Library/Logs/elias"

echo "ELIAS Garden - Gracey Node Status"
echo "================================"

# Check PID file
if [ -f "$PID_FILE" ]; then
    PID=$(cat "$PID_FILE")
    if kill -0 "$PID" 2>/dev/null; then
        echo "Status: RUNNING (PID: $PID)"
        
        # Check if Erlang node is responding
        if erl -name status_check@gracey.local -eval "
            case net_adm:ping('$NODE_NAME') of
                pong -> io:format('Node Status: RESPONSIVE~n');
                pang -> io:format('Node Status: NOT RESPONDING~n')
            end,
            init:stop()." -noshell 2>/dev/null; then
            echo "Network: OK"
        else
            echo "Network: FAILED"
        fi
    else
        echo "Status: STOPPED (stale PID file)"
        rm -f "$PID_FILE"
    fi
else
    echo "Status: STOPPED"
fi

echo ""
echo "Recent logs:"
if [ -d "$LOG_DIR" ]; then
    ls -la "$LOG_DIR"/*.log 2>/dev/null | tail -5
else
    echo "No logs found"
fi

echo ""
echo "System resources:"
echo "CPU: $(top -l 1 -s 0 | grep "CPU usage" || echo "Unknown")"
echo "Memory: $(vm_stat | grep "free" || echo "Unknown")"
EOF

    chmod +x "$ELIAS_HOME/status_gracey.sh"
    echo "   ✅ Status script created: $ELIAS_HOME/status_gracey.sh"
}

# Function to create health check script
create_health_check() {
    echo "🏥 Creating health check script..."
    
    cat > "$ELIAS_HOME/health_check_gracey.sh" <<'EOF'
#!/bin/bash
# ELIAS Gracey Node Health Check Script

NODE_NAME="elias@gracey.local"
COOKIE_FILE="$HOME/.erlang.cookie"

# Function to check node health
check_node_health() {
    erl -name health_check@gracey.local \
        -cookie "$(cat $COOKIE_FILE)" \
        -eval "
        case net_adm:ping('$NODE_NAME') of
            pong ->
                % Check manager status
                case rpc:call('$NODE_NAME', GenServer, whereis, [EliasServer.Manager.UCM]) of
                    Pid when is_pid(Pid) ->
                        io:format('Health: HEALTHY~n'),
                        io:format('UCM Manager: RUNNING~n');
                    _ ->
                        io:format('Health: DEGRADED~n'),
                        io:format('UCM Manager: NOT RUNNING~n')
                end;
            pang ->
                io:format('Health: UNHEALTHY~n'),
                io:format('Node: NOT RESPONDING~n')
        end,
        init:stop()." -noshell 2>/dev/null
}

echo "ELIAS Garden Health Check - Gracey"
echo "================================="
check_node_health

# Check system resources
echo ""
echo "System Health:"
echo "Disk: $(df -h . | tail -1 | awk '{print $5}') used"
echo "Load: $(uptime | awk -F'load averages:' '{print $2}')"
EOF

    chmod +x "$ELIAS_HOME/health_check_gracey.sh"
    echo "   ✅ Health check script created: $ELIAS_HOME/health_check_gracey.sh"
}

# Function to run deployment tests
run_deployment_tests() {
    echo "🧪 Running deployment tests..."
    
    cd "$ELIAS_HOME"
    
    # Test compilation
    echo "   Testing compilation..."
    if MIX_ENV=prod mix compile --force; then
        echo "   ✅ Compilation test passed"
    else
        echo "   ❌ Compilation test failed"
        return 1
    fi
    
    # Test ML integration
    if command_exists python3; then
        echo "   Testing ML Python integration..."
        if python3 -c "import json, sys; print('Python integration OK')"; then
            echo "   ✅ Python integration test passed"
        else
            echo "   ⚠️  Python integration test failed"
        fi
    fi
    
    echo "   ✅ Deployment tests completed"
}

# Function to display deployment summary
display_summary() {
    echo ""
    echo "🎉 ELIAS Garden Deployment Complete - Gracey Node"
    echo "==============================================="
    echo ""
    echo "📁 Installation Directory: $ELIAS_HOME"
    echo "🏷️  Node Name: $NODE_NAME"
    echo "📜 Log Directory: $LOG_DIR"
    echo "🍪 Cookie File: $COOKIE_FILE"
    echo ""
    echo "🚀 Management Commands:"
    echo "   Start:  ./start_gracey.sh"
    echo "   Stop:   ./stop_gracey.sh"
    echo "   Status: ./status_gracey.sh"
    echo "   Health: ./health_check_gracey.sh"
    echo ""
    echo "📊 Next Steps:"
    echo "   1. Deploy Griffith node: ./deploy/deploy_griffith.sh"
    echo "   2. Start Gracey: ./start_gracey.sh"
    echo "   3. Test federation: ./health_check_gracey.sh"
    echo "   4. Monitor logs: tail -f $LOG_DIR/*.log"
    echo ""
    echo "✅ Gracey deployment ready for production!"
}

# Main deployment sequence
main() {
    check_prerequisites
    create_directories
    setup_network
    setup_erlang_cookie
    configure_firewall
    install_dependencies
    setup_ml_integration
    create_launch_script
    create_stop_script
    create_status_script
    create_health_check
    run_deployment_tests
    display_summary
}

# Run main deployment
main "$@"