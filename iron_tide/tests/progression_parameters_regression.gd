extends "res://tests/peregrine_service_regression.gd"
const Params=preload("res://scripts/rules/progression_parameters.gd")
const Editor=preload("res://scripts/admin/progression_editor.gd")
const Furnace=preload("res://scripts/units/furnace_legend.gd")
const Commandos=preload("res://scripts/units/expansion_2_commandos.gd")
const Tanya=preload("res://scripts/units/tanya_talents.gd")
const Boris=preload("res://scripts/units/boris_command.gd")
const Leizhu=preload("res://scripts/units/leizhu.gd")

func _ready() -> void:
	output_dir=OS.get_environment("IRON_TIDE_REPORT_DIR")
	if output_dir.is_empty() or not OS.get_user_data_dir().contains("CodexIronTideValidation"):get_tree().quit(2);return
	await get_tree().process_frame
	MetaProgress.reset_save()
	registry()
	await furnace_editor()
	await commando_parameters()
	await aircraft_parameters()
	await tesla_parameters()
	await legacy_parameters()
	persistence()
	FileAccess.open(output_dir.path_join("result.json"),FileAccess.WRITE).store_string(JSON.stringify({"checks":checks,"failed":failed,"screenshots":0},"  "))
	print("PROGRESSION_PARAMETERS ",checks.size()," checks, ",failed," failed")
	get_tree().quit(0 if failed==0 else 1)

func tune(key:String,fields:Dictionary) -> void:
	var edits:Dictionary={}
	for field:String in fields:edits["values/"+field]=fields[field]
	check(GameData.progression_tuning.apply(key,edits).is_empty(),"apply "+key,edits)

func registry() -> void:
	var model=GameData.progression_tuning
	var count:=0
	for key:String in Params.groups():
		check(model.records.has(key),"registered "+key)
		for field:Dictionary in model.fields(key):
			count+=1
			var edited:float=float(field.value)+float(field.step)
			if edited>field.maximum:edited=float(field.value)-float(field.step)
			if edited<field.minimum:edited=field.minimum
			check(model.apply(key,{field.path:edited}).is_empty(),"field accepts legal edit "+key+"/"+field.path)
			check(is_equal_approx(Params.number(key,field.path.get_slice("/",1)),edited),"live authority reads edit "+field.path)
			check(not model.apply(key,{field.path:INF}).is_empty(),"nonfinite rejected "+field.path)
			if field.integer:check(not model.apply(key,{field.path:edited+.5}).is_empty(),"fractional count rejected "+field.path)
			model.apply(key,{})
	check(count>=396,"all migrated fields exercised",count)
	for id in ["ap_furnace_bastion","ap_tanya_breach","ap_boris_corridor","ap_peregrine_hunt","ap_leizhu_court","native_deploy_def","alternate_advance","wake_fork"]:
		check(not Params.related(id).is_empty(),"skill/talent exposes fixed parameters "+id)

func hero_for(id:String):
	MetaProgress.reset_save()
	MetaProgress.academy.hero_builds={id:50}
	MetaProgress.academy.hero_escort_ranks={id:5}
	MetaProgress.academy.hero_survival_ranks={id:5}
	boot(id if id in ["TANY","BORIS"] else "TANY")
	var hero=battle.spawn_unit(id,"ally",Vector2(1000,1000))
	A.promote(MetaProgress,battle,id,hero)
	return hero

func furnace_editor() -> void:
	var hero=hero_for("E2")
	var editor:=Editor.new();editor.embedded=true;add_child(editor)
	editor.select_key("skill/ap_furnace_bastion")
	var path:="mechanic/ap_furnace_bastion|values/shield_seconds"
	check(editor.inputs.has(path),"Furnace 10-second field is editable on its own skill page")
	if editor.inputs.has(path):
		editor.inputs[path].value=7.5
		await get_tree().process_frame
		check(Params.number("mechanic/ap_furnace_bastion","shield_seconds")==10,"typing does not prematurely change combat")
		editor.apply_current()
		var ab:=Ability.new();ab.setup(GameData.get_skill(Furnace.ACTIVE),0)
		check(Furnace.cast(hero,ab),"real Furnace stance casts after editor Apply")
		check(is_equal_approx(hero.special.furnace_prone.left,7.5),"actual spawned shield uses edited 7.5 seconds",[hero.special.furnace_prone,editor.status.text,editor.drafts])
		check(A.skill_description(GameData.get_skill(Furnace.ACTIVE),0).contains("持续 7.5 秒"),"Furnace live description follows shield duration")
		Furnace.tick(hero,7.4)
		check(hero.special.furnace_prone.hp>0,"edited shield survives before expiry")
		Furnace.tick(hero,.1)
		check(hero.special.furnace_prone.hp==0,"edited shield expires at new duration")
		editor.reset_current()
		check(Params.number("mechanic/ap_furnace_bastion","shield_seconds")==10,"reset restores linked mechanics too")
	editor.search.text="停机护罩";editor.refresh_list()
	check(editor.listed.has("hero/ORCA/survival"),"hero sub-perk searchable by its displayed name")
	editor.free();await finish()

func commando_parameters() -> void:
	var hero=hero_for("TANY")
	var enemy=battle.spawn_unit("E2","enemy",hero.position+Vector2(150,0))
	tune("hero/TANY/command",{"c4_guard_seconds":6,"c4_cooldown":9,"c4_defense":.4})
	Commandos.c4_started(hero)
	check(hero.special[Commandos.KEY].c4_guard==6 and hero.special[Commandos.KEY].c4_cd==9,"Tanya C4 uses edited duration/cooldown")
	check(is_equal_approx(Commandos.defend(hero,100,"bullet",{},enemy),60),"Tanya damage reduction uses edited ratio")
	tune("hero/TANY/survival",{"lethal_cap":.2})
	check(is_equal_approx(Tanya.before_damage(hero,hero.max_hp*2,"bullet",{},enemy,""),hero.max_hp*.2),"Tanya lethal cap consumes edited ratio")
	tune("mechanic/ap_tanya_breach",{"detonation_delay":120})
	var breach=preload("res://scripts/units/tanya_breach.gd")
	hero.special[Commandos.KEY].breach_charges=[]
	breach.throw_charge(hero,hero.position+Vector2(30,0),0)
	var charges:Array=hero.special[Commandos.KEY].breach_charges
	check(charges.size()==1,"edited-delay charge spawns")
	if not charges.is_empty():
		var bomb=charges[0]
		check(bomb.special.expansion_temporary.left>120,"temporary lifetime supports delay beyond old 100-second limit")
		tune("mechanic/ap_tanya_breach",{"detonation_delay":1})
		breach.charge_tick(bomb,119)
		check(not bomb.special[breach.PAYLOAD].get("spent",false),"in-flight charge keeps its chosen fuse")
		breach.charge_tick(bomb,1)
		check(bomb.special[breach.PAYLOAD].get("spent",false),"charge detonates at configured 120 seconds")
	tune("mechanic/ap_tanya_breach",{})
	tune("hero/TANY/command",{});tune("hero/TANY/survival",{})
	await finish()
	hero=hero_for("BORIS");enemy=battle.spawn_unit("HTNK","enemy",hero.position+Vector2(150,0))
	tune("hero/BORIS/survival",{"stationary_seconds":.5,"ranged_defense":.4})
	Commandos.tick(hero,.5)
	check(is_equal_approx(Commandos.defend(hero,100,"shell",{},enemy),60),"Boris cover consumes edited prepare/damage parameters")
	var infantry=battle.spawn_unit("E2","ally",hero.position+Vector2(50,0))
	Boris.state(infantry).relay={"left":4}
	tune("hero/BORIS/command",{"relay_reload":.2})
	check(is_equal_approx(Boris.modify_reload(infantry,10),2),"Boris relay consumes edited cooldown multiplier")
	tune("mechanic/ap_boris_corridor",{"count":5,"spacing":1})
	var points=preload("res://scripts/units/boris_fire_control.gd").points(hero,hero.position+Vector2(100,0))
	check(points.size()==5 and is_equal_approx(points[4].distance_to(points[0]),220),"Boris strike count and spacing change together")
	for key in ["hero/BORIS/command","hero/BORIS/survival","mechanic/ap_boris_corridor"]:tune(key,{})
	await finish()

func aircraft_parameters() -> void:
	var hero=service_hero(4);place_service(hero)
	tune("hero/ORCA/survival",{"maintenance_duration":17,"maintenance_shield":.3,"descent_seconds":2})
	check(S.toggle(hero),"Peregrine maintenance starts")
	S.tick(hero,1)
	check(hero.special[P.KEY].maintenance.descent==1 and not hero.special[P.KEY].has("maintenance_shield"),"edited descent preserves one-second midpoint")
	S.tick(hero,1)
	check(is_equal_approx(hero.special[P.KEY].maintenance_shield.left,17) and is_equal_approx(hero.special[P.KEY].maintenance_shield.hp,hero.max_hp*.3),"maintenance shield uses edited time and HP")
	S.leave(hero)
	hero.special.hero_command_rank=0;hero.passive={};hero.logistics.ammo=0;hero.special[P.KEY].progress=0
	tune("hero/ORCA/command",{"reload_base":2})
	P.tick(hero,2)
	check(hero.logistics.ammo==1,"Peregrine actual air refill uses edited interval")
	tune("hero/ORCA/command",{});tune("hero/ORCA/survival",{})
	await finish()

func tesla_parameters() -> void:
	MetaProgress.reset_save();boot("BORIS")
	var hero=battle.spawn_unit("TTNK","ally",Vector2(1000,1000));Leizhu.promote(MetaProgress,battle,hero)
	var enemy=battle.spawn_unit("HTNK","enemy",Vector2(1120,1000))
	tune("hero/TTNK/survival",{"shield_wait":1,"shield_hp":.25,"shield_duration":11,"shield_cooldown":7})
	Leizhu.tick(hero,1)
	check(is_equal_approx(hero.special.leizhu.shield.hp,hero.max_hp*.25) and hero.special.leizhu.shield.left==11 and hero.special.leizhu.shield_cd==7,"Leizhu actual shield consumes four edited fields")
	tune("hero/TTNK/command",{"mark_damage":1.7,"mark_duration":9})
	var packet={"leizhu_primary":true,"leizhu_side":"ally"}
	Leizhu.impact(enemy,hero,100,packet)
	check(hero.special.leizhu.marks[enemy].left==9 and is_equal_approx(Leizhu.impact(enemy,hero,100,packet),170),"Leizhu mark duration and damage use current authority")
	tune("hero/TTNK/command",{});tune("hero/TTNK/survival",{})
	await finish()

func legacy_parameters() -> void:
	var training=preload("res://scripts/rules/skill_training.gd")
	var model=GameData.progression_tuning
	check(model.apply("talent/E1/native_deploy_def",{"values/power/0":1.8}).is_empty(),"native per-rank power accepts edit")
	check(is_equal_approx(training.power_at("E1",0),1.8),"native runtime consumes per-rank configured power")
	model.apply("talent/E1/native_deploy_def",{})
	tune("hero/infantry/escort",{"veteran_0":2,"elite_0":1})
	check(A.ESCORT_RANKS[0]==[2,1,1],"legacy escort actual spawn ranks use configured counts")
	tune("hero/training",{"attack_step":2.5,"attack_cap":7.5})
	check(is_equal_approx(A.training_percent("firepower",2),1.25) and A.training_cap("firepower")==3,"fractional training increments and cap share authority")
	var hero=hero_for("MTNK")
	tune("hero/tank/shield",{"delay":.5,"initial":.2,"growth":.1,"growth_interval":2})
	hero.special.erase(Unit.TankHero.Shield.KEY)
	Unit.TankHero.Shield.tick(hero,.5)
	check(is_equal_approx(Unit.TankHero.Shield.amount(hero),hero.max_hp*.2),"old hero shield uses edited delay and initial health")
	Unit.TankHero.Shield.tick(hero,1)
	check(is_equal_approx(Unit.TankHero.Shield.amount(hero),hero.max_hp*.2),"old hero shield respects edited growth interval")
	Unit.TankHero.Shield.tick(hero,1)
	check(is_equal_approx(Unit.TankHero.Shield.amount(hero),hero.max_hp*.3),"old hero shield grows by edited amount")
	for key in ["hero/infantry/escort","hero/training","hero/tank/shield"]:tune(key,{})
	await finish()

func persistence() -> void:
	var model=GameData.progression_tuning
	tune("hero/ORCA/survival",{"maintenance_duration":19})
	check(model.save().is_empty(),"hero parameter save succeeds")
	model.loaded=false;model.patches.clear();GameData.reload()
	check(Params.number("hero/ORCA/survival","maintenance_duration")==19,"hero parameter survives disk reload")
	check(model.records["hero/ORCA/survival"].base.values.maintenance_duration==10,"reload retains immutable shipped baseline")
	tune("hero/ORCA/survival",{})
	check(Params.number("hero/ORCA/survival","maintenance_duration")==10,"reset after reload returns shipped value")
	model.save()
