extends Node

var economy: Dictionary
var segments: Dictionary
var enemies: Dictionary
var upgrades: Dictionary
var upgrade_list: Array[Dictionary] = []

var _rows_by_id := {}
var _rows_by_stat := {}


func _init() -> void:
	economy = _load("res://data/economy.json")
	segments = _load("res://data/segments.json")
	enemies = _load("res://data/enemies.json")
	upgrades = _load("res://data/upgrades.json")
	for row: Dictionary in upgrades.rows:
		upgrade_list.append(row)
		if not _rows_by_stat.has(row.stat):
			_rows_by_stat[row.stat] = []
		_rows_by_stat[row.stat].append(row)
	for type_id: String in line_slots():
		var t := segment_type(type_id)
		var tiers: Array = t.tiers
		var final: bool = tiers[-1].get("final", false)
		var count := tiers.size() - (0 if t.get("optional", false) else 1) - (1 if final else 0)
		upgrade_list.append({"id": "tier_" + type_id, "kind": "tier", "type": type_id, "max_level": count})
		if final:
			upgrade_list.append({"id": "final_" + type_id, "kind": "final", "type": type_id, "max_level": 1})
	for row in upgrade_list:
		_rows_by_id[row.id] = row


func econ(key: String) -> float:
	return float(economy[key])


func line_slots() -> Array:
	return segments.line_slots


func segment_type(type_id: String) -> Dictionary:
	return segments.types[type_id]


func tier(type_id: String, tier_index: int) -> Dictionary:
	return segments.types[type_id].tiers[tier_index]


func wave_type(wave: int) -> Dictionary:
	return enemies.types[wave % enemies.types.size()]


func upgrade_row(id: String) -> Dictionary:
	return _rows_by_id[id]


func tier_row_id(type_id: String) -> String:
	return "tier_" + type_id


func rows_for_stat(stat: String) -> Array:
	return _rows_by_stat.get(stat, [])


func base_stat(stat: String) -> float:
	var dot := stat.find(".")
	if dot == -1:
		return econ(stat)
	return float(segment_type(stat.left(dot))[stat.substr(dot + 1)])


func _load(path: String) -> Dictionary:
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	assert(parsed is Dictionary, "Invalid JSON: " + path)
	return parsed
