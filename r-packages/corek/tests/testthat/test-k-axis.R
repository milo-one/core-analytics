test_that("K-Factor axis can be fitted and scored", {
  set.seed(123)
  baseline <- data.frame(
    text_id = paste0("base_", seq_len(40)),
    a = rnorm(40),
    b = rnorm(40),
    c = rnorm(40),
    d = rnorm(40),
    stringsAsFactors = FALSE
  )
  reference <- data.frame(
    text_id = paste0("ref_", seq_len(8)),
    a = rnorm(8, 1),
    b = rnorm(8, 0.5),
    c = rnorm(8),
    d = rnorm(8),
    stringsAsFactors = FALSE
  )
  target <- data.frame(
    text_id = paste0("target_", seq_len(5)),
    a = rnorm(5),
    b = rnorm(5),
    c = rnorm(5),
    d = rnorm(5),
    stringsAsFactors = FALSE
  )

  pca_space <- fit_pca_space(baseline, pc_count = 4)
  reference_scores <- project_pca_space(reference, pca_space)
  target_scores <- project_pca_space(target, pca_space)
  axis <- fit_k_axis(reference_scores)
  scored <- score_k_axis(target_scores, axis)

  expect_equal(axis$n_reference, 8)
  expect_true(all(c("k_factor", "k_axis_distance", "k_axis_similarity") %in% names(scored)))
  expect_true(all(is.finite(scored$k_factor)))
})

test_that("feature contributions return original features", {
  set.seed(456)
  baseline <- data.frame(
    text_id = paste0("base_", seq_len(30)),
    a = rnorm(30),
    b = rnorm(30),
    c = rnorm(30),
    stringsAsFactors = FALSE
  )
  pca_space <- fit_pca_space(baseline, pc_count = 3)
  ref_scores <- pca_space$scores[seq_len(10), ]
  axis <- fit_k_axis(ref_scores)
  contrib <- k_feature_contributions(axis, pca_space, top_n = 2)

  expect_equal(nrow(contrib), 2)
  expect_true(all(contrib$feature %in% c("a", "b", "c")))
})
