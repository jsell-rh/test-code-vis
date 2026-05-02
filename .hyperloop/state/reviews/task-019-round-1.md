---
task_id: task-019
round: 1
role: verifier
verdict: fail
---
## Scope Check Output

OK: No prohibited (not-in-scope) features detected.

## Check Sync

OK: All check scripts from main are present and content-identical in working tree (61 checked).

## run-all-checks.sh Summary

Four checks exit non-zero:

| Check | Result | Classification |
|---|---|---|
| check-rebased-onto-main.sh | FAIL | **Implementer fix required** |
| check-main-local-vs-remote.sh | FAIL | Orchestrator configuration |
| check-main-not-diverged.sh | FAIL | Orchestrator configuration (same root cause) |
| check-cycle-gate.sh | FAIL | Orchestrator configuration (banned task-031 open on hyperloop/state) |
| All other checks (57+) | EXIT 0 | — |

## Mandatory Check Outputs (verbatim)

### check-rebased-onto-main.sh

```
FAIL: Branch 'hyperloop/task-019' is NOT rebased onto origin/main.

  Fork point (merge-base): 1c869b5
  origin/main HEAD:        0f73f57
  Commits on main not in branch: 2

  RISK: Merging this branch as-is would REVERT all 2 commit(s)
  that main added after 1c869b5. Inspect what would be lost:
    git log 1c869b5..origin/main --oneline

  Fix:
    git fetch origin main:main
    git rebase origin/main
    # During conflict resolution:
    #   KEEP all functions/files main added (the incoming 'theirs' side).
    #   Apply your changes ON TOP — never choose 'ours' to discard main work.
    # After rebase completes:
    bash .hyperloop/checks/check-run-tests-suite-count.sh   # guard against suite regression
    bash .hyperloop/checks/run-all-checks.sh
```

### Commits on origin/main not in branch

```
0f73f57f process: add rebase-only fix protocol and verifier-stops-reading warning
08dd753f feat(core): schema — symbol table data on nodes (#219)
```

### check-run-tests-suite-count.sh

```
OK: _run_suite() count on branch (20) >= origin/main (19).
```

### check-spec-ref-staleness.sh

```
OK (no drift): specs/visualization/spatial-structure.spec.md is identical at
Spec-Ref (7a839cc34dd84819b28b93d8a6ffe88aa0dce0f1) and HEAD.
SUMMARY: No spec drift detected across all Spec-Ref references.
```

### check-sync-divergence-impact.sh

```
OK: No stale check scripts found — check-checks-in-sync.sh should pass.
```

### check-main-local-vs-remote.sh

```
FAIL (ORCHESTRATOR): local main (5d6a7ed9...) is AHEAD of origin/main (0f73f57f...).
Fix: git push origin main  (orchestrator action — not an implementer fix).
```

## Verdict: FAIL — Rebase Required

Per the mandatory protocol, the verifier **stops reading** when
`check-rebased-onto-main.sh` exits non-zero. Implementation quality is not
evaluated in this cycle.

**Why this matters (not a trivial race condition):** The 2 missing commits
include `08dd753f feat(core): schema — symbol table data on nodes (#219)`, a
3,292-line insertion commit that modifies `godot/scripts/main.gd`,
`godot/tests/test_spatial_structure.gd`, and `extractor/extractor.py` —
the same files this branch modified. Without rebasing, merging would silently
revert all of that work.

## Orchestrator Issues (for orchestrator awareness — not implementer issues)

Three additional check failures are orchestrator configuration problems:

1. **check-main-local-vs-remote.sh / check-main-not-diverged.sh**: Local main
   is ahead of origin/main. Fix: `git push origin main` from the main worktree.

2. **check-cycle-gate.sh**: Banned task-031 remains open on the `hyperloop/state`
   branch. Fix per check output:
   ```
   git checkout hyperloop/state
   sed -i 's/^status:.*/status: closed/' .hyperloop/state/tasks/task-031.md
   sed -i 's/^spec_ref:.*/spec_ref: null/' .hyperloop/state/tasks/task-031.md
   git add .hyperloop/state/tasks/task-031.md
   git commit -m 'chore(tasks): permanently close banned task task-031'
   git push origin hyperloop/state
   git checkout main
   ```

## What the Implementer Must Do

This is a **process-only fix** — no implementation changes are needed, only a
rebase. Execute the REBASE-ONLY FIX PROTOCOL exactly:

```bash
git fetch origin main:main
git rebase origin/main
# 08dd753f will conflict in godot/scripts/main.gd and
# godot/tests/test_spatial_structure.gd — keep ALL incoming changes from
# main (schema/symbol-table work) and re-apply your edge re-routing commits on top.
# Do NOT choose 'ours' in any conflict — main's work must be preserved.
git checkout origin/main -- .hyperloop/checks/
bash .hyperloop/checks/check-checks-in-sync.sh     # must exit 0
bash .hyperloop/checks/check-rebased-onto-main.sh  # must exit 0
bash .hyperloop/checks/run-all-checks.sh           # must exit 0
```

Conflict warning: `main.gd` was modified by both the schema commit (08dd753f)
and this branch's edge re-routing fix. Resolve by keeping all schema additions
from main and applying the edge re-routing changes from this branch on top.
Use `git diff origin/main...HEAD -- godot/scripts/main.gd` to identify which
hunks belong to this branch.

Commit message template after resolving:

```
chore(process): rebase onto origin/main — incorporate schema commit

Task-Ref: task-019
Spec-Ref: specs/visualization/spatial-structure.spec.md@7a839cc34dd84819b28b93d8a6ffe88aa0dce0f1
```

After the rebase, the verifier will evaluate whether the edge re-routing
implementation in commit `70306cf7` satisfies the THEN-clauses that were MISSING
in the prior cycle.