#!/usr/bin/env python3
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
    
    print("\n🎉 SageMaker deployment complete!")

if __name__ == "__main__":
    main()
