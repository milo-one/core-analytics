# CoRE Analytics: MANOVA post-hoc diagnostics and robust checks
#
# Purpose:
# - recompute PCA from the current numeric feature matrix
# - run MANOVA on selected freshly computed PCA scores for cluster,
#   doc_class and genre_group
# - export Pillai/Wilks summaries, effect-size tables and post-hoc contrasts
# - check assumptions with pragmatic diagnostics: covariance inequality,
#   Box's M approximation, Mardia diagnostics and permutation pseudo-F
#
# Run from the repository root in RStudio:
#   source("manova_posthoc_diagnostics.R")

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
OUTPUT_DIR <- "tables/manova_posthoc_diagnostics"
FIGURE_DIR <- file.path(OUTPUT_DIR, "figures")
SEED <- 123
PC_CUMULATIVE_TARGET <- 0.90
MAX_PCS <- 30
PERMUTATIONS <- 499

load_required_packages <- function() {
  packages <- c("tidyverse", "ggplot2")
  missing <- packages[!vapply(packages, require, logical(1), character.only = TRUE)]
  if (length(missing) > 0) {
    stop("Missing required packages: ", paste(missing, collapse = ", "))
  }
}

source_project_files <- function(project_dir = PROJECT_DIR) {
  source(file.path(project_dir, "r", "core", "data_load.R"))
  source(file.path(project_dir, "r", "core", "data_clean.R"))
  source(file.path(project_dir, "r", "core", "output_tables.R"))
}

ensure_dirs <- function() {
  ensure_output_dir(OUTPUT_DIR)
  ensure_output_dir(FIGURE_DIR)
}

make_genre_group <- function(df) {
  genre <- tolower(as.character(df$doc_genre))
  class <- tolower(as.character(df$doc_class))
  dplyr::case_when(
    grepl("_cot$", genre) ~ "ki_cot",
    grepl("_p[12]$", genre) | grepl("model_interaction", genre) ~ "ki_personalized",
    grepl("_p0$", genre) | grepl("model", class) | grepl("conversation_ai|conversation_rant_ai", genre) ~ "ki_generic",
    class %in% c("author", "reddit", "whatsapp", "youtube", "wiki") ~ "human",
    TRUE ~ "extra"
  )
}

remove_old_analysis_columns <- function(df) {
  old_cols <- c(
    paste0("PC", 1:500),
    paste0("pc", 1:500),
    "cluster",
    "label",
    "label_5",
    "label_binary",
    "predicted_label",
    paste0("LD", 1:20)
  )
  df[, !(names(df) %in% old_cols), drop = FALSE]
}

build_pca_variance_table <- function(pca_obj) {
  eig <- pca_obj$sdev^2
  var_explained <- eig / sum(eig)
  data.frame(
    PC = paste0("PC", seq_along(var_explained)),
    variance_explained = var_explained,
    cumulative_variance = cumsum(var_explained),
    stringsAsFactors = FALSE
  )
}

build_fresh_pca_for_manova <- function(full_raw) {
  features_for_pca <- remove_old_analysis_columns(full_raw)
  cleaned <- clean_numeric(features_for_pca)
  pca_model <- stats::prcomp(cleaned$scaled, scale. = FALSE)
  pca_var <- build_pca_variance_table(pca_model)

  k_by_variance <- which(pca_var$cumulative_variance >= PC_CUMULATIVE_TARGET)[1]
  if (is.na(k_by_variance)) {
    k_by_variance <- ncol(pca_model$x)
  }
  pc_count <- min(k_by_variance, MAX_PCS, ncol(pca_model$x))
  pc_cols <- paste0("PC", seq_len(pc_count))

  pca_scores <- as.data.frame(pca_model$x[, seq_len(pc_count), drop = FALSE])
  colnames(pca_scores) <- pc_cols
  pca_scores$text_id <- full_raw$text_id

  list(
    cleaned = cleaned,
    pca = pca_model,
    variance = pca_var,
    scores = pca_scores,
    pc_cols = pc_cols,
    k_by_variance = k_by_variance,
    pc_count = pc_count
  )
}

regularized_cov <- function(x, eps = 1e-6) {
  cov_mat <- stats::cov(x, use = "pairwise.complete.obs")
  cov_mat + diag(eps, nrow(cov_mat))
}

box_m_approx <- function(df, group_col, pc_cols) {
  work <- df %>% dplyr::filter(!is.na(.data[[group_col]]))
  groups <- unique(work[[group_col]])
  groups <- groups[!is.na(groups)]
  p <- length(pc_cols)
  g <- length(groups)
  if (g < 2 || nrow(work) <= g + p) return(data.frame())

  group_covs <- lapply(groups, function(grp) {
    x <- work[work[[group_col]] == grp, pc_cols, drop = FALSE]
    x <- x[stats::complete.cases(x), , drop = FALSE]
    list(n = nrow(x), cov = regularized_cov(x))
  })
  valid <- vapply(group_covs, function(x) x$n > p, logical(1))
  group_covs <- group_covs[valid]
  groups <- groups[valid]
  if (length(group_covs) < 2) return(data.frame())

  pooled_num <- Reduce("+", lapply(group_covs, function(x) (x$n - 1) * x$cov))
  pooled_den <- sum(vapply(group_covs, function(x) x$n - 1, numeric(1)))
  pooled_cov <- pooled_num / pooled_den

  logdet <- function(mat) as.numeric(determinant(mat, logarithm = TRUE)$modulus)
  m_stat <- pooled_den * logdet(pooled_cov) -
    sum(vapply(group_covs, function(x) (x$n - 1) * logdet(x$cov), numeric(1)))

  correction <- ((2 * p^2 + 3 * p - 1) / (6 * (p + 1) * (length(group_covs) - 1))) *
    (sum(vapply(group_covs, function(x) 1 / (x$n - 1), numeric(1))) - 1 / pooled_den)
  chi_sq <- m_stat * (1 - correction)
  df_chi <- (length(group_covs) - 1) * p * (p + 1) / 2

  determinants <- vapply(group_covs, function(x) exp(logdet(x$cov)), numeric(1))

  data.frame(
    group_var = group_col,
    groups_used = length(group_covs),
    pc_count = p,
    box_m = m_stat,
    chi_square_approx = chi_sq,
    df = df_chi,
    p_value_approx = stats::pchisq(chi_sq, df_chi, lower.tail = FALSE),
    min_cov_det = min(determinants, na.rm = TRUE),
    max_cov_det = max(determinants, na.rm = TRUE),
    cov_det_ratio = max(determinants, na.rm = TRUE) / max(min(determinants, na.rm = TRUE), .Machine$double.eps),
    stringsAsFactors = FALSE
  )
}

mardia_diagnostics <- function(df, group_col, pc_cols, max_n = 1200) {
  work <- df %>% dplyr::filter(!is.na(.data[[group_col]]))
  rows <- lapply(unique(work[[group_col]]), function(grp) {
    x <- work[work[[group_col]] == grp, pc_cols, drop = FALSE]
    x <- x[stats::complete.cases(x), , drop = FALSE]
    if (nrow(x) < length(pc_cols) + 5) return(NULL)
    if (nrow(x) > max_n) {
      set.seed(SEED)
      x <- x[sample(seq_len(nrow(x)), max_n), , drop = FALSE]
    }
    cov_inv <- tryCatch(solve(regularized_cov(x)), error = function(e) NULL)
    if (is.null(cov_inv)) return(NULL)
    centered <- sweep(as.matrix(x), 2, colMeans(x), "-")
    d2 <- rowSums((centered %*% cov_inv) * centered)
    inner <- centered %*% cov_inv %*% t(centered)
    skew <- mean(inner^3)
    kurt <- mean(d2^2)
    p <- length(pc_cols)
    expected_kurt <- p * (p + 2)
    data.frame(
      group_var = group_col,
      group = as.character(grp),
      n = nrow(x),
      pc_count = p,
      mardia_skewness = skew,
      mardia_kurtosis = kurt,
      expected_kurtosis = expected_kurt,
      kurtosis_z_approx = (kurt - expected_kurt) / sqrt(8 * p * (p + 2) / nrow(x)),
      stringsAsFactors = FALSE
    )
  })
  dplyr::bind_rows(rows)
}

run_manova_for_group <- function(df, group_col, pc_cols) {
  work <- df %>%
    dplyr::select(dplyr::all_of(c(group_col, pc_cols))) %>%
    dplyr::filter(!is.na(.data[[group_col]])) %>%
    dplyr::mutate(group = factor(.data[[group_col]]))
  if (length(unique(work$group)) < 2) return(NULL)

  response <- as.matrix(work[, pc_cols, drop = FALSE])
  fit <- stats::manova(response ~ group, data = work)
  pillai <- summary(fit, test = "Pillai")$stats
  wilks <- summary(fit, test = "Wilks")$stats

  make_row <- function(stats_matrix, test_name) {
    data.frame(
      group_var = group_col,
      test = test_name,
      statistic = stats_matrix[1, 1],
      approx_f = stats_matrix[1, 2],
      num_df = stats_matrix[1, 3],
      den_df = stats_matrix[1, 4],
      p_value = stats_matrix[1, 5],
      pc_count = length(pc_cols),
      n = nrow(work),
      groups = length(unique(work$group)),
      stringsAsFactors = FALSE
    )
  }

  dplyr::bind_rows(make_row(pillai, "Pillai"), make_row(wilks, "Wilks"))
}

anova_effects <- function(df, group_col, pc_cols) {
  rows <- lapply(pc_cols, function(pc) {
    work <- df %>%
      dplyr::select(group = dplyr::all_of(group_col), value = dplyr::all_of(pc)) %>%
      dplyr::filter(!is.na(group), !is.na(value)) %>%
      dplyr::mutate(group = factor(group))
    if (length(unique(work$group)) < 2) return(NULL)
    fit <- stats::lm(value ~ group, data = work)
    tab <- stats::anova(fit)
    ss_group <- tab$`Sum Sq`[1]
    ss_res <- tab$`Sum Sq`[2]
    ss_total <- ss_group + ss_res
    data.frame(
      group_var = group_col,
      outcome = pc,
      df_group = tab$Df[1],
      df_residual = tab$Df[2],
      f_value = tab$`F value`[1],
      p_value = tab$`Pr(>F)`[1],
      eta_squared = ss_group / ss_total,
      partial_eta_squared = ss_group / (ss_group + ss_res),
      stringsAsFactors = FALSE
    )
  })

  out <- dplyr::bind_rows(rows)
  out$p_fdr <- stats::p.adjust(out$p_value, method = "fdr")
  out %>% dplyr::arrange(p_fdr, dplyr::desc(partial_eta_squared))
}

posthoc_pairwise <- function(df, group_col, pc_cols, top_outcomes = 8) {
  effects <- anova_effects(df, group_col, pc_cols) %>%
    dplyr::slice_head(n = top_outcomes)
  rows <- lapply(effects$outcome, function(pc) {
    work <- df %>%
      dplyr::select(group = dplyr::all_of(group_col), value = dplyr::all_of(pc)) %>%
      dplyr::filter(!is.na(group), !is.na(value)) %>%
      dplyr::mutate(group = factor(group))
    groups <- levels(work$group)
    pairs <- utils::combn(groups, 2, simplify = FALSE)
    dplyr::bind_rows(lapply(pairs, function(pair) {
      a <- work$value[work$group == pair[1]]
      b <- work$value[work$group == pair[2]]
      test <- stats::t.test(a, b)
      pooled_sd <- sqrt(((length(a) - 1) * stats::var(a) + (length(b) - 1) * stats::var(b)) / (length(a) + length(b) - 2))
      data.frame(
        group_var = group_col,
        outcome = pc,
        group_a = pair[1],
        group_b = pair[2],
        mean_a = mean(a, na.rm = TRUE),
        mean_b = mean(b, na.rm = TRUE),
        mean_diff = mean(a, na.rm = TRUE) - mean(b, na.rm = TRUE),
        cohen_d = ifelse(is.finite(pooled_sd) && pooled_sd > 0, (mean(a, na.rm = TRUE) - mean(b, na.rm = TRUE)) / pooled_sd, NA_real_),
        p_value = test$p.value,
        stringsAsFactors = FALSE
      )
    }))
  })

  out <- dplyr::bind_rows(rows)
  out$p_fdr <- stats::p.adjust(out$p_value, method = "fdr")
  out %>% dplyr::arrange(p_fdr, dplyr::desc(abs(cohen_d)))
}

pseudo_f_stat <- function(x, groups) {
  groups <- factor(groups)
  grand <- colMeans(x, na.rm = TRUE)
  total_ss <- sum(rowSums((x - matrix(grand, nrow(x), ncol(x), byrow = TRUE))^2), na.rm = TRUE)
  within_ss <- sum(vapply(levels(groups), function(grp) {
    rows <- groups == grp
    center <- colMeans(x[rows, , drop = FALSE], na.rm = TRUE)
    sum(rowSums((x[rows, , drop = FALSE] - matrix(center, sum(rows), ncol(x), byrow = TRUE))^2), na.rm = TRUE)
  }, numeric(1)))
  between_ss <- total_ss - within_ss
  df_between <- length(levels(groups)) - 1
  df_within <- nrow(x) - length(levels(groups))
  (between_ss / df_between) / (within_ss / df_within)
}

permutation_pseudo_f <- function(df, group_col, pc_cols, permutations = PERMUTATIONS) {
  work <- df %>%
    dplyr::select(group = dplyr::all_of(group_col), dplyr::all_of(pc_cols)) %>%
    dplyr::filter(!is.na(group)) %>%
    dplyr::mutate(group = factor(group))
  if (length(unique(work$group)) < 2) return(data.frame())
  x <- as.matrix(work[, pc_cols, drop = FALSE])
  groups <- work$group
  observed <- pseudo_f_stat(x, groups)
  set.seed(SEED)
  perm_stats <- replicate(permutations, pseudo_f_stat(x, sample(groups)))
  data.frame(
    group_var = group_col,
    pc_count = length(pc_cols),
    permutations = permutations,
    pseudo_f = observed,
    p_perm = (sum(perm_stats >= observed) + 1) / (permutations + 1),
    stringsAsFactors = FALSE
  )
}

plot_effects <- function(effects, group_col) {
  effects %>%
    dplyr::slice_max(partial_eta_squared, n = 20) %>%
    ggplot2::ggplot(ggplot2::aes(x = partial_eta_squared, y = reorder(outcome, partial_eta_squared), fill = p_fdr < 0.05)) +
    ggplot2::geom_col() +
    ggplot2::theme_minimal(base_size = 11) +
    ggplot2::labs(
      title = paste0("Univariate PC effects: ", group_col),
      x = "Partial eta squared",
      y = NULL,
      fill = "FDR < .05"
    )
}

load_required_packages()
source_project_files()
ensure_dirs()
set.seed(SEED)

full_raw_loaded <- load_data(DATA_ROOT)
pca_for_manova <- build_fresh_pca_for_manova(full_raw_loaded)

old_pc_cols <- grep("^PC[0-9]+$", names(full_raw_loaded), value = TRUE)
full_raw <- full_raw_loaded[, !(names(full_raw_loaded) %in% old_pc_cols), drop = FALSE] %>%
  dplyr::left_join(pca_for_manova$scores, by = "text_id") %>%
  dplyr::mutate(
    cluster = as.factor(cluster),
    genre_group = make_genre_group(.)
  )

pc_cols <- pca_for_manova$pc_cols
group_vars <- c("cluster", "doc_class", "genre_group")
group_vars <- group_vars[group_vars %in% names(full_raw)]

manova_summary <- dplyr::bind_rows(lapply(group_vars, function(g) run_manova_for_group(full_raw, g, pc_cols)))
anova_summary <- dplyr::bind_rows(lapply(group_vars, function(g) anova_effects(full_raw, g, pc_cols)))
posthoc_summary <- dplyr::bind_rows(lapply(group_vars, function(g) posthoc_pairwise(full_raw, g, pc_cols, top_outcomes = 8)))
box_m_summary <- dplyr::bind_rows(lapply(group_vars, function(g) box_m_approx(full_raw, g, pc_cols)))
mardia_summary <- dplyr::bind_rows(lapply(group_vars, function(g) mardia_diagnostics(full_raw, g, pc_cols)))
perm_summary <- dplyr::bind_rows(lapply(group_vars, function(g) permutation_pseudo_f(full_raw, g, pc_cols, permutations = PERMUTATIONS)))

write_table_csv(pca_for_manova$variance, "fresh_pca_variance.csv", output_dir = OUTPUT_DIR)
write_table_csv(
  data.frame(
    PC = pc_cols,
    variance_explained = pca_for_manova$variance$variance_explained[seq_along(pc_cols)],
    cumulative_variance = pca_for_manova$variance$cumulative_variance[seq_along(pc_cols)],
    stringsAsFactors = FALSE
  ),
  "manova_pcs_used.csv",
  output_dir = OUTPUT_DIR
)
write_table_csv(manova_summary, "manova_pillai_wilks_summary.csv", output_dir = OUTPUT_DIR)
write_table_csv(anova_summary, "univariate_pc_effect_sizes.csv", output_dir = OUTPUT_DIR)
write_table_csv(posthoc_summary, "posthoc_pairwise_top_pc_contrasts.csv", output_dir = OUTPUT_DIR)
write_table_csv(box_m_summary, "box_m_approximation.csv", output_dir = OUTPUT_DIR)
write_table_csv(mardia_summary, "mardia_multivariate_normality_diagnostics.csv", output_dir = OUTPUT_DIR)
write_table_csv(perm_summary, "permutation_pseudo_f_robust_check.csv", output_dir = OUTPUT_DIR)

for (g in group_vars) {
  p <- plot_effects(anova_summary %>% dplyr::filter(group_var == g), g)
  ggplot2::ggsave(file.path(FIGURE_DIR, paste0("effect_sizes_", g, ".png")), p, width = 8, height = 6, dpi = 300)
}

diagnostic_overview <- data.frame(
  n_rows = nrow(full_raw),
  n_pca_input_features = ncol(pca_for_manova$cleaned$clean),
  pca_recomputed_from_features = TRUE,
  pc_count_needed_for_target_variance = pca_for_manova$k_by_variance,
  pc_count = length(pc_cols),
  pc_range = paste(pc_cols[1], pc_cols[length(pc_cols)], sep = "-"),
  cumulative_variance_used = pca_for_manova$variance$cumulative_variance[length(pc_cols)],
  cumulative_variance_target = PC_CUMULATIVE_TARGET,
  max_pcs = MAX_PCS,
  group_vars = paste(group_vars, collapse = ", "),
  permutations = PERMUTATIONS,
  stringsAsFactors = FALSE
)
write_table_csv(diagnostic_overview, "manova_diagnostic_overview.csv", output_dir = OUTPUT_DIR)

manova_posthoc_results <- list(
  full_raw = full_raw,
  pca_for_manova = pca_for_manova,
  pc_cols = pc_cols,
  manova = manova_summary,
  anova = anova_summary,
  posthoc = posthoc_summary,
  box_m = box_m_summary,
  mardia = mardia_summary,
  permutation = perm_summary,
  overview = diagnostic_overview
)

message("MANOVA post-hoc diagnostics complete. Outputs written to: ", ensure_output_dir(OUTPUT_DIR))





