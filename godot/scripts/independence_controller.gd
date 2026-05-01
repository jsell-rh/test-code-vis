class_name IndependenceController
extends RefCounted

## Independence Controller — highlights orthogonal independence for a selected module.
##
## When a module is selected, this controller:
##   1. Reads the 'independence_group' field from the scene graph nodes.
##   2. Highlights modules in OTHER groups as INDEPENDENT_COLOR (orthogonally free).
##   3. Highlights modules in the SAME group as CODEPENDENT_COLOR (structurally coupled).
##   4. Highlights the selected module as SELECTED_COLOR.
##   5. Highlights bounded contexts with no transitive dep on the selected context
##      as CONTEXT_INDEPENDENT_COLOR (cross-context independence).
##   6. Uses Tween on material albedo_color:a for smooth animated transitions
##      (fade in/out). Node3D/MeshInstance3D has no modulate property.
##
## Implements specs/visualization/orthogonal-independence.spec.md
## § "Independence as Queryable Property"

## ── Colour constants ─────────────────────────────────────────────────────────
## Blue  — module is orthogonally independent of the selected module.
const INDEPENDENT_COLOR: Color = Color(0.15, 0.55, 1.0, 1.0)
## Orange — module is co-dependent (same independence group as selected).
const CODEPENDENT_COLOR: Color = Color(1.0, 0.60, 0.10, 1.0)
## Yellow — the selected module itself.
const SELECTED_COLOR: Color = Color(1.0, 0.95, 0.15, 1.0)
## Green — bounded context is fully independent of the selected context.
const CONTEXT_INDEPENDENT_COLOR: Color = Color(0.20, 0.90, 0.45, 1.0)

## Duration of the animated opacity fade-in in seconds (spec: "smoothly").
const TRANSITION_DURATION: float = 0.35

## ID of the currently selected module.  Empty string = no selection.
var _selected_id: String = ""


# ---------------------------------------------------------------------------
# Public API
# ---------------------------------------------------------------------------

## Select *node_id* and display its orthogonal complement.
##
## Reads independence_group from node data in *graph* to classify all other
## modules as either co-dependent (same group) or independent (different group).
## Bounded contexts with no transitive dependency on the selected module's
## context are highlighted as context-level independent peers.
##
## Animated transition: each highlighted node's material is replaced with the
## target colour and albedo_color:a fades from 0 → 1 via a Tween so the
## highlight smoothly appears rather than jumping.
##
## *tween_host* must be a Node that is inside the scene tree; if null the
## colour is applied directly (no animation) so unit tests can call this
## without a running scene.
func select_module(
		node_id: String,
		graph: Dictionary,
		anchors: Dictionary,
		tween_host: Node) -> void:
	_selected_id = node_id
	var nodes: Array = graph.get("nodes", [])

	# Locate the selected node's data.
	var selected_node: Dictionary = {}
	for nd: Dictionary in nodes:
		if nd.get("id", "") == node_id:
			selected_node = nd
			break
	if selected_node.is_empty():
		return

	var selected_group: String = selected_node.get("independence_group", "")
	var selected_context: String = selected_node.get("parent", "")

	# Find bounded contexts with no transitive dependency on selected_context.
	var ctx_independent_ids: Array = _find_independent_contexts(selected_context, graph)

	# Apply colours to relevant nodes.
	for nd: Dictionary in nodes:
		var nid: String = nd.get("id", "")
		var anchor: Node3D = anchors.get(nid) as Node3D
		if anchor == null:
			continue

		var ntype: String = nd.get("type", "")
		# independence_group and parent may be absent or explicitly null on
		# bounded-context nodes; guard against null→String assignment errors.
		var raw_group = nd.get("independence_group")
		var ngroup: String = raw_group if raw_group != null else ""
		var raw_parent = nd.get("parent")
		var nparent: String = raw_parent if raw_parent != null else ""

		var target_color: Color
		var should_highlight: bool = true

		if nid == node_id:
			# The selected module.
			target_color = SELECTED_COLOR
		elif ntype == "module" and nparent == selected_context:
			# Same bounded context — classify by independence group.
			if ngroup == selected_group:
				# Same group → structurally co-dependent.
				target_color = CODEPENDENT_COLOR
			else:
				# Different group → orthogonally independent.
				target_color = INDEPENDENT_COLOR
		elif ntype == "bounded_context" and ctx_independent_ids.has(nid):
			# Context with no transitive dependency on the selected context.
			target_color = CONTEXT_INDEPENDENT_COLOR
		else:
			should_highlight = false

		if should_highlight:
			# spec: "the transition between default and independence-highlighted
			# states is animated smoothly" → fade in the new colour via modulate:a.
			_apply_color_animated(anchor, target_color, tween_host)


## Clear all independence highlighting, restoring nodes to their default appearance.
func clear_independence_highlight(anchors: Dictionary, graph: Dictionary, tween_host: Node) -> void:
	_selected_id = ""
	var nodes: Array = graph.get("nodes", [])
	for nd: Dictionary in nodes:
		var nid: String = nd.get("id", "")
		var anchor: Node3D = anchors.get(nid) as Node3D
		if anchor != null:
			# Restore default modulate (fully opaque, no colour tint).
			_restore_modulate_animated(anchor, tween_host)


## Return the ID of the currently selected module (empty string = none).
func get_selected_id() -> String:
	return _selected_id


# ---------------------------------------------------------------------------
# Cross-context independence
# ---------------------------------------------------------------------------

## Return the IDs of bounded contexts that have no transitive dependency
## (in either direction) on *target_context*.
##
## spec: "bounded contexts with no transitive dependency on context X are
##        highlighted as fully independent"
func _find_independent_contexts(target_context: String, graph: Dictionary) -> Array:
	if target_context.is_empty():
		return []

	var edges: Array = graph.get("edges", [])
	var nodes: Array = graph.get("nodes", [])

	# Build forward adjacency (source → target) for cross-context edges.
	var fwd: Dictionary = {}   # {src_ctx: [tgt_ctx, ...]}
	var rev: Dictionary = {}   # {tgt_ctx: [src_ctx, ...]}
	for ed: Dictionary in edges:
		if ed.get("type", "") == "cross_context":
			var src: String = ed.get("source", "")
			var tgt: String = ed.get("target", "")
			if src.is_empty() or tgt.is_empty():
				continue
			if not fwd.has(src):
				fwd[src] = []
			fwd[src].append(tgt)
			if not rev.has(tgt):
				rev[tgt] = []
			rev[tgt].append(src)

	# BFS forward (contexts reachable FROM target_context).
	var reachable: Dictionary = {target_context: true}
	var queue: Array = [target_context]
	while not queue.is_empty():
		var cur = queue.pop_front()
		for nb in fwd.get(cur, []):
			if not reachable.has(nb):
				reachable[nb] = true
				queue.append(nb)

	# BFS reverse (contexts that transitively depend ON target_context).
	var rev_queue: Array = [target_context]
	while not rev_queue.is_empty():
		var cur = rev_queue.pop_front()
		for nb in rev.get(cur, []):
			if not reachable.has(nb):
				reachable[nb] = true
				rev_queue.append(nb)

	# Collect bounded-context nodes NOT in the reachable set.
	var independent: Array = []
	for nd in nodes:
		if (nd as Dictionary).get("type", "") == "bounded_context":
			var nid: String = (nd as Dictionary).get("id", "")
			if not reachable.has(nid):
				independent.append(nid)
	return independent


# ---------------------------------------------------------------------------
# Visual helpers
# ---------------------------------------------------------------------------

## Set the first MeshInstance3D child's material to *color* and animate
## albedo_color:a from 0.0 → 1.0 so the highlight fades in smoothly.
##
## MeshInstance3D is a Node3D (not a CanvasItem) and therefore has no
## *modulate* property.  Animation is achieved by tweening the material's
## albedo_color:a channel instead, which works in 3D.
##
## If *tween_host* is null or not in the scene tree, the color is applied
## directly (no Tween) — used by unit tests that run without a scene.
func _apply_color_animated(anchor: Node3D, color: Color, tween_host: Node) -> void:
	for child in anchor.get_children():
		if child is MeshInstance3D:
			var mat := StandardMaterial3D.new()
			mat.albedo_color = color
			(child as MeshInstance3D).material_override = mat
			if tween_host != null and tween_host.is_inside_tree():
				# spec: "animated smoothly" → fade albedo_color:a from 0 to 1.
				# MeshInstance3D has no modulate (that is a CanvasItem property);
				# animate through the material instead.
				mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
				mat.albedo_color.a = 0.0
				var tween: Tween = tween_host.create_tween()
				tween.tween_property(mat, "albedo_color:a", 1.0, TRANSITION_DURATION)
			break


## Restore the first MeshInstance3D child's material alpha to fully opaque.
## Fades in via Tween when in the scene tree, or snaps directly in tests.
## (Node3D / MeshInstance3D has no modulate property — uses material alpha.)
func _restore_modulate_animated(anchor: Node3D, tween_host: Node) -> void:
	for child in anchor.get_children():
		if child is MeshInstance3D:
			var mat: StandardMaterial3D = (child as MeshInstance3D).material_override as StandardMaterial3D
			if mat == null:
				break
			if tween_host != null and tween_host.is_inside_tree():
				var tween: Tween = tween_host.create_tween()
				tween.tween_property(mat, "albedo_color:a", 1.0, TRANSITION_DURATION)
			else:
				mat.albedo_color.a = 1.0
			break
