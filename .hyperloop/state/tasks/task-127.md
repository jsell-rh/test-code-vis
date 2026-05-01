---
id: task-127
title: Godot — smooth node position animation on hot-reload layout change
spec_ref: "specs/visualization/orthogonal-independence.spec.md@ca0ad7afad8d95361892fbfba84f55049cf288fd"
status: not-started
phase: null
deps: [task-065, task-070, task-106]
round: 0
branch: null
pr: null
pr_title: "feat(godot): animate node positions on scene graph hot-reload"
pr_description: |
  ## What and why

  When the user hot-reloads the scene graph (keyboard shortcut from task-106),
  node positions can change — for example when a new import bridges two formerly
  independent groups, collapsing them into one, which compacts the layout.
  Currently nodes would snap to their new positions instantly, breaking spatial
  continuity.  This task makes nodes *slide* to their new positions, satisfying
  the "Smooth regrouping on data change" scenario in the orthogonal-independence
  spec.

  ## Spec requirement satisfied

  `specs/visualization/orthogonal-independence.spec.md` — Requirement: Spatial
  Separation of Independent Groups, Scenario: Smooth regrouping on data change:

  > WHEN a new extraction produces different independence groups
  > THEN nodes animate smoothly to their new positions
  > AND the transition preserves spatial continuity — nodes slide rather than jump

  ## Design

  The scene graph hot-reload (task-106) already emits a `scene_graph_reloaded`
  signal after the new JSON is parsed and node data is available. This task hooks
  into that signal and drives per-node `Tween` animations instead of instant
  position snaps.

  ### Position reconciliation

  After `scene_graph_reloaded` fires, the rendering code must:

  1. Build a `new_positions: Dictionary` mapping `node_id → Vector3` from the
     freshly-loaded scene graph data.
  2. For each existing `MeshInstance3D` node volume that is still present in the
     new data:
     - Compare its current `global_position` to `new_positions[node_id]`.
     - If the delta exceeds a small epsilon (0.01 units), start a `Tween`.
  3. For nodes removed from the new data: fade out (`modulate.a` → 0) then
     `queue_free()`.
  4. For nodes added by the new data: instantiate at their target position with
     `modulate.a = 0` and fade in (opacity → 1).

  ### Tween parameters

  ```gdscript
  var tween := create_tween().set_parallel(true)
  tween.tween_property(node_volume, "position", new_pos, 0.45)\
       .set_ease(Tween.EASE_IN_OUT)\
       .set_trans(Tween.TRANS_CUBIC)
  ```

  Duration 0.45 s is fast enough to feel responsive yet slow enough for the
  human to track where each node moved.  All nodes animate in parallel so the
  entire layout settles at the same time.

  ### Edge re-routing during animation

  Edges are re-drawn each frame by the edge rendering code (task-009 / task-067).
  Since edges already reference their source and target node volumes' current
  world positions, they will follow the nodes smoothly during the Tween without
  any additional work — the edge renderer just needs to update every frame while
  a relayout Tween is running.

  To prevent edge redraw overhead from stacking up: set a boolean flag
  `_relayout_in_progress = true` when any position Tween starts and `false`
  when all Tweens complete.  Edge rendering should call `queue_redraw()` or
  update `ImmediateMesh` vertices every `_process` frame only while this flag
  is true (already the case for animated edges from task-067).

  ### Independence group tint continuity

  The independence group tint (task-070) is baked into the `StandardMaterial3D`
  of each node volume, keyed on `independence_group`.  After the layout Tween
  completes, update the tint material if the node's group has changed.  Do NOT
  update the tint mid-animation — keep the old tint during flight and switch
  atomically when the node settles.  This prevents colour flicker during the
  slide.

  ## Files / areas affected

  - `godot/autoload/scene_graph_loader.gd` — subscribe to `scene_graph_reloaded`
    signal; expose a `get_node_positions() → Dictionary` helper.
  - `godot/scene/main_scene.gd` (or the node-rendering component) — position
    reconciliation logic and Tween launch.
  - Edge rendering component — confirm it reads live node world positions each
    frame (no change needed if already doing so).

  ## How to verify

  1. Run the extractor against kartograph normally and load the scene.
  2. Temporarily add a dummy import between two independent groups in kartograph
     (bridging them), re-run the extractor, and press the hot-reload key.
  3. Nodes that were spatially separated should slide smoothly together rather
     than jumping.
  4. Remove the dummy import, re-extract, hot-reload — nodes should slide back
     apart.
  5. Edges should remain correctly connected to node volumes throughout the
     animations.

  ## Caveats / follow-up

  - If a relayout produces a very large positional delta (e.g. the entire layout
    flips), the 0.45 s duration may be insufficient for the human to track
    individual nodes.  A future enhancement could scale duration proportionally
    to delta magnitude.
  - Cluster suggestion rings (task-126) may need their positions updated after
    the Tween completes if they are parented to the scene root rather than to
    the node volume; if they are children of the volume they move automatically.
---

Implement smooth Tween-based position animation for node volumes when the scene
graph hot-reload (task-106) produces a new layout.  Satisfies the
orthogonal-independence spec scenario "Smooth regrouping on data change":
nodes must *slide* to new positions, not snap.

Covers `specs/visualization/orthogonal-independence.spec.md` — Requirement:
Spatial Separation of Independent Groups, Scenario: Smooth regrouping on data
change.

---

### Acceptance criteria

1. Hot-reloading a scene graph that changes node positions causes all moved
   nodes to animate smoothly (Tween, 0.45 s, ease-in-out cubic) rather than
   snapping.
2. Edges remain continuously connected to node volumes during the animation.
3. Independence group tints do NOT flicker during position animation; they
   update only after the Tween completes.
4. New nodes fade in at their target position; removed nodes fade out before
   being freed.
5. The animation completes fully before a second hot-reload can be triggered
   (or the in-progress Tween is killed and replaced cleanly).

### Implementation notes

- Use `create_tween().set_parallel(true)` so all node moves run concurrently
  and the scene settles at the same moment.
- A `_relayout_in_progress` flag guards edge redraw against unnecessary per-frame
  updates outside animation windows.
- Tint material swap happens atomically on `tween_all_completed` signal, not
  mid-flight.
- No extractor or schema changes — this is a Godot-only task.
- Use only GDScript and Godot 4.6 API.  No external libraries.
