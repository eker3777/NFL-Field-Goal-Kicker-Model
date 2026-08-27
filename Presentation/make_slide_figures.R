# ============================================================
# Conference deck figures -- "Here's the Kicker" (Vancouver, Sept 2026)
#
# Regenerates every figure the slide deck uses, at slide scale, into
# Presentation/figures/. Run from the repo root or from Presentation/:
#
#     Rscript Presentation/make_slide_figures.R
#
# Figures here with no manuscript counterpart:
#   * data_overview_dashboard.png -- four-panel EDA of the analysis sample. The
#                                    manuscript build (notebook 05) carries six.
#   * oos_pred_density.png        -- OOS predicted-probability density plus
#                                    decile bin widths, which answers the
#                                    "why is the lowest decile at 60%?" question
#   * m2_eligibility.png          -- appendix A7, the pseudo-miss pool screens
#   * propensity_density_three_way.png, wpa_by_regime_era.png -- backups, built
#                                    but not placed on a slide
#
# Distance bands throughout are half-open on the right, [0,30) / [30,40) / ...
# / [60, Inf), matching notebook 03, notebook 05 and scripts/audit_paper_numbers.R.
#
# The remaining figures are slide-scale ports of notebook 05 cells. They are
# intentionally duplicated rather than shared: the deck is a different design
# target (16:9, read from 30 feet) and must not be able to overwrite the
# manuscript's figures, which notebook 05 wipes and rebuilds wholesale.
# ============================================================

.here <- if (dir.exists('Presentation')) 'Presentation' else '.'
source(file.path(.here, '_slide_common.R'))


# ============================================================
# NEW 1. Data overview dashboard  (slide 4)
# ============================================================
# The deck's cut of the manuscript dashboard: four panels instead of six. The
# paper version (notebook 05) additionally carries kickers-per-season and the
# kicker-workload histogram; both are modelling justifications rather than
# narrative, and a slide read from thirty feet cannot afford six panels.
# The venue-mix panel is dropped from both.
message('\n[1/15] data overview dashboard')

fg_att <- fg_all %>%
  filter(play_type_original == 'field_goal', is_pat == 0,
         season >= EVAL_SEASON_MIN, season <= EVAL_SEASON_MAX,
         !is.na(kick_distance), !is.na(kick_made))

# --- headline counts, computed rather than quoted -----------------------
n_analysis <- nrow(preds_is)
n_test     <- nrow(preds_test)
n_train    <- nrow(preds_train)
n_kickers  <- dplyr::n_distinct(preds_is$kicker_player_id)
n_kseasons <- dplyr::n_distinct(paste(preds_is$kicker_player_id, preds_is$season))
n_stadiums <- dplyr::n_distinct(preds_is$stadium_id)
n_seasons  <- dplyr::n_distinct(preds_is$season)

# Panel A -- attempts by season. Flat, which is the point: the sample is not
# driven by a few outlier seasons. Distinct kickers used to ride a secondary
# axis on this panel; it now has its own panel in the paper version, because a
# dual axis asked the reader to decode two scales to learn that both are flat.
season_sample <- preds_is %>%
  group_by(season) %>%
  summarise(attempts = n(),
            kickers  = dplyr::n_distinct(kicker_player_id), .groups = 'drop')

pA <- ggplot(season_sample, aes(season, attempts)) +
  geom_col(fill = '#0072B2', alpha = 0.85, width = 0.72) +
  scale_x_continuous(breaks = seq(EVAL_SEASON_MIN, EVAL_SEASON_MAX, 2)) +
  scale_y_continuous(labels = scales::comma, expand = expansion(mult = c(0, 0.10))) +
  labs(title = 'Attempts by season',
       subtitle = wrap_sub(paste0(n_seasons, ' seasons, ',
                                  scales::comma(n_analysis), ' kicks, ',
                                  n_kickers, ' kickers.')),
       x = NULL, y = 'Field goal attempts') +
  theme_slide_panel()

# Panel B -- distance distribution, split by realised outcome. Shows both the
# shape of the covariate that dominates the model and where the misses live.
pB <- preds_is %>%
  mutate(Outcome = if_else(kick_made == 1, 'Made', 'Missed')) %>%
  ggplot(aes(kick_distance, fill = Outcome)) +
  geom_histogram(binwidth = 2, colour = 'white', linewidth = 0.18) +
  scale_fill_manual(values = outcome_cols) +
  scale_x_continuous(breaks = seq(20, 70, 10)) +
  scale_y_continuous(labels = scales::comma, expand = expansion(mult = c(0, 0.08))) +
  labs(title = 'Kick distance and outcome',
       subtitle = wrap_sub(sprintf('Mean %.1f yds, range %d-%d. Overall make rate %.1f%%.',
                                   mean(preds_is$kick_distance),
                                   min(preds_is$kick_distance), max(preds_is$kick_distance),
                                   100 * mean(preds_is$kick_made))),
       x = 'Kick distance (yards)', y = 'Kicks', fill = NULL) +
  theme_slide_panel() +
  theme(legend.position = c(0.16, 0.84),
        legend.background = element_rect(fill = alpha('white', 0.75), colour = NA))

# Panel D -- make rate by distance band, with counts.
# Bands are half-open on the right, [0,30) / [30,40) / ... / [60, Inf), the
# single convention shared with notebook 03, notebook 05 and the audit script.
# The 60+ band is the one the IPW correction is built to act on and also the
# one with almost no data; printing n on the bars makes that tension visible.
band_lv <- c('<30', '30-39', '40-49', '50-59', '60+')
band_stats <- preds_is %>%
  mutate(band = cut(kick_distance, c(0, 30, 40, 50, 60, 100),
                    right = FALSE, include.lowest = TRUE, labels = band_lv)) %>%
  group_by(band) %>%
  summarise(n = n(), make = mean(kick_made), .groups = 'drop')

n_tail <- band_stats$n[band_stats$band == '60+']

pD <- ggplot(band_stats, aes(band, make)) +
  geom_col(fill = '#0072B2', alpha = 0.85, width = 0.7) +
  geom_text(aes(label = paste0('n=', scales::comma(n))),
            vjust = -0.55, size = SLIDE_BASE / 3.0, colour = 'grey25') +
  scale_y_continuous(labels = scales::percent_format(accuracy = 1),
                     limits = c(0, 1.09), expand = expansion(mult = c(0, 0))) +
  labs(title = 'Make rate by distance band',
       subtitle = wrap_sub(sprintf('The band the IPW correction targets (60+) holds %s kicks, %.1f%% of the sample.',
                                   scales::comma(n_tail), 100 * n_tail / n_analysis)),
       x = 'Kick distance (yards)', y = 'Make rate') +
  theme_slide_panel()

# Panel F -- how the analysis sample was carved out.
#
# CANONICAL DEFINITION of the propensity-model universe. This reproduces
# notebook 02's decision frame exactly. The frame spans the FULL field: the
# propensity model is a model of the coach's fourth-down choice, and that choice
# exists at every field position, so truncating it at kicking range would hide
# most punts from a model of when teams punt. It deliberately does NOT apply
# notebook 05's `ydstogo >= 1` screen: that screen is a plotting convenience for
# the decision-share figures and drops a single row, which is not a reason to
# carry two different definitions of the same population.
propensity_universe <- fg_all %>%
  filter(is_pat == 0L,
         play_type_original %in% c('field_goal', 'pass', 'run', 'punt'),
         !is.na(yardline_100),
         !is.na(game_seconds_remaining),
         season >= EVAL_SEASON_MIN, season <= EVAL_SEASON_MAX)
n_decision_win <- nrow(propensity_universe)
n_fg_raw       <- nrow(fg_att)

# The steps are strictly nested, so the bars read as a funnel. The top bar is
# broken out by what the coach actually did, in the decision figures' own
# colours, so the audience can see that the field goal segment IS the second bar
# rather than taking the nesting on trust. An earlier draft opened with the
# 78,563 / 32,666 non-attempt counts quoted in the manuscript; those are the M2
# augmentation pool, a DIFFERENT population that does not contain the field goal
# attempts, so stacking them here implied a nesting that does not exist.
TOP_STEP  <- '4th-down decisions (all field positions)'
FUNNEL_LV <- c(TOP_STEP, 'Field goal attempts', 'Analysis set (blocked excluded)',
               'Training attempts', 'Held-out test attempts')

top_seg <- propensity_universe %>%
  mutate(seg = dplyr::case_when(play_type_original == 'field_goal' ~ 'Field Goal',
                                play_type_original == 'punt'       ~ 'Punt',
                                TRUE                               ~ 'Go for It')) %>%
  count(seg, name = 'n') %>%
  mutate(step = TOP_STEP)

funnel <- bind_rows(
  top_seg,
  tibble::tibble(step = FUNNEL_LV[-1],
                 n    = c(n_fg_raw, n_analysis, n_train, n_test),
                 seg  = c('rest_b', 'rest_b', 'rest_c', 'rest_c'))) %>%
  mutate(step = factor(step, levels = rev(FUNNEL_LV)),
         # position_stack draws the last level first, so Field Goal is listed
         # last to put it at the left edge, flush with the bar below it.
         seg  = factor(seg, levels = c('Punt', 'Go for It', 'Field Goal',
                                       'rest_b', 'rest_c')))

funnel_tot  <- funnel %>% group_by(step) %>% summarise(n = sum(n), .groups = 'drop')
funnel_cols <- c('Field Goal' = '#0072B2', 'Go for It' = '#D55E00', 'Punt' = '#525252',
                 'rest_b' = '#5B93B8', 'rest_c' = '#0072B2')

pF <- ggplot(funnel, aes(n, step, fill = seg)) +
  geom_col(width = 0.68, alpha = 0.92) +
  geom_text(data = dplyr::filter(funnel, step == TOP_STEP),
            aes(label = scales::comma(n)), position = position_stack(vjust = 0.5),
            size = SLIDE_BASE / 3.6, colour = 'white', fontface = 'bold') +
  geom_text(data = funnel_tot, aes(x = n, y = step, label = scales::comma(n)),
            hjust = -0.12, size = SLIDE_BASE / 3.0, colour = 'grey25', inherit.aes = FALSE) +
  scale_fill_manual(values = funnel_cols,
                    breaks = c('Field Goal', 'Go for It', 'Punt'), name = NULL) +
  scale_x_continuous(limits = c(0, n_decision_win * 1.32), expand = expansion(mult = c(0, 0))) +
  labs(title = 'Building the analysis set',
       subtitle = wrap_sub('Propensity model fits the top bar; outcome models fit the attempts. 2015-2025.'),
       x = NULL, y = NULL) +
  theme_slide_panel() +
  theme(axis.text.y = element_text(size = SLIDE_BASE - 3), legend.position = 'bottom')

p_eda <- (pA + pB) / (pD + pF) +
  plot_annotation(
    title = 'The analysis sample, 2015-2025',
    subtitle = sprintf(
      '%s field goal attempts | %d seasons | %d kickers | %d stadiums\n%s fourth-down decisions | %s training / %s held-out test',
      scales::comma(n_analysis), n_seasons, n_kickers, n_stadiums,
      scales::comma(n_decision_win), scales::comma(n_train), scales::comma(n_test)),
    theme = slide_annotation())

save_slide(p_eda, 'data_overview_dashboard.png', w = 17, h = 10.0, dpi = 150)

# Echo the funnel, plus the two manuscript counts it deliberately omits, so a
# discrepancy against the paper is loud rather than silent.
message('  funnel: ', paste(funnel_tot$step, scales::comma(funnel_tot$n), sep = '=', collapse = ' | '))
message('  top bar by decision: ', paste(top_seg$seg, scales::comma(top_seg$n), sep = '=', collapse = ' | '))
message('  distance bands: ', paste(band_stats$band, scales::comma(band_stats$n), sep = '=', collapse = ' | '))
message('  M2 non-attempt pool (NOT nested in the above): ',
        scales::comma(fg_all %>% filter(is_pat == 0L, attempted == 0L) %>% nrow()),
        ' all seasons | ',
        scales::comma(fg_all %>% filter(is_pat == 0L, attempted == 0L,
                                        season >= EVAL_SEASON_MIN,
                                        season <= EVAL_SEASON_MAX) %>% nrow()),
        ' in 2015-2025')


# ============================================================
# NEW 2. Out-of-sample predicted probability density  (slide 14)
# ============================================================
# Answers a co-author question: if the calibration bins are equal-sized, why
# does the lowest decile sit near 60%? Because the bins are equal in COUNT,
# not in RANGE. Predicted make probability piles up against 1.0, so the
# bottom decile has to span an enormous, sparse stretch of the probability
# scale to collect its 225 kicks, while the top decile collects its 225 from
# a slice under one percentage point wide.
message('\n[2/15] OOS predicted probability density')

decile_edges <- function(p) {
  p <- p[!is.na(p)]
  as.numeric(quantile(p, probs = seq(0, 1, 0.1), type = 7))
}

decile_table <- function(y, p, label) {
  d <- tibble::tibble(y = y, p = p) %>% filter(!is.na(y), !is.na(p))
  d$dec <- cut(d$p, breaks = decile_edges(d$p), include.lowest = TRUE, labels = FALSE)
  d %>% group_by(dec) %>%
    summarise(n = n(), lo = min(p), hi = max(p),
              pred = mean(p), obs = mean(y), .groups = 'drop') %>%
    mutate(width = hi - lo, model = label)
}

dec_m1 <- decile_table(y_test, preds_test$p_m1, 'M1 (Baseline)')
dec_m3 <- decile_table(y_test, preds_test$p_m3, 'M3 (IPW-weighted)')
dec_all <- bind_rows(dec_m1, dec_m3)

e3  <- decile_edges(preds_test$p_m3)
b1_lo <- dec_m3$lo[1]; b1_hi <- dec_m3$hi[1]
b1_w  <- dec_m3$width[1]; b10_w <- dec_m3$width[10]

# Panel A -- the density, with every decile boundary drawn on it.
# The callouts are positioned relative to the density's own maximum so they
# land in clear space instead of on top of the peak.
dmax <- max(stats::density(preds_test$p_m3[!is.na(preds_test$p_m3)], adjust = 0.85)$y)

pG <- ggplot(tibble(p = preds_test$p_m3), aes(p)) +
  annotate('rect', xmin = b1_lo, xmax = b1_hi, ymin = 0, ymax = Inf,
           fill = model_cols[['M3']], alpha = 0.13) +
  geom_density(fill = model_cols[['M3']], colour = NA, alpha = 0.55, adjust = 0.85) +
  geom_vline(xintercept = e3[2:10], colour = 'grey40',
             linetype = 'dashed', linewidth = 0.45) +
  annotate('text', x = (b1_lo + b1_hi) / 2, y = dmax * 1.02,
           label = sprintf('lowest decile\n%.2f to %.2f\n(%.0f points wide)', b1_lo, b1_hi, 100 * b1_w),
           vjust = 1, size = SLIDE_BASE / 2.9, colour = 'grey20', lineheight = 0.95) +
  annotate('text', x = 0.745, y = dmax * 1.02, hjust = 0, vjust = 1,
           label = sprintf('top decile:\n%.0f point wide', 100 * b10_w),
           size = SLIDE_BASE / 2.9, colour = 'grey20', lineheight = 0.95) +
  annotate('curve', x = 0.885, y = dmax * 0.88, xend = 0.982, yend = dmax * 1.00,
           curvature = -0.28, linewidth = 0.5, colour = 'grey35',
           arrow = arrow(length = unit(0.16, 'cm'), type = 'closed')) +
  scale_x_continuous(limits = c(0.18, 1.02), breaks = seq(0.2, 1.0, 0.1)) +
  scale_y_continuous(expand = expansion(mult = c(0, 0.30))) +
  labs(title = 'Held-out predicted make probability is piled against 1.0',
       subtitle = sprintf('M3, n = %s test kicks. Dashed = deciles. Only %.1f%% sit below 0.60.',
                          scales::comma(nrow(preds_test)),
                          100 * mean(preds_test$p_m3 < 0.6, na.rm = TRUE)),
       x = 'Predicted P(make)', y = 'Density') +
  theme_slide()

# Panel B -- the punchline: bin width by decile, both models.
pH <- ggplot(dec_all, aes(factor(dec), width, fill = model)) +
  geom_col(position = position_dodge(width = 0.78), width = 0.72, alpha = 0.9) +
  scale_fill_manual(values = setNames(unname(model_cols[c('M1', 'M3')]),
                                      c('M1 (Baseline)', 'M3 (IPW-weighted)'))) +
  scale_y_continuous(labels = scales::number_format(accuracy = 0.01),
                     expand = expansion(mult = c(0, 0.10))) +
  labs(title = 'Equal counts, wildly unequal ranges',
       subtitle = sprintf('Each decile holds ~%d kicks. Decile 1 spans %.0fx the range of decile 10.',
                          round(mean(dec_m3$n)), b1_w / b10_w),
       x = 'Decile of predicted probability', y = 'Width of bin (probability)',
       fill = NULL) +
  theme_slide() +
  theme(legend.position = 'bottom')

p_dens <- pG / pH +
  plot_layout(heights = c(1, 1)) +
  plot_annotation(
    title = 'Why the lowest calibration decile sits near 60%',
    subtitle = 'Bins are equal in count, not in range: the bottom decile is wide and sparse.',
    theme = slide_annotation())

save_slide(p_dens, 'oos_pred_density.png', w = 15, h = 10.0, dpi = 155)

message('  M3 decile 1: [', round(b1_lo, 3), ', ', round(b1_hi, 3), '] width ', round(b1_w, 3),
        ' | decile 10 width ', round(b10_w, 4), ' | ratio ', round(b1_w / b10_w, 1), 'x')


# ============================================================
# 3. Season kicking trends  (paper Fig 12) -- slide 4
# ============================================================
message('\n[3/15] season kicking trends')

season_stats <- fg_all %>%
  filter(play_type_original == 'field_goal', is_pat == 0,
         !is.na(kick_distance), !is.na(kick_made)) %>%
  group_by(season) %>%
  summarise(n_kicks = n(),
            avg_distance = mean(kick_distance, na.rm = TRUE),
            make_pct = mean(kick_made, na.rm = TRUE),
            n_50_plus = sum(kick_distance >= 50, na.rm = TRUE),
            make_pct_50_plus = mean(kick_made[kick_distance >= 50], na.rm = TRUE),
            .groups = 'drop')

trend_theme <- theme_slide() + theme(axis.title.x = element_blank())
shade <- annotate('rect', xmin = 2015, xmax = 2025, ymin = -Inf, ymax = Inf,
                  fill = '#0072B2', alpha = 0.08)

t1 <- ggplot(season_stats, aes(season, avg_distance)) + shade +
  geom_line(colour = '#0072B2', linewidth = 1.2) +
  geom_point(colour = '#0072B2', size = 2.2) +
  geom_smooth(method = 'lm', formula = y ~ x, se = FALSE, linetype = 'dashed', colour = 'grey50') +
  scale_x_continuous(breaks = seq(2000, 2025, 5)) +
  coord_cartesian(ylim = c(32, 42)) +
  labs(title = 'Average kick distance', subtitle = 'Mean distance of all attempts', y = 'Yards') +
  trend_theme

t2 <- ggplot(season_stats, aes(season, make_pct)) + shade +
  geom_line(colour = accent_green, linewidth = 1.2) +
  geom_point(colour = accent_green, size = 2.2) +
  scale_x_continuous(breaks = seq(2000, 2025, 5)) +
  coord_cartesian(ylim = c(0.70, 0.92)) +
  scale_y_continuous(labels = percent_format(accuracy = 1)) +
  labs(title = 'Overall make rate', subtitle = 'Success rate for all attempts', y = 'Make %') +
  trend_theme

t3 <- ggplot(season_stats, aes(season, n_50_plus)) + shade +
  geom_line(colour = accent_gold, linewidth = 1.2) +
  geom_point(colour = accent_gold, size = 2.2) +
  scale_x_continuous(breaks = seq(2000, 2025, 5)) +
  labs(title = 'Volume of 50+ yard attempts', subtitle = 'Total deep kicks per season', y = 'Count') +
  trend_theme

t4 <- ggplot(season_stats, aes(season, make_pct_50_plus)) + shade +
  geom_line(colour = '#D55E00', linewidth = 1.2) +
  geom_point(colour = '#D55E00', size = 2.2) +
  geom_smooth(method = 'lm', formula = y ~ x, se = FALSE, linetype = 'dashed', colour = 'grey50') +
  scale_x_continuous(breaks = seq(2000, 2025, 5)) +
  coord_cartesian(ylim = c(0.30, 0.80)) +
  scale_y_continuous(labels = percent_format(accuracy = 1)) +
  labs(title = 'Accuracy on 50+ yard attempts', subtitle = 'Success rate for deep kicks',
       y = 'Make % (50+)', x = 'Season') +
  theme_slide()

p_trends <- (t1 + t2) / (t3 + t4) +
  plot_annotation(title = 'NFL field goal kicking trends, 2000-2025',
                  subtitle = 'Shaded region = modelling period (2015-2025)',
                  theme = slide_annotation())

save_slide(p_trends, 'season_kicking_trends_detailed.png', w = 15, h = 9.4, dpi = 155)


# ============================================================
# 4. Kick distance distribution, 2015 vs 2025  (paper Fig 13) -- slide 5
# ============================================================
message('\n[4/15] distance distribution 2015 vs 2025')

dist_comp <- fg_all %>%
  filter(play_type_original == 'field_goal', is_pat == 0,
         season %in% c(2015, 2025), !is.na(kick_distance)) %>%
  mutate(season = factor(season))
season_means <- dist_comp %>% group_by(season) %>%
  summarise(mean_dist = mean(kick_distance), .groups = 'drop')

p_distshift <- ggplot(dist_comp, aes(kick_distance, fill = season)) +
  geom_density(alpha = 0.42, colour = NA) +
  geom_vline(data = season_means, aes(xintercept = mean_dist, colour = season),
             linetype = 'dashed', linewidth = 1.1, show.legend = FALSE) +
  scale_fill_manual(values = c('2015' = '#0072B2', '2025' = '#D55E00')) +
  scale_colour_manual(values = c('2015' = '#0072B2', '2025' = '#D55E00')) +
  labs(title = 'Shift in kicking strategy, 2015 vs 2025',
       subtitle = sprintf('Attempt-distance density. Dashed lines = means (%.1f vs %.1f yards).',
                          season_means$mean_dist[1], season_means$mean_dist[2]),
       x = 'Kick distance (yards)', y = 'Density', fill = NULL) +
  theme_slide() + theme(legend.position = 'top')

save_slide(p_distshift, 'kick_distance_distribution_15vs25.png', w = 11.5, h = 6.4)


# ============================================================
# 5. Make rate by distance and era  (paper Fig 5) -- slide 5
# ============================================================
# The dashed reference at 45 yards is where the era curves separate. Inside it
# the pre-2020 curve was already near its ceiling; essentially all of the era
# gap opens beyond it. The counterfactual artifact written by notebook 05
# quantifies the gap and supplies the slide's headline number.
message('\n[5/15] make rate by distance and era')

ERA_SPLIT_YDS <- 45

era_cols <- c('Pre-2020 (2015-2019)' = '#0072B2',
              'Post-2020 (2020-2025)' = '#D55E00',
              'Full Period (2015-2025)' = accent_green)

fg_era <- fg_all %>%
  filter(play_type_original == 'field_goal', is_pat == 0, season >= 2015,
         !is.na(kick_distance), !is.na(kick_made))

make_rate_data <- bind_rows(
  fg_era %>% filter(season %in% 2015:2019) %>% mutate(Era = 'Pre-2020 (2015-2019)'),
  fg_era %>% filter(season %in% 2020:2025) %>% mutate(Era = 'Post-2020 (2020-2025)'),
  fg_era                                   %>% mutate(Era = 'Full Period (2015-2025)')
) %>% mutate(Era = factor(Era, levels = names(era_cols)))

p_makeera <- ggplot(make_rate_data, aes(kick_distance, kick_made, colour = Era, fill = Era)) +
  annotate('rect', xmin = ERA_SPLIT_YDS, xmax = Inf, ymin = -Inf, ymax = Inf,
           fill = 'grey70', alpha = 0.10) +
  geom_vline(xintercept = ERA_SPLIT_YDS, linetype = 'dashed',
             colour = 'grey35', linewidth = 0.9) +
  geom_smooth(method = 'loess', formula = y ~ x, span = 0.4, se = TRUE,
              alpha = 0.10, linewidth = 1.3) +
  annotate('text', x = ERA_SPLIT_YDS + 1.2, y = 0.07, hjust = 0,
           label = 'the era gap opens here',
           size = SLIDE_BASE / 3.0, colour = 'grey30') +
  scale_colour_manual(values = era_cols) +
  scale_fill_manual(values = era_cols) +
  scale_y_continuous(labels = scales::percent_format(accuracy = 1), limits = c(0, 1)) +
  labs(title = 'Kickers have improved past 45 yards',
       subtitle = sprintf('Inside %d yards the curves nearly coincide. The gain is all beyond it.',
                          ERA_SPLIT_YDS),
       x = 'Kick distance (yards)', y = 'Make rate', colour = NULL, fill = NULL) +
  theme_slide() + theme(legend.position = 'top')

# Slide 5 places this in a 62% column, so its height is set by its width:
# at the old 12.5x6.8 it could only reach 540px of the ~795px available.
save_slide(p_makeera, 'make_rate_by_distance_era.png', w = 12.5, h = 9.5)

# The slide's headline number, echoed here so a mismatch between the artifact
# and the printed slide is loud at build time.
cf_path <- file.path(reports_dir, 'figures', 'era_counterfactual.csv')
if (file.exists(cf_path)) {
  cf <- readr::read_csv(cf_path, show_col_types = FALSE)
  message('  era counterfactual: ',
          paste(sprintf('%s: %+.0f makes (%+.1f/season)',
                        cf$subset, cf$excess_makes, cf$excess_per_season),
                collapse = ' | '))
} else {
  warning('era_counterfactual.csv missing -- run notebook 05 before quoting the slide 5 headline')
}


# ============================================================
# 6. Fourth-down decision evolution  (paper Fig 15) -- slide 6
# ============================================================
message('\n[6/15] decision evolution by yards-to-go')

decision_evol <- decision %>%
  mutate(ydsgap = if_else(ydstogo >= 5, 'Long yards-to-go', 'Short yards-to-go'),
         action = dplyr::recode(action, FG = 'FG', punt = 'Punt', go_for_it = 'Go for It')) %>%
  count(season, ydsgap, action, name = 'count') %>%
  group_by(season, ydsgap) %>% mutate(pct = count / sum(count)) %>% ungroup()

evol_panel <- function(regime, title, show_legend, ylab) {
  p <- decision_evol %>% filter(ydsgap == regime) %>%
    ggplot(aes(season, pct, colour = action, group = action)) +
    geom_line(linewidth = 1.3) + geom_point(size = 2.2) +
    scale_colour_manual(values = decision_cols) +
    scale_y_continuous(labels = percent_format(accuracy = 1), limits = c(0, 1)) +
    scale_x_continuous(breaks = seq(2000, 2025, 5)) +
    labs(title = title, x = 'Season', y = ylab, colour = NULL) +
    theme_slide()
  if (!show_legend) p + theme(legend.position = 'none') else p
}

p_evol <- evol_panel('Long yards-to-go', 'Long yards-to-go (5 or more)', FALSE, 'Decision share') +
  evol_panel('Short yards-to-go', 'Short yards-to-go (4 or fewer)', TRUE, NULL) +
  plot_annotation(
    title = 'Historical shifts in fourth-down decisions',
    subtitle = 'On short yards-to-go coaches increasingly go for it, declining punts and kicks.',
    theme = slide_annotation())

save_slide(p_evol, 'kicking_decision_evolution.png', w = 14.5, h = 7.0, dpi = 165)


# ============================================================
# 7. Decision rates by field position  (paper Fig 16) -- slide 7
# ============================================================
message('\n[7/15] decision rates by field position')

decision_by_pos <- decision %>%
  filter(yardline_100 <= 60, yardline_100 >= 1) %>%
  mutate(ydsgap = if_else(ydstogo >= 5,
                          'Long yards-to-go (5 or more)', 'Short yards-to-go (4 or fewer)'),
         Outcome = dplyr::case_when(action == 'FG' ~ 'Field Goal',
                                    action == 'punt' ~ 'Punt',
                                    action == 'go_for_it' ~ 'Go for It')) %>%
  group_by(ydsgap, yardline_100, Outcome) %>%
  summarise(n = n(), .groups = 'drop_last') %>%
  mutate(total_plays = sum(n), rate = n / total_plays) %>%
  ungroup() %>% filter(total_plays > 20)

p_decpos <- ggplot(decision_by_pos, aes(yardline_100, rate, colour = Outcome, fill = Outcome)) +
  geom_smooth(method = 'loess', formula = y ~ x, span = 0.3, linewidth = 1.7, se = FALSE) +
  geom_point(alpha = 0.28, size = 1.5) +
  facet_wrap(~ ydsgap, ncol = 2) +
  scale_colour_manual(values = decision_cols) +
  scale_fill_manual(values = decision_cols) +
  scale_y_continuous(labels = scales::percent) +
  scale_x_continuous(breaks = seq(0, 60, 10)) +
  labs(title = 'Fourth-down decision rates by field position',
       subtitle = 'A sharp, predictable function of field position and yards to go.',
       x = 'Yards from end zone', y = 'Decision rate', colour = NULL, fill = NULL) +
  theme_slide() + theme(legend.position = 'top')

save_slide(p_decpos, 'decision_by_field_position.png', w = 14.5, h = 7.0, dpi = 165)


# ============================================================
# 8. Short yards-to-go by era  (paper Fig 8) -- slide 15
# ============================================================
# Both eras on shared axes rather than side-by-side facets. The claim is about
# how far the curves MOVED, and a reader cannot measure a shift across two
# panels -- they have to hold one curve in memory while looking at the other.
# Era is linetype, decision stays colour, so the colour encoding is identical to
# every other decision figure in the deck.
message('\n[8/15] short yards-to-go decisions by era')

short_ytg_era <- decision %>%
  filter(ydstogo <= 4, yardline_100 <= 60, yardline_100 >= 1, season >= 2015) %>%
  mutate(Era = dplyr::case_when(season %in% 2015:2019 ~ 'Pre-2020 (2015-2019)',
                                season %in% 2020:2025 ~ 'Post-2020 (2020-2025)',
                                TRUE ~ NA_character_),
         Outcome = dplyr::case_when(action == 'FG' ~ 'Field Goal',
                                    action == 'punt' ~ 'Punt',
                                    action == 'go_for_it' ~ 'Go for It')) %>%
  filter(!is.na(Era)) %>%
  mutate(Era = factor(Era, levels = c('Pre-2020 (2015-2019)', 'Post-2020 (2020-2025)'))) %>%
  group_by(Era, yardline_100, Outcome) %>%
  summarise(n = n(), .groups = 'drop_last') %>%
  mutate(total_plays = sum(n), rate = n / total_plays) %>%
  ungroup() %>% filter(total_plays > 10)

p_shortera <- ggplot(short_ytg_era,
                     aes(yardline_100, rate, colour = Outcome, linetype = Era)) +
  geom_smooth(method = 'loess', formula = y ~ x, span = 0.4, linewidth = 1.6, se = FALSE) +
  scale_colour_manual(values = decision_cols) +
  scale_linetype_manual(values = c('Pre-2020 (2015-2019)'  = '22',
                                   'Post-2020 (2020-2025)' = 'solid')) +
  scale_y_continuous(labels = scales::percent) +
  scale_x_continuous(breaks = seq(0, 60, 10)) +
  labs(title = 'Fourth and short: the levels moved, the shapes did not',
       subtitle = 'Fourth down with 4 or fewer to go. Dashed = pre-2020, solid = post-2020.',
       x = 'Yards from end zone', y = 'Decision rate',
       colour = NULL, linetype = NULL) +
  guides(linetype = guide_legend(override.aes = list(colour = 'grey30'))) +
  theme_slide() +
  theme(legend.position = 'top', legend.box = 'horizontal')

save_slide(p_shortera, 'short_yardage_decisions_era.png', w = 14.5, h = 7.0, dpi = 165)


# ============================================================
# 9. Propensity density by decision  (paper Fig 12) -- slide 7
# ============================================================
# Restricted to plausible kicking range. On the full field the separation is
# trivial -- a punt from a team's own 12 is a punt -- and including those plays
# piles a spike against zero that swamps the part of the picture the selection
# argument rests on. This is the same restriction behind the in-range AUC.
#
# The AUC in the subtitle is read from the artifact, not typed. A hardcoded
# range here survived a propensity re-specification once and printed stale
# numbers on a slide.
message('\n[9/15] propensity density by decision')

prop_in_range <- preds_pi %>%
  filter(!is.na(p_hat_multinom), yardline_100 <= IN_RANGE_YL) %>%
  mutate(decision_type = if_else(attempt_fg == 1, 'FG Attempted', 'Not Attempted'))

p_prop <- ggplot(prop_in_range, aes(p_hat_multinom, fill = decision_type)) +
  geom_density(alpha = 0.55, colour = NA) +
  scale_fill_manual(values = c('FG Attempted' = '#0072B2', 'Not Attempted' = '#D55E00')) +
  labs(title = 'Coaching decisions are highly predictable',
       subtitle = sprintf('In-range plays only. Out-of-fold AUC %.3f-%.3f by season, n = %s.',
                          AUC_IN_RANGE[1], AUC_IN_RANGE[2], scales::comma(nrow(prop_in_range))),
       x = expression(hat(pi)(x) * ' -- P(attempt FG | context)'),
       y = 'Density', fill = NULL) +
  theme_slide()

save_slide(p_prop, 'propensity_density_by_decision.png', w = 12.5, h = 6.6)

message(sprintf('  in-range plays %s of %s in the frame | in-range AUC %.3f-%.3f',
                scales::comma(nrow(prop_in_range)), scales::comma(nrow(preds_pi)),
                AUC_IN_RANGE[1], AUC_IN_RANGE[2]))


# ============================================================
# 10. IPW weights vs kick distance  (paper Fig 3) -- slide 10
# ============================================================
message('\n[10/15] IPW weights vs distance')

p_weights <- preds %>%
  filter(!is.na(w_ipw_final), is.finite(w_ipw_final)) %>%
  ggplot(aes(kick_distance, w_ipw_final)) +
  geom_point(alpha = 0.13, size = 0.8, colour = '#0072B2') +
  geom_smooth(method = 'loess', formula = y ~ x, colour = '#D55E00', se = FALSE, linewidth = 1.5) +
  geom_hline(yintercept = 1, linetype = 'dashed', colour = 'grey40') +
  scale_y_continuous(limits = c(0, 8)) +
  labs(title = 'The weights load onto the long tail',
       subtitle = 'Stabilised, Hajek-normalised IPW weight by distance. Dashed line = 1.',
       x = 'Kick distance (yards)', y = 'IPW weight') +
  theme_slide()

# Slide 8 places this in a 55% column, the narrowest figure slot in the
# deck, so it needs the squarest aspect ratio.
save_slide(p_weights, 'weights_vs_distance.png', w = 12.5, h = 10.5)


# ============================================================
# 11. Calibration and squared error  (paper Figs 5, 7) -- slides 13, 14
# ============================================================
message('\n[11/15] calibration and squared error')

wilson_ci <- function(k, n, z = 1.96) {
  p <- k / n; d <- 1 + z^2 / n
  ctr <- (p + z^2 / (2 * n)) / d
  hw  <- z * sqrt(p * (1 - p) / n + z^2 / (4 * n^2)) / d
  tibble::tibble(lo = pmax(0, ctr - hw), hi = pmin(1, ctr + hw))
}

calib_binned <- function(y, p, label, nbins = 10) {
  df <- tibble::tibble(y = y, p = p) %>% dplyr::filter(!is.na(y), !is.na(p))
  df$bin <- ggplot2::cut_number(df$p, nbins)
  df %>% group_by(bin) %>%
    summarise(obs = mean(y), pred = mean(p), n = dplyr::n(), k = sum(y), .groups = 'drop') %>%
    bind_cols(wilson_ci(.$k, .$n)) %>% mutate(model = label)
}

build_calibration_fig <- function(pred_list, y, title, subtitle) {
  calib <- purrr::imap_dfr(pred_list, ~ calib_binned(y, .x, .y))
  long  <- purrr::imap_dfr(pred_list, ~ tibble::tibble(p = .x, model = .y)) %>% filter(!is.na(p))
  rng <- range(c(calib$pred, calib$obs, calib$lo, calib$hi), na.rm = TRUE)
  rng <- c(floor(rng[1] * 20) / 20, ceiling(rng[2] * 20) / 20)

  p_top <- ggplot(calib, aes(pred, obs, colour = model)) +
    geom_abline(slope = 1, intercept = 0, linetype = 'dashed', colour = 'grey45') +
    geom_errorbar(aes(ymin = lo, ymax = hi), width = 0, linewidth = 0.6, alpha = 0.8) +
    geom_line(linewidth = 0.9, alpha = 0.9) +
    geom_point(aes(size = n)) +
    scale_size_continuous(range = c(1.6, 4.2), guide = 'none') +
    scale_colour_manual(values = model_cols, guide = 'none') +
    scale_x_continuous(limits = rng, breaks = scales::pretty_breaks(4)) +
    scale_y_continuous(limits = rng, breaks = scales::pretty_breaks(4)) +
    coord_equal() + facet_wrap(~ model, nrow = 1) +
    labs(title = title, subtitle = subtitle, x = NULL, y = 'Observed make rate') +
    theme_slide()

  p_bot <- ggplot(long, aes(p, fill = model)) +
    geom_histogram(bins = 40, colour = NA, alpha = 0.85) +
    scale_fill_manual(values = model_cols, guide = 'none') +
    scale_x_continuous(limits = rng, breaks = scales::pretty_breaks(4)) +
    facet_wrap(~ model, nrow = 1) +
    labs(x = 'Mean predicted P(make)', y = 'Kicks') +
    theme_slide() +
    theme(strip.text = element_blank(), strip.background = element_blank())

  p_top / p_bot + plot_layout(heights = c(3.2, 1))
}

p_calib_test <- build_calibration_fig(
  list(M0 = preds_test$p_m0, M1 = preds_test$p_m1,
       M3 = preds_test$p_m3, M2 = preds_test$p_m2),
  y_test,
  'Calibration by decile of predicted probability (held-out test set)',
  paste0('Equal-count bins, 95% Wilson intervals, n = ',
         scales::comma(sum(!is.na(y_test)))))

save_slide(p_calib_test, 'calibration_test.png', w = 15, h = 7.4, dpi = 160)

brier_data <- bind_rows(
  preds_is %>% filter(!is.na(kick_made)) %>%
    transmute(kick_distance,
              `M1 (Baseline)`     = (kick_made - p_m1_full)^2,
              `M3 (IPW-weighted)` = (kick_made - p_m3_full)^2,
              split = 'In-sample'),
  preds_test %>% filter(!is.na(kick_made)) %>%
    transmute(kick_distance,
              `M1 (Baseline)`     = (kick_made - p_m1)^2,
              `M3 (IPW-weighted)` = (kick_made - p_m3)^2,
              split = 'Out-of-sample (held-out test)')
) %>%
  pivot_longer(c(`M1 (Baseline)`, `M3 (IPW-weighted)`),
               names_to = 'Model', values_to = 'Sq_Residual')

p_brier <- ggplot(brier_data, aes(kick_distance, Sq_Residual, colour = Model, fill = Model)) +
  geom_smooth(method = 'loess', formula = y ~ x, span = 0.5, se = TRUE,
              alpha = 0.10, linewidth = 1.4) +
  # Stacked rather than side by side. Slide 13 gives this a 60% column, and
  # two panels sharing 960px were the narrowest panels in the deck. Stacking
  # makes each panel wider than the old side-by-side version AND lets the
  # figure fill the column's full height. It also puts the two splits on a
  # shared x axis, which is the comparison the slide is actually making.
  facet_wrap(~ split, ncol = 1, scales = 'fixed') +
  scale_colour_manual(values = cols_model_long) +
  scale_fill_manual(values = cols_model_long) +
  labs(title = 'The correction works where it was designed to,\nand only there',
       subtitle = 'LOESS squared error by distance. In-sample M3 wins the long tail;\nout-of-sample the curves cross.',
       x = 'Kick distance (yards)', y = 'Squared residual', colour = NULL, fill = NULL) +
  theme_slide() +
  theme(legend.position = 'top')

save_slide(p_brier, 'brier_comparison_is_oos.png', w = 11, h = 9, dpi = 165)


# ============================================================
# 12. WPA by yards-to-go regime  (paper Fig 10) -- slide 16
# ============================================================
# Slide-scale port of notebook 05's figure. This is the evidence for the deck's
# closing beat: on short yards-to-go the go-for-it curve sits above zero at
# every field position while field goal WPA sits below it, so a declined kick
# looks like a statement about the alternative rather than about the kicker.
#
# Descriptive only. These curves do not identify what any coach was thinking.
message('\n[12/15] WPA by yards-to-go regime')

wpa_ytg <- decision %>%
  filter(!is.na(wpa), !is.na(yardline_100), yardline_100 <= 55, yardline_100 >= 1) %>%
  mutate(Decision = dplyr::case_when(action == 'FG'        ~ 'Field Goal',
                                     action == 'punt'      ~ 'Punt',
                                     action == 'go_for_it' ~ 'Go for It'),
         ytg_regime = if_else(ydstogo >= 5,
                              'Long yards-to-go (5 or more)',
                              'Short yards-to-go (4 or fewer)')) %>%
  filter(!is.na(Decision))

p_wpa_ytg <- ggplot(wpa_ytg, aes(yardline_100, wpa, colour = Decision, fill = Decision)) +
  geom_hline(yintercept = 0, colour = 'grey55', linetype = 'dashed', linewidth = 0.8) +
  geom_smooth(method = 'loess', formula = y ~ x, se = TRUE, alpha = 0.10,
              span = 0.6, linewidth = 1.5) +
  facet_wrap(~ ytg_regime, ncol = 2) +
  scale_colour_manual(values = decision_cols) +
  scale_fill_manual(values = decision_cols) +
  scale_x_continuous(breaks = seq(0, 55, 10)) +
  labs(title = 'The value was in the alternative',
       subtitle = 'WPA by decision and field position, 2015-2025. Descriptive, not causal.',
       x = 'Yards from end zone', y = 'WPA', colour = NULL, fill = NULL) +
  theme_slide() + theme(legend.position = 'top')

save_slide(p_wpa_ytg, 'wpa_by_ytg_regime.png', w = 14.5, h = 7.0, dpi = 165)


# ============================================================
# 13. M2 eligibility  (appendix A7)
# ============================================================
# Answers "how did you pick the pseudo-miss pool?" by showing the whole
# candidate population and the sliver of it that survives both screens. The
# hypothetical kick distance on the x-axis is `yardline_100 + 17`, which is only
# meaningful where a kick is physically possible -- hence the 70-yard cap, which
# is also the outer boundary knot of the outcome model's distance basis.
message('\n[13/15] M2 eligibility histogram')

M2_PI_FLOOR   <- 0.25
M2_DIST_FLOOR <- 33

m2_cand <- fg_all %>%
  filter(is_pat == 0L, attempted == 0L,
         season >= EVAL_SEASON_MIN, season <= EVAL_SEASON_MAX,
         !is.na(kick_distance), kick_distance <= 70) %>%
  mutate(game_id = as.character(game_id), play_id = as.character(play_id)) %>%
  left_join(preds_pi %>%
              mutate(game_id = as.character(game_id), play_id = as.character(play_id)) %>%
              select(game_id, play_id, p_hat_attempt_clipped),
            by = c('game_id', 'play_id')) %>%
  mutate(admitted = !is.na(p_hat_attempt_clipped) &
                     p_hat_attempt_clipped >= M2_PI_FLOOR &
                     kick_distance > M2_DIST_FLOOR)

n_cand <- nrow(m2_cand)
n_adm  <- sum(m2_cand$admitted)

p_m2elig <- ggplot(m2_cand, aes(kick_distance, fill = admitted)) +
  geom_histogram(binwidth = 2, colour = 'white', linewidth = 0.18, position = 'stack') +
  geom_vline(xintercept = M2_DIST_FLOOR, linetype = 'dashed',
             colour = 'grey30', linewidth = 0.9) +
  annotate('text', x = M2_DIST_FLOOR - 1, y = Inf, hjust = 1, vjust = 1.6,
           label = sprintf('%d yd floor  ', M2_DIST_FLOOR),
           size = SLIDE_BASE / 3.0, colour = 'grey30') +
  scale_fill_manual(values = c('FALSE' = '#C9CDD1', 'TRUE' = '#D55E00'),
                    labels = c('FALSE' = 'Screened out', 'TRUE' = 'Entered M2 as a pseudo-miss'),
                    name = NULL) +
  scale_x_continuous(breaks = seq(20, 70, 10)) +
  scale_y_continuous(labels = scales::comma, expand = expansion(mult = c(0, 0.10))) +
  labs(title = 'What M2 actually trains on',
       subtitle = sprintf('Fourth-down non-attempts by hypothetical kick distance. %s of %s admitted.',
                          scales::comma(n_adm), scales::comma(n_cand)),
       x = 'Hypothetical kick distance (yards)', y = 'Fourth-down non-attempts') +
  theme_slide() + theme(legend.position = 'top')

# A7 places this in a 58% column beside the threshold sweep table.
save_slide(p_m2elig, 'm2_eligibility.png', w = 12, h = 10)

message('  M2 candidates ', scales::comma(n_cand), ' | admitted ', scales::comma(n_adm))


# ============================================================
# 14. BACKUP -- propensity density split three ways
# ============================================================
# Not placed on any slide. Built because the two-way split collapses punts and
# go-for-its into one "Not Attempted" mass, and those are different decisions
# with different propensity profiles. Hold in reserve in case the room asks.
message('\n[14/15] BACKUP propensity density, three-way')

prop3 <- preds_pi %>%
  filter(!is.na(p_hat_multinom), yardline_100 <= IN_RANGE_YL, !is.na(action_actual)) %>%
  mutate(Decision = dplyr::recode(as.character(action_actual),
                                  FG = 'Field Goal', punt = 'Punt',
                                  go_for_it = 'Go for It', .default = NA_character_)) %>%
  filter(!is.na(Decision))

p_prop3 <- ggplot(prop3, aes(p_hat_multinom, fill = Decision)) +
  geom_density(alpha = 0.50, colour = NA) +
  scale_fill_manual(values = decision_cols) +
  labs(title = 'Propensity by the decision actually taken',
       subtitle = sprintf('In-range plays, n = %s. Punts and go-for-its also separate from each other.',
                          scales::comma(nrow(prop3))),
       x = expression(hat(pi)(x) * ' -- P(attempt FG | context)'),
       y = 'Density', fill = NULL) +
  theme_slide() + theme(legend.position = 'top')

save_slide(p_prop3, 'propensity_density_three_way.png', w = 12.5, h = 6.6)


# ============================================================
# 15. BACKUP -- WPA by regime and era, four panels  (appendix A12)
# ============================================================
# Guards against "is the WPA landscape itself a post-2020 artifact?". If the
# curves hold their shape across eras, the closing argument does not depend on
# the era split.
message('\n[15/15] BACKUP WPA by regime and era')

wpa_4 <- wpa_ytg %>%
  filter(season >= 2015) %>%
  mutate(Era = dplyr::case_when(season %in% 2015:2019 ~ '2015-2019',
                                season %in% 2020:2025 ~ '2020-2025',
                                TRUE ~ NA_character_)) %>%
  filter(!is.na(Era))

p_wpa4 <- ggplot(wpa_4, aes(yardline_100, wpa, colour = Decision, fill = Decision)) +
  geom_hline(yintercept = 0, colour = 'grey55', linetype = 'dashed', linewidth = 0.7) +
  geom_smooth(method = 'loess', formula = y ~ x, se = TRUE, alpha = 0.10,
              span = 0.6, linewidth = 1.3) +
  facet_grid(Era ~ ytg_regime) +
  scale_colour_manual(values = decision_cols) +
  scale_fill_manual(values = decision_cols) +
  scale_x_continuous(breaks = seq(0, 55, 10)) +
  labs(title = 'The WPA landscape holds its shape across eras',
       subtitle = 'WPA by decision, field position, yards-to-go regime and era.',
       x = 'Yards from end zone', y = 'WPA', colour = NULL, fill = NULL) +
  theme_slide() + theme(legend.position = 'top')

save_slide(p_wpa4, 'wpa_by_regime_era.png', w = 14.5, h = 9.0, dpi = 160)


# ============================================================
# 16. Appendix-only figures, copied from the manuscript build
# ============================================================
# A8, A9 and A11 need figures that exist only at manuscript scale. They are
# COPIED rather than rebuilt, and that is deliberate: a 9-inch manuscript figure
# shown full-slide is scaled up bodily, so its type grows with it and ends up
# LARGER relative to the canvas than a purpose-built 15-inch slide figure at the
# same point size. Rebuilding them would be work with no legibility gain.
#
# They are copied into Presentation/figures/ rather than referenced across the
# repo so the deck stays self-contained: notebook 05 wipes and rebuilds
# reports/figures/ wholesale, and a deck reaching into that directory would
# break silently between a notebook run and a render.
message('\n[16/17] appendix figures copied from reports/figures')

# The two weather figures used to be copied from reports/figures/ too, but
# at the manuscript's 2.62 aspect ratio they rendered 305px tall in A9's
# 50% columns -- the emptiest slide in the deck at 53% fill. They are now
# built at slide scale in block 17 and get one appendix slide each.
appendix_copies <- c('m2_weight_sensitivity.png',
                     'separation_density.png')

for (f in appendix_copies) {
  src <- file.path(reports_dir, 'figures', f)
  if (!file.exists(src)) {
    warning('missing appendix figure, run notebook 05 first: ', f)
    next
  }
  file.copy(src, file.path(slide_figs, f), overwrite = TRUE)
  message('  copied: ', f, '  (', round(file.size(src) / 1024), ' KB)')
}


# ============================================================
# 17. Weather covariates at slide scale  (paper Fig A9) -- appendix A9a / A9b
# ============================================================
# Mirrors notebook 05 cell 17, but at a slide aspect ratio and on theme_slide().
# The manuscript keeps its own 11x4.2 versions; these are deck-only.
message('\n[17/17] weather covariate panels (A9a, A9b)')

weather_long <- preds_is %>%
  filter(!is.na(kick_made)) %>%
  select(kick_made, kick_distance, wind, temp, humidity) %>%
  pivot_longer(c(wind, temp, humidity), names_to = 'var', values_to = 'value') %>%
  filter(!is.na(value)) %>%
  mutate(var = recode(var,
                      wind     = 'Wind speed (mph)',
                      temp     = 'Temperature (F)',
                      humidity = 'Relative humidity (%)'))

# ntile() rather than cut_number(): temperature and humidity carry heavy ties
# from the indoor/imputed values, and quantile cutting cannot form distinct
# breaks when one value spans a bin boundary.
weather_pts <- weather_long %>%
  group_by(var) %>%
  mutate(bin = ntile(value, 8)) %>%
  group_by(var, bin) %>%
  summarise(x = mean(value), obs = mean(kick_made),
            k = sum(kick_made), n = n(), .groups = 'drop') %>%
  bind_cols(wilson_ci(.$k, .$n))

p_weather_raw <- ggplot(weather_long, aes(value, kick_made)) +
  geom_smooth(method = 'loess', formula = y ~ x, se = TRUE,
              colour = '#0072B2', fill = '#0072B2', alpha = 0.15, linewidth = 1.2) +
  geom_errorbar(data = weather_pts, aes(x = x, y = obs, ymin = lo, ymax = hi),
                width = 0, colour = '#D55E00', linewidth = 0.7, inherit.aes = FALSE) +
  geom_point(data = weather_pts, aes(x = x, y = obs, size = n),
             colour = '#D55E00', inherit.aes = FALSE) +
  scale_size_continuous(range = c(1.8, 5.0), guide = 'none') +
  facet_wrap(~ var, scales = 'free_x', nrow = 1) +
  coord_cartesian(ylim = c(0.6, 1)) +
  labs(title = 'Raw make rate against the weather covariates',
       subtitle = 'Orange: equal-count bins, 95% Wilson. Blue: LOESS. Not adjusted for distance.',
       x = NULL, y = 'Observed make rate') +
  theme_slide()

save_slide(p_weather_raw, 'weather_make_rate_raw.png', w = 14.5, h = 7.2, dpi = 160)

p_weather_band <- weather_long %>%
  filter(kick_distance >= 40, kick_distance < 55) %>%
  ggplot(aes(value, kick_made)) +
  geom_smooth(method = 'loess', formula = y ~ x, se = TRUE,
              colour = '#009E73', fill = '#009E73', alpha = 0.15, linewidth = 1.2) +
  facet_wrap(~ var, scales = 'free_x', nrow = 1) +
  coord_cartesian(ylim = c(0.5, 1)) +
  labs(title = 'The same covariates, holding distance roughly fixed',
       subtitle = '40-54 yard attempts only. Removes the distance mix that confounds the panel above.',
       x = NULL, y = 'Observed make rate') +
  theme_slide()

save_slide(p_weather_band, 'weather_make_rate_40_54.png', w = 14.5, h = 7.2, dpi = 160)


message('\nDone. ', length(list.files(slide_figs, pattern = '[.]png$')),
        ' figures in ', slide_figs)
