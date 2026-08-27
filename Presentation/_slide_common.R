# ============================================================
# Shared setup for the conference deck's figures.
#
# Sourced by make_slide_figures.R. Kept separate so the data-loading and
# theme definitions can be re-used without re-running the whole figure build.
#
# This file deliberately does NOT touch reports/figures/. Slide figures are a
# separate design target from the paper figures -- larger type, 16:9 canvas --
# and are written to Presentation/figures/ only. Notebook 05 remains the
# canonical source for everything the manuscript renders.
# ============================================================

suppressPackageStartupMessages({
  library(dplyr); library(tibble); library(tidyr); library(readr)
  library(stringr); library(purrr); library(ggplot2); library(scales)
  library(patchwork)
})

get_project_root <- function() {
  cwd <- getwd()
  if (basename(cwd) == 'Presentation') return(dirname(cwd))
  if (dir.exists(file.path(cwd, 'Presentation'))) return(cwd)
  stop('Run from the repo root or from Presentation/.')
}
PROJECT_ROOT <- get_project_root()

data_dir    <- file.path(PROJECT_ROOT, 'data')
reports_dir <- file.path(PROJECT_ROOT, 'reports')
slide_figs  <- file.path(PROJECT_ROOT, 'Presentation', 'figures')
dir.create(slide_figs, recursive = TRUE, showWarnings = FALSE)

EVAL_SEASON_MIN <- 2015L
EVAL_SEASON_MAX <- 2025L

# ------------------------------------------------------------
# Theme: theme_paper() scaled up for projection
# ------------------------------------------------------------
# theme_paper() targets an 11pt manuscript figure printed at ~4 inches wide.
# A slide is read from 30 feet. Everything below is the same theme with the
# type scale lifted; the title gets the largest lift because that is the one
# line the audience reads before the presenter starts talking.
SLIDE_BASE <- 16

theme_paper <- function(base_size = 11) {
  ggplot2::theme_minimal(base_size = base_size) +
    ggplot2::theme(
      panel.grid.major = ggplot2::element_blank(),
      panel.grid.minor = ggplot2::element_blank(),
      panel.border = ggplot2::element_rect(fill = NA, colour = 'grey80', linewidth = 0.5),
      axis.line = ggplot2::element_line(colour = 'grey45', linewidth = 0.3),
      strip.background = ggplot2::element_rect(fill = 'grey95', colour = 'grey80', linewidth = 0.4),
      strip.text = ggplot2::element_text(face = 'bold', colour = 'grey25'),
      legend.position = 'bottom',
      legend.key = ggplot2::element_blank(),
      plot.title = ggplot2::element_text(face = 'bold', size = base_size + 2),
      plot.subtitle = ggplot2::element_text(colour = 'grey35', size = base_size),
      axis.title = ggplot2::element_text(size = base_size)
    )
}

theme_slide <- function(base_size = SLIDE_BASE) {
  theme_paper(base_size) +
    theme(
      plot.title      = element_text(face = 'bold', size = base_size + 11, colour = 'grey15'),
      plot.subtitle   = element_text(colour = 'grey35', size = base_size + 3),
      plot.title.position = 'plot',
      axis.title      = element_text(size = base_size + 1),
      axis.text       = element_text(size = base_size, colour = 'grey30'),
      strip.text      = element_text(face = 'bold', colour = 'grey25', size = base_size + 2),
      legend.text     = element_text(size = base_size + 3),
      legend.title    = element_text(size = base_size + 3),
      plot.margin     = margin(10, 14, 8, 10)
    )
}

# Panels inside a multi-panel dashboard get roughly a third of the canvas each,
# so they need the title lift without the subtitle lift -- a full-width subtitle
# on a one-third-width panel runs straight over its neighbour.
theme_slide_panel <- function(base_size = SLIDE_BASE) {
  theme_slide(base_size) +
    theme(
      plot.title          = element_text(face = 'bold', size = base_size + 5, colour = 'grey15'),
      plot.subtitle       = element_text(colour = 'grey40', size = base_size - 2),
      plot.title.position = 'panel'
    )
}

# Hard-wrap panel subtitles so they break instead of overflowing.
wrap_sub <- function(x, width = 46) paste(strwrap(x, width = width), collapse = '\n')

# patchwork's plot_annotation() does not inherit a plot theme, so the dashboard
# supertitles need their own. One step above the panel titles.
slide_annotation <- function() {
  theme(
    plot.title    = element_text(face = 'bold', size = SLIDE_BASE + 15, colour = 'grey15'),
    plot.subtitle = element_text(colour = 'grey35', size = SLIDE_BASE + 5),
    plot.margin   = margin(10, 14, 8, 10)
  )
}

# 16:9-friendly defaults. dpi 180 keeps a 13in-wide figure under ~1 MB while
# still resolving cleanly on a conference projector.
save_slide <- function(p, fname, w = 12.0, h = 6.2, dpi = 180) {
  path <- file.path(slide_figs, fname)
  ggplot2::ggsave(path, plot = p, width = w, height = h, dpi = dpi, bg = 'white')
  message('  saved: ', fname, '  (', round(file.size(path) / 1024), ' KB)')
  invisible(path)
}

# ------------------------------------------------------------
# Colour palettes -- mirrored from notebook 05 cell 2.
# Colour must follow the model across paper and deck alike, so a viewer who
# learns "M3 is the reddish-purple line" carries it between the two.
# ------------------------------------------------------------
model_cols <- c('M0' = '#525252', 'M1' = '#0072B2', 'M2' = '#D55E00', 'M3' = '#CC79A7')
cols_model_long <- setNames(
  unname(model_cols[c('M0', 'M1', 'M2', 'M3')]),
  c('M0 (Distance Only)', 'M1 (Baseline)', 'M2 (Augmented)', 'M3 (IPW-weighted)'))
decision_cols <- c('FG' = '#0072B2', 'Punt' = '#525252', 'Go for It' = '#D55E00',
                   'Field Goal' = '#0072B2', 'FG Attempted' = '#0072B2',
                   'go_for_it' = '#D55E00', 'punt' = '#525252')
outcome_cols  <- c('Made' = '#0072B2', 'Missed' = '#D55E00')
accent_green  <- '#009E73'
accent_gold   <- '#E69F00'

# ------------------------------------------------------------
# Data
# ------------------------------------------------------------
message('Loading data ...')

preds <- readr::read_csv(file.path(reports_dir, 'xfg_success', 'fg_full_with_predictions.csv'),
                         show_col_types = FALSE)
fg_all <- readr::read_csv(file.path(data_dir, 'fg_all.csv'), show_col_types = FALSE)
preds_pi <- readr::read_csv(file.path(reports_dir, 'attempt_pi', 'attempt_pi_oof_predictions_final.csv'),
                            show_col_types = FALSE)

test_game_ids <- readr::read_csv(
  file.path(data_dir, 'augmented',
            sprintf('test_fg_game_ids_%d_%d.csv', EVAL_SEASON_MIN, EVAL_SEASON_MAX)),
  show_col_types = FALSE)$game_id

preds <- preds %>% mutate(split = if_else(game_id %in% test_game_ids, 'test', 'train'))

preds_is    <- preds
preds_test  <- preds %>% filter(split == 'test')
preds_train <- preds %>% filter(split == 'train')
y_is        <- preds_is$kick_made
y_test      <- preds_test$kick_made

# Fourth-down decision frame (mirrors notebook 05 cell 3)
pi_metrics <- readr::read_csv(
  file.path(reports_dir, 'attempt_pi', 'attempt_pi_metrics_by_season.csv'),
  show_col_types = FALSE)

# Plays inside plausible kicking range: yardline_100 <= 53 is exactly a 70-yard
# attempt, the outer edge of the outcome model's distance basis. This is the
# restriction behind the in-range AUC column the selection argument rests on.
IN_RANGE_YL <- 53L
AUC_IN_RANGE <- range(pi_metrics$auc_in_range, na.rm = TRUE)

decision <- fg_all %>%
  filter(is_pat == 0L,
         play_type_original %in% c('field_goal', 'pass', 'run', 'punt'),
         !is.na(ydstogo), ydstogo >= 1) %>%
  mutate(action = dplyr::case_when(
    play_type_original == 'field_goal' ~ 'FG',
    play_type_original == 'punt'       ~ 'punt',
    TRUE                               ~ 'go_for_it'))

message('  analysis attempts: ', nrow(preds_is),
        ' | train: ', nrow(preds_train), ' | test: ', nrow(preds_test))
