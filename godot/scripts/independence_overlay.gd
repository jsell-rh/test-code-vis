class_name IndependenceOverlay
extends RefCounted

## Independence Overlay — visual overlay for orthogonal independence analysis.
##
## Implements specs/visualization/orthogonal-independence.spec.md:
##
##   apply_independence_highlight(selected_id, graph, anchors)
##     Given a selected module, highlights its orthogonal complement:
##       - Modules in OTHER independence groups within the same BC → INDEPENDENT_COLOR
##         (these can change without affecting the selected module)
##       - Modules in the SAME group → CODEPENDENT_COLOR
##         (these are co-dependent with the selected module)
##       - Bounded contexts with no transitive dependency on the selected module's
##         context → BC_INDEPENDENT_COLOR (fully independent at context level)
##     Transitions animate smoothly (Tween modulate.a fade).
##
##   clear_independence_highlight(anchors)
##     Resets all node colours to the default material (removes overlay).

## Colour for modules in OTHER independence groups within the same bounded context.
## These are the "safe change" peers — the orthogonal complement.
const INDEPENDENT_COLOR: Color = Color(0.1, 0.85, 0.8, 1.0)   # teal  — safe to change

## Colour for modules in the SAME independence group as the selected module.
## These co-dependent modules share an internal dependency path with the selection.
const CODEPENDENT_COLOR: Color = Color(0.95, 0.6, 0.1, 1.0)   # amber — co-dependent

## Colour for the selected module itself.
const SELECTED_COLOR: Color = Color(1.0, 1.0, 1.0, 1.0)       # white — selection

## Colour for bounded contexts that are fully independent of the selected module's context.
const BC_INDEPENDENT_COLOR: Color = Color(0.3, 0.9, 0.4, 1.0) # green — independent BC

## Animation duration for all independence highlight transitions (seconds).
const TRANSITION_DURATION: float = 0.35


# ---------------------------------------------------------------------------
# Independence highlight — module selection → orthogonal complement
# ---------------------------------------------------------------------------

## Apply independence highlight for the selected module.
##
## Spec: "all modules in other independence groups within the same bounded
## context are highlighted AND modules in A's own group are visually
## distinguished as co-dependent AND the transition is animated smoothly."
##
## Also handles cross-context independence:
## Spec: "bounded contexts with no transitive dependency on context X are
## highlighted as fully independent AND the highlight animates in from the
## selected module outward."
##
## Returns a Dictionary {node_id → assigned_color} for test assertions.
func apply_independence_highlight(
		selected_id: String,
		graph: Dictionary,
		anchors: Dictionary,
		scene_root: Node) -> Dictionary:
	var nodes_data: Array = graph.get("nodes", [])
	var edges_data: Array = graph.get("edges", [])

	# Find the selected node's data.
	var selected_node: Dictionary = {}
	for nd in nodes_data:
		if nd.get("id", "") == selected_id:
			selected_node = nd
			break

	if selected_node.is_empty():
		return {}

	var selected_group: String = selected_node.get("independence_group", "")
	var selected_bc: String = selected_node.get("parent", "")

	# Compute reachable BCs from selected_bc via cross-context edges (BFS).
	var reachable_bcs: Dictionary = _compute_reachable_bcs(selected_bc, nodes_data, edges_data)

	var result: Dictionary = {}

	for nd in nodes_data:
		var node_id: String = nd.get("id", "")
		var anchor: Node3D = anchors.get(node_id) as Node3D
		if anchor == null:
			continue

		var node_type: String = nd.get("type", "")
		var color: Color

		match node_type:
			"module":
				var node_bc: String = nd.get("parent", "")
				if node_bc != selected_bc:
					# Module in a different BC — skip (BC-level handled below).
					continue
				if node_id == selected_id:
					# The selected module itself.
					color = SELECTED_COLOR
				elif nd.get("independence_group", "") == selected_group:
					# Same independence group → co-dependent.
					color = CODEPENDENT_COLOR
				else:
					# Different independence group within the same BC → independent peer.
					color = INDEPENDENT_COLOR

			"bounded_context":
				if node_id == selected_bc:
					# Selected module's own context — no BC-level highlight.
					continue
				if reachable_bcs.has(node_id):
					# This BC is reachable from selected_bc → not fully independent.
					continue
				# No transitive dependency path → fully independent BC.
				color = BC_INDEPENDENT_COLOR

			_:
				continue

		_apply_node_color_animated(anchor, color, scene_root)
		result[node_id] = color

	return result


## Remove the independence highlight and restore default node appearance.
##
## Clears any material override set by apply_independence_highlight.
func clear_independence_highlight(anchors: Dictionary, scene_root: Node) -> void:
	for node_id in anchors.keys():
		var anchor: Node3D = anchors.get(node_id) as Node3D
		if anchor == null:
			continue
		_clear_node_color_animated(anchor, scene_root)


# ---------------------------------------------------------------------------
# Cross-context reachability
# ---------------------------------------------------------------------------

## Compute which BCs have a transitive dependency ON src_bc_id.
##
## "Dependency on X" means: there exists a forward path from that BC to X via
## cross_context edges.  We find these by doing REVERSE BFS from src_bc_id —
## walking edges backwards (target → source) to find all BCs that can reach
## src_bc_id.
##
## Returns a Dictionary containing src_bc_id itself plus every BC that has a
## transitive dependency on it.  BCs NOT in this set are fully independent of
## src_bc_id and will be highlighted by the caller.
func _compute_reachable_bcs(
		src_bc_id: String,
		nodes_data: Array,
		edges_data: Array) -> Dictionary:
	# Collect all BC IDs.
	var bc_ids: Dictionary = {}
	for nd in nodes_data:
		if nd.get("type", "") == "bounded_context":
			bc_ids[nd.get("id", "")] = true

	# Build REVERSE adjacency for cross-context edges:
	# if BC_A → BC_B exists, then rev_adj[BC_B] = {BC_A, ...}
	# This lets us walk "who depends on me?" from src_bc_id.
	var rev_adj: Dictionary = {}
	for ed in edges_data:
		if ed.get("type", "") != "cross_context":
			continue
		# source and target may be module IDs; extract BC prefix.
		var src: String = ed.get("source", "").split(".")[0]
		var tgt: String = ed.get("target", "").split(".")[0]
		if bc_ids.has(src) and bc_ids.has(tgt) and src != tgt:
			if not rev_adj.has(tgt):
				rev_adj[tgt] = {}
			rev_adj[tgt][src] = true

	# Reverse BFS from src_bc_id to find all BCs that depend on it (transitively).
	# These BCs are NOT independent of src_bc_id.
	var dependent_bcs: Dictionary = {}
	var queue: Array = [src_bc_id]
	dependent_bcs[src_bc_id] = true
	while not queue.is_empty():
		var current: String = queue.pop_front()
		var dependents: Dictionary = rev_adj.get(current, {})
		for dep: String in dependents.keys():
			if not dependent_bcs.has(dep):
				dependent_bcs[dep] = true
				queue.append(dep)

	return dependent_bcs


# ---------------------------------------------------------------------------
# Shared helpers
# ---------------------------------------------------------------------------

## Apply a color to the first MeshInstance3D child of an anchor.
## Animates with Tween when in the scene tree; sets directly otherwise (tests).
func _apply_node_color_animated(anchor: Node3D, color: Color, scene_root: Node) -> void:
	for child in anchor.get_children():
		if child is MeshInstance3D:
			var mat := StandardMaterial3D.new()
			mat.albedo_color = color
			(child as MeshInstance3D).material_override = mat
			# spec: "the transition between default and independence-highlighted states
			# is animated smoothly" — use Tween modulate.a when in the scene tree.
			if scene_root != null and scene_root.is_inside_tree():
				anchor.modulate = Color(1.0, 1.0, 1.0, 0.0)  # start transparent
				var tween: Tween = scene_root.create_tween()
				# animate opacity from 0 → 1: "animates in from the selected module outward"
				tween.tween_property(anchor, "modulate:a", 1.0, TRANSITION_DURATION)
			break


## Remove a color override from an anchor (clear independence highlight).
## Animates fade-out when in the scene tree.
func _clear_node_color_animated(anchor: Node3D, scene_root: Node) -> void:
	for child in anchor.get_children():
		if child is MeshInstance3D:
			(child as MeshInstance3D).material_override = null
			break
	if scene_root != null and scene_root.is_inside_tree():
		anchor.modulate = Color(1.0, 1.0, 1.0, 1.0)
