class_name ViewSpecRenderer
extends RefCounted

## Interprets a ViewSpec into a 3D spatial scene.
##
## apply() is the sole entry point.  It takes:
##   graph — output of SceneGraphLoader.load_from_dict()  (all known nodes/edges)
##   spec  — output of ViewSpec.from_dict()               (what to show and how)
##   root  — Node3D that will receive all generated child nodes
##
## Primitives handled (in the order they are applied):
##   show      → only the listed ids are rendered (when present; otherwise all non-hidden)
##   hide      → listed ids are omitted from the scene tree
##   highlight → a StandardMaterial3D with the given albedo_color is set on the mesh
##   arrange   → overrides the node's JSON position with the spec-provided coordinates
##   annotate  → adds a Label3D child named "annotation" with the given text
##   connect   → adds a Node3D child of root named "conn_{src}_{tgt}" at the midpoint
##
## No new rendering logic is generated at runtime — the primitive set is fixed
## in ViewSpec.VALID_OPS.


static func apply(graph: Dictionary, spec: Dictionary, root: Node3D) -> void:
	var ops: Array = spec.get("operations", [])

	# Index all known nodes by id for O(1) lookup.
	var node_by_id: Dictionary = {}
	for nd in graph.get("nodes", []):
		node_by_id[nd["id"]] = nd

	# Pre-compute per-primitive lookup structures.
	var hidden_ids: Array      = _collect_ids_for_op(ops, "hide")
	var show_ids: Array        = _collect_ids_for_op(ops, "show")
	var highlight_map: Dictionary = _collect_highlight_map(ops)
	var arrange_map: Dictionary   = _collect_arrange_map(ops)
	var annotate_map: Dictionary  = _collect_annotate_map(ops)

	# Determine which node ids to render.
	# Rule: if any "show" ops exist, render only those ids (minus hidden).
	#       If no "show" ops, render everything from the graph (minus hidden).
	var render_ids: Array = []
	if show_ids.is_empty():
		for id in node_by_id.keys():
			if not hidden_ids.has(id):
				render_ids.append(id)
	else:
		for id in show_ids:
			if not hidden_ids.has(id) and node_by_id.has(id):
				render_ids.append(id)

	# Spawn one MeshInstance3D per rendered node.
	var spawned: Dictionary = {}  # id -> MeshInstance3D
	for id in render_ids:
		var nd: Dictionary = node_by_id[id]
		var mesh := MeshInstance3D.new()
		mesh.name = id

		# arrange overrides the JSON position; otherwise use the JSON value.
		var pos: Dictionary
		if arrange_map.has(id):
			pos = arrange_map[id]
		else:
			pos = nd.get("position", {"x": 0.0, "y": 0.0, "z": 0.0})
		mesh.position = Vector3(
			float(pos.get("x", 0.0)),
			float(pos.get("y", 0.0)),
			float(pos.get("z", 0.0))
		)

		# highlight sets a StandardMaterial3D with the specified albedo_color.
		if highlight_map.has(id):
			var col: Array = highlight_map[id]
			var mat := StandardMaterial3D.new()
			mat.albedo_color = Color(
				float(col[0]) if col.size() > 0 else 1.0,
				float(col[1]) if col.size() > 1 else 1.0,
				float(col[2]) if col.size() > 2 else 1.0
			)
			mesh.material_override = mat

		root.add_child(mesh)
		spawned[id] = mesh

		# annotate adds a Label3D child named "annotation".
		if annotate_map.has(id):
			var label := Label3D.new()
			label.name = "annotation"
			label.text = annotate_map[id]
			label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
			label.pixel_size = 0.05
			mesh.add_child(label)

	# connect adds a Node3D at the midpoint between the two named nodes.
	for op in ops:
		if op.get("op", "") != "connect":
			continue
		var src_id: String = op.get("source", "")
		var tgt_id: String = op.get("target", "")
		if not spawned.has(src_id) or not spawned.has(tgt_id):
			continue
		var src_pos: Vector3 = spawned[src_id].position
		var tgt_pos: Vector3 = spawned[tgt_id].position
		var connector := Node3D.new()
		connector.name = "conn_%s_%s" % [src_id, tgt_id]
		connector.position = (src_pos + tgt_pos) * 0.5
		root.add_child(connector)


# ---------------------------------------------------------------------------
# Private helpers
# ---------------------------------------------------------------------------

## Collect all ids listed by any op whose "op" key matches op_name.
static func _collect_ids_for_op(ops: Array, op_name: String) -> Array:
	var result: Array = []
	for op in ops:
		if op.get("op", "") == op_name:
			for id in op.get("ids", []):
				if not result.has(id):
					result.append(id)
	return result


## Build a map from node id → colour array [r, g, b] from "highlight" ops.
static func _collect_highlight_map(ops: Array) -> Dictionary:
	var result: Dictionary = {}
	for op in ops:
		if op.get("op", "") == "highlight":
			var color: Array = op.get("color", [1.0, 1.0, 0.0])
			for id in op.get("ids", []):
				result[id] = color
	return result


## Build a map from node id → position dict {"x","y","z"} from "arrange" ops.
static func _collect_arrange_map(ops: Array) -> Dictionary:
	var result: Dictionary = {}
	for op in ops:
		if op.get("op", "") == "arrange":
			var id: String = op.get("id", "")
			if id != "":
				result[id] = op.get("position", {"x": 0.0, "y": 0.0, "z": 0.0})
	return result


## Build a map from node id → annotation text from "annotate" ops.
static func _collect_annotate_map(ops: Array) -> Dictionary:
	var result: Dictionary = {}
	for op in ops:
		if op.get("op", "") == "annotate":
			var id: String = op.get("id", "")
			if id != "":
				result[id] = op.get("text", "")
	return result
