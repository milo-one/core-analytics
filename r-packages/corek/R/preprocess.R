#' Preprocess Text Features
#'
#' Cleans and prepares raw feature vectors for analysis.
#'
#' @param data Raw feature data frame.
#' @return Preprocessed data frame.
#' @export
k_analysis_columns <- function(n = 500) {
  c(
    paste0("PC", seq_len(n)),
    paste0("pc", seq_len(n)),
    paste0("LD", seq_len(n)),
    "cluster",
    "label",
    "label_5",
    "label_binary",
    "predicted_label"
  )
}

#' Clean Numeric Features
#'
#' Cleans, imputes, filters zero-variance and scales features.
#'
#' @param data Raw data frame.
#' @param exclude Columns to exclude.
#' @param id_cols Metadata ID columns to preserve.
#' @param center Logical, whether to center.
#' @param scale Logical, whether to scale.
#' @return A list containing cleaned, scaled data and metadata.
#' @export
k_clean_numeric <- function(
    data,
    exclude = k_analysis_columns(),
    id_cols = c("text_id", "doc_id", "doc_class", "doc_genre", "doc_source", "doc_author", "doc_year"),
    center = TRUE,
    scale = TRUE
) {
  keep <- !(names(data) %in% exclude)
  candidate <- data[, keep, drop = FALSE]
  numeric_cols <- vapply(candidate, is.numeric, logical(1))
  numeric <- candidate[, numeric_cols, drop = FALSE]

  if (ncol(numeric) == 0) {
    stop("No numeric feature columns available after exclusions.", call. = FALSE)
  }

  for (name in names(numeric)) {
    x <- as.numeric(numeric[[name]])
    x[!is.finite(x)] <- NA_real_
    x[is.na(x)] <- 0
    numeric[[name]] <- x
  }

  variance <- vapply(numeric, stats::var, numeric(1), na.rm = TRUE)
  non_constant <- is.finite(variance) & variance > 0
  numeric <- numeric[, non_constant, drop = FALSE]

  scaled <- base::scale(as.matrix(numeric), center = center, scale = scale)

  metadata_cols <- intersect(id_cols, names(data))
  metadata <- data[, metadata_cols, drop = FALSE]

  list(
    clean = numeric,
    scaled = scaled,
    metadata = metadata,
    feature_names = names(numeric),
    removed_zero_variance = names(non_constant)[!non_constant]
  )
}
