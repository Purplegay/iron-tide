extends "res://tests/base_recovery_regression.gd"
const Houses = preload("res://scripts/rules/skirmish_houses.gd")
const Preferences = preload("res://scripts/ui/lobby_preferences.gd")

func choose(picker: OptionButton, index: int) -> void:
	picker.select(index)
	picker.item_selected.emit(index)

func choose_color(picker: OptionButton, id: String) -> void:
	for i in picker.item_count:
		if picker.get_item_metadata(i) == id:
			choose(picker, i)
			return
	check(false, "palette contains " + id)

func roster(count: int) -> Array:
	var rows: Array = []
	for i in count: rows.append({"team":i+1,"seat":i,"spawn":i,"country":"美国","color":"auto"})
	return rows

func verify_actor(actor, color_id: String, label: String) -> void:
	var expected := Color(HouseColor.hex_of(color_id))
	check(actor._col.is_equal_approx(expected), label + " actor/minimap colour")
	check(actor.material != null and actor.material.get_shader_parameter("target_color").is_equal_approx(expected), label + " shader tint")

func _ready() -> void:
	process_mode=Node.PROCESS_MODE_ALWAYS
	output_dir=OS.get_environment("IRON_TIDE_REPORT_DIR")
	if output_dir.is_empty() or not OS.get_user_data_dir().contains("CodexIronTideValidation"):
		get_tree().quit(2); return
	await get_tree().process_frame
	if "--house-colors-cold" in OS.get_cmdline_user_args():
		var cold_lobby=load("res://scenes/lobby.tscn").instantiate();add_child(cold_lobby)
		check(cold_lobby._team_rows[1].color=="indigo" and cold_lobby._team_rows[2].color=="magenta", "fresh process restores AI colour preferences")
		cold_lobby.free()
		var load_result:=BattleSaves.prepare_load(BattleSaves.SLOTS[0])
		check(load_result.ok,"fresh process accepts coloured battle save")
		screen=load("res://scenes/battle.tscn").instantiate();add_child(screen)
		screen.process_mode=Node.PROCESS_MODE_DISABLED;battle=screen.battle
		verify_actor(battle.spawn_unit("MTNK","enemy",Vector2(1700,1600)),"indigo","fresh process spawned unit")
		verify_actor(battle.buildings.filter(func(b):return b.side=="ai2")[0],"magenta","fresh process restored building")
		await finish()
		FileAccess.open(output_dir.path_join("cold-result.json"),FileAccess.WRITE).store_string(JSON.stringify({"checks":checks,"failed":failed},"  "))
		get_tree().quit(0 if failed==0 else 1);return
	check(HouseColor.palette()==HouseColor.PALETTE, "authored and fallback twelve-colour palettes agree")
	check(HouseColor.palette().size()==12, "four distinct new colours available")
	for entry in HouseColor.palette():
		HouseColor.set_player_id(entry.id)
		var ids := HouseColor.roster_color_ids(roster(8))
		var unique := {}
		for id in ids: unique[id]=true
		check(unique.size()==8, "eight automatic houses stay distinct with player " + entry.id)
		check(ids==HouseColor.roster_color_ids(roster(8)), "automatic colours deterministic " + entry.id)
	HouseColor.set_player_id("allied")
	var mixed:=roster(6)
	mixed[3].color="magenta"; mixed[5].color="indigo"
	var assigned:=HouseColor.roster_color_ids(mixed)
	check(assigned[3]=="magenta" and assigned[5]=="indigo" and assigned.count("magenta")==1 and assigned.count("indigo")==1, "automatic seats reserve later manual colours")
	mixed[1].color="magenta"
	check(HouseColor.roster_color_ids(mixed).count("magenta")==2, "explicit duplicate choices are respected")
	var invalid:=mixed.duplicate(true); invalid[1].color="invalid"
	check(not Houses.valid(invalid,"yr_isleland",false), "unknown colour IDs rejected by match/save validation")
	invalid[1].color=7
	check(not Houses.valid(invalid,"yr_isleland",false), "non-string colour rejected")
	for row in invalid: row.erase("color")
	check(Houses.valid(invalid,"yr_isleland",false), "legacy rosters without colour remain valid")
	BattleRequest.reset()
	var lobby=load("res://scenes/lobby.tscn").instantiate()
	add_child(lobby)
	choose(lobby._layout_opt,Preferences.OPTIONS.map_layout.find("yr_isleland"))
	for seat in range(2,6): choose(lobby._team_grid.get_child(6+seat*6),0)
	choose_color(lobby._team_grid.get_node("HouseColorSeat1"),"indigo")
	choose_color(lobby._team_grid.get_node("HouseColorSeat2"),"magenta")
	choose_color(lobby._team_grid.get_node("HouseColorSeat3"),"teal")
	await get_tree().process_frame
	await get_tree().process_frame
	check(lobby._team_grid.get_global_rect().end.x<=get_viewport().get_visible_rect().size.x and lobby._map_preview.size.x>=300,"roster colour column fits beside map preview")
	check(lobby._team_rows[1].color=="indigo" and lobby._team_rows[2].color=="magenta", "real AI pickers update independent seats")
	var config:=ConfigFile.new(); config.load(Preferences.PATH)
	check(config.get_value(lobby._map_section(),"houses")[3].color=="teal", "AI colour immediately persists in map preferences")
	var row:Dictionary=lobby._team_rows[1]
	var pin:Button=lobby._map_preview.pins[row.spawn]
	check(pin.get_theme_stylebox("normal").border_color.is_equal_approx(Color(HouseColor.hex_of("indigo"))), "map pin matches manual AI colour")
	var saved_rows:Array=lobby._team_rows.duplicate(true)
	choose(lobby._layout_opt,Preferences.OPTIONS.map_layout.find("coast"))
	choose(lobby._layout_opt,Preferences.OPTIONS.map_layout.find("yr_isleland"))
	check(lobby._team_rows==saved_rows, "switching maps restores independent colours")
	lobby.free()
	lobby=load("res://scenes/lobby.tscn").instantiate(); add_child(lobby)
	check(lobby._team_rows==saved_rows, "reopening lobby restores AI colours")
	lobby.free()
	for mode in [MatchRules.RA2,MatchRules.EXTENDED]:
		BattleRequest.configure_skirmish(mode,{"houses":saved_rows,"map_layout":"yr_isleland","starting_funds":12000,"difficulty":1})
		var frozen_rows:Array=BattleRequest.skirmish_config.houses.duplicate(true)
		check(frozen_rows[4].color!="auto" and saved_rows[4].color=="auto",mode+" resolves automatic colour without mutating lobby preferences")
		screen=load("res://scenes/battle.tscn").instantiate(); add_child(screen)
		screen.process_mode=Node.PROCESS_MODE_DISABLED; battle=screen.battle
		var tank=battle.spawn_unit("MTNK","enemy",Vector2(1600,1600))
		verify_actor(tank,"indigo",mode+" spawned AI unit")
		verify_actor(battle.buildings.filter(func(b):return b.side=="ai2")[0],"magenta",mode+" AI building")
		AlliedAbilities.change_side(tank,"ai3")
		verify_actor(tank,"teal",mode+" captured unit")
		var slot:String=BattleSaves.SLOTS[0]
		var saved:=BattleSaves.save_slot(battle,slot)
		check(saved.ok,mode+" coloured battle saves")
		await finish()
		BattleRequest.reset()
		var loaded:=BattleSaves.prepare_load(slot)
		check(loaded.ok and BattleRequest.skirmish_config.houses==frozen_rows,mode+" disk reload restores fixed AI colours")
		screen=load("res://scenes/battle.tscn").instantiate(); add_child(screen)
		screen.process_mode=Node.PROCESS_MODE_DISABLED; battle=screen.battle
		verify_actor(battle.units.filter(func(u):return u.side=="ai3" and u.unit_id=="MTNK")[0],"teal",mode+" restored captured unit")
		verify_actor(battle.spawn_unit("MTNK","enemy",Vector2(1700,1600)),"indigo",mode+" produced after reload")
		await finish()
	var child_output:Array=[]
	var code:=OS.execute(OS.get_executable_path(),["--headless","--path",ProjectSettings.globalize_path("res://"),"res://tests/house_color_roster_regression.tscn","--","--house-colors-cold"],child_output,true)
	check(code==0,"fresh process verifies AI colours in preferences and restored battle",child_output if code!=0 else null)
	# A single computer uses its explicit colour too, without multi-house teams.
	var duel:=roster(2);duel[1].color="brown"
	BattleRequest.configure_skirmish(MatchRules.EXTENDED,{"houses":duel,"map_layout":"coast"})
	check(HouseColor.color_for_side("enemy","#ff5b4a").is_equal_approx(Color(HouseColor.hex_of("brown"))),"duel respects selected computer colour")
	FileAccess.open(output_dir.path_join("result.json"),FileAccess.WRITE).store_string(JSON.stringify({"checks":checks,"failed":failed},"  "))
	get_tree().quit(0 if failed==0 else 1)
