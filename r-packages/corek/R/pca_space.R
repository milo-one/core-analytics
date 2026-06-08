fit_pca_space <- function(features, pc_count = 52, exclude = k_analysis_columns()) {
  cleaned <- k_clean_numeric(features, exclude = exclude)
  pca <- stats::prcomp(cleaned$scaled, center = FALSE, scale. = FALSE)

  pc_count <- min(pc_count, ncol(pca$x))
  scores <- as.data.frame(pca$x[, seq_len(pc_count), drop = FALSE])
  names(scores) <- paste0("PC", seq_len(pc_count))

  if ("text_id" %in% names(features)) {
    scores$text_id <- features$text_id
  } else {
    scores$text_id <- paste0("row_", seq_len(nrow(features)))
  }

  eig <- pca$sdev^2
  variance <- data.frame(
    PC = paste0("PC", seq_along(eig)),
    variance_explained = eig / sum(eig),
    cumulative_variance = cumsum(eig / sum(eig)),
    stringsAsFactors = FALSE
  )

  list(
    pca = pca,
    scores = scores,
    variance = variance,
    pc_cols = paste0("PC", seq_len(pc_count)),
    feature_names = cleaned$feature_names,
    center = attr(cleaned$scaled, "scaled:center"),
    scale = attr(cleaned$scaled, "scaled:scale"),
    removed_zero_variance = cleaned$removed_zero_variance
  )
}

project_pca_space <- function(features, pca_space, fill_missing = 0) {
  if (!"text_id" %in% names(features)) {
    features$text_id <- paste0("row_", seq_len(nrow(features)))
  }

  missing <- setdiff(pca_space$feature_names, names(features))
  if (length(missing) > 0) {
    for (name in missing) {
      features[[name]] <- fill_missing
    }
    warning(
      "Missing feature columns were filled with ", fill_missing, ": ",
      paste(missing, collapse = ", "),
      call. = FALSE
    )
  }

  x <- features[, pca_space$feature_names, drop = FALSE]
  for (name in names(x)) {
    x[[name]] <- as.numeric(x[[name]])
    x[[name]][!is.finite(x[[name]])] <- fill_missing
    x[[name]][is.na(x[[name]])] <- fill_missing
  }

  scaled <- scale(as.matrix(x), center = pca_space$center, scale = pca_space$scale)
  pc_count <- length(pca_space$pc_cols)
  scores <- scaled %*% pca_space$pca$rotation[, seq_len(pc_count), drop = FALSE]
  scores <- as.data.frame(scores)
  names(scores) <- pca_space$pc_cols
  scores$text_id <- features$text_id

  meta_cols <- intersect(
    c("text_id", "doc_id", "doc_class", "doc_genre", "doc_source", "doc_author", "doc_year"),
    names(features)
  )
  meta <- features[, meta_cols, drop = FALSE]
  merge(meta, scores, by = "text_id", all.x = TRUE, sort = FALSE)
}
