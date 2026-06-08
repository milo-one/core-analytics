k_read_features <- function(path, text_id_col = "text_id") {
  if (!file.exists(path)) {
    stop("Feature file not found: ", path, call. = FALSE)
  }

  df <- utils::read.csv(path, stringsAsFactors = FALSE, check.names = FALSE)
  if (!text_id_col %in% names(df)) {
    df[[text_id_col]] <- paste0("row_", seq_len(nrow(df)))
  }
  if (text_id_col != "text_id") {
    df$text_id <- df[[text_id_col]]
  }
  df
}

save_k_axis_bundle <- function(bundle, path) {
  dir.create(dirname(path), recursive = TRUE, showWarnings = FALSE)
  saveRDS(bundle, path)
  invisible(path)
}

load_k_axis_bundle <- function(path) {
  if (!file.exists(path)) {
    stop("Bundle file not found: ", path, call. = FALSE)
  }
  readRDS(path)
}
