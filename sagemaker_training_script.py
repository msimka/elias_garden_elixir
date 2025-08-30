#!/usr/bin/env python3
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
