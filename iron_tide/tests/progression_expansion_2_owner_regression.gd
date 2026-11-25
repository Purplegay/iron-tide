extends "res://tests/progression_expansion_2_support_regression.gd"
const Infiltration=preload("res://scripts/units/expansion_2_infiltration.gd")

func _ready() -> void:
	output_dir=OS.get_environment("IRON_TIDE_REPORT_DIR")
	if output_dir.is_empty() or not OS.get_user_data_dir().contains("CodexIronTideValidation"):get_tree().quit(2);return
	await get_tree().process_frame
	MetaProgress.reset_save()
	for rank in 4:
		await water_owner(rank)
		await calibration_owner(rank)
		await convoy_owner(rank)
		await escort_owner(rank)
		calibration_demo(rank)
	FileAccess.open(output_dir.path_join("result.json"),FileAccess.WRITE).store_string(JSON.stringify({"checks":checks,"failed":failed},"  "))
	get_tree().quit(0 if failed==0 else 1)

func teams() -> void:
	BattleRequest.house_teams={"ally":1,"enemy":1,"hostile":2}
	check(BattleRequest.friendly("ally","enemy") and not BattleRequest.friendly("ally","hostile"),"fixture has distinct allied owners and a real enemy")

func water_owner(rank:int) -> void:
	setup(rank);teams()
	var ship:=make("DEST","ally",Vector2(1100,1200),Naval.WATER)
	var allied:=make("HYD","enemy",Vector2(1110,1200))
	var first:=make("HYD","ally",Vector2(1140,1200))
	var second:=make("AEGIS","ally",Vector2(1180,1200))
	check(cast(ship),"real water W casts in allied-house battle")
	check(Naval.guard(allied)==0 and Naval.guard(first)>0 and Naval.guard(second)>0,"nearby allied house cannot consume either same-owner recipient slot "+str(rank))
	var hostile:=make("HTNK","hostile",Vector2(1300,1200))
	check(is_equal_approx(direct_loss(first,hostile),1000*(1-[.12,.16,.2,.24][rank])) and direct_loss(allied,hostile)==1000,"actual hostile damage protects only same-owner water recipients")
	await finish()

func calibration_owner(rank:int) -> void:
	prepare_support(rank);teams()
	var gun:=deploy_chopper(Vector2(1000,1100))
	var allied:=deploy_chopper(Vector2(1000,1350));allied.side="enemy";allied.passive={}
	var target:=make("HTNK","hostile",Vector2(1300,1100))
	battle.allied_state[Calibration.ZONES]=[{"owner":gun,"side":"ally","point":target.position,"left":4.0,"damage":[.08,.12,.16,.2][rank]}]
	check(Calibration.bonus_at(battle,"enemy",target)==0,"allied house cannot use player's calibration zone "+str(rank))
	var before:float=target.hp
	target.receive_hit(1000,"shell",{"expansion_extra":true,"reference_weapon":allied.deployed_weapon()},allied)
	check(target.hp==before-1000,"real cannon skill from allied owner receives no borrowed calibration")
	before=target.hp
	target.receive_hit(1000,"shell",{"expansion_extra":true,"reference_weapon":gun.deployed_weapon()},gun)
	check(is_equal_approx(before-target.hp,1000*(1+[.08,.12,.16,.2][rank])),"same-owner cannon skill retains calibration")
	battle.allied_state[Calibration.ZONES].append({"owner":allied,"side":"enemy","point":target.position,"left":4.0,"damage":.9})
	check(is_equal_approx(Calibration.bonus_at(battle,"ally",target),[.08,.12,.16,.2][rank]),"stronger allied-owner overlap cannot override own zone")
	var codec=BattleSaves.Snapshot.new();var snapshot:Dictionary=codec.capture(battle);codec.restore(battle,snapshot)
	target=battle.units.filter(func(u):return u.side=="hostile")[0]
	check(codec.error.is_empty() and is_equal_approx(Calibration.bonus_at(battle,"ally",target),[.08,.12,.16,.2][rank]) and Calibration.bonus_at(battle,"enemy",target)==.9,"snapshot preserves independent same-team zone ownership")
	await finish()

func convoy_owner(rank:int) -> void:
	prepare_support(rank);teams()
	var unit:=make("MTNK","ally",Vector2(1000,1100));unit.max_hp=1000;unit.hp=500
	var peer:=make("HTNK","enemy",Vector2(1040,1100));peer.passive={}
	X.tick(unit,0);move_pair(unit,peer,3);move_pair(unit,peer,1)
	check(unit.hp==500 and not unit.special.progression_v2.has("convoy_left"),"allied-house movement cannot arm or heal convoy "+str(rank))
	peer.side="ally";X.tick(unit,0);move_pair(unit,peer,3);move_pair(unit,peer,1)
	check(is_equal_approx(unit.hp,500+1000*[.005,.007,.009,.011][rank]),"same-owner actual movement enables convoy healing")
	peer.side="enemy";move_pair(unit,peer,.1)
	check(not unit.special.progression_v2.has("convoy_left"),"changing companion to allied owner ends active convoy")
	await finish()

func escort_owner(rank:int) -> void:
	setup(rank);teams();BattleRequest.combat_context.card_ranks[Infiltration.ESCORT]=rank
	var caster:=make("TANY","ally",Vector2(1000,1100));caster.passive=GameData.get_skill(Infiltration.ESCORT);caster.max_hp=1000;caster.hp=410
	var allied:=make("E1","enemy",Vector2(1010,1100))
	var first:=make("E1","ally",Vector2(1040,1100))
	var second:=make("E2","ally",Vector2(1080,1100))
	var hostile:=make("HTNK","hostile",Vector2(1300,1100))
	caster.receive_hit(50,"shell",{},hostile)
	check(caster.hp>0 and caster.hp<400,"real hostile hit crosses escort threshold")
	check(Infiltration.escort_speed(allied)==0 and Infiltration.escort_speed(first)>0 and Infiltration.escort_speed(second)>0,"allied infantry cannot consume either same-owner escort slot "+str(rank))
	check(Infiltration.escort_speed(caster)==0,"escort still excludes caster")
	await finish()

func calibration_demo(rank:int) -> void:
	var demo=preload("res://scripts/ui/expansion_2_demo.gd")
	var strong:float=[8.,12.,16.,20.][rank];var weak:float=[8.,8.,8.,12.][rank]
	for point in [[.99,0.],[1.,strong],[2.,strong],[4.99,strong],[5.,weak],[5.99,weak],[6.,0.]]:
		var sample:Dictionary=demo.sample(Calibration.CARD,rank,point[0])
		check(is_equal_approx(sample.value,point[1]) and sample.active==(point[1]>0),"calibration demo shows actual maximum then surviving weak bonus "+str(rank)+"/"+str(point[0]))
