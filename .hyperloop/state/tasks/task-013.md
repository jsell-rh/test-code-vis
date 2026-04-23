---
id: task-013
title: "Godot: camera controls (top-down, zoom, orbit)"
spec_ref: specs/prototype/godot-application.spec.md
status: not-started
phase: null
deps: [task-007]
round: 0
branch: null
pr: null
---

## Goal

Implement the 3D camera controller that lets the user navigate the scene from a top-down overview down to module-level detail.

## Scope

- **Default position**: camera starts at a top-down position elevated enough to show all bounded contexts in the scene at once
- **Zoom**: scroll wheel (or keyboard) moves the camera closer to or farther from the focal point; closer zoom reveals internal module structure within a bounded context
- **Orbit**: mouse drag (right-button or middle-button) rotates the camera around the current focal point; "up" remains intuitive (no gimbal flip)
- **Pan**: optional but desirable — middle-click drag or arrow keys shift the focal point laterally
- Camera movement must be smooth (interpolated, not instant snapping) to preserve spatial orientation
- Frame rate during camera movement must remain above 30 fps on Fedora Linux desktop hardware (per NFR)

## Acceptance

- On launch, all kartograph bounded contexts are visible in the default view
- The user can zoom in to a single bounded context and see its internal modules
- The user can orbit around the scene and the view remains stable
