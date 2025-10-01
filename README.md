# NFL Field Goal Kicker Model

## Project Goals & Flow
- Establish a notebook-first workflow for modeling NFL kicker decision making and execution.
- Preserve legacy exploratory notebooks and samples under `Reference/` for context.
- Build a staged pipeline:
  1. Estimate attempt propensity \(\pi(X)\) for kickable fourth downs (PATs assumed attempted).
  2. Model win probability deltas for field goal vs go-for-it decisions.
  3. Fit IPW-weighted field goal/PAT success models.
  4. Produce AIPW pseudo-outcomes for evaluation across all decisions.
  5. Report predictive and standardized skill views for stakeholders.

## Notebook-First Philosophy
- Core logic, feature engineering, and diagnostics live directly inside the notebooks.
- Each notebook includes parameters, helper functions, and reporting cells so it is runnable on its own.
- Optional overrides can be supplied via `config/params.yaml`, but every notebook carries sane defaults in-code.
- Keep helper functions short (≤40 lines) and colocated in the "Utilities & Helpers" cell for discoverability.

## Repository Structure
```
Reference/           # Legacy notebooks and sample data (read-only)
notebooks/           # Primary modeling workflow (R notebooks via IRkernel)
data/                # Local working data (ignored, `.keep` placeholder)
reports/             # Generated plots, tables, diagnostics (`.keep` placeholder)
config/params.yaml   # Optional parameter overrides (mirrors in-notebook defaults)
```

## Quickstart in VS Code
1. Install R and the [IRkernel](https://irkernel.github.io/installation/).
2. Clone this repository and open the folder in VS Code.
3. Use the Jupyter extension and select the "R" kernel (IRkernel) for each notebook.
4. Open `notebooks/01_attempt_pi.ipynb`.
5. In the first code cell, ensure `SMOKE_MODE <- TRUE` to enable fast, sample-based execution.
6. Run all cells. The notebook will read from the samples in `Reference/` and write lightweight artifacts to `reports/`.
7. Disable `SMOKE_MODE` when ready to process full datasets (ensure local data lives under `data/`).

## Data Handling Expectations
- Keep large or sensitive raw data out of git; place working copies under `data/` (ignored).
- Sample CSVs are stored under `Reference/` for smoke testing and documentation.
- Generated reports, plots, and tables should land in `reports/` and will be ignored by git except for intentional artifacts.

## Reporting Views
- **Predictive (Operational) View**: Uses the IPW-weighted models as deployed to assess current performance and calibration.
- **Standardized Skill View**: Scores kickers on a reference grid of situations without control-function covariates to compare underlying skill.

Each notebook saves at least one artifact in `reports/` (e.g., CSV summary, PNG plot) and writes session metadata to `reports/session_info.txt` when run.
