# Reproduce The Full Analysis

This guide shows how to reproduce the public CoRE Analytics pipeline from the repository test fixtures. It is written for a new user who starts from a fresh clone and wants to generate the feature matrix and run the downstream R analyses.

The repository contains curated test text fixtures in `data_raw/` and a checked feature fixture in `data/features_full.csv`. Generated outputs are written to `out/` and are ignored by Git.

## 1. Clone The Repository

```bash
git clone https://github.com/milo-one/core-analytics.git
cd core-analytics
```

## 2. Create A Python Environment

Windows PowerShell:

```powershell
python -m venv .venv
.\.venv\Scripts\Activate.ps1
python -m pip install --upgrade pip
pip install -r requirements.txt
```

macOS/Linux:

```bash
python -m venv .venv
source .venv/bin/activate
python -m pip install --upgrade pip
pip install -r requirements.txt
```

The configured spaCy model is read from `config/config.yaml`:

```yaml
spacy:
  model: "de_core_news_lg"
```

The pipeline tries to download the configured model automatically if it is missing. To install it manually instead, run:

```bash
python -m spacy download de_core_news_lg
```

## 3. Run The Python Feature Pipeline

```bash
python run_pipeline.py
```

The pipeline reads text fixtures from:

```text
data_raw/
```

and writes generated outputs to:

```text
out/
```

Expected key outputs:

```text
out/category_features.csv
out/style_features.csv
out/features_full.csv
out/pca_scores.csv
out/cluster_labels.csv
```

The public feature fixture is also available as:

```text
data/features_full.csv
```

Use `out/features_full.csv` when you want to reproduce the full pipeline from raw text fixtures. Use `data/features_full.csv` when you want to start from the already generated feature table.

## 4. Quick Sanity Checks

Python-side checks:

```bash
python -m compileall -q pipeline config run_pipeline.py
```

Check that the feature table exists:

Windows PowerShell:

```powershell
Get-Item out\features_full.csv
```

macOS/Linux:

```bash
ls -lh out/features_full.csv
```

## 5. Prepare R

Open R or RStudio from the repository root. Install the packages needed for the R analyses you want to run.

Core packages used across many scripts:

```r
install.packages(c(
  "tidyverse",
  "ggplot2",
  "plotly",
  "MASS",
  "psych"
))
```

Additional packages needed by some optional scripts:

```r
install.packages(c(
  "cluster",
  "factoextra",
  "fpc",
  "effectsize",
  "pROC",
  "glue",
  "lavaan",
  "semPlot",
  "htmlwidgets"
))
```

`ComplexHeatmap` is distributed through Bioconductor:

```r
install.packages("BiocManager")
BiocManager::install("ComplexHeatmap")
```

## 6. Minimal R Reproduction

The minimal R path checks that the feature matrix can be read, summarized, and plotted.

```r
source("r/diagnostics/descriptive_diagnostics.R")
source("r/pca_cluster/pca_plotly_exports.R")
```

Expected output folders include:

```text
tables/descriptive_diagnostics/
pca_plotly/
```

Depending on which scripts are run, output paths may also appear under `tables/...`. Generated R outputs are local analysis artifacts and should not be committed unless explicitly intended.

## 7. Full R Analysis Sequence

The R scripts are grouped by analysis stage. A practical full sequence is:

```r
source("r/diagnostics/descriptive_diagnostics.R")
source("r/diagnostics/manova_posthoc_diagnostics.R")
source("r/diagnostics/canonical_discriminant_analysis.R")

source("r/pca_cluster/pca_plotly_exports.R")

source("r/sem/efa_sem.R")
source("r/sem/efa_sem_strict.R")
source("r/sem/efa_sem_minres.R")
source("r/sem/sem_confirm_5f.R")
source("r/sem/sem_visualize_5f.R")

source("r/lda/lda_milo_train.R")
source("r/lda/lda_milo_visualize_and_compare.R")

source("r/k_factor/k_factor_axis.R")
```

Notes:

- Some analyses are computationally heavier than the Python fixture pipeline.
- SEM and LDA scripts may require additional packages listed above.
- K-Factor is a custom axis metric, not a classifier. Interpret `k_factor` together with `k_axis_distance`.
- The future `corek` R package is currently represented by a placeholder under `r-packages/corek/`.

## 8. Expected Output Areas

Common local output folders:

```text
out/
tables/
tables/descriptive_diagnostics/
tables/manova_posthoc_diagnostics/
tables/lda_milo/
tables/lda_milo_visual/
tables/k_factor/
```

These outputs are generated artifacts. The repository keeps `out/` ignored by default; additional large or private output folders should also remain local.

## 9. Data Policy

Versioned test inputs:

```text
data_raw/
data/features_full.csv
```

Ignored or local-only data areas:

```text
out/
archive/
data_raw_private/
private/
```

Only curated test fixtures should be committed. Private study data, author reference axes, trained K-Factor bundles, forensic thresholds, and raw non-public texts should remain outside Git.

## 10. Troubleshooting

### spaCy model missing

Run:

```bash
python -m spacy download de_core_news_lg
```

or check the configured model in:

```text
config/config.yaml
```

### R cannot find files

Run R from the repository root, or use absolute paths when sourcing scripts. Most scripts infer the repository root from their own file path, but starting from the root is the most predictable workflow.

### R package missing

Install the package named in the error message. For `ComplexHeatmap`, use Bioconductor:

```r
install.packages("BiocManager")
BiocManager::install("ComplexHeatmap")
```

### Pipeline output differs from `data/features_full.csv`

That can happen if category YAML files, dependencies, spaCy versions, or preprocessing rules changed. Treat `data/features_full.csv` as the checked public fixture and `out/features_full.csv` as the locally regenerated output.

## 11. One-Page Command Summary

```bash
git clone https://github.com/milo-one/core-analytics.git
cd core-analytics
python -m venv .venv
.venv\Scripts\activate
python -m pip install --upgrade pip
pip install -r requirements.txt
python run_pipeline.py
```

Then in R:

```r
source("r/diagnostics/descriptive_diagnostics.R")
source("r/pca_cluster/pca_plotly_exports.R")
```
