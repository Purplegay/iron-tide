extends "res://tests/ground_control_regression.gd"
const Limit=preload("res://scripts/core/final_damage.gd")
const Expansion=preload("res://scripts/units/ra3_expansion.gd")

func make(id:String,side:String,at:Vector2):
	var actor=battle.spawn_unit(id,side,at);activate(actor)
	actor.max_hp=1000000;actor.hp=actor.max_hp
	return actor

func expected(reference:float,ratio:float,target,warhead:String) -> float:
	var amount:=reference*(CombatMath.compress_growth(ratio,3.5) if Limit.active() else ratio)
	amount=CombatMath.with_defense(amount,target.bonuses)
	return amount if warhead in ["RA3_PRISM","RA3_EXPANSION"] else Ra2Damage.quantize(amount)

func exercise(mode:String) -> void:
	for difficulty in [4,5]:
		BattleRequest.configure_skirmish(mode,{"map_size":2400,"difficulty":difficulty,"starting_funds":8000})
		screen=load("res://scenes/battle.tscn").instantiate();add_child(screen);screen.process_mode=Node.PROCESS_MODE_DISABLED;battle=screen.battle
		prefix=mode+str(difficulty)+": "
		check(Limit.active()==(mode==MatchRules.EXTENDED and difficulty==5),prefix+"new final damage rule scope")
		check(BattleRequest.growth_attack_cap()==0,prefix+"new game never precompresses source")
		BattleRequest.combat_context.bonuses.attack_bonus=1.95
		BattleRequest.combat_context.unit_bonus.E1={"attack_bonus":1.6,"defense_bonus":1.0,"skill_bonus":1.0}
		BattleRequest.combat_context.loadouts.E1={"active":[],"passive":"ps_hollow_point"}
		var shooter=make("E1","ally",Vector2(800,1000))
		var passive_factor:float=1.0+float(shooter.passive.get("value",0))*Unit.Training.card_scale(shooter)
		var raw_growth:=3.12 if mode==MatchRules.EXTENDED else 1.95
		check(is_equal_approx(shooter._base_atk,raw_growth*passive_factor),prefix+"source retains uncompressed growth and card")
		shooter.add_buff("attack",5.0,.5)
		var combined:float=raw_growth*passive_factor*1.5
		check(is_equal_approx(shooter.bonuses.attack_bonus,combined),prefix+"temporary attack buff also stays raw")
		for id in ["E1","HTNK"]:
			var victim=make(id,"enemy",Vector2(1200,1000))
			var weapon:Dictionary=shooter._active_weapon()
			var bonus:Dictionary=shooter.bonuses.duplicate(true);bonus.reference_weapon=weapon.duplicate(true)
			var reference:=CombatMath.full_damage(weapon,victim.armor,{"veteran_attack":bonus.get("veteran_attack",1.0)},null,victim.ra2_armor,0.0,victim)
			var before:float=victim.hp
			victim.receive_hit(CombatMath.full_damage(weapon,victim.armor,bonus,null,victim.ra2_armor,0.0,victim),"bullet",bonus,shooter,weapon.ra2_warhead)
			check(is_equal_approx(before-victim.hp,expected(reference,combined,victim,weapon.ra2_warhead)),prefix+id+" combined final damage compressed once",before-victim.hp)
			for ratio in [1.0,2.0,3.12,5.0,12.48]:
				bonus.attack_bonus=ratio
				before=victim.hp
				victim.receive_hit(reference*ratio,"bullet",bonus,shooter,weapon.ra2_warhead)
				check(is_equal_approx(before-victim.hp,expected(reference,ratio,victim,weapon.ra2_warhead)),prefix+id+" final ratio "+str(ratio))
			# Contact adds its damage INSIDE receive_hit, after the projectile payload.
			shooter.passive={"id":"ps_contact","value":.5}
			shooter.special.contact_target=victim;shooter.special.contact_left=4.0
			bonus.attack_bonus=4.0;before=victim.hp
			victim.receive_hit(reference*4.0,"bullet",bonus,shooter,weapon.ra2_warhead)
			check(is_equal_approx(before-victim.hp,expected(reference,6.0,victim,weapon.ra2_warhead)),prefix+"late contact passive is inside final compression")
			shooter.passive={};shooter.special.erase("contact_left")
			victim.position=Vector2(2300,2300)
		var factory=battle._place_building("GAPILE","enemy",Vector2(1200,1400),true)
		factory.hp=1000000;factory.max_hp=1000000
		var weapon:Dictionary=shooter._active_weapon()
		var bonus:Dictionary=shooter.bonuses.duplicate();bonus.reference_weapon=weapon.duplicate(true)
		var reference:=CombatMath.full_damage(weapon,factory.armor,{"veteran_attack":1.0},null,factory.ra2_armor,0.0,factory)
		var before:float=factory.hp
		factory.receive_hit(reference*combined,"bullet",bonus,shooter,weapon.ra2_warhead)
		check(is_equal_approx(before-factory.hp,expected(reference,combined,factory,weapon.ra2_warhead)),prefix+"building receives same final rule")
		# RA3 impact-time phase/Heat/Twin amount is compared to its native pulse.
		var victim=make("HTNK","enemy",Vector2(1500,1800))
		var shot:=Projectile.new();shot.owner_side="ally";shot.attacker_bonus={"attack_bonus":4.0,"veteran_attack":1.25,"damage_owner_side":"ally"};shot.target=victim
		shot.splinters={"phase_factor":1.5};battle.projectiles_root.add_child(shot)
		reference=Expansion.raw_damage(100,"CANNON",victim)*1.25;before=victim.hp
		Expansion.hit(shot,victim,100,"CANNON")
		check(is_equal_approx(before-victim.hp,expected(reference,6.0,victim,"RA3_EXPANSION")),prefix+"RA3 phase buff included; rank preserved with dead source")
		shot.splinters={};before=victim.hp
		Expansion.hit(shot,victim,200,"CANNON",100)
		check(is_equal_approx(before-victim.hp,expected(reference,8.0,victim,"RA3_EXPANSION")),prefix+"RA3 Heat Split or Twin impact amount included")
		shot.free()
		if mode==MatchRules.EXTENDED:
			battle.fog=null
			BattleRequest.combat_context.card_ranks.ap_tesla_chain=3
			BattleRequest.combat_context.loadouts.SHK={"active":["ap_tesla_chain"],"passive":""}
			var tesla=make("SHK","ally",Vector2(400,1800));tesla.bonuses.attack_bonus=4.0;tesla._base_atk=4.0
			var primary=make("HTNK","enemy",Vector2(500,1800))
			var secondary=make("HTNK","enemy",Vector2(520,1800))
			var index:=UnitSkillLayout.index(tesla,1)
			check(index>=0 and tesla.use_ability(index),prefix+"real chain card casts")
			weapon=tesla._active_weapon()
			reference=CombatMath.full_damage(weapon,primary.armor,{"veteran_attack":1.0},null,primary.ra2_armor,0,primary)
			tesla._fire_shot(primary)
			check(is_equal_approx(primary.max_hp-primary.hp,expected(reference,5.4,primary,weapon.ra2_warhead)),prefix+"chain primary bonus inside final compression")
			check(is_equal_approx(secondary.max_hp-secondary.hp,expected(reference,5.4,secondary,weapon.ra2_warhead)),prefix+"chain secondary bonus inside final compression")
			var flak=make("FLAKT","ally",Vector2(800,1900));flak.passive={"id":"ps_barrage","value":.5}
			var air=make("ORCA","enemy",Vector2(900,1900));air.logistics.air_lift=20.0
			flak.special.barrage_target=air;flak.special.barrage_count=2
			bonus=Limit.packet({"attack_bonus":4.0,"damage_owner_side":"ally"},100.0)
			before=air.hp;air.receive_hit(400,"flak",bonus,flak,"RA3_EXPANSION")
			check(is_equal_approx(before-air.hp,expected(100,6,air,"RA3_EXPANSION")),prefix+"third-hit barrage passive compressed at receiver")
		# Artillery keeps each victim's splash distance and armor in its reference.
		var tank=make("HTNK","ally",Vector2(1600,1700));tank.bonuses.attack_bonus=6.0
		var shell:=Projectile.new();weapon=tank._active_weapon()
		shell.setup(tank.position,victim,weapon,CombatMath.full_damage(weapon,victim.armor,tank.bonuses,null,victim.ra2_armor,0,victim),tank.bonuses,"ally",tank)
		battle.projectiles_root.add_child(shell)
		for distance in [0.0,5.0,10.0]:
			var packet:=shell.hit_modifiers(victim,distance)
			reference=CombatMath.full_damage(weapon,victim.armor,{"veteran_attack":tank.bonuses.get("veteran_attack",1.0)},null,victim.ra2_armor,distance,victim)
			before=victim.hp
			victim.receive_hit(reference*6,"shell",packet,shell,weapon.ra2_warhead)
			check(is_equal_approx(before-victim.hp,expected(reference,6,victim,weapon.ra2_warhead)),prefix+"splash reference by distance "+str(distance))
		reference=CombatMath.full_damage(weapon,victim.armor,{"veteran_attack":tank.bonuses.get("veteran_attack",1.0)},null,victim.ra2_armor,0.0,victim)
		before=victim.hp;shell._explode()
		check(is_equal_approx(before-victim.hp,expected(reference,6,victim,weapon.ra2_warhead)),prefix+"real projectile detonation applies limiter only once",before-victim.hp)
		if mode==MatchRules.EXTENDED:
			MetaProgress.academy.get_or_add("hero_builds",{}).HTNK=100
			BattleRequest.combat_context.unit_bonus.HTNK={"attack_bonus":1.6,"defense_bonus":1.0,"skill_bonus":1.0}
			BattleRequest.combat_context.hero_training.HTNK={"firepower":150,"health":0}
			BattleRequest.combat_context.hero_loadouts.HTNK={"active":[],"passive":""}
			battle.allied_state.get_or_add("named_heroes",{}).erase("HTNK")
			var hero=make("HTNK","ally",Vector2(1800,1800))
			MetaProgress.Academy.promote(MetaProgress,battle,"HTNK",hero)
			check(is_equal_approx(hero._base_atk,5.46),prefix+"hero retains full training before hit")
			hero.add_buff("attack",5,.5);weapon=hero._active_weapon()
			bonus=hero.bonuses.duplicate();bonus.reference_weapon=weapon.duplicate(true)
			reference=CombatMath.full_damage(weapon,victim.armor,{"veteran_attack":bonus.get("veteran_attack",1.0)},null,victim.ra2_armor,0,victim)
			before=victim.hp;victim.receive_hit(reference*8.19,"shell",bonus,hero,weapon.ra2_warhead)
			check(is_equal_approx(before-victim.hp,expected(reference,8.19,victim,weapon.ra2_warhead)),prefix+"hero training and skill combined at final damage")
		var codec=BattleSaves.Snapshot.new();var saved:Dictionary=codec.capture(battle)
		check(codec.error.is_empty(),prefix+"reference packets serialize")
		BattleRequest.combat_context=saved.context.combat_context.duplicate(true)
		codec.restore(battle,saved)
		check(codec.error.is_empty() and Limit.active()==(mode==MatchRules.EXTENDED and difficulty==5),prefix+"final rule survives snapshot restore")
		BattleRequest.combat_context.erase("final_damage_cap")
		check(not Limit.active(),prefix+"old contexts do not silently gain final compression")
		await finish()
