
🚀 Kaggle Training Setup Instructions:

1. Install Kaggle CLI:
   pip install kaggle

2. Setup Kaggle credentials:
   - Go to https://kaggle.com/account
   - Create API token and download kaggle.json
   - Place in ~/.kaggle/kaggle.json
   - Run: chmod 600 ~/.kaggle/kaggle.json

3. Create and upload dataset:
   cd kaggle_dataset
   kaggle datasets create -p .

4. Upload training notebook:
   kaggle kernels push -p kaggle_uff_training.ipynb

5. Monitor training:
   - Check Kaggle notebook output
   - Download trained model when complete
   - Stay within 20 hour/week GPU limit

📊 Training Configuration:
   - Model: DeepSeek 6.7B-FP16
   - GPU: Kaggle P100 (16GB VRAM)
   - Training Time: 12 hours max per session  
   - Batch Size: 8 (optimized for P100)
   - Learning Rate: 3e-6 (conservative)
