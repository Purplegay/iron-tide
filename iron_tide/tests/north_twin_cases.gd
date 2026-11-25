extends RefCounted
const R=preload("res://scripts/units/expansion_rules.gd")
const X=preload("res://scripts/units/progression_expansion.gd")

static func run(t) -> void:
	for rank in 4:
		t.start(MatchRules.EXTENDED)
		if t.battle.fog!=null:t.battle.fog.free();t.battle.fog=null
		BattleRequest.combat_context.card_ranks.ap_north_twin=rank
		var hero=t.battle.spawn_unit("MTNK","ally",Vector2(1000,1000))
		hero.special.academy_hero="MTNK"
		var ability=t.card(hero,"ap_north_twin")
		var primary=t.battle.spawn_unit("MTNK","enemy",Vector2(1120,1000))
		var other=t.battle.spawn_unit("E2","enemy",Vector2(1070,1040))
		hero.order_target(primary,false,false)
		t.check(X.cast(hero,ability,Vector2.INF),"north summon with an existing focus rank "+str(rank))
		var twin=R.state(hero).twin
		t.check(twin.attack_target==primary and not twin.attack_ordered,"new twin inherits owner focus without a manual order")
		twin._refresh_target()
		t.check(twin.attack_target==primary,"closer enemy cannot steal twin focus")
		twin.hull_angle=twin.position.direction_to(primary.position).angle()
		twin.turret_angle=twin.hull_angle
		t.check(twin._try_fire_ready(),"twin fires its real weapon at owner focus")
		hero.order_target(other,false,false)
		X.Heroes.temporary_tick(twin,.01)
		t.check(twin.attack_target==other and not twin.attack_ordered,"owner retarget propagates on temporary-unit tick")
		t.check(not twin._weapon_target_valid(primary),"old volley cannot continue firing at a different target after owner retargets")
		twin.order_target(primary,false,false)
		X.Heroes.temporary_tick(twin,.01);twin._refresh_target()
		t.check(twin.attack_ordered and twin.attack_target==primary,"manual twin attack overrides owner focus")
		twin.order_stop();twin._refresh_target()
		t.check(twin.attack_target==other and not twin.attack_ordered,"stop clears manual override and resumes linked attacks")
		twin.set_fire_stance("none");twin._refresh_target()
		t.check(twin.attack_target==null and not twin._try_fire_ready(),"manual hold fire suppresses linked attacks")
		twin.set_fire_stance("defend")
		primary.position=Vector2(2200,2200);hero.attack_target=primary;twin._refresh_target()
		t.check(twin.attack_target==primary and not twin._weapon_target_valid(primary),"out-of-range focus is retained without granting weapon range")
		var plane=t.battle.spawn_unit("ORCA","enemy",Vector2(1120,1000));plane.logistics.air_lift=64
		hero.attack_target=plane;twin._refresh_target()
		t.check(twin.attack_target==null,"invalid air focus cannot redirect twin to another enemy")
		hero.attack_target=hero;twin._refresh_target()
		t.check(twin.attack_target==null and not twin._automatic_target_allowed(hero),"linked focus never authorizes friendly fire")
		var structure=t.battle.buildings.filter(func(b):return b.side=="enemy")[0]
		hero.attack_target=structure;twin._refresh_target()
		t.check(twin.attack_target==structure and twin._automatic_target_allowed(structure),"linked focus allows owner-designated buildings in defend stance")
		var ordinary=t.battle.spawn_unit("MTNK","ally",Vector2(950,1000))
		t.check(not ordinary._automatic_target_allowed(structure),"ordinary guard policy stays unchanged")
		hero.attack_target=other;twin.order_target(primary,false,false)
		if rank==2:
			var codec=preload("res://scripts/save/battle_snapshot.gd").new()
			var snapshot:Dictionary=codec.capture(t.battle)
			codec.restore(t.battle,snapshot)
			hero=t.battle.units.filter(func(u):return u.special.get("academy_hero")=="MTNK")[0]
			twin=R.state(hero).twin
			var manual=twin.attack_target
			twin._refresh_target()
			t.check(codec.error.is_empty() and twin.attack_ordered and twin.attack_target==manual and manual!=hero.attack_target,"save retains independent manual twin target")
			twin.order_stop();twin._refresh_target()
			t.check(twin.attack_target==hero.attack_target,"restored twin resumes owner focus after stop")
		twin.order_stop();hero.attack_target=null;twin._refresh_target()
		t.check(not twin.attack_ordered,"owner without target leaves normal guard acquisition available")
		await t.finish()
	await active_frame(t)

static func active_frame(t) -> void:
	for rank in 4:
		t.start(MatchRules.EXTENDED)
		BattleRequest.combat_context.card_ranks.ap_north_twin=rank
		var hero=t.battle.spawn_unit("MTNK","ally",Vector2(1000,1000));hero.special.academy_hero="MTNK"
		var ability=t.card(hero,"ap_north_twin")
		t.battle.select_unit(hero,false)
		t.screen.hud._rebuild_ability_bar()
		var button=t.screen.hud._ability_btns[1]
		var frame=button.get_node_or_null("ActiveSkillFrame")
		t.check(frame!=null and not frame.visible,"north W has inactive frame before summon rank "+str(rank))
		var index=UnitSkillLayout.find(hero,"ap_north_twin")
		t.check(t.battle.request_ability(index)==1,"north real HUD W summons twin")
		t.screen.hud._update_ability_live()
		t.check(frame.visible and frame.is_processing() and frame.recast_ready and not button.disabled,"north ready swap flashes during summon cooldown")
		t.check(not button.get_node("CooldownClock").visible,"ready swap does not display summon cooldown overlay")
		frame._process(.2)
		var phase:float=frame.phase
		t.screen.hud._update_ability_live()
		t.check(phase>0 and frame.phase==phase,"live HUD refresh preserves rotating highlight phase")
		t.check(frame.mouse_filter==Control.MOUSE_FILTER_IGNORE,"highlight does not intercept W clicks")
		t.check(t.battle.request_ability(index)==1,"highlighted W performs actual swap")
		t.screen.hud._update_ability_live()
		t.check(frame.visible and not frame.recast_ready and button.disabled and button.get_node("CooldownClock").visible,"short swap cooldown retains blue rotating frame and countdown")
		X.Heroes.tick(hero,R.value(hero,"ap_north_twin","swap")+.01)
		t.screen.hud._update_ability_live()
		t.check(frame.visible and frame.recast_ready and not button.disabled,"short cooldown ending restores ready highlight")
		if rank==2:
			var codec=preload("res://scripts/save/battle_snapshot.gd").new()
			codec.restore(t.battle,codec.capture(t.battle))
			hero=t.battle.units.filter(func(u):return u.special.get("academy_hero")=="MTNK")[0]
			t.battle.select_unit(hero,false);t.screen.hud._rebuild_ability_bar()
			button=t.screen.hud._ability_btns[1];frame=button.get_node("ActiveSkillFrame")
			t.check(codec.error.is_empty() and frame.visible and frame.recast_ready,"loading active twin restores W highlight from live state")
		var ordinary=t.battle.spawn_unit("MTNK","ally",Vector2(900,900))
		t.battle.select_unit(ordinary,false);t.screen.hud._rebuild_ability_bar()
		t.check(t.screen.hud._ability_btns[1].get_node_or_null("ActiveSkillFrame")==null,"selection change cannot leak hero highlight to ordinary W")
		t.battle.select_unit(hero,false);t.screen.hud._rebuild_ability_bar()
		button=t.screen.hud._ability_btns[1];frame=button.get_node("ActiveSkillFrame")
		X.Heroes.temporary_tick(R.state(hero).twin,30)
		t.screen.hud._update_ability_live()
		t.check(not frame.visible and not frame.is_processing() and frame.phase==0 and button.disabled,"expired twin clears highlight and stops animation")
		t.check(button.get_node("CooldownClock").visible,"twin ending restores summon cooldown display")
		await t.finish()
