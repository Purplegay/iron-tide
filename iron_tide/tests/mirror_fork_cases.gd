extends RefCounted
const M=preload("res://scripts/units/mirror_fork.gd")
const X=preload("res://scripts/units/progression_expansion.gd")
const R=preload("res://scripts/units/expansion_rules.gd")
const Demo=preload("res://scripts/ui/mirror_fork_demo.gd")

static func run(t) -> void:
	for rank in 4:await exercise(t,rank)
	await endings(t)
	await preview(t)

static func owner(t,rank:int):
	BattleRequest.combat_context.get_or_add("card_ranks",{})[M.ID]=rank
	BattleRequest.combat_context.get_or_add("loadouts",{})["MGTK"]={"active":[M.ID],"passive":""}
	var unit=t.battle.spawn_unit("MGTK","ally",Vector2(1000,1000))
	unit.special.mirror_test_owner=true
	unit.hull_angle=0
	return unit

static func exercise(t,rank:int) -> void:
	t.start(MatchRules.EXTENDED)
	var unit=owner(t,rank)
	var index:=UnitSkillLayout.find(unit,M.ID)
	t.battle.select_unit(unit,false)
	t.check(index>=0 and t.battle.request_ability(index)==1,"mirror real W summon rank "+str(rank))
	var ab=unit.ability_at(index)
	var mirrors:=M.living(unit)
	t.check(mirrors.size()==2,"two live mirrors "+str(rank))
	if mirrors.size()!=2:await t.finish();return
	t.check(is_equal_approx(mirrors[0].max_hp,unit.max_hp*[.08,.1,.12,.15][rank]),"mirror rank health "+str(rank))
	t.check(is_equal_approx(mirrors[0].bonuses.attack_bonus,unit.bonuses.attack_bonus*[.3,.35,.4,.5][rank]),"mirror inherits attack percentage "+str(rank))
	t.check(not mirrors[0]._active_weapon().is_empty() and mirrors[0].skills.is_empty() and mirrors[0].passive.is_empty(),"mirror fires without recursive skills")
	var enemy=t.battle.spawn_unit("MTNK","enemy",mirrors[0].position+Vector2(90,0))
	enemy.hp=10000;enemy.max_hp=10000
	mirrors[0].process_mode=Node.PROCESS_MODE_ALWAYS
	mirrors[0].set_process(false);mirrors[0].set_physics_process(false)
	await t.get_tree().physics_frame
	mirrors[0].attack_target=enemy
	mirrors[0].turret_angle=0;mirrors[0].hull_angle=0;mirrors[0]._cd_timer=0
	t.check(mirrors[0].has_move_order and mirrors[0]._try_fire_ready() and mirrors[0].has_move_order,"mirror fires while preserving movement order")
	var before_position:Vector2=mirrors[0].position
	mirrors[0]._physics_process(.1)
	t.check(mirrors[0].position.distance_to(before_position)>0 and mirrors[0].has_move_order,"mirror continues moving during attack")
	mirrors[0].hp=mirrors[0].max_hp*.4;mirrors[1].hp=mirrors[1].max_hp*.8
	if rank==3:
		var codec=preload("res://scripts/save/battle_snapshot.gd").new()
		var snapshot:Dictionary=codec.capture(t.battle)
		t.check(codec.error.is_empty(),"active mirror group serializes")
		codec.restore(t.battle,snapshot)
		for candidate in t.battle.units:
			if candidate.special.get("mirror_test_owner",false):unit=candidate;break
		mirrors=M.living(unit);index=UnitSkillLayout.find(unit,M.ID);ab=unit.ability_at(index)
		t.check(mirrors.size()==2 and mirrors[0].special.expansion_temporary.owner==unit,"save restores owner and both mirror references")
		t.battle.select_unit(unit,false)
	t.screen.hud._rebuild_ability_bar();t.screen.hud._update_ability_live()
	var button:Button=t.screen.hud._ability_btns[1]
	var frame=button.get_node_or_null("ActiveSkillFrame")
	t.check(frame!=null and frame.visible and not button.disabled and not button.get_node("CooldownClock").visible,"active W highlights and remains clickable during summon cooldown")
	if frame!=null:
		frame._process(.2)
		t.check(frame.phase>0,"active W border rotates")
	var destination:Vector2=mirrors[1].position
	var shield:float=mirrors[1].hp
	var cooldown:float=ab.cd_left
	t.check(t.battle.request_ability(index)==1,"real second W executes during cooldown")
	t.check(unit.position.is_equal_approx(destination) and is_equal_approx(R.state(unit).mirror_shield.hp,shield),"transfer selects greater current HP and grants equal shield")
	t.check(M.living(unit).is_empty() and mirrors[0]._dead and mirrors[1]._dead and ab.cd_left==cooldown,"second W detonates both without restarting cooldown")
	t.screen.hud._update_ability_live()
	t.check(not frame.visible and button.disabled and button.get_node("CooldownClock").visible,"W highlight ends and original cooldown resumes")
	var health:float=unit.hp
	unit.receive_hit(1,"bullet")
	t.check(unit.hp==health and R.state(unit).mirror_shield.hp<shield,"shield absorbs actual incoming damage before health")
	var remains:float=R.state(unit).mirror_shield.hp
	t.check(is_equal_approx(M.absorb(unit,remains+5),5) and not R.state(unit).has("mirror_shield"),"shield overflow passes remaining damage and clears shield")
	R.state(unit).mirror_shield={"hp":shield,"maximum":shield,"left":8.0}
	if rank==3:
		var codec=preload("res://scripts/save/battle_snapshot.gd").new()
		codec.restore(t.battle,codec.capture(t.battle))
		for candidate in t.battle.units:
			if candidate.special.get("mirror_test_owner",false):unit=candidate;break
		t.check(is_equal_approx(R.state(unit).mirror_shield.hp,shield),"save restores transferred shield")
	M.tick(unit,8.0)
	t.check(not R.state(unit).has("mirror_shield"),"transferred shield expires after eight seconds")
	await t.finish()

static func endings(t) -> void:
	for ending in ["death","timeout","recast","owner_death"]:
		t.start(MatchRules.EXTENDED)
		var unit=owner(t,3)
		var index:=UnitSkillLayout.find(unit,M.ID)
		unit.use_ability(index)
		var mirrors:=M.living(unit)
		var enemy=t.battle.spawn_unit("MTNK","enemy",mirrors[0].position+Vector2(20,0))
		var far=t.battle.spawn_unit("MTNK","enemy",mirrors[0].position+Vector2(400,0))
		var friendly=t.battle.spawn_unit("MTNK","ally",mirrors[0].position+Vector2(15,0))
		enemy.hp=10000;enemy.max_hp=10000
		var health:float=enemy.hp
		if ending=="death":mirrors[0].receive_hit(100000,"bullet",{},enemy)
		elif ending=="timeout":X.Heroes.temporary_tick(mirrors[0],6.1)
		elif ending=="recast":unit.use_ability(index)
		else:unit.receive_hit(100000,"bullet",{},enemy)
		t.check((enemy.hp<health)==(ending!="owner_death"),"explosion trigger "+ending)
		t.check(far.hp==far.max_hp and friendly.hp==friendly.max_hp,"blast excludes distant and friendly units "+ending)
		var after:float=enemy.hp
		if ending!="owner_death":
			M.detonate(mirrors[0]);X.Heroes.temporary_tick(mirrors[0],10)
			t.check(enemy.hp==after,"same mirror cannot detonate twice "+ending)
		if ending in ["death","timeout"]:
			t.check(M.target(unit)==mirrors[1] and unit.ability_ready(index),"one remaining mirror still permits transfer "+ending)
			t.check(unit.use_ability(index) and M.living(unit).is_empty(),"transfer consumes last mirror "+ending)
		await t.finish()
	# Equal health keeps creation order; control restrictions do not consume a recast.
	t.start(MatchRules.EXTENDED)
	var unit=owner(t,0);var index:=UnitSkillLayout.find(unit,M.ID)
	unit.use_ability(index)
	var mirrors:=M.living(unit)
	t.check(M.target(unit)==mirrors[0],"equal current HP selects first mirror deterministically")
	unit._stun_timer=1
	t.check(not unit.use_ability(index) and M.living(unit).size()==2,"stunned owner cannot recast")
	unit._stun_timer=0
	for mirror in mirrors:X.Heroes.temporary_tick(mirror,3.1)
	t.check(not unit.ability_ready(index),"all mirrors expired removes recast permission")
	await t.finish()

static func preview(t) -> void:
	var gallery=preload("res://scripts/ui/faction_card_gallery.gd").new();t.add_child(gallery)
	var index:int=gallery.ids.find(M.ID)
	for rank in 4:
		gallery.select_card(index,rank)
		t.check(gallery.mirror_ending.visible and not gallery.summary.text.contains("{"),"mirror demo exposes endings and rank description "+str(rank))
		for ending in 3:
			gallery.mirror_ending.item_selected.emit(ending)
			gallery.playback.user_seek(.4)
			var state:=Demo.sample(gallery.stage)
			t.check(state.active and state.alive[0] and state.alive[1],"demo begins with two moving shooters")
			await t.get_tree().process_frame
			gallery.playback.user_seek(float(state.life)*(.7 if ending==0 else .5 if ending==1 else 1.0)+.01)
			state=Demo.sample(gallery.stage)
			t.check(state.blasts[0]>=0 and (state.moved==(ending==0)),"demo shows correct explosion and transfer ending "+str(ending))
			if ending==1:t.check(state.alive[1] and not state.alive[0],"destruction demo leaves other mirror alive")
			await t.get_tree().process_frame
	gallery.free()
