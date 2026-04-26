---
id: task-027
title: Performance validation at kartograph scale
spec_ref: specs/prototype/nfr.spec.md
status: not-started
phase: null
deps: [task-006, task-013, task-018, task-019]
round: 0
branch: null
pr: null
---

Validate that the Godot application renders kartograph's full structure — 6 bounded
contexts, ~50 modules, ~100 files — at or above 30 fps during all navigation gestures.

Covers `specs/prototype/nfr.spec.md` — Requirement: Performance at Kartograph Scale:

- Run the full extractor pipeline (task-006) against the kartograph codebase
  (`~/code/kartograph`) to produce a representative scene graph with the complete
  node and edge set (expected: ~6 contexts, ~50 modules, ~100 file-level nodes).
- Load that scene graph in the Godot application.
- Exercise all three navigation gestures — pan (task-015), zoom-to-cursor (task-016),
  and orbit (task-017) — across the full loaded scene with smooth movement (task-018).
- Confirm that the frame rate remains above 30 fps throughout; use Godot's built-in
  performance monitor (`Performance.get_monitor(Performance.TIME_FPS)`) to sample FPS
  during navigation.
- If frame rate drops below 30 fps under normal navigation, profile and resolve the
  bottleneck before marking this task complete. Acceptable approaches include:
  - Batching `MeshInstance3D` nodes to reduce draw calls.
  - Simplifying dependency line meshes (task-013).
  - Tuning LOD thresholds (task-019) so fewer nodes are evaluated per frame.
  - Culling off-screen nodes using Godot 4.6's `VisibleOnScreenNotifier3D`.
- Record the scene graph statistics (total node count, edge count) in a brief comment
  or note in `godot/README.md` so the performance baseline is traceable.
- No external profiling tools required; Godot 4.6 built-in monitors and the Godot
  editor's Profiler tab only.
- All fixes MUST use GDScript and Godot 4.6 API only.
