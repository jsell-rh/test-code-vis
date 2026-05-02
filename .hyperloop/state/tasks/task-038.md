---
id: task-038
title: Implement Port primitive renderer in Godot (public interface points on Container membrane)
spec_ref: "specs/core/visual-primitives.spec.md@82d048ecde6d3209435ad2561c1384da93ba2cdd"
status: not-started
phase: null
deps: [task-023, task-012, task-014]
round: 0
branch: null
pr: null
pr_title: "feat(godot): render Port primitives on Container membrane (public symbol interface points)"
pr_description: |
  ## What and Why

  Implements the Port primitive renderer in Godot. A Port is a small visual element
  anchored to a Container's membrane that represents an interface point — a public
  function, API endpoint, or event emitter. Ports make a module's public API visible
  without opening it, and Edges connect to Ports rather than to the Container body,
  making the entry/exit points of a dependency explicit.

  This task reads public symbol data from the scene graph (produced by task-023's symbol
  table extraction) and renders them as Ports on the Container membrane (established by
  task-012).

  ## Spec Requirements Satisfied

  `specs/core/visual-primitives.spec.md` — Requirement: Port Primitive

  - Public functions rendered as labeled Ports on Container membrane
  - Edges connect to Ports, not directly to Container body
  - Input/output Port direction distinction (parameters = input, return values = output)
  - Port visibility is LOD-driven: hidden at tier-0 (far), fade in at tier-2 (near)

  ## Key Design Decisions

  ### Data source: symbols field, no schema extension required

  The symbol table extraction (task-023) adds a `symbols` array to each node, with each
  symbol carrying `name`, `visibility`, and `signature` (parameters + return type). No
  additional extractor pass is needed. The Port renderer filters symbols where
  `visibility == "public"` and treats each as a Port.

  ```
  symbols[*]{visibility: "public"}  →  Port on membrane
  ```

  Port direction is derived from the symbol signature:
  - **Input Port**: one per parameter in the function signature (parameters represent
    accepted dependencies/data)
  - **Output Port**: one per distinct non-`None` return type in the signature (return
    values represent emitted data/events)

  For the prototype, a simplified form is used: one input-side Port and one output-side
  Port per public function (full per-parameter ports are tier-2 enhancement).

  ### Port placement on membrane

  Ports are distributed evenly around the Container's bounding surface:
  - Input ports appear on the left/bottom face of the Container volume
  - Output ports appear on the right/top face
  - Each Port is a small labeled sphere or disc (`MeshInstance3D`) anchored to the
    membrane surface at a computed offset
  - Port label (`Label3D`) shows the function name, oriented toward the camera

  ### LOD integration

  Ports are a tier-2 (near) detail. At tier-0 and tier-1:
  - Port meshes: alpha = 0 (hidden)
  - Port labels: alpha = 0

  At tier-2 (near), ports fade in using the same animated opacity system as the LOD
  Shell (task-014). This matches the spec: "As the human zooms in, Ports fade in on
  the membrane."

  ### Edge routing to Ports

  The existing Edge renderer (task-013) currently connects Edges to Container centroids.
  This task extends the Edge renderer to look up Port positions and route Edge endpoints
  to the closest Port on the source/target Container:
  - If a Port position is available, the Edge's endpoint snaps to the Port
  - If no Ports are present (tier-0/1 LOD), the Edge falls back to Container centroid

  This is a non-breaking extension: the fallback preserves existing Edge rendering
  behavior when Ports are not visible.

  ### Container membrane permeability integration

  The membrane permeability visual (task-033) and Port rendering are independent features
  that both render on the Container membrane surface. This task does NOT require task-033
  to be complete. Ports are rendered as discrete anchored elements regardless of membrane
  visual state. Coordinate with task-033 implementer to avoid overlapping surface anchors.

  ## Files / Areas Affected

  - `godot/rendering/port_renderer.gd` — new GDScript; reads public symbols from a node's
    symbol table; computes Port positions on the Container membrane; instantiates Port
    mesh and label nodes; manages LOD opacity; exposes Port world positions for Edge routing
  - `godot/rendering/container_renderer.gd` — extended to instantiate `port_renderer`
    per Container; store Port position map keyed by symbol name
  - `godot/rendering/edge_renderer.gd` — extended to query Port positions when routing
    Edge endpoints; fall back to Container centroid when Ports are hidden/unavailable
  - `godot/tests/test_port_renderer.gd` — Godot behavioral tests covering:
    - Container with 4 public symbols displays 4 Port elements on its membrane
    - Container with 0 public symbols displays no Port elements
    - Port labels match the function names from the symbol table
    - At tier-0 LOD all Port meshes and labels have alpha = 0
    - At tier-2 LOD Port meshes and labels have alpha > 0
    - Edge endpoints route to Port positions rather than Container centroid when Ports visible
    - Input and output Ports appear on opposing faces of the Container

  ## How to Verify

  1. Run the extractor on `~/code/kartograph` (with task-023 symbol table data present).
  2. Load the scene graph in Godot.
  3. Zoom in to a module Container — confirm small labeled Port elements appear on its
     membrane, one per public function.
  4. Confirm Edges from other modules terminate at Port positions, not at Container centers.
  5. Zoom out to tier-0 — confirm Ports disappear and Edges route back to Container centroids.
  6. Run Godot behavioral tests: all test suites pass, including port-specific suites.

  ## Caveats / Follow-up

  - Prototype renders one Port per public function (not per parameter). Full per-parameter
    Port rendering is a future enhancement once the visual is validated.
  - Port placement algorithm distributes ports evenly around the membrane. For Containers
    with many public functions (e.g. 20+), ports may become crowded. A future task can
    implement port-count-aware spacing or grouping.
  - Edge routing to Ports is an extension to the existing Edge renderer (task-013). If
    task-013 is still in-flight when this task begins, coordinate to avoid merge conflicts
    in `edge_renderer.gd`.
  - The Port primitive spec states that Ports are labeled and that Edges connect to Ports.
    Full conformance requires both mesh placement AND edge routing. Both are in scope here.
---
