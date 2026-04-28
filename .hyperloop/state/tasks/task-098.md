---
id: task-098
title: Godot — private symbol interior indicators inside Container at near LOD
spec_ref: specs/core/visual-primitives.spec.md
status: not-started
phase: null
deps: [task-078, task-088, task-067]
round: 0
branch: null
pr: null
---

Implement interior rendering of private symbols within Container nodes: at near LOD,
display small label indicators for each private function/class inside the Container
volume, distinct from Port glyphs (task-088) which show only public interface points
on the membrane.

Covers `specs/core/visual-primitives.spec.md` — Requirement: Container Primitive,
Scenario: Module as container ("the 3 private functions are contained inside, visible
only at close zoom — AND the 5 public functions are represented as Ports on the
membrane"):

---

**Context:**

Task-088 renders public function symbols as Port glyphs on the Container's membrane,
and task-093 encodes the public/private ratio as membrane permeability. However, the
private symbols themselves have no visual representation. This task adds that missing
interior layer: at near LOD, the human can look INSIDE a Container and see what private
implementation details are present, without reading source code.

---

**Symbol selection** — for each module node that carries a `symbols` array (from
task-078 / task-075):

- **Render as interior indicators**: symbols where `visibility == "private"`.
- **Skip**: public symbols (they are rendered as Ports by task-088 and would be
  duplicated if also rendered as interior indicators).
- **Kinds included**: `"function"`, `"class"`, `"variable"`, `"constant"` — all private
  symbols regardless of kind.

If `symbols` is absent or empty, no interior indicators are created for that node.

---

**Interior indicator rendering** — after the Container volume mesh is created
(task-010 / task-093), for each module node with private symbols:

1. Compute a grid layout inside the Container:
   - Available interior volume: the Container's inner face area (excluding the
     membrane thickness; use `node_size * 0.8` as the usable interior side length).
   - Arrange private symbols in a grid: `cols = ceil(sqrt(N))` where N is the count
     of private symbols.
   - Grid cell size: `cell_size = (node_size * 0.8) / cols`.
   - Start from the top-left interior face and fill left-to-right, top-to-bottom.

2. For each private symbol, create a `Label3D` child of the node's root `Node3D`:
   - `text` = the symbol name (truncated to 16 characters with `…` suffix if longer).
   - `position`: computed from grid cell position, offset slightly into the interior
     (z-offset of `node_size * 0.1` so labels don't clip the front membrane face).
   - `font_size = 8` (smaller than Port labels, intentionally de-emphasised).
   - Colour varies by kind:
     - `"function"` → `Color(0.7, 0.7, 0.7, 0.8)` (grey)
     - `"class"` → `Color(0.6, 0.75, 0.9, 0.8)` (muted blue)
     - `"constant"` or `"variable"` → `Color(0.8, 0.7, 0.6, 0.8)` (muted amber)
   - `billboard = BaseMaterial3D.BILLBOARD_ENABLED` (always faces the camera)
   - `double_sided = true`

3. Add a small `BoxMesh` indicator glyph next to each label (5×5×5 units in
   godot-space) with matching colour to help the human spot the indicators when
   many are present:
   - Position: to the left of the label at `label_position + Vector3(-0.15, 0, 0)`.
   - `MeshInstance3D` with `StandardMaterial3D`, albedo = kind colour, no emission.

---

**LOD behaviour:**

- **Far tier**: all interior indicator Labels and meshes are hidden.
- **Medium tier**: all interior indicator Labels and meshes are hidden.
- **Near tier**: interior indicators fade in (`modulate.a` from 0 to target alpha,
  0.25 s Tween) as the human approaches the Container.

Integrate with the LOD system (task-067):
- Interior indicators start with `visible = false`.
- When the LOD system transitions a node to near tier, set interior indicators to
  `visible = true` and begin the fade-in Tween.
- When the LOD system transitions away from near tier, fade out (`modulate.a` to 0,
  0.25 s) then set `visible = false`.

This is the ONLY visual element that becomes visible exclusively at near tier —
reinforcing the spec's "visible only at close zoom" requirement.

---

**Maximum indicators** — if a module has more than 24 private symbols, display only
the first 24 (4×6 grid) and add a `"…+N more"` Label3D at the overflow position. More
than 24 private symbols indicates a module with very dense private implementation; the
grid cap prevents visual overload while still communicating the presence of private
complexity.

**Hover tooltip** — when the mouse hovers over an interior indicator label or mesh,
display a small HUD tooltip (CanvasLayer Label) showing:
```
(private) _validate_input
signature: (data: dict) -> bool
```
Reuse the hover tooltip mechanism from task-087/097. Show the full symbol name
(un-truncated), its kind, and its signature (from the `symbols` array entry).

---

**Interaction with Port rendering (task-088):**

Interior indicators are positioned INSIDE the container volume; Ports are positioned
ON the membrane (the outer surface). There is no spatial overlap. The z-offset of
interior indicators (`+0.1` interior) vs. Ports (flush with membrane, facing outward)
keeps them geometrically distinct.

At near LOD, both Port glyphs and interior indicators are visible simultaneously,
giving the human a complete picture: public interface points on the membrane, private
implementation details inside.

---

**Interaction with mode overlays:**

Interior indicator labels and glyphs occupy their own child nodes within the Container
`Node3D` hierarchy. Mode-specific fill colours (Conformance, Evaluation, Simulation)
are applied to the base Container mesh on surface slot 0 and do NOT affect Label3D or
the small indicator BoxMesh nodes. No interference.

**Mode compatibility** — interior indicators coexist with:
- Badge glyphs (task-087): top-right exterior.
- Beacon indicators (task-097): bottom-left exterior.
- Port glyphs (task-088): on the membrane surface.
- Rail glyphs (task-090): base centre.
- Purpose annotation labels (task-096): above the Container.
All occupy distinct spatial positions; no overlap.

**Fallback** — if a node carries no `symbols` field (absent or empty), or if all
symbols are public (no private symbols), no interior indicators are created. No crash.

**No schema or extractor changes** — the `symbols` array (with `visibility` field)
is defined in task-075 and populated by task-078. This task only reads and renders
the private subset at near LOD.

Use only GDScript and Godot 4.6 API. No external libraries.
