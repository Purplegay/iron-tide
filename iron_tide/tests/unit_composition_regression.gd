extends "res://tests/unit_muzzle_regression.gd"
## Reuse the real eight-facing body/turret/muzzle suite with the reported
## purple house shader enabled, instead of the default unshaded blue.

var last_progress_ms := Time.get_ticks_msec()

func check(ok: bool, label: String, details = null) -> void:
	last_progress_ms = Time.get_ticks_msec()
	super.check(ok, label, details)
	if "body points" in label:
		print("COMPOSITION ", label)

func _process(_delta: float) -> void:
	if Time.get_ticks_msec() - last_progress_ms > 60000:
		push_error("Composition renderer made no assertion progress for 60 seconds.")
		get_tree().quit(2)

func exercise_mode(mode: String) -> void:
	var previous := HouseColor.player_id
	HouseColor.set_player_id("purple")
	await super.exercise_mode(mode)
	HouseColor.set_player_id(previous)
