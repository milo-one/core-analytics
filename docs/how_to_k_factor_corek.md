# How to Run the K-Factor Workbench

This guide describes the optional `corek` workflow for building a personalized
K-Factor axis from reference texts, projecting a comparison corpus into the same
PCA feature space and inspecting nearest texts and movement directions.

The workflow is intended as an additional analysis option. It does not replace
the main PCA, clustering, SEM or LDA scripts.

## 1. Prepare Feature Files

Run the Python feature pipeline first, or provide already processed
`features_full.csv` files with the same feature schema.

The workbench expects:

- a baseline corpus, used to fit the PCA feature space
- a reference corpus for one person or author, used to fit the person axis
- optionally, a target corpus to score against the same axis

The package includes a small Kafka demonstration feature file:

```text
r-packages/corek/inst/extdata/kafka_features_full.csv
```

It contains derived features only, not raw text.

Default paths in the local example are:

```r
BASELINE_FEATURE_FILE <- "C:/Users/Kathrin Preuß/OneDrive/Dokumente/core-analytics/data/features_full.csv"
REFERENCE_FEATURE_FILE <- "inst/extdata/kafka_features_full.csv"
TARGET_FEATURE_FILE <- NULL
```

For other authors or target texts, replace these paths with local
`features_full.csv` files on your machine.

## 2. Start R in the Package Folder

```r
setwd("C:/path/to/core-analytics/r-packages/corek")
```

If the package is not installed, the workbench sources the local package files
from the `R/` folder. If it is installed, it can use `library(corek)` instead.

## 3. Run the Default Workbench

```r
source("inst/examples/k_factor_corek_workbench.R")
```

By default, this uses the repository test feature fixture as the baseline corpus
and the included Kafka feature file as the reference author corpus.

The script writes results to:

```r
examples_out/k_factor_workbench
```

## 4. Configure Paths and Output

Set variables before sourcing the script:

```r
BASELINE_FEATURE_FILE <- "C:/path/to/baseline/features_full.csv"
REFERENCE_FEATURE_FILE <- "C:/path/to/author/features_full.csv"
TARGET_FEATURE_FILE <- "C:/path/to/target/features_full.csv"
OUTPUT_DIR <- "examples_out/kafka_axis"

source("inst/examples/k_factor_corek_workbench.R")
```

The same settings can be supplied as environment variables with the prefix
`COREK_`, for example `COREK_REFERENCE_FEATURE_FILE`.

## 5. Search Nearest Texts

To find the nearest texts to a specific text in the shared PCA space:

```r
QUERY_TEXT_ID <- "author__bush__farewell_address__2009__speech__01"
NEAREST_N <- 20

source("inst/examples/k_factor_corek_workbench.R")
```

The result is written to:

```text
query_nearest_texts.csv
```

The table contains Euclidean distance to the query text, K-Factor projection,
axis distance and center distance.

## 6. Find Texts Closest to the Person Axis

Without `QUERY_TEXT_ID`, the workbench writes the closest texts from the
baseline corpus to the person axis:

```text
nearest_reference_corpus_to_axis.csv
```

This is useful for asking: Which texts in the comparison corpus lie nearest to
the author/person axis?

## 7. Estimate Movement Toward the Axis

To ask how a text would need to move toward the nearest point on the person
axis:

```r
MOVEMENT_TEXT_ID <- "author__bush__farewell_address__2009__speech__01"
MOVEMENT_TO <- "axis"
TOP_FEATURES_N <- 20

source("inst/examples/k_factor_corek_workbench.R")
```

Outputs:

```text
movement_summary.csv
movement_top_feature_changes.csv
```

`movement_top_feature_changes.csv` lists the strongest standardized feature
directions. `increase` means the feature would move upward in standardized
feature space; `decrease` means it would move downward.

These are diagnostic directions, not causal rewriting instructions.

## 8. Move Toward the Axis Center

```r
MOVEMENT_TEXT_ID <- "author__bush__farewell_address__2009__speech__01"
MOVEMENT_TO <- "center"

source("inst/examples/k_factor_corek_workbench.R")
```

This estimates movement toward the central tendency of the reference texts.

## 9. Move Toward a Specific Text

```r
MOVEMENT_TEXT_ID <- "author__bush__farewell_address__2009__speech__01"
MOVEMENT_TO <- "text"
MOVEMENT_TO_TEXT_ID <- "author__kafka_franz__aphorismen__1920__belletristik__01"
TOP_FEATURES_N <- 20

source("inst/examples/k_factor_corek_workbench.R")
```

This estimates feature-level movement from one text toward another selected
text in the same PCA space.

## 10. Inspect 3D Plots

The workbench writes two Plotly files when `plotly` and `htmlwidgets` are
available:

```text
person_axis_3d.html
person_axis_context_3d.html
```

`person_axis_context_3d.html` uses separate visual layers:

- grey points: full corpus
- teal points: reference texts defining the person axis
- orange points: nearest corpus matches
- dark line: fitted person axis

Open the HTML file in a browser and rotate the scene to inspect the axis,
nearest texts and outliers.

## 11. Key Output Files

```text
reference_scored.csv
baseline_scored_against_axis.csv
target_scored_against_axis.csv
all_scored_against_axis.csv
axis_feature_contributions.csv
nearest_reference_corpus_to_axis.csv
query_nearest_texts.csv
movement_summary.csv
movement_top_feature_changes.csv
k_factor_workbench_report.md
person_axis_bundle.rds
```

The `.rds` bundle stores the fitted PCA space and person axis for reuse.

## Source Note For The Kafka Demo

The Kafka example file contains derived numeric/stylistic features only. The
underlying source texts were obtained from Project Gutenberg. Kafka's original
German works are public domain in Germany/EU because Franz Kafka died in 1924
and the 70-year post mortem auctoris term has expired. They are also treated as
public-domain works for the relevant Project Gutenberg releases in the United
States.

This repository does not redistribute Kafka raw text and does not present the
feature file as an official Project Gutenberg dataset. Please observe Project
Gutenberg's terms and trademark guidance when obtaining or redistributing source
texts.
