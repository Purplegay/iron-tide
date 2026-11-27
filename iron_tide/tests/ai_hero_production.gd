extends Node

var checks := 0
var failures := 0

func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok: failures += 1
	print(("通过：" if ok else "失败：") + label)

func _ready() -> void:
	run.call_deferred()

func run() -> void:
	BattleRequest.configure_skirmish(MatchRules.RA2, {"map_size": 3200, "starting_funds": 8000, "enemy_base": "allied"})
	var screen := preload("res://scenes/battle.tscn").instantiate()
	add_child(screen)
	var world: Battle = screen.battle
	world.paused = true
	for id in GameData.UNIQUE_HERO_TYPES:
		check(not GameData.ai_product_allowed(id), id + " 不进入 AI 候选池")
	for id in ["E1", "E2", "MTNK", "HTNK", "ORCA", "TTNK", "FV", "HARV"]:
		check(GameData.ai_product_allowed(id), id + " 普通兵种不受英雄禁令影响")
	var ai = world.skirmish_ai
	check(ai != null and "E1" in ai._unit_pool and not "TANY" in ai._unit_pool, "正式遭遇战 AI 候选池保留美国大兵而排除谭雅")
	var factory: Building = world._place_building("GAPILE", "enemy", Vector2(1500, 1400), true)
	factory.buildable.assign(["TANY", "E1"])
	factory._buildup_play = -1.0
	factory.powered = false
	check(not factory.can_queue("TANY") and not factory.enqueue("TANY"), "敌方兵营不能排队制造谭雅")
	check(factory.enqueue("E1"), "同一兵营仍能排普通步兵")
	factory.cancel_queue()
	factory.production.assign(["TANY", "E1"])
	var funds := world.funds_for("enemy")
	factory.progress = 3.0
	factory.production_paid = 20.0
	factory._tick_unit_queues(1.0)
	check(factory.production == ["E1"] and is_equal_approx(world.funds_for("enemy"), funds + 20.0), "既有非法订单取消退款，不堵合法订单")
	var player_factory: Building = world._place_building("GAPILE", "ally", Vector2(1300, 1400), true)
	world._place_building("GATECH", "ally", Vector2(1050, 1400), true)
	player_factory.buildable.assign(["TANY"])
	var player_block := player_factory.queue_block_reason("TANY")
	check(player_factory.enqueue("TANY"), "玩家满足前置时仍可制造谭雅" + player_block)
	BattleRequest.house_teams["house2"] = 0
	factory.side = "house2"
	check(not factory.can_queue("TANY") and not factory.enqueue("TANY"), "其他电脑房同样不能排英雄")
	var story_actor = world.spawn_unit("YURIPR", "enemy", Vector2(1520, 1600))
	check(story_actor != null, "指定阵营的场景脚本仍可直接放置英雄")
	BattleRequest.house_teams.clear()
	screen.queue_free()
	await get_tree().process_frame
	print("AI_HERO_PRODUCTION %d/%d" % [checks - failures, checks])
	get_tree().quit(1 if failures else 0)
