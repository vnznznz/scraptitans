extends Node

var economy: Dictionary
var segments: Dictionary
var enemies: Dictionary
var upgrades: Dictionary

var _rows_by_id := {}
var _rows_by_stat := {}


func _init() -> void:
	economy = _load("res://data/economy.json")
	segments = _load("res://data/segments.json")
	enemies = _load("res://data/enemies.json")
	upgrades = _load("res://data/upgrades.json")
	for row: Dictionary in upgrades.rows:
		_rows_by_id[row.id] = row
		if not _rows_by_stat.has(row.stat):
			_rows_by_stat[row.stat] = []
		_rows_by_stat[row.stat].append(row)


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


func upgrade_rows(tab: String) -> Array:
	return upgrades.rows.filter(func(r: Dictionary) -> bool: return r.tab == tab)


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
