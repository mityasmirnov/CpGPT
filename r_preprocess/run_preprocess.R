#!/usr/bin/env Rscript
# R preprocessing pipeline for GEO methylation arrays
# Processes IDAT files using minfi and exports data for CpGPT and AJHG analysis
#
# Usage: Rscript run_preprocess.R <GSE_ID> [base_dir] [output_dir]
# Example: Rscript run_preprocess.R GSE116300 ../geo_raw ../data/processed

suppressPackageStartupMessages({
  library(minfi)
  library(limma)
  library(arrow)
  library(feather)
})

# Parse command line arguments
args <- commandArgs(trailingOnly = TRUE)
if (length(args) < 1) {
  stop("Usage: Rscript run_preprocess.R <GSE_ID> [base_dir] [output_dir]")
}

GSE_ID <- args[1]
BASE_DIR <- ifelse(length(args) >= 2, args[2], "../geo_raw")
OUTPUT_DIR <- ifelse(length(args) >= 3, args[3], "../data/processed")

# Configuration
DETECTION_P_THRESHOLD <- 0.01  # Detection p-value threshold for probe filtering
FAILED_PROBE_RATE_THRESHOLD <- 0.1  # Exclude samples with >10% failed probes

cat("==========================================\n")
cat("R Preprocessing Pipeline\n")
cat("==========================================\n")
cat(sprintf("GSE: %s\n", GSE_ID))
cat(sprintf("Base directory: %s\n", BASE_DIR))
cat(sprintf("Output directory: %s\n", OUTPUT_DIR))
cat("\n")

# Create output directory
gse_output_dir <- file.path(OUTPUT_DIR, GSE_ID)
dir.create(gse_output_dir, recursive = TRUE, showWarnings = FALSE)

# Paths
idat_dir <- file.path(BASE_DIR, GSE_ID, "IDAT")
if (!dir.exists(idat_dir)) {
  # Try alternative location
  idat_dir <- file.path(BASE_DIR, GSE_ID)
}

if (!dir.exists(idat_dir)) {
  stop(sprintf("IDAT directory not found: %s", idat_dir))
}

cat(sprintf("Reading IDAT files from: %s\n", idat_dir))

# Find all IDAT files
idat_files <- list.files(idat_dir, pattern = "\\.idat$", full.names = TRUE, recursive = TRUE)
if (length(idat_files) == 0) {
  stop(sprintf("No IDAT files found in %s", idat_dir))
}

cat(sprintf("Found %d IDAT files\n", length(idat_files)))

# Create targets data.frame
# Extract basenames (without _Red.idat/_Grn.idat suffix)
basenames <- unique(sub("_(Red|Grn)\\.idat$", "", basename(idat_files)))
basenames <- unique(sub("_(Red|Grn)\\.idat$", "", basename(idat_files)))

# Build full paths for basenames
targets <- data.frame(
  Basename = file.path(idat_dir, basenames),
  stringsAsFactors = FALSE
)

# Try to load sample metadata if available
sample_sheet_file <- file.path(BASE_DIR, GSE_ID, "SampleSheet.csv")
if (file.exists(sample_sheet_file)) {
  cat("Loading sample sheet...\n")
  sample_sheet <- read.csv(sample_sheet_file, stringsAsFactors = FALSE)
  # Merge with targets if possible
  # This is a simplified version - adjust based on your sample sheet format
}

cat("Reading methylation array data...\n")
rgSet <- read.metharray.exp(base = idat_dir, targets = targets, verbose = TRUE)

cat(sprintf("Loaded %d samples\n", ncol(rgSet)))
cat(sprintf("Platform: %s\n", annotation(rgSet)[["array"]]))

# Quality control: detection p-values
cat("\nPerforming quality control...\n")
detP <- detectionP(rgSet)
failed_probes <- colMeans(detP > DETECTION_P_THRESHOLD)
failed_samples <- names(failed_probes)[failed_probes > FAILED_PROBE_RATE_THRESHOLD]

if (length(failed_samples) > 0) {
  cat(sprintf("Excluding %d samples with >%.0f%% failed probes:\n", 
              length(failed_samples), FAILED_PROBE_RATE_THRESHOLD * 100))
  cat(paste(failed_samples, collapse = ", "), "\n")
  rgSet <- rgSet[, !colnames(rgSet) %in% failed_samples]
}

# Filter probes with high detection p-values
keep_probes <- rowMeans(detP[, colnames(rgSet)]) < DETECTION_P_THRESHOLD
cat(sprintf("Keeping %d/%d probes (%.1f%%) after detection p-value filtering\n",
            sum(keep_probes), length(keep_probes), 
            100 * sum(keep_probes) / length(keep_probes)))

# Normalization: GenomeStudio-like preprocessing
cat("\nNormalizing data (preprocessIllumina)...\n")
mset <- preprocessIllumina(rgSet, bg.correct = TRUE, normalize = "controls")

# Apply probe filtering
mset <- mset[keep_probes, ]

# Get beta and M values
cat("Extracting beta and M values...\n")
beta <- getBeta(mset)
M <- getM(mset)

cat(sprintf("Final dimensions: %d probes x %d samples\n", nrow(beta), ncol(beta)))

# Estimate cell composition (Houseman method)
cat("\nEstimating blood cell composition...\n")
tryCatch({
  if (annotation(mset)[["array"]] == "IlluminaHumanMethylation450k") {
    cellcounts <- estimateCellCounts(rgSet, compositeCellType = "Blood")
  } else if (annotation(mset)[["array"]] == "IlluminaHumanMethylationEPIC") {
    cellcounts <- estimateCellCounts(rgSet, compositeCellType = "Blood")
  } else {
    cat("Warning: Cell composition estimation may not be available for this platform\n")
    cellcounts <- NULL
  }
}, error = function(e) {
  cat("Warning: Cell composition estimation failed:", conditionMessage(e), "\n")
  cellcounts <<- NULL
})

# Build phenotype data.frame
pheno <- data.frame(
  Sample_ID = colnames(beta),
  GSE = GSE_ID,
  Platform = annotation(mset)[["array"]],
  stringsAsFactors = FALSE
)

# Add cell counts if available
if (!is.null(cellcounts)) {
  pheno <- cbind(pheno, cellcounts)
}

# Add other metadata if available (age, sex, disease, batch, etc.)
# These would come from GEO metadata or sample sheets
# For now, we'll create placeholder columns
pheno$Age <- NA_real_
pheno$Sex <- NA_character_
pheno$Disease <- NA_character_
pheno$Batch <- NA_character_

cat("\nSaving outputs...\n")

# Save RDS files (probes x samples)
saveRDS(beta, file.path(gse_output_dir, "beta.rds"))
saveRDS(M, file.path(gse_output_dir, "M.rds"))
saveRDS(pheno, file.path(gse_output_dir, "pheno.rds"))
cat(sprintf("Saved RDS files to %s\n", gse_output_dir))

# Save feather file for CpGPT (samples x probes + species column)
cat("Preparing feather file for CpGPT...\n")
beta_df <- as.data.frame(t(beta))  # Transpose: samples x probes
beta_df$species <- "homo_sapiens"  # Add species column

# Reorder columns to put species first
beta_df <- beta_df[, c("species", setdiff(colnames(beta_df), "species"))]

feather_file <- file.path(gse_output_dir, "beta_cpgpt.feather")
write_feather(beta_df, feather_file)
cat(sprintf("Saved feather file to %s\n", feather_file))

# Save probe list for harmonization
probe_list_file <- file.path(OUTPUT_DIR, "probe_set_450k_intersection.txt")
if (!file.exists(probe_list_file)) {
  writeLines(rownames(beta), probe_list_file)
  cat(sprintf("Saved probe list to %s\n", probe_list_file))
}

cat("\n==========================================\n")
cat("✓ Preprocessing complete!\n")
cat("==========================================\n")
cat(sprintf("Output directory: %s\n", gse_output_dir))
cat(sprintf("Files created:\n"))
cat(sprintf("  - beta.rds\n"))
cat(sprintf("  - M.rds\n"))
cat(sprintf("  - pheno.rds\n"))
cat(sprintf("  - beta_cpgpt.feather\n"))
cat("\n")
