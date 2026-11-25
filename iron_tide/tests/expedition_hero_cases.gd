extends RefCounted
const Catalog=preload("res://scripts/expedition/catalog.gd")
const Heroes=preload("res://scripts/expedition/heroes.gd")
var t

func run(test) -> void:
	t=test
	check_offers()
	for country:String in ["美国","苏俄"]:await check_lifecycle(country)
	check_legacy()
	await check_factory_boundary()

func check_offers() -> void:
	MetaProgress.academy.hero_builds={}
	t.check(Expedition.start("美国","",350),"hero offers need no permanent hero unlock")
	var sample:Dictionary=Expedition.state.duplicate(true)
	sample.stage=2
	var hits:=0
	var seen:Array=[]
	var valid:=true
	for seed_value in 512:
		sample.seed=seed_value
		var offers:=Catalog.offer(sample,"unit","victory_unit")
		valid=valid and offers==Catalog.offer(sample,"unit","victory_unit") and offers.size()==3
		var hero_count:=0
		for item:Dictionary in offers:
			if item.kind!="hero":continue
			hero_count+=1;hits+=1
			valid=valid and item.id in ["E1","MTNK"]
			if item.id not in seen:seen.append(item.id)
		valid=valid and hero_count<=1
	t.check(valid and seen.size()==2,"stable three-choice rewards offer at most one same-faction hero and reach both heroes")
	t.check(hits>85 and hits<175,"fixed seed sample exercises both 25 percent hero branch and ordinary rewards",str(hits))
	sample.heroes=["E1","MTNK"];sample.wounded_heroes=["E1"]
	var exhausted:=true
	for seed_value in 64:
		sample.seed=seed_value
		for item:Dictionary in Catalog.offer(sample,"unit","victory_unit"):
			if item.kind=="hero":exhausted=false
	t.check(exhausted,"owned and wounded heroes never reappear as duplicate rewards")
	sample.heroes=[];sample.wounded_heroes=[];sample.stage=1
	var initial_safe:=true
	for seed_value in 64:
		sample.seed=seed_value
		for item:Dictionary in Catalog.offer(sample,"unit","victory_unit")+Catalog.shop(sample,seed_value)+Catalog.offer(sample,"buff","initial"):
			if item.kind=="hero":initial_safe=false
	t.check(initial_safe,"hero reward does not leak into opening buffs or ordinary shop inventory")
	t.check(not Heroes.recruit(sample,"E2") and Heroes.recruit(sample,"E1") and not Heroes.recruit(sample,"E1"),"recruit rejects foreign heroes and duplicates")
	sample.heroes=["E1","E1"]
	t.check(not Expedition.valid(sample),"invalid duplicate hero roster rejected")
	sample.heroes=["E1"];sample.wounded_heroes=["MTNK"]
	t.check(not Expedition.valid(sample),"injury for unowned hero rejected")

func seed_reward(id:String) -> void:
	var next:Dictionary=Expedition.state.duplicate(true)
	var preview:=next.duplicate(true)
	preview.stage=int(next.stage)+1
	var found:=false
	for seed_value in 1024:
		preview.seed=seed_value
		for item:Dictionary in Catalog.offer(preview,"unit","victory_unit"):
			if item.kind=="hero" and item.id==id:
				next.seed=seed_value;found=true;break
		if found:break
	t.check(found and Expedition.commit(next),"deterministic upcoming victory prepares hero "+id)

func launch() -> void:
	t.check(Expedition.launch(0),"hero lifecycle launches real battle")
	t.screen=load("res://scenes/battle.tscn").instantiate();t.add_child(t.screen)
	t.screen.process_mode=Node.PROCESS_MODE_DISABLED;t.battle=t.screen.battle
	t.check(t.screen.expedition_runtime.error.is_empty(),"hero lifecycle deploys real army",t.screen.expedition_runtime.error)

func victory() -> void:
	for building in t.battle.buildings.duplicate():
		if t.battle.actor_alive(building) and building.side=="enemy":building._die()
	for unit in t.battle.units.duplicate():
		if t.battle.actor_alive(unit) and unit.side=="enemy":unit._die()
	t.battle._check_end()
	t.check(t.battle.ended and Expedition.state.phase=="reward","real victory produces reward phase for recruitment")

func claim_hero(id:String) -> void:
	var offers:Array=Expedition.state.offers.duplicate(true)
	t.check(Expedition.load_run() and Expedition.state.offers==offers,"hero candidate survives disk reload without reroll")
	var index:=-1
	for i in Expedition.state.offers.size():
		if Expedition.state.offers[i].kind=="hero" and Expedition.state.offers[i].id==id:index=i;break
	t.check(index>=0,"real victory includes requested deterministic hero "+id)
	if index<0:return
	var frozen:Dictionary=Expedition.state.frozen.duplicate(true)
	t.check(Expedition.choose(index) and id in Heroes.owned(Expedition.state),"selecting reward recruits hero "+id)
	t.check(not Expedition.state.reward_unit and Expedition.state.reward_buff,"hero consumes unit choice and preserves separate Buff reward")
	t.check(Expedition.state.frozen==frozen and MetaProgress.academy.hero_builds.is_empty(),"recruitment preserves frozen profile and permanent hero unlocks")
	t.check(Expedition.choose(0) and not Expedition.choose(0),"Buff claimed once after hero reward")

func actors(id:String) -> Array:
	var result:Array=[]
	for unit in t.battle.units:
		if t.battle.actor_alive(unit) and unit.side=="ally" and unit.special.get("academy_hero","")==id:result.append(unit)
	return result

func check_lifecycle(country:String) -> void:
	MetaProgress.academy.hero_builds={}
	var ids:Array=["E1","MTNK"] if country=="美国" else ["E2","HTNK"]
	t.check(Expedition.start(country,"",900) and Expedition.choose(0),"start locked-hero lifecycle "+country)
	seed_reward(ids[0]);launch();victory()
	await t.finish()
	claim_hero(ids[0]);seed_reward(ids[1]);launch()
	var first:=actors(ids[0])
	t.check(first.size()==1,"locked infantry reward deploys as exactly one named hero "+ids[0])
	if first.size()!=1:await t.finish();return
	t.check(first[0].display_name.contains(str(MetaProgress.Academy.HEROES[ids[0]])) and first[0].special.has("hero_survival_rank"),"recruited infantry receives hero identity and talents")
	first[0].hp=first[0].max_hp*0.5
	t.check(Expedition.checkpoint(t.battle),"recruited hero checkpoint captures real skills and health")
	await t.finish()
	t.check(Expedition.load_run() and Expedition.prepare_battle(),"recruited hero checkpoint restores from disk")
	t.screen=load("res://scenes/battle.tscn").instantiate();t.add_child(t.screen)
	t.screen.process_mode=Node.PROCESS_MODE_DISABLED;t.battle=t.screen.battle
	first=actors(ids[0])
	t.check(first.size()==1 and is_equal_approx(first[0].hp/first[0].max_hp,0.5),"checkpoint restores one hero without healing or duplicate deployment")
	victory()
	await t.finish()
	claim_hero(ids[1]);launch()
	t.check(actors(ids[0]).size()==1 and actors(ids[1]).size()==1,"survivor and newly recruited hero deploy together "+country)
	var tanks:=actors(ids[1])
	t.check(tanks.size()==1 and Unit.TankHero.active(tanks[0]),"recruited tank uses real tank hero abilities")
	for id:String in ids:
		var existing:=actors(id)
		if existing.size()!=1:continue
		var ordinary=t.battle.spawn_unit(id,"ally",Vector2(500,500))
		MetaProgress.Academy.promote(MetaProgress,t.battle,id,ordinary)
		t.check(not ordinary.special.has("academy_hero") and actors(id).size()==1,"ordinary reinforcements cannot duplicate hero "+id)
		if id==ids[0]:existing[0]._die()
	victory()
	t.check(Heroes.wounded(Expedition.state)==[ids[0]],"settlement marks only fallen hero as wounded")
	await t.finish()
	while Expedition.state.phase=="reward":Expedition.choose(0)
	if Expedition.state.phase=="event":t.check(Expedition.resolve_event(0,Expedition.event_token()),"post-battle event before hero relaunch")
	launch()
	t.check(actors(ids[0]).is_empty() and actors(ids[1]).size()==1,"wounded hero stays absent while surviving hero continues")
	var replacement=t.battle.spawn_unit(ids[0],"ally",Vector2(600,500))
	MetaProgress.Academy.promote(MetaProgress,t.battle,ids[0],replacement)
	t.check(not replacement.special.has("academy_hero"),"ordinary unit cannot bypass injured hero rescue")
	var second:=actors(ids[1])
	if second.size()==1:second[0]._die()
	t.check(Expedition.retreat(t.battle),"retreat updates all recruited hero injuries")
	t.check(Heroes.wounded(Expedition.state).size()==2,"both fallen heroes remain owned and need separate rescue")
	await t.finish()
	t.check(Expedition.load_run() and Heroes.wounded(Expedition.state).size()==2,"multiple injuries survive disk reload")
	await check_camp_rescue(ids)
	var saved:Dictionary=Expedition.state.duplicate(true)
	var poor:=saved.duplicate(true);poor.supplies=59
	t.check(Expedition.commit(poor) and not Expedition.rescue_hero(ids[0]) and Expedition.state.supplies==59,"insufficient supplies cannot rescue or charge")
	t.check(Expedition.commit(saved),"restore funded camp after insufficient supply case")
	var funds:int=Expedition.state.supplies
	t.check(Expedition.rescue_hero(ids[0]) and Expedition.state.supplies==funds-60,"rescue chosen hero charges exactly 60")
	t.check(not Expedition.rescue_hero(ids[0]) and Expedition.state.supplies==funds-60 and Heroes.wounded(Expedition.state)==[ids[1]],"repeat rescue rejected and other hero remains wounded")
	t.check(Expedition.rescue_hero(ids[1]) and Expedition.load_run(),"second hero rescued and saved independently")
	launch()
	t.check(actors(ids[0]).size()==1 and actors(ids[1]).size()==1,"both rescued heroes return once on next deployment")
	t.check(MetaProgress.academy.hero_builds.is_empty(),"full recruitment lifecycle leaves permanent unlock counts unchanged")
	await t.finish()
	t.check(Expedition.start(country,"",901) and Heroes.owned(Expedition.state).is_empty(),"new expedition does not inherit temporary heroes")

func check_legacy() -> void:
	MetaProgress.academy.hero_builds={"MTNK":20}
	t.check(Expedition.start("美国","MTNK",123),"owned opening hero remains selectable")
	var old:Dictionary=Expedition.state.duplicate(true)
	old.erase("heroes");old.erase("wounded_heroes")
	t.check(Expedition.commit(old) and Expedition.load_run() and Heroes.owned(Expedition.state)==["MTNK"],"legacy single hero save still loads")
	old=Expedition.state.duplicate(true);old.hero_wounded=true
	Expedition.ready(old)
	t.check(Expedition.commit(old) and Expedition.load_run() and Heroes.wounded(Expedition.state)==["MTNK"],"legacy wounded flag remains authoritative")
	t.check(Expedition.rescue_hero() and Heroes.wounded(Expedition.state).is_empty(),"legacy default rescue remains supported")
	var upgraded:Dictionary=Expedition.state.duplicate(true)
	t.check(Heroes.recruit(upgraded,"E1") and Expedition.commit(upgraded) and Expedition.load_run(),"legacy save gains second hero without dropping selected hero")
	t.check(Heroes.owned(Expedition.state)==["MTNK","E1"] and not Expedition.state.hero_wounded,"legacy roster preserves both hero identities")

func check_camp_rescue(ids:Array) -> void:
	var camp=load("res://scenes/expedition.tscn").instantiate()
	t.add_child(camp)
	await t.get_tree().process_frame
	for id:String in ids:
		var found:=false
		for child in camp.body.get_children():
			if child is Button and child.text=="救治%s · 60 补给"%MetaProgress.Academy.HEROES[id]:found=true
		t.check(found,"camp exposes named rescue button for "+id)
	camp.free()
	await t.get_tree().process_frame

func check_factory_boundary() -> void:
	MetaProgress.academy.hero_builds={"MTNK":20,"HTNK":20}
	for country:String in ["美国","苏俄"]:
		t.check(Expedition.start(country,"",723) and Expedition.choose(0),"start without selected hero despite permanent unlock "+country)
		launch()
		var before:int=t.battle.units.size()
		for tick in 4:
			t.battle.allied_state.hero_tank_scan=0
			Unit.TankHero.tick_world(t.battle,0.25)
		t.check(t.battle.units.size()==before and actors("MTNK").is_empty() and actors("HTNK").is_empty(),"factory auto-gifts cannot add unselected heroes or ordinary tank duplicates "+country)
		await t.finish()
