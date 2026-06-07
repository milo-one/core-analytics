# CoRE Analytics - Computational Behavioral Linguistics (CBL)

This repository documents the computational pipeline and codebook artifacts for the CoRE research framework.

## Repository Structure

- `config/` - YAML category definitions and pipeline configuration.
- `pipeline/` - Python extraction, audit, vectorization, merge, and PCA/KMeans scripts.
- `data_raw/` - versioned test text fixtures used by the pipeline.
- `data/` - explicitly allowed test artifacts, including `features_full.csv`.
- `out/` - generated pipeline output, ignored by Git.
- `r/` - downstream R analysis scripts, grouped by analysis stage.
- `r-packages/corek/` - placeholder for the future K-Factor R package.
- `meta/` - codebook, regex audit, project log and compact analysis notes.

## Pipeline Architecture

1. **Regex/YAML feature system:** Category definitions live as YAML files in `config/`.
2. **Extraction:** Python scripts in `pipeline/` load raw `.txt` files from `data_raw/`, compile category regexes, and produce category/style feature matrices in `out/`.
3. **Integration:** Category and style features are merged into `features_full.csv`.
4. **Analysis:** R scripts in `r/` operate on the feature matrix for PCA, clustering, diagnostics, SEM, LDA and K-Factor analysis.


## Reproduce The Analysis

For a step-by-step reproduction path from `git clone` through the Python pipeline and downstream R scripts, see:

```text
docs/reproduce_full_analysis.md
```
## Python Setup

```bash
pip install -r requirements.txt
```

The configured spaCy model is read from `config/config.yaml`. If it is missing, the pipeline tries to download it automatically during the style-feature step.

## Test Data

- Text fixtures: `data_raw/`
- Feature fixture: `data/features_full.csv`
- Generated local outputs: `out/` (ignored)

## R Analysis

See:

```text
r/README_Scripts.md
```

The R scripts are grouped into:

```text
r/core/
r/pca_cluster/
r/diagnostics/
r/sem/
r/lda/
r/k_factor/
```

## Reproducibility Artifacts

- `meta/codebook_final.csv` - final category codebook with descriptions and anchor examples.
- `meta/codebook_final_qa.csv` - completeness QA for the final codebook.
- `meta/codebook_alignment_report.csv` - alignment between the Excel codebook and current YAML categories.
- `meta/yaml_regex_audit.csv` - regex audit export for all YAML category patterns.
- `meta/regex_refactor_notes.md` - conservative regex-cleaning notes before PCA preparation.
- `meta/analysis/kurzbericht_2026-06-07.md` - compact analysis/script status note.

## Data Policy

Only the curated test fixtures in `data_raw/` and explicitly allowed files in `data/` are intended for version control. Generated outputs in `out/`, archived local runs in `archive/`, and private/raw study material must not be committed.

