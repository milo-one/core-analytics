# Kafka author-axis example for corek.
#
# This example is written so it can be used from a future GitHub layout as well
# as from a local development folder. Override paths via environment variables
# when needed:
#
#   COREK_BASELINE_FEATURE_FILE="C:/path/to/baseline/features_full.csv"
#   COREK_REFERENCE_FEATURE_FILE="C:/path/to/kafka/features_full.csv"
#   COREK_EXAMPLE_OUT="C:/path/to/output"

if (dir.exists("R")) {
  invisible(lapply(list.files("R", full.names = TRUE), source))
} else {
  library(corek)
}

first_existing <- function(paths) {
  hit <- paths[file.exists(paths)]
  if (length(hit) == 0) NA_character_ else hit[1]
}

baseline_path <- Sys.getenv(
  "COREK_BASELINE_FEATURE_FILE",
  unset = first_existing(c(
    file.path("..", "..", "data", "features_full.csv"),
    "C:/Users/Kathrin Preuß/OneDrive/Dokumente/core-analytics/data/features_full.csv"
  ))
)

reference_path <- Sys.getenv(
  "COREK_REFERENCE_FEATURE_FILE",
  unset = first_existing(c(
    file.path("inst", "extdata", "kafka_features_full.csv"),
    file.path("out", "features_full.csv")
  ))
)

output_dir <- Sys.getenv("COREK_EXAMPLE_OUT", unset = file.path("examples_out", "kafka_axis"))
dir.create(output_dir, recursive = TRUE, showWarnings = FALSE)

if (!file.exists(baseline_path)) {
  stop("Baseline feature file not found. Set COREK_BASELINE_FEATURE_FILE.")
}
if (!file.exists(reference_path)) {
  stop("Kafka reference feature file not found. Set COREK_REFERENCE_FEATURE_FILE.")
}

baseline <- k_read_features(baseline_path)
kafka <- k_read_features(reference_path)

pca_space <- fit_pca_space(baseline, pc_count = 52)
kafka_scores <- project_pca_space(kafka, pca_space)
baseline_scores <- project_pca_space(baseline, pca_space)

axis <- fit_k_axis(kafka_scores)
scored_kafka <- score_k_axis(kafka_scores, axis)
scored_baseline <- score_k_axis(baseline_scores, axis)
combined_scores <- score_k_axis(rbind(baseline_scores, kafka_scores), axis)
contrib <- k_feature_contributions(axis, pca_space, top_n = 40)
movement_baseline <- k_axis_movement(scored_baseline, axis, pca_space = pca_space, top_n = 12)
movement_kafka <- k_axis_movement(scored_kafka, axis, pca_space = pca_space, top_n = 12)

utils::write.csv(scored_kafka, file.path(output_dir, "kafka_k_factor_scores.csv"), row.names = FALSE)
utils::write.csv(scored_baseline, file.path(output_dir, "baseline_scored_against_kafka_axis.csv"), row.names = FALSE)
utils::write.csv(combined_scores, file.path(output_dir, "combined_scored_against_kafka_axis.csv"), row.names = FALSE)
utils::write.csv(contrib, file.path(output_dir, "kafka_axis_feature_contributions.csv"), row.names = FALSE)
utils::write.csv(movement_baseline$summary, file.path(output_dir, "baseline_movement_to_kafka_axis.csv"), row.names = FALSE)
utils::write.csv(movement_baseline$feature_moves, file.path(output_dir, "baseline_feature_moves_to_kafka_axis.csv"), row.names = FALSE)
utils::write.csv(movement_kafka$summary, file.path(output_dir, "kafka_movement_to_own_axis.csv"), row.names = FALSE)

nearest_baseline <- scored_baseline[order(scored_baseline$k_axis_distance, scored_baseline$k_center_distance), ]
utils::write.csv(
  nearest_baseline[seq_len(min(25, nrow(nearest_baseline))), ],
  file.path(output_dir, "nearest_baseline_texts_to_kafka_axis.csv"),
  row.names = FALSE
)

if (requireNamespace("plotly", quietly = TRUE) && requireNamespace("htmlwidgets", quietly = TRUE)) {
  p <- plot_k_axis_3d(combined_scores, axis, label_n = 45, axis_scale = 5)
  htmlwidgets::saveWidget(
    p,
    file.path(output_dir, "kafka_axis_3d.html"),
    selfcontained = FALSE
  )
}

k_write_report(
  combined_scores,
  axis,
  contrib,
  path = file.path(output_dir, "kafka_k_factor_report.md")
)

bundle <- list(
  created_at = Sys.time(),
  baseline_feature_file = baseline_path,
  reference_feature_file = reference_path,
  pca_space = pca_space,
  axis = axis,
  scored_kafka = scored_kafka,
  scored_baseline = scored_baseline,
  combined_scores = combined_scores
)
save_k_axis_bundle(bundle, file.path(output_dir, "kafka_axis_bundle.rds"))

cat("\nKafka K-Factor example complete.\n")
cat("Baseline:  ", baseline_path, "\n", sep = "")
cat("Reference: ", reference_path, "\n", sep = "")
cat("Reference texts: ", axis$n_reference, "\n", sep = "")
cat("Output:    ", normalizePath(output_dir, winslash = "/", mustWork = TRUE), "\n\n", sep = "")

print(scored_kafka[, c("text_id", "k_factor", "k_axis_distance", "k_axis_similarity")])
print(utils::head(contrib, 10))

cat("\nNearest baseline texts to Kafka axis:\n")
print(utils::head(nearest_baseline[, c("text_id", "k_factor", "k_axis_distance", "k_center_distance")], 10))

cat("\nExample movement vectors toward Kafka axis:\n")
print(utils::head(movement_baseline$summary[, c("text_id", "k_axis_distance", "movement_to_axis_distance", "move_PC1", "move_PC2", "move_PC3")], 10))
