extends "res://tests/tank_hero_regression.gd"

func _ready() -> void:
	output_dir=OS.get_environment("IRON_TIDE_REPORT_DIR")
	if output_dir.is_empty() or not OS.get_user_data_dir().contains("CodexIronTideValidation"):
		get_tree().quit(2);return
	MetaProgress.reset_save()
	start(MatchRules.EXTENDED)
	var fog=preload("res://scripts/world/fog_of_war.gd").new()
	battle.add_child(fog);fog.setup(battle);battle.fog=fog
	var hq=battle.buildings.filter(func(b):return b.side=="enemy" and b.is_hq)[0]
	for id in Hero.IDS:
		var unit=hero(id,1,0,Vector2(900,1200))
		var health:float=unit.max_hp
		var attack:float=unit.bonuses.attack_bonus
		var speed:float=unit.move_speed
		var sight:float=unit.sight
		unit.hp=0;unit._die()
		check(unit.special.has("hero_wreck") and is_equal_approx(unit.max_hp,health*1.5) and is_equal_approx(unit.hp,health*0.75),id+" wreck has 150 percent capacity and starts half full")
		check(Hero.revival_used(unit) and battle.allied_state.hero_revives_used.has("ally:"+id),id+" consumes match allowance at death")
		Hero.tick(unit,7.5)
		check(is_equal_approx(unit.hp/unit.max_hp,0.75),id+" half timer heals exactly quarter wreck capacity")
		unit.hp-=unit.max_hp*0.2
		Hero.tick(unit,7.49)
		check(unit.special.has("hero_wreck"),id+" must wait entire fifteen seconds")
		var codec=BattleSaves.Snapshot.new()
		var snapshot:Dictionary=codec.capture(battle)
		check(codec.error.is_empty(),id+" healing wreck serializes")
		codec.restore(battle,snapshot)
		unit=battle.units.filter(func(u):return u.special.get("academy_hero")==id)[0]
		fog=battle.fog
		hq=battle.buildings.filter(func(b):return b.side=="enemy" and b.is_hq)[0]
		fog.sight_until.ally.clear()
		Hero.tick(unit,1.0)
		check(not unit.special.has("hero_wreck") and is_equal_approx(unit.max_hp,health*0.5) and is_equal_approx(unit.hp,health*0.4),id+" damage preserved and long final tick grants only remaining healing")
		check(is_equal_approx(unit._base_max_hp,health*0.5) and is_equal_approx(unit.bonuses.attack_bonus,attack*0.7),id+" permanent health and attack penalties")
		check(is_equal_approx(unit.move_speed,speed*1.15) and is_equal_approx(unit.sight,sight+55),id+" speed and sight rewards")
		check(unit.display_name.contains("本局已用") and not unit.special.has("hero_revive_cd"),id+" unit label marks consumed revival with no cooldown")
		var cell:int=fog._index(hq.position)
		check(is_equal_approx(float(fog.sight_until.ally.get(cell,0)),fog.sight_clock+10),id+" actual revival reveals enemy base for ten seconds")
		# Compare the real reveal footprint against the fog engine's 9-cell stamp.
		var actual:Dictionary=fog.sight_until.ally.duplicate()
		fog.sight_until.ally.clear()
		for building in battle.buildings:
			if battle.actor_alive(building) and building.side=="enemy" and building.is_hq:fog._reveal("ally",building.position,9*55,10)
		check(actual==fog.sight_until.ally,id+" revival uses nine-cell base reveal footprint")
		snapshot=codec.capture(battle);codec.restore(battle,snapshot)
		unit=battle.units.filter(func(u):return u.special.get("academy_hero")==id)[0]
		unit._recompute_bonuses();unit._grant_veteran(2,false)
		Hero.tick(unit,121)
		check(is_equal_approx(unit.max_hp,health*0.5) and is_equal_approx(unit.bonuses.attack_bonus,attack*0.7) and is_equal_approx(unit.move_speed,speed*1.15) and is_equal_approx(unit.sight,sight+55),id+" reload promotion and time cannot duplicate or undo modifiers")
		unit.hp=0;unit._die()
		check(unit._dead and not unit.special.has("hero_wreck"),id+" second death remains final even after 120 seconds and reload")
		var duplicate=hero(id,1,0,Vector2(1600,1200))
		duplicate.hp=0;duplicate._die()
		check(duplicate._dead,id+" same match cannot grant another revival by recreating hero")
	# Legacy saves adopt the new rule once, including zero-valued old cooldowns.
	var legacy=hero("MTNK",1,0,Vector2(900,900))
	var legacy_health:float=legacy.max_hp
	legacy.special.hero_wreck={"health":legacy_health,"left":6.0,"name":legacy.display_name,"sight":legacy.sight}
	legacy.max_hp=legacy_health*5;legacy.hp=legacy.max_hp*0.4
	Hero.tick(legacy,0)
	check(is_equal_approx(legacy.max_hp,legacy_health*1.5) and is_equal_approx(legacy.hp/legacy.max_hp,0.4) and legacy.special.hero_wreck.left==6,"legacy wreck preserves remaining time and health fraction")
	Hero.tick(legacy,6)
	check(is_equal_approx(legacy.max_hp,legacy_health*0.5) and is_equal_approx(legacy.hp/legacy.max_hp,0.6),"legacy wreck receives only remaining recovery budget")
	var old=hero("HTNK",1,0,Vector2(1200,900))
	var old_hp:float=old.max_hp
	var old_attack:float=old._base_atk
	old.special.hero_revive_cd=0.0
	Hero.tick(old,0);Hero.tick(old,0)
	check(old.special.hero_revive_used and old.special.hero_reborn and is_equal_approx(old.max_hp,old_hp*0.5) and is_equal_approx(old._base_atk,old_attack*0.7),"legacy completed cooldown becomes spent revival and applies penalties once")
	check(Hero.COMMAND[1].contains("150%") and Hero.COMMAND[1].contains("每局仅一次") and Hero.COMMAND[1].contains("10 秒"),"talent description explains complete new rule")
	var preview:Dictionary=Hero.revival_preview(0)
	check(preview.title.contains("150%") and preview.title.contains("50%") and not preview.title.contains("5 倍"),"demo header reads the actual wreck health constants")
	check(is_equal_approx(preview.fraction,0.5) and is_equal_approx(preview.left,15),"demo starts at half health and fifteen seconds")
	preview=Hero.revival_preview(0.5)
	check(is_equal_approx(preview.fraction,0.75) and is_equal_approx(preview.left,7.5),"demo recovery follows battle time")
	preview=Hero.revival_preview(1)
	check(is_equal_approx(preview.fraction,1) and is_zero_approx(preview.left),"demo reaches full recovery at revival")
	await finish()
	FileAccess.open(output_dir.path_join("result.json"),FileAccess.WRITE).store_string(JSON.stringify({"checks":checks,"failed":failed}))
	get_tree().quit(0 if failed==0 else 1)
