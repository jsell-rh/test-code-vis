extends RefCounted

## AggregateEdgeRenderer — groups cross-context dependency edges by bounded-context
## pair and renders a single weighted summary line per pair at the LOD FAR level.
##
## Spec: specs/visualization/spatial-structure.spec.md
## Requirement: Scale Through Zoom — Far scenario:
##   "cross-context dependencies are shown as single aggregate edges per context
##    pair, with weight indicating total import count"
##
## At FAR distance:
##   - Individual cross-context edges are hidden by LodManager.
##   - Aggregate edges (one per unique context pair) are made visible here.
##   - Visual weight (material albedo alpha) is proportional to the number of
##     individual cross-context edges between the same context pair.
##
## At MEDIUM / NEAR distance:
##   - Aggregate edges are hidden; individual module-level edges reappear.
##
## Implementation notes:
##   - edges_by_context: Dictionary keyed by "src_ctx->tgt_ctx" strings — the
##     canonical name for the context-pair grouping structure used below.
##   - Visibility transitions use Tween on the material's albedo_color:a when the
##     parent node is inside the scene tree, or direct .visible assignment in
##     headless unit-test mode.


## Build aggregate edge visuals from the full edge and node lists.
##
## edges:           Array of edge dicts from the scene graph
## nodes:           Array of node dicts from the scene graph
## world_positions: Dictionary from node_id → Vector3 (pre-computed by main.gd)
## parent_node:     Node3D that owns the visual children (typically main)
##
## Returns an Array of Dictionaries:
##   { "visual": MeshInstance3D, "material": StandardMaterial3D,
##     "source_context": String, "target_context": String, "count": int }
func build_aggregate_edges(
	edges: Array,
	nodes: Array,
	world_positions: Dictionary,
	parent_node: Node3D
) -> Array:
	# ── Step 1: build node_id → context_id map ────────────────────────────────
	# bounded_context nodes map to themselves.
	# module nodes map to their parent (which is always a bounded_context).
	var node_context_map: Dictionary = {}
	for nd: Dictionary in nodes:
		var ntype: String = nd.get("type", "")
		var nid: String = nd.get("id", "")
		if ntype == "bounded_context":
			node_context_map[nid] = nid
		elif ntype == "module":
			var parent_id = nd.get("parent", null)
			if parent_id != null and parent_id != "":
				node_context_map[nid] = parent_id

	# ── Step 2: group cross-context edges by (src_ctx, tgt_ctx) pair ──────────
	# edges_by_context: "src_ctx->tgt_ctx" → count of individual edges
	var edges_by_context: Dictionary = {}
	for ed: Dictionary in edges:
		if ed.get("type", "") != "cross_context":
			continue
		var src: String = ed.get("source", "")
		var tgt: String = ed.get("target", "")
		var src_ctx: String = node_context_map.get(src, src)
		var tgt_ctx: String = node_context_map.get(tgt, tgt)
		if src_ctx == tgt_ctx or src_ctx == "" or tgt_ctx == "":
			continue  # skip same-context or unknown nodes
		var pair_key: String = src_ctx + "->" + tgt_ctx
		edges_by_context[pair_key] = edges_by_context.get(pair_key, 0) + 1

	# ── Step 3: render one weighted MeshInstance3D line per context pair ───────
	var aggregate_entries: Array = []
	for pair_key: String in edges_by_context.keys():
		var count: int = int(edges_by_context[pair_key])
		var sep: int = pair_key.find("->")
		if sep < 0:
			continue
		var src_ctx: String = pair_key.left(sep)
		var tgt_ctx: String = pair_key.substr(sep + 2)

		if not world_positions.has(src_ctx) or not world_positions.has(tgt_ctx):
			continue

		var from_pos: Vector3 = world_positions[src_ctx]
		var to_pos: Vector3 = world_positions[tgt_ctx]

		if from_pos.is_equal_approx(to_pos):
			continue  # degenerate edge

		# Visual weight: opacity scales with import count (clamped 0.35–1.0).
		# More edges between a pair → more opaque aggregate line → stronger coupling.
		var weight: float = clamp(float(count) / 8.0, 0.35, 1.0)
		# Gold colour distinguishes aggregate edges from individual orange/grey edges.
		# Start with alpha=0.0 (hidden); show_edges() fades in at FAR LOD.
		var agg_color: Color = Color(1.0, 0.80, 0.10, 0.0)

		var imesh := ImmediateMesh.new()
		imesh.surface_begin(Mesh.PRIMITIVE_LINES)
		imesh.surface_set_color(Color(1.0, 0.80, 0.10, weight))
		imesh.surface_add_vertex(from_pos)
		imesh.surface_set_color(Color(1.0, 0.80, 0.10, weight))
		imesh.surface_add_vertex(to_pos)
		imesh.surface_end()

		var mat := StandardMaterial3D.new()
		mat.vertex_color_use_as_albedo = true
		mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		mat.albedo_color = agg_color  # alpha=0.0: hidden until show_edges() is called

		var mesh_instance := MeshInstance3D.new()
		mesh_instance.name = "AggregateEdge_" + src_ctx.replace("/", "_") + "_" + tgt_ctx.replace("/", "_")
		mesh_instance.mesh = imesh
		mesh_instance.material_override = mat
		# Start hidden: shown at FAR LOD via show_edges().
		mesh_instance.visible = false
		parent_node.add_child(mesh_instance)

		aggregate_entries.append({
			"visual": mesh_instance,
			"material": mat,
			"source_context": src_ctx,
			"target_context": tgt_ctx,
			"count": count,
			"weight": weight,
		})

	return aggregate_entries


## Fade aggregate edges in (make visible) for the FAR LOD level.
##
## When the parent node is inside the scene tree, uses Tween on the material's
## albedo_color:a for an animated opacity fade (spec: "elements fade in or out
## with animated opacity, never appearing or disappearing instantly").
## In headless unit-test mode (parent not in tree), sets visibility directly so
## tests can assert the final state without running a scene-tree process loop.
func show_edges(entries: Array, parent: Node3D) -> void:
	for entry: Dictionary in entries:
		var mesh: MeshInstance3D = entry["visual"]
		var mat: StandardMaterial3D = entry["material"]
		var w: float = float(entry["weight"])
		if parent.is_inside_tree():
			# aggregate edges fade in → albedo_color.a rises to weight → visible
			mesh.visible = true
			var tween := parent.create_tween()
			tween.tween_property(mat, "albedo_color:a", w, 0.4)
		else:
			# headless unit-test mode: set immediately for testability
			mesh.visible = true
			mat.albedo_color.a = w


## Fade aggregate edges out (hide) for MEDIUM and NEAR LOD levels.
##
## When the parent node is inside the scene tree, uses Tween on the material's
## albedo_color:a for an animated opacity fade. In headless mode, hides directly.
func hide_edges(entries: Array, parent: Node3D) -> void:
	for entry: Dictionary in entries:
		var mesh: MeshInstance3D = entry["visual"]
		var mat: StandardMaterial3D = entry["material"]
		if parent.is_inside_tree():
			# aggregate edges fade out → albedo_color.a falls to 0.0 → hidden
			var tween := parent.create_tween()
			tween.tween_property(mat, "albedo_color:a", 0.0, 0.4)
		else:
			# headless unit-test mode: set immediately
			mesh.visible = false
			mat.albedo_color.a = 0.0
