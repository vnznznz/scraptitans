extends Node

signal purchased
signal mech_deployed(mech: MechState)
signal mech_income(mech: MechState, credits: float)
signal mech_died(mech: MechState, salvage: float)
signal wave_cleared(bounty: float)
signal line_added(index: int)

const TICK := 1.0 / 30.0
const MAX_FRAME_DELTA := 0.25
const RATE_WINDOW := 5

var scrap := 0.0
var credits := 0.0
var lines: Array[LineState] = []
var field: Array[MechState] = []
var next_mech_id := 1
var run_time := 0.0
var mechs_built := 0
var credits_earned := 0.0
var wave := 0
var wave_hp := 0.0
var yard_workers := 0
var yard_t := 0.0
var levels := {}
var credits_rate := 0.0
var scrap_rate := 0.0
var time_scale := 1.0
var yard_chunks := 0

var _stats := {}
var _acc := 0.0
var _rate_t := 0.0
var _credits_bucket := 0.0
var _scrap_bucket := 0.0
var _credits_history: Array[float] = []
var _scrap_history: Array[float] = []


func _process(delta: float) -> void:
	_acc += minf(delta, MAX_FRAME_DELTA) * time_scale
	while _acc >= TICK:
		_acc -= TICK
		_step(TICK)


func advance(seconds: float) -> void:
	for i in int(round(seconds / TICK)):
		_step(TICK)


func new_game() -> void:
	scrap = Data.econ("start_scrap")
	credits = Data.econ("start_credits")
	lines = [LineState.create()]
	field = []
	next_mech_id = 1
	run_time = 0.0
	mechs_built = 0
	credits_earned = 0.0
	levels = {}
	_stats = {}
	wave = 0
	wave_hp = wave_max_hp()
	yard_workers = 0
	yard_t = 0.0
	_reset_rates()


func stat(key: String) -> float:
	if _stats.has(key):
		return _stats[key]
	var v := Data.base_stat(key)
	for row: Dictionary in Data.rows_for_stat(key):
		v += float(row.delta) * level(row.id)
	_stats[key] = v
	return v


func tap_pile() -> void:
	_gain_scrap(stat("scrap_per_tap"))


func tap_segment(line_index: int, seg_index: int) -> bool:
	var s := lines[line_index].segments[seg_index]
	if not s.built or s.bar_full():
		return false
	s.work = minf(s.bar_size(), s.work + Data.econ("work_per_tap"))
	return true


func build_cost(line_index: int, seg_index: int) -> float:
	return float(Data.segment_type(lines[line_index].segments[seg_index].type_id).build_cost)


func build_segment(line_index: int, seg_index: int) -> bool:
	var s := lines[line_index].segments[seg_index]
	var cost := build_cost(line_index, seg_index)
	if s.built or scrap < cost:
		return false
	scrap -= cost
	s.built = true
	purchased.emit()
	return true


func worker_cost(line_index: int, seg_index: int) -> float:
	var s := lines[line_index].segments[seg_index]
	var t := Data.segment_type(s.type_id)
	return float(t.worker_base) * pow(float(t.worker_growth), s.workers)


func hire_worker(line_index: int, seg_index: int) -> bool:
	var s := lines[line_index].segments[seg_index]
	var cost := worker_cost(line_index, seg_index)
	if not s.built or s.workers >= s.worker_slots() or credits < cost:
		return false
	credits -= cost
	s.workers += 1
	purchased.emit()
	return true


func yard_slots() -> int:
	return int(stat("yard_slots"))


func yard_worker_cost() -> float:
	return Data.econ("yard_worker_base") * pow(Data.econ("yard_worker_growth"), yard_workers)


func hire_yard_worker() -> bool:
	var cost := yard_worker_cost()
	if yard_workers >= yard_slots() or credits < cost:
		return false
	credits -= cost
	yard_workers += 1
	purchased.emit()
	return true


func toggle_pause(line_index: int) -> void:
	lines[line_index].paused = not lines[line_index].paused
	purchased.emit()


func segment_rate(s: SegmentState) -> float:
	return s.workers * stat("worker_chunk") / stat("worker_interval") / s.bar_size()


func bottlenecks(line_index: int) -> Array[int]:
	var line := lines[line_index]
	var result: Array[int] = []
	if not line.is_complete():
		return result
	var rates := line.segments.map(segment_rate)
	var lo: float = rates.min()
	if is_equal_approx(lo, rates.max()):
		return result
	for i in rates.size():
		if is_equal_approx(rates[i], lo):
			result.append(i)
	return result


func level(id: String) -> int:
	return int(levels.get(id, 0))


func upgrade_cost(id: String) -> float:
	return float(Data.upgrade_row(id).base_cost) * pow(Data.econ("upgrade_cost_growth"), level(id))


func upgrade_maxed(id: String) -> bool:
	return level(id) >= int(Data.upgrade_row(id).max_level)


func buy_upgrade(id: String) -> bool:
	var cost := upgrade_cost(id)
	if upgrade_maxed(id) or credits < cost:
		return false
	credits -= cost
	levels[id] = level(id) + 1
	_stats = {}
	while lines.size() < int(stat("lines")):
		lines.append(LineState.create())
		line_added.emit(lines.size() - 1)
	purchased.emit()
	return true


func salvage_share() -> float:
	return minf(stat("salvage"), Data.econ("salvage_cap"))


func wave_max_hp() -> float:
	return float(Data.enemies.base_hp) * pow(float(Data.enemies.hp_growth), wave)


func wave_bounty() -> float:
	return float(Data.enemies.base_bounty) * pow(float(Data.enemies.bounty_growth), wave)


func field_dps() -> float:
	var total := 0.0
	for m in field:
		total += m.dps
	return total


func kill_wave() -> void:
	_clear_wave()


func to_dict() -> Dictionary:
	return {
		"scrap": scrap,
		"credits": credits,
		"lines": lines.map(func(l: LineState) -> Dictionary: return l.to_dict()),
		"field": field.map(func(m: MechState) -> Dictionary: return m.to_dict()),
		"next_mech_id": next_mech_id,
		"run_time": run_time,
		"mechs_built": mechs_built,
		"credits_earned": credits_earned,
		"wave": wave,
		"wave_hp": wave_hp,
		"yard_workers": yard_workers,
		"yard_t": yard_t,
		"levels": levels.duplicate(),
	}


func from_dict(d: Dictionary) -> void:
	scrap = float(d.scrap)
	credits = float(d.credits)
	lines = []
	for ld: Dictionary in d.lines:
		lines.append(LineState.from_dict(ld))
	field = []
	for md: Dictionary in d.field:
		field.append(MechState.from_dict(md))
	next_mech_id = int(d.next_mech_id)
	run_time = float(d.run_time)
	mechs_built = int(d.mechs_built)
	credits_earned = float(d.credits_earned)
	levels = {}
	var saved_levels: Dictionary = d.get("levels", {})
	for id: String in saved_levels:
		levels[id] = int(saved_levels[id])
	_stats = {}
	wave = int(d.get("wave", 0))
	wave_hp = float(d.get("wave_hp", wave_max_hp()))
	yard_workers = int(d.get("yard_workers", 0))
	yard_t = float(d.get("yard_t", 0.0))
	_reset_rates()


func _step(dt: float) -> void:
	run_time += dt
	for line in lines:
		_step_workers(line, dt)
		_step_line(line, dt)
	_step_yard(dt)
	_step_field(dt)
	_step_wave(dt)
	_step_rates(dt)


func _step_workers(line: LineState, dt: float) -> void:
	var interval := stat("worker_interval")
	var chunk := stat("worker_chunk")
	for s in line.segments:
		if not s.built or s.workers == 0:
			continue
		s.worker_t += dt * s.workers
		while s.worker_t >= interval:
			s.worker_t -= interval
			if not s.bar_full():
				s.work = minf(s.bar_size(), s.work + chunk)
				s.chunks += 1


func _step_yard(dt: float) -> void:
	if yard_workers == 0:
		return
	var interval := stat("worker_interval")
	yard_t += dt * yard_workers
	while yard_t >= interval:
		yard_t -= interval
		_gain_scrap(stat("yard_chunk"))
		yard_chunks += 1


func _step_line(line: LineState, dt: float) -> void:
	var segs := line.segments
	var last := segs.size() - 1
	for i in range(last, -1, -1):
		var s := segs[i]
		s.stall = SegmentState.Stall.NONE
		if not s.built:
			continue
		if s.assembling:
			s.assemble_t -= dt
			if s.assemble_t <= 0.0:
				s.assembling = false
				s.assemble_t = 0.0
				s.mech.parts[s.type_id] = s.tier
		if s.mech and s.mech.arrive_t > 0.0:
			s.mech.arrive_t = maxf(0.0, s.mech.arrive_t - dt)
		if s.mech and not s.assembling and s.mech.has_part(s.type_id):
			if i == last:
				_deploy(s.mech)
				s.mech = null
			elif segs[i + 1].built and segs[i + 1].mech == null:
				segs[i + 1].mech = s.mech
				s.mech.arrive_t = Data.econ("belt_time")
				s.mech = null
			else:
				s.stall = SegmentState.Stall.BLOCKED
				continue
		if line.paused or s.assembling or not s.bar_full():
			continue
		if i == 0:
			if s.mech == null and line.is_complete():
				_try_assemble(s, true)
		elif s.mech and s.mech.arrive_t <= 0.0 and not s.mech.has_part(s.type_id):
			_try_assemble(s, false)


func _try_assemble(s: SegmentState, spawn: bool) -> void:
	var cost := float(s.tier_data().scrap_per_mech)
	if scrap < cost:
		s.stall = SegmentState.Stall.NO_SCRAP
		return
	scrap -= cost
	if spawn:
		s.mech = MechState.new()
		s.mech.id = next_mech_id
		next_mech_id += 1
	s.mech.scrap_cost += cost
	s.work = 0.0
	s.assembling = true
	s.assemble_t = Data.econ("assembly_time")


func _deploy(m: MechState) -> void:
	var frame := Data.tier("frame", m.parts.get("frame", 0))
	var core := Data.tier("core", m.parts.get("core", 0))
	var arms := Data.tier("arms", m.parts.get("arms", 0))
	m.lifetime = float(frame.lifetime)
	m.base_rate = float(core.credits_per_sec)
	m.deploy_fee = float(core.deploy_fee) * stat("deploy_fee_mult")
	m.dps = float(arms.dps)
	m.arrive_t = 0.0
	field.append(m)
	mechs_built += 1
	_gain_credits(m.deploy_fee)
	mech_deployed.emit(m)


func payout_rate(m: MechState) -> float:
	var steps := mini(int(floor(m.age / stat("payout_interval"))), int(stat("payout_cap")))
	return m.base_rate * pow(Data.econ("payout_step"), steps)


func _step_field(dt: float) -> void:
	for m: MechState in field.duplicate():
		var c := payout_rate(m) * dt
		m.age += dt
		_gain_credits(c)
		m.pend_credits += c
		m.pend_t += dt
		var dead := m.age >= m.lifetime
		if m.pend_t >= 1.0 or dead:
			mech_income.emit(m, m.pend_credits)
			m.pend_t = 0.0
			m.pend_credits = 0.0
		if dead:
			var salvage := m.scrap_cost * salvage_share()
			_gain_scrap(salvage)
			field.erase(m)
			mech_died.emit(m, salvage)


func _step_wave(dt: float) -> void:
	wave_hp -= field_dps() * dt
	if wave_hp <= 0.0:
		_clear_wave()


func _clear_wave() -> void:
	var bounty := wave_bounty()
	_gain_credits(bounty)
	wave += 1
	wave_hp = wave_max_hp()
	wave_cleared.emit(bounty)


func _gain_credits(amount: float) -> void:
	credits += amount
	credits_earned += amount
	_credits_bucket += amount


func _gain_scrap(amount: float) -> void:
	scrap += amount
	_scrap_bucket += amount


func _step_rates(dt: float) -> void:
	_rate_t += dt
	if _rate_t < 1.0:
		return
	_rate_t -= 1.0
	_credits_history.append(_credits_bucket)
	_scrap_history.append(_scrap_bucket)
	_credits_bucket = 0.0
	_scrap_bucket = 0.0
	if _credits_history.size() > RATE_WINDOW:
		_credits_history.pop_front()
		_scrap_history.pop_front()
	credits_rate = _average(_credits_history)
	scrap_rate = _average(_scrap_history)


func _average(values: Array[float]) -> float:
	var total := 0.0
	for v in values:
		total += v
	return total / values.size()


func _reset_rates() -> void:
	_rate_t = 0.0
	_credits_bucket = 0.0
	_scrap_bucket = 0.0
	_credits_history = []
	_scrap_history = []
	credits_rate = 0.0
	scrap_rate = 0.0
