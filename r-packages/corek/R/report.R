k_write_report <- function(scored, axis, contributions = NULL, path = "k_factor_report.md", top_n = 12) {
  dir.create(dirname(path), recursive = TRUE, showWarnings = FALSE)

  ref <- scored
  if ("text_id" %in% names(scored)) {
    ref <- scored[scored$text_id %in% axis$reference_ids, , drop = FALSE]
  }

  summary_line <- function(label, value) {
    paste0("- ", label, ": ", value)
  }

  nearest <- k_nearest_to_axis(scored, n = top_n)
  high <- scored[order(scored$k_factor, decreasing = TRUE), , drop = FALSE]
  high <- high[seq_len(min(top_n, nrow(high))), , drop = FALSE]
  low <- scored[order(scored$k_factor), , drop = FALSE]
  low <- low[seq_len(min(top_n, nrow(low))), , drop = FALSE]

  table_text <- function(df) {
    keep <- intersect(
      c("text_id", "k_factor", "k_axis_distance", "k_projection", "k_axis_similarity"),
      names(df)
    )
    paste(utils::capture.output(print(df[, keep, drop = FALSE], row.names = FALSE)), collapse = "\n")
  }

  contribution_text <- ""
  if (!is.null(contributions)) {
    keep <- intersect(c("feature", "contribution", "direction"), names(contributions))
    contribution_text <- paste0(
      "\n## Strongest Feature Contributions\n\n```text\n",
      paste(utils::capture.output(print(contributions[, keep, drop = FALSE], row.names = FALSE)), collapse = "\n"),
      "\n```\n"
    )
  }

  text <- paste0(
    "# K-Factor Report\n\n",
    "The K-Factor is a personalized axis metric in PCA-transformed text-feature space. ",
    "It is not a classifier. Interpret `k_factor` together with `k_axis_distance`; ",
    "a high projection is only persuasive when the orthogonal distance to the axis is also low.\n\n",
    "## Axis\n\n",
    paste(
      summary_line("Reference texts", axis$n_reference),
      summary_line("PCs used", length(axis$pc_cols)),
      summary_line("Reference radius", round(axis$radius, 4)),
      summary_line("Method", axis$method),
      sep = "\n"
    ),
    "\n\n## Reference Scores\n\n",
    paste(
      summary_line("Mean K", round(mean(ref$k_factor, na.rm = TRUE), 4)),
      summary_line("SD K", round(stats::sd(ref$k_factor, na.rm = TRUE), 4)),
      summary_line("Mean axis distance", round(mean(ref$k_axis_distance, na.rm = TRUE), 4)),
      sep = "\n"
    ),
    "\n\n## Nearest To Axis\n\n```text\n", table_text(nearest), "\n```\n",
    "\n## Highest K-Factor\n\n```text\n", table_text(high), "\n```\n",
    "\n## Lowest K-Factor\n\n```text\n", table_text(low), "\n```\n",
    contribution_text
  )

  writeLines(text, path)
  invisible(path)
}
