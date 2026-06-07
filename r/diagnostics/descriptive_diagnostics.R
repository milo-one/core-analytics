# CoRE Analytics: descriptive statistics and feature diagnostics
#
# Purpose:
# - summarize numeric feature distributions, missingness and zero inflation
# - inspect high correlations and approximate VIF/redundancy
# - flag robust outliers
# - export compact tables and diagnostic plots
#
# Run from the repository root in RStudio:
#   source("descriptive_diagnostics.R")

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
DATA_ROOT <- file.path(PROJECT_DIR, "out")
OUTPUT_DIR <- "tables/descriptive_diagnostics"
FIGURE_DIR <- file.path(OUTPUT_DIR, "figures")

load_required_packages <- function() {
  packages <- c("tidyverse", "ggplot2")
  missing <- packages[!vapply(packages, require, logical(1), character.only = TRUE)]
  if (length(missing) > 0) {
    stop("Missing required packages: ", paste(missing, collapse = ", "))
  }
}

source_project_files <- function(project_dir = PROJECT_DIR) {
  source(file.path(project_dir, "r", "core", "data_load.R"))
  source(file.path(project_dir, "r", "core", "output_tables.R"))
}

ensure_dirs <- function() {
  ensure_output_dir(OUTPUT_DIR)
  ensure_output_dir(FIGURE_DIR)
}

is_analysis_feature <- function(name) {
  !grepl("^(PC|pc)[0-9]+$", name) &&
    !name %in% c("cluster") &&
    !grepl("^LD[0-9]+$", name)
}

safe_skewness <- function(x) {
  x <- x[is.finite(x)]
  if (length(x) < 3 || stats::sd(x) == 0) return(NA_real_)
  mean((x - mean(x))^3) / stats::sd(x)^3
}

safe_kurtosis_excess <- function(x) {
  x <- x[is.finite(x)]
  if (length(x) < 4 || stats::sd(x) == 0) return(NA_real_)
  mean((x - mean(x))^4) / stats::sd(x)^4 - 3
}

robust_outlier_count <- function(x, cutoff = 3.5) {
  x <- as.numeric(x)
  med <- stats::median(x, na.rm = TRUE)
  mad_val <- stats::mad(x, constant = 1.4826, na.rm = TRUE)
  if (!is.finite(mad_val) || mad_val == 0) {
    return(0L)
  }
  sum(abs((x - med) / mad_val) > cutoff, na.rm = TRUE)
}

make_feature_summary <- function(df) {
  numeric_df <- df %>% dplyr::select(where(is.numeric))
  numeric_df <- numeric_df[, vapply(names(numeric_df), is_analysis_feature, logical(1)), drop = FALSE]

  rows <- lapply(names(numeric_df), function(feature) {
    x <- as.numeric(numeric_df[[feature]])
    non_missing <- sum(!is.na(x))
    zero_count <- sum(x == 0, na.rm = TRUE)
    data.frame(
      feature = feature,
      n = length(x),
      non_missing = non_missing,
      missing_n = sum(is.na(x)),
      missing_percent = round(mean(is.na(x)) * 100, 4),
      zero_n = zero_count,
      zero_percent = round(zero_count / max(non_missing, 1) * 100, 4),
      mean = mean(x, na.rm = TRUE),
      sd = stats::sd(x, na.rm = TRUE),
      median = stats::median(x, na.rm = TRUE),
      mad = stats::mad(x, na.rm = TRUE),
      min = min(x, na.rm = TRUE),
      q01 = stats::quantile(x, 0.01, na.rm = TRUE, names = FALSE),
      q05 = stats::quantile(x, 0.05, na.rm = TRUE, names = FALSE),
      q25 = stats::quantile(x, 0.25, na.rm = TRUE, names = FALSE),
      q75 = stats::quantile(x, 0.75, na.rm = TRUE, names = FALSE),
      q95 = stats::quantile(x, 0.95, na.rm = TRUE, names = FALSE),
      q99 = stats::quantile(x, 0.99, na.rm = TRUE, names = FALSE),
      max = max(x, na.rm = TRUE),
      skewness = safe_skewness(x),
      kurtosis_excess = safe_kurtosis_excess(x),
      robust_outlier_n = robust_outlier_count(x),
      robust_outlier_percent = round(robust_outlier_count(x) / max(non_missing, 1) * 100, 4),
      stringsAsFactors = FALSE
    )
  })

  dplyr::bind_rows(rows) %>%
    dplyr::mutate(
      feature_family = dplyr::case_when(
        grepl("^cat_", feature) ~ "semantic_category",
        grepl("sentence|word|token|ratio|dichte|quote|density|length|bluff|breadth|overload|subordinate|hedging|modal", feature, ignore.case = TRUE) ~ "style_or_anchor",
        TRUE ~ "other_numeric"
      )
    ) %>%
    dplyr::arrange(dplyr::desc(zero_percent), dplyr::desc(abs(skewness)))
}

make_missing_pattern_summary <- function(df, max_features = 80) {
  summary <- make_feature_summary(df)
  selected <- summary %>%
    dplyr::arrange(dplyr::desc(missing_percent), dplyr::desc(zero_percent)) %>%
    dplyr::slice_head(n = max_features) %>%
    dplyr::pull(feature)

  if (length(selected) == 0) return(data.frame())

  pattern_df <- df[, selected, drop = FALSE] %>%
    dplyr::mutate(dplyr::across(dplyr::everything(), ~ ifelse(is.na(.x), "NA", ifelse(.x == 0, "zero", "present"))))

  pattern_key <- apply(pattern_df, 1, paste, collapse = "|")
  data.frame(pattern = pattern_key, stringsAsFactors = FALSE) %>%
    dplyr::count(pattern, name = "n") %>%
    dplyr::mutate(percent = round(n / sum(n) * 100, 4)) %>%
    dplyr::arrange(dplyr::desc(n)) %>%
    dplyr::slice_head(n = 50)
}

make_correlation_tables <- function(df, max_features = 160) {
  summary <- make_feature_summary(df)
  selected <- summary %>%
    dplyr::filter(non_missing > 5, sd > 0) %>%
    dplyr::arrange(zero_percent, dplyr::desc(sd)) %>%
    dplyr::slice_head(n = max_features) %>%
    dplyr::pull(feature)

  x <- df[, selected, drop = FALSE] %>%
    dplyr::mutate(dplyr::across(dplyr::everything(), ~ tidyr::replace_na(as.numeric(.x), 0)))

  cor_mat <- stats::cor(x, use = "pairwise.complete.obs")
  cor_long <- as.data.frame(as.table(cor_mat), stringsAsFactors = FALSE)
  colnames(cor_long) <- c("feature_a", "feature_b", "correlation")
  cor_long %>%
    dplyr::filter(feature_a < feature_b) %>%
    dplyr::mutate(abs_correlation = abs(correlation)) %>%
    dplyr::arrange(dplyr::desc(abs_correlation))
}

approximate_vif <- function(df, max_features = 80) {
  summary <- make_feature_summary(df)
  selected <- summary %>%
    dplyr::filter(non_missing > 5, sd > 0, zero_percent < 98) %>%
    dplyr::arrange(dplyr::desc(sd)) %>%
    dplyr::slice_head(n = max_features) %>%
    dplyr::pull(feature)

  if (length(selected) < 3) return(data.frame())

  x <- df[, selected, drop = FALSE] %>%
    dplyr::mutate(dplyr::across(dplyr::everything(), ~ tidyr::replace_na(as.numeric(.x), 0)))

  rows <- lapply(selected, function(feature) {
    others <- setdiff(selected, feature)
    fit <- tryCatch(
      stats::lm(stats::reformulate(others, response = feature), data = x),
      error = function(e) NULL
    )
    if (is.null(fit)) {
      return(data.frame(feature = feature, r_squared = NA_real_, vif = NA_real_))
    }
    r2 <- summary(fit)$r.squared
    data.frame(
      feature = feature,
      r_squared = r2,
      vif = ifelse(r2 >= 0.999999, Inf, 1 / (1 - r2)),
      stringsAsFactors = FALSE
    )
  })

  dplyr::bind_rows(rows) %>% dplyr::arrange(dplyr::desc(vif))
}

make_outlier_rows <- function(df, top_features_n = 30, max_rows_per_feature = 20) {
  summary <- make_feature_summary(df)
  selected <- summary %>%
    dplyr::filter(robust_outlier_n > 0) %>%
    dplyr::arrange(dplyr::desc(robust_outlier_percent)) %>%
    dplyr::slice_head(n = top_features_n) %>%
    dplyr::pull(feature)

  rows <- lapply(selected, function(feature) {
    x <- as.numeric(df[[feature]])
    med <- stats::median(x, na.rm = TRUE)
    mad_val <- stats::mad(x, constant = 1.4826, na.rm = TRUE)
    if (!is.finite(mad_val) || mad_val == 0) return(NULL)

    robust_z <- (x - med) / mad_val
    data.frame(
      text_id = if ("text_id" %in% names(df)) df$text_id else seq_len(nrow(df)),
      feature = feature,
      value = x,
      robust_z = robust_z,
      stringsAsFactors = FALSE
    ) %>%
      dplyr::filter(abs(robust_z) > 3.5) %>%
      dplyr::arrange(dplyr::desc(abs(robust_z))) %>%
      dplyr::slice_head(n = max_rows_per_feature)
  })

  dplyr::bind_rows(rows)
}

plot_zero_missing <- function(feature_summary) {
  feature_summary %>%
    dplyr::slice_max(zero_percent, n = 35) %>%
    ggplot2::ggplot(ggplot2::aes(x = zero_percent, y = reorder(feature, zero_percent), fill = feature_family)) +
    ggplot2::geom_col() +
    ggplot2::theme_minimal(base_size = 11) +
    ggplot2::labs(title = "Highest zero inflation", x = "Zero percent", y = NULL, fill = "Feature family")
}

plot_skewness <- function(feature_summary) {
  feature_summary %>%
    dplyr::filter(is.finite(skewness)) %>%
    dplyr::slice_max(abs(skewness), n = 35) %>%
    ggplot2::ggplot(ggplot2::aes(x = skewness, y = reorder(feature, abs(skewness)), fill = skewness > 0)) +
    ggplot2::geom_col() +
    ggplot2::theme_minimal(base_size = 11) +
    ggplot2::labs(title = "Most skewed features", x = "Skewness", y = NULL, fill = "Positive skew")
}

plot_correlation_heatmap <- function(cor_pairs, top_n = 40) {
  features <- cor_pairs %>%
    dplyr::slice_head(n = top_n) %>%
    dplyr::select(feature_a, feature_b) %>%
    unlist(use.names = FALSE) %>%
    unique()

  cor_pairs %>%
    dplyr::filter(feature_a %in% features, feature_b %in% features) %>%
    ggplot2::ggplot(ggplot2::aes(x = feature_a, y = feature_b, fill = correlation)) +
    ggplot2::geom_tile() +
    ggplot2::scale_fill_gradient2(low = "#c85c4a", mid = "white", high = "#4f46c6", limits = c(-1, 1)) +
    ggplot2::theme_minimal(base_size = 8) +
    ggplot2::theme(axis.text.x = ggplot2::element_text(angle = 70, hjust = 1)) +
    ggplot2::labs(title = "High-correlation feature block", x = NULL, y = NULL, fill = "r")
}

load_required_packages()
source_project_files()
ensure_dirs()

full_raw <- load_data(DATA_ROOT)

feature_summary <- make_feature_summary(full_raw)
missing_patterns <- make_missing_pattern_summary(full_raw)
cor_pairs <- make_correlation_tables(full_raw)
vif_table <- approximate_vif(full_raw)
outlier_rows <- make_outlier_rows(full_raw)

write_table_csv(feature_summary, "feature_descriptive_summary.csv", output_dir = OUTPUT_DIR)
write_table_csv(feature_summary %>% dplyr::filter(missing_percent > 0), "features_with_missing.csv", output_dir = OUTPUT_DIR)
write_table_csv(feature_summary %>% dplyr::filter(zero_percent >= 90), "features_zero_over_90pct.csv", output_dir = OUTPUT_DIR)
write_table_csv(feature_summary %>% dplyr::filter(zero_percent >= 98), "features_zero_over_98pct.csv", output_dir = OUTPUT_DIR)
write_table_csv(missing_patterns, "missing_zero_patterns_top.csv", output_dir = OUTPUT_DIR)
write_table_csv(cor_pairs, "feature_correlations_ranked.csv", output_dir = OUTPUT_DIR)
write_table_csv(cor_pairs %>% dplyr::filter(abs_correlation >= 0.80), "feature_correlations_abs_ge_0_80.csv", output_dir = OUTPUT_DIR)
write_table_csv(vif_table, "approx_vif_top_features.csv", output_dir = OUTPUT_DIR)
write_table_csv(outlier_rows, "robust_outlier_rows.csv", output_dir = OUTPUT_DIR)

ggplot2::ggsave(file.path(FIGURE_DIR, "zero_inflation_top.png"), plot_zero_missing(feature_summary), width = 9, height = 8, dpi = 300)
ggplot2::ggsave(file.path(FIGURE_DIR, "skewness_top.png"), plot_skewness(feature_summary), width = 9, height = 8, dpi = 300)
ggplot2::ggsave(file.path(FIGURE_DIR, "high_correlation_heatmap.png"), plot_correlation_heatmap(cor_pairs), width = 10, height = 9, dpi = 300)

diagnostic_overview <- data.frame(
  n_rows = nrow(full_raw),
  n_numeric_analysis_features = nrow(feature_summary),
  n_features_with_missing = sum(feature_summary$missing_percent > 0),
  n_features_zero_over_90pct = sum(feature_summary$zero_percent >= 90),
  n_features_zero_over_98pct = sum(feature_summary$zero_percent >= 98),
  n_high_corr_pairs_abs_ge_0_80 = sum(cor_pairs$abs_correlation >= 0.80, na.rm = TRUE),
  n_vif_over_10 = sum(vif_table$vif > 10, na.rm = TRUE),
  n_robust_outlier_cells = nrow(outlier_rows),
  stringsAsFactors = FALSE
)
write_table_csv(diagnostic_overview, "diagnostic_overview.csv", output_dir = OUTPUT_DIR)

descriptive_diagnostics_results <- list(
  full_raw = full_raw,
  feature_summary = feature_summary,
  missing_patterns = missing_patterns,
  cor_pairs = cor_pairs,
  vif = vif_table,
  outliers = outlier_rows,
  overview = diagnostic_overview
)

message("Descriptive diagnostics complete. Outputs written to: ", ensure_output_dir(OUTPUT_DIR))





