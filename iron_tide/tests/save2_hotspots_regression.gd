extends "res://tests/base_recovery_regression.gd"

const Tactics = preload("res://scripts/world/skirmish_tactics.gd")

func _ready() -> void:
	output_dir = OS.get_environment("IRON_TIDE_REPORT_DIR")
	if output_dir.is_empty() or not OS.get_user_data_dir().contains("CodexIronTideValidation"):
		get_tree().quit(2)
		return
	for mode in [MatchRules.RA2, MatchRules.EXTENDED]:
		start(mode)
		exercise_detection()
		exercise_targets()
		exercise_ore_marks()
		await finish()
	FileAccess.open(output_dir.path_join("result.json"),FileAccess.WRITE).store_string(JSON.stringify({"checks":checks,"failed":failed},"  "))
	print("SAVE2 HOTSPOTS checks=",checks.size()," failed=",failed)
	get_tree().quit(0 if failed == 0 else 1)

# Independent original full-roster detection rule for a resting YR mirage.
func legacy_hidden(target, observer: String) -> bool:
	for other in battle.units:
		if not AlliedAbilities.alive(other) or other.side != observer or other.embarked_in != null: continue
		var radius := 0.0
		if AlliedAbilities.flag(other,"DetectDisguise"): radius = other.sight
		elif AlliedAbilities.infantry(other): radius = 55.0
		if radius > 0 and other.global_position.distance_to(target.global_position) <= radius: return false
	return true

func exercise_detection() -> void:
	var target = battle.spawn_unit("MGTK","enemy",Vector2(1200,1200))
	target.order_stop()
	target.special.erase("reveal")
	var scout = battle.spawn_unit("E1","ally",Vector2(2000,2000))
	var dog = battle.spawn_unit("DOG","ally",Vector2(2000,2000))
	var tank = battle.spawn_unit("MTNK","ally",Vector2(1200,1200))
	for actor in [scout,dog]:
		for radius in [0.0,20.0,300.0]:
			actor.sight = radius
			for distance in [0.0,19.0,20.0,21.0,54.0,55.0,56.0,299.0,300.0,301.0]:
				actor.position = target.position + Vector2(distance,0)
				for state in ["live","captured","embarked","dead"]:
					actor.side = "enemy" if state == "captured" else "ally"
					actor.embarked_in = tank if state == "embarked" else null
					actor.hp = 0 if state == "dead" else actor.max_hp
					check(AlliedAbilities.concealed(target,"ally") == legacy_hidden(target,"ally"),prefix+"detection oracle",[actor.unit_id,radius,distance,state])
		actor.side = "ally"; actor.hp = actor.max_hp; actor.embarked_in = null
		actor.position = Vector2(2000,2000)
	# Another preview/battle in the same SceneTree must not provide detection.
	var outside := Node2D.new()
	add_child(outside)
	dog.reparent(outside)
	dog.position = target.position
	battle.units.erase(dog)
	check(AlliedAbilities.concealed(target,"ally"),prefix+"foreign world detector ignored")
	outside.free()
	target.special.reveal = 1.0
	check(not AlliedAbilities.concealed(target,"ally"),prefix+"fire reveal remains immediate")

func legacy_objective(ai, army: Array) -> Vector2:
	var best := -INF
	var result: Vector2 = ai.objective()
	var center: Vector2 = ai.rally
	if not army.is_empty():
		center=Vector2.ZERO
		for unit in army: center+=unit.global_position
		center/=army.size()
	for target in battle.units+battle.buildings:
		if not battle.actor_alive(target) or not BattleRequest.is_house(target.side) or BattleRequest.friendly(ai.house_id,target.side) or not battle.actor_visible_to(ai.house_id,target): continue
		if not army.any(func(u): return Tactics.fighter(battle,u,ai.house_id) and u.attack_domain_valid(target)): continue
		var priority := 30.0
		if target is Building:
			priority=90.0
			if target.is_refinery(): priority=120.0
			elif target.building_id=="GAWEAP": priority=130.0
			elif target.building_id in ["GAWEAT","GACSPH","NAMISL","NAIRON"]: priority=180.0
		elif target.is_harvester: priority=110.0
		priority+=15.0*(1.0-target.hp/maxf(1.0,target.max_hp))
		var distance:float=center.distance_to(target.global_position)
		priority-=distance/30.0
		if target is Building and distance<=12.0*Ra2Damage.PX_PER_CELL:priority+=100.0
		if priority>best:best=priority;result=target.global_position
	return result

func exercise_targets() -> void:
	var ai=battle.skirmish_ai
	var army:Array=[]
	for id in ["MTNK","GGI","ENGINEER","SHAD","FV"]:
		army.append(battle.spawn_unit(id,"enemy",Vector2(1600,1600)))
	for id in ["MTNK","ZEP","HARV"]:battle.spawn_unit(id,"ally",Vector2(1400,1400))
	for hidden in [false,true]:
		if hidden:
			battle.fog=preload("res://scripts/world/fog_of_war.gd").new()
			battle.add_child(battle.fog)
			battle.fog.setup(battle)
		for count in range(army.size()+1):
			var squad:=army.slice(0,count)
			check(Tactics.attack_position(ai,squad)==legacy_objective(ai,squad),prefix+"objective matches original full scan",[hidden,count])

func exercise_ore_marks() -> void:
	if battle.fog!=null:
		battle.fog.free()
		battle.fog=null
	var random:=RandomNumberGenerator.new()
	random.seed=12821
	for i in 400:
		var ore:=ResourceNode.new()
		ore.position=Vector2(random.randf_range(0,2400),random.randf_range(0,2400))
		battle.add_child(ore)
		if i%7==0:ore.amount=0
	for scale in [0.025,0.1,0.3]:
		var projection:=Transform2D(0.6,Vector2(scale,scale),0.0,Vector2(-25,13))
		var expected:Array=[]
		for ore in get_tree().get_nodes_in_group("resource_nodes"):
			if not battle.position_explored_by("ally",ore.position):continue
			var seen:bool=battle.position_visible_to("ally",ore.position)
			if seen and ore.is_empty():continue
			var point:Vector2=projection*ore.position
			var merged:=false
			for mark in expected:
				if point.distance_squared_to(mark.p)<25:
					mark.n+=1;mark.seen=mark.seen or seen;merged=true;break
			if not merged:expected.append({"p":point,"n":1,"seen":seen})
		screen.hud.minimap._refresh_ore_marks(projection)
		check(screen.hud.minimap._ore_marks==expected,prefix+"ore clusters preserve first match and negative bin edges",scale)
	# A fog revision elsewhere must not recreate unchanged clusters. Remaining
	# amount is not a radar input; depletion and regrowth are.
	var radar=screen.hud.minimap
	var projection:Transform2D=radar._ore_projection
	var marks:Array=radar._ore_marks.duplicate(true)
	var first:Dictionary=radar._ore_marks[0]
	first.probe=17
	radar._refresh_ore_marks(projection)
	check(radar._ore_marks[0].get("probe")==17,prefix+"unchanged ore intelligence reuses existing clusters")
	first.erase("probe")
	var ore=get_tree().get_nodes_in_group("resource_nodes")[1]
	var amount:float=ore.amount
	ore.amount=0
	radar._refresh_ore_marks(projection)
	check(radar._ore_marks!=marks,prefix+"visible depleted ore updates clusters immediately")
	ore.amount=amount
	radar._refresh_ore_marks(projection)
	check(radar._ore_marks==marks,prefix+"visible regrowth restores original clusters")
