# CoRE Analytics: MILO-LDA visualizations and comparison reports
#
# Purpose:
# - visualize binary and 5-group LDA spaces with group ellipses
# - reconstruct feature contributions for LD axes from PCA + LDA scalings
# - interpret LD1-LD4 from strongest original feature/category contributions
# - apply the saved model to a comparison feature file
# - optionally write a focused report and highlighted scatterplot for one row/text
#
# Run from the repository root in RStudio:
#   source("lda_milo_visualize_and_compare.R")
#
# Optional selection before sourcing:
#   TARGET_FEATURE_FILE <- "C:/path/to/features_full.csv"
#   TARGET_ROW_INDEX <- 7
#   TARGET_TEXT_ID <- "some_text_id"

TARGET_TEXT_ID <- NULL
TARGET_ROW_INDEX <- NULL

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
TRAINING_FEATURE_FILE <- if (file.exists(file.path(PROJECT_DIR, "data", "features_full.csv"))) file.path(PROJECT_DIR, "data", "features_full.csv") else file.path(PROJECT_DIR, "out", "features_full.csv")
TARGET_FEATURE_FILE <- if (exists("TARGET_FEATURE_FILE")) TARGET_FEATURE_FILE else TRAINING_FEATURE_FILE
TARGET_ROW_INDEX <- if (exists("TARGET_ROW_INDEX")) TARGET_ROW_INDEX else {
  env_row <- Sys.getenv("LDA_TARGET_ROW", unset = "")
  if (nzchar(env_row)) as.integer(env_row) else NULL
}
TARGET_TEXT_ID <- if (exists("TARGET_TEXT_ID")) TARGET_TEXT_ID else {
  env_id <- Sys.getenv("LDA_TARGET_TEXT_ID", unset = "")
  if (nzchar(env_id)) env_id else NULL
}

OUTPUT_DIR <- "tables/lda_milo_visual"
FIGURE_DIR <- file.path(OUTPUT_DIR, "figures")
REPORT_DIR <- file.path(OUTPUT_DIR, "reports")

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
  ensure_output_dir(REPORT_DIR)
}

safe_filename <- function(x) {
  x <- as.character(x)
  x <- gsub("[^A-Za-z0-9._-]+", "_", x)
  substr(x, 1, 140)
}

drop_old_analysis_columns <- function(df) {
  old_cols <- c(
    paste0("PC", 1:300),
    paste0("pc", 1:300),
    "cluster", "label", "label_5", "label_binary", "predicted_label",
    "LD1", "LD2", "LD3", "LD4"
  )
  df[, !(names(df) %in% old_cols), drop = FALSE]
}

is_ki_prompt_genre <- function(genre) {
  genre <- tolower(as.character(genre))
  grepl("(^|_)(aa|chap|flli-5|ha|leli|mf|mm|so|sv|tat[0-9])_p[0-2](_cot)?$", genre) |
    grepl("_p[0-2](_cot)?$", genre)
}

build_lda_labels <- function(df, human_core_genres) {
  df %>%
    dplyr::mutate(
      doc_genre_l = tolower(trimws(as.character(doc_genre))),
      doc_class_l = tolower(trimws(as.character(doc_class))),
      doc_id_l = if ("doc_id" %in% names(.)) tolower(trimws(as.character(doc_id))) else "",
      is_ki_genre = is_ki_prompt_genre(doc_genre_l),
      label_5 = dplyr::case_when(
        is_ki_genre & grepl("_cot$", doc_genre_l) ~ "ki_cot",
        is_ki_genre & grepl("_p[12]$", doc_genre_l) ~ "ki_personalized",
        grepl("model_interaction", doc_genre_l) ~ "ki_personalized",
        grepl("gpt_4o_kathrin|gpt_5\\.1_kathrin", doc_id_l) ~ "ki_personalized",
        is_ki_genre & grepl("_p0$", doc_genre_l) ~ "ki_generic",
        grepl("model", doc_class_l) ~ "ki_generic",
        grepl("conversation_ai|conversation_rant_ai", doc_genre_l) ~ "ki_generic",
        doc_genre_l %in% human_core_genres ~ "human",
        doc_class_l %in% c("author", "reddit", "whatsapp", "youtube", "wiki") ~ "human",
        TRUE ~ "extra"
      ),
      label_binary = dplyr::case_when(
        label_5 %in% c("ki_generic", "ki_personalized", "ki_cot") ~ "ki",
        label_5 == "human" ~ "human",
        TRUE ~ NA_character_
      )
    ) %>%
    dplyr::select(-doc_genre_l, -doc_class_l, -doc_id_l, -is_ki_genre)
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

predict_all <- function(raw, bundle) {
  if (!"text_id" %in% names(raw)) {
    raw$text_id <- paste0("row_", seq_len(nrow(raw)))
  }
  for (col in c("doc_genre", "doc_class", "doc_source", "doc_author", "doc_year")) {
    if (!col %in% names(raw)) {
      raw[[col]] <- NA_character_
    }
  }

  matrix_df <- prepare_external_matrix(raw, bundle)
  binary_out <- predict_model(bundle$binary$fit, matrix_df, "binary")
  five_out <- predict_model(bundle$five_group$fit, matrix_df, "five")
  anchor_z <- matrix_df[, bundle$feature_bundle$anchor_features, drop = FALSE] %>%
    dplyr::rename_with(~ paste0("anchor_z_", .x))
  meta_cols <- intersect(
    c("text_id", "doc_class", "doc_genre", "doc_source", "doc_author", "doc_year"),
    names(raw)
  )

  list(
    matrix = matrix_df,
    predictions = dplyr::bind_cols(raw[, meta_cols, drop = FALSE], binary_out, five_out, anchor_z)
  )
}

compute_centroid_distances <- function(df, label_col, axes, prefix) {
  axes <- axes[axes %in% names(df)]
  if (length(axes) == 0 || !label_col %in% names(df)) {
    return(data.frame())
  }

  centroids <- df %>%
    dplyr::filter(!is.na(.data[[label_col]])) %>%
    dplyr::group_by(.data[[label_col]]) %>%
    dplyr::summarise(dplyr::across(dplyr::all_of(axes), ~ mean(.x, na.rm = TRUE)), .groups = "drop") %>%
    dplyr::rename(group = dplyr::all_of(label_col))

  distances <- lapply(seq_len(nrow(df)), function(i) {
    row_values <- as.numeric(df[i, axes, drop = TRUE])
    group_dist <- vapply(seq_len(nrow(centroids)), function(j) {
      centroid_values <- as.numeric(centroids[j, axes, drop = TRUE])
      sqrt(sum((row_values - centroid_values)^2, na.rm = TRUE))
    }, numeric(1))

    names(group_dist) <- centroids$group
    ordered <- sort(group_dist)
    out <- as.data.frame(t(group_dist), stringsAsFactors = FALSE)
    colnames(out) <- paste0(prefix, "_dist_", colnames(out))
    out[[paste0(prefix, "_nearest_group")]] <- names(ordered)[1]
    out[[paste0(prefix, "_nearest_distance")]] <- as.numeric(ordered[1])
    out[[paste0(prefix, "_second_distance")]] <- if (length(ordered) > 1) as.numeric(ordered[2]) else NA_real_
    out[[paste0(prefix, "_distance_ratio")]] <- if (length(ordered) > 1 && ordered[2] > 0) as.numeric(ordered[1] / ordered[2]) else NA_real_
    out
  })

  dplyr::bind_rows(distances)
}

compute_distances_to_centroids <- function(target, train, train_label_col, axes, prefix) {
  axes <- axes[axes %in% names(target) & axes %in% names(train)]
  if (length(axes) == 0 || !train_label_col %in% names(train)) {
    return(data.frame())
  }

  centroids <- train %>%
    dplyr::filter(!is.na(.data[[train_label_col]])) %>%
    dplyr::group_by(.data[[train_label_col]]) %>%
    dplyr::summarise(dplyr::across(dplyr::all_of(axes), ~ mean(.x, na.rm = TRUE)), .groups = "drop") %>%
    dplyr::rename(group = dplyr::all_of(train_label_col))

  distances <- lapply(seq_len(nrow(target)), function(i) {
    row_values <- as.numeric(target[i, axes, drop = TRUE])
    group_dist <- vapply(seq_len(nrow(centroids)), function(j) {
      centroid_values <- as.numeric(centroids[j, axes, drop = TRUE])
      sqrt(sum((row_values - centroid_values)^2, na.rm = TRUE))
    }, numeric(1))

    names(group_dist) <- centroids$group
    ordered <- sort(group_dist)
    out <- as.data.frame(t(group_dist), stringsAsFactors = FALSE)
    colnames(out) <- paste0(prefix, "_dist_", colnames(out))
    out[[paste0(prefix, "_nearest_group")]] <- names(ordered)[1]
    out[[paste0(prefix, "_nearest_distance")]] <- as.numeric(ordered[1])
    out[[paste0(prefix, "_second_distance")]] <- if (length(ordered) > 1) as.numeric(ordered[2]) else NA_real_
    out[[paste0(prefix, "_distance_ratio")]] <- if (length(ordered) > 1 && ordered[2] > 0) as.numeric(ordered[1] / ordered[2]) else NA_real_
    out
  })

  dplyr::bind_rows(distances)
}

mahalanobis_to_group <- function(target, train, train_label, group_value, cols, prefix) {
  cols <- cols[cols %in% names(target) & cols %in% names(train)]
  out_name <- paste0(prefix, "_anchor_mahal_", group_value)
  if (length(cols) < 2) {
    return(stats::setNames(data.frame(rep(NA_real_, nrow(target))), out_name))
  }

  ref <- train %>%
    dplyr::filter(.data[[train_label]] == group_value) %>%
    dplyr::select(dplyr::all_of(cols))
  ref <- ref[stats::complete.cases(ref), , drop = FALSE]
  if (nrow(ref) <= length(cols)) {
    return(stats::setNames(data.frame(rep(NA_real_, nrow(target))), out_name))
  }

  center <- colMeans(ref, na.rm = TRUE)
  cov_mat <- stats::cov(ref, use = "pairwise.complete.obs")
  cov_mat <- cov_mat + diag(1e-6, nrow(cov_mat))
  values <- stats::mahalanobis(target[, cols, drop = FALSE], center = center, cov = cov_mat)
  stats::setNames(data.frame(values), out_name)
}

add_forensic_audit <- function(target_pred, training_pred) {
  five_axes <- paste0("five_LD", 1:4)
  five_axes <- five_axes[five_axes %in% names(target_pred) & five_axes %in% names(training_pred)]
  anchor_cols <- grep("^anchor_z_", names(target_pred), value = TRUE)

  target_aug <- target_pred

  if (length(five_axes) > 0) {
    five_dist_target <- compute_distances_to_centroids(target_pred, training_pred, "label_5", five_axes, "five")
    five_dist_train <- compute_centroid_distances(training_pred, "label_5", five_axes, "five")
    target_aug <- dplyr::bind_cols(target_aug, five_dist_target)

    training_with_dist <- dplyr::bind_cols(training_pred, five_dist_train)
    human_dist_threshold <- training_with_dist %>%
      dplyr::filter(label_5 == "human") %>%
      dplyr::pull(five_nearest_distance) %>%
      stats::quantile(0.95, na.rm = TRUE)
    target_aug$five_human_distance_q95 <- as.numeric(human_dist_threshold)
  }

  if (length(anchor_cols) >= 2) {
    target_aug <- dplyr::bind_cols(
      target_aug,
      mahalanobis_to_group(target_pred, training_pred, "label_binary", "human", anchor_cols, "binary"),
      mahalanobis_to_group(target_pred, training_pred, "label_binary", "ki", anchor_cols, "binary")
    )

    train_human_mahal <- mahalanobis_to_group(
      training_pred,
      training_pred,
      "label_binary",
      "human",
      anchor_cols,
      "binary"
    )
    target_aug$binary_anchor_human_q95 <- stats::quantile(
      train_human_mahal$binary_anchor_mahal_human[training_pred$label_binary == "human"],
      0.95,
      na.rm = TRUE
    )
  }

  human_ki_residual_q90 <- training_pred %>%
    dplyr::filter(label_binary == "human") %>%
    dplyr::pull(binary_prob_ki) %>%
    stats::quantile(0.90, na.rm = TRUE)

  human_log_bluff_q01 <- NA_real_
  if ("anchor_z_log_bluff" %in% names(training_pred)) {
    human_log_bluff_q01 <- training_pred %>%
      dplyr::filter(label_binary == "human") %>%
      dplyr::pull(anchor_z_log_bluff) %>%
      stats::quantile(0.01, na.rm = TRUE)
  }

  target_aug <- target_aug %>%
    dplyr::mutate(
      binary_margin = abs(as.numeric(binary_prob_human) - as.numeric(binary_prob_ki)),
      human_ki_residual_q90 = as.numeric(human_ki_residual_q90),
      anchor_log_bluff_human_q01 = as.numeric(human_log_bluff_q01),
      flag_ki_residual_high = binary_predicted == "human" & as.numeric(binary_prob_ki) > human_ki_residual_q90,
      flag_binary_five_conflict = binary_predicted == "human" & five_predicted != "human",
      flag_anchor_low_log_bluff_human_q01 = binary_predicted == "human" &
        !is.na(anchor_z_log_bluff) &
        !is.na(anchor_log_bluff_human_q01) &
        anchor_z_log_bluff <= anchor_log_bluff_human_q01,
      flag_anchor_outside_human_q95 = binary_predicted == "human" &
        !is.na(binary_anchor_mahal_human) &
        !is.na(binary_anchor_human_q95) &
        binary_anchor_mahal_human > binary_anchor_human_q95,
      flag_nearest_ld_centroid_not_human = binary_predicted == "human" &
        !is.na(five_nearest_group) &
        five_nearest_group != "human",
      flag_ld_distance_outside_human_q95 = binary_predicted == "human" &
        !is.na(five_nearest_distance) &
        !is.na(five_human_distance_q95) &
        five_nearest_distance > five_human_distance_q95,
      forensic_flags = purrr::pmap_chr(
        dplyr::pick(dplyr::starts_with("flag_")),
        function(...) {
          vals <- c(...)
          names(vals) <- gsub("^flag_", "", names(vals))
          hit <- names(vals)[as.logical(vals)]
          if (length(hit) == 0) "" else paste(hit, collapse = "|")
        }
      ),
      forensic_zone = dplyr::case_when(
        binary_predicted == "ki" ~ "KI_DIRECT_LDA",
        binary_predicted == "human" & grepl("anchor_low_log_bluff_human_q01|anchor_outside_human_q95|ld_distance_outside_human_q95|nearest_ld_centroid_not_human", forensic_flags) ~ "MIMICRY_WARNING",
        binary_predicted == "human" & grepl("binary_five_conflict|ki_residual_high", forensic_flags) ~ "HUMAN_REVIEW_GREY_ZONE",
        binary_predicted == "human" ~ "HUMAN_LDA_STABLE",
        TRUE ~ "REVIEW"
      )
    )

  target_aug
}

get_axis_contributions <- function(bundle, fit, axes = NULL, model_name = "model") {
  fb <- bundle$feature_bundle
  scaling <- fit$scaling
  if (is.null(axes)) {
    axes <- seq_len(ncol(scaling))
  }
  axes <- axes[axes <= ncol(scaling)]

  pc_names <- paste0("pc", seq_len(fb$pc_count))
  pc_coef <- scaling[intersect(pc_names, rownames(scaling)), axes, drop = FALSE]
  pc_coef <- pc_coef[pc_names[pc_names %in% rownames(pc_coef)], , drop = FALSE]

  rotation_cols <- paste0("PC", as.integer(gsub("^pc", "", rownames(pc_coef))))
  original_from_pcs <- fb$pca_model$rotation[, rotation_cols, drop = FALSE] %*% pc_coef
  original_from_pcs <- as.data.frame(original_from_pcs)
  colnames(original_from_pcs) <- paste0("LD", axes)
  original_from_pcs$feature <- rownames(original_from_pcs)

  anchor_names <- intersect(fb$anchor_features, rownames(scaling))
  anchor_rows <- data.frame()
  if (length(anchor_names) > 0) {
    anchor_rows <- as.data.frame(scaling[anchor_names, axes, drop = FALSE])
    colnames(anchor_rows) <- paste0("LD", axes)
    anchor_rows$feature <- rownames(anchor_rows)
  }

  dplyr::bind_rows(original_from_pcs, anchor_rows) %>%
    tidyr::pivot_longer(
      cols = dplyr::starts_with("LD"),
      names_to = "axis",
      values_to = "contribution"
    ) %>%
    dplyr::mutate(
      model = model_name,
      abs_contribution = abs(contribution),
      side = dplyr::case_when(
        contribution > 0 ~ "positive",
        contribution < 0 ~ "negative",
        TRUE ~ "zero"
      )
    ) %>%
    dplyr::arrange(axis, dplyr::desc(abs_contribution))
}

axis_direction_table <- function(predictions, label_col, axes) {
  rows <- lapply(axes, function(axis) {
    if (!axis %in% names(predictions)) {
      return(NULL)
    }
    predictions %>%
      dplyr::group_by(.data[[label_col]]) %>%
      dplyr::summarise(mean_score = mean(.data[[axis]], na.rm = TRUE), .groups = "drop") %>%
      dplyr::mutate(axis = gsub("^(binary_|five_)", "", axis)) %>%
      dplyr::rename(group = dplyr::all_of(label_col))
  })
  dplyr::bind_rows(rows) %>% dplyr::arrange(axis, mean_score)
}

plot_binary_contribution_bar <- function(contrib, n = 24) {
  top <- contrib %>%
    dplyr::filter(model == "binary_human_ki", axis == "LD1") %>%
    dplyr::slice_max(abs_contribution, n = n) %>%
    dplyr::arrange(contribution) %>%
    dplyr::mutate(feature = factor(feature, levels = feature))

  ggplot2::ggplot(top, ggplot2::aes(x = contribution, y = feature, fill = contribution > 0)) +
    ggplot2::geom_col(width = 0.75) +
    ggplot2::geom_vline(xintercept = 0, color = "grey35", linewidth = 0.4) +
    ggplot2::scale_fill_manual(values = c("TRUE" = "#16b9c0", "FALSE" = "#f8766d"), labels = c("TRUE" = "positive", "FALSE" = "negative")) +
    ggplot2::theme_minimal(base_size = 12) +
    ggplot2::theme(legend.position = "bottom") +
    ggplot2::labs(
      title = "Direkter Feature-Beitrag zur binaeren LDA-Diskriminanz",
      x = "Beitrag zu LD1",
      y = NULL,
      fill = "LD1-Seite"
    )
}

plot_contribution_heatmap <- function(contrib, model_name, axes, n_per_axis = 24) {
  top_features <- contrib %>%
    dplyr::filter(model == model_name, axis %in% axes) %>%
    dplyr::group_by(axis) %>%
    dplyr::slice_max(abs_contribution, n = n_per_axis, with_ties = FALSE) %>%
    dplyr::ungroup() %>%
    dplyr::pull(feature) %>%
    unique()

  contrib %>%
    dplyr::filter(model == model_name, axis %in% axes, feature %in% top_features) %>%
    ggplot2::ggplot(ggplot2::aes(x = axis, y = reorder(feature, abs_contribution), fill = contribution)) +
    ggplot2::geom_tile(color = "white", linewidth = 0.2) +
    ggplot2::scale_fill_gradient2(low = "#c85c4a", mid = "white", high = "#4f46c6") +
    ggplot2::theme_minimal(base_size = 11) +
    ggplot2::labs(
      title = paste0("Wichtigste Feature-Beitraege: ", model_name),
      x = NULL,
      y = "Feature",
      fill = "Beitrag"
    )
}

plot_binary_scatter <- function(train_pred, target_pred = NULL, highlight_rows = NULL) {
  p <- train_pred %>%
    dplyr::filter(!is.na(label_binary), !is.na(binary_LD1), !is.na(binary_prob_ki)) %>%
    ggplot2::ggplot(ggplot2::aes(x = binary_LD1, y = binary_prob_ki, color = label_binary)) +
    ggplot2::geom_point(alpha = 0.38, size = 1.7) +
    ggplot2::stat_ellipse(type = "norm", geom = "path", linewidth = 0.8, alpha = 0.85) +
    ggplot2::theme_minimal(base_size = 12) +
    ggplot2::labs(title = "Binaere LDA: Mensch vs. KI", x = "LD1", y = "P(KI)", color = "Gruppe")

  if (!is.null(target_pred) && !is.null(highlight_rows) && length(highlight_rows) > 0) {
    h <- target_pred[highlight_rows, , drop = FALSE]
    p <- p +
      ggplot2::geom_point(
        data = h,
        ggplot2::aes(x = binary_LD1, y = binary_prob_ki),
        inherit.aes = FALSE,
        color = "#111111",
        fill = "#ffd166",
        shape = 23,
        size = 4.5,
        stroke = 1.2
      )
  }
  p
}

plot_five_scatter <- function(train_pred, x_axis = "five_LD1", y_axis = "five_LD2", target_pred = NULL, highlight_rows = NULL) {
  p <- train_pred %>%
    dplyr::filter(!is.na(.data[[x_axis]]), !is.na(.data[[y_axis]])) %>%
    ggplot2::ggplot(ggplot2::aes(x = .data[[x_axis]], y = .data[[y_axis]], color = label_5)) +
    ggplot2::geom_point(alpha = 0.42, size = 1.7) +
    ggplot2::stat_ellipse(type = "norm", linewidth = 0.8, alpha = 0.9) +
    ggplot2::theme_minimal(base_size = 12) +
    ggplot2::labs(
      title = paste0("5-Gruppen-LDA: ", gsub("five_", "", x_axis), " / ", gsub("five_", "", y_axis)),
      x = gsub("five_", "", x_axis),
      y = gsub("five_", "", y_axis),
      color = "Gruppe"
    )

  if (!is.null(target_pred) && !is.null(highlight_rows) && length(highlight_rows) > 0) {
    h <- target_pred[highlight_rows, , drop = FALSE]
    p <- p +
      ggplot2::geom_point(
        data = h,
        ggplot2::aes(x = .data[[x_axis]], y = .data[[y_axis]]),
        inherit.aes = FALSE,
        color = "#111111",
        fill = "#ffd166",
        shape = 23,
        size = 5,
        stroke = 1.3
      ) +
      ggplot2::geom_text(
        data = h,
        ggplot2::aes(x = .data[[x_axis]], y = .data[[y_axis]], label = text_id),
        inherit.aes = FALSE,
        size = 2.8,
        nudge_y = 0.18,
        color = "#111111",
        check_overlap = TRUE
      )
  }
  p
}

make_row_report <- function(row, binary_contrib, five_contrib, out_path) {
  five_probs <- row[grep("^five_prob_", names(row))]
  binary_probs <- row[grep("^binary_prob_", names(row))]
  five_confidence <- max(as.numeric(five_probs), na.rm = TRUE)

  top_binary <- binary_contrib %>%
    dplyr::filter(model == "binary_human_ki", axis == "LD1") %>%
    dplyr::slice_max(abs_contribution, n = 8) %>%
    dplyr::mutate(line = glue::glue("- {feature}: {round(contribution, 4)}")) %>%
    dplyr::pull(line)

  top_five <- five_contrib %>%
    dplyr::filter(model == "five_group", axis %in% c("LD1", "LD2", "LD3", "LD4")) %>%
    dplyr::group_by(axis) %>%
    dplyr::slice_max(abs_contribution, n = 5, with_ties = FALSE) %>%
    dplyr::ungroup() %>%
    dplyr::mutate(line = glue::glue("- {axis}: {feature} ({round(contribution, 4)})")) %>%
    dplyr::pull(line)

  text <- glue::glue(
"# MILO-LDA Einzelbericht

Text: `{row$text_id}`

Genre: `{row$doc_genre}`

Klasse: `{row$doc_class}`

## Klassifikation

- Binaer: `{row$binary_predicted}`
- P(human): {round(as.numeric(row$binary_prob_human), 4)}
- P(KI): {round(as.numeric(row$binary_prob_ki), 4)}
- 5-Gruppen-LDA: `{row$five_predicted}`
- 5-Gruppen-Konfidenz: {round(five_confidence, 4)}

## Position

- binaere LD1: {round(as.numeric(row$binary_LD1), 3)}
- five LD1: {round(as.numeric(row$five_LD1), 3)}
- five LD2: {round(as.numeric(row$five_LD2), 3)}
- five LD3: {if ('five_LD3' %in% names(row)) round(as.numeric(row$five_LD3), 3) else NA}
- five LD4: {if ('five_LD4' %in% names(row)) round(as.numeric(row$five_LD4), 3) else NA}

## Staerkste globale binaere LD1-Beitraege

{paste(top_binary, collapse = '\n')}

## Staerkste globale 5-Gruppen-Beitraege LD1-LD4

{paste(top_five, collapse = '\n')}
"
  )
  writeLines(text, out_path)
}

write_axis_interpretation <- function(binary_contrib, five_contrib, binary_dir, five_dir, out_path) {
  describe_axis <- function(contrib, model_name, axis, dir_table = NULL) {
    top_pos <- contrib %>%
      dplyr::filter(model == model_name, axis == !!axis, contribution > 0) %>%
      dplyr::slice_max(abs_contribution, n = 8) %>%
      dplyr::pull(feature)
    top_neg <- contrib %>%
      dplyr::filter(model == model_name, axis == !!axis, contribution < 0) %>%
      dplyr::slice_max(abs_contribution, n = 8) %>%
      dplyr::pull(feature)
    group_text <- ""
    if (!is.null(dir_table)) {
      groups <- dir_table %>% dplyr::filter(axis == !!axis)
      low <- groups %>% dplyr::slice_min(mean_score, n = 1)
      high <- groups %>% dplyr::slice_max(mean_score, n = 1)
      group_text <- glue::glue("Gruppenrichtung: niedrig = `{low$group}` ({round(low$mean_score, 3)}), hoch = `{high$group}` ({round(high$mean_score, 3)}).")
    }
    glue::glue(
"### {model_name} {axis}

{group_text}

Positive Seite:
{paste(paste0('- ', top_pos), collapse = '\n')}

Negative Seite:
{paste(paste0('- ', top_neg), collapse = '\n')}
"
    )
  }

  axes_five <- paste0("LD", 1:min(4, max(as.integer(gsub("LD", "", unique(five_contrib$axis))))))
  text <- c(
    "# MILO-LDA: Interpretation der Diskriminanzachsen",
    "",
    "Die folgenden Achseninterpretationen beruhen auf den rekonstruierten Originalfeature-Beitraegen. PCA-Komponenten wurden ueber die gespeicherte PCA-Rotation wieder auf die Ausgangsfeatures zurueckprojiziert; die Ankerfeatures bleiben direkt im LDA-Raum sichtbar.",
    "",
    describe_axis(binary_contrib, "binary_human_ki", "LD1", binary_dir),
    paste(vapply(axes_five, function(axis) describe_axis(five_contrib, "five_group", axis, five_dir), character(1)), collapse = "\n")
  )
  writeLines(text, out_path)
}

load_required_packages()
source_project_files()
ensure_dirs()

bundle <- readRDS(MODEL_BUNDLE_PATH)

training_raw <- readr::read_csv(TRAINING_FEATURE_FILE, show_col_types = FALSE) %>%
  build_lda_labels(bundle$human_core_genres)
training_pred <- predict_all(training_raw, bundle)$predictions %>%
  dplyr::bind_cols(training_raw[, intersect(c("label_5", "label_binary"), names(training_raw)), drop = FALSE])

target_raw <- readr::read_csv(TARGET_FEATURE_FILE, show_col_types = FALSE)
target_result <- predict_all(target_raw, bundle)
target_pred <- add_forensic_audit(target_result$predictions, training_pred)

binary_contrib <- get_axis_contributions(bundle, bundle$binary$fit, axes = 1, model_name = "binary_human_ki")
five_contrib <- get_axis_contributions(bundle, bundle$five_group$fit, axes = 1:4, model_name = "five_group")
all_contrib <- dplyr::bind_rows(binary_contrib, five_contrib)

write_table_csv(all_contrib, "lda_original_feature_contributions.csv", output_dir = OUTPUT_DIR)
write_table_csv(
  all_contrib %>%
    dplyr::group_by(model, axis) %>%
    dplyr::slice_max(abs_contribution, n = 30, with_ties = FALSE) %>%
    dplyr::ungroup(),
  "lda_top_feature_contributions.csv",
  output_dir = OUTPUT_DIR
)

binary_dir <- axis_direction_table(training_pred, "label_binary", "binary_LD1")
five_dir <- axis_direction_table(training_pred, "label_5", paste0("five_LD", 1:4))
write_table_csv(binary_dir, "binary_axis_group_means.csv", output_dir = OUTPUT_DIR)
write_table_csv(five_dir, "five_group_axis_group_means.csv", output_dir = OUTPUT_DIR)
write_table_csv(target_pred, "comparison_lda_predictions.csv", output_dir = OUTPUT_DIR)
write_table_csv(
  target_pred %>%
    dplyr::select(
      text_id,
      binary_predicted,
      binary_prob_human,
      binary_prob_ki,
      binary_margin,
      five_predicted,
      five_nearest_group,
      five_nearest_distance,
      five_distance_ratio,
      five_human_distance_q95,
      dplyr::starts_with("anchor_z_"),
      dplyr::starts_with("binary_anchor_mahal_"),
      binary_anchor_human_q95,
      anchor_log_bluff_human_q01,
      human_ki_residual_q90,
      dplyr::starts_with("flag_"),
      forensic_flags,
      forensic_zone
    ),
  "comparison_forensic_audit.csv",
  output_dir = OUTPUT_DIR
)

highlight_rows <- integer(0)
if (!is.null(TARGET_TEXT_ID)) {
  highlight_rows <- which(target_pred$text_id == TARGET_TEXT_ID)
}
if (length(highlight_rows) == 0 && !is.null(TARGET_ROW_INDEX)) {
  highlight_rows <- TARGET_ROW_INDEX[TARGET_ROW_INDEX >= 1 & TARGET_ROW_INDEX <= nrow(target_pred)]
}

ggplot2::ggsave(
  file.path(FIGURE_DIR, "binary_ld1_feature_contributions.png"),
  plot_binary_contribution_bar(binary_contrib, n = 28),
  width = 9,
  height = 8,
  dpi = 300
)

ggplot2::ggsave(
  file.path(FIGURE_DIR, "five_group_feature_contribution_heatmap_ld1_ld4.png"),
  plot_contribution_heatmap(five_contrib, "five_group", paste0("LD", 1:4), n_per_axis = 18),
  width = 9,
  height = 10,
  dpi = 300
)

ggplot2::ggsave(
  file.path(FIGURE_DIR, "binary_ld1_training_with_ellipses.png"),
  plot_binary_scatter(training_pred),
  width = 9,
  height = 4,
  dpi = 300
)

ggplot2::ggsave(
  file.path(FIGURE_DIR, "five_group_ld1_ld2_training_with_ellipses.png"),
  plot_five_scatter(training_pred, "five_LD1", "five_LD2"),
  width = 9,
  height = 7,
  dpi = 300
)

ggplot2::ggsave(
  file.path(FIGURE_DIR, "five_group_ld1_ld3_training_with_ellipses.png"),
  plot_five_scatter(training_pred, "five_LD1", "five_LD3"),
  width = 9,
  height = 7,
  dpi = 300
)

if (length(highlight_rows) > 0) {
  suffix <- safe_filename(paste(target_pred$text_id[highlight_rows], collapse = "_"))
  ggplot2::ggsave(
    file.path(FIGURE_DIR, paste0("comparison_highlight_", suffix, "_ld1_ld2.png")),
    plot_five_scatter(training_pred, "five_LD1", "five_LD2", target_pred, highlight_rows),
    width = 9,
    height = 7,
    dpi = 300
  )
  ggplot2::ggsave(
    file.path(FIGURE_DIR, paste0("comparison_highlight_", suffix, "_ld1_ld3.png")),
    plot_five_scatter(training_pred, "five_LD1", "five_LD3", target_pred, highlight_rows),
    width = 9,
    height = 7,
    dpi = 300
  )
  for (idx in highlight_rows) {
    make_row_report(
      target_pred[idx, , drop = FALSE],
      binary_contrib,
      five_contrib,
      file.path(REPORT_DIR, paste0("comparison_report_", safe_filename(target_pred$text_id[idx]), ".md"))
    )
  }
}

write_axis_interpretation(
  binary_contrib,
  five_contrib,
  binary_dir,
  five_dir,
  file.path(REPORT_DIR, "lda_axis_interpretation_ld1_ld4.md")
)

message("LDA visualization and comparison outputs written to: ", ensure_output_dir(OUTPUT_DIR))






