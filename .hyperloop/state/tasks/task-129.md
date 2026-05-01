---
id: task-129
title: "[DEFERRED] system-purpose.spec.md — all requirements out of prototype scope"
spec_ref: "specs/core/system-purpose.spec.md@f1f52d804d7ad3bdd7c18b8aeea74cbfd01cfeca"
status: closed
phase: null
deps: []
round: 0
branch: null
pr: null
pr_title: null
pr_description: null
---

Scope review performed against `specs/prototype/prototype-scope.spec.md` § "Not In
Scope". All three requirements in `specs/core/system-purpose.spec.md` are deferred to
a future phase. No prototype implementation tasks are created from this spec.

## Requirement-by-Requirement Ruling

### Requirement: Understanding Without Writing Code
> "The system MUST provide humans with a concrete understanding of how a software
> system is actually built, without requiring them to read or write any of its source
> code."

Pure vision statement — describes the high-level goal of the eventual product, not a
discrete feature to implement. The prototype as a whole tests this hypothesis by
design; no additional feature is required.

**Ruling: no task — pure goal statement, no implementable scope.**

### Requirement: Spec-Driven Context
> "The system MUST accept human-authored specifications as input alongside the
> codebase, treating specs as the authoritative expression of human intent."

Requires **spec extraction** — parsing and aligning spec files against a codebase.
`specs/prototype/prototype-scope.spec.md` line 94 explicitly excludes this:

> "spec extraction is NOT implemented"

**Ruling: deferred — spec extraction is NOT IN SCOPE for the prototype.**

### Requirement: Support the Architecture Feedback Loop
> "The system MUST support the iterative loop of: human writes spec, agent builds,
> human evaluates, human refines spec."

The three evaluation sub-features named in the scenarios are:
- "determine whether the build matches the spec" → **conformance mode** (NOT IN SCOPE,
  `prototype-scope.spec.md` line 89)
- "determine whether the build is architecturally sound regardless of spec compliance"
  → **evaluation mode** (NOT IN SCOPE, `prototype-scope.spec.md` line 90)
- "explore the impact of potential changes before updating the spec" → **simulation
  mode** (NOT IN SCOPE, `prototype-scope.spec.md` line 91)

**Ruling: deferred — all sub-features are NOT IN SCOPE for the prototype.**

## Resolution

`specs/core/system-purpose.spec.md` is a vision document. Revisit when
`specs/prototype/prototype-scope.spec.md` is revised to lift the restrictions on
spec extraction and understanding modes.
