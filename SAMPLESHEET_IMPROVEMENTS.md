# Samplesheet Improvements Summary

**Date**: February 18, 2026  
**Status**: ✓ Completed - Enhanced samplesheet builder with deduplication, batch parsing, and paper fields

## Issues Identified and Fixed

### 1. Deduplication Issue ✓ FIXED

**Problem**: 
- Original samplesheet had **1119 rows** but only **133 unique GEO sample accessions (GSM IDs)**
- Extra rows were duplicates created by `meta_/meta_meta_/meta_meta_meta_` layered columns from merging multiple metadata sources
- Same samples repeated with metadata arriving from different merge layers

**Solution**:
- Created `scripts/build_ajhg2020_samplesheet_enhanced.py`
- Extracts GSM IDs from nested `meta_GSM_ID` columns (handles `meta_GSM_ID`, `meta_meta_GSM_ID`, etc.)
- Deduplicates to **1 row per GSM** using `groupby` with `first_nonnull` aggregation
- Removes nested `meta_meta_meta_...` columns (keeps only first-level `meta_` columns)

**Result**:
- **133 unique GSMs** (matches GEO counts):
  - GSE116992: 29 samples
  - GSE125367: 44 samples  
  - GSE35069: 60 samples

### 2. Missing Batch Information ✓ FIXED

**Problem**:
- Paper uses "experimental batch" for matching covariates (MatchIt)
- GEO doesn't provide explicit "batch" column
- Batch proxy can be recovered from IDAT filenames (Sentrix ID and position)

**Solution**:
- Added `parse_sentrix_from_idat_filename()` function
- Parses pattern: `GSM3267080_101032560039_R02C01_Grn.idat.gz`
  - `sentrix_id` = `101032560039`
  - `sentrix_position` = `R02C01`
- Extracts from `meta_supplementary_file` column

**Result**:
- Batch info extracted for **73/133 samples** (GSE116992 and GSE125367 have IDAT files)
- GSE35069 has "NONE" for supplementary files (no batch info available)

### 3. Missing Paper Table 1 Fields ✓ FIXED

**Problem**:
- Paper Table 1 provides essential context not in GEO metadata:
  - Underlying gene(s)
  - OMIM (MIM) number(s)
  - Training cohort size
  - Testing cohort size
  - Whether episignature was detected

**Solution**:
- Added `AJHG_TABLE1_MAPPING` with paper fields:
  - `paper_abbrev`
  - `paper_underlying_genes`
  - `paper_mim_numbers`
  - `paper_training_n`
  - `paper_testing_n`
  - `paper_episignature_detected`
- Added BAFopathy subtype inference:
  - `baf_subtype` (CSS1, CSS3, CSS4, NCBRS)
  - `baf_gene_inferred` (ARID1B, SMARCB1, SMARCA4, SMARCA2)

**Result**:
- Paper fields added for all BAFopathy samples (7 samples in current dataset)
- BAFopathy subtypes correctly inferred from titles

### 4. Coverage Gap (Still Pending)

**Problem**:
- Paper Data Availability section lists **18 GSEs**
- Current samplesheet only includes **3 GSEs**:
  - GSE116992, GSE125367, GSE35069

**Missing GSEs** (need GEO download/processing):
- GSE66552, GSE74432, GSE97362, GSE116300, GSE95040, GSE104451, GSE55491, GSE108423, GSE89353, GSE52588, GSE42861, GSE85210, GSE87571, GSE87648, GSE99863

**Note**: 3 of these (GSE66552, GSE74432, GSE97362) have been processed to Arrow format but not yet added to samplesheet.

## Files Created

1. **`scripts/build_ajhg2020_samplesheet_enhanced.py`**
   - Deduplication logic
   - Batch parsing from IDAT filenames
   - Paper Table 1 fields
   - BAFopathy subtype inference

2. **`data/ajhg2020/samplesheet_enhanced.parquet`**
   - Deduplicated samplesheet (133 rows)
   - Includes batch info and paper fields

3. **`data/ajhg2020/samplesheet_enhanced.csv`**
   - CSV version for inspection

## Usage

```bash
# Process existing samplesheet with enhancements
python3 scripts/build_ajhg2020_samplesheet_enhanced.py \
  --input-samplesheet data/ajhg2020/samplesheet.parquet \
  --output-dir data/ajhg2020

# Options:
# --deduplicate (default: True) - Deduplicate to 1 row per GSM
# --add-batch-info (default: True) - Parse batch from IDAT filenames
# --add-paper-fields (default: True) - Add paper Table 1 fields
```

## Known Limitations (Documented in Plan)

1. **Training/testing split**: Not recoverable from GEO (paper used 75/25 random split but doesn't provide per-sample assignment)
2. **Age/sex for GSE116992**: Missing in GEO metadata (paper used these for matching)
3. **Paper cohort sizes**: Larger than public GEO (e.g., BAFopathy: 69 in paper vs 29 in public GSE116992 due to ethics restrictions)

## Next Steps

1. **Add missing GSEs**: Process remaining 15 GSEs from GEO and add to samplesheet
2. **Rebuild samplesheet**: Run enhanced builder on full manifest once all GSEs are available
3. **Update label audit**: Re-run audit report with all 18 GSEs
