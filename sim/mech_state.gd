class_name MechState
extends RefCounted

const FLOAT_FIELDS := [
	"scrap_cost", "arrive_t", "age", "wear", "lifetime", "base_rate", "deploy_fee",
	"dps", "pend_t", "pend_credits",
]

var id := 0
var parts := {}
var scrap_cost := 0.0
var arrive_t := 0.0
var age := 0.0
var wear := 0.0
var lifetime := 0.0
var base_rate := 0.0
var deploy_fee := 0.0
var dps := 0.0
var pend_t := 0.0
var pend_credits := 0.0


func has_part(type_id: String) -> bool:
	return parts.has(type_id)


func remaining() -> float:
	return clampf(1.0 - wear / lifetime, 0.0, 1.0) if lifetime > 0.0 else 1.0


func is_nuclear() -> bool:
	return parts.keys().any(func(k: String) -> bool: return Data.tier(k, parts[k]).get("final", false))


func to_dict() -> Dictionary:
	var d := {"id": id, "parts": parts.duplicate()}
	for f: String in FLOAT_FIELDS:
		d[f] = get(f)
	return d


static func from_dict(d: Dictionary) -> MechState:
	var m := MechState.new()
	m.id = int(d.id)
	for k: String in d.parts:
		m.parts[k] = int(d.parts[k])
	for f: String in FLOAT_FIELDS:
		m.set(f, float(d.get(f, 0.0)))
	return m
