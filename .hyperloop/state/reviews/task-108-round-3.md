---
task_id: task-108
round: 3
role: verifier
verdict: fail
---
## Review: task-108 (third round — post tscn-fix)
Spec: specs/visualization/spatial-structure.spec.md@7a839cc34dd84819b28b93d8a6ffe88aa0dce0f1
Branch: hyperloop/task-108 (3 commits above main)

---

## Scope Check Output

```
NOTE: Pre-existing prohibited-mode patterns detected in files that originate from main
  (NOT introduced by this branch — attributed to their originating task, not to you):
  godot/scripts/understanding_overlay.gd  (origin: a2f9d139 feat(core): godot: evaluation mode — coupling and centrality visualization (#108))
  These are informational only and do NOT count as a FAIL for this branch.
OK: No prohibited (not-in-scope) features detected.
```

---

## run-all-checks.sh Summary

All 41 checks exit 0 **except**:

| Check | Exit | Note |
|---|---|---|
| check-report-scope-section.sh | 1 ✗ | Expected — worker-result.yaml not yet written |
| check-spec-ref-valid.sh | 1 ✗ | BLOCKING — see below |

All other 39 checks: EXIT 0 ✓

---

## BLOCKING ISSUE — Invalid Spec-Ref Trailer in Fix Commit

`check-spec-ref-valid.sh` fails with:

```
FAIL: Spec-Ref commit '359dbcb1d7f64009e6dd64084a8bcbb5fa325cb4' does not exist in this repo.
      (Spec-Ref: specs/visualization/spatial-structure.spec.md@359dbcb1d7f64009e6dd64084a8bcbb5fa325cb4)
OK: specs/visualization/spatial-structure.spec.md@7a839cc34dd84819b28b93d8a6ffe88aa0dce0f1 — commit and file both resolve.

Checked 2 Spec-Ref(s); 1 unresolvable.
```

The fix commit `b6aca5e0` ("fix(spatial): remove dangling first_person_camera_controller
from main.tscn") carries:

```
Spec-Ref: specs/visualization/spatial-structure.spec.md@359dbcb1d7f64009e6dd64084a8bcbb5fa325cb4
```

`git cat-file -t 359dbcb1d7f64009e6dd64084a8bcbb5fa325cb4` returns `blob` — this hash
identifies the blob object for the spec file content, not a commit. The check requires a
commit hash (`git cat-file -e hash^{commit}`) so `b6aca5e0`'s Spec-Ref fails validation.

**What is needed:** Rewrite the fix commit with the correct Spec-Ref:

```
Spec-Ref: specs/visualization/spatial-structure.spec.md@7a839cc34dd84819b28b93d8a6ffe88aa0dce0f1
```

(This is the same valid commit hash used by the other two commits on this branch and is
confirmed by `check-spec-ref-staleness.sh` to be identical to HEAD.)

---

## Prior Blocking Issue — RESOLVED

The dangling `[ext_resource]` reference to
`res://scripts/first_person_camera_controller.gd` in `godot/scenes/main.tscn` that
caused the second-round FAIL has been correctly addressed:

- `check-tscn-no-dangling-references.sh` exits 0.
- `godot-compile.sh` reports "Godot project compiles successfully" with no parse errors.
- `git diff main..HEAD -- godot/scenes/main.tscn` is empty; the scene file is identical
  to its state on main.

---

## Mandatory Check Outputs (verbatim)

### check-lod-opacity-animation.sh
```
NOTE: godot/scripts/lod_manager.gd (pre-existing on main) uses binary .visible toggle without opacity
  animation — this is a pre-existing spec gap, not attributed to this branch.
OK: Branch LOD files include Tween/modulate.a opacity animation.
```

### check-aggregate-edge-impl.sh
```
OK: Aggregate-edge implementation found.
  godot/scripts/aggregate_edge_renderer.gd
  godot/scripts/main.gd
```

### check-lod-level-tests.sh
```
LOD/visualization files modified by this branch:
  godot/scripts/main.gd

OK: 'Near (full detail)' LOD level test found.
  godot/tests/test_spatial_structure.gd
OK: 'Medium (module structure)' LOD level test found.
  godot/tests/test_spatial_structure.gd
OK: 'Far (aggregate edges / bounded context)' LOD level test found.
  godot/tests/test_spatial_structure.gd

OK: All LOD levels (Near / Medium / Far) have behavioral test coverage.
```

### check-compute-functions-called-from-entry-point.sh
```
Entry point file: extractor/extractor.py
OK: compute_layout() is called from extractor/extractor.py
OK: compute_loc() is called from extractor/extractor.py
```

### check-typeddict-fields-extractor-tested.sh
```
Schema file:     extractor/schema.py
test_extractor:  extractor/tests/test_extractor.py
test_schema:     extractor/tests/test_schema.py

Literal values found in schema TypedDicts:
  "bounded_context"
  "cross_context"
  "internal"
  "module"
  "spec"

OK: "bounded_context" — covered in test_extractor.py (9 occurrence(s))
OK: "cross_context" — covered in test_extractor.py (3 occurrence(s))
OK: "internal" — covered in test_extractor.py (2 occurrence(s))
OK: "module" — covered in test_extractor.py (3 occurrence(s))
OK: "spec" — covered in test_extractor.py (8 occurrence(s))

OK: All Literal type values have coverage in test_extractor.py.
```

### check-spec-ref-staleness.sh
```
OK (no drift): specs/visualization/spatial-structure.spec.md is identical at Spec-Ref
  (7a839cc34dd84819b28b93d8a6ffe88aa0dce0f1) and HEAD.
SUMMARY: No spec drift detected across all Spec-Ref references.
```

---

## Spec-Drift Summary

No spec drift. The committed spec at Spec-Ref hash `7a839cc34dd84819b28b93d8a6ffe88aa0dce0f1`
is identical to HEAD.

---

## Requirement-by-Requirement Table

| Scenario | Status | Notes |
|---|---|---|
| 3D Interactive Navigation — First-person exploration | COVERED | Orbital camera; FPS code removed; orbit tests in test_spatial_structure.gd; tscn reverted |
| Structure as Persistent Geography — Structural elements | COVERED | Pre-existing; anchors, positions, containment, translucency asserted in tests |
| Scale Through Zoom — Far (aggregate edges) | COVERED | aggregate_edge_renderer.gd groups by context pair, weight proportional to count; 5 behavioral tests |
| Scale Through Zoom — Medium (module fade) | PRE-EXISTING GAP | Binary .visible in lod_manager.gd; attributed to originating task by check-lod-opacity-animation.sh; not this branch's remit |
| Scale Through Zoom — Near (full detail) | COVERED | _apply_near(); test_near_distance_shows_all_nodes + test_near_distance_shows_internal_edges |
| Smooth transitions — aggregate edges | COVERED | Tween on albedo_color:a in show_edges/hide_edges |
| Smooth transitions — individual edges | PRE-EXISTING GAP | Binary .visible via lod_manager.gd; pre-existing, not this branch |
| Cluster Collapsing (all 4 scenarios) | OUT OF PROTOTYPE SCOPE | Not evaluated |

All spec requirements (except pre-existing gaps and out-of-scope clusters) are correctly
implemented and tested. The sole FAIL driver is the invalid Spec-Ref blob hash in commit
`b6aca5e0`.

---

## FAIL Reason

`check-spec-ref-valid.sh` exits 1. Commit `b6aca5e0` carries a Spec-Ref that resolves to
a blob object (`359dbcb1d7f64009e6dd64084a8bcbb5fa325cb4`), not a commit. The check
requires `hash^{commit}` to resolve; it does not.

**Fix:** Amend or re-author `b6aca5e0` to use the correct Spec-Ref commit hash:
`7a839cc34dd84819b28b93d8a6ffe88aa0dce0f1` (the hash used by the other two commits on
this branch and confirmed valid by `check-spec-ref-valid.sh`).