---
id: task-105
title: Godot — Evaluation Mode: community drift annotation on module nodes
spec_ref: specs/core/visual-primitives.spec.md
status: not-started
phase: null
deps: [task-031, task-046, task-074, task-082]
round: 0
branch: null
pr: null
---

Extend Evaluation Mode to visually annotate module nodes that carry
`significance.community_drift == true`, surfacing the architectural smell of
modules whose code structure (as detected by community analysis) does not align
with their declared package boundary.

Covers `specs/core/visual-primitives.spec.md` — Requirement: Structural Significance
Extraction, Scenario: Community detection ("modules whose detected community differs
from their declared package are flagged as `community_drift`") and the Evaluation
Mode principle that architectural quality issues are visible independent of the spec:

---

**Trigger** — this annotation is applied when Evaluation Mode is active (same
activation lifecycle as the HIGH COUPLING annotation in task-044 and CRITICAL
annotation in task-045). Connect to `ModeController.mode_changed` (task-050);
activate when `"evaluation"` is in the `active_modes` array.

---

**Annotation rendering** — after existing Evaluation Mode annotations (task-044,
task-045) are applied, iterate all loaded nodes:

1. Skip `spec_item` nodes (same filter as task-046 — only structural code nodes
   are considered for architectural quality metrics).
2. For each `module` node where `significance` is present AND
   `significance["community_drift"] == true`:

   **Floating label**:
   - Create a `Label3D` above the node mesh (higher than the CRITICAL label if
     both apply; stack above):
     - `text`: `"⇌ COMMUNITY DRIFT"`
     - `font_size`: 11
     - `modulate`: `Color(0.85, 0.55, 1.0, 1.0)` — violet, distinct from the
       orange HIGH COUPLING label and red CRITICAL label.
     - `billboard`: `BaseMaterial3D.BILLBOARD_ENABLED`
     - Position: `node_position + Vector3(0, node_size * 1.25, 0)` (shift upward
       further if CRITICAL label is also present: `node_size * 1.6`).
   - Name the node `"DriftLabel"` so it can be found and removed on deactivation.

   **Subtle mesh tint**:
   - Apply a faint violet emissive tint to the node's material (second surface slot,
     same pattern as task-051's border ring — do NOT overwrite the base material):
     `emission_enabled = true`, `emission = Color(0.6, 0.2, 0.9)`,
     `emission_energy = 0.15` (intentionally dim; the label is the primary signal).
   - This tint must compose with Conformance mode fill and Simulation cascade fill
     without overwriting them (use a surface material override, not slot 0).

---

**Deactivation** — when `"evaluation"` leaves `active_modes`:

1. Free all `DriftLabel` Label3D nodes (find by name or maintain a list).
2. Remove the emissive override from affected nodes' materials.
3. Removal is done by the existing `begin_fade_out` mechanism from task-053:
   the DriftLabel fades out with `modulate.a` tween before being freed.

---

**Multi-mode interaction**:

- **Conformance + Evaluation** (task-051): the Conformance fill colour is the
  primary fill; Evaluation uses border ring. The violet emissive tint is additive
  on top of the border ring. Both the DriftLabel and the Conformance fill are
  simultaneously visible — no conflict.
- **Evaluation + Simulation** (task-052): Simulation owns fill colour; Evaluation
  uses border ring. The DriftLabel floats above both. The violet emissive tint
  composites additively on the cascade fill. Visual noise risk: the emissive tint
  is deliberately low (`emission_energy = 0.15`) so it does not mask the cascade
  gradient colours.
- **All three modes**: DriftLabel is visible; emissive tint applies. The annotation
  does not break the C+E+S channel allocation defined in task-073.

---

**Graceful absence** — if no nodes carry `significance.community_drift == true`
(extractor ran with `--no-significance` or community analysis found no drift), no
DriftLabels are created and Evaluation Mode behaves identically to its pre-task-105
state. No crash.

**LOD compatibility** — DriftLabel follows the same LOD visibility as its parent
node: hidden when the module node is hidden (LOD far tier), visible when the module
is visible (LOD medium/near tier). Hook into the same visibility state as the
CRITICAL label (task-045).

**No schema or extractor changes.** Godot-only task.

Use only GDScript and Godot 4.6 API. No external libraries.
