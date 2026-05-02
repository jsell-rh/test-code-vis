---
id: task-035
title: Implement Node Primitive renderer (labeled entities at tier-2 LOD)
spec_ref: "specs/core/visual-primitives.spec.md@82d048ecde6d3209435ad2561c1384da93ba2cdd"
status: not-started
phase: null
deps: [task-011, task-014]
round: 0
branch: null
pr: null
pr_title: "feat(godot): implement Node primitive renderer for tier-2 LOD (functions/classes)"
pr_description: |
  ## What and Why

  At tier-2 LOD (near zoom), the scene must show individual functions and classes
  as distinct visual entities within their parent module Container. The Container
  renderer (task-012) handles bounded context and module-level boxes. Below that
  level — the individual symbol layer — there is currently nothing to render.
  This task fills that gap with a Node Primitive renderer.

  The Node primitive is defined in the spec as: "an entity with identity, carrying
  zero or more Badges. Nodes do not have baked-in types — their visual identity
  comes entirely from their Badges." For the prototype (which has no Badge
  extraction yet), a Node renders as a small labeled 3D object. Its label is its
  name; its size is derived from a complexity metric (e.g. LOC or call-site count
  if available, otherwise uniform size). All Nodes look the same visually — only
  labels and Badges would differentiate them — making this renderer intentionally
  simple and composable.

  Without this renderer, zooming into a module at tier-2 reveals an empty box:
  the Container is drawn but its constituent functions and classes are invisible.
  This breaks the prototype's core "zoom to detail" requirement: "WHEN the user
  zooms into the IAM context, THEN the internal layers become visible."

  The LOD Shell (task-014) already manages when tier-2 elements fade in and out.
  This task provides the scene node that the LOD Shell fades in — a `NodePrimitive`
  GDScript class that the LOD Shell can instantiate and control.

  ## Spec Requirements Satisfied

  `specs/core/visual-primitives.spec.md` — Requirement: Node Primitive

  - A function `validate_order` is represented as a Node with its name label;
    it appears as a plain labeled object with no special shape.
  - An entity with no notable aspects (no Badges) renders as a plain Node with
    its name — Badges are additive and their absence is the default state.
  - All Nodes use the same geometry (consistent shape vocabulary), differentiated
    only by their name label and size.

  Also satisfies:
  `specs/prototype/prototype-scope.spec.md` — Requirement: Zoom to Detail

  - Zooming into a bounded context reveals internal layers; at tier-2, individual
    module members (functions, classes) are visible.

  ## Key Design Decisions

  - **Geometry**: Node primitives use a flattened box (BoxMesh with reduced
    height) distinct from Container boxes (which use a taller box). The visual
    distinction is intentional: Containers have interior volume, Nodes are
    flat entities sitting inside Containers. At tier-2 distances the difference
    is perceptible without requiring color or special shape.
  - **Size**: Node size is proportional to a complexity scalar read from the node
    JSON. For symbol-level nodes, complexity defaults to 1.0 if no metric is
    present. This allows uniform-sized Nodes for now; future passes (call graph,
    symbol table) can populate a `complexity` field that scales the Node.
  - **Label**: A `Label3D` child node displays the symbol name. Label visibility
    is managed by the LOD Shell — at distance, labels fade out before the Node
    itself does.
  - **Position**: Node positions are read directly from the scene graph JSON
    (`position.x/y/z`), pre-computed by the extractor layout pass (task-008).
    The Node renderer does not compute layout.
  - **Parenting**: Each Node scene instance is attached to its parent Container
    node in the Godot scene tree, using the `parent` field from the JSON to find
    the correct Container. The Container renderer (task-012) must already exist
    in the tree before NodePrimitives are instantiated.
  - **LOD integration**: `NodePrimitive` exposes a `set_lod_visibility(tier)`
    method. LOD Shell (task-014) calls this when the camera distance changes.
    Tier-0 and tier-1: hidden (opacity 0). Tier-2: visible (opacity 1.0). Fade
    is animated by the LOD Shell's existing opacity animation infrastructure.
  - **Badge slot**: the Node primitive includes a reserved `badge_container`
    node (empty `Node3D`) where Badge Primitive children can be attached in a
    future task. This slot is unused in this task but its presence avoids
    rework when Badges are added.

  ## Files / Areas Affected

  - `godot/scenes/node_primitive.tscn` — new scene: BoxMesh body + Label3D
    child + empty badge_container node
  - `godot/scripts/node_primitive.gd` — new GDScript class; reads `id`, `name`,
    `size`/`complexity`, `position` from a JSON dict; exposes
    `set_lod_visibility(tier: int)` method; positions Label3D relative to mesh
  - `godot/scripts/scene_loader.gd` — extended to instantiate NodePrimitive
    for every JSON node whose type is `function`, `method`, or `class`
    (i.e. symbol-level entities, not `module` or `bounded_context` which are
    rendered by ContainerRenderer)
  - `godot/tests/test_node_primitive.gd` — GDScript tests covering:
    - node with `name: "validate_order"` renders Label3D with text "validate_order"
    - node with no `complexity` field renders at default size (1.0 scale)
    - `set_lod_visibility(0)` hides the node (modulate alpha = 0)
    - `set_lod_visibility(2)` makes the node visible (modulate alpha = 1)
    - node's world position matches the `position` dict from JSON (within
      floating-point tolerance)
    - node with `parent: "iam.domain"` is attached to the correct Container
      in the scene tree

  ## How to Verify

  1. Run the extractor on `~/code/kartograph` (ensure task-002 scope nesting
     is merged so function-level nodes appear in the JSON).
  2. Launch the Godot project and zoom to a module (IAM domain layer).
  3. As the camera reaches tier-2 distance, individual function and class nodes
     should fade in inside the module Container box.
  4. Each node displays its name as a 3D label.
  5. Zooming back out past tier-1 causes the nodes to fade out (label first,
     then mesh — matching LOD Shell behavior).
  6. Run `gdscript tests/test_node_primitive.gd` — all assertions pass.

  ## Caveats / Follow-up

  - Node size uses a uniform default until a `complexity` field is populated by
    the symbol table pass (task-030) or call graph pass (task-032). Uniform size
    is acceptable for the prototype.
  - The Badge slot is present but empty. Badge Primitive rendering is a separate
    future task (not in current scope). When Badges are implemented, they attach
    as children of `badge_container` without changing this renderer.
  - At tier-2, all symbol-level nodes (functions, classes, methods) are rendered
    identically. Visual differentiation between e.g. a class and a function
    requires either different Badge assignments or a future shape vocabulary
    extension — both outside current prototype scope.
  - If a JSON node has a `parent` ID that does not correspond to a loaded
    Container, it is rendered at world origin with a warning logged. This is a
    defensive fallback for partial scene graphs.
---
