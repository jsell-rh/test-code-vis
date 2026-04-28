---
id: task-042
title: Extractor — classify spec item divergence type
spec_ref: specs/core/understanding-modes.spec.md
status: not-started
phase: null
deps: [task-041, task-029]
round: 0
branch: null
pr: null
---

Extend the Python extractor to classify each `spec_item` node as `"realized"`,
`"merged"`, or `"absent"` and emit that value in the `divergence_type` field defined
by task-041. Without this classification, Conformance Mode cannot distinguish a spec
requirement that was merged into a broader component from one that simply has no
implementation anywhere.

Covers `specs/core/understanding-modes.spec.md` — Requirement: Conformance Mode,
Scenario: Spec-divergent implementation ("the specific nature of the divergence is
clear (merged vs. separate)"):

After the name-matching pass from task-029 has emitted all `spec_to_code` edges,
classify each `spec_item` node as follows and set `divergence_type` before writing
the JSON output:

**`"absent"`** — no `spec_to_code` edge was found for this spec item (name matching
produced no candidate code node). The spec requirement has no implementation anywhere
in the codebase.

**`"realized"`** — a `spec_to_code` edge exists AND the target code node is plausibly
dedicated to this spec item's scope. Apply this classification when ALL of the
following hold:
- A `spec_to_code` edge exists from this spec_item to a code node.
- The code node's name contains at least one content word from the spec item's
  requirement heading (e.g. spec item "Payment Processing" → code node "payment"
  or "payment_service"). Use case-insensitive substring matching; ignore common stop
  words (a, an, the, for, of, in, and, or, to, is, be, as, at, by, that).
- The same code node is NOT already set as the `"realized"` target of a different
  spec_item node (i.e. it is not shared across two spec items' realizations).

**`"merged"`** — a `spec_to_code` edge exists BUT the target code node fails one or
more of the `"realized"` conditions above:
- The code node's name does not contain any content word from the spec item heading
  (the match was a false positive — the spec item's concern is embedded but not
  reflected in the node's primary identity), OR
- The same code node is already the `"realized"` target of a different spec_item
  (two requirements are collapsed into one component).

Classification order: process nodes in alphabetical id order so that when two spec
items compete for the same code node, the alphabetically earlier spec_item wins
`"realized"` and the later one gets `"merged"`.

Set `divergence_type` on each `spec_item` node object before calling the validator
and writing the output file.

Output remains valid per the extended schema from task-041.
Use only Python standard library; no external NLP or ML libraries.
