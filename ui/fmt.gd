class_name Fmt

const SUFFIXES := ["", "K", "M", "B", "T", "Qa", "Qi", "Sx", "Sp", "Oc", "No", "Dc"]


static func num(x: float) -> String:
	if x < 1000.0:
		return str(int(floor(x)))
	var e := mini(int(floor(log(x) / log(1000.0))), SUFFIXES.size() - 1)
	var v := x / pow(1000.0, e)
	if v >= 100.0:
		return "%d%s" % [int(floor(v)), SUFFIXES[e]]
	return "%.1f%s" % [floor(v * 10.0) / 10.0, SUFFIXES[e]]


static func short(x: float) -> String:
	var text := num(x)
	return whole(x) if text.length() > 4 else text


static func whole(x: float) -> String:
	if x < 1000.0:
		return str(roundi(x))
	var e := mini(int(floor(log(x) / log(1000.0))), SUFFIXES.size() - 1)
	return "%d%s" % [int(floor(x / pow(1000.0, e))), SUFFIXES[e]]


static func rate(x: float) -> String:
	var sign := "-" if x <= -0.1 else "+"
	x = absf(x)
	if x < 10.0:
		return "%s%.1f/S" % [sign, floor(x * 10.0) / 10.0]
	return "%s%s/S" % [sign, short(x)]


static func mult(x: float) -> String:
	var v := snappedf(x, 1.0) if x >= 10.0 else snappedf(x, 0.01)
	return "X" + (str(int(v)) if is_equal_approx(v, roundf(v)) else str(v))


static func span(seconds: float) -> String:
	var minutes := maxi(1, floori(seconds / 60.0))
	if minutes < 60:
		return "%d MIN" % minutes
	return "%d H" % (minutes / 60) if minutes % 60 == 0 else "%d H %d MIN" % [minutes / 60, minutes % 60]


static func clock(seconds: float) -> String:
	var s := ceili(seconds)
	return "%d:%02d" % [s / 60, s % 60]
