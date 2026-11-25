extends RefCounted
const Army=preload("res://scripts/expedition/army.gd")
const Talents=preload("res://scripts/expedition/talents.gd")
const Market=preload("res://scripts/expedition/market.gd")
const Repack=preload("res://scripts/world/construction_repack.gd")

static func run(t) -> void:
	MetaProgress.unit_talents={"CLEG":{"chrono_bookmark":1,"native_chrono_time":2}}
	var permanent:Dictionary=MetaProgress.unit_talents.duplicate(true)
	t.new_ready("美国",16)
	var next:Dictionary=Expedition.state.duplicate(true)
	Army.add_unit(next,"CLEG",1)
	Expedition.grant(next,{"kind":"special_unit","id":"CLEG","tier":2,"native_rank":1,"count":1})
	Expedition.commit(next)
	t.check(Talents.rank(next,"CLEG","chrono_bookmark")==1 and Talents.rank(next,"CLEG","native_chrono_time")==2,"two outside talent ranks are inherited independently")
	t.check(Expedition.service("native","CLEG") and Talents.rank(Expedition.state,"CLEG","chrono_bookmark")==2 and Talents.rank(Expedition.state,"CLEG","native_chrono_time")==3,"one purchase raises both talents once")
	t.check(Expedition.service("native","CLEG") and Talents.minimum(Expedition.state,"CLEG")==3,"second purchase finishes lower talent without exceeding cap")
	var saved:Dictionary=Expedition.state.duplicate(true)
	t.check(not Expedition.service("native","CLEG") and not Expedition.service("blueprint","CLEG") and Expedition.state==saved,"full talents and removed blueprint cannot charge")
	for item:Dictionary in Market.native_pool(saved):t.check(item.id!="CLEG","fully upgraded twin talents disappear from offers")
	t.check(Expedition.load_run() and Expedition.state==saved,"shared talent upgrades survive reload")
	t.check(Expedition.launch(0),"shared talents actual battle launches")
	if t.instantiate_battle():
		var normal=t.battle.spawn_unit("CLEG","ally",t.battle.player_start()+Vector2(400,200))
		var special
		for unit in t.battle.units:
			if unit.unit_id=="CLEG" and unit.special.has("expedition_variant"):special=unit
		t.check(special!=null and is_equal_approx(Unit.Training.scale(normal),2.2) and is_equal_approx(Unit.Training.scale(special),2.2),"ordinary newly spawned and special units consume same native rank")
		t.check(BattleRequest.has_unit_talent("CLEG","chrono_bookmark","ally") and MetaProgress.talent_rank("CLEG","chrono_bookmark",BattleRequest.combat_context.unit_talents)==3 and not BattleRequest.talent_upgrade("CLEG","chrono_bookmark","ally").is_empty(),"second non-native talent reaches its real battle consumer")
		t.check(Expedition.checkpoint(t.battle),"save battle with shared talents")
		await t.finish()
		t.check(Expedition.load_run() and Expedition.prepare_battle(),"resume shared talents checkpoint")
		if t.instantiate_battle():t.check(MetaProgress.talent_rank("CLEG","chrono_bookmark",BattleRequest.combat_context.unit_talents)==3,"checkpoint retains both talents")
	await t.finish()
	t.check(MetaProgress.unit_talents==permanent,"expedition talent upgrades never write outside ranks")
	MetaProgress.unit_talents={}
	t.new_ready("苏俄",1)
	next=Expedition.state.duplicate(true);Army.add_unit(next,"DESO",1);Expedition.commit(next)
	for level in range(1,4):
		t.check(Expedition.service("native","DESO") and Talents.rank(Expedition.state,"DESO","deso_expansion")==level and Talents.rank(Expedition.state,"DESO","native_radiation")==level,"three purchases raise both initially unowned talents "+str(level))
	for country:String in ["美国","苏俄"]:
		t.new_ready(country,9)
		t.check(Expedition.launch(0),"defense repack fixture launches "+country)
		if not t.instantiate_battle():await t.finish();continue
		var tasks=t.screen.expedition_runtime.tasks
		var yard=tasks.actor("defense")
		yard._buildup_play=-1
		t.check(Repack.execute(t.battle,yard),"real defense yard repacks "+country)
		var mcv=tasks.actor("defense")
		t.check(mcv is Unit and not mcv.deploy_building_id().is_empty(),"objective transfers to live MCV "+country)
		tasks.tick(1.0);t.battle._check_end()
		t.check(not t.battle.ended and Expedition.state.phase=="battle","packing defense base never causes defeat "+country)
		t.check(Expedition.checkpoint(t.battle),"mobile defense objective saves "+country)
		await t.finish()
		t.check(Expedition.load_run() and Expedition.prepare_battle(),"restore packed defense objective "+country)
		if not t.instantiate_battle():await t.finish();continue
		tasks=t.screen.expedition_runtime.tasks;mcv=tasks.actor("defense")
		t.check(mcv is Unit,"restored mission still targets MCV "+country)
		mcv.special.mcv_repack_left=0.0
		# The authored base can have overlapping foundations; select a legal nearby relocation.
		var origin:Vector2=mcv.position
		for offset:Vector2 in [Vector2.ZERO,Vector2(400,0),Vector2(0,400),Vector2(-400,0),Vector2(0,-400)]:
			mcv.position=origin+offset
			if t.battle.construction_deploy_check(mcv).ok:break
		var deploy_check:Dictionary=t.battle.construction_deploy_check(mcv)
		t.check(t.battle.deploy_construction_vehicle(mcv),"defense MCV redeploys "+country,deploy_check)
		yard=tasks.actor("defense")
		t.check(yard is Building,"objective transfers back to building "+country)
		if not yard is Building:await t.finish();continue
		tasks.tick(1.0)
		t.check(not t.battle.ended,"redeploy also preserves defense progress "+country)
		await t.get_tree().process_frame
		# Restored battles enter paused; resume before issuing a second player command.
		t.get_tree().paused=false;t.battle.paused=false
		yard._buildup_play=-1
		var repack_check:Dictionary=Repack.check(t.battle,yard)
		t.check(Repack.execute(t.battle,yard),"repeated repack remains valid "+country,repack_check)
		if not repack_check.ok:await t.finish();continue
		mcv=tasks.actor("defense");mcv._die();tasks.tick(1.0)
		t.check(t.battle.ended and Expedition.state.phase=="failed","actual destruction of defense MCV still loses "+country)
		await t.finish()
