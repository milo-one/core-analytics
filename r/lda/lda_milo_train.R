# CoRE Analytics: MILO-style LDA training
#
# Purpose:
# - train a classical binary human-vs-KI LDA
# - train a 5-group LDA after the binary baseline
# - use existing derived features in the data, without rewriting them into full_raw
# - export models, diagnostics, plots and tables
#
# Run from the repository root in RStudio:
#   source("lda_milo_train.R")

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
OUTPUT_DIR <- "tables/lda_milo"
MODEL_DIR <- file.path(OUTPUT_DIR, "models")
FIGURE_DIR <- file.path(OUTPUT_DIR, "figures")
SEED <- 123
LDA_CUMULATIVE_VARIANCE <- 0.90
MAX_PCS <- NULL

load_required_packages <- function() {
  packages <- c("tidyverse", "MASS", "pROC", "ggplot2")
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
  ensure_output_dir(MODEL_DIR)
  ensure_output_dir(FIGURE_DIR)
}

human_core_genres <- c(
  "analytic", "children", "comedy", "conversation",
  "conversation_commentary", "conversation_rant", "diary",
  "dystopia", "erotica", "essay", "fanfic", "horror", "humor",
  "interview", "journalism", "juridical", "letter",
  "literary_classic", "literary_modern", "manifesto",
  "medical", "memoir", "musical", "nonfiction", "novella",
  "poetry", "popular_fiction", "preaching", "propaganda_narrativ",
  "rambling", "religion_doctrine", "romance", "science_classic",
  "science_fiction", "screenplay", "self-help", "shortstories",
  "speech", "theoretical", "lexical", "thriller", "travelouge",
  "bachelor", "master", "abschlussbericht"
)

extra_genres <- c(
  "corporate", "harmful_meta", "manual", "marketing", "propaganda",
  "propaganda_administrative", "technical", "functional_instruction",
  "medical", "journalism"
)

is_ki_prompt_genre <- function(genre) {
  genre <- tolower(as.character(genre))
  grepl("(^|_)(aa|chap|flli-5|ha|leli|mf|mm|so|sv|tat[0-9])_p[0-2](_cot)?$", genre) |
    grepl("_p[0-2](_cot)?$", genre)
}

build_lda_labels <- function(df) {
  df %>%
    dplyr::mutate(
      doc_genre_l = tolower(trimws(as.character(doc_genre))),
      doc_class_l = tolower(trimws(as.character(doc_class))),
      text_id_l = tolower(trimws(as.character(text_id))),
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
    dplyr::select(-doc_genre_l, -doc_class_l, -text_id_l, -doc_id_l, -is_ki_genre)
}

remove_old_analysis_columns <- function(df) {
  old_cols <- c(
    paste0("PC", 1:300),
    paste0("pc", 1:300),
    "cluster", "label", "label_5", "label_binary", "predicted_label",
    "LD1", "LD2", "LD3", "LD4"
  )
  df[, !(names(df) %in% old_cols), drop = FALSE]
}

find_anchor_features <- function(df) {
  candidates <- c("semantic_breadth_abs", "semantic_breadth", "log_bluff", "verbal_overload")
  intersect(candidates, names(df))
}

build_training_features <- function(full_raw) {
  anchor_features <- find_anchor_features(full_raw)
  if (!all(c("log_bluff", "verbal_overload") %in% anchor_features)) {
    stop("Expected derived features log_bluff and verbal_overload are missing.")
  }
  if (!any(c("semantic_breadth_abs", "semantic_breadth") %in% anchor_features)) {
    stop("Expected semantic breadth feature is missing.")
  }

  pca_source <- remove_old_analysis_columns(full_raw)
  pca_source <- pca_source[, !(names(pca_source) %in% anchor_features), drop = FALSE]
  cleaned <- clean_numeric(pca_source)
  pca_input_center <- attr(cleaned$scaled, "scaled:center")
  pca_input_scale <- attr(cleaned$scaled, "scaled:scale")
  pca_model <- stats::prcomp(cleaned$scaled, scale. = FALSE)

  explained <- summary(pca_model)$importance["Cumulative Proportion", ]
  k <- which(explained >= LDA_CUMULATIVE_VARIANCE)[1]
  if (is.na(k)) {
    k <- ncol(pca_model$x)
  }
  if (!is.null(MAX_PCS)) {
    k <- min(k, MAX_PCS)
  }

  scores <- as.data.frame(pca_model$x[, seq_len(k), drop = FALSE])
  colnames(scores) <- paste0("pc", seq_len(k))

  anchors_raw <- full_raw[, anchor_features, drop = FALSE] %>%
    dplyr::mutate(dplyr::across(dplyr::everything(), ~ tidyr::replace_na(as.numeric(.x), 0)))

  anchor_center <- vapply(anchors_raw, mean, numeric(1), na.rm = TRUE)
  anchor_scale <- vapply(anchors_raw, stats::sd, numeric(1), na.rm = TRUE)
  anchor_scale[anchor_scale == 0 | is.na(anchor_scale)] <- 1

  anchors_scaled <- sweep(as.matrix(anchors_raw), 2, anchor_center, "-")
  anchors_scaled <- sweep(anchors_scaled, 2, anchor_scale, "/")
  anchors_scaled <- as.data.frame(anchors_scaled)

  model_matrix <- dplyr::bind_cols(scores, anchors_scaled)

  list(
    model_matrix = model_matrix,
    pca_source_columns = colnames(cleaned$clean),
    pca_input_center = pca_input_center,
    pca_input_scale = pca_input_scale,
    pca_model = pca_model,
    pc_count = k,
    anchor_features = anchor_features,
    anchor_center = anchor_center,
    anchor_scale = anchor_scale
  )
}

fit_lda_model <- function(model_matrix, labels, model_name) {
  lda_df <- model_matrix %>%
    dplyr::mutate(label = factor(labels)) %>%
    dplyr::filter(!is.na(label))

  fit <- MASS::lda(label ~ ., data = lda_df)
  pred <- predict(fit)

  cv_pred <- MASS::lda(label ~ ., data = lda_df, CV = TRUE)

  confusion <- as.data.frame(table(True = lda_df$label, Pred = pred$class))
  confusion_norm <- as.data.frame(prop.table(table(True = lda_df$label, Pred = pred$class), 1))
  cv_confusion <- as.data.frame(table(True = lda_df$label, Pred = cv_pred$class))
  cv_confusion_norm <- as.data.frame(prop.table(table(True = lda_df$label, Pred = cv_pred$class), 1))

  predictions <- lda_df %>%
    dplyr::select(label) %>%
    dplyr::mutate(
      predicted = pred$class,
      cv_predicted = cv_pred$class
    )

  posterior <- as.data.frame(pred$posterior)
  posterior <- posterior %>%
    dplyr::rename_with(~ paste0("prob_", .x))

  ld_scores <- as.data.frame(pred$x)
  ld_scores <- ld_scores %>%
    dplyr::rename_with(~ paste0("LD", seq_along(.x)))

  predictions <- dplyr::bind_cols(predictions, posterior, ld_scores)

  list(
    model_name = model_name,
    lda_df = lda_df,
    fit = fit,
    pred = pred,
    cv_pred = cv_pred,
    predictions = predictions,
    confusion = confusion,
    confusion_norm = confusion_norm,
    cv_confusion = cv_confusion,
    cv_confusion_norm = cv_confusion_norm
  )
}

compute_binary_auc <- function(result) {
  if (!all(c("human", "ki") %in% levels(result$lda_df$label))) {
    return(data.frame())
  }

  prob_col <- "prob_ki"
  if (!prob_col %in% names(result$predictions)) {
    return(data.frame())
  }

  roc_obj <- pROC::roc(
    response = result$lda_df$label == "ki",
    predictor = result$predictions[[prob_col]],
    quiet = TRUE
  )

  data.frame(
    model = result$model_name,
    class = "ki",
    auc = as.numeric(pROC::auc(roc_obj)),
    stringsAsFactors = FALSE
  )
}

compute_one_vs_all_auc <- function(result) {
  classes <- levels(result$lda_df$label)
  rows <- lapply(classes, function(class_name) {
    prob_col <- paste0("prob_", class_name)
    if (!prob_col %in% names(result$predictions)) {
      return(NULL)
    }

    roc_obj <- pROC::roc(
      response = result$lda_df$label == class_name,
      predictor = result$predictions[[prob_col]],
      quiet = TRUE
    )

    data.frame(
      model = result$model_name,
      class = class_name,
      auc = as.numeric(pROC::auc(roc_obj)),
      stringsAsFactors = FALSE
    )
  })

  dplyr::bind_rows(rows)
}

plot_confusion <- function(confusion_df, title, normalized = FALSE) {
  label_col <- if (normalized) "Freq" else "Freq"
  text_labels <- if (normalized) {
    sprintf("%.1f%%", confusion_df[[label_col]] * 100)
  } else {
    as.character(confusion_df[[label_col]])
  }

  confusion_df$label_text <- text_labels

  ggplot2::ggplot(confusion_df, ggplot2::aes(x = Pred, y = True, fill = Freq)) +
    ggplot2::geom_tile(color = "white") +
    ggplot2::geom_text(ggplot2::aes(label = label_text), size = 4) +
    ggplot2::scale_fill_gradient(low = "#f1faee", high = "#1d3557") +
    ggplot2::theme_minimal(base_size = 12) +
    ggplot2::theme(axis.text.x = ggplot2::element_text(angle = 35, hjust = 1)) +
    ggplot2::labs(title = title, x = "Predicted", y = "True")
}

plot_binary_ld <- function(result) {
  result$predictions %>%
    ggplot2::ggplot(ggplot2::aes(x = LD1, fill = label, color = label)) +
    ggplot2::geom_density(alpha = 0.25, linewidth = 1) +
    ggplot2::theme_minimal(base_size = 12) +
    ggplot2::labs(title = "Binary LDA: human vs KI", x = "LD1", y = "Density")
}

plot_multiclass_ld <- function(result) {
  cols <- grep("^LD", names(result$predictions), value = TRUE)
  if (length(cols) < 2) {
    return(NULL)
  }

  result$predictions %>%
    ggplot2::ggplot(ggplot2::aes(x = LD1, y = LD2, color = label)) +
    ggplot2::geom_point(alpha = 0.62, size = 1.8) +
    ggplot2::theme_minimal(base_size = 12) +
    ggplot2::labs(title = "5-group LDA: LD1 / LD2", x = "LD1", y = "LD2", color = "Label")
}

save_result_tables <- function(result, prefix) {
  write_table_csv(result$confusion, paste0(prefix, "_confusion.csv"), output_dir = OUTPUT_DIR)
  write_table_csv(result$confusion_norm, paste0(prefix, "_confusion_norm.csv"), output_dir = OUTPUT_DIR)
  write_table_csv(result$cv_confusion, paste0(prefix, "_cv_confusion.csv"), output_dir = OUTPUT_DIR)
  write_table_csv(result$cv_confusion_norm, paste0(prefix, "_cv_confusion_norm.csv"), output_dir = OUTPUT_DIR)
  write_table_csv(result$predictions, paste0(prefix, "_predictions.csv"), output_dir = OUTPUT_DIR)
}

save_result_plots <- function(result, prefix) {
  ggplot2::ggsave(
    file.path(FIGURE_DIR, paste0(prefix, "_confusion.png")),
    plot_confusion(result$confusion, paste0(prefix, " confusion"), normalized = FALSE),
    width = 7,
    height = 5,
    dpi = 300
  )

  ggplot2::ggsave(
    file.path(FIGURE_DIR, paste0(prefix, "_confusion_norm.png")),
    plot_confusion(result$confusion_norm, paste0(prefix, " confusion (%)"), normalized = TRUE),
    width = 7,
    height = 5,
    dpi = 300
  )

  if (prefix == "binary") {
    ggplot2::ggsave(
      file.path(FIGURE_DIR, "binary_ld1_density.png"),
      plot_binary_ld(result),
      width = 8,
      height = 5,
      dpi = 300
    )
  } else {
    p <- plot_multiclass_ld(result)
    if (!is.null(p)) {
      ggplot2::ggsave(
        file.path(FIGURE_DIR, paste0(prefix, "_ld1_ld2.png")),
        p,
        width = 8,
        height = 6,
        dpi = 300
      )
    }
  }
}

load_required_packages()
source_project_files()
ensure_dirs()
set.seed(SEED)

full_raw <- load_data(DATA_ROOT) %>% build_lda_labels()
feature_bundle <- build_training_features(full_raw)

binary_filter <- !is.na(full_raw$label_binary)
binary_result <- fit_lda_model(
  feature_bundle$model_matrix[binary_filter, , drop = FALSE],
  full_raw$label_binary[binary_filter],
  "binary_human_ki"
)

five_group_result <- fit_lda_model(
  feature_bundle$model_matrix,
  full_raw$label_5,
  "five_group"
)

save_result_tables(binary_result, "binary")
save_result_tables(five_group_result, "five_group")
save_result_plots(binary_result, "binary")
save_result_plots(five_group_result, "five_group")

auc_table <- dplyr::bind_rows(
  compute_binary_auc(binary_result),
  compute_one_vs_all_auc(five_group_result)
)
write_table_csv(auc_table, "lda_auc.csv", output_dir = OUTPUT_DIR)

label_counts <- full_raw %>%
  dplyr::count(label_5, label_binary, name = "n") %>%
  dplyr::arrange(label_5, label_binary)
write_table_csv(label_counts, "lda_label_counts.csv", output_dir = OUTPUT_DIR)

bundle <- list(
  created_at = Sys.time(),
  data_root = DATA_ROOT,
  feature_bundle = feature_bundle,
  human_core_genres = human_core_genres,
  extra_genres = extra_genres,
  binary = list(fit = binary_result$fit, labels = levels(binary_result$lda_df$label)),
  five_group = list(fit = five_group_result$fit, labels = levels(five_group_result$lda_df$label))
)

saveRDS(bundle, file.path(MODEL_DIR, "milo_lda_model_bundle.rds"))

summary_table <- data.frame(
  model = c("binary_human_ki", "five_group"),
  n_training = c(nrow(binary_result$lda_df), nrow(five_group_result$lda_df)),
  n_predictors = c(ncol(binary_result$lda_df) - 1, ncol(five_group_result$lda_df) - 1),
  pc_count = feature_bundle$pc_count,
  anchor_features = paste(feature_bundle$anchor_features, collapse = ", "),
  stringsAsFactors = FALSE
)
write_table_csv(summary_table, "lda_model_summary.csv", output_dir = OUTPUT_DIR)

lda_training_results <- list(
  full_raw = full_raw,
  feature_bundle = feature_bundle,
  binary = binary_result,
  five_group = five_group_result,
  auc = auc_table,
  summary = summary_table
)

message("LDA training complete. Outputs written to: ", ensure_output_dir(OUTPUT_DIR))





