# K-Factor + corek workbench.
#
# Purpose:
# - fit a person/author axis from reference features
# - score a reference corpus, optional target data and a baseline corpus
# - search nearest texts by axis distance or by a query text
# - estimate how a text would need to move toward the person axis, center or
#   another text, including top feature-level change directions
# - write a 3D Plotly visualization when plotly/htmlwidgets are available
#
# Override defaults before sourcing or via environment variables:
#
#   BASELINE_FEATURE_FILE <- "C:/path/to/baseline/features_full.csv"
#   REFERENCE_FEATURE_FILE <- "C:/path/to/reference_author/features_full.csv"
#   TARGET_FEATURE_FILE <- "C:/path/to/optional_target/features_full.csv"
#   QUERY_TEXT_ID <- "text_id_for_nearest_neighbor_search"
#   MOVEMENT_TEXT_ID <- "text_id_to_move"
#   MOVEMENT_TO <- "axis"       # "axis", "center", or "text"
#   MOVEMENT_TO_TEXT_ID <- NULL # used only when MOVEMENT_TO == "text"
#   NEAREST_N <- 20
#   TOP_FEATURES_N <- 20
#   OUTPUT_DIR <- "examples_out/k_factor_workbench"

if (dir.exists("R")) {
  invisible(lapply(list.files("R", full.names = TRUE), source))
} else {
  library(corek)
}

first_existing <- function(paths) {
  hit <- paths[file.exists(paths)]
  if (length(hit) == 0) NA_character_ else hit[1]
}

get_config <- function(name, default = NULL) {
  if (exists(name, envir = .GlobalEnv)) {
    return(get(name, envir = .GlobalEnv))
  }
  env <- Sys.getenv(paste0("COREK_", name), unset = "")
  if (nzchar(env)) env else default
}

BASELINE_FEATURE_FILE <- get_config(
  "BASELINE_FEATURE_FILE",
  first_existing(c(
    file.path("..", "..", "data", "features_full.csv"),
    "C:/Users/Kathrin Preuß/OneDrive/Dokumente/core-analytics/data/features_full.csv"
  ))
)

REFERENCE_FEATURE_FILE <- get_config(
  "REFERENCE_FEATURE_FILE",
  first_existing(c(
    file.path("inst", "extdata", "kafka_features_full.csv"),
    file.path("out", "features_full.csv")
  ))
)

TARGET_FEATURE_FILE <- get_config("TARGET_FEATURE_FILE", NULL)
OUTPUT_DIR <- get_config("OUTPUT_DIR", file.path("examples_out", "k_factor_workbench"))
QUERY_TEXT_ID <- get_config("QUERY_TEXT_ID", NULL)
MOVEMENT_TEXT_ID <- get_config("MOVEMENT_TEXT_ID", NULL)
MOVEMENT_TO <- get_config("MOVEMENT_TO", "axis")
MOVEMENT_TO_TEXT_ID <- get_config("MOVEMENT_TO_TEXT_ID", NULL)
NEAREST_N <- as.integer(get_config("NEAREST_N", 20))
TOP_FEATURES_N <- as.integer(get_config("TOP_FEATURES_N", 20))
PC_COUNT <- as.integer(get_config("PC_COUNT", 52))

if (!file.exists(BASELINE_FEATURE_FILE)) {
  stop("Baseline feature file not found. Set BASELINE_FEATURE_FILE or COREK_BASELINE_FEATURE_FILE.")
}
if (!file.exists(REFERENCE_FEATURE_FILE)) {
  stop("Reference feature file not found. Set REFERENCE_FEATURE_FILE or COREK_REFERENCE_FEATURE_FILE.")
}

dir.create(OUTPUT_DIR, recursive = TRUE, showWarnings = FALSE)

baseline <- k_read_features(BASELINE_FEATURE_FILE)
reference <- k_read_features(REFERENCE_FEATURE_FILE)
target <- if (!is.null(TARGET_FEATURE_FILE) && nzchar(TARGET_FEATURE_FILE) && file.exists(TARGET_FEATURE_FILE)) {
  k_read_features(TARGET_FEATURE_FILE)
} else {
  NULL
}

pca_space <- fit_pca_space(baseline, pc_count = PC_COUNT)
baseline_scores <- project_pca_space(baseline, pca_space)
reference_scores <- project_pca_space(reference, pca_space)
target_scores <- if (!is.null(target)) project_pca_space(target, pca_space) else NULL

axis <- fit_k_axis(reference_scores)
scored_baseline <- score_k_axis(baseline_scores, axis)
scored_reference <- score_k_axis(reference_scores, axis)
scored_target <- if (!is.null(target_scores)) score_k_axis(target_scores, axis) else NULL

all_scored <- rbind(
  scored_baseline,
  scored_reference,
  if (!is.null(scored_target)) scored_target else scored_reference[0, ]
)

axis_contrib <- k_feature_contributions(axis, pca_space, top_n = max(40, TOP_FEATURES_N))

nearest_reference_corpus <- k_nearest_texts(
  scored_baseline,
  n = NEAREST_N,
  pool = "all",
  order_by = "axis_distance"
)

query_nearest <- NULL
if (!is.null(QUERY_TEXT_ID) && nzchar(QUERY_TEXT_ID)) {
  query_nearest <- k_nearest_texts(
    all_scored,
    query_text_id = QUERY_TEXT_ID,
    n = NEAREST_N,
    pool = "all",
    order_by = "euclidean"
  )
}

movement <- NULL
if (!is.null(MOVEMENT_TEXT_ID) && nzchar(MOVEMENT_TEXT_ID)) {
  movement <- k_move_toward(
    all_scored,
    from_text_id = MOVEMENT_TEXT_ID,
    to = MOVEMENT_TO,
    axis = axis,
    pca_space = pca_space,
    to_text_id = if (!is.null(MOVEMENT_TO_TEXT_ID) && nzchar(MOVEMENT_TO_TEXT_ID)) MOVEMENT_TO_TEXT_ID else NULL,
    top_n = TOP_FEATURES_N
  )
}

utils::write.csv(scored_reference, file.path(OUTPUT_DIR, "reference_scored.csv"), row.names = FALSE)
utils::write.csv(scored_baseline, file.path(OUTPUT_DIR, "baseline_scored_against_axis.csv"), row.names = FALSE)
if (!is.null(scored_target)) {
  utils::write.csv(scored_target, file.path(OUTPUT_DIR, "target_scored_against_axis.csv"), row.names = FALSE)
}
utils::write.csv(all_scored, file.path(OUTPUT_DIR, "all_scored_against_axis.csv"), row.names = FALSE)
utils::write.csv(axis_contrib, file.path(OUTPUT_DIR, "axis_feature_contributions.csv"), row.names = FALSE)
utils::write.csv(nearest_reference_corpus, file.path(OUTPUT_DIR, "nearest_reference_corpus_to_axis.csv"), row.names = FALSE)

if (!is.null(query_nearest)) {
  utils::write.csv(query_nearest, file.path(OUTPUT_DIR, "query_nearest_texts.csv"), row.names = FALSE)
}
if (!is.null(movement)) {
  utils::write.csv(movement$summary, file.path(OUTPUT_DIR, "movement_summary.csv"), row.names = FALSE)
  utils::write.csv(movement$feature_moves, file.path(OUTPUT_DIR, "movement_top_feature_changes.csv"), row.names = FALSE)
}

if (requireNamespace("plotly", quietly = TRUE) && requireNamespace("htmlwidgets", quietly = TRUE)) {
  plot <- plot_k_axis_3d(all_scored, axis, label_n = min(60, nrow(all_scored)), axis_scale = 5)
  htmlwidgets::saveWidget(
    plot,
    file.path(OUTPUT_DIR, "person_axis_3d.html"),
    selfcontained = FALSE
  )
  context_plot <- plot_k_axis_context_3d(
    all_scored,
    axis,
    nearest = nearest_reference_corpus,
    top_n = NEAREST_N,
    label_reference = TRUE,
    label_nearest = TRUE,
    axis_scale = 5
  )
  htmlwidgets::saveWidget(
    context_plot,
    file.path(OUTPUT_DIR, "person_axis_context_3d.html"),
    selfcontained = FALSE
  )
}

k_write_report(
  all_scored,
  axis,
  axis_contrib,
  path = file.path(OUTPUT_DIR, "k_factor_workbench_report.md")
)

save_k_axis_bundle(
  list(
    created_at = Sys.time(),
    baseline_feature_file = BASELINE_FEATURE_FILE,
    reference_feature_file = REFERENCE_FEATURE_FILE,
    target_feature_file = TARGET_FEATURE_FILE,
    pca_space = pca_space,
    axis = axis
  ),
  file.path(OUTPUT_DIR, "person_axis_bundle.rds")
)

cat("\nK-Factor workbench complete.\n")
cat("Baseline:  ", BASELINE_FEATURE_FILE, "\n", sep = "")
cat("Reference: ", REFERENCE_FEATURE_FILE, "\n", sep = "")
cat("Targets:   ", if (!is.null(TARGET_FEATURE_FILE)) TARGET_FEATURE_FILE else "<none>", "\n", sep = "")
cat("Reference texts: ", axis$n_reference, "\n", sep = "")
cat("Output:    ", normalizePath(OUTPUT_DIR, winslash = "/", mustWork = TRUE), "\n\n", sep = "")

cat("Nearest texts from baseline/reference corpus to the person axis:\n")
print(nearest_reference_corpus[, intersect(
  c("text_id", "doc_class", "doc_genre", "k_factor", "k_axis_distance", "k_center_distance"),
  names(nearest_reference_corpus)
)][seq_len(min(NEAREST_N, nrow(nearest_reference_corpus))), ])

if (!is.null(query_nearest)) {
  cat("\nNearest texts to query: ", QUERY_TEXT_ID, "\n", sep = "")
  print(query_nearest[, intersect(
    c("text_id", "distance_to_query", "k_factor", "k_axis_distance", "k_center_distance"),
    names(query_nearest)
  )][seq_len(min(NEAREST_N, nrow(query_nearest))), ])
}

if (!is.null(movement)) {
  cat("\nMovement summary:\n")
  print(movement$summary)
  cat("\nTop feature changes:\n")
  print(movement$feature_moves)
}
