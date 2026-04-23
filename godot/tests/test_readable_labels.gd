## Behavioral tests: Readable Labels at all zoom levels.
##
## Spec: specs/prototype/prototype-scope.spec.md
##
## Requirement: Readable Labels
##   The prototype MUST label all visible structural elements with their names.
##
## Scenario: Identifying a module
##   GIVEN a volume in the scene
##   WHEN the user looks at it
##   THEN the module's name is visible as a text label
##   AND the label remains readable at the current zoom level
##
## Implementation under test: godot/scripts/main.gd → _create_volume()
## Labels must:
##   - Use BILLBOARD_ENABLED so they always face the camera (readable from any angle)
##   - Have pixel_size > 0.0 for legible real-world text size
##   - Have no_depth_test = true so they remain visible through geometry at all depths
##   - Have .text set to the node's "name" field

extends RefCounted

const MainScript := preload("res://scripts/main.gd")

var _runner: Object = null
var _test_failed: bool = false


func _check(condition: bool, msg: String = "") -> void:
	if not condition:
		_test_failed = true
		if _runner != null:
			_runner.record_failure(msg if msg != "" else "Assertion failed")


# ---------------------------------------------------------------------------
# Fixtures
# ---------------------------------------------------------------------------

func _make_fixture_two_nodes() -> Dictionary:
	return {
		"nodes": [
			{
				"id": "iam",
				"name": "IAM",
				"type": "bounded_context",
				"parent": null,
				"position": {"x": 0.0, "y": 0.0, "z": 0.0},
				"size": 8.0,
			},
			{
				"id": "iam.domain",
				"name": "Domain",
				"type": "module",
				"parent": "iam",
				"position": {"x": 1.0, "y": 0.0, "z": 0.0},
				"size": 2.5,
			},
		],
		"edges": [],
	}


func _make_fixture_single_module() -> Dictionary:
	return {
		"nodes": [
			{
				"id": "payments",
				"name": "Payments",
				"type": "bounded_context",
				"parent": null,
				"position": {"x": 5.0, "y": 0.0, "z": 0.0},
				"size": 6.0,
			},
		],
		"edges": [],
	}


func _get_label(anchor: Node3D) -> Label3D:
	for child: Node in anchor.get_children():
		if child is Label3D:
			return child as Label3D
	return null


# ---------------------------------------------------------------------------
# THEN the module's name is visible as a text label:
# Every anchor produced by build_from_graph() must contain a Label3D child.
# ---------------------------------------------------------------------------

func test_bounded_context_anchor_has_label() -> void:
	var main_node: Node3D = MainScript.new()
	main_node.build_from_graph(_make_fixture_two_nodes())

	var anchor: Node3D = main_node._anchors.get("iam")
	_check(anchor != null, "Anchor for 'iam' must exist")
	if anchor == null:
		main_node.free()
		return

	var label: Label3D = _get_label(anchor)
	_check(label != null, "Bounded-context anchor 'iam' must contain a Label3D child")

	main_node.free()


func test_module_anchor_has_label() -> void:
	var main_node: Node3D = MainScript.new()
	main_node.build_from_graph(_make_fixture_two_nodes())

	var anchor: Node3D = main_node._anchors.get("iam.domain")
	_check(anchor != null, "Anchor for 'iam.domain' must exist")
	if anchor == null:
		main_node.free()
		return

	var label: Label3D = _get_label(anchor)
	_check(label != null, "Module anchor 'iam.domain' must contain a Label3D child")

	main_node.free()


# ---------------------------------------------------------------------------
# Label text must match the node name field from the JSON.
# ---------------------------------------------------------------------------

func test_label_text_matches_node_name_bounded_context() -> void:
	var main_node: Node3D = MainScript.new()
	main_node.build_from_graph(_make_fixture_two_nodes())

	var anchor: Node3D = main_node._anchors.get("iam")
	_check(anchor != null, "Anchor 'iam' must exist")
	if anchor == null:
		main_node.free()
		return

	var label: Label3D = _get_label(anchor)
	_check(label != null, "Label3D must exist on 'iam' anchor")
	if label == null:
		main_node.free()
		return

	_check(label.text == "IAM",
		"Label text must equal the node name 'IAM', got '%s'" % label.text)

	main_node.free()


func test_label_text_matches_node_name_module() -> void:
	var main_node: Node3D = MainScript.new()
	main_node.build_from_graph(_make_fixture_two_nodes())

	var anchor: Node3D = main_node._anchors.get("iam.domain")
	_check(anchor != null, "Anchor 'iam.domain' must exist")
	if anchor == null:
		main_node.free()
		return

	var label: Label3D = _get_label(anchor)
	_check(label != null, "Label3D must exist on 'iam.domain' anchor")
	if label == null:
		main_node.free()
		return

	_check(label.text == "Domain",
		"Label text must equal the node name 'Domain', got '%s'" % label.text)

	main_node.free()


# ---------------------------------------------------------------------------
# AND the label remains readable at the current zoom level:
# BILLBOARD_ENABLED makes the label face the camera at every zoom distance.
# ---------------------------------------------------------------------------

func test_label_billboard_enabled_bounded_context() -> void:
	var main_node: Node3D = MainScript.new()
	main_node.build_from_graph(_make_fixture_single_module())

	var anchor: Node3D = main_node._anchors.get("payments")
	_check(anchor != null, "Anchor 'payments' must exist")
	if anchor == null:
		main_node.free()
		return

	var label: Label3D = _get_label(anchor)
	_check(label != null, "Label3D must exist on 'payments' anchor")
	if label == null:
		main_node.free()
		return

	_check(
		label.billboard == BaseMaterial3D.BILLBOARD_ENABLED,
		"Label billboard must be BILLBOARD_ENABLED so it faces the camera at all zoom distances — got %d" % label.billboard
	)

	main_node.free()


func test_label_billboard_enabled_module() -> void:
	var main_node: Node3D = MainScript.new()
	main_node.build_from_graph(_make_fixture_two_nodes())

	var anchor: Node3D = main_node._anchors.get("iam.domain")
	_check(anchor != null, "Anchor 'iam.domain' must exist")
	if anchor == null:
		main_node.free()
		return

	var label: Label3D = _get_label(anchor)
	_check(label != null, "Label3D must exist on 'iam.domain' anchor")
	if label == null:
		main_node.free()
		return

	_check(
		label.billboard == BaseMaterial3D.BILLBOARD_ENABLED,
		"Module label must use BILLBOARD_ENABLED — got %d" % label.billboard
	)

	main_node.free()


# ---------------------------------------------------------------------------
# pixel_size > 0.0 ensures real-world legible text height.
# A Label3D at pixel_size=0.0 (or <= 0.0) is invisible.
# ---------------------------------------------------------------------------

func test_label_pixel_size_positive_bounded_context() -> void:
	var main_node: Node3D = MainScript.new()
	main_node.build_from_graph(_make_fixture_single_module())

	var anchor: Node3D = main_node._anchors.get("payments")
	_check(anchor != null, "Anchor 'payments' must exist")
	if anchor == null:
		main_node.free()
		return

	var label: Label3D = _get_label(anchor)
	_check(label != null, "Label3D must exist on 'payments' anchor")
	if label == null:
		main_node.free()
		return

	_check(
		label.pixel_size > 0.0,
		"Label pixel_size must be > 0.0 for legibility — got %s" % label.pixel_size
	)

	main_node.free()


func test_label_pixel_size_positive_module() -> void:
	var main_node: Node3D = MainScript.new()
	main_node.build_from_graph(_make_fixture_two_nodes())

	var anchor: Node3D = main_node._anchors.get("iam.domain")
	_check(anchor != null, "Anchor 'iam.domain' must exist")
	if anchor == null:
		main_node.free()
		return

	var label: Label3D = _get_label(anchor)
	_check(label != null, "Label3D must exist on 'iam.domain' anchor")
	if label == null:
		main_node.free()
		return

	_check(
		label.pixel_size > 0.0,
		"Module label pixel_size must be > 0.0 — got %s" % label.pixel_size
	)

	main_node.free()


# ---------------------------------------------------------------------------
# no_depth_test = true: labels remain visible through geometry at all zoom
# depths so the user can always read a label even when partially occluded.
# ---------------------------------------------------------------------------

func test_label_no_depth_test_bounded_context() -> void:
	var main_node: Node3D = MainScript.new()
	main_node.build_from_graph(_make_fixture_single_module())

	var anchor: Node3D = main_node._anchors.get("payments")
	_check(anchor != null, "Anchor 'payments' must exist")
	if anchor == null:
		main_node.free()
		return

	var label: Label3D = _get_label(anchor)
	_check(label != null, "Label3D must exist on 'payments' anchor")
	if label == null:
		main_node.free()
		return

	_check(
		label.no_depth_test == true,
		"Label no_depth_test must be true so it is visible through geometry at all zoom levels"
	)

	main_node.free()


func test_label_no_depth_test_module() -> void:
	var main_node: Node3D = MainScript.new()
	main_node.build_from_graph(_make_fixture_two_nodes())

	var anchor: Node3D = main_node._anchors.get("iam.domain")
	_check(anchor != null, "Anchor 'iam.domain' must exist")
	if anchor == null:
		main_node.free()
		return

	var label: Label3D = _get_label(anchor)
	_check(label != null, "Label3D must exist on 'iam.domain' anchor")
	if label == null:
		main_node.free()
		return

	_check(
		label.no_depth_test == true,
		"Module label no_depth_test must be true"
	)

	main_node.free()


# ---------------------------------------------------------------------------
# FileAccess: verify the project uses Godot 4.6 by reading project.godot.
#
# This exercises the FileAccess.open() → get_as_text() code path that
# main.gd uses in _ready(), and also covers the engine-version constraint
# for the prototype (Godot 4.x — specifically 4.6 as declared in project.godot).
# ---------------------------------------------------------------------------

func test_project_godot_declares_version_4_6() -> void:
	var file := FileAccess.open("res://project.godot", FileAccess.READ)
	_check(file != null, "FileAccess.open(project.godot) must succeed")
	if file == null:
		return

	var content: String = file.get_as_text()
	file.close()

	_check(content.length() > 0, "project.godot must not be empty")
	_check(
		content.contains("4.6"),
		"project.godot must declare Godot 4.6 (config/features or similar) — content excerpt: '%s'" % content.left(200)
	)
