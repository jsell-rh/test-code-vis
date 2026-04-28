# Code-Vis Specifications

Spatial development environment for understanding agent-built software systems.

## Spec Index

### Core
- [System Purpose](core/system-purpose.spec.md) — Why this system exists, the problem it solves
- [Understanding Modes](core/understanding-modes.spec.md) — Conformance, Evaluation, Simulation
- [Visual Primitives](core/visual-primitives.spec.md) — The fixed vocabulary: extraction layer (6 data primitives) and composition layer (9 visual primitives)
- [Primitive Research](core/primitive-research.spec.md) — Cross-disciplinary rationale: 20 perspectives that grounded the primitive choices

### Visualization
- [Spatial Structure](visualization/spatial-structure.spec.md) — The persistent 3D geography of a software system, semantic zoom, cluster collapsing
- [Orthogonal Independence](visualization/orthogonal-independence.spec.md) — Making structural independence visible: what can change without affecting what
- [Data Flow](visualization/data-flow.spec.md) — On-demand flow visualization through the structure

### Interaction
- [Moldable Views](interaction/moldable-views.spec.md) — LLM-powered question-driven views

### Extraction
- [Code Extraction](extraction/code-extraction.spec.md) — Python extractor: codebase → JSON scene graph
- [Scene Graph Schema](extraction/scene-graph-schema.spec.md) — JSON interface contract between extractor and Godot app

### Prototype (Phase 1)
- [Prototype Scope](prototype/prototype-scope.spec.md) — What we're building and why, hypothesis to test
- [Godot Application](prototype/godot-application.spec.md) — Godot 4 app: JSON scene graph → navigable 3D space
- [Non-Functional Requirements](prototype/nfr.spec.md) — Tech stack, platform, performance, disposability
- [UX Polish](prototype/ux-polish.spec.md) — Intuitive controls: pan, zoom-to-cursor, orbit-around-point, smooth movement
