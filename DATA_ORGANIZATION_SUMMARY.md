# AJHG 2020 Data Organization Summary

**Date**: February 18, 2026  
**Status**: ✓ Complete - Data organized, duplicates removed, GEO datasets processed

## Organization Actions Completed

### 1. Data Consolidation ✓
- **Consolidated all data into `raw/` structure**
  - Moved top-level `GSE*/` directories to `data/ajhg2020/raw/GSE*/`
  - Removed duplicate files (verified identical via SHA256)
  - All data now follows consistent structure: `raw/{GSE}/{GPL}/{betas|metadata}/`

### 2. Manifest Updates ✓
- **Updated all manifest paths** to point to `raw/` structure
  - Changed from `data/ajhg2020/GSE*/...` to `raw/GSE*/...`
  - All paths now relative to `data/ajhg2020/`
- **Removed incomplete GEO entries** (3 entries with no actual data)
- **Added processed GEO datasets** (3 new entries)

### 3. GEO Dataset Processing ✓
- **Successfully processed 3 GEO series matrices**:
  - **GSE66552**: 45 samples, 485,577 probes (GPL13534) - 88.7 MB
  - **GSE74432**: 122 samples, 424,586 probes (GPL13534) - 205.3 MB  
  - **GSE97362**: 235 samples, 485,577 probes (GPL13534) - 443.1 MB
- **Converted to Arrow format** compatible with CpGPT pipeline
- **Updated manifest** with proper GPL IDs and file paths

## Final Data Structure

```
data/ajhg2020/
├── manifest.parquet          # Download manifest (7 entries)
├── manifest.csv              # CSV version for inspection
├── samplesheet.parquet       # Sample annotations (307 samples, 100% labeled)
├── raw/                      # All raw data (organized)
│   ├── GSE116992/
│   │   ├── GPL13534/
│   │   │   ├── betas/QCDPB.arrow
│   │   │   └── metadata/metadata.arrow
│   │   └── GPL21145/
│   │       ├── betas/QCDPB.arrow
│   │       └── metadata/metadata.arrow
│   ├── GSE125367/
│   │   └── GPL21145/
│   │       ├── betas/QCDPB.arrow
│   │       └── metadata/metadata.arrow
│   ├── GSE35069/
│   │   └── GPL13534/
│   │       └── metadata/metadata.arrow (no QCDPB)
│   ├── GSE66552/             # GEO processed
│   │   └── GPL13534/
│   │       ├── betas/QCDPB.arrow
│   │       └── metadata/metadata.arrow
│   ├── GSE74432/             # GEO processed
│   │   └── GPL13534/
│   │       ├── betas/QCDPB.arrow
│   │       └── metadata/metadata.arrow
│   └── GSE97362/             # GEO processed
│       └── GPL13534/
│           ├── betas/QCDPB.arrow
│           └── metadata/metadata.arrow
├── processed/                # Converted R/CpGPT formats
│   ├── GSE116992/
│   └── GSE125367/
└── geo_fallback/             # Raw GEO artifacts
    ├── GSE66552/
    │   └── GSE66552_series_matrix.txt.gz
    ├── GSE74432/
    │   └── GSE74432_series_matrix.txt.gz
    └── GSE97362/
        └── GSE97362_series_matrix.txt.gz
```

## Manifest Summary

**Total entries**: 7  
**GSEs**: 6 (GSE116992, GSE125367, GSE35069, GSE66552, GSE74432, GSE97362)  
**GPLs**: 7 (4 GPL13534, 3 GPL21145)

**Sources**:
- `cpgcorpus`: 4 entries (GSE116992×2, GSE125367, GSE35069)
- `geo_processed`: 3 entries (GSE66552, GSE74432, GSE97362)

**Download Status**:
- QCDPB files: 6
- Metadata files: 7
- **Total samples**: 533

**By GSE**:
- GSE116992: 29 samples (cpgcorpus, 2 GPLs)
- GSE125367: 44 samples (cpgcorpus)
- GSE35069: 60 samples (cpgcorpus, metadata only)
- GSE66552: 45 samples (geo_processed)
- GSE74432: 122 samples (geo_processed)
- GSE97362: 235 samples (geo_processed)

## Scripts Created/Updated

1. **`scripts/organize_ajhg_data.py`** (NEW)
   - Consolidates data into `raw/` structure
   - Updates manifest paths
   - Removes incomplete entries
   - Identifies GEO series matrices for processing

2. **`scripts/process_geo_series_matrices.py`** (NEW)
   - Processes existing GEO series matrix files
   - Converts to Arrow format compatible with CpGPT
   - Updates manifest automatically

3. **`scripts/download_geo_fallback.py`** (EXISTING)
   - Downloads GEO data (IDATs or series matrices)
   - Processes to Arrow format

## Next Steps

1. **Rebuild samplesheet** to include GEO datasets:
   ```bash
   python3 scripts/build_ajhg2020_samplesheet.py \
     --manifest-file data/ajhg2020/manifest.parquet \
     --output-dir data/ajhg2020 \
     --report-dir reports
   ```

2. **Convert GEO datasets** to R/CpGPT formats:
   ```bash
   make convert_data
   ```

3. **Continue with pipeline**:
   ```bash
   make ajhg_train cpgpt_prepare cpgpt_infer
   ```

## Notes

- All data is now organized under `raw/` structure
- Manifest paths are consistent and relative
- GEO datasets successfully processed and integrated
- Duplicate files removed (verified identical)
- Ready for downstream analysis
