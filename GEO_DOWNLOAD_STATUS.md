# GEO Fallback Download Status

**Date**: February 18, 2026  
**Status**: In Progress

## Summary

Downloading missing GSEs from GEO that are not available in CpGCorpus. The download process is running in the background and will process all 15 missing GSEs sequentially.

## CpGCorpus availability for AJHG 2020 GSEs

Confirmed using `scripts/download_ajhg2020_from_cpgcorpus.py` (with AWS S3 `ls`) on February 18, 2026:

| GSE ID    | Description                         | CpGCorpus availability | GEO fallback needed? |
| --------- | ----------------------------------- | ---------------------- | -------------------- |
| GSE116992 | BAFopathies (CSS + NCBRS)          | Yes (GPL13534, GPL21145)| No (optional only)   |
| GSE125367 | NCBRS / SMARCA2                    | Yes (GPL21145)         | No (optional only)   |
| GSE35069  | FlowSorted blood cell types        | Yes (GPL13534)         | No (optional only)   |
| GSE66552  | 7q11.23 CNV (Williams / Dup7)      | No                     | **Yes (GEO-only)**   |
| GSE74432  | Sotos / NSD1                       | No                     | **Yes (GEO-only)**   |
| GSE97362  | Kabuki + CHARGE                    | No                     | **Yes (GEO-only)**   |
| GSE116300 | Kabuki phenotype                   | No                     | **Yes (GEO-only)**   |
| GSE95040  | ICF subtypes                       | No                     | **Yes (GEO-only)**   |
| GSE104451 | Silver-Russell (external control)  | No                     | **Yes (GEO-only)**   |
| GSE55491  | Silver-Russell (external control)  | No                     | **Yes (GEO-only)**   |
| GSE108423 | CJS / KDM5C                        | No                     | **Yes (GEO-only)**   |
| GSE89353  | Unresolved NDD / congenital anomalies | No                  | **Yes (GEO-only)**   |
| GSE52588  | Down syndrome trios                | No                     | **Yes (GEO-only)**   |
| GSE42861  | Rheumatoid arthritis               | No                     | **Yes (GEO-only)**   |
| GSE85210  | Smoking (smokers vs never)         | No                     | **Yes (GEO-only)**   |
| GSE87571  | Aging cohort                       | No                     | **Yes (GEO-only)**   |
| GSE87648  | IBD cases/controls                 | No                     | **Yes (GEO-only)**   |
| GSE99863  | ENID trial (Gambian children)      | No                     | **Yes (GEO-only)**   |

## Completed GSEs (3/15)

1. **GSE66552** (7q11.23 CNV)
   - GPL13534: 45 samples, 485,577 probes
   - Source: geo_processed (series matrix)
   - Status: ✓ Complete

2. **GSE74432** (Sotos)
   - GPL13534: 122 samples, 424,586 probes
   - Source: geo_processed (series matrix)
   - Status: ✓ Complete

3. **GSE97362** (CHARGE + Kabuki)
   - GPL13534: 235 samples, 485,577 probes
   - Source: geo_processed (series matrix)
   - Status: ✓ Complete

## Remaining GSEs (12/15)

The following GSEs are being downloaded and processed:

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

## Monitoring Progress

### Check current status:
```bash
python3 scripts/check_geo_progress.py data/ajhg2020
# or
make check_geo_progress
```

### Check if download process is running:
```bash
ps aux | grep download_all_geo_fallback
```

### View download log:
```bash
tail -f /tmp/geo_download.log
```

## Process Details

The download process:
1. Attempts to download IDAT files first (preferred, requires minfi processing)
2. Falls back to series matrix files if IDATs are not available
3. Processes downloaded files to Arrow format (QCDPB.arrow + metadata.arrow)
4. Updates manifest.parquet with new entries
5. Retries failed downloads up to 2 times per GSE

## Expected Duration

- **Per GSE**: 5-30 minutes (depending on file size and GEO server load)
- **Total**: 1-6 hours for all 12 remaining GSEs

Large datasets (e.g., GSE87571, GSE99863) may take longer.

## Troubleshooting

### If download fails for a specific GSE:

1. **Check if series matrix was downloaded but not processed:**
   ```bash
   ls -lh data/ajhg2020/geo_fallback/<GSE>/<GSE>_series_matrix.txt.gz
   ```
   
   If file exists, process it manually:
   ```bash
   python3 scripts/process_geo_series_matrices.py --gse <GSE> --output-dir data/ajhg2020
   ```

2. **Retry a specific GSE:**
   ```bash
   python3 scripts/download_all_geo_fallback.py \
     --output-dir data/ajhg2020 \
     --gse-list <GSE> \
     --max-retries 3
   ```

3. **Check R package availability:**
   ```bash
   Rscript -e "required_packages <- c('GEOquery', 'minfi', 'arrow', 'feather'); for (pkg in required_packages) { if (!requireNamespace(pkg, quietly = TRUE)) cat('MISSING:', pkg, '\n') }"
   ```

### If R packages are missing:

```r
if (!require("BiocManager")) install.packages("BiocManager")
BiocManager::install(c("GEOquery", "minfi"))
install.packages(c("arrow", "feather"))
```

## Next Steps

Once all downloads are complete:

1. **Rebuild samplesheet** (to include new GSEs):
   ```bash
   make build_samplesheet
   ```

2. **Convert data** to R/CpGPT formats:
   ```bash
   make convert_data
   ```

3. **Continue with pipeline**:
   ```bash
   make ajhg_train cpgpt_prepare cpgpt_infer
   ```

## Files Created

- `data/ajhg2020/geo_fallback/<GSE>/` - Raw GEO downloads
- `data/ajhg2020/raw/<GSE>/<GPL>/betas/QCDPB.arrow` - Processed methylation data
- `data/ajhg2020/raw/<GSE>/<GPL>/metadata/metadata.arrow` - Sample metadata
- `data/ajhg2020/manifest.parquet` - Updated manifest with all entries
