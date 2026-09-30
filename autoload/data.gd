extends Node

var economy: Dictionary
var segments: Dictionary
var enemies: Dictionary
var upgrades: Dictionary
var audio: Dictionary
var upgrade_list: Array[Dictionary] = []

var _rows_by_id := {}
var _rows_by_stat := {}


func _init() -> void:
	economy = _load("res://data/economy.json")
	segments = _load("res://data/segments.json")
	enemies = _load("res://data/enemies.json")
	upgrades = _load("res://data/upgrades.json")
	audio = _load("res://data/audio.json")
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


func wave_enemies(wave: int) -> Array[Dictionary]:
	var e := enemies
	var types: Array = e.types
	var kinds := 1 + int(wave >= int(e.mix_from)) + int(wave >= int(e.mix_all_from))
	var base := 0.0
	for k in kinds:
		base += float(types[(wave + k) % types.size()].count)
	var mult := minf((1.0 + wave * float(e.count_growth)) / kinds, float(e.max_enemies) / base)
	var list: Array[Dictionary] = []
	for k in kinds:
		var type: Dictionary = types[(wave + k) % types.size()]
		for i in maxi(1, roundi(float(type.count) * mult)):
			list.append({"sprite": type.sprite, "flying": type.flying, "weight": float(type.weight), "variant": 0})
	list.resize(mini(list.size(), int(e.max_enemies)))
	var band := float(wave) / float(e.variant_every)
	var top := mini(int(band), int(e.variants) - 1)
	var elites := 0 if top == int(e.variants) - 1 else roundi(fmod(band, 1.0) * list.size())
	for i in list.size():
		var en := list[i]
		en.variant = top + (1 if i >= list.size() - elites else 0)
		en.weight *= pow(float(e.variant_tough), en.variant)
	var order := range(list.size())
	order.sort_custom(func(a: int, b: int) -> bool:
		return list[a].weight < list[b].weight or (list[a].weight == list[b].weight and a < b))
	var sorted: Array[Dictionary] = []
	for i: int in order:
		sorted.append(list[i])
	return sorted


func upgrade_row(id: String) -> Dictionary:
	return _rows_by_id[id]


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
