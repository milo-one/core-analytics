# CoRE Analytics: Canonical Discriminant Analysis / CVA
#
# Purpose:
# - run canonical discriminant analyses for cluster, document class and genre group
# - connect canonical axes back to PCA dimensions and PCA feature loadings
# - export interpretable tables and interactive plots
#
# Run from the repository root in RStudio:
#   source("canonical_discriminant_analysis.R")

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
OUTPUT_DIR <- "tables/canonical_discriminant"
SEED <- 123
CLUSTER_K <- 7
CDA_PC_COUNT <- 12
MIN_GENRE_GROUP_N <- 5
TOP_FEATURES_PER_CAN <- 30

load_required_packages <- function() {
  packages <- c("tidyverse", "candisc", "plotly", "htmlwidgets", "ggplot2")
  missing <- packages[!vapply(packages, require, logical(1), character.only = TRUE)]

  if (length(missing) > 0) {
    stop("Missing required packages: ", paste(missing, collapse = ", "))
  }
}

source_project_files <- function(project_dir = PROJECT_DIR) {
  source(file.path(project_dir, "r", "core", "data_load.R"))
  source(file.path(project_dir, "r", "core", "data_clean.R"))
  source(file.path(project_dir, "r", "pca_cluster", "pca_analysis.R"))
  source(file.path(project_dir, "r", "pca_cluster", "clustering.R"))
  source(file.path(project_dir, "r", "core", "output_tables.R"))
}

remove_old_analysis_columns <- function(df) {
  old_cols <- c(paste0("PC", 1:300), "cluster")
  df[, !(names(df) %in% old_cols), drop = FALSE]
}

is_ki_prompt_genre <- function(genre) {
  genre <- tolower(as.character(genre))
  grepl("(^|_)(aa|chap|flli-5|ha|leli|mf|mm|so|sv)_p[0-2](_cot)?$", genre) |
    grepl("_p[0-2](_cot)?$", genre)
}

classify_ki_genre <- function(genre) {
  genre_chr <- tolower(as.character(genre))
  ki_like <- is_ki_prompt_genre(genre_chr)

  dplyr::case_when(
    ki_like & grepl("_cot$", genre_chr) ~ "ki_cot",
    ki_like & grepl("_p[12]$", genre_chr) ~ "ki_personalized",
    ki_like & grepl("_p0$", genre_chr) ~ "ki_generic",
    TRUE ~ as.character(genre)
  )
}

collapse_rare_human_genres <- function(group, min_n = MIN_GENRE_GROUP_N) {
  group <- as.character(group)
  counts <- table(group)
  keep <- names(counts)[counts >= min_n]
  is_ki <- group %in% c("ki_cot", "ki_generic", "ki_personalized")

  dplyr::case_when(
    is_ki ~ group,
    group %in% keep ~ group,
    TRUE ~ "other_human_rare"
  )
}

prepare_analysis_data <- function() {
  full_raw <- load_data(DATA_ROOT)
  features_for_pca <- remove_old_analysis_columns(full_raw)
  cleaned <- clean_numeric(features_for_pca)
  pca_results <- run_pca(cleaned$scaled, n_top = 20, n_components = NULL)
  km <- run_kmeans(cleaned$scaled, k = CLUSTER_K, seed = SEED)

  scores <- as.data.frame(pca_results$pca$x)
  pc_cols <- paste0("PC", seq_len(min(CDA_PC_COUNT, ncol(scores))))
  scores <- scores[, pc_cols, drop = FALSE]

  metadata_cols <- intersect(
    c("text_id", "doc_class", "doc_source", "doc_author", "doc_year", "doc_genre", "doc_title"),
    names(full_raw)
  )

  analysis_df <- dplyr::bind_cols(scores, full_raw[, metadata_cols, drop = FALSE])
  analysis_df$cluster <- factor(km$cluster)
  analysis_df$genre_group_raw <- classify_ki_genre(analysis_df$doc_genre)
  analysis_df$genre_group <- factor(collapse_rare_human_genres(analysis_df$genre_group_raw))
  analysis_df$doc_class <- factor(analysis_df$doc_class)

  list(
    full_raw = full_raw,
    cleaned = cleaned,
    pca_results = pca_results,
    km = km,
    analysis_df = analysis_df,
    pc_cols = pc_cols
  )
}

safe_axis_cols <- function(df, prefix = "Can") {
  grep(paste0("^", prefix), names(df), value = TRUE)
}

extract_cd_scores <- function(cd_obj, analysis_df, group_var) {
  scores <- as.data.frame(cd_obj$scores)
  can_cols <- safe_axis_cols(scores, "Can")

  metadata_cols <- intersect(
    c("text_id", "doc_class", "doc_genre", "genre_group_raw", "genre_group", "cluster"),
    names(analysis_df)
  )

  dplyr::bind_cols(
    scores[, can_cols, drop = FALSE],
    analysis_df[, metadata_cols, drop = FALSE]
  ) %>%
    dplyr::mutate(group = analysis_df[[group_var]])
}

extract_can_summary <- function(cd_obj, analysis_name) {
  canrsq <- cd_obj$canrsq
  canonical_axis <- names(canrsq)
  if (is.null(canonical_axis)) {
    canonical_axis <- paste0("Can", seq_along(canrsq))
  }

  data.frame(
    analysis = analysis_name,
    canonical_axis = canonical_axis,
    can_rsq = as.numeric(canrsq),
    percent_of_canonical_rsq = as.numeric(100 * canrsq / sum(canrsq)),
    stringsAsFactors = FALSE
  )
}

extract_structure_table <- function(cd_obj, analysis_name) {
  structure <- as.data.frame(cd_obj$structure)
  structure$PC <- rownames(structure)

  structure %>%
    dplyr::relocate(PC) %>%
    tidyr::pivot_longer(-PC, names_to = "canonical_axis", values_to = "structure_loading") %>%
    dplyr::mutate(
      analysis = analysis_name,
      abs_structure_loading = abs(structure_loading)
    ) %>%
    dplyr::arrange(analysis, canonical_axis, dplyr::desc(abs_structure_loading))
}

extract_coeff_table <- function(cd_obj, analysis_name) {
  coeffs <- as.data.frame(cd_obj$coeffs.std)
  coeffs$PC <- rownames(coeffs)

  coeffs %>%
    dplyr::relocate(PC) %>%
    tidyr::pivot_longer(-PC, names_to = "canonical_axis", values_to = "standardized_coefficient") %>%
    dplyr::mutate(
      analysis = analysis_name,
      abs_standardized_coefficient = abs(standardized_coefficient)
    ) %>%
    dplyr::arrange(analysis, canonical_axis, dplyr::desc(abs_standardized_coefficient))
}

extract_feature_contributions <- function(cd_obj, pca_results, analysis_name, top_n = TOP_FEATURES_PER_CAN) {
  structure <- as.data.frame(cd_obj$structure)
  pca_rotation <- pca_results$pca$rotation
  axes <- colnames(structure)

  tables <- lapply(axes, function(axis) {
    pc_weights <- abs(structure[, axis])
    names(pc_weights) <- rownames(structure)
    used_pcs <- intersect(names(pc_weights), colnames(pca_rotation))
    weighted <- abs(pca_rotation[, used_pcs, drop = FALSE]) %*% pc_weights[used_pcs]
    weighted <- as.numeric(weighted)

    data.frame(
      analysis = analysis_name,
      canonical_axis = axis,
      feature = rownames(pca_rotation),
      contribution = weighted,
      stringsAsFactors = FALSE
    ) %>%
      dplyr::arrange(dplyr::desc(contribution)) %>%
      dplyr::slice_head(n = top_n)
  })

  dplyr::bind_rows(tables)
}

save_plotly <- function(fig, filename, output_dir = OUTPUT_DIR) {
  output_dir <- ensure_output_dir(output_dir)
  path <- file.path(output_dir, filename)
  libdir <- paste0(tools::file_path_sans_ext(filename), "_lib")
  htmlwidgets::saveWidget(fig, path, selfcontained = FALSE, libdir = libdir)
  message("Wrote plot: ", path)
  invisible(path)
}

plot_scores_2d <- function(scores, group_var, title) {
  plotly::plot_ly(
    data = scores,
    x = ~Can1,
    y = ~Can2,
    type = "scatter",
    mode = "markers",
    color = scores[[group_var]],
    marker = list(size = 7, opacity = 0.68),
    text = ~paste0(
      "text_id: ", text_id,
      "<br>group: ", group,
      "<br>cluster: ", cluster,
      "<br>class: ", doc_class,
      "<br>genre: ", doc_genre,
      "<br>genre_group: ", genre_group,
      "<br>Can1: ", round(Can1, 3),
      "<br>Can2: ", round(Can2, 3)
    ),
    hoverinfo = "text"
  ) %>%
    plotly::layout(
      title = title,
      xaxis = list(title = "Can1"),
      yaxis = list(title = "Can2"),
      legend = list(itemsizing = "constant")
    )
}

plot_scores_3d <- function(scores, group_var, title) {
  can_cols <- safe_axis_cols(scores, "Can")
  if (length(can_cols) < 3) {
    return(NULL)
  }

  plotly::plot_ly(
    data = scores,
    x = ~Can1,
    y = ~Can2,
    z = ~Can3,
    type = "scatter3d",
    mode = "markers",
    color = scores[[group_var]],
    marker = list(size = 3, opacity = 0.72),
    text = ~paste0(
      "text_id: ", text_id,
      "<br>group: ", group,
      "<br>cluster: ", cluster,
      "<br>class: ", doc_class,
      "<br>genre: ", doc_genre,
      "<br>genre_group: ", genre_group,
      "<br>Can1: ", round(Can1, 3),
      "<br>Can2: ", round(Can2, 3),
      "<br>Can3: ", round(Can3, 3)
    ),
    hoverinfo = "text"
  ) %>%
    plotly::layout(
      title = title,
      scene = list(
        xaxis = list(title = "Can1"),
        yaxis = list(title = "Can2"),
        zaxis = list(title = "Can3")
      ),
      legend = list(itemsizing = "constant")
    )
}

plot_scores_2d_static <- function(scores, analysis_name) {
  centroids <- scores %>%
    dplyr::group_by(group) %>%
    dplyr::summarise(
      Can1 = mean(Can1, na.rm = TRUE),
      Can2 = mean(Can2, na.rm = TRUE),
      .groups = "drop"
    )

  scores %>%
    ggplot2::ggplot(ggplot2::aes(x = Can1, y = Can2, color = group)) +
    ggplot2::geom_point(alpha = 0.45, size = 1.4) +
    ggplot2::geom_point(
      data = centroids,
      ggplot2::aes(x = Can1, y = Can2, color = group),
      inherit.aes = FALSE,
      size = 4,
      shape = 18
    ) +
    ggplot2::theme_minimal(base_size = 11) +
    ggplot2::theme(
      plot.title = ggplot2::element_text(face = "bold"),
      panel.grid.minor = ggplot2::element_blank(),
      legend.position = "right"
    ) +
    ggplot2::labs(
      title = paste0("CDA scores: ", analysis_name),
      subtitle = "Diamonds show group centroids",
      x = "Can1",
      y = "Can2",
      color = "Group"
    )
}

plot_can_summary <- function(can_summary, analysis_name) {
  can_summary %>%
    ggplot2::ggplot(ggplot2::aes(
      x = canonical_axis,
      y = percent_of_canonical_rsq
    )) +
    ggplot2::geom_col(fill = "#2f6f73", width = 0.72) +
    ggplot2::theme_minimal(base_size = 11) +
    ggplot2::theme(
      plot.title = ggplot2::element_text(face = "bold"),
      panel.grid.minor = ggplot2::element_blank()
    ) +
    ggplot2::labs(
      title = paste0("Canonical separation by axis: ", analysis_name),
      x = NULL,
      y = "% of canonical R-squared"
    )
}

plot_structure_heatmap <- function(structure_table, analysis_name) {
  top_pcs <- structure_table %>%
    dplyr::group_by(PC) %>%
    dplyr::summarise(max_abs = max(abs_structure_loading), .groups = "drop") %>%
    dplyr::arrange(dplyr::desc(max_abs)) %>%
    dplyr::slice_head(n = 12) %>%
    dplyr::pull(PC)

  structure_table %>%
    dplyr::filter(PC %in% top_pcs) %>%
    ggplot2::ggplot(ggplot2::aes(x = canonical_axis, y = PC, fill = structure_loading)) +
    ggplot2::geom_tile(color = "white", linewidth = 0.6) +
    ggplot2::geom_text(ggplot2::aes(label = sprintf("%.2f", structure_loading)), size = 3) +
    ggplot2::scale_fill_gradient2(
      low = "#9a4d4d",
      mid = "white",
      high = "#2f6f73",
      midpoint = 0,
      name = "loading"
    ) +
    ggplot2::theme_minimal(base_size = 11) +
    ggplot2::theme(panel.grid = ggplot2::element_blank()) +
    ggplot2::labs(
      title = paste0("CDA structure loadings: ", analysis_name),
      x = NULL,
      y = NULL
    )
}

run_cda <- function(analysis_df, pc_cols, group_var, analysis_name, pca_results) {
  group_counts <- analysis_df %>%
    dplyr::count(.data[[group_var]], name = "n") %>%
    dplyr::arrange(dplyr::desc(n))

  write_table_csv(group_counts, paste0(analysis_name, "_group_counts.csv"), output_dir = OUTPUT_DIR)

  formula <- stats::as.formula(
    paste0("cbind(", paste(pc_cols, collapse = ", "), ") ~ ", group_var)
  )

  man <- stats::manova(formula, data = analysis_df)
  cd <- candisc::candisc(man)

  scores <- extract_cd_scores(cd, analysis_df, group_var)
  can_summary <- extract_can_summary(cd, analysis_name)
  structure_table <- extract_structure_table(cd, analysis_name)
  coeff_table <- extract_coeff_table(cd, analysis_name)
  feature_contributions <- extract_feature_contributions(cd, pca_results, analysis_name)

  write_table_csv(scores, paste0(analysis_name, "_canonical_scores.csv"), output_dir = OUTPUT_DIR)
  write_table_csv(can_summary, paste0(analysis_name, "_canonical_summary.csv"), output_dir = OUTPUT_DIR)
  write_table_csv(structure_table, paste0(analysis_name, "_structure_loadings.csv"), output_dir = OUTPUT_DIR)
  write_table_csv(coeff_table, paste0(analysis_name, "_standardized_coefficients.csv"), output_dir = OUTPUT_DIR)
  write_table_csv(feature_contributions, paste0(analysis_name, "_top_feature_contributions.csv"), output_dir = OUTPUT_DIR)

  fig2d <- plot_scores_2d(scores, "group", paste0("CDA ", analysis_name, ": Can1 / Can2"))
  save_plotly(fig2d, paste0(analysis_name, "_scores_can1_can2.html"))

  fig3d <- plot_scores_3d(scores, "group", paste0("CDA ", analysis_name, ": Can1 / Can2 / Can3"))
  if (!is.null(fig3d)) {
    save_plotly(fig3d, paste0(analysis_name, "_scores_can1_can2_can3.html"))
  }

  heatmap <- plot_structure_heatmap(structure_table, analysis_name)
  ggplot2::ggsave(
    file.path(ensure_output_dir(OUTPUT_DIR), paste0(analysis_name, "_structure_heatmap.png")),
    heatmap,
    width = 8,
    height = 6,
    dpi = 300
  )

  score_plot <- plot_scores_2d_static(scores, analysis_name)
  ggplot2::ggsave(
    file.path(ensure_output_dir(OUTPUT_DIR), paste0(analysis_name, "_scores_can1_can2.png")),
    score_plot,
    width = 9,
    height = 7,
    dpi = 300
  )

  summary_plot <- plot_can_summary(can_summary, analysis_name)
  ggplot2::ggsave(
    file.path(ensure_output_dir(OUTPUT_DIR), paste0(analysis_name, "_canonical_summary.png")),
    summary_plot,
    width = 8,
    height = 5,
    dpi = 300
  )

  list(
    manova = man,
    candisc = cd,
    scores = scores,
    canonical_summary = can_summary,
    structure = structure_table,
    coefficients = coeff_table,
    feature_contributions = feature_contributions
  )
}

load_required_packages()
source_project_files()
set.seed(SEED)

analysis_bundle <- prepare_analysis_data()
analysis_df <- analysis_bundle$analysis_df
pc_cols <- analysis_bundle$pc_cols
pca_results <- analysis_bundle$pca_results

write_table_csv(
  analysis_df %>% dplyr::count(doc_genre, genre_group_raw, genre_group, name = "n"),
  "genre_group_mapping_counts.csv",
  output_dir = OUTPUT_DIR
)

analyses <- list(
  cluster = run_cda(analysis_df, pc_cols, "cluster", "cluster", pca_results),
  doc_class = run_cda(analysis_df, pc_cols, "doc_class", "doc_class", pca_results),
  genre_group = run_cda(analysis_df, pc_cols, "genre_group", "genre_group", pca_results)
)

combined_summary <- dplyr::bind_rows(lapply(analyses, `[[`, "canonical_summary"))
write_table_csv(combined_summary, "canonical_summary_all.csv", output_dir = OUTPUT_DIR)

canonical_discriminant_results <- list(
  data = analysis_df,
  pc_cols = pc_cols,
  analyses = analyses
)

message("Canonical discriminant analysis complete. Outputs written to: ", ensure_output_dir(OUTPUT_DIR))





