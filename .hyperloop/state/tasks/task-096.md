---
id: task-096
title: Godot — Purpose-Level Annotation rendering (purpose, beacon, invariant)
spec_ref: specs/core/visual-primitives.spec.md
status: not-started
phase: null
deps: [task-009, task-095, task-067]
round: 0
branch: null
pr: null
---

Read purpose-level annotation fields from scene graph nodes and render them as floating
labels and glyph indicators: purpose text at the Container level, beacon glyphs docked
to nodes, and invariant text below nodes — each using a distinct perceptual channel
that does not conflict with other primitives.

Covers `specs/core/visual-primitives.spec.md` — Requirement: Purpose-Level Annotation,
Scenarios: LLM-generated purpose annotation ("attached at the cluster's Container level
and distinct from the module names"), Beacon recognition ("a beacon annotation naming
the recognised pattern, visible as a small indicator on the Node"), Invariant annotation
("attached to the Aggregate or Container that the validations protect"):

**Loading** — extend the scene graph loader autoload (task-008) to read `purpose`,
`beacon`, and `invariant` from each node entry (absent → no annotation for that field
on that node; no error).

---

**Purpose annotation rendering:**

1. For each node with a non-empty `purpose` field: add a `Label3D` as a child of the
   node's root `Node3D`, positioned above the node name label:
   - Y-offset from node top: `node_size * 0.5 + 0.55` (above the name label, which
     sits at `node_size * 0.5 + 0.25` from task-009).
   - Text: `purpose` value. Enable `autowrap_mode = TextServer.AUTOWRAP_WORD_SMART`,
     `width = 4.0` (world units).
   - Font size: 10.
   - Colour: `Color(0.75, 0.95, 0.80)` (soft green-white — semantic/intent colour).
   - `billboard = BaseMaterial3D.BILLBOARD_ENABLED` so it faces the camera.

2. **LOD visibility** — purpose labels are hidden at far LOD (camera farther than
   `FAR_THRESHOLD` from the node's parent context) and visible at medium and near.
   Connect to task-067's LOD distance computation: add purpose `Label3D` nodes to the
   same `medium_near_elements` group that task-067 manages, OR check distance in
   `_process()` if task-067 uses a list-based approach. Duration for fade: 0.25 s
   via `Tween` on `modulate.a`.

---

**Beacon glyph rendering:**

1. For each node with a `beacon` field: add a `MeshInstance3D` child with a
   `SphereMesh` (`radius = 0.09`) to the node's `Node3D`.
   - Position: top-LEFT corner of the node mesh:
     `Vector3(-(node_size * 0.5 + 0.14), node_size * 0.5 + 0.14, 0)`
     (distinct from badge position at top-right, task-087).
   - Apply `StandardMaterial3D` with the beacon's assigned colour (see below).
   - `emission_enabled = true`, `emission_energy = 0.3` (subtle glow to draw the eye).

2. Beacon colour and 2-char label:

   | Beacon value  | Colour                          | Abbr |
   |---------------|---------------------------------|------|
   | `retry_loop`  | `Color(1.0, 0.55, 0.15)`        | `Rl` |
   | `accumulator` | `Color(0.35, 0.80, 1.00)`       | `Ac` |
   | `observer`    | `Color(0.90, 0.35, 0.90)`       | `Ob` |
   | `pipeline`    | `Color(0.40, 1.00, 0.45)`       | `Pi` |
   | `facade`      | `Color(0.95, 0.95, 0.30)`       | `Fa` |
   | `singleton`   | `Color(0.65, 0.65, 0.65)`       | `Si` |

3. Add a `Label3D` child of the sphere with the 2-char abbreviation:
   - Font size: 9. Colour: white.
   - Visible at near and medium LOD; hidden at far LOD (suppress `visible` in `_process()`
     when LOD tier is far, same as badge label logic in task-087).

4. **Hover tooltip** — when the mouse hovers over the beacon sphere, display a HUD
   label (CanvasLayer `Label`) with the full beacon name, e.g. "retry_loop — contains
   a retry-on-failure mechanism". Use the same tooltip mechanism as task-087 badge
   hover; implement from scratch if it does not yet exist.

---

**Invariant annotation rendering:**

1. For each node with a non-empty `invariant` field: add a `Label3D` below the node:
   - Y-offset from node bottom: `-(node_size * 0.5 + 0.30)`.
   - Text: `"⟡ " + invariant` (diamond marker). If the Unicode diamond is unavailable
     in the project font, use `"[I] " + invariant`.
   - Font size: 9 (subordinate to purpose label).
   - Colour: `Color(1.0, 0.88, 0.55)` (warm amber — business rule colour).
   - `billboard = BaseMaterial3D.BILLBOARD_ENABLED`.

2. **LOD visibility** — invariant labels are visible ONLY at near LOD tier (camera
   within `NEAR_THRESHOLD` of the specific node). Hidden at medium and far. Use the
   same `modulate.a` tween approach as purpose labels (0.25 s).

3. **Conformance Mode integration** — when Conformance Mode is active (task-030), nodes
   with both an `invariant` field AND a `spec_to_code` edge incoming to them have their
   invariant `Label3D` given a slightly brighter modulate (`Color(1.1, 1.1, 1.1)`). This
   signals that the invariant corresponds to a spec checkpoint. Implementation: in the
   Conformance Mode script, after rendering spec_to_code lines (task-030), iterate nodes
   that are `spec_to_code` targets and brighten their invariant label if present. No
   mode logic changes; this is a cosmetic pass only.

---

**Fallback** — if all three annotation fields are absent on a node, no annotation nodes
are created (no empty labels, no empty spheres). Scene graphs produced by the extractor
pipeline have no annotation fields by default; the Godot application renders without
annotations in that case.

**Channel summary** (non-interference):
- Purpose label: above-node Y position + green-white colour.
- Beacon glyph: top-left corner + sphere shape (distinct from badge box at top-right,
  task-087, and rail glyph at base, task-090).
- Invariant label: below-node Y position + amber colour.
- None of these use the fill colour, edge, or tint channels.

Use only GDScript and Godot 4.6 API. No external libraries.
