extends RefCounted
const R=preload("res://scripts/units/expansion_rules.gd")
const X=preload("res://scripts/units/progression_expansion.gd")

static func run(t) -> void:
	for rank in 4:
		t.start(MatchRules.EXTENDED)
		if t.battle.fog!=null:t.battle.fog.free();t.battle.fog=null
		BattleRequest.combat_context.card_ranks.ap_watch_posts=rank
		var hero=t.battle.spawn_unit("E1","ally",Vector2(1000,1000))
		hero.special.academy_hero="E1"
		var ability=t.card(hero,"ap_watch_posts")
		hero.add_buff("attack",20,.25,"哨位继承验证")
		hero.set_fire_stance("none")
		var plane=t.battle.spawn_unit("ORCA","enemy",Vector2(1100,1000))
		plane.logistics.air_lift=64
		plane.hp=10000;plane.max_hp=10000
		var ordinary=t.battle.spawn_unit("E1","ally",Vector2(950,900))
		t.check(not ordinary.attack_domain_valid(plane),"ordinary GI does not inherit hero anti-air")
		t.check(hero.attack_domain_valid(plane)==(rank>=2),"hero anti-air unlock is rank two "+str(rank))
		t.check(X.cast(hero,ability,Vector2.INF) and hero.is_deployed() and hero.is_prone(),"W deploys owner immediately "+str(rank))
		t.check(hero.fire_stance=="free","deployment enables automatic attacks even from hold fire")
		var posts:Array=R.state(hero).posts
		for post in posts:
			t.check(post.is_deployed() and post.is_prone() and post._fire_sequence()=="DeployedFire","sentry uses native deployed idle and firing pose")
			t.check(post.move_speed==0 and post._base_speed==0,"sentry remains immobile")
			t.check(post.attack_domain_valid(plane)==(rank>=2),"sentry anti-air matches skill rank")
			var expected:float=[.4,.5,.6,.7][rank]
			t.check(is_equal_approx(post._active_weapon().damage,hero._active_weapon().damage) and is_equal_approx(post.bonuses.attack_bonus,hero.bonuses.attack_bonus*expected),"sentry inherits deployed hero firepower at configured percentage")
			if rank>=2:
				post._refresh_target()
				t.check(post.attack_target==plane and not post.attack_ordered,"deployed sentry automatically acquires aircraft")
				var hp:float=plane.hp
				post.order_target(plane,false,false)
				post.hull_angle=post.position.direction_to(plane.position).angle()
				post._cd_timer=0
				t.check(post._try_fire_ready() and plane.hp<hp,"sentry real shot damages airborne aircraft")
		if rank>=2:
			t.check(hero.attack_target==plane and not hero.attack_ordered,"deployed hero automatically acquires aircraft")
			hero.order_target(plane,false,false)
			hero._cd_timer=0
			var hp:float=plane.hp
			t.check(hero._try_fire_ready() and plane.hp<hp,"hero real shot damages airborne aircraft")
		else:
			var ground=t.battle.spawn_unit("E2","enemy",Vector2(1100,1040))
			for defender in [hero]+posts:
				defender._refresh_target()
				t.check(defender.attack_target==ground and not defender.attack_ordered,"rank zero and one deploys auto-acquire ground enemies")
				defender.set_fire_stance("none")
				defender._refresh_target()
				t.check(defender.attack_target==null,"manual hold fire remains available after deployment")
		if rank==2:
			var codec=preload("res://scripts/save/battle_snapshot.gd").new()
			var snapshot:Dictionary=codec.capture(t.battle)
			codec.restore(t.battle,snapshot)
			hero=t.battle.units.filter(func(u):return u.special.get("academy_hero")=="E1")[0]
			posts=R.state(hero).posts
			t.check(codec.error.is_empty() and hero.is_deployed() and posts.size()==3,"save restores deployed hero and three sentries")
			for post in posts:
				t.check(post.is_deployed() and CombatMath.can_hit_air(post._active_weapon()) and is_equal_approx(post.bonuses.attack_bonus,hero.bonuses.attack_bonus*.6),"save retains sentry posture anti-air and damage")
		hero.set_deployed(false,false)
		hero.order_move(hero.position+Vector2(200,0))
		t.check(not hero.is_deployed() and hero.has_move_order,"owner can stand then move after W")
		hero.skills.clear()
		t.check(not CombatMath.can_hit_air(hero._active_weapon()),"hero without contract active has no added anti-air")
		await t.finish()
	var stage=preload("res://scripts/ui/faction_card_stage.gd").new()
	t.add_child(stage)
	for rank in 4:
		stage.configure("ap_watch_posts",0,"",rank)
		stage.sync_caster()
		t.check(stage.caster_model.actor.is_deployed() and stage.caster_model.actor._fire_sequence()=="DeployedFire","demonstration uses deployed model at every rank")
	stage.configure("ap_focus_fire",0,"",0)
	stage.sync_caster()
	t.check(stage.caster_model==null or not stage.caster_model.actor.is_deployed(),"switching demo clears sentry preview posture")
	stage.free()
	await t.get_tree().process_frame
