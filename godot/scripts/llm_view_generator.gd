class_name LLMViewGenerator
extends RefCounted

## Integrates with an LLM to convert natural language questions into ViewSpecs.
##
## The pipeline is:
##   question + graph  →  build_prompt()  →  LLM  →  parse_response()  →  ViewSpec
##
## The LLM receives:
##   - The human's natural-language question
##   - The list of node ids and names from the structural graph
##   - The complete list of valid view-spec primitives (from ViewSpec.VALID_OPS)
##
## The LLM emits a JSON object conforming to the ViewSpec format.
## parse_response() delegates to ViewSpec.from_dict() to enforce the fixed
## primitive set — no new rendering logic can be invented at runtime.
##
## Requirement: Question-Driven View Generation
##   The system MUST accept natural language questions and generate a spatial
##   view tailored to answering that specific question.
##
## Requirement: View Specs as Intermediate Representation
##   The LLM generates a view spec; the renderer interprets it.
##   The LLM does NOT generate raw 3D geometry.
##
## Requirement: Fixed Visual Primitive Set
##   The LLM selects from VALID_OPS; it does not invent new ones.

## Fixed set of visual primitives the LLM may select from.
## No new rendering logic is generated at runtime — this list is the contract.
const VALID_OPS: Array = ["show", "hide", "highlight", "arrange", "annotate", "connect"]


## Build a prompt string for the LLM containing the question and graph context.
##
## The prompt instructs the LLM to emit a JSON ViewSpec using only the
## fixed set of primitives defined in ViewSpec.VALID_OPS.  The node list
## gives the LLM enough context to identify relevant components without
## sending full source code.
##
## Returns a non-empty String ready to send to an LLM endpoint.
static func build_prompt(question: String, graph: Dictionary) -> String:
	var node_lines: Array = []
	for nd in graph.get("nodes", []):
		node_lines.append(
			'  - id: "%s", name: "%s", type: "%s"' % [
				nd.get("id", ""),
				nd.get("name", ""),
				nd.get("type", ""),
			]
		)

	var ops_list: String = ", ".join(VALID_OPS)
	var nodes_str: String = "\n".join(node_lines) if node_lines.size() > 0 else "  (none)"

	return (
		"You are a software architecture visualiser. "
		+ "Given a structural graph and a question, emit a JSON view specification.\n\n"
		+ "## Question\n"
		+ question + "\n\n"
		+ "## Available nodes\n"
		+ nodes_str + "\n\n"
		+ "## Available primitives\n"
		+ "Only these operations are valid: " + ops_list + "\n\n"
		+ "## Instructions\n"
		+ "Return ONLY a valid JSON object with this exact structure:\n"
		+ "{\n"
		+ '  "question": "<the original question>",\n'
		+ '  "operations": [\n'
		+ '    {"op": "<primitive>", ...args...}\n'
		+ "  ]\n"
		+ "}\n\n"
		+ "Primitive argument schemas:\n"
		+ '- show:      {"op": "show", "ids": ["node_id", ...]}\n'
		+ '- hide:      {"op": "hide", "ids": ["node_id", ...]}\n'
		+ '- highlight: {"op": "highlight", "ids": ["node_id", ...], "color": [r, g, b]}\n'
		+ '- arrange:   {"op": "arrange", "id": "node_id", "position": {"x": 0, "y": 0, "z": 0}}\n'
		+ '- annotate:  {"op": "annotate", "id": "node_id", "text": "label text"}\n'
		+ '- connect:   {"op": "connect", "source": "node_id", "target": "node_id"}\n\n'
		+ "Do not use any operation not listed above. "
		+ "Do not include any text outside the JSON object."
	)


## Parse an LLM text response into a validated ViewSpec dictionary.
##
## The LLM may return extra whitespace or markdown code fences; this method
## strips those before parsing.  JSON parsing failures return an empty spec
## so the caller always receives a valid ViewSpec structure.
##
## Enforces the fixed primitive set — unknown ops emitted by the LLM are
## silently dropped, ensuring no new rendering logic enters the renderer at runtime.
##
## Returns a Dictionary with "question" (String) and "operations" (Array).
static func parse_response(llm_text: String) -> Dictionary:
	var text: String = llm_text.strip_edges()

	# Strip markdown code fences if the LLM wrapped the JSON in ``` ... ```.
	if text.begins_with("```"):
		var first_newline: int = text.find("\n")
		var end_fence: int = text.rfind("```")
		if first_newline != -1 and end_fence > first_newline:
			text = text.substr(first_newline + 1, end_fence - first_newline - 1).strip_edges()

	var json := JSON.new()
	if json.parse(text) != OK:
		# Return an empty but structurally valid spec on parse failure.
		return _make_spec("", [])

	if not json.data is Dictionary:
		return _make_spec("", [])

	# Enforce the fixed primitive contract: drop any op not in VALID_OPS.
	return _make_spec(
		json.data.get("question", ""),
		json.data.get("operations", [])
	)


## Build a normalised view-spec Dictionary, filtering ops to VALID_OPS only.
## Unknown ops are silently dropped — no new rendering logic can be introduced.
static func _make_spec(question: String, raw_ops: Array) -> Dictionary:
	var ops: Array = []
	for op in raw_ops:
		if op is Dictionary and VALID_OPS.has(op.get("op", "")):
			ops.append(op)
	return {"question": question, "operations": ops}
