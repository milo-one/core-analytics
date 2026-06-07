# CoRE Analytics: interactive PCA plotly exports
#
# Purpose:
# - export interactive 3D PCA plots as standalone HTML files
# - provide variants by individual text, cluster, raw genre and grouped genre
# - collapse KI prompt genres into analytically useful groups
#
# Run from the repository root in RStudio:
#   source("pca_plotly_exports.R")

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
OUTPUT_DIR <- "tables/pca_plotly"
SEED <- 123
CLUSTER_K <- 7

load_required_packages <- function() {
  packages <- c("tidyverse", "plotly", "htmlwidgets", "RColorBrewer")
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

build_plot_data <- function(pca_results, km, full_raw) {
  pc_scores <- as.data.frame(pca_results$pca$x)
  keep_pc <- intersect(paste0("PC", 1:12), names(pc_scores))
  pc_scores <- pc_scores[, keep_pc, drop = FALSE]

  metadata_cols <- intersect(
    c("text_id", "doc_class", "doc_source", "doc_author", "doc_year", "doc_genre", "doc_title"),
    names(full_raw)
  )

  plot_df <- dplyr::bind_cols(
    pc_scores,
    full_raw[, metadata_cols, drop = FALSE]
  )

  plot_df$cluster <- factor(km$cluster)
  plot_df$genre_group <- classify_ki_genre(plot_df$doc_genre)
  plot_df$genre_group <- factor(plot_df$genre_group)

  plot_df$hover_text <- paste0(
    "text_id: ", plot_df$text_id,
    "<br>cluster: ", plot_df$cluster,
    "<br>doc_class: ", plot_df$doc_class,
    "<br>doc_genre: ", plot_df$doc_genre,
    "<br>genre_group: ", plot_df$genre_group,
    if ("doc_author" %in% names(plot_df)) paste0("<br>author: ", plot_df$doc_author) else "",
    if ("doc_year" %in% names(plot_df)) paste0("<br>year: ", plot_df$doc_year) else "",
    "<br>PC1: ", round(plot_df$PC1, 3),
    "<br>PC2: ", round(plot_df$PC2, 3),
    "<br>PC3: ", round(plot_df$PC3, 3)
  )

  plot_df
}

make_3d_plot <- function(
    plot_df,
    color_col = NULL,
    title = "PCA 3D space",
    marker_size = 3,
    opacity = 0.72
) {
  if (is.null(color_col)) {
    fig <- plotly::plot_ly(
      data = plot_df,
      x = ~PC1,
      y = ~PC2,
      z = ~PC3,
      type = "scatter3d",
      mode = "markers",
      marker = list(size = marker_size, opacity = opacity, color = "#2f6f73"),
      text = ~hover_text,
      hoverinfo = "text"
    )
  } else {
    fig <- plotly::plot_ly(
      data = plot_df,
      x = ~PC1,
      y = ~PC2,
      z = ~PC3,
      type = "scatter3d",
      mode = "markers",
      color = plot_df[[color_col]],
      marker = list(size = marker_size, opacity = opacity),
      text = ~hover_text,
      hoverinfo = "text"
    )
  }

  fig %>%
    plotly::layout(
      title = title,
      scene = list(
        xaxis = list(title = "PC1"),
        yaxis = list(title = "PC2"),
        zaxis = list(title = "PC3")
      ),
      legend = list(itemsizing = "constant")
    )
}

save_plotly <- function(fig, filename, output_dir = OUTPUT_DIR) {
  output_dir <- ensure_output_dir(output_dir)
  path <- file.path(output_dir, filename)
  libdir <- paste0(tools::file_path_sans_ext(filename), "_lib")
  htmlwidgets::saveWidget(fig, path, selfcontained = FALSE, libdir = libdir)
  message("Wrote plot: ", path)
  invisible(path)
}

make_2d_plot <- function(plot_df, color_col, title) {
  plotly::plot_ly(
    data = plot_df,
    x = ~PC1,
    y = ~PC2,
    type = "scatter",
    mode = "markers",
    color = plot_df[[color_col]],
    marker = list(size = 7, opacity = 0.68),
    text = ~hover_text,
    hoverinfo = "text"
  ) %>%
    plotly::layout(
      title = title,
      xaxis = list(title = "PC1"),
      yaxis = list(title = "PC2"),
      legend = list(itemsizing = "constant")
    )
}

load_required_packages()
source_project_files()
set.seed(SEED)

message("Loading data from: ", DATA_ROOT)
full_raw <- load_data(DATA_ROOT)
features_for_pca <- remove_old_analysis_columns(full_raw)
cleaned <- clean_numeric(features_for_pca)

pca_results <- run_pca(cleaned$scaled, n_top = 20, n_components = NULL)
km <- run_kmeans(cleaned$scaled, k = CLUSTER_K, seed = SEED)

plot_df <- build_plot_data(pca_results, km, full_raw)

write_table_csv(
  plot_df %>%
    dplyr::count(doc_genre, genre_group, name = "n") %>%
    dplyr::arrange(genre_group, doc_genre),
  "genre_group_mapping_counts.csv",
  output_dir = OUTPUT_DIR
)

write_table_csv(
  plot_df %>%
    dplyr::count(cluster, genre_group, name = "n") %>%
    dplyr::group_by(cluster) %>%
    dplyr::mutate(percent_in_cluster = round(n / sum(n) * 100, 2)) %>%
    dplyr::ungroup(),
  "cluster_by_genre_group.csv",
  output_dir = OUTPUT_DIR
)

write_table_csv(
  plot_df,
  "pca_plot_data.csv",
  output_dir = OUTPUT_DIR
)

plot_plain <- make_3d_plot(
  plot_df,
  color_col = NULL,
  title = "CoRE Analytics PCA: all texts with hover"
)

plot_cluster <- make_3d_plot(
  plot_df,
  color_col = "cluster",
  title = paste0("CoRE Analytics PCA: k = ", CLUSTER_K, " clusters")
)

plot_genre_group <- make_3d_plot(
  plot_df,
  color_col = "genre_group",
  title = "CoRE Analytics PCA: grouped genre / KI prompt type"
)

plot_raw_genre <- make_3d_plot(
  plot_df,
  color_col = "doc_genre",
  title = "CoRE Analytics PCA: raw document genre",
  marker_size = 2.5,
  opacity = 0.65
)

plot_class <- make_3d_plot(
  plot_df,
  color_col = "doc_class",
  title = "CoRE Analytics PCA: document class"
)

plot_2d_cluster <- make_2d_plot(
  plot_df,
  color_col = "cluster",
  title = paste0("CoRE Analytics PCA PC1/PC2: k = ", CLUSTER_K, " clusters")
)

plot_2d_genre_group <- make_2d_plot(
  plot_df,
  color_col = "genre_group",
  title = "CoRE Analytics PCA PC1/PC2: grouped genre / KI prompt type"
)

save_plotly(plot_plain, "pca_3d_all_points_hover.html")
save_plotly(plot_cluster, "pca_3d_by_cluster.html")
save_plotly(plot_genre_group, "pca_3d_by_genre_group.html")
save_plotly(plot_raw_genre, "pca_3d_by_raw_genre.html")
save_plotly(plot_class, "pca_3d_by_doc_class.html")
save_plotly(plot_2d_cluster, "pca_2d_pc1_pc2_by_cluster.html")
save_plotly(plot_2d_genre_group, "pca_2d_pc1_pc2_by_genre_group.html")

pca_plotly_results <- list(
  data = plot_df,
  plots = list(
    plain = plot_plain,
    cluster = plot_cluster,
    genre_group = plot_genre_group,
    raw_genre = plot_raw_genre,
    doc_class = plot_class,
    cluster_2d = plot_2d_cluster,
    genre_group_2d = plot_2d_genre_group
  )
)

message("Plotly exports complete. Outputs written to: ", ensure_output_dir(OUTPUT_DIR))





