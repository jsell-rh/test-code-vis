class_name ViewSpec
extends RefCounted

## Fixed set of visual primitives available in view specifications.
##
## The LLM selects from this set; it does not invent new primitives.
## No new rendering logic is generated at runtime — the set is fixed here.
##
## Primitives:
##   show      — include listed node ids in the rendered scene
##   hide      — exclude listed node ids from the rendered scene
##   highlight — render listed node ids with a distinct colour
##   arrange   — override a node id's 3D position
##   annotate  — attach a text label to a node id
##   connect   — draw a visual connector between two node ids
const VALID_OPS: Array = ["show", "hide", "highlight", "arrange", "annotate", "connect"]


## Parse and validate a raw view-spec Dictionary.
##
## Returns a normalised Dictionary:
##   {
##     "question":   String,           # the original natural-language question
##     "operations": Array[Dictionary] # only ops whose "op" key is in VALID_OPS
##   }
##
## Unknown ops are silently dropped, enforcing the fixed primitive contract.
static func from_dict(data: Dictionary) -> Dictionary:
	var ops: Array = []
	for op in data.get("operations", []):
		if op is Dictionary and VALID_OPS.has(op.get("op", "")):
			ops.append(op)
	return {
		"question": data.get("question", ""),
		"operations": ops,
	}


## Returns a copy of the complete valid-op list for introspection / tests.
static func get_valid_ops() -> Array:
	return VALID_OPS.duplicate()
