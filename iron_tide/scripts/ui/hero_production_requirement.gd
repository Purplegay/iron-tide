extends RichTextLabel

const Academy=preload("res://scripts/rules/academy.gd")
const Showcase=preload("res://scripts/ui/unit_showcase.gd")

func _ready() -> void:
	bbcode_enabled=true
	fit_content=true
	scroll_active=false
	mouse_filter=Control.MOUSE_FILTER_PASS
	add_theme_font_size_override("normal_font_size",get_theme_font_size("font_size","Label"))

func show_requirement(hero:String,count:int) -> void:
	if hero in Academy.Stars.IDS:
		text="中立英雄 · 各阵营均可在中立英雄制造所招募，同一位英雄同时在场一人。"
		return
	if hero in ["FV","HARV"]:
		text=("已解锁" if count>0 else "尚未解锁")+"　·　"+("己方步兵登上普通多功能步兵车，当场晋升，每局一次。" if hero=="FV" else "同一辆武装矿车先打伤敌人，再采矿入仓。后续局首辆付费生产的武装矿车晋升，每局一次。")
		return
	var goal:=Academy.hero_requirement(hero)
	var units:=PackedStringArray()
	var arrival:String
	var action:="累计生产"
	if hero=="ORCA":
		for id:String in Academy.PEREGRINE_PRODUCTS:
			units.append(unit_link(id))
		action="累计主动生产以下任一机型"
		arrival="达标从下一局生效。扩展遭遇战中，盟军玩家首次生产上述机型时额外赠送游隼，原机保留，游隼不占机场位。"
	else:
		units.append(unit_link(hero))
		var unit_name:String=GameData.get_unit(hero).name
		if hero in Unit.TankHero.IDS:
			arrival="每场扩展遭遇战，对应阵营车厂就绪后自动赠送 1 辆%s，不占生产队列。"%Academy.HEROES[hero]
		elif hero=="TTNK":
			action="累计主动生产"
			arrival="达标从下一局生效。每局第三辆%s完成时额外赠送雷铸，原车保留。"%unit_name
		elif hero in Academy.Commandos.IDS:
			action="兵营累计主动生产"
			arrival="达标从下一局生效。每场扩展遭遇战首名主动生产的%s满军衔出厂，带 ☆ 英雄标记。远征中，招募英雄、超时空编制普通兵和兵营普通兵各可同时在场一名。"%unit_name
		else:
			action="兵营累计生产"
			arrival="解锁后，每场扩展遭遇战首名%s以英雄「%s」身份满军衔出厂。"%[unit_name,Academy.HEROES[hero]]
	text="%s　·　%s %s　%d / %d。%s"%["已解锁" if count>=goal else "尚未解锁",action,"、".join(units),count,goal,arrival]

func unit_link(id:String) -> String:
	return "[hint=%s][color=#%s][u]%s[/u][/color][/hint]"%[id,UiKit.COL_ACCENT_2.to_html(false),GameData.get_unit(id).name]

func _make_custom_tooltip(id:String) -> Object:
	if not GameData.unit_index.has(id):return null
	var panel:=UiKit.make_panel(UiKit.COL_PANEL,UiKit.COL_ACCENT_2)
	var column:=VBoxContainer.new()
	panel.add_child(column)
	column.add_child(UiKit.make_label(GameData.get_unit(id).name,16,UiKit.COL_ACCENT_2))
	var model:=Showcase.new()
	model.ready.connect(model.show_unit.bind(id),CONNECT_ONE_SHOT)
	column.add_child(model)
	return panel
