class_name SceneGraphLoader
extends RefCounted

## Parses a raw scene-graph Dictionary (loaded from JSON) into structured arrays.
##
## The JSON produced by the Python extractor has the form:
##   {
##     "nodes": [ {id, name, type, parent, position, size, metrics,
##                 independence_group?, is_hub, is_bridge, in_degree,
##                 out_degree, ubiquitous, ...}, ... ],
##     "edges": [ {source, target, type, ubiquitous, weight?, ...}, ... ],
##     "metadata": {source_path, timestamp},
##     "clusters": [ {id, members, context, aggregate_metrics}, ... ]
##   }
##
## load_from_dict() returns that same structure with all fields preserved so
## the Godot visualiser can consume them without any extra transformation.
## Structural significance fields (is_hub, is_bridge, in_degree, is_peripheral,
## community_id, community_drift, out_degree) and edge flags (ubiquitous) are
## passed through verbatim from the raw JSON — they must not be stripped.

static func load_from_dict(data: Dictionary) -> Dictionary:
	return {
		"nodes": _parse_nodes(data.get("nodes", [])),
		"edges": _parse_edges(data.get("edges", [])),
		"metadata": data.get("metadata", {}),
		"clusters": _parse_clusters(data.get("clusters", [])),
	}


## Normalise a raw node dict from the JSON.
## Required fields are defaulted if absent; ALL other fields from the raw dict
## are passed through verbatim so structural significance annotations
## (is_hub, is_bridge, in_degree, community_id, independence_group, etc.)
## reach the renderer.
static func _parse_nodes(raw_nodes: Array) -> Array:
	var result: Array = []
	for raw in raw_nodes:
		if not raw is Dictionary:
			continue
		# Start with a copy of the raw dict so every field is preserved.
		var node: Dictionary = raw.duplicate()
		# Normalise required fields to ensure stable types and defaults.
		node["id"] = raw.get("id", "")
		node["name"] = raw.get("name", "")
		node["type"] = raw.get("type", "")
		node["parent"] = raw.get("parent", null)
		node["position"] = raw.get("position", {"x": 0.0, "y": 0.0, "z": 0.0})
		node["size"] = raw.get("size", 1.0)
		node["metrics"] = raw.get("metrics", {})
		result.append(node)
	return result


## Normalise a raw edge dict from the JSON.
## Required fields are defaulted if absent; ALL other fields (including the
## 'ubiquitous' flag set by compute_ubiquitous_flags() and 'weight' on
## aggregate edges) are passed through verbatim so the Power Rail renderer
## can suppress ubiquitous edges and aggregate edges carry import counts.
static func _parse_edges(raw_edges: Array) -> Array:
	var result: Array = []
	for raw in raw_edges:
		if not raw is Dictionary:
			continue
		# Start with a copy of the raw dict so every field is preserved.
		var edge: Dictionary = raw.duplicate()
		# Normalise required fields.
		edge["source"] = raw.get("source", "")
		edge["target"] = raw.get("target", "")
		edge["type"] = raw.get("type", "")
		result.append(edge)
	return result


static func _parse_clusters(raw_clusters: Array) -> Array:
	var result: Array = []
	for raw in raw_clusters:
		if not raw is Dictionary:
			continue
		result.append({
			"id": raw.get("id", ""),
			"members": raw.get("members", []),
			"context": raw.get("context", ""),
			"aggregate_metrics": raw.get("aggregate_metrics", {}),
		})
	return result
