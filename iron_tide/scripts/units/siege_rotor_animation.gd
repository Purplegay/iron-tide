extends Node
## Presentation-only clock. A two-pose 20 fps rotor must not be sampled at 15 Hz.
var unit: Unit
var clock := 0.0
var last_frame := -1

func _init(actor: Unit) -> void:
	unit = actor
	clock = actor._anim

func phase(art: Dictionary) -> int:
	return posmod(int(clock * float(art.get("fps", 20.0)) + 0.00001), maxi(1, int(art.get("poses", 1))))

func _process(delta: float) -> void:
	clock += delta
	if unit._dead or unit._dying > 0.0 or unit.embarked_in != null or unit.logistics.air_lift <= 0.1 or unit._ra2.get("key") != "SCHP":
		last_frame = -1
		return
	var next := phase(unit._ra2)
	if next != last_frame:
		last_frame = next
		unit.queue_redraw()
