suppressPackageStartupMessages({library(dplyr); library(readr); library(tidyr); library(stringr)})
qmd <- readLines("Paper/Field_Goal_Kicking_IPW_v2/index.qmd", warn = FALSE)
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

# ---- integer-count checking -------------------------------------------------
# `nums()` matches [0-9]+\.[0-9]+, so it only ever sees decimals. Every
# discrepancy found in the 2026-08-20 audit (Paper/paper_numbers_audit.md) was
# an integer sample count, invisible to every check above. The helpers below
# close that gap.
known_bad <- 0

# Same column layout as chk(), integer formatting, exact comparison.
# `known` documents a mismatch we already understand; those are still counted
# as failures but do not, on their own, make the script exit non-zero.
chk_int <- function(label, paper, truth, known = NULL) {
  good <- !is.na(paper) && !is.na(truth) && paper == truth
  if (good) ok <<- ok + 1 else bad <<- bad + 1
  if (!good && !is.null(known)) known_bad <<- known_bad + 1
  fmt <- function(x) if (is.na(x)) "NA" else format(x, big.mark = ",", scientific = FALSE)
  cat(sprintf("%-34s paper=%-8s artifact=%-8s %s\n", label, fmt(paper), fmt(truth),
      if (good) "OK" else if (!is.null(known)) paste0("<<< MISMATCH (known: ", known, ")")
      else "<<< MISMATCH"))
}

# Integers in the manuscript appear both plain (`11,548`) and in LaTeX math
# (`11{,}548`). Strip both thousands separators before extracting, then drop
# decimals: without that step a table row like `| 2,453 | 26.4% | 564 |` yields
# 2453, 26, 4, 564 and the caller has to index around the fragments of a
# percentage. Removing decimals first makes position mean what it looks like.
ints <- function(s) {
  s <- gsub("\\{,\\}", "", s)
  s <- gsub("(?<=[0-9]),(?=[0-9])", "", s, perl = TRUE)
  s <- gsub("[0-9]+\\.[0-9]+", " ", s)
  as.numeric(str_extract_all(s, "[0-9]+")[[1]])
}

# Pull the n-th integer appearing AFTER a literal anchor. Anchoring rather than
# indexing into the line matters because the abstract is a single line holding
# a dozen unrelated numbers.
int_after <- function(anchor, lines = qmd, nth = 1, window = 120) {
  hit <- grep(anchor, lines, fixed = TRUE)
  if (!length(hit)) return(NA_real_)
  s <- lines[hit[1]]
  p <- regexpr(anchor, s, fixed = TRUE)
  after <- substr(s, p + attr(p, "match.length"), p + attr(p, "match.length") + window)
  v <- ints(after)
  if (length(v) < nth) NA_real_ else v[nth]
}

# Rows of a labelled table, found by walking back from its caption. Needed
# because tbl-split-balance and tbl-dist-brier reuse identical band labels.
tbl_block <- function(id, span = 14) {
  i <- grep(id, qmd, fixed = TRUE)
  if (!length(i)) return(character(0))
  qmd[max(1, i[1] - span):i[1]]
}

# Decimal counterpart to int_after(): the n-th decimal appearing AFTER a literal
# anchor. Section 4.4 quotes the full-field and in-range AUC ranges in a single
# sentence, so positional indexing into nums(line) would mean counting
# fragments by eye.
num_after <- function(anchor, lines = qmd, nth = 1, window = 160,
                      pat = "[0-9]+\\.[0-9]+") {
  hit <- grep(anchor, lines, fixed = TRUE)
  if (!length(hit)) return(NA_real_)
  s <- lines[hit[1]]
  p <- regexpr(anchor, s, fixed = TRUE)
  after <- substr(s, p + attr(p, "match.length"), p + attr(p, "match.length") + window)
  v <- as.numeric(str_extract_all(after, pat)[[1]])
  if (length(v) < nth) NA_real_ else v[nth]
}

mt <- read_csv("reports/figures/metrics_table.csv", show_col_types = FALSE)
gv <- function(m, s, c) mt[[c]][mt$model == m & mt$split == s]

cat("--- tbl-model-metrics ---\n")
# Section 6.2 compares M2 with and without the PAT block on both splits. These
# in-sample figures were unverifiable until notebook 03 started exporting
# full_m2_nopat_fg_only; checked here so they cannot drift again.
msum <- read_csv("reports/xfg_success/metrics_summary.csv", show_col_types = FALSE)
mg <- function(set, col) msum[[col]][msum$set == set]
l_np <- grep("the PAT-free version is marginally the better", qmd, value = TRUE, fixed = TRUE)[1]
v_np <- nums(l_np)
chk("6.2 nopat IS Brier",  v_np[1], mg("full_m2_nopat_fg_only", "brier"))
chk("6.2 M2    IS Brier",  v_np[2], mg("full_m2_fg_only",       "brier"))
chk("6.2 nopat IS LL",     v_np[3], mg("full_m2_nopat_fg_only", "logloss"))
chk("6.2 M2    IS LL",     v_np[4], mg("full_m2_fg_only",       "logloss"))
chk("6.2 nopat OOS Brier", v_np[5], mg("test_m2_nopat_fg_only", "brier"))
chk("6.2 M2    OOS Brier", v_np[6], mg("test_m2_fg_only",       "brier"))
chk("6.2 nopat OOS LL",    v_np[7], mg("test_m2_nopat_fg_only", "logloss"))
chk("6.2 M2    OOS LL",    v_np[8], mg("test_m2_fg_only",       "logloss"))

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
bands <- c("| < 30 yds | 2,709 |", "| 30-39 yds | 3,298 |", "| 40-49 yds | 3,412 |",
           "| 50-59 yds | 2,033 |", "| 60+ yds | 96 |")
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
lg <- function(s, st, c) lv[[c]][lv$subset == s & lv$stage == st]
l <- grep("scored attempts", qmd, value = TRUE, fixed = TRUE)[1]
v <- nums(l)
chk("lev RMSE overall", v[1], lg("overall", "post-rules", "rmse"), 5e-4)
chk("lev MAE overall",  v[2], lg("overall", "post-rules", "mae"),  5e-4)
chk("lev R2 overall",   v[3], lg("overall", "post-rules", "r2"),   5e-4)
rr <- function(s) 100 * (lg(s, "post-rules", "rmse") - lg(s, "pre-rules", "rmse")) / lg(s, "pre-rules", "rmse")
chk("lev rmse pct late",    -v[4], rr("late & close"), 5e-2)
chk("lev rmse pct overall", -v[5], rr("overall"),      5e-2)

# The M3-pop A/B variant sentence was cut from v2 along with the rest of the
# M3-pop comparison; notebook 04 still writes the artifact if it is restored.

cat("\n--- sample counts (integers quoted in prose and table stubs) ---\n")
S_MIN <- 2015L; S_MAX <- 2025L
fg_all <- read_csv("data/fg_all.csv", show_col_types = FALSE)
preds  <- read_csv("reports/xfg_success/fg_full_with_predictions.csv", show_col_types = FALSE)
poof   <- read_csv("reports/attempt_pi/attempt_pi_oof_predictions_final.csv", show_col_types = FALSE)
tids   <- read_csv("data/augmented/test_fg_game_ids_2015_2025.csv", show_col_types = FALSE)$game_id

# The propensity model's decision frame, reconstructed from notebook 02's filter.
# The propensity frame spans the FULL field: the coaching decision exists at
# every field position, so it is defined on yardline_100 rather than on a
# hypothetical kick distance truncated at kicking range.
t_prop_frame <- fg_all %>%
  filter(is_pat == 0L,
         play_type_original %in% c("field_goal", "pass", "run", "punt"),
         !is.na(yardline_100),
         !is.na(game_seconds_remaining),
         season >= S_MIN, season <= S_MAX) %>% nrow()
t_prop_fg    <- fg_all %>%
  filter(is_pat == 0L, play_type_original == "field_goal",
         !is.na(yardline_100), !is.na(game_seconds_remaining),
         season >= S_MIN, season <= S_MAX) %>% nrow()
# The M2 augmentation pool: non-attempts inside the outcome model's basis.
t_m2_pool    <- fg_all %>%
  filter(is_pat == 0L, attempted == 0L,
         !is.na(kick_distance), kick_distance <= 70,
         season >= S_MIN, season <= S_MAX) %>% nrow()
# The rows M2 actually trains on: the pool after the propensity floor and the
# distance floor. This turns on the propensity estimates, so it moves whenever
# the propensity model is re-specified - which is exactly why it is checked.
t_m2_used <- fg_all %>%
  filter(is_pat == 0L, attempted == 0L,
         !is.na(kick_distance), kick_distance <= 70, kick_distance > 33,
         season >= S_MIN, season <= S_MAX) %>%
  mutate(game_id = as.character(game_id), play_id = as.character(play_id)) %>%
  inner_join(poof %>%
               mutate(game_id = as.character(game_id), play_id = as.character(play_id)) %>%
               select(game_id, play_id, p_hat_attempt_clipped),
             by = c("game_id", "play_id")) %>%
  filter(p_hat_attempt_clipped >= 0.25) %>% nrow()
t_analysis   <- nrow(preds)
t_test       <- preds %>% filter(game_id %in% tids) %>% nrow()
t_train      <- t_analysis - t_test
t_test_games <- length(unique(tids))
t_non_win    <- fg_all %>% filter(is_pat == 0L, attempted == 0L,
                                  season >= S_MIN, season <= S_MAX) %>% nrow()
t_non_all    <- fg_all %>% filter(is_pat == 0L, attempted == 0L) %>% nrow()
t_pat_win    <- fg_all %>% filter(is_pat == 1L, season >= S_MIN, season <= S_MAX) %>% nrow()

# Self-check: our reconstruction of the frame must reproduce notebook 02's artifact,
# otherwise every propensity-count check below is measuring the wrong thing.
chk_int("propensity frame == OOF rows", t_prop_frame, nrow(poof))

cat("\n  abstract\n")
chk_int("abstract propensity n",
        int_after("rolling window of all fourth-down plays across the full field ($n = "),
        t_prop_frame)
chk_int("abstract analysis n",  int_after("actual FG attempts ($n = "),      t_analysis)
chk_int("abstract test n",      int_after("in-sample attempts; $n = "),      t_test)

cat("\n  section 2.1\n")
chk_int("2.1 in-sample training set",
        int_after("The in-sample training set comprised "), t_analysis)
chk_int("2.1 propensity frame",
        int_after("taken across the whole field: $n = "),                t_prop_frame)
chk_int("2.1 propensity frame FG count",
        int_after("comprising "),                                        t_prop_fg)
chk_int("4.1 M2 rows after both floors", int_after("it admits "),      t_m2_used)
chk_int("4.1 M2 candidate pool",         int_after("it admits ", nth = 2), t_m2_pool)
chk_int("6.2 M2 rows after both floors", int_after("It is. The "),       t_m2_used)
chk_int("2.1 M2 augmentation pool",
        int_after("outcome model's distance basis, $n = "),              t_m2_pool)
chk_int("2.1 PAT augmentation pool", int_after("An additional "),        t_pat_win)
chk_int("2.1 test games",
        int_after("stratified random sample of games ("),                t_test_games)
chk_int("2.1 test kicks",
        int_after("formed the held-out test set ($n = "),                t_test)
chk_int("2.1 training attempts",  int_after("training set ($n = "),      t_train)

cat("\n  section 5.1 and tbl-model-metrics caption\n")
chk_int("5.1 full-dataset n",
        int_after("over the full dataset ($n = "),                       t_analysis)
chk_int("caption IS n",  int_after("in-sample (IS, $n = "),              t_analysis)
chk_int("caption OOS n", int_after("held-out test set (OOS, $n = "),     t_test)

# Distance bands, half-open on the right: [0,30), [30,40), ..., [60, Inf). The
# printed labels therefore mean what they say -- "60+" is >= 60. This matches
# notebook 03's dist_breaks_is, notebook 05's band_of(), and the deck figures.
band_n  <- as.integer(table(cut(preds$kick_distance, c(0, 30, 40, 50, 60, 100),
                                right = FALSE, include.lowest = TRUE)))
labels  <- c("| < 30 yds |", "| 30-39 yds |", "| 40-49 yds |", "| 50-59 yds |", "| 60+ yds |")
keys    <- c("<30", "30-39", "40-49", "50-59", "60+")

cat("\n  tbl-dist-brier sample counts\n")
db <- tbl_block("{#tbl-dist-brier}")
for (i in seq_along(labels)) {
  chk_int(paste("dist-brier", keys[i], "N"), int_after(labels[i], lines = db), band_n[i])
}

cat("\n  tbl-split-balance sample counts\n")
sbb <- tbl_block("{#tbl-split-balance}")
sb_n <- read_csv("reports/figures/split_balance.csv", show_col_types = FALSE)
for (i in seq_along(labels)) {
  r <- sb_n[sb_n$band == c("<30", "30-39", "40-49", "50-59", "60+")[i], ]
  chk_int(paste("split", keys[i], "n train"),
          int_after(labels[i], lines = sbb, nth = 1), r$n_train)
  chk_int(paste("split", keys[i], "n test"),
          int_after(labels[i], lines = sbb, nth = 2), r$n_test)
}

cat("\n--- IPW weight range (Sections 4.5 and 7.1) ---\n")
# This block exists because the 2026-08-24 review found the manuscript quoting a
# maximum weight of 8.33 against an artifact maximum of 8.49, and 156 checks
# passed anyway: nothing here had ever looked at the weight column itself. The
# weight range is a headline property of the correction; it now cannot drift.
w_fg <- poof$w_ipw_final[poof$attempt_fg == 1L]
w_fg <- w_fg[is.finite(w_fg)]

chk_int("4.5 scored attempts",
        int_after("bounded upper tail. Across the "), length(w_fg))
chk("4.5 weight min",    num_after("the resulting weight ranges from", nth = 1), min(w_fg),    5e-3)
chk("4.5 weight max",    num_after("the resulting weight ranges from", nth = 2), max(w_fg),    5e-3)
chk("4.5 weight median", num_after("with a median of"),                          median(w_fg), 5e-3)
chk("7.1 capped max weight",
    num_after("reduces the largest single case weight from 1,633 to"), max(w_fg), 5e-3)

cat("\n--- propensity AUC ranges (Section 4.4) ---\n")
# Both ranges sit in one sentence. The in-range pair is the one the selection
# argument rests on; the full-field pair is quoted only to be set aside, and is
# checked so it cannot quietly become the headline.
chk("4.4 full-field AUC min", num_after("full-field AUC accordingly sits between", nth = 1),
    min(pm$auc), 5e-4)
chk("4.4 full-field AUC max", num_after("full-field AUC accordingly sits between", nth = 2),
    max(pm$auc), 5e-4)
chk("4.4 in-range AUC min", num_after("In-range AUC ranges from", nth = 1),
    min(pm$auc_in_range), 5e-4)
chk("4.4 in-range AUC max", num_after("In-range AUC ranges from", nth = 2),
    max(pm$auc_in_range), 5e-4)

cat("\n--- tail Brier reductions (abstract, 6.3, 8, conclusion) ---\n")
# Recomputed from the band table rather than compared as literals, so a
# percentage and the table it summarises cannot disagree. They did: the deck
# printed M3 band values that were stale relative to its own footnote.
cbw <- read_csv("reports/xfg_success/calibration_by_range_insample.csv",
                show_col_types = FALSE) %>%
  select(model, dist_band, brier) %>%
  pivot_wider(names_from = model, values_from = brier)
tail_pct <- function(band) {
  r <- cbw[cbw$dist_band == band, ]
  100 * (r$M1 - r$M3) / r$M1
}
# Percentages are printed to one decimal, so half a printed digit is 0.05; the
# tolerance has to clear that plus a little slack or a legitimate rounding
# fails the gate.
PCT_TOL <- 6e-2
t_50 <- tail_pct("50-59"); t_60 <- tail_pct("60+")

# Four sites quote the same two percentages. Each is anchored on its own
# sentence, so a partial edit is caught rather than averaged away.
chk("abstract 60+ reduction",
    num_after("calibration gains concentrated at long distances: a"), t_60, PCT_TOL)
chk("abstract 50-59 reduction",
    num_after("Brier reduction at 60+ yards and a"),                  t_50, 5e-2)
chk("6.3 50-59 reduction",
    num_after("M3 achieves a"),                                       t_50, 5e-2)
chk("6.3 60+ reduction",
    num_after("Brier reduction versus M1 at 50-59 yards and a"),      t_60, 5e-2)
chk("8 60+ reduction",
    num_after("in the held-out test set. The"),                       t_60, 5e-2)
chk("conclusion 60+ reduction",
    num_after("better-calibrated predictions at long distance, achieving a"), t_60, PCT_TOL)

cat("\n--- tail band sample counts ---\n")
# n = 77 was quoted in four places and became a different number when the bands
# were re-cut half-open on 2026-08-24. Anchored per site so a missed one shows.
n_tail_is  <- sum(preds$kick_distance >= 60, na.rm = TRUE)
n_tail_oos <- preds %>% filter(game_id %in% tids, kick_distance >= 60) %>% nrow()
chk_int("5.2 60+ in-sample n",
        int_after("The 60+ yard band contains $n = "),                        n_tail_is)
chk_int("6.3 60+ in-sample n",
        int_after("the 60+ yard distance band contains only $n = "),          n_tail_is)
chk_int("8 60+ in-sample n",
        int_after("The 60+ yard distance band contains only $n = "),          n_tail_is)
chk_int("8 60+ held-out n",
        int_after("in-sample observations, and only $n = "),                  n_tail_oos)

cat("\n--- tbl-m2-threshold and the 4.1 distance-floor evidence ---\n")
# Both sections quote the pool experiments of notebooks/03_models.ipynb. Every
# number is checked, because these are the two places where the manuscript now
# makes a measured claim in place of an assumption.
ex <- read_csv("reports/xfg_success/m2_pool_experiments.csv", show_col_types = FALSE)
eb <- read_csv("reports/xfg_success/m2_pool_experiments_by_band.csv", show_col_types = FALSE)
exg <- function(cfg, col) ex[[col]][ex$config == cfg]
ebb <- function(cfg, band) eb$bias_vs_m1[eb$config == cfg & eb$dist_band == band]
ebn <- function(band) eb$n[eb$config == "M1 (no augmentation)" & eb$dist_band == band]

# Rows are found by pseudo-miss pool size, which is unique per row and, unlike
# the LaTeX threshold label, contains no digits that nums() would pick up.
sw <- list(c("| 1,087 |", "E1 pi>=0.50"), c("| 1,543 |", "E1 pi>=0.35"),
           c("| 1,923 | 0.1013", "M2 primary (pi>=0.25)"),
           c("| 2,470 |", "E1 pi>=0.15"), c("| 2,903 |", "E1 pi>=0.10"))
for (r in sw) {
  l <- grep(r[1], qmd, value = TRUE, fixed = TRUE)[1]
  v <- nums(l, "0\\.[0-9]{4}")
  chk_int(paste("m2thr", r[2], "pool"),      ints(l)[1], exg(r[2], "n_non"))
  chk(paste("m2thr", r[2], "OOS Brier"), v[1], exg(r[2], "brier_oos"))
  chk(paste("m2thr", r[2], "OOS LL"),    v[2], exg(r[2], "logloss_oos"))
}
# The M1 row is handled apart: ints() sees the "1" in the label "M1".
l <- grep("| M1 (no augmentation) | 0 |", qmd, value = TRUE, fixed = TRUE)[1]
v <- nums(l, "0\\.[0-9]{4}")
chk("m2thr M1 OOS Brier", v[1], exg("M1 (no augmentation)", "brier_oos"))
chk("m2thr M1 OOS LL",    v[2], exg("M1 (no augmentation)", "logloss_oos"))

# 6.2 prose: the make rates that motivate the sweep, and the band-level bias at
# the loosest floor that explains why it fails.
# Observed make rate over the full in-sample set, which is what the manuscript
# quotes. eb$obs is the training-split rate and is a different number.
cbo <- read_csv("reports/xfg_success/calibration_by_range_insample.csv",
                show_col_types = FALSE)
obs_rate <- function(band) 100 * cbo$obs_make_pct[cbo$model == "M1" & cbo$dist_band == band]
chk("6.2 30-39 make rate", num_after("a 30-39 yard attempt is made"), obs_rate("30-39"), PCT_TOL)
chk("6.2 60+ make rate",   num_after("and a 60+ yard attempt only"),  obs_rate("60+"),   PCT_TOL)
chk("6.2 loose-floor 50-59 bias pp", num_after("the fitted curve sits", nth = 1),
    -100 * ebb("E1 pi>=0.10", "50-59"), PCT_TOL)
chk("6.2 loose-floor 60+ bias pp",   num_after("the fitted curve sits", nth = 2),
    -100 * ebb("E1 pi>=0.10", "60+"),   PCT_TOL)
chk_int("6.2 50-59 training n",
        int_after("and 4.7 below it at 60+, against ", nth = 1), ebn("50-59"))
chk_int("6.2 60+ training n",
        int_after("and 4.7 below it at 60+, against ", nth = 2), ebn("60+"))

# 4.1 prose: the E2 configuration that measures what the 33-yard floor excludes.
chk("4.1 E2 OOS Brier",   num_after("held-out Brier", nth = 1),
    exg("E2 no PAT, no distance floor", "brier_oos"))
chk("4.1 nopat OOS Brier", num_after("held-out Brier", nth = 2),
    exg("ref: no PAT, dist>33 (existing m2_nopat)", "brier_oos"))
chk("4.1 E2 sub-30 bias pp", num_after("held-out Brier", nth = 3),
    -100 * ebb("E2 no PAT, no distance floor", "<30"), PCT_TOL)
chk("4.1 sub-30 make rate",  num_after("attempts converted at"), obs_rate("<30"), PCT_TOL)
chk_int("4.1 sub-30 band n", int_after("That band holds "),
        as.integer(table(cut(preds$kick_distance, c(0, 30, 40, 50, 60, 100),
                             right = FALSE, include.lowest = TRUE))[1]))

# =============================================================================
# The conference deck, checked against the same artifacts as the manuscript
# =============================================================================
# Deck plan v2, 7.1.5. Every figure the deck prints is checked against the
# pipeline artifact rather than against the paper, because checking the deck
# against the paper would let the two drift together. Before the 2026-08-24
# rewrite the deck carried three stale M3 band values that reconciled with
# neither the paper nor the artifact, while its own footnote reconciled with
# the artifact -- so the slide disagreed with itself and nothing caught it.
cat("\n\n########## Presentation/heres_the_kicker_slides.qmd ##########\n")
deck <- readLines("Presentation/heres_the_kicker_slides.qmd", warn = FALSE)
drow <- function(key) grep(key, deck, value = TRUE, fixed = TRUE)[1]
# Drop a table row's first cell. Band labels are made of digits, and they
# contribute a different number of them per band ("30-39" two, "< 30" one),
# so positional indexing past the label is not stable across rows.
cell_rest <- function(l) sub("^[|][^|]*[|]", "", l)

cat("\n--- deck: headline metrics table (slide 11) ---\n")
# Column order here is IS Brier, OOS Brier, IS Log-Loss, OOS Log-Loss, which is
# NOT the manuscript's order: the slide leads with the two Brier columns because
# the reversal between them is the point of the slide.
deck_models <- list(c("[M0]{.model-m0} distance only", "M0 (distance only)", "M0 distance only"),
                    c("[M1]{.model-m1} full GLMM",     "M1 (full GLMM)",     "M1 full GLMM"),
                    c("[M2]{.model-m2} augmented",     "M2 (augmented)",     "M2 augmented"),
                    c("[M3]{.model-m3} IPW",           "M3 (IPW-corrected)", "M3 IPW"))
for (r in deck_models) {
  # Pinned to the table row with a leading pipe: the bare key also matches
  # the slide 9 column heading, which is the same text and has no numbers.
  v <- nums(drow(paste0("| ", r[1], " |")), "0\\.[0-9]{4}")
  chk(paste("deck s11", r[2], "IS Brier"),  v[1], gv(r[2], "in_sample", "brier"))
  chk(paste("deck s11", r[2], "OOS Brier"), v[2], gv(r[2], "test", "brier"))
  chk(paste("deck s11", r[2], "IS LL"),     v[3], gv(r[2], "in_sample", "logloss"))
  chk(paste("deck s11", r[2], "OOS LL"),    v[4], gv(r[2], "test", "logloss"))
}

cat("\n--- deck: full results table (appendix A3) ---\n")
for (r in deck_models) {
  v <- nums(drow(paste0("| ", r[3], " |")), "0\\.[0-9]{3,4}")
  chk(paste("deck A3", r[2], "IS Brier"),  v[1], gv(r[2], "in_sample", "brier"))
  chk(paste("deck A3", r[2], "IS LL"),     v[2], gv(r[2], "in_sample", "logloss"))
  chk(paste("deck A3", r[2], "IS AUC"),    v[3], gv(r[2], "in_sample", "auc"), 5e-4)
  chk(paste("deck A3", r[2], "OOS Brier"), v[4], gv(r[2], "test", "brier"))
  chk(paste("deck A3", r[2], "OOS LL"),    v[5], gv(r[2], "test", "logloss"))
  chk(paste("deck A3", r[2], "OOS AUC"),   v[6], gv(r[2], "test", "auc"), 5e-4)
}

cat("\n--- deck: distance-band table (appendix A4) ---\n")
deck_bands <- c("| < 30 | 2,709 |", "| 30-39 | 3,298 |", "| 40-49 | 3,412 |",
                "| 50-59 | 2,033 |", "| 60+ | 96 |")
for (i in seq_along(deck_bands)) {
  l <- drow(deck_bands[i])
  v <- nums(l, "0\\.[0-9]{4}")
  r <- cb[cb$dist_band == keys[i], ]
  # The band label is itself made of integers, and "30-39" contributes two
  # of them while "< 30" contributes one. Strip the label cell rather than
  # counting past it.
  chk_int(paste("deck A4", keys[i], "n"), ints(cell_rest(l))[1], band_n[i])
  for (j in 1:4) chk(paste("deck A4", keys[i], c("M0","M1","M2","M3")[j]),
                     v[j], r[[c("M0","M1","M2","M3")[j]]])
}
chk("deck A4 50-59 reduction", num_after("M3 gains", lines = deck),          t_50, PCT_TOL)
chk("deck A4 60+ reduction",   num_after("at 50-59 and", lines = deck),      t_60, PCT_TOL)

cat("\n--- deck: split balance (appendix A1) ---\n")
deck_sb <- c("| < 30 | 2,214 |", "| 30-39 | 2,654 |", "| 40-49 | 2,716 |",
             "| 50-59 | 1,636 |", "| 60+ | 77 |")
for (i in seq_along(deck_sb)) {
  l <- drow(deck_sb[i])
  r <- sb[sb$band == sb_keys[i], ]
  ii <- ints(cell_rest(l))
  chk_int(paste("deck A1", sb_keys[i], "n train"), ii[1], r$n_train)
  chk_int(paste("deck A1", sb_keys[i], "n test"),  ii[2], r$n_test)
  v <- as.numeric(str_extract_all(l, "-?[0-9]+\\.[0-9]+")[[1]])
  chk(paste("deck A1", sb_keys[i], "train %"), v[1], 100 * r$share_train, 6e-2)
  chk(paste("deck A1", sb_keys[i], "test %"),  v[2], 100 * r$share_test,  6e-2)
  chk(paste("deck A1", sb_keys[i], "diff pp"), v[3], r$diff_pp,           5e-3)
}
v <- nums(drow("Observed total variation distance"))
chk("deck A1 tvd observed", v[1], sp$tvd_observed, 5e-5)
chk("deck A1 tvd null med", v[2], sp$tvd_perm_med, 5e-5)
chk("deck A1 perm p",       v[3], sp$perm_p,       5e-3)

cat("\n--- deck: era stability (appendix A2) ---\n")
for (tag in c("Pre-2020", "Post-2020")) {
  era <- ifelse(tag == "Pre-2020", "pre-2020", "post-2020")
  v <- nums(drow(paste0("| ", tag, " (n =")), "0\\.[0-9]{4}")
  chk(paste("deck A2", tag, "M1 Brier"), v[1], ev(era, "M1 (full GLMM)", "brier"))
  chk(paste("deck A2", tag, "M3 Brier"), v[2], ev(era, "M3 (IPW-corrected)", "brier"))
  chk(paste("deck A2", tag, "M1 LL"),    v[3], ev(era, "M1 (full GLMM)", "logloss"))
  chk(paste("deck A2", tag, "M3 LL"),    v[4], ev(era, "M3 (IPW-corrected)", "logloss"))
}

cat("\n--- deck: M2 grids (slide 13 and appendix A7) ---\n")
for (w in g$pat_weight) {
  l <- drow(paste0("| ", formatC(w, format = "f", digits = 2), " | 0."))
  chk(paste("deck s13 m2grid", w, "IS Brier"), nums(l, "0\\.[0-9]{4}")[1],
      g$brier_is_fg[g$pat_weight == w])
}
deck_thr <- list(c("| 0.50 | 1,087 |",          "E1 pi>=0.50"),
                 c("| 0.35 | 1,543 |",          "E1 pi>=0.35"),
                 c("| 0.25 (primary) | 1,923 |", "M2 primary (pi>=0.25)"),
                 c("| 0.15 | 2,470 |",          "E1 pi>=0.15"),
                 c("| 0.10 | 2,903 |",          "E1 pi>=0.10"))
for (r in deck_thr) {
  l <- drow(r[1])
  chk_int(paste("deck A7", r[2], "pool"), ints(l)[1], exg(r[2], "n_non"))
  chk(paste("deck A7", r[2], "OOS Brier"), nums(l, "0\\.[0-9]{4}")[1],
      exg(r[2], "brier_oos"))
}
chk("deck A7 M1 OOS Brier",
    nums(drow("| M1, no augmentation | 0 |"), "0\\.[0-9]{4}")[1],
    exg("M1 (no augmentation)", "brier_oos"))

cat("\n--- deck: prose figures ---\n")
chk("deck s7 in-range AUC min", num_after("**AUC", lines = deck, nth = 1),
    min(pm$auc_in_range), 5e-4)
chk("deck s7 in-range AUC max", num_after("**AUC", lines = deck, nth = 2),
    max(pm$auc_in_range), 5e-4)
chk("deck s7 leverage RMSE", num_after("**RMSE", lines = deck),
    lg("overall", "post-rules", "rmse"), 5e-4)
chk("deck s8 weight min", num_after("Final weights span", lines = deck, nth = 1),
    min(w_fg), 5e-3)
chk("deck s8 weight max", num_after("Final weights span", lines = deck, nth = 2),
    max(w_fg), 5e-3)
chk_int("deck s9 M2 admitted",
        int_after("Distance beyond 33 yards. ", lines = deck, nth = 1), t_m2_used)
chk_int("deck s9 M2 pool",
        int_after("Distance beyond 33 yards. ", lines = deck, nth = 2), t_m2_pool)

# Slide 5's headline counterfactual, rounded to whole kicks on the slide.
cf <- read_csv("reports/figures/era_counterfactual.csv", show_col_types = FALSE)
cfg_ <- function(sub, col) cf[[col]][cf$subset == sub]
chk_int("deck s5 excess makes",      ints(drow("additional makes"))[1],
        round(cfg_("all distances", "excess_makes")))
chk_int("deck s5 excess per season", ints(drow("makes per season"))[1],
        round(cfg_("all distances", "excess_per_season")))
chk_int("deck s5 excess beyond 45",  ints(drow("come from beyond 45 yards"))[1],
        round(cfg_("45+ yards", "excess_makes")))

# Appendix A6: the effective sample size the weights cost.
ess <- sum(w_fg)^2 / sum(w_fg^2)
chk_int("deck A6 scored attempts",
        int_after("Effective sample size falls from ", lines = deck, nth = 1), length(w_fg))
chk_int("deck A6 ESS (nearest 100)",
        int_after("Effective sample size falls from ", lines = deck, nth = 2),
        round(ess / 100) * 100)

cat("\n--- deck: tail band counts ---\n")
chk_int("deck s13 60+ in-sample n",
        int_after("you look at the counts. ", lines = deck), n_tail_is)
chk_int("deck s13 60+ held-out n",
        int_after("in-sample beyond 60 yards, ", lines = deck), n_tail_oos)
chk_int("deck s4 60+ in-sample n",
        int_after("Beyond 60 yards there are ", lines = deck),  n_tail_is)

cat(sprintf("\n============ %d checks passed, %d MISMATCHED ============\n", ok, bad))
if (known_bad > 0) {
  cat(sprintf("%d of the %d mismatches are known, documented issues (see Paper/paper_numbers_audit.md).\n",
              known_bad, bad))
}
# Exit non-zero only on mismatches we have not already characterised, so the
# script stays usable as a regression gate while known issues await the
# manuscript revision.
if (bad - known_bad > 0) quit(status = 1)
