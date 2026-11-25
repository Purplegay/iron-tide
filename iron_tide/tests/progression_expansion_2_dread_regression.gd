extends "res://tests/progression_expansion_2_armor_regression.gd"
const Dread=preload("res://scripts/units/expansion_2_dread.gd")

func _ready() -> void:
	output_dir=OS.get_environment("IRON_TIDE_REPORT_DIR")
	if output_dir.is_empty() or not OS.get_user_data_dir().contains("CodexIronTideValidation"):get_tree().quit(2);return
	await get_tree().process_frame
	MetaProgress.reset_save()
	for level in 4:await ranked_dread(level)
	await actual_interceptor()
	await saved_missile()
	await boundaries_dread()
	await purchase_dread()
	FileAccess.open(output_dir.path_join("result.json"),FileAccess.WRITE).store_string(JSON.stringify({"checks":checks,"failed":failed},"  "))
	print("EXPANSION_2_DREAD_RESULT ",checks.size()," checks, ",failed," failed")
	get_tree().quit(0 if failed==0 else 1)

func setup_dread(level:int) -> void:
	start(MatchRules.EXTENDED);battle.fog=null
	BattleRequest.combat_context.unit_talents.DRED={Dread.TALENT:level}

func launch_pair(ship,target) -> Array:
	check(normal_shot(ship,target),"real Dreadnought ordinary launcher fires")
	var first=ship.special.get("raising_missile_0")
	var delay:float=ship._active_weapon().burst_delay
	ship._update_burst(delay*.5)
	check(not ship.special.has("raising_missile_1"),"second missile does not leave early")
	ship._update_burst(delay*.5+.000001)
	var second=ship.special.get("raising_missile_1")
	check(first!=null and second!=null and first!=second,"native burst produces two independent missiles at original delay")
	return [first,second]

func ranked_dread(level:int) -> void:
	setup_dread(level)
	var ship:=actor("DRED","ally",Vector2(700,1200));var target:=structure(Vector2(1450,1200))
	var reload:float=ship.data.rocket.reload*(1-[.08,.12,.16,.2][level])
	var prep:=Demo.dread_departure()
	check(is_equal_approx(Native.rack_cycle(ship),prep+reload),"rank only shortens reload part of complete rack cycle "+str(level))
	var shots:=launch_pair(ship,target)
	var a=shots[0];var b=shots[1]
	if a==null or b==null:await finish();return
	Native.fly(a,prep-.01);Native.tick_racks(ship,0)
	check(a.special.flight.phase=="rack" and Dread.shield(a).is_empty(),"raising missile has no early shield")
	check(is_equal_approx(ship.special.missile_racks[0],reload+.01),"remaining preparation is never discounted")
	Native.fly(a,.010001)
	var maximum:float=a.max_hp*[.3,.45,.6,.8][level]
	check(a.special.flight.phase!="rack" and is_equal_approx(Dread.shield(a).hp,maximum),"actual native departure grants exact rank missile shield "+str(level))
	check(is_equal_approx(ship.special.missile_racks[0],reload) and Dread.shield(b).is_empty(),"first departed rail reloads while second rail remains raising")
	leave_rack(b)
	check(is_equal_approx(Dread.shield(b).hp,maximum),"second missile independently receives full protection")
	var hp:float=a.hp
	a.receive_hit(5,"flak",{},target)
	check(a.hp==hp and is_equal_approx(Dread.shield(a).hp,maximum-5),"real interception damage consumes shield before missile health")
	check(Dread.shield(b).hp==maximum,"damage to one missile does not consume other missile shield")
	Dread.departed(a)
	check(is_equal_approx(Dread.shield(a).hp,maximum-5),"duplicate departure cannot refill damaged shield")
	X.tick(a,100)
	check(is_equal_approx(Dread.shield(a).hp,maximum-5),"shield does not regenerate or expire on a timer")
	a.receive_hit(maximum,"flak",{},target)
	var overflow:float=Ra2Damage.quantize(maximum)-(maximum-5)
	check(is_equal_approx(a.hp,hp-overflow) and Dread.shield(a).is_empty(),"native integer hit crossing shield boundary spills remaining damage into health",[a.hp,hp-overflow,maximum])
	Dread.departed(a);check(Dread.shield(a).is_empty(),"depleted missile cannot regain its shield")
	var racks:Array=ship.special.missile_racks
	Native.tick_racks(ship,reload-.01)
	check(racks[0]>0 and racks[1]>0,"both actual rails remain unavailable before their shortened duration")
	Native.tick_racks(ship,.010001)
	check(racks[0]==0 and racks[1]==0 and Native.ready_racks(ship)==2,"both actual rails refill after shortened duration")
	X.tick(ship,0)
	check(not Second.entries(ship).is_empty() and not Second.entries(b).is_empty(),"ship reload and individual missile shield have live status rows")
	if DisplayServer.get_name()!="headless":
		battle.camera.position=b.position;b.visible=true;b.queue_redraw()
		await get_tree().process_frame;await RenderingServer.frame_post_draw
		check(b._art_frame>=0,"GPU draws actual protected missile "+str(level))
	var before:float=target.hp;impact(b)
	check(target.hp<before,"shielded missile retains native ground impact damage")
	a.receive_hit(10000,"flak",{},target)
	check(a._dead,"shield spent missile can still be intercepted")
	await finish()

func actual_interceptor() -> void:
	setup_dread(3)
	var ship:=actor("DRED","ally",Vector2(700,1200));var target:=structure(Vector2(1450,1200))
	var shots:=launch_pair(ship,target);var missile=shots[0]
	leave_rack(missile)
	var aa:=actor("AEGIS","enemy",missile.position+Vector2(180,0))
	var initial:float=Dread.shield(missile).hp
	check(normal_shot(aa,missile),"real enemy Aegis accepts protected native missile as air target")
	check(not missiles(aa).is_empty(),"real interception projectile launches")
	fly_missiles(aa)
	check(missile._dead or Dread.shield(missile).is_empty() or Dread.shield(missile).hp<initial,"actual AA projectile reaches shielded missile and consumes durability")
	for i in 20:
		if missile._dead:break
		normal_shot(aa,missile);fly_missiles(aa)
	check(missile._dead,"repeated actual AA fire destroys protected missile")
	check(not Dread.shield(shots[1]).has("hp"),"interception never grants shield to still raising other missile")
	await finish()

func saved_missile() -> void:
	setup_dread(2)
	var ship:=actor("DRED","ally",Vector2(700,1200));var target:=structure(Vector2(1450,1200))
	var shots:=launch_pair(ship,target);var missile=shots[0]
	leave_rack(missile);missile.receive_hit(7)
	Native.tick_racks(ship,.8)
	var shield_left:float=Dread.shield(missile).hp
	var left:float=ship.special.missile_racks[0]
	var codec=BattleSaves.Snapshot.new();var snapshot:Dictionary=codec.capture(battle)
	var path:=output_dir.path_join("dread.snapshot")
	var file=FileAccess.open(path,FileAccess.WRITE);file.store_var(snapshot);file.close()
	file=FileAccess.open(path,FileAccess.READ);snapshot=file.get_var();file.close()
	codec.restore(battle,snapshot)
	check(codec.error.is_empty(),"binary missile and independent rail snapshot restores")
	ship=battle.units.filter(func(u):return u.unit_id=="DRED")[0]
	missile=battle.units.filter(func(u):return u.unit_id=="DMISL" and u.special.flight.phase!="rack")[0]
	var raising=ship.special.raising_missile_1
	check(is_equal_approx(Dread.shield(missile).hp,shield_left) and ship.special.missile_racks[0]==left,"restore retains spent shield and remaining reload")
	check(Dread.shield(raising).is_empty() and raising.special.flight.source==ship,"still raising other rail remains unshielded with restored source")
	Dread.departed(missile);check(Dread.shield(missile).hp==shield_left,"restored departure marker prevents extra shield")
	leave_rack(raising);check(Dread.shield(raising).hp==raising.max_hp*.6,"restored raising missile earns its own shield only on departure")
	ship.hp=0
	missile.receive_hit(3)
	check(is_equal_approx(Dread.shield(missile).hp,shield_left-3),"in-flight shield persists after launcher dies")
	await finish()

func boundaries_dread() -> void:
	for mode in [MatchRules.RA2,MatchRules.EXTENDED]:
		start(mode);battle.fog=null
		BattleRequest.combat_context.unit_talents.DRED={Dread.TALENT:3} if mode==MatchRules.RA2 else {}
		var ship:=actor("DRED","ally",Vector2(700,1200));var target:=structure(Vector2(1450,1200))
		var missile=launch_pair(ship,target)[0];leave_rack(missile)
		check(Dread.reload_time(ship)==ship.data.rocket.reload and Dread.shield(missile).is_empty(),"classic or unowned talent preserves native reload and no shield "+mode)
		await finish()
	setup_dread(3)
	var ship:=actor("DRED","ally",Vector2(700,1200));var target:=structure(Vector2(1450,1200))
	var shots:=launch_pair(ship,target)
	shots[0].receive_hit(10000)
	check(shots[0]._dead and Dread.shield(shots[0]).is_empty(),"intercepting on rack never grants departure protection")
	check(is_equal_approx(ship.special.missile_racks[0],Dread.reload_time(ship)),"destroyed occupied rail still uses shortened normal reload")
	leave_rack(shots[1]);AlliedAbilities.change_side(shots[1],"enemy")
	check(Dread.shield(shots[1]).is_empty(),"changing missile owner cannot retain prior-side shield")
	var truck:=actor("V3","ally",Vector2(700,1400))
	check(Dread.reload_time(truck)==truck.data.rocket.reload,"Dreadnought talent does not change V3 reload")
	var fresh:=actor("DRED","ally",Vector2(700,1400))
	var removal=launch_pair(fresh,target)[0];leave_rack(removal)
	check(not Dread.shield(removal).is_empty(),"direct-removal boundary starts from a fully protected native missile")
	var target_hp:float=target.hp
	AlliedAbilities.consume(removal)
	check(removal._dead and removal.is_queued_for_deletion() and target.hp==target_hp,"native non-damage removal bypasses shield and does not cause a shield-break blast")
	await finish()

func purchase_dread() -> void:
	MetaProgress.reset_save();MetaProgress.currency.cores=100000
	var quote:=MetaProgress.talent_unlock_quote("DRED",Dread.TALENT)
	check(not quote.is_empty() and MetaProgress.unlock_unit_talent("DRED",Dread.TALENT,quote.get("cost",-1)),"real Dreadnought talent unlock")
	for rank in 3:check(MetaProgress.upgrade_talent("DRED",Dread.TALENT,rank),"real Dreadnought talent upgrade "+str(rank))
	MetaProgress.load_save();start(MatchRules.EXTENDED)
	var ship:=actor("DRED","ally",Vector2(700,1200))
	check(is_equal_approx(Dread.reload_time(ship),ship.data.rocket.reload*.8),"purchased rank three persists and applies to a new match")
	await finish()
