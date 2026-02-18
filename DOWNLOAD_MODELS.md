# Downloading CpGPT Model Checkpoints

This guide will help you download the pretrained CpGPT model checkpoints (small and large) from AWS S3.

## Prerequisites

1. **AWS CLI installed** ✅ (Already installed)
2. **AWS credentials configured** (Required - see below)

## Step 1: Configure AWS Credentials

The models are hosted in a requester-pays S3 bucket, which requires AWS credentials even though the bucket is public.

### Option A: Quick Setup (Recommended)

Run the following command and follow the prompts:

```bash
aws configure
```

You'll need to provide:
- **AWS Access Key ID**: Get this from [AWS Console → Security Credentials](https://console.aws.amazon.com/iam/home#/security_credentials)
- **AWS Secret Access Key**: Same location as above
- **Default region name**: `us-east-1` (where the models are hosted)
- **Default output format**: `json`

### Option B: Create AWS Account & Access Keys

If you don't have an AWS account:

1. **Create AWS Account**: Go to [AWS Console](https://aws.amazon.com/) and sign up (free tier is sufficient)
2. **Create IAM User**:
   - Go to IAM → Users → Create User
   - Enable "Programmatic access"
   - Attach policy: `AmazonS3ReadOnlyAccess` (or create a custom policy for just this bucket)
3. **Create Access Keys**:
   - Go to Security Credentials → Create Access Key
   - Select "Command Line Interface (CLI)"
   - **IMPORTANT**: Save the Access Key ID and Secret Access Key immediately (you won't see the secret again)
4. **Configure AWS CLI**: Run `aws configure` with your new credentials

## Step 2: Verify Configuration

Test your AWS setup:

```bash
aws s3 ls s3://cpgpt-lucascamillo-public/ --request-payer requester
```

You should see a list of folders including `models/` if configured correctly.

## Step 3: Download Models

### Option A: Use the Download Script

Run the provided script:

```bash
./download_models.sh
```

### Option B: Manual Download

Download models individually:

```bash
# Small model (CpGPT-2M, ~30 MB)
aws s3 cp s3://cpgpt-lucascamillo-public/models/small ./checkpoints/small --request-payer requester --recursive

# Large model (CpGPT-100M, ~1.1 GB)
aws s3 cp s3://cpgpt-lucascamillo-public/models/large ./checkpoints/large --request-payer requester --recursive
```

### Option C: List and Download Specific Files

First, explore what's available:

```bash
# List contents of models directory
aws s3 ls s3://cpgpt-lucascamillo-public/models/ --request-payer requester

# List small model files
aws s3 ls s3://cpgpt-lucascamillo-public/models/small/ --request-payer requester --recursive

# List large model files
aws s3 ls s3://cpgpt-lucascamillo-public/models/large/ --request-payer requester --recursive
```

Then download specific files or folders as needed.

## Model Information

| Model      | Size  | Parameters | Location                    |
|------------|-------|------------|-----------------------------|
| CpGPT-2M   | 30MB  | ~2.5M      | `./checkpoints/small/`      |
| CpGPT-100M | 1.1GB | ~101M      | `./checkpoints/large/`      |

## Important Notes

- **16-bit Mixed Precision**: All models were trained with 16-bit mixed precision. Make sure to use the same precision when loading/inference.
- **Requester-Pays**: You will be charged for data transfer (typically very small amounts, often within AWS free tier limits).
- **Checkpoint Format**: Models are stored as PyTorch Lightning checkpoint files (`.ckpt` format).

## Troubleshooting

### "Unable to locate credentials"
- Make sure you've run `aws configure` and entered your credentials
- Check credentials: `aws configure list`

### "Access Denied" or "403 Forbidden"
- Verify your AWS credentials have S3 read permissions
- Ensure you're using `--request-payer requester` flag

### "No such bucket" or "404"
- Verify the bucket name: `cpgpt-lucascamillo-public`
- Check your AWS region is set to `us-east-1`

### Slow Downloads
- The large model is ~1.1 GB, so downloads may take time depending on your connection
- Consider downloading during off-peak hours if experiencing slow speeds

## Illumina metadata (for `cpgpt_prepare`)

The pipeline downloads Illumina probe manifests from GitHub. If the download times out (slow network), you can place the zip manually:

1. Download: [InfiniumAnnotationV1 main.zip](https://github.com/zhou-lab/InfiniumAnnotationV1/archive/refs/heads/main.zip) (e.g. in your browser or `curl -L -o main.zip '...'`).
2. Save it as: **`dependencies/manifests/main.zip`** (create `dependencies/manifests` if needed).
3. Re-run: `make cpgpt_prepare` (or `python3 scripts/cpgpt_prepare_data.py ...`). The script will detect the file and extract it.

## Next Steps

After downloading, you can use the models with CpGPT:

```python
from cpgpt.infer import CpGPTInferencer

# Initialize inferencer
inferencer = CpGPTInferencer()

# Load small model
model = inferencer.load_cpgpt_model(
    config=inferencer.load_cpgpt_config("configs/model/small.yaml"),
    model_ckpt_path="./checkpoints/small/small.ckpt"  # Adjust path as needed
)
```

See the [README.md](README.md) and tutorials for more usage examples.
