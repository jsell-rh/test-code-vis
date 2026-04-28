---
id: task-090
title: Godot — Power Rail notation (suppress ubiquitous edges, show rail indicator)
spec_ref: specs/core/visual-primitives.spec.md
status: not-started
phase: null
deps: [task-083, task-013, task-067]
round: 0
branch: null
pr: null
---

Implement Power Rail notation in the Godot application: suppress edges flagged as
`ubiquitous: true` by default, add a small rail-glyph indicator to each node that
has ubiquitous dependencies, and allow the human to toggle ubiquitous edges on and
off with an animated transition.

Covers `specs/core/visual-primitives.spec.md` — Requirement: Power Rail Notation
("A visual acknowledgment that a ubiquitous dependency exists without drawing its
edges. Each Node that imports it has a small, consistent indicator (e.g. a tiny
rail glyph at its base)"):

**Loading** — extend the scene graph loader autoload (task-008):
1. Read the `ubiquitous` field on each edge entry (absent/false → not ubiquitous).
2. Build two edge sets: `normal_edges` and `ubiquitous_edges`.
3. Read `metadata.ubiquitous_deps` (list of ubiquitous target node ids) if present.

**Default state — ubiquitous edges suppressed:**
1. On initial scene load, ubiquitous edge lines (from task-013) are NOT created or
   are created with `visible = false`.
2. For each module node that has at least one outgoing `ubiquitous: true` edge:
   - Create a small **rail glyph**: a `MeshInstance3D` with a `CylinderMesh`
     (height 0.06, radius 0.06) positioned at the node's base (bottom face of the
     container volume, centred).
   - Apply `StandardMaterial3D` with `albedo_color = Color(0.9, 0.75, 0.3)` (amber),
     `emission_enabled = true`, `emission_energy = 0.4`.
   - Add a `Label3D` below the glyph showing `"⚡"` (or the text `"~"` if the emoji
     is unavailable).
3. At most 7 distinct rail glyphs per node (one per ubiquitous dependency target).
   If a node imports more than 7 ubiquitous targets, collapse them into one glyph
   labelled `"⚡×N"`.

**Rail glyph LOD** — rail glyphs follow the same LOD rules as their parent node
(task-067): hidden when the node is hidden, visible when the node is visible.

**Toggle — show ubiquitous edges:**
- Press `U` to toggle ubiquitous edge visibility.
- **Show state**: fade ubiquitous edge lines in (`modulate.a` from 0 to 1, duration
  0.3 s) using `Tween`. Ubiquitous edge lines are rendered with a dashed or dotted
  line style (if the edge renderer supports it; otherwise a muted colour:
  `Color(0.5, 0.4, 0.2, 0.6)`). Rail glyphs remain visible (they acknowledge the
  dependency regardless of whether edges are drawn).
- **Hide state**: fade ubiquitous edge lines out (`modulate.a` from 1 to 0, duration
  0.3 s). After the tween completes, set `visible = false`.
- The toggle is reversible; the HUD shows `"[U] Power rails: ON"` or `"[U] Power
  rails: OFF"` in the corner.

**Multiple power rails** — the `metadata.ubiquitous_deps` list drives which target
nodes get a power rail indicator. The glyph on the SOURCE node indicates "this node
has ubiquitous outgoing deps". The TARGET node itself (e.g. `shared_kernel.logging`)
is NOT rendered in the default structural view unless it appears as a source of other
edges; its absence is expected.

**Mode compatibility** — power rail glyphs occupy the base of the node and do NOT
interfere with top-right badge glyphs (task-087), membrane Ports (task-088), or
any mode-specific fill colour on the node mesh.

**Fallback** — if no edges in the scene graph carry `ubiquitous: true` (extractor
ran without `--ubiquitous`), no rail glyphs are shown and the `U` toggle is a no-op.
No crash.

Use only GDScript and Godot 4.6 API. No external libraries.
