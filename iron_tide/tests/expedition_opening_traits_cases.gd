extends RefCounted
const Rules=preload("res://scripts/expedition/rules.gd")
const Army=preload("res://scripts/expedition/army.gd")
const Catalog=preload("res://scripts/expedition/catalog.gd")

static func run(t) -> void:
	for key:String in Army.TRAITS:
		t.check("达到 3 层" in Catalog.description({"kind":"trait_buff","id":key}) and not "3 层追加" in Army.trait_detail(key,2) and "3 层追加" in Army.trait_detail(key,3),"early build description and unlock boundary "+key)
	for count in [2,3,6,9]:
		for key:String in Army.TRAITS:
			t.set_stacks(key,count);t.build_time(500)
			var id:String={"infantry":"E1","vehicle":"MTNK","air":"ORCA","naval":"DEST","fortify":"GGI","mobile":"MTNK","support":"E1","energy":"SREF","artillery":"HTNK","special":"GHOST"}[key]
			var unit=t.actor(id)
			var target=t.hit_target()
			var before:float=unit.hp
			var enabled:bool=count>=3
			var prefix:="early "+key+" layer "+str(count)
			match key:
				"infantry":
					Rules.defeated(t.battle,target,unit)
					t.check(is_equal_approx(unit.hp-before,unit.max_hp*(0.04 if enabled else 0)),prefix+" kill dressing")
					before=unit.hp;Rules.defeated(t.battle,target,unit)
					t.check(is_equal_approx(unit.hp,before),prefix+" same-tick kills cannot multiply healing")
					t.build_time(506);Rules.defeated(t.battle,unit,unit)
					t.check(is_equal_approx(unit.hp,before),prefix+" allied death never grants dressing")
					Rules.defeated(t.battle,target,unit)
					t.check(is_equal_approx(unit.hp-before,unit.max_hp*(0.05+(0.04 if enabled else 0))),prefix+" dressing resumes after cooldown and stacks with existing casualty rally")
				"vehicle":
					unit.velocity=Vector2(40,0);Rules.tick_unit(unit,2,false)
					t.check(is_equal_approx(unit.hp,before),prefix+" movement repair waits two full seconds")
					Rules.tick_unit(unit,1,false)
					t.check(is_equal_approx(unit.hp-before,unit.max_hp*(0.005 if enabled else 0)),prefix+" movement repair rate")
					before=unit.hp;unit.velocity=Vector2.ZERO;Rules.tick_unit(unit,1,false)
					t.check(is_equal_approx(unit.hp,before),prefix+" stopping ends moving repair")
					unit.hp=unit.max_hp*0.499;unit.velocity=Vector2(40,0);Rules.tick_unit(unit,100,false)
					t.check(is_equal_approx(unit.hp,unit.max_hp*(0.5 if enabled else 0.499)),prefix+" repair cannot exceed half health")
				"air":
					unit.logistics.ammo_max=4;unit.logistics.ammo=4;unit.special.expedition_ammo=3;Rules.tick_unit(unit,1,false)
					t.check(is_equal_approx(unit.special.get("expedition_shield",0),unit.max_hp*(0.20 if count==9 else 0.05 if enabled else 0)),prefix+" reload shield upgrades at nine")
					unit.special.expedition_shield=0.0;Rules.tick_unit(unit,1,false)
					t.check(is_zero_approx(unit.special.expedition_shield),prefix+" full ammo alone cannot regenerate shield")
				"naval":
					unit.special.expedition_last_hit=493.0;Rules.tick_unit(unit,0,false)
					t.check(not unit.special.has("expedition_shield"),prefix+" naval shield requires eight seconds without damage")
					t.build_time(501);unit.attack_target=target;Rules.tick_unit(unit,0,false)
					t.check(not unit.special.has("expedition_shield"),prefix+" naval shield requires disengagement")
					unit.attack_target=null;Rules.tick_unit(unit,0,false)
					t.check(is_equal_approx(unit.special.get("expedition_shield",0),unit.max_hp*(0.08 if enabled else 0)),prefix+" disengagement grants reserve shield")
					unit.special.expedition_shield=0.0;Rules.tick_unit(unit,0,false)
					t.check(is_zero_approx(unit.special.expedition_shield),prefix+" naval shield cooldown")
					t.build_time(521);Rules.tick_unit(unit,0,false)
					t.check(is_equal_approx(unit.special.expedition_shield,unit.max_hp*(0.08 if enabled else 0)),prefix+" naval shield returns after twenty seconds")
				"fortify":
					unit.special.expedition_still=1.9;Rules.impact(target,unit,100,"bullet")
					t.check(not target.special.has("expedition_cover_until"),prefix+" cover fire waits for stationary stance")
					unit.special.expedition_still=2.0;Rules.impact(target,unit,100,"bullet")
					t.check(is_equal_approx(Rules.impact(unit,target,100,"bullet"),90 if enabled else 100),prefix+" cover fire reduces enemy direct damage")
					t.check(is_equal_approx(Rules.impact(unit,target,100,"radiation"),100),prefix+" cover fire excludes indirect damage")
					t.build_time(502);Rules.impact(target,unit,100,"bullet")
					t.check(is_equal_approx(Rules.impact(unit,target,100,"bullet"),100),prefix+" cover expires before six-second cooldown")
					t.build_time(506);Rules.impact(target,unit,100,"bullet");target.special.expedition_suppressed_until=510.0
					t.check(is_equal_approx(Rules.impact(unit,target,100,"bullet"),80),prefix+" stronger suppression replaces rather than multiplies cover")
				"mobile":
					unit.special.expedition_distance=165.0;Rules.impact(target,unit,100,"bullet")
					t.check(is_equal_approx(unit.special.get("expedition_shield",0),unit.max_hp*(0.05 if enabled else 0)),prefix+" march strike shields")
					unit.special.expedition_shield=0.0;unit.special.expedition_distance=165.0;Rules.impact(target,unit,100,"bullet")
					t.check(is_zero_approx(unit.special.expedition_shield),prefix+" march shield shares strike cooldown")
					t.build_time(508);unit.special.expedition_shield=unit.max_hp*0.20;Rules.impact(target,unit,100,"bullet")
					t.check(is_equal_approx(unit.special.expedition_shield,unit.max_hp*0.20),prefix+" march shield preserves stronger protection")
				"support":
					Rules.tick_unit(unit,5,false)
					t.check(is_equal_approx(unit.hp,before),prefix+" first aid waits for medical pulse")
					Rules.tick_unit(unit,5,true)
					t.check(is_equal_approx(unit.hp-before,unit.max_hp*(0.02 if count>=6 else 0.01 if enabled else 0)),prefix+" first aid upgrades into full medical care")
					unit.hp=unit.max_hp*0.499;Rules.tick_unit(unit,5,true)
					t.check(is_equal_approx(unit.hp,unit.max_hp*(0.519 if count>=6 else 0.5 if enabled else 0.499)),prefix+" early first aid stops at half health")
				"energy":
					target.special.expedition_mark_type="E1";target.special.expedition_mark_time=500.0;Rules.impact(target,unit,100,"bullet")
					t.check(is_equal_approx(unit.hp-before,unit.max_hp*(0.03 if enabled else 0)),prefix+" mixed-unit cooperation heals energy attacker")
					before=unit.hp;target.special.expedition_mark_type="E1";Rules.impact(target,unit,100,"bullet")
					t.check(is_equal_approx(unit.hp,before),prefix+" shared cooperation cooldown prevents healing spam")
					t.build_time(504);target.special.expedition_mark_type=unit.unit_id;Rules.impact(target,unit,100,"bullet")
					t.check(is_equal_approx(unit.hp,before),prefix+" same type cannot trigger cooperation healing")
				"artillery":
					target.special.expedition_first_mark=499.0;Rules.impact(target,unit,100,"bullet")
					t.check(not target.special.has("expedition_exposed_until"),prefix+" exposure requires two-second mark")
					target.special.expedition_first_mark=498.0;Rules.impact(target,unit,100,"bullet")
					var ally=t.actor("E1")
					t.check(is_equal_approx(Rules.impact(target,ally,100,"bullet"),110 if enabled else 100),prefix+" marked strike exposes target to other units")
					t.check(is_equal_approx(Rules.impact(target,ally,100,"radiation"),100),prefix+" exposure excludes indirect damage")
					t.build_time(503);Rules.impact(target,unit,100,"bullet")
					t.check(is_equal_approx(Rules.impact(target,ally,100,"bullet"),100),prefix+" exposure expires before shared marking cooldown")
					t.build_time(506);Rules.impact(target,unit,100,"bullet");target.special.expedition_overload_until=510.0
					t.check(is_equal_approx(Rules.impact(target,ally,100,"bullet"),115),prefix+" stronger overload replaces exposure")
					ally.queue_free()
				"special":
					Rules.impact(target,unit,100,"bullet")
					t.check(not unit.special.has("expedition_shield"),prefix+" ordinary healthy target gives no breach cover")
					target.special.expedition_objective="probe";Rules.impact(target,unit,100,"bullet")
					t.check(is_equal_approx(unit.special.get("expedition_shield",0),unit.max_hp*(0.05 if enabled else 0)),prefix+" objective strike grants breach cover")
					unit.special.expedition_shield=0.0;Rules.impact(target,unit,100,"bullet")
					t.check(is_zero_approx(unit.special.expedition_shield),prefix+" breach cover cooldown")
					Rules.defeated(t.battle,target,unit);Rules.impact(target,unit,100,"bullet")
					t.check(is_equal_approx(unit.special.expedition_shield,unit.max_hp*(0.05 if count==9 else 0)),prefix+" only ninth layer resets breach cover on kill")
			unit.queue_free();target.queue_free()
		await t.get_tree().process_frame
	# Actual death dispatch must invoke the early effect, not just the rule helper.
	t.set_stacks("infantry",3);t.build_time(900)
	var killer=t.actor("E1")
	var victim=t.battle.spawn_unit("E1","enemy",t.battle.player_start()+Vector2(700,400))
	victim.hp=1.0
	var health:float=killer.hp
	victim.receive_hit(10000,"bullet",{},killer)
	t.check(killer.hp>health and killer.special.get("expedition_milestone_infantry_dressing",0)==906.0,"real lethal hit dispatches third-layer dressing")
	killer.special.opening_save_probe=true
	# Keep the actor for the suite's existing real checkpoint / restore flow.
