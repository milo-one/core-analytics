fit_k_axis <- function(reference_scores, pc_cols = NULL, orient = c("auto", "none")) {
  orient <- match.arg(orient)

  if (is.null(pc_cols)) {
    pc_cols <- grep("^PC[0-9]+$", names(reference_scores), value = TRUE)
  }
  if (length(pc_cols) < 2) {
    stop("At least two PC columns are required to fit a K axis.", call. = FALSE)
  }
  if (nrow(reference_scores) < 3) {
    stop("At least three reference texts are required to fit a K axis.", call. = FALSE)
  }

  m <- as.matrix(reference_scores[, pc_cols, drop = FALSE])
  center <- colMeans(m, na.rm = TRUE)
  centered <- sweep(m, 2, center, "-")

  person_pca <- stats::prcomp(centered, center = FALSE, scale. = FALSE)
  direction <- person_pca$rotation[, 1]
  direction <- direction / sqrt(sum(direction^2))

  projection <- as.vector(centered %*% direction)
  if (orient == "auto") {
    strongest <- projection[which.max(abs(projection))]
    if (is.finite(strongest) && strongest < 0) {
      direction <- -direction
      projection <- -projection
    }
  }

  reference_distances <- sqrt(rowSums(centered^2))
  radius <- mean(reference_distances, na.rm = TRUE)
  if (!is.finite(radius) || radius == 0) {
    radius <- 1
  }

  reference_ids <- if ("text_id" %in% names(reference_scores)) {
    reference_scores$text_id
  } else {
    paste0("reference_", seq_len(nrow(reference_scores)))
  }

  list(
    center = center,
    direction = direction,
    radius = radius,
    pc_cols = pc_cols,
    reference_ids = reference_ids,
    n_reference = nrow(reference_scores),
    reference_projection_sd = stats::sd(projection, na.rm = TRUE),
    reference_distances = reference_distances,
    method = "reference_pca_first_axis"
  )
}

score_k_axis <- function(scores, axis) {
  missing <- setdiff(axis$pc_cols, names(scores))
  if (length(missing) > 0) {
    stop("Missing PC columns in scores: ", paste(missing, collapse = ", "), call. = FALSE)
  }

  m <- as.matrix(scores[, axis$pc_cols, drop = FALSE])
  shifted <- sweep(m, 2, axis$center, "-")
  projection <- as.vector(shifted %*% axis$direction)
  reconstructed <- sweep(matrix(projection, ncol = 1) %*% t(axis$direction), 2, axis$center, "+")
  orth_distance <- sqrt(rowSums((m - reconstructed)^2))
  center_distance <- sqrt(rowSums(shifted^2))

  out <- scores
  out$k_projection <- projection
  out$k_factor <- projection / axis$radius
  out$k_axis_distance <- orth_distance
  out$k_center_distance <- center_distance
  out$k_axis_similarity <- 1 / (1 + orth_distance)
  if ("text_id" %in% names(out)) {
    out$k_on_reference_axis <- out$text_id %in% axis$reference_ids
  } else {
    out$k_on_reference_axis <- FALSE
  }
  out
}

k_feature_contributions <- function(axis, pca_space, top_n = 40) {
  pc_index <- as.integer(sub("^PC", "", axis$pc_cols))
  rotation <- pca_space$pca$rotation[, pc_index, drop = FALSE]
  contribution <- as.vector(rotation %*% axis$direction)

  out <- data.frame(
    feature = rownames(rotation),
    contribution = contribution,
    abs_contribution = abs(contribution),
    direction = ifelse(contribution >= 0, "positive", "negative"),
    stringsAsFactors = FALSE
  )
  out <- out[order(out$abs_contribution, decreasing = TRUE), , drop = FALSE]
  out[seq_len(min(top_n, nrow(out))), , drop = FALSE]
}

k_nearest_to_axis <- function(scored, n = 20) {
  scored <- scored[order(scored$k_axis_distance, -abs(scored$k_projection)), , drop = FALSE]
  scored[seq_len(min(n, nrow(scored))), , drop = FALSE]
}

k_axis_movement <- function(scored, axis, pca_space = NULL, text_id = NULL, top_n = 12) {
  if (!is.null(text_id)) {
    scored <- scored[scored$text_id %in% text_id, , drop = FALSE]
  }
  if (nrow(scored) == 0) {
    stop("No scored rows selected.", call. = FALSE)
  }

  missing <- setdiff(axis$pc_cols, names(scored))
  if (length(missing) > 0) {
    stop("Missing PC columns in scored data: ", paste(missing, collapse = ", "), call. = FALSE)
  }

  m <- as.matrix(scored[, axis$pc_cols, drop = FALSE])
  shifted <- sweep(m, 2, axis$center, "-")
  projection <- as.vector(shifted %*% axis$direction)
  closest <- sweep(matrix(projection, ncol = 1) %*% t(axis$direction), 2, axis$center, "+")
  delta_pc <- closest - m
  movement_distance <- sqrt(rowSums(delta_pc^2))

  summary <- scored[, intersect(c("text_id", "doc_class", "doc_genre"), names(scored)), drop = FALSE]
  summary$k_factor <- scored$k_factor
  summary$k_axis_distance <- scored$k_axis_distance
  summary$k_center_distance <- scored$k_center_distance
  summary$movement_to_axis_distance <- movement_distance
  summary$nearest_axis_projection <- projection

  for (i in seq_along(axis$pc_cols)) {
    summary[[paste0("move_", axis$pc_cols[i])]] <- delta_pc[, i]
  }

  feature_moves <- NULL
  if (!is.null(pca_space)) {
    pc_index <- as.integer(sub("^PC", "", axis$pc_cols))
    rotation <- pca_space$pca$rotation[, pc_index, drop = FALSE]

    feature_moves <- do.call(rbind, lapply(seq_len(nrow(delta_pc)), function(i) {
      delta_feature <- as.vector(rotation %*% delta_pc[i, ])
      out <- data.frame(
        text_id = if ("text_id" %in% names(scored)) scored$text_id[i] else paste0("row_", i),
        feature = rownames(rotation),
        suggested_standardized_change = delta_feature,
        abs_change = abs(delta_feature),
        direction = ifelse(delta_feature >= 0, "increase", "decrease"),
        stringsAsFactors = FALSE
      )
      out <- out[order(out$abs_change, decreasing = TRUE), , drop = FALSE]
      out[seq_len(min(top_n, nrow(out))), , drop = FALSE]
    }))
    rownames(feature_moves) <- NULL
  }

  list(
    summary = summary,
    feature_moves = feature_moves
  )
}

k_nearest_texts <- function(
    scored,
    query_text_id = NULL,
    n = 20,
    pc_cols = NULL,
    pool = c("all", "reference", "non_reference"),
    exclude_query = TRUE,
    order_by = c("euclidean", "axis_distance", "center_distance")
) {
  pool <- match.arg(pool)
  order_by <- match.arg(order_by)

  out <- scored
  if (pool == "reference" && "k_on_reference_axis" %in% names(out)) {
    out <- out[out$k_on_reference_axis, , drop = FALSE]
  }
  if (pool == "non_reference" && "k_on_reference_axis" %in% names(out)) {
    out <- out[!out$k_on_reference_axis, , drop = FALSE]
  }

  if (is.null(pc_cols)) {
    pc_cols <- grep("^PC[0-9]+$", names(scored), value = TRUE)
  }

  if (is.null(query_text_id)) {
    if (order_by == "axis_distance" && "k_axis_distance" %in% names(out)) {
      out <- out[order(out$k_axis_distance, out$k_center_distance), , drop = FALSE]
    } else if (order_by == "center_distance" && "k_center_distance" %in% names(out)) {
      out <- out[order(out$k_center_distance, out$k_axis_distance), , drop = FALSE]
    } else {
      stop("query_text_id is required when order_by = 'euclidean'.", call. = FALSE)
    }
    return(out[seq_len(min(n, nrow(out))), , drop = FALSE])
  }

  if (!"text_id" %in% names(scored)) {
    stop("scored data must contain text_id for nearest-text search.", call. = FALSE)
  }
  query <- scored[scored$text_id == query_text_id, , drop = FALSE]
  if (nrow(query) != 1) {
    stop("query_text_id must select exactly one row. Found: ", nrow(query), call. = FALSE)
  }
  if (exclude_query && "text_id" %in% names(out)) {
    out <- out[out$text_id != query_text_id, , drop = FALSE]
  }

  q <- as.numeric(query[1, pc_cols, drop = TRUE])
  m <- as.matrix(out[, pc_cols, drop = FALSE])
  out$distance_to_query <- sqrt(rowSums((m - matrix(q, nrow(m), length(q), byrow = TRUE))^2))
  out <- out[order(out$distance_to_query, out$k_axis_distance), , drop = FALSE]
  out[seq_len(min(n, nrow(out))), , drop = FALSE]
}

k_move_toward <- function(
    scored,
    from_text_id,
    to = c("axis", "center", "text"),
    axis = NULL,
    pca_space = NULL,
    to_text_id = NULL,
    top_n = 20,
    pc_cols = NULL
) {
  to <- match.arg(to)
  if (!"text_id" %in% names(scored)) {
    stop("scored data must contain text_id.", call. = FALSE)
  }
  from_row <- scored[scored$text_id == from_text_id, , drop = FALSE]
  if (nrow(from_row) != 1) {
    stop("from_text_id must select exactly one row. Found: ", nrow(from_row), call. = FALSE)
  }

  if (is.null(pc_cols)) {
    pc_cols <- if (!is.null(axis)) axis$pc_cols else grep("^PC[0-9]+$", names(scored), value = TRUE)
  }

  from <- as.numeric(from_row[1, pc_cols, drop = TRUE])

  if (to == "axis") {
    if (is.null(axis)) stop("axis is required when to = 'axis'.", call. = FALSE)
    shifted <- from - axis$center
    projection <- as.numeric(shifted %*% axis$direction)
    target <- axis$center + projection * axis$direction
    target_label <- "nearest point on axis"
  } else if (to == "center") {
    if (is.null(axis)) stop("axis is required when to = 'center'.", call. = FALSE)
    target <- axis$center
    target_label <- "axis center"
  } else {
    if (is.null(to_text_id) || !nzchar(to_text_id)) {
      stop("to_text_id is required when to = 'text'.", call. = FALSE)
    }
    to_row <- scored[scored$text_id == to_text_id, , drop = FALSE]
    if (nrow(to_row) != 1) {
      stop("to_text_id must select exactly one row. Found: ", nrow(to_row), call. = FALSE)
    }
    target <- as.numeric(to_row[1, pc_cols, drop = TRUE])
    target_label <- to_text_id
  }

  delta_pc <- target - from
  summary <- data.frame(
    from_text_id = from_text_id,
    to = target_label,
    movement_distance = sqrt(sum(delta_pc^2)),
    stringsAsFactors = FALSE
  )
  for (i in seq_along(pc_cols)) {
    summary[[paste0("move_", pc_cols[i])]] <- delta_pc[i]
  }

  feature_moves <- NULL
  if (!is.null(pca_space)) {
    pc_index <- as.integer(sub("^PC", "", pc_cols))
    rotation <- pca_space$pca$rotation[, pc_index, drop = FALSE]
    delta_feature <- as.vector(rotation %*% delta_pc)
    feature_moves <- data.frame(
      from_text_id = from_text_id,
      to = target_label,
      feature = rownames(rotation),
      suggested_standardized_change = delta_feature,
      abs_change = abs(delta_feature),
      direction = ifelse(delta_feature >= 0, "increase", "decrease"),
      stringsAsFactors = FALSE
    )
    feature_moves <- feature_moves[order(feature_moves$abs_change, decreasing = TRUE), , drop = FALSE]
    feature_moves <- feature_moves[seq_len(min(top_n, nrow(feature_moves))), , drop = FALSE]
  }

  list(summary = summary, feature_moves = feature_moves)
}
