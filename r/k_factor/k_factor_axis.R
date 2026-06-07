# CoRE Analytics: K-Factor personalized axis
#
# Purpose:
# - define a personalized stylistic axis in the freshly computed PCA space
# - score all corpus texts by projection, orthogonal distance and K-Factor
# - export nearest-neighbor tables and a text report
# - visualize the axis in an interactive 3D plot
#
# Run from the repository root in RStudio:
#   source("k_factor_axis.R")
#
# Optional configuration before sourcing:
#   REFERENCE_TEXT_IDS <- c("text_id_1", "text_id_2", "text_id_3")
#   REFERENCE_FEATURE_FILE <- "C:/path/to/author/features_full.csv"
#   REFERENCE_FEATURE_FOLDER <- "C:/path/with/features_full.csv/files"
#   TARGET_FEATURE_FILE <- "C:/path/to/comparison/features_full.csv"
#   TARGET_TEXT_IDS <- c("model_or_text_to_describe")
#   PLOT_CONTEXT_CORPUS <- TRUE
#
# For an arbitrary author axis:
#   1. create features_full.csv for several reference texts by that author
#   2. set REFERENCE_FEATURE_FILE or REFERENCE_FEATURE_FOLDER
#   3. optionally set TARGET_FEATURE_FILE for new texts to score

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
OUTPUT_DIR <- "tables/k_factor"
FIGURE_DIR <- file.path(OUTPUT_DIR, "figures")
MODEL_DIR <- file.path(OUTPUT_DIR, "models")

SEED <- 123
K_FACTOR_PC_COUNT <- 52
K_FACTOR_PLOT_PC_COUNT <- 3
AXIS_SCALE <- 4
TOP_NEIGHBORS_N <- 30
PLOT_CONTEXT_CORPUS <- if (exists("PLOT_CONTEXT_CORPUS")) PLOT_CONTEXT_CORPUS else TRUE

REFERENCE_TEXT_IDS <- if (exists("REFERENCE_TEXT_IDS")) REFERENCE_TEXT_IDS else NULL
REFERENCE_FEATURE_FILE <- if (exists("REFERENCE_FEATURE_FILE")) REFERENCE_FEATURE_FILE else NULL
REFERENCE_FEATURE_FOLDER <- if (exists("REFERENCE_FEATURE_FOLDER")) REFERENCE_FEATURE_FOLDER else NULL
TARGET_FEATURE_FILE <- if (exists("TARGET_FEATURE_FILE")) TARGET_FEATURE_FILE else NULL
TARGET_TEXT_IDS <- if (exists("TARGET_TEXT_IDS")) TARGET_TEXT_IDS else NULL

load_required_packages <- function() {
  packages <- c("tidyverse", "plotly", "htmlwidgets")
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
  ensure_output_dir(MODEL_DIR)
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
    paste0("LD", 1:30)
  )
  df[, !(names(df) %in% old_cols), drop = FALSE]
}

load_feature_folder <- function(folder) {
  files <- list.files(folder, pattern = "features_full\\.csv$", full.names = TRUE, recursive = TRUE)
  if (length(files) == 0) {
    stop("No features_full.csv found in folder: ", folder)
  }

  dplyr::bind_rows(lapply(files, function(file) {
    tmp <- readr::read_csv(file, show_col_types = FALSE)
    tmp$file_id <- basename(dirname(file))
    tmp$feature_file <- file
    if (!"text_id" %in% names(tmp)) {
      tmp$text_id <- paste0(tmp$file_id, "_row_", seq_len(nrow(tmp)))
    }
    tmp
  }))
}

load_feature_input <- function(feature_file = NULL, feature_folder = NULL, fallback_df = NULL) {
  if (!is.null(feature_file) && nzchar(feature_file)) {
    return(readr::read_csv(feature_file, show_col_types = FALSE))
  }
  if (!is.null(feature_folder) && nzchar(feature_folder)) {
    return(load_feature_folder(feature_folder))
  }
  if (!is.null(fallback_df)) {
    return(fallback_df)
  }
  stop("No feature input supplied.")
}

ensure_metadata_columns <- function(df) {
  if (!"text_id" %in% names(df)) {
    df$text_id <- paste0("row_", seq_len(nrow(df)))
  }
  for (col in c("doc_class", "doc_genre", "doc_source", "doc_author", "doc_year", "doc_id", "cluster")) {
    if (!col %in% names(df)) {
      df[[col]] <- NA_character_
    }
  }
  df
}

make_genre_group <- function(df) {
  genre <- tolower(as.character(df$doc_genre))
  class <- tolower(as.character(df$doc_class))
  text_id <- tolower(as.character(df$text_id))
  dplyr::case_when(
    class %in% c("author", "reddit", "whatsapp", "youtube", "wiki", "human", "mensch") ~ "human",
    grepl("_cot$", genre) ~ "ki_cot",
    grepl("_p[12]$", genre) | grepl("model_interaction", genre) | grepl("personal", text_id) ~ "ki_personalized",
    grepl("_p0$", genre) | grepl("model", class) | grepl("conversation_ai|conversation_rant_ai", genre) ~ "ki_generic",
    TRUE ~ "extra"
  )
}

build_fresh_pca <- function(full_raw) {
  features_for_pca <- remove_old_analysis_columns(full_raw)
  cleaned <- clean_numeric(features_for_pca)
  pca_model <- stats::prcomp(cleaned$scaled, scale. = FALSE)
  pc_count <- min(K_FACTOR_PC_COUNT, ncol(pca_model$x))
  scores <- as.data.frame(pca_model$x[, seq_len(pc_count), drop = FALSE])
  colnames(scores) <- paste0("PC", seq_len(pc_count))
  scores$text_id <- full_raw$text_id

  eig <- pca_model$sdev^2
  variance <- data.frame(
    PC = paste0("PC", seq_along(eig)),
    variance_explained = eig / sum(eig),
    cumulative_variance = cumsum(eig / sum(eig)),
    stringsAsFactors = FALSE
  )

  list(
    cleaned = cleaned,
    pca = pca_model,
    scores = scores,
    pc_cols = paste0("PC", seq_len(pc_count)),
    variance = variance
  )
}

project_features_to_pca <- function(raw_df, pca_bundle) {
  raw_df <- ensure_metadata_columns(raw_df)
  feature_cols <- colnames(pca_bundle$cleaned$clean)
  missing_cols <- setdiff(feature_cols, names(raw_df))
  if (length(missing_cols) > 0) {
    warning("Missing feature columns in projection input; filling with zero: ", paste(missing_cols, collapse = ", "))
    for (col in missing_cols) {
      raw_df[[col]] <- 0
    }
  }

  x <- raw_df[, feature_cols, drop = FALSE] %>%
    dplyr::mutate(dplyr::across(dplyr::everything(), ~ tidyr::replace_na(as.numeric(.x), 0)))
  x_scaled <- scale(
    as.matrix(x),
    center = attr(pca_bundle$cleaned$scaled, "scaled:center"),
    scale = attr(pca_bundle$cleaned$scaled, "scaled:scale")
  )

  pc_count <- length(pca_bundle$pc_cols)
  scores <- x_scaled %*% pca_bundle$pca$rotation[, seq_len(pc_count), drop = FALSE]
  scores <- as.data.frame(scores)
  colnames(scores) <- pca_bundle$pc_cols
  scores$text_id <- raw_df$text_id

  meta_cols <- intersect(
    c("text_id", "doc_class", "doc_genre", "doc_source", "doc_author", "doc_year", "doc_id", "cluster", "file_id", "feature_file"),
    names(raw_df)
  )

  raw_df[, meta_cols, drop = FALSE] %>%
    dplyr::left_join(scores, by = "text_id") %>%
    dplyr::mutate(genre_group = make_genre_group(.))
}

auto_reference_ids <- function(df, min_n = 3) {
  candidates <- df %>%
    dplyr::mutate(
      text_id_l = tolower(as.character(text_id)),
      doc_id_l = if ("doc_id" %in% names(.)) tolower(as.character(doc_id)) else "",
      doc_genre_l = tolower(as.character(doc_genre)),
      doc_class_l = tolower(as.character(doc_class))
    ) %>%
    dplyr::filter(
      grepl("kathrin", text_id_l) |
        grepl("kathrin", doc_id_l) |
        grepl("kathrin", doc_genre_l) |
        grepl("kathrin", doc_class_l) |
        grepl("gpt_4o_kathrin|gpt_5\\.1_kathrin", doc_id_l)
    )

  if (nrow(candidates) >= min_n) {
    return(candidates$text_id)
  }

  fallback <- df %>%
    dplyr::mutate(
      text_id_l = tolower(as.character(text_id)),
      doc_genre_l = tolower(as.character(doc_genre)),
      doc_class_l = tolower(as.character(doc_class))
    ) %>%
    dplyr::filter(
      grepl("model_interaction", doc_genre_l) |
        grepl("_p[12]$", doc_genre_l) |
        (grepl("model", doc_class_l) & grepl("kathrin|personal", text_id_l))
    )

  if (nrow(fallback) >= min_n) {
    return(fallback$text_id)
  }

  character(0)
}

build_person_axis <- function(scores_df, reference_ids = NULL, pc_cols) {
  ref <- if (is.null(reference_ids) || length(reference_ids) == 0) {
    scores_df
  } else {
    scores_df %>% dplyr::filter(text_id %in% reference_ids)
  }
  if (nrow(ref) < 3) {
    stop("K-Factor needs at least 3 reference texts. Found: ", nrow(ref))
  }

  m <- as.matrix(ref[, pc_cols, drop = FALSE])
  center <- colMeans(m)

  if (nrow(ref) >= 3) {
    pca_person <- stats::prcomp(m, center = TRUE, scale. = FALSE)
    direction <- pca_person$rotation[, 1]
  } else {
    direction <- center
  }
  direction <- direction / sqrt(sum(direction^2))

  # Orient the axis so the average reference projection is positive.
  ref_projection <- as.vector((m - matrix(center, nrow(m), length(center), byrow = TRUE)) %*% direction)
  if (mean(ref_projection, na.rm = TRUE) < 0) {
    direction <- -direction
  }

  dists <- sqrt(rowSums((m - matrix(center, nrow(m), length(center), byrow = TRUE))^2))
  radius <- mean(dists, na.rm = TRUE)
  if (!is.finite(radius) || radius == 0) {
    radius <- 1
  }

  list(
    center = center,
    direction = direction,
    radius = radius,
    reference_ids = ref$text_id,
    n_reference = nrow(ref),
    pc_cols = pc_cols,
    reference_distances = dists,
    reference_projection_sd = stats::sd(ref_projection, na.rm = TRUE)
  )
}

score_against_axis <- function(scores_df, axis_obj) {
  pc_cols <- axis_obj$pc_cols
  m <- as.matrix(scores_df[, pc_cols, drop = FALSE])
  shifted <- sweep(m, 2, axis_obj$center, "-")
  projection <- as.vector(shifted %*% axis_obj$direction)
  reconstructed <- sweep(matrix(projection, ncol = 1) %*% t(axis_obj$direction), 2, axis_obj$center, "+")
  orth_distance <- sqrt(rowSums((m - reconstructed)^2))
  euclidean_to_center <- sqrt(rowSums(shifted^2))

  scores_df %>%
    dplyr::mutate(
      k_projection = projection,
      k_factor = projection / axis_obj$radius,
      k_axis_distance = orth_distance,
      k_center_distance = euclidean_to_center,
      k_axis_similarity = 1 / (1 + orth_distance),
      k_on_reference_axis = text_id %in% axis_obj$reference_ids
    )
}

axis_feature_contributions <- function(axis_obj, pca_obj, top_n = 40) {
  pc_index <- as.integer(gsub("^PC", "", axis_obj$pc_cols))
  rotation <- pca_obj$rotation[, pc_index, drop = FALSE]
  contrib <- rotation %*% axis_obj$direction
  data.frame(
    feature = rownames(rotation),
    contribution = as.numeric(contrib),
    abs_contribution = abs(as.numeric(contrib)),
    direction = ifelse(contrib >= 0, "positive", "negative"),
    stringsAsFactors = FALSE
  ) %>%
    dplyr::arrange(dplyr::desc(abs_contribution)) %>%
    dplyr::slice_head(n = top_n)
}

nearest_to_axis <- function(scored_df, n = TOP_NEIGHBORS_N, label_filter = NULL) {
  out <- scored_df
  if (!is.null(label_filter)) {
    out <- out %>% dplyr::filter(genre_group %in% label_filter)
  }
  out %>%
    dplyr::arrange(k_axis_distance, dplyr::desc(abs(k_projection))) %>%
    dplyr::select(
      text_id,
      genre_group,
      doc_class,
      doc_genre,
      k_factor,
      k_projection,
      k_axis_distance,
      k_center_distance,
      k_axis_similarity
    ) %>%
    dplyr::slice_head(n = n)
}

summarise_kfactor_groups <- function(scored_df) {
  scored_df %>%
    dplyr::group_by(genre_group) %>%
    dplyr::summarise(
      n = dplyr::n(),
      mean_k_factor = mean(k_factor, na.rm = TRUE),
      median_k_factor = stats::median(k_factor, na.rm = TRUE),
      sd_k_factor = stats::sd(k_factor, na.rm = TRUE),
      mean_axis_distance = mean(k_axis_distance, na.rm = TRUE),
      median_axis_distance = stats::median(k_axis_distance, na.rm = TRUE),
      nearest_axis_distance = min(k_axis_distance, na.rm = TRUE),
      mean_axis_similarity = mean(k_axis_similarity, na.rm = TRUE),
      .groups = "drop"
    ) %>%
    dplyr::arrange(mean_axis_distance)
}

summarise_kfactor_reference <- function(reference_scored) {
  reference_scored %>%
    dplyr::summarise(
      n = dplyr::n(),
      mean_k_factor = mean(k_factor, na.rm = TRUE),
      sd_k_factor = stats::sd(k_factor, na.rm = TRUE),
      min_k_factor = min(k_factor, na.rm = TRUE),
      max_k_factor = max(k_factor, na.rm = TRUE),
      mean_axis_distance = mean(k_axis_distance, na.rm = TRUE),
      median_axis_distance = stats::median(k_axis_distance, na.rm = TRUE),
      max_axis_distance = max(k_axis_distance, na.rm = TRUE),
      .groups = "drop"
    )
}

make_axis_line <- function(axis_obj, plot_cols = paste0("PC", 1:3), scale = AXIS_SCALE) {
  idx <- match(plot_cols, axis_obj$pc_cols)
  center <- axis_obj$center[idx]
  direction <- axis_obj$direction[idx]
  direction <- direction / sqrt(sum(direction^2))
  data.frame(
    PC1 = center[1] + c(-scale, scale) * direction[1],
    PC2 = center[2] + c(-scale, scale) * direction[2],
    PC3 = center[3] + c(-scale, scale) * direction[3],
    stringsAsFactors = FALSE
  )
}

plot_k_axis_3d <- function(scored_df, axis_obj, reference_scored = NULL, target_scored = NULL, top_label_n = 80) {
  axis_line <- make_axis_line(axis_obj)
  plot_df <- scored_df %>%
    dplyr::mutate(
      point_size = ifelse(k_on_reference_axis, 6, 2.4),
      hover = paste0(
        "ID: ", text_id,
        "<br>group: ", genre_group,
        "<br>class: ", doc_class,
        "<br>genre: ", doc_genre,
        "<br>K-Factor: ", round(k_factor, 3),
        "<br>Axis distance: ", round(k_axis_distance, 3),
        "<br>Projection: ", round(k_projection, 3)
      )
    )

  label_df <- plot_df %>%
    dplyr::arrange(k_axis_distance) %>%
    dplyr::slice_head(n = top_label_n)

  ref_df <- reference_scored
  if (is.null(ref_df)) {
    ref_df <- plot_df %>% dplyr::filter(k_on_reference_axis)
  }
  if (!is.null(ref_df) && nrow(ref_df) > 0) {
    ref_df <- ref_df %>%
      dplyr::mutate(
        hover = paste0(
          "REFERENCE",
          "<br>ID: ", text_id,
          "<br>K-Factor: ", round(k_factor, 3),
          "<br>Axis distance: ", round(k_axis_distance, 3)
        )
      )
  }

  target_df <- target_scored
  if (!is.null(target_df) && nrow(target_df) > 0) {
    target_df <- target_df %>%
      dplyr::mutate(
        hover = paste0(
          "TARGET",
          "<br>ID: ", text_id,
          "<br>group: ", genre_group,
          "<br>K-Factor: ", round(k_factor, 3),
          "<br>Axis distance: ", round(k_axis_distance, 3),
          "<br>Projection: ", round(k_projection, 3)
        )
      )
  }

  p <- plotly::plot_ly() %>%
    plotly::add_markers(
      data = plot_df,
      x = ~PC1,
      y = ~PC2,
      z = ~PC3,
      color = ~genre_group,
      colors = c(
        human = "#1f77b4",
        ki_generic = "#d62728",
        ki_personalized = "#2ca02c",
        ki_cot = "#9467bd",
        extra = "#7f7f7f"
      ),
      marker = list(size = ~point_size, opacity = 0.58),
      text = ~hover,
      hoverinfo = "text",
      name = "Corpus"
    )

  if (!is.null(ref_df) && nrow(ref_df) > 0) {
    p <- p %>%
      plotly::add_markers(
        data = ref_df,
        x = ~PC1,
        y = ~PC2,
        z = ~PC3,
        marker = list(size = 7, color = "#0b6f7f", symbol = "diamond", opacity = 0.95),
        text = ~hover,
        hoverinfo = "text",
        name = "K reference"
      )
  }

  if (!is.null(target_df) && nrow(target_df) > 0) {
    p <- p %>%
      plotly::add_markers(
        data = target_df,
        x = ~PC1,
        y = ~PC2,
        z = ~PC3,
        marker = list(size = 8, color = "#ffb000", symbol = "circle", opacity = 0.95),
        text = ~hover,
        hoverinfo = "text",
        name = "Scored target"
      )
  }

  p %>%
    plotly::add_trace(
      data = axis_line,
      x = ~PC1,
      y = ~PC2,
      z = ~PC3,
      type = "scatter3d",
      mode = "lines",
      line = list(color = "#0b6f7f", width = 9),
      name = "K-Factor axis"
    ) %>%
    plotly::add_text(
      data = label_df,
      x = ~PC1,
      y = ~PC2,
      z = ~PC3,
      text = ~text_id,
      textfont = list(size = 9),
      showlegend = FALSE,
      hoverinfo = "none"
    ) %>%
    plotly::layout(
      title = "K-Factor axis in the PCA style space",
      scene = list(
        xaxis = list(title = "PC1 - Structural dominance / compression"),
        yaxis = list(title = "PC2 - Directness / operative steering"),
        zaxis = list(title = "PC3 - Semantic coherence / self-positioning")
      ),
      legend = list(orientation = "h")
    )
}

write_kfactor_report <- function(scored_df, reference_scored, axis_obj, contrib, output_path, target_ids = NULL) {
  ref_summary <- summarise_kfactor_reference(reference_scored)
  group_summary <- summarise_kfactor_groups(scored_df)

  top_axis <- nearest_to_axis(scored_df, n = 12)
  high_k <- scored_df %>%
    dplyr::arrange(dplyr::desc(k_factor)) %>%
    dplyr::select(text_id, genre_group, k_factor, k_axis_distance) %>%
    dplyr::slice_head(n = 12)
  low_k <- scored_df %>%
    dplyr::arrange(k_factor) %>%
    dplyr::select(text_id, genre_group, k_factor, k_axis_distance) %>%
    dplyr::slice_head(n = 12)

  target_block <- ""
  if (!is.null(target_ids)) {
    targets <- scored_df %>% dplyr::filter(text_id %in% target_ids)
    if (nrow(targets) > 0) {
      target_lines <- targets %>%
        dplyr::mutate(line = paste0(
          "- `", text_id, "`: K=", round(k_factor, 3),
          ", Achsendistanz=", round(k_axis_distance, 3),
          ", Projektion=", round(k_projection, 3),
          ", Gruppe=", genre_group
        )) %>%
        dplyr::pull(line)
      target_block <- paste0("\n## Zieltexte\n\n", paste(target_lines, collapse = "\n"), "\n")
    }
  }

  fmt_table <- function(df) {
    paste(utils::capture.output(print(df, row.names = FALSE)), collapse = "\n")
  }

  text <- paste0(
    "# K-Faktor: personalisierte PCA-Achse\n\n",
    "Der K-Faktor ist eine projektinterne Metrik fuer Naehe zu einer personalisierten Stilachse. ",
    "Er ist keine Klassifikation und ersetzt weder LDA noch Clusteranalyse. ",
    "Er misst, wie ein Text relativ zu einem Referenzzentrum auf einer aus Referenztexten abgeleiteten PCA-Richtung liegt.\n\n",
    "Das Skript kann fuer beliebige Autor- oder Vergleichsdaten verwendet werden, solange diese als `features_full.csv` ",
    "durch dieselbe Feature-Pipeline erzeugt wurden. Externe Referenzdaten definieren die Achse; externe Zieldaten werden anschliessend in denselben PCA-Raum projiziert und gegen diese Achse bewertet.\n\n",
    "## Definition\n\n",
    "- `k_projection`: Projektion eines Textes auf die K-Achse.\n",
    "- `k_factor`: Projektion normiert durch den mittleren Referenzradius.\n",
    "- `k_axis_distance`: orthogonale Distanz zur Achse; niedrig bedeutet achsennah.\n",
    "- `k_center_distance`: Gesamtdistanz zum Referenzzentrum.\n",
    "- `k_axis_similarity`: einfache Aehnlichkeitsskala `1 / (1 + axis_distance)`.\n\n",
    "## Referenzachse\n\n",
    "- Referenztexte: ", axis_obj$n_reference, "\n",
    "- PCs verwendet: ", length(axis_obj$pc_cols), "\n",
    "- mittlerer Referenzradius: ", round(axis_obj$radius, 4), "\n\n",
    "Referenzzusammenfassung:\n\n```text\n", fmt_table(ref_summary), "\n```\n\n",
    "## Gruppenuebersicht\n\n```text\n", fmt_table(group_summary), "\n```\n\n",
    "## Achsennaechste Texte\n\n```text\n", fmt_table(top_axis), "\n```\n\n",
    "## Hoechste K-Faktoren\n\n```text\n", fmt_table(high_k), "\n```\n\n",
    "## Niedrigste K-Faktoren\n\n```text\n", fmt_table(low_k), "\n```\n",
    target_block,
    "\n## Staerkste Feature-Beitraege zur K-Achse\n\n```text\n",
    fmt_table(contrib %>% dplyr::select(feature, contribution, direction) %>% dplyr::slice_head(n = 25)),
    "\n```\n\n",
    "## Interpretation\n\n",
    "Hohe positive K-Werte bedeuten eine starke Ausrichtung entlang der positiven Referenzrichtung. ",
    "Niedrige oder negative Werte bedeuten Gegenrichtung oder Entfernung entlang der Achse. ",
    "Die wichtigste Qualitaetskontrolle ist die Achsendistanz: Ein hoher K-Wert ohne niedrige Achsendistanz ist keine echte Naehe zur Achse, sondern nur eine Projektion aus groesserer Entfernung. ",
    "Fuer Modellvergleiche sind deshalb `k_factor` und `k_axis_distance` gemeinsam zu lesen.\n"
  )

  writeLines(text, output_path)
}

load_required_packages()
source_project_files()
ensure_dirs()
set.seed(SEED)

full_raw <- load_data(DATA_ROOT)
pca_bundle <- build_fresh_pca(full_raw)

corpus_scores <- project_features_to_pca(full_raw, pca_bundle)

has_external_reference <- (!is.null(REFERENCE_FEATURE_FILE) && nzchar(REFERENCE_FEATURE_FILE)) ||
  (!is.null(REFERENCE_FEATURE_FOLDER) && nzchar(REFERENCE_FEATURE_FOLDER))

if (has_external_reference) {
  reference_raw <- load_feature_input(
    feature_file = REFERENCE_FEATURE_FILE,
    feature_folder = REFERENCE_FEATURE_FOLDER
  )
  reference_scores <- project_features_to_pca(reference_raw, pca_bundle)
  reference_ids <- reference_scores$text_id
} else {
  reference_scores <- corpus_scores
  reference_ids <- REFERENCE_TEXT_IDS
  if (is.null(reference_ids) || length(reference_ids) == 0) {
    reference_ids <- auto_reference_ids(full_raw)
  }
}

if (length(reference_ids) < 3) {
  stop(
    "No sufficient K-Factor reference texts found. ",
    "Set REFERENCE_TEXT_IDS, REFERENCE_FEATURE_FILE, or REFERENCE_FEATURE_FOLDER before sourcing this script."
  )
}

target_raw <- load_feature_input(
  feature_file = TARGET_FEATURE_FILE,
  fallback_df = full_raw
)
target_scores <- project_features_to_pca(target_raw, pca_bundle)

axis_obj <- build_person_axis(reference_scores, reference_ids, pca_bundle$pc_cols)
scored <- score_against_axis(target_scores, axis_obj)
reference_scored <- score_against_axis(reference_scores %>% dplyr::filter(text_id %in% axis_obj$reference_ids), axis_obj)
context_scored <- if (PLOT_CONTEXT_CORPUS) {
  score_against_axis(corpus_scores, axis_obj)
} else {
  scored
}
contrib <- axis_feature_contributions(axis_obj, pca_bundle$pca, top_n = 80)
group_summary <- summarise_kfactor_groups(scored)
reference_summary <- summarise_kfactor_reference(reference_scored)

write_table_csv(pca_bundle$variance, "k_factor_fresh_pca_variance.csv", output_dir = OUTPUT_DIR)
write_table_csv(reference_scores %>% dplyr::filter(text_id %in% axis_obj$reference_ids), "k_factor_reference_texts.csv", output_dir = OUTPUT_DIR)
write_table_csv(reference_summary, "k_factor_reference_summary.csv", output_dir = OUTPUT_DIR)
write_table_csv(scored, "k_factor_scores.csv", output_dir = OUTPUT_DIR)
write_table_csv(group_summary, "k_factor_group_summary.csv", output_dir = OUTPUT_DIR)
write_table_csv(nearest_to_axis(scored, TOP_NEIGHBORS_N), "k_factor_nearest_to_axis_all.csv", output_dir = OUTPUT_DIR)
write_table_csv(nearest_to_axis(scored, TOP_NEIGHBORS_N, label_filter = "human"), "k_factor_nearest_to_axis_human.csv", output_dir = OUTPUT_DIR)
write_table_csv(nearest_to_axis(scored, TOP_NEIGHBORS_N, label_filter = c("ki_generic", "ki_personalized", "ki_cot")), "k_factor_nearest_to_axis_ki.csv", output_dir = OUTPUT_DIR)
write_table_csv(contrib, "k_factor_axis_feature_contributions.csv", output_dir = OUTPUT_DIR)

saveRDS(
  list(
    created_at = Sys.time(),
    data_root = DATA_ROOT,
    axis = axis_obj,
    pca = pca_bundle$pca,
    pca_input_columns = colnames(pca_bundle$cleaned$clean),
    pca_input_center = attr(pca_bundle$cleaned$scaled, "scaled:center"),
    pca_input_scale = attr(pca_bundle$cleaned$scaled, "scaled:scale")
  ),
  file.path(MODEL_DIR, "k_factor_axis_bundle.rds")
)

p3d <- plot_k_axis_3d(
  context_scored,
  axis_obj,
  reference_scored = reference_scored,
  target_scored = if (PLOT_CONTEXT_CORPUS && !is.null(TARGET_FEATURE_FILE) && nzchar(TARGET_FEATURE_FILE)) scored else NULL
)
htmlwidgets::saveWidget(
  p3d,
  file.path(FIGURE_DIR, "k_factor_axis_3d.html"),
  selfcontained = FALSE
)

write_kfactor_report(
  scored,
  reference_scored,
  axis_obj,
  contrib,
  file.path(OUTPUT_DIR, "k_factor_report.md"),
  target_ids = TARGET_TEXT_IDS
)

k_factor_results <- list(
  full_raw = full_raw,
  pca = pca_bundle,
  axis = axis_obj,
  scored = scored,
  context_scored = context_scored,
  group_summary = group_summary,
  reference_summary = reference_summary,
  contributions = contrib,
  plot = p3d
)

message("K-Factor analysis complete. Outputs written to: ", ensure_output_dir(OUTPUT_DIR))





