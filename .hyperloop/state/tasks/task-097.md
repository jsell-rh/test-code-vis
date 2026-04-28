---
id: task-097
title: Godot — beacon pattern indicator on Node (recognized pattern glyphs)
spec_ref: specs/core/visual-primitives.spec.md
status: not-started
phase: null
deps: [task-095, task-009, task-087]
round: 0
branch: null
pr: null
---

Implement beacon indicator rendering in the Godot application: read the `beacons` array
from each node in the scene graph JSON and render a small, visually distinct indicator
for each recognized pattern on the node — distinct from Badge glyphs (task-087), which
encode structural properties, not recognized design patterns.

Covers `specs/core/visual-primitives.spec.md` — Requirement: Purpose-Level Annotation,
Scenario: Beacon recognition ("given a function body that matches a well-known pattern
AND the LLM analyzes the function, THEN it MAY attach a beacon annotation naming the
recognized pattern AND the beacon is visible as a small indicator on the Node AND
beacons help the human form hypotheses about purpose without reading code"):

---

**Distinction from Badges:**

| Property          | Badge (task-087)                       | Beacon (this task)                      |
|-------------------|----------------------------------------|-----------------------------------------|
| Source            | Extractor (deterministic, AST-based)   | LLM (pattern recognition, open vocab)   |
| Vocabulary        | Closed, fixed (8 types)                | Open strings (any pattern name)         |
| Encodes           | Structural property (io, async, …)     | Design pattern (retry_loop, observer …) |
| Visual position   | Top-right of node, stacked along X     | Bottom-left of node, stacked along X    |
| Visual shape      | BoxMesh (coloured cube)                | DiamondMesh (rotated BoxMesh at 45°)    |
| Perceptual channel| Glyph/shape at top-right               | Glyph/shape at bottom-left              |

The distinct position (bottom-left vs. top-right) and shape (diamond vs. cube) ensure
badges and beacons occupy the same perceptual channel at different locations, preventing
visual conflict while keeping both readable.

---

**Loading** — extend the scene graph loader autoload (task-008) to read the `beacons`
array from each node entry (absent or empty → no beacons for that node). Store in a
`beacons: Dictionary` keyed by node id.

---

**Beacon rendering** — after the base node mesh is created (task-009), for each node
with at least one beacon:

1. For each beacon in the `beacons` array (in the order they appear in the JSON):
   a. Create a `MeshInstance3D` child of the node's root `Node3D`.
   b. Use a `BoxMesh` with `size = Vector3(0.15, 0.15, 0.15)` rotated 45° around
      the Z-axis (`rotation_degrees.z = 45`) to form a diamond silhouette.
   c. Apply a `StandardMaterial3D`:
      - `albedo_color = BEACON_COLOR` (see below)
      - `emission_enabled = true`
      - `emission = BEACON_COLOR`
      - `emission_energy = 0.5` (subtle glow, less intense than landmark glow)
   d. Position at the node's bottom-left corner:
      - `offset = Vector3(-(node_size * 0.5 + 0.10), -(node_size * 0.5 + 0.10), 0)`
      - Additional beacons stack along the X axis:
        `offset.x -= beacon_index * 0.22`
   e. `BEACON_COLOR = Color(0.3, 0.95, 0.75)` — a teal-green distinct from all
      badge colours (named constant).

2. Add a `Label3D` child above the diamond mesh:
   - `text` = the first 4 characters of `beacon.pattern` (e.g. `"retr"` for
     `"retry_loop"`, `"accm"` for `"accumulator"`) — abbreviated to keep it compact.
   - `font_size = 9`
   - `modulate = Color(0.9, 1.0, 0.9, 0.9)` (light green-white)
   - `billboard = BaseMaterial3D.BILLBOARD_ENABLED`

---

**Hover tooltip** — when the mouse hovers over a beacon diamond mesh, display a small
HUD label (CanvasLayer `Label`) with the full pattern name and description from the
beacon object:

```
Pattern: retry_loop
"Retries the token validation call up to 3 times with exponential backoff on
transient failures."
```

Reuse the hover tooltip mechanism established by task-087. If task-087 created a shared
`TooltipManager` or similar, use it; otherwise implement using the same technique:
connect `mouse_entered` and `mouse_exited` signals on the `Area3D` around the beacon
mesh to a CanvasLayer Label.

---

**LOD behaviour** — beacons follow the same LOD visibility rules as their parent node
(inherited from task-087's badge LOD pattern):

- **Far tier**: beacon meshes hidden, label hidden.
- **Medium tier**: beacon meshes visible, label hidden.
- **Near tier**: beacon meshes visible with label.

When the parent node is hidden by the LOD system, hide all beacon children simultaneously
(copy the parent node's `visible` state and `modulate.a` Tween to the beacon child nodes).

---

**Maximum beacons** — if a node has more than 5 beacons, display only the first 5 and
add a condensed `"…+N"` Label3D at position 6 to indicate overflow. Five diamond glyphs
fit comfortably within a standard module node's bounding box.

**Mode compatibility** — beacon diamond meshes occupy the bottom-left glyph position,
which is distinct from badge cubes (top-right), Port cylinders (membrane surface),
rail glyphs (base centre, task-090), and border shells (task-051/073). No interference.

**Fallback** — if a node carries no `beacons` field (absent or empty), no beacon
geometry is created. No crash.

**No schema or extractor changes** — all required fields are defined in task-095 and
populated by a future LLM annotation agent. This task only reads and renders them.

Use only GDScript and Godot 4.6 API. No external libraries.
