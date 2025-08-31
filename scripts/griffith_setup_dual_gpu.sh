#!/bin/bash

# Griffith Dual GPU Setup Script
# Sets up ELIAS system for dual GPU configuration
# Run this script on the Griffith server

set -e  # Exit on error

echo "🚀 ELIAS Griffith Dual GPU Setup Starting..."
echo "============================================="

# Configuration
ELIAS_DIR="/opt/elias_garden_elixir"
MODELS_DIR="/opt/elias_models"
USER_HOME="/home/msimka"
BACKUP_DIR="$USER_HOME/backups/elias_garden_elixir"

# Colors for output
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

log_info() {
    echo -e "${GREEN}✅ $1${NC}"
}

log_warning() {
    echo -e "${YELLOW}⚠️  $1${NC}"
}

log_error() {
    echo -e "${RED}❌ $1${NC}"
}

log_step() {
    echo -e "${BLUE}🔄 $1${NC}"
}

# Step 1: Create backup and pull latest code
log_step "Step 1: Pulling latest ELIAS code"
if [ -d "$ELIAS_DIR" ]; then
    cd "$ELIAS_DIR"
    
    # Create backup first
    if [ ! -d "$BACKUP_DIR" ]; then
        mkdir -p "$BACKUP_DIR"
    fi
    
    # Backup current state
    TIMESTAMP=$(date +%Y%m%d_%H%M%S)
    BACKUP_PATH="${BACKUP_DIR}/elias_backup_${TIMESTAMP}.tar.gz"
    log_step "Creating backup at $BACKUP_PATH"
    tar -czf "$BACKUP_PATH" -C "$(dirname $ELIAS_DIR)" "$(basename $ELIAS_DIR)" 2>/dev/null || log_warning "Backup creation failed"
    
    # Stash any local changes and pull
    git stash push -m "Pre-dual-GPU-setup stash $(date)" || log_warning "No changes to stash"
    git pull origin main
    log_info "Latest code pulled successfully"
else
    log_error "ELIAS directory not found at $ELIAS_DIR"
    log_step "Cloning ELIAS repository"
    sudo mkdir -p "$ELIAS_DIR"
    sudo chown -R msimka:msimka "$ELIAS_DIR"
    git clone https://github.com/msimka/elias_garden_elixir.git "$ELIAS_DIR"
    cd "$ELIAS_DIR"
    log_info "Repository cloned successfully"
fi

# Step 2: Check GPU configuration
log_step "Step 2: Checking GPU configuration"
if command -v nvidia-smi >/dev/null 2>&1; then
    GPU_COUNT=$(nvidia-smi --query-gpu=name --format=csv,noheader,nounits | wc -l)
    log_info "Found $GPU_COUNT GPU(s):"
    nvidia-smi --query-gpu=name,memory.total --format=csv,noheader,nounits | nl
    
    if [ "$GPU_COUNT" -ge 2 ]; then
        log_info "Dual GPU configuration detected - ready for parallel training"
        export CUDA_VISIBLE_DEVICES="0,1"
    else
        log_warning "Single GPU detected - dual GPU features will be limited"
        export CUDA_VISIBLE_DEVICES="0"
    fi
else
    log_error "NVIDIA drivers not found - GPU acceleration unavailable"
fi

# Step 3: Set up Python environment and install dependencies
log_step "Step 3: Setting up Python environment"
cd "$ELIAS_DIR"

if [ -f "requirements.txt" ]; then
    # Check if virtual environment exists
    if [ ! -d "venv" ]; then
        log_step "Creating Python virtual environment"
        python3 -m venv venv
    fi
    
    source venv/bin/activate
    log_step "Installing Python dependencies"
    pip install --upgrade pip
    pip install -r requirements.txt
    log_info "Python environment ready"
else
    log_warning "requirements.txt not found - skipping Python setup"
fi

# Step 4: Download required AI models
log_step "Step 4: Downloading required AI models"
mkdir -p "$MODELS_DIR"

# DeepSeek model for local inference
DEEPSEEK_MODEL="deepseek-ai/deepseek-coder-6.7b-instruct"
log_step "Downloading DeepSeek model: $DEEPSEEK_MODEL"

if command -v huggingface-cli >/dev/null 2>&1; then
    huggingface-cli download "$DEEPSEEK_MODEL" --local-dir "$MODELS_DIR/deepseek-coder-6.7b" --local-dir-use-symlinks False
    log_info "DeepSeek model downloaded"
else
    log_step "Installing Hugging Face CLI"
    pip install huggingface_hub[cli]
    huggingface-cli download "$DEEPSEEK_MODEL" --local-dir "$MODELS_DIR/deepseek-coder-6.7b" --local-dir-use-symlinks False
    log_info "DeepSeek model downloaded"
fi

# LoRA models for personalization
log_step "Downloading base LoRA models"
LORA_MODELS=(
    "microsoft/DialoGPT-medium"
    "microsoft/CodeBERT-base"
    "sentence-transformers/all-MiniLM-L6-v2"
)

for model in "${LORA_MODELS[@]}"; do
    model_name=$(echo "$model" | sed 's/.*\///')
    log_step "Downloading $model"
    huggingface-cli download "$model" --local-dir "$MODELS_DIR/$model_name" --local-dir-use-symlinks False
    log_info "$model downloaded"
done

# Step 5: Set up Elixir environment
log_step "Step 5: Setting up Elixir environment"
cd "$ELIAS_DIR"

if command -v mix >/dev/null 2>&1; then
    log_step "Installing Elixir dependencies"
    export MIX_ENV=dev
    mix deps.get
    mix compile
    log_info "Elixir environment ready"
else
    log_error "Elixir not found - please install Elixir first"
fi

# Step 6: Configure ELIAS for dual GPU setup
log_step "Step 6: Configuring ELIAS for dual GPU"

# Create GPU configuration file
cat > config/gpu.exs << EOF
# GPU Configuration for ELIAS
import Config

config :elias_garden, :gpu,
  # GPU Settings
  cuda_devices: "$CUDA_VISIBLE_DEVICES",
  gpu_count: $GPU_COUNT,
  parallel_training: $([ "$GPU_COUNT" -ge 2 ] && echo "true" || echo "false"),
  
  # Model Paths
  model_cache_dir: "$MODELS_DIR",
  deepseek_model_path: "$MODELS_DIR/deepseek-coder-6.7b",
  
  # Performance Settings
  max_batch_size: $([ "$GPU_COUNT" -ge 2 ] && echo "32" || echo "16"),
  gradient_accumulation_steps: $([ "$GPU_COUNT" -ge 2 ] && echo "2" || echo "4"),
  mixed_precision: true,
  
  # Memory Management
  max_memory_fraction: 0.9,
  memory_growth: true
EOF

log_info "GPU configuration created"

# Step 7: Test deployment configuration
log_step "Step 7: Testing deployment configuration"
cd "$ELIAS_DIR"

if [ -f "apps/elias_server/lib/mix/tasks/elias.deploy.ex" ]; then
    log_step "Testing deployment status"
    mix elias.deploy status || log_warning "Deployment status check failed"
    
    log_step "Testing deployment configuration"
    mix elias.deploy config || log_warning "Deployment config check failed"
    
    log_info "Deployment system ready"
else
    log_warning "Deployment task not found - deployment system may not be fully configured"
fi

# Step 8: Create startup scripts
log_step "Step 8: Creating startup scripts"

# ELIAS startup script
cat > scripts/start_elias_dual_gpu.sh << EOF
#!/bin/bash
export CUDA_VISIBLE_DEVICES="$CUDA_VISIBLE_DEVICES"
export MIX_ENV=dev
cd "$ELIAS_DIR"
source venv/bin/activate
mix phx.server
EOF

chmod +x scripts/start_elias_dual_gpu.sh

# Training script
cat > scripts/start_training_dual_gpu.sh << EOF
#!/bin/bash
export CUDA_VISIBLE_DEVICES="$CUDA_VISIBLE_DEVICES"
export MIX_ENV=dev
cd "$ELIAS_DIR"
source venv/bin/activate
mix uff.train --dual-gpu
EOF

chmod +x scripts/start_training_dual_gpu.sh

log_info "Startup scripts created"

# Step 9: Run system health check
log_step "Step 9: Running system health check"

echo -e "\n${BLUE}=== System Configuration Summary ===${NC}"
echo "ELIAS Directory: $ELIAS_DIR"
echo "Models Directory: $MODELS_DIR"
echo "GPU Count: $GPU_COUNT"
echo "CUDA Devices: $CUDA_VISIBLE_DEVICES"
echo "Elixir Version: $(mix --version | head -1 || echo 'Not available')"
echo "Python Version: $(python3 --version)"
echo "Git Status: $(cd $ELIAS_DIR && git rev-parse --short HEAD 2>/dev/null || echo 'Unknown')"

if [ "$GPU_COUNT" -ge 2 ]; then
    log_info "System ready for dual GPU operations!"
    echo -e "\n${GREEN}🎯 Next steps for dual GPU setup:${NC}"
    echo "1. Run: ./scripts/start_elias_dual_gpu.sh (to start ELIAS)"
    echo "2. Run: ./scripts/start_training_dual_gpu.sh (to start training)"
    echo "3. Monitor: nvidia-smi (to watch GPU usage)"
else
    log_warning "Single GPU detected - consider adding second GPU for optimal performance"
fi

echo -e "\n${GREEN}🚀 ELIAS Griffith setup completed successfully!${NC}"
echo "============================================="