---
id: task-123
title: Extractor — owner annotation from CODEOWNERS
spec_ref: specs/core/visual-primitives.spec.md
status: not-started
phase: null
deps: [task-122, task-003]
round: 0
branch: null
pr: null
---

Parse the repository's CODEOWNERS file and annotate each module and
bounded-context node with the `owner` field defined in task-122, so the
ownership tint facet (task-124) has team data at render time.

Covers `specs/core/visual-primitives.spec.md` — Requirement: Overlay/Facet
Composition, Scenario: Switching from structure view to ownership view:

This is the cheapest ownership source: most repositories already maintain a
CODEOWNERS file. No git blame or external API is needed.

---

**CODEOWNERS file location** — search in priority order:
1. `{codebase_root}/.github/CODEOWNERS`
2. `{codebase_root}/CODEOWNERS`
3. `{codebase_root}/docs/CODEOWNERS`

If none found and `--owners` is active: log a warning to stderr, set
`owner: null` on all annotated nodes, and continue. Do not abort extraction.

**Fallback manifest** — accept `--owners-manifest <path>` for a YAML file:
```yaml
"iam/**": "@org/identity-team"
"billing/**": "@org/payments-team"
```
When provided, this takes precedence over any CODEOWNERS file.

---

**CODEOWNERS parsing** — last matching rule wins (GitHub/GitLab semantics):

1. Read lines; skip blank lines and lines beginning with `#`.
2. Each non-comment line: `<pattern>  <owner1> [<owner2> ...]`.
3. Build an ordered list of `(pattern, primary_owner)` tuples.
   Use only the FIRST owner token (the primary owner) per rule.
4. To match a file path, iterate rules in order; record the last match.
5. Use `pathlib.PurePosixPath` and `fnmatch.fnmatch` for glob matching:
   - A pattern not starting with `/` is treated as recursive: prepend `**/`
     before matching.
   - A pattern starting with `/` is anchored to the codebase root.
   - `*` matches within a single path segment; `**` matches any depth.

Use only `pathlib`, `fnmatch`, and `re`. No third-party pattern libraries.

---

**Module node annotation**:

For each node with `type == "module"`:
1. Resolve the module's source directory (reuse task-003's path resolution:
   e.g. module id `"iam.domain"` → directory `iam/domain/` or file
   `iam/domain.py`).
2. Match every `.py` file in that directory against CODEOWNERS rules.
3. The module's owner = the primary owner from the LAST matching rule across
   all its files. If no rule matches any file: `owner = null`.

**Bounded-context node annotation**:

For each `bounded_context` node:
1. Collect owners of all direct child module nodes (after module annotation).
2. If all modules share one non-null owner: that owner is the context's owner.
3. If modules have mixed owners: use the most-frequent non-null owner.
   Tie-break: lexicographically first string.
4. If all child modules have `owner: null`: set context `owner = null`.
5. If the context has no child modules: `owner = null`.

Set `node["owner"]` on every `module` and `bounded_context` node. Nodes with
no CODEOWNERS match receive `node["owner"] = null` (explicitly null — NOT
absent), so Godot can distinguish "no match" from "not annotated."

---

**CLI integration** — opt-in:

- Flag `--owners`: enable CODEOWNERS parsing.
- Flag `--owners-manifest <path>`: use YAML manifest instead.
- When neither flag is active: skip entirely; no `owner` field is added to any
  node (field is absent in JSON output).

**Output writer integration** — add a pipeline step in task-085's writer:
"Owner annotation (task-123) — runs after module discovery (task-003),
before layout (task-005), when `--owners` or `--owners-manifest` is active."

---

**Edge cases**:
- Windows line endings in CODEOWNERS: strip `\r` before parsing.
- Rule line with no owner tokens: skip (malformed rule, no-match).
- Module with no discovered `.py` files: `owner = null`.
- Bounded context with zero child modules: `owner = null`.

Use only Python standard library. No external dependencies.
