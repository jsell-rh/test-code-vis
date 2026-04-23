extends Node3D

const SceneGraphLoader = preload("res://scripts/scene_graph_loader.gd")

var _graph_path: String = "res://data/scene_graph.json"


func _ready() -> void:
	if FileAccess.file_exists(_graph_path):
		var file: FileAccess = FileAccess.open(_graph_path, FileAccess.READ)
		if file == null:
			push_error("Cannot open scene graph: " + _graph_path)
			return
		var json_text: String = file.read_as_text()
		file.close()
		var json: JSON = JSON.new()
		if json.parse(json_text) != OK:
			push_error("JSON parse error: " + json.get_error_message())
			return
		var graph: Dictionary = SceneGraphLoader.load_from_dict(json.data)
		build_from_graph(graph)


## Create one MeshInstance3D per node and position it using the pre-computed
## coordinates from the JSON.  No layout is computed here; the extractor owns
## that responsibility.
func build_from_graph(graph: Dictionary) -> void:
	for node_data in graph.get("nodes", []):
		_spawn_node(node_data)


func _spawn_node(node_data: Dictionary) -> void:
	var mesh_instance: MeshInstance3D = MeshInstance3D.new()
	mesh_instance.name = node_data.get("id", "unknown")
	var pos: Dictionary = node_data.get("position", {"x": 0.0, "y": 0.0, "z": 0.0})
	mesh_instance.position = Vector3(
		float(pos.get("x", 0.0)),
		float(pos.get("y", 0.0)),
		float(pos.get("z", 0.0))
	)
	add_child(mesh_instance)


func _process(_delta: float) -> void:
	pass
