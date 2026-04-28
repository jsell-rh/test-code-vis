# Orthogonal Independence Specification

## Purpose
Define how the system makes structural independence visible. Dependency visualization answers "what depends on what?" — this spec answers the complement: "what is independent of what?" Making independence a first-class visual concept lets the human identify safe change boundaries, understand concurrency of development, and reason about blast radius before it happens.

Inspired by Harel's AND-decomposition in statecharts: orthogonal components are those whose internal behavior does not affect each other.

## Requirements

### Requirement: Independence Detection
The extractor MUST identify groups of modules within each bounded context that are structurally independent — sharing no direct or transitive internal dependencies.

#### Scenario: Two independent module clusters
- GIVEN a bounded context with modules A, B, C, D
- AND A imports B, C imports D, but neither {A,B} nor {C,D} imports the other
- WHEN independence analysis runs
- THEN {A,B} and {C,D} are identified as independent groups
- AND each module carries its group identifier in the scene graph

#### Scenario: Fully connected context
- GIVEN a bounded context where every module transitively depends on every other
- WHEN independence analysis runs
- THEN the entire context is a single group
- AND no independence separation is applied

### Requirement: Spatial Separation of Independent Groups
Independent groups within a bounded context MUST be spatially separated so that independence is visible without interaction.

#### Scenario: Visual gap between independent groups
- GIVEN a bounded context containing two independent groups
- WHEN the context is rendered
- THEN the groups occupy distinct spatial regions within the context's volume
- AND a visible gap separates the groups
- AND modules within each group remain close to each other (coupling-aware layout still applies within groups)

#### Scenario: Smooth regrouping on data change
- GIVEN a scene graph is loaded and rendered
- WHEN a new extraction produces different independence groups (e.g. a new import bridges two formerly independent groups)
- THEN nodes animate smoothly to their new positions
- AND the transition preserves spatial continuity — nodes slide rather than jump

### Requirement: Independence as Queryable Property
The human MUST be able to select a module and see its orthogonal complement — everything that can change without affecting it.

#### Scenario: Selecting a module shows its independent peers
- GIVEN the human selects module A
- WHEN independence information is displayed
- THEN all modules in other independence groups within the same bounded context are highlighted
- AND modules in A's own group are visually distinguished as "co-dependent"
- AND the transition between default and independence-highlighted states is animated smoothly

#### Scenario: Cross-context independence
- GIVEN the human selects module A in context X
- WHEN independence is displayed at the context level
- THEN bounded contexts with no transitive dependency on context X are highlighted as fully independent
- AND the highlight animates in from the selected module outward
