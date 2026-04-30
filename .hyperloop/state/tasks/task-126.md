---
id: task-126
title: Godot — cluster loader extension and pre-collapse suggestion indicator
spec_ref: specs/extraction/scene-graph-schema.spec.md
status: not-started
phase: null
deps: [task-008, task-061, task-009, task-068]
round: 0
branch: null
pr: null
---

Extend the Godot scene graph loader to parse the `clusters` array from the JSON
scene graph and provide a visual indicator on cluster member nodes before the human
triggers collapse, plus the UI entry point that fires the collapse mechanic in
task-068.

Covers `specs/extraction/scene-graph-schema.spec.md` — Requirement: Cluster Schema,
and `specs/visualization/spatial-structure.spec.md` — Requirement: Cluster Collapsing,
Scenario: Pre-computed cluster suggestions ("suggested clusters are indicated visually
AND the human can accept a suggestion to collapse, or ignore it AND suggestions never
auto-collapse — the human always initiates"):

---

**Loader extension** (task-008 autoload):

Add a `clusters: Array[Dictionary]` property to the scene graph loader autoload.
When the JSON file is parsed, populate this property from the top-level `clusters`
key (an array per the schema in task-061). Each entry is the raw dict:
```
{
  "id": "<context_id>:cluster_<n>",
  "members": [...],
  "context": "<context_id>",
  "aggregate_metrics": { "total_loc": int, "in_degree": int, "out_degree": int }
}
```
If `clusters` is absent in the JSON (e.g. extractor ran with `--no-clusters`),
default to an empty array. The loader must not crash on a missing key.

Extend the `scene_graph_reloaded` signal (task-106) to include the refreshed cluster
list so all subscribers receive updated cluster data on hot-reload.

---

**ClusterSuggestionManager autoload** (`godot/autoload/cluster_suggestion_manager.gd`):

A lightweight singleton that exposes cluster data and tracks suggestion UI state:
```gdscript
extends Node
var clusters: Array[Dictionary] = []   # from SceneGraphLoader

func load_clusters(data: Array[Dictionary]) -> void:
    clusters = data
    emit_signal("clusters_loaded", clusters)

signal clusters_loaded(clusters: Array[Dictionary])
```

Called on initial load and on `scene_graph_reloaded`.

---

**Visual suggestion indicator** — for each cluster entry:

1. After node volumes are created (task-009), identify the `MeshInstance3D` nodes
   whose ids appear in `cluster["members"]`.
2. Apply a subtle shared visual hint to all members of the same cluster:
   - Add a thin ring `MeshInstance3D` (a `TorusMesh` with a small tube radius) as a
     child of each member node volume, positioned at the node's vertical midpoint.
   - The ring color is a desaturated cluster-specific hue (one color per cluster index
     within the context, drawn from a 4-color soft palette).
   - Ring `modulate.a = 0.45` (subtle — does not compete with structural encoding).
   - Name the ring node `"ClusterSuggestionRing"` for lookup.
3. Different clusters within the same context get different hue assignments.
   Singleton nodes (not in any cluster) have no ring.

**Ring is not a badge and not a tint** — it occupies the ring/halo spatial channel,
not the badge glyph channel or the container fill color channel, so it does not
interfere with independence group tints (task-070) or the Tint primitive (task-089).

---

**UI trigger for collapse**:

The human initiates collapse by clicking on any member node that has a
`ClusterSuggestionRing`. Integrate with the existing input handling in the main scene:

1. When the human clicks a node (existing input path from task-009's node picking):
   - Check if the clicked node id appears in any cluster's `members` array via
     `ClusterSuggestionManager.clusters`.
   - If yes, enter "cluster selection" mode:
     - Highlight all members of that cluster (increase ring opacity to 1.0 and add a
       pulsing animation via `Tween` on `ring.modulate.a` between 0.8 and 1.0).
     - Display a brief HUD tooltip: `"[C] Collapse cluster  [Esc] Cancel"`.

2. While in cluster selection mode:
   - Pressing `C` calls `ClusterManager.collapse_cluster(cluster_id)` from task-068.
     The `cluster_id` is the `id` field of the matched cluster entry.
   - Pressing `Escape` or clicking elsewhere exits cluster selection mode and restores
     ring opacity to 0.45.

3. After collapse is triggered, the `ClusterSuggestionRing` nodes on the (now hidden)
   member volumes are set `visible = false`. The ring on the newly created supernode
   is not added (the supernode is the result of the collapse, not a suggestion).

4. After expand (task-068 `expand_cluster`), restore `ClusterSuggestionRing.visible
   = true` and `modulate.a = 0.45` on re-shown member nodes.

---

**Key legend update** — add `"[C] Collapse cluster (when cluster selected)"` to the
HUD key reference (task-106 / task-039 legend update point). This key is active only
in cluster selection mode.

**No schema or extractor changes.** Godot-only task; all cluster data comes from the
extractor via the JSON scene graph loaded by task-061 and task-066.

Use only GDScript and Godot 4.6 API. No external libraries.
