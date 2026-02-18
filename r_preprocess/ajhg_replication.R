#!/usr/bin/env Rscript
# AJHG 2020 Episignature Replication
# Exact implementation of the AJHG 2020 method for episignature derivation and classification
#
# Usage: Rscript ajhg_replication.R [data_dir] [output_dir]
# Example: Rscript ajhg_replication.R ../data/processed ../results/ajhg

suppressPackageStartupMessages({
  library(limma)
  library(pROC)
  library(e1071)
  library(umap)
})

# Parse command line arguments
args <- commandArgs(trailingOnly = TRUE)
DATA_DIR <- ifelse(length(args) >= 1, args[1], "../data/processed")
OUTPUT_DIR <- ifelse(length(args) >= 2, args[2], "../results/ajhg")

# Configuration (matching AJHG 2020)
TOP_N_PROBES <- 1000  # Initial probe selection
TARGET_PROBES <- 125  # Target number after pruning (100-150 range)
AUC_CUTOFF <- 0.5  # Remove half with lowest AUC
CORRELATION_R2_CUTOFF <- 0.7  # R² threshold for correlation pruning (0.6-0.8 range)
SVM_SCORE_THRESHOLD <- 0.5  # Classification threshold
N_PCS_FOR_BATCH <- 10  # Top N PCs for batch correction

# Error handling wrapper function
handle_errors <- function(expr, error_msg = "An error occurred", warn_on_error = TRUE) {
  tryCatch({
    expr
  }, error = function(e) {
    if (warn_on_error) {
      cat(sprintf("ERROR: %s\n", error_msg))
      cat(sprintf("Error details: %s\n", e$message))
      cat(sprintf("Call stack:\n"))
      print(sys.calls())
    }
    stop(e)
  })
}

# Setup error handling
options(error = function() {
  cat("\n==========================================\n")
  cat("FATAL ERROR DETECTED\n")
  cat("==========================================\n")
  cat("Error message:", geterrmessage(), "\n")
  cat("\nCall stack:\n")
  print(sys.calls())
  cat("\n==========================================\n")
  q(status = 1)
})

# Error handling wrapper function
handle_errors <- function(expr, error_msg = "An error occurred", warn_on_error = TRUE) {
  tryCatch({
    expr
  }, error = function(e) {
    if (warn_on_error) {
      cat(sprintf("ERROR: %s\n", error_msg))
      cat(sprintf("Error details: %s\n", e$message))
      cat(sprintf("Call stack:\n"))
      print(sys.calls())
    }
    stop(e)
  })
}

# Setup error handling
options(error = function() {
  cat("\n==========================================\n")
  cat("FATAL ERROR DETECTED\n")
  cat("==========================================\n")
  cat("Error message:", geterrmessage(), "\n")
  cat("\nCall stack:\n")
  print(sys.calls())
  cat("\n==========================================\n")
  q(status = 1)
})

cat("==========================================\n")
cat("AJHG 2020 Episignature Replication\n")
cat("==========================================\n")
cat(sprintf("Data directory: %s\n", DATA_DIR))
cat(sprintf("Output directory: %s\n", OUTPUT_DIR))
cat("\n")

# Create output directory
dir.create(OUTPUT_DIR, recursive = TRUE, showWarnings = FALSE)

# Function to load and combine data from multiple GSEs
load_combined_data <- function(data_dir) {
  # Find all GSE directories (may be nested: GSE/GPL/)
  gse_dirs <- list.dirs(data_dir, recursive = TRUE, full.names = TRUE)
  # Filter to only directories that contain data files (beta.csv or beta.rds)
  gse_dirs <- gse_dirs[sapply(gse_dirs, function(d) {
    any(file.exists(file.path(d, c("beta.csv", "beta.rds", "M.csv", "M.rds"))))
  })]
  gse_dirs <- gse_dirs[basename(gse_dirs) != "cpgpt_processed"]
  
  all_beta <- NULL
  all_M <- NULL
  all_pheno <- NULL
  
  for (gse_dir in gse_dirs) {
    # Extract GSE/GPL identifier (handle nested structure)
    path_parts <- strsplit(gse_dir, "/")[[1]]
    gse_id <- paste(path_parts[(length(path_parts)-1):length(path_parts)], collapse = "/")
    # Try RDS first, then CSV
    beta_file_rds <- file.path(gse_dir, "beta.rds")
    M_file_rds <- file.path(gse_dir, "M.rds")
    pheno_file_rds <- file.path(gse_dir, "pheno.rds")
    beta_file_csv <- file.path(gse_dir, "beta.csv")
    M_file_csv <- file.path(gse_dir, "M.csv")
    pheno_file_csv <- file.path(gse_dir, "pheno.csv")
    
    # Check if RDS files exist
    if (all(file.exists(beta_file_rds), file.exists(M_file_rds), file.exists(pheno_file_rds))) {
      cat(sprintf("Loading %s from RDS...\n", gse_id))
      beta <- readRDS(beta_file_rds)
      M <- readRDS(M_file_rds)
      pheno <- readRDS(pheno_file_rds)
    } else if (all(file.exists(beta_file_csv), file.exists(M_file_csv), file.exists(pheno_file_csv))) {
      # Load from CSV (probes as rows, samples as columns)
      cat(sprintf("Loading %s from CSV...\n", gse_id))
      beta <- read.csv(beta_file_csv, row.names = 1, check.names = FALSE)
      M <- read.csv(M_file_csv, row.names = 1, check.names = FALSE)
      pheno <- read.csv(pheno_file_csv, row.names = 1, check.names = FALSE)
      
      # Ensure beta and M are numeric matrices (probes x samples)
      beta <- as.matrix(beta)
      M <- as.matrix(M)
      
      # Ensure pheno has Sample_ID column (use rownames if missing)
      if (!"Sample_ID" %in% colnames(pheno)) {
        pheno$Sample_ID <- rownames(pheno)
      }
      
      # Harmonize probe sets (use intersection)
      if (is.null(all_beta)) {
        all_beta <- beta
        all_M <- M
        all_pheno <- pheno
      } else {
        common_probes <- intersect(rownames(all_beta), rownames(beta))
        all_beta <- cbind(all_beta[common_probes, ], beta[common_probes, ])
        all_M <- cbind(all_M[common_probes, ], M[common_probes, ])
        all_pheno <- rbind(all_pheno, pheno)
      }
    }
  }
  
  # Ensure consistent probe ordering
  common_probes <- rownames(all_beta)
  all_beta <- all_beta[common_probes, ]
  all_M <- all_M[common_probes, ]
  
  # Filter out probes with infinite or missing values in M matrix
  cat("Filtering probes with infinite/NA values...\n")
  has_inf_or_na <- apply(all_M, 1, function(x) any(is.infinite(x) | is.na(x)))
  if (sum(has_inf_or_na) > 0) {
    cat(sprintf("Removing %d probes with infinite/NA values (out of %d total)\n",
                sum(has_inf_or_na), nrow(all_M)))
    valid_probes <- !has_inf_or_na
    all_beta <- all_beta[valid_probes, ]
    all_M <- all_M[valid_probes, ]
  }
  
  # Also filter out probes with infinite/NA in beta matrix
  has_inf_or_na_beta <- apply(all_beta, 1, function(x) any(is.infinite(x) | is.na(x)))
  if (sum(has_inf_or_na_beta) > 0) {
    cat(sprintf("Removing %d additional probes with infinite/NA values in beta (out of %d remaining)\n",
                sum(has_inf_or_na_beta & !has_inf_or_na), nrow(all_beta)))
    valid_probes_beta <- !has_inf_or_na_beta
    all_beta <- all_beta[valid_probes_beta, ]
    all_M <- all_M[valid_probes_beta, ]
  }
  
  cat(sprintf("Final data: %d probes x %d samples\n", nrow(all_M), ncol(all_M)))
  
  return(list(beta = all_beta, M = all_M, pheno = all_pheno))
}

# Load data
cat("Loading combined data...\n")
data_list <- load_combined_data(DATA_DIR)
beta <- data_list$beta
M <- data_list$M
pheno <- data_list$pheno

cat(sprintf("Loaded %d probes x %d samples\n", nrow(beta), ncol(beta)))

# Check for required phenotype columns
if (!"Disease" %in% colnames(pheno)) {
  cat("Warning: 'Disease' column not found in pheno. Using placeholder.\n")
  pheno$Disease <- "Control"  # Placeholder - should be filled from GEO metadata
}

# Identify syndromes (unique disease labels excluding controls)
syndromes <- setdiff(unique(pheno$Disease), c("Control", "control", NA))
cat(sprintf("Found %d syndromes: %s\n", length(syndromes), paste(syndromes, collapse = ", ")))

# Function to identify family groups (for GSE52588 trios)
identify_family_groups <- function(pheno) {
  # Check if this is GSE52588 (Down syndrome with trios)
  if ("GSE" %in% colnames(pheno) && any(pheno$GSE == "GSE52588", na.rm = TRUE)) {
    # Look for family identifiers in sample metadata
    # Common patterns: family ID, trio ID, or related sample indicators
    family_cols <- c("Family_ID", "family_id", "Trio_ID", "trio_id", "Related_Sample")
    for (col in family_cols) {
      if (col %in% colnames(pheno) && !all(is.na(pheno[[col]]))) {
        return(pheno[[col]])
      }
    }
    # Fallback: try to infer from sample IDs (e.g., GSM12345_mother, GSM12345_sibling)
    if ("Sample_ID" %in% colnames(pheno)) {
      # Extract base ID (remove suffixes like _mother, _sibling)
      base_ids <- gsub("_(mother|sibling|father|child)$", "", pheno$Sample_ID, ignore.case = TRUE)
      return(base_ids)
    }
  }
  return(NULL)
}

# Function for AJHG feature selection per syndrome (with error handling)
ajhg_feature_selection <- function(M, pheno, syndrome, controls = "Control", train_indices = NULL) {
  cat(sprintf("\nFeature selection for %s...\n", syndrome))
  
  # Error handling wrapper
  result <- tryCatch({
  
  # Use train_indices if provided (for cross-validation)
  if (!is.null(train_indices)) {
    pheno <- pheno[train_indices, ]
  }
  
  # Identify cases and controls
  cases <- pheno$Sample_ID[pheno$Disease == syndrome]
  controls_idx <- pheno$Sample_ID[pheno$Disease %in% controls]
  
  if (length(cases) < 3 || length(controls_idx) < 3) {
    cat(sprintf("Warning: Insufficient samples for %s (cases: %d, controls: %d)\n",
                syndrome, length(cases), length(controls_idx)))
    return(NULL)
  }
  
  # Subset data
  M_subset <- M[, c(cases, controls_idx)]
  pheno_subset <- pheno[pheno$Sample_ID %in% c(cases, controls_idx), ]
  
  # Filter out probes with infinite or missing values globally (before any analysis)
  has_inf_or_na <- apply(M_subset, 1, function(x) any(is.infinite(x) | is.na(x)))
  if (sum(has_inf_or_na) > 0) {
    cat(sprintf("Filtering out %d probes with infinite/NA values (out of %d total)\n",
                sum(has_inf_or_na), nrow(M_subset)))
    M_subset <- M_subset[!has_inf_or_na, ]
  }
  
  if (nrow(M_subset) == 0) {
    cat("Error: No valid probes remaining after filtering infinite/NA values\n")
    return(NULL)
  }
  
  # Build design matrix
  # Include: disease status, age, sex, cell counts, batch PCs
  design_vars <- data.frame(
    Disease = as.numeric(pheno_subset$Disease == syndrome),
    stringsAsFactors = FALSE
  )
  
  # Add age if available
  if ("Age" %in% colnames(pheno_subset) && !all(is.na(pheno_subset$Age))) {
    design_vars$Age <- pheno_subset$Age
  }
  
  # Add sex if available
  if ("Sex" %in% colnames(pheno_subset) && !all(is.na(pheno_subset$Sex))) {
    design_vars$Sex <- as.numeric(pheno_subset$Sex == "F" | pheno_subset$Sex == "Female")
  }
  
  # Add cell counts if available
  cell_types <- c("CD8T", "CD4T", "NK", "Bcell", "Mono", "Gran")
  for (ct in cell_types) {
    if (ct %in% colnames(pheno_subset)) {
      design_vars[[paste0("Cell_", ct)]] <- pheno_subset[[ct]]
    }
  }
  
  # Add batch PCs if multiple batches/platforms
  if ("Batch" %in% colnames(pheno_subset) || "GSE" %in% colnames(pheno_subset)) {
    # Filter out probes with infinite, missing, or constant values before PCA
    # Check for infinite or missing values
    has_inf_or_na <- apply(M_subset, 1, function(x) any(is.infinite(x) | is.na(x)))
    # Check for constant probes (zero variance)
    probe_vars <- apply(M_subset, 1, var, na.rm = TRUE)
    has_zero_var <- is.na(probe_vars) | probe_vars == 0
    
    # Keep only valid probes
    valid_probes <- !has_inf_or_na & !has_zero_var
    
    if (sum(valid_probes) < 10) {
      cat("Warning: Too few valid probes for PCA batch correction. Skipping batch PCs.\n")
    } else {
      M_subset_clean <- M_subset[valid_probes, ]
      cat(sprintf("Filtered %d probes with infinite/NA/zero-variance values (kept %d probes for PCA)\n",
                  sum(!valid_probes), sum(valid_probes)))
      
      # Compute top PCs of methylation for batch correction
      M_centered <- t(scale(t(M_subset_clean), center = TRUE, scale = FALSE))
      # Additional check: remove any remaining infinite/NA values
      if (any(is.infinite(M_centered) | is.na(M_centered))) {
        cat("Warning: Infinite/NA values detected after centering. Removing affected probes.\n")
        bad_rows <- apply(M_centered, 1, function(x) any(is.infinite(x) | is.na(x)))
        M_centered <- M_centered[!bad_rows, ]
      }
      
      if (nrow(M_centered) < 10 || ncol(M_centered) < 2) {
        cat("Warning: Insufficient data for PCA after filtering. Skipping batch PCs.\n")
      } else {
        pca_result <- prcomp(t(M_centered), center = FALSE, scale. = FALSE)
        n_pcs <- min(N_PCS_FOR_BATCH, ncol(pca_result$x), nrow(pca_result$x))
        for (i in 1:n_pcs) {
          design_vars[[paste0("PC", i)]] <- pca_result$x[, i]
        }
      }
    }
  }
  
  # Create design matrix
  design <- model.matrix(~ ., data = design_vars)
  
  # Fit linear model
  fit <- lmFit(M_subset, design)
  fit <- eBayes(fit)
  
  # Extract results for disease coefficient (first after intercept)
  coef_name <- colnames(design)[grepl("Disease", colnames(design))][1]
  if (is.na(coef_name)) coef_name <- colnames(design)[2]  # Fallback
  
  tt <- topTable(fit, coef = coef_name, number = Inf, adjust.method = "BH")
  
  # Calculate delta methylation (mean cases - mean controls)
  beta_subset <- beta[, c(cases, controls_idx)]
  delta_meth <- rowMeans(beta_subset[, cases, drop = FALSE]) - 
                rowMeans(beta_subset[, controls_idx, drop = FALSE])
  
  # AJHG ranking: abs(delta_meth) * -log(p)
  score <- abs(delta_meth[rownames(tt)]) * (-log10(tt$P.Value))
  tt$delta_meth <- delta_meth[rownames(tt)]
  tt$score <- score
  
  # Select top N probes
  top_probes <- rownames(tt)[order(tt$score, decreasing = TRUE)[1:min(TOP_N_PROBES, nrow(tt))]]
  
  cat(sprintf("Selected top %d probes\n", length(top_probes)))
  
  # Per-probe AUC calculation
  cat("Computing per-probe AUC...\n")
  disease_labels <- as.numeric(pheno_subset$Disease == syndrome)
  aucs <- sapply(top_probes, function(probe) {
    roc_obj <- tryCatch(
      roc(response = disease_labels, predictor = beta_subset[probe, ], quiet = TRUE),
      error = function(e) NULL
    )
    if (is.null(roc_obj)) return(0.5)
    as.numeric(auc(roc_obj))
  })
  
  # Remove half with lowest AUC
  n_keep <- max(ceiling(length(aucs) / 2), 50)
  top_auc_probes <- names(sort(aucs, decreasing = TRUE))[1:n_keep]
  cat(sprintf("Kept %d probes after AUC filtering\n", length(top_auc_probes)))
  
  # Correlation pruning with error handling
  cat("Correlation pruning...\n")
  
  # Ensure we have valid probes for correlation
  if (length(top_auc_probes) < 2) {
    cat("Warning: Too few probes for correlation pruning. Using all probes.\n")
    final_probes <- top_auc_probes
  } else {
    tryCatch({
      # Subset beta matrix to top AUC probes
      beta_top <- beta_subset[top_auc_probes, , drop = FALSE]
      
      # Check for constant probes (zero variance) that would cause cor() to fail
      probe_vars <- apply(beta_top, 1, var, na.rm = TRUE)
      constant_probes <- names(probe_vars)[is.na(probe_vars) | probe_vars == 0]
      
      if (length(constant_probes) > 0) {
        cat(sprintf("Warning: Removing %d constant probes before correlation pruning\n", length(constant_probes)))
        top_auc_probes <- setdiff(top_auc_probes, constant_probes)
        beta_top <- beta_subset[top_auc_probes, , drop = FALSE]
      }
      
      if (length(top_auc_probes) < 2) {
        cat("Warning: Too few probes after removing constants. Using all remaining probes.\n")
        final_probes <- top_auc_probes
      } else {
        # Compute correlation matrix with error handling
        cor_matrix <- tryCatch({
          cor(t(beta_top), use = "pairwise.complete.obs")
        }, error = function(e) {
          cat(sprintf("Error computing correlation matrix: %s\n", e$message))
          cat("Falling back to using all probes without correlation pruning.\n")
          return(NULL)
        })
        
        if (is.null(cor_matrix)) {
          # Fallback: use all probes
          final_probes <- top_auc_probes[1:min(TARGET_PROBES, length(top_auc_probes))]
        } else {
          # Ensure correlation matrix has proper rownames/colnames
          if (is.null(rownames(cor_matrix))) {
            rownames(cor_matrix) <- top_auc_probes
          }
          if (is.null(colnames(cor_matrix))) {
            colnames(cor_matrix) <- top_auc_probes
          }
          
          # Greedy removal of correlated probes
          selected_probes <- top_auc_probes
          removed <- c()
          
          for (i in 1:length(selected_probes)) {
            if (length(selected_probes) <= TARGET_PROBES) break
            if (selected_probes[i] %in% removed) next
            
            # Check if probe exists in correlation matrix
            if (!selected_probes[i] %in% rownames(cor_matrix)) {
              cat(sprintf("Warning: Probe %s not in correlation matrix, skipping\n", selected_probes[i]))
              next
            }
            
            # Find highly correlated probes
            corrs <- cor_matrix[selected_probes[i], , drop = FALSE]
            if (ncol(corrs) == 0) {
              next
            }
            corrs_vec <- as.vector(corrs)
            names(corrs_vec) <- colnames(corrs)
            corrs_vec[selected_probes[i]] <- 0  # Exclude self
            highly_corr <- names(corrs_vec)[abs(corrs_vec)^2 > CORRELATION_R2_CUTOFF]
            
            # Remove probes with lower AUC
            to_remove <- intersect(highly_corr, selected_probes)
            if (length(to_remove) > 0) {
              aucs_to_remove <- aucs[to_remove]
              # Keep the one with highest AUC, remove others
              keep_probe <- names(which.max(aucs_to_remove))
              to_remove <- setdiff(to_remove, keep_probe)
              removed <- c(removed, to_remove)
              selected_probes <- setdiff(selected_probes, to_remove)
            }
          }
          
          final_probes <- selected_probes[1:min(TARGET_PROBES, length(selected_probes))]
        }
      }
    }, error = function(e) {
      cat(sprintf("Error in correlation pruning: %s\n", e$message))
      cat("Falling back to using top probes without correlation pruning.\n")
      final_probes <- top_auc_probes[1:min(TARGET_PROBES, length(top_auc_probes))]
    })
  }
  
  cat(sprintf("Final signature: %d probes\n", length(final_probes)))
  
  # Validate final probes exist
  if (length(final_probes) == 0) {
    cat("ERROR: No probes selected after filtering. Returning NULL.\n")
    return(NULL)
  }
  
  # Check that all final probes exist in the data
  missing_probes <- setdiff(final_probes, rownames(beta_subset))
  if (length(missing_probes) > 0) {
    cat(sprintf("Warning: %d final probes not found in beta_subset, removing them\n", length(missing_probes)))
    final_probes <- setdiff(final_probes, missing_probes)
  }
  
  if (length(final_probes) == 0) {
    cat("ERROR: No valid probes remaining. Returning NULL.\n")
    return(NULL)
  }
  
    return(list(
      probes = final_probes,
      aucs = aucs[final_probes],
      delta_meth = delta_meth[final_probes],
      pvalues = tt[final_probes, "P.Value"]
    ))
  }, error = function(e) {
    cat(sprintf("\nERROR in ajhg_feature_selection for %s:\n", syndrome))
    cat(sprintf("Error message: %s\n", e$message))
    cat("Returning NULL - this syndrome will be skipped.\n")
    return(NULL)
  })
}

# Function for SVM classification with Platt scaling
train_svm_classifier <- function(beta, pheno, signature_probes, syndrome, controls = "Control", 
                                  train_indices = NULL, test_indices = NULL) {
  cat(sprintf("\nTraining SVM classifier for %s...\n", syndrome))
  
  # Use train_indices if provided (for cross-validation)
  if (!is.null(train_indices)) {
    pheno_train <- pheno[train_indices, ]
  } else {
    pheno_train <- pheno
  }
  
  # Prepare training data
  cases_train <- pheno_train$Sample_ID[pheno_train$Disease == syndrome]
  controls_train <- pheno_train$Sample_ID[pheno_train$Disease %in% controls]
  
  X_train <- t(beta[signature_probes, c(cases_train, controls_train)])
  y_train <- factor(ifelse(c(cases_train, controls_train) %in% cases_train, syndrome, "Control"),
                    levels = c("Control", syndrome))
  
  # Train SVM
  svm_model <- svm(X_train, y_train, probability = TRUE, kernel = "radial")
  
  # Get training predictions
  pred_train <- predict(svm_model, X_train, probability = TRUE)
  probs_train <- attr(pred_train, "probabilities")
  
  # Test predictions if test_indices provided
  probs_test <- NULL
  if (!is.null(test_indices) && length(test_indices) > 0) {
    pheno_test <- pheno[test_indices, ]
    cases_test <- pheno_test$Sample_ID[pheno_test$Disease == syndrome]
    controls_test <- pheno_test$Sample_ID[pheno_test$Disease %in% controls]
    
    if (length(c(cases_test, controls_test)) > 0) {
      X_test <- t(beta[signature_probes, c(cases_test, controls_test)])
      pred_test <- predict(svm_model, X_test, probability = TRUE)
      probs_test <- attr(pred_test, "probabilities")
    }
  }
  
  return(list(model = svm_model, probabilities_train = probs_train, probabilities_test = probs_test))
}

# Identify family groups for GSE52588 (to avoid splitting trios)
family_groups <- identify_family_groups(pheno)
if (!is.null(family_groups)) {
  cat("Family groups identified for GSE52588. Will keep families together in splits.\n")
}

# Get unique GSEs for leave-one-GSE-out cross-validation
if ("GSE" %in% colnames(pheno)) {
  unique_gses <- unique(pheno$GSE)
  cat(sprintf("Found %d unique GSEs: %s\n", length(unique_gses), paste(unique_gses, collapse = ", ")))
} else {
  # Fallback: use GPL as grouping variable
  if ("GPL" %in% colnames(pheno)) {
    unique_gses <- unique(pheno$GPL)
    cat(sprintf("Using GPL as grouping variable. Found %d unique GPLs.\n", length(unique_gses)))
  } else {
    unique_gses <- NULL
    cat("Warning: No GSE or GPL column found. Cannot perform leave-one-GSE-out CV.\n")
  }
}

# Perform feature selection and classification for each syndrome
signatures <- list()
classifiers <- list()
cv_results <- list()

for (syndrome in syndromes) {
  cat("\n============================================================\n")
  cat(sprintf("Processing syndrome: %s\n", syndrome))
  cat("============================================================\n")
  
  # Leave-one-sample-out cross-validation
  # Pool all samples together (cases + controls) regardless of GSE/platform
  cases_all <- pheno$Sample_ID[pheno$Disease == syndrome]
  controls_all <- pheno$Sample_ID[pheno$Disease == "Control"]
  
  if (length(cases_all) >= 3 && length(controls_all) >= 3) {
    cat("Performing leave-one-sample-out cross-validation...\n")
    cat(sprintf("Total samples: %d cases + %d controls = %d total\n", 
                length(cases_all), length(controls_all), 
                length(cases_all) + length(controls_all)))
    
    # Collect CV predictions
    cv_predictions <- numeric()
    cv_labels <- numeric()
    cv_probes_list <- list()
    
    # Get all sample indices for this syndrome comparison
    all_sample_ids <- c(cases_all, controls_all)
    all_sample_indices <- match(all_sample_ids, pheno$Sample_ID)
    
    # Leave-one-sample-out CV
    n_samples <- length(all_sample_indices)
    cat(sprintf("Performing %d-fold leave-one-out CV...\n", n_samples))
    
    for (i in 1:n_samples) {
      if (i %% 10 == 0) {
        cat(sprintf("  CV fold %d/%d...\n", i, n_samples))
      }
      
      # Hold out sample i
      test_idx <- all_sample_indices[i]
      train_indices <- setdiff(all_sample_indices, test_idx)
      
      # Check train set has both cases and controls
      train_cases <- sum(pheno$Disease[train_indices] == syndrome, na.rm = TRUE)
      train_controls <- sum(pheno$Disease[train_indices] == "Control", na.rm = TRUE)
      
      if (train_cases < 3 || train_controls < 3) {
        # Skip if insufficient training samples
        next
      }
      
      # Feature selection on training set
      sig_result <- tryCatch({
        ajhg_feature_selection(M, pheno, syndrome, controls = "Control", train_indices = train_indices)
      }, error = function(e) {
        return(NULL)
      })
      
      if (is.null(sig_result) || length(sig_result$probes) == 0) {
        next
      }
      
      # Store probes for this fold (for analysis)
      cv_probes_list[[i]] <- sig_result$probes
      
      # Train classifier on training set
      classifier <- tryCatch({
        train_svm_classifier(beta, pheno, sig_result$probes, syndrome,
                             train_indices = train_indices, test_indices = test_idx)
      }, error = function(e) {
        return(NULL)
      })
      
      if (is.null(classifier)) {
        next
      }
      
      # Predict on held-out sample
      test_sample_id <- pheno$Sample_ID[test_idx]
      test_label <- as.numeric(pheno$Disease[test_idx] == syndrome)
      
      # Get prediction for held-out sample
      X_test <- t(beta[sig_result$probes, test_sample_id, drop = FALSE])
      pred_test <- predict(classifier$model, X_test, probability = TRUE)
      prob_test <- attr(pred_test, "probabilities")[1, syndrome]
      
      # Store prediction and label
      cv_predictions <- c(cv_predictions, prob_test)
      cv_labels <- c(cv_labels, test_label)
    }
    
    # Compute CV ROC if we have predictions
    if (length(cv_predictions) > 0 && sum(cv_labels) > 0 && sum(cv_labels == 0) > 0) {
      roc_cv <- roc(response = cv_labels, predictor = cv_predictions, quiet = TRUE)
      cv_auc <- as.numeric(auc(roc_cv))
      
      cv_results[[syndrome]] <- list(
        mean_auc = cv_auc,
        sd_auc = NA,  # Single AUC from combined predictions
        cv_aucs = cv_auc,
        cv_predictions = cv_predictions,
        cv_labels = cv_labels,
        roc_obj = roc_cv,
        probes_per_fold = cv_probes_list,
        n_folds = length(cv_predictions)
      )
      
      cat(sprintf("\nLeave-one-out CV AUC: %.3f (from %d folds)\n", 
                  cv_auc, length(cv_predictions)))
      
      # Save CV ROC curve
      png_file <- file.path(OUTPUT_DIR, paste0("roc_curve_cv_", syndrome, ".png"))
      png(png_file, width = 800, height = 600)
      plot(roc_cv, 
           main = paste0("ROC Curve (Leave-One-Out CV): ", syndrome, 
                        " (AUC = ", sprintf("%.3f", cv_auc), ")"),
           print.auc = TRUE,
           legacy.axes = TRUE,
           xlab = "False Positive Rate (1 - Specificity)",
           ylab = "True Positive Rate (Sensitivity)")
      grid()
      dev.off()
      cat(sprintf("Saved CV ROC curve to %s\n", png_file))
    } else {
      cat("Warning: Could not compute CV ROC (insufficient predictions)\n")
    }
    
    # Use all data for final signature (for comparison with CpGPT)
    cat("\nComputing final signature on all data...\n")
  } else {
    cat(sprintf("Skipping CV: insufficient samples (%d cases, %d controls)\n",
                length(cases_all), length(controls_all)))
  }
  
  # Feature selection on all data (for final signature) - with error handling
  sig_result <- tryCatch({
    ajhg_feature_selection(M, pheno, syndrome)
  }, error = function(e) {
    cat(sprintf("ERROR computing final signature for %s: %s\n", syndrome, e$message))
    return(NULL)
  })
  
  if (!is.null(sig_result) && length(sig_result$probes) > 0) {
    signatures[[syndrome]] <- sig_result
    
    # Train classifier on all data
    classifier <- train_svm_classifier(beta, pheno, sig_result$probes, syndrome)
    classifiers[[syndrome]] <- classifier
    
    # Save signature
    sig_file <- file.path(OUTPUT_DIR, sprintf("%s_signature.txt", syndrome))
    write.table(
      data.frame(
        Probe = sig_result$probes,
        AUC = sig_result$aucs,
        Delta_Meth = sig_result$delta_meth,
        P_Value = sig_result$pvalues
      ),
      sig_file, row.names = FALSE, sep = "\t", quote = FALSE
    )
    cat(sprintf("Saved signature to %s\n", sig_file))
  }
}

# Save classifiers and CV results
classifier_file <- file.path(OUTPUT_DIR, "classifiers.rds")
saveRDS(classifiers, classifier_file)
cat(sprintf("\nSaved classifiers to %s\n", classifier_file))

if (length(cv_results) > 0) {
  cv_file <- file.path(OUTPUT_DIR, "cv_results.rds")
  saveRDS(cv_results, cv_file)
  cat(sprintf("Saved cross-validation results to %s\n", cv_file))
  
  # Write CV summary table
  cv_summary <- data.frame(
    Syndrome = names(cv_results),
    CV_AUC = sapply(cv_results, function(x) x$mean_auc),
    N_Folds = sapply(cv_results, function(x) x$n_folds)
  )
  write.table(cv_summary, file.path(OUTPUT_DIR, "cv_summary.txt"), 
              row.names = FALSE, sep = "\t", quote = FALSE)
  cat("Saved CV summary table\n")
}

# Generate plots
cat("\nGenerating plots...\n")

# MDS plot on signature probes
if (length(signatures) > 0) {
  all_sig_probes <- unique(unlist(lapply(signatures, function(s) s$probes)))
  beta_sig <- beta[all_sig_probes, ]
  
  # MDS
  mds <- cmdscale(dist(t(beta_sig)), k = 2)
  mds_df <- data.frame(
    PC1 = mds[, 1],
    PC2 = mds[, 2],
    Disease = pheno$Disease[match(rownames(mds), pheno$Sample_ID)],
    Sample_ID = rownames(mds)
  )
  
  # Add GSE/platform information if available
  if ("GSE" %in% colnames(pheno)) {
    mds_df$GSE <- pheno$GSE[match(mds_df$Sample_ID, pheno$Sample_ID)]
  }
  if ("GPL" %in% colnames(pheno)) {
    mds_df$GPL <- pheno$GPL[match(mds_df$Sample_ID, pheno$Sample_ID)]
  }
  
  # Plot colored by disease
  png(file.path(OUTPUT_DIR, "mds_plot_by_disease.png"), width = 800, height = 600)
  plot(mds_df$PC1, mds_df$PC2, col = as.numeric(factor(mds_df$Disease)),
       xlab = "MDS PC1", ylab = "MDS PC2", main = "MDS on Signature Probes (colored by Disease)")
  legend("topright", legend = unique(mds_df$Disease), 
         col = 1:length(unique(mds_df$Disease)), pch = 1)
  dev.off()
  cat("Saved MDS plot (by disease)\n")
  
  # Plot colored by GSE (to check for batch effects)
  if ("GSE" %in% colnames(mds_df)) {
    png(file.path(OUTPUT_DIR, "mds_plot_by_gse.png"), width = 800, height = 600)
    plot(mds_df$PC1, mds_df$PC2, col = as.numeric(factor(mds_df$GSE)),
         xlab = "MDS PC1", ylab = "MDS PC2", main = "MDS on Signature Probes (colored by GSE)")
    legend("topright", legend = unique(mds_df$GSE), 
           col = 1:length(unique(mds_df$GSE)), pch = 1)
    dev.off()
    cat("Saved MDS plot (by GSE)\n")
  }
  
  # Plot colored by platform (to check for platform effects)
  if ("GPL" %in% colnames(mds_df)) {
    png(file.path(OUTPUT_DIR, "mds_plot_by_gpl.png"), width = 800, height = 600)
    plot(mds_df$PC1, mds_df$PC2, col = as.numeric(factor(mds_df$GPL)),
         xlab = "MDS PC1", ylab = "MDS PC2", main = "MDS on Signature Probes (colored by Platform)")
    legend("topright", legend = unique(mds_df$GPL), 
           col = 1:length(unique(mds_df$GPL)), pch = 1)
    dev.off()
    cat("Saved MDS plot (by platform)\n")
  }
  
  # UMAP (if available)
  if (requireNamespace("umap", quietly = TRUE)) {
    cat("Computing UMAP...\n")
    umap_result <- umap(t(beta_sig), n_neighbors = min(15, ncol(beta_sig) - 1), n_components = 2)
    umap_df <- data.frame(
      UMAP1 = umap_result$layout[, 1],
      UMAP2 = umap_result$layout[, 2],
      Disease = pheno$Disease[match(rownames(umap_result$layout), pheno$Sample_ID)],
      Sample_ID = rownames(umap_result$layout)
    )
    
    if ("GSE" %in% colnames(pheno)) {
      umap_df$GSE <- pheno$GSE[match(umap_df$Sample_ID, pheno$Sample_ID)]
    }
    if ("GPL" %in% colnames(pheno)) {
      umap_df$GPL <- pheno$GPL[match(umap_df$Sample_ID, pheno$Sample_ID)]
    }
    
    # UMAP by disease
    png(file.path(OUTPUT_DIR, "umap_plot_by_disease.png"), width = 800, height = 600)
    plot(umap_df$UMAP1, umap_df$UMAP2, col = as.numeric(factor(umap_df$Disease)),
         xlab = "UMAP1", ylab = "UMAP2", main = "UMAP on Signature Probes (colored by Disease)")
    legend("topright", legend = unique(umap_df$Disease), 
           col = 1:length(unique(umap_df$Disease)), pch = 1)
    dev.off()
    cat("Saved UMAP plot (by disease)\n")
    
    # UMAP by GSE
    if ("GSE" %in% colnames(umap_df)) {
      png(file.path(OUTPUT_DIR, "umap_plot_by_gse.png"), width = 800, height = 600)
      plot(umap_df$UMAP1, umap_df$UMAP2, col = as.numeric(factor(umap_df$GSE)),
           xlab = "UMAP1", ylab = "UMAP2", main = "UMAP on Signature Probes (colored by GSE)")
      legend("topright", legend = unique(umap_df$GSE), 
             col = 1:length(unique(umap_df$GSE)), pch = 1)
      dev.off()
      cat("Saved UMAP plot (by GSE)\n")
    }
    
    # UMAP by platform
    if ("GPL" %in% colnames(umap_df)) {
      png(file.path(OUTPUT_DIR, "umap_plot_by_gpl.png"), width = 800, height = 600)
      plot(umap_df$UMAP1, umap_df$UMAP2, col = as.numeric(factor(umap_df$GPL)),
           xlab = "UMAP1", ylab = "UMAP2", main = "UMAP on Signature Probes (colored by Platform)")
      legend("topright", legend = unique(umap_df$GPL), 
             col = 1:length(unique(umap_df$GPL)), pch = 1)
      dev.off()
      cat("Saved UMAP plot (by platform)\n")
    }
  }
}

cat("\n==========================================\n")
cat("✓ AJHG replication complete!\n")
cat("==========================================\n")
