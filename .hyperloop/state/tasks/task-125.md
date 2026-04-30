---
id: task-125
title: Godot — Landmark Primitive (hub/bridge/entry-point nodes at all zoom levels)
spec_ref: specs/core/visual-primitives.spec.md
status: not-started
phase: null
deps: [task-074, task-082, task-009, task-019]
round: 0
branch: null
pr: null
---

Implement the Landmark Primitive: read the `landmark` boolean flag from loaded nodes
and give landmark nodes a persistent, distinctive visual treatment that survives all
LOD tier transitions so they always serve as spatial orientation anchors.

Covers `specs/core/visual-primitives.spec.md` — Requirement: Landmark Primitive,
Scenarios: Hub as landmark, Entry point as landmark, Bridge as landmark, Landmark
sources:

---

**Landmark identification** — after scene graph load, iterate all nodes. For every
node where `node["landmark"] == true` (per the schema defined in task-074 and
populated by task-082):

1. Store the node id in a `LandmarkManager` autoload
   (`godot/autoload/landmark_manager.gd`) in a `landmarks: Array[String]` list.
2. The landmark list is the single authoritative source for which nodes are currently
   landmarks. Other systems (Distortion Legend in task-091) read from this list.

**LandmarkManager autoload** — minimal singleton:
```gdscript
extends Node
var landmarks: Array[String] = []

func set_landmarks(ids: Array[String]) -> void:
    landmarks = ids
    emit_signal("landmarks_changed", landmarks)

signal landmarks_changed(ids: Array[String])
```

---

**Visual treatment** — for each node whose id is in `LandmarkManager.landmarks`,
apply the following adjustments to its `MeshInstance3D` immediately after the base
node volumes are created by task-009:

1. **Scale** — multiply the node's base scale by `LANDMARK_SCALE = 1.35`. Use
   `node_mesh.scale *= Vector3.ONE * LANDMARK_SCALE`. This makes landmark nodes
   visually larger than their non-landmark peers.

2. **Emissive glow** — on the node's `StandardMaterial3D`, set:
   ```gdscript
   mat.emission_enabled = true
   mat.emission = Color(1.0, 0.9, 0.4)   # gold
   mat.emission_energy = 1.2
   ```
   The gold glow makes landmark nodes immediately identifiable even at far LOD.

3. **Label emphasis** — if the node has a `Label3D` name label (from task-012),
   increase its `font_size` by 2 pts relative to the standard label size.

---

**LOD override** — landmark nodes MUST remain visible at every LOD tier, regardless
of camera distance. Override task-019's LOD visibility logic for landmark nodes:

In the LOD `_process()` loop, after computing `new_visible` for a node, add:
```gdscript
if LandmarkManager.landmarks.has(node_id):
    new_visible = true   # landmarks are never hidden by LOD
```

This ensures the human always has spatial anchors visible. Non-landmark nodes continue
to appear and disappear according to normal LOD thresholds.

---

**Landmark list for Distortion Legend** — task-091 queries `LandmarkManager.landmarks`
to populate "Section 4 — Active Landmarks" of the Distortion Legend. No additional
API is needed beyond the `landmarks` array and `landmarks_changed` signal.

---

**Landmark sources** (from task-082's significance computation):
- High in-degree nodes (hubs) — imported by many other modules
- High betweenness centrality nodes (bridges) — sit on many shortest paths
- Entry points — no in-edges from application code (e.g. CLI main, HTTP handler)
- Human-designated landmarks — `landmark: true` set manually in scene graph JSON

This task ONLY reads and renders the `landmark` flag; derivation is task-082's job.

---

**Scene graph reload** — connect to the `scene_graph_reloaded` signal from the loader
autoload (task-008 / task-106) to refresh the landmark list:
```gdscript
SceneGraphLoader.scene_graph_reloaded.connect(_on_scene_graph_reloaded)

func _on_scene_graph_reloaded(new_data: Dictionary) -> void:
    var new_ids := []
    for node in new_data["nodes"]:
        if node.get("landmark", false):
            new_ids.append(node["id"])
    LandmarkManager.set_landmarks(new_ids)
    _apply_landmark_visuals()
```

After refreshing the list, re-apply visual treatment to the updated node set:
remove gold glow from previously landmark nodes that are no longer landmarks, add
gold glow to newly landmark nodes.

---

**No external libraries.** GDScript and Godot 4.6 API only.
