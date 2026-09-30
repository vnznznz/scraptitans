class_name Reveal

const TIME := 0.4
const SLIDE_TIME := 0.6

static var instant := false


static func step(k: float, on: bool, delta: float, time := TIME) -> float:
	var target := 1.0 if on else 0.0
	if instant:
		return target
	return move_toward(k, target, delta / time)


static func eased(k: float) -> float:
	return smoothstep(0.0, 1.0, k)


static func moving(k: float) -> bool:
	return k > 0.0 and k < 1.0
