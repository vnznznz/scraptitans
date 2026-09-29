class_name LineState
extends RefCounted

const RATE_WINDOW := 5

var segments: Array[SegmentState] = []
var paused := false
var workers := 0
var worker_t := 0.0
var scrap_used_rate := 0.0

var _used_bucket := 0.0
var _used_history: Array[float] = []


static func create(types: Array) -> LineState:
	var line := LineState.new()
	for type_id: String in types:
		line.segments.append(SegmentState.new(type_id))
	return line


func use_scrap(amount: float) -> void:
	_used_bucket += amount


func sample_rate() -> void:
	_used_history.append(_used_bucket)
	_used_bucket = 0.0
	if _used_history.size() > RATE_WINDOW:
		_used_history.pop_front()
	var total := 0.0
	for v in _used_history:
		total += v
	scrap_used_rate = total / _used_history.size()


func starved() -> bool:
	return segments.any(func(s: SegmentState) -> bool: return s.stall == SegmentState.Stall.NO_SCRAP)


func is_complete() -> bool:
	return segments.all(func(s: SegmentState) -> bool: return s.built or s.optional())


func has_type(type_id: String) -> bool:
	return segments.any(func(s: SegmentState) -> bool: return s.type_id == type_id)


func built_count() -> int:
	return segments.filter(func(s: SegmentState) -> bool: return s.built).size()


func worker_slots() -> int:
	return int(GameState.stat("worker_slots")) * built_count()


func station_workers(seg_index: int) -> int:
	if not segments[seg_index].built:
		return 0
	var k := 0
	for i in seg_index:
		if segments[i].built:
			k += 1
	var n := built_count()
	return floori(float(workers) / n) + (1 if k < workers % n else 0)


func last_built() -> int:
	var last := segments.size() - 1
	while last > 0 and not segments[last].built:
		last -= 1
	return last


func to_dict() -> Dictionary:
	return {
		"segments": segments.map(func(s: SegmentState) -> Dictionary: return s.to_dict()),
		"paused": paused,
		"workers": workers,
		"worker_t": worker_t,
	}


static func from_dict(d: Dictionary) -> LineState:
	var line := LineState.new()
	for sd: Dictionary in d.segments:
		line.segments.append(SegmentState.from_dict(sd))
	line.paused = d.get("paused", false)
	var old_workers := 0
	for sd: Dictionary in d.segments:
		old_workers += int(sd.get("workers", 0))
	line.workers = int(d.get("workers", old_workers))
	line.worker_t = float(d.get("worker_t", 0.0))
	return line
