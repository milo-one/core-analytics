# CoRE Analytics: Script Guide

This folder contains the R analysis scripts for the CoRE Analytics / MILO forensic text-feature workflow. The scripts assume that text features were already produced by the Python feature pipeline and are available as `features_full.csv` plus metadata and, where relevant, PCA or cluster side files.

The current analysis flow is modular: the master script is useful for the original exploratory run, while the newer scripts are meant to be runnable as separate, documented analysis steps.

## Data Location

Most scripts load data through `data_load.R`. The default input folder is:

```text
PROJECT_ROOT/out
```

Several newer scripts fall back to:

```text
PROJECT_ROOT/out
```

Expected input files in the data folder:

```text
features_full.csv
features_by_category.csv
pca_scores.csv
cluster_assignments.csv
```

Not every script needs every file. Fresh PCA scripts mainly need `features_full.csv`; cluster/profile scripts also need cluster assignments.

## Recommended Run Order

1. `master_Surface_clean.R` or the modular sequence `data_load.R` -> `data_clean.R` -> `pca_analysis.R`
2. `clustering.R`
3. `heatmap.R`
4. `pca_plotly_exports.R`
5. `descriptive_diagnostics.R`
6. `manova_posthoc_diagnostics.R`
7. `canonical_discriminant_analysis.R`
8. `efa_sem.R`, `efa_sem_strict.R`, `efa_sem_minres.R`
9. `sem_confirm_5f.R`, then `sem_visualize_5f.R`
10. `lda_milo_train.R`, then `lda_milo_visualize_and_compare.R` or `lda_milo_apply_report.R`
11. `k_factor_axis.R` for the personalized author/person axis

## Core Utilities

| Script | Purpose | Input | Output |
| --- | --- | --- | --- |
| `data_load.R` | Loads and joins the current feature tables, metadata, PCA scores and cluster assignments. Defines `load_data()`. | Data folder with feature and metadata CSVs. | In-memory `full_raw` style data frame. |
| `data_clean.R` | Cleans numeric features for multivariate analysis: NA handling, zero-variance removal and scaling. Defines `clean_numeric()`. | Data frame from `load_data()` or equivalent feature table. | Cleaned numeric matrix, scaled matrix and metadata. |
| `output_tables.R` | Shared table export helpers plus cluster/PCA summary table functions. | Analysis objects produced by other scripts. | CSV tables under the selected `tables/...` folder. |

## Master And Baseline Analysis

| Script | Purpose | Input | Output |
| --- | --- | --- | --- |
| `master_Surface_clean.R` | Cleaner integrated version of the original exploratory master script. Runs the main PCA, clustering and table pipeline. | Current CoRE feature data via `data_load.R`. | Main `tables/` outputs, PCA summaries, cluster summaries. |
| `master_Surface.original.R` | Archived original/long exploratory script. Keep for provenance, but do not use as the primary working version. | Older ad hoc pipeline inputs. | Historical exploratory outputs. |
| `pca_analysis.R` | Runs PCA, variance summaries, loading tables and parallel-analysis style diagnostics. | Cleaned numeric features. | PCA object in memory; `pca_variance.csv`, loading tables and feature lists when exported. |
| `clustering.R` | Runs clustering diagnostics: k-means/hierarchical logic, silhouette, WSS/elbow, Gap statistic and bootstrap stability helpers. | PCA/scaled feature matrix. | Cluster assignments and decision diagnostics. |
| `heatmap.R` | Builds YAML/category heatmaps over PC loadings and selected feature contributions. Includes export logic for PNG/PDF where device support allows it. | PCA loadings and category/YAML feature names. | Heatmap graphics and supporting tables. |
| `pca_plotly_exports.R` | Produces interactive PCA scatterplots by point, cluster and genre/group. | PCA scores, metadata, clusters. | Plotly HTML files under a PCA plot output folder. |

## Diagnostics And Group Tests

| Script | Purpose | Input | Output |
| --- | --- | --- | --- |
| `descriptive_diagnostics.R` | Descriptive statistics and diagnostics for the complete numeric feature set: missingness, zero inflation, distributions, correlations, approximate VIF/redundancy and robust outliers. | `features_full.csv` through `load_data()`. | `tables/descriptive_diagnostics/` CSVs and figures. |
| `manova_posthoc_diagnostics.R` | Recomputes PCA from the current feature matrix, then runs MANOVA/post-hoc diagnostics for cluster, `doc_class` and `genre_group`. Includes pragmatic assumption checks and permutation pseudo-F tests. | Current feature data; old PC/LD columns are ignored. | `tables/manova_posthoc_diagnostics/` summaries, effect sizes, contrasts, assumption diagnostics and report material. |
| `canonical_discriminant_analysis.R` | Canonical Discriminant Analysis / canonical variate analysis for cluster, genre and class structures. Useful for interpreting separation beyond PCA and MANOVA. | Current features, metadata and cluster labels. | `tables/canonical_discriminant/` tables and plots; `canonical_discriminant_report.md`. |

## EFA And SEM

| Script | Purpose | Input | Output |
| --- | --- | --- | --- |
| `efa_sem.R` | Exploratory EFA and SEM workflow. Broader exploratory model search, including feature filtering and factor interpretation. | Current numeric features. | `tables/efa_sem/`, model tables and `efa_sem_report.md`. |
| `efa_sem_strict.R` | Strict-filter EFA/SEM run. This is the preferred compact factor-screening variant when the broader model is too noisy. | Current numeric features. | Strict model tables and `efa_sem_strict_report.md`. |
| `efa_sem_minres.R` | MINRES robustness check for EFA when convergence or extraction method sensitivity matters. | Same feature input as EFA scripts. | MINRES comparison outputs. |
| `sem_confirm_5f.R` | Confirmatory 5-factor SEM based on the selected strict model. | Selected indicators/features and SEM model definition. | SEM fit tables, standardized estimates and model object outputs. |
| `sem_visualize_5f.R` | Visualizes the 5-factor SEM with readable labels and multiple layouts, including spring-style diagrams. | Fitted SEM object from `sem_confirm_5f.R` or rerun model context. | SEM path diagrams under the SEM figure output folder. |

## LDA And Forensic Classification

| Script | Purpose | Input | Output |
| --- | --- | --- | --- |
| `lda_milo_train.R` | Trains classical LDA models: first binary human-vs-KI, then 5-group LDA. Uses existing feature columns rather than rewriting derived variables. | Current feature data. | `tables/lda_milo/`, model bundle `milo_lda_model_bundle.rds`, predictions, confusion matrices and plots. |
| `lda_milo_visualize_and_compare.R` | Visualizes LDA spaces with ellipses, reconstructs original feature contributions to LD axes, applies the saved model to comparison data and writes highlighted scatterplots/reports. Also contains the forensic audit layer for adversarial/mimicry cases. | Saved LDA model bundle plus `TARGET_FEATURE_FILE` or training features. | `tables/lda_milo_visual/` plots, comparison predictions, forensic audit CSVs and text reports. |
| `lda_milo_apply_report.R` | Lightweight application/report script for external feature files. Can report one row or all rows depending on `TARGET_ROW_INDEX` / `TARGET_TEXT_ID`. | Saved LDA model bundle and external `features_full.csv`. | Per-text prediction reports and classification tables. |

Useful optional settings before sourcing LDA comparison scripts:

```r
TARGET_FEATURE_FILE <- "C:/path/to/features_full.csv"
TARGET_ROW_INDEX <- 7
TARGET_TEXT_ID <- "some_text_id"
source("lda_milo_visualize_and_compare.R")
```

## Personalized K-Factor Axis

| Script | Purpose | Input | Output |
| --- | --- | --- | --- |
| `k_factor_axis.R` | Builds a personalized author/person axis in freshly computed PCA space. Scores texts by projection, normalized K-Factor, orthogonal axis distance, center distance and axis similarity. This is not a classifier; it is a custom proximity/orientation metric. | Baseline corpus plus either `REFERENCE_TEXT_IDS`, `REFERENCE_FEATURE_FILE` or `REFERENCE_FEATURE_FOLDER`; optional `TARGET_FEATURE_FILE`. | `tables/k_factor/` scores, reference summaries, nearest-axis tables, feature contributions, `k_factor_report.md`, 3D Plotly axis and `k_factor_axis_bundle.rds`. |
| `k_factor_usage_example.R` | Minimal runner showing how to configure an arbitrary author reference file and target feature file. | User-edited paths. | Calls `k_factor_axis.R`. |
| `corek/` | Draft R package for the K-Factor method. Exposes reusable functions but contains no private reference data, real author axis or forensic thresholds. | Baseline, reference and target feature tables supplied by the user. | Package functions, example script and tests. |

For arbitrary future author/person data:

```r
REFERENCE_FEATURE_FILE <- "C:/path/to/author_reference/features_full.csv"
TARGET_FEATURE_FILE <- "C:/path/to/new_texts/features_full.csv"
PLOT_CONTEXT_CORPUS <- TRUE
source("k_factor_axis.R")
```

Interpret `k_factor` together with `k_axis_distance`: a high projection is only persuasive when the orthogonal distance to the axis is also low.

## Reports And Decision Notes

| File | Purpose |
| --- | --- |
| `analysis_decisions.md` | Main methodological decision log: coverage, clustering, PCA and rationale notes. |
| `cluster_decision_note.md` | Short cluster-number decision note. |
| `cluster_profiles.md` / `cluster_profiles_report.md` | Cluster profile interpretation and supporting evidence. |
| `canonical_discriminant_report.md` | Interpretation of CDA results. |
| `diagnostics_and_manova_report.md` | Combined diagnostics and MANOVA interpretation. |
| `efa_sem_report.md`, `efa_sem_strict_report.md` | EFA/SEM interpretation reports. |
| `sem_model_decision.md` | Decision note for the selected SEM model. |
| `lda_milo_report.md` | LDA training and interpretation report. |
| `integrated_analysis_summary.md` | Cross-analysis summary tying PCA, clustering, MANOVA, CDA, SEM and LDA together. |
| `refactor_notes.md` | Notes from cleaning/refactoring the original scripts. |

## Output Folders

Common output roots:

```text
tables/
tables/descriptive_diagnostics/
tables/manova_posthoc_diagnostics/
tables/lda_milo/
tables/lda_milo_visual/
tables/k_factor/
```

Generated HTML plots may create an accompanying `_files/` folder. Keep the HTML file and that folder together.

## Reproducibility Notes

- Run scripts from the repository root unless a script says otherwise.
- Most stochastic scripts set `SEED <- 123`.
- PCA is intentionally recomputed in several newer scripts so old `PC*` columns do not silently control the analysis.
- Generated outputs should stay out of GitHub unless explicitly intended. In this repository, `out/` and `archive/` are ignored; curated test texts in `data_raw/` are versioned.
- For external comparison data, always create features with the same Python feature pipeline before using the R scripts.


