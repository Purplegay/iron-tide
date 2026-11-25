extends "res://tests/commando_hero_regression.gd"
const Details=preload("res://scripts/ui/battle_effect_details.gd")
const Peregrine=preload("res://scripts/units/peregrine.gd")
const Leizhu=preload("res://scripts/units/leizhu.gd")
const HERO_IDS=["TANY","BORIS","ORCA","TTNK"]
const NAMES={"TANY":["破袭专家","极限脱身"],"BORIS":["前线指挥","战地电台"],"ORCA":["王牌航线","滞空保障"],"TTNK":["移动变电站","过载保险"]}

func _ready() -> void:
	output_dir=OS.get_environment("IRON_TIDE_REPORT_DIR")
	if output_dir.is_empty() or not OS.get_user_data_dir().contains("CodexIronTideValidation"):get_tree().quit(2);return
	await get_tree().process_frame
	for level in 6:await ranks_case(level,5-level)
	FileAccess.open(output_dir.path_join("result.json"),FileAccess.WRITE).store_string(JSON.stringify({"checks":checks,"failed":failed},"  "))
	print("HERO_EFFECT_DETAILS_RESULT ",checks.size()," checks, ",failed," failed")
	get_tree().quit(0 if failed==0 else 1)

func ranks_case(command:int,defense:int) -> void:
	MetaProgress.reset_save()
	MetaProgress.academy.hero_builds={"TANY":5,"BORIS":5}
	MetaProgress.academy.hero_escort_ranks={}
	MetaProgress.academy.hero_survival_ranks={}
	for id in HERO_IDS:
		MetaProgress.academy.hero_escort_ranks[id]=command
		MetaProgress.academy.hero_survival_ranks[id]=defense
	boot("TANY")
	for id in HERO_IDS:
		var hero=battle.spawn_unit(id,"ally",Vector2(1000+HERO_IDS.find(id)*150,1000))
		if id=="ORCA":Peregrine.promote(MetaProgress,battle,hero)
		elif id=="TTNK":Leizhu.promote(MetaProgress,battle,hero)
		else:A.promote(MetaProgress,battle,id,hero)
		var actual_defense:=mini(defense,Leizhu.OPEN_RANK) if id=="TTNK" else defense
		check(hero.special.get("academy_hero")==id and hero.special.hero_command_rank==command and hero.special.hero_survival_rank==actual_defense,"real promotion freezes ranks "+id,[command,actual_defense])
		var text:=Details.describe(hero)
		check(text.contains("指挥 Lv.%d／生存 Lv.%d"%[command,actual_defense]),"live detail displays both frozen ranks "+id)
		check(not text.contains("随行护卫：") and not text.contains("英雄天赋 · Lv.0"),"new hero avoids legacy/baseline-only branch "+id)
		for track in 2:
			check(text.contains(NAMES[id][track]+"："),"correct track title "+id+str(track))
			var values:=descriptions(id,track)
			var rank:int=command if track==0 else actual_defense
			for i in values.size():
				check(text.contains("Lv.%d　%s"%[i,values[i]])==(i<=rank),"only current and earlier nodes shown "+id+str(track)+str(i))
		MetaProgress.academy.hero_escort_ranks[id]=5-command
		MetaProgress.academy.hero_survival_ranks[id]=5-defense
		check(Details.describe(hero)==text,"editing profile cannot rewrite current match hero detail "+id)
		var ordinary=battle.spawn_unit(id,"ally",Vector2(1000,1300))
		check(not Details.describe(ordinary).contains("英雄天赋"),"ordinary chassis has no hero chain "+id)
		var panel:=Details.new();panel.actor=hero;panel.hud=screen.hud
		screen.hud.add_child(panel);panel.refresh()
		check(panel.body.text==text,"actual detail panel consumes the corrected text "+id)
		panel.free()
	var tower=battle._place_building("TESLA","ally",Vector2(1700,1700),true)
	tower.special.card_armor=.14;tower.special.card_armor_rank=2
	tower.special[preload("res://scripts/units/expansion_rules.gd").KEY]={"arc_count":2}
	var building_details:=Details.describe(tower)
	check(building_details.contains("复合装甲板") and building_details.contains("零点放电"),"building detail retains card and current effect without unit-only passive field")
	check(not building_details.contains("英雄天赋") and not building_details.contains("废铁装甲"),"building never receives infantry/vehicle-only hero or scrap rows")
	await finish()

func descriptions(id:String,track:int) -> Array:
	match id:
		"TANY":return preload("res://scripts/units/tanya_talents.gd").COMMAND if track==0 else preload("res://scripts/units/tanya_talents.gd").DEFENSE
		"BORIS":return preload("res://scripts/units/boris_command.gd").COMMAND if track==0 else preload("res://scripts/units/boris_radio.gd").DEFENSE
		"ORCA":return preload("res://scripts/units/peregrine_command.gd").COMMAND if track==0 else preload("res://scripts/units/peregrine_defense.gd").DEFENSE
	return preload("res://scripts/units/leizhu_command.gd").COMMAND if track==0 else preload("res://scripts/units/leizhu_defense.gd").DEFENSE
