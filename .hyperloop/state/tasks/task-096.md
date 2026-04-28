---
id: task-096
title: Godot — purpose annotation and invariant labels on Container nodes
spec_ref: specs/core/visual-primitives.spec.md
status: not-started
phase: null
deps: [task-095, task-010, task-067]
round: 0
branch: null
pr: null
---

Implement purpose annotation and invariant label rendering in the Godot application:
read `purpose_annotation` and `invariants` from the scene graph JSON, and display
them as `Label3D` elements anchored above Container (module and bounded_context) nodes,
visible at medium and near LOD tiers.

Covers `specs/core/visual-primitives.spec.md` — Requirement: Purpose-Level Annotation,
Scenarios: LLM-generated purpose annotation ("attached to the cluster's Container level
AND it is distinct from the module names, which describe mechanism, not purpose") and
Invariant annotation ("attached to the Aggregate or Container that the validations
protect"):

---

**Loading** — extend the scene graph loader autoload (task-008) to read two new optional
fields from each node entry:

1. `purpose_annotation` (string | null | absent) — a sentence describing what the node
   is FOR.
2. `invariants` (array | absent) — each entry has `rule` (string) and `enforced_by`
   (array of node id strings).

Store them in two Dictionaries keyed by node id:
- `purpose_annotations: Dictionary` → `{ node_id: String }`
- `invariants: Dictionary` → `{ node_id: Array[Dictionary] }`

Absent or null values are not stored (Dictionary miss = no annotation for that node).

---

**Purpose annotation label** — after the Container volume mesh is created (task-010),
for each node with a non-null, non-absent `purpose_annotation`:

1. Create a `Label3D` child of the node's root `Node3D`.
2. Set `text` to the `purpose_annotation` string.
3. Position it **above** the node mesh:
   - `position = Vector3(0, node_height * 0.5 + ANNOTATION_OFFSET, 0)` where
     `ANNOTATION_OFFSET = 0.6` (named constant).
   - The label floats above the mesh so it does not overlap the node volume.
4. Visual style:
   - `font_size = 14`
   - `modulate = Color(0.95, 0.95, 0.7, 0.9)` (warm off-white, slightly translucent)
   - `outline_size = 4` (so it remains readable against any background)
   - `billboard = BaseMaterial3D.BILLBOARD_ENABLED` (always faces the camera)
   - `double_sided = true`
5. Prefix the text with a `◈ ` glyph (or `[P] ` if the glyph is unavailable) so the
   human can distinguish purpose labels from node name labels at a glance.

---

**Invariant labels** — for each node with one or more invariants, render each rule
as a subordinate `Label3D` below the purpose annotation (or directly above the node
if no purpose annotation is present):

1. Stack invariant labels vertically below the purpose annotation label with
   `INVARIANT_SPACING = 0.35` units between them (named constant).
2. Visual style (distinct from purpose annotation):
   - `font_size = 11` (smaller)
   - `modulate = Color(0.8, 0.9, 1.0, 0.85)` (cool blue-white, slightly dimmer)
   - `billboard = BaseMaterial3D.BILLBOARD_ENABLED`
   - Prefix each invariant text with `⚖ ` (or `[I] ` fallback).
3. If a node has more than 3 invariants, display the first 2 and append a condensed
   `"… +N more invariants"` label to avoid visual overflow.

---

**LOD behaviour:**

- **Far tier** (task-067 far threshold): purpose annotation and invariant labels
  are hidden (`visible = false`). Container nodes at far distance show only their
  volume mesh and landmark treatment (task-086).
- **Medium tier**: purpose annotation label is visible. Invariant labels are hidden
  (they add detail appropriate only when closer).
- **Near tier**: both purpose annotation and invariant labels are visible.

Implement by connecting to the LOD visibility system:
- When the LOD system hides a node's mesh (`modulate.a` tweens toward 0 or
  `visible = false`), simultaneously hide the annotation Label3D(s) for that node.
- When the LOD system brings a node to medium visibility, fade in the purpose
  annotation label (`modulate.a` from 0 to `0.9`, 0.3 s Tween).
- When the LOD system brings a node to near visibility, fade in the invariant
  labels (`modulate.a` from 0 to `0.85`, 0.3 s Tween).

---

**Fallback** — if a node carries no `purpose_annotation` and no `invariants`, no
Label3D is created for that node. The scene remains unchanged from task-010's output.
No crash if the fields are absent from the JSON.

**Mode compatibility** — purpose annotation and invariant labels occupy the glyph/text
channel (Label3D) and do NOT interfere with fill colour (mode-specific materials on
slot 0), badge glyphs (task-087), or Port glyphs (task-088). All can coexist.

**No schema or extractor changes** — all required fields are defined in task-095 and
populated by a future annotation agent. This task only reads and renders them.

Use only GDScript and Godot 4.6 API. No external libraries.
