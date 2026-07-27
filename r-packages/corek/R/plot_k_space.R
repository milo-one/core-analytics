#' Interactive 3D K-Space Visualization
#'
#' Renders an interactive 3D scatter plot of PCA components, highlighting 
#' target projections onto a custom K-axis.
#'
#' @param baseline_scores Data frame containing baseline PCA scores (PC1, PC2, PC3, text_id).
#' @param target_scores Data frame containing reference/target scores to highlight.
#' @param k_axis Optional K-axis object from fit_k_axis() to plot the direction vector.
#' @param pc_x String, component for X axis. Default "PC1".
#' @param pc_y String, component for Y axis. Default "PC2".
#' @param pc_z String, component for Z axis. Default "PC3".
#'
#' @return A plotly 3D scene object.
#' @export
plot_k_space <- function(baseline_scores, 
                         target_scores, 
                         k_axis = NULL, 
                         pc_x = "PC1", 
                         pc_y = "PC2", 
                         pc_z = "PC3") {
  
  if (!requireNamespace("plotly", quietly = TRUE)) {
    stop("Package 'plotly' is required for plot_k_space(). Please install it via install.packages('plotly').")
  }
  
  # Tooltips für Baseline
  bg_data <- baseline_scores
  bg_data$hover_txt <- paste0(
    "<b>ID:</b> ", bg_data$text_id,
    "<br><b>", pc_x, ":</b> ", round(bg_data[[pc_x]], 2),
    "<br><b>", pc_y, ":</b> ", round(bg_data[[pc_y]], 2),
    "<br><b>", pc_z, ":</b> ", round(bg_data[[pc_z]], 2)
  )
  
  # Tooltips für Target
  tg_data <- target_scores
  k_fac_str <- if("k_factor" %in% names(tg_data)) paste0("<br><b>K-Factor:</b> ", round(tg_data$k_factor, 3)) else ""
  k_dist_str <- if("k_axis_distance" %in% names(tg_data)) paste0("<br><b>K-Distance:</b> ", round(tg_data$k_axis_distance, 3)) else ""
  
  tg_data$hover_txt <- paste0(
    "<b>TARGET:</b> ", tg_data$text_id,
    k_fac_str,
    k_dist_str,
    "<br><b>", pc_x, ":</b> ", round(tg_data[[pc_x]], 2),
    "<br><b>", pc_y, ":</b> ", round(tg_data[[pc_y]], 2),
    "<br><b>", pc_z, ":</b> ", round(tg_data[[pc_z]], 2)
  )
  
  # Plotly Szene mit explizitem Namespace `plotly::` aufbauen
  p <- plotly::plot_ly()
  p <- plotly::add_markers(
    p,
    data = bg_data,
    x = bg_data[[pc_x]], y = bg_data[[pc_y]], z = bg_data[[pc_z]],
    name = "Baseline Feld",
    marker = list(size = 2.5, color = "#b8b8b8", opacity = 0.25),
    hoverinfo = "text", text = ~hover_txt
  )
  p <- plotly::add_markers(
    p,
    data = tg_data,
    x = tg_data[[pc_x]], y = tg_data[[pc_y]], z = tg_data[[pc_z]],
    name = "Target Projektion",
    marker = list(size = 8, color = "#0b6f7f", symbol = "diamond", opacity = 0.95),
    hoverinfo = "text", text = ~hover_txt
  )
  
  # Vektor-Linie zeichnen, falls k_axis übergeben wurde
  if (!is.null(k_axis)) {
    mean_target_x <- mean(tg_data[[pc_x]], na.rm = TRUE)
    mean_target_y <- mean(tg_data[[pc_y]], na.rm = TRUE)
    mean_target_z <- mean(tg_data[[pc_z]], na.rm = TRUE)
    
    p <- plotly::add_paths(
      p,
      x = c(0, mean_target_x),
      y = c(0, mean_target_y),
      z = c(0, mean_target_z),
      name = "K-Achsen Vektor",
      line = list(color = "#063f49", width = 5, dash = "dash")
    )
  }
  
  p <- plotly::layout(
    p,
    title = list(text = "<b>corek</b> :: 3D Attractor & K-Space Projection", font = list(size = 16)),
    scene = list(
      xaxis = list(title = pc_x, gridcolor = "#e9ecef"),
      yaxis = list(title = pc_y, gridcolor = "#e9ecef"),
      zaxis = list(title = pc_z, gridcolor = "#e9ecef"),
      camera = list(eye = list(x = 1.6, y = 1.6, z = 1.2))
    ),
    legend = list(orientation = "h", x = 0.1, y = 0.9)
  )
  
  return(p)
}