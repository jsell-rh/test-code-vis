class_name IndependenceQuery
extends RefCounted

## Independence Query — makes structural independence a queryable, visual property.
##
## Implements specs/visualization/orthogonal-independence.spec.md §
## Requirement: Independence as Queryable Property.
##
## When the human selects a module, this class computes its orthogonal complement
## (everything that can change without affecting it) and highlights those modules.
##
## Two levels of independence are supported:
##   - Module-level: modules in other independence groups within the same bounded
##     context are the orthogonal complement of the selected module.
##   - Context-level: bounded contexts with no transitive dependency on the
##     selected module's context are fully independent at the context level.
##
## Colour scheme:
##   INDEPENDENT_COLOR  — modules/contexts in other independence groups (orthogonal
##                        complement — can change without affecting selected node)
##   CODEPENDENT_COLOR  — modules in the same independence group (co-dependent —
##                        changes may affect the selected node)
##   SELECTED_COLOR     — the selected module itself (reference anchor)
##   DEFAULT_COLOR      — modules outside the selected context (neutral)

## Colour for the orthogonal complement — modules that can change independently.
const INDEPENDENT_COLOR: Color = Color(0.20, 0.85, 0.30, 1.0)   # green — safe to change

## Colour for co-dependent modules in the same independence group.
const CODEPENDENT_COLOR: Color = Color(0.90, 0.55, 0.10, 1.0)   # orange — coupled

## Colour for the selected module (origin of the query).
const SELECTED_COLOR: Color = Color(0.95, 0.95, 0.20, 1.0)      # bright yellow — selected

## Colour for modules outside the selected context (context-level independence).
const CONTEXT_INDEPENDENT_COLOR: Color = Color(0.10, 0.70, 0.95, 1.0)  # cyan — context-independent


# ---------------------------------------------------------------------------
# Module-level independence query
# ---------------------------------------------------------------------------

## Apply independence highlighting for the selected module.
##
## Spec: "WHEN independence information is displayed
##   THEN all modules in other independence groups within the same bounded context
##        are highlighted
##   AND modules in A's own group are visually distinguished as 'co-dependent'"
##
## Args:
##   selected_id: The node ID of the selected module.
##   nodes_data: Array of all node dicts from the scene graph.
##   anchors: Dict mapping node_id → Node3D anchor.
##
## Returns a Dictionary:
##   "independent": Array of node IDs in the orthogonal complement.
##   "codependent": Array of node IDs in the same independence group.
func apply_independence_highlight(
		selected_id: String,
		nodes_data: Array,
		anchors: Dictionary) -> Dictionary:

	# Find the selected node to get its independence_group and parent context.
	var selected_group: String = ""
	var selected_parent: String = ""
	for nd: Dictionary in nodes_data:
		if nd.get("id", "") == selected_id:
			selected_group = nd.get("independence_group", "")
			selected_parent = nd.get("parent", "")
			break

	var independent_ids: Array = []
	var codependent_ids: Array = []

	# Classify modules within the same bounded context.
	for nd: Dictionary in nodes_data:
		var nid: String = nd.get("id", "")
		if nid == selected_id:
			# Highlight the selected module itself.
			_apply_node_color(anchors.get(nid) as Node3D, SELECTED_COLOR)
			continue

		# Only consider modules in the same parent bounded context.
		if nd.get("type", "") != "module":
			continue
		if nd.get("parent", "") != selected_parent:
			continue

		var grp: String = nd.get("independence_group", "")
		var anchor: Node3D = anchors.get(nid) as Node3D
		if grp != "" and grp != selected_group:
			# Different independence group → orthogonal complement.
			independent_ids.append(nid)
			_apply_node_color(anchor, INDEPENDENT_COLOR)
		else:
			# Same independence group → co-dependent.
			codependent_ids.append(nid)
			_apply_node_color(anchor, CODEPENDENT_COLOR)

	return {
		"independent": independent_ids,
		"codependent": codependent_ids,
	}


## Reset all node colours to a neutral default (clear independence highlight).
##
## Spec: "the transition between default and independence-highlighted states is
##   animated smoothly" — this function performs an instant reset for cases where
##   animation is not required (unit tests, programmatic reset).
##
## In the Godot scene tree the caller should Tween the material albedo_color
## back to the node's original colour; here we restore a neutral grey.
func clear_independence_highlight(nodes_data: Array, anchors: Dictionary) -> void:
	var neutral := Color(0.35, 0.70, 0.40, 1.0)  # module default green
	for nd: Dictionary in nodes_data:
		if nd.get("type", "") != "module":
			continue
		var nid: String = nd.get("id", "")
		var anchor: Node3D = anchors.get(nid) as Node3D
		_apply_node_color(anchor, neutral)


# ---------------------------------------------------------------------------
# Context-level independence query
# ---------------------------------------------------------------------------

## Find bounded contexts that have no transitive dependency on context_id.
##
## Spec: "GIVEN the human selects module A in context X
##   WHEN independence is displayed at the context level
##   THEN bounded contexts with no transitive dependency on context X are
##        highlighted as fully independent"
##
## Uses BFS on the reverse-dependency graph to find all contexts that can
## reach context_id transitively, then returns the complement.
##
## Args:
##   context_id: The bounded-context node ID (e.g. "iam").
##   nodes_data: Array of all node dicts.
##   edges_data: Array of all edge dicts.
##
## Returns an Array of bounded-context node IDs that are fully independent
## of context_id (no transitive dependency path to or from it).
func find_context_independent_peers(
		context_id: String,
		nodes_data: Array,
		edges_data: Array) -> Array:

	# Collect all bounded-context IDs.
	var all_context_ids: Array = []
	for nd: Dictionary in nodes_data:
		if nd.get("type", "") == "bounded_context":
			all_context_ids.append(nd.get("id", ""))

	# Build a directed adjacency: context → set of contexts it depends on.
	# An edge A→B means A depends on B (A "imports from" B).
	var depends_on: Dictionary = {}  # context_id → Array of dependency context IDs
	for ed: Dictionary in edges_data:
		var src: String = ed.get("source", "")
		var tgt: String = ed.get("target", "")
		if src.is_empty() or tgt.is_empty():
			continue
		var src_ctx: String = src.split(".")[0]
		var tgt_ctx: String = tgt.split(".")[0]
		if src_ctx == tgt_ctx:
			continue  # internal edge — not a cross-context dependency
		if src_ctx not in depends_on:
			depends_on[src_ctx] = []
		if tgt_ctx not in (depends_on[src_ctx] as Array):
			(depends_on[src_ctx] as Array).append(tgt_ctx)

	# BFS: find all contexts that transitively depend on context_id.
	# These contexts are NOT independent — changes to context_id affect them.
	var dependent_contexts: Dictionary = {}  # set of context IDs that depend on context_id
	dependent_contexts[context_id] = true
	var queue: Array = [context_id]
	# We need the reverse graph: for each context, who depends on IT?
	var depended_by: Dictionary = {}  # context_id → Array of contexts that depend on it
	for ctx: String in depends_on.keys():
		for dep: String in (depends_on[ctx] as Array):
			if dep not in depended_by:
				depended_by[dep] = []
			if ctx not in (depended_by[dep] as Array):
				(depended_by[dep] as Array).append(ctx)

	while not queue.is_empty():
		var current: String = queue.pop_front()
		for dependent: String in depended_by.get(current, []):
			if not dependent_contexts.has(dependent):
				dependent_contexts[dependent] = true
				queue.append(dependent)

	# Also add contexts that context_id depends on (transitively).
	# Those are also "non-independent" because context_id depends on them.
	var dependency_contexts: Dictionary = {}
	dependency_contexts[context_id] = true
	queue = [context_id]
	while not queue.is_empty():
		var current: String = queue.pop_front()
		for dep: String in depends_on.get(current, []):
			if not dependency_contexts.has(dep):
				dependency_contexts[dep] = true
				queue.append(dep)

	# Merge both: any context connected to context_id (directly or transitively)
	# in either direction is not fully independent.
	for ctx: String in dependency_contexts.keys():
		dependent_contexts[ctx] = true

	# The orthogonal complement: contexts with NO transitive path to or from context_id.
	var independent: Array = []
	for ctx: String in all_context_ids:
		if ctx == context_id:
			continue
		if not dependent_contexts.has(ctx):
			independent.append(ctx)

	return independent


## Apply context-level independence highlighting.
##
## Spec: "THEN bounded contexts with no transitive dependency on context X
##   are highlighted as fully independent"
##
## Highlights independent contexts with CONTEXT_INDEPENDENT_COLOR.
##
## Returns the Array of independent context IDs.
func apply_context_independence_highlight(
		context_id: String,
		nodes_data: Array,
		edges_data: Array,
		anchors: Dictionary) -> Array:

	var independent_contexts := find_context_independent_peers(
		context_id, nodes_data, edges_data
	)

	for ctx_id: String in independent_contexts:
		var anchor: Node3D = anchors.get(ctx_id) as Node3D
		_apply_node_color(anchor, CONTEXT_INDEPENDENT_COLOR)

	return independent_contexts


# ---------------------------------------------------------------------------
# Shared helpers
# ---------------------------------------------------------------------------

## Apply a colour to the first MeshInstance3D child of an anchor.
## No-op if anchor is null or has no MeshInstance3D child.
func _apply_node_color(anchor: Node3D, color: Color) -> void:
	if anchor == null:
		return
	for child: Node in anchor.get_children():
		if child is MeshInstance3D:
			var mat := StandardMaterial3D.new()
			mat.albedo_color = color
			(child as MeshInstance3D).material_override = mat
			break
