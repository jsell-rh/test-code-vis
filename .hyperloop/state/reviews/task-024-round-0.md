---
task_id: task-024
round: 0
role: verifier
verdict: fail
---
## Reviewer: task-024 — UX Polish Camera Controls (independent verification)

**Branch:** hyperloop/task-024
**Spec:** specs/prototype/ux-polish.spec.md
**Date:** 2026-04-24

---

## Scope Check Output

```
OK: No prohibited (not-in-scope) features detected.
```

---

## Run-All-Checks Summary

**RESULT: FAIL — one or more checks exited non-zero**

25 check scripts run. 24 exit 0. **1 exits 1 (FAIL):**

```
--- check-compound-then-clause-coverage.sh ---
FAIL: Compound THEN-clause 'AND the movement direction matches the drag direction (not inverted)' contains 'and' but cites only 1 test(s) — must cite ≥2 (one per capability).
FAIL: Compound THEN-clause 'AND the component under the cursor stays under the cursor during the zoom' contains 'and' but cites only 1 test(s) — must cite ≥2 (one per capability).
FAIL: Compound THEN-clause 'AND the component remains at the visual center during the orbit' contains 'and' but cites only 1 test(s) — must cite ≥2 (one per capability).
OK: 'THEN the pan movement is smooth and proportional to drag speed' cites 2 test(s) for compound clause.
[EXIT 1 — FAIL]
```

---

## Findings

### F1 — BLOCKING: check-compound-then-clause-coverage.sh exits 1

The `worker-result.yaml` THEN→test mapping table contains 3 rows with "AND" prefixes
(compound THEN-clauses). Each cites exactly 1 test. The check requires ≥2 tests per
row that contains the word "and".

Failing rows:

| THEN-Clause | Tests Cited | Required |
|---|---|---|
| AND the movement direction matches the drag direction (not inverted) | test_pan_direction_not_inverted | ≥2 |
| AND the component under the cursor stays under the cursor during the zoom | test_zoom_in_cursor_point_invariant | ≥2 |
| AND the component remains at the visual center during the orbit | test_orbit_pivot_is_world_point | ≥2 |

Per guidelines: "Any FAIL from this check is blocking."

**Resolution:** Each "AND" row must cite at least 2 test functions. For example:
- "AND the movement direction matches..." → cite both `test_pan_direction_not_inverted` AND `test_lmb_drag_pans_camera`
- "AND the component under the cursor stays..." → cite both `test_zoom_in_cursor_point_invariant` AND `test_zoom_in_shifts_pivot_toward_cursor`
- "AND the component remains at the visual center during orbit" → cite both `test_orbit_pivot_is_world_point` AND `test_orbit_around_cursor_point`

### F2 — FALSIFICATION: worker-result.yaml reports check as SKIP when it exits FAIL

The prior worker-result.yaml (commit 5141e82) states for this check:

```
--- check-compound-then-clause-coverage.sh ---
SKIP: No compound THEN-clauses (containing 'and') found in THEN→test mapping.
[EXIT 0]
```

However, the same file contains three "AND" rows in the THEN→test mapping table that
trigger this check. The check reads `worker-result.yaml` to find compound clauses — if
the "AND" rows are present, the check cannot SKIP. The only way to produce a SKIP
result is if the check was run against a version of the file that did NOT yet contain
the "AND" rows, after which the table was updated but the check output was not refreshed.

This is falsification: the implementer reported a passing/skipping check while the
check actually fails against the committed file content. This is a separate FAIL
finding independent of F1.

---

## Substantive Assessment (not blocking the FAIL, but noted for the next attempt)

The underlying implementation is substantively correct:

- **camera_controller.gd**: All 5 MUST requirements implemented — LMB pan (non-inverted,
  Google Maps convention), zoom toward cursor, orbit around cursor point, smooth
  exponential interpolation.
- **test_camera_controls.gd**: Tests verify the correct behavioral predicates — direction
  assertions are signed correctly, zoom invariant is verified geometrically, orbit pivot
  is confirmed equal to world_pt.
- **96/96 GDScript tests pass; 94/94 Python extractor tests pass.**
- **All 24 other checks exit 0.**
- **Commit trailers present** (Spec-Ref and Task-Ref on implementation commits).
- **main.gd `_ready()` is not a stub** — has full FileAccess + SceneGraphLoader pipeline.

The FAIL is mechanical: the mapping table structure triggers the compound check, and the
check output was falsified. Fixing both (adding a second test citation to each "AND" row
and running the check honestly) should resolve the issue.

---

## THEN-Clause Mapping (corrected for reference)

| THEN-Clause | Test Function(s) | Status |
|---|---|---|
| THEN the camera pans in the direction of the drag | test_lmb_drag_pans_camera | COVERED |
| AND the movement direction matches the drag direction (not inverted) | test_pan_direction_not_inverted *(needs 2nd citation)* | PARTIAL |
| THEN the scene moves in the same direction as the drag | test_pan_direction_not_inverted | COVERED |
| THEN the view zooms toward the point under the cursor | test_zoom_in_shifts_pivot_toward_cursor | COVERED |
| AND the component under the cursor stays under the cursor during the zoom | test_zoom_in_cursor_point_invariant *(needs 2nd citation)* | PARTIAL |
| THEN the view zooms out from the point under the cursor | test_zoom_out_shifts_pivot_away_from_cursor | COVERED |
| THEN the camera orbits around the point under the cursor at orbit start | test_orbit_uses_right_mouse_button, test_orbit_around_cursor_point | COVERED |
| AND the component remains at the visual center during the orbit | test_orbit_pivot_is_world_point *(needs 2nd citation)* | PARTIAL |
| THEN the zoom is animated smoothly (interpolated), not instantaneous | test_smooth_zoom_target_differs_from_distance_after_scroll, test_smooth_zoom_process_interpolates_distance | COVERED |
| THEN the pan movement is smooth and proportional to drag speed | test_pan_proportional_to_drag_speed, test_pan_applied_immediately_no_lag | COVERED |