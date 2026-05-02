extends RefCounted

## Node Primitive renderer for code-vis.
##
## Implements the Node primitive from visual-primitives.spec.md:
##   "an entity with identity, carrying zero or more Badges. Nodes do not have
##    baked-in types — their visual identity comes entirely from their Badges."
##
## Handles rendering of function, method, and class type nodes.
## All three types use IDENTICAL BoxMesh geometry — only Badges differentiate
## them visually.  Spec: "no special shape distinguishes [a function node] from
## a class node — only the Badges differ."
##
## Usage: call populate_anchor(anchor, node_data, sz) after the anchor Node3D
## has been created and positioned by main.gd.  This function attaches the mesh
## and label sub-nodes to the anchor.  Badge rendering is delegated to the
## VisualPrimitives module via main.gd's _visual_primitives instance.


## Node types this renderer handles.
const HANDLED_TYPES: PackedStringArray = ["function", "method", "class"]

## Height ratio for BoxMesh relative to the node's size field.
## Compact ratio keeps function/class nodes visually subordinate to module slabs.
const HEIGHT_RATIO: float = 0.5

## Colour for all node primitive types (function, method, class).
## One colour for all three — type distinction comes from Badges, not colour.
## Spec: "Nodes do not have baked-in types — their visual identity comes
##        entirely from their Badges."
const NODE_COLOR: Color = Color(0.60, 0.75, 0.95, 1.0)  # soft blue: code entity


## Return true if this renderer should handle the given node_type string.
## Used by main.gd to route function/method/class nodes to this renderer.
static func handles(node_type: String) -> bool:
	return node_type in HANDLED_TYPES


## Populate *anchor* with the BoxMesh and Label3D for a Node Primitive.
##
## The anchor Node3D has already been positioned and added to the scene tree
## by main.gd._create_volume().  This function attaches its visual children:
##   - MeshInstance3D with BoxMesh (same geometry for ALL handled types)
##   - Label3D with the node's human-readable name
##
## Spec §Scenario: Function node —
##   "The Node exists with its name"
##   "no special shape distinguishes it from a class node — only the Badges differ"
##
## Note: Badge glyphs are applied by VisualPrimitives.attach_primitives(), which
## main.gd calls AFTER populate_anchor().  Badge placement is therefore separate
## and independent of the mesh/label created here.
##
## Parameters:
##   anchor:    The Node3D to attach mesh and label to.
##   node_data: The raw node dict from the scene graph (must include "name" and "size").
##   sz:        The node's 'size' field as a float (pre-converted by caller).
func populate_anchor(anchor: Node3D, node_data: Dictionary, sz: float) -> void:
	# ── Mesh ──────────────────────────────────────────────────────────────────
	# Identical BoxMesh for function, method, AND class nodes.
	# Spec: "no special shape distinguishes it from a class node"
	var box := BoxMesh.new()
	box.size = Vector3(sz, sz * HEIGHT_RATIO, sz)

	var mat := StandardMaterial3D.new()
	mat.albedo_color = NODE_COLOR

	var mesh_instance := MeshInstance3D.new()
	mesh_instance.mesh = box
	mesh_instance.material_override = mat
	anchor.add_child(mesh_instance)

	# ── Label ─────────────────────────────────────────────────────────────────
	# Always present — carries the node's human-readable identifier.
	# Spec: "The Node exists with its name"
	var label := Label3D.new()
	label.text = node_data["name"]
	# pixel_size > 0.0 is mandatory for Label3D readability in headless tests.
	label.pixel_size = 0.012
	label.position = Vector3(0.0, sz * 0.15 + 0.4, 0.0)
	# Billboard so label faces the camera from any angle.
	# Spec (guideline): "Label3D readability: billboard = BILLBOARD_ENABLED"
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	# Render on top of geometry so labels remain visible through solid meshes.
	label.no_depth_test = true
	anchor.add_child(label)
