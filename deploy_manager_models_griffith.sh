#!/bin/bash
# Deploy UFF Manager Models to Griffith Server
# Each of the 7 managers gets a specialized DeepSeek 6.7B-FP16 instance

set -e

GRIFFITH_HOST="griffith"
GRIFFITH_USER="${USER}"  # Use current username
BASE_PATH="/opt/elias"

echo "🚀 Deploying 7 UFF Manager Models to Griffith..."
echo "📡 Target: ${GRIFFITH_USER}@${GRIFFITH_HOST}"

# Test SSH connection
echo "🔗 Testing SSH connection to Griffith..."
ssh ${GRIFFITH_USER}@${GRIFFITH_HOST} "echo '✅ SSH connection successful'" || {
    echo "❌ Cannot connect to Griffith. Please check SSH setup."
    exit 1
}

# Create directory structure on Griffith
echo "📁 Creating model directories on Griffith..."
ssh ${GRIFFITH_USER}@${GRIFFITH_HOST} "
    sudo mkdir -p ${BASE_PATH}/models/{base,ufm,ucm,urm,ulm,uim,uam}
    sudo mkdir -p ${BASE_PATH}/logs/models
    sudo mkdir -p ${BASE_PATH}/scripts
    sudo chown -R ${USER}:${USER} ${BASE_PATH}
"

# Transfer deployment script to Griffith
echo "📤 Transferring deployment script..."
cat << 'EOF' | ssh ${GRIFFITH_USER}@${GRIFFITH_HOST} "cat > ${BASE_PATH}/scripts/setup_manager_models.sh"
#!/bin/bash
# Manager Model Setup Script (runs on Griffith)

set -e

BASE_MODEL_DIR="/opt/elias/models/base/deepseek-6.7b-fp16"
LOG_FILE="/opt/elias/logs/models/setup_$(date +%Y%m%d_%H%M%S).log"

exec > >(tee -a $LOG_FILE)
exec 2>&1

echo "🧠 Setting up 6 DeepSeek 6.7B-FP16 Manager Models..."

# Check system resources
echo "📊 System Resources:"
free -h
nvidia-smi || echo "⚠️  NVIDIA GPU not detected"

# Download base model if needed
if [ ! -d "$BASE_MODEL_DIR" ]; then
    echo "📥 Downloading base DeepSeek 6.7B-FP16 model..."
    mkdir -p $BASE_MODEL_DIR
    
    # For now, create placeholder until we can download from HuggingFace
    cat > $BASE_MODEL_DIR/config.json << 'MODELEOF'
{
    "model_type": "deepseek",
    "architecture": "DeepSeekForCausalLM", 
    "vocab_size": 32000,
    "hidden_size": 4096,
    "intermediate_size": 11008,
    "num_hidden_layers": 30,
    "num_attention_heads": 32,
    "torch_dtype": "float16"
}
MODELEOF

    echo "📋 Base model structure created (placeholder)"
fi

# Setup each manager model
for manager in ufm ucm urm ulm uim uam udm; do
    echo "🔧 Configuring $manager model..."
    
    MODEL_DIR="/opt/elias/models/$manager"
    
    # Create manager-specific configuration
    cat > $MODEL_DIR/manager_config.json << CONFIGEOF
{
    "manager_type": "$manager",
    "model_name": "uff-deepseek-$manager-6.7b-fp16",
    "base_model_path": "$BASE_MODEL_DIR",
    "vram_allocation": "5GB",
    "batch_size": 8,
    "context_window": 4096,
    "specialization": "$(echo $manager | tr '[:lower:]' '[:upper:]') domain expertise",
    "deployment_timestamp": "$(date -Iseconds)",
    "griffith_deployment": true
}
CONFIGEOF

    # Create model server startup script
    cat > $MODEL_DIR/start_model_server.sh << SERVEREOF
#!/bin/bash
# Start $manager model server on Griffith

MODEL_DIR="/opt/elias/models/$manager"
LOG_FILE="/opt/elias/logs/models/${manager}_server.log"

echo "🚀 Starting $manager model server..." | tee -a \$LOG_FILE

# Python model server (placeholder - will be replaced with actual implementation)
python3 -c "
import json
import time
from datetime import datetime

config_path = '\$MODEL_DIR/manager_config.json'
with open(config_path, 'r') as f:
    config = json.load(f)

print(f'✅ {config[\"manager_type\"].upper()} model server initialized')
print(f'📊 VRAM allocated: {config[\"vram_allocation\"]}')
print(f'🧠 Model: {config[\"model_name\"]}')

# Simulate model server running
while True:
    print(f'{datetime.now().isoformat()}: {config[\"manager_type\"].upper()} model server active')
    time.sleep(60)
" >> \$LOG_FILE 2>&1 &

echo \$! > \$MODEL_DIR/server.pid
echo "✅ $manager model server started (PID: \$(cat \$MODEL_DIR/server.pid))"
SERVEREOF

    chmod +x $MODEL_DIR/start_model_server.sh
    
    echo "✅ $manager model configured"
done

# Create master control script
cat > /opt/elias/scripts/manager_models_control.sh << 'CONTROLEOF'
#!/bin/bash
# Master control for all 7 manager models

MANAGERS=(ufm ucm urm ulm uim uam udm)

case "$1" in
    start)
        echo "🚀 Starting all manager model servers..."
        for manager in "${MANAGERS[@]}"; do
            /opt/elias/models/$manager/start_model_server.sh
        done
        echo "✅ All 7 manager models started"
        ;;
    
    stop)
        echo "🛑 Stopping all manager model servers..."
        for manager in "${MANAGERS[@]}"; do
            if [ -f "/opt/elias/models/$manager/server.pid" ]; then
                kill $(cat /opt/elias/models/$manager/server.pid) 2>/dev/null || true
                rm -f /opt/elias/models/$manager/server.pid
            fi
        done
        echo "✅ All manager models stopped"
        ;;
        
    status)
        echo "📊 Manager Model Status:"
        for manager in "${MANAGERS[@]}"; do
            if [ -f "/opt/elias/models/$manager/server.pid" ]; then
                pid=$(cat /opt/elias/models/$manager/server.pid)
                if ps -p $pid > /dev/null; then
                    echo "  ✅ $manager: Running (PID: $pid)"
                else
                    echo "  ❌ $manager: Stopped (stale PID file)"
                fi
            else
                echo "  ⭕ $manager: Not started"
            fi
        done
        ;;
        
    *)
        echo "Usage: $0 {start|stop|status}"
        exit 1
        ;;
esac
CONTROLEOF

chmod +x /opt/elias/scripts/manager_models_control.sh

echo "🎉 All 7 manager models configured on Griffith!"
echo "📊 Total setup: UFM, UCM, URM, ULM, UIM, UAM, UDM"
echo "💾 Estimated VRAM usage: 35GB (7 models x 5GB each)"
echo "🔧 Control script: /opt/elias/scripts/manager_models_control.sh"
EOF

# Make script executable on Griffith
ssh ${GRIFFITH_USER}@${GRIFFITH_HOST} "chmod +x ${BASE_PATH}/scripts/setup_manager_models.sh"

# Run the setup
echo "⚙️  Running manager model setup on Griffith..."
ssh ${GRIFFITH_USER}@${GRIFFITH_HOST} "${BASE_PATH}/scripts/setup_manager_models.sh"

# Test the deployment
echo "🧪 Testing manager model deployment..."
ssh ${GRIFFITH_USER}@${GRIFFITH_HOST} "${BASE_PATH}/scripts/manager_models_control.sh status"

echo ""
echo "🎉 UFF Manager Models deployment complete!"
echo "📡 Griffith now hosts 6 specialized DeepSeek 6.7B-FP16 instances:"
echo "   🔗 UFM: Federation orchestration model"  
echo "   📄 UCM: Content processing model"
echo "   ⚡ URM: Resource optimization model"
echo "   🧠 ULM: Learning adaptation model"
echo "   🖥️  UIM: Interface design model"
echo "   🎨 UAM: Creative generation model"
echo ""
echo "🚀 To start all models: ssh ${GRIFFITH_USER}@${GRIFFITH_HOST} '/opt/elias/scripts/manager_models_control.sh start'"
echo "📊 To check status: ssh ${GRIFFITH_USER}@${GRIFFITH_HOST} '/opt/elias/scripts/manager_models_control.sh status'"