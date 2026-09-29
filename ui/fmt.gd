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


static func rate(x: float) -> String:
	var sign := "-" if x <= -0.1 else "+"
	x = absf(x)
	if x < 10.0:
		return "%s%.1f/S" % [sign, floor(x * 10.0) / 10.0]
	return "%s%s/S" % [sign, num(x)]
