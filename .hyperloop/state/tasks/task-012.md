---
id: task-012
title: Implement Container primitive renderer
spec_ref: "specs/core/visual-primitives.spec.md@82d048ecde6d3209435ad2561c1384da93ba2cdd"
status: not-started
phase: null
deps: [task-011]
round: 0
branch: null
pr: null
pr_title: "feat(godot): implement Container primitive renderer"
pr_description: |
  ## What and Why

  Renders bounded contexts and module-level scopes as nested, labeled 3D volumes
  in the Godot scene. This is the visual backbone of the prototype — the bounded
  contexts become the navigable "buildings" of the architectural landscape. Without
  the Container renderer, no structural information is visible.

  The prototype-scope requirement is explicit: "labeled geometric volume, size
  reflects relative complexity, containment shown by nesting."

  ## Spec Requirements Satisfied

  `specs/core/visual-primitives.spec.md` — Requirement: Container Primitive

  - Each node of type `bounded_context` or `module` is rendered as a bounded
    3D region (box mesh by default).
  - Containers can be nested: a module node whose `parent` is a bounded context
    appears as a smaller box inside the context's box.
  - Node `size` field drives the mesh scale: larger size → larger box.
  - Node `position` field (from the layout algorithm) positions the box in world
    space.
  - Each Container has a `Label3D` displaying the node `name`.
  - Encapsulation visual: the box outline (or subtle translucent fill) varies with
    the ratio of public to private symbols — placeholder for now; full membrane
    visual is deferred.

  `specs/prototype/prototype-scope.spec.md` — "abstract volumes (boxes), size
  reflects relative complexity, containment shown by nesting, readable labels"

  ## Key Design Decisions

  - Each Container is a Godot `MeshInstance3D` with a `BoxMesh` scaled to the
    node size.
  - Nested Containers are children of their parent Container node in the Godot
    scene tree, so parent transforms naturally contain children.
  - Labels use `Label3D` anchored to the top face of the box; font size scales
    with the box so labels remain readable across zoom levels.
  - Bounded context boxes use a distinct color per context (simple modulo of a
    fixed palette) — full Tint primitive assignment is deferred.
  - Module boxes use a slightly transparent fill to show they are inside a context.

  ## Files / Areas Affected

  - `godot/scenes/container_node.tscn` — new scene for a single Container instance
  - `godot/scripts/container_renderer.gd` — instantiates Container nodes from
    loader data, handles nesting by reparenting to parent Container
  - `godot/scripts/main.gd` — calls `container_renderer.render_all()` after loader
    completes
  - `godot/tests/test_container_renderer.gd` — tests covering:
    - node count matches JSON nodes array
    - bounded context Container has `parent: null` (root-level in scene tree)
    - module Container is a child of its parent context Container
    - Container scale proportional to `size` field

  ## How to Verify

  1. Run the extractor on `~/code/kartograph`.
  2. Launch the Godot project; the scene should display labeled boxes for each
     bounded context with smaller module boxes nested inside.
  3. Confirm no script errors in the Godot output log.
  4. From a top-down camera perspective (task-015), all bounded contexts should be
     visible as distinct, labeled regions.

  ## Caveats / Follow-up

  The encapsulation membrane visual (permeability encoding public/private ratio) is
  a placeholder. The Tint primitive (categorical color assignment with legend) is
  deferred to a future phase — this task uses a simple per-context color for visual
  distinction. LOD visibility (showing/hiding Containers based on zoom) is handled
  by task-014.
---
