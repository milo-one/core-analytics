# CoRE Analytics - Computational Behavioral Linguistics (CBL)

This repository documents the computational pipeline and codebook artifacts for the preregistered CoRE research framework.

## Current Repository State

The current working pipeline is preserved in its original project-root layout:

- `config/` - YAML category definitions and pipeline configuration.
- `pipeline/` - Python extraction, audit, vectorization, merge, and PCA/KMeans scripts.
- `meta/` - codebook, regex audit, and methodological trace files.
- `python/` - early placeholder structure retained from repository initialization.
- `r/` - placeholder structure for downstream statistical analysis scripts.
- `data/` - ignored by default except synthetic examples.

## Pipeline Architecture

1. **Regex/YAML feature system:** Category definitions live as YAML files in `config/`.
2. **Extraction:** Python scripts in `pipeline/` load raw `.txt` files from `data_raw/`, compile category regexes, and produce category/style feature matrices in `out/`.
3. **Integration:** Category and style features are merged into `features_full.csv`.
4. **Analysis:** PCA/KMeans scripts operate on the numeric feature matrix for exploratory structure checks before downstream preregistered analysis.

## Reproducibility Artifacts

- `meta/codebook_final.csv` - final category codebook with descriptions and anchor examples.
- `meta/codebook_final_qa.csv` - completeness QA for the final codebook.
- `meta/codebook_alignment_report.csv` - alignment between the Excel codebook and current YAML categories.
- `meta/yaml_regex_audit.csv` - regex audit export for all YAML category patterns.
- `meta/regex_refactor_notes.md` - conservative regex-cleaning notes before PCA preparation.

## Python Setup

```bash
pip install -r python/requirements.txt
python -m spacy download de_core_news_lg
```

The current pipeline additionally uses the third-party `regex` package for Unicode-aware and advanced regular expressions.

## Data Policy

Raw data are not versioned in this repository. The `.gitignore` keeps `data/` locked except explicitly allowed synthetic sample files.
