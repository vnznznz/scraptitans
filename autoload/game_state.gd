extends Node

signal purchased
signal mech_deployed(mech: MechState)
signal mech_income(mech: MechState, credits: float)
signal mech_died(mech: MechState, salvage: float)
signal wave_cleared(bounty: float)
signal enemy_killed(index: int, scrap: float)
signal line_added(index: int)
signal segment_added(line_index: int)
signal nuke_launched(mech: MechState)
signal gate_fell

const TICK := 1.0 / 30.0
const MAX_FRAME_DELTA := 0.25
const RATE_WINDOW := 5
const MECH_WINDOW := 60
const AWAY_WINDOW := 60
const REVEALS := ["factory", "crew", "yard_crew", "upgrades", "unlock"]

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
var run_over := false
var lost := false
var siege := 0.0
var gate_damage := 0.0
var stalled_once := false
var seen := {}
var field_taps := 0
var prestige := 0
var scrap_boost_t := 0.0
var ad_cooldown_t := 0.0
var away_t := 0.0
var away_scrap := 0.0
var away_credits := 0.0
var credits_rate := 0.0
var scrap_rate := 0.0
var scrap_gain_rate := 0.0
var tap_dps := 0.0
var mechs_per_min := 0
var time_scale := 1.0
var yard_chunks := 0

var _stats := {}
var _acc := 0.0
var _frame_at := 0.0
var _rate_t := 0.0
var _credits_bucket := 0.0
var _scrap_bucket := 0.0
var _scrap_gain_bucket := 0.0
var _tap_bucket := 0.0
var _credits_history: Array[float] = []
var _scrap_history: Array[float] = []
var _scrap_gain_history: Array[float] = []
var _tap_history: Array[float] = []
var _mech_bucket := 0
var _mech_history: Array[int] = []
var _wave_list: Array[Dictionary] = []
var _wave_listed := -1


func _process(delta: float) -> void:
	var now := Time.get_unix_time_from_system()
	if _frame_at > 0.0 and now - _frame_at >= Data.econ("away_min"):
		away(now - _frame_at)
	_frame_at = now
	if run_over:
		return
	_update_seen()
	_acc += minf(delta, MAX_FRAME_DELTA) * time_scale
	while _acc >= TICK:
		_acc -= TICK
		_step(TICK)


func _notification(what: int) -> void:
	if what == NOTIFICATION_UNPAUSED:
		_frame_at = 0.0


func advance(seconds: float) -> void:
	for i in int(round(seconds / TICK)):
		if run_over:
			return
		_step(TICK)
	_update_seen()


func new_game() -> void:
	scrap = Data.econ("start_scrap")
	credits = Data.econ("start_credits")
	levels = {}
	_stats = {}
	lines = [LineState.create(active_slots())]
	field = []
	next_mech_id = 1
	run_time = 0.0
	mechs_built = 0
	credits_earned = 0.0
	run_over = false
	lost = false
	siege = 0.0
	gate_damage = 0.0
	stalled_once = false
	seen = {}
	field_taps = 0
	wave = 0
	wave_hp = wave_max_hp()
	yard_workers = 0
	yard_t = 0.0
	scrap_boost_t = 0.0
	ad_cooldown_t = 0.0
	_clear_away()
	_reset_rates()


func war_scale() -> float:
	return pow(Data.econ("prestige_scale"), prestige)


func pile_scale() -> float:
	return pow(Data.econ("prestige_pile"), prestige)


func stat(key: String) -> float:
	if _stats.has(key):
		return _stats[key]
	var v := Data.base_stat(key)
	for row: Dictionary in Data.rows_for_stat(key):
		v += float(row.delta) * level(row.id)
	_stats[key] = v
	return v


func active_slots() -> Array:
	return Data.line_slots().filter(func(t: String) -> bool: return unlocked_tier(t) >= 0)


func unlocked_tier(type_id: String) -> int:
	var lv := level("tier_" + type_id) + level("final_" + type_id)
	return lv - (1 if Data.segment_type(type_id).get("optional", false) else 0)


func top_tier(type_id: String) -> int:
	var tiers: Array = Data.segment_type(type_id).tiers
	return tiers.size() - (2 if tiers[-1].get("final", false) else 1)


func line_maxed(line_index: int) -> bool:
	return lines[line_index].segments.all(func(s: SegmentState) -> bool: return s.built and s.tier >= top_tier(s.type_id))


func apply_target(line_index: int, seg_index: int) -> int:
	var s := lines[line_index].segments[seg_index]
	var target := unlocked_tier(s.type_id)
	if target > top_tier(s.type_id) and not line_maxed(line_index):
		target = top_tier(s.type_id)
	return target


func can_apply_tier(line_index: int, seg_index: int) -> bool:
	var s := lines[line_index].segments[seg_index]
	return s.built and s.tier < apply_target(line_index, seg_index)


func tier_apply_cost(line_index: int, seg_index: int) -> float:
	var s := lines[line_index].segments[seg_index]
	var cost := 0.0
	for t in range(s.tier + 1, apply_target(line_index, seg_index) + 1):
		cost += float(Data.tier(s.type_id, t).apply_cost)
	return cost * war_scale()


func apply_tier(line_index: int, seg_index: int) -> bool:
	if not can_apply_tier(line_index, seg_index):
		return false
	var cost := tier_apply_cost(line_index, seg_index)
	if scrap < cost:
		return false
	scrap -= cost
	var s := lines[line_index].segments[seg_index]
	s.tier = apply_target(line_index, seg_index)
	purchased.emit()
	return true


func starved() -> bool:
	return lines.any(func(l: LineState) -> bool: return l.starved())


func revealed() -> bool:
	return mechs_built > 0


func shown(key: String) -> bool:
	return seen.has(key)


func pause_shown() -> bool:
	return stalled_once or prestige > 0


func _update_seen() -> void:
	if lines.is_empty():
		return
	if not seen.has("factory") and (scrap >= build_cost(0, 0) or lines[0].segments.any(func(s: SegmentState) -> bool: return s.built)):
		seen.factory = true
	if not revealed():
		return
	if not seen.has("crew") and credits >= worker_cost(0):
		seen.crew = true
	if not seen.has("yard_crew") and credits >= yard_worker_cost():
		seen.yard_crew = true
	if not seen.has("upgrades") and affordable_upgrades() > 0:
		seen.upgrades = true
	if not seen.has("unlock") and credits >= upgrade_cost("lines"):
		seen.unlock = true


func aging() -> float:
	return 1.0 + float(Data.enemies.wave_damage) * wave


func tap_scrap() -> float:
	return stat("scrap_per_tap") * pile_scale() + stat("tap_yard_share") * yard_rate()


func tap_pile() -> void:
	_gain_scrap(tap_scrap())


func tap_segment(line_index: int, seg_index: int) -> bool:
	var s := lines[line_index].segments[seg_index]
	if not s.built or s.bar_full():
		return false
	s.work = minf(s.bar_size(), s.work + Data.econ("work_per_tap"))
	return true


func build_cost(line_index: int, seg_index: int) -> float:
	return float(Data.segment_type(lines[line_index].segments[seg_index].type_id).build_cost) * war_scale()


func build_segment(line_index: int, seg_index: int) -> bool:
	var s := lines[line_index].segments[seg_index]
	var cost := build_cost(line_index, seg_index)
	if s.built or scrap < cost:
		return false
	scrap -= cost
	s.built = true
	purchased.emit()
	return true


func worker_cost(line_index: int) -> float:
	return Data.econ("worker_base") * pow(Data.econ("worker_growth"), lines[line_index].workers) * war_scale()


func hire_worker(line_index: int) -> bool:
	var line := lines[line_index]
	var cost := worker_cost(line_index)
	if line.workers >= line.worker_slots() or credits < cost:
		return false
	credits -= cost
	line.workers += 1
	purchased.emit()
	return true


func yard_slots() -> int:
	return int(stat("yard_slots"))


func yard_chunk() -> float:
	return stat("yard_chunk") * stat("worker_chunk") * pile_scale()


func yard_rate() -> float:
	return yard_workers * yard_chunk() / stat("worker_interval")


func yard_worker_cost() -> float:
	return Data.econ("yard_worker_base") * pow(Data.econ("yard_worker_growth"), yard_workers) * war_scale()


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


func level(id: String) -> int:
	return int(levels.get(id, 0))


func upgrade_cost(id: String) -> float:
	var row := Data.upgrade_row(id)
	match row.get("kind", ""):
		"tier":
			return float(Data.tier(row.type, mini(unlocked_tier(row.type) + 1, Data.segment_type(row.type).tiers.size() - 1)).unlock_cost) * war_scale()
		"final":
			return float(Data.segment_type(row.type).tiers[-1].unlock_cost) * war_scale()
	return float(row.base_cost) * pow(float(row.get("cost_growth", Data.econ("upgrade_cost_growth"))), level(id)) * war_scale()


func upgrade_maxed(id: String) -> bool:
	return level(id) >= int(Data.upgrade_row(id).max_level)


func upgrade_locked(id: String) -> bool:
	var row := Data.upgrade_row(id)
	return row.get("kind", "") == "final" and Data.upgrade_list.any(func(r: Dictionary) -> bool: return r.get("kind", "") == "tier" and not upgrade_maxed(r.id))


func upgrade_visible(id: String) -> bool:
	var row := Data.upgrade_row(id)
	var stat_key: String = row.get("stat", "")
	var dot := stat_key.find(".")
	return dot == -1 or unlocked_tier(stat_key.left(dot)) >= 0


func affordable_upgrades() -> int:
	var n := 0
	for r: Dictionary in Data.upgrade_list:
		if upgrade_visible(r.id) and not upgrade_maxed(r.id) and not upgrade_locked(r.id) and credits >= upgrade_cost(r.id):
			n += 1
	return n


func scrap_boost() -> float:
	return Data.econ("ad_scrap_mult") if scrap_boost_t > 0.0 else 1.0


func ad_offers() -> Array[String]:
	var ids: Array[String] = []
	if ad_cooldown_t > 0.0:
		return ids
	var rows := []
	for i in Data.upgrade_list.size():
		var r: Dictionary = Data.upgrade_list[i]
		var id: String = r.id
		if r.get("kind", "") != "final" and upgrade_visible(id) and not upgrade_maxed(id) and credits < upgrade_cost(id):
			rows.append([upgrade_cost(id), i, id])
	rows.sort()
	for row: Array in rows.slice(0, int(Data.econ("ad_offers"))):
		ids.append(row[2])
	return ids


func reward_scrap() -> bool:
	if ad_cooldown_t > 0.0 or scrap_boost_t > 0.0:
		return false
	scrap_boost_t = Data.econ("ad_scrap_time")
	ad_cooldown_t = Data.econ("ad_cooldown")
	purchased.emit()
	return true


func reward_upgrade(id: String) -> bool:
	if not id in ad_offers() or not buy_upgrade(id, true):
		return false
	ad_cooldown_t = Data.econ("ad_cooldown")
	return true


func away_rates() -> Array[float]:
	return [_average(_credits_history), _average(_scrap_history), _average(_scrap_gain_history)]


func away(seconds: float) -> void:
	var rates := away_rates()
	add_away(seconds, rates[0], rates[1], rates[2])


func add_away(seconds: float, credits_per_s: float, scrap_per_s: float, scrap_gain_per_s: float) -> void:
	var counted := minf(seconds, Data.econ("away_max") - away_t)
	if seconds < Data.econ("away_min") or counted <= 0.0 or run_over or not revealed():
		return
	var share := Data.econ("away_share")
	var scrap_floor := maxf(scrap_gain_per_s * Data.econ("away_scrap_floor"), tap_scrap() * Data.econ("away_taps"))
	away_t += counted
	away_scrap += maxf(scrap_per_s, scrap_floor) * counted * share
	away_credits += maxf(credits_per_s, 0.0) * counted * share
	purchased.emit()


func claim_away(mult := 1.0) -> void:
	scrap += away_scrap * mult
	credits += away_credits * mult
	credits_earned += away_credits * mult
	_clear_away()
	purchased.emit()


func _clear_away() -> void:
	away_t = 0.0
	away_scrap = 0.0
	away_credits = 0.0


func buy_upgrade(id: String, free := false) -> bool:
	var cost := 0.0 if free else upgrade_cost(id)
	if upgrade_maxed(id) or upgrade_locked(id) or credits < cost:
		return false
	credits -= cost
	levels[id] = level(id) + 1
	_stats = {}
	while lines.size() < int(stat("lines")):
		lines.append(LineState.create(active_slots()))
		line_added.emit(lines.size() - 1)
	for i in lines.size():
		for type_id: String in active_slots():
			if not lines[i].has_type(type_id):
				lines[i].segments.append(SegmentState.new(type_id))
				segment_added.emit(i)
	purchased.emit()
	return true


func salvage_share() -> float:
	return minf(stat("salvage"), Data.econ("salvage_cap"))


func wave_max_hp() -> float:
	return float(Data.enemies.base_hp) * pow(float(Data.enemies.hp_growth), wave) * war_scale()


func wave_bounty() -> float:
	return float(Data.enemies.base_bounty) * pow(float(Data.enemies.bounty_growth), wave) * war_scale()


func wave_enemies() -> Array[Dictionary]:
	if _wave_listed != wave:
		_wave_list = Data.wave_enemies(wave)
		_wave_listed = wave
	return _wave_list


func wave_alive() -> int:
	var list := wave_enemies()
	var total := 0.0
	for e in list:
		total += e.weight
	var drained := (1.0 - wave_hp / wave_max_hp()) * total + 1e-6
	var cum := 0.0
	for i in list.size():
		cum += list[i].weight
		if cum > drained:
			return list.size() - i
	return 0


func kill_scrap(e: Dictionary) -> float:
	return stat("kill_scrap") * pow(float(Data.enemies.variant_scrap), e.variant) * war_scale()


func field_dps() -> float:
	var total := 0.0
	for m in field:
		total += m.dps
	return total


func wave_dps() -> float:
	return field_dps() + tap_dps


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
		"run_over": run_over,
		"lost": lost,
		"siege": siege,
		"gate_damage": gate_damage,
		"stalled_once": stalled_once,
		"seen": seen.keys(),
		"field_taps": field_taps,
		"prestige": prestige,
		"scrap_boost_t": scrap_boost_t,
		"ad_cooldown_t": ad_cooldown_t,
		"away_t": away_t,
		"away_scrap": away_scrap,
		"away_credits": away_credits,
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
	prestige = int(d.get("prestige", 0))
	levels = {}
	var saved_levels: Dictionary = d.get("levels", {})
	for id: String in saved_levels:
		levels[id] = int(saved_levels[id])
	_stats = {}
	wave = int(d.get("wave", 0))
	wave_hp = float(d.get("wave_hp", wave_max_hp()))
	yard_workers = int(d.get("yard_workers", 0))
	yard_t = float(d.get("yard_t", 0.0))
	run_over = d.get("run_over", false)
	lost = d.get("lost", false)
	siege = float(d.get("siege", 0.0))
	gate_damage = float(d.get("gate_damage", 0.0))
	stalled_once = d.get("stalled_once", false)
	seen = {}
	for key: String in d.get("seen", REVEALS if mechs_built > 0 else []):
		seen[key] = true
	field_taps = int(d.get("field_taps", 0))
	scrap_boost_t = float(d.get("scrap_boost_t", 0.0))
	ad_cooldown_t = float(d.get("ad_cooldown_t", 0.0))
	away_t = float(d.get("away_t", 0.0))
	away_scrap = float(d.get("away_scrap", 0.0))
	away_credits = float(d.get("away_credits", 0.0))
	_reset_rates()


func _step(dt: float) -> void:
	run_time += dt
	scrap_boost_t = maxf(0.0, scrap_boost_t - dt)
	ad_cooldown_t = maxf(0.0, ad_cooldown_t - dt)
	for line in lines:
		_step_workers(line, dt)
		_step_line(line, dt)
	_step_yard(dt)
	_step_field(dt)
	_step_gate(dt)
	_step_wave(dt)
	_step_rates(dt)


func _step_workers(line: LineState, dt: float) -> void:
	var interval := stat("worker_interval")
	var chunk := stat("worker_chunk")
	if line.workers == 0:
		return
	line.worker_t += dt * line.workers
	while line.worker_t >= interval:
		line.worker_t -= interval
		var target: SegmentState
		for s in line.segments:
			if s.built and not s.bar_full() and (target == null or s.work / s.bar_size() < target.work / target.bar_size()):
				target = s
		if target:
			target.work = minf(target.bar_size(), target.work + chunk)
			target.chunks += 1


func _step_yard(dt: float) -> void:
	if yard_workers == 0:
		return
	var interval := stat("worker_interval")
	yard_t += dt * yard_workers
	while yard_t >= interval:
		yard_t -= interval
		_gain_scrap(yard_chunk())
		yard_chunks += 1


func _step_line(line: LineState, dt: float) -> void:
	var segs := line.segments
	var last := line.last_built()
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
				_try_assemble(line, s, true)
		elif s.mech and s.mech.arrive_t <= 0.0 and not s.mech.has_part(s.type_id):
			_try_assemble(line, s, false)


func _try_assemble(line: LineState, s: SegmentState, spawn: bool) -> void:
	var cost := s.scrap_cost()
	if scrap < cost:
		s.stall = SegmentState.Stall.NO_SCRAP
		stalled_once = true
		return
	scrap -= cost
	_scrap_bucket -= cost
	line.use_scrap(cost)
	if spawn:
		s.mech = MechState.new()
		s.mech.id = next_mech_id
		s.mech.line = lines.find(line)
		next_mech_id += 1
	s.mech.scrap_cost += cost
	s.work = 0.0
	s.assemblies += 1
	s.assembling = true
	s.assemble_t = Data.econ("assembly_time")


func _deploy(m: MechState) -> void:
	for type_id: String in m.parts:
		var t := Data.tier(type_id, m.parts[type_id])
		m.lifetime += float(t.get("lifetime", 0.0))
		m.base_rate += float(t.get("credits_per_sec", 0.0))
		m.deploy_fee += float(t.get("deploy_fee", 0.0))
		m.dps += float(t.get("dps", 0.0))
	m.deploy_fee *= stat("deploy_fee_mult") * war_scale()
	m.base_rate *= war_scale()
	m.dps *= war_scale()
	m.arrive_t = 0.0
	field.append(m)
	mechs_built += 1
	_mech_bucket += 1
	_gain_credits(m.deploy_fee)
	mech_deployed.emit(m)
	if m.is_nuclear():
		run_over = true
		purchased.emit()
		nuke_launched.emit(m)


func debug_spawn_mechs(n: int) -> void:
	for i in n:
		var m := MechState.new()
		m.id = next_mech_id
		next_mech_id += 1
		for type_id: String in ["frame", "core", "arms"]:
			m.parts[type_id] = 0
		_deploy(m)


func payout_rate(m: MechState) -> float:
	var steps := mini(int(floor(m.age / stat("payout_interval"))), int(stat("payout_cap")))
	return m.base_rate * pow(Data.econ("payout_step"), steps)


func _step_field(dt: float) -> void:
	for m: MechState in field.duplicate():
		var c := payout_rate(m) * dt
		m.age += dt
		m.wear += dt * aging()
		_gain_credits(c)
		m.pend_credits += c
		m.pend_t += dt
		var dead := m.wear >= m.lifetime
		if m.pend_t >= 1.0 or dead:
			mech_income.emit(m, m.pend_credits)
			m.pend_t = 0.0
			m.pend_credits = 0.0
		if dead:
			var salvage := m.scrap_cost * salvage_share()
			_gain_scrap(salvage)
			field.erase(m)
			mech_died.emit(m, salvage)


func gate_attacked() -> bool:
	return siege >= 1.0 and field.is_empty() and not run_over


func gate_health() -> float:
	return 1.0 - gate_damage / Data.econ("gate_time")


func _step_gate(dt: float) -> void:
	if not field.is_empty():
		siege = maxf(0.0, siege - dt / Data.econ("gate_retreat"))
		gate_damage = maxf(0.0, gate_damage - dt * Data.econ("gate_repair"))
		return
	siege = minf(1.0, siege + dt / Data.econ("gate_approach"))
	if siege < 1.0:
		return
	gate_damage += dt
	if gate_damage >= Data.econ("gate_time"):
		gate_damage = Data.econ("gate_time")
		lost = true
		run_over = true
		purchased.emit()
		gate_fell.emit()


func tap_wave_damage() -> float:
	return stat("tap_damage") * maxf(field_dps(), float(Data.tier("arms", 0).dps) * war_scale())


func tap_wave() -> float:
	if run_over:
		return 0.0
	var damage := tap_wave_damage()
	field_taps += 1
	_tap_bucket += damage
	_damage_wave(damage)
	return damage


func _step_wave(dt: float) -> void:
	var dps := field_dps()
	if dps > 0.0:
		_damage_wave(dps * dt)


func _damage_wave(damage: float) -> void:
	var alive := wave_alive()
	wave_hp -= damage
	if wave_hp <= 0.0:
		_clear_wave()
		return
	_pay_kills(alive, wave_alive())


func _pay_kills(alive_before: int, alive_after: int) -> void:
	if stat("kill_scrap") <= 0.0:
		return
	var list := wave_enemies()
	for i in range(list.size() - alive_before, list.size() - alive_after):
		var amount := kill_scrap(list[i])
		_gain_scrap(amount)
		enemy_killed.emit(i, amount)


func _clear_wave() -> void:
	_pay_kills(wave_alive(), 0)
	var bounty := wave_bounty()
	_gain_credits(bounty)
	wave += 1
	wave_hp = wave_max_hp()
	siege = 0.0
	wave_cleared.emit(bounty)


func _gain_credits(amount: float) -> void:
	credits += amount
	credits_earned += amount
	_credits_bucket += amount


func _gain_scrap(amount: float) -> void:
	amount *= scrap_boost()
	scrap += amount
	_scrap_bucket += amount
	_scrap_gain_bucket += amount


func _step_rates(dt: float) -> void:
	_rate_t += dt
	if _rate_t < 1.0:
		return
	_rate_t -= 1.0
	for line in lines:
		line.sample_rate()
	_mech_history.append(_mech_bucket)
	mechs_per_min += _mech_bucket
	_mech_bucket = 0
	if _mech_history.size() > MECH_WINDOW:
		mechs_per_min -= _mech_history.pop_front()
	_credits_history.append(_credits_bucket)
	_scrap_history.append(_scrap_bucket)
	_scrap_gain_history.append(_scrap_gain_bucket)
	_tap_history.append(_tap_bucket)
	_credits_bucket = 0.0
	_scrap_bucket = 0.0
	_scrap_gain_bucket = 0.0
	_tap_bucket = 0.0
	if _tap_history.size() > RATE_WINDOW:
		_tap_history.pop_front()
	if _credits_history.size() > AWAY_WINDOW:
		_credits_history.pop_front()
		_scrap_history.pop_front()
		_scrap_gain_history.pop_front()
	credits_rate = _average(_credits_history.slice(-RATE_WINDOW))
	scrap_rate = _average(_scrap_history.slice(-RATE_WINDOW))
	scrap_gain_rate = _average(_scrap_gain_history.slice(-RATE_WINDOW))
	tap_dps = _average(_tap_history)


func _average(values: Array[float]) -> float:
	var total := 0.0
	for v in values:
		total += v
	return total / maxi(values.size(), 1)


func _reset_rates() -> void:
	_rate_t = 0.0
	_credits_bucket = 0.0
	_scrap_bucket = 0.0
	_scrap_gain_bucket = 0.0
	_credits_history = []
	_scrap_history = []
	_scrap_gain_history = []
	_tap_bucket = 0.0
	_tap_history = []
	tap_dps = 0.0
	_mech_bucket = 0
	_mech_history = []
	mechs_per_min = 0
	credits_rate = 0.0
	scrap_rate = 0.0
	scrap_gain_rate = 0.0
