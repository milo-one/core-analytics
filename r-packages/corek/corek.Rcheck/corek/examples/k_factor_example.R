if (!requireNamespace("corek", quietly = TRUE)) {
  invisible(lapply(list.files("R", full.names = TRUE), source))
} else {
  library(corek)
}

set.seed(123)

make_features <- function(n, prefix, shift = 0) {
  data.frame(
    text_id = paste0(prefix, "_", seq_len(n)),
    feature_a = rnorm(n, mean = shift),
    feature_b = rnorm(n, mean = shift * 0.5),
    feature_c = rnorm(n),
    feature_d = rnorm(n),
    stringsAsFactors = FALSE
  )
}

baseline <- rbind(
  make_features(80, "baseline_human", shift = -0.2),
  make_features(80, "baseline_model", shift = 0.4)
)

reference <- make_features(20, "author_reference", shift = 0.8)
target <- rbind(
  make_features(5, "near_author", shift = 0.75),
  make_features(5, "far_author", shift = -0.6)
)

pca_space <- fit_pca_space(baseline, pc_count = 4)
reference_scores <- project_pca_space(reference, pca_space)
target_scores <- project_pca_space(target, pca_space)

axis <- fit_k_axis(reference_scores)
scored <- score_k_axis(target_scores, axis)
contrib <- k_feature_contributions(axis, pca_space)

print(scored[, c("text_id", "k_factor", "k_axis_distance", "k_axis_similarity")])
print(contrib)
