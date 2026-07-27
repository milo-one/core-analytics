\name{fit_k_axis}
\alias{fit_k_axis}
\alias{score_k_axis}
\alias{fit_pca_space}
\alias{project_pca_space}
\alias{k_clean_numeric}
\alias{k_feature_contributions}
\alias{k_axis_movement}
\alias{k_nearest_texts}
\alias{k_move_toward}
\alias{k_read_features}
\alias{k_write_report}
\alias{plot_k_axis_3d}
\alias{save_k_axis_bundle}
\alias{load_k_axis_bundle}
\alias{plot_k_axis_context_3d}
\title{K-Factor axis workflow functions}
\description{
Core functions for fitting a PCA feature space, projecting reference and target
features, fitting a personalized K-Factor axis, scoring texts, visualizing the
axis and writing reports.
}
\usage{
fit_pca_space(features, pc_count = 52, exclude = k_analysis_columns())
project_pca_space(features, pca_space, fill_missing = 0)
fit_k_axis(reference_scores, pc_cols = NULL, orient = c("auto", "none"))
score_k_axis(scores, axis)
k_feature_contributions(axis, pca_space, top_n = 40)
k_axis_movement(scored, axis, pca_space = NULL, text_id = NULL, top_n = 12)
k_nearest_texts(scored, query_text_id = NULL, n = 20, pc_cols = NULL,
  pool = c("all", "reference", "non_reference"),
  exclude_query = TRUE,
  order_by = c("euclidean", "axis_distance", "center_distance"))
k_move_toward(scored, from_text_id, to = c("axis", "center", "text"),
  axis = NULL, pca_space = NULL, to_text_id = NULL, top_n = 20,
  pc_cols = NULL)
k_clean_numeric(data, exclude = k_analysis_columns(), id_cols = c("text_id",
  "doc_id", "doc_class", "doc_genre", "doc_source", "doc_author", "doc_year"),
  center = TRUE, scale = TRUE)
k_read_features(path, text_id_col = "text_id")
k_write_report(scored, axis, contributions = NULL,
  path = "k_factor_report.md", top_n = 12)
plot_k_axis_3d(scored, axis, label_n = 60, axis_scale = 4)
plot_k_axis_context_3d(scored, axis, nearest = NULL, top_n = 20,
  label_reference = TRUE, label_nearest = TRUE, axis_scale = 4,
  background_color = "#b8b8b8", reference_color = "#0b6f7f",
  nearest_color = "#d95f02", axis_color = "#063f49")
save_k_axis_bundle(bundle, path)
load_k_axis_bundle(path)
}
\arguments{
\item{features, data}{A data frame containing text IDs and numeric feature columns.}
\item{pc_count}{Maximum number of principal components to retain.}
\item{exclude}{Column names to exclude before numeric feature extraction.}
\item{pca_space}{A PCA space returned by \code{fit_pca_space}.}
\item{fill_missing}{Value used for missing projection features.}
\item{reference_scores}{Projected PCA scores for reference texts.}
\item{pc_cols}{Principal component columns used for the axis.}
\item{orient}{Whether to orient the axis automatically or leave it unchanged.}
\item{scores, scored}{Projected PCA scores, optionally already scored.}
\item{axis}{A K-Factor axis returned by \code{fit_k_axis}.}
\item{top_n}{Number of rows or feature contributions to include.}
\item{text_id}{Optional text IDs for focused movement analysis.}
\item{query_text_id}{Optional text ID used as the nearest-neighbor query.}
\item{n}{Number of nearest texts to return.}
\item{pool}{Whether to search all, reference-axis or non-reference rows.}
\item{exclude_query}{Whether to remove the query text from the returned neighbors.}
\item{order_by}{Distance criterion used when no query text is supplied.}
\item{from_text_id}{Text ID whose movement direction should be estimated.}
\item{to}{Movement target: nearest point on the axis, axis center or another text.}
\item{to_text_id}{Target text ID when \code{to = "text"}.}
\item{id_cols}{Metadata columns kept during cleaning.}
\item{center, scale}{Passed to \code{scale}.}
\item{path}{File path for reading, writing or saving.}
\item{text_id_col}{Column used as text identifier.}
\item{contributions}{Optional feature-contribution table.}
\item{label_n}{Number of nearest-axis labels in the 3D plot.}
\item{axis_scale}{Visual length of the plotted K axis.}
\item{nearest}{Optional nearest-text table returned by \code{k_nearest_texts}.}
\item{label_reference, label_nearest}{Whether to label reference and nearest texts.}
\item{background_color, reference_color, nearest_color, axis_color}{Plot colors.}
\item{bundle}{List containing at least a PCA space and K axis.}
}
\value{
Data frames, lists or files depending on the function. The primary scoring
output contains \code{k_projection}, \code{k_factor}, \code{k_axis_distance},
\code{k_center_distance} and \code{k_axis_similarity}.
}
\examples{
set.seed(1)
baseline <- data.frame(text_id = paste0("b", 1:20), a = rnorm(20), b = rnorm(20))
reference <- data.frame(text_id = paste0("r", 1:5), a = rnorm(5, 1), b = rnorm(5))
pca_space <- fit_pca_space(baseline, pc_count = 2)
reference_scores <- project_pca_space(reference, pca_space)
axis <- fit_k_axis(reference_scores)
score_k_axis(reference_scores, axis)
}
