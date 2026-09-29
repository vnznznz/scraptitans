class_name SegmentState
extends RefCounted

enum Stall { NONE, NO_SCRAP, BLOCKED }

var type_id := ""
var built := false
var tier := 0
var work := 0.0
var mech: MechState
var assembling := false
var assemble_t := 0.0
var stall := Stall.NONE


func _init(p_type_id: String = "") -> void:
	type_id = p_type_id


func bar_size() -> float:
	return float(Data.segment_type(type_id).bar_size)


func bar_full() -> bool:
	return work >= bar_size()


func tier_data() -> Dictionary:
	return Data.tier(type_id, tier)


func to_dict() -> Dictionary:
	return {
		"type_id": type_id,
		"built": built,
		"tier": tier,
		"work": work,
		"mech": mech.to_dict() if mech else null,
		"assembling": assembling,
		"assemble_t": assemble_t,
	}


static func from_dict(d: Dictionary) -> SegmentState:
	var s := SegmentState.new(d.type_id)
	s.built = d.built
	s.tier = int(d.tier)
	s.work = float(d.work)
	s.mech = MechState.from_dict(d.mech) if d.mech is Dictionary else null
	s.assembling = d.assembling
	s.assemble_t = float(d.assemble_t)
	return s
