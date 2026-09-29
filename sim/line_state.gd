class_name LineState
extends RefCounted

var segments: Array[SegmentState] = []
var paused := false


static func create() -> LineState:
	var line := LineState.new()
	for type_id: String in Data.line_slots():
		line.segments.append(SegmentState.new(type_id))
	return line


func is_complete() -> bool:
	return segments.all(func(s: SegmentState) -> bool: return s.built)


func to_dict() -> Dictionary:
	return {
		"segments": segments.map(func(s: SegmentState) -> Dictionary: return s.to_dict()),
		"paused": paused,
	}


static func from_dict(d: Dictionary) -> LineState:
	var line := LineState.new()
	for sd: Dictionary in d.segments:
		line.segments.append(SegmentState.from_dict(sd))
	line.paused = d.get("paused", false)
	return line
