class_name SceneGraphLoader
extends RefCounted

## Parses a raw scene-graph Dictionary (loaded from JSON) into structured arrays.
##
## The JSON produced by the Python extractor has the form:
##   {
##     "nodes": [ {id, name, type, parent, position, size, metrics,
##                 independence_group?}, ... ],
##     "edges": [ {source, target, type, weight?}, ... ],
##     "metadata": {source_path, timestamp},
##     "clusters": [ {id, members, context, aggregate_metrics}, ... ]
##   }
##
## load_from_dict() returns that same structure with all fields preserved so
## the Godot visualiser can consume them without any extra transformation.

static func load_from_dict(data: Dictionary) -> Dictionary:
	return {
		"nodes": _parse_nodes(data.get("nodes", [])),
		"edges": _parse_edges(data.get("edges", [])),
		"metadata": data.get("metadata", {}),
		"clusters": _parse_clusters(data.get("clusters", [])),
	}


static func _parse_nodes(raw_nodes: Array) -> Array:
	var result: Array = []
	for raw in raw_nodes:
		if not raw is Dictionary:
			continue
		var node: Dictionary = {
			"id": raw.get("id", ""),
			"name": raw.get("name", ""),
			"type": raw.get("type", ""),
			"parent": raw.get("parent", null),
			"position": raw.get("position", {"x": 0.0, "y": 0.0, "z": 0.0}),
			"size": raw.get("size", 1.0),
			"metrics": raw.get("metrics", {}),
		}
		# Optional independence_group field (present only for module nodes).
		if raw.has("independence_group"):
			node["independence_group"] = raw["independence_group"]
		result.append(node)
	return result


static func _parse_edges(raw_edges: Array) -> Array:
	var result: Array = []
	for raw in raw_edges:
		if not raw is Dictionary:
			continue
		var edge: Dictionary = {
			"source": raw.get("source", ""),
			"target": raw.get("target", ""),
			"type": raw.get("type", ""),
		}
		# Optional weight field — aggregate edges carry total import count.
		if raw.has("weight"):
			edge["weight"] = raw["weight"]
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
