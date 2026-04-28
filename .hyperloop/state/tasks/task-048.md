---
id: task-048
title: Godot — Simulation: cascade depth per-hop gradient
spec_ref: specs/core/understanding-modes.spec.md
status: not-started
phase: null
deps: [task-032, task-035, task-047]
round: 0
branch: null
pr: null
---

Extend the failure-injection cascade visualisation to encode each hop distance from the
failure origin as a visually distinct shade, so the human can distinguish first-order,
second-order, third-order (and beyond) dependents at a glance — not just "direct" vs.
"everything else."

Covers `specs/core/understanding-modes.spec.md` — Requirement: Cascade Depth, Scenario:
Visualizing blast radius by depth ("first-order dependents (direct consumers) are visually
distinct from second-order, third-order, etc. AND depth is encoded as a gradient"):

**Current behaviour (task-032 / task-035):** the cascade walk classifies nodes into two
buckets — distance 1 (AFFECTED, amber) and distance 2+ (DOWNSTREAM, lighter warning). All
nodes beyond distance 1 receive the same visual treatment regardless of how many hops away
they are.

**New behaviour — per-hop depth gradient:**

- Perform BFS from the failed node as before (using the spec-filtered edge list from
  task-047), tracking the exact hop distance for every reached node.
- Compute `max_depth`: the greatest hop distance of any reached node.
- For each reached node at distance `d`, compute a normalised depth ratio:
  `ratio = d / max_depth` (float in [0.0, 1.0]; if only one depth level is reached,
  `ratio = 1.0` for all nodes at distance 1).
- Apply a colour interpolation along a cascade gradient:
  - Distance 1 (ratio ≈ 0): bright, fully saturated warning colour (e.g. `Color(1, 0.3, 0)` —
    deep orange-red).
  - Max depth (ratio = 1): pale, low-saturation warning tint (e.g. `Color(1, 0.85, 0.7)` —
    near-white peach).
  - Intermediate distances: linearly interpolated between the two colours using
    `Color.lerp(near_color, far_color, ratio)`.
- Replace the two-level AFFECTED / DOWNSTREAM label system from task-032 with a single
  floating `Label3D` above each reached node showing `"⚠ depth N"` where N is the integer
  hop distance. The failed node itself shows `"✕ FAILED"` as before.
- The gradient and depth labels must be cleared by the same Reset / Escape logic that
  task-032 uses to clean up failure markers.
- Backward compatibility: when no nodes are reached (the failed node is a leaf with no
  dependents), no gradient is applied and the only label is `"✕ FAILED"` on the failed node.
- Spec node filtering from task-047 is enforced: `spec_item` nodes and `spec_to_code` edges
  are excluded from the BFS traversal before the depth gradient computation begins.
- Multi-failure: when the human selects additional nodes to fail (task-032's multi-failure
  feature), compute per-hop depth from each failed node independently; for nodes reachable
  from multiple failed origins, use the minimum (closest) depth to determine their gradient
  shade.

- Use only GDScript and Godot 4.6 API. No external libraries.
