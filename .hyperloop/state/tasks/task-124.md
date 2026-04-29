---
id: task-124
title: Godot — TintController: ownership tint dimension
spec_ref: specs/core/visual-primitives.spec.md
status: not-started
phase: null
deps: [task-089, task-122, task-123]
round: 0
branch: null
pr: null
---

Extend TintController (task-089) with an "owner" dimension that tints Container
nodes by team ownership, enabling the human to ask "what does team X own?" and
see the answer as a categorical colour overlay on the structural geography.

Covers `specs/core/visual-primitives.spec.md` — Requirement: Overlay/Facet
Composition, Scenario: Switching from structure view to ownership view ("Tints
encode team ownership AND the structural geography provides continuity — the
human recognizes the same space with different coloring"):

Task-089 implements TintController with dimensions `["none", "context",
"community"]`. Neither provides a persistent `"owner"` dimension driven by
scene graph data. This task adds `"owner"` to the static dimension cycle so
the human can toggle to it at any time.

---

**Colour assignment** — ownership categories may be numerous. Re-use the
six-colour soft palette from task-089 (`TINT_PALETTE`), assigned round-robin
in sorted owner-string order:

```gdscript
# Sort owner strings alphabetically for stable colour assignment across reloads.
# Re-use TINT_PALETTE from task-089 — do not duplicate the constant.
```

Nodes with `owner: null` (explicitly null) or with `owner` absent receive
`Color.TRANSPARENT` — no tint. The gap in tinting signals "no owner assigned"
without visual noise.

---

**TintController extension** — in `tint_controller.gd` (task-089):

**1. Extend the dimension cycle:**

```gdscript
const DIMENSIONS = ["none", "context", "community", "owner"]
```

`cycle_dimension()` now cycles through all four values.

**2. Build owner → colour mapping on scene load** (or lazily on first
transition to `"owner"`):

```gdscript
func _build_owner_palette() -> void:
    var owners: Array[String] = []
    for node in SceneGraphLoader.nodes:
        var o = node.get("owner", null)
        if o != null and o not in owners:
            owners.append(o)
    owners.sort()  # alphabetical → stable assignment
    _owner_colours.clear()
    for i in owners.size():
        _owner_colours[owners[i]] = TINT_PALETTE[i % TINT_PALETTE.size()]
```

**3. Extend `get_tint_for_node(node_id: String) -> Color`:**

```gdscript
"owner":
    var o = _node_owner_map.get(node_id, null)  # dict built from SceneGraphLoader
    if o == null:
        return Color.TRANSPARENT
    return _owner_colours.get(o, Color.TRANSPARENT)
```

Build `_node_owner_map` (node_id → owner string) from the loaded scene graph
in `_ready()` alongside `_build_owner_palette()`.

**4. Emit `dimension_changed` signal:**

When the dimension transitions to `"owner"`, emit `dimension_changed("owner")`
as usual. The Distortion Legend (task-091) reacts to this signal and updates
its Tint section. Extend the signal payload to include the owner-to-colour
mapping so the legend can render one coloured swatch per distinct owner:

```gdscript
signal dimension_changed(dimension: String, categories: Dictionary)
# categories: { owner_string: Color } or {} for "none" dimension.
```

Update existing callers of `dimension_changed` (task-091, task-116) to accept
the optional `categories` parameter (default `{}`). When `categories` is
non-empty, the legend renders coloured squares with owner labels instead of
context or community labels.

---

**Distortion Legend update** — when `dimension == "owner"`, task-091's Tint
section must render one coloured square per distinct owner. Task-091 already
iterates `categories.keys()` for the context and community dimensions (if
extended by this task's signal change). If task-091 hard-codes context/community
rendering, update its Tint section to iterate the `categories` dictionary
generically:

```gdscript
for owner_name in categories.keys():
    var swatch := ColorRect.new()
    swatch.color = categories[owner_name]
    swatch.custom_minimum_size = Vector2(16, 16)
    # add swatch + label "owner_name" to the Tint section VBox
```

This is a minimal, additive change within task-091's existing PanelContainer.

---

**One-dimension constraint** — enforced by task-089: only ONE tint dimension
is active at a time. Cycling to "owner" replaces the previous dimension via
the existing dimension-replacement logic (no additional handling needed).

**Interaction with task-116 (resilience Tint)** — task-116 activates
"resilience" as a named dimension during failure simulation and restores the
previous dimension on reset. When the previous dimension is "owner", restoration
re-applies the owner palette. Task-116's connect to `failure_injected` /
`failure_reset` already handles dimension save/restore generically; no change
to task-116 is required.

**Scene graph with no owner data** — if no node has an `owner` field (extractor
ran without `--owners`), `_owner_colours` is empty. `get_tint_for_node` returns
`Color.TRANSPARENT` for all nodes. The `"owner"` dimension still appears in
the cycle; the human sees it and understands why nothing is coloured. Emit a
one-time Godot console warning:
`"[TintController] No owner data in scene graph. Run extractor with --owners."`

**No schema or extractor changes.** Godot-only task. Owner data is loaded from
the `owner` field on nodes, defined in task-122 and written by task-123.

Use only GDScript and Godot 4.6 API. No external libraries.
