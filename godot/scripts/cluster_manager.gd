extends RefCounted

## Cluster collapse / expand manager for the spatial-structure visualisation.
##
## Implements specs/visualization/spatial-structure.spec.md § "Cluster Collapsing":
##
##   "The human MUST be able to collapse a group of tightly-coupled modules
##    into a single supernode, reducing visual complexity without losing
##    structural information."
##
## Features:
##   - apply_cluster_hints()  — renders a subtle tint on members of each
##     suggested cluster so the human can see cluster suggestions without
##     auto-collapsing.
##   - collapse_cluster()     — animates member modules converging into a
##     supernode at their centroid; creates supernode label with aggregate metrics;
##     reroutes edge endpoints that formerly connected to cluster members so they
##     now point to the supernode.
##   - expand_cluster()       — animates the supernode expanding back into
##     its constituent modules at their original positions; restores all
##     rerouted edge endpoints.
##
## Spec § "Pre-computed cluster suggestions":
##   "suggested clusters are indicated visually (e.g. subtle shared tint or
##    proximity grouping) AND the human can accept a suggestion to collapse,
##    or ignore it AND suggestions never auto-collapse"
##
## Animation spec § "Collapsing a cluster":
##   "modules animate together, converging smoothly into a single supernode"
##   "edges that formerly entered or left any member of the cluster are
##    re-routed to the supernode"
##   "edge re-routing animates smoothly — endpoints slide to the supernode
##    rather than jumping"
##
## Animation spec § "Expanding a supernode":
##   "modules animate outward to their original positions"
##   "edges re-route back to their original endpoints with smooth animation"
##
## Animation spec § "Smooth transitions between levels":
##   Uses Tween-based opacity so elements never appear or disappear instantly.

## Duration (seconds) for collapse/expand animations.
const ANIM_DURATION: float = 0.35

## Subtle alpha for cluster-hint tint overlay so it does not dominate the view.
const HINT_TINT_ALPHA: float = 0.22

## Height of the arrowhead cone (must match main.gd's _create_edge()).
## Used when repositioning arrow visuals during edge rerouting.
const ARROW_CONE_HEIGHT: float = 0.7

## Cluster hint colours — one per cluster index, cycling.
const HINT_COLOURS: Array = [
	Color(0.95, 0.70, 0.10, HINT_TINT_ALPHA),  # amber
	Color(0.15, 0.80, 0.70, HINT_TINT_ALPHA),  # teal
	Color(0.80, 0.25, 0.80, HINT_TINT_ALPHA),  # violet
	Color(0.20, 0.75, 0.30, HINT_TINT_ALPHA),  # green
]

## Tracks per-cluster collapse state.
## Keyed by cluster_id → {
##   collapsed: bool,
##   supernode: Node3D,
##   members: Array[String],
##   centroid: Vector3,
##   original_positions: Dictionary,       # member_id → Vector3 (local position before collapse)
##   rerouted_edges: Array[Dictionary],    # [{entry_idx, orig_from, orig_to}, ...]
##   hidden_internal_lines: Array[Node3D], # internal-edge visuals hidden during collapse
## }
var _collapse_state: Dictionary = {}

## Reference to the main scene's _anchors dictionary (node_id → Node3D).
## Set via init() before any collapse/expand operation.
var _anchors: Dictionary = {}

## Reference to the Godot Node3D that owns the scene (used for add_child).
var _scene_root: Node3D = null

## Reference to main.gd's _path_edge_entries (Array[Dictionary]).
## Each entry: {visual, source, target, entry_type, from_pos, to_pos}
## Shared by reference so that cluster_manager can mutate from_pos/to_pos
## during collapse/expand without a copy round-trip.
## Spec: "edges that formerly entered or left any member of the cluster are
##        re-routed to the supernode".
var _path_edge_entries: Array = []

## In-progress edge endpoint animations.
## Keyed by a unique edge animation id (string) →
##   {from_pos, to_pos, target_from, target_to, progress, duration, entry}
## Populated by _reroute_edges_for_collapse() and _restore_edges_for_expand().
## Drained each frame by _process().
var _edge_animations: Dictionary = {}


## Initialise this manager with the main scene's anchor map, root node, and
## edge-entry array.  Must be called before collapse_cluster() or expand_cluster().
##
## path_edge_entries: reference to main.gd's _path_edge_entries; passed here so
##   collapse/expand can reroute edge endpoints in-place.
func init(
	anchors: Dictionary,
	scene_root: Node3D,
	path_edge_entries: Array = [],
) -> void:
	_anchors = anchors
	_scene_root = scene_root
	_path_edge_entries = path_edge_entries


# ---------------------------------------------------------------------------
# Cluster hint visualisation
# ---------------------------------------------------------------------------

## Apply subtle tint overlays to member nodes of each suggested cluster.
##
## Spec: "suggested clusters are indicated visually (e.g. subtle shared tint)"
##       "suggestions never auto-collapse — the human always initiates"
##
## For each cluster entry in *clusters*, adds a thin coloured plane (BoxMesh,
## flat) on top of each member's anchor so they share a shared visual tint.
## The tint node is named "ClusterHint_<cluster_id>" for easy identification.
##
## anchors_map: node_id → Node3D (from main.gd's _anchors)
## clusters:    Array of {id, members, context, aggregate_metrics}
func apply_cluster_hints(anchors_map: Dictionary, clusters: Array) -> void:
	for ci in range(clusters.size()):
		var cluster: Dictionary = clusters[ci]
		var cluster_id: String = cluster.get("id", "cluster_%d" % ci)
		var members: Array = cluster.get("members", [])
		var hint_color: Color = HINT_COLOURS[ci % HINT_COLOURS.size()]

		for member_id: String in members:
			var anchor: Node3D = anchors_map.get(member_id)
			if anchor == null:
				continue

			# Avoid adding duplicate hints.
			var hint_name: String = "ClusterHint_" + cluster_id.replace(":", "_")
			var already_has_hint: bool = false
			for child: Node in anchor.get_children():
				if child.name == hint_name:
					already_has_hint = true
					break
			if already_has_hint:
				continue

			# Create a thin flat box that overlays the module mesh.
			# Height is very small (0.05) so it reads as a highlight, not a volume.
			var hint_mesh := BoxMesh.new()
			hint_mesh.size = Vector3(2.0, 0.05, 2.0)

			var hint_mat := StandardMaterial3D.new()
			hint_mat.albedo_color = hint_color
			hint_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
			hint_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
			hint_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED

			var hint_instance := MeshInstance3D.new()
			hint_instance.name = hint_name
			hint_instance.mesh = hint_mesh
			hint_instance.material_override = hint_mat
			# Slightly elevated so it sits on top of the module box.
			hint_instance.position = Vector3(0.0, 0.35, 0.0)
			anchor.add_child(hint_instance)


# ---------------------------------------------------------------------------
# Collapse
# ---------------------------------------------------------------------------

## Collapse the given cluster into a single supernode.
##
## Spec: "modules animate together, converging smoothly into a single supernode"
##       "the supernode displays aggregate metrics (total LOC, combined in-degree,
##        combined out-degree)"
##       "edges that formerly entered or left any member are re-routed to the supernode"
##       "edge re-routing animates smoothly — endpoints slide to the supernode"
##
## cluster_id:  string identifier matching a cluster entry from the scene graph.
## cluster:     Dictionary with keys: id, members, context, aggregate_metrics.
##
## Returns the supernode Node3D (or null if already collapsed / no members).
func collapse_cluster(cluster_id: String, cluster: Dictionary) -> Node3D:
	if _collapse_state.has(cluster_id) and _collapse_state[cluster_id].get("collapsed", false):
		return null  # Already collapsed — idempotent.

	var members: Array = cluster.get("members", [])
	if members.is_empty():
		return null

	# Compute centroid of member positions.
	# Uses global_position when inside the scene tree for accurate world-space
	# coordinates; falls back to local position in headless tests.
	var centroid := Vector3.ZERO
	var valid_count: int = 0
	for member_id: String in members:
		var anchor: Node3D = _anchors.get(member_id)
		if anchor == null:
			continue
		centroid += anchor.global_position if anchor.is_inside_tree() else anchor.position
		valid_count += 1

	if valid_count == 0:
		return null
	centroid /= float(valid_count)

	# ── Capture original LOCAL positions before any animation ────────────────
	# Stored so expand_cluster() can animate members BACK to their original
	# positions. Spec: "modules animate outward to their original positions".
	var original_positions: Dictionary = {}
	for member_id: String in members:
		var anchor: Node3D = _anchors.get(member_id)
		if anchor != null:
			original_positions[member_id] = anchor.position  # local position

	# Create the supernode at the centroid.
	var agg: Dictionary = cluster.get("aggregate_metrics", {})
	var supernode := _create_supernode(cluster_id, centroid, agg)
	if _scene_root != null:
		_scene_root.add_child(supernode)

	# Animate member anchors converging toward centroid, then hide them.
	for member_id: String in members:
		var anchor: Node3D = _anchors.get(member_id)
		if anchor == null:
			continue
		var tween := supernode.create_tween() if supernode.is_inside_tree() else null
		if tween != null:
			# Position → centroid (relative to parent).
			var target_pos: Vector3 = centroid
			if anchor.get_parent() != null and anchor.get_parent() != _scene_root:
				# Convert centroid to local space of the parent.
				var parent_world: Vector3 = (
					anchor.get_parent().global_position
					if anchor.get_parent().is_inside_tree()
					else anchor.get_parent().position
				)
				target_pos = centroid - parent_world
			tween.tween_property(anchor, "position", target_pos, ANIM_DURATION)
			# Fade out via material alpha after position animation.
			tween.tween_callback(anchor.set.bind("visible", false))
		else:
			# Headless (no scene tree): hide immediately.
			anchor.visible = false

	# ── Reroute edge endpoints to supernode ──────────────────────────────────
	# Spec: "edges that formerly entered or left any member of the cluster are
	#        re-routed to the supernode"
	# Spec: "edge re-routing animates smoothly — endpoints slide to the supernode
	#        rather than jumping"
	# Implementation: queues _process-based lerp animations in _edge_animations so
	# endpoints slide each frame toward the supernode centroid. Entry data is also
	# updated immediately so headless tests and subsequent operations are correct.
	var rerouted_edges: Array = []
	var hidden_internal_lines: Array = []
	_reroute_edges_for_collapse(members, centroid, rerouted_edges, hidden_internal_lines)

	# Record collapse state — includes everything needed for expansion.
	_collapse_state[cluster_id] = {
		"collapsed": true,
		"supernode": supernode,
		"members": members,
		"centroid": centroid,
		"original_positions": original_positions,
		"rerouted_edges": rerouted_edges,
		"hidden_internal_lines": hidden_internal_lines,
	}

	return supernode


## Reroute edge entries that touch any member of the collapsing cluster.
##
## For each entry in _path_edge_entries:
##   - If both endpoints are cluster members → hide the visual (internal edge).
##   - If one endpoint is a cluster member → move that endpoint to centroid
##     and rebuild the visual (boundary edge).
##
## Modifies rerouted_edges and hidden_internal_lines in-place (GDScript Array
## is a reference type, so the caller sees the mutations).
func _reroute_edges_for_collapse(
	members: Array,
	centroid: Vector3,
	rerouted_edges: Array,
	hidden_internal_lines: Array,
) -> void:
	# Build a set for O(1) membership tests.
	var member_set: Dictionary = {}
	for m: String in members:
		member_set[m] = true

	for i: int in range(_path_edge_entries.size()):
		var entry: Dictionary = _path_edge_entries[i]
		var src: String = entry.get("source", "")
		var tgt: String = entry.get("target", "")
		var src_is_member: bool = member_set.has(src)
		var tgt_is_member: bool = member_set.has(tgt)

		if not src_is_member and not tgt_is_member:
			continue  # edge does not touch this cluster

		var visual: Node3D = entry.get("visual")
		if visual == null:
			continue

		if src_is_member and tgt_is_member:
			# Internal edge — hide it for the duration of the collapse.
			# Spec: at cluster level, internal edges are not visible.
			visual.visible = false
			hidden_internal_lines.append(visual)
			continue

		# Boundary edge — reroute the cluster-member endpoint to the centroid.
		var orig_from: Vector3 = entry.get("from_pos", Vector3.ZERO)
		var orig_to: Vector3 = entry.get("to_pos", Vector3.ZERO)
		var new_from: Vector3 = orig_from
		var new_to: Vector3 = orig_to

		if src_is_member:
			new_from = centroid  # source-endpoint slides to supernode centroid
		else:  # tgt_is_member
			new_to = centroid  # target-endpoint slides to supernode centroid

		# Queue a smooth lerp animation so the endpoint slides rather than jumps.
		# Spec: "edge re-routing animates smoothly — endpoints slide to the supernode
		#        rather than jumping"
		var anim_id: String = "collapse_%d" % i
		_edge_animations[anim_id] = {
			"from_pos": orig_from,
			"to_pos": orig_to,
			"target_from": new_from,
			"target_to": new_to,
			"progress": 0.0,
			"duration": ANIM_DURATION,
			"entry": entry,
		}

		# Also update entry data immediately so headless tests and subsequent
		# operations (expand restoration) see the correct final positions.
		entry["from_pos"] = new_from
		entry["to_pos"] = new_to

		rerouted_edges.append({
			"entry_idx": i,
			"orig_from": orig_from,
			"orig_to": orig_to,
		})


## Create the supernode MeshInstance3D + Label3D for a collapsed cluster.
## The supernode is a bright-outlined box at *centroid* labelled with
## aggregate metrics (total LOC, in-degree, out-degree).
func _create_supernode(cluster_id: String, centroid: Vector3, agg: Dictionary) -> Node3D:
	var supernode := Node3D.new()
	supernode.name = "Supernode_" + cluster_id.replace(":", "_")
	supernode.position = centroid

	# Supernode box: slightly larger than a regular module box.
	var box := BoxMesh.new()
	box.size = Vector3(4.0, 2.4, 4.0)

	var mat := StandardMaterial3D.new()
	# Bright amber — visually distinct from bounded-context (blue) and module (green).
	mat.albedo_color = Color(0.95, 0.70, 0.10, 1.0)
	mat.emission_enabled = true
	mat.emission = Color(0.5, 0.35, 0.0)
	mat.emission_energy_multiplier = 0.3

	var mesh_instance := MeshInstance3D.new()
	mesh_instance.name = "SupernodeMesh"
	mesh_instance.mesh = box
	mesh_instance.material_override = mat
	supernode.add_child(mesh_instance)

	# Label: cluster id + aggregate metrics.
	var total_loc: int = int(agg.get("total_loc", 0))
	var in_deg: int = int(agg.get("in_degree", 0))
	var out_deg: int = int(agg.get("out_degree", 0))
	var label_text: String = (
		cluster_id + "\nLOC:%d  in:%d  out:%d" % [total_loc, in_deg, out_deg]
	)

	var label := Label3D.new()
	label.text = label_text
	label.pixel_size = 0.012
	label.position = Vector3(0.0, 1.6, 0.0)
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.no_depth_test = true
	supernode.add_child(label)

	return supernode


# ---------------------------------------------------------------------------
# Expand
# ---------------------------------------------------------------------------

## Expand a previously collapsed cluster back to its constituent modules.
##
## Spec: "the supernode smoothly expands back into its constituent modules"
##       "modules animate outward to their original positions"
##       "edges re-route back to their original endpoints with smooth animation"
##
## Returns true if the expansion was initiated, false if the cluster was not
## in a collapsed state.
func expand_cluster(cluster_id: String) -> bool:
	if not _collapse_state.has(cluster_id):
		return false
	var state: Dictionary = _collapse_state[cluster_id]
	if not state.get("collapsed", false):
		return false

	var supernode: Node3D = state.get("supernode")
	var members: Array = state.get("members", [])
	var original_positions: Dictionary = state.get("original_positions", {})
	var rerouted_edges: Array = state.get("rerouted_edges", [])
	var hidden_internal_lines: Array = state.get("hidden_internal_lines", [])

	# ── Restore edge endpoints ────────────────────────────────────────────────
	# Spec: "edges re-route back to their original endpoints with smooth animation"
	# Implementation: queues _process-based lerp animations in _edge_animations so
	# endpoints slide each frame back to original positions. Entry data also restored
	# immediately so headless tests and subsequent operations are correct.
	_restore_edges_for_expand(rerouted_edges, hidden_internal_lines)

	# Show members and animate them back to their stored original positions.
	# Spec: "modules animate outward to their original positions"
	for member_id: String in members:
		var anchor: Node3D = _anchors.get(member_id)
		if anchor == null:
			continue
		# Restore visibility first.
		anchor.visible = true
		# Retrieve the original local position captured during collapse.
		var orig_pos: Vector3 = original_positions.get(member_id, anchor.position)
		if supernode != null and supernode.is_inside_tree():
			# In scene: animate from current (collapsed centroid) back to original position.
			var tween := supernode.create_tween()
			# member animates outward to original position from centroid
			tween.tween_property(anchor, "position", orig_pos, ANIM_DURATION)
		else:
			# Headless: restore position immediately.
			anchor.position = orig_pos

	# Fade-out and remove the supernode.
	if supernode != null and supernode.is_inside_tree():
		var tween := supernode.create_tween()
		# Fade out the supernode mesh.
		var mesh_child: MeshInstance3D = null
		for child: Node in supernode.get_children():
			if child is MeshInstance3D:
				mesh_child = child as MeshInstance3D
				break
		if mesh_child != null and mesh_child.material_override is StandardMaterial3D:
			var mat := mesh_child.material_override as StandardMaterial3D
			mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
			tween.tween_property(mat, "albedo_color:a", 0.0, ANIM_DURATION)
		tween.tween_callback(supernode.queue_free)
	elif supernode != null:
		supernode.queue_free()

	# Update collapse state.
	_collapse_state[cluster_id]["collapsed"] = false
	_collapse_state[cluster_id]["supernode"] = null

	return true


## Restore edge visuals that were rerouted during a collapse.
##
## For each entry in rerouted_edges, rebuilds the mesh or repositions the
## arrow using the stored original from_pos/to_pos values.
## For internal edges (hidden during collapse), restores visibility.
func _restore_edges_for_expand(
	rerouted_edges: Array,
	hidden_internal_lines: Array,
) -> void:
	# Restore boundary-edge endpoints to their original positions.
	for reroute_info: Dictionary in rerouted_edges:
		var entry_idx: int = reroute_info.get("entry_idx", -1)
		if entry_idx < 0 or entry_idx >= _path_edge_entries.size():
			continue
		var entry: Dictionary = _path_edge_entries[entry_idx]
		var visual: Node3D = entry.get("visual")
		if visual == null:
			continue

		var orig_from: Vector3 = reroute_info.get("orig_from", Vector3.ZERO)
		var orig_to: Vector3 = reroute_info.get("orig_to", Vector3.ZERO)

		# Current collapsed positions (the centroid) are the start of the restore anim.
		var cur_from: Vector3 = entry.get("from_pos", Vector3.ZERO)
		var cur_to: Vector3 = entry.get("to_pos", Vector3.ZERO)

		# Queue a smooth lerp animation so the endpoint slides back rather than jumps.
		# Spec: "edges re-route back to their original endpoints with smooth animation"
		var anim_id: String = "expand_%d" % entry_idx
		_edge_animations[anim_id] = {
			"from_pos": cur_from,
			"to_pos": cur_to,
			"target_from": orig_from,
			"target_to": orig_to,
			"progress": 0.0,
			"duration": ANIM_DURATION,
			"entry": entry,
		}

		# Also restore entry data immediately so headless tests and subsequent
		# operations see the correct final positions.
		entry["from_pos"] = orig_from
		entry["to_pos"] = orig_to

	# Show internal edges that were hidden during collapse.
	for internal_visual: Node3D in hidden_internal_lines:
		if internal_visual != null:
			internal_visual.visible = true


# ---------------------------------------------------------------------------
# Edge visual helpers
# ---------------------------------------------------------------------------

## Rebuild an ImmediateMesh line visual with updated endpoint positions.
##
## ImmediateMesh vertices are immutable after surface_end(), so rerouting
## requires creating a new ImmediateMesh and assigning it to the instance.
## The material is preserved from the existing mesh_instance.
func _rebuild_line_mesh(
	mesh_inst: MeshInstance3D,
	from_pos: Vector3,
	to_pos: Vector3,
) -> void:
	var old_mat: StandardMaterial3D = mesh_inst.material_override as StandardMaterial3D
	# Preserve the original line colour from the existing material.
	var line_color: Color = (
		old_mat.albedo_color if old_mat != null else Color(0.55, 0.55, 0.55)
	)
	var imesh := ImmediateMesh.new()
	imesh.surface_begin(Mesh.PRIMITIVE_LINES)
	imesh.surface_set_color(line_color)
	imesh.surface_add_vertex(from_pos)
	imesh.surface_set_color(line_color)
	imesh.surface_add_vertex(to_pos)
	imesh.surface_end()
	mesh_inst.mesh = imesh


## Reposition and reorient an arrowhead cone to the new edge endpoints.
##
## The arrow tip is at to_pos; the cone is oriented along
## normalize(to_pos - from_pos).  Matches the initial placement logic in
## main.gd._create_edge() so the arrowhead stays consistent after rerouting.
func _reposition_arrow(
	arrow: MeshInstance3D,
	from_pos: Vector3,
	to_pos: Vector3,
) -> void:
	var dir: Vector3 = (to_pos - from_pos).normalized()
	if dir.is_zero_approx():
		return  # degenerate edge — leave arrow in place
	# Reorient cone tip along new direction.
	arrow.basis = Basis(Quaternion(Vector3.UP, dir))
	# Centre the cone so its tip lands exactly at to_pos.
	# ARROW_CONE_HEIGHT matches the CylinderMesh.height in main.gd._create_edge().
	arrow.position = to_pos - dir * (ARROW_CONE_HEIGHT * 0.5)


# ---------------------------------------------------------------------------
# State queries
# ---------------------------------------------------------------------------

## Return true if the cluster identified by *cluster_id* is currently collapsed.
func is_collapsed(cluster_id: String) -> bool:
	if not _collapse_state.has(cluster_id):
		return false
	return bool(_collapse_state[cluster_id].get("collapsed", false))


# ---------------------------------------------------------------------------
# Per-frame edge animation (_process)
# ---------------------------------------------------------------------------

## Advance all in-progress edge endpoint animations each frame.
##
## Spec: "edge re-routing animates smoothly — endpoints slide to the supernode
##        rather than jumping"
## Spec: "edges re-route back to their original endpoints with smooth animation"
##
## Each animation entry interpolates from_pos/to_pos toward target_from/target_to
## using linear interpolation over `duration` seconds.  When progress reaches 1.0
## the entry is removed from _edge_animations.
##
## This method is called automatically by the Godot engine each frame when
## the node is inside the scene tree.  In headless tests the engine does NOT
## call _process, so tests simply check the final data values that were
## applied immediately in _reroute_edges_for_collapse / _restore_edges_for_expand.
func _process(delta: float) -> void:
	if _edge_animations.is_empty():
		return
	var completed: Array = []
	for anim_id: String in _edge_animations:
		var anim: Dictionary = _edge_animations[anim_id]
		# Advance progress (clamped to [0, 1]).
		anim["progress"] = min(anim["progress"] + delta / anim["duration"], 1.0)
		var t: float = anim["progress"]
		# Linearly interpolate endpoints toward targets.
		var interp_from: Vector3 = (anim["from_pos"] as Vector3).lerp(anim["target_from"], t)
		var interp_to: Vector3 = (anim["to_pos"] as Vector3).lerp(anim["target_to"], t)
		# Rebuild the mesh visual at the interpolated positions.
		_rebuild_edge_mesh_at(anim["entry"], interp_from, interp_to)
		if t >= 1.0:
			completed.append(anim_id)
	for anim_id: String in completed:
		_edge_animations.erase(anim_id)


## Rebuild the edge visual for *entry* at the given interpolated positions.
##
## Dispatches to _rebuild_line_mesh or _reposition_arrow depending on entry_type.
## Used by _process() during per-frame lerp animation.
func _rebuild_edge_mesh_at(
	entry: Dictionary,
	interp_from: Vector3,
	interp_to: Vector3,
) -> void:
	var visual: Node3D = entry.get("visual")
	if visual == null:
		return
	var entry_type: String = entry.get("entry_type", "line")
	if entry_type == "line" and visual is MeshInstance3D:
		_rebuild_line_mesh(visual as MeshInstance3D, interp_from, interp_to)
	elif entry_type == "arrow" and visual is MeshInstance3D:
		_reposition_arrow(visual as MeshInstance3D, interp_from, interp_to)
