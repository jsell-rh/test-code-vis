---
task_id: task-078
round: 1
role: implementer
verdict: fail
---
## INVALID ASSIGNMENT — FEATURE ALREADY ON MAIN

**Task:** task-078 — "Extractor — symbol table extraction"
**Spec:** specs/core/visual-primitives.spec.md

### Assigned Feature Is Already Implemented on Origin/Main

The assigned feature — Symbol Table Extraction (`extract_symbols()`) — was implemented by
task-023 and merged to origin/main at commit `20461a84`
("feat(extractor): add symbol table extraction and node symbols schema field (#234)").

Verification:
```
$ git grep "def extract_symbols" origin/main -- extractor/
origin/main:extractor/extractor.py:def extract_symbols(src_path: Path, nodes: list[Node]) -> None:
```

Per the FEATURE EXISTENCE CHECK — STOP PROTOCOL, no implementation code was written.
The branch was reset to origin/main tip.

```
$ git log --oneline origin/main..HEAD
(no output — zero commits above main)
```

### Branch State

- 0 commits above origin/main
- No implementation files added or modified
- Branch HEAD = 9a83afdb (origin/main tip)

### Prior Round Context

The prior implementer (Round 1) implemented:
1. Data Flow Spine Extraction (build_data_flow_spines()) — spec section: Requirement: Data Flow Spine Extraction
2. Port Primitive rendering (Godot) — spec section: Requirement: Port Primitive

Both are legitimate features not yet on main, but NEITHER is the assigned task.
The prior verifier correctly classified this as WRONG-FEATURE FAIL.

Per STOP PROTOCOL: no rebase-and-resubmit with wrong-feature work.
Branch reset to origin/main tip; FAIL report submitted instead.

### Orchestrator Action Required

One of the following:
1. Close task-078 — reassign to a new task ID that correctly describes the
   deliverable (Data Flow Spine + Port Primitive, or each as a separate task).
2. Amend the task definition — update the task-078 title and spec section to match
   what the prior implementer built, then re-review the prior implementation.
3. Discard the prior work — if neither Data Flow Spine nor Port Primitive are
   needed at this time, close task-078 with no deliverable.

The prior Port Primitive implementation was PARTIAL (missing port direction distinction
and edge routing to ports). If that work is to be salvaged, it needs a correct task
assignment and the two missing THEN-clauses must be addressed.

### No Implementation Code Written This Round