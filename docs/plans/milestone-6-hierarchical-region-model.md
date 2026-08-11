# Milestone 6 — Hierarchical region model

## Goal
Add a region-aware hierarchical path on top of the existing flat CpGPT baseline, but only after the flat baseline is stable.

The target is to compare:
- flat CpGPT backbone
- hierarchical region-aware CpGPT backbone

on the same multitask / pilot folds for the 5d age / tissue / sex cohort, while reusing the existing masked phenotype modules.

## Hard invariants
1. **Do not aggregate unmapped CpG sites away.**
   Unmapped probes must remain explicit tokens in the model.
2. **Do not collapse probes with no annotation into a single catch-all bucket.**
   If a probe cannot be assigned to a regulatory role, keep it in the residual/unmapped set.
3. **If a gene-level annotation has a regulatory annotation, retain the regulatory level.**
   Prefer the most specific available annotation.
4. **Always differentiate performance for unmapped probes.**
   Report metrics separately for:
   - promoter
   - body
   - regulatory / other annotated roles
   - unmapped / residual probes
5. **If role annotations are absent for a sample, fall back to the flat model behavior.**

## Scope
This milestone is intentionally limited to the region-layer path.

The flat model remains the primary baseline. The hierarchical model adds a region context layer only after the flat baseline is validated on the same folds.

## Data contract
The hierarchical path expects the processed batch to optionally include:
- `region_roles`: integer role IDs per CpG/probe token
- `region_role_names`: human-readable role names
- `unmapped_mask`: optional boolean mask for residual tokens
- `annotation_level`: optional annotation source tag

Suggested role conventions:
- `0 = unmapped / residual`
- `1 = promoter`
- `2 = body`
- `3 = regulatory`
- additional IDs may be used for task-specific roles, but only if they are explicit and auditable

## Model behavior
The hierarchical model should:
1. Keep the original CpG token sequence intact.
2. Add role-aware context for annotated CpGs.
3. Preserve unmapped tokens as individual elements.
4. Use the region layer as an additive / contextual module, not as a replacement for the flat token stream.
5. Return the same public outputs as the flat model:
   - sample embedding
   - methylation reconstruction
   - uncertainty
   - optional condition predictions

## Implementation plan
### 1. Add a hierarchical backbone
Create a `HierarchicalDeepSet`-style module that extends the current CpGPT backbone.

Required behavior:
- accept optional region-role tensors in `encode_sample`
- build region context from annotated tokens only
- inject region context into the CLS / sample representation
- keep the methylation decoder unchanged so the output interface stays compatible

### 2. Add a hierarchical LightningModule path
Create a hierarchical training module that reuses the existing CpGPT training flow, but passes role annotations into the backbone and logs grouped metrics.

Required behavior:
- preserve the existing multitask / reconstruction logic
- keep masked phenotype modules intact
- route the new region-aware batch keys when they exist
- fall back safely when they do not

### 3. Add grouped metrics
During validation and testing, report metrics separately for:
- annotated probes
- promoter probes
- body probes
- regulatory probes
- unmapped probes

If a role is not present in a fold, skip the metric rather than fabricating it.

### 4. Wire an experiment config
Add a dedicated experiment config for the 5d age / tissue / sex cohort.

The config should:
- use the hierarchical module
- start from the stable flat pretrained checkpoint
- set `strict_load = false` so the shared backbone can be loaded while the region layer is initialized anew
- reuse the masked phenotype targets already used by the flat pilot setup

### 5. Keep the flat baseline comparison fixed
Do not change the flat baseline while evaluating the hierarchical path.

Use the same:
- data folds
- preprocessing
- multitask heads
- reporting metrics

## Acceptance criteria
This milestone is done when all of the following hold:
1. The hierarchical model can train end-to-end on the 5d pilot cohort.
2. The flat baseline can be compared to the hierarchical model on the same folds.
3. Region-level metrics are reported separately from unmapped-probe metrics.
4. Unmapped probes remain present in the model graph and are not aggregated away.
5. The model falls back to flat behavior when annotations are missing.
6. A milestone plan and a runnable hierarchical experiment config exist in the repo.

## Out of scope
- replacing the flat baseline
- removing unmapped probes
- collapsing all unannotated probes into a single summary
- changing the existing CpGPT data loader contract unless the new batch fields are present
