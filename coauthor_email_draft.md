# Draft email to co-author

**Subject:** Reviewer feedback on "Here's the Kicker" — plan + two things I want your input on

Hi Michael,

We got the review back on the field goal / IPW paper. Overall it's positive — the reviewer calls it
"a nice paper," thinks the fixes are doable, and recommends moving toward the reproducible stage once
we agree to the changes. I've worked through all of the comments and drafted a full response plan
(edits located to specific sections/notebooks). Most of it is straightforward, and a few of the
reviewer's concerns actually come down to the paper not describing our method clearly enough rather
than the method being wrong. Quick summary below, then two things I'd like your take on.

**What I'm planning to do (no disagreement expected):**

- **Reframe explicitly as non-causal.** Add estimand-precise language and a short contrast of what a
  fully causal treatment would require (a defined counterfactual, overlap, no unmeasured confounding
  of the attempt decision, SUTVA) and why we're doing selection-reweighting instead.
- **Explain the propensity model / leverage better.** The reviewer suggested using win probability or
  expected points. We already do, by proxy — `leverage_z` is our standardized post-kick WP-gap
  estimate. I'll make that explicit and explain why we built a bespoke version for the kick decision.
- **Season in the propensity model.** The reviewer's right that coaching behavior drifts over time. I'll
  add a within-window season trend to the propensity features and, more importantly, report the
  selection-bias result split pre-/post-2020 to show whether the answer changes by era.
- **Humidity** added to the outcome model (the data's already parsed, just wasn't in the formula).
- **Weather non-linearity.** I'm going to spline wind/temp/humidity as main effects and drop the
  wind×distance interaction — simpler and cleaner than adding interactions everywhere. I'll also add a
  raw make-rate-vs-weather plot so the relationship is shown.
- **Log-loss** added to the results tables (already computed, just not displayed), plus a redesigned
  calibration plot and a multi-metric comparison chart — the current calibration figures are hard to
  read.
- **Housekeeping** the reviewer flagged: unnumbered figures, missing section text, a section-numbering
  gap, and tightening the weight-normalization description. Holding these for a final formatting pass.

**Two things I want your input on:**

1. **Renumbering the models (M2 ↔ M3).** Right now M2 = IPW and M3 = the augmentation/pseudo-label
   model. The reviewer's comments made me think the narrative would read better if we present them in
   the order we actually developed them: M1 baseline → then our rougher first idea (augmentation, as
   M2) → then the refined approach we settled on (IPW, as M3). It also reinforces the "exploratory"
   framing for the augmentation model, which is what we want. The downside is it's a mechanical rename
   across all the notebooks and the paper. Do you think the clearer narrative is worth the churn, or
   should we leave the labels as they are?

2. **How we handle the non-attempt pseudo-labels.** The reviewer pushed on two things here, and I
   think one is a real question and the other is just us being unclear:
   - **PATs (I think this is a wording problem on our end, want to confirm you agree).** The reviewer
     read our text as treating PATs as guaranteed successes. But in the code we actually include PATs
     with their **real observed make/miss outcomes**, just down-weighted (`aug_weight = 0.10`). So the
     objection ("PAT success rate is .9x, not 1") doesn't apply — I just need to fix the sentence in
     §4.1 that mis-describes it. Can you sanity-check that framing?
   - **Non-attempts (the real question).** We do label filtered 4th-down non-attempts as misses
     (`kick_made = 0`) beyond 33 yards with propensity ≥ 0.25. The reviewer's point is that some of
     those had a real make probability of, say, 0.3 rather than 0, so calling them hard misses is
     unfair. My view: the GLMM needs a binary response, we dampen the influence with the low augment
     weight, M3 is explicitly exploratory, and my exhaustive weighting search never beat M1 anyway —
     so I'd defend the current approach in writing and note the induced bias. The alternative would be
     soft/fractional labels (use an expected make probability as the response instead of 0/1). I lean
     toward keeping it simple and defending it, but I wanted your read before I commit — do you think
     the soft-label version is worth a quick experiment, or is defending the binary version fine?

I'll hold on the model renaming and the non-attempt approach until I hear from you; everything else I
can start on now. Full located plan is in the repo (`Review_Response_Plan.md`) if you want the details.

Thanks,
Elliott
