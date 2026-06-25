# NFL Field Goal Kicker Model

This repository contains the replication code, data placeholders, figures, and Quarto manuscript source files for the paper: **"Here's the Kicker: Correcting Selection Bias in NFL Field Goal Models via Inverse Probability Weighting"**.

The project investigates how to address selection bias in observed field goal attempts—since coaches selectively attempt field goals under favorable game states—using Inverse Probability Weighting (IPW) and data augmentation.

---

## 1. Project Overview & Pipeline Roadmap

The workflow is structured as a sequential **notebook-first** pipeline in R (using the IRkernel in Jupyter). Each stage can be executed independently (loading intermediate CSV artifacts) or run end-to-end.

| Notebook | Focus | Key Deliverables / Artifacts |
| :--- | :--- | :--- |
| [`01_data_prep.ipynb`](notebooks/01_data_prep.ipynb) | modernizes and prepares nflfastR play-by-play data. | Cleans, joins, and engineers baseline features for all kickable plays and actual attempts. Writes `fg_all.csv` and subset files under `data/`. |
| [`02_propensity.ipynb`](notebooks/02_propensity.ipynb) | Estimates attempt propensity $\pi(X) = P(\text{attempt} \mid X)$. | Fits a rolling-origin multinomial classifier across all 4th down plays ($n = 32{,}666$ plays). Computes stabilized, clipped IPW weights. |
| [`03_models.ipynb`](notebooks/03_models.ipynb) | Fits success outcome models M0, M1, M2, M3. | Fits distance-only (M0), baseline GLMM (M1), IPW-weighted GLMM (M2), and data-augmented pseudo-label GLMM (M3) models. Outputs predictions to `fg_full_with_predictions.csv` and model coefficients. |
| [`04_evaluation.ipynb`](notebooks/04_evaluation.ipynb) | Computes global and distance-band metrics. | Calculates Brier scores, AUC, log-loss, and calibration error across models for in-sample (full-dataset, Option B) and out-of-sample (test-split) evaluations. Writes `metrics_table.csv`. |
| [`05_visuals.ipynb`](notebooks/05_visuals.ipynb) | Generates all manuscript figures. | Creates and saves diagnostic curves (calibration, separation density, tail density, win probability added, and attempt propensities) directly referenced in the paper. |

---

## 2. Repository Layout

```
├── Paper/
│   ├── Field_Goal_Kicking_IPW/
│   │   ├── index.qmd             # Quarto paper source manuscript
│   │   ├── index.pdf             # Compiled PDF of the paper
│   │   ├── references.bib        # BibTeX bibliography
│   │   └── _quarto.yml           # Quarto manuscript configuration
│   └── References/               # Academic papers and reference material
├── config/
│   └── params.yaml               # Optional pipeline parameter overrides
├── data/
│   └── .keep                     # Data folder placeholder (actual CSVs are git-ignored)
├── notebooks/
│   ├── 01_data_prep.ipynb        # Data preparation stage
│   ├── 02_propensity.ipynb       # Propensity modeling stage
│   ├── 03_models.ipynb           # Model fitting stage
│   ├── 04_evaluation.ipynb       # Evaluation stage
│   └── 05_visuals.ipynb          # Visual analytics & figures stage
├── reports/
│   ├── .keep                     # Reports folder placeholder
│   └── figures/                  # Final generated manuscript figures (git-tracked)
├── README.md                     # Project documentation
└── .gitignore                    # Git ignore configurations
```

---

## 3. Getting Started

### Prerequisites
1. Install **R** and the **IRkernel** so Jupyter can run R notebooks.
2. Install the following R packages:
   ```R
   install.packages(c("dplyr", "tibble", "tidyr", "readr", "stringr", "purrr",
                      "ggplot2", "ggrepel", "scales", "patchwork", "pROC", "glmmTMB"))
   ```
3. Install **Quarto** if you wish to recompile the paper manuscript.

### Running the Pipeline
1. Clone this repository.
2. Provide raw nflfastR play-by-play data under the `data/` directory (or use default sample variables if running in smoke test mode).
3. Execute the notebooks in `notebooks/` in sequential order (`01_data_prep.ipynb` through `05_visuals.ipynb`).
4. Recompile the manuscript:
   ```bash
   cd Paper/Field_Goal_Kicking_IPW
   quarto render index.qmd --to pdf
   ```

---

## 4. Key Findings

- **In-Sample descriptive fit**: Reweighting attempts via IPW (M2) significantly reduces calibration errors on the upweighted long-distance kicks, achieving a **22.8% Brier score reduction** at 60+ yards and a **5.6% Brier score reduction** at 50-59 yards versus M1 in-sample.
- **Out-of-Sample generalization**: On held-out test data, M1 (Brier 0.1007, AUC 0.769) outperforms the corrective M2 model (Brier 0.1029, AUC 0.760), indicating that the tail variance fit by IPW does not generalize to future unseen attempts.
- **Strategic applications**: We introduce **Field Goal Outcome Expectation (FGOE)**, calculated using a population-marginal version of the IPW model (`M2-pop`), as a more robust kicker evaluation metric.
