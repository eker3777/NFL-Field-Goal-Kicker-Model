# ============================================================
# Validate the leverage model's win-probability heads
# ============================================================
# The leverage weight used throughout the paper is built from two fitted heads,
# wp_make_hat and wp_miss_hat, which predict the post-play win probability under
# each field goal outcome. Section 3.4 previously asserted these were reasonable
# without evidence. This script scores them.
#
# METHOD. For every observed attempt we select the head matching what actually
# happened -- wp_make_hat if the kick was made, wp_miss_hat if it was missed --
# and compare it against wp_post, nflfastR's realized post-play win probability
# (wp_pre + wpa). Only the matching head is scored, because only that branch was
# realised; the counterfactual branch has no observable target.
#
# The comparison is run twice, before and after the deterministic endgame rules
# are applied (`*_rules`), so the rules can be shown to help rather than assumed
# to. Breakouts: overall / made / missed / late-and-close, the last being where
# the rules actually bind.
#
# SOURCE. Scored directly off 01_data_prep.ipynb's own leverage-scoring output
# (data/fg_attempts.csv), which applies the already-fitted wp_heads_rulepack.rds
# to every attempt via predict() -- not a frozen validation split from the
# (deleted) fitting notebook. This covers the full 2015-2025 paper window.
#
# SCOPE, stated rather than glossed:
#   wp_post is another model's output, not a realized game result, so this
#   measures agreement with nflfastR's WP model, not truth. That caveat is
#   repeated in the manuscript.
#
# Continuous target on [0,1]: RMSE / MAE / R^2 / mean bias. No AUC or log-loss.
#
# Outputs:
#   reports/attempt_pi/leverage_validation.csv
#   reports/attempt_pi/leverage_validation_calibration.csv

suppressPackageStartupMessages({
  library(dplyr); library(readr); library(tidyr)
})

IN_PATH  <- 'data/fg_attempts.csv'
OUT_DIR  <- 'reports/attempt_pi'
N_BINS   <- 10L

stopifnot(file.exists(IN_PATH))
if (!dir.exists(OUT_DIR)) dir.create(OUT_DIR, recursive = TRUE)

lev <- readr::read_csv(IN_PATH, show_col_types = FALSE) %>%
  filter(is_pat == 0L, season >= 2015, season <= 2025)

n_raw <- nrow(lev)

lev <- lev %>%
  mutate(
    wp_post = wp + wpa,
    made = kick_result == 'made',
    # Head matching the realized outcome, before and after the endgame rules
    wp_hat_pre  = if_else(made, wp_make_hat,       wp_miss_hat),
    wp_hat_post = if_else(made, wp_make_hat_rules, wp_miss_hat_rules),
    late_close  = qtr == 4 & !as.logical(is_ot) &
                  abs(score_differential) <= 3 & game_seconds_remaining <= 120
  ) %>%
  filter(!is.na(wp_post), !is.na(wp_hat_pre), !is.na(wp_hat_post))

message('Rows: ', n_raw, ' read | ', nrow(lev), ' scored (', n_raw - nrow(lev),
        ' dropped for missing head or target)')
message('Seasons: ', min(lev$season), '-', max(lev$season))

# ------------------------------------------------------------
score <- function(y, p) {
  err <- p - y
  sse <- sum(err^2)
  sst <- sum((y - mean(y))^2)
  tibble::tibble(
    n     = length(y),
    rmse  = sqrt(mean(err^2)),
    mae   = mean(abs(err)),
    bias  = mean(err),
    r2    = 1 - sse / sst,
    cor   = suppressWarnings(cor(y, p))
  )
}

subsets <- list(
  'overall'      = rep(TRUE, nrow(lev)),
  'made'         = lev$made,
  'missed'       = !lev$made,
  'late & close' = lev$late_close
)

metrics <- purrr::imap_dfr(subsets, function(mask, nm) {
  d <- lev[mask, , drop = FALSE]
  dplyr::bind_rows(
    score(d$wp_post, d$wp_hat_pre)  %>% mutate(stage = 'pre-rules',  .before = 1),
    score(d$wp_post, d$wp_hat_post) %>% mutate(stage = 'post-rules', .before = 1)
  ) %>% mutate(subset = nm, .before = 1)
})

# Improvement attributable to the endgame rules
improvement <- metrics %>%
  select(subset, stage, rmse, mae) %>%
  pivot_wider(names_from = stage, values_from = c(rmse, mae)) %>%
  mutate(
    rmse_delta   = `rmse_post-rules` - `rmse_pre-rules`,
    rmse_pct     = 100 * rmse_delta / `rmse_pre-rules`
  )

cat('\n=== Leverage WP heads scored against realized post-play WP ===\n')
print(as.data.frame(metrics %>% mutate(across(where(is.numeric), ~round(., 4)))),
      row.names = FALSE)
cat('\n=== Effect of the deterministic endgame rules ===\n')
print(as.data.frame(improvement %>% mutate(across(where(is.numeric), ~round(., 4)))),
      row.names = FALSE)

# ------------------------------------------------------------
# Calibration: equal-count bins of the predicted WP, post-rules
calib <- lev %>%
  mutate(bin = ntile(wp_hat_post, N_BINS)) %>%
  group_by(bin) %>%
  summarise(
    n         = n(),
    pred_mean = mean(wp_hat_post),
    obs_mean  = mean(wp_post),
    gap       = obs_mean - pred_mean,
    .groups = 'drop'
  )

cat('\n=== Calibration by decile of predicted post-play WP (post-rules) ===\n')
print(as.data.frame(calib %>% mutate(across(where(is.numeric), ~round(., 4)))),
      row.names = FALSE)
cat('\nMax absolute calibration gap:', round(max(abs(calib$gap)), 4), '\n')

readr::write_csv(metrics, file.path(OUT_DIR, 'leverage_validation.csv'))
readr::write_csv(calib,   file.path(OUT_DIR, 'leverage_validation_calibration.csv'))
message('\nSaved: ', file.path(OUT_DIR, 'leverage_validation.csv'))
message('Saved: ', file.path(OUT_DIR, 'leverage_validation_calibration.csv'))
