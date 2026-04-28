---
id: task-069
title: Godot — cluster suggestion visualisation (tint + human-initiated collapse)
spec_ref: specs/visualization/spatial-structure.spec.md
status: not-started
phase: null
deps: [task-061, task-066, task-068, task-008]
round: 0
branch: null
pr: null
---

Load pre-computed cluster suggestions from the scene graph JSON, surface them with a
subtle per-cluster tint, and allow the human to accept a suggestion via keyboard
shortcut — never auto-collapsing.

Covers `specs/visualization/spatial-structure.spec.md` — Requirement: Cluster
Collapsing, Scenario: Pre-computed cluster suggestions:

**Loader extension** — extend the scene graph loader autoload (task-008) to also parse
the top-level `clusters` array and store it in a `clusters` property (list of cluster
dicts) alongside `nodes` and `edges`.

**Suggestion visualisation** — after initial node rendering (task-009), for each
cluster entry in the loaded clusters array:
1. Assign a per-cluster hue from a small fixed palette (e.g. soft blue, soft orange,
   soft green, soft purple), round-robin within a bounded context.
2. Apply a subtle albedo tint (≈20–30% saturation) to all member module
   `MeshInstance3D` nodes using a per-cluster material override.  The tint must
   compose with Evaluation and Conformance mode colouring (use additive blend or a
   secondary material slot rather than overwriting the base material).
3. Do NOT auto-collapse.  The tint is informational only.

**Human-initiated collapse** — while hovering over a tinted node:
- Pressing `F` (or right-click → "Collapse cluster") calls
  `ClusterManager.collapse_cluster(cluster_id)` (task-068) for that node's cluster.
- If the hovered node belongs to no cluster, the action is a no-op.
- After collapse, the tint is applied to the supernode mesh so it remains identifiable.

**HUD hint** — when ≥ 1 cluster suggestion exists in the loaded scene, display a small
one-line hint: `"[F] Collapse suggested cluster"`.  The hint disappears once all
suggestions are collapsed.

**Ignore path** — if the human never presses F, suggestions persist as tints indefinitely
with no other effect.  There is no "dismiss" action.

Use only GDScript and Godot 4.6 API.  No external libraries.
