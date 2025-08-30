#!/usr/bin/env python3
"""
AWS SageMaker Training Setup for UFF DeepSeek 6.7B-FP16  
Production-scale Tank Building methodology training
"""

import json
import boto3
from datetime import datetime, timedelta

# SageMaker Training Configuration
SAGEMAKER_CONFIG = {
    "job_name_prefix": "uff-deepseek-training",
    "model_architecture": "DeepSeek 6.7B-FP16", 
    "instance_type": "ml.p3.2xlarge",  # V100 16GB GPU
    "instance_count": 1,
    "max_runtime_hours": 24,
    "volume_size_gb": 100,
    "training_image": "763104351884.dkr.ecr.us-west-2.amazonaws.com/pytorch-training:1.13.1-gpu-py39-cu117-ubuntu20.04-sagemaker",
    "role_name": "SageMakerExecutionRole-UFF",
    "s3_bucket": "uff-training-data", 
    "s3_prefix": "tank-building-corpus"
}

def create_sagemaker_training_script():
    """Create training script for SageMaker"""
    script = '''#!/usr/bin/env python3
"""
UFF DeepSeek Training Script for AWS SageMaker
Tank Building Methodology + Claude Supervision
"""

import argparse
import json
import logging
import os
import torch
import torch.distributed as dist
from transformers import AutoTokenizer, AutoModelForCausalLM, TrainingArguments, Trainer
from datasets import Dataset
import deepspeed
from datetime import datetime
import subprocess

# Setup logging
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

def setup_distributed():
    """Setup distributed training if using multiple GPUs"""
    if "WORLD_SIZE" in os.environ:
        dist.init_process_group(backend="nccl")
        local_rank = int(os.environ["LOCAL_RANK"]) 
        torch.cuda.set_device(local_rank)
        
def load_training_data(data_dir):
    """Load Tank Building training corpus"""
    logger.info(f"Loading training data from {data_dir}")
    
    with open(os.path.join(data_dir, "training_data.json"), "r") as f:
        training_data = json.load(f)
    
    logger.info(f"Loaded {len(training_data)} Tank Building sessions")
    
    # Process for training
    texts = []
    labels = []
    
    for session in training_data:
        stage = session.get("tank_building_stage", "stage_1")
        component_code = session.get("component_code", "")
        claude_feedback = session.get("claude_feedback", [])
        
        # Create training example
        prompt = f"Tank Building {stage}: {component_code}"
        texts.append(prompt)
        labels.append(prompt)  # For causal LM, labels same as input
        
    return Dataset.from_dict({"text": texts, "labels": labels})

def create_deepspeed_config(args):
    """Create DeepSpeed configuration for SageMaker"""
    config = {
        "zero_optimization": {
            "stage": 2,
            "offload_optimizer": {
                "device": "cpu",
                "pin_memory": True
            },
            "offload_param": {
                "device": "cpu", 
                "pin_memory": True
            },
            "reduce_bucket_size": 500000,
            "allgather_bucket_size": 500000,
            "overlap_comm": True,
            "contiguous_gradients": True
        },
        "fp16": {
            "enabled": True,
            "auto_cast": False,
            "loss_scale": 0,
            "loss_scale_window": 100,
            "hysteresis": 2,
            "min_loss_scale": 1,
            "initial_scale_power": 32
        },
        "gradient_accumulation_steps": args.gradient_accumulation_steps,
        "train_micro_batch_size_per_gpu": args.per_device_train_batch_size,
        "gradient_clipping": 1.0,
        "optimizer": {
            "type": "AdamW",
            "params": {
                "lr": args.learning_rate,
                "betas": [0.9, 0.999], 
                "eps": 1e-8,
                "weight_decay": 0.01
            }
        },
        "scheduler": {
            "type": "WarmupLR",
            "params": {
                "warmup_min_lr": 0,
                "warmup_max_lr": args.learning_rate,
                "warmup_num_steps": args.warmup_steps
            }
        },
        "tensorboard": {
            "enabled": True,
            "output_path": "/opt/ml/output/tensorboard",
            "job_name": "uff_sagemaker_training"
        }
    }
    
    # Save config
    with open("/opt/ml/code/deepspeed_config.json", "w") as f:
        json.dump(config, f, indent=2)
        
    return config

def train_uff_model(args):
    """Main training function"""
    logger.info("🚀 Starting UFF DeepSeek training on SageMaker")
    
    # Setup distributed training
    setup_distributed()
    
    # Load model and tokenizer  
    model_name = args.model_name_or_path
    logger.info(f"Loading model: {model_name}")
    
    tokenizer = AutoTokenizer.from_pretrained(model_name)
    model = AutoModelForCausalLM.from_pretrained(
        model_name,
        torch_dtype=torch.float16,
        device_map="auto" if torch.cuda.is_available() else None
    )
    
    # Add padding token if missing
    if tokenizer.pad_token is None:
        tokenizer.pad_token = tokenizer.eos_token
        
    # Load training data
    dataset = load_training_data("/opt/ml/input/data/training")
    
    # Create DeepSpeed config
    ds_config = create_deepspeed_config(args)
    
    # Setup training arguments
    training_args = TrainingArguments(
        output_dir="/opt/ml/model",
        overwrite_output_dir=True,
        num_train_epochs=args.num_train_epochs,
        per_device_train_batch_size=args.per_device_train_batch_size,
        gradient_accumulation_steps=args.gradient_accumulation_steps,
        learning_rate=args.learning_rate,
        warmup_steps=args.warmup_steps,
        logging_steps=10,
        save_steps=500,
        save_total_limit=2,
        prediction_loss_only=True,
        remove_unused_columns=False,
        dataloader_pin_memory=False,  # Helps with DeepSpeed
        deepspeed="/opt/ml/code/deepspeed_config.json",
        report_to=["tensorboard"],
        logging_dir="/opt/ml/output/tensorboard"
    )
    
    # Data collator for causal LM
    def data_collator(features):
        batch = tokenizer([f["text"] for f in features], 
                         return_tensors="pt", 
                         padding=True, 
                         truncation=True,
                         max_length=512)
        batch["labels"] = batch["input_ids"].clone()
        return batch
    
    # Initialize trainer
    trainer = Trainer(
        model=model,
        args=training_args, 
        train_dataset=dataset,
        data_collator=data_collator,
        tokenizer=tokenizer
    )
    
    # Start training
    logger.info("🏗️  Starting Tank Building methodology training")
    trainer.train()
    
    # Save final model
    trainer.save_model()
    tokenizer.save_pretrained("/opt/ml/model")
    
    # Generate training report
    training_report = {
        "model": "UFF DeepSeek 6.7B-FP16",
        "methodology": "Tank Building + Claude Supervision",
        "sagemaker_instance": args.instance_type,
        "training_epochs": args.num_train_epochs,
        "batch_size": args.per_device_train_batch_size,
        "learning_rate": args.learning_rate,
        "dataset_size": len(dataset),
        "timestamp": datetime.now().isoformat()
    }
    
    with open("/opt/ml/output/data/training_report.json", "w") as f:
        json.dump(training_report, f, indent=2)
        
    logger.info("🎉 UFF training completed successfully!")
    
if __name__ == "__main__":
    parser = argparse.ArgumentParser(description="UFF DeepSeek Training")
    
    # SageMaker environment variables
    parser.add_argument("--model-name-or-path", type=str, default="deepseek-ai/deepseek-coder-6.7b-base")
    parser.add_argument("--instance-type", type=str, default=os.environ.get("SM_CURRENT_INSTANCE_TYPE", "ml.p3.2xlarge"))
    parser.add_argument("--num-train-epochs", type=int, default=3)
    parser.add_argument("--per-device-train-batch-size", type=int, default=4)
    parser.add_argument("--gradient-accumulation-steps", type=int, default=4)
    parser.add_argument("--learning-rate", type=float, default=5e-6)
    parser.add_argument("--warmup-steps", type=int, default=100)
    
    args = parser.parse_args()
    
    try:
        train_uff_model(args)
    except Exception as e:
        logger.error(f"Training failed: {str(e)}")
        raise
'''
    
    with open("sagemaker_training_script.py", "w") as f:
        f.write(script)
        
    print("✅ Created SageMaker training script")

def create_sagemaker_requirements():
    """Create requirements file for SageMaker"""
    requirements = """
torch>=1.13.1
transformers>=4.21.0
datasets>=2.4.0
deepspeed>=0.7.0
accelerate>=0.12.0
tokenizers>=0.13.0
tensorboard>=2.10.0
boto3>=1.24.0
"""
    
    with open("requirements.txt", "w") as f:
        f.write(requirements.strip())
        
    print("✅ Created SageMaker requirements.txt")

def create_sagemaker_deployment_script():
    """Create SageMaker job deployment script"""
    script = '''#!/usr/bin/env python3
"""
Deploy UFF DeepSeek training job to AWS SageMaker
"""

import boto3
import json
import os
from datetime import datetime
import tarfile

def create_source_tar():
    """Package source code for SageMaker"""
    print("📦 Creating source code package...")
    
    with tarfile.open("uff_training_source.tar.gz", "w:gz") as tar:
        tar.add("sagemaker_training_script.py")
        tar.add("requirements.txt")
        # Add any additional files needed
        
    print("✅ Source package created: uff_training_source.tar.gz")

def upload_training_data_to_s3(bucket, prefix):
    """Upload training data to S3"""
    s3_client = boto3.client('s3')
    
    print(f"📤 Uploading training data to s3://{bucket}/{prefix}/")
    
    # Upload training data (exported from UFF system)
    s3_client.upload_file(
        'training_data.json',
        bucket,
        f'{prefix}/training_data.json'
    )
    
    print("✅ Training data uploaded to S3")

def launch_sagemaker_job():
    """Launch SageMaker training job"""
    sagemaker = boto3.client('sagemaker')
    
    # Generate unique job name
    timestamp = datetime.now().strftime("%Y%m%d-%H%M%S")
    job_name = f"uff-deepseek-training-{timestamp}"
    
    # Training job configuration
    training_config = {
        "TrainingJobName": job_name,
        "RoleArn": f"arn:aws:iam::{boto3.client('sts').get_caller_identity()['Account']}:role/SageMakerExecutionRole-UFF",
        "InputDataConfig": [
            {
                "ChannelName": "training",
                "DataSource": {
                    "S3DataSource": {
                        "S3DataType": "S3Prefix",
                        "S3Uri": f"s3://uff-training-data/tank-building-corpus/",
                        "S3DataDistributionType": "FullyReplicated"
                    }
                },
                "ContentType": "application/json",
                "CompressionType": "None"
            }
        ],
        "OutputDataConfig": {
            "S3OutputPath": "s3://uff-training-data/output/"
        },
        "ResourceConfig": {
            "InstanceType": "ml.p3.2xlarge",
            "InstanceCount": 1,
            "VolumeSizeInGB": 100
        },
        "StoppingCondition": {
            "MaxRuntimeInSeconds": 86400  # 24 hours
        },
        "AlgorithmSpecification": {
            "TrainingInputMode": "File",
            "TrainingImage": "763104351884.dkr.ecr.us-west-2.amazonaws.com/pytorch-training:1.13.1-gpu-py39-cu117-ubuntu20.04-sagemaker"
        },
        "HyperParameters": {
            "model-name-or-path": "deepseek-ai/deepseek-coder-6.7b-base",
            "num-train-epochs": "3",
            "per-device-train-batch-size": "4", 
            "gradient-accumulation-steps": "4",
            "learning-rate": "5e-6",
            "warmup-steps": "100"
        },
        "Tags": [
            {"Key": "Project", "Value": "UFF-DeepSeek-Training"},
            {"Key": "Methodology", "Value": "Tank-Building"},
            {"Key": "Environment", "Value": "Production"}
        ]
    }
    
    # Launch job
    print(f"🚀 Launching SageMaker training job: {job_name}")
    response = sagemaker.create_training_job(**training_config)
    
    print(f"✅ Training job started!")
    print(f"📊 Job Name: {job_name}")
    print(f"🔗 Console: https://console.aws.amazon.com/sagemaker/home#/jobs/{job_name}")
    
    return job_name

def monitor_training_job(job_name):
    """Monitor SageMaker training job"""
    sagemaker = boto3.client('sagemaker')
    
    print(f"📊 Monitoring job: {job_name}")
    print("💡 Use 'aws sagemaker describe-training-job --training-job-name {job_name}' for details")
    print(f"📈 CloudWatch logs: /aws/sagemaker/TrainingJobs/{job_name}")

def main():
    """Main deployment function"""
    print("🔥 Deploying UFF DeepSeek training to SageMaker...")
    print("=" * 60)
    
    # Step 1: Package source code
    create_source_tar()
    
    # Step 2: Upload to S3 (requires training data to be exported)
    print("⚠️  Make sure to export training data first with:")
    print("   ./uff_cli export --format=json --output=training_data.json")
    
    # Step 3: Launch training job  
    job_name = launch_sagemaker_job()
    
    # Step 4: Provide monitoring info
    monitor_training_job(job_name)
    
    print("\\n🎉 SageMaker deployment complete!")

if __name__ == "__main__":
    main()
'''
    
    with open("deploy_sagemaker_training.py", "w") as f:
        f.write(script)
        
    print("✅ Created SageMaker deployment script")

def create_sagemaker_setup_instructions():
    """Create setup instructions for SageMaker"""
    instructions = """
🚀 AWS SageMaker Training Setup Instructions:

## Prerequisites:
1. AWS CLI configured with appropriate permissions
2. SageMaker execution role created
3. S3 bucket for training data and outputs

## Setup Steps:

### 1. AWS IAM Role Setup:
```bash
# Create SageMaker execution role (if not exists)
aws iam create-role --role-name SageMakerExecutionRole-UFF \\
    --assume-role-policy-document file://sagemaker-trust-policy.json

# Attach necessary policies
aws iam attach-role-policy --role-name SageMakerExecutionRole-UFF \\
    --policy-arn arn:aws:iam::aws:policy/AmazonSageMakerFullAccess
    
aws iam attach-role-policy --role-name SageMakerExecutionRole-UFF \\
    --policy-arn arn:aws:iam::aws:policy/AmazonS3FullAccess
```

### 2. S3 Bucket Setup:
```bash
# Create S3 bucket for training
aws s3 mb s3://uff-training-data

# Upload training data
./uff_cli export --format=json --output=training_data.json
aws s3 cp training_data.json s3://uff-training-data/tank-building-corpus/
```

### 3. Launch Training:
```bash
# Deploy training job
python deploy_sagemaker_training.py

# Monitor progress
aws sagemaker describe-training-job --training-job-name uff-deepseek-training-YYYYMMDD-HHMMSS
```

### 4. Cost Management:
- **ml.p3.2xlarge**: ~$3.06/hour (V100 16GB GPU)
- **Estimated cost for 24h training**: ~$73
- **Storage**: $0.10/GB/month for training data
- **Set up billing alerts** to monitor costs

### 5. Download Trained Model:
```bash
# Once training completes, download model
aws s3 sync s3://uff-training-data/output/uff-deepseek-training-TIMESTAMP/output/model/ ./trained_model/
```

## Training Configuration:
- **Model**: DeepSeek 6.7B-FP16 
- **Instance**: ml.p3.2xlarge (V100 16GB)
- **Training Time**: Up to 24 hours
- **Batch Size**: 4 per GPU
- **Learning Rate**: 5e-6
- **DeepSpeed**: ZeRO Stage 2 with CPU offloading

## Monitoring:
- **CloudWatch Logs**: `/aws/sagemaker/TrainingJobs/[job-name]`
- **Tensorboard**: Available in output artifacts
- **SageMaker Console**: Real-time job monitoring
"""
    
    with open("SAGEMAKER_SETUP_INSTRUCTIONS.md", "w") as f:
        f.write(instructions)
        
    print("📋 SageMaker setup instructions created")
    print(instructions)

def main():
    """Main setup function"""
    print("⚡ Setting up SageMaker training for UFF DeepSeek model...")
    print("=" * 60)
    
    create_sagemaker_training_script()
    create_sagemaker_requirements() 
    create_sagemaker_deployment_script()
    create_sagemaker_setup_instructions()
    
    print("\n🎉 SageMaker training setup complete!")
    print("📁 Files created:")
    print("   - sagemaker_training_script.py")
    print("   - requirements.txt")
    print("   - deploy_sagemaker_training.py")
    print("   - SAGEMAKER_SETUP_INSTRUCTIONS.md")
    print("\n💰 Estimated cost: ~$73 for 24-hour training on ml.p3.2xlarge")
    print("🚀 Ready to export training data and launch SageMaker job!")

if __name__ == "__main__":
    main()