
🚀 AWS SageMaker Training Setup Instructions:

## Prerequisites:
1. AWS CLI configured with appropriate permissions
2. SageMaker execution role created
3. S3 bucket for training data and outputs

## Setup Steps:

### 1. AWS IAM Role Setup:
```bash
# Create SageMaker execution role (if not exists)
aws iam create-role --role-name SageMakerExecutionRole-UFF \
    --assume-role-policy-document file://sagemaker-trust-policy.json

# Attach necessary policies
aws iam attach-role-policy --role-name SageMakerExecutionRole-UFF \
    --policy-arn arn:aws:iam::aws:policy/AmazonSageMakerFullAccess
    
aws iam attach-role-policy --role-name SageMakerExecutionRole-UFF \
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
