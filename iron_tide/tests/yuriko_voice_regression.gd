extends Node

const Psi = preload("res://scripts/units/yuriko.gd")
var failures := 0
var checks := 0

func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok: failures += 1
	print("PASS " if ok else "FAIL ", message)

func _ready() -> void:
	if not ProjectSettings.get_setting("application/config/use_custom_user_dir", false):
		get_tree().quit(2)
		return
	call_deferred("run")

func wait_for_end(player: Node) -> void:
	var handle := player.get_instance_id()
	var deadline := Time.get_ticks_msec() + 12000
	while is_instance_id_valid(handle) and Time.get_ticks_msec() < deadline:
		await get_tree().process_frame
	check(not is_instance_id_valid(handle), "native clip finished")

func run() -> void:
	BattleRequest.configure_skirmish(MatchRules.EXTENDED, {"country":"美国", "map_size":2400, "starting_funds":8000})
	var screen = load("res://scenes/battle.tscn").instantiate()
	add_child(screen)
	var world = screen.battle
	world._place_building("GAPILE", "ally", world.player_start()+Vector2(175,95), true)
	check(Psi.summon(world), "normal barracks summon")
	var u = Psi.hero(world)
	world.process_mode = Node.PROCESS_MODE_DISABLED
	check(Ra2Sfx._yuriko_layers.size()==1, "creation line uses dedicated player")
	if Ra2Sfx._yuriko_layers.is_empty():
		get_tree().quit(1)
		return
	var created: Node = Ra2Sfx._yuriko_layers[0]
	check(created.stream.resource_path.ends_with("JUYurik_VoiCreatec.wav"), "creation precedes automatic selection")
	var count := Ra2Sfx.a_voice_plays
	check(world._play_group_voice([u], "move", 0) and world._play_group_voice([u], "select", 0), "rapid orders accepted")
	check(Ra2Sfx.a_voice_plays==count and created.playing and Ra2Sfx._yuriko_next.id==Ra2Sfx.voice_id(u.data,"select"), "creation finishes before latest command")
	for i in Ra2Sfx.POOL_SIZE+2: Ra2Sfx.play("SupportReady")
	check(created.playing and world._play_group_voice([world.spawn_unit("E1","ally",u.position)], "move", 0), "pool saturation and another unit's response coexist")
	await wait_for_end(created)
	check(Ra2Sfx._yuriko_layers.size()==2 and Ra2Sfx.unit_voice_active(), "selection starts both retail layers after creation")
	if Ra2Sfx._yuriko_layers.size()!=2:
		get_tree().quit(1)
		return
	var spoken: Node = Ra2Sfx._yuriko_layers[0]
	var psychic: Node = Ra2Sfx._yuriko_layers[1]
	spoken.pitch_scale=5
	psychic.pitch_scale=0.5
	check(Psi.burst(u) and Ra2Sfx._yuriko_next.id==Ra2Sfx.voice_id(u.data,"burst_yell"), "Q fires while its shout waits")
	await wait_for_end(spoken)
	check(Ra2Sfx._yuriko_layers.size()==1 and psychic.playing and not Ra2Sfx._yuriko_next.is_empty(), "both selection layers must finish")
	psychic.pitch_scale=4
	await wait_for_end(psychic)
	check(Ra2Sfx._yuriko_layers.size()==1 and Ra2Sfx._yuriko_next.is_empty(), "Q shout now playing")
	var shout: Node = Ra2Sfx._yuriko_layers[0]
	check(shout is AudioStreamPlayer2D and shout.global_position==u.global_position, "shout retains world position")
	world._play_group_voice([u], "attack", 0)
	u._die()
	check(shout.playing and Ra2Sfx._yuriko_next.id==Ra2Sfx.voice_id(u.data,"die"), "death replaces waiting order and preserves active shout")
	check(not Ra2Sfx.play_voice(u.data,"move",Vector2.INF,0), "stale order cannot replace pending farewell")
	await wait_for_end(shout)
	var farewell: Node = Ra2Sfx._yuriko_layers[0]
	check(farewell.playing and farewell is AudioStreamPlayer2D, "positional farewell starts after shout")
	await wait_for_end(farewell)
	check(Ra2Sfx._yuriko_layers.is_empty() and Ra2Sfx._yuriko_next.is_empty(), "silent after death")
	var data: Dictionary = GameData.get_unit("YURIKO")
	Ra2Sfx.play_voice(data,"select",Vector2.INF,0)
	Ra2Sfx.play_voice(data,"move",Vector2.INF,0)
	screen.free()
	check(Ra2Sfx._yuriko_layers.is_empty() and Ra2Sfx._yuriko_next.is_empty() and not Ra2Sfx.unit_voice_active(), "battle exit cancels active and pending voices")
	print("YURIKO VOICE checks=", checks, " failed=", failures)
	get_tree().quit(0 if failures==0 else 1)
