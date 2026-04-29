---
id: task-118
title: Godot — Conformance Mode invariant annotation checkpoint styling
spec_ref: specs/core/visual-primitives.spec.md
status: not-started
phase: null
deps: [task-096, task-030]
round: 0
branch: null
pr: null
---

In Conformance Mode, invariant annotations on Container nodes must be visually
distinguished as spec-vs-implementation checkpoints — not merely readable labels,
but explicit signals to the human that these invariants must be verified against
the realized system.

Covers `specs/core/visual-primitives.spec.md` — Requirement: Purpose-Level
Annotation, Scenario: Invariant annotation ("the invariant is surfaced in
conformance mode as a spec-vs-implementation checkpoint"):

---

**Baseline** — task-096 renders invariant labels as `Label3D` children on Container
nodes at medium and near LOD tiers (cool blue-white, `⚖ ` prefix). At rest (no mode
or non-Conformance mode active) that rendering is unchanged.

---

**Conformance Mode active — connect to ModeController (task-050) signal.**

When `ModeController` emits `mode_changed` and the new active set includes
Conformance Mode:

1. **Checkpoint indicator ring** — for each Container node that has one or more
   invariant `Label3D` children (identifiable by their `"Invariant_"` node name
   prefix or by querying the `invariants` dictionary from task-096's loader):

   - Create a thin `TorusMesh` ring around the Container mesh at its equator:
     - `inner_radius = container_half_size * 1.05` (just outside the Container
       volume, so it does not clip the mesh)
     - `outer_radius = inner_radius + 0.07`
     - `rings = 12`, `ring_segments = 8` (low-poly; this is a small decorative
       element)
   - Material: `StandardMaterial3D`, `albedo_color = Color(0.3, 0.7, 1.0, 0.0)`
     initially (transparent). Fade the alpha to `0.85` over `0.25 s` via
     `create_tween()` when Conformance Mode activates. Never snap.
   - Name the node `"InvariantCheckpointRing"` for identification on deactivation.

2. **Invariant label emphasis** — for each existing invariant `Label3D` child on
   the Container (created by task-096):

   - Tween `modulate` from `Color(0.8, 0.9, 1.0, 0.85)` (task-096 default) to
     `Color(0.5, 0.85, 1.0, 1.0)` (brighter cyan, fully opaque) over `0.25 s`.
   - Prepend `"[CHK] "` to each label's `text` (or replace the `⚖ ` prefix with
     `⚖ [CHK] `) to signal checkpoint status. This is a text swap, not a visual
     animation — do it instantly when the mode activates.

3. **LOD gate** — the checkpoint ring follows the same LOD rule as the Container
   volume (task-067): hidden at far tier, visible at medium and near. Do not show
   the ring when the Container volume itself is hidden. Implement by setting
   `visible = false` on the ring when the LOD system hides the Container, and
   restoring it when the Container becomes visible.

4. **Stagger** — if many Container nodes have invariants, stagger the ring fade-in
   by `0.03 s × index` (where index is the Container's position in the loaded node
   list) so they do not all pop in simultaneously. Cap total stagger at `0.4 s`.

---

**Conformance Mode deactivating** — when Conformance Mode leaves the active set:

1. Tween each `InvariantCheckpointRing` alpha from its current value to `0.0`
   over `0.20 s`.
2. On tween completion: free the ring node from the scene tree.
3. Restore each invariant `Label3D` modulate to `Color(0.8, 0.9, 1.0, 0.85)` and
   restore the original `⚖ ` prefix (remove `[CHK]` prefix) over `0.20 s`.

No partial state should remain after deactivation.

---

**Mode compatibility:**

- Evaluation Mode: checkpoint rings occupy a distinct spatial layer (torus around
  the Container exterior) and do not conflict with Evaluation Mode's coupling
  annotations or CRITICAL labels (which are `Label3D` nodes above the Container,
  not rings around it). Both can coexist.
- Simulation Mode: cascade depth fills (task-048) and SPOF Landmark treatment
  (task-117) are on different nodes and channels. The checkpoint rings are on
  Container nodes; cascade/SPOF effects target module and Landmark nodes. No
  channel conflict.
- Multi-mode transitions (task-053): the checkpoint ring uses the same
  `create_tween()` pattern. If Conformance Mode fades in while another mode is
  already active, the ring fades in alongside the other mode's encodings without
  interference.

---

**No schema or extractor changes.** Godot-only task. The invariant data is loaded
from fields defined in task-095 and rendered by task-096; this task only adds
Conformance Mode-specific visual treatment.

Use only GDScript and Godot 4.6 API. No external libraries.
