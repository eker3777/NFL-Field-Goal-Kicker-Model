# Review Response Plan — "Here's the Kicker"

**Purpose.** This document translates the reviewer's comments (see `Review of Heres the Kicker.qmd`)
into concrete, located edits for the manuscript (`Paper/Field_Goal_Kicking_IPW/index.qmd`) and the
notebooks (`notebooks/01`–`05`). It is a hand-off spec for a local, Git-connected editor. **No files
have been edited yet.**

**Environment note.** These changes were planned in an environment with **no R and no data** (the
CSVs are git-ignored). Every item tagged `[CODE]` must be **run locally** to produce numbers/figures;
the manuscript's numeric tables should not be updated until the local run is complete and verified.

**Tags**
- `[PAPER]` — manuscript prose only; no model re-run; safe to do immediately.
- `[CODE]` — notebook edit requiring a local re-run; regenerates numbers/figures.
- `[DEFER]` — intentionally postponed to a later pass (drafted as a TODO note, not executed now).

**Locked decisions (from author)**
- Season term: **within-window linear centered-season trend** in the propensity model (not an era
  random effect — `nnet::multinom` is fixed-effects only and folds hold only 3 seasons), **plus**
  era-stratified (pre-/post-2020) reporting of the selection-bias result.
- M2-pop: implement **both** the refit variant and the marginalization (`re.form = NA`) variant;
  compare **out-of-sample**; keep the better one for FGOE.
- Weather non-linearity: **simpler option** — spline `wind`, `temp`, `humidity` as main effects;
  **drop** the wind×distance-spline interactions; keep `rain`/`snow` as binary flags.
- Humidity: add to the outcome model and to the paper formula.
- M2→M3 relabel and major narrative re-org: **deferred**, pending co-author input.

---

## 0. Draft banner / deferred TODOs (do first, as a visible note)

`[DEFER]` Add an HTML comment / `.callout-note` block at the very top of `index.qmd` (below the YAML
front matter) listing the items we are deliberately holding for a later pass, so no one mistakes the
draft for final:

```
<!-- DRAFT — PENDING FINAL PASS. Do not treat as camera-ready.
  TODO (final pass, after content is approved):
   1. Figure numbering: convert every bare ![](...) to a Quarto #fig- cross-reference with a caption.
   2. Bridge paragraphs: add intro text under §4→§4.1 and §5→§5.1 (currently heading-on-heading).
   3. Section numbering: §7 jumps 7.1 → 7.3 (no 7.2). Renumber.
   4. Model relabel: possible M2↔M3 swap (rough-ideation-first narrative) — pending co-author.
   5. Major narrative re-org: move raw-data exploration (parts of §7) ahead of the propensity model.
-->
```

These five are **not** executed in this pass by author instruction.

---

## 1. Manuscript prose changes — `[PAPER]`, no re-run

### 1.1 Fix the M3 PAT mis-framing (correctness)
- **Where:** §4.1, "**M3 (augmented GLMM)**" paragraph (the sentence describing PATs as
  "pseudo-successes with `aug_weight` = 0.10"); also check the Abstract wording.
- **Problem:** The code (`03_models.ipynb`, M3 cell) sets
  `kick_made = as.integer(kick_result == 'made')` for PATs — i.e. **PATs enter with their real,
  observed make/miss outcome, merely down-weighted to 0.10.** They are *not* labeled as certain
  successes. Only **non-attempts** are hard pseudo-misses (`kick_made = 0L`).
- **Fix:** Rewrite to: "augmented with PAT attempts carrying their **observed** outcomes at a reduced
  case weight (`aug_weight = 0.10`), and non-attempt fourth-down situations treated as pseudo-misses
  (`kick_made = 0`, `aug_weight = 0.10`)…". This directly resolves the reviewer's "PAT success rate
  is .9x, not 1" objection — it no longer applies.

### 1.2 Justify the M3 cutoffs and the non-attempt pseudo-miss (motivation)
- **Where:** §4.1 M3 paragraph and/or §4.3.
- **Add** the author's rationale:
  - `propensity ≥ 0.25`: a reasonable threshold for "plausibly-considered" attempts; below it we
    assume the coach had sound game-context reasons **not** to kick, so those plays carry little
    kicker-difficulty signal.
  - `distance > 33 yds`: beyond PAT distance (the post-2015 extra point is a ~33-yд kick). Inside 33
    yards makes are near-certain and highly predictable, and non-attempts there reflect **aggressive
    strategic choices** (go-for-it), not kicker selection.
  - **State the induced bias explicitly:** this labels all qualifying beyond-33 non-attempts as
    misses, which is an approximation, not ground truth — hence M3's exploratory status.
- **On the reviewer's "0.3, not 0" point:** add one sentence — the outcome model requires a binary
  Bernoulli response, so non-attempts must be labeled; their influence is dampened via `aug_weight`,
  and an exhaustive weighting search (separate notebook) found no scheme beating M1. (Soft-label
  alternative is raised in the co-author email, not adopted here.)

### 1.3 Reframe the paper as explicitly non-causal
- **Where:** §9 item 1 (promote and expand); add a short paragraph in §8.1 or a new §9 note.
- **Do:**
  - Replace casual/causal-sounding phrasing with estimand-precise language (we estimate a
    **selection-reweighted / population-marginal success probability**, not a counterfactual).
  - Add an explicit contrast: a **fully causal** treatment would require a defined counterfactual
    estimand (e.g. `E[Y(attempt)]` over all kickable plays), and the identification assumptions —
    positivity/overlap, no unmeasured confounding of the attempt decision (conditional ignorability),
    and SUTVA. Note which we can/can't defend.
  - State benefits/drawbacks of our approach vs. a causal one: IPW reweighting gives a transparent,
    low-assumption population-marginal baseline useful for evaluation, but does **not** identify a
    causal effect and should not be read as one.

### 1.4 Expand the propensity-model logic and explain leverage as a WP proxy
- **Where:** §3.2 (the `leverage_z` bullet) — promote to its own short paragraph; reference from §3.1.
- **Do:** Explain that the propensity model already incorporates **win-probability information** via
  `leverage_z`, defined as a standardized estimate of the **post-kick win-probability gap** between
  making and missing a field goal, built from custom fractional-logit models with explicit endgame
  rule overrides. Explain **why bespoke** rather than an off-the-shelf EP/WP model: it targets the
  make-vs-miss WP differential that actually drives the 4th-down kick decision, tailored to this use
  case. This answers the reviewer's EP/WP suggestion (we use WP by proxy, purpose-built).

### 1.5 Review and (if sound) collapse the §2.3 double normalization
- **Where:** §2.3, the 5-step weight pipeline (steps 3 and 5).
- **Assessment:** The two normalizations are **not redundant** — step 4 (3σ cap) perturbs the mean,
  so step 5 restores per-season mean = 1 **after** capping. Keep both, but tighten the prose so the
  logic reads as **normalize → cap → renormalize** (the cap is bracketed by the two normalizations).
- **Fix:** Rewrite steps 3–5 as a single clear sentence making the bracketing explicit, rather than
  three separate steps that read as duplicative. Answers the reviewer's "is step 3 needed given
  step 5" question.

### 1.6 Add humidity to the model description
- **Where:** §2.2 (feature list) and §4.1 M1 formula.
- **Do:** Add `humidity_z` as a standardized environmental covariate in the covariate list, and add a
  `+ β·humidity_z` term to the M1 formula block. (Numbers pending the `[CODE]` run in §2.1.)

### 1.7 Add log-loss to the results tables
- **Where:** `@tbl-model-metrics` (§5.1) and optionally `@tbl-m3-grid`.
- **Do:** Add **IS log-loss** and **OOS log-loss** columns. The metric is **already computed** by
  `calc_metrics()` in `04_evaluation.ipynb` (`logloss = logloss(y, p)`), so this is a table-structure
  edit; fill the values from the local run. Answers the reviewer's log-loss request.

---

## 2. Notebook code changes — `[CODE]`, require local re-run

> Downstream chain to remember: **02 (weights/propensity) → 03 (models/predictions) →
> 04 (metrics) → 05 (figures) → paper tables.** Any change upstream requires re-running everything
> below it.

### 2.1 Humidity into the outcome models
- **File:** `notebooks/03_models.ipynb`, "**7. Model Formulas**" cell (`form_m1`), and the
  feature-engineering cell.
- **Precondition:** confirm `01_data_prep.ipynb` §6 produces a standardized `humidity_z`
  (temp/wind are z-scored there; `humidity` is parsed + imputed but **verify it is also z-scored** —
  add the z-score if missing, standardized over the same attempted-kick set as temp/wind).
- **Change:** add `humidity_z` as a main effect to `form_m1`. M2, M3, M2-pop inherit `form_m1`
  automatically, so no separate edits — just re-fit all.
- **Also** add `humidity_z` to the paper formula per §1.6.

### 2.2 Weather non-linearity — simpler splined main effects
- **File:** `notebooks/03_models.ipynb`, `form_m1`.
- **Change (author-chosen simpler option):**
  - Replace the linear `wind` term and the **wind × distance-spline interaction** block
    (`Σ γ_k (w_i · b_k(d_i))`) and the `wind × temp` term with **natural-spline main effects** on
    `wind_z`, `temp_z`, `humidity_z` (e.g. `splines::ns(wind_z, df = 3)` etc.; pick df modestly).
  - Keep `rain_showers`, `snow_sleet`, `turf`, and the other binary/context flags unchanged.
- **Trade-off to note (for the local editor + paper):** dropping the wind×distance interaction
  assumes weather acts additively on the logit rather than amplifying with distance. This is the
  deliberate simplification; the "interactions everywhere" alternative was considered and rejected as
  overkill.
- **Paper:** update the §4.1 M1 formula to the splined-main-effects form and revise the §2.2 wording
  about wind-by-distance interactions accordingly.
- **Supporting exploratory viz (answers "what is the relationship?"):** in
  `05_visuals.ipynb`, add a raw make-rate-vs-`wind`/`temp`/`humidity` panel (binned/LOESS) so the
  relationship is shown, not just asserted.

### 2.3 Season term in the propensity model + era-stratified reporting
- **File:** `notebooks/02_propensity.ipynb`, "**5. Feature Construction**" cell.
- **Change:** add a **centered linear season trend** to the feature matrix `X`
  (`season_c = season_num - mean(season_num)` within each rolling window). Rationale: `nnet::multinom`
  is fixed-effects-only, and each rolling fold trains on just 3 seasons, so a spline/RE on season is
  not identifiable per fold; a centered linear trend captures within-window drift at 2 params/class.
  Re-run the rolling-origin OOF fit → regenerated propensities → **regenerated IPW weights** → this
  flows into M2/M2-pop.
- **Era-stratified analysis (the reviewer's real ask):** in `03_models.ipynb`/`04_evaluation.ipynb`,
  additionally report M1-vs-M2 OOS Brier/AUC **split into pre-2020 (2015–2019) and post-2020
  (2020–2025)** test kicks, to show whether the selection-bias answer differs by era.
- **Paper:** note the season feature in §3.3; add a short era-stratified result paragraph (§5 or §8).

### 2.4 M2-pop — implement both variants and compare OOS
- **File:** `notebooks/03_models.ipynb` (M2-pop cell) and prediction/eval cells; `04_evaluation.ipynb`
  §4b.
- **Change:** produce **two** population-marginal baselines:
  1. **Refit variant (current):** `form_m1` minus the kicker-season random intercept, refit with M2
     IPW weights (stadium RE retained).
  2. **Marginalization variant (reviewer's suggestion):** take the fitted **M2** and predict with the
     kicker random effect integrated out (`predict(..., re.form = NA)` for the kicker term; retain
     stadium). No separate refit.
- **Compare** the two on OOS Brier/log-loss and long-distance calibration; **keep the winner** as the
  FGOE baseline. Check the reviewer's specific worry: does the kicker-free **refit** bias long
  distances relative to marginalization?
- **Paper:** in §4.1 (M2-pop) and §6 (FGOE), report the comparison and state which baseline FGOE uses
  and why.

### 2.5 M3 — with/without PATs, expanded subsection
- **File:** `notebooks/03_models.ipynb`, M3 cell and the M3 sensitivity cell (§13).
- **Change:** add an M3 variant that **excludes PATs** (non-attempt pseudo-misses only), alongside the
  current PAT-inclusive variant. Compare IS/OOS. (Author expectation: little difference — worth
  showing.)
- **Paper:** expand §5.3 into a fuller M3 subsection presenting: the cutoff rationale (§1.2 above),
  the with/without-PAT comparison, and the existing weight-sensitivity grid — this reinforces the
  exploratory framing the reviewer asked for. Fix the mis-framing per §1.1.

### 2.6 Calibration chart redesign + multi-metric charts
- **File:** `notebooks/05_visuals.ipynb`, calibration cells (in-sample + test, producing
  `calibration_curves.png`, `calibration_test.png`) and a new metrics-comparison cell.
- **Change:**
  - **Redesign the calibration plots** for legibility: clear 45° reference line, decile (or
    equal-count) bins with observed-vs-predicted points, per-bin counts or a rug/histogram of
    predicted-probability mass, faceting or clean color separation across M0–M3, and readable
    axis/legend scaling. (Author: current versions are hard to read.)
  - **Add a multi-metric comparison chart**: grouped points/bars of **Brier, AUC, log-loss** across
    M0–M3 for IS and OOS, so the reviewer's requested metrics are visible at a glance.
- **Paper:** embed the redesigned calibration figure (answers "show a calibration plot") and,
  optionally, the multi-metric chart in §5.

---

## 3. Reviewer-comment → action map

| # | Reviewer comment | Action | Tag |
|---|---|---|---|
| Main-1 | Causal vs. casual; what full causal needs | §1.3 non-causal reframe | `[PAPER]` |
| Main-2 | Move raw-data exploration earlier | Deferred narrative re-org (banner) | `[DEFER]` |
| Main-3 | Propensity should account for season / era | §2.3 season trend + era-stratified report | `[CODE]` |
| Main-4a | M3 motivation | §1.2 motivation text | `[PAPER]` |
| Main-4b | Why cutoffs 0.25 / 33 yds | §1.2 justification | `[PAPER]` |
| Main-4c | Non-attempts as pseudo-miss unfair (0.3≠0) | §1.2 defense; soft-label → co-author email | `[PAPER]` |
| Main-4d | PATs as pseudo-success unfair (.9x≠1) | §1.1 — **mis-framing; PATs use real outcomes** | `[PAPER]` |
| Main-5 | M2-pop vs. zeroing kicker coefficients | §2.4 both variants, compare OOS | `[CODE]` |
| Other | Humidity | §2.1 + §1.6 add humidity | `[CODE]` |
| Other | Weather relationship / non-linearity | §2.2 splined main effects + raw viz | `[CODE]` |
| Other | §2.3 step 3 vs step 5 redundant | §1.5 review + collapse description | `[PAPER]` |
| Other | Use EP/WP in propensity | §1.4 explain leverage as WP proxy | `[PAPER]` |
| Other | Figures not numbered | Banner TODO | `[DEFER]` |
| Other | Log-loss in tables | §1.7 (metric already computed) | `[PAPER]` |
| Other | No text between §4/§4.1, §5/§5.1 | Banner TODO | `[DEFER]` |
| Other | Show a calibration plot | §2.6 redesign + embed | `[CODE]` |

---

## 4. Suggested execution order (dependencies)

1. **Paper-only prose** (§1.1–§1.7) — independent of any run; do first.
2. **Data check** — confirm/produce `humidity_z` in `01_data_prep.ipynb`.
3. **Propensity** — season trend in `02_propensity.ipynb`; re-run → new weights.
4. **Models** — humidity + splined weather in `form_m1`; M2-pop both variants; M3 with/without PAT
   in `03_models.ipynb`; re-run all fits.
5. **Evaluation** — `04_evaluation.ipynb`: metrics incl. log-loss, era-stratified split, M2-pop
   comparison.
6. **Visuals** — `05_visuals.ipynb`: calibration redesign, multi-metric chart, weather-relationship
   viz.
7. **Back-fill the paper's numeric tables/figures** from the verified local run.
8. **Final pass (later):** banner TODO items (figure numbering, bridge paragraphs, §7.2 renumber,
   M2↔M3 relabel, narrative re-org) once content and co-author input are settled.
