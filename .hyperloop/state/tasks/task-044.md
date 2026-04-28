---
id: task-044
title: Godot — Evaluation Mode: HIGH COUPLING edge annotation
spec_ref: specs/core/understanding-modes.spec.md
status: not-started
phase: null
deps: [task-031]
round: 0
branch: null
pr: null
---

Extend Evaluation Mode (task-031) to annotate statistically high-coupling node pairs
with a visible "HIGH COUPLING" label, giving the human an explicit threshold signal so
they can assess whether the coupling between two services is problematic — not just
perceive its relative intensity.

Covers `specs/core/understanding-modes.spec.md` — Requirement: Evaluation Mode,
Scenario: Detecting tight coupling ("AND the human can assess whether the coupling is
problematic"):

Task-031 recolours and thickens edges proportionally to the pairwise edge count, which
makes coupling *apparent*. However, the human has no reference point to judge whether a
thick red line represents *problematic* coupling or merely the busiest edge in a
generally low-coupling graph. This task adds an explicit threshold annotation.

**Threshold computation** — after task-031 has computed pairwise edge counts for all
node pairs, derive a coupling severity threshold as follows:

- Collect the pairwise edge counts for every unique (source, target) pair, counting
  multi-edges (i.e. count of edges between that pair, not just edge existence).
- Compute the 75th percentile of those counts across the whole graph. Any pair whose
  count strictly exceeds this percentile AND has at least 2 edges is classified as
  "high coupling."
- If fewer than four distinct pairs exist (degenerate graph), set the threshold to 2
  edges and apply the same rule.

**Annotation** — for every edge that belongs to a high-coupling pair, add a floating
`Label3D` anchored to the midpoint of that edge's rendered line (use the average of
the source and target node world positions, offset slightly on the Y axis so the label
does not overlap the line itself). The label text is `"HIGH COUPLING"`. Use the same
font size and visual style as the `"CRITICAL"` label added by task-031.

- If multiple edges exist between the same pair of nodes (parallel edges), place a
  single label at the midpoint — do not add one label per parallel edge.
- The label colour must be distinct from the `"CRITICAL"` node label: use a saturated
  orange-red (to echo the edge's own colour) rather than the pure red used for CRITICAL
  nodes.

**Cleanup** — remove all HIGH COUPLING `Label3D` nodes when Evaluation Mode is toggled
off, using the same cleanup logic task-031 uses for CRITICAL labels. If ModeController
(task-038) switches away from Evaluation Mode, cleanup must fire via the `mode_changed`
signal handler.

**HUD legend update** — add a line to the Evaluation Mode HUD legend introduced by
task-031:
  `● HIGH COUPLING   edges in the top 25% of pairwise connection count`
Position this line below the existing node-centrality legend entries.

- The threshold computation MUST be performed at mode-toggle time from already-loaded
  edge data; no re-parsing or file I/O after initial scene load.
- Use only GDScript and Godot 4.6 API. No external libraries.
