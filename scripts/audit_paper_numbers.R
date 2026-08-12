suppressPackageStartupMessages({library(dplyr); library(readr); library(tidyr); library(stringr)})
qmd <- readLines("Paper/Field_Goal_Kicking_IPW/index.qmd", warn = FALSE)
ok <- 0; bad <- 0
chk <- function(label, paper, truth, tol = 5e-5) {
  good <- !is.na(paper) && !is.na(truth) && abs(paper - truth) < tol
  if (good) ok <<- ok + 1 else bad <<- bad + 1
  cat(sprintf("%-34s paper=%-8s artifact=%-8s %s\n", label,
      formatC(paper, format = "f", digits = 4),
      formatC(truth, format = "f", digits = 4),
      ifelse(good, "OK", "<<< MISMATCH")))
}
nums <- function(line, pat = "[0-9]+\\.[0-9]+") as.numeric(str_extract_all(line, pat)[[1]])

mt <- read_csv("reports/figures/metrics_table.csv", show_col_types = FALSE)
gv <- function(m, s, c) mt[[c]][mt$model == m & mt$split == s]

cat("--- tbl-model-metrics ---\n")
rows <- list(c("M0 (distance only)", "M0 (distance only)"),
             c("M1 (full GLMM)",     "M1 (full GLMM)"),
             c("M2 (IPW)",           "M2 (IPW-corrected)"),
             c("M3 (augmented)",     "M3 (augmented)"))
for (r in rows) {
  l <- grep(paste0("| ", r[1], " |"), qmd, value = TRUE, fixed = TRUE)[1]
  v <- nums(l)
  chk(paste(r[1], "IS Brier"),  v[1], gv(r[2], "in_sample", "brier"))
  chk(paste(r[1], "IS LL"),     v[2], gv(r[2], "in_sample", "logloss"))
  chk(paste(r[1], "IS AUC"),    v[3], gv(r[2], "in_sample", "auc"), 5e-4)
  chk(paste(r[1], "OOS Brier"), v[4], gv(r[2], "test", "brier"))
  chk(paste(r[1], "OOS LL"),    v[5], gv(r[2], "test", "logloss"))
  chk(paste(r[1], "OOS AUC"),   v[6], gv(r[2], "test", "auc"), 5e-4)
}

cat("\n--- tbl-dist-brier ---\n")
cb <- read_csv("reports/xfg_success/calibration_by_range_insample.csv", show_col_types = FALSE) %>%
  select(model, dist_band, brier) %>% pivot_wider(names_from = model, values_from = brier)
bands <- c("| < 30 yds |", "| 30-39 yds |", "| 40-49 yds |", "| 50-59 yds |", "| 60+ yds |")
keys  <- c("<30", "30-39", "40-49", "50-59", "60+")
for (i in seq_along(bands)) {
  l <- grep(bands[i], qmd, value = TRUE, fixed = TRUE)[1]
  v <- nums(l, "0\\.[0-9]{4}")
  r <- cb[cb$dist_band == keys[i], ]
  for (j in 1:4) chk(paste(keys[i], c("M0","M1","M2","M3")[j]), v[j], r[[c("M0","M1","M2","M3")[j]]])
}

cat("\n--- era table ---\n")
e  <- read_csv("reports/figures/metrics_by_era_oos.csv", show_col_types = FALSE)
ev <- function(er, mo, c) e[[c]][e$era2 == er & e$model == mo]
for (tag in c("Pre-2020", "Post-2020")) {
  era <- ifelse(tag == "Pre-2020", "pre-2020", "post-2020")
  l <- grep(paste0("| ", tag, " ("), qmd, value = TRUE, fixed = TRUE)[1]
  v <- nums(l, "0\\.[0-9]{4}")
  chk(paste(tag, "M1 Brier"), v[1], ev(era, "M1 (full GLMM)", "brier"))
  chk(paste(tag, "M2 Brier"), v[2], ev(era, "M2 (IPW-corrected)", "brier"))
  chk(paste(tag, "M1 LL"),    v[3], ev(era, "M1 (full GLMM)", "logloss"))
  chk(paste(tag, "M2 LL"),    v[4], ev(era, "M2 (IPW-corrected)", "logloss"))
}

# The M2-pop A/B variant table (former Section 5.5) was cut from the manuscript as
# non-central; only the adopted zeroed-kicker construction is stated, in Section 4.1.
# m2pop_variant_by_distance_oos.csv is still produced by notebook 04, so this block can
# be restored verbatim if the comparison is ever put back into the paper.

cat("\n--- tbl-propensity-auc ---\n")
pm <- read_csv("reports/attempt_pi/attempt_pi_metrics_by_season.csv", show_col_types = FALSE)
for (s in pm$season) {
  l <- grep(paste0("| ", s, " | 0."), qmd, value = TRUE, fixed = TRUE)[1]
  v <- nums(l, "0\\.[0-9]{3}")
  chk(paste("prop", s, "AUC"),   v[1], pm$auc[pm$season == s],   5e-4)
  chk(paste("prop", s, "Brier"), v[2], pm$brier[pm$season == s], 5e-4)
}

cat("\n--- tbl-m3-grid ---\n")
g <- read_csv("reports/xfg_success/m3_weight_grid.csv", show_col_types = FALSE)
for (w in g$pat_weight) {
  l <- grep(paste0("| ", formatC(w, format = "f", digits = 2), " | 0."), qmd, value = TRUE, fixed = TRUE)[1]
  v <- nums(l, "0\\.[0-9]{3,4}")
  r <- g[g$pat_weight == w, ]
  chk(paste("m3grid", w, "Brier"), v[1], r$brier_is_fg)
  chk(paste("m3grid", w, "LL"),    v[2], r$logloss_is_fg)
  chk(paste("m3grid", w, "AUC"),   v[3], r$auc_is_fg, 5e-4)
  chk(paste("m3grid", w, "Calib"), v[4], r$calib_err_is_fg)
}

cat(sprintf("\n============ %d checks passed, %d MISMATCHED ============\n", ok, bad))
if (bad > 0) quit(status = 1)
