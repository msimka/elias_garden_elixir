#!/bin/bash

# Deploy UDM (Universal Deployment Manager) to Griffith Server
# This script replaces UBM with UDM as the 7th manager in the ELIAS federation

set -e

echo "🚀 Deploying UDM (Universal Deployment Manager) to Griffith..."
echo "Replacing UBM with UDM as the 7th manager model"
echo ""

# SSH connection details
GRIFFITH_USER="msimka"
GRIFFITH_HOST="griffith"
BASE_MODEL_PATH="/opt/elias/models/base/deepseek-6.7b-fp16"
UDM_MODEL_PATH="/opt/elias/models/udm"
OLD_UBM_PATH="/opt/elias/models/ubm"

echo "📡 Connecting to Griffith server..."

# Deploy UDM model via SSH
ssh ${GRIFFITH_USER}@${GRIFFITH_HOST} << 'EOF'
    set -e
    
    echo "🧠 Setting up UDM (Universal Deployment Manager) model..."
    
    # Remove old UBM directory if it exists
    if [ -d "/opt/elias/models/ubm" ]; then
        echo "🗑️  Removing old UBM model directory..."
        sudo rm -rf /opt/elias/models/ubm
    fi
    
    # Create UDM model directory
    echo "📁 Creating UDM model directory..."
    sudo mkdir -p /opt/elias/models/udm
    sudo chown -R msimka:msimka /opt/elias/models/udm
    
    # Link to base DeepSeek model
    echo "🔗 Linking to base DeepSeek 6.7B-FP16 model..."
    BASE_MODEL="/opt/elias/models/base/deepseek-6.7b-fp16"
    
    if [ ! -d "$BASE_MODEL" ]; then
        echo "📥 Base model not found. Please ensure DeepSeek model is installed."
        exit 1
    fi
    
    ln -sf $BASE_MODEL/pytorch_model.bin /opt/elias/models/udm/
    ln -sf $BASE_MODEL/config.json /opt/elias/models/udm/
    ln -sf $BASE_MODEL/tokenizer.json /opt/elias/models/udm/
    
    # Create UDM-specific configuration
    echo "⚙️  Creating UDM model configuration..."
    cat > /opt/elias/models/udm/manager_config.json << UDMEOF
{
    "manager_type": "udm",
    "model_name": "uff-deepseek-udm-6.7b-fp16",
    "specialization": "universal_deployment_orchestration",
    "vram_allocation": "5GB",
    "batch_size": 8,
    "context_window": 4096,
    "responsibilities": [
        "Automated CI/CD pipeline management",
        "Zero-downtime deployment coordination",
        "Blockchain-verified release management",
        "Rollback and recovery orchestration",
        "Environment and configuration management",
        "Cross-platform deployment strategies"
    ],
    "deployment_timestamp": "$(date -Iseconds)",
    "architecture_version": "7-manager-federation",
    "coordinator_dependencies": ["ufm", "urm", "ulm"],
    "blockchain_integration": {
        "ape_harmony": true,
        "signature_verification": true,
        "tamper_detection": true
    }
}
UDMEOF
    
    # Create UDM TIKI specification on Griffith
    echo "📋 Installing UDM TIKI specification..."
    sudo mkdir -p /opt/elias/tiki_specs
    cat > /opt/elias/tiki_specs/udm.tiki << TIKEOF
id: root
name: UniversalDeploymentManager
metadata: {always_on: true, deps: [ufm, urm, ulm], priority: high, specialization: "deployment_orchestration"}
children:
  - id: 1.0
    name: PipelineOrchestrator
    metadata: {inputs: [code_bundle: binary, stage: integer], outputs: [deploy_status: atom], tests: {canary_success: "95% uptime"}}
  - id: 2.0
    name: ReleaseVerifier
    metadata: {blockchain: ape_harmony, verify: "hash + sig", integrity: "tamper_detection"}
  - id: 3.0
    name: RollbackHandler
    metadata: {triggers: [perf_drop: float >0.1], recovery: "blue_green_swap", coordination: "ulm_learning"}
  - id: 4.0
    name: EnvironmentManager
    metadata: {tiers: [development, staging, production], configs: "tiki_injection"}
  - id: 5.0
    name: DeploymentAnalytics
    metadata: {learning: "ulm_integration", patterns: "optimization", metrics: "performance_tracking"}
TIKEOF
    
    # Update manager registry
    echo "📝 Updating manager registry..."
    cat > /opt/elias/manager_registry.json << REGEOF
{
    "federation_managers": [
        {
            "name": "ufm",
            "specialization": "federation_orchestration",
            "status": "active",
            "model_path": "/opt/elias/models/ufm"
        },
        {
            "name": "ucm", 
            "specialization": "content_processing",
            "status": "active",
            "model_path": "/opt/elias/models/ucm"
        },
        {
            "name": "urm",
            "specialization": "resource_optimization", 
            "status": "active",
            "model_path": "/opt/elias/models/urm"
        },
        {
            "name": "ulm",
            "specialization": "learning_adaptation",
            "status": "active", 
            "model_path": "/opt/elias/models/ulm"
        },
        {
            "name": "uim",
            "specialization": "interface_design",
            "status": "active",
            "model_path": "/opt/elias/models/uim"
        },
        {
            "name": "uam",
            "specialization": "creative_generation",
            "status": "active",
            "model_path": "/opt/elias/models/uam"
        },
        {
            "name": "udm",
            "specialization": "universal_deployment_orchestration",
            "status": "active",
            "model_path": "/opt/elias/models/udm"
        }
    ],
    "total_managers": 7,
    "total_vram_requirement": "35GB",
    "architecture": "7-manager-federation",
    "last_updated": "$(date -Iseconds)"
}
REGEOF
    
    echo "✅ UDM model deployment completed!"
    echo "📊 7-Manager Federation Status:"
    echo "   UFM: Federation orchestration"
    echo "   UCM: Content processing" 
    echo "   URM: Resource optimization"
    echo "   ULM: Learning adaptation"
    echo "   UIM: Interface design"
    echo "   UAM: Creative generation"
    echo "   UDM: Universal deployment orchestration"
    echo ""
    echo "🎯 Total VRAM allocation: 35GB (7 models × 5GB each)"
    echo "📅 Ready for Sunday UDM training sessions on SageMaker"
EOF

echo ""
echo "🎉 UDM deployment to Griffith completed successfully!"
echo "📈 Training Schedule Updated:"
echo "   Sunday: Kaggle Main UFF (6h) + SageMaker UDM (4h) = 10h"
echo "🔄 ELIAS federation now runs 7 specialized manager models"
echo "🚀 UDM ready for deployment orchestration and release management"