---
id: task-127
title: Godot — smooth node position animation on hot-reload layout change
spec_ref: specs/visualization/orthogonal-independence.spec.md@ca0ad7afad8d95361892fbfba84f55049cf288fd
status: not_started
phase: null
deps:
- task-065
- task-070
- task-106
round: 0
branch: null
pr: null
pr_title: 'feat(godot): animate node positions on scene graph hot-reload'
pr_description: "## What and why\n\nWhen the user hot-reloads the scene graph (keyboard\
  \ shortcut from task-106),\nnode positions can change — for example when a new import\
  \ bridges two formerly\nindependent groups, collapsing them into one, which compacts\
  \ the layout.\nCurrently nodes would snap to their new positions instantly, breaking\
  \ spatial\ncontinuity.  This task makes nodes *slide* to their new positions, satisfying\n\
  the \"Smooth regrouping on data change\" scenario in the orthogonal-independence\n\
  spec.\n\n## Spec requirement satisfied\n\n`specs/visualization/orthogonal-independence.spec.md`\
  \ — Requirement: Spatial\nSeparation of Independent Groups, Scenario: Smooth regrouping\
  \ on data change:\n\n> WHEN a new extraction produces different independence groups\n\
  > THEN nodes animate smoothly to their new positions\n> AND the transition preserves\
  \ spatial continuity — nodes slide rather than jump\n\n## Design\n\nThe scene graph\
  \ hot-reload (task-106) already emits a `scene_graph_reloaded`\nsignal after the\
  \ new JSON is parsed and node data is available. This task hooks\ninto that signal\
  \ and drives per-node `Tween` animations instead of instant\nposition snaps.\n\n\
  ### Position reconciliation\n\nAfter `scene_graph_reloaded` fires, the rendering\
  \ code must:\n\n1. Build a `new_positions: Dictionary` mapping `node_id → Vector3`\
  \ from the\n   freshly-loaded scene graph data.\n2. For each existing `MeshInstance3D`\
  \ node volume that is still present in the\n   new data:\n   - Compare its current\
  \ `global_position` to `new_positions[node_id]`.\n   - If the delta exceeds a small\
  \ epsilon (0.01 units), start a `Tween`.\n3. For nodes removed from the new data:\
  \ fade out (`modulate.a` → 0) then\n   `queue_free()`.\n4. For nodes added by the\
  \ new data: instantiate at their target position with\n   `modulate.a = 0` and fade\
  \ in (opacity → 1).\n\n### Tween parameters\n\n```gdscript\nvar tween := create_tween().set_parallel(true)\n\
  tween.tween_property(node_volume, \"position\", new_pos, 0.45)\\\n     .set_ease(Tween.EASE_IN_OUT)\\\
  \n     .set_trans(Tween.TRANS_CUBIC)\n```\n\nDuration 0.45 s is fast enough to feel\
  \ responsive yet slow enough for the\nhuman to track where each node moved.  All\
  \ nodes animate in parallel so the\nentire layout settles at the same time.\n\n\
  ### Edge re-routing during animation\n\nEdges are re-drawn each frame by the edge\
  \ rendering code (task-009 / task-067).\nSince edges already reference their source\
  \ and target node volumes' current\nworld positions, they will follow the nodes\
  \ smoothly during the Tween without\nany additional work — the edge renderer just\
  \ needs to update every frame while\na relayout Tween is running.\n\nTo prevent\
  \ edge redraw overhead from stacking up: set a boolean flag\n`_relayout_in_progress\
  \ = true` when any position Tween starts and `false`\nwhen all Tweens complete.\
  \  Edge rendering should call `queue_redraw()` or\nupdate `ImmediateMesh` vertices\
  \ every `_process` frame only while this flag\nis true (already the case for animated\
  \ edges from task-067).\n\n### Independence group tint continuity\n\nThe independence\
  \ group tint (task-070) is baked into the `StandardMaterial3D`\nof each node volume,\
  \ keyed on `independence_group`.  After the layout Tween\ncompletes, update the\
  \ tint material if the node's group has changed.  Do NOT\nupdate the tint mid-animation\
  \ — keep the old tint during flight and switch\natomically when the node settles.\
  \  This prevents colour flicker during the\nslide.\n\n## Files / areas affected\n\
  \n- `godot/autoload/scene_graph_loader.gd` — subscribe to `scene_graph_reloaded`\n\
  \  signal; expose a `get_node_positions() → Dictionary` helper.\n- `godot/scene/main_scene.gd`\
  \ (or the node-rendering component) — position\n  reconciliation logic and Tween\
  \ launch.\n- Edge rendering component — confirm it reads live node world positions\
  \ each\n  frame (no change needed if already doing so).\n\n## How to verify\n\n\
  1. Run the extractor against kartograph normally and load the scene.\n2. Temporarily\
  \ add a dummy import between two independent groups in kartograph\n   (bridging\
  \ them), re-run the extractor, and press the hot-reload key.\n3. Nodes that were\
  \ spatially separated should slide smoothly together rather\n   than jumping.\n\
  4. Remove the dummy import, re-extract, hot-reload — nodes should slide back\n \
  \  apart.\n5. Edges should remain correctly connected to node volumes throughout\
  \ the\n   animations.\n\n## Caveats / follow-up\n\n- If a relayout produces a very\
  \ large positional delta (e.g. the entire layout\n  flips), the 0.45 s duration\
  \ may be insufficient for the human to track\n  individual nodes.  A future enhancement\
  \ could scale duration proportionally\n  to delta magnitude.\n- Cluster suggestion\
  \ rings (task-126) may need their positions updated after\n  the Tween completes\
  \ if they are parented to the scene root rather than to\n  the node volume; if they\
  \ are children of the volume they move automatically."
---
