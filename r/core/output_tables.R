# Output table helpers for the CoRE Analytics master workflow.

ensure_output_dir <- function(output_dir = "tables") {
  if (!dir.exists(output_dir)) {
    dir.create(output_dir, recursive = TRUE)
  }
  normalizePath(output_dir, winslash = "/", mustWork = TRUE)
}

write_table_csv <- function(df, filename, output_dir = "tables", row_names = FALSE) {
  output_dir <- ensure_output_dir(output_dir)
  path <- file.path(output_dir, filename)
  utils::write.csv(df, path, row.names = row_names)
  message("Wrote table: ", path)
  invisible(path)
}

export_coverage_tables <- function(analysis_data, output_dir = "tables") {
  coverage <- analysis_data$coverage

  paths <- c(
    write_table_csv(coverage, "coverage_all.csv", output_dir),
    write_table_csv(
      dplyr::filter(coverage, coverage_percent < 2),
      "coverage_under_2pct.csv",
      output_dir
    ),
    write_table_csv(
      analysis_data$empty_check,
      "coverage_zero_or_na_over_90pct.csv",
      output_dir
    ),
    write_table_csv(
      data.frame(feature = analysis_data$empty_cols),
      "coverage_zero_or_na_over_98pct.csv",
      output_dir
    )
  )

  invisible(paths)
}

export_pca_tables <- function(pca_results, pca_var_table, output_dir = "tables", top_n = 20) {
  rotation <- pca_results$pca$rotation

  loading_tables <- lapply(seq_len(ncol(rotation)), function(i) {
    pc <- colnames(rotation)[i]
    vals <- rotation[, i]

    data.frame(
      PC = pc,
      rank_abs = seq_len(min(top_n, length(vals))),
      feature = names(vals)[order(abs(vals), decreasing = TRUE)][seq_len(min(top_n, length(vals)))],
      loading = vals[order(abs(vals), decreasing = TRUE)][seq_len(min(top_n, length(vals)))],
      stringsAsFactors = FALSE
    )
  })

  top_abs_loadings <- dplyr::bind_rows(loading_tables)

  signed_tables <- lapply(seq_len(ncol(rotation)), function(i) {
    pc <- colnames(rotation)[i]
    vals <- rotation[, i]
    n <- min(top_n, length(vals))

    data.frame(
      PC = pc,
      direction = rep(c("positive", "negative"), each = n),
      rank = rep(seq_len(n), times = 2),
      feature = c(
        names(vals)[order(vals, decreasing = TRUE)][seq_len(n)],
        names(vals)[order(vals, decreasing = FALSE)][seq_len(n)]
      ),
      loading = c(
        vals[order(vals, decreasing = TRUE)][seq_len(n)],
        vals[order(vals, decreasing = FALSE)][seq_len(n)]
      ),
      stringsAsFactors = FALSE
    )
  })

  top_signed_loadings <- dplyr::bind_rows(signed_tables)

  paths <- c(
    write_table_csv(pca_var_table, "pca_variance.csv", output_dir),
    write_table_csv(top_abs_loadings, "pca_top_abs_loadings.csv", output_dir),
    write_table_csv(top_signed_loadings, "pca_top_signed_loadings.csv", output_dir),
    write_table_csv(data.frame(feature = rownames(rotation)), "pca_feature_list.csv", output_dir)
  )

  invisible(paths)
}

get_cluster_pc_means <- function(pc_df) {
  pc_df %>%
    dplyr::group_by(cluster) %>%
    dplyr::summarise(
      dplyr::across(dplyr::starts_with("PC"), ~ mean(.x, na.rm = TRUE)),
      .groups = "drop"
    )
}

get_cluster_pc_deviations <- function(pc_df, top_n = 10) {
  pc_means <- get_cluster_pc_means(pc_df)
  pc_long <- pc_means %>%
    tidyr::pivot_longer(
      cols = dplyr::starts_with("PC"),
      names_to = "PC",
      values_to = "cluster_mean"
    ) %>%
    dplyr::mutate(abs_cluster_mean = abs(cluster_mean)) %>%
    dplyr::arrange(cluster, dplyr::desc(abs_cluster_mean))

  pc_long %>%
    dplyr::group_by(cluster) %>%
    dplyr::slice_head(n = top_n) %>%
    dplyr::ungroup()
}

get_cluster_example_texts <- function(pc_df, n = 5) {
  pc_cols <- grep("^PC", names(pc_df), value = TRUE)

  cluster_centers <- pc_df %>%
    dplyr::group_by(cluster) %>%
    dplyr::summarise(
      dplyr::across(dplyr::all_of(pc_cols), ~ mean(.x, na.rm = TRUE)),
      .groups = "drop"
    )

  pc_with_centers <- pc_df %>%
    dplyr::left_join(
      cluster_centers,
      by = "cluster",
      suffix = c("", "_center")
    )

  center_cols <- paste0(pc_cols, "_center")
  pc_with_centers$distance_to_cluster_center <- sqrt(rowSums(
    (as.matrix(pc_with_centers[, pc_cols, drop = FALSE]) -
       as.matrix(pc_with_centers[, center_cols, drop = FALSE]))^2,
    na.rm = TRUE
  ))

  pc_with_centers %>%
    dplyr::group_by(cluster) %>%
    dplyr::arrange(distance_to_cluster_center, .by_group = TRUE) %>%
    dplyr::slice_head(n = n) %>%
    dplyr::ungroup() %>%
    dplyr::select(cluster, text_id, distance_to_cluster_center)
}

export_cluster_tables <- function(
    full_raw,
    pc_df = NULL,
    cluster_profiles = NULL,
    output_dir = "tables"
) {
  cluster_sizes <- full_raw %>%
    dplyr::count(cluster, name = "n") %>%
    dplyr::mutate(percent = round(n / sum(n) * 100, 2))

  cluster_class <- full_raw %>%
    dplyr::count(cluster, doc_class, name = "n") %>%
    dplyr::group_by(cluster) %>%
    dplyr::mutate(percent_in_cluster = round(n / sum(n) * 100, 2)) %>%
    dplyr::ungroup()

  cluster_genre <- full_raw %>%
    dplyr::count(cluster, doc_genre, name = "n") %>%
    dplyr::group_by(cluster) %>%
    dplyr::mutate(percent_in_cluster = round(n / sum(n) * 100, 2)) %>%
    dplyr::ungroup()

  paths <- c(
    write_table_csv(cluster_sizes, "cluster_sizes.csv", output_dir),
    write_table_csv(cluster_class, "cluster_by_doc_class.csv", output_dir),
    write_table_csv(cluster_genre, "cluster_by_doc_genre.csv", output_dir)
  )

  if (!is.null(pc_df)) {
    paths <- c(
      paths,
      write_table_csv(
        get_cluster_pc_means(pc_df),
        "cluster_pc_means.csv",
        output_dir
      ),
      write_table_csv(
        get_cluster_pc_deviations(pc_df, top_n = 10),
        "cluster_top_pc_deviations.csv",
        output_dir
      ),
      write_table_csv(
        get_cluster_example_texts(pc_df, n = 5),
        "cluster_example_texts_central.csv",
        output_dir
      )
    )
  }

  if (!is.null(cluster_profiles)) {
    paths <- c(
      paths,
      write_table_csv(
        as.data.frame(cluster_profiles) |> tibble::rownames_to_column("yaml_module"),
        "cluster_yaml_profiles.csv",
        output_dir
      )
    )
  }

  invisible(paths)
}

export_cluster_decision_tables <- function(
    cluster_decision,
    stability_tables = NULL,
    output_dir = "tables"
) {
  paths <- write_table_csv(
    cluster_decision,
    "cluster_decision_summary.csv",
    output_dir
  )

  if (!is.null(stability_tables)) {
    paths <- c(
      paths,
      write_table_csv(
        stability_tables$summary,
        "cluster_stability_summary.csv",
        output_dir
      ),
      write_table_csv(
        stability_tables$long,
        "cluster_stability_by_cluster.csv",
        output_dir
      )
    )
  }

  invisible(paths)
}

export_manova_tables <- function(res_manova, output_dir = "tables") {
  overview <- dplyr::bind_rows(lapply(names(res_manova), function(name) {
    res <- res_manova[[name]]
    data.frame(
      comparison = name,
      pcs_used = paste0("PC", res$pcs_used, collapse = ", "),
      variance_used = sum(res$var_explained),
      stringsAsFactors = FALSE
    )
  }))

  write_table_csv(overview, "manova_pcs_used.csv", output_dir)
}





