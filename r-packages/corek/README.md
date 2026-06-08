# corek

`corek` is a small R package skeleton for the CoRE Analytics K-Factor method.
It exposes the method but does not include private reference texts, real author
features, trained axes, forensic thresholds or raw data.

## What The Package Does

- fits a PCA feature space from a baseline feature matrix
- projects arbitrary `features_full.csv` data into that PCA space
- fits a personalized K-Factor axis from reference texts
- scores target texts by:
  - `k_projection`
  - `k_factor`
  - `k_axis_distance`
  - `k_center_distance`
  - `k_axis_similarity`
- reconstructs original feature contributions to the K-axis
- searches nearest texts in the shared PCA space
- estimates movement toward the axis, its center or another text
- optionally creates 3D Plotly visualizations
- writes a compact Markdown report

## What Stays Private

Do not commit these into the package:

```text
private/
data_raw/
out/
real_author_reference_features.csv
*_axis_bundle.rds
forensic_thresholds*.rds
raw_texts/
```

The method can be public while the empirical reference spaces remain private.

## Included Example Data

The package includes one small demonstration feature file:

```text
inst/extdata/kafka_features_full.csv
```

It contains derived feature values for Franz Kafka texts and no raw text. The
underlying original texts were obtained from Project Gutenberg and are used here
only to demonstrate the workflow. This is not an official Project Gutenberg
dataset.

## Minimal Workflow

Use this minimal path when you only want to build and inspect an author/person
axis. A `target` file is not required for this.

```r
library(corek)

baseline <- k_read_features("C:/path/to/baseline/features_full.csv")
reference <- k_read_features("C:/path/to/author_reference/features_full.csv")

pca_space <- fit_pca_space(baseline, pc_count = 52)
reference_scores <- project_pca_space(reference, pca_space)

axis <- fit_k_axis(reference_scores)
scored_reference <- score_k_axis(reference_scores, axis)
contrib <- k_feature_contributions(axis, pca_space, top_n = 40)

k_write_report(scored_reference, axis, contrib, "k_factor_report.md")

nearest_reference <- k_nearest_texts(scored_reference, n = 20, order_by = "axis_distance")
movement <- k_move_toward(
  scored_reference,
  from_text_id = scored_reference$text_id[1],
  to = "axis",
  axis = axis,
  pca_space = pca_space,
  top_n = 20
)

bundle <- list(
  pca_space = pca_space,
  axis = axis,
  created_at = Sys.time()
)
save_k_axis_bundle(bundle, "private/example_axis_bundle.rds")
```

To score new or external texts against the same axis, add a target file after
the axis has been fitted:

```r
target <- k_read_features("C:/path/to/new_texts/features_full.csv")
target_scores <- project_pca_space(target, pca_space)
scored_target <- score_k_axis(target_scores, axis)

k_write_report(scored_target, axis, contrib, "target_k_factor_report.md")
```

## Reading The Metric

`k_factor` is not a class label. It is a normalized projection on a reference
axis. A high `k_factor` only becomes meaningful when `k_axis_distance` is also
low. A text can project strongly in the same direction while still being far
away from the reference axis.

## Package Status

This is a preparation scaffold. It is intentionally compact and should be
extended with roxygen documentation, vignettes, tests and a formal method note
before publication.

See `docs/how_to_k_factor_corek.md` for the full workbench workflow.
