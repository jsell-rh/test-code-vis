---
id: task-103
title: Schema — add data_flow_spines as 5th top-level key
spec_ref: specs/extraction/scene-graph-schema.spec.md
status: not-started
phase: null
deps: [task-061, task-081, task-085]
round: 0
branch: null
pr: null
---

Formally define `data_flow_spines` as the fifth permitted top-level key in the JSON
scene graph schema, resolving the inconsistency between the schema specification
("no other top-level fields are present" — task-061) and the output writer
(task-085 already emits `data_flow_spines`).

Covers `specs/extraction/scene-graph-schema.spec.md` — Requirement: Schema Structure
("The JSON scene graph MUST contain nodes, edges, metadata, and clusters as top-level
fields") as extended to accommodate data flow spine output from
`specs/core/visual-primitives.spec.md` — Requirement: Data Flow Spine Extraction.

---

**Schema document update** — edit `extractor/schema.md`:

1. In the "Top-level structure" section, replace the four-key description with five:

   ```
   Required top-level keys (in order):
     nodes           (array)   — node entries
     edges           (array)   — edge entries
     metadata        (object)  — extraction metadata
     clusters        (array)   — pre-computed cluster suggestions
     data_flow_spines (array)  — intraprocedural data flow chains
                                 (MAY be empty [] if --no-data-flow is passed)
   ```

   No other top-level keys are permitted.

2. Add a new section "## Data Flow Spines" documenting the spine entry shape:

   ```
   Each spine entry (object):
     function_id   (string)  — id of the function this spine belongs to;
                               matches a node id of type "function".
     steps         (array)   — ordered list of step objects:
       kind        (string)  — one of: "param", "operation", "call_site",
                               "return_value"
       ref         (string)  — node id or expression label for this step
       label       (string)  — human-readable description of this step
     interprocedural (array) — zero or one entries for one-call-deep flow:
       callee_id   (string)  — node id of the called function
       param_label (string)  — name of the argument passed
       return_label (string) — name of the local variable receiving the return value
   ```

3. Add a worked example showing a spine for a simple transform function:

   ```json
   {
     "function_id": "iam.domain.process_order",
     "steps": [
       { "kind": "param",         "ref": "input", "label": "parameter input: Order" },
       { "kind": "operation",     "ref": "validate_input", "label": "call validate_input(input)" },
       { "kind": "operation",     "ref": "enrich_order",   "label": "call enrich_order(validated)" },
       { "kind": "return_value",  "ref": "result", "label": "return result: ProcessedOrder" }
     ],
     "interprocedural": [
       {
         "callee_id": "iam.domain.validate_input",
         "param_label": "input",
         "return_label": "validated"
       }
     ]
   }
   ```

---

**Validator update** — extend the Python validator (from task-085):

1. Assert `data_flow_spines` is a list (it is always present; may be empty).
2. For each spine entry, assert: `function_id` (string), `steps` (list),
   `interprocedural` (list). Steps and interprocedural entries are validated
   for required sub-fields.
3. The validator update is additive — no existing validation rules are removed.

---

**Scenario alignment** — the five-key output is now consistent with:
- task-066 (four-key baseline: nodes, edges, metadata, clusters)
- task-085 (five-key extension: adds data_flow_spines)
- task-081 (spine computation that produces the data)

No extractor logic changes. No Godot changes. Schema documentation only.
