extends RefCounted
## Visual adapter for the YR Hover locomotor, not an aircraft altitude.
## Stock rulesmd.ini [General]: HoverHeight=120, HoverDampen=40%, HoverBob=.04.
## The projected height and settling curve are Godot presentation choices;
## this does not claim to reproduce the proprietary locomotor's integration.
const HEIGHT_LEPTONS := 120.0
const DAMPEN := 0.4
const BOB := 0.04
const HEIGHT_TO_PIXELS := 30.0 / 256.0

var lift := 0.0
var phase := 0.0

func tick(unit, delta: float, offline: bool) -> void:
	if str(unit._mv("speed_type", "")).to_lower() != "hover" or unit.is_air:
		return
	phase = fposmod(phase + delta * BOB * 15.0 * TAU, TAU)
	var height := HEIGHT_LEPTONS * HEIGHT_TO_PIXELS
	var target := 0.0 if offline else height + sin(phase + float(unit._seed % 97)) * height * 0.12
	lift = lerpf(lift, target, 1.0 - exp(-DAMPEN * 15.0 * delta))
	if offline and lift < 0.01: lift = 0.0
	# Idle unselected units also animate; shadow and collision remain at ground level.
	if not offline or lift > 0.0 or unit._art_lift > 0.0: unit.queue_redraw()
