extends VBoxContainer
## Shared by the main-menu backend and the in-battle Ctrl+G console.
const PREFERENCES := "user://gm_unit_picker.cfg"
var notify: Callable
var choices: OptionButton
var search: LineEdit
var count: SpinBox
var side: OptionButton
var rank: OptionButton
var health: SpinBox
var stationary: CheckBox
var ids: Array[String]=[]

func _ready() -> void:
	add_theme_constant_override("separation",6)
	var title:=UiKit.make_label("单位测试 · 当前视野生成",16,UiKit.COL_ACCENT);add_child(title)
	search=LineEdit.new();search.placeholder_text="中文名称 / 单位 ID，例如：未来、炮艇、R3";search.name="UnitSearch";add_child(search)
	choices=OptionButton.new();choices.name="UnitChoice";choices.fit_to_longest_item=false;choices.custom_minimum_size=Vector2(0,32);add_child(choices)
	search.text_changed.connect(_filter)
	choices.item_selected.connect(_remember_choice)
	visibility_changed.connect(_restore_choice)
	_restore_choice()
	if ids.is_empty(): _filter("")
	var row:=HBoxContainer.new();add_child(row)
	side=UiKit.make_option(["我方","敌方"],0);row.add_child(side)
	row.add_child(UiKit.make_label("数量",12));count=UiKit.make_spin(1,1,50,1);row.add_child(count)
	rank=UiKit.make_option(["新兵","老兵","精英","英雄（RA3）"],0);row.add_child(rank)
	var row2:=HBoxContainer.new();add_child(row2)
	row2.add_child(UiKit.make_label("血量 %",12));health=UiKit.make_spin(100,1,100,1);row2.add_child(health)
	stationary=UiKit.make_check("靶标（地面静止，飞机飞行，不还击）",false);row2.add_child(stationary)
	button("生成所选单位", "SpawnUnit", func():
		if choices.selected < 0 or choices.selected >= ids.size(): return
		_remember_choice(choices.selected)
		command("spawn",{"id":ids[choices.selected],"count":int(count.value),"side":"ally" if side.selected==0 else "enemy","rank":rank.selected,"health":health.value,"stationary":stationary.button_pressed}))
	button("一键生成所选方阵营的全部兵种（每种 1 个）","SpawnFaction",func():
		command("faction",{"side":"ally" if side.selected==0 else "enemy","rank":rank.selected,"health":health.value,"stationary":stationary.button_pressed}))
	button("快捷：未来坦克 + 先锋炮艇（我方）","SpawnExpansion",func():
		var results: Array[String]=[]
		for id in ["R3FUTURE","R3HARBINGER"]:results.append(GM.cmd_unit_tools({"action":"spawn","id":id,"side":"ally","count":1}))
		notify.call("\n".join(results)))
	button("生成测试靶标（含全部 RA3）","SpawnTargets",func():command("targets"))
	add_child(UiKit.make_label("下方操作作用于当前框选单位",12,UiKit.COL_ACCENT))
	button("选中单位：应用上方血量 %","SetHealth",func():command("health",{"health":health.value}))
	button("选中单位：一键升星（各升一级）","PromoteOnce",func():command("promote"))
	button("选中单位：应用上方军衔","SetRank",func():command("rank",{"rank":rank.selected}))
	button("选中单位：重置冷却／补满弹药","ResetCooldown",func():command("reset"))
	button("选中单位：停止并禁止自动开火","StopUnits",func():command("stop"))
	button("清除本局 GM 生成的单位","ClearSpawns",func():command("clear"))
	if not GM.has_battle_tools():
		button("进入单位测试场（无 AI、无胜负结算）","LaunchUnitLab",func():
			BattleRequest.configure_skirmish(MatchRules.EXTENDED,{"map_size":3200,"starting_funds":50000,"country":"美国","enemy_base":"allied","difficulty":0,"fog_of_war":false,"gm_unit_lab":true})
			get_tree().change_scene_to_file("res://scenes/battle.tscn"))

func _remember_choice(index: int) -> void:
	if index < 0 or index >= ids.size(): return
	var prefs := ConfigFile.new()
	prefs.set_value("picker", "unit_id", ids[index])
	var error := prefs.save(PREFERENCES)
	if error != OK: push_warning("GM 单位选择保存失败：" + error_string(error))

func _restore_choice() -> void:
	if not is_visible_in_tree(): return
	search.clear()
	_filter("")
	var prefs := ConfigFile.new()
	if prefs.load(PREFERENCES) != OK: return
	var index := ids.find(str(prefs.get_value("picker", "unit_id", "")))
	if not ids.is_empty(): choices.select(maxi(0, index))

func _filter(query: String) -> void:
	var previous:=ids[choices.selected] if choices.selected>=0 and choices.selected<ids.size() else ""
	ids.clear();choices.clear()
	for data: Dictionary in GameData.units:
		if str(data.get("id", "")) in GameData.FieldCommission.HIDDEN: continue
		var id:=str(data.get("id",""));var label: String="%s · %s" % [str(data.get("name",id)),id]
		if query.strip_edges().is_empty() or query.strip_edges().to_lower() in label.to_lower():
			ids.append(id);choices.add_item(label)
	if ids.has(previous):choices.select(ids.find(previous))

func button(text: String, id: String, callback: Callable) -> void:
	var item:=UiKit.make_button(text);item.name=id;item.pressed.connect(callback);add_child(item)

func command(action: String, extra: Dictionary={}) -> void:
	var request:=extra.duplicate();request.action=action
	notify.call(GM.cmd_unit_tools(request))
