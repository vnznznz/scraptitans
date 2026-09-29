extends Node

var economy: Dictionary
var segments: Dictionary


func _init() -> void:
	economy = _load("res://data/economy.json")
	segments = _load("res://data/segments.json")


func econ(key: String) -> float:
	return float(economy[key])


func line_slots() -> Array:
	return segments.line_slots


func segment_type(type_id: String) -> Dictionary:
	return segments.types[type_id]


func tier(type_id: String, tier_index: int) -> Dictionary:
	return segments.types[type_id].tiers[tier_index]


func _load(path: String) -> Dictionary:
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	assert(parsed is Dictionary, "Invalid JSON: " + path)
	return parsed
