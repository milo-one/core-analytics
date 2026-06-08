setwd("C:/Users/Kathrin Preuß/OneDrive/Dokumente/New project/MASTER_KONZEPT_work/corek")
source("inst/examples/k_factor_example.R")

install.packages(
  "C:/Users/Kathrin Preuß/OneDrive/Dokumente/New project/MASTER_KONZEPT_work/corek",
  repos = NULL,
  type = "source"
)

library(corek)

set.seed(1)

baseline <- data.frame(
  text_id = paste0("b", 1:20),
  a = rnorm(20),
  b = rnorm(20),
  c = rnorm(20)
)

reference <- baseline[1:8, ]

pca_space <- fit_pca_space(baseline, pc_count = 3)
reference_scores <- project_pca_space(reference, pca_space)
axis <- fit_k_axis(reference_scores)
scored <- score_k_axis(reference_scores, axis)

head(scored[, c("text_id", "k_factor", "k_axis_distance")])

setwd("C:/Temp")
system("R CMD check corek --no-manual --no-build-vignettes")

setwd("C:/Temp")
Sys.setenv(HOME = "C:/Temp", R_USER = "C:/Temp")
system("R CMD build corek")
system("R CMD check corek_0.1.0.tar.gz --no-manual --no-build-vignettes")
