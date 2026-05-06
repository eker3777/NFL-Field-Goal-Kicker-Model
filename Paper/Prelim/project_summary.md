# NFL Field Goal Model — Coding Agent Briefing
**Project:** Strategy vs. Confidence: Using Unobserved Data to Estimate NFL Kicker Success  
**Authors:** Elliott Kervin & Dr. Michael Schuckers (UNC Charlotte)  
**Agent Task:** Notebook refactoring and codebase consolidation in support of academic paper writing

---

## 1. Project Overview

This project builds a next-generation NFL field goal success model that corrects for **selection bias** inherent in observed attempt data. The core insight: field goal models are trained only on kicks that coaches *allowed* — a biased, curated sample. Elite kickers attempt difficult kicks that weaker kickers are protected from. The goal is to recover **true kicker skill** by correcting for this selection mechanism.

The paper asks three things:
1. Does modeling the **coaching decision to kick or not kick** (via a propensity score) improve predictive accuracy when used as an IPW correction?
2. Does **augmenting training data with pseudo-labeled non-attempts** correct optimism bias in the observed sample?
3. What does the **structural decision landscape** tell us about why the bias exists and whether it's rational?

---

## 2. Data

**Source:** nflfastR NFL play-by-play data, **2015–2024** (10 seasons)

**Primary dataset (Attempts):**
- All field goal attempts and extra points (PATs)
- Outcomes: Made, Missed, Blocked
- Blocks excluded from outcome modeling (treated as missing or down-weighted)

**Augmented dataset (Non-Attempts / Declined Kicks):**
- All 4th-down run, pass, and punt plays within plausible FG range
- Used as the "negative class" for propensity modeling and pseudo-label augmentation

**Feature engineering:**
- Weather parsed from game description text; indoor games normalized to 70°F / 0 mph wind
- Wind and temperature converted to z-scores
- Controls for: turf vs. grass, altitude (Denver, Mexico City), icing (timeout before kick), clock running, rain/snow flags
- Distance spline knots at: 28, 38, 48, 58 yards; bounds (18, 70)

---

## 3. Model Architecture

All outcome models share this core structure:

**Framework:** Generalized Linear Mixed Model (GLMM)  
**Package:** `glmmTMB` (R) — uses TMB (Template Model Builder) with C++ and automatic differentiation for efficient Laplace approximation of high-dimensional random effects  
**Family:** Binomial with logit link  
**Target:** P(Make = 1 | Conditions)

**Fixed Effects:**
- Distance spline (7 basis functions, bounds 18–70, knots at 28/38/48/58)
- Wind (z-score), Temperature (z-score), Wind × Temperature interaction
- Rain flag, Snow flag
- Overtime indicator, Iced indicator
- Clock running × Timeouts interaction
- Spline interactions: Distance × Wind, Distance × Temperature

**Random Effects:**
- Stadium intercept (controls for venue-specific altitude, turf)
- Kicker-Season intercept (controls for individual skill drift over time)

---

## 4. Model Families (M0–M3)

### M0 — Distance Only (Baseline Control)
- Manual splines on distance only
- No random effects, no environmental features
- Brier: 0.105 | AUC: 0.775

### M1 — Full Baseline (Observed Attempts Only)
- Full fixed effects + random effects (Stadium, Kicker:Season)
- Trained on observed FG attempts only
- Assumption: missing data is irrelevant
- Brier: 0.101 | AUC: 0.808 (in-sample); best out-of-sample CV performance

### M2 — Inverse Probability Weighting (IPW)
- Same architecture as M1, but each attempt is weighted by its **inverse propensity to be attempted**
- Goal: up-weight attempts in situations where a coach rarely kicks, simulating the unobserved population
- In-sample best on Brier (0.099), Accuracy (0.871), Precision (0.874)
- Out-of-sample performance slightly worse than M1; IPW improves deep-tail (50+ yard) calibration but overall calibration regresses slightly

### M3 — Augmented (Pseudo-Label Hard Negatives)
- Trains on: FG attempts + PATs + filtered non-attempts
- Non-attempts are pseudo-labeled as **misses** (hard negative)
- Filter for inclusion: attempt propensity ≥ 25%, distance > 33 yards → N = 1,789 non-attempts included
- PATs and non-attempts both weighted at **0.10** (conservative, small-weight influence)
- Metrics evaluated on FG subset only
- Key finding: M3 predicts ~3–3.4% lower success probability at 50+ yards than M1 ("Pessimism Gap") — this represents the hidden difficulty of kicks never taken
- No global performance improvement over M1; augmentation introduces more noise than signal

---

## 5. Propensity / Attempt Model (π)

**Purpose:** Estimate P(FG Attempt | game state X) across the full kickable 4th-down universe  
**Method:** Multinomial Logistic Regression predicting three outcomes — Field Goal Attempt, Punt, Go For It (Pass/Run)  
**Training:** Rolling window (train on prior 3 seasons, predict current season) to capture era drift and evolving coaching aggressiveness  
**AUC by season:** 0.938 – 0.960

**Features:**
- Game state: leverage (WP impact), score differential, time remaining
- Environment: wind (z-score), temperature (z-score), stadium effects
- Geometry: yards to go, yardline

**PATs:** Set π = 1 (certain attempts)

**IPW Weight Pipeline (4-step stabilization):**
1. **Probability clipping** to [0.02, 0.98] for numerical stability
2. **Stabilized IPW:** w_raw = Training Prevalence (FG, ~52–58% per season) / p_hat_clipped — centers weights near 1.0 rather than scaling to sample size
3. **Hájek season normalization:** Scale so mean weight = 1 within each season — controls for era effects
4. **Outlier control:** Cap at mean + 3 SD, then re-normalize to mean = 1

**Final weight summary stats (FG subset, N = 10,432):**
- Min: 0.617 | Median: 0.698 | Mean: 0.944 | Max: 8.55 | SD: 0.875
- Effective Sample Size (ESS): 5,612 (ESS ratio: 0.538)

The weight distribution is right-skewed as expected — rare long attempts in standard game situations ("unicorn kicks") receive the highest weights (max 8.55). These are not desperation heaves; they are normal-game-state long kicks in Q1/Q2 that coaches almost always punt instead.

---

## 6. Key Findings & Narrative

### 6.1 The Decision Zone (45–55 yards)
The 45–55 yard range is strategic "no man's land." All three options (FG, punt, go for it) have comparable WPA, and punting yields only ~20 net yards. Coaches declining kicks in this zone are acting **rationally to maximize win probability**, not signaling lack of confidence in the kicker. This has a critical modeling implication: pseudo-labeling these non-attempts as "misses" is structurally incorrect — it penalizes the kicker for the coach's correct strategic decision to chase a touchdown.

### 6.2 Rationality Confirmed
WPA analysis shows "go for it" dominates from approximately 45–55 yards in modern NFL (2022–2024), and FG dominates at very short distances. The strategic shift from 2015–2017 to 2022–2024 shows a meaningful increase in "go for it" frequency in the 40–55 yard range. Propensity scores capture this behavioral shift via the rolling-window training.

### 6.3 IPW Improves Tail Calibration, Not Global Performance
M2 (IPW) is the best in-sample model. It learns that long kicks are harder by up-weighting the rare ones. However, out-of-sample CV shows M1 generalizes slightly better globally. The IPW improvement is concentrated in the 50+ yard tail — the region where observed data is most biased.

### 6.4 The Pessimism Gap (~3–3.4%)
M3 (Augmented) predicts systematically lower success probability at 50+ yards vs. M1. This gap quantifies the optimism bias in observed attempts: the kicks coaches *do* allow at long distance are a positively selected subset. The "true" universe of long kicks would succeed at a lower rate.

### 6.5 Kicking Has Changed Radically (2015–2024)
- Average attempt distance has risen from ~37.5 to ~40 yards
- Volume of 50+ yard attempts has nearly doubled
- Make% on 50+ yard attempts has trended upward (~60% → ~70%)
- Overall make% has been stable at ~84–87%
- This evolution provides strong motivation for era-aware modeling (rolling-window propensity, season random effects)

### 6.6 FGOE Leaderboard (Supplemental)
Using the kicker-agnostic M1 model, FGOE (Field Goals Over Expectation) rankings are computed as actual make% minus environment-adjusted expected make%. Top performers (2015–2024):
- B. Aubrey (+9%), C. Dicker (+6.1%), J. Tucker (+5.1%)
- Bottom: J. Moody (-8.4%), C. Ryland (-7%), C. Barth (-6.2%)

B. Aubrey is the standout case — highest FGOE while also carrying the hardest workload (highest average attempt distance, lowest mean propensity to attempt).

---

## 7. Evaluation Metrics

Primary:
- **Brier Score** (MSE for probabilities — lower is better)
- **AUC** (discrimination — TPR vs. FPR across thresholds)

Secondary:
- Accuracy, Precision (Make), Recall (Make)
- Calibration curves (predicted vs. observed, by distance bin)
- Residual bias curves (Predicted – Observed across kick distance)
- Global probability density and Make vs. Miss separation plots

Cross-validation: Rolling-origin OOF for propensity model; standard train/test for outcome models

---

## 8. Sample Sizes

| Dataset | N |
|---|---|
| Field Goal Attempts | 10,432 |
| PAT Attempts | 12,639 |
| All Non-Attempts (4th down no-kick) | 9,981 |
| M3 Included Non-Attempts (filtered) | 1,789 |

---

## 9. Codebase Context & Refactoring Goals

The codebase is built in **R** using `glmmTMB`, `nflfastR`, and supporting tidyverse tooling. The notebook is being refactored to:

1. Consolidate data prep, propensity modeling, IPW weight pipeline, and outcome model training into a clean, sequential pipeline
2. Separate model training from evaluation and visualization
3. Ensure rolling-window OOF propensity predictions are cleanly joined back to the attempt data before weighting
4. Ensure M3 augmented dataset construction (PAT + filtered non-attempts + FG) is modular and the weight assignment is transparent
5. Support academic paper figure reproduction — all key plots should be reproducible from saved model objects and clean data frames

**Priority areas for refactoring:**
- IPW weight pipeline (clipping → stabilization → Hájek normalization → 3-sigma cap → re-normalization)
- M3 dataset construction and pseudo-label logic
- Out-of-sample cross-validation setup for M1 vs. M2 comparison
- FGOE computation from kicker-agnostic model predictions vs. actual outcomes

---

## 10. Paper Structure (Target)

1. **Introduction** — Selection bias problem, rational agent hypothesis, research goal
2. **Data & Methodology** — Data universe, propensity model, model hierarchy (M0–M3)
3. **Results** — In-sample leaderboard, calibration surprise, deep-tail behavior
4. **Discussion** — The Pessimism Gap, discrimination analysis, operational vs. evaluative model use cases
5. **Conclusion** — Structural bias confirmed, two-track model recommendation

**Key figures needed:**
- Propensity overlap density (attempted vs. non-attempted)
- Truth Curve (predicted vs. binned actual by model)
- Bias/Residual Curve (predicted – observed across distance)
- Model diagnostics: global vs. deep kicks (Brier + mean probability by Make/Miss)
- FGOE leaderboard bar chart
- Skill vs. Workload matrix scatter
- Strategic decision landscape (4th down decisions by distance, era comparison)
- WPA by decision type
- Kicking strategy shift 2015 vs. 2024 (density plot)