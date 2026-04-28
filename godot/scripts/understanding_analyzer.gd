class_name UnderstandingAnalyzer
extends RefCounted

## Understanding Analyzer — structural analysis for architectural understanding.
##
## Provides three types of analysis to help a human evaluate an agent-built system:
##
##   1. Alignment check  — are spec-defined components present as separate entities?
##      Returns aligned/divergent/missing classifications for each expected component.
##
##   2. Quality analysis — are there coupling or centrality problems?
##      Detects tightly coupled node pairs and high-in-degree (critical) nodes.
##
##   3. Impact analysis  — what happens under a hypothetical change or failure?
##      Computes dependent sets for proposed splits and transitive cascades for failures.
##
## Each analysis function returns a plain Dictionary result.
## The render_*() functions apply visual changes directly to the live 3D scene
## using the anchors dict (node_id → Node3D) and a scene_root node.

## Highlight colour applied to nodes flagged by quality and impact analysis.
const HIGHLIGHT_COLOR: Color = Color(1.0, 0.9, 0.0, 1.0)


# ---------------------------------------------------------------------------
# 1. Alignment check
# ---------------------------------------------------------------------------

## Check whether spec-defined components exist as separate nodes in the actual graph.
##
## Parameters:
##   actual_nodes   — Array of node dicts (each must have an "id" key)
##   spec_node_ids  — Array of String IDs that the spec defines as separate components
##
## Returns:
##   {
##     "aligned":  [...],  # spec IDs present as distinct nodes in the actual graph
##     "divergent": [...], # spec IDs merged into a differently-named node
##     "missing":  [...],  # spec IDs absent from the actual graph entirely
##   }
func check_alignment(actual_nodes: Array, spec_node_ids: Array) -> Dictionary:
	var actual_ids: Dictionary = {}
	for nd in actual_nodes:
		var id: String = nd.get("id", "")
		if not id.is_empty():
			actual_ids[id] = nd

	var aligned: Array = []
	var divergent: Array = []
	var missing: Array = []

	for spec_id in spec_node_ids:
		if actual_ids.has(spec_id):
			aligned.append(spec_id)
		else:
			# Check whether a partial name match suggests merging occurred.
			var found_partial: bool = false
			for actual_id in actual_ids.keys():
				if actual_id.contains(spec_id) or spec_id.contains(actual_id):
					divergent.append(spec_id)
					found_partial = true
					break
			if not found_partial:
				missing.append(spec_id)

	return {"aligned": aligned, "divergent": divergent, "missing": missing}


## Render alignment results directly onto the live 3D scene.
##   aligned nodes  → annotate with "✓ SPEC ALIGNED"
##   divergent nodes → highlight and annotate with "⚠ MERGED"
##
## Parameters:
##   alignment_result — dict returned by check_alignment()
##   anchors          — Dictionary mapping node_id → Node3D
##   scene_root       — Node3D where annotation labels are added as children
func render_alignment(alignment_result: Dictionary, anchors: Dictionary, scene_root: Node3D) -> void:
	for node_id in alignment_result.get("aligned", []):
		var anchor: Node3D = anchors.get(node_id)
		_add_annotation(scene_root, anchor, "✓ SPEC ALIGNED")
	for node_id in alignment_result.get("divergent", []):
		var anchor: Node3D = anchors.get(node_id)
		_highlight_node(anchor)
		_add_annotation(scene_root, anchor, "⚠ MERGED")


# ---------------------------------------------------------------------------
# 2. Quality analysis — coupling
# ---------------------------------------------------------------------------

## Analyze coupling between nodes based on bidirectional edge count.
##
## Parameters:
##   nodes     — Array of node dicts
##   edges     — Array of edge dicts (each has "source" and "target" keys)
##   threshold — int: minimum total edge count between a pair to flag as tightly coupled
##
## Returns:
##   {"pairs": [{"node_a": ..., "node_b": ..., "coupling_score": int}, ...]}
##   sorted by coupling_score descending.
func analyze_coupling(nodes: Array, edges: Array, threshold: int = 2) -> Dictionary:
	var pair_counts: Dictionary = {}
	for ed in edges:
		var src: String = ed.get("source", "")
		var tgt: String = ed.get("target", "")
		if src.is_empty() or tgt.is_empty():
			continue
		# Canonical pair key: alphabetical order so A→B and B→A share one bucket.
		var pair_key: String
		if src < tgt:
			pair_key = src + "|" + tgt
		else:
			pair_key = tgt + "|" + src
		pair_counts[pair_key] = pair_counts.get(pair_key, 0) + 1

	var pairs: Array = []
	for pair_key in pair_counts.keys():
		var count: int = pair_counts[pair_key]
		if count >= threshold:
			var parts: PackedStringArray = pair_key.split("|")
			pairs.append({
				"node_a": parts[0],
				"node_b": parts[1],
				"coupling_score": count,
			})
	pairs.sort_custom(func(a, b): return a["coupling_score"] > b["coupling_score"])
	return {"pairs": pairs}


## Render coupling analysis results directly onto the live 3D scene.
## Both nodes in each tightly coupled pair are highlighted and annotated.
##
## Parameters:
##   coupling_result — dict returned by analyze_coupling()
##   anchors         — Dictionary mapping node_id → Node3D
##   scene_root      — Node3D where annotation labels are added as children
func render_coupling(coupling_result: Dictionary, anchors: Dictionary, scene_root: Node3D) -> void:
	for pair in coupling_result.get("pairs", []):
		var node_a: String = pair.get("node_a", "")
		var node_b: String = pair.get("node_b", "")
		var score: int = pair.get("coupling_score", 0)
		if not node_a.is_empty():
			var anchor_a: Node3D = anchors.get(node_a)
			_highlight_node(anchor_a)
			_add_annotation(scene_root, anchor_a, "⚠ Coupling: %d" % score)
		if not node_b.is_empty():
			var anchor_b: Node3D = anchors.get(node_b)
			_highlight_node(anchor_b)
			_add_annotation(scene_root, anchor_b, "⚠ Coupling: %d" % score)


# ---------------------------------------------------------------------------
# 2. Quality analysis — criticality (single point of failure risk)
# ---------------------------------------------------------------------------

## Analyze criticality (centrality) of nodes based on incoming edge count (in-degree).
##
## Parameters:
##   nodes     — Array of node dicts
##   edges     — Array of edge dicts
##   threshold — int: minimum in-degree to flag a node as critical
##
## Returns:
##   {"critical": [{"node_id": ..., "in_degree": int}, ...]}
##   sorted by in_degree descending.
func analyze_criticality(nodes: Array, edges: Array, threshold: int = 2) -> Dictionary:
	var in_degree: Dictionary = {}
	for nd in nodes:
		var id: String = nd.get("id", "")
		if not id.is_empty():
			in_degree[id] = 0

	for ed in edges:
		var tgt: String = ed.get("target", "")
		if in_degree.has(tgt):
			in_degree[tgt] = in_degree[tgt] + 1

	var critical: Array = []
	for node_id in in_degree.keys():
		if node_id.is_empty():
			continue
		var deg: int = in_degree[node_id]
		if deg >= threshold:
			critical.append({"node_id": node_id, "in_degree": deg})
	critical.sort_custom(func(a, b): return a["in_degree"] > b["in_degree"])
	return {"critical": critical}


## Render criticality analysis results directly onto the live 3D scene.
## High-in-degree nodes are highlighted and annotated with their SPOF risk label.
##
## Parameters:
##   criticality_result — dict returned by analyze_criticality()
##   anchors            — Dictionary mapping node_id → Node3D
##   scene_root         — Node3D where annotation labels are added as children
func render_criticality(criticality_result: Dictionary, anchors: Dictionary, scene_root: Node3D) -> void:
	for item in criticality_result.get("critical", []):
		var node_id: String = item.get("node_id", "")
		var deg: int = item.get("in_degree", 0)
		if not node_id.is_empty():
			var anchor: Node3D = anchors.get(node_id)
			_highlight_node(anchor)
			_add_annotation(scene_root, anchor, "⚠ SPOF Risk (in-degree: %d)" % deg)


# ---------------------------------------------------------------------------
# 3. Impact analysis — split
# ---------------------------------------------------------------------------

## Simulate splitting a node: find all nodes that directly depend on it.
##
## Parameters:
##   nodes   — Array of node dicts
##   edges   — Array of edge dicts
##   node_id — the node being considered for splitting
##
## Returns:
##   {
##     "dependents":     [...],  # nodes with a direct dependency on node_id
##     "new_interfaces": [...],  # descriptions of interfaces callers would need
##   }
func simulate_split(nodes: Array, edges: Array, node_id: String) -> Dictionary:
	var dependents: Array = []
	var seen: Dictionary = {}
	for ed in edges:
		var src: String = ed.get("source", "")
		var tgt: String = ed.get("target", "")
		if tgt == node_id and not seen.has(src):
			dependents.append(src)
			seen[src] = true

	var new_interfaces: Array = []
	for dep in dependents:
		new_interfaces.append(dep + " → (new interface required)")

	return {"dependents": dependents, "new_interfaces": new_interfaces}


## Render split-impact results directly onto the live 3D scene.
## The split node is highlighted as the subject; dependents are highlighted as affected.
##
## Parameters:
##   split_result  — dict returned by simulate_split()
##   split_node_id — the node being considered for splitting
##   anchors       — Dictionary mapping node_id → Node3D
##   scene_root    — Node3D where annotation labels are added as children
func render_split_impact(split_result: Dictionary, split_node_id: String, anchors: Dictionary, scene_root: Node3D) -> void:
	if not split_node_id.is_empty():
		var anchor: Node3D = anchors.get(split_node_id)
		_highlight_node(anchor)
		_add_annotation(scene_root, anchor, "◈ SPLITTING")
	for dep in split_result.get("dependents", []):
		var dep_anchor: Node3D = anchors.get(dep)
		_highlight_node(dep_anchor)
		_add_annotation(scene_root, dep_anchor, "↯ Affected by split")


# ---------------------------------------------------------------------------
# 3. Impact analysis — failure cascade
# ---------------------------------------------------------------------------

## Simulate a component failure: find all nodes that transitively depend on it.
##
## Uses breadth-first traversal through the reverse dependency graph so that
## indirect consumers (e.g. frontend → api → db) are all included.
##
## Parameters:
##   nodes   — Array of node dicts
##   edges   — Array of edge dicts
##   node_id — the component that fails
##
## Returns:
##   {"cascade": [...]}  # all nodes transitively affected by the failure
func simulate_failure(nodes: Array, edges: Array, node_id: String) -> Dictionary:
	# Build reverse adjacency: for each node, which nodes depend on it?
	var dependents_of: Dictionary = {}
	for nd in nodes:
		var id: String = nd.get("id", "")
		if not id.is_empty():
			dependents_of[id] = []

	for ed in edges:
		var src: String = ed.get("source", "")
		var tgt: String = ed.get("target", "")
		if dependents_of.has(tgt):
			var arr: Array = dependents_of[tgt]
			arr.append(src)

	# BFS from the failed node.
	var cascade: Array = []
	var visited: Dictionary = {node_id: true}
	var queue: Array = [node_id]

	while not queue.is_empty():
		var current: String = queue.pop_front()
		for dependent in dependents_of.get(current, []):
			if not visited.has(dependent):
				visited[dependent] = true
				cascade.append(dependent)
				queue.append(dependent)

	return {"cascade": cascade}


## Render failure-cascade results directly onto the live 3D scene.
## The failed node is annotated "✕ FAILED"; all cascade members are highlighted.
##
## Parameters:
##   failure_result — dict returned by simulate_failure()
##   failed_node_id — the component that has failed
##   anchors        — Dictionary mapping node_id → Node3D
##   scene_root     — Node3D where annotation labels are added as children
func render_failure_cascade(failure_result: Dictionary, failed_node_id: String, anchors: Dictionary, scene_root: Node3D) -> void:
	if not failed_node_id.is_empty():
		var anchor: Node3D = anchors.get(failed_node_id)
		_highlight_node(anchor)
		_add_annotation(scene_root, anchor, "✕ FAILED")
	for affected in failure_result.get("cascade", []):
		var aff_anchor: Node3D = anchors.get(affected)
		_highlight_node(aff_anchor)
		_add_annotation(scene_root, aff_anchor, "⚡ Cascading failure")


# ---------------------------------------------------------------------------
# Private rendering helpers
# ---------------------------------------------------------------------------

## Apply highlight color to the MeshInstance3D material of the given anchor.
## No-ops silently when anchor is null or has no MeshInstance3D child.
func _highlight_node(anchor: Node3D) -> void:
	if anchor == null:
		return
	for child in anchor.get_children():
		if child is MeshInstance3D:
			var mesh_child: MeshInstance3D = child as MeshInstance3D
			var mat: StandardMaterial3D = mesh_child.material_override as StandardMaterial3D
			if mat != null:
				mat.albedo_color = HIGHLIGHT_COLOR
			return


## Add a Label3D annotation to scene_root positioned near the given anchor.
## The label has billboard = BILLBOARD_ENABLED and pixel_size > 0.0 for legibility.
## No-ops silently when text is empty.
func _add_annotation(scene_root: Node3D, anchor: Node3D, text: String) -> void:
	if text.is_empty() or scene_root == null:
		return
	var label := Label3D.new()
	label.text = text
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.pixel_size = 0.05
	label.no_depth_test = true
	if anchor != null:
		label.position = anchor.position + Vector3(0.0, 1.5, 0.0)
	scene_root.add_child(label)
