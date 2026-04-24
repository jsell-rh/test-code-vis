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
## The build_*_spec() functions convert results into view-spec dicts that
## SceneInterpreter.apply_spec() can apply directly to the live 3D scene.


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


## Build a view-spec dict from an alignment result.
##   aligned nodes  → annotate with "✓ SPEC ALIGNED"
##   divergent nodes → highlight and annotate with "⚠ MERGED"
func build_alignment_spec(alignment_result: Dictionary) -> Dictionary:
	var ops: Array = []
	for node_id in alignment_result.get("aligned", []):
		ops.append({"op": "annotate", "target": node_id, "text": "✓ SPEC ALIGNED"})
	for node_id in alignment_result.get("divergent", []):
		ops.append({"op": "highlight", "target": node_id})
		ops.append({"op": "annotate", "target": node_id, "text": "⚠ MERGED"})
	return {"operations": ops}


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


## Build a view-spec from coupling analysis.
## Both nodes in each tightly coupled pair are highlighted and annotated.
func build_coupling_spec(coupling_result: Dictionary) -> Dictionary:
	var ops: Array = []
	for pair in coupling_result.get("pairs", []):
		var node_a: String = pair.get("node_a", "")
		var node_b: String = pair.get("node_b", "")
		var score: int = pair.get("coupling_score", 0)
		if not node_a.is_empty():
			ops.append({"op": "highlight", "target": node_a})
			ops.append({"op": "annotate", "target": node_a, "text": "⚠ Coupling: %d" % score})
		if not node_b.is_empty():
			ops.append({"op": "highlight", "target": node_b})
			ops.append({"op": "annotate", "target": node_b, "text": "⚠ Coupling: %d" % score})
	return {"operations": ops}


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


## Build a view-spec from criticality analysis.
## High-in-degree nodes are highlighted and annotated with their SPOF risk label.
func build_criticality_spec(criticality_result: Dictionary) -> Dictionary:
	var ops: Array = []
	for item in criticality_result.get("critical", []):
		var node_id: String = item.get("node_id", "")
		var deg: int = item.get("in_degree", 0)
		if not node_id.is_empty():
			ops.append({"op": "highlight", "target": node_id})
			ops.append({"op": "annotate", "target": node_id,
				"text": "⚠ SPOF Risk (in-degree: %d)" % deg})
	return {"operations": ops}


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


## Build a view-spec from a split-impact result.
## The split node is highlighted as the subject; dependents are highlighted as affected.
func build_split_spec(split_result: Dictionary, split_node_id: String) -> Dictionary:
	var ops: Array = []
	if not split_node_id.is_empty():
		ops.append({"op": "highlight", "target": split_node_id})
		ops.append({"op": "annotate", "target": split_node_id, "text": "◈ SPLITTING"})
	for dep in split_result.get("dependents", []):
		ops.append({"op": "highlight", "target": dep})
		ops.append({"op": "annotate", "target": dep, "text": "↯ Affected by split"})
	return {"operations": ops}


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


## Build a view-spec from a failure-cascade result.
## The failed node is annotated "✕ FAILED"; all cascade members are highlighted.
func build_failure_spec(failure_result: Dictionary, failed_node_id: String) -> Dictionary:
	var ops: Array = []
	if not failed_node_id.is_empty():
		ops.append({"op": "highlight", "target": failed_node_id})
		ops.append({"op": "annotate", "target": failed_node_id, "text": "✕ FAILED"})
	for affected in failure_result.get("cascade", []):
		ops.append({"op": "highlight", "target": affected})
		ops.append({"op": "annotate", "target": affected, "text": "⚡ Cascading failure"})
	return {"operations": ops}
