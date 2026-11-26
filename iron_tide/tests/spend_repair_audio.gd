extends Node

func _ready() -> void:
	BattleRequest.configure_skirmish(MatchRules.EXTENDED, {"starting_funds": 50000})
	var screen = preload("res://scenes/battle.tscn").instantiate()
	add_child(screen)
	screen.process_mode = Node.PROCESS_MODE_DISABLED
	var world = screen.battle
	var starting_funds: float = world.funds
	var before := Ra2Sfx.a_plays
	assert(world.spend_funds(10))
	assert(Ra2Sfx.a_plays == before)
	assert(world.try_spend(1))
	assert(Ra2Sfx.a_plays == before)
	assert(not world.try_spend(world.funds + 1))
	assert(world.try_spend(0))
	assert(world.spend_side("enemy", 1))
	assert(Ra2Sfx.a_plays == before)
	assert(world.try_spend(1))
	assert(Ra2Sfx.a_plays == before)
	assert(world.funds == starting_funds - 12)
	var hq = world._player_hq()
	hq.hp = hq.max_hp * 0.8
	Ra2Sfx.stop_eva()
	var voices := Ra2Sfx.a_eva_plays
	world.allied_state.area_repair = 2
	world._tick_area_repair()
	assert(hq.repairing and Ra2Sfx.a_eva_plays == voices + 1)
	world._tick_area_repair()
	assert(Ra2Sfx.a_eva_plays == voices + 1)
	print("SPEND_REPAIR_AUDIO_PASS")
	get_tree().quit()
