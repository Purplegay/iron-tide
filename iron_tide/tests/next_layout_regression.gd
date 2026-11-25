extends "res://tests/base_recovery_regression.gd"
const Before=preload("res://tests/next_layout_reference.gd")
var micro:Array=[]
func ability(id:String):
	var a=Ability.new();a.setup(GameData.get_skill(id) if not GameData.get_skill(id).is_empty() else {"id":id,"name":id});return a
func _ready() -> void:
	output_dir=OS.get_environment("IRON_TIDE_REPORT_DIR")
	if output_dir.is_empty() or not OS.get_user_data_dir().contains("CodexIronTideValidation"):get_tree().quit(2);return
	start(MatchRules.EXTENDED)
	var actors:Array=[]
	for id in ["E1","GGI","MTNK","HTNK","APOC","SREF","MGTK","TTNK","CLEG","BORIS","DEST","CARRIER","R3REAPER","R3APOC"]:
		var unit=battle.spawn_unit(id,"ally",Vector2(1100,1100));unit.process_mode=Node.PROCESS_MODE_DISABLED
		for hero in [false,true]:
			if hero:unit.special.academy_hero=id
			else:unit.special.erase("academy_hero")
			for skill in GameData.skill_index:
				check(UnitSkillLayout.equippable(id,skill,hero)==Before.equippable(id,skill,hero),"live skill scope "+str([id,skill,hero]))
				unit.skills.assign([ability(Before.primary_id(id)),ability(skill),ability("allied_special")])
				for slot in [0,1,2]:check(UnitSkillLayout.index(unit,slot)==Before.index(unit,slot),"slot identity "+str([id,skill,hero,slot]))
		unit.special.erase("academy_hero")
		var equipped:=""
		for skill in GameData.skill_index:
			if Before.equippable(id,skill):equipped=skill;break
		unit.skills.assign([ability(Before.primary_id(id)),ability(equipped),ability("allied_special")]);actors.append(unit)
	for sample in 18:
		var sum:=0;var begun:=Time.get_ticks_usec()
		for i in 1000:
			for unit in actors:sum+=Before.index(unit,1) if sample%2==0 else UnitSkillLayout.index(unit,1)
		micro.append({"variant":"before" if sample%2==0 else "after","us":Time.get_ticks_usec()-begun,"calls":14000,"sum":sum})
	await finish()
	FileAccess.open(output_dir.path_join("result.json"),FileAccess.WRITE).store_string(JSON.stringify({"checks":checks,"failed":failed,"micro":micro}))
	get_tree().quit(0 if failed==0 else 1)
