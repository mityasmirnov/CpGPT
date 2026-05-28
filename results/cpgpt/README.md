# CpGPT results (local copy)

This folder contains a **local copy** of embeddings and UMAP visualizations from **full inference (`make cpgpt_infer`)** for easy access in the project.

## Contents

| File | Description |
|------|-------------|
| `sample_embeddings.pt` | 73 sample embeddings (128-d) from **cpgpt_infer** (Feb 19 01:44) |
| `umap_by_disease.png` | UMAP colored by disease/condition |
| `umap_by_case_control.png` | UMAP colored by case/control |
| `umap_by_gene.png` | UMAP colored by causal genes |
| `umap_by_gse.png` | UMAP colored by GSE (batch effect check) |
| `umap_coordinates.csv` | UMAP coordinates + metadata |

## Canonical location (external volume)

When the external drive is connected, the same outputs live at:

- **Full inference (cpgpt_infer)**: `/Volumes/Dima_work/cpgpt_data/results/cpgpt/`  
  (Embeddings + UMAP from this run; `reconstruction.pt` will appear there when reconstruction completes.)

To regenerate visualizations from existing embeddings:

```bash
# Local embeddings (this folder)
make visualize_embeddings_only RESULTS_DIR=results

# External embeddings
make visualize_embeddings_only RESULTS_DIR=/Volumes/Dima_work/cpgpt_data/results
# (use cpgpt_embeddingsonly path for embeddings: copy sample_embeddings.pt to results/cpgpt/ first or set path in script)
```
