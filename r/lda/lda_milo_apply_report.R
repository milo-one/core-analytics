# CoRE Analytics: apply trained MILO-style LDA model to external feature data
#
# Purpose:
# - load `milo_lda_model_bundle.rds`
# - read an external/current features_full.csv
# - prepare features with the training PCA and anchor scaling
# - classify with binary and 5-group LDA
# - export a table and a text report per row
#
# Configure TARGET_FEATURE_FILE, then run from the repository root:
#   source("lda_milo_apply_report.R")

find_project_root <- function() {
  frames <- sys.frames()
  files <- vapply(frames, function(frame) {
    if (!is.null(frame$ofile)) frame$ofile else NA_character_
  }, character(1))
  files <- files[!is.na(files)]
  script_dir <- if (length(files) > 0) dirname(normalizePath(files[length(files)], winslash = "/", mustWork = TRUE)) else normalizePath(getwd(), winslash = "/", mustWork = TRUE)
  root <- normalizePath(file.path(script_dir, "..", ".."), winslash = "/", mustWork = FALSE)
  if (dir.exists(file.path(root, "r", "core"))) root else normalizePath(getwd(), winslash = "/", mustWork = TRUE)
}

PROJECT_DIR <- find_project_root()
MODEL_BUNDLE_PATH <- "tables/lda_milo/models/milo_lda_model_bundle.rds"
TARGET_FEATURE_FILE <- if (file.exists(file.path(PROJECT_DIR, "data", "features_full.csv"))) file.path(PROJECT_DIR, "data", "features_full.csv") else file.path(PROJECT_DIR, "out", "features_full.csv")
OUTPUT_DIR <- "tables/lda_milo_external_report"
FIGURE_DIR <- file.path(OUTPUT_DIR, "figures")

load_required_packages <- function() {
  packages <- c("tidyverse", "MASS", "ggplot2", "glue")
  missing <- packages[!vapply(packages, require, logical(1), character.only = TRUE)]

  if (length(missing) > 0) {
    stop("Missing required packages: ", paste(missing, collapse = ", "))
  }
}

source_project_files <- function(project_dir = PROJECT_DIR) {
  source(file.path(project_dir, "r", "core", "output_tables.R"))
}

ensure_dirs <- function() {
  ensure_output_dir(OUTPUT_DIR)
  ensure_output_dir(FIGURE_DIR)
}

prepare_external_matrix <- function(target_raw, bundle) {
  fb <- bundle$feature_bundle

  missing_pca <- setdiff(fb$pca_source_columns, names(target_raw))
  if (length(missing_pca) > 0) {
    warning("Missing PCA columns in target; filling with zero: ", paste(missing_pca, collapse = ", "))
  }

  for (col in missing_pca) {
    target_raw[[col]] <- 0
  }

  x_raw <- target_raw[, fb$pca_source_columns, drop = FALSE] %>%
    dplyr::mutate(dplyr::across(dplyr::everything(), ~ tidyr::replace_na(as.numeric(.x), 0)))

  x_scaled <- scale(
    as.matrix(x_raw),
    center = fb$pca_input_center,
    scale = fb$pca_input_scale
  )

  pc_scores <- x_scaled %*% fb$pca_model$rotation[, seq_len(fb$pc_count), drop = FALSE]
  pc_scores <- as.data.frame(pc_scores)
  colnames(pc_scores) <- paste0("pc", seq_len(fb$pc_count))

  missing_anchor <- setdiff(fb$anchor_features, names(target_raw))
  if (length(missing_anchor) > 0) {
    stop("Missing anchor features in target: ", paste(missing_anchor, collapse = ", "))
  }

  anchors_raw <- target_raw[, fb$anchor_features, drop = FALSE] %>%
    dplyr::mutate(dplyr::across(dplyr::everything(), ~ tidyr::replace_na(as.numeric(.x), 0)))

  anchors_scaled <- sweep(as.matrix(anchors_raw), 2, fb$anchor_center, "-")
  anchors_scaled <- sweep(anchors_scaled, 2, fb$anchor_scale, "/")
  anchors_scaled <- as.data.frame(anchors_scaled)

  dplyr::bind_cols(pc_scores, anchors_scaled)
}

predict_model <- function(fit, matrix_df, prefix) {
  pred <- predict(fit, newdata = matrix_df)
  posterior <- as.data.frame(pred$posterior) %>%
    dplyr::rename_with(~ paste0(prefix, "_prob_", .x))
  scores <- as.data.frame(pred$x)
  if (ncol(scores) > 0) {
    scores <- scores %>% dplyr::rename_with(~ paste0(prefix, "_LD", seq_along(.x)))
  }

  predicted <- stats::setNames(
    data.frame(as.character(pred$class), stringsAsFactors = FALSE),
    paste0(prefix, "_predicted")
  )

  dplyr::bind_cols(predicted, posterior, scores)
}

make_report_text <- function(row) {
  binary_pred <- row$binary_predicted
  five_pred <- row$five_predicted
  p_human <- if ("binary_prob_human" %in% names(row)) as.numeric(row$binary_prob_human) else NA_real_
  p_ki <- if ("binary_prob_ki" %in% names(row)) as.numeric(row$binary_prob_ki) else NA_real_

  confidence <- max(
    as.numeric(row[grep("^five_prob_", names(row))]),
    na.rm = TRUE
  )

  glue::glue(
"======================================================
MILO-LDA DETECTION REPORT
======================================================
TEXT:        {row$text_id}
GENRE:       {row$doc_genre}
CLASS:       {row$doc_class}
------------------------------------------------------
BINARY:      {binary_pred}
P(human):    {round(p_human, 4)}
P(KI):       {round(p_ki, 4)}

5-GROUP:     {five_pred}
confidence:  {round(confidence, 4)}

LD position:
binary LD1:  {round(as.numeric(row$binary_LD1), 3)}
five LD1:    {round(as.numeric(row$five_LD1), 3)}
five LD2:    {if ('five_LD2' %in% names(row)) round(as.numeric(row$five_LD2), 3) else NA}
======================================================
"
  )
}

plot_external_ld <- function(results) {
  if (!all(c("five_LD1", "five_LD2") %in% names(results))) {
    return(NULL)
  }

  ggplot2::ggplot(results, ggplot2::aes(x = five_LD1, y = five_LD2, color = five_predicted)) +
    ggplot2::geom_point(size = 2.5, alpha = 0.75) +
    ggplot2::theme_minimal(base_size = 12) +
    ggplot2::labs(
      title = "External data: 5-group LDA position",
      x = "LD1",
      y = "LD2",
      color = "Prediction"
    )
}

load_required_packages()
source_project_files()
ensure_dirs()

bundle <- readRDS(MODEL_BUNDLE_PATH)
target_raw <- readr::read_csv(TARGET_FEATURE_FILE, show_col_types = FALSE)

if (!"text_id" %in% names(target_raw)) {
  target_raw$text_id <- paste0("row_", seq_len(nrow(target_raw)))
}
for (col in c("doc_genre", "doc_class")) {
  if (!col %in% names(target_raw)) {
    target_raw[[col]] <- NA_character_
  }
}

external_matrix <- prepare_external_matrix(target_raw, bundle)

binary_out <- predict_model(bundle$binary$fit, external_matrix, "binary")
five_out <- predict_model(bundle$five_group$fit, external_matrix, "five")

results <- dplyr::bind_cols(
  target_raw[, intersect(c("text_id", "doc_class", "doc_genre", "doc_source", "doc_author", "doc_year"), names(target_raw)), drop = FALSE],
  binary_out,
  five_out
)

write_table_csv(results, "external_lda_predictions.csv", output_dir = OUTPUT_DIR)

report_lines <- lapply(seq_len(nrow(results)), function(i) make_report_text(results[i, ]))
writeLines(unlist(report_lines), file.path(ensure_output_dir(OUTPUT_DIR), "external_lda_reports.txt"))

p <- plot_external_ld(results)
if (!is.null(p)) {
  ggplot2::ggsave(
    file.path(FIGURE_DIR, "external_5group_ld1_ld2.png"),
    p,
    width = 8,
    height = 6,
    dpi = 300
  )
}

lda_external_results <- list(
  bundle = bundle,
  raw = target_raw,
  matrix = external_matrix,
  predictions = results
)

message("External LDA report complete. Outputs written to: ", ensure_output_dir(OUTPUT_DIR))





