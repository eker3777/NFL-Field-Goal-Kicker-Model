# NFL Field Goal Kicker Model

This repository contains the replication code, data placeholders, figures, Quarto manuscript, and conference presentation for the paper: **"Here's the Kicker: Correcting Selection Bias in NFL Field Goal Models via Inverse Probability Weighting"**.

The project investigates how to address selection bias in observed field goal attempts—since coaches selectively attempt field goals under favorable game states—using inverse probability weighting (IPW) and data augmentation.

---

## 1. Project Overview & Pipeline Roadmap

The workflow is structured as a sequential **notebook-first** pipeline in R (using the IRkernel in Jupyter). Each stage can be executed independently (loading intermediate CSV artifacts) or run end-to-end.

| Notebook | Focus | Key Deliverables / Artifacts |
| :--- | :--- | :--- |
| [`01_data_prep.ipynb`](notebooks/01_data_prep.ipynb) | Modernizes and prepares nflfastR play-by-play data. | Cleans, joins, and engineers baseline features for all kickable plays and actual attempts. Writes `fg_all.csv` and subset files under `data/`. |
| [`02_propensity.ipynb`](notebooks/02_propensity.ipynb) | Estimates attempt propensity $\pi(X) = P(\text{attempt} \mid X)$. | Fits a rolling-origin multinomial classifier over the fourth-down decision frame ($n = 44{,}395$ plays, full field; see §3). Computes stabilized, clipped, capped IPW weights. |
| [`03_models.ipynb`](notebooks/03_models.ipynb) | Fits success outcome models M0, M1, M2, M3. | Fits distance-only (M0), baseline GLMM (M1), **data-augmented pseudo-label GLMM (M2)**, and **IPW-weighted GLMM (M3)**. Outputs predictions to `fg_full_with_predictions.csv` and model coefficients. |
| [`04_evaluation.ipynb`](notebooks/04_evaluation.ipynb) | Computes global and distance-band metrics. | Brier scores, AUC, log-loss, and calibration error across models for in-sample (full-dataset, Option B) and out-of-sample (test-split) evaluations. Writes `metrics_table.csv`. |
| [`05_visuals.ipynb`](notebooks/05_visuals.ipynb) | Generates all manuscript figures. | Data overview dashboard, calibration and separation curves, out-of-sample probability density, win probability added, and attempt propensities. Writes to `reports/figures/`. |

> **Model naming.** M2 is the **augmented** model (PATs plus non-attempt pseudo-misses); M3 is the **IPW-weighted** model. Earlier drafts of this README had these two reversed.

---

## 2. Repository Layout

```
├── Paper/
│   ├── Field_Goal_Kicking_IPW/       # v1 manuscript (current submitted state)
│   │   ├── index.qmd                 # Quarto paper source
│   │   ├── index.pdf                 # Compiled PDF
│   │   ├── references.bib            # BibTeX bibliography
│   │   └── _quarto.yml               # Quarto manuscript configuration
│   ├── Field_Goal_Kicking_IPW_v2/    # v2 structural draft (reorganization only)
│   │   ├── index.qmd                 # Trends moved to §3; weighting to §4.5; FGOE removed
│   │   └── _quarto.yml
│   └── References/                   # Academic papers and reference material
├── Presentation/                     # Conference deck (Vancouver, Sept 2026)
│   ├── heres_the_kicker_slides.qmd   # Revealjs + pptx source, 15 slides
│   ├── heres_the_kicker_slides.html  # Self-contained revealjs build
│   ├── heres_the_kicker_slides.pptx  # Editable PowerPoint build
│   ├── make_slide_figures.R          # Regenerates deck figures at slide scale
│   ├── _slide_common.R               # Shared theme + data loading
│   ├── custom.scss                   # Deck styling
│   └── figures/                      # Slide-scale figures (separate from reports/figures/)
├── config/
│   └── params.yaml                   # Optional pipeline parameter overrides
├── data/
│   └── .keep                         # Data folder placeholder (actual CSVs are git-ignored)
├── notebooks/                        # 01-05, run in order
├── reports/
│   ├── .keep
│   └── figures/                      # Manuscript figures (git-tracked)
├── scripts/                          # Audit and validation helpers
├── README.md
└── .gitignore
```

> `Presentation/figures/` and `reports/figures/` are deliberately separate. Notebook 05 clears and rebuilds `reports/figures/` wholesale on every run, so the deck keeps its own copies at a different type scale.

---

## 3. Sample Definitions

Several distinct populations appear in this pipeline and are easy to confuse. The canonical counts, all computed from `data/fg_all.csv`:

| Population | Filter | n |
| :--- | :--- | ---: |
| All rows | `fg_all.csv`, seasons 2000–2025 | 137,668 |
| **Propensity model frame** | Non-PAT; `play_type_original ∈ {field_goal, pass, run, punt}`; `yardline_100` and `game_seconds_remaining` present; seasons 2015–2025. **All field positions** | **44,395** |
| — of which field goal attempts | | 11,764 |
| — of which punts | | 25,070 |
| — of which go-for-it | | 7,561 |
| — of which in kicking range (`yardline_100 ≤ 53`) | | 22,879 |
| **Outcome model analysis set** | Field goal attempts, 2015–2025, blocked kicks excluded | **11,548** |
| — training attempts | disjoint games | 9,297 |
| — held-out test attempts | 593 games | 2,251 |
| **M2 non-attempt pool** | Non-PAT, `attempted == 0`, `kick_distance ≤ 70`, seasons 2015–2025 | 11,142 |
| — after the π̂ ≥ 0.25 and distance > 33 screens (what M2 actually trains on) | | 1,923 |
| — all non-attempts, unrestricted, 2015–2025 | | 32,666 |
| — same, all seasons 2000–2025 | | 78,563 |
| **PAT pool** (M2 augmentation) | `is_pat == 1`, seasons 2015–2025 | 14,073 |

Two cautions:

1. **The M2 non-attempt pool is not nested inside the propensity frame.** It contains only non-attempts, so it holds no field goal attempts at all. The two counts are separate populations, not stages of one filter chain.
2. **The propensity frame spans the whole field, on purpose.** The coaching decision exists at every field position, so restricting it to kicking range would hide most punts from a model of when teams punt. The frame is defined on `yardline_100`, not on the hypothetical kick distance a non-attempt would have produced.
3. **The M2 pool is bounded at 70 yards** because a non-attempt's `kick_distance` is a construction (`yardline_100 + 17`) that only means anything inside kicking range, and because the outcome model's B-spline is defined on [18, 70]. Rows beyond that would be extrapolated.
4. **The propensity frame is defined without any `ydstogo` screen.** Notebook 05's `decision` frame additionally requires `ydstogo >= 1` for the decision-share plots, which drops exactly one row. Use the definition in the table above whenever reporting the size of this population.

---

## 4. Getting Started

### Prerequisites
1. Install **R** and the **IRkernel** so Jupyter can run R notebooks.
2. Install the following R packages:
   ```R
   install.packages(c("dplyr", "tibble", "tidyr", "readr", "stringr", "purrr",
                      "ggplot2", "ggrepel", "scales", "patchwork", "pROC",
                      "glmmTMB", "splines2", "nnet"))
   ```
3. Install **Quarto** if you wish to recompile the manuscript or the presentation.

### Running the Pipeline
1. Clone this repository.
2. Provide raw nflfastR play-by-play data under `data/`.
3. Execute the notebooks in `notebooks/` in order (`01` through `05`).
4. Recompile the manuscript:

```bash
quarto render Paper/Field_Goal_Kicking_IPW/index.qmd --to pdf
```

### Building the Presentation
Regenerate the slide-scale figures, then render both output formats:

```bash
Rscript Presentation/make_slide_figures.R
```

```bash
quarto render Presentation/heres_the_kicker_slides.qmd --to revealjs
```

```bash
quarto render Presentation/heres_the_kicker_slides.qmd --to pptx
```

---

## 5. Key Findings

- **Coaching selection is strongly structured.** The multinomial attempt-propensity model achieves out-of-fold AUC between 0.933 and 0.959 **within kicking range** in every season from 2015 to 2025 (0.976–0.987 across the full field), confirming that attempt selection is predictable rather than idiosyncratic.
- **Augmentation (M2) does not work.** Adding PATs and non-attempt pseudo-misses fails to beat M1 on either split, and fit degrades monotonically as the augmentation weight rises (in-sample Brier 0.1007 → 0.1016 across the 0.05–0.25 grid). This is the signature of a label that is wrong in a known direction. The PAT block contributes essentially nothing.
- **IPW (M3) corrects in-sample and fails to generalize.** M3 achieves the best in-sample fit on every metric (Brier 0.0982, log-loss 0.3216, AUC 0.805), with gains concentrated in the tail: a **24.2% Brier reduction at 60+ yards** and **5.8% at 50–59 yards** versus M1. Out of sample the ordering reverses — M1 leads (Brier 0.1004, log-loss 0.3295, AUC 0.769) and M3 (0.1030 / 0.3383 / 0.757) trails even the distance-only M0 (0.1012).
- **The reversal is stable, not an artifact.** M1 beats M3 out of sample in both the pre-2020 and post-2020 halves, on both proper scoring rules. A season-stratified permutation test over 2,000 redraws confirms the held-out split is an unremarkable draw ($p = 0.68$).
- **Recommendation.** Use the unweighted GLMM (M1) for in-game make probability. M3's role is diagnostic — it shows where selection bias acts — and it supplies the population-marginal baseline (M3-pop) used by the follow-on kicker-evaluation work.

### Planned follow-on papers
1. **This paper** — GLMM + IPW selection correction (M1–M3).
2. **Kicker evaluation** — field goals over expectation (FGOE) built on M3-pop.
3. **Causal inference** — a causal treatment of the attempt decision.

Field goal kicking trends run through all three.
