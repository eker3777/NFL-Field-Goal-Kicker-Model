---
jupyter:
  kernelspec:
    display_name: R
    language: R
    name: ir
  language_info:
    codemirror_mode: r
    file_extension: .r
    mimetype: text/x-r-source
    name: R
    pygments_lexer: r
    version: 3.13.9
  nbformat: 4
  nbformat_minor: 5
---

::: {.cell .markdown}
# 01 · Data Preparation {#01--data-preparation}

**Purpose:** Carry forward and modernize data preparation from the
legacy notebooks.

**Inputs:** Reference/pbp_head.csv, Reference/fg_attempts_sample.csv

**Outputs:** reports/data_prep_schema_preview.csv

**Sections:**

-   [Parameters & Modes](#parameters--modes)
-   [Imports](#imports--install-if-missing)
-   [Utilities & Helpers](#utilities--helpers)
-   [Data Load & Peek](#data-load--peek)
-   [Stage Logic](#stage-logic)
-   [Artifacts](#artifacts)
-   [Session Info](#session-info)
:::

::: {.cell .code vscode="{\"languageId\":\"r\"}"}
``` R
# Parameters & Modes

PROJECT_ROOT <- normalizePath('G:/My files/Python/Sports Analytics Projects/Football/Kickers/NFL-Field-Goal-Kicker-Model', winslash = '\\', mustWork = FALSE)
reference_dir <- file.path(PROJECT_ROOT, 'Reference')
pbp_data_dir <- 'G:\\Python\\Data\\NFL'
data_dir <- file.path(PROJECT_ROOT, 'data')
leverage_dir <- file.path(PROJECT_ROOT,'data','leverage')
reports_dir <- file.path(PROJECT_ROOT, 'reports')
config_path <- file.path(PROJECT_ROOT, 'config', 'params.yaml')

SEASONS <- 2012:2024

default_params <- list(
  time_knots = c(60, 120, 300),
  late_flags = c(120, 60),
  p_clip_min = 0.05,
  p_clip_max = 0.98,
  kickable_cap_modeling = 65,
  kickable_cap_audit = 50,
  tau_grid = c(0.03, 0.05, 0.07, 0.10),
  df_distance = 5,
  df_yardline = 5,
  df_yards_to_go = 5
)

params <- default_params

if (file.exists(config_path)) {
  tryCatch({
    config_values <- yaml::read_yaml(config_path)
    params <- utils::modifyList(params, config_values, keep.null = TRUE)
  }, error = function(e) message('Config read failed, using defaults: ', e$message))
}

print(PROJECT_ROOT)
print(data_dir)
set.seed(20240517)
```

::: {.output .stream .stdout}
    [1] "G:\\My files\\Python\\Sports Analytics Projects\\Football\\Kickers\\NFL-Field-Goal-Kicker-Model"
    [1] "G:\\My files\\Python\\Sports Analytics Projects\\Football\\Kickers\\NFL-Field-Goal-Kicker-Model/data"
    [1] "G:\\My files\\Python\\Sports Analytics Projects\\Football\\Kickers\\NFL-Field-Goal-Kicker-Model/data"
:::
:::

::: {.cell .code vscode="{\"languageId\":\"r\"}"}
``` R
# Imports — install if missing

dependencies <- c(
  'dplyr', 'tibble', 'tidyr', 'readr', 'stringr', 'purrr', 'ggplot2',
  'mgcv', 'splines', 'glmmTMB', 'pROC', 'yaml', 'rlang',
  'forcats', 'lubridate', 'nflreadr', 'glue'
 )

installed <- rownames(installed.packages())

for (pkg in dependencies) {
  if (!pkg %in% installed) {
    install.packages(pkg)
  }
  suppressPackageStartupMessages(library(pkg, character.only = TRUE))
}
```
:::

::: {.cell .markdown}
### Function Index

-   `get_schema()` --- quick schema preview of a data frame.
-   `ensure_columns()` --- add defaulted columns when missing.
-   `add_time_features()` --- derive common time and score features.
-   `clip_probabilities()` --- constrain probabilities to \[min, max\].
-   `stabilize_weights()` --- compute stabilized weights with optional
    grouping.
-   `effective_sample_size()` --- calculate ESS from weights.
-   `calibration_summary()` --- summarize calibration by bins.
-   `plot_calibration()` --- simple calibration scatter + smoother.
:::

::: {.cell .code vscode="{\"languageId\":\"r\"}"}
``` R
# # Data Load
# pbp_path <- file.path(pbp_data_dir, 'pbp_2000_2024_clean.csv')
# fg_path <- file.path(fg_data_dir, 'fg_attempts.csv')

# #Load if file exits, if not return error
# if (file.exists(pbp_path)) {
#   pbp <- readr::read_csv(pbp_path, guess_max = 10000, show_col_types = FALSE)
# } else {
#   stop(glue("File {pbp_path} does not exist. Please download the data first."))
# }

# pbp %>%
#   write_rds(file.path(pbp_data_dir, "pbp.rds"))
```
:::

::: {#cfe7908f .cell .code vscode="{\"languageId\":\"r\"}"}
``` R
# Data Load
pbp_path <- file.path(pbp_data_dir, 'pbp.rds')
fg_path <- file.path(data_dir, 'fg_attempts.csv')

pbp <- readr::read_rds(pbp_path)
fg_attempts <- if (file.exists(fg_path)) readr::read_csv(fg_path, show_col_types = FALSE) else NULL

if (SMOKE_MODE) {
  pbp <- pbp %>% dplyr::slice_head(n = min(1000, nrow(pbp)))
  if (!is.null(fg_attempts)) {
    fg_attempts <- fg_attempts %>% dplyr::slice_head(n = min(500, nrow(fg_attempts)))
  }
}

#Filter for 2015 - 2024
pbp <- pbp %>% filter(season %in% SEASONS)


glimpse(pbp)
```

::: {.output .stream .stdout}
    Rows: 627,226
    Columns: 372
    $ play_id                              <dbl> 1, 35, 53, 74, 95, 119, 143, 165,…
    $ game_id                              <chr> "2012_01_ATL_KC", "2012_01_ATL_KC…
    $ old_game_id                          <dbl> 2012090908, 2012090908, 201209090…
    $ home_team                            <chr> "KC", "KC", "KC", "KC", "KC", "KC…
    $ away_team                            <chr> "ATL", "ATL", "ATL", "ATL", "ATL"…
    $ season_type                          <chr> "REG", "REG", "REG", "REG", "REG"…
    $ week                                 <dbl> 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, …
    $ posteam                              <chr> NA, "ATL", "ATL", "ATL", "ATL", "…
    $ posteam_type                         <chr> NA, "away", "away", "away", "away…
    $ defteam                              <chr> NA, "KC", "KC", "KC", "KC", "KC",…
    $ side_of_field                        <chr> NA, "KC", "ATL", "ATL", "ATL", "A…
    $ yardline_100                         <dbl> NA, 35, 80, 74, 72, 69, 44, 44, 4…
    $ game_date                            <date> 2012-09-09, 2012-09-09, 2012-09-…
    $ quarter_seconds_remaining            <dbl> 900, 900, 900, 862, 821, 781, 746…
    $ half_seconds_remaining               <dbl> 1800, 1800, 1800, 1762, 1721, 168…
    $ game_seconds_remaining               <dbl> 3600, 3600, 3600, 3562, 3521, 348…
    $ game_half                            <chr> "Half1", "Half1", "Half1", "Half1…
    $ quarter_end                          <dbl> 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, …
    $ drive                                <dbl> NA, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1,…
    $ sp                                   <dbl> 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, …
    $ qtr                                  <dbl> 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, …
    $ down                                 <dbl> NA, NA, 1, 2, 3, 1, 1, 2, 3, 1, 2…
    $ goal_to_go                           <dbl> 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, …
    $ time                                 <time> 15:00:00, 15:00:00, 15:00:00, 14…
    $ yrdln                                <chr> "KC 35", "KC 35", "ATL 20", "ATL …
    $ ydstogo                              <dbl> 0, 0, 10, 4, 2, 10, 10, 10, 8, 10…
    $ ydsnet                               <dbl> NA, 80, 80, 80, 80, 80, 80, 80, 8…
    $ desc                                 <chr> "GAME", "6-R.Succop kicks 65 yard…
    $ play_type                            <chr> NA, "kickoff", "run", "run", "pas…
    $ yards_gained                         <dbl> NA, 0, 6, 2, 3, 25, 0, 2, 11, 0, …
    $ shotgun                              <dbl> 0, 0, 0, 0, 1, 0, 0, 0, 1, 0, 0, …
    $ no_huddle                            <dbl> 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, …
    $ qb_dropback                          <dbl> NA, 0, 0, 0, 1, 1, 1, 0, 1, 1, 1,…
    $ qb_kneel                             <dbl> 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, …
    $ qb_spike                             <dbl> 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, …
    $ qb_scramble                          <dbl> 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, …
    $ pass_length                          <chr> NA, NA, NA, NA, "short", "short",…
    $ pass_location                        <chr> NA, NA, NA, NA, "right", "middle"…
    $ air_yards                            <dbl> NA, NA, NA, NA, 2, 14, 15, NA, 6,…
    $ yards_after_catch                    <dbl> NA, NA, NA, NA, 1, 11, NA, NA, 5,…
    $ run_location                         <chr> NA, NA, "right", "middle", NA, NA…
    $ run_gap                              <chr> NA, NA, "guard", NA, NA, NA, NA, …
    $ field_goal_result                    <chr> NA, NA, NA, NA, NA, NA, NA, NA, N…
    $ kick_distance                        <dbl> NA, 65, NA, NA, NA, NA, NA, NA, N…
    $ extra_point_result                   <chr> NA, NA, NA, NA, NA, NA, NA, NA, N…
    $ two_point_conv_result                <chr> NA, NA, NA, NA, NA, NA, NA, NA, N…
    $ home_timeouts_remaining              <dbl> 3, 3, 3, 3, 3, 3, 3, 3, 3, 3, 3, …
    $ away_timeouts_remaining              <dbl> 3, 3, 3, 3, 3, 3, 3, 3, 3, 3, 3, …
    $ timeout                              <dbl> NA, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,…
    $ timeout_team                         <chr> NA, NA, NA, NA, NA, NA, NA, NA, N…
    $ td_team                              <chr> NA, NA, NA, NA, NA, NA, NA, NA, N…
    $ td_player_name                       <chr> NA, NA, NA, NA, NA, NA, NA, NA, N…
    $ td_player_id                         <chr> NA, NA, NA, NA, NA, NA, NA, NA, N…
    $ posteam_timeouts_remaining           <dbl> NA, 3, 3, 3, 3, 3, 3, 3, 3, 3, 3,…
    $ defteam_timeouts_remaining           <dbl> NA, 3, 3, 3, 3, 3, 3, 3, 3, 3, 3,…
    $ total_home_score                     <dbl> 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, …
    $ total_away_score                     <dbl> 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, …
    $ posteam_score                        <dbl> NA, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,…
    $ defteam_score                        <dbl> NA, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,…
    $ score_differential                   <dbl> NA, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,…
    $ posteam_score_post                   <dbl> NA, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,…
    $ defteam_score_post                   <dbl> NA, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,…
    $ score_differential_post              <dbl> NA, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,…
    $ no_score_prob                        <dbl> 0.000000000, 0.006326471, 0.00632…
    $ opp_fg_prob                          <dbl> 0.00000000, 0.18425368, 0.1842536…
    $ opp_safety_prob                      <dbl> 0.0000000000, 0.0047913706, 0.004…
    $ opp_td_prob                          <dbl> 0.00000000, 0.30240622, 0.3024062…
    $ fg_prob                              <dbl> 0.0000000, 0.2025459, 0.2025459, …
    $ safety_prob                          <dbl> 0.000000000, 0.003165345, 0.00316…
    $ td_prob                              <dbl> 0.0000000, 0.2965110, 0.2965110, …
    $ extra_point_prob                     <dbl> 0.0000000, 0.0000000, 0.0000000, …
    $ two_point_conversion_prob            <dbl> 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, …
    $ ep                                   <dbl> 0.01035813, 0.01035813, 0.0103581…
    $ epa                                  <dbl> 0.00000000, 0.00000000, 0.3797030…
    $ total_home_epa                       <dbl> 0.0000000, 0.0000000, -0.3797030,…
    $ total_away_epa                       <dbl> 0.0000000, 0.0000000, 0.3797030, …
    $ total_home_rush_epa                  <dbl> 0.00000000, 0.00000000, -0.379703…
    $ total_away_rush_epa                  <dbl> 0.00000000, 0.00000000, 0.3797030…
    $ total_home_pass_epa                  <dbl> 0.000000, 0.000000, 0.000000, 0.0…
    $ total_away_pass_epa                  <dbl> 0.000000, 0.000000, 0.000000, 0.0…
    $ air_epa                              <dbl> NA, NA, NA, NA, 0.7958058, 0.9528…
    $ yac_epa                              <dbl> NA, NA, NA, NA, 0.1013802, 0.8104…
    $ comp_air_epa                         <dbl> NA, 0.0000000, 0.0000000, 0.00000…
    $ comp_yac_epa                         <dbl> NA, 0.0000000, 0.0000000, 0.00000…
    $ total_home_comp_air_epa              <dbl> 0.0000000, 0.0000000, 0.0000000, …
    $ total_away_comp_air_epa              <dbl> 0.0000000, 0.0000000, 0.0000000, …
    $ total_home_comp_yac_epa              <dbl> 0.0000000, 0.0000000, 0.0000000, …
    $ total_away_comp_yac_epa              <dbl> 0.0000000, 0.0000000, 0.0000000, …
    $ total_home_raw_air_epa               <dbl> 0.0000000, 0.0000000, 0.0000000, …
    $ total_away_raw_air_epa               <dbl> 0.0000000, 0.0000000, 0.0000000, …
    $ total_home_raw_yac_epa               <dbl> 0.00000000, 0.00000000, 0.0000000…
    $ total_away_raw_yac_epa               <dbl> 0.00000000, 0.00000000, 0.0000000…
    $ wp                                   <dbl> 0.4220242, 0.4220242, 0.4220242, …
    $ def_wp                               <dbl> 0.5779758, 0.5779758, 0.5779758, …
    $ home_wp                              <dbl> 0.5779758, 0.5779758, 0.5779758, …
    $ away_wp                              <dbl> 0.4220242, 0.4220242, 0.4220242, …
    $ wpa                                  <dbl> 0.000000000, 0.000000000, 0.00328…
    $ vegas_wpa                            <dbl> 0.0000000000, 0.0000000000, 0.002…
    $ vegas_home_wpa                       <dbl> 0.0000000000, 0.0000000000, -0.00…
    $ home_wp_post                         <dbl> NA, 0.5779758, 0.5746871, 0.58511…
    $ away_wp_post                         <dbl> NA, 0.4220242, 0.4253129, 0.41488…
    $ vegas_wp                             <dbl> 0.5396563, 0.5396563, 0.5396563, …
    $ vegas_home_wp                        <dbl> 0.4603437, 0.4603437, 0.4603437, …
    $ total_home_rush_wpa                  <dbl> 0.000000000, 0.000000000, -0.0032…
    $ total_away_rush_wpa                  <dbl> 0.000000000, 0.000000000, 0.00328…
    $ total_home_pass_wpa                  <dbl> 0.00000000, 0.00000000, 0.0000000…
    $ total_away_pass_wpa                  <dbl> 0.00000000, 0.00000000, 0.0000000…
    $ air_wpa                              <dbl> NA, NA, NA, NA, 0.00000000, 0.000…
    $ yac_wpa                              <dbl> NA, NA, NA, NA, 0.01866183, 0.046…
    $ comp_air_wpa                         <dbl> NA, 0.00000000, 0.00000000, 0.000…
    $ comp_yac_wpa                         <dbl> NA, 0.00000000, 0.00000000, 0.000…
    $ total_home_comp_air_wpa              <dbl> 0.00000000, 0.00000000, 0.0000000…
    $ total_away_comp_air_wpa              <dbl> 0.00000000, 0.00000000, 0.0000000…
    $ total_home_comp_yac_wpa              <dbl> 0.00000000, 0.00000000, 0.0000000…
    $ total_away_comp_yac_wpa              <dbl> 0.00000000, 0.00000000, 0.0000000…
    $ total_home_raw_air_wpa               <dbl> 0.00000000, 0.00000000, 0.0000000…
    $ total_away_raw_air_wpa               <dbl> 0.00000000, 0.00000000, 0.0000000…
    $ total_home_raw_yac_wpa               <dbl> 0.00000000, 0.00000000, 0.0000000…
    $ total_away_raw_yac_wpa               <dbl> 0.00000000, 0.00000000, 0.0000000…
    $ punt_blocked                         <dbl> NA, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,…
    $ first_down_rush                      <dbl> NA, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,…
    $ first_down_pass                      <dbl> NA, 0, 0, 0, 1, 1, 0, 0, 1, 0, 1,…
    $ first_down_penalty                   <dbl> NA, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,…
    $ third_down_converted                 <dbl> NA, 0, 0, 0, 1, 0, 0, 0, 1, 0, 0,…
    $ third_down_failed                    <dbl> NA, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,…
    $ fourth_down_converted                <dbl> NA, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,…
    $ fourth_down_failed                   <dbl> NA, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,…
    $ incomplete_pass                      <dbl> NA, 0, 0, 0, 0, 0, 1, 0, 0, 1, 0,…
    $ touchback                            <dbl> 0, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, …
    $ interception                         <dbl> NA, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,…
    $ punt_inside_twenty                   <dbl> NA, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,…
    $ punt_in_endzone                      <dbl> NA, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,…
    $ punt_out_of_bounds                   <dbl> NA, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,…
    $ punt_downed                          <dbl> NA, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,…
    $ punt_fair_catch                      <dbl> NA, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,…
    $ kickoff_inside_twenty                <dbl> NA, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,…
    $ kickoff_in_endzone                   <dbl> NA, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,…
    $ kickoff_out_of_bounds                <dbl> NA, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,…
    $ kickoff_downed                       <dbl> NA, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,…
    $ kickoff_fair_catch                   <dbl> NA, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,…
    $ fumble_forced                        <dbl> NA, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,…
    $ fumble_not_forced                    <dbl> NA, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,…
    $ fumble_out_of_bounds                 <dbl> NA, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,…
    $ solo_tackle                          <dbl> NA, 0, 1, 1, 1, 1, 0, 1, 1, 0, 1,…
    $ safety                               <dbl> NA, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,…
    $ penalty                              <dbl> NA, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,…
    $ tackled_for_loss                     <dbl> NA, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,…
    $ fumble_lost                          <dbl> NA, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,…
    $ own_kickoff_recovery                 <dbl> NA, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,…
    $ own_kickoff_recovery_td              <dbl> NA, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,…
    $ qb_hit                               <dbl> NA, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,…
    $ rush_attempt                         <dbl> NA, 0, 1, 1, 0, 0, 0, 1, 0, 0, 0,…
    $ pass_attempt                         <dbl> NA, 0, 0, 0, 1, 1, 1, 0, 1, 1, 1,…
    $ sack                                 <dbl> NA, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,…
    $ touchdown                            <dbl> NA, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,…
    $ pass_touchdown                       <dbl> NA, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,…
    $ rush_touchdown                       <dbl> NA, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,…
    $ return_touchdown                     <dbl> NA, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,…
    $ extra_point_attempt                  <dbl> NA, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,…
    $ two_point_attempt                    <dbl> NA, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,…
    $ field_goal_attempt                   <dbl> NA, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,…
    $ kickoff_attempt                      <dbl> NA, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0,…
    $ punt_attempt                         <dbl> NA, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,…
    $ fumble                               <dbl> NA, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,…
    $ complete_pass                        <dbl> NA, 0, 0, 0, 1, 1, 0, 0, 1, 0, 1,…
    $ assist_tackle                        <dbl> NA, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,…
    $ lateral_reception                    <dbl> NA, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,…
    $ lateral_rush                         <dbl> NA, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,…
    $ lateral_return                       <dbl> NA, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,…
    $ lateral_recovery                     <dbl> NA, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,…
    $ passer_player_id                     <chr> NA, NA, NA, NA, "00-0026143", "00…
    $ passer_player_name                   <chr> NA, NA, NA, NA, "M.Ryan", "M.Ryan…
    $ passing_yards                        <dbl> NA, NA, NA, NA, 3, 25, NA, NA, 11…
    $ receiver_player_id                   <chr> NA, NA, NA, NA, "00-0006101", "00…
    $ receiver_player_name                 <chr> NA, NA, NA, NA, "T.Gonzalez", "J.…
    $ receiving_yards                      <dbl> NA, NA, NA, NA, 3, 25, NA, NA, 11…
    $ rusher_player_id                     <chr> NA, NA, "00-0022821", "00-0022821…
    $ rusher_player_name                   <chr> NA, NA, "M.Turner", "M.Turner", N…
    $ rushing_yards                        <dbl> NA, NA, 6, 2, NA, NA, NA, 2, NA, …
    $ lateral_receiver_player_id           <chr> NA, NA, NA, NA, NA, NA, NA, NA, N…
    $ lateral_receiver_player_name         <chr> NA, NA, NA, NA, NA, NA, NA, NA, N…
    $ lateral_receiving_yards              <dbl> NA, NA, NA, NA, NA, NA, NA, NA, N…
    $ lateral_rusher_player_id             <chr> NA, NA, NA, NA, NA, NA, NA, NA, N…
    $ lateral_rusher_player_name           <chr> NA, NA, NA, NA, NA, NA, NA, NA, N…
    $ lateral_rushing_yards                <dbl> NA, NA, NA, NA, NA, NA, NA, NA, N…
    $ lateral_sack_player_id               <lgl> NA, NA, NA, NA, NA, NA, NA, NA, N…
    $ lateral_sack_player_name             <lgl> NA, NA, NA, NA, NA, NA, NA, NA, N…
    $ interception_player_id               <chr> NA, NA, NA, NA, NA, NA, NA, NA, N…
    $ interception_player_name             <chr> NA, NA, NA, NA, NA, NA, NA, NA, N…
    $ lateral_interception_player_id       <lgl> NA, NA, NA, NA, NA, NA, NA, NA, N…
    $ lateral_interception_player_name     <lgl> NA, NA, NA, NA, NA, NA, NA, NA, N…
    $ punt_returner_player_id              <chr> NA, NA, NA, NA, NA, NA, NA, NA, N…
    $ punt_returner_player_name            <chr> NA, NA, NA, NA, NA, NA, NA, NA, N…
    $ lateral_punt_returner_player_id      <lgl> NA, NA, NA, NA, NA, NA, NA, NA, N…
    $ lateral_punt_returner_player_name    <lgl> NA, NA, NA, NA, NA, NA, NA, NA, N…
    $ kickoff_returner_player_name         <chr> NA, NA, NA, NA, NA, NA, NA, NA, N…
    $ kickoff_returner_player_id           <chr> NA, NA, NA, NA, NA, NA, NA, NA, N…
    $ lateral_kickoff_returner_player_id   <lgl> NA, NA, NA, NA, NA, NA, NA, NA, N…
    $ lateral_kickoff_returner_player_name <lgl> NA, NA, NA, NA, NA, NA, NA, NA, N…
    $ punter_player_id                     <chr> NA, NA, NA, NA, NA, NA, NA, NA, N…
    $ punter_player_name                   <chr> NA, NA, NA, NA, NA, NA, NA, NA, N…
    $ kicker_player_name                   <chr> NA, "R.Succop", NA, NA, NA, NA, N…
    $ kicker_player_id                     <chr> NA, "00-0026968", NA, NA, NA, NA,…
    $ own_kickoff_recovery_player_id       <lgl> NA, NA, NA, NA, NA, NA, NA, NA, N…
    $ own_kickoff_recovery_player_name     <lgl> NA, NA, NA, NA, NA, NA, NA, NA, N…
    $ blocked_player_id                    <chr> NA, NA, NA, NA, NA, NA, NA, NA, N…
    $ blocked_player_name                  <chr> NA, NA, NA, NA, NA, NA, NA, NA, N…
    $ tackle_for_loss_1_player_id          <chr> NA, NA, NA, NA, NA, NA, NA, NA, N…
    $ tackle_for_loss_1_player_name        <chr> NA, NA, NA, NA, NA, NA, NA, NA, N…
    $ tackle_for_loss_2_player_id          <chr> NA, NA, NA, NA, NA, NA, NA, NA, N…
    $ tackle_for_loss_2_player_name        <chr> NA, NA, NA, NA, NA, NA, NA, NA, N…
    $ qb_hit_1_player_id                   <chr> NA, NA, NA, NA, NA, NA, NA, NA, N…
    $ qb_hit_1_player_name                 <chr> NA, NA, NA, NA, NA, NA, NA, NA, N…
    $ qb_hit_2_player_id                   <chr> NA, NA, NA, NA, NA, NA, NA, NA, N…
    $ qb_hit_2_player_name                 <chr> NA, NA, NA, NA, NA, NA, NA, NA, N…
    $ forced_fumble_player_1_team          <chr> NA, NA, NA, NA, NA, NA, NA, NA, N…
    $ forced_fumble_player_1_player_id     <chr> NA, NA, NA, NA, NA, NA, NA, NA, N…
    $ forced_fumble_player_1_player_name   <chr> NA, NA, NA, NA, NA, NA, NA, NA, N…
    $ forced_fumble_player_2_team          <chr> NA, NA, NA, NA, NA, NA, NA, NA, N…
    $ forced_fumble_player_2_player_id     <chr> NA, NA, NA, NA, NA, NA, NA, NA, N…
    $ forced_fumble_player_2_player_name   <chr> NA, NA, NA, NA, NA, NA, NA, NA, N…
    $ solo_tackle_1_team                   <chr> NA, NA, "KC", "KC", "KC", "KC", N…
    $ solo_tackle_2_team                   <chr> NA, NA, NA, NA, NA, NA, NA, NA, N…
    $ solo_tackle_1_player_id              <chr> NA, NA, "00-0026869", "00-0023449…
    $ solo_tackle_2_player_id              <chr> NA, NA, NA, NA, NA, NA, NA, NA, N…
    $ solo_tackle_1_player_name            <chr> NA, NA, "J.Belcher", "D.Johnson",…
    $ solo_tackle_2_player_name            <chr> NA, NA, NA, NA, NA, NA, NA, NA, N…
    $ assist_tackle_1_player_id            <chr> NA, NA, NA, NA, NA, NA, NA, NA, N…
    $ assist_tackle_1_player_name          <chr> NA, NA, NA, NA, NA, NA, NA, NA, N…
    $ assist_tackle_1_team                 <chr> NA, NA, NA, NA, NA, NA, NA, NA, N…
    $ assist_tackle_2_player_id            <chr> NA, NA, NA, NA, NA, NA, NA, NA, N…
    $ assist_tackle_2_player_name          <chr> NA, NA, NA, NA, NA, NA, NA, NA, N…
    $ assist_tackle_2_team                 <chr> NA, NA, NA, NA, NA, NA, NA, NA, N…
    $ assist_tackle_3_player_id            <lgl> NA, NA, NA, NA, NA, NA, NA, NA, N…
    $ assist_tackle_3_player_name          <lgl> NA, NA, NA, NA, NA, NA, NA, NA, N…
    $ assist_tackle_3_team                 <lgl> NA, NA, NA, NA, NA, NA, NA, NA, N…
    $ assist_tackle_4_player_id            <lgl> NA, NA, NA, NA, NA, NA, NA, NA, N…
    $ assist_tackle_4_player_name          <lgl> NA, NA, NA, NA, NA, NA, NA, NA, N…
    $ assist_tackle_4_team                 <lgl> NA, NA, NA, NA, NA, NA, NA, NA, N…
    $ tackle_with_assist                   <dbl> NA, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,…
    $ tackle_with_assist_1_player_id       <chr> NA, NA, NA, NA, NA, NA, NA, NA, N…
    $ tackle_with_assist_1_player_name     <chr> NA, NA, NA, NA, NA, NA, NA, NA, N…
    $ tackle_with_assist_1_team            <chr> NA, NA, NA, NA, NA, NA, NA, NA, N…
    $ tackle_with_assist_2_player_id       <lgl> NA, NA, NA, NA, NA, NA, NA, NA, N…
    $ tackle_with_assist_2_player_name     <lgl> NA, NA, NA, NA, NA, NA, NA, NA, N…
    $ tackle_with_assist_2_team            <lgl> NA, NA, NA, NA, NA, NA, NA, NA, N…
    $ pass_defense_1_player_id             <chr> NA, NA, NA, NA, NA, NA, "00-00278…
    $ pass_defense_1_player_name           <chr> NA, NA, NA, NA, NA, NA, "E.Berry"…
    $ pass_defense_2_player_id             <chr> NA, NA, NA, NA, NA, NA, NA, NA, N…
    $ pass_defense_2_player_name           <chr> NA, NA, NA, NA, NA, NA, NA, NA, N…
    $ fumbled_1_team                       <chr> NA, NA, NA, NA, NA, NA, NA, NA, N…
    $ fumbled_1_player_id                  <chr> NA, NA, NA, NA, NA, NA, NA, NA, N…
    $ fumbled_1_player_name                <chr> NA, NA, NA, NA, NA, NA, NA, NA, N…
    $ fumbled_2_player_id                  <chr> NA, NA, NA, NA, NA, NA, NA, NA, N…
    $ fumbled_2_player_name                <chr> NA, NA, NA, NA, NA, NA, NA, NA, N…
    $ fumbled_2_team                       <chr> NA, NA, NA, NA, NA, NA, NA, NA, N…
    $ fumble_recovery_1_team               <chr> NA, NA, NA, NA, NA, NA, NA, NA, N…
    $ fumble_recovery_1_yards              <dbl> NA, NA, NA, NA, NA, NA, NA, NA, N…
    $ fumble_recovery_1_player_id          <chr> NA, NA, NA, NA, NA, NA, NA, NA, N…
    $ fumble_recovery_1_player_name        <chr> NA, NA, NA, NA, NA, NA, NA, NA, N…
    $ fumble_recovery_2_team               <chr> NA, NA, NA, NA, NA, NA, NA, NA, N…
    $ fumble_recovery_2_yards              <dbl> NA, NA, NA, NA, NA, NA, NA, NA, N…
    $ fumble_recovery_2_player_id          <chr> NA, NA, NA, NA, NA, NA, NA, NA, N…
    $ fumble_recovery_2_player_name        <chr> NA, NA, NA, NA, NA, NA, NA, NA, N…
    $ sack_player_id                       <chr> NA, NA, NA, NA, NA, NA, NA, NA, N…
    $ sack_player_name                     <chr> NA, NA, NA, NA, NA, NA, NA, NA, N…
    $ half_sack_1_player_id                <chr> NA, NA, NA, NA, NA, NA, NA, NA, N…
    $ half_sack_1_player_name              <chr> NA, NA, NA, NA, NA, NA, NA, NA, N…
    $ half_sack_2_player_id                <chr> NA, NA, NA, NA, NA, NA, NA, NA, N…
    $ half_sack_2_player_name              <chr> NA, NA, NA, NA, NA, NA, NA, NA, N…
    $ return_team                          <chr> NA, "ATL", NA, NA, NA, NA, NA, NA…
    $ return_yards                         <dbl> NA, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,…
    $ penalty_team                         <chr> NA, NA, NA, NA, NA, NA, NA, NA, N…
    $ penalty_player_id                    <chr> NA, NA, NA, NA, NA, NA, NA, NA, N…
    $ penalty_player_name                  <chr> NA, NA, NA, NA, NA, NA, NA, NA, N…
    $ penalty_yards                        <dbl> NA, NA, NA, NA, NA, NA, NA, NA, N…
    $ replay_or_challenge                  <dbl> 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, …
    $ replay_or_challenge_result           <chr> NA, NA, NA, NA, NA, NA, NA, NA, N…
    $ penalty_type                         <chr> NA, NA, NA, NA, NA, NA, NA, NA, N…
    $ defensive_two_point_attempt          <dbl> NA, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,…
    $ defensive_two_point_conv             <dbl> NA, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,…
    $ defensive_extra_point_attempt        <dbl> NA, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,…
    $ defensive_extra_point_conv           <dbl> NA, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,…
    $ safety_player_name                   <chr> NA, NA, NA, NA, NA, NA, NA, NA, N…
    $ safety_player_id                     <chr> NA, NA, NA, NA, NA, NA, NA, NA, N…
    $ season                               <dbl> 2012, 2012, 2012, 2012, 2012, 201…
    $ cp                                   <dbl> NA, NA, NA, NA, 0.6581519, 0.6771…
    $ cpoe                                 <dbl> NA, NA, NA, NA, 34.18481, 32.2890…
    $ series                               <dbl> 1, 1, 1, 1, 1, 2, 3, 3, 3, 4, 4, …
    $ series_success                       <dbl> 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, …
    $ series_result                        <chr> "First down", "First down", "Firs…
    $ order_sequence                       <dbl> 1, 35, 53, 74, 95, 119, 143, 165,…
    $ start_time                           <chr> "9/9/12, 13:03:08", "9/9/12, 13:0…
    $ time_of_day                          <chr> NA, "2012-09-09T17:03:08Z", "2012…
    $ stadium                              <chr> "GEHA Field at Arrowhead Stadium"…
    $ weather                              <chr> "Sunny and clear Temp: 69° F, Hum…
    $ nfl_api_id                           <chr> "10012012-0909-08bb-fd6d-0839971c…
    $ play_clock                           <dbl> 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, …
    $ play_deleted                         <dbl> 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, …
    $ play_type_nfl                        <chr> "GAME_START", "KICK_OFF", "RUSH",…
    $ special_teams_play                   <dbl> 0, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, …
    $ st_play_type                         <chr> NA, NA, NA, NA, NA, NA, NA, NA, N…
    $ end_clock_time                       <chr> NA, NA, NA, NA, NA, NA, NA, NA, N…
    $ end_yard_line                        <chr> NA, NA, NA, NA, NA, NA, NA, NA, N…
    $ fixed_drive                          <dbl> 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, …
    $ fixed_drive_result                   <chr> "Touchdown", "Touchdown", "Touchd…
    $ drive_real_start_time                <dttm> NA, 2012-09-09 17:03:08, 2012-09…
    $ drive_play_count                     <dbl> NA, 12, 12, 12, 12, 12, 12, 12, 1…
    $ drive_time_of_possession             <time>       NA, 06:09:00, 06:09:00, 06…
    $ drive_first_downs                    <dbl> NA, 5, 5, 5, 5, 5, 5, 5, 5, 5, 5,…
    $ drive_inside20                       <dbl> NA, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1,…
    $ drive_ended_with_score               <dbl> NA, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1,…
    $ drive_quarter_start                  <dbl> NA, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1,…
    $ drive_quarter_end                    <dbl> NA, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1,…
    $ drive_yards_penalized                <dbl> NA, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,…
    $ drive_start_transition               <chr> NA, "KICKOFF", "KICKOFF", "KICKOF…
    $ drive_end_transition                 <chr> NA, "TOUCHDOWN", "TOUCHDOWN", "TO…
    $ drive_game_clock_start               <time>       NA, 15:00:00, 15:00:00, 15…
    $ drive_game_clock_end                 <time>       NA, 08:51:00, 08:51:00, 08…
    $ drive_start_yard_line                <chr> NA, "ATL 20", "ATL 20", "ATL 20",…
    $ drive_end_yard_line                  <chr> NA, "KC 8", "KC 8", "KC 8", "KC 8…
    $ drive_play_id_started                <dbl> NA, 35, 35, 35, 35, 35, 35, 35, 3…
    $ drive_play_id_ended                  <dbl> NA, 321, 321, 321, 321, 321, 321,…
    $ away_score                           <dbl> 40, 40, 40, 40, 40, 40, 40, 40, 4…
    $ home_score                           <dbl> 24, 24, 24, 24, 24, 24, 24, 24, 2…
    $ location                             <chr> "Home", "Home", "Home", "Home", "…
    $ result                               <dbl> -16, -16, -16, -16, -16, -16, -16…
    $ total                                <dbl> 64, 64, 64, 64, 64, 64, 64, 64, 6…
    $ spread_line                          <dbl> -1, -1, -1, -1, -1, -1, -1, -1, -…
    $ total_line                           <dbl> 43, 43, 43, 43, 43, 43, 43, 43, 4…
    $ div_game                             <dbl> 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, …
    $ roof                                 <chr> "outdoors", "outdoors", "outdoors…
    $ surface                              <chr> "grass", "grass", "grass", "grass…
    $ temp                                 <dbl> 69, 69, 69, 69, 69, 69, 69, 69, 6…
    $ wind                                 <dbl> 7, 7, 7, 7, 7, 7, 7, 7, 7, 7, 7, …
    $ home_coach                           <chr> "Romeo Crennel", "Romeo Crennel",…
    $ away_coach                           <chr> "Mike Smith", "Mike Smith", "Mike…
    $ stadium_id                           <chr> "KAN00", "KAN00", "KAN00", "KAN00…
    $ game_stadium                         <chr> "Arrowhead Stadium", "Arrowhead S…
    $ aborted_play                         <dbl> 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, …
    $ success                              <dbl> 0, 0, 1, 0, 1, 1, 0, 0, 1, 0, 1, …
    $ passer                               <chr> NA, NA, NA, NA, "M.Ryan", "M.Ryan…
    $ passer_jersey_number                 <dbl> NA, NA, NA, NA, 2, 2, 2, NA, 2, 2…
    $ rusher                               <chr> NA, NA, "M.Turner", "M.Turner", N…
    $ rusher_jersey_number                 <dbl> NA, NA, 33, 33, NA, NA, NA, 33, N…
    $ receiver                             <chr> NA, NA, NA, NA, "T.Gonzalez", "J.…
    $ receiver_jersey_number               <dbl> NA, NA, NA, NA, 88, 11, 88, NA, 1…
    $ pass                                 <dbl> 0, 0, 0, 0, 1, 1, 1, 0, 1, 1, 1, …
    $ rush                                 <dbl> 0, 0, 1, 1, 0, 0, 0, 1, 0, 0, 0, …
    $ first_down                           <dbl> NA, 0, 0, 0, 1, 1, 0, 0, 1, 0, 1,…
    $ special                              <dbl> 0, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, …
    $ play                                 <dbl> 0, 0, 1, 1, 1, 1, 1, 1, 1, 1, 1, …
    $ passer_id                            <chr> NA, NA, NA, NA, "00-0026143", "00…
    $ rusher_id                            <chr> NA, NA, "00-0022821", "00-0022821…
    $ receiver_id                          <chr> NA, NA, NA, NA, "00-0006101", "00…
    $ name                                 <chr> NA, NA, "M.Turner", "M.Turner", "…
    $ jersey_number                        <dbl> NA, NA, 33, 33, 2, 2, 2, 33, 2, 2…
    $ id                                   <chr> NA, NA, "00-0022821", "00-0022821…
    $ fantasy_player_name                  <chr> NA, NA, "M.Turner", "M.Turner", "…
    $ fantasy_player_id                    <chr> NA, NA, "00-0022821", "00-0022821…
    $ fantasy                              <chr> NA, NA, "M.Turner", "M.Turner", "…
    $ fantasy_id                           <chr> NA, NA, "00-0022821", "00-0022821…
    $ out_of_bounds                        <dbl> 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, …
    $ home_opening_kickoff                 <dbl> 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, …
    $ qb_epa                               <dbl> 0.00000000, 0.00000000, 0.3797030…
    $ xyac_epa                             <dbl> NA, NA, NA, NA, 0.3484046, 0.3609…
    $ xyac_mean_yardage                    <dbl> NA, NA, NA, NA, 5.524704, 4.31315…
    $ xyac_median_yardage                  <dbl> NA, NA, NA, NA, 3, 2, 1, NA, 2, 2…
    $ xyac_success                         <dbl> NA, NA, NA, NA, 0.9855300, 1.0000…
    $ xyac_fd                              <dbl> NA, NA, NA, NA, 0.9855300, 0.9990…
    $ xpass                                <dbl> NA, NA, 0.5100481, 0.4223437, 0.7…
    $ pass_oe                              <dbl> NA, NA, -51.004809, -42.234373, 2…
:::
:::

::: {#c7f65dc3 .cell .markdown}
## Previous Play Features (lag within game)
:::

::: {#bc024ac2 .cell .code vscode="{\"languageId\":\"r\"}"}
``` R
pbp_prev <- pbp %>%
  arrange(game_id, play_id) %>%
  group_by(game_id) %>%
  mutate(
    prev_play_type = dplyr::lag(play_type),
    prev_desc = dplyr::lag(desc),
    prev_timeout = as.integer(dplyr::lag(timeout)),
    prev_timeout_team = dplyr::lag(timeout_team),
    prev_penalty = as.integer(dplyr::lag(penalty)),
    prev_incomplete = as.integer(dplyr::lag(incomplete_pass)),
    prev_out_bounds = as.integer(dplyr::lag(out_of_bounds)),
    prev_gsr = dplyr::lag(game_seconds_remaining),
    delta_secs = prev_gsr - game_seconds_remaining,
    prev_end_quarter = as.integer(!is.na(prev_desc) & str_detect(prev_desc, "(?i)end\\s+quarter")),
    prev_two_min_warning = as.integer(!is.na(prev_desc) & str_detect(prev_desc, "(?i)two-?minute\\s+warning"))
  ) %>%
  ungroup() %>%
  select(
    game_id, play_id,
    prev_play_type, prev_desc, prev_timeout, prev_timeout_team,
    prev_penalty, prev_incomplete, prev_out_bounds,
    prev_end_quarter, prev_two_min_warning, delta_secs
)

print(head(pbp_prev))
```

::: {.output .stream .stdout}
    # A tibble: 6 × 12
      game_id        play_id prev_play_type prev_desc prev_timeout prev_timeout_team
      <chr>            <dbl> <chr>          <chr>            <int> <chr>            
    1 2012_01_ATL_KC       1 NA             NA                  NA NA               
    2 2012_01_ATL_KC      35 NA             GAME                NA NA               
    3 2012_01_ATL_KC      53 kickoff        6-R.Succ…            0 NA               
    4 2012_01_ATL_KC      74 run            (15:00) …            0 NA               
    5 2012_01_ATL_KC      95 run            (14:22) …            0 NA               
    6 2012_01_ATL_KC     119 pass           (13:41) …            0 NA               
    # ℹ 6 more variables: prev_penalty <int>, prev_incomplete <int>,
    #   prev_out_bounds <int>, prev_end_quarter <int>, prev_two_min_warning <int>,
    #   delta_secs <dbl>
:::
:::

::: {#54ba7f4e .cell .markdown}
## Field Goal & PAT Attempts {#field-goal--pat-attempts}
:::

::: {#62d934fa .cell .code vscode="{\"languageId\":\"r\"}"}
``` R
fg_attempts_raw <- pbp %>%
  filter(
    season %in% SEASONS,
    play_type %in% c("field_goal", "extra_point"),
    (field_goal_result %in% c("made", "missed", "blocked")) |
      (extra_point_result %in% c("good", "failed", "blocked"))
  ) %>%
  mutate(
    is_pat = as.integer(play_type == "extra_point"),
    kick_result_raw = dplyr::coalesce(field_goal_result, extra_point_result),
    kick_result = case_when(
      kick_result_raw %in% c("made", "good") ~ "made",
      kick_result_raw %in% c("missed", "failed") ~ "missed",
      kick_result_raw %in% c("blocked") ~ "blocked",
      TRUE ~ NA_character_
    ),
    kick_distance = suppressWarnings(as.numeric(kick_distance)),
    kick_distance = if_else(is_pat == 1L & is.na(kick_distance), 33, kick_distance),
    attempted = 1L
  ) %>%
  filter(!is.na(kick_distance)) %>%
  transmute(
    game_id, play_id, old_game_id,
    season = as.integer(season),
    week = as.integer(week),
    season_type,
    playoffs = as.integer(season_type == "POST"),
    qtr = as.integer(qtr),
    game_date = as.Date(game_date),
    home_team, away_team, posteam, defteam,
    game_seconds_remaining, quarter_seconds_remaining,
    score_differential, yardline_100, ydstogo,
    wp, home_wp, epa,
    posteam_timeouts_remaining, defteam_timeouts_remaining,
    goal_to_go,
    is_ot  = qtr >= 5,
    roof, surface, temp, wind, weather,
    stadium_id, stadium, location,
    kick_distance, kicker_player_id, kicker_player_name,
    field_goal_result, extra_point_result,
    kick_result, is_pat, attempted,
    play_type_original = play_type
  )

print(head(fg_attempts_raw))
```

::: {.output .stream .stdout}
    # A tibble: 6 × 42
      game_id play_id old_game_id season  week season_type playoffs   qtr game_date 
      <chr>     <dbl>       <dbl>  <int> <int> <chr>          <int> <int> <date>    
    1 2012_0…     321  2012090908   2012     1 REG                0     1 2012-09-09
    2 2012_0…     588  2012090908   2012     1 REG                0     1 2012-09-09
    3 2012_0…     727  2012090908   2012     1 REG                0     1 2012-09-09
    4 2012_0…     983  2012090908   2012     1 REG                0     2 2012-09-09
    5 2012_0…    1213  2012090908   2012     1 REG                0     2 2012-09-09
    6 2012_0…    1427  2012090908   2012     1 REG                0     2 2012-09-09
    # ℹ 33 more variables: home_team <chr>, away_team <chr>, posteam <chr>,
    #   defteam <chr>, game_seconds_remaining <dbl>,
    #   quarter_seconds_remaining <dbl>, score_differential <dbl>,
    #   yardline_100 <dbl>, ydstogo <dbl>, wp <dbl>, home_wp <dbl>, epa <dbl>,
    #   posteam_timeouts_remaining <dbl>, defteam_timeouts_remaining <dbl>,
    #   goal_to_go <dbl>, is_ot <lgl>, roof <chr>, surface <chr>, temp <dbl>,
    #   wind <dbl>, weather <chr>, stadium_id <chr>, stadium <chr>, …
:::
:::

::: {#b36b414c .cell .markdown}
## Fourth-Down Non-Attempt Opportunities
:::

::: {#a0590499 .cell .code vscode="{\"languageId\":\"r\"}"}
``` R
fg_nonattempts_raw <- pbp %>%
  filter(
    season %in% SEASONS,
    down == 4L,
    !is.na(yardline_100),
    !is.na(ydstogo)
  ) %>%
  mutate(
    derived_kick_distance = yardline_100 + 17L,
  ) %>%
  filter(
    play_type %in% c("pass","run","punt","qb_kneel","qb_spike") |
      (special_teams_play == 1 & field_goal_attempt == 0 &
         play_type %in% c("pass","run"))
  ) %>%
  transmute(
    game_id, play_id, old_game_id,
    season = as.integer(season),
    week = as.integer(week),
    season_type,
    playoffs = as.integer(season_type == "POST"),
    qtr = as.integer(qtr), down,
    game_date = as.Date(game_date),
    home_team, away_team, posteam, defteam,
    game_seconds_remaining, quarter_seconds_remaining,
    score_differential, yardline_100, ydstogo,
    wp, home_wp, epa,
    posteam_timeouts_remaining, defteam_timeouts_remaining,
    goal_to_go,
    roof, surface, temp, wind, weather,
    stadium_id, stadium, location,
    kick_distance = derived_kick_distance,
    kicker_player_id = NA_character_,
    kicker_player_name = NA_character_,
    field_goal_result = NA_character_,
    extra_point_result = NA_character_,
    kick_result = NA_character_,
    is_pat = 0L,
    is_ot  = qtr >= 5,
    attempted = 0L,
    play_type_original = play_type
  )
print(head(fg_nonattempts_raw))
```

::: {.output .stream .stdout}
    # A tibble: 6 × 43
      game_id      play_id old_game_id season  week season_type playoffs   qtr  down
      <chr>          <dbl>       <dbl>  <int> <int> <chr>          <int> <int> <dbl>
    1 2012_01_ATL…    3124  2012090908   2012     1 REG                0     4     4
    2 2012_01_ATL…    3263  2012090908   2012     1 REG                0     4     4
    3 2012_01_BUF…    1110  2012090902   2012     1 REG                0     2     4
    4 2012_01_BUF…    2340  2012090902   2012     1 REG                0     3     4
    5 2012_01_BUF…    3042  2012090902   2012     1 REG                0     4     4
    6 2012_01_BUF…    3620  2012090902   2012     1 REG                0     4     4
    # ℹ 34 more variables: game_date <date>, home_team <chr>, away_team <chr>,
    #   posteam <chr>, defteam <chr>, game_seconds_remaining <dbl>,
    #   quarter_seconds_remaining <dbl>, score_differential <dbl>,
    #   yardline_100 <dbl>, ydstogo <dbl>, wp <dbl>, home_wp <dbl>, epa <dbl>,
    #   posteam_timeouts_remaining <dbl>, defteam_timeouts_remaining <dbl>,
    #   goal_to_go <dbl>, roof <chr>, surface <chr>, temp <dbl>, wind <dbl>,
    #   weather <chr>, stadium_id <chr>, stadium <chr>, location <chr>, …
:::
:::

::: {#2426bd5e .cell .code vscode="{\"languageId\":\"r\"}"}
``` R
# ensure output directory exists and write with basic error handling
if (!dir.exists(data_dir)) dir.create(data_dir, recursive = TRUE, showWarnings = FALSE)

out_path <- file.path(data_dir, 'fg_nonattempts_raw.csv')
tryCatch({
  readr::write_csv(fg_nonattempts_raw, out_path)
  message("Wrote: ", out_path)
}, error = function(e) {
  stop("Failed to write ", out_path, ": ", e$message, call. = FALSE)
})
```

::: {.output .stream .stderr}
    Wrote: G:\My files\Python\Sports Analytics Projects\Football\Kickers\NFL-Field-Goal-Kicker-Model/data/fg_nonattempts_raw.csv
:::
:::

::: {#d3880d11 .cell .code vscode="{\"languageId\":\"r\"}"}
``` R
pbp %>%
  filter(season %in% SEASONS, qtr == 4L, down == 4L,
         !is.na(yardline_100), !is.na(ydstogo)) %>%
  mutate(dist = yardline_100 + 17L) %>%
  filter(dplyr::between(score_differential, -10, 6),
         ydstogo >= 1, dist <= 50) %>%
  count(play_type, sort = TRUE)
```

::: {.output .display_data}

A tibble: 7 × 2

| play_type &lt;chr&gt; | n &lt;int&gt; |
|---|---|
| field_goal | 1662 |
| pass       |  387 |
| run        |  187 |
| no_play    |  126 |
| punt       |    1 |
| qb_kneel   |    1 |
| NA         |    1 |
:::
:::

::: {#4ef39931 .cell .code vscode="{\"languageId\":\"r\"}"}
``` R
pbp %>%
  filter(season %in% SEASONS, qtr == 4L, down == 4L,
         !is.na(yardline_100), !is.na(ydstogo)) %>%
  mutate(dist = yardline_100 + 17L,
         in_window = dplyr::between(score_differential, -10, 6) &
                     ydstogo >= 1 & dist <= 50) %>%
  summarise(
    total_window = sum(in_window),
    kicks = sum(in_window & play_type == 'field_goal'),
    non_kicks = sum(in_window &
                    (play_type %in% c('pass','run','punt','qb_kneel','qb_spike') |
                       (special_teams_play == 1 & field_goal_attempt == 0 &
                          play_type %in% c('pass','run'))))
  )
```

::: {.output .display_data}

A tibble: 1 × 3

| total_window &lt;int&gt; | kicks &lt;int&gt; | non_kicks &lt;int&gt; |
|---|---|---|
| 2365 | NA | 576 |
:::
:::

::: {#b6c227cf .cell .markdown}
## Combine Attempts & Opportunities for Shared Feature Engineering {#combine-attempts--opportunities-for-shared-feature-engineering}
:::

::: {#3793bcab .cell .code vscode="{\"languageId\":\"r\"}"}
``` R
fg_all <- bind_rows(fg_attempts_raw, fg_nonattempts_raw) %>%
  left_join(pbp_prev, by = c('game_id', 'play_id'))
```
:::

::: {#019ccbdf .cell .markdown}
## Situational Features
:::

::: {#0e778476 .cell .code vscode="{\"languageId\":\"r\"}"}
``` R
fg_all <- fg_all %>%
  mutate(
    l2m = as.integer(qtr %in% c(2L, 4L) & quarter_seconds_remaining <= 120),
    clock_running = as.integer(
      is_pat == 0L &
      !is.na(delta_secs) & delta_secs > 0 &
      coalesce(prev_timeout, 0L) == 0L &
      coalesce(prev_penalty, 0L) == 0L &
      coalesce(prev_incomplete, 0L) == 0L &
      coalesce(prev_out_bounds, 0L) == 0L &
      coalesce(prev_end_quarter, 0L) == 0L &
      coalesce(prev_two_min_warning, 0L) == 0L
    ),
    iced = as.integer(
      is_pat == 0L &
      coalesce(prev_timeout, 0L) == 1L &
      !is.na(prev_timeout_team) &
      prev_timeout_team == defteam
    )
  )
```
:::

::: {#e789ea00 .cell .markdown}
## Kicker Information (age & experience) {#kicker-information-age--experience}
:::

::: {#c42e6941 .cell .code vscode="{\"languageId\":\"r\"}"}
``` R
players <- nflreadr::load_players() %>%
  transmute(
    gsis_id = as.character(gsis_id),
    birth_date = as.Date(birth_date),
    rookie_season = suppressWarnings(as.integer(rookie_season))
  )

fg_all <- fg_all %>%
  mutate(kicker_player_id = as.character(kicker_player_id)) %>%
  left_join(players, by = c('kicker_player_id' = 'gsis_id')) %>%
  mutate(
    kicker_age = as.numeric(difftime(game_date, birth_date, units = 'days')) / 365.25,
    kicker_experience = if_else(
      !is.na(rookie_season),
      as.numeric(season - rookie_season) + 1,
      NA_real_
    )
  )
```
:::

::: {#6add3ea9 .cell .markdown}
## Venue Flags
:::

::: {#85dc0478 .cell .code vscode="{\"languageId\":\"r\"}"}
``` R
fg_all <- fg_all %>%
  mutate(
    roof = forcats::fct_explicit_na(as.factor(roof), 'unknown'),
    surface = forcats::fct_explicit_na(as.factor(surface), 'unknown'),
    roof_std = tolower(as.character(roof)),
    indoors = as.integer(roof_std %in% c('dome', 'closed', 'open')),
    surface_std = tolower(as.character(surface)),
    is_turf = as.integer(surface_std != 'grass'),
    high_altitude = as.integer(!is.na(stadium_id) & str_detect(stadium_id, '^(DEN|MEX)'))
  )
```

::: {.output .stream .stderr}
    Warning message:
    "There was 1 warning in `mutate()`.
    ℹ In argument: `roof = forcats::fct_explicit_na(as.factor(roof), "unknown")`.
    Caused by warning:
    ! `fct_explicit_na()` was deprecated in forcats 1.0.0.
    ℹ Please use `fct_na_value_to_level()` instead."
:::
:::

::: {#68210704 .cell .markdown}
## Weather Parsing & Imputation {#weather-parsing--imputation}
:::

::: {#b764feba .cell .code vscode="{\"languageId\":\"r\"}"}
``` R
fg_all <- fg_all %>%
  mutate(
    weather = if_else(weather == '', NA_character_, weather),
    weather_first = if_else(
      is.na(weather),
      NA_character_,
      str_squish(str_to_lower(str_replace(weather, '(?i)\\s*temp:.*$', '')))
    ),
    weather_clean = weather_first,
    temp_from_weather = str_extract(weather, '(?i)temp\\s*:?\\s*(-?\\d{1,3})'),
    temp_from_weather = suppressWarnings(as.numeric(str_extract(temp_from_weather, '-?\\d{1,3}'))),
    temp_degree = str_extract(weather, '(?i)(-?\\d{1,3})\\s*(?:deg|degrees|\\u00B0)?\\s*f'),
    temp_degree = suppressWarnings(as.numeric(str_extract(temp_degree, '-?\\d{1,3}'))),
    wind_from_weather = str_extract(weather, '(?i)(\\d{1,3})\\s*mph'),
    wind_from_weather = suppressWarnings(as.numeric(str_extract(wind_from_weather, '\\d{1,3}'))),
    humidity_from_weather = str_extract(weather, '(?i)(\\d{1,3})\\s*%'),
    humidity_from_weather = suppressWarnings(as.numeric(str_extract(humidity_from_weather, '\\d{1,3}'))),
    temp = coalesce(temp, temp_from_weather, temp_degree),
    wind = coalesce(wind, wind_from_weather),
    humidity = humidity_from_weather
  ) %>%
  mutate(
    temp = if_else(is.na(temp) & indoors == 1L, 71, temp),
    wind = if_else(is.na(wind) & indoors == 1L, 0, wind),
    humidity = if_else(is.na(humidity) & indoors == 1L, 45, humidity)
  )

outdoor_monthly_medians <- fg_all %>%
  filter(indoors == 0L) %>%
  mutate(month = lubridate::month(game_date)) %>%
  group_by(stadium_id, month) %>%
  summarise(
    temp_median = suppressWarnings(as.numeric(median(temp, na.rm = TRUE))),
    wind_median = suppressWarnings(as.numeric(median(wind, na.rm = TRUE))),
    humidity_median = suppressWarnings(as.numeric(median(humidity, na.rm = TRUE))),
    .groups = 'drop'
  )


fg_all <- fg_all %>%
  mutate(month = lubridate::month(game_date)) %>%
  left_join(outdoor_monthly_medians, by = c('stadium_id', 'month')) %>%
  mutate(
    temp = if_else(is.na(temp) & indoors == 0L, temp_median, temp),
    wind = if_else(is.na(wind) & indoors == 0L, wind_median, wind),
    humidity = if_else(is.na(humidity) & indoors == 0L, humidity_median, humidity)
  )

global_temp_median <- fg_all %>% filter(indoors == 0L, !is.na(temp)) %>% summarise(median = median(temp)) %>% pull()
if (length(global_temp_median) == 0) global_temp_median <- NA_real_

global_wind_median <- fg_all %>% filter(indoors == 0L, !is.na(wind)) %>% summarise(median = median(wind)) %>% pull()
if (length(global_wind_median) == 0) global_wind_median <- NA_real_

global_humidity_median <- fg_all %>% filter(indoors == 0L, !is.na(humidity)) %>% summarise(median = median(humidity)) %>% pull()
if (length(global_humidity_median) == 0) global_humidity_median <- NA_real_

fg_all <- fg_all %>%
  mutate(
    temp = if_else(is.na(temp) & indoors == 0L, global_temp_median, temp),
    wind = if_else(is.na(wind) & indoors == 0L, global_wind_median, wind),
    humidity = if_else(is.na(humidity) & indoors == 0L, global_humidity_median, humidity)
  ) %>%
  # Final logic check for indoor venues:
  mutate(
    # ensure roof_std exists and is lowercase; fallback to tolower(roof) if needed
    roof_std = if_else(is.na(roof_std), tolower(as.character(roof)), roof_std),
    temp = case_when(
      indoors == 1L & roof_std %in% c('dome', 'closed') ~ 71,
      TRUE ~ temp
    ),
    wind = case_when(
      indoors == 1L & roof_std %in% c('dome', 'closed') ~ 0,
      indoors == 1L & roof_std == 'open' & !is.na(wind) & wind > 5 ~ 5,
      TRUE ~ wind
    )
  ) %>%
  select(-temp_from_weather, -temp_degree, -wind_from_weather, -humidity_from_weather,
         -temp_median, -wind_median, -humidity_median, -month)
```
:::

::: {#a0229ee1 .cell .markdown}
## Weather Flags
:::

::: {#8049fa7b .cell .code vscode="{\"languageId\":\"r\"}"}
``` R
fg_all <- fg_all %>%
  mutate(
    weather_clean = str_to_lower(coalesce(weather, '')) %>% str_squish(),
    weather_clean = if_else(weather_clean == '' & indoors == 0L, 'clear', weather_clean),
    weather_clean = str_replace_all(weather_clean, '(cloudly|coudy|cloundy|clo[iu]dy)', 'cloudy'),
    weather_clean = str_replace_all(weather_clean, '(mosly|mostly\\s+coudy)', 'mostly cloudy'),
    weather_clean = str_replace_all(weather_clean, '(partly\\s*sunny|sun\\s*/\\s*clouds|sun\\s*&\\s*clouds|sunny\\s*intervals)', 'partly cloudy'),
    weather_clean = str_replace_all(weather_clean, 'hazey', 'hazy'),
    no_rain_phrase = as.integer(str_detect(weather_clean, 'no\\s+chance\\s+of\\s+rain|0%\\s*chance\\s*of\\s+rain|zero\\s*percent\\s*chance\\s*of\\s+rain')),
    is_snow_sleet = as.integer(
      indoors != 1L & str_detect(weather_clean, '\\bsnow\\b|\\bflurr(y|ies)\\b|\\bsleet\\b|\\bfreezing\\s+rain\\b|\\bwintry\\s+mix\\b|\\bice\\b')
    ),
    is_rain_showers = as.integer(
      indoors != 1L & str_detect(weather_clean, '\\brain\\b|\\braining\\b|\\bshowers?\\b|\\bdrizzle\\b|\\bstorm\\b|\\bthunderstorm\\b')
    ),
    is_rain_showers = if_else(is_snow_sleet == 1L | no_rain_phrase == 1L, 0L, is_rain_showers),
    is_cloudy = as.integer(
      indoors != 1L & str_detect(weather_clean, '\\bcloudy\\b|\\bovercast\\b|\\bpartly\\s+cloudy\\b|\\bmostly\\s+cloudy\\b|\\bscattered\\s+clouds?\\b')
    ),
    is_hazy_fog = as.integer(
      indoors != 1L & str_detect(weather_clean, '\\bfog(?:gy)?\\b|\\bhaze\\b|\\bhazy\\b|\\bmist\\b')
    )
  ) %>%
  select(-no_rain_phrase)
```
:::

::: {#a240dff2 .cell .markdown}
## Adding Leverage
:::

::: {#910df204 .cell .code vscode="{\"languageId\":\"r\"}"}
``` R
leverage_pack_ok <- TRUE
leverage_dir <- file.path(PROJECT_ROOT, 'data', 'leverage')
fg_pack_path  <- file.path(leverage_dir, 'wp_heads_rulepack.rds')
pat_pack_path <- file.path(leverage_dir, 'pat_heads_rulepack.rds')

if (!file.exists(fg_pack_path) || !file.exists(pat_pack_path)) {
  leverage_pack_ok <- FALSE
  warning('Leverage rulepacks missing; skipping leverage augmentation. Expected in ', leverage_dir)
}

if (leverage_pack_ok) {
  fg_pack <- readRDS(fg_pack_path)
  pat_pack <- readRDS(pat_pack_path)

  mod_make        <- fg_pack$mod_make
  mod_miss        <- fg_pack$mod_miss
  mk_feats_make   <- fg_pack$mk_feats_make
  mk_feats_miss   <- fg_pack$mk_feats_miss
  apply_end_rules <- fg_pack$apply_endgame_rules

  mod_pat_make      <- pat_pack$mod_pat_make
  mod_pat_miss      <- pat_pack$mod_pat_miss
  mk_feats_pat_make <- pat_pack$mk_feats_pat_make
  mk_feats_pat_miss <- pat_pack$mk_feats_pat_miss
  apply_pat_rules   <- pat_pack$apply_pat_rules_min
  pat_ot_const      <- pat_pack$pat_ot_const

  eps <- 1e-6
  clamp01 <- function(x) pmin(pmax(x, eps), 1 - eps)
  desired_cols <- c(
    '.row_id',
    'wp_make_hat', 'wp_miss_hat', 'leverage',
    'wp_make_hat_rules', 'wp_miss_hat_rules',
    'pred_hat_post',
    'leverage_rules'
  )

  fg_all <- fg_all %>% mutate(.row_id = dplyr::row_number())

  fg_nonpat <- fg_all %>% filter(is_pat == 0L)
  fg_nonpat_scorable <- fg_nonpat %>%
    filter(!is_ot) %>%
    filter(!is.na(yardline_100))

  if (nrow(fg_nonpat_scorable) > 0) {
    feats_make <- mk_feats_make(fg_nonpat_scorable)
    feats_miss <- mk_feats_miss(fg_nonpat_scorable)

    scored_fg <- fg_nonpat_scorable %>%
      mutate(
        wp_make_hat = clamp01(predict(mod_make, newdata = feats_make, type = 'response')),
        wp_miss_hat = clamp01(predict(mod_miss, newdata = feats_miss, type = 'response')),
        leverage    = pmin(pmax(wp_make_hat - wp_miss_hat, 0), 1)
      ) %>%
      apply_end_rules() %>%
      dplyr::select(dplyr::any_of(desired_cols))
  } else {
    scored_fg <- tibble(.row_id = integer(),
                        wp_make_hat = numeric(), wp_miss_hat = numeric(), leverage = numeric(),
                        wp_make_hat_rules = numeric(), wp_miss_hat_rules = numeric(),
                        pred_hat_post = numeric(), leverage_rules = numeric())
  }

  fg_nonpat_ot <- fg_nonpat %>% filter(is_ot)

  const_pool <- fg_nonpat_scorable %>%
    inner_join(
      scored_fg %>% dplyr::select(.row_id, leverage_rules),
      by = '.row_id'
    ) %>%
    dplyr::filter(
      qtr == 4L,
      quarter_seconds_remaining < 120,
      score_differential %in% -3:0
    )

  fg_ot_const_val <- const_pool %>%
    summarise(med = median(leverage_rules, na.rm = TRUE)) %>%
    pull(med)

  if (is.na(fg_ot_const_val)) {
    fg_ot_const_val <- scored_fg %>%
      summarise(med = median(leverage_rules, na.rm = TRUE)) %>% pull(med)
  }
  if (is.na(fg_ot_const_val)) fg_ot_const_val <- 0.5

  if (nrow(fg_nonpat_ot) > 0) {
    scored_fg_ot <- fg_nonpat_ot %>%
      transmute(
        .row_id,
        wp_make_hat       = NA_real_,
        wp_miss_hat       = NA_real_,
        leverage          = fg_ot_const_val,
        wp_make_hat_rules = NA_real_,
        wp_miss_hat_rules = NA_real_,
        pred_hat_post     = NA_real_,
        leverage_rules    = fg_ot_const_val
      ) %>%
      dplyr::select(dplyr::any_of(desired_cols))
  } else {
    scored_fg_ot <- tibble(.row_id = integer(),
                           wp_make_hat = numeric(), wp_miss_hat = numeric(), leverage = numeric(),
                           wp_make_hat_rules = numeric(), wp_miss_hat_rules = numeric(),
                           pred_hat_post = numeric(), leverage_rules = numeric())
  }

  pats <- fg_all %>% filter(is_pat == 1L)
  pats_nonot <- pats %>% filter(!is_ot)
  pats_ot    <- pats %>% filter(is_ot)

  if (nrow(pats_nonot) > 0) {
    feats_pat_make <- mk_feats_pat_make(pats_nonot)
    feats_pat_miss <- mk_feats_pat_miss(pats_nonot)

    scored_pat_nonot <- pats_nonot %>%
      mutate(
        wp_make_hat = clamp01(predict(mod_pat_make, newdata = feats_pat_make, type = 'response')),
        wp_miss_hat = clamp01(predict(mod_pat_miss, newdata = feats_pat_miss, type = 'response')),
        leverage    = pmin(pmax(wp_make_hat - wp_miss_hat, 0), 1)
      ) %>%
      apply_pat_rules() %>%
      dplyr::select(dplyr::any_of(desired_cols))
  } else {
    scored_pat_nonot <- tibble(.row_id = integer(),
                               wp_make_hat = numeric(), wp_miss_hat = numeric(), leverage = numeric(),
                               wp_make_hat_rules = numeric(), wp_miss_hat_rules = numeric(),
                               pred_hat_post = numeric(), leverage_rules = numeric())
  }

  if (nrow(pats_ot) > 0) {
    scored_pat_ot <- pat_ot_const(pats_ot) %>%
      dplyr::select(dplyr::any_of(desired_cols))
  } else {
    scored_pat_ot <- tibble(.row_id = integer(),
                            wp_make_hat = numeric(), wp_miss_hat = numeric(), leverage = numeric(),
                            wp_make_hat_rules = numeric(), wp_miss_hat_rules = numeric(),
                            pred_hat_post = numeric(), leverage_rules = numeric())
  }

  scored_all <- bind_rows(scored_fg, scored_fg_ot, scored_pat_nonot, scored_pat_ot)

  fg_all <- fg_all %>%
    left_join(scored_all, by = '.row_id') %>%
    select(-.row_id)

  message(sprintf(
    'Leverage added: FG (reg) = %d, FG (OT const) = %d, PAT (reg) = %d, PAT (OT) = %d. FG OT const = %.4f',
    nrow(scored_fg), nrow(scored_fg_ot), nrow(scored_pat_nonot), nrow(scored_pat_ot), fg_ot_const_val
  ))

  fg_made_vals   <- c('made', 'good')
  fg_miss_vals   <- c('missed', 'blocked')
  pat_good_vals  <- c('good')
  pat_fail_vals  <- c('failed', 'missed', 'blocked', 'aborted', 'no_good')

  fg_all <- fg_all %>%
    mutate(
      pred_hat_post = dplyr::case_when(
        is_pat == 0L & attempted == 1L & !is.na(kick_result) &
          tolower(kick_result) %in% fg_made_vals ~ wp_make_hat_rules,

        is_pat == 0L & attempted == 1L & !is.na(kick_result) &
          tolower(kick_result) %in% fg_miss_vals ~ wp_miss_hat_rules,

        is_pat == 1L & !is.na(extra_point_result) &
          tolower(extra_point_result) %in% pat_good_vals ~ wp_make_hat_rules,

        is_pat == 1L & !is.na(extra_point_result) &
          tolower(extra_point_result) %in% pat_fail_vals ~ wp_miss_hat_rules,

        TRUE ~ pred_hat_post
      ),
      pred_hat_post = dplyr::if_else(
        !is.na(pred_hat_post),
        pmin(pmax(pred_hat_post, 0), 1),
        pred_hat_post
      )
    )
} else {
  leverage_cols <- c('wp_make_hat','wp_miss_hat','leverage','wp_make_hat_rules','wp_miss_hat_rules','leverage_rules','pred_hat_post')
  for (col in leverage_cols) {
    if (!col %in% names(fg_all)) {
      fg_all[[col]] <- NA_real_
    }
  }
}
```

::: {.output .stream .stderr}
    Leverage added: FG (reg) = 52090, FG (OT const) = 431, PAT (reg) = 16656, PAT (OT) = 0. FG OT const = 0.4936
:::
:::

::: {#6d2f985c .cell .markdown}
## Sanity Checks & Completeness {#sanity-checks--completeness}
:::

::: {#44d540d9 .cell .code vscode="{\"languageId\":\"r\"}"}
``` R
suppressPackageStartupMessages({
  library(glue)
})

assert_true <- function(ok, msg) if (!isTRUE(ok)) stop(msg, call. = FALSE)
assert_between01 <- function(x, allow_na = TRUE, label = deparse(substitute(x))) {
  if (allow_na) x <- x[!is.na(x)]
  bad <- any(x < 0 | x > 1)
  assert_true(!bad, glue('{label} must be within [0,1].'))
}

fg_chk <- fg_all %>% mutate(.row_id_check = dplyr::row_number())

fg_chk <- fg_chk %>%
  mutate(
    pat_flag = as.logical(is_pat),
    ot_flag  = as.logical(is_ot)
  )

req_cols <- c(
  'is_pat', 'is_ot',
  'wp_make_hat', 'wp_miss_hat', 'leverage',
  'wp_make_hat_rules', 'wp_miss_hat_rules', 'leverage_rules'
 )
missing_cols <- setdiff(req_cols, names(fg_chk))
assert_true(length(missing_cols) == 0,
            glue('Missing expected columns: {paste(missing_cols, collapse=", ")}'))

assert_between01(fg_chk$wp_make_hat,       TRUE, 'wp_make_hat')
assert_between01(fg_chk$wp_miss_hat,       TRUE, 'wp_miss_hat')
assert_between01(fg_chk$leverage,          TRUE, 'leverage')
assert_between01(fg_chk$wp_make_hat_rules, TRUE, 'wp_make_hat_rules')
assert_between01(fg_chk$wp_miss_hat_rules, TRUE, 'wp_miss_hat_rules')
assert_between01(fg_chk$leverage_rules,    TRUE, 'leverage_rules')

fg_chk <- fg_chk %>%
  mutate(.lev_raw_from_heads = pmin(pmax(wp_make_hat - wp_miss_hat, 0), 1))
diff_eps <- with(fg_chk, abs(leverage - .lev_raw_from_heads))
if (any(!is.na(diff_eps))) {
  assert_true(max(diff_eps, na.rm = TRUE) < 1e-6,
              'leverage != clamp(wp_make_hat - wp_miss_hat) on some rows.')
}

fg_nonpat <- fg_chk %>% filter(!pat_flag)
fg_pats   <- fg_chk %>% filter( pat_flag)

fg_nonpat_nonot <- fg_nonpat %>% filter(!ot_flag)
fg_nonpat_nonot_na <- fg_nonpat_nonot %>%
  summarise(
    n = n(),
    na_wp_make = sum(is.na(wp_make_hat)),
    na_wp_miss = sum(is.na(wp_miss_hat)),
    na_lev     = sum(is.na(leverage))
  )

fg_nonpat_ot <- fg_nonpat %>% filter(ot_flag)

pats_na <- fg_pats %>%
  summarise(
    n = n(),
    na_wp_make    = sum(is.na(wp_make_hat)),
    na_wp_miss    = sum(is.na(wp_miss_hat)),
    na_lev        = sum(is.na(leverage)),
    na_lev_rules  = sum(is.na(leverage_rules))
  )
assert_true(all(pats_na[1, c('na_wp_make','na_wp_miss','na_lev','na_lev_rules')] == 0),
            'PAT rows contain NAs but should be fully scored (including OT).')

fg_nonpat_nonot_rules_na <- fg_nonpat_nonot %>% summarise(na_lev_rules = sum(is.na(leverage_rules)))
assert_true(fg_nonpat_nonot_rules_na$na_lev_rules == 0,
            'Non-OT FG rows have NA in leverage_rules unexpectedly.')

summary_counts <- fg_chk %>%
  mutate(kind = if_else(pat_flag, 'PAT', 'FG'),
         period = if_else(ot_flag, 'OT', 'Reg')) %>%
  count(kind, period, name = 'plays')

na_summary <- fg_chk %>%
  mutate(kind = if_else(pat_flag, 'PAT', 'FG'),
         period = if_else(ot_flag, 'OT', 'Reg')) %>%
  summarise(
    plays        = n(),
    wp_make_na   = sum(is.na(wp_make_hat)),
    wp_miss_na   = sum(is.na(wp_miss_hat)),
    lev_na       = sum(is.na(leverage)),
    lev_rules_na = sum(is.na(leverage_rules)),
    .by = c(kind, period)
  ) %>%
  arrange(kind, period)

range_summary <- fg_chk %>%
  summarise(
    across(
      c(wp_make_hat, wp_miss_hat, leverage, wp_make_hat_rules, wp_miss_hat_rules, leverage_rules),
      list(min = ~min(.x, na.rm = TRUE), max = ~max(.x, na.rm = TRUE)),
      .names = '{.col}_{.fn}'
    )
  )

cat('\n=== Sanity Check Report =====================================\n')
summary_counts
cat('\n--- NA counts by group ---------------------------------------\n')
na_summary
cat('\n--- Value ranges (excluding NAs) ------------------------------\n')
range_summary

edge_hi <- fg_chk %>%
  filter(!is.na(leverage_rules)) %>%
  arrange(desc(leverage_rules)) %>%
  select(game_id, play_id, is_pat, is_ot, wp_make_hat_rules, wp_miss_hat_rules, leverage_rules) %>%
  head(5)

edge_lo <- fg_chk %>%
  filter(!is.na(leverage_rules)) %>%
  arrange(leverage_rules) %>%
  select(game_id, play_id, is_pat, is_ot, wp_make_hat_rules, wp_miss_hat_rules, leverage_rules) %>%
  head(5)

cat('\n--- Top 5 highest leverage_rules ------------------------------\n'); edge_hi
cat('\n--- Top 5 lowest leverage_rules -------------------------------\n'); edge_lo
cat('\nSanity checks completed.\n')
```

::: {.output .stream .stdout}

    === Sanity Check Report =====================================
:::

::: {.output .display_data}

A tibble: 3 × 3

| kind &lt;chr&gt; | period &lt;chr&gt; | plays &lt;int&gt; |
|---|---|---|
| FG  | OT  |   431 |
| FG  | Reg | 52090 |
| PAT | Reg | 16656 |
:::

::: {.output .stream .stdout}

    --- NA counts by group ---------------------------------------
:::

::: {.output .display_data}

A tibble: 3 × 7

| kind &lt;chr&gt; | period &lt;chr&gt; | plays &lt;int&gt; | wp_make_na &lt;int&gt; | wp_miss_na &lt;int&gt; | lev_na &lt;int&gt; | lev_rules_na &lt;int&gt; |
|---|---|---|---|---|---|---|
| FG  | OT  |   431 | 431 | 431 | 0 | 0 |
| FG  | Reg | 52090 |   0 |   0 | 0 | 0 |
| PAT | Reg | 16656 |   0 |   0 | 0 | 0 |
:::

::: {.output .stream .stdout}

    --- Value ranges (excluding NAs) ------------------------------
:::

::: {.output .display_data}

A tibble: 1 × 12

| wp_make_hat_min &lt;dbl&gt; | wp_make_hat_max &lt;dbl&gt; | wp_miss_hat_min &lt;dbl&gt; | wp_miss_hat_max &lt;dbl&gt; | leverage_min &lt;dbl&gt; | leverage_max &lt;dbl&gt; | wp_make_hat_rules_min &lt;dbl&gt; | wp_make_hat_rules_max &lt;dbl&gt; | wp_miss_hat_rules_min &lt;dbl&gt; | wp_miss_hat_rules_max &lt;dbl&gt; | leverage_rules_min &lt;dbl&gt; | leverage_rules_max &lt;dbl&gt; |
|---|---|---|---|---|---|---|---|---|---|---|---|
| 1e-06 | 0.999999 | 1e-06 | 0.999999 | 0 | 0.8135067 | 1e-06 | 0.999999 | 1e-06 | 0.999999 | 0 | 0.99 |
:::

::: {.output .stream .stdout}

    --- Top 5 highest leverage_rules ------------------------------
:::

::: {.output .display_data}

A tibble: 5 × 7

| game_id &lt;chr&gt; | play_id &lt;dbl&gt; | is_pat &lt;int&gt; | is_ot &lt;lgl&gt; | wp_make_hat_rules &lt;dbl&gt; | wp_miss_hat_rules &lt;dbl&gt; | leverage_rules &lt;dbl&gt; |
|---|---|---|---|---|---|---|
| 2012_02_ARI_NE  | 4435 | 0 | FALSE | 0.995 | 0.005 | 0.99 |
| 2012_03_NE_BAL  | 4771 | 0 | FALSE | 0.995 | 0.005 | 0.99 |
| 2012_05_PHI_PIT | 4153 | 0 | FALSE | 0.995 | 0.005 | 0.99 |
| 2012_08_CAR_CHI | 4312 | 0 | FALSE | 0.995 | 0.005 | 0.99 |
| 2012_14_DAL_CIN | 4230 | 0 | FALSE | 0.995 | 0.005 | 0.99 |
:::

::: {.output .stream .stdout}

    --- Top 5 lowest leverage_rules -------------------------------
:::

::: {.output .display_data}

A tibble: 5 × 7

| game_id &lt;chr&gt; | play_id &lt;dbl&gt; | is_pat &lt;int&gt; | is_ot &lt;lgl&gt; | wp_make_hat_rules &lt;dbl&gt; | wp_miss_hat_rules &lt;dbl&gt; | leverage_rules &lt;dbl&gt; |
|---|---|---|---|---|---|---|
| 2012_05_BUF_SF  | 3698 | 1 | FALSE | 0.9999990 | 0.9999990 | 0 |
| 2012_09_CHI_TEN | 1176 | 1 | FALSE | 0.9596418 | 0.9597301 | 0 |
| 2012_14_ARI_SEA | 3876 | 1 | FALSE | 0.9999990 | 0.9999990 | 0 |
| 2012_16_TEN_GB  | 3097 | 1 | FALSE | 0.9998017 | 0.9998026 | 0 |
| 2012_16_TEN_GB  | 3253 | 1 | FALSE | 0.9999704 | 0.9999714 | 0 |
:::

::: {.output .stream .stdout}

    Sanity checks completed.
:::
:::

::: {#ba2fde6f .cell .markdown}
## Standardized Features & Modeling Flags {#standardized-features--modeling-flags}
:::

::: {#b58c877a .cell .code vscode="{\"languageId\":\"r\"}"}
``` R
stats_attempts <- fg_all %>%
  filter(attempted == 1L) %>%
  summarise(
    wind_mean = mean(wind, na.rm = TRUE),
    wind_sd = sd(wind, na.rm = TRUE),
    temp_mean = mean(temp, na.rm = TRUE),
    temp_sd = sd(temp, na.rm = TRUE),
    humidity_mean = mean(humidity, na.rm = TRUE),
    humidity_sd = sd(humidity, na.rm = TRUE),
    age_mean = mean(kicker_age, na.rm = TRUE),
    age_sd = sd(kicker_age, na.rm = TRUE),
    exp_mean = mean(kicker_experience, na.rm = TRUE),
    exp_sd = sd(kicker_experience, na.rm = TRUE),
    season_mean = mean(season, na.rm = TRUE),
    season_sd = sd(season, na.rm = TRUE)
  )

wind_mean <- stats_attempts$wind_mean
wind_sd <- stats_attempts$wind_sd
if (is.na(wind_sd) || wind_sd == 0) wind_sd <- NA_real_

temp_mean <- stats_attempts$temp_mean
temp_sd <- stats_attempts$temp_sd
if (is.na(temp_sd) || temp_sd == 0) temp_sd <- NA_real_

humidity_mean <- stats_attempts$humidity_mean
humidity_sd <- stats_attempts$humidity_sd
if (is.na(humidity_sd) || humidity_sd == 0) humidity_sd <- NA_real_

age_mean <- stats_attempts$age_mean
age_sd <- stats_attempts$age_sd
if (is.na(age_sd) || age_sd == 0) age_sd <- NA_real_

exp_mean <- stats_attempts$exp_mean
exp_sd <- stats_attempts$exp_sd
if (is.na(exp_sd) || exp_sd == 0) exp_sd <- NA_real_

season_mean <- stats_attempts$season_mean
season_sd <- stats_attempts$season_sd
if (is.na(season_sd) || season_sd == 0) season_sd <- NA_real_

lev_mean <- mean(fg_all$leverage_rules, na.rm = TRUE)
lev_sd   <- stats::sd(fg_all$leverage_rules, na.rm = TRUE)

fg_all <- fg_all %>%
  mutate(
    wind_z = ifelse(!is.na(wind) & !is.na(wind_sd), (wind - wind_mean) / wind_sd, NA_real_),
    temp_z = ifelse(!is.na(temp) & !is.na(temp_sd), (temp - temp_mean) / temp_sd, NA_real_),
    humidity_z = ifelse(!is.na(humidity) & !is.na(humidity_sd), (humidity - humidity_mean) / humidity_sd, NA_real_),
    kicker_age_z = ifelse(!is.na(kicker_age) & !is.na(age_sd), (kicker_age - age_mean) / age_sd, NA_real_),
    kicker_experience_z = ifelse(!is.na(kicker_experience) & !is.na(exp_sd), (kicker_experience - exp_mean) / exp_sd, NA_real_),
    season_z = ifelse(!is.na(season) & !is.na(season_sd), (season - season_mean) / season_sd, NA_real_),
    kick_made = ifelse(attempted == 1L & !is.na(kick_result), as.integer(kick_result == 'made'), NA_integer_),
    eoh_urgency = as.integer(qtr == 2L & quarter_seconds_remaining <= 10 & clock_running == 1L),
    eog_urgency = as.integer(qtr == 4L & l2m == 1L & clock_running == 1L & !is.na(score_differential) & abs(score_differential) <= 3),
    go_ahead = as.integer(score_differential == 0),
    to_tie = as.integer(score_differential == -3),
    one_score = as.integer(!is.na(score_differential) & abs(score_differential) <= 8),
    leverage_z = ifelse(!is.na(leverage_rules) & is.finite(lev_sd) & lev_sd > 0,
                        (leverage_rules - lev_mean) / lev_sd, NA_real_)
  )
```
:::

::: {#a4efdcd8 .cell .markdown}
## Split Data & Basic QA {#split-data--basic-qa}
:::

::: {#b035b5cf .cell .code vscode="{\"languageId\":\"r\"}"}
``` R
fg_attempts <- fg_all %>% filter(attempted == 1L) %>% arrange(season, week, game_id, play_id)
fg_nonattempts <- fg_all %>% filter(attempted == 0L) %>% arrange(season, week, game_id, play_id)

fg_attempts %>%
  select(game_id, season, week, kick_result, kick_distance, wind, wind_z, temp, temp_z, kicker_player_name, kick_made) %>%
  head()

fg_nonattempts %>%
  select(game_id, season, week, posteam, defteam, kick_distance, wind, temp, ydstogo, score_differential) %>%
  head()

fg_attempts %>%
  summarise(
    attempts = n(),
    pats = sum(is_pat == 1L, na.rm = TRUE),
    min_distance = min(kick_distance, na.rm = TRUE),
    max_distance = max(kick_distance, na.rm = TRUE),
    missing_temp = sum(is.na(temp)),
    missing_wind = sum(is.na(wind))
  )

fg_nonattempts %>%
  summarise(
    opportunities = n(),
    min_distance = min(kick_distance, na.rm = TRUE),
    max_distance = max(kick_distance, na.rm = TRUE)
  )
```

::: {.output .display_data}

A tibble: 6 × 11

| game_id &lt;chr&gt; | season &lt;int&gt; | week &lt;int&gt; | kick_result &lt;chr&gt; | kick_distance &lt;dbl&gt; | wind &lt;dbl&gt; | wind_z &lt;dbl&gt; | temp &lt;dbl&gt; | temp_z &lt;dbl&gt; | kicker_player_name &lt;chr&gt; | kick_made &lt;int&gt; |
|---|---|---|---|---|---|---|---|---|---|---|
| 2012_01_ATL_KC | 2012 | 1 | made | 20 | 7 | 0.230199 | 69 | 0.4451003 | M.Bryant | 1 |
| 2012_01_ATL_KC | 2012 | 1 | made | 39 | 7 | 0.230199 | 69 | 0.4451003 | R.Succop | 1 |
| 2012_01_ATL_KC | 2012 | 1 | made | 34 | 7 | 0.230199 | 69 | 0.4451003 | M.Bryant | 1 |
| 2012_01_ATL_KC | 2012 | 1 | made | 20 | 7 | 0.230199 | 69 | 0.4451003 | R.Succop | 1 |
| 2012_01_ATL_KC | 2012 | 1 | made | 20 | 7 | 0.230199 | 69 | 0.4451003 | M.Bryant | 1 |
| 2012_01_ATL_KC | 2012 | 1 | made | 20 | 7 | 0.230199 | 69 | 0.4451003 | R.Succop | 1 |
:::

::: {.output .display_data}

A tibble: 6 × 10

| game_id &lt;chr&gt; | season &lt;int&gt; | week &lt;int&gt; | posteam &lt;chr&gt; | defteam &lt;chr&gt; | kick_distance &lt;dbl&gt; | wind &lt;dbl&gt; | temp &lt;dbl&gt; | ydstogo &lt;dbl&gt; | score_differential &lt;dbl&gt; |
|---|---|---|---|---|---|---|---|---|---|
| 2012_01_ATL_KC  | 2012 | 1 | KC  | ATL |  79 | 7 | 69 |  9 | -23 |
| 2012_01_ATL_KC  | 2012 | 1 | ATL | KC  |  92 | 7 | 69 |  4 |  23 |
| 2012_01_BUF_NYJ | 2012 | 1 | BUF | NYJ |  93 | 1 | 74 |  6 | -14 |
| 2012_01_BUF_NYJ | 2012 | 1 | BUF | NYJ | 106 | 1 | 74 | 19 | -27 |
| 2012_01_BUF_NYJ | 2012 | 1 | NYJ | BUF |  76 | 1 | 74 | 13 |  27 |
| 2012_01_BUF_NYJ | 2012 | 1 | NYJ | BUF |  97 | 1 | 74 | 10 |  20 |
:::

::: {.output .display_data}

A tibble: 1 × 6

| attempts &lt;int&gt; | pats &lt;int&gt; | min_distance &lt;dbl&gt; | max_distance &lt;dbl&gt; | missing_temp &lt;int&gt; | missing_wind &lt;int&gt; |
|---|---|---|---|---|---|
| 30397 | 16656 | 18 | 71 | 0 | 0 |
:::

::: {.output .display_data}

A tibble: 1 × 3

| opportunities &lt;int&gt; | min_distance &lt;dbl&gt; | max_distance &lt;dbl&gt; |
|---|---|---|
| 38780 | 18 | 116 |
:::
:::

::: {#41bd07a5 .cell .markdown}
## Persist Outputs
:::

::: {#e1188bb0 .cell .code vscode="{\"languageId\":\"r\"}"}
``` R
get_schema <- function(df, n = 5) {
  tibble::tibble(
    name = names(df),
    class = purrr::map_chr(df, ~ paste(class(.x), collapse = '/')),
    sample = purrr::map_chr(df, ~ paste(head(.x, n), collapse = ', '))
  )
}

attempts_path <- file.path(data_dir, 'fg_attempts.csv')
nonattempts_path <- file.path(data_dir, 'fg_nonattempts.csv')
all_path <- file.path(data_dir, 'fg_all.csv')

readr::write_csv(fg_attempts, attempts_path)
readr::write_csv(fg_nonattempts, nonattempts_path)
readr::write_csv(fg_all, all_path)

schema_preview <- get_schema(fg_all)
readr::write_csv(schema_preview, file.path(reports_dir, 'data_prep_schema_preview.csv'))
schema_preview
```

::: {.output .display_data}

A tibble: 92 × 3

| name &lt;chr&gt; | class &lt;chr&gt; | sample &lt;chr&gt; |
|---|---|---|
| game_id                    | character | 2012_01_ATL_KC, 2012_01_ATL_KC, 2012_01_ATL_KC, 2012_01_ATL_KC, 2012_01_ATL_KC                                                                                                                                                                                                                             |
| play_id                    | numeric   | 321, 588, 727, 983, 1213                                                                                                                                                                                                                                                                                   |
| old_game_id                | numeric   | 2012090908, 2012090908, 2012090908, 2012090908, 2012090908                                                                                                                                                                                                                                                 |
| season                     | integer   | 2012, 2012, 2012, 2012, 2012                                                                                                                                                                                                                                                                               |
| week                       | integer   | 1, 1, 1, 1, 1                                                                                                                                                                                                                                                                                              |
| season_type                | character | REG, REG, REG, REG, REG                                                                                                                                                                                                                                                                                    |
| playoffs                   | integer   | 0, 0, 0, 0, 0                                                                                                                                                                                                                                                                                              |
| qtr                        | integer   | 1, 1, 1, 2, 2                                                                                                                                                                                                                                                                                              |
| game_date                  | Date      | 2012-09-09, 2012-09-09, 2012-09-09, 2012-09-09, 2012-09-09                                                                                                                                                                                                                                                 |
| home_team                  | character | KC, KC, KC, KC, KC                                                                                                                                                                                                                                                                                         |
| away_team                  | character | ATL, ATL, ATL, ATL, ATL                                                                                                                                                                                                                                                                                    |
| posteam                    | character | ATL, KC, ATL, KC, ATL                                                                                                                                                                                                                                                                                      |
| defteam                    | character | KC, ATL, KC, ATL, KC                                                                                                                                                                                                                                                                                       |
| game_seconds_remaining     | numeric   | 3231, 2946, 2817, 2499, 2268                                                                                                                                                                                                                                                                               |
| quarter_seconds_remaining  | numeric   | 531, 246, 117, 699, 468                                                                                                                                                                                                                                                                                    |
| score_differential         | numeric   | 6, -7, 4, -1, 6                                                                                                                                                                                                                                                                                            |
| yardline_100               | numeric   | 2, 21, 16, 2, 2                                                                                                                                                                                                                                                                                            |
| ydstogo                    | numeric   | 0, 7, 2, 0, 0                                                                                                                                                                                                                                                                                              |
| wp                         | numeric   | 0.62115947306537, 0.409854084253311, 0.646720051765442, 0.559583809119425, 0.637317121952369                                                                                                                                                                                                               |
| home_wp                    | numeric   | 0.378840526934629, 0.409854084253311, 0.353279948234558, 0.559583809119425, 0.362682878047631                                                                                                                                                                                                              |
| epa                        | numeric   | 0.017960741538217, 0.790261980449425, 0.375770560161675, 0.017960741538217, 0.017960741538217                                                                                                                                                                                                              |
| posteam_timeouts_remaining | numeric   | 3, 3, 3, 3, 3                                                                                                                                                                                                                                                                                              |
| defteam_timeouts_remaining | numeric   | 3, 3, 3, 3, 2                                                                                                                                                                                                                                                                                              |
| goal_to_go                 | numeric   | 0, 0, 0, 0, 0                                                                                                                                                                                                                                                                                              |
| is_ot                      | logical   | FALSE, FALSE, FALSE, FALSE, FALSE                                                                                                                                                                                                                                                                          |
| roof                       | factor    | outdoors, outdoors, outdoors, outdoors, outdoors                                                                                                                                                                                                                                                           |
| surface                    | factor    | grass, grass, grass, grass, grass                                                                                                                                                                                                                                                                          |
| temp                       | numeric   | 69, 69, 69, 69, 69                                                                                                                                                                                                                                                                                         |
| wind                       | numeric   | 7, 7, 7, 7, 7                                                                                                                                                                                                                                                                                              |
| weather                    | character | Sunny and clear Temp: 69° F, Humidity: 47%, Wind: NE 7 mph, Sunny and clear Temp: 69° F, Humidity: 47%, Wind: NE 7 mph, Sunny and clear Temp: 69° F, Humidity: 47%, Wind: NE 7 mph, Sunny and clear Temp: 69° F, Humidity: 47%, Wind: NE 7 mph, Sunny and clear Temp: 69° F, Humidity: 47%, Wind: NE 7 mph |
| ⋮ | ⋮ | ⋮ |
| surface_std         | character | grass, grass, grass, grass, grass                                                                                                                                                                                                                                                                          |
| is_turf             | integer   | 0, 0, 0, 0, 0                                                                                                                                                                                                                                                                                              |
| high_altitude       | integer   | 0, 0, 0, 0, 0                                                                                                                                                                                                                                                                                              |
| weather_first       | character | sunny and clear, sunny and clear, sunny and clear, sunny and clear, sunny and clear                                                                                                                                                                                                                        |
| weather_clean       | character | sunny and clear temp: 69° f, humidity: 47%, wind: ne 7 mph, sunny and clear temp: 69° f, humidity: 47%, wind: ne 7 mph, sunny and clear temp: 69° f, humidity: 47%, wind: ne 7 mph, sunny and clear temp: 69° f, humidity: 47%, wind: ne 7 mph, sunny and clear temp: 69° f, humidity: 47%, wind: ne 7 mph |
| humidity            | numeric   | 47, 47, 47, 47, 47                                                                                                                                                                                                                                                                                         |
| is_snow_sleet       | integer   | 0, 0, 0, 0, 0                                                                                                                                                                                                                                                                                              |
| is_rain_showers     | integer   | 0, 0, 0, 0, 0                                                                                                                                                                                                                                                                                              |
| is_cloudy           | integer   | 0, 0, 0, 0, 0                                                                                                                                                                                                                                                                                              |
| is_hazy_fog         | integer   | 0, 0, 0, 0, 0                                                                                                                                                                                                                                                                                              |
| wp_make_hat         | numeric   | 0.69608402413363, 0.365483079066313, 0.69581342608046, 0.494541486604616, 0.709846885546206                                                                                                                                                                                                                |
| wp_miss_hat         | numeric   | 0.679467252220493, 0.274744089017486, 0.583762257631314, 0.448371596036698, 0.696275812231319                                                                                                                                                                                                              |
| leverage            | numeric   | 0.0166167719131368, 0.0907389900488272, 0.112051168449146, 0.0461698905679176, 0.0135710733148872                                                                                                                                                                                                          |
| wp_make_hat_rules   | numeric   | 0.69608402413363, 0.365483079066313, 0.69581342608046, 0.494541486604616, 0.709846885546206                                                                                                                                                                                                                |
| wp_miss_hat_rules   | numeric   | 0.679467252220493, 0.274744089017486, 0.583762257631314, 0.448371596036698, 0.696275812231319                                                                                                                                                                                                              |
| leverage_rules      | numeric   | 0.0166167719131368, 0.0907389900488272, 0.112051168449146, 0.0461698905679176, 0.0135710733148872                                                                                                                                                                                                          |
| pred_hat_post       | numeric   | 0.69608402413363, 0.365483079066313, 0.69581342608046, 0.494541486604616, 0.709846885546206                                                                                                                                                                                                                |
| wind_z              | numeric   | 0.230198953752107, 0.230198953752107, 0.230198953752107, 0.230198953752107, 0.230198953752107                                                                                                                                                                                                              |
| temp_z              | numeric   | 0.445100320152038, 0.445100320152038, 0.445100320152038, 0.445100320152038, 0.445100320152038                                                                                                                                                                                                              |
| humidity_z          | numeric   | -0.567690809114373, -0.567690809114373, -0.567690809114373, -0.567690809114373, -0.567690809114373                                                                                                                                                                                                         |
| kicker_age_z        | numeric   | 1.49259296128017, -0.745540448948044, 1.49259296128017, -0.745540448948044, 1.49259296128017                                                                                                                                                                                                               |
| kicker_experience_z | numeric   | 0.788987301589984, -0.639668623020175, 0.788987301589984, -0.639668623020175, 0.788987301589984                                                                                                                                                                                                            |
| season_z            | numeric   | -1.60480603606461, -1.60480603606461, -1.60480603606461, -1.60480603606461, -1.60480603606461                                                                                                                                                                                                              |
| kick_made           | integer   | 1, 1, 1, 1, 1                                                                                                                                                                                                                                                                                              |
| eoh_urgency         | integer   | 0, 0, 0, 0, 0                                                                                                                                                                                                                                                                                              |
| eog_urgency         | integer   | 0, 0, 0, 0, 0                                                                                                                                                                                                                                                                                              |
| go_ahead            | integer   | 0, 0, 0, 0, 0                                                                                                                                                                                                                                                                                              |
| to_tie              | integer   | 0, 0, 0, 0, 0                                                                                                                                                                                                                                                                                              |
| one_score           | integer   | 1, 1, 1, 1, 1                                                                                                                                                                                                                                                                                              |
| leverage_z          | numeric   | -0.914541910793433, -0.173408774919313, 0.0396874060560331, -0.61904622738874, -0.944995237877034                                                                                                                                                                                                          |
:::
:::

::: {#1726e967 .cell .code vscode="{\"languageId\":\"r\"}"}
``` R
list(
  fg_attempts = attempts_path,
  fg_nonattempts = nonattempts_path,
  fg_all = all_path,
  schema_preview = file.path(reports_dir, 'data_prep_schema_preview.csv')
)
```

::: {.output .display_data}
$fg_attempts
:   'G:\\My files\\Python\\Sports Analytics Projects\\Football\\Kickers\\NFL-Field-Goal-Kicker-Model/data/fg_attempts.csv'
$fg_nonattempts
:   'G:\\My files\\Python\\Sports Analytics Projects\\Football\\Kickers\\NFL-Field-Goal-Kicker-Model/data/fg_nonattempts.csv'
$fg_all
:   'G:\\My files\\Python\\Sports Analytics Projects\\Football\\Kickers\\NFL-Field-Goal-Kicker-Model/data/fg_all.csv'
$schema_preview
:   'G:\\My files\\Python\\Sports Analytics Projects\\Football\\Kickers\\NFL-Field-Goal-Kicker-Model/reports/data_prep_schema_preview.csv'
:::
:::

::: {#39506222 .cell .markdown}
## Session Info
:::

::: {#6803ba84 .cell .code vscode="{\"languageId\":\"r\"}"}
``` R
info <- capture.output(sessionInfo())
readr::write_lines(info, file.path(reports_dir, 'session_info.txt'), append = TRUE)
cat(info, sep = '\n')
```

::: {.output .stream .stdout}
    R version 4.5.1 (2025-06-13 ucrt)
    Platform: x86_64-w64-mingw32/x64
    Running under: Windows 11 x64 (build 26100)

    Matrix products: default
      LAPACK version 3.12.1

    locale:
    [1] LC_COLLATE=English_Canada.utf8  LC_CTYPE=English_Canada.utf8   
    [3] LC_MONETARY=English_Canada.utf8 LC_NUMERIC=C                   
    [5] LC_TIME=English_Canada.utf8    

    time zone: America/Toronto
    tzcode source: internal

    attached base packages:
    [1] splines   stats     graphics  grDevices utils     datasets  methods  
    [8] base     

    other attached packages:
     [1] nflreadr_1.5.0  lubridate_1.9.4 forcats_1.0.0   glue_1.8.0     
     [5] rlang_1.1.6     yaml_2.3.10     pROC_1.19.0.1   glmmTMB_1.1.12 
     [9] mgcv_1.9-3      nlme_3.1-168    ggplot2_4.0.0   purrr_1.1.0    
    [13] stringr_1.5.2   readr_2.1.5     tidyr_1.3.1     tibble_3.3.0   
    [17] dplyr_1.1.4    

    loaded via a namespace (and not attached):
     [1] gtable_0.3.6        TMB_1.9.17          lattice_0.22-7     
     [4] tzdb_0.5.0          numDeriv_2016.8-1.1 vctrs_0.6.5        
     [7] tools_4.5.1         Rdpack_2.6.4        generics_0.1.4     
    [10] parallel_4.5.1      sandwich_3.1-1      pkgconfig_2.0.3    
    [13] Matrix_1.7-3        data.table_1.17.8   RColorBrewer_1.1-3 
    [16] S7_0.2.0            uuid_1.2-1          lifecycle_1.0.4    
    [19] compiler_4.5.1      farver_2.1.2        textshaping_1.0.3  
    [22] repr_1.1.7          htmltools_0.5.8.1   pillar_1.11.1      
    [25] nloptr_2.2.1        crayon_1.5.3        MASS_7.3-65        
    [28] cachem_1.1.0        reformulas_0.4.1    boot_1.3-31        
    [31] tidyselect_1.2.1    digest_0.6.37       stringi_1.8.7      
    [34] fastmap_1.2.0       grid_4.5.1          cli_3.6.5          
    [37] magrittr_2.0.4      base64enc_0.1-3     utf8_1.2.6         
    [40] IRdisplay_1.1       withr_3.0.2         scales_1.4.0       
    [43] IRkernel_1.3.2      bit64_4.6.0-1       timechange_0.3.0   
    [46] bit_4.6.0           lme4_1.1-37         pbdZMQ_0.3-14      
    [49] ragg_1.5.0          zoo_1.8-14          hms_1.1.3          
    [52] memoise_2.0.1       evaluate_1.0.5      rbibutils_2.3      
    [55] Rcpp_1.1.0          vroom_1.6.6         minqa_1.2.8        
    [58] jsonlite_2.0.0      R6_2.6.1            systemfonts_1.2.3  
:::
:::
