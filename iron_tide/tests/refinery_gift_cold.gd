extends Node

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	if not ProjectSettings.get_setting("application/config/use_custom_user_dir", false):
		get_tree().quit(2)
		return
	get_tree().current_scene = null
	var ok := true
	for slot in ["slot1", "slot2"]:
		var result: Dictionary = BattleSaves.load_into_scene(slot)
		if not result.ok:
			ok = false
			continue
		await get_tree().process_frame
		await get_tree().process_frame
		var screen = get_tree().current_scene
		var world = screen.battle
		var n: int = world.units.size()
		var funds: float = world.funds
		var found := false
		for b in world.buildings:
			if not b.special.get("gift_test", false): continue
			found = true
			ok = ok and b.special.get("construction_free_unit") == "CMIN"
			b._process(1.0)
			b.notify_construction_placed()
			b._process(1.0)
			ok = ok and world.units.size() == n + 1 and world.funds == funds and world.units[-1].home_base == b
		ok = ok and found
		get_tree().paused = false
		get_tree().current_scene = null
		screen.free()
		await get_tree().process_frame
	print("REFINERY_GIFT_COLD passed=", ok)
	get_tree().quit(0 if ok else 1)
