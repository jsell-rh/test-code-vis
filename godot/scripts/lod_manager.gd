extends RefCounted

## Level-of-detail (LOD) manager for the spatial structure visualisation.
##
## Controls which nodes and edges are visible based on camera distance from
## the scene pivot. This implements the "Scale Through Zoom" requirement from
## specs/visualization/spatial-structure.spec.md:
##
##   FAR   (camera_distance > FAR_THRESHOLD):
##     Only top-level services (bounded_context) are visible.
##     All module nodes and all edges are hidden.
##
##   MEDIUM (NEAR_THRESHOLD < camera_distance ≤ FAR_THRESHOLD):
##     Services (bounded_context) and their internal modules are visible.
##     Cross-context edges are visible.
##     Internal (within-context) edges remain hidden.
##
##   NEAR  (camera_distance ≤ NEAR_THRESHOLD):
##     Everything visible — bounded_context, module, all edges.
##     This is the "finer-grained details appear" level from the spec.
##
## Entry formats:
##   node_entries[i]  = {anchor: Node3D,  node_type: String}
##   edge_entries[i]  = {visual: Node3D,  edge_type: String}
##
## Each edge creates two visual nodes (line mesh + arrowhead cone). Both are
## stored as separate entries with the same edge_type so they toggle together.

const FAR_THRESHOLD: float = 80.0
const NEAR_THRESHOLD: float = 20.0

## Fade duration in seconds for LOD transitions.
## Spec (spatial-structure.spec.md § "Smooth transitions between levels"):
##   "elements fade in or out with animated opacity, never appearing or
##    disappearing instantly"
const LOD_FADE_DURATION: float = 0.25


## Apply LOD visibility to all tracked nodes and edges.
##
## node_entries: Array of {anchor: Node3D, node_type: String}
## edge_entries: Array of {visual: Node3D, edge_type: String}
## camera_distance: current distance from camera to scene pivot
func update_lod(
	node_entries: Array,
	edge_entries: Array,
	camera_distance: float
) -> void:
	if camera_distance > FAR_THRESHOLD:
		_apply_far(node_entries, edge_entries)
	elif camera_distance > NEAR_THRESHOLD:
		_apply_medium(node_entries, edge_entries)
	else:
		_apply_near(node_entries, edge_entries)


## Transition a node's visibility with smooth animated opacity.
##
## Sets node.visible immediately (so synchronous callers such as unit tests
## see the correct value right away). When the node is inside the scene tree
## the transition is additionally animated via Tween on modulate.a so that
## elements fade in or out rather than appearing or disappearing instantly,
## as required by spatial-structure.spec.md § "Smooth transitions between levels".
##
## Spec: "elements fade in or out with animated opacity, never appearing or
##        disappearing instantly."
func _transition_visible(node: Node3D, show: bool) -> void:
	node.visible = show
	if node.is_inside_tree():
		var target_alpha: float = 1.0 if show else 0.0
		node.create_tween().tween_property(node, "modulate:a", target_alpha, LOD_FADE_DURATION)


## FAR: only bounded_context and spec anchors visible.
##
## Edge visibility at FAR distance:
##   aggregate edges (one per context pair, weight = total import count) → VISIBLE
##   cross_context individual edges → HIDDEN
##   internal edges → HIDDEN
##
## Spec: visual-primitives.spec.md §LOD Shell Primitive — tier 0 (far): the
## context is a single Container with aggregate metrics and its Landmarks.
## Spec: spatial-structure.spec.md §Far — bounded context architecture:
## cross-context dependencies are shown as single aggregate edges per
## context pair, with weight indicating total import count.
##
## Spec nodes (intended design) are top-level like bounded_context nodes and
## remain visible at all distances so the human can always see the intended design.
func _apply_far(node_entries: Array, edge_entries: Array) -> void:
	for entry: Dictionary in node_entries:
		var anchor: Node3D = entry["anchor"]
		var ntype: String = entry["node_type"]
		_transition_visible(anchor, ntype == "bounded_context" or ntype == "spec")
	for entry: Dictionary in edge_entries:
		var vis_node: Node3D = entry["visual"]
		var etype: String = entry["edge_type"]
		# Show only aggregate edges at FAR; hide individual cross-context and internal.
		_transition_visible(vis_node, etype == "aggregate")


## MEDIUM: bounded_context, module, and spec visible; cross_context edges visible;
## internal and aggregate edges hidden.
## Spec: visual-primitives.spec.md §LOD Shell Primitive — tier 1 (medium): the
## context expands to show its module-level Containers with inter-module Edges.
func _apply_medium(node_entries: Array, edge_entries: Array) -> void:
	for entry: Dictionary in node_entries:
		var anchor: Node3D = entry["anchor"]
		var ntype: String = entry["node_type"]
		_transition_visible(anchor, ntype == "bounded_context" or ntype == "module" or ntype == "spec")
	for entry: Dictionary in edge_entries:
		var vis_node: Node3D = entry["visual"]
		var etype: String = entry["edge_type"]
		# Individual cross-context edges visible; aggregate and internal hidden.
		_transition_visible(vis_node, etype == "cross_context")


## NEAR: all nodes and non-aggregate edges visible — finest detail level.
## Spec: visual-primitives.spec.md §LOD Shell Primitive — tier 2 (near): modules
## expand to show classes, functions, and all Edges.
## Aggregate edges are hidden at NEAR because individual edges provide full detail.
func _apply_near(node_entries: Array, edge_entries: Array) -> void:
	for entry: Dictionary in node_entries:
		_transition_visible(entry["anchor"] as Node3D, true)
	for entry: Dictionary in edge_entries:
		var vis_node: Node3D = entry["visual"]
		var etype: String = entry["edge_type"]
		# All edges visible at near; aggregate edges hidden (individual edges shown).
		_transition_visible(vis_node, etype != "aggregate")
