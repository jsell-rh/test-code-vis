extends RefCounted

## TintController — Tint Primitive renderer for code-vis.
##
## Implements the Tint Primitive from specs/core/visual-primitives.spec.md:
##   §Requirement: Tint Primitive
##
## A Tint is a background color on a Container encoding one categorical
## dimension.  The spec requires:
##   - Each bounded context gets a distinct desaturated fill color.
##   - The palette is limited to 4–6 categorical colors (preattentive limit).
##   - Only ONE categorical dimension is encoded via Tint at a time.
##   - Reassigning Tints REPLACES the prior assignment — never layers.
##   - When Tint is active a legend must be visible showing what it encodes.
##
## Usage:
##   var tc := TintController.new()
##   tc.apply_domain_tints(nodes_array, anchors_dict)
##   var legend := tc.get_legend_entries()  # → Array of {label, color}
##   tc.clear_tints(anchors_dict)

# ---------------------------------------------------------------------------
# Palette — 4–6 desaturated categorical colors
# ---------------------------------------------------------------------------

## Categorical palette: 6 desaturated (low-saturation) fill colors.
## Desaturation keeps them legible alongside structural geometry.
## Limited to 6 entries — spec §Scenario: Domain tinting:
##   "the palette is limited to 4-6 categorical colors (preattentive
##    discrimination limit)"
## Colors cycle if there are more contexts than palette entries.
const TINT_PALETTE: Array = [
	Color(0.70, 0.30, 0.30, 0.22),  # muted rose   — e.g. auth
	Color(0.30, 0.55, 0.70, 0.22),  # muted teal   — e.g. billing
	Color(0.50, 0.70, 0.30, 0.22),  # muted sage   — e.g. shipping
	Color(0.70, 0.60, 0.25, 0.22),  # muted amber  — e.g. infra
	Color(0.55, 0.30, 0.70, 0.22),  # muted violet — e.g. core
	Color(0.70, 0.50, 0.30, 0.22),  # muted sienna — e.g. api
]

## Name of the child node that holds the tint overlay geometry.
## Consistent name is used to detect and remove prior overlays (no-double-tint).
const TINT_NODE_NAME: String = "DomainTintOverlay"

# ---------------------------------------------------------------------------
# Internal state
# ---------------------------------------------------------------------------

## Maps context_id → Color assigned during the most recent apply_domain_tints().
## Used to build legend entries and detect existing assignments.
var _assignments: Dictionary = {}

## Human-readable label for the currently active tint dimension.
## Defaults to "Domain" for the base domain-tinting use case.
var _active_dimension: String = ""


# ---------------------------------------------------------------------------
# Public API
# ---------------------------------------------------------------------------

## Apply categorical tints to bounded_context nodes in *nodes_array*.
##
## This is the primary entry point for the Tint primitive.
##
## Algorithm:
##   1. Clear any prior tint overlays (replace, never layer).
##   2. Assign palette colors to bounded_context nodes in order of encounter.
##   3. Create a semi-transparent thin slab (MeshInstance3D) on each context
##      anchor that acts as a colored floor plane — visually below and slightly
##      wider than the context box so the hue is readable without obscuring
##      the geometry above.
##
## Spec §Scenario: Domain tinting:
##   "each context has a distinct desaturated fill color"
##   "the palette is limited to 4–6 categorical colors"
## Spec §Scenario: One tint dimension per view:
##   "the previous Tint assignment is replaced, not layered"
##   "only ONE categorical dimension is encoded via Tint at a time"
##
## Parameters:
##   nodes_array: Array — raw node dicts from the scene graph.
##   anchors:     Dictionary — node_id → Node3D anchor (from Main._anchors).
##   dimension:   String — human-readable label for what this tint encodes.
##                         Shown in the legend.  Default: "Domain".
func apply_domain_tints(
	nodes_array: Array,
	anchors: Dictionary,
	dimension: String = "Domain"
) -> void:
	# Step 1: Replace — clear prior tints so we never layer.
	# Spec §One tint dimension: "previous Tint assignment is replaced, not layered"
	clear_tints(anchors)
	_assignments.clear()
	_active_dimension = dimension

	# Step 2: Assign palette colors to bounded_context nodes.
	var palette_index: int = 0
	for nd: Dictionary in nodes_array:
		if nd.get("type", "") != "bounded_context":
			continue  # only contexts receive Tint — spec §Domain tinting
		var ctx_id: String = nd.get("id", "")
		if ctx_id == "":
			continue
		# Cycle through the palette if there are more contexts than colors.
		var tint_color: Color = TINT_PALETTE[palette_index % TINT_PALETTE.size()]
		palette_index += 1
		_assignments[ctx_id] = tint_color

		# Step 3: Attach tint overlay to anchor if available.
		var anchor: Node3D = anchors.get(ctx_id) as Node3D
		if anchor == null:
			continue
		_attach_tint_overlay(anchor, nd, tint_color)


## Remove all tint overlays from anchors in *anchors* dict.
##
## Called before re-applying tints so the assignment is replaced, not layered.
## Also called externally when switching to a non-tint view.
##
## Spec §One tint dimension: "the previous Tint assignment is replaced".
func clear_tints(anchors: Dictionary) -> void:
	for anchor: Node3D in anchors.values():
		if anchor == null:
			continue
		_remove_tint_from_anchor(anchor)


## Return legend entries for the currently active tint dimension.
##
## Each entry is a Dictionary with:
##   label: String — the context name / id used as legend text.
##   color: Color  — the tint color assigned to that context.
##
## The array is ordered by assignment (first-encountered context first).
## Returns an empty array if no tints have been applied.
##
## Spec §Tint is the only symbolic primitive:
##   "it is the one primitive that requires a legend"
##   "the legend is always visible when Tint is active"
func get_legend_entries() -> Array:
	var entries: Array = []
	for ctx_id: String in _assignments.keys():
		entries.append({
			"label": ctx_id,
			"color": _assignments[ctx_id],
			"dimension": _active_dimension,
		})
	return entries


## Return the active tint dimension label (empty string if no tints applied).
func get_active_dimension() -> String:
	return _active_dimension


## Return true if at least one tint is currently active.
func is_active() -> bool:
	return _assignments.size() > 0


# ---------------------------------------------------------------------------
# Private helpers
# ---------------------------------------------------------------------------

## Attach a DomainTintOverlay child to *anchor*.
##
## The overlay is a thin flat slab (BoxMesh) slightly wider than the context
## box, placed just below the context geometry.  The semi-transparent color
## marks the context's categorical membership at a glance.
func _attach_tint_overlay(anchor: Node3D, nd: Dictionary, color: Color) -> void:
	var sz: float = float(nd.get("size", 2.0))
	# Overlay is wider than the box for perimeter visibility.
	# Height is minimal — just enough to be visible without obscuring content.
	var slab := BoxMesh.new()
	slab.size = Vector3(sz * 1.10, sz * 0.04, sz * 1.10)

	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED   # visible from above AND below
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED  # not affected by lighting

	var overlay := MeshInstance3D.new()
	overlay.name = TINT_NODE_NAME
	overlay.mesh = slab
	overlay.material_override = mat
	# Placed at a small negative Y so it sits just below the context slab but
	# is clearly visible as a colored floor plate.
	# local offset only — parent world coordinates added by Godot at render time.
	overlay.position = Vector3(0.0, -sz * 0.13, 0.0)
	anchor.add_child(overlay)


## Remove any existing DomainTintOverlay child from *anchor*.
##
## Uses free() rather than queue_free() so that the removal is immediate and
## observable in unit tests running outside the main scene tree.  queue_free()
## defers removal to the next process frame, which never arrives in headless
## test contexts — nodes stay as children and the test incorrectly fails.
func _remove_tint_from_anchor(anchor: Node3D) -> void:
	# Collect in a separate array first — modifying get_children() while
	# iterating it is undefined behaviour in GDScript.
	var to_remove: Array = []
	for child: Node in anchor.get_children():
		if str(child.name) == TINT_NODE_NAME:
			to_remove.append(child)
	for child: Node in to_remove:
		child.free()
