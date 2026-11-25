extends Node
var checks:=0
var failed:=0
func check(ok:bool,label:String) -> void:
	checks+=1
	if not ok:failed+=1;print("FAIL ",label)
func _ready() -> void:
	if not OS.get_user_data_dir().contains("CodexIronTideValidation"):get_tree().quit(2);return
	check(Expedition.start("美国","",713),"start isolated campaign")
	Expedition.state.buffs={"engines":1}
	Expedition.state.offers=[{"kind":"buff","id":"engines","levels":1,"price":0},{"kind":"trait_buff","id":"support","levels":1},{"kind":"trait_buff","id":"infantry","levels":2,"manual":true},{"kind":"relic","id":"bridge_station"}]
	Expedition.state.reward_round="buff"
	var ui=load("res://scenes/expedition.tscn").instantiate();add_child(ui)
	await get_tree().process_frame
	var labels:Array=ui.find_children("*","Label",true,false)
	check(labels.any(func(entry):return entry.text=="当前等级 1 / 3 → 获得后 2 / 3"),"reward buff shows current and next level")
	var market=preload("res://scripts/expedition/market.gd")
	for item:Dictionary in Expedition.state.offers:
		var grade:String=market.item_grade(Expedition.state,item)
		var title:String=preload("res://scripts/expedition/catalog.gd").name_of(item)
		if not title.begins_with(grade+" · "):title=grade+" · "+title
		var hits:=labels.filter(func(entry):return entry.text==title)
		check(hits.size()==1,"rarity appears once on "+item.id)
		if hits.size()==1:
			var color:=Color(market.Relics.COLORS[grade])
			check(hits[0].get_theme_color("font_color")==color and hits[0].get_parent().get_parent().get_parent().get_theme_stylebox("panel").border_color==color,"title and frame match rarity "+item.id)
	for count in [0, 2, 3, 5, 6, 8, 9]:
		Expedition.state.trait_buffs.support = count
		for gain in [1, 2]:
			var offer := {"kind":"trait_buff", "id":"support", "levels":gain}
			var box: VBoxContainer = ui.card(self, offer, func(): pass, "购买")
			var texts := PackedStringArray()
			for entry in box.find_children("*", "Label", true, false): texts.append(entry.text)
			var actual := "\n".join(texts)
			var target := mini(9, count + gain)
			var expected := "获得后 %d 层：%s" % [target, market.Army.Progress.summary("support", target)] if count < 9 else "已满 9 层"
			check(actual.contains(expected), "correct resulting layer %d + %d" % [count, gain])
			for threshold in [3, 6, 9]:
				check(actual.contains("%d 层解锁：" % threshold) == (threshold > count), "future milestone %d at %d" % [threshold, count])
			check(not actual.contains("搭配建议") and not actual.contains("受益兵种"), "compact card")
			box.get_parent().free()
	ui.free()
	print("REWARD LEVEL DISPLAY checks=",checks," failed=",failed)
	get_tree().quit(0 if failed==0 else 1)
