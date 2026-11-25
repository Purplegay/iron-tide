extends "res://tests/base_recovery_regression.gd"
const View=preload("res://scripts/ui/shield_readout.gd")
const SPECS=[
	["MTNK","","hero_stationary_shield"],["E2","","furnace_prone"],["MGTK","progression_v1","mirror_shield"],
	["MTNK","progression_v2","module_shield"],["SREF","progression_v2","prism_shield"],
	["V3","progression_v2","bulkhead_shield"],["SUB","progression_v2","pressure_shield"],
	["DMISL","progression_v2","escort_shield"],["DEST","progression_v2","water_relay_shield"],
	["MTNK","","expedition_shield"],["MTNK","","boris_radio_shield"],
	["TANY","commando_hero_v2","shield"],["TANY","commando_hero_v2","swim_shield"],
	["ORCA","peregrine","rearm_shield"],["ORCA","peregrine","maintenance_shield"],
	["TTNK","leizhu","shield"],["TTNK","leizhu","stolen"],
	["TTNK","leizhu","recycled"],["TTNK","leizhu","emergency_shield"]]

func _ready() -> void:
	output_dir=OS.get_environment("IRON_TIDE_REPORT_DIR")
	if output_dir.is_empty() or not OS.get_user_data_dir().contains("CodexIronTideValidation"):get_tree().quit(2);return
	await get_tree().process_frame
	for spec in SPECS:await shield_case(spec)
	await stacking()
	await other_shields()
	await capacitor_marker()
	FileAccess.open(output_dir.path_join("result.json"),FileAccess.WRITE).store_string(JSON.stringify({"checks":checks,"failed":failed},"  "))
	get_tree().quit(0 if failed==0 else 1)

func seed_shield(unit,spec:Array) -> void:
	var key:String=spec[2]
	var state:Dictionary=unit.special if spec[1]=="" else unit.special.get_or_add(spec[1],{"side":unit.side})
	state[key]=20.0 if key in ["expedition_shield","rearm_shield","emergency_shield"] else {"hp":20.0,"maximum":20.0,"left":10.0,"side":unit.side}
	if key=="hero_stationary_shield":unit.special.academy_hero="MTNK"
	if key=="furnace_prone":state[key].rank=0
	if key=="expedition_shield":BattleRequest.combat_context.expedition={"country":"美国","buffs":{}}
	if spec[1] in ["commando_hero_v2","peregrine","leizhu"]:
		unit.special.academy_hero=unit.unit_id
		unit.special.hero_command_rank=2;unit.special.hero_survival_rank=2
		state.side=unit.side
	if spec[1]=="peregrine":
		unit.passive={"id":"ps_peregrine_rearm"};state.cycle=0
	if spec[1]=="leizhu":state.quiet=0.0;state.marks={}

func shield_case(spec:Array) -> void:
	start(MatchRules.EXTENDED)
	var unit=battle.spawn_unit(spec[0],"ally",Vector2(1000,1000));unit.max_hp=10000;unit.hp=10000
	unit.special.audit_owner=true;seed_shield(unit,spec)
	var saved:Dictionary=unit.special.duplicate(true);var label:String=spec[1]+"/"+spec[2]
	check(is_equal_approx(View.amount(unit),20),label+" visible amount matches real shield")
	View.summary(unit);check(unit.special==saved,label+" presentation does not mutate combat state")
	battle.select_unit(unit,false);battle._emit_selection();screen.hud._refresh_selection();screen.hud._refresh_selection_live(false)
	if unit.unit_id=="DMISL":check(battle.selected_units.is_empty(),"missile remains unselectable; world readout still exposes escort shield")
	else:check(screen.hud.sel_shield_label.visible and screen.hud.sel_shield_label.text.begins_with("护盾 20"),label+" real HUD displays shield")
	unit.receive_hit(5,"bullet")
	var remains:=View.amount(unit)
	check(unit.hp==10000 and remains>0 and remains<20,label+" real receiver debits shield before health")
	screen.hud._refresh_selection_live(false)
	if unit.unit_id!="DMISL":check(screen.hud.sel_shield_label.text.begins_with("护盾 "+HpBar.shield_number(remains)),label+" HUD follows actual debit")
	var codec=BattleSaves.Snapshot.new();var path:=output_dir.path_join(str(SPECS.find(spec))+".bin")
	var file=FileAccess.open(path,FileAccess.WRITE);file.store_var(codec.capture(battle),false);file.close()
	file=FileAccess.open(path,FileAccess.READ);var snap=file.get_var(false);file.close();codec.restore(battle,snap)
	unit=battle.units.filter(func(u):return u.special.get("audit_owner",false))[0]
	check(codec.error.is_empty() and is_equal_approx(View.amount(unit),remains),label+" binary save restores remaining shield")
	unit.receive_hit(100,"bullet")
	check(View.amount(unit)==0 and unit.hp<10000 and not unit._dead,label+" break passes overflow to health")
	await finish()

func other_shields() -> void:
	start(MatchRules.EXTENDED)
	var unit=battle.spawn_unit("HTNK","ally",Vector2(1000,1000))
	unit.special.progression_v1={"scrap":[10.0,15.0]}
	var hp:float=unit.hp
	check(View.amount(unit)==25,"scrap armor contributes remaining absorption across layers")
	unit.receive_hit(5,"bullet")
	check(unit.hp==hp and View.amount(unit)<25 and View.amount(unit)>0,"scrap armor readout follows actual absorption")
	var building=battle.buildings.filter(func(b):return b.side=="enemy")[0]
	building.special.brutal_shield=20.0;hp=building.hp
	battle.select_building(building);battle._emit_selection()
	check(screen.hud.sel_shield_label.visible and View.amount(building)==20,"building HUD includes actual shield")
	building.receive_hit(5,"bullet");screen.hud._refresh_selection_live(false)
	check(building.hp==hp and View.amount(building)<20,"building shield absorbs through real damage entry")
	building.special.brutal_shield=0.0;screen.hud._refresh_selection_live(false)
	check(not screen.hud.sel_shield_label.visible,"exhausted building shield disappears from HUD")
	await finish()

func capacitor_marker() -> void:
	start(MatchRules.EXTENDED)
	var unit=battle.spawn_unit("TTNK","ally",Vector2(1000,1000))
	BattleRequest.combat_context.unit_talents.TTNK={"ground_capacitor":3}
	var rules=preload("res://scripts/units/expansion_rules.gd")
	var talents=preload("res://scripts/units/expansion_talents.gd")
	rules.state(unit).shot_idle=3.0;talents.tick(unit,2.1)
	unit.position+=Vector2(60,0);talents.tick(unit,.1)
	var state:Dictionary=rules.state(unit)
	check(state.has("capacitor") and state.capacitor.point==Vector2(1000,1000),"Tesla ground capacitor is anchored to the departed position")
	var token=unit.get_meta(preload("res://scripts/units/ground_capacitor_token.gd").META).get_ref()
	check(token!=null and token.global_position==state.capacitor.point and token.get_parent()==battle.effects_root,"capacitor has an independent world token at the drop point")
	check(View.amount(unit)==0,"ground capacitor marker is not a shield")
	unit.position+=Vector2(100,0);talents.tick(unit,.1)
	check(state.capacitor.point==Vector2(1000,1000),"moving again retains the capacitor world position")
	check(token.global_position==Vector2(1000,1000) and get_tree().get_nodes_in_group("ground_capacitor_token").size()==1,"movement reuses one anchored token")
	talents.tick(unit,8)
	check(not state.has("capacitor"),"ground capacitor marker expires without leaving permanent state")
	check(token.is_queued_for_deletion(),"expired capacitor removes its token")
	await finish()
	start(MatchRules.EXTENDED)
	unit=battle.spawn_unit("TTNK","ally",Vector2(1000,1000))
	unit.special.progression_v1={"capacitor":{"point":Vector2(940,1000),"left":3.5,"damage":0.2}}
	preload("res://scripts/units/ground_capacitor_token.gd").sync(unit)
	var codec=BattleSaves.Snapshot.new();codec.restore(battle,codec.capture(battle))
	unit=battle.units.filter(func(u):return u.unit_id=="TTNK")[0]
	token=unit.get_meta(preload("res://scripts/units/ground_capacitor_token.gd").META).get_ref()
	check(codec.error.is_empty() and battle.paused and token.global_position==Vector2(940,1000) and token.seconds==4,"paused snapshot immediately rebuilds token without advancing gameplay")
	check(get_tree().get_nodes_in_group("ground_capacitor_token").size()==1,"snapshot removes obsolete token before restoring one")
	var victim=battle.spawn_unit("MTNK","enemy",Vector2(940,1000))
	var hp:float=victim.hp
	talents.tick(unit,.1)
	check(victim.hp<hp and token.is_queued_for_deletion(),"trigger consumes capacitor and removes token with real damage")
	await finish()

func stacking() -> void:
	start(MatchRules.EXTENDED)
	var unit=battle.spawn_unit("MTNK","ally",Vector2(1000,1000));unit.max_hp=10000;unit.hp=10000
	seed_shield(unit,["MTNK","","boris_radio_shield"]);seed_shield(unit,["MTNK","progression_v2","module_shield"])
	check(View.amount(unit)==40 and View.entries(unit).size()==2,"stacked shield totals and source breakdown")
	unit.receive_hit(25,"bullet")
	check(unit.hp==10000 and View.amount(unit)<40 and View.amount(unit)>0,"multiple shields absorb without double charging HP")
	var ordinary=battle.spawn_unit("TTNK","ally",Vector2(1300,1000))
	check(View.amount(ordinary)==0 and not View.summary(ordinary).visible,"ordinary Tesla tank has no invented hero shield")
	await finish()

