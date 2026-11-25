extends RefCounted
const X=preload("res://scripts/units/progression_expansion.gd")
const R=preload("res://scripts/units/expansion_rules.gd")
const Demo=preload("res://scripts/ui/dive_momentum_demo.gd")
const Cloak=preload("res://scripts/units/ra3_cloak_visual.gd")

static func run(t) -> void:
	for rank in 4:
		t.start(MatchRules.EXTENDED)
		var fog=t.battle.fog;t.battle.fog=null
		BattleRequest.combat_context.unit_talents.BEAG={"dive_momentum":rank}
		var eagle=t.battle.spawn_unit("BEAG","ally",Vector2(1200,1200))
		var target=t.battle.spawn_unit("MTNK","enemy",Vector2(1300,1200))
		var aa=t.battle.spawn_unit("FV","enemy",Vector2(1350,1200))
		eagle.logistics.air_state="flying";eagle.logistics.air_lift=1.0
		eagle.logistics.ammo=eagle.logistics.ammo_max
		eagle.attack_target=target;eagle.attack_ordered=true;eagle.hull_angle=0
		aa.attack_target=eagle;aa.attack_ordered=true
		t.check(t.battle.actor_visible_to("enemy",eagle) and aa._weapon_target_valid(eagle),"uncloaked eagle is a valid explicit AA target rank "+str(rank))
		var ammo:int=eagle.logistics.ammo
		t.check(eagle._try_fire_ready() and eagle.logistics.ammo==ammo-1,"actual bombing consumes ammo rank "+str(rank))
		var duration:float=[1.0,1.25,1.5,2.0][rank]
		t.check(is_equal_approx(float(R.state(eagle).get("dive_cloak",0)),duration) and is_equal_approx(X.speed(eagle),1.0+[.1,.15,.2,.25][rank]),"bomb grants configured cloak and existing speed rank "+str(rank))
		t.check(not t.battle.actor_visible_to("enemy",eagle) and t.battle.actor_visible_to("ally",eagle) and AlliedAbilities.concealed(eagle,"enemy"),"cloak blocks enemy visibility while owner sees eagle rank "+str(rank))
		t.check(not aa._weapon_target_valid(eagle) and is_equal_approx(Cloak.opacity(eagle),.32),"cloak blocks explicit AA lock and owner model is translucent rank "+str(rank))
		var health:float=eagle.hp;eagle.receive_hit(1,"bullet",{},aa)
		t.check(eagle.hp<health and R.state(eagle).has("dive_cloak"),"cloak is not damage immunity rank "+str(rank))
		X.Talents.tick(eagle,.25)
		X.shot(eagle,target,{})
		t.check(is_equal_approx(R.state(eagle).dive_cloak,duration-.25),"second shot cannot extend cloak rank "+str(rank))
		X.Talents.tick(eagle,duration-.24)
		t.check(not R.state(eagle).has("dive_cloak") and t.battle.actor_visible_to("enemy",eagle) and aa._weapon_target_valid(eagle) and is_equal_approx(Cloak.opacity(eagle),1.0),"expiry restores enemy targeting and opacity rank "+str(rank))
		X.shot(eagle,target,{})
		t.check(not R.state(eagle).has("dive_cloak"),"spent sortie cannot re-cloak rank "+str(rank))
		eagle.logistics.air_state="parked";eagle.logistics.ammo=0;X.Talents.tick(eagle,.01)
		t.check(R.state(eagle).get("dive_used",false),"partial ground reload does not reset eligibility rank "+str(rank))
		eagle.logistics.ammo=eagle.logistics.ammo_max;X.Talents.tick(eagle,.01)
		eagle.logistics.air_state="flying"
		X.shot(eagle,aa,{})
		t.check(is_equal_approx(R.state(eagle).dive_cloak,duration),"full landing reload enables next cloak rank "+str(rank))
		eagle.special.echo_cloaked=true
		X.Talents.tick(eagle,duration+.01)
		t.check(eagle.special.has("echo_cloaked") and not t.battle.actor_visible_to("enemy",eagle),"expiry does not erase independent cloak rank "+str(rank))
		eagle.special.erase("echo_cloaked")
		R.state(eagle).erase("dive_used")
		X.shot(eagle,eagle,{})
		t.check(not R.state(eagle).get("dive_used",false),"friendly shot cannot consume enemy bombing trigger rank "+str(rank))
		X.shot(eagle,target,{})
		eagle.logistics.air_state="parked";X.Talents.tick(eagle,.01)
		t.check(not R.state(eagle).has("dive_cloak") and not R.state(eagle).has("dive_boost"),"landing ends remaining cloak and speed rank "+str(rank))
		BattleRequest.combat_context.unit_talents.BEAG={}
		eagle.logistics.air_state="flying";R.state(eagle).erase("dive_used");X.shot(eagle,target,{})
		t.check(not R.state(eagle).has("dive_cloak"),"unselected talent has no cloak rank "+str(rank))
		t.battle.fog=fog
		await t.finish()
	await interface(t)

static func interface(t) -> void:
	var ui=load("res://scenes/meta.tscn").instantiate();t.add_child(ui)
	for rank in 4:
		ui._show_talent_demo("BEAG","dive_momentum",rank)
		var shade=ui.get_node("TalentDemo")
		var preview=shade.find_child("Preview",true,false)
		preview.playing=false
		preview.age=1.3;preview._animate()
		t.check(Demo.sample(1.3,rank).bomb and Demo.sample(1.3,rank).hidden and is_equal_approx(Cloak.opacity(preview.actor),.32),"actual demo previews falling bomb and translucent model rank "+str(rank))
		preview.age=1.21+float([1,1.25,1.5,2][rank]);preview._animate()
		t.check(not Demo.sample(preview.age,rank).hidden and is_equal_approx(Cloak.opacity(preview.actor),1.0),"demo reappears at configured duration rank "+str(rank))
		t.check(Demo.sample(6.6,rank).label.contains("落地补满"),"demo explains reload reset rank "+str(rank))
		shade.free()
	ui.free()
	await t.get_tree().process_frame
