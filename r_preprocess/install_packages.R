# Install required R packages for CpGPT preprocessing pipeline
# Run this script once to set up the R environment

# Install renv if not already installed
if (!require("renv", quietly = TRUE)) {
  install.packages("renv")
}

# Initialize renv if not already initialized
if (!file.exists("renv/activate.R")) {
  renv::init()
}

# Install BiocManager if needed
if (!require("BiocManager", quietly = TRUE)) {
  install.packages("BiocManager")
}

# Install Bioconductor packages
bioc_packages <- c(
  "GEOquery",
  "minfi",
  "limma",
  "pROC",
  "FlowSorted.Blood.450k",
  "FlowSorted.Blood.EPIC",
  "sva"
)

# Install CRAN packages
cran_packages <- c(
  "e1071",  # For SVM (alternative: kernlab)
  "arrow",  # For feather/arrow file support
  "feather" # For feather file support (if arrow doesn't work)
)

cat("Installing Bioconductor packages...\n")
for (pkg in bioc_packages) {
  if (!require(pkg, character.only = TRUE, quietly = TRUE)) {
    BiocManager::install(pkg, update = FALSE, ask = FALSE)
  }
}

cat("Installing CRAN packages...\n")
for (pkg in cran_packages) {
  if (!require(pkg, character.only = TRUE, quietly = TRUE)) {
    install.packages(pkg, repos = "https://cloud.r-project.org")
  }
}

# Snapshot renv
cat("Creating renv snapshot...\n")
renv::snapshot()

cat("\n✓ Package installation complete!\n")
cat("Packages are now available in this renv environment.\n")
