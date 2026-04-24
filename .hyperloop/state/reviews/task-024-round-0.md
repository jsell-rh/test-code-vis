---
task_id: task-024
round: 0
role: spec-reviewer
verdict: fail
---
## Reviewer Verdict — task-024 (UX Polish / Camera Controls)

**Branch:** hyperloop/task-024
**Spec:** specs/prototype/ux-polish.spec.md
**Reviewer action date:** 2026-04-24

---

## Summary

**FAIL.** One SHALL requirement is violated: the pan direction is inverted relative
to the spec's explicit Google Maps behavioral contract. The tests on this branch also
test the wrong direction (they verify the inverted behavior and call it
"non-inverted"). All other requirements are correctly implemented and tested.

---

## Requirement Status

| Requirement | Status | Notes |
|---|---|---|
| Pan with Left Mouse Button | PARTIAL | LMB panning is wired; direction is INVERTED (see below) |
| Non-Inverted Movement | MISSING | Pan is inverted; test tests the wrong direction |
| Zoom Toward Mouse Cursor | COVERED | Both zoom-in and zoom-out scenarios pass ✓ |
| Orbit Around Mouse Point | COVERED | Pivot remapped to cursor world point ✓ |
| Smooth Camera Movement — zoom | COVERED | Exponential interpolation in `_process` ✓ |
| Smooth Camera Movement — pan | COVERED | Direct proportional movement ✓ |

---

## Blocking Finding: Pan Direction Is Inverted

### The Spec Contract (SHALL)

From `specs/prototype/ux-polish.spec.md`:

> **Requirement: Non-Inverted Movement**
> All camera movement directions MUST match the user's intuitive expectation.
> Dragging left moves the view left. Dragging up moves the view up.

> **Scenario: Drag direction matches view movement**
> THEN the scene moves in the same direction as the drag
> (i.e. dragging left reveals content to the right, as in Google Maps)

The spec unambiguously names Google Maps as the reference: **drag left → scene
moves left → content to the right comes into view**.  In Google Maps the content
follows your cursor, so dragging left reveals the right side.  For that to work the
camera/pivot must move to the **right** (opposite direction to the drag).

### What the Code Does

`godot/scripts/camera_controller.gd`, lines 152–157:

```gdscript
var pan_amount: float = pan_speed * (_distance * 0.05 + 1.0)
# Drag right → pivot moves right; drag up (negative delta.y) → pivot moves forward.
_target_pivot += right * delta.x * pan_amount   # ← PLUS sign
_target_pivot -= backward * delta.y * pan_amount
_pivot = _target_pivot
```

With `delta.x < 0` (drag LEFT) and `right ≈ world +X`:

```
_target_pivot += (+X) * (negative delta.x) * pan_amount
              = _target_pivot - X * positive
              → pivot.x DECREASES  (camera moves LEFT)
```

Camera moves **LEFT** → all scene objects shift **RIGHT** on screen →
the LEFT side of the world comes into view, **not** the right.

This is the exact opposite of what the spec requires.

### Cross-check: Reference Implementation

The main-branch `camera_controller.gd` (at `/home/jsell/code/code-vis/`) uses the
**correct** minus sign:

```gdscript
# line 118: "Dragging left (delta.x < 0) moves pivot rightward → scene moves left"
_pivot -= right * delta.x * PAN_SPEED   # ← MINUS sign  ✓
```

With drag LEFT (delta.x < 0): `_pivot -= (+X)*(negative) = _pivot += (+X)*positive`
→ pivot moves **right** → camera moves right → scene scrolls left → reveals content
to the right. **Google Maps correct.**

The task-024 branch has the sign **flipped to plus**, inverting the behavior.

### What the Test Does (and why it does not catch the bug)

`godot/tests/test_camera_controls.gd`, line 167 (`test_pan_direction_not_inverted`):

```gdscript
# At phi = PI/2, camera.basis.x = world +X.
# Non-inverted: right drag → pivot.x increases.
return cam._pivot.x > 0.0
```

This test verifies `right drag → pivot.x > 0` — i.e. **pivot moves right on a
right drag** — and calls it "non-inverted."  But that is the **inverted** behavior:
for Google Maps style, right drag should move the pivot **left** (pivot.x < 0),
so the camera moves left and the scene shifts right (revealing right-side content).

The test passes because the test and the implementation agree with each other; they
are both wrong relative to the spec.

---

## What the Implementer Must Fix

**In `godot/scripts/camera_controller.gd`** — flip the sign on the X-axis pan:

```gdscript
# CURRENT (inverted):
_target_pivot += right * delta.x * pan_amount

# CORRECT (Google Maps style):
_target_pivot -= right * delta.x * pan_amount
```

The Y-axis line (`_target_pivot -= backward * delta.y * pan_amount`) may also need
a sign review for consistency, but the X-axis inversion is the confirmed failure.

**In `godot/tests/test_camera_controls.gd`** — fix `test_pan_direction_not_inverted`
to assert the correct direction:

```gdscript
# CURRENT (tests inverted behavior):
# Non-inverted: right drag → pivot.x increases.
return cam._pivot.x > 0.0

# CORRECT (Google Maps style):
# Non-inverted: right drag → pivot.x DECREASES (camera moves left, scene moves right).
return cam._pivot.x < 0.0
```

Also update the comment in the test header that maps `[Drag dir]` to
`test_pan_direction_not_inverted` — the test currently asserts the wrong predicate.

---

## Non-Blocking Notes

- Zoom toward cursor (`_zoom_toward_point`): sign convention (-1 = in, +1 = out)
  is internally consistent and correctly verified by all three zoom tests. ✓
- Orbit (`begin_orbit_at_world_point` / `_remap_orbit_pivot`): correctly remaps
  pivot to cursor world point and recomputes spherical coordinates without camera
  jump. ✓
- Smooth zoom: exponential interpolation `1 - pow(0.05, delta * zoom_smooth)` is
  well-implemented and tested. ✓
- Boundary clamping for `_theta` and `_distance`: tested at limits. ✓
- All 91/91 GDScript tests pass because the tests are consistent with the
  (incorrect) implementation — fixing the implementation will also require fixing
  the pan-direction test.