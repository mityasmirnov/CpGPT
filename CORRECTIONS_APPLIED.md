# Corrections Applied to AJHG 2020 Pipeline Plan

**Date**: February 18, 2026  
**Based on**: Sanity check review of plan

## Summary

All critical corrections from the sanity check review have been implemented. The pipeline now correctly aligns with AJHG 2020 Table 1 class definitions and implements proper masking-based anomaly detection to avoid leakage.

---

## ✅ Corrections Implemented

### 1. AJHG Label Scheme Fixed ✅

**Issue**: Plan used separate classes for CSS vs NCBRS and ICF2/3/4, but AJHG Table 1 groups them.

**Fix Applied**:
- **BAFopathy**: Now a single class (not `BAFopathy_CSS` vs `BAFopathy_NCBRS` separate)
  - Subtype information preserved in `subtype` column (`BAFopathy_subtype_CSS` or `BAFopathy_subtype_NCBRS`) for exploratory analysis
- **ICF**: Now `ICF1` vs `ICF2_3_4` (not ICF2/3/4 separate)
  - Subtype information preserved in `subtype` column (`ICF_subtype_1/2/3/4`) for exploratory analysis

**Files Modified**:
- `scripts/build_ajhg2020_samplesheet.py`:
  - Updated `label_gse116992()` to return `BAFopathy` (single class)
  - Updated `label_gse125367()` to return `BAFopathy` (single class)
  - Updated `label_gse95040()` to return `ICF1` or `ICF2_3_4` (grouped)
  - Updated `AJHG_TABLE1_MAPPING` dictionary
  - Added subtype extraction logic
  - Added `subtype` column to samplesheet

---

### 2. Silver-Russell Marked as External Controls ✅

**Issue**: Silver-Russell datasets (GSE104451, GSE55491) are not in AJHG Table 1.

**Fix Applied**:
- Created `label_silver_russell()` function
- Labels Silver-Russell samples as `ExternalControl_SilverRussell`
- Added to `EXTERNAL_CONTROL_MAPPING` dictionary
- Updated `apply_labeling_rules()` to handle Silver-Russell GSEs
- Updated mapping function to handle external controls

**Files Modified**:
- `scripts/build_ajhg2020_samplesheet.py`:
  - Added `label_silver_russell()` function
  - Added `EXTERNAL_CONTROL_MAPPING` dictionary
  - Updated `add_ajhg_mapping()` to handle external controls

---

### 3. Preprocessing Gating Fixed ✅

**Issue**: Plan would run minfi preprocessing on CpGCorpus QCDPB data (already processed), causing double-processing.

**Fix Applied**:
- Updated plan documentation to clarify preprocessing is gated by source:
  - **CpGCorpus QCDPB**: Only QC + M-value transformation (no minfi)
  - **GEO IDAT**: Full minfi pipeline
  - **GEO processed betas**: Minimal QC + M-value transformation (no re-normalization)
- Conversion script already handles CpGCorpus correctly (no minfi call)

**Files Modified**:
- Plan document: Section 3 updated with gating logic
- `scripts/convert_cpgcorpus_to_r_format.py`: Already correct (no minfi calls)

---

### 4. CpGPT DataSaver Fixed ✅

**Issue**: Plan stated `species` column is required, but it's optional. Also, `sample_id` must be first column.

**Fix Applied**:
- Updated conversion script to ensure `sample_id` is first column
- `species` column is optional (defaults to `homo_sapiens` if missing)
- Column order: `sample_id` (first) → `species` (optional) → probe IDs

**Files Modified**:
- `scripts/convert_cpgcorpus_to_r_format.py`:
  - Added `sample_id` as first column in `beta_cpgpt.feather`
  - Ensured proper column ordering

---

### 5. Anomaly Detection Masking Implemented ✅

**Issue**: Direct residual computation leaks observed values into predictions, masking true epimutations.

**Fix Applied**:
- Added `compute_anomaly_scores_masked()` function for masking-based detection
- Added `--use-masking` and `--mask-cpgs` command-line flags
- Documented three approaches:
  1. Targeted masking (for signature CpGs)
  2. Stochastic masking (for genome-wide burden)
  3. Embedding-only global outlier detection

**Files Modified**:
- `scripts/anomaly_detection.py`:
  - Added `compute_anomaly_scores_masked()` function
  - Added masking command-line arguments
  - Updated documentation

---

### 6. MPS Support Verification ⏳

**Issue**: Need to verify both device selection AND Lightning accelerator are configured.

**Status**: Pending verification
- Plan updated with note to verify MPS support
- Code review needed: `cpgpt/infer/cpgpt_inferencer.py`

**Action Required**:
- Verify `torch.backends.mps.is_available()` check
- Verify Lightning accelerator configuration (`accelerator="mps"`)

---

### 7. Evaluation Improvements ⏳

**Issue**: Need leave-one-GSE-out splits and family structure handling.

**Status**: Pending implementation
- Plan updated with evaluation requirements
- AJHG replication script needs updates

**Action Required**:
- Update `r_preprocess/ajhg_replication.R` to use leave-one-GSE-out splits
- Add family structure handling for GSE52588 (trios)
- Add batch/platform coloring to UMAP plots

---

### 8. CpGPT Full Inference (cpgpt_infer) Fixes ✅ (Feb 19, 2026)

**Context**: Running `make cpgpt_infer` to produce both sample embeddings and reconstruction for anomaly detection.

**Fixes Applied**:

1. **Makefile**
   - `cpgpt_infer` now passes `--batch-size 1` to the inference script to avoid OOM on 16GB systems (reconstruction over ~450k–900k loci is memory-heavy).

2. **`scripts/cpgpt_inference.py`**
   - **Predict return type**: `CpGPTTrainer.predict()` returns a single **dict** of concatenated tensors (keyed by `return_keys`), not a list of per-batch dicts. The script was updated to use `embeddings["sample_embedding"]` and `reconstructions["pred_meth"]` / `reconstructions["pred_meth_unc"]` directly instead of `torch.cat([e["sample_embedding"] for e in embeddings], dim=0)`.
   - **Datamodule for reconstruction**: Reconstruct mode requires `trainer.datamodule` in the model’s `on_predict_epoch_start` (for embedder and hparams). Both predict calls now use `datamodule=data_module` instead of `dataloaders=data_module.predict_dataloader()`.
   - **Genomic locations**: Reconstruct mode requires a `genomic_locations` kwarg. Added `load_genomic_locations_from_processed_dir()` to read locations from `processed_dir/genomic_locations.db` (by species) and pass `genomic_locations=...` into the reconstruction `predict()` call. If the DB or species is missing, reconstruction is skipped and a clear message is printed.
   - **Sample IDs**: Sample IDs are loaded from `obs_names.npy` in each processed dataset directory via `load_sample_ids_from_processed_dir()` instead of being inferred from the dataloader loop.
   - **Progress output**: Added `flush=True` on key prints so progress is visible when stdout is redirected (e.g. `tee` to a log file).

3. **UMAP visualization**
   - **Samplesheet format**: `scripts/visualize_embeddings_umap.py` now supports both CSV and Parquet samplesheets (uses `pd.read_parquet` when path ends with `.parquet`).
   - **Makefile**: `visualize_embeddings` uses `samplesheet.csv`; added target `visualize_embeddings_only` to visualize existing `sample_embeddings.pt` without re-running embeddings (useful with `RESULTS_DIR` override for external volume).

**Files Modified**:
- `Makefile`: `--batch-size 1` for `cpgpt_infer`; `visualize_embeddings` samplesheet → CSV; new `visualize_embeddings_only` target.
- `scripts/cpgpt_inference.py`: dict-based predict handling, datamodule usage, genomic_locations loading, sample ID loading from processed dir, flush on prints.
- `scripts/visualize_embeddings_umap.py`: load_samplesheet supports CSV and Parquet.

**Usage (external volume)**:
```bash
# Full inference (embeddings + reconstruction)
PYTHON=python3 make cpgpt_infer \
  DEPENDENCIES_DIR=/Volumes/Dima_work/cpgpt_data/dependencies \
  RESULTS_DIR=/Volumes/Dima_work/cpgpt_data/results \
  CPGPT_PROCESSED_DIR=/Volumes/Dima_work/cpgpt_data/data/cpgpt_processed

# Visualize existing embeddings only
PYTHON=python3 make visualize_embeddings_only RESULTS_DIR=/Volumes/Dima_work/cpgpt_data/results
```

---

## Files Modified

1. ✅ `scripts/build_ajhg2020_samplesheet.py` - Label scheme corrections
2. ✅ `scripts/convert_cpgcorpus_to_r_format.py` - DataSaver sample_id fix
3. ✅ `scripts/anomaly_detection.py` - Masking-based detection
4. ✅ Plan document - All corrections documented
5. ✅ `Makefile` - cpgpt_infer batch-size 1, visualize_embeddings samplesheet, visualize_embeddings_only target (Feb 19, 2026)
6. ✅ `scripts/cpgpt_inference.py` - Predict dict handling, datamodule, genomic_locations, sample IDs (Feb 19, 2026)
7. ✅ `scripts/visualize_embeddings_umap.py` - Samplesheet CSV/Parquet support (Feb 19, 2026)

## Testing Checklist

- [ ] Rebuild samplesheet with corrected labels
- [ ] Verify BAFopathy is single class in samplesheet
- [ ] Verify ICF is ICF1 vs ICF2_3_4 in samplesheet
- [ ] Verify Silver-Russell marked as ExternalControl
- [ ] Verify beta_cpgpt.feather has sample_id as first column
- [ ] Test anomaly detection with `--use-masking` flag
- [ ] Verify MPS support in inferencer
- [ ] Update AJHG replication with leave-one-GSE-out splits

## Next Steps

1. Rebuild samplesheet: `python3 scripts/build_ajhg2020_samplesheet.py`
2. Verify corrected labels in samplesheet
3. Continue with CpGPT data preparation
4. Implement evaluation improvements (leave-one-GSE-out, family structure)
5. Verify MPS support

---

## References

- AJHG 2020 Table 1: [PMC7058829](https://pmc.ncbi.nlm.nih.gov/articles/PMC7058829/)
- CpGPT repository: [GitHub](https://github.com/lcamillo/CpGPT)
