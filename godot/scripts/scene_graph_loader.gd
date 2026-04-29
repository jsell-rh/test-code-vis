class_name SceneGraphLoader
extends RefCounted

## Parses a raw scene-graph Dictionary (loaded from JSON) into structured arrays.
##
## The JSON produced by the Python extractor has the form:
##   {
##     "nodes": [ {id, name, type, parent, position, size, metrics}, ... ],
##     "edges": [ {source, target, type}, ... ],
##     "metadata": {source_path, timestamp},
##     "flow_paths": [ {id, name, steps}, ... ]   # optional
##   }
##
## load_from_dict() returns that same structure with all fields preserved so
## the Godot visualiser can consume them without any extra transformation.
## The flow_paths field is optional — absent or empty means no flow overlays.

static func load_from_dict(data: Dictionary) -> Dictionary:
	return {
		"nodes": _parse_nodes(data.get("nodes", [])),
		"edges": _parse_edges(data.get("edges", [])),
		"metadata": data.get("metadata", {}),
		"flow_paths": _parse_flow_paths(data.get("flow_paths", [])),
	}


static func _parse_nodes(raw_nodes: Array) -> Array:
	var result: Array = []
	for raw in raw_nodes:
		if not raw is Dictionary:
			continue
		result.append({
			"id": raw.get("id", ""),
			"name": raw.get("name", ""),
			"type": raw.get("type", ""),
			"parent": raw.get("parent", null),
			"position": raw.get("position", {"x": 0.0, "y": 0.0, "z": 0.0}),
			"size": raw.get("size", 1.0),
			"metrics": raw.get("metrics", {}),
		})
	return result


static func _parse_edges(raw_edges: Array) -> Array:
	var result: Array = []
	for raw in raw_edges:
		if not raw is Dictionary:
			continue
		result.append({
			"source": raw.get("source", ""),
			"target": raw.get("target", ""),
			"type": raw.get("type", ""),
		})
	return result


static func _parse_flow_paths(raw_paths: Array) -> Array:
	var result: Array = []
	for raw in raw_paths:
		if not raw is Dictionary:
			continue
		result.append({
			"id": raw.get("id", ""),
			"name": raw.get("name", ""),
			"steps": raw.get("steps", []),
		})
	return result
