---
id: task-033
title: Implement Container membrane permeability renderer
spec_ref: "specs/core/visual-primitives.spec.md@82d048ecde6d3209435ad2561c1384da93ba2cdd"
status: not-started
phase: null
deps: [task-012, task-030]
round: 0
branch: null
pr: null
pr_title: "feat(godot): implement Container membrane permeability as continuous visual property"
pr_description: |
  ## What and Why

  The Container renderer (task-012) ships with a placeholder for membrane
  permeability: every Container renders with the same border regardless of how
  exposed its internals are. This task replaces that placeholder with a real
  continuous visual encoding.

  The spec requires: "a module with 2 public symbols and 30 private symbols has
  a thick/opaque membrane; a module with 25 public symbols and 5 private symbols
  has a thin/porous membrane. Permeability is a continuous visual property, not
  a binary toggle."

  Membrane permeability communicates encapsulation strength at a glance, without
  the user needing to read labels or open a detail panel. A tightly encapsulated
  module (few public symbols) should look solid; a leaky one (many public symbols
  relative to its total) should look permeable. This lets an architect immediately
  spot modules that are over-exposing their internals.

  The raw data — `public_symbol_count` and `private_symbol_count` per node —
  is produced by the symbol table extraction pass (task-030). This task consumes
  those fields from the loaded scene graph and translates them into a visual
  property on the existing Container mesh.

  ## Spec Requirements Satisfied

  `specs/core/visual-primitives.spec.md` — Requirement: Container Primitive,
  Scenario: Container membrane permeability

  - A module with 2 public symbols and 30 private symbols renders with a thick,
    nearly-opaque border.
  - A module with 25 public symbols and 5 private symbols renders with a thin,
    near-transparent border.
  - The visual is continuous: the permeability ratio drives a shader parameter
    linearly, not with threshold steps.
  - Modules where `public_symbol_count` and `private_symbol_count` are both 0
    (e.g. `__init__.py` with no symbols) render with a neutral mid-opacity border.

  ## Key Design Decisions

  - **Permeability ratio**: `p = public_symbol_count / max(1, public_symbol_count + private_symbol_count)`.
    `p` ranges from 0.0 (fully private) to 1.0 (fully public).
  - **Visual encoding**: the Container box's border uses a ShaderMaterial with a
    `permeability` uniform. At `p = 0.0` the border is full opacity and maximum
    thickness. At `p = 1.0` the border is minimum thickness and partially
    transparent (suggesting openings in the membrane). The shader linearly
    interpolates between these extremes based on `p`.
  - **Separation of concerns**: the permeability shader is a separate
    `ShaderMaterial` on the `border_mesh` (a `MeshInstance3D` child of the
    Container node), distinct from the main fill material. This avoids coupling
    the encapsulation visual to the Tint (fill color).
  - Nodes without `public_symbol_count` / `private_symbol_count` fields (e.g.
    pre-task-030 JSON or non-module nodes) default to `p = 0.5` (neutral).
  - The permeability rendering applies to module-level Containers. Bounded
    context Containers do not show membrane permeability (they are organizational
    boundaries, not encapsulation surfaces).

  ## Files / Areas Affected

  - `godot/shaders/membrane.gdshader` — new shader implementing continuous border
    thickness and opacity based on `permeability` uniform
  - `godot/scripts/container_renderer.gd` — updated to compute permeability ratio
    from node's `public_symbol_count` / `private_symbol_count`, set the
    `permeability` uniform on the border mesh's ShaderMaterial
  - `godot/scenes/container_node.tscn` — updated to include a `border_mesh`
    child `MeshInstance3D` alongside the existing fill mesh
  - `godot/tests/test_membrane_permeability.gd` — tests covering:
    - node with all-private symbols → permeability uniform close to 0.0
    - node with all-public symbols → permeability uniform close to 1.0
    - node with equal public/private → permeability uniform ≈ 0.5
    - node with missing counts → permeability uniform defaults to 0.5
    - permeability shader uniform is a continuous float, not a step value

  ## How to Verify

  1. Run the extractor (with task-030 merged) on `~/code/kartograph`.
  2. Launch the Godot project.
  3. Zoom to medium distance inside a bounded context. Module Containers should
     visibly differ in border thickness/opacity — high-encapsulation modules
     should look "solid" while loosely-encapsulated modules should look "porous."
  4. Confirm the variation is continuous: modules with ratios in between extremes
     should show intermediate border weights.
  5. Confirm bounded context Containers do NOT show the membrane effect (they
     remain solid-bordered organizational volumes).
  6. Run `gdscript tests/test_membrane_permeability.gd` — all assertions pass.

  ## Caveats / Follow-up

  - The membrane shader encodes permeability via border weight and opacity.
    Future work could add a "pore" pattern (small gaps or dots) at high
    permeability values for a more iconic membrane metaphor.
  - Port Primitive rendering (not in prototype scope) would eventually place
    individual Port markers on the membrane at positions corresponding to each
    public symbol. Membrane permeability as implemented here is the prerequisite
    visual infrastructure for that.
  - If `task-030` has not run, `public_symbol_count` and `private_symbol_count`
    will be absent from the JSON, triggering the neutral-default fallback.
    This is intentional: the renderer degrades gracefully.
---
