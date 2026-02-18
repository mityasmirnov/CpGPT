#!/usr/bin/env Rscript
# Generate ROC curves for AJHG classifiers

suppressPackageStartupMessages({
  library(pROC)
  library(e1071)
})

args <- commandArgs(trailingOnly = TRUE)
DATA_DIR <- ifelse(length(args) >= 1, args[1], "../data/ajhg2020/processed")
OUTPUT_DIR <- ifelse(length(args) >= 2, args[2], "../results/ajhg")

# Load combined data (same as in ajhg_replication.R)
load_combined_data <- function(data_dir) {
  gse_dirs <- list.dirs(data_dir, recursive = TRUE, full.names = TRUE)
  gse_dirs <- gse_dirs[sapply(gse_dirs, function(d) {
    any(file.exists(file.path(d, c("beta.csv", "beta.rds", "M.csv", "M.rds"))))
  })]
  gse_dirs <- gse_dirs[basename(gse_dirs) != "cpgpt_processed"]
  
  all_beta <- NULL
  all_pheno <- NULL
  
  for (gse_dir in gse_dirs) {
    beta_file_csv <- file.path(gse_dir, "beta.csv")
    pheno_file_csv <- file.path(gse_dir, "pheno.csv")
    
    if (all(file.exists(beta_file_csv), file.exists(pheno_file_csv))) {
      beta <- read.csv(beta_file_csv, row.names = 1, check.names = FALSE)
      pheno <- read.csv(pheno_file_csv, row.names = 1, check.names = FALSE)
      
      beta <- as.matrix(beta)
      
      if (!"Sample_ID" %in% colnames(pheno)) {
        pheno$Sample_ID <- rownames(pheno)
      }
      
      if (is.null(all_beta)) {
        all_beta <- beta
        all_pheno <- pheno
      } else {
        common_probes <- intersect(rownames(all_beta), rownames(beta))
        all_beta <- cbind(all_beta[common_probes, ], beta[common_probes, ])
        all_pheno <- rbind(all_pheno, pheno)
      }
    }
  }
  
  return(list(beta = all_beta, pheno = all_pheno))
}

cat("Loading combined data...\n")
data_list <- load_combined_data(DATA_DIR)
beta <- data_list$beta
pheno <- data_list$pheno

# Load classifiers
classifier_file <- file.path(OUTPUT_DIR, "classifiers.rds")
classifiers <- readRDS(classifier_file)

cat("Generating ROC curves...\n")

for (syndrome in names(classifiers)) {
  sig_file <- file.path(OUTPUT_DIR, paste0(syndrome, "_signature.txt"))
  if (!file.exists(sig_file)) next
  
  sig <- read.table(sig_file, header = TRUE, sep = "\t")
  
  # Get cases and controls
  cases <- pheno$Sample_ID[pheno$Disease == syndrome]
  controls <- pheno$Sample_ID[pheno$Disease == "Control"]
  
  if (length(cases) == 0 || length(controls) == 0) {
    cat(sprintf("Skipping %s: insufficient cases or controls\n", syndrome))
    next
  }
  
  # Ensure signature probes exist in beta matrix
  sig_probes <- intersect(sig$Probe, rownames(beta))
  if (length(sig_probes) == 0) {
    cat(sprintf("Skipping %s: no signature probes found in beta matrix\n", syndrome))
    next
  }
  
  # Get the exact probe set used in training (from classifier's training data structure)
  # The classifier was trained on signature probes, so we need to match exactly
  # Check if we can extract training probe names from the model
  model_probes <- NULL
  if (!is.null(classifiers[[syndrome]]$model$SV)) {
    # Try to get probe names from support vectors
    model_probes <- colnames(classifiers[[syndrome]]$model$SV)
  }
  
  # Use signature probes (should match what was used in training)
  if (is.null(model_probes)) {
    model_probes <- sig_probes
  } else {
    # Ensure we use the same probes as in training
    sig_probes <- intersect(model_probes, rownames(beta))
  }
  
  # Prepare data - ensure same order as training
  X <- t(beta[sig_probes, c(cases, controls), drop = FALSE])
  
  # Ensure column order matches training (important for SVM)
  if (!is.null(model_probes) && length(model_probes) == ncol(X)) {
    X <- X[, model_probes, drop = FALSE]
  }
  
  y <- factor(ifelse(c(cases, controls) %in% cases, syndrome, "Control"),
              levels = c("Control", syndrome))
  
  # Get predictions
  pred <- predict(classifiers[[syndrome]]$model, X, probability = TRUE)
  probs <- attr(pred, "probabilities")[, syndrome]
  labels <- as.numeric(y == syndrome)
  
  # Compute ROC
  roc_obj <- roc(response = labels, predictor = probs, quiet = TRUE)
  auc_val <- as.numeric(auc(roc_obj))
  
  # Plot ROC
  png_file <- file.path(OUTPUT_DIR, paste0("roc_curve_", syndrome, ".png"))
  png(png_file, width = 800, height = 600)
  plot(roc_obj, 
       main = paste0("ROC Curve: ", syndrome, " (AUC = ", sprintf("%.3f", auc_val), ")"),
       print.auc = TRUE, 
       legacy.axes = TRUE,
       xlab = "False Positive Rate (1 - Specificity)",
       ylab = "True Positive Rate (Sensitivity)")
  grid()
  dev.off()
  
  cat(sprintf("Generated ROC curve for %s: AUC = %.3f\n", syndrome, auc_val))
}

cat("ROC curve generation complete!\n")
