#!/bin/bash

# Script to download CpGPT model checkpoints from AWS S3
# Requires AWS CLI to be configured with credentials
# See DOWNLOAD_MODELS.md for detailed setup instructions

set -e

echo "=========================================="
echo "CpGPT Model Checkpoint Downloader"
echo "=========================================="
echo ""

# Check if AWS CLI is installed
if ! command -v aws &> /dev/null; then
    echo "✗ AWS CLI is not installed"
    echo "Please install AWS CLI first:"
    echo "  macOS: brew install awscli"
    echo "  Linux: See https://aws.amazon.com/cli/"
    exit 1
fi

# Check AWS credentials
echo "Checking AWS credentials..."
if aws configure list | grep -q "access_key.*<not set>"; then
    echo "✗ AWS credentials not configured"
    echo ""
    echo "Please configure AWS credentials first:"
    echo "  1. Create a free AWS account at https://aws.amazon.com/"
    echo "  2. Create an IAM user with programmatic access"
    echo "  3. Run: aws configure"
    echo "     - Access Key ID: [your access key]"
    echo "     - Secret Access Key: [your secret key]"
    echo "     - Default region: us-east-1"
    echo "     - Default output format: json"
    echo ""
    echo "See DOWNLOAD_MODELS.md for detailed instructions."
    exit 1
fi

echo "✓ AWS credentials found"
echo ""

# Test S3 access
echo "Testing S3 access..."
if ! aws s3 ls s3://cpgpt-lucascamillo-public/ --request-payer requester &> /dev/null; then
    echo "✗ Cannot access S3 bucket"
    echo "Please verify your AWS credentials and permissions"
    exit 1
fi

echo "✓ S3 access confirmed"
echo ""

# Create checkpoint directories
mkdir -p checkpoints/small checkpoints/large

# List available model weights
echo "Listing available model weights in S3 bucket..."
aws s3 ls s3://cpgpt-lucascamillo-public/dependencies/model/weights/ --request-payer requester
echo ""

# Download small model (CpGPT-2M, ~30 MB)
echo "=========================================="
echo "Downloading CpGPT-2M (small) model..."
echo "Size: ~30 MB"
echo "=========================================="
if aws s3 cp s3://cpgpt-lucascamillo-public/dependencies/model/weights/small.ckpt ./checkpoints/small/small.ckpt --request-payer requester; then
    echo "✓ Small model downloaded successfully"
else
    echo "✗ Failed to download small model"
    exit 1
fi
echo ""

# Download large model (CpGPT-100M, ~1.2 GB)
echo "=========================================="
echo "Downloading CpGPT-100M (large) model..."
echo "Size: ~1.2 GB (this may take 10-15 minutes)"
echo "=========================================="
if aws s3 cp s3://cpgpt-lucascamillo-public/dependencies/model/weights/large.ckpt ./checkpoints/large/large.ckpt --request-payer requester; then
    echo "✓ Large model downloaded successfully"
else
    echo "✗ Failed to download large model"
    exit 1
fi
echo ""

# Summary
echo "=========================================="
echo "✓ Download Complete!"
echo "=========================================="
echo ""
echo "Models are available in:"
echo "  - Small (CpGPT-2M):   ./checkpoints/small/"
echo "  - Large (CpGPT-100M): ./checkpoints/large/"
echo ""
echo "Note: Models were trained with 16-bit mixed precision."
echo "Make sure to use the same precision when loading."
echo ""
