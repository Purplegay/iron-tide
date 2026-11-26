extends Node

var failed := 0

func check(ok: bool, label: String) -> void:
	print("CAMPAIGN_MARKS ", ok, " ", label)
	if not ok: failed += 1

func _ready() -> void:
	call_deferred("run")

func run() -> void:
	var tree := get_tree()
	reparent(tree.root)
	var args := OS.get_cmdline_user_args()
	var id := args[0] if not args.is_empty() else "m02"
	var title: String = GameData.get_mission(id).name
	var menu = load("res://scenes/campaign_command.tscn").instantiate()
	tree.root.add_child(menu)
	for button in menu.find_children("*", "Button", true, false):
		if button.text == "Iron Tide 原创战役":
			button.pressed.emit()
			break
	if menu.mission.id != id:
		for button in menu.find_children("*", "Button", true, false):
			if button.text == title:
				button.pressed.emit()
				break
	check(menu.mission.id == id, "从原创战役菜单选关：" + title)
	if failed:
		tree.quit(failed)
		return
	BattleRequest.configure_mission(id, {"campaign_growth": false, "difficulty": 1, "country": "美国"})
	var scene = load("res://scenes/battle.tscn").instantiate()
	tree.root.add_child(scene)
	tree.current_scene = scene
	var world = scene.battle
	var radar = world.hud.minimap
	var field_marks: Array = world.CampaignMarks.marks(world, false)
	var map_marks: Array = radar.objective_marks()
	check(world.mission.id == id, "进入目标战场")
	if id == "m02":
		check(field_marks.size() == 2 and map_marks.size() == 2 and field_marks.all(func(mark): return mark.actor.is_spawner and mark.actor.side == "enemy"), "两处胜利条件孵化巢均有标记")
		if field_marks.size() == 2:
			check(radar._focus_point(map_marks[0].local).is_equal_approx(field_marks[0].position), "点击孵化巢菱形定位目标")
			field_marks[0].actor.receive_hit(100000)
			check(world.CampaignMarks.marks(world, false).size() == 1 and radar.objective_marks().size() == 1, "摧毁一处后不再标记该目标")
			field_marks[1].actor.receive_hit(100000)
			check(world.CampaignMarks.marks(world, false).is_empty() and radar.objective_marks().is_empty(), "摧毁两处后没有残留标记")
	else:
		check(field_marks.is_empty() and map_marks.is_empty(), "守波或生存关无固定目标，不制造标记")
	tree.quit(failed)
