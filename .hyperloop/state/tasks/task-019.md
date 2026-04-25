---
id: task-019
title: Godot — level-of-detail visibility (show/hide nodes by camera distance)
spec_ref: specs/visualization/spatial-structure.spec.md
status: not-started
phase: null
deps: [task-009, task-014]
round: 0
branch: null
pr: null
---

Implement level-of-detail (LOD) visibility so that child nodes become visible as the camera
moves closer to their parent, and are hidden when the camera is far away. This makes
high-level structure visible at a distance and exposes internal detail on approach.

Covers `specs/visualization/spatial-structure.spec.md` — Requirement: Scale Through Zoom:
- When the camera is far away, only top-level nodes (bounded contexts) are visible.
- As the camera moves closer to a bounded context, its child module nodes become visible.
- As the camera moves closer to a module, finer-grained detail nodes appear.

Also covers `specs/prototype/prototype-scope.spec.md` — Requirement: Zoom to Detail:
- When the user zooms into the IAM context, internal layers become visible
  (domain, application, infrastructure, presentation).

Implementation notes:
- Use each node's `type` field from the JSON schema to assign a LOD tier:
  `bounded_context` → tier 0 (always visible); `module` → tier 1; file-level → tier 2.
- In `_process()`, compute camera distance to each node's world position.
- Toggle `visible` on each node's MeshInstance3D (or parent Node3D) based on whether the
  camera is within the tier's visibility threshold distance.
- Threshold distances should be tuned against kartograph's layout extents so that
  internal modules appear naturally as the user zooms in on a context.
- Dependency edge lines (task-013) should follow the same LOD rules as their source and
  target nodes: a line is visible only when both endpoints are visible.
- No external library required; use pure GDScript and Godot 4.6 API.
