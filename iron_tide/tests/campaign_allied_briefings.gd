extends Node

func _ready() -> void:
	if not OS.get_user_data_dir().contains("CampaignBriefingTest"):
		push_error("Run with isolated APPDATA (CampaignBriefingTest).")
		get_tree().quit(2)
		return
	var menu = preload("res://scenes/campaign_command.tscn").instantiate()
	add_child(menu)
	menu.choose_faction("allied")
	var expected := {
		"时间流逝": ["旧金山与恶魔岛", "美国 · 旧金山", "派工程师占领任务发电厂，为时光机恢复供电。\n保护时光机并完成穿越。\n摧毁恶魔岛的心灵控制器。"],
		"好莱坞梦一场": ["洛杉矶作战地图", "美国 · 洛杉矶", "在洛杉矶机场接应基地车并展开基地。\n摧毁城内四座部队回收厂，解救居民。\n摧毁尤里两处基地的剩余建筑。"],
		"脑死": ["火地岛与南极作战地图", "火地岛 · 南极洲", "接管火地岛苏军基地，建造雷达。\n接收超时空增援并展开盟军基地车。\n摧毁心灵控制器，消灭尤里的部队。"],
	}
	for title in expected:
		var found := false
		for button in menu.page.find_children("*", "Button", true, false):
			if button.text == title:
				button.pressed.emit()
				found = true
				break
		var labels := {}
		for label: Label in menu.page.find_children("*", "Label", true, false):
			labels[label.position] = label.text
		var copy: Array = expected[title]
		if not found or labels.get(Vector2(285,196)) != copy[0] or labels.get(Vector2(285,550)) != copy[1] or labels.get(Vector2(786,293)) != copy[1] or labels.get(Vector2(285,646)) != copy[2]:
			push_error("Unexpected briefing content for %s" % title)
			get_tree().quit(1)
			return
		print("CAMPAIGN_BRIEFING_PASS ", title)
	get_tree().quit()
