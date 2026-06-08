plot_k_axis_3d <- function(scored, axis, label_n = 60, axis_scale = 4) {
  if (!requireNamespace("plotly", quietly = TRUE)) {
    stop("Package 'plotly' is required for plot_k_axis_3d().", call. = FALSE)
  }

  needed <- c("PC1", "PC2", "PC3")
  missing <- setdiff(needed, names(scored))
  if (length(missing) > 0) {
    stop("3D plotting requires PC1, PC2 and PC3 in scored data.", call. = FALSE)
  }

  idx <- match(needed, axis$pc_cols)
  if (any(is.na(idx))) {
    stop("Axis must include PC1, PC2 and PC3 for 3D plotting.", call. = FALSE)
  }

  center <- axis$center[idx]
  direction <- axis$direction[idx]
  direction <- direction / sqrt(sum(direction^2))
  axis_line <- data.frame(
    PC1 = center[1] + c(-axis_scale, axis_scale) * direction[1],
    PC2 = center[2] + c(-axis_scale, axis_scale) * direction[2],
    PC3 = center[3] + c(-axis_scale, axis_scale) * direction[3]
  )

  scored$k_hover <- paste0(
    "ID: ", if ("text_id" %in% names(scored)) scored$text_id else seq_len(nrow(scored)),
    "<br>K-Factor: ", round(scored$k_factor, 3),
    "<br>Axis distance: ", round(scored$k_axis_distance, 3),
    "<br>Projection: ", round(scored$k_projection, 3)
  )
  scored$k_color <- ifelse(scored$k_on_reference_axis, "reference", "scored")

  label_df <- scored[order(scored$k_axis_distance), , drop = FALSE]
  label_df <- label_df[seq_len(min(label_n, nrow(label_df))), , drop = FALSE]

  plotly::plot_ly() |>
    plotly::add_markers(
      data = scored,
      x = ~PC1,
      y = ~PC2,
      z = ~PC3,
      color = ~k_color,
      colors = c(reference = "#0b6f7f", scored = "#7f7f7f"),
      marker = list(size = 3, opacity = 0.62),
      text = ~k_hover,
      hoverinfo = "text",
      name = "Texts"
    ) |>
    plotly::add_trace(
      data = axis_line,
      x = ~PC1,
      y = ~PC2,
      z = ~PC3,
      type = "scatter3d",
      mode = "lines",
      line = list(color = "#0b6f7f", width = 8),
      name = "K-Factor axis"
    ) |>
    plotly::add_text(
      data = label_df,
      x = ~PC1,
      y = ~PC2,
      z = ~PC3,
      text = if ("text_id" %in% names(label_df)) ~text_id else NULL,
      textfont = list(size = 9),
      showlegend = FALSE,
      hoverinfo = "none"
    ) |>
    plotly::layout(
      title = "K-Factor axis in PCA feature space",
      scene = list(
        xaxis = list(title = "PC1"),
        yaxis = list(title = "PC2"),
        zaxis = list(title = "PC3")
      )
    )
}

plot_k_axis_context_3d <- function(
    scored,
    axis,
    nearest = NULL,
    top_n = 20,
    label_reference = TRUE,
    label_nearest = TRUE,
    axis_scale = 4,
    background_color = "#b8b8b8",
    reference_color = "#0b6f7f",
    nearest_color = "#d95f02",
    axis_color = "#063f49"
) {
  if (!requireNamespace("plotly", quietly = TRUE)) {
    stop("Package 'plotly' is required for plot_k_axis_context_3d().", call. = FALSE)
  }

  needed <- c("PC1", "PC2", "PC3")
  missing <- setdiff(needed, names(scored))
  if (length(missing) > 0) {
    stop("3D plotting requires PC1, PC2 and PC3 in scored data.", call. = FALSE)
  }
  if (!"text_id" %in% names(scored)) {
    scored$text_id <- paste0("row_", seq_len(nrow(scored)))
  }
  if (!"k_on_reference_axis" %in% names(scored)) {
    scored$k_on_reference_axis <- FALSE
  }

  idx <- match(needed, axis$pc_cols)
  if (any(is.na(idx))) {
    stop("Axis must include PC1, PC2 and PC3 for 3D plotting.", call. = FALSE)
  }

  center <- axis$center[idx]
  direction <- axis$direction[idx]
  direction <- direction / sqrt(sum(direction^2))
  axis_line <- data.frame(
    PC1 = center[1] + c(-axis_scale, axis_scale) * direction[1],
    PC2 = center[2] + c(-axis_scale, axis_scale) * direction[2],
    PC3 = center[3] + c(-axis_scale, axis_scale) * direction[3]
  )

  if (is.null(nearest)) {
    nearest <- k_nearest_texts(scored, n = top_n, order_by = "axis_distance")
  } else {
    nearest <- nearest[seq_len(min(top_n, nrow(nearest))), , drop = FALSE]
  }
  if (!"text_id" %in% names(nearest)) {
    nearest$text_id <- paste0("nearest_", seq_len(nrow(nearest)))
  }

  nearest_ids <- nearest$text_id
  background <- scored[!scored$text_id %in% c(axis$reference_ids, nearest_ids), , drop = FALSE]
  reference <- scored[scored$text_id %in% axis$reference_ids, , drop = FALSE]
  nearest_points <- scored[scored$text_id %in% nearest_ids, , drop = FALSE]

  make_hover <- function(data, prefix) {
    paste0(
      prefix, "<br>ID: ", data$text_id,
      if ("doc_class" %in% names(data)) paste0("<br>Class: ", data$doc_class) else "",
      if ("doc_genre" %in% names(data)) paste0("<br>Genre: ", data$doc_genre) else "",
      "<br>K-Factor: ", round(data$k_factor, 3),
      "<br>Axis distance: ", round(data$k_axis_distance, 3),
      "<br>Center distance: ", round(data$k_center_distance, 3)
    )
  }

  background$k_hover <- make_hover(background, "Corpus text")
  reference$k_hover <- make_hover(reference, "Person-axis reference")
  nearest_points$k_hover <- make_hover(nearest_points, "Nearest corpus match")

  p <- plotly::plot_ly()
  if (nrow(background) > 0) {
    p <- plotly::add_markers(
      p,
      data = background,
      x = ~PC1,
      y = ~PC2,
      z = ~PC3,
      marker = list(color = background_color, size = 3, opacity = 0.32),
      text = ~k_hover,
      hoverinfo = "text",
      name = "Corpus"
    )
  }
  if (nrow(reference) > 0) {
    p <- plotly::add_markers(
      p,
      data = reference,
      x = ~PC1,
      y = ~PC2,
      z = ~PC3,
      marker = list(color = reference_color, size = 6, opacity = 0.92),
      text = ~k_hover,
      hoverinfo = "text",
      name = "Person-axis texts"
    )
  }
  if (nrow(nearest_points) > 0) {
    p <- plotly::add_markers(
      p,
      data = nearest_points,
      x = ~PC1,
      y = ~PC2,
      z = ~PC3,
      marker = list(color = nearest_color, size = 5, opacity = 0.9, symbol = "diamond"),
      text = ~k_hover,
      hoverinfo = "text",
      name = paste0("Nearest top ", min(top_n, nrow(nearest_points)))
    )
  }

  p <- plotly::add_trace(
    p,
    data = axis_line,
    x = ~PC1,
    y = ~PC2,
    z = ~PC3,
    type = "scatter3d",
    mode = "lines",
    line = list(color = axis_color, width = 9),
    name = "Person axis"
  )

  if (label_reference && nrow(reference) > 0) {
    p <- plotly::add_text(
      p,
      data = reference,
      x = ~PC1,
      y = ~PC2,
      z = ~PC3,
      text = ~text_id,
      textfont = list(size = 9, color = reference_color),
      showlegend = FALSE,
      hoverinfo = "none"
    )
  }
  if (label_nearest && nrow(nearest_points) > 0) {
    p <- plotly::add_text(
      p,
      data = nearest_points,
      x = ~PC1,
      y = ~PC2,
      z = ~PC3,
      text = ~text_id,
      textfont = list(size = 8, color = nearest_color),
      showlegend = FALSE,
      hoverinfo = "none"
    )
  }

  plotly::layout(
    p,
    title = "Person axis with nearest corpus texts",
    scene = list(
      xaxis = list(title = "PC1"),
      yaxis = list(title = "PC2"),
      zaxis = list(title = "PC3")
    ),
    legend = list(orientation = "h")
  )
}
