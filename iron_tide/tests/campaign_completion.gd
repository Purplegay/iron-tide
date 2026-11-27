extends Node

const Payout = preload("res://scripts/rules/campaign_payout.gd")
var failures := 0

func expect(ok: bool, message: String) -> void:
	print("CAMPAIGN COMPLETION ", ok, " ", message)
	if not ok: failures += 1

func press(menu: Control, title: String) -> void:
	for btn in menu.find_children("*", "Button", true, false):
		if btn.text == title:
			btn.pressed.emit()
			return
	expect(false, "找不到按钮：" + title)

func marks(menu: Control) -> Array[Vector2]:
	var result: Array[Vector2] = []
	for label in menu.find_children("*", "Label", true, false):
		if label.text == "已完成": result.append(label.position)
	return result

func has_label(menu: Control, caption: String) -> bool:
	return menu.find_children("*", "Label", true, false).any(func(label): return label.text == caption)

func check_allied_first_rewards(menu: Control) -> void:
	press(menu,"时间流逝")
	expect(has_label(menu,"首胜") and has_label(menu,"重打胜利") and not has_label(menu,"无尽挑战 · 按波数结算"),"美国首关显示剧情奖励表，不显示无尽文案")
	var mission: Dictionary = menu.mission
	var first := Payout.settle(mission,{"match_id":"allied-first-win","win":true,"draw":false})
	expect(first.get("first_win",false) and first.war_points==200 and first.credits==1200 and first.diamonds==30,"美国首关首胜奖励入账")
	menu.draw_page()
	expect(has_label(menu,"已领首胜") and marks(menu).size()==2,"首胜后列表和简报显示已完成")
	var repeat := Payout.settle(mission,{"match_id":"allied-first-repeat","win":true,"draw":false})
	expect(not repeat.get("first_win",true) and repeat.war_points==10 and repeat.credits==60 and repeat.diamonds==0,"重复胜利按正常战役规则结算")

func _ready() -> void:
	if not OS.get_user_data_dir().contains("CampaignCompletionTest"):
		push_error("CampaignCompletionTest 必须使用隔离存档目录")
		get_tree().quit(2)
		return
	var menu := preload("res://scenes/campaign_command.tscn").instantiate()
	add_child(menu)
	press(menu, "Iron Tide 原创战役")
	var writing := "--write" in OS.get_cmdline_user_args()
	if writing:
		expect(marks(menu).is_empty(), "新档不显示完成标记")
		Payout.settle(menu.mission, {"match_id":"completion-loss", "win":false, "draw":false})
		menu.draw_page()
		expect(marks(menu).is_empty(), "失败不显示完成标记")
		var reward := Payout.settle(menu.mission, {"match_id":"completion-win", "win":true, "draw":false})
		expect(reward.get("first_win", false) and MetaProgress.save(), "首次正常胜利写入原有通关记录")
		menu.draw_page()
	expect(marks(menu) == [Vector2(188, 308), Vector2(1160, 207)], "已通关项同时标在任务行和当前简报")
	press(menu, "结晶裂谷")
	expect(marks(menu) == [Vector2(188, 308)], "换到未通关任务：原行仍标记，当前简报不标记")
	press(menu, "灰烬要塞")
	expect(has_label(menu,"无尽挑战 · 按波数结算"),"真正的无尽关仍显示按波数结算")
	expect(marks(menu) == [Vector2(188, 308)], "无尽关不显示通关标记")
	press(menu, "断轨平原")
	expect(marks(menu).size() == 2, "已完成任务仍可选择和重打")
	press(menu, "‹  更换阵营")
	press(menu, "盟军战役")
	expect(marks(menu).is_empty(), "其他阵营不会误用本关胜利记录")
	if "--allied-first-rewards" in OS.get_cmdline_user_args(): check_allied_first_rewards(menu)
	get_tree().quit(failures)
