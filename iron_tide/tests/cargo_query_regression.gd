extends "res://tests/base_recovery_regression.gd"
const Actor=preload("res://tests/cargo_query_actor.gd")
const Reference=preload("res://tests/cargo_query_reference.gd")
var resolutions := {"before":0,"after":0}
var acquisitions := 0
func make(id:String,old:bool) -> Unit:
	var unit:Unit=Reference.new() if old else Actor.new()
	unit.setup(GameData.get_unit(id).duplicate(true),"ally",Vector2(1100,1100))
	unit._combat_world=battle
	battle.add_child(unit);battle.units.append(unit)
	unit.set_physics_process(false);unit.set_process(false)
	unit.fire_stance="free"
	return unit
func query_count(car) -> int:
	var count:int=car.weapon_queries
	for crew in car.logistics.passengers:count+=crew.weapon_queries
	return count
func _ready() -> void:
	output_dir=OS.get_environment("IRON_TIDE_REPORT_DIR")
	if output_dir.is_empty() or not OS.get_user_data_dir().contains("CodexIronTideValidation"):
		get_tree().quit(2);return
	for mode in [MatchRules.RA2,MatchRules.EXTENDED]:
		start(mode);battle.fog=null
		var targets=[]
		for i in 16:
			var foe=battle.spawn_unit("JUMPJET" if i%3==0 else "MTNK","enemy",Vector2(1220+i*12,1100+i%4*18))
			foe.set_physics_process(false);foe.hp=foe.max_hp*(0.2+float(i)/20.0)
			if foe.is_air:foe.logistics.air_lift=120.0
			targets.append(foe)
		var cars=[make("BFRT",true),make("BFRT",false)]
		for car in cars:
			for id in ["GGI","E1","GGI","CLEG","BORIS"]:
				var crew=make(id,car==cars[0]);car.logistics.passengers.append(crew);crew.set_stowed(car)
		for spatial in [false,true]:
			if spatial:
				for i in 100:
					var filler=make("MTNK",false)
					filler.position=Vector2(2100+i%10,2100+i/10)
					battle.neighborhood.register(filler,filler.radius,false)
			for rank in [0,2]:
				for state in ["normal","hero","controlled","dead","aura","bonus_changed"]:
					for car in cars:
						car.data.open_topped.range_bonus=165.0 if state=="bonus_changed" else 110.0
						for crew in car.logistics.passengers:
							crew.veteran_level=rank;crew._refresh_veteran_bonuses(false)
							crew.side="enemy" if state=="controlled" else "ally"
							crew.hp=0.0 if state=="dead" else crew.max_hp
							crew.special.erase("academy_hero")
							if state=="hero":crew.special.academy_hero=crew.unit_id
							crew.special.hero_range_aura=55.0 if state=="aura" else 0.0
							crew._refresh_weapon_derived()
					for stance in ["free","defend","return"]:
						for car in cars:
							car.fire_stance=stance;car.attack_ordered=false;car.attack_move=false;car.attack_target=null
							car.special.retaliation_target=targets[3];car._return_timer=2.0;car._scan_grant_until=999999999
							var count=query_count(car)
							car._refresh_target()
							resolutions["before" if car==cars[0] else "after"]+=query_count(car)-count
							if car.attack_target!=null:acquisitions+=1
						check(cars[0].attack_target==cars[1].attack_target,prefix+"carrier target matches original "+str([spatial,rank,state,stance]))
						for seat in 3:
							for car in cars:
								var crew=car.logistics.passengers[seat]
								crew.fire_stance=stance;crew.hold_position=true;crew.attack_ordered=false;crew.attack_move=false;crew.attack_target=null
								crew.special.retaliation_target=targets[3];crew._return_timer=2.0;crew._scan_grant_until=999999999
								var count:int=crew.weapon_queries
								crew._refresh_target()
								resolutions["before" if car==cars[0] else "after"]+=crew.weapon_queries-count
							check(cars[0].logistics.passengers[seat].attack_target==cars[1].logistics.passengers[seat].attack_target,prefix+"cargo target matches original "+str([spatial,rank,state,stance,seat]))
					var car=cars[1]
					var cache={"enabled":true}
					for target in targets:
						var expected=[false];var actual=[false]
						var old_range=OpenTopped.command_range(car,target,{},expected)
						var new_range=OpenTopped.command_range(car,target,{},actual,null,cache)
						check(old_range==new_range and expected==actual,prefix+"range/domain remain per-target "+state)
		check(acquisitions>0 and resolutions.after<resolutions.before,prefix+"real candidate acquisition with fewer weapon resolutions",resolutions.duplicate())
		await finish()
	FileAccess.open(output_dir.path_join("result.json"),FileAccess.WRITE).store_string(JSON.stringify({"checks":checks,"failed":failed,"resolutions":resolutions,"acquisitions":acquisitions},"  "))
	get_tree().quit(0 if failed==0 else 1)
