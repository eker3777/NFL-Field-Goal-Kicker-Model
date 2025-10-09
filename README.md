# NFL Field Goal Kicker Model

## Project Vision
- Build a **notebook-first** workflow where every stage of the kicker modeling pipeline can run directly from an R (IRkernel) Jupyter notebook.
- Preserve the legacy exploratory work under `Reference/` as read-only context for data lineage and sanity checks.
- Prioritize transparency: each notebook declares its own defaults, utilities, and artifacts so it can be executed independently without relying on external packages or modules beyond CRAN libraries.

## Pipeline Roadmap
| Notebook | Focus | Key Notes |
| --- | --- | --- |
| `01_data_prep.ipynb` | Carry forward and modernize the data preparation steps from the reference notebooks. | Cleans, joins, and engineers baseline features for kickable plays. |
| `02_attempt_pi.ipynb` | Estimate attempt propensity \(\pi(X) = P(\text{FG attempt} \mid X)\). | Rolling-origin out-of-fold predictions across 2015–2024 with stabilized, clipped weights and effective sample size diagnostics. |
| `03_xwp_modules.ipynb` | **Optional / paused** xWPA and conversion modules. | Placeholder scaffolding for future work on WP deltas and conversion rates (not required for the π-only core). |
| `04_xfg_success_ipw.ipynb` | Fit success models M1 (baseline) and M2 (IPW + control-function). | Cloglog `glmmTMB` models for kicks, treating blocks as misses and setting PAT weights to 1. Includes a template for the optional M3 pseudo-label experiment. |
| `05_aipw_eval.ipynb` | Evaluate the models with AIPW pseudo-outcomes. | Builds the full kickable decision set, computes AIPW outcomes, and prepares calibration/Brier diagnostics. |
| `06_reporting_views.ipynb` | Package results for consumers. | Creates predictive (operational) and standardized skill views; standardized view drops the control-function covariate. |

> **PAT Handling:** PATs enter the pipeline with \(\hat{\pi} = 1\Rightarrow w = 1\). Blocks are always recorded as misses. Weight clipping defaults to `[0.05, 0.98]` with stabilized means near 1.0.

## Notebook-First Conventions
- Each notebook starts with a header markdown cell summarizing purpose, inputs, outputs, and quick links.
- `SMOKE_MODE <- TRUE` by default for fast sanity checks on the sample CSVs under `Reference/`. Toggle to `FALSE` for full modeling runs.
- Default parameters live inside the notebooks (`time_knots`, `late_flags`, clipping bounds, spline degrees of freedom, etc.). If `config/params.yaml` exists, overrides are merged, but notebooks never depend on it.
- A dedicated "Utilities & Helpers" cell holds lightweight helper functions (≤40 lines each) for feature engineering, weighting, calibration, and plotting.
- The final cell in every notebook writes `sessionInfo()` to `reports/session_info.txt` so downstream consumers can audit package versions.

## Getting Started in VS Code
1. Install R and the [IRkernel](https://irkernel.github.io/installation/).
2. Clone the repository and open it in VS Code with the Jupyter extension enabled.
3. Open any notebook under `notebooks/` (start with `01_data_prep.ipynb`).
4. Ensure the first code cell reads `SMOKE_MODE <- TRUE` for fast execution against the `Reference/` samples.
5. Run all cells. Artifacts (CSV summaries, diagnostic placeholders, etc.) are written to `reports/` and ignored by git by default.
6. When ready for full seasons, set `SMOKE_MODE <- FALSE`, provide raw data under `data/`, and (optionally) add overrides in `config/params.yaml`.

## Repository Layout
```
Reference/           # Legacy notebooks & sample CSVs (read-only)
notebooks/           # Primary modeling workflow (IRkernel notebooks)
data/.keep           # Placeholder for local data (git-ignored)
reports/.keep        # Placeholder for generated artifacts (git-ignored)
config/params.yaml   # Optional parameter overrides (never required)
```

## Reporting Views
- **Predictive (Operational):** Uses the IPW + control-function model (M2) on application data to describe current decision quality and calibration.
- **Standardized Skill:** Re-scores kickers on a reference state grid without the control-function covariate to compare underlying execution skill across common scenarios.

Both views rely on the π-only core; the xWPA notebook remains optional/paused until the win-probability modules are revisited.

## Next Steps
- PR#2 will implement the full rolling-origin attempt propensity workflow (`02_attempt_pi.ipynb`) and flesh out success models (`04_xfg_success_ipw.ipynb`).
- PR#3 will focus on AIPW evaluation, reporting views, and ensuring `SMOKE_MODE` delivers fast end-to-end smoke tests.
