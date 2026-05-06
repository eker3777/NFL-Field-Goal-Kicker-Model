# Notebook Consolidation & 2025 Re-run Plan

**Goal:** Consolidate 10 exploratory notebooks into 4 clean, sequential, paper-reproducible
`.ipynb` notebooks (R kernel). Integrate 2025 season data pull, archive all exploratory work,
and produce all key paper figures from a single end-to-end re-run.

---

## Decisions Log

| Decision | Choice |
|---|---|
| Target journal | TBD |
| 2025 data pull | Integrated into notebook 01 via `nflfastR::load_pbp()` |
| Notebook structure | 4 clean notebooks |
| Exploratory notebooks | Archived to `notebooks/archive/` |
| Format | Jupyter `.ipynb` with R kernel (IRkernel) |
| Parameters | Inline at top of each notebook |
| Leverage/WPA analysis | Inside notebook 04 (evaluation) |
| Paper figures | All key figures in notebook 04, saved to `reports/figures/` |

---

## Clean Notebook Structure

### `01_data_prep.ipynb`
**Sources:** `nflfastR::load_pbp()` (2000–2025, with local RDS cache)

**Pipeline:**
1. `nflfastR::load_pbp(SEASONS)` → cached to `data/pbp_raw.rds`
2. Previous play lag features (timeout, penalty, iced detection)
3. FG attempts + PAT extraction → `fg_attempts_raw`
4. 4th-down non-attempt extraction → `fg_nonattempts_raw`
5. Combine → shared feature engineering (situational, kicker, venue, weather)
6. Leverage scoring (conditional on `data/leverage/*.rds` rulepacks)
7. Z-score standardization (wind, temp, age, experience, leverage)
8. `kicker_by_game` mapping table

**Outputs:**
- `data/fg_attempts.csv` — FG attempts + PATs with all features
- `data/fg_nonattempts.csv` — 4th-down non-attempts with features
- `data/fg_all.csv` — combined (attempts + non-attempts)
- `data/kicker_by_game.csv` — primary kicker per game/team

---

### `02_propensity.ipynb`
**Sources:** `data/fg_all.csv`

**Pipeline:**
1. Build 4th-down decision frame (FG, Punt, Go-for-it)
2. Feature construction (B-splines on distance, time features, score flags)
3. Rolling-origin OOF multinomial logistic regression (3-season window, seasons ≥ 2015)
4. Per-season AUC diagnostics
5. IPW weight pipeline:
   - Step 1: Clip propensities to [0.02, 0.98]
   - Step 2: Stabilized IPW (w_raw = prevalence / p_clipped)
   - Step 3: Hájek season-normalize (mean weight = 1 per season)
   - Step 4: 3σ cap (remove extreme outliers)
   - Step 5: Re-normalize (mean = 1 again)
6. ESS diagnostics + weight distribution summary

**Outputs:**
- `reports/attempt_pi/attempt_pi_oof_predictions_final.csv`
  - Columns: `season`, `game_id`, `play_id`, `attempt_fg`, `p_hat_attempt_clipped`, `w_ipw_final`
- `reports/attempt_pi/attempt_pi_metrics_by_season.csv`

---

### `03_models.ipynb`
**Sources:** `data/fg_all.csv`, `data/kicker_by_game.csv`,
`reports/attempt_pi/attempt_pi_oof_predictions_final.csv`,
`data/augmented/test_fg_game_ids.csv`

**Pipeline:**
1. Load & join data (fg_all + OOF preds + kicker imputation)
2. Distance splines (B-splines, knots [28,38,48,58], bounds [18,70])
3. Kicker age/experience z-scores (standardized on attempts only)
4. Weight/probability assignment (FG: OOF IPW; PAT: min FG weight; Non: 1/p_hat)
5. Master sets (FG_master, PAT_master, NON_master) + train/test split
6. **M0** — distance-only GLMM → `models/m0/`
7. **M1** — full GLMM (fixed + random effects) → `models/m1/`
8. **M2** — IPW-weighted GLMM (`weights = w_ipw_final`) → `models/m2/`
9. **M3** dataset: FG (w=1) + PAT (w=0.10) + filtered non-attempts (π≥0.25, dist>33, w=0.10)
10. **M3** — augmented GLMM → `models/m3/`
11. Predictions export (train, test, full in-sample per model)

**Outputs:**
- `models/m0/`, `models/m1/`, `models/m2/`, `models/m3/` — fitted `.rds` objects
- `reports/xfg_success_ipw/fg_full_with_ipw_predictions.csv` — M0/M1/M2 predictions
- `reports/xfg_success_augmented/fg_full_with_augmented_predictions.csv` — M3 predictions
- `data/augmented/test_fg_game_ids.csv` — test game IDs (if not already present)

---

### `04_evaluation.ipynb`
**Sources:** Prediction CSVs from notebook 03

**Pipeline:**
1. Load all model predictions, join M3
2. **Metrics table:** Brier, AUC, LogLoss, CalibError — all models, global + 50+ yard + OOS
3. **Calibration curves:** predicted vs. observed by distance bin (all models overlaid)
4. **Residual/bias curves:** predicted − observed across kick distance
5. **Weight analysis:** make rate by weight category (standard vs. high)
6. **Rationality check:** density of M1-predicted P(make) for attempts vs. non-attempts
7. **WPA decision landscape:** 4th-down WPA by decision type (FG / Punt / Go)
8. **Era comparison:** FG vs Go rates, 2015–17 vs 2022–25
9. **Kicking evolution:** avg distance, make%, 50+ volume, 50+ make% by season (2015–2025)
10. **Distance distribution:** 2015 vs 2025 density comparison
11. **FGOE leaderboard:** actual − M1-predicted per kicker (top/bottom bar chart)
12. **Skill vs workload scatter:** FGOE vs mean attempt distance

**Outputs (all to `reports/figures/`):**
| File | Content |
|---|---|
| `fig_01_calibration_by_model.png` | Calibration curves (all models) |
| `fig_02_residual_by_distance.png` | Bias curves by distance |
| `fig_03_weight_distribution.png` | IPW weight histogram |
| `fig_04_weights_vs_distance.png` | Weights vs kick distance scatter |
| `fig_05_rationality_density.png` | Attempt vs non-attempt predicted density |
| `fig_06_wpa_decision_landscape.png` | WPA by decision type (4th downs) |
| `fig_07_era_comparison.png` | FG vs Go rate shift (2015–17 vs 2022–25) |
| `fig_08_kicking_evolution.png` | Season trends (avg dist, make%, volume) |
| `fig_09_distance_distribution.png` | 2015 vs 2025 kick distance density |
| `fig_10_fgoe_leaderboard.png` | FGOE bar chart |
| `fig_11_skill_vs_workload.png` | FGOE vs mean attempt distance scatter |
| `fig_12_metrics_table.csv` | All model metrics (for paper table) |

---

## Verification Checklist

- [ ] Each notebook runs end-to-end without error
- [ ] `data/fg_attempts.csv` row count ≥ ~11,000 (confirms 2025 season included)
- [ ] M1 OOF AUC ≥ 0.80 and Brier ≤ 0.105 (sanity check vs. prior results)
- [ ] All 12 figures exist in `reports/figures/` after notebook 04 runs
- [ ] `quarto render "Paper/Field_Goal_Kicking_IPW/index.qmd"` succeeds

---

## Progress Tracker

| Notebook | Status | Notes |
|---|---|---|
| `01_data_prep.ipynb` | ⬜ Not started | Needs 2025 data pull test |
| `02_propensity.ipynb` | ⬜ Not started | |
| `03_models.ipynb` | ⬜ Not started | |
| `04_evaluation.ipynb` | ⬜ Not started | |
| Figures verified | ⬜ Not started | |
| Paper metrics updated | ⬜ Not started | |
