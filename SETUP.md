# CpGPT AJHG Episignature Pipeline Setup Guide

This guide will help you set up the complete pipeline for replicating AJHG 2020 episignatures and integrating CpGPT for anomaly detection, synthetic generation, and classification.

## Prerequisites

### System Requirements
- **macOS** (M1/M2 recommended) or **Linux**
- **Python 3.10+** (Python 3.11 or 3.12 recommended)
- **R 4.2+** with Bioconductor
- **AWS CLI** (for downloading CpGPT models and data)
- **Git** (for cloning the repository)

### Disk Space
- **Minimum**: ~100 GB free space
- **Recommended**: ~500 GB for full dataset processing
- GEO RAW.tar files: ~50-100 GB
- Processed data: ~20-50 GB
- Results: ~5-10 GB

### Memory
- **Minimum**: 16 GB RAM
- **Recommended**: 32+ GB RAM for large cohorts

## Step 1: Clone and Setup Repository

```bash
# Clone the repository (if not already done)
git clone https://github.com/mityasmirnov/CpGPT.git
cd CpGPT

# Set PROJECT_ROOT environment variable (optional, for Hydra paths)
export PROJECT_ROOT=$(pwd)
```

## Step 2: Python Environment Setup

### Using Poetry

```bash
# Install Poetry if not already installed
pip install poetry

# Install dependencies
poetry install

# Run pipeline with Poetry
make build_samplesheet convert_data embeddings
```

If `poetry install` fails (e.g. on some optional deps), use pip instead and pass `PYTHON=python3` to make.

### Using pip

```bash
# Install CpGPT and dependencies
pip install -e .
# or: pip install CpGPT

# Run pipeline with system Python
PYTHON=python3 make build_samplesheet convert_data embeddings
```

## Step 3: AWS Configuration

CpGPT models and dependencies are stored on AWS S3. You need AWS credentials to download them.

```bash
# Install AWS CLI if not already installed
# macOS: brew install awscli
# Linux: See https://aws.amazon.com/cli/

# Configure AWS credentials
aws configure
# Enter:
#   - Access Key ID: [your access key]
#   - Secret Access Key: [your secret key]
#   - Default region: us-east-1
#   - Default output format: json

# Test S3 access
aws s3 ls s3://cpgpt-lucascamillo-public/data/cpgcorpus/raw/ --request-payer requester
```

**Note**: The S3 bucket uses "requester pays" billing. You will be charged for data transfer.

## Step 4: Download CpGPT Models

```bash
# Download models (small and/or large)
bash download_models.sh

# Or download manually via Python
python3 -c "
from cpgpt.infer.cpgpt_inferencer import CpGPTInferencer
inferencer = CpGPTInferencer()
inferencer.download_model('small')  # or 'large'
"
```

## Step 5: R Environment Setup

```bash
# Navigate to R preprocessing directory
cd r_preprocess

# Install R packages
Rscript install_packages.R

# This will:
# 1. Initialize renv (if not already done)
# 2. Install Bioconductor packages (minfi, limma, GEOquery, etc.)
# 3. Install CRAN packages (e1071, arrow, feather)
# 4. Create renv snapshot

cd ..
```

**Note**: R package installation may take 10-30 minutes depending on your system.

### Manual R Package Installation

If the automated script fails, install packages manually:

```r
# In R console
if (!require("BiocManager", quietly = TRUE))
    install.packages("BiocManager")

BiocManager::install(c(
    "GEOquery",
    "minfi",
    "limma",
    "pROC",
    "FlowSorted.Blood.450k",
    "FlowSorted.Blood.EPIC",
    "sva"
))

install.packages(c("e1071", "arrow", "feather"))
```

## Step 6: Verify Setup

```bash
# Test Python imports
python3 -c "
from cpgpt.infer.cpgpt_inferencer import CpGPTInferencer
from cpgpt.data.components.cpgpt_datasaver import CpGPTDataSaver
print('✓ Python imports successful')
"

# Test R setup
cd r_preprocess
Rscript -e "library(minfi); library(limma); cat('✓ R packages loaded successfully\n')"
cd ..

# Test AWS access
aws s3 ls s3://cpgpt-lucascamillo-public/dependencies/model/weights/ --request-payer requester

# Test model download (if not already downloaded)
python3 -c "
from cpgpt.infer.cpgpt_inferencer import CpGPTInferencer
inf = CpGPTInferencer()
print(f'Available models: {inf.available_models[:3]}...')
"
```

## Step 7: Quick Start - Run Pipeline

### Option 1: Full Pipeline (All Steps)

```bash
# Run everything (CpGCorpus-first approach)
make all

# This will:
# 1. Download AJHG 2020 datasets from CpGCorpus S3 (QCDPB.arrow + metadata)
# 2. Build samplesheet with AJHG-aligned disease labels
# 3. Convert Arrow files to R/CpGPT formats (beta.rds, M.rds, pheno.rds, beta_cpgpt.feather)
# 4. Run AJHG replication
# 5. Prepare CpGPT data
# 6. Run CpGPT inference
# 7. Run anomaly detection
# 8. Generate and evaluate synthetic data
# 9. Compare CpGPT vs AJHG
```

### Option 2: Step-by-Step (CpGCorpus-First)

```bash
# 1. Download from CpGCorpus (primary source)
make download_cpgcorpus

# 2. Build samplesheet with AJHG-aligned labels
make build_samplesheet

# 3. Convert Arrow to R/CpGPT formats
make convert_data

# 4. Run AJHG replication
make ajhg_train

# 5. Prepare CpGPT data
make cpgpt_prepare

# 6. Run CpGPT inference
make cpgpt_infer

# 7. Anomaly detection
make anomaly_eval

# 8. Synthetic generation and evaluation
make synth_eval

# 9. Episignature comparison
make episignature_eval
```

### Option 3: Embeddings Only (Existing Data – No Full CpGCorpus Download)

If you already have `data/ajhg2020/manifest.parquet` and `data/ajhg2020/raw/` from a previous run (or limited download), you can run the embeddings pipeline without re-downloading:

```bash
# Install once (Poetry or pip)
poetry install
# or: pip install -e .

# Use existing data only (no download_cpgcorpus)
make build_samplesheet convert_data embeddings
```

This builds the samplesheet from the existing manifest, converts to CpGPT format, downloads the small model if needed, and writes `results/cpgpt/sample_embeddings.pt`. If you use `pip` instead of Poetry, run: `PYTHON=python3 make build_samplesheet convert_data embeddings`.

### Option 4: GEO Fallback (Only if CpGCorpus Missing)

```bash
# If a GSE is missing from CpGCorpus, use GEO fallback:
make download_geo_fallback
# Then manually run R preprocessing for missing GSEs
```

## Step 8: Configuration

### Environment Variables

You can customize paths via environment variables:

```bash
export GEO_RAW_DIR=geo_raw          # GEO download directory
export DATA_DIR=data                # Data directory
export RESULTS_DIR=results          # Results directory
export DEPENDENCIES_DIR=dependencies # CpGPT dependencies
export MODEL_NAME=small              # Model to use (small or large)
```

### Makefile Variables

Edit `Makefile` or pass variables:

```bash
make all MODEL_NAME=large DATA_DIR=my_data
```

## Troubleshooting

### M1 Mac Issues

- **MPS Support**: MPS (Metal Performance Shaders) support is automatically enabled. If you encounter issues, ensure PyTorch was installed with MPS support:
  ```bash
  pip install torch torchvision --index-url https://download.pytorch.org/whl/cpu
  ```

### R Package Installation Issues

- **Bioconductor**: Ensure Bioconductor is properly installed:
  ```r
  if (!require("BiocManager")) install.packages("BiocManager")
  BiocManager::install(version = "3.18")
  ```

- **renv**: If renv fails, try:
  ```r
  renv::restore()
  ```

### AWS/S3 Issues

- **403 Forbidden**: Ensure AWS credentials are configured correctly
- **Slow Downloads**: Use `--request-payer requester` flag (already included in scripts)
- **Connection Timeout**: Check your internet connection and AWS region settings

### Memory Issues

- **Out of Memory**: Reduce batch size in scripts or use smaller model:
  ```bash
  make cpgpt_infer MODEL_NAME=small
  ```

- **R Memory**: Increase R memory limit:
  ```r
  memory.limit(size = 32000)  # Windows
  # macOS/Linux: R automatically uses available memory
  ```

### File Format Issues

- **RDS Files**: Some scripts expect CSV instead of RDS. Convert:
  ```r
  beta <- readRDS("beta.rds")
  write.csv(beta, "beta.csv")
  ```

## Directory Structure

After running the pipeline, you should have:

```
CpGPT/
├── data/
│   ├── ajhg2020/               # AJHG 2020 datasets (CpGCorpus-first)
│   │   ├── manifest.parquet    # Download manifest
│   │   ├── samplesheet.parquet # Sample annotations with AJHG labels
│   │   ├── raw/                # CpGCorpus Arrow files
│   │   │   └── GSE*/GPL*/
│   │   │       ├── betas/QCDPB.arrow
│   │   │       └── metadata/metadata.arrow
│   │   └── processed/          # Converted R/CpGPT formats
│   │       └── GSE*/GPL*/
│   │           ├── beta.rds
│   │           ├── M.rds
│   │           ├── pheno.rds
│   │           └── beta_cpgpt.feather
│   └── cpgpt_processed/        # CpGPT-processed data
├── geo_raw/                    # GEO fallback (only if CpGCorpus missing)
│   └── GSE*/                   # Per-GSE directories
├── dependencies/               # CpGPT models and dependencies
│   ├── model/
│   └── human/
├── reports/                    # Label audit reports
│   └── ajhg2020_label_audit.md
├── results/
│   ├── ajhg/                   # AJHG replication results
│   ├── cpgpt/                  # CpGPT inference results
│   ├── anomaly/                # Anomaly detection results
│   ├── synthetic/              # Synthetic data and evaluation
│   └── episignature/           # Comparison results
└── scripts/                     # Pipeline scripts
```

## Next Steps

1. **Review Results**: Check `results/` directory for outputs
2. **Customize**: Modify scripts in `scripts/` for your specific needs
3. **Extend**: Add new analysis scripts following the existing patterns

## Getting Help

- **CpGPT Documentation**: See `README.md` and `tutorials/`
- **Issues**: Report issues on GitHub
- **R/Bioconductor**: See Bioconductor documentation

## Version Information

To log versions for reproducibility:

```bash
# Python
poetry export --without-hashes > requirements.txt
# or
pip freeze > requirements.txt

# R
cd r_preprocess
Rscript -e "sessionInfo()" > session_info.txt

# Git
git rev-parse HEAD > git_commit.txt
```
