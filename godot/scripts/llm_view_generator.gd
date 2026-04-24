class_name LlmViewGenerator
extends RefCounted

## LLM View Generator — Stage 1 of the moldable-views pipeline.
##
## Converts a natural-language question into a structured view specification
## that the SceneInterpreter (Stage 2) applies to the live 3D scene.
##
## The fixed visual primitive set is: show, hide, highlight, arrange, annotate, connect.
## The LLM MUST select from this finite list — no new rendering logic is generated at runtime.
##
## Pipeline:
##   build_prompt(question, graph) → String  (sent to LLM)
##   parse_response(response)      → Dictionary  (consumed by SceneInterpreter.apply_spec)

## The complete, fixed set of visual primitives available in view specs.
## The LLM selects from this list; it cannot invent new primitives.
const VALID_OPS: Array = ["show", "hide", "highlight", "arrange", "annotate", "connect"]


## Build a prompt for the LLM that embeds the question, the full list of node ids,
## and the fixed primitive set so the LLM understands the contract.
##
## Parameters:
##   question — natural-language question from the human
##   graph    — scene graph dict {"nodes": [...], "edges": [...], ...}
##
## Returns the prompt string to send to the LLM.
static func build_prompt(question: String, graph: Dictionary) -> String:
	var node_lines: Array = []
	for node in graph.get("nodes", []):
		node_lines.append(
			"  - id: %s  name: %s  type: %s" % [
				node.get("id", ""),
				node.get("name", ""),
				node.get("type", ""),
			]
		)

	var primitives: String = ", ".join(VALID_OPS)
	var nodes_text: String = "\n".join(node_lines) if not node_lines.is_empty() else "  (no nodes)"

	return (
		"You are a software architecture visualization assistant.\n"
		+ "Given the following software system and a question, produce a view specification.\n"
		+ "\n"
		+ "SYSTEM NODES:\n"
		+ nodes_text + "\n"
		+ "\n"
		+ "AVAILABLE VISUAL PRIMITIVES (use ONLY these): " + primitives + "\n"
		+ "\n"
		+ "QUESTION: " + question + "\n"
		+ "\n"
		+ "Respond with a JSON object matching this schema:\n"
		+ '{"operations": [{"op": "<primitive>", "target": "<node_id>", ...}]}\n'
		+ "\n"
		+ "Rules:\n"
		+ "  - Each operation MUST use one of the available primitives listed above.\n"
		+ "  - Do NOT invent new primitive types; no new rendering logic is generated at runtime.\n"
		+ "  - show / hide   → {\"op\": \"show\"|\"hide\",      \"target\": \"<id>\"}\n"
		+ "  - highlight     → {\"op\": \"highlight\",        \"target\": \"<id>\"}\n"
		+ "  - arrange       → {\"op\": \"arrange\",          \"target\": \"<id>\",  \"position\": {\"x\":0,\"y\":0,\"z\":0}}\n"
		+ "  - annotate      → {\"op\": \"annotate\",         \"target\": \"<id>\",  \"text\": \"...\"}\n"
		+ "  - connect       → {\"op\": \"connect\",          \"source\": \"<id>\",  \"target\": \"<id>\"}\n"
	)


## Parse an LLM response string into a structured view specification dictionary.
##
## The response may be wrapped in markdown code fences (```json ... ```).
## Any operation with an op value not in VALID_OPS is silently discarded —
## ensuring no new rendering logic is introduced at runtime.
##
## Returns {"operations": [...]}.  Operations that survive filtering each have
## at least the "op" key and whatever additional keys the LLM included.
static func parse_response(response: String) -> Dictionary:
	var text: String = response.strip_edges()

	# Strip markdown code fences (```json ... ``` or ``` ... ```)
	if text.begins_with("```"):
		var lines: PackedStringArray = text.split("\n")
		var inside: bool = false
		var content_lines: Array = []
		for line in lines:
			if line.strip_edges().begins_with("```"):
				inside = !inside
				continue
			if inside:
				content_lines.append(line)
		text = "\n".join(content_lines).strip_edges()

	# Parse JSON
	var json := JSON.new()
	if json.parse(text) != OK:
		return {"operations": []}

	var data = json.data
	if not data is Dictionary:
		return {"operations": []}

	# Filter to only the fixed primitive set — no new rendering at runtime.
	var raw_ops: Array = data.get("operations", [])
	var filtered: Array = []
	for op in raw_ops:
		if not op is Dictionary:
			continue
		var op_name: String = op.get("op", "")
		if op_name in VALID_OPS:
			filtered.append(op)

	return {"operations": filtered}
