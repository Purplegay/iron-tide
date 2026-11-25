extends "res://tests/progression_expansion_2_armor_regression.gd"

func _ready() -> void:
	output_dir=OS.get_environment("IRON_TIDE_REPORT_DIR")
	if output_dir.is_empty() or not OS.get_user_data_dir().contains("CodexIronTideValidation"):get_tree().quit(2);return
	await get_tree().process_frame
	MetaProgress.reset_save()
	for rank in 4:
		await underwater_splash(rank)
		for scenario in ["separate","single","overlap","growth","elite"]:await splash_totals(rank,scenario)
	FileAccess.open(output_dir.path_join("result.json"),FileAccess.WRITE).store_string(JSON.stringify({"checks":checks,"failed":failed},"  "))
	print("HUNT_BOUNDARY_RESULT ",checks.size()," checks, ",failed," failed")
	get_tree().quit(0 if failed==0 else 1)

func underwater_splash(rank:int) -> void:
	setup_rank(rank)
	var gun:=actor("APOC","ally",Vector2(700,1200))
	var main:=actor("HTNK","enemy",Vector2(1000,1200))
	var underwater:Array=[]
	for id in ["SUB","DLPH","SQD"]:
		var target:=actor(id,"enemy",Vector2(1020,1200));target.special.erase("dive_remaining")
		check(NavalContact.submerged(target),"fixture is submerged "+id)
		underwater.append(target)
	var edge:=actor("HTNK","enemy",Vector2(1055,1200))
	var outside:=actor("HTNK","enemy",Vector2(1055.1,1200))
	var air:=actor("JUMPJET","enemy",Vector2(1020,1200))
	var friend:=actor("HTNK","ally",Vector2(1020,1200))
	check(normal_shot(gun,main),"actual ordinary cannon creates splash source")
	var shell=missiles(gun)[0]
	# Isolate the newly-added blast from the native shell explosion: this real
	# projectile retains its attack snapshot after the shooter is removed.
	gun._die(main)
	Armor.finish_projectile(shell)
	for target in underwater:check(target.hp==100000,"added split splash excludes submerged "+target.unit_id+" rank "+str(rank))
	check(main.hp<100000 and edge.hp<100000 and outside.hp==100000,"added splash still includes direct target and exact one-cell boundary")
	check(air.hp==100000 and friend.hp==100000,"added splash excludes air and friendly recipients")
	var hp:float=main.hp
	Armor.finish_projectile(shell)
	check(main.hp==hp,"same projectile cannot repeat its added blast")
	await finish()

func splash_totals(rank:int,scenario:String) -> void:
	setup_rank(rank)
	var gun:=actor("APOC","ally",Vector2(700,1200))
	var main:=actor("HTNK","enemy",Vector2(1000,1200))
	var other:Unit=null
	if scenario in ["separate","overlap","elite"]:other=actor("HTNK","enemy",Vector2(970 if scenario=="overlap" else 900,1200))
	if scenario=="elite":gun._grant_veteran(2,false)
	if scenario=="growth":gun.bonuses.attack_bonus=float(gun.bonuses.get("attack_bonus",1.0))*2
	var losses:Array=[]
	var per_hit:=0.0
	for enabled in [false,true]:
		main.hp=100000
		if other!=null:other.hp=100000
		check(normal_shot(gun,main),"actual cannon volley for differential splash "+scenario)
		for index in int(gun._active_weapon().burst)-1:gun._advance_valid_burst(1,gun._active_weapon())
		var shots:=missiles(gun)
		check(shots.size()==(4 if scenario=="elite" else 2),"differential volley retains native ammunition count")
		for index in shots.size():
			var shot=shots[index]
			check(shot.target==(other if other!=null and index%2==1 else main),"real split chooses intended main/secondary in "+scenario)
			if not enabled:shot.attacker_bonus.erase("expansion_hunt")
			var raw:float=Ra2Damage.target_damage(shot.base_damage,shot.ra2_warhead,main,0.0)*.1
			per_hit=Ra2Damage.quantize(CombatMath.with_defense(CombatMath.with_offense(raw,shot.attacker_bonus),main.bonuses))
			shot._explode()
		losses.append([100000-main.hp,100000-other.hp if other!=null else 0.0])
		await get_tree().process_frame
	var count:=1 if scenario=="separate" else 2
	check(is_equal_approx(losses[1][0]-losses[0][0],per_hit*count),"full explosion adds one ten-percent instance per overlapping shell "+scenario+" rank "+str(rank),[losses,per_hit,count])
	if other!=null:check(is_equal_approx(losses[1][1]-losses[0][1],per_hit*count),"secondary independently receives matching splash instances "+scenario,[losses,per_hit,count])
	await finish()
