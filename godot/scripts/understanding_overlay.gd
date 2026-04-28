class_name UnderstandingOverlay
extends RefCounted

## Understanding Overlay — visual overlays for the three modes of architectural
## understanding described in specs/core/understanding-modes.spec.md.
##
## Three overlay functions correspond to the three understanding requirements:
##
##   apply_alignment_overlay()
##     Colours each node by its spec alignment status so the human can see
##     whether the as-built system matches the as-specced design.
##       spec_status "aligned"   → ALIGNED_COLOR   (green)
##       spec_status "divergent" → DIVERGENT_COLOR  (red) + divergence label
##       absent / other          → UNSPECIFIED_COLOR (grey)
##
##   apply_quality_overlay()
##     Colours nodes by architectural quality metrics so the human can
##     evaluate the realized system independently of the spec.
##       in_degree >= 3  → CRITICAL_COLOR  (red)    — single-point-of-failure risk
##       in_degree == 2  → COUPLED_COLOR   (orange)  — high coupling
##       mutual edge A↔B → COUPLED_COLOR on both    — tight interdependence
##
##   apply_split_overlay()
##     Shows the impact of splitting a target service: colours direct
##     dependents AFFECTED_COLOR and annotates each with "requires new interface".
##
##   apply_failure_overlay()
##     BFS-cascades from a failed target node, colouring and annotating
##     every transitively affected node AFFECTED_COLOR.

## ── Alignment overlay colours (Conformance Mode) ──────────────────────────
const ALIGNED_COLOR: Color = Color(0.2, 0.8, 0.3, 1.0)      # green  — matches spec
const DIVERGENT_COLOR: Color = Color(0.9, 0.2, 0.1, 1.0)    # red    — diverges from spec
const UNSPECIFIED_COLOR: Color = Color(0.6, 0.6, 0.6, 1.0)  # grey   — absent from spec

## ── Quality overlay colours (Evaluation Mode) ─────────────────────────────
const CRITICAL_COLOR: Color = Color(0.95, 0.15, 0.05, 1.0)  # deep red — SPOF risk
const COUPLED_COLOR: Color = Color(0.95, 0.55, 0.05, 1.0)   # orange   — tight coupling

## ── Impact overlay colour (Simulation Mode) ───────────────────────────────
const AFFECTED_COLOR: Color = Color(0.85, 0.1, 0.55, 1.0)   # magenta  — affected by change


# ---------------------------------------------------------------------------
# Alignment overlay — Conformance Mode
# ---------------------------------------------------------------------------

## Apply alignment overlay: colour each node by its spec alignment status.
##
## Reads the "spec_status" field from each entry in nodes_data:
##   "aligned"   → ALIGNED_COLOR        — node matches spec; component is separate and correct
##   "divergent" → DIVERGENT_COLOR + label — node diverges; label shows the specific nature
##   other/absent → UNSPECIFIED_COLOR   — not mentioned in the spec
##
## The resulting scene makes both spec correspondence and spec divergence
## visually apparent without any additional UI:
##   - separate aligned components appear as distinct green volumes
##   - divergent components are highlighted red with an explanatory annotation
func apply_alignment_overlay(nodes_data: Array, anchors: Dictionary) -> void:
	for nd in nodes_data:
		var node_id: String = nd.get("id", "")
		var anchor: Node3D = anchors.get(node_id) as Node3D
		if anchor == null:
			continue

		var status: String = nd.get("spec_status", "")
		var color: Color
		match status:
			"aligned":
				color = ALIGNED_COLOR
			"divergent":
				color = DIVERGENT_COLOR
				# Show the specific nature of the divergence (e.g. "merged with order service").
				var detail: String = nd.get("spec_divergence", "")
				if not detail.is_empty():
					_add_overlay_label(anchor, detail)
			_:
				color = UNSPECIFIED_COLOR

		_apply_node_color(anchor, color)


# ---------------------------------------------------------------------------
# Quality overlay — Evaluation Mode
# ---------------------------------------------------------------------------

## Apply quality overlay: colour nodes by architectural quality metrics.
##
## For each node, computes:
##   in_degree  — number of incoming edges (other services that depend on it)
##   mutual     — whether this node and another share edges in both directions
##
## Colour scheme:
##   in_degree >= 3        → CRITICAL_COLOR  (single-point-of-failure risk is clear)
##   in_degree == 2        → COUPLED_COLOR   (high coupling is apparent)
##   mutual edge pair A↔B  → COUPLED_COLOR   (tight interdependence is apparent)
##
## This overlay works independently of alignment status: a node that is
## spec-aligned can still receive CRITICAL_COLOR if it has high centrality,
## making architectural problems visible even when conformance is perfect.
func apply_quality_overlay(nodes_data: Array, edges_data: Array, anchors: Dictionary) -> void:
	# Compute in-degree per node.
	var in_degree: Dictionary = {}
	for ed in edges_data:
		var tgt: String = ed.get("target", "")
		if not tgt.is_empty():
			in_degree[tgt] = in_degree.get(tgt, 0) + 1

	# Build a quick-lookup set of all edges to detect mutual coupling.
	var edge_set: Dictionary = {}
	for ed in edges_data:
		var src: String = ed.get("source", "")
		var tgt: String = ed.get("target", "")
		if not src.is_empty() and not tgt.is_empty():
			edge_set[src + ">" + tgt] = true

	# Mark all nodes that participate in a mutual (bidirectional) edge pair.
	var mutually_coupled: Dictionary = {}
	for ed in edges_data:
		var src: String = ed.get("source", "")
		var tgt: String = ed.get("target", "")
		if edge_set.has(tgt + ">" + src):
			mutually_coupled[src] = true
			mutually_coupled[tgt] = true

	# Apply colours based on quality metrics.
	for nd in nodes_data:
		var node_id: String = nd.get("id", "")
		var anchor: Node3D = anchors.get(node_id) as Node3D
		if anchor == null:
			continue
		var degree: int = in_degree.get(node_id, 0)
		if degree >= 3:
			# Single-point-of-failure: risk is clear via CRITICAL_COLOR.
			_apply_node_color(anchor, CRITICAL_COLOR)
		elif degree >= 2 or mutually_coupled.has(node_id):
			# High coupling: problematic coupling is apparent via COUPLED_COLOR.
			_apply_node_color(anchor, COUPLED_COLOR)


# ---------------------------------------------------------------------------
# Impact overlay — Simulation Mode (splitting a service)
# ---------------------------------------------------------------------------

## Apply split impact overlay: show the consequences of splitting target_id.
##
## Finds every service that has an outgoing edge TO target_id — these are the
## services that currently depend on the monolith and will be impacted by a split.
## Each such dependent is:
##   - coloured AFFECTED_COLOR (impact on dependent services is visible)
##   - annotated "requires new interface" (new dependencies that would be required
##     are shown — after the split the dependent must bind to one of the two parts)
func apply_split_overlay(
		target_id: String,
		graph: Dictionary,
		anchors: Dictionary,
		scene_root: Node3D) -> void:
	var edges: Array = graph.get("edges", [])
	var dependents: Array = []
	for ed in edges:
		# A service whose edge points TO target is a dependent.
		if ed.get("target", "") == target_id:
			var src: String = ed.get("source", "")
			if not src.is_empty() and src not in dependents:
				dependents.append(src)

	for node_id in dependents:
		var anchor: Node3D = anchors.get(node_id) as Node3D
		if anchor == null:
			continue
		_apply_node_color(anchor, AFFECTED_COLOR)
		_add_scene_label(anchor, "requires new interface", scene_root)


# ---------------------------------------------------------------------------
# Impact overlay — Simulation Mode (failure injection)
# ---------------------------------------------------------------------------

## Apply failure impact overlay: show the cascade from a failed component.
##
## BFS from target_id through the dependency graph to find every service
## that is directly or transitively affected by the failure.  Each affected
## node is:
##   - coloured AFFECTED_COLOR (cascade of effects is visible)
##   - annotated "AFFECTED"    (affected components are clearly identified)
##
## Only nodes that depend on target_id (directly or via a chain) are coloured;
## the failed node itself is not re-coloured so the origin is distinguishable.
func apply_failure_overlay(
		target_id: String,
		graph: Dictionary,
		anchors: Dictionary,
		scene_root: Node3D) -> void:
	var edges: Array = graph.get("edges", [])

	# Build reverse-adjacency: for each node, the set of services that depend on it.
	# When node X fails, the services in dependents_of[X] are immediately affected.
	var dependents_of: Dictionary = {}
	for ed in edges:
		var src: String = ed.get("source", "")
		var tgt: String = ed.get("target", "")
		# src depends on tgt: failure of tgt directly impacts src.
		if not tgt.is_empty() and not src.is_empty():
			if not dependents_of.has(tgt):
				dependents_of[tgt] = []
			dependents_of[tgt].append(src)

	# BFS to find all transitively affected nodes.
	var visited: Dictionary = {}
	var queue: Array = [target_id]
	visited[target_id] = true
	while not queue.is_empty():
		var current: String = queue.pop_front()
		var affected: Array = dependents_of.get(current, [])
		for dep: String in affected:
			if not visited.has(dep):
				visited[dep] = true
				queue.append(dep)

	# Colour and annotate all affected nodes except the origin itself.
	for node_id: String in visited.keys():
		if node_id == target_id:
			continue
		var anchor: Node3D = anchors.get(node_id) as Node3D
		if anchor == null:
			continue
		_apply_node_color(anchor, AFFECTED_COLOR)
		_add_scene_label(anchor, "AFFECTED", scene_root)


# ---------------------------------------------------------------------------
# Shared helpers
# ---------------------------------------------------------------------------

## Colour the first MeshInstance3D child of an anchor.
func _apply_node_color(anchor: Node3D, color: Color) -> void:
	for child in anchor.get_children():
		if child is MeshInstance3D:
			var mat := StandardMaterial3D.new()
			mat.albedo_color = color
			(child as MeshInstance3D).material_override = mat
			break


## Add a Label3D as a direct child of an anchor (used for alignment divergence).
## Mandatory settings: billboard=ENABLED, pixel_size>0 for legibility in 3D.
func _add_overlay_label(anchor: Node3D, text: String) -> void:
	var label := Label3D.new()
	label.text = text
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.pixel_size = 0.05
	label.no_depth_test = true
	label.position = Vector3(0.0, 2.0, 0.0)
	anchor.add_child(label)


## Add a Label3D to the scene root, positioned above the anchor in world space
## (used for impact overlays where labels belong to the scene rather than the node).
## Mandatory settings: billboard=ENABLED, pixel_size>0 for legibility in 3D.
func _add_scene_label(anchor: Node3D, text: String, scene_root: Node3D) -> void:
	var label := Label3D.new()
	label.text = text
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.pixel_size = 0.05
	label.no_depth_test = true
	label.position = anchor.position + Vector3(0.0, 2.0, 0.0)
	scene_root.add_child(label)
