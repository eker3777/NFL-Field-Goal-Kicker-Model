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
             c("M2 (augmented)",     "M2 (augmented)"),
             c("M3 (IPW)",           "M3 (IPW-corrected)"))
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
# Counts are included in the search key: Section 2.1's split-balance table reuses the
# same band labels, and a bare label would match that row first.
bands <- c("| < 30 yds | 3,017 |", "| 30-39 yds | 3,314 |", "| 40-49 yds | 3,407 |",
           "| 50-59 yds | 1,733 |", "| 60+ yds | 77 |")
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
  chk(paste(tag, "M3 Brier"), v[2], ev(era, "M3 (IPW-corrected)", "brier"))
  chk(paste(tag, "M1 LL"),    v[3], ev(era, "M1 (full GLMM)", "logloss"))
  chk(paste(tag, "M3 LL"),    v[4], ev(era, "M3 (IPW-corrected)", "logloss"))
}

# The M3-pop A/B variant table (former Section 5.5) was cut from the manuscript as
# non-central; only the adopted zeroed-kicker construction is stated, in Section 4.1.
# m3pop_variant_by_distance_oos.csv is still produced by notebook 04, so this block can
# be restored verbatim if the comparison is ever put back into the paper.

cat("\n--- tbl-propensity-auc ---\n")
pm <- read_csv("reports/attempt_pi/attempt_pi_metrics_by_season.csv", show_col_types = FALSE)
for (s in pm$season) {
  l <- grep(paste0("| ", s, " | 0."), qmd, value = TRUE, fixed = TRUE)[1]
  v <- nums(l, "0\\.[0-9]{3}")
  chk(paste("prop", s, "AUC"),   v[1], pm$auc[pm$season == s],   5e-4)
  chk(paste("prop", s, "Brier"), v[2], pm$brier[pm$season == s], 5e-4)
}

cat("\n--- tbl-m2-grid ---\n")
g <- read_csv("reports/xfg_success/m2_weight_grid.csv", show_col_types = FALSE)
for (w in g$pat_weight) {
  l <- grep(paste0("| ", formatC(w, format = "f", digits = 2), " | 0."), qmd, value = TRUE, fixed = TRUE)[1]
  v <- nums(l, "0\\.[0-9]{3,4}")
  r <- g[g$pat_weight == w, ]
  chk(paste("m2grid", w, "Brier"), v[1], r$brier_is_fg)
  chk(paste("m2grid", w, "LL"),    v[2], r$logloss_is_fg)
  chk(paste("m2grid", w, "AUC"),   v[3], r$auc_is_fg, 5e-4)
  chk(paste("m2grid", w, "Calib"), v[4], r$calib_err_is_fg)
}

cat("\n--- tbl-split-balance ---\n")
sb <- read_csv("reports/figures/split_balance.csv", show_col_types = FALSE)
sm <- read_csv("reports/figures/split_balance_moments.csv", show_col_types = FALSE)
sp <- read_csv("reports/figures/split_balance_permutation.csv", show_col_types = FALSE)
sb_rows <- c("| < 30 yds | 2,", "| 30-39 yds | 2,", "| 40-49 yds | 2,",
             "| 50-59 yds | 1,", "| 60+ yds | ")
sb_keys <- c("<30", "30-39", "40-49", "50-59", "60+")
for (i in seq_along(sb_rows)) {
  l <- grep(sb_rows[i], qmd, value = TRUE, fixed = TRUE)[1]
  r <- sb[sb$band == sb_keys[i], ]
  # row reads: n_train | share_train% | n_test | share_test% | diff_pp
  # Shares are printed to 1 dp and diff_pp carries an explicit sign, so the
  # extractor must keep a leading '-' and the share tolerance must exceed 0.05.
  v <- as.numeric(str_extract_all(l, "-?[0-9]+\\.[0-9]+")[[1]])
  chk(paste("split", sb_keys[i], "train %"), v[1], 100 * r$share_train, 6e-2)
  chk(paste("split", sb_keys[i], "test %"),  v[2], 100 * r$share_test,  6e-2)
  chk(paste("split", sb_keys[i], "diff pp"), v[3], r$diff_pp,           5e-3)
}
gm <- function(s, c) sm[[c]][sm$split == s]
l <- grep("**Mean kick distance**", qmd, value = TRUE, fixed = TRUE)[1]
v <- nums(l)
chk("split mean dist train", v[1], gm("train", "dist_mean"), 5e-3)
chk("split mean dist test",  v[2], gm("test",  "dist_mean"), 5e-3)
l <- grep("**Mean $\\hat{\\pi}(X)$**", qmd, value = TRUE, fixed = TRUE)[1]
v <- nums(l)
chk("split mean pi train", v[1], gm("train", "phat_mean"), 5e-4)
chk("split mean pi test",  v[2], gm("test",  "phat_mean"), 5e-4)
l <- grep("**Mean IPW weight**", qmd, value = TRUE, fixed = TRUE)[1]
v <- nums(l)
chk("split mean weight train", v[1], gm("train", "weight_mean"), 5e-4)
chk("split mean weight test",  v[2], gm("test",  "weight_mean"), 5e-4)
l <- grep("observed total variation distance", qmd, value = TRUE, fixed = TRUE)[1]
v <- nums(l)
chk("split tvd observed", v[1], sp$tvd_observed, 5e-5)
chk("split tvd null med", v[2], sp$tvd_perm_med, 5e-5)
chk("split perm p",       v[3], sp$perm_p,       5e-3)

cat("\n--- leverage validation (Section 3.2) ---\n")
lv <- read_csv("reports/attempt_pi/leverage_validation.csv", show_col_types = FALSE)
lc <- read_csv("reports/attempt_pi/leverage_validation_calibration.csv", show_col_types = FALSE)
lg <- function(s, st, c) lv[[c]][lv$subset == s & lv$stage == st]
# Both leverage sentences sit in one Markdown paragraph, i.e. one line, so all ten
# numbers come off a single grep in document order.
l <- grep("Across 10,486 scored attempts", qmd, value = TRUE, fixed = TRUE)[1]
v <- nums(l)
chk("lev RMSE overall",  v[1], lg("overall", "post-rules", "rmse"), 5e-4)
chk("lev MAE overall",   v[2], lg("overall", "post-rules", "mae"),  5e-4)
chk("lev R2 overall",    v[3], lg("overall", "post-rules", "r2"),   5e-4)
chk("lev max calib gap", v[4], max(abs(lc$gap)), 5e-4)
rr <- function(s) 100 * (lg(s, "post-rules", "rmse") - lg(s, "pre-rules", "rmse")) / lg(s, "pre-rules", "rmse")
chk("lev rmse pct overall", -v[5], rr("overall"),      5e-2)
chk("lev rmse pct made",    -v[6], rr("made"),         5e-2)
chk("lev rmse pct missed",  -v[7], rr("missed"),       5e-2)
chk("lev rmse pct late",    -v[8], rr("late & close"), 5e-2)
chk("lev late rmse pre",  v[9],  lg("late & close", "pre-rules",  "rmse"), 5e-4)
chk("lev late rmse post", v[10], lg("late & close", "post-rules", "rmse"), 5e-4)

cat("\n--- M3-pop variant sentence (Section 6) ---\n")
mv <- read_csv("reports/xfg_success/m3pop_variant_by_distance_oos.csv", show_col_types = FALSE)
vg <- function(va, c) mv[[c]][mv$variant == va & mv$dist_band == "60+"]
l <- grep("in the 60+ yard band (mean predicted minus observed", qmd, value = TRUE, fixed = TRUE)[1]
v <- nums(l, "[0-9]+\\.[0-9]{3}")
chk("m3pop refit bias 60+",  v[1], vg("A_refit", "bias"),          5e-4)
chk("m3pop zeroed bias 60+", v[2], vg("B_kicker_zeroed", "bias"),  5e-4)
chk("m3pop refit brier 60+", v[3], vg("A_refit", "brier"),         5e-4)
chk("m3pop zeroed brier 60+", v[4], vg("B_kicker_zeroed", "brier"), 5e-4)

cat(sprintf("\n============ %d checks passed, %d MISMATCHED ============\n", ok, bad))
if (bad > 0) quit(status = 1)
