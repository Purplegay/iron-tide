extends "res://tests/progression_expansion_2_naval_regression.gd"
const Seal=preload("res://scripts/units/expansion_2_overload.gd")
const Cards=preload("res://scripts/units/expansion_cards.gd")

func _ready() -> void:
	output_dir=OS.get_environment("IRON_TIDE_REPORT_DIR")
	if output_dir.is_empty() or not OS.get_user_data_dir().contains("CodexIronTideValidation"):get_tree().quit(2);return
	await get_tree().process_frame
	MetaProgress.reset_save()
	for level in 4:
		for id in Seal.CASTERS:await ordinary_case(level,id)
		await idle_duration(level)
	await legal_targets()
	await building_fire()
	await burst_and_ra3()
	await save_pending()
	await player_selection()
	await visibility_and_skill()
	await classic_seal()
	FileAccess.open(output_dir.path_join("result.json"),FileAccess.WRITE).store_string(JSON.stringify({"checks":checks,"failed":failed},"  "))
	print("EXPANSION_2_OVERLOAD_RESULT ",checks.size()," checks, ",failed," failed")
	get_tree().quit(0 if failed==0 else 1)

func setup_seal(level:int) -> void:
	setup(level);BattleRequest.combat_context.card_ranks[Seal.CARD]=level
	for id in Seal.CASTERS:BattleRequest.combat_context.loadouts[id]={"active":[Seal.CARD],"passive":""}

func apply_seal(caster,target) -> bool:
	caster.attack_target=target
	return caster.use_ability(UnitSkillLayout.find(caster,Seal.CARD))

func expected(state:Dictionary,target) -> float:
	return Ra2Damage.quantize(CombatMath.full_damage(state.weapon,target.armor,state.bonus,null,target.ra2_armor,0,target))

func ordinary_case(level:int,id:String) -> void:
	setup_seal(level)
	var caster:=make(id,"ally",Vector2(1000,1100));var target:=make("HTNK","enemy",Vector2(1200,1100))
	var near:=make("E1","enemy",Vector2(1250,1100));var far:=make("E1","enemy",Vector2(1267,1100));var friendly:=make("E1","ally",Vector2(1220,1120))
	caster.has_move_order=true;caster.move_target=Vector2(900,1400);caster._cd_timer=2.3
	check(apply_seal(caster,target),"real W applies seal "+id+str(level))
	var state:Dictionary=target.special[Seal.KEY]
	check(state.left==4+level and state.remaining==3 and w(caster).cd_left==30,"rank duration, three uses and thirty-second cooldown")
	check(caster.has_move_order and caster.move_target==Vector2(900,1400) and caster._cd_timer==2.3,"cast preserves existing movement and ordinary reload")
	check(is_equal_approx(state.weapon.damage,caster._active_weapon().damage*[.2,.25,.3,.4][level]),"sealed attack snapshot uses casting weapon percentage")
	var main_damage:=expected(state,target);var near_damage:=expected(state,near)
	var before:float=target.hp;var nearby:float=near.hp;var outside:float=far.hp;var friendly_hp:float=friendly.hp
	check(normal_shot(target,caster),"sealed ordinary target fires actual shell")
	check(state.remaining==2 and target.hp==before and battle.allied_state.get(Seal.EVENTS,[]).size()==1,"real fire queues one electric blast after original attack")
	Cards.world_tick(battle,0)
	check(is_equal_approx(before-target.hp,main_damage) and is_equal_approx(nearby-near.hp,near_damage),"self and nearby enemy each take one rank-correct shock",[before-target.hp,main_damage,nearby-near.hp,near_damage])
	check(far.hp==outside and friendly.hp==friendly_hp,"radius boundary and caster-friendly exclusion")
	check(battle.has_node("ExpansionFields") and not Seal.entries(target).is_empty(),"live seal visual host and remaining-use status exist")
	normal_shot(target,caster);Cards.world_tick(battle,.99)
	check(state.remaining==2,"repeat firing inside one second cannot consume another use")
	Cards.world_tick(battle,.010001);normal_shot(target,caster);Cards.world_tick(battle,0)
	check(state.remaining==1,"new ordinary volley after one second consumes second use")
	Cards.world_tick(battle,1.01);normal_shot(target,caster);Cards.world_tick(battle,0)
	check(not target.special.has(Seal.KEY),"third use removes seal")
	check(is_equal_approx(before-target.hp,3*main_damage),"total capped at three shocks without recursive fire")
	normal_shot(target,caster);Cards.world_tick(battle,1.01)
	check(is_equal_approx(before-target.hp,3*main_damage),"fourth ordinary fire after consumption causes no extra blast")
	await finish()

func idle_duration(level:int) -> void:
	setup_seal(level)
	var caster:=make("TTNK","ally",Vector2(1000,1100));var target:=make("HTNK","enemy",Vector2(1200,1100))
	check(apply_seal(caster,target),"idle rank case applies actual seal "+str(level))
	var before:float=target.hp
	Cards.world_tick(battle,4+level-.01)
	check(target.special.has(Seal.KEY) and target.special[Seal.KEY].remaining==3 and target.hp==before,"idle seal retains all charges immediately before rank expiry "+str(level))
	Cards.world_tick(battle,.010001)
	check(not target.special.has(Seal.KEY) and target.hp==before and not battle.allied_state.has(Seal.EVENTS),"idle seal expires without damage at rank boundary "+str(level))
	check(normal_shot(target,caster),"ordinary fire still works after idle expiry "+str(level))
	Cards.world_tick(battle,0)
	check(target.hp==before and not battle.allied_state.has(Seal.EVENTS),"later shot cannot revive expired seal "+str(level))
	await finish()

func legal_targets() -> void:
	setup_seal(3)
	var caster:=make("TTNK","ally",Vector2(1000,1100))
	for row in [["E1","enemy"],["SHAD","enemy"],["SUB","enemy"],["CMIN","enemy"],["HTNK","ally"],["HTNK","neutral"]]:
		var target:=make(row[0],row[1],Vector2(1200,1100))
		check(not apply_seal(caster,target) and w(caster).cd_left==0,"illegal seal target refused without cooldown "+str(row))
		battle.units.erase(target);target.free()
	var harmless:Building=battle._place_building("GAPOWR","enemy",Vector2(1200,1100),true);harmless._buildup_play=-1
	check(not apply_seal(caster,harmless),"unarmed building cannot be sealed")
	var target:=make("HTNK","enemy",Vector2(1276,1100))
	check(not apply_seal(caster,target),"outside five cells refused")
	target.position.x=1275
	check(apply_seal(caster,target),"inclusive five-cell boundary succeeds")
	var other:=make("SHK","ally",Vector2(1100,1050));target.special[Seal.KEY].remaining=1
	check(not apply_seal(other,target) and w(other).cd_left==0 and target.special[Seal.KEY].remaining==1,"second caster cannot stack or refill existing seal")
	var before:float=target.hp
	Cards.world_tick(battle,7)
	check(not target.special.has(Seal.KEY) and target.hp==before,"holding fire lets full seal duration expire without damage")
	check(apply_seal(other,target),"new seal allowed after previous expires")
	AlliedAbilities.change_side(target,"ally");Cards.world_tick(battle,0)
	check(not target.special.has(Seal.KEY),"target capture removes old-side seal")
	await finish()

func building_fire() -> void:
	setup_seal(2)
	var caster:=make("SHK","ally",Vector2(1000,1100))
	var tower:Building=battle._place_building("GAPILL","enemy",Vector2(1200,1100),true);tower._buildup_play=-1;tower.hp=100000;tower.max_hp=100000
	check(apply_seal(caster,tower),"armed building accepts real seal")
	var before:float=tower.hp;var state:Dictionary=tower.special[Seal.KEY];var damage:=expected(state,tower)
	tower.attack_target=caster
	check(tower._fire(),"sealed native building actually fires")
	Cards.world_tick(battle,0)
	check(is_equal_approx(before-tower.hp,damage) and state.remaining==2,"building ordinary fire consumes one seal and damages itself")
	if DisplayServer.get_name()!="headless":
		battle.camera.position=tower.position;tower.queue_redraw()
		await get_tree().process_frame;await RenderingServer.frame_post_draw
		check(battle.has_node("ExpansionFields"),"GPU renders active building seal")
	await finish()

func burst_and_ra3() -> void:
	for id in ["APOC","R3APOC","R3TESLA","R3FUTURE"]:
		setup_seal(3)
		var caster:=make("TTNK","ally",Vector2(1000,1100));var target:=make(id,"enemy",Vector2(1200,1100))
		check(apply_seal(caster,target),"combat vehicle accepts seal "+id)
		if id=="R3FUTURE":
			normal_shot(target,caster)
			check(target.special[Seal.KEY].remaining==3,"future tank preattack preparation is not firing")
			preload("res://scripts/units/ra3_future_state.gd").tick(target,.11)
		check(normal_shot(target,caster),"actual main weapon fires "+id)
		check(target.special[Seal.KEY].remaining==2,"first ordinary volley triggers once "+id)
		Cards.world_tick(battle,1.1)
		if id=="APOC":target._update_burst(1.1)
		elif id in ["R3APOC","R3TESLA"]:
			target.special.soviet_mounts[id].left=0
			target._try_fire_ready()
		check(target.special[Seal.KEY].remaining==2,"same volley cannot trigger again even after interval "+id)
		await finish()

func save_pending() -> void:
	setup_seal(3)
	var caster:=make("TTNK","ally",Vector2(1000,1100));var target:=make("HTNK","enemy",Vector2(1200,1100))
	check(apply_seal(caster,target),"prepare saved seal")
	var expected_damage:=expected(target.special[Seal.KEY],target)
	normal_shot(target,caster)
	var codec=BattleSaves.Snapshot.new();var snapshot:Dictionary=codec.capture(battle)
	var file=FileAccess.open(output_dir.path_join("seal.snapshot"),FileAccess.WRITE);file.store_var(snapshot);file.close()
	file=FileAccess.open(output_dir.path_join("seal.snapshot"),FileAccess.READ);snapshot=file.get_var();file.close()
	codec.restore(battle,snapshot)
	caster=battle.units.filter(func(u):return u.unit_id=="TTNK")[0];target=battle.units.filter(func(u):return u.unit_id=="HTNK")[0]
	check(codec.error.is_empty() and target.special[Seal.KEY].remaining==2 and battle.allied_state[Seal.EVENTS].size()==1,"binary snapshot preserves already consumed use and pending blast")
	caster.bonuses.attack_bonus*=4;caster.hp=0
	var before:float=target.hp
	Cards.world_tick(battle,.4)
	check(is_equal_approx(before-target.hp,expected_damage) and not battle.allied_state.has(Seal.EVENTS),"restored queued attack snapshot resolves once after source death")
	var hp:float=target.hp;Cards.world_tick(battle,.1)
	check(target.hp==hp and target.special[Seal.KEY].remaining==2 and is_equal_approx(target.special[Seal.KEY].left,6.5),"no repeated event and remaining duration continues after restore")
	target.position+=Vector2(300,0)
	var victim:=make("E1","ally",target.position+Vector2(100,0));var old_neighbor:=make("E1","enemy",Vector2(1200,1130));var new_neighbor:=make("E1","enemy",target.position+Vector2(30,0))
	Cards.world_tick(battle,.6);normal_shot(target,victim);Cards.world_tick(battle,0)
	check(old_neighbor.hp==100000 and new_neighbor.hp<100000,"next shock follows new firing position outside original cast range")
	await finish()

func player_selection() -> void:
	setup_seal(0)
	var caster:=make("TTNK","ally",Vector2(1000,1100));var target:=make("HTNK","enemy",Vector2(1200,1100))
	battle.selected_units=[caster]
	var slot:=UnitSkillLayout.find(caster,Seal.CARD)
	check(battle.request_ability(slot)==-1 and battle.cast_slot==slot,"actual W button enters manual targeting mode")
	battle.cancel_cast()
	check(Seal.cast_selected(battle,target.position)==1 and target.special.has(Seal.KEY),"manual confirmation selects real enemy at clicked world position")
	check(Auto.supported(Seal.CARD) and not Auto.hint(Seal.CARD).is_empty(),"Auto W documents engaged-target automatic seal policy")
	await finish()

func classic_seal() -> void:
	start(MatchRules.RA2)
	var caster:=make("SHK","ally",Vector2(1000,1100));var target:=make("HTNK","enemy",Vector2(1200,1100))
	var ab:=ability(caster,Seal.CARD);caster.attack_target=target
	check(not X.cast(caster,ab,Vector2.INF) and not target.special.has(Seal.KEY),"classic mode cannot apply forced expansion card")
	await finish()

func visibility_and_skill() -> void:
	start(MatchRules.EXTENDED)
	battle.fog=preload("res://scripts/world/fog_of_war.gd").new()
	battle.add_child(battle.fog);battle.fog.setup(battle)
	BattleRequest.combat_context.loadouts.TTNK={"active":[Seal.CARD],"passive":""}
	var caster:=make("TTNK","ally",Vector2(1000,1100));var target:=make("TTNK","enemy",Vector2(1200,1100))
	check(battle.fog!=null,"visibility test uses real fog object")
	battle.fog.visible_cells.ally.fill(0)
	check(not apply_seal(caster,target) and w(caster).cd_left==0,"unseen enemy refused without cooldown")
	battle.fog._reveal("ally",target.position,55,1)
	check(apply_seal(caster,target),"real fog reveal permits target")
	caster.position=target.position+Vector2(-60,0)
	battle.fog._reveal("enemy",caster.position,55,1)
	var shock:=ability(target,"ap_shock_pulse")
	var before:float=caster.hp
	check(target.use_ability(target.skills.find(shock)),"sealed enemy casts real W shock pulse")
	Cards.world_tick(battle,0)
	check(caster.hp<before and target.special[Seal.KEY].remaining==3 and not battle.allied_state.has(Seal.EVENTS),"actual damaging W does not trigger seal",[before-caster.hp,target.special[Seal.KEY].remaining,battle.allied_state.get(Seal.EVENTS,[])])
	target._cd_timer=99;target.attack_target=caster;target.attack_ordered=true
	check(not target._try_fire_ready() and target.special[Seal.KEY].remaining==3,"waiting ordinary weapon cannot trigger seal")
	var temporary:=make("HTNK","enemy",Vector2(1150,1100));temporary.special.expansion_temporary={"kind":"mirror"}
	check(not Seal.available(caster,temporary),"temporary summoned copy cannot receive seal")
	await finish()
