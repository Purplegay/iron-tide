extends RefCounted
const Auto=preload("res://scripts/units/auto_w.gd")
const R=preload("res://scripts/units/expansion_rules.gd")

static func hero(t,id:String,card:String):
	var unit=t.make(id)
	unit.special.academy_hero=id
	unit.skills.clear()
	var ability:=Ability.new();ability.setup(GameData.get_skill(card));unit.skills.append(ability)
	return unit

static func run(t) -> void:
	# Earlier emplacement cases free their building directly; remove its stale path footprint.
	t.battle._refresh_pathing()
	for card in MetaProgress.skill_draw_candidates():
		if card.type=="active":t.check(Auto.supported(card.id) or Auto.MANUAL_ONLY.has(card.id),"every current pool W has explicit automatic or manual policy "+card.id)
	for entry in MetaProgress.Academy.ContractPool.entries():
		for id in entry.cards:
			if GameData.get_skill(id).type=="active":t.check(Auto.supported(id) or Auto.MANUAL_ONLY.has(id),"every hero reward W has explicit policy "+id)
	for id in Auto.Expansion.SUPPORTED:t.check(not Auto.hint(id).is_empty(),"new Auto W exposes trigger explanation "+id)
	var u=t.make("MTNK","ap_tracer_mark")
	var enemy=t.make("E2","","enemy",u.position+Vector2(150,0));t.arm(u,enemy)
	t.check(not Auto.evaluate(u),"tracer rejects infantry target")
	enemy=t.make("HTNK","","enemy",u.position+Vector2(160,0));t.arm(u,enemy)
	R.state(enemy).mark={"side":"ally","left":3.0,"charges":2}
	t.check(not Auto.evaluate(u),"tracer avoids refreshing unspent allied mark")
	R.state(enemy).erase("mark")
	for gate in ["cooldown","paused","casting","hidden","off"]:
		match gate:
			"cooldown":u.skills[UnitSkillLayout.index(u,1)].cd_left=5
			"paused":t.battle.paused=true
			"casting":t.battle.cast_slot=1
			"hidden":enemy.special.echo_cloaked=true
			"off":t.battle.allied_state.auto_w_preferences={"MTNK":false}
		t.check(not Auto.evaluate(u),"new card respects shared guard "+gate)
		u.skills[UnitSkillLayout.index(u,1)].cd_left=0;t.battle.paused=false;t.battle.cast_slot=-1;enemy.special.erase("echo_cloaked");t.battle.allied_state.auto_w_preferences={}
	t.check(Auto.evaluate(u) and R.state(u).has("tracer_arm"),"tracer arms before eligible vehicle shot")
	u.skills[UnitSkillLayout.index(u,1)].cd_left=0
	t.check(not Auto.evaluate(u),"pending tracer does not consume again")
	t.clear_actors()
	u=t.make("SCHP","ap_seismic_anchor");enemy=t.make("HTNK","","enemy",u.position+Vector2(100,0));t.arm(u,enemy)
	t.check(not Auto.evaluate(u),"seismic never automatically deploys helicopter")
	t.check(u.set_deployed(true,false),"seismic fixture starts deployment")
	t.check(not Auto.evaluate(u),"seismic waits until landing and deployment animation finish")
	u.logistics.air_lift=0
	u.logistics.SiegeChopper.tick(u,u.logistics.SiegeChopper.duration()+.01)
	enemy.position=u.position+Vector2(2000,0);t.battle.remove_meta("auto_w_contacts")
	t.check(not Auto.evaluate(u),"seismic rejects out-of-range point")
	enemy.position=u.position+Vector2(100,0);t.battle.remove_meta("auto_w_contacts")
	t.check(Auto.evaluate(u) and t.battle.allied_state.expansion_zones.back().left==11.0,"seismic passes real target point and creates warning plus ten-second field",[Auto.enabled(u),u._deployed,u.attack_target,u.attack_range,u.fire_stance,u.attack_ordered,u.power_disabled_reason()])
	t.battle.allied_state.expansion_zones=[];t.clear_actors()
	u=t.make("ZEP","ap_bomb_nests");u.fire_stance="free"
	t.check(not Auto.evaluate(u),"airdrop does not waste nests without ground enemies")
	enemy=t.make("HTNK","","enemy",u.position+Vector2(25,0))
	u.logistics.air_lift=0
	t.check(not Auto.evaluate(u),"airdrop requires flight")
	u.logistics.air_lift=1.0
	t.check(Auto.evaluate(u) and R.state(u).has("nests"),"airdrop triggers over nearby ground enemy")
	t.clear_actors()
	u=t.make("MGTK","ap_mirror_fork");enemy=t.make("HTNK","","enemy",u.position+Vector2(150,0));t.arm(u,enemy)
	t.check(Auto.evaluate(u) and R.state(u).mirrors.size()==2,"mirror auto first cast summons both")
	var origin:Vector2=u.position
	t.check(not Auto.evaluate(u) and u.position==origin and R.state(u).mirrors.size()==2,"mirror auto never consumes second W or teleports")
	t.clear_actors()
	for row in [["E1","ap_watch_posts","posts"],["MTNK","ap_north_twin","twin"],["HTNK","ap_spine_crown","crown"]]:
		u=hero(t,row[0],row[1])
		t.check(not Auto.evaluate(u),"hero card idle retains cooldown "+row[1])
		enemy=t.make("HTNK","","enemy",u.position+Vector2(150,0));t.arm(u,enemy)
		if row[1]=="ap_spine_crown":
			u.hp=u.max_hp*.5
			t.check(not Auto.evaluate(u),"low health crown preserves defensive armor")
			u.hp=u.max_hp
		t.check(Auto.evaluate(u) and R.state(u).has(row[2]),"hero first cast enters actual effect "+row[1])
		u.skills[UnitSkillLayout.index(u,1)].cd_left=0
		origin=u.position
		t.check(not Auto.evaluate(u) and u.position==origin,"active hero effect not replaced or swapped "+row[1])
		t.clear_actors()
	t.battle.water_rects=[Rect2(600,600,1300,1300)];t.battle.path_service.set_water(t.battle.water_rects)
	u=t.make("SUB","ap_tidal_decoy");enemy=t.make("DEST","","enemy",u.position+Vector2(50,0))
	t.check(not Auto.evaluate(u),"tidal decoy waits for damage")
	Auto.record_hit(u,1,enemy)
	t.check(Auto.evaluate(u) and R.state(u).has("dive"),"hurt submarine uses real water decoy")
	t.clear_actors()
	u=t.make("SQD","ap_ink_mine");u.fire_stance="free";enemy=t.make("DEST","","enemy",u.position+Vector2(30,0))
	u.special.squid=enemy
	t.check(not Auto.evaluate(u),"ink mine blocked during grapple")
	u.special.erase("squid")
	t.check(Auto.evaluate(u) and t.battle.units.any(func(a):return a.special.get("expansion_temporary",{}).get("kind")=="ink"),"ink mine casts near visible surface enemy")
	t.clear_actors();t.battle.water_rects=[];t.battle.path_service.set_water([])
