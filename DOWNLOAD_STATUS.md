# AJHG 2020 Data Download Status

## Summary

**Date**: February 18, 2026  
**Status**: Partial completion - CpGCorpus data downloaded, GEO fallback requires R packages

## Downloaded Datasets

### From CpGCorpus (3 GSEs, 4 GPLs)

1. **GSE116992** (BAFopathies)
   - GPL13534: 7 samples, 485,579 features ✓
   - GPL21145: 22 samples, 865,920 features ✓
   - Total: 29 samples

2. **GSE125367** (NCBRS / SMARCA2)
   - GPL21145: 44 samples, 865,920 features ✓
   - Total: 44 samples

3. **GSE35069** (FlowSorted Blood Cell Types)
   - GPL13534: 60 samples (metadata only, no QCDPB) ✓
   - Total: 60 samples

**Total downloaded**: 133 samples from CpGCorpus

### Missing from CpGCorpus (15 GSEs)

The following GSEs are not available in CpGCorpus and require GEO fallback:

- GSE66552 (7q11.23 CNV)
- GSE74432 (Sotos)
- GSE97362 (CHARGE + Kabuki)
- GSE116300 (Kabuki phenotype)
- GSE95040 (ICF subtypes)
- GSE104451 (Silver-Russell)
- GSE55491 (Silver-Russell)
- GSE108423 (CJS / KDM5C)
- GSE89353 (Unresolved NDD/CA)
- GSE52588 (Down syndrome)
- GSE42861 (Rheumatoid arthritis)
- GSE85210 (Smoking)
- GSE87571 (Aging)
- GSE87648 (IBD)
- GSE99863 (ENID trial)

## GEO Fallback Status

**Status**: Script created but requires R/Bioconductor packages

**Required R packages**:
- `GEOquery` - Download GEO data
- `minfi` - Process IDAT files
- `limma` - Data processing
- `arrow` / `feather` - Arrow format export

**Installation**:
```r
if (!require("BiocManager")) install.packages("BiocManager")
BiocManager::install(c("GEOquery", "minfi", "limma"))
install.packages(c("arrow", "feather"))
```

**Usage**:
```bash
# Download a single GSE from GEO
python3 scripts/download_geo_fallback.py --gse GSE66552 --output-dir data/ajhg2020

# Or run download script with GEO fallback enabled (will attempt for all missing GSEs)
python3 scripts/download_ajhg2020_from_cpgcorpus.py --output-dir data/ajhg2020 --geo-fallback
```

## Samplesheet Status

**Status**: ✓ Complete

- **Total samples**: 307
- **Labeled samples**: 307
- **Labeling rate**: 100.0%

**Metadata sources merged**:
- CpGCorpus metadata (primary)
- Existing samplesheet (preserved labels)
- GEO metadata (when available)
- User-provided metadata (when specified)

**Samplesheet location**: `data/ajhg2020/samplesheet.parquet`

**Label audit report**: `reports/ajhg2020_label_audit.md`

## Files Created

### Data Files
- `data/ajhg2020/manifest.parquet` - Download manifest
- `data/ajhg2020/samplesheet.parquet` - Sample annotations with AJHG labels
- `data/ajhg2020/raw/{GSE}/{GPL}/betas/QCDPB.arrow` - Methylation data
- `data/ajhg2020/raw/{GSE}/{GPL}/metadata/metadata.arrow` - Sample metadata

### Scripts
- `scripts/download_ajhg2020_from_cpgcorpus.py` - CpGCorpus downloader (enhanced)
- `scripts/download_geo_fallback.py` - GEO fallback downloader (NEW)
- `scripts/build_ajhg2020_samplesheet.py` - Samplesheet builder (enhanced with multi-source merging)

### Reports
- `reports/ajhg2020_label_audit.md` - Label audit report

## Next Steps

1. **Install R packages** for GEO fallback (if needed):
   ```r
   BiocManager::install(c("GEOquery", "minfi", "limma"))
   install.packages(c("arrow", "feather"))
   ```

2. **Download missing GSEs** from GEO (optional):
   ```bash
   # Download all missing GSEs
   for gse in GSE66552 GSE74432 GSE97362 GSE116300 GSE95040 GSE104451 GSE55491 GSE108423 GSE89353 GSE52588 GSE42861 GSE85210 GSE87571 GSE87648 GSE99863; do
     python3 scripts/download_geo_fallback.py --gse $gse --output-dir data/ajhg2020
   done
   ```

3. **Continue with pipeline**:
   ```bash
   # Convert data to R/CpGPT formats
   make convert_data
   
   # Run AJHG replication
   make ajhg_train
   
   # Prepare CpGPT data and run inference
   make cpgpt_prepare cpgpt_infer
   ```

## Notes

- CpGCorpus-first approach: Always tries CpGCorpus first, falls back to GEO only if missing
- Multi-source metadata merging: Samplesheet builder intelligently merges metadata from:
  1. CpGCorpus metadata (highest priority)
  2. GEO metadata
  3. User-provided metadata
  4. Existing samplesheet (preserves labels)
- Label preservation: Existing labels are preserved when merging metadata sources
- 100% labeling: All samples in the current samplesheet are labeled
