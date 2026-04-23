# Moldable Views Specification

## Purpose
Define how LLM-powered, question-driven views allow the human to ask questions and receive purpose-built spatial visualizations in response.

## Requirements

### Requirement: Question-Driven View Generation
The system MUST accept natural language questions and generate a spatial view tailored to answering that specific question.

#### Scenario: Architectural question
- GIVEN a loaded software system
- WHEN the human asks "how does authentication work?"
- THEN the system generates a view focused on auth-related components
- AND irrelevant components are hidden or de-emphasized
- AND the relevant components are arranged to answer the question

#### Scenario: Impact question
- GIVEN a loaded software system
- WHEN the human asks "what depends on the user database?"
- THEN the system generates a view showing the user database and all its dependents
- AND the dependency relationships are spatially clear

### Requirement: View Specs as Intermediate Representation
The system MUST use a structured view specification as the intermediate representation between the LLM and the 3D renderer. The LLM generates a view spec; the renderer interprets it.

#### Scenario: LLM produces view spec
- GIVEN a human question and the system's structural graph
- WHEN the LLM processes the question
- THEN it emits a structured view specification (not raw 3D geometry)
- AND the view spec controls which elements are shown, hidden, highlighted, and how they are arranged
- AND the 3D renderer interprets the view spec into a spatial scene

### Requirement: Fixed Visual Primitive Set
The set of visual primitives available in view specs MUST be fixed and finite. The LLM selects from available primitives; it does not invent new ones.

#### Scenario: LLM uses existing primitives
- GIVEN a question that requires a novel visualization
- WHEN the LLM generates a view spec
- THEN it composes the answer from the existing set of primitives (show, hide, highlight, arrange, annotate, connect)
- AND no new rendering logic is generated at runtime
