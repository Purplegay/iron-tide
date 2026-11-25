extends "res://tests/base_recovery_regression.gd"
const Before=preload("res://tests/cargo_range_reference.gd")
const Actor=preload("res://tests/cargo_range_actor.gd")
var metrics:Array=[]
var before_calls:=0
var after_calls:=0
func make(id:String,side:="ally"):
	var actor=Actor.new()
	actor.setup(GameData.get_unit(id).duplicate(true),side,Vector2(900,900))
	actor._combat_world=battle;battle.add_child(actor);battle.units.append(actor)
	actor.set_process(false);actor.set_physics_process(false)
	return actor
func calls(car) -> int:
	var n:int=car.domain_calls
	for crew in car.logistics.passengers:n+=crew.domain_calls
	return n
func compare(car,target,cache:Dictionary) -> void:
	var old_domain=[false];var new_domain=[false]
	var n:=calls(car)
	var expected:float=Before.command_range(car,target,{},old_domain,null,cache)
	before_calls+=calls(car)-n
	n=calls(car)
	var actual:float=OpenTopped.command_range(car,target,{},new_domain,null,cache)
	after_calls+=calls(car)-n
	check(expected==actual and old_domain==new_domain,prefix+"range and eligible domain equal",[expected,actual,old_domain,new_domain])
func _ready() -> void:
	output_dir=OS.get_environment("IRON_TIDE_REPORT_DIR")
	if output_dir.is_empty() or not OS.get_user_data_dir().contains("CodexIronTideValidation"):
		get_tree().quit(2);return
	for mode in [MatchRules.RA2,MatchRules.EXTENDED]:
		start(mode);battle.fog=null
		var ground=make("HTNK","enemy");var air=make("JUMPJET","enemy");air.logistics.air_lift=120.0
		var friend=make("E1");var structure=battle._place_building("GAPOWR","enemy",Vector2(1200,900),true)
		var car=make("BFRT")
		for roster in [["E1","E1","E1","E1","E1"],["GGI","GGI","GGI","GGI","GGI"],["E1","GGI","CLEG","BORIS","E1"]]:
			for id in roster:
				var crew=make(id);car.logistics.passengers.append(crew);crew.set_stowed(car)
			for rank in [0,2]:
				for state in ["normal","hero","controlled","dead","short","zero"]:
					for i in car.logistics.passengers.size():
						var crew=car.logistics.passengers[i]
						crew.hp=0 if state=="dead" else crew.max_hp
						crew.side="enemy" if state=="controlled" and i%2==0 else "ally"
						crew.veteran_level=rank;crew._refresh_veteran_bonuses(false)
						crew.special.erase("academy_hero")
						if state=="hero":crew.special.academy_hero=crew.unit_id
					car.data.open_topped.range_bonus=-2000.0 if state=="short" else 110.0
					# Include a genuinely valid zero-range weapon: validity must not
					# be inferred from range > 0 when every prior weapon is invalid.
					if state=="zero":
						car.data.open_topped.range_bonus=-float(car.logistics.passengers[0].deployed_weapon().get("range",0.0))
					for target in [ground,air,friend,structure,null]:
						for cache in [{},{"enabled":true}]:compare(car,target,cache)
			if roster[0]=="E1" and roster[1]=="E1":benchmark(car,ground)
			for crew in car.logistics.passengers:battle.units.erase(crew);crew.free()
			car.logistics.passengers.clear()
		await finish()
	check(after_calls<before_calls,"eligible range short-circuit removes actual domain calls",[before_calls,after_calls])
	FileAccess.open(output_dir.path_join("result.json"),FileAccess.WRITE).store_string(JSON.stringify({"checks":checks,"failed":failed,"before_calls":before_calls,"after_calls":after_calls,"metrics":metrics},"  "))
	get_tree().quit(0 if failed==0 else 1)
func benchmark(car,target) -> void:
	car.data.open_topped.range_bonus=110.0
	for crew in car.logistics.passengers:crew.hp=crew.max_hp;crew.side="ally";crew.special.erase("academy_hero")
	var old:Array=[];var now:Array=[]
	for sample in 9:
		for variant in ([0,1] if sample%2==0 else [1,0]):
			var begin:=Time.get_ticks_usec()
			var total:=0.0
			for i in 1000:
				if variant==0:total+=Before.command_range(car,target)
				else:total+=OpenTopped.command_range(car,target)
			(old if variant==0 else now).append(Time.get_ticks_usec()-begin)
			check(total>0,"range benchmark exercises eligible weapons")
	old.sort();now.sort()
	metrics.append({"mode":BattleRequest.rules_mode,"passengers":5,"type":"E1","repetitions":1000,"before_us":old,"after_us":now,"before_p50_us":old[4],"after_p50_us":now[4]})
