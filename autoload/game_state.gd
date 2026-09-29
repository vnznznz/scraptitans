extends Node

signal purchased
signal mech_deployed(mech: MechState)
signal mech_income(mech: MechState, credits: float, scrap: float)
signal enemy_killed(mech: MechState)
signal mech_died(mech: MechState, salvage: float)

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
var credits_rate := 0.0
var scrap_rate := 0.0
var time_scale := 1.0

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
	_reset_rates()


func tap_pile() -> void:
	_gain_scrap(Data.econ("scrap_per_tap"))


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
	_reset_rates()


func _step(dt: float) -> void:
	run_time += dt
	for line in lines:
		_step_line(line, dt)
	_step_field(dt)
	_step_rates(dt)


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
		if s.assembling or not s.bar_full():
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
	m.deploy_fee = float(core.deploy_fee)
	m.kill_rate = float(arms.kills_per_sec)
	m.scrap_per_kill = float(arms.scrap_per_kill)
	m.arrive_t = 0.0
	field.append(m)
	mechs_built += 1
	_gain_credits(m.deploy_fee)
	mech_deployed.emit(m)


func payout_rate(m: MechState) -> float:
	var steps := mini(int(floor(m.age / Data.econ("payout_interval"))), int(Data.econ("payout_cap")))
	return m.base_rate * pow(Data.econ("payout_step"), steps)


func _step_field(dt: float) -> void:
	for m: MechState in field.duplicate():
		var c := payout_rate(m) * dt
		m.age += dt
		_gain_credits(c)
		m.pend_credits += c
		m.kill_acc += m.kill_rate * dt
		while m.kill_acc >= 1.0 - 1e-6:
			m.kill_acc -= 1.0
			_gain_scrap(m.scrap_per_kill)
			m.pend_scrap += m.scrap_per_kill
			enemy_killed.emit(m)
		m.pend_t += dt
		var dead := m.age >= m.lifetime
		if m.pend_t >= 1.0 or dead:
			mech_income.emit(m, m.pend_credits, m.pend_scrap)
			m.pend_t = 0.0
			m.pend_credits = 0.0
			m.pend_scrap = 0.0
		if dead:
			var salvage := m.scrap_cost * Data.econ("salvage")
			_gain_scrap(salvage)
			field.erase(m)
			mech_died.emit(m, salvage)


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
