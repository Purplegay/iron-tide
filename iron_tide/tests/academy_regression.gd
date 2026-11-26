extends Node

var failed := 0
var checks := 0

func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failed += 1
		push_error(label)

func _ready() -> void:
	if not OS.get_user_data_dir().contains("CodexIronTideValidation"):
		get_tree().quit(2)
		return
	run.call_deferred()

func run() -> void:
	var m := MetaProgress
	var a := MetaProgress.Academy
	m.reset_save()
	var legacy := m.to_dict().duplicate(true)
	legacy.erase("academy_version")
	legacy.unlocked_skills = ["ap_smoke","ps_regen"]
	legacy.unit_loadouts = {"E1":{"active":["ap_smoke"],"passive":"ps_regen"}}
	legacy.currency.credits = 3456
	legacy.stats.player_production = {"factions":{"allied":{"unit":{"E1":{"built":49,"matches":1}}}}}
	var file := FileAccess.open(m.SAVE_PATH,FileAccess.WRITE)
	file.store_string(JSON.stringify(legacy))
	file.close()
	m.load_save()
	check(m.unlocked_skills.is_empty() and m.unit_loadout("E1").passive=="" and m.unit_loadout("E1").active[0]=="", "old card and slots reset")
	check(m.balance("credits")==3456 and m.academy.hero_builds.E1==49,"preserve wallet and historical GI production")
	var world := {"skirmish":true, "gm_unit_lab":false, "match_id":"test1","allied_state":{"player_production":{"unit":{}}}}
	a.started(m,world)
	a.started(m,world)
	check(m.balance("diamonds")==100,"daily start once")
	BattleRequest.configure_skirmish(MatchRules.EXTENDED,{})
	var soldier := Unit.new()
	add_child(soldier)
	soldier.setup(GameData.get_unit("E1"),"ally",Vector2.ZERO)
	world.allied_state.player_production.unit.E1=1
	a.built(m,world,"E1",soldier)
	check(soldier.special.get("academy_hero")=="E1" and soldier.veteran_level==2,"first eligible GI promoted")
	a.built(m,world,"E1",soldier)
	check(m.academy.hero_builds.E1==50 and a.today(m).units==1,"reload does not duplicate production")
	for i in 9:
		world.allied_state.player_production.unit.APOC=i+1
		a.built(m,world,"APOC",null)
	check(a.t3("APOC") and not a.t3("E2") and m.balance("diamonds")==300,"T3 and ten production rewards")
	m.academy.affinity={"E1":480}
	var victim := Unit.new()
	victim.side="enemy"
	a.hit(victim,soldier)
	a.defeated(world,victim,null)
	a.defeated(world,{"side":"enemy","special":{}},soldier)
	check(world.allied_state.named_heroes.E1==17,"appearance, assist and kill")
	a.settled(m,world,true)
	world.allied_state.named_heroes={}
	a.settled(m,world,true)
	check(m.academy.affinity.E1==517 and m.balance("diamonds")==400 and m.academy.victory_shards==1,"affinity milestone and daily win")
	victim.free()
	m.academy.victory_shards=20
	check(a.purchase(m,"skin_ticket") and a.purchase(m,"tickets"),"ten pieces per choice")
	check(m.buy_cosmetic("MTNK","skin","cobalt_porcelain") and m.balance("diamonds")==400 and m.academy.skin_ticket==0,"skin ticket consumed")
	m.currency.diamonds=8100
	var result := a.draw(m,10)
	check(result.size()==10 and m.balance("diamonds")==0 and m.academy.tickets==0 and m.academy.card_shards>=10,"ten draw consumes one ticket and nine diamond pulls")
	check(a.draw(m,1).is_empty(),"no overdraft")
	var sid: String=result.filter(func(row):return a.ContractPool.entry(row.id).is_empty())[0].id
	m.currency.cores=1000
	var upgrade_total:=0
	for rank in 3:upgrade_total+=a.card_upgrade_cost(sid,rank)
	for i in 3: check(a.purchase(m,"level",sid),"card level %d"%i)
	check(not a.purchase(m,"level",sid) and m.balance("cores")==1000-upgrade_total,"card cap and rarity upgrade total")
	BattleRequest.freeze_combat_context()
	check(is_equal_approx(BattleRequest.card_scale(sid),float(GameData.get_skill(sid).strength_by_rank[3]) if GameData.get_skill(sid).has("strength_by_rank") else 1.45),"new match card strength")
	m.academy.card_shards=250
	for tier in ["epic","legend"]:
		var card: Dictionary=m.skill_draw_candidates().filter(func(c):return c.rarity==tier)[0]
		m.unlocked_skills.erase(card.id)
		check(a.purchase(m,"redeem",card.id) and not a.purchase(m,"redeem",card.id),"targeted exchange "+tier)
	check(m.academy.card_shards==0,"50 and 200 exchange thresholds")
	m.save()
	m.load_save()
	check(m.academy.levels[sid]==3 and m.unlocked_skills.size()>0,"new save not reset twice")
	var ui=load("res://scenes/meta.tscn").instantiate()
	add_child(ui)
	ui.tasks_tab.pressed.emit()
	check(ui.tasks.visible and ui.tasks_tab.disabled and not ui.shop_body.visible and ui.tasks.rows.size()==3,"daily tab has three diamond tasks")
	check(ui.tasks.summary.text.contains("300 / 300") and ui.tasks.rows.units.state.text.contains("已到账"),"earned total reflects paid tasks")
	var day_before: Dictionary=m.academy.daily.duplicate()
	var wallet_before := m.balance("diamonds")
	m.academy.daily.date="2000-01-01"
	ui._process(2.0)
	check(ui.tasks.summary.text.contains("0 / 300") and ui.tasks.rows.units.bar.value==0,"open task page resets across local day")
	m.academy.daily=day_before
	m.academy.daily.units=6
	ui.tasks.refresh()
	check(ui.tasks.rows.units.state.text.contains("6 / 10") and ui.tasks.summary.text.contains("250 / 300") and m.balance("diamonds")==wallet_before,"partial task progress is read-only")
	m.academy.daily.units=10
	ui._set_page("shop")
	check(ui.shop_body.visible and not ui.tasks.visible,"shop and tasks are separate pages")
	ui._set_page("pool")
	var preview_rank:OptionButton=ui.pool_body.get_node("TrainingPreviewRank")
	var selected_id:String=ui.selected_card
	var wallet:=m.currency.duplicate()
	for rank in 4:
		preview_rank.select(rank)
		preview_rank.item_selected.emit(rank)
		check(ui.pool_body.get_node("TrainingDescription").text.begins_with("Lv.%d" % rank),"training preview changes selected rank")
	check(m.currency==wallet and ui.selected_card==selected_id,"rank preview does not purchase anything or change cards")
	for card in GameData.skills_by_unlock("gacha"):
		var descriptions:={}
		for rank in 4:
			var description:=a.skill_description(card,rank)
			check(not description.contains("{") and description.begins_with("Lv.%d" % rank),"resolved card description "+card.id+str(rank))
			descriptions[description.substr(4)]=true
		check(descriptions.size()==4,"all four descriptions change effective numbers "+card.id)
	check(a.skill_description(GameData.get_skill("ps_phase"),3).contains("57%") and a.skill_description(GameData.get_skill("ap_smoke"),0).contains("37.5%"),"stack maximum and actual damage reduction")
	ui.pool_body.get_node("CardDemos").pressed.emit()
	var gallery = ui.get_node("FactionCardDemos")
	for index in 8:
		for rank in 4:
			gallery.select_card(index,rank)
			check(gallery.actor_view.actor != null and gallery.stage.card==gallery.ids[index] and gallery.stage.magnitude>0 and gallery.rank==rank,"faction preview %d/%d" % [index,rank])
	for rank in 4:
		gallery.select_card(gallery.ids.find("ap_decoy"),rank)
		check(gallery.summary.text.contains("基础冷却 %d 秒" % [30,28,26,25][rank]),"decoy demo cooldown "+str(rank))
		gallery.select_card(gallery.ids.find("ap_twin"),rank)
		check(gallery.summary.text.contains("基础冷却 %s 秒" % ["24","23","22.5","22"][rank]) and gallery.values.text.contains("冷却 22.5 秒"),"Twin demo preserves cooldown precision "+str(rank))
		gallery.select_card(gallery.ids.find("ap_buoy"),rank)
		check(gallery.summary.text.contains("基础冷却 %d 秒" % [32,30,28,25][rank]),"buoy demo cooldown "+str(rank))
		gallery.select_card(gallery.ids.find("ps_phase"),rank)
		check(is_equal_approx(gallery.stage.magnitude,[5.0,10.0,15.0,19.0][rank]),"Flux preview per layer at rank "+str(rank))
	gallery.free()
	ui._set_page("units")
	ui._unit_sel="E1"
	ui._rebuild_unit_detail()
	check(ui.pool_body.get_child_count()>5 and ui.unit_detail.get_child_count()>2,"shop, pool, hero UI")
	ui.hero_tab.pressed.emit()
	check(ui.heroes.visible and not ui.units_body.visible and ui.heroes.preview.unit_id=="E1", "dedicated hero tab opens on GI")
	var demo=ui.heroes.talent_demo
	var academy_before:=m.academy.duplicate(true)
	var hero_wallet:=m.currency.duplicate()
	# Keep the original GI/conscript coverage independent of roster ordering.
	var hero_indices:Array=[]
	for id in ["E1","E2"]:
		for index in ui.heroes.picker.item_count:
			if ui.heroes.picker.get_item_metadata(index)==id:hero_indices.append(index)
	for hero_index in hero_indices:
		ui.heroes.picker.select(hero_index)
		ui.heroes.picker.item_selected.emit(hero_index)
		for kind in 2:
			demo.talent.select(kind)
			demo.talent.item_selected.emit(kind)
			check(demo.levels.item_count==(4 if kind==0 else 6),"all hero talent ranks previewable")
			for tier in demo.levels.item_count:
				demo.levels.select(tier)
				demo.levels.item_selected.emit(tier)
				demo._process(2.5)
				check(demo.hero_id==ui.heroes.selected and demo.elapsed==2.5 and demo.caption.text.contains(a.escort_description(tier) if kind==0 else a.SURVIVAL_STAGES[tier]),"hero talent preview matches selected hero and tier")
				if DisplayServer.get_name()!="headless":
					await RenderingServer.frame_post_draw
	demo.pause_button.pressed.emit()
	var stopped:float=demo.elapsed
	demo._process(1.0)
	check(demo.elapsed==stopped and not demo.playing,"hero demo pauses in place")
	demo.restart()
	check(demo.elapsed==0 and demo.playing and m.academy==academy_before and hero_wallet==m.currency,"replay does not change hero or wallet")
	ui.heroes.picker.select(hero_indices[0])
	ui.heroes.picker.item_selected.emit(hero_indices[0])
	if DisplayServer.get_name()!="headless":
		demo.talent.select(0)
		demo.talent.item_selected.emit(0)
		demo.levels.select(2)
		demo.levels.item_selected.emit(2)
		demo.elapsed=4.7
		demo.stage.queue_redraw()
		ui.heroes.ensure_control_visible(demo)
		await get_tree().process_frame
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png(OS.get_environment("IRON_TIDE_REPORT_DIR").path_join("hero-escort-demo.png"))
		demo.talent.select(1)
		demo.talent.item_selected.emit(1)
		demo.levels.select(4)
		demo.levels.item_selected.emit(4)
		demo.elapsed=2.5
		demo.stage.queue_redraw()
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png(OS.get_environment("IRON_TIDE_REPORT_DIR").path_join("hero-survival-demo.png"))
	var preview_wallet:=m.currency.duplicate()
	ui.heroes.reward_toggle.button_pressed=true
	check(ui.heroes.reward_panel.visible and ui.heroes.reward_page.item_count==20 and ui.heroes.reward_list.text.contains("Lv.5　100 钻石　·　已发放"),"hero reward preview shows all pages and earned milestone")
	ui.heroes.reward_page.select(19)
	ui.heroes.reward_page.item_selected.emit(19)
	check(ui.heroes.reward_list.text.contains("Lv.200　100 钻石　·　未达到") and m.currency==preview_wallet,"last reward inspectable without granting it")
	ui.heroes.picker.select(hero_indices[1])
	ui.heroes.picker.item_selected.emit(hero_indices[1])
	check(ui.heroes.reward_page.selected==0 and ui.heroes.reward_list.text.contains("Lv.1　100 军需券　·　下一级"),"changing hero shows that hero's next reward")
	ui.heroes.reward_toggle.button_pressed=false
	ui.heroes.trial.button_pressed=true
	check(ui.heroes.skin_description.text.contains("炉芯") and ui.heroes.skin_description.text.contains("炉前赤卫"),"locked hero carries its skin description")
	check(ui.heroes.preview.actor.special.hero_skin and ui.heroes.firepower.disabled and ui.heroes.health.disabled and ui.heroes.outfit.disabled,"locked conscript skin can be previewed on hero page")
	ui.heroes.picker.select(hero_indices[0])
	ui.heroes.picker.item_selected.emit(hero_indices[0])
	m.currency.credits=10000
	ui.heroes.refresh()
	var credits_before := m.balance("credits")
	var cores_before := m.balance("cores")
	ui.heroes.firepower.pressed.emit()
	ui.heroes.outfit.pressed.emit()
	check(m.balance("cores")==cores_before and m.balance("credits")==credits_before-1000 and m.academy.hero_training.E1=={"firepower":1,"health":0} and ui.heroes.trial.button_pressed,"credit training and equip reach selected hero from new page")
	ui.heroes.health.pressed.emit()
	check(m.balance("cores")==cores_before and m.balance("credits")==credits_before-2000 and m.academy.hero_training.E1=={"firepower":1,"health":1},"health trains independently using credits only")
	m.currency.cores=400
	check(not a.purchase(m,"escort","E2"),"locked hero cannot train escorts")
	for tier in range(1,4):
		ui.heroes.escort.pressed.emit()
		check(m.academy.hero_escort_ranks.E1==tier and m.balance("cores")==[360,240,0][tier-1],"hero escort training UI rank "+str(tier))
	check(ui.heroes.escort.disabled and not a.purchase(m,"escort","E1"),"maximum escort rank cannot be repurchased")
	m.currency.cores=1400
	check(not a.purchase(m,"survival","E2"),"locked hero cannot train survival")
	for tier in range(1,6):
		ui.heroes.refresh()
		ui.heroes.survival.pressed.emit()
		check(m.academy.hero_survival_ranks.E1==tier and m.balance("cores")==[1360,1240,1000,600,0][tier-1],"survival upgrade "+str(tier))
	check(ui.heroes.survival.disabled and not a.purchase(m,"survival","E1") and not m.academy.hero_survival_ranks.has("E2"),"separate survival ranks and cap")
	ui.tab_units_btn.pressed.emit()
	check(not ui.heroes.visible and ui.units_body.visible,"refits remain on their own tab")
	ui.free()
	var daily_screen = load("res://scenes/daily_tasks.tscn").instantiate()
	add_child(daily_screen)
	check(daily_screen.tasks.visible and daily_screen.tasks.rows.start.state.text.contains("已到账"),"main menu direct daily scene")
	daily_screen.free()
	var direct = load("res://scenes/heroes.tscn").instantiate()
	add_child(direct)
	check(direct.heroes.visible and direct.hero_tab.disabled and direct.heroes.preview.actor.special.hero_skin,"direct menu scene restores selected hero skin")
	direct.free()
	for trial in 4:
		var uid:String=["E1","E2","E1","E2"][trial]
		m.academy.get_or_add("hero_escort_ranks",{})[uid]=trial
		if trial==3:
			m.academy.hero_survival_ranks[uid]=4
			m.currency.cores=600
			var attack_cap:=a.training_cap("firepower")
			var hp_cap:=a.training_cap("health")
			m.currency.credits=a.hero_training_cost(attack_cap-1)+a.hero_training_cost(hp_cap-1)
			m.academy.hero_training[uid]={"firepower":attack_cap-1,"health":hp_cap-1}
			m.academy.get_or_add("hero_builds",{})[uid]=50
			check(a.purchase(m,"firepower",uid) and a.purchase(m,"health",uid),"both tracks reach final rank independently")
			check(not a.purchase(m,"firepower",uid) and not a.purchase(m,"health",uid) and m.balance("credits")==0 and m.balance("cores")==600,"no billing above either cap and no core charge")
		var country := "美国" if uid == "E1" else "苏俄"
		BattleRequest.configure_skirmish(MatchRules.EXTENDED, {"country":country,"map_size":2400,"starting_funds":12000})
		var scene = load("res://scenes/battle.tscn").instantiate()
		add_child(scene)
		var battle = scene.battle
		m.academy.get_or_add("hero_builds",{})[uid] = 50
		var factory = battle._place_building("GAPILE" if uid=="E1" else "NAHAND","ally",Vector2(1500,1300),true)
		factory._buildup_play = -1.0
		var before_spawn:Array=battle.units.duplicate()
		var rally:=Vector2(1350,1510)
		battle.rally_points[factory.get_instance_id()]=rally
		var queued: bool = factory.enqueue(uid)
		for tick in 300:
			if factory.production.is_empty(): break
			factory._process(0.1)
		var heroes: Array = battle.units.filter(func(u): return is_instance_valid(u) and u.special.get("academy_hero")==uid)
		check(queued and heroes.size()==1 and heroes[0].veteran_level==2, "paid barracks production creates one hero "+uid)
		if heroes.size()==1:
			check(heroes[0].display_name.contains(a.HEROES[uid]), "named hero visible in unit identity "+uid)
		var ranks:Array=[]
		var guard=null
		for actor in battle.units:
			if actor.unit_id==uid and not before_spawn.has(actor) and not actor.special.has("academy_hero"):
				ranks.append(actor.veteran_level)
				guard=actor
				check(actor.has_move_order and actor.move_target.is_equal_approx(rally),"guard inherits actual barracks rally")
		check(ranks==[[1,1,1,1],[1,1,1,1,1],[2,2,2,1,1],[2,2,2,2,2]][trial],"actual guard ranks at tier "+str(trial))
		check(int(battle.allied_state.player_production.unit[uid])==1 and int(m.academy.hero_builds[uid])==51,"escorts do not count as paid production")
		if guard!=null and heroes.size()==1:
			var hero=heroes[0]
			var trained:int=5 if uid=="E1" else (4 if trial==3 else 0)
			check(a.survival_rank(hero)==trained and a.survival_rank(guard)==-1,"survival belongs to named officer only")
			if trial==0: check_survival(hero,guard,battle)
			guard._grant_veteran(2,false)
			if trial==3:
				hero._tick_skills(0.1)
				guard._tick_skills(0.1)
				var hero_damage:=CombatMath.with_offense(100,hero.bonuses)
				var guard_damage:=CombatMath.with_offense(100,guard.bonuses)
				check(is_equal_approx(hero_damage,guard_damage*2.0) and is_equal_approx(hero.max_hp,guard.max_hp*2.5),"max hero training applies to combat offense and HP but not escorts")
			check(is_equal_approx(hero.attack_range-guard.attack_range,55.0),"only hero receives extra cell")
			if uid=="E1":
				hero.set_deployed(true,false)
				guard.set_deployed(true,false)
				check(is_equal_approx(hero.attack_range-guard.attack_range,55.0),"deployed GI gains exactly one cell")
			hero._refresh_weapon_derived()
			check(is_equal_approx(hero.attack_range-guard.attack_range,55.0),"derived range refresh never stacks")
		var before_second:int=battle.units.size()
		check(factory.enqueue(uid),"can order another ordinary soldier")
		for tick in 300:
			if factory.production.is_empty():break
			factory._process(0.1)
		check(battle.units.size()==before_second+1 and not battle.units.back().special.has("academy_hero"),"second order gives no duplicate officer or guards")
		if trial==3:
			var position_before:Vector2=factory.position
			factory.position=Vector2(-5000,-5000)
			factory.special.hero_escort_queue=[{"unit":uid,"stars":2}]
			a.release_escorts(factory)
			check(factory.special.has("hero_escort_queue") and battle.units.size()==before_second+1,"blocked exit retains outstanding escort")
			var codec=preload("res://scripts/save/battle_snapshot.gd").new()
			var snapshot:=codec.capture(battle)
			var hero_idx:int=codec.ids[heroes[0]]
			var factory_idx:int=codec.ids[factory]
			codec.restore(battle,snapshot)
			check(a.survival_rank(codec.objects[hero_idx])==4,"battle save restores exact hero survival rank")
			factory=codec.objects[factory_idx]
			factory.position=position_before
			factory._process(0.26)
			check(codec.error.is_empty() and not factory.special.has("hero_escort_queue") and battle.units.size()==before_second+2 and battle.units.back().veteran_level==2,"reopened exit releases only outstanding escort after restore")
		var xp_before := int(m.academy.get("affinity",{}).get(uid,0))
		battle.end_battle(true)
		preload("res://scripts/world/production_counts.gd").settle(battle,true)
		check(int(m.academy.affinity.get(uid,0))==xp_before+30,"real win and settlement replay "+uid)
		scene.free()
	m.load_save()
	var bookmarks=preload("res://scripts/ui/progression_bookmarks.gd").new()
	bookmarks.set_value("hero","HTNK");bookmarks.save()
	var roster=load("res://scenes/heroes.tscn").instantiate()
	add_child(roster)
	check(roster.heroes.selected=="HTNK" and roster.heroes.preview.unit_id=="HTNK","direct hero page opens remembered hero before recent production")
	roster.heroes.picker.select(1)
	roster.heroes.picker.item_selected.emit(1)
	roster._refresh()
	check(roster.heroes.selected=="E1","refresh preserves manual selection while page is open")
	roster._set_page("units")
	roster._set_page("heroes")
	check(roster.heroes.selected=="E1","returning to hero tab retains manual selection")
	var totals:Dictionary=m.academy.hero_builds.duplicate()
	m.academy.hero_builds.E2=30
	roster.heroes.open_page()
	check(roster.heroes.selected=="E1" and roster.heroes.picker.get_item_text(1).contains("未解锁"),"locked recent hero remains below unlocked heroes")
	m.academy.hero_builds=totals
	roster.free()
	m.academy.daily.date = "2000-01-01"
	var old_balance := m.balance("diamonds")
	world.gm_unit_lab = true
	a.started(m,world)
	check(m.balance("diamonds")==old_balance, "lab cannot claim new daily start")
	world.gm_unit_lab = false
	a.started(m,world)
	check(m.balance("diamonds")==old_balance+100 and a.today(m).units==0 and a.today(m).win==0,"new day refreshes counters and pays once")
	var fresh := Unit.new()
	add_child(fresh)
	fresh.setup(GameData.get_unit("E1"),"ally",Vector2.ZERO)
	m.academy.hero_training={"E1":3}
	m.academy.hero_skin={"E1":true}
	BattleRequest.freeze_combat_context()
	var life := fresh.max_hp
	world.match_id="trained"
	world.allied_state={"player_production":{"unit":{"E1":1}}}
	a.built(m,world,"E1",fresh)
	check(fresh.special.hero_skin and is_equal_approx(fresh._base_max_hp,life*1.0225),"trained hero keeps independent skin and health baseline")
	fresh._tick_skills(0.1)
	check(is_equal_approx(fresh.bonuses.attack_bonus,fresh._base_atk),"trained firepower survives next combat tick")
	m.currency.cores=2000
	m.currency.credits=a.hero_training_cost(3)
	check(a.purchase(m,"health","E1") and m.academy.hero_training.E1=={"firepower":3,"health":4},"old joint rank preserved in both tracks on first purchase")
	m.load_save()
	check(a.training_rank(m.academy.hero_training,"E1","health")==4 and a.training_rank(m.academy.hero_training,"E1","firepower")==3,"both track ranks survive reload")
	m.academy.affinity.E1=19990
	a.settled(m,world,true)
	var capped := m.balance("diamonds")
	a.settled(m,world,true)
	check(m.academy.affinity.E1==20000 and m.balance("diamonds")==capped,"level 200 cap never awards another milestone")
	var old_cards := m.to_dict().duplicate(true)
	old_cards.academy_version = 1
	old_cards.unit_talents = {"R3REAPER":{"reaper_split_fire":2,"reaper_fire_control":1}}
	old_cards.owned_talent_points = 8
	old_cards.currency.cores = 25
	old_cards.academy.levels = {"ap_smoke":3, "ap_berserk":9, "ps_regen":10}
	file = FileAccess.open(m.SAVE_PATH,FileAccess.WRITE)
	file.store_string(JSON.stringify(old_cards))
	file.close()
	m.load_save()
	m.load_save()
	check(m.unassigned_talent_points()==4 and m.redeemed_points_in_use()==1 and a.card_rank(m,"reaper_split_fire")==2 and m.unlocked_skills.has("reaper_split_fire"),"old split rank becomes owned card and frees allocation once")
	check(a.card_rank(m,"ap_smoke")==0 and a.card_rank(m,"ap_berserk")==2 and a.card_rank(m,"ps_regen")==3 and m.balance("cores")==205,"migration returns partial ranks once, including max rank")
	BattleRequest.combat_context={"card_levels":{"ap_smoke":3}}
	check(is_equal_approx(BattleRequest.card_scale("ap_smoke"),1.1),"earlier battle retains its frozen scale")
	var console = preload("res://scripts/admin/gm_console.gd").new()
	add_child(console)
	var before_grant := m.balance("diamonds")
	console.find_child("GrantDiamonds",true,false).pressed.emit()
	m.load_save()
	check(m.balance("diamonds")==before_grant+9000 and console._status.text.contains("9000"),"GM diamond button persists and displays grant")
	console.free()
	check_faction_battle(m)
	check_contact_fog()
	await check_yr_talents()
	check_free_draw(m)
	check_permanent_tiers(m)
	check_affinity_rewards(m)
	print("ACADEMY checks=",checks," failed=",failed)
	get_tree().quit(1 if failed else 0)

func check_affinity_rewards(m) -> void:
	m.reset_save()
	var old:=MetaProgress.to_dict().duplicate(true)
	old.academy_version=3
	old.academy.affinity={"E1":585,"E2":274}
	old.currency={"diamonds":100,"credits":50}
	var file:=FileAccess.open(m.SAVE_PATH,FileAccess.WRITE)
	file.store_string(JSON.stringify(old))
	file.close()
	m.load_save()
	check(m.balance("credits")==650 and m.balance("diamonds")==100,"v3 pays six reached ordinary levels across both heroes")
	m.load_save()
	check(m.balance("credits")==650 and m.balance("diamonds")==100,"backfill and earned milestones never repeat")
	var world:={"skirmish":true,"gm_unit_lab":false,"match_id":"affinity","allied_state":{"named_heroes":{"E1":430,"E2":26}}}
	MetaProgress.Academy.settled(m,world,false)
	check(m.academy.affinity=={"E1":1015,"E2":300} and m.balance("credits")==1150 and m.balance("diamonds")==200,"multi-level payout includes all ordinary levels and one milestone")
	m.academy.affinity={"E1":19975}
	world.allied_state.named_heroes={"E1":1250}
	MetaProgress.Academy.settled(m,world,false)
	MetaProgress.Academy.settled(m,world,false)
	check(m.balance("diamonds")==300 and m.balance("credits")==1150 and m.academy.affinity.E1==20000,"last milestone granted only once")
	m.reset_save()

func check_permanent_tiers(m) -> void:
	m.reset_save()
	var ui=load("res://scenes/meta.tscn").instantiate()
	add_child(ui)
	check(ui.tier_list.get_child_count()==2 and m.next_tier()=="t1","only current and next tier are shown")
	check(not m.unlock_tier("unknown") and not m.unlock_tier("t2") and not m.unlock_tier("t1"),"reject unknown, skipped and unaffordable tier")
	m.grant("credits",30000)
	m.idle.last_tick_unix=m._now()-3600.0
	var button=ui.tier_list.get_child(1).find_children("*","Button",true,false)[0]
	button.pressed.emit()
	check(m.current_tier=="t1" and m.balance("credits")==28800 and absf(m.pending_rewards().credits-240.0)<0.1,"UI upgrade charges once and closes previous hour at old rate")
	check(m.hourly_rate().credits==480 and is_equal_approx(m.stat_bonuses().attack_bonus,1.05) and not m.unlock_tier("t0") and not m.unlock_tier("t1"),"new rate and bonuses apply immediately; lower and duplicate orders rejected")
	var snapshot: Dictionary=m.to_dict().duplicate(true)
	snapshot.current_tier="t0"
	snapshot.unlocked_tiers=["t3","t0","unknown"]
	var file:=FileAccess.open(m.SAVE_PATH,FileAccess.WRITE)
	file.store_string(JSON.stringify(snapshot))
	file.close()
	m.load_save()
	m.load_save()
	check(m.current_tier=="t3" and m.unlocked_tiers==["t0","t1","t2","t3"] and m.balance("credits")==28800 and m.pending_rewards().credits>=240,"legacy selection migrates to highest earned tier without rebilling")
	m.grant("credits",m.tier_unlock_cost("t4"))
	check(m.can_unlock_tier("t4"),"final upgrade is affordable before failed save")
	var tmp: String=m.SAVE_PATH+".tmp"
	check(DirAccess.make_dir_absolute(tmp)==OK,"prepare blocked save")
	var before: Dictionary=m.to_dict().duplicate(true)
	check(not m.unlock_tier("t4") and m.to_dict()==before,"failed upgrade rolls back tier, balance and pending income")
	DirAccess.remove_absolute(tmp)
	GM.cmd_grant_all_tiers()
	m.load_save()
	ui._refresh()
	check(m.current_tier=="t4" and m.hourly_rate().credits==3200 and ui.tier_list.get_child_count()==1 and m.next_tier().is_empty(),"final tier persists and is the sole displayed form")
	ui.free()

func check_survival(hero,guard,battle) -> void:
	var a:=MetaProgress.Academy
	var heavy:float=hero.max_hp*100.0
	var rows:=[
		[0,"ParasiteDog","",0.25],[0,"YR_SOV_ParasiteDog","",0.25],
		[0,"HollowPoint","MP5E",0.25],[0,"HollowPoint2","DoublePistols",0.25],
		[1,"YR_SOV_Parasite","",1.0/3.0],[1,"HollowPoint","AWP",1.0/3.0],
		[3,"Gas","",0.5],[3,"","VirusgunE",0.5],[3,"RadSite","",0.5],[4,"YR_SOV_TerrorBombWH","",2.0/3.0],
		[4,"YR_SOV_DemobombWH","",2.0/3.0]]
	for row in rows:
		var tier:int=row[0]
		hero.special.hero_survival_rank=tier
		hero.hp=hero.max_hp
		hero.receive_hit(heavy,"bullet",{"impact_weapon":row[2]},null,row[1])
		check(is_equal_approx(hero.hp,hero.max_hp*(1.0-float(row[3]))),"lethal impact mitigated "+str(row))
		if tier>0:
			hero.special.hero_survival_rank=tier-1
			check(a.survival_damage(hero,heavy,row[1],row[2])==heavy,"untrained tier has no mitigation "+str(row))
	hero.special.hero_survival_rank=2
	hero.hp=hero.max_hp
	hero.receive_hit(heavy,"crush")
	check(hero.hp==hero.max_hp and not hero._crush_death,"immune to crush without latching crush death")
	check(a.survival_damage(hero,heavy,"HollowPoint","BearBite")==heavy and a.survival_damage(guard,heavy,"ParasiteDog","")==heavy,"unrelated hollow points and guards are unaffected")
	check(a.survival_damage(hero,5,"HollowPoint","MP5")==5,"ordinary nonlethal hits retain their damage")
	hero.special.hero_survival_rank=0
	hero.receive_hit(20,"melee",{},null,"YR_CAP_ParasiteDog")
	check(is_equal_approx(hero.hp,hero.max_hp*0.75),"Allied dog culling resolves before hero mitigation")
	var seal=battle.spawn_unit("GHOST","enemy",hero.position+Vector2(40,0))
	hero.hp=hero.max_hp*0.5
	hero.special.hero_survival_rank=0
	seal._fire_shot(hero)
	for shot in battle.projectiles_root.get_children():
		if shot is Projectile and shot.shooter()==seal: shot._explode()
	check(is_equal_approx(hero.hp,hero.max_hp*0.25),"SEAL service weapon carries its identity through impact")
	hero.hp=hero.max_hp
	var chrono=battle.spawn_unit("CLEG","enemy",hero.position+Vector2(40,0))
	chrono.attack_target=hero
	check(AlliedAbilities.special_shot(chrono,hero,chrono._active_weapon()),"chrono weapon acquires named hero")
	var base_rate:=preload("res://scripts/units/temporal_visual.gd").erase_rate(chrono)
	hero.special.hero_survival_rank=5
	var normal_time:float=hero.max_hp/base_rate
	var channelled:=AlliedAbilities.channel(chrono,normal_time)
	check(channelled and hero.hp>0 and is_equal_approx(chrono.special.temporal_work,hero.max_hp/2.0),"maximum rank survives the original erasure duration")
	AlliedAbilities.release_temporal(chrono)
	var victim=battle.spawn_unit("E2","ally",hero.position+Vector2(10,0))
	victim.special.academy_hero="E2"
	victim.special.hero_survival_rank=5
	chrono.attack_target=victim
	AlliedAbilities.special_shot(chrono,victim,chrono._active_weapon())
	var duration:float=victim.max_hp/base_rate*2.0
	AlliedAbilities.channel(chrono,duration-0.01)
	check(victim.hp>0,"final instant before extended erase")
	AlliedAbilities.channel(chrono,0.02)
	check(victim.hp==0,"extended erase reaches death")

func check_free_draw(m) -> void:
	m.reset_save()
	var a := MetaProgress.Academy
	var ui = load("res://scenes/meta.tscn").instantiate()
	add_child(ui)
	ui._set_page("pool")
	var tmp: String = m.SAVE_PATH + ".tmp"
	check(DirAccess.make_dir_absolute(tmp) == OK, "block free draw save")
	var original: Dictionary = m.academy.duplicate(true)
	check(a.draw(m, 1, true).is_empty() and m.academy == original and m.unlocked_skills.is_empty(), "failed free draw restores eligibility and rewards")
	DirAccess.remove_absolute(tmp)
	check(a.draw(m, 10, true).is_empty(), "free allowance cannot fund ten draws")
	ui.pool_body.find_child("FreeDailySkill", true, false).pressed.emit()
	check(ui.pool_body.find_child("FreeDailySkill", true, false).disabled and not ui.pool_result.is_empty() and m.academy.card_shards == 1 and (m.unlocked_skills.size() == 1 or a.ContractPool.owned_count(m)==1), "free UI draw works without funds and awards one card or contract")
	m.load_save()
	check(a.draw(m, 1, true).is_empty() and m.academy.card_shards == 1, "reload cannot repeat today's free draw")
	m.academy.last_free_draw_date = "2000-01-01"
	m.academy.tickets = 2
	m.currency.diamonds = 900
	check(a.draw(m, 1).size() == 1, "ticket draw before daily allowance")
	ui.pool_date = "2000-01-01"
	ui._process(5.0)
	check(not ui.pool_body.find_child("FreeDailySkill", true, false).disabled, "open pool refreshes daily availability")
	check(a.draw(m, 1, true).size() == 1 and m.academy.tickets == 1 and m.balance("diamonds") == 900, "new day grants one draw with ticket and diamond balances intact")
	check(a.draw(m, 1, true).is_empty(), "missed days do not accumulate")
	ui.free()

func check_faction_battle(m) -> void:
	m.reset_save()
	BattleRequest.configure_skirmish(MatchRules.EXTENDED,{"map_size":2400})
	for id in preload("res://scripts/ui/faction_card_gallery.gd").card_ids():
		var card:=GameData.get_skill(id)
		m.unlock_skill(id)
		m.academy.get_or_add("levels",{})[id]=3
		for uid in card.get("allowed_units",["E1"]):
			check(m.set_unit_skill(uid,card.type,0,id),"refit "+uid+" "+id)
		check(m.set_unit_skill("E1",card.type,0,id)==not card.has("allowed_units"),"general versus exclusive equipment eligibility "+id)
	BattleRequest.freeze_combat_context()
	var scene=load("res://scenes/battle.tscn").instantiate()
	add_child(scene)
	var w=scene.battle
	w.fog=null
	var p:=Vector2(1300,1300)
	for rank in 4:
		BattleRequest.combat_context.card_ranks.ap_decoy=rank
		var tester=w.spawn_unit("R3MIRAGE","ally",p+Vector2(-500,rank*70))
		var slot_index:=UnitSkillLayout.index(tester,1)
		var base:float=[30,28,26,25][rank]
		check(tester.use_ability(slot_index) and tester.ability_info(slot_index).cooldown==base and is_equal_approx(tester.ability_at(slot_index).cd_left,base/tester.skill_power),"decoy cast starts ranked cooldown "+str(rank))
	var mir=w.spawn_unit("R3MIRAGE","ally",p)
	var foe=w.spawn_unit("HTNK","enemy",p+Vector2(100,0))
	foe.hp=10000
	mir.hull_angle=0;mir.attack_target=foe;mir.attack_ordered=true
	check(mir.use_ability(UnitSkillLayout.index(mir,1)),"Mirage W arms")
	Unit.FactionCards.tick(mir,12.0)
	check(mir.special.has("decoy_origin") and not mir.special.has("echo_cloaked"),"waiting to depart does not start the cloak window")
	mir.position+=Vector2.RIGHT*2
	Unit.FactionCards.tick(mir,0.1)
	check(not w.actor_visible_to("enemy",mir) and mir.special.echo_left==2,"departure conceals and leaves image")
	Unit.FactionCards.tick(mir,2.0)
	check(not mir.special.has("echo_left") and mir.special.has("echo_cloaked"),"decoy expires separately")
	Unit.FactionCards.tick(mir,7.99)
	Ra3Mirage.shoot(mir,foe,mir.weapon,100,{})
	var shot=w.projectiles_root.get_child(-1)
	# Scatter is optional and may spawn a second projectile in a crowded scenario.
	for item in w.projectiles_root.get_children():
		if item is Projectile and item.attacker_bonus.has("echo_hit"):shot=item;break
	var before:float=foe.hp
	Ra3Mirage.tick_impact(shot,1)
	check(is_equal_approx(before-foe.hp,111.6) and not mir.special.has("echo_cloaked"),"actual first prism hit consumes Echo")
	for wait_time in [10.0,12.0]:
		var late=w.spawn_unit("R3MIRAGE","ally",p+Vector2(0,150))
		late.passive={}
		late.set_fire_stance("none")
		check(late.use_ability(UnitSkillLayout.index(late,1)),"late Echo cast")
		late.position+=Vector2.RIGHT*2
		Unit.FactionCards.tick(late,0.01)
		late._physics_process(2.0)
		late._physics_process(wait_time-2.0)
		check(not late.special.has("echo_cloaked") and not late.special.has("echo_bonus") and w.actor_visible_to("enemy",late),"Echo expires and enemy visibility returns")
		check(Ra3Mirage.disguised(late),"Echo expiry does not break stationary disguise")
		var cover=w.spawn_unit("R3MIRAGE","ally",late.position+Vector2(40,0))
		check(Ra3Mirage.toggle(cover) and Ra3Mirage.field_conceals(late,"enemy") and not w.actor_visible_to("enemy",late),"independent friendly field can conceal expired Echo")
		cover.special.ra3_field_cd=0
		Ra3Mirage.toggle(cover)
		var late_bonus:={}
		check(is_equal_approx(Unit.FactionCards.primary_shot(late,foe,late_bonus),1.0) and not late_bonus.has("echo_hit"),"no first-shot bonus or Echo marker at "+str(wait_time))
	var bonuses:={}
	for layers in range(1,4):
		Unit.FactionCards.tick(mir,3.0)
		check(is_equal_approx(Unit.FactionCards.primary_shot(mir,foe,bonuses),1.0+0.19*layers),"Flux strength after "+str(3*layers)+" seconds")
	Unit.FactionCards.tick(mir,10.0)
	check(is_equal_approx(Unit.FactionCards.primary_shot(mir,foe,bonuses),1.57) and bonuses.get("phase_layers")==3,"three max-rank Flux stacks cap")
	mir.velocity=Vector2(30,0)
	Unit.FactionCards.tick(mir,0.1)
	check(not mir.special.has("phase_target"),"movement clears Flux")
	var future=w.spawn_unit("R3FUTURE","ally",p)
	future.attack_target=foe;future.attack_ordered=true;future.turret_angle=0
	Ra3Expansion.make_shot(future,foe,foe.position,"neutron")
	Unit.FactionCards.tick(future,9.1)
	var neutron:=Ra3Expansion.make_shot(future,foe,foe.position,"neutron")
	check(is_equal_approx(neutron.splinters.get("phase_factor",0),1.57),"future neutron snapshots Flux")
	var bystander=w.spawn_unit("HTNK","enemy",foe.position)
	bystander.hp=10000
	before=foe.hp
	Ra3Expansion.hit(neutron,foe,100,"NEUTRON")
	var primary_damage:float=before-foe.hp
	Ra3Expansion.hit(neutron,bystander,100,"NEUTRON")
	check(is_equal_approx(primary_damage,(10000.0-bystander.hp)*1.57),"Flux amplifies focused target only")
	future.attack_ordered=false
	future.fire_stance="free"
	bystander.hp=30
	preload("res://scripts/units/ra3_neutron.gd").pulse(neutron,w,60)
	check(bystander.hp<30 and bystander.hp>0,"neutron pulse grazes a low-health secondary target")
	future._refresh_target()
	Unit.FactionCards.tick(future,0.1)
	check(is_same(future.attack_target,foe) and future.special.get("phase_time",0)==9.0,"automatic targeting retains Flux focus after collateral damage")
	var followup:=Ra3Expansion.make_shot(future,future.attack_target,future.attack_target.position,"neutron")
	check(is_equal_approx(followup.splinters.get("phase_factor",1),1.57),"next neutron retains all three layers")
	future.order_target(bystander,false,false)
	Unit.FactionCards.tick(future,0.1)
	check(is_same(future.attack_target,bystander) and not future.special.has("phase_target"),"explicitly switching targets still clears Flux")
	bystander.hp=10000
	var apoc=w.spawn_unit("R3APOC","ally",p)
	Unit.FactionCards.tick(apoc,0.1)
	apoc.velocity=Vector2(40,0)
	apoc.position+=Vector2.RIGHT*3
	Unit.FactionCards.tick(apoc,3)
	apoc.hp=1000;apoc.receive_hit(100,"cannon",{},foe,"RA3_EXPANSION")
	check(is_equal_approx(apoc.hp,907.25) and apoc.special.has("plate_flash"),"limiter after continuous drive absorbs damage")
	apoc.velocity=Vector2.ZERO;Unit.FactionCards.tick(apoc,0.1)
	check(apoc.use_ability(UnitSkillLayout.index(apoc,1)),"Apocalypse arms twin gun")
	var sov=preload("res://scripts/units/ra3_soviet.gd")
	apoc.attack_target=foe;apoc.attack_ordered=true;apoc.turret_angle=0;apoc.hull_angle=0
	for barrel in 2:
		check(sov.fire(apoc),"actual left/right fire "+str(barrel))
		shot=w.projectiles_root.get_child(-1)
		before=foe.hp
		sov.advance(shot,1)
		var base:=Ra3Expansion.raw_damage(float(apoc.data.weapon.damage),"CANNON",foe)
		check(is_equal_approx(before-foe.hp,base*(1.174 if barrel else 1.0)),"calibration shell damage "+str(barrel))
		apoc.special.soviet_mounts.R3APOC.left=0.0
	check_twin_windows(w,p)
	var rhino=w.spawn_unit("HTNK","ally",p)
	rhino.hull_angle=0;rhino.hp=1000
	check(rhino.use_ability(UnitSkillLayout.index(rhino,1)),"Rhino W")
	rhino.receive_hit(100,"shell",{},foe,"RA3_EXPANSION")
	check(is_equal_approx(rhino.hp,926.1) and rhino.special.has("plate_flash"),"rhino front reduction and flash")
	foe.position=p-Vector2(100,0)
	rhino.receive_hit(100,"shell",{},foe,"RA3_EXPANSION")
	check(is_equal_approx(rhino.hp,826.1),"rear bypasses front armor")
	check_slope_drive(w,foe)
	var dest=w.spawn_unit("DEST","ally",p)
	var water:=p+Vector2(600,0)
	w.water_rects.clear()
	w.water_rects.append(Rect2(water-Vector2(20,20),Vector2(40,40)))
	var sub=w.spawn_unit("SUB","enemy",water)
	sub.special.erase("dive_remaining")
	var other=w.spawn_unit("DEST","ally",p)
	var plane=w.spawn_unit("ASW","ally",p)
	plane.logistics.carrier_owner=dest
	for rank in 4:
		BattleRequest.combat_context.card_ranks.ap_buoy=rank
		var tester=w.spawn_unit("DEST","ally",p)
		var idx:=UnitSkillLayout.index(tester,1)
		var base:float=[32,30,28,25][rank]
		check(tester.use_ability(idx,water) and tester.ability_info(idx).cooldown==base and is_equal_approx(tester.ability_at(idx).cd_left,base/tester.skill_power),"buoy cast uses configured rank cooldown "+str(rank))
		var ab:Ability=tester.ability_at(idx)
		ab.tick(ab.cd_left-0.01)
		check(not tester.use_ability(idx,water),"buoy rejects early recast")
		ab.tick(0.02)
		check(tester.use_ability(idx,water),"buoy ready after full cooldown")
	var slot:=UnitSkillLayout.index(dest,1)
	check(not dest.use_ability(slot,p) and dest.ability_ready(slot),"invalid buoy does not spend cooldown")
	check(dest.use_ability(slot,water) and is_equal_approx(dest.special.buoy_left,5.8),"rank three buoy")
	check(w.actor_visible_to("ally",sub,dest) and w.actor_visible_to("ally",sub,plane) and not w.actor_visible_to("ally",sub,other),"only owning squadron can use buoy")
	var scout=w.spawn_unit("DLPH","ally",p)
	foe.hp=1000
	foe.receive_hit(0.1,"bullet",{},scout)
	check(not scout.special.has("contact_target"),"zero quantized damage creates no contact")
	for n in 3:
		before=foe.hp
		foe.receive_hit(100,"shell",{},scout,"RA3_EXPANSION")
		check(is_equal_approx(before-foe.hp,100 if n==0 else 107.25),"surface vehicle gets the nonstacking mark")
	rhino.receive_hit(10,"shell",{},scout,"RA3_EXPANSION")
	check(is_same(scout.special.get("contact_target"),foe),"friendly damage cannot replace the mark")
	bystander.receive_hit(10,"shell",{},scout,"RA3_EXPANSION")
	check(is_same(scout.special.get("contact_target"),foe),"switching targets during cooldown preserves existing mark")
	Unit.FactionCards.tick(scout,22.0)
	bystander.receive_hit(10,"shell",{},scout,"RA3_EXPANSION")
	check(is_same(scout.special.get("contact_target"),bystander),"new target is marked once cooldown completes")
	sub.hp=1000
	for n in 3:
		before=sub.hp
		sub.receive_hit(100,"shell",{},plane,"RA3_EXPANSION")
		check(is_equal_approx(before-sub.hp,100 if n==0 else 107.25),"ASW credits ship, Ping never stacks "+str(n))
	foe.receive_hit(1,"shell",{},dest,"RA3_EXPANSION")
	check(is_same(dest.special.contact_target,sub),"ASW trigger puts parent ship on cooldown")
	var flak=w._place_building("NAFLAK","ally",p,true)
	var air=w.spawn_unit("R3HARBINGER","enemy",p+Vector2(20,0))
	air.hp=1000
	for n in 4:
		before=air.hp
		air.receive_hit(100,"shell",{},flak,"RA3_EXPANSION")
		check(is_equal_approx(before-air.hp,111.6 if n==2 else 100.0),"building third AA hit "+str(n))
	var codec=preload("res://scripts/save/battle_snapshot.gd").new()
	var snapshot:=codec.capture(w)
	var ship_idx:int=codec.ids[dest]
	var sub_idx:int=codec.ids[sub]
	var flak_idx:int=codec.ids[flak]
	codec.restore(w,snapshot)
	var restored=codec.objects[ship_idx]
	check(codec.error.is_empty() and is_same(restored.special.contact_target,codec.objects[sub_idx]) and is_equal_approx(restored.special.buoy_left,5.8) and restored.ability_at(slot).cooldown==25 and is_equal_approx(restored.ability_at(slot).cd_left,25/restored.skill_power) and is_equal_approx(restored.special.contact_cd,22.0),"save restores the buoy timer and Ping target")
	check(codec.objects[flak_idx].special.barrage_count==1 and is_equal_approx(codec.objects[flak_idx].special.flak_card,0.116),"save restores flak counter and rank")
	scene.free()

# Exercise reload, alternating barrels and shell flight at maximum range without clearing cooldowns.
func check_twin_windows(world,origin:Vector2) -> void:
	var sov=preload("res://scripts/units/ra3_soviet.gd")
	var enemy=world.spawn_unit("HTNK","enemy",origin+Vector2(225,0))
	enemy.hp=1000000
	var rolled:={}
	for trial in 8:
		var rank:int=[0,1,2,3,0,1,2,3][trial]
		BattleRequest.combat_context.card_ranks.ap_twin=rank
		var tank=world.spawn_unit("R3APOC","ally",origin)
		tank.attack_target=enemy
		tank.attack_ordered=true
		tank.hull_angle=0
		tank.turret_angle=0
		var heroic:=trial>=4
		if heroic:tank._grant_veteran(3,false)
		enemy.position=origin+Vector2(tank.attack_range-0.01,0)
		var skill:int=UnitSkillLayout.index(tank,1)
		# Cast after the first left barrel has already launched.
		check(sov.fire(tank),"pre-cast left shot")
		var rounds:Array=[world.projectiles_root.get_child(-1)]
		if rank==2:
			# Select reproducible seeds for both sides of the configured 50% threshold.
			for rng_seed in 100:
				seed(rng_seed)
				if (randf()<0.5)==heroic:
					seed(rng_seed)
					break
		check(tank.use_ability(skill),"arm rank %d"%rank)
		var base_cd:float=[24,23,22.5,22][rank]
		check(tank.ability_info(skill).cooldown==base_cd and is_equal_approx(tank.ability_at(skill).cd_left,base_cd/tank.skill_power),"Twin cast starts ranked cooldown "+str(rank))
		check(is_equal_approx(tank.ability_at(skill).duration,[2.0,4.0,5.5,6.0][rank]),"duration grows with rank")
		var dt:=1.0/60.0
		var hit_times:Array[float]=[]
		var elapsed:=0.0
		var start:=-1.0
		for frame in 660:
			Unit.FactionCards.tick(tank,dt)
			sov.tick(tank,dt)
			if sov.fire(tank):
				rounds.append(world.projectiles_root.get_child(-1))
				if start<0 and tank.special.has("twin_left"):
					start=elapsed
					check(rounds.back().splinters.cannon_index==0 and elapsed>2.0/(1.2 if heroic else 1.0),"precast partial volley cannot consume the window")
			for shell in rounds.duplicate():
				var before:float=enemy.hp
				sov.advance(shell,dt)
				if not shell.is_queued_for_deletion():continue
				rounds.erase(shell)
				var base:=CombatMath.with_offense(Ra3Expansion.raw_damage(shell.splinters.amount,shell.splinters.kind,enemy),shell.attacker_bonus)
				var dealt:float=before-enemy.hp
				if dealt>base*1.001:
					check(start>=0 and shell.splinters.cannon_index==1 and is_equal_approx(dealt,base*(1+tank.ability_at(skill).value)),"only paired right shells get full bonus")
					hit_times.append(snappedf(elapsed-start,0.01))
			elapsed+=dt
		var expected:int=[1,2,3 if heroic else 2,3][rank]
		check(hit_times.size()==expected,"rank %d heroic %s expected %d right hits, got %s"%[rank,heroic,expected,hit_times])
		if rank==2:rolled[hit_times.size()]=true
		print("TWIN rank=",rank," heroic=",heroic," impact times=",hit_times)
	check(rolled.has(2) and rolled.has(3),"rank two covers both third-shell outcomes")

func check_yr_talents() -> void:
	const Talents=preload("res://scripts/units/yr_unit_talents.gd")
	BattleRequest.configure_skirmish(MatchRules.EXTENDED,{"map_size":2400})
	var scene=load("res://scenes/battle.tscn").instantiate()
	add_child(scene)
	var world=scene.battle
	world.fog=null
	world.water_rects.clear()
	world.path_service.set_water([])
	world.paused=false
	var loadout:Dictionary=BattleRequest.combat_context.unit_talents
	for uid in ["MTNK","HTNK","CLEG","DESO"]:
		var key:String=Talents.GROWTH if uid=="DESO" else MetaProgress.talent_options(uid).keys()[0]
		loadout[uid]={key:0}
		for tier in 4:
			loadout[uid][key]=tier
			var rule:Dictionary=MetaProgress.talent_options(uid)[key]
			var expected:float=rule.base if tier==0 else rule.ranks[tier-1].value
			var unit=world.spawn_unit(uid,"ally",Vector2(750,1200))
			check(Talents.value(unit,key)==expected and Talents.enabled(unit,key),"new unit talent rank "+key+str(tier))
			world.units.erase(unit)
			unit.free()
	var origin:=Vector2(800,1200)
	var tank=world.spawn_unit("MTNK","ally",origin)
	tank.hull_angle=0
	tank.hp=tank.max_hp/2
	var old_hp:float=tank.hp
	check(UnitSkillLayout.info(tank,2).id==Talents.REVERSE,"grizzly E granted")
	world.select_unit(tank,false)
	scene.hud._cast_ability(2)
	check(world.command_mode==Talents.REVERSE,"E opens reverse aim")
	world._issue_command_at(origin-Vector2(300,0))
	check(tank.special.get(Talents.REVERSE)==origin-Vector2(165,0),"rear order clamps to three cells")
	Talents.reverse_tick(tank,0.5)
	check(tank.position.x<origin.x and tank.hull_angle==0 and is_equal_approx(tank.hp-old_hp,tank.max_hp*0.005) and is_equal_approx(tank.special.reverse_heal_left,5.5),"reverse starts one six-second heal")
	tank.order_stop()
	check(not tank.special.has(Talents.REVERSE) and tank.special.reverse_heal_left==5.5,"stop cancels reverse but retains heal")
	for tier in 4:
		loadout.MTNK[Talents.REVERSE]=tier
		var runner=world.spawn_unit("MTNK","ally",Vector2(960,900+tier*90))
		runner.hull_angle=0
		runner.hp=runner.max_hp*0.5
		check(Talents.start_reverse(runner,runner.position-Vector2(5,0)),"short reverse accepted")
		Talents.reverse_tick(runner,1.0)
		check(not runner.special.has(Talents.REVERSE) and runner.special.reverse_heal_left==2+tier,"reaching endpoint preserves timed healing")
		runner.order_move(runner.position+Vector2(0,40))
		runner.order_stop()
		runner._physics_process(0.5)
		check(is_equal_approx(runner.hp,runner.max_hp*0.515),"stationary physics tick continues healing")
		check(not Talents.start_reverse(runner,runner.position-Vector2(5,0)),"cooldown rejects repeat order while healing")
		check(is_equal_approx(runner.special.reverse_heal_left,1.5+tier),"new order cannot refresh heal")
		Talents.tick_reverse_heal(runner,10.0)
		check(not runner.special.has("reverse_heal_left") and is_equal_approx(runner.hp,runner.max_hp*(0.5+0.01*(3+tier))),"rank caps total healing including last partial tick")
	var wall=world._place_building("NAWALL","enemy",tank.position-Vector2(65,0),true)
	world._refresh_pathing()
	old_hp=tank.hp
	check(not Talents.start_reverse(tank,wall.position-Vector2(60,0)) and tank.hp==old_hp,"blocked reverse route grants no movement or healing")
	var chrono=world.spawn_unit("CLEG","ally",origin+Vector2(0,100))
	var victim=world.spawn_unit("HTNK","enemy",chrono.position+Vector2(40,0))
	chrono.attack_target=victim
	chrono.attack_ordered=true
	var gun:Dictionary=chrono._active_weapon()
	AlliedAbilities.special_shot(chrono,victim,gun)
	AlliedAbilities.channel(chrono,0.2)
	var work:float=chrono.special.temporal_work
	AlliedAbilities.release_temporal(chrono)
	check(not AlliedAbilities.frozen(victim) and chrono.special[Talents.BOOK].left==11,"bookmark frees target immediately")
	AlliedAbilities.special_shot(chrono,victim,gun)
	check(is_equal_approx(chrono.special.temporal_work,work/2) and not chrono.special.has(Talents.BOOK),"bookmark consumes saved half work")
	AlliedAbilities.release_temporal(chrono)
	var new_target=world.spawn_unit("MTNK","enemy",victim.position+Vector2(10,0))
	chrono.order_target(new_target,false,false)
	check(not chrono.special.has(Talents.BOOK),"different order discards bookmark")
	AlliedAbilities.special_shot(chrono,new_target,gun)
	AlliedAbilities.channel(chrono,0.1)
	AlliedAbilities.release_temporal(chrono)
	chrono.order_stop()
	chrono._physics_process(11.01)
	check(not chrono.special.has(Talents.BOOK),"timed-out bookmark cannot be reused")
	var rhino=world.spawn_unit("HTNK","ally",Vector2(1400,1450))
	var main=world._place_building("NAPOWR","enemy",Vector2(1450,1350),true)
	var neighbor=world._place_building("NAPOWR","enemy",main.position+Vector2(100,0),true)
	var friend=world._place_building("NAPOWR","ally",main.position-Vector2(100,0),true)
	var shell:=Projectile.new()
	shell.setup(rhino.position,main,rhino.weapon,50,rhino.bonuses,"ally",rhino)
	world.projectiles_root.add_child(shell)
	var before:float=neighbor.hp
	var friendly:float=friend.hp
	var second=world._place_building("NAPOWR","enemy",main.position+Vector2(0,100),true)
	var third=world._place_building("NAPOWR","enemy",main.position+Vector2(0,-110),true)
	var secondary_hp:float=second.hp
	shell._explode()
	var secondary_hits:=int(neighbor.hp<before)+int(second.hp<secondary_hp)+int(third.hp<secondary_hp)
	check(secondary_hits==2,"split is capped at two buildings without recursion")
	check(friend.hp==friendly and (neighbor.has_meta("reaper_split_fx") or second.has_meta("reaper_split_fx")),"building split damages and marks enemy neighbor only")
	var deso=world.spawn_unit("DESO","ally",Vector2(550,640))
	deso.set_deployed(true,false)
	var exposed=world.spawn_unit("HTNK","enemy",deso.position+Vector2(50,0))
	check(not BattleRequest.has_unit_talent("DESO","deso_sample","ally"),"retired sampling is unavailable")
	exposed.position=deso.position+Vector2(20,0)
	var control=world.spawn_unit("HTNK","ally",deso.position-Vector2(20,0))
	exposed.hp=5000
	control.hp=5000
	Unit.SovietSpecials.drop_radiation(deso)
	var was_paused:=get_tree().paused
	get_tree().paused=false
	Unit.SovietSpecials.tick_world(world,2.9)
	check(exposed.hp==control.hp and control.hp<5000,"real deployed field deals ordinary uncharged pulses")
	Unit.SovietSpecials.tick_world(world,1.5)
	get_tree().paused=was_paused
	check(exposed.hp==control.hp,"radiation never adds retired sampling bonus after three seconds")
	var codec=preload("res://scripts/save/battle_snapshot.gd").new()
	var snapshot:=codec.capture(world)
	var tank_id:int=codec.ids[tank]
	var emitter_id:int=codec.ids[deso]
	codec.restore(world,snapshot)
	check(codec.objects[tank_id].special.reverse_heal_left==5.5,"battle save restores remaining heal after stopping")
	var restored_site:Dictionary=world.allied_state.rad_sites.back()
	check(codec.error.is_empty() and not restored_site.has("samplers"),"restored radiation has no retired sampling")
	var ui=load("res://scenes/meta.tscn").instantiate()
	add_child(ui)
	for uid in ["MTNK","CLEG","HTNK","DESO"]:
		var key:String=Talents.GROWTH if uid=="DESO" else MetaProgress.talent_options(uid).keys()[0]
		ui._unit_sel=uid
		ui._set_page("units")
		ui._show_talent_demo(uid,key,3)
		var panel=ui.get_node("TalentDemo")
		var preview=panel.find_child("Preview",true,false)
		check(preview.actor.unit_id==uid and preview.demo==key and preview.rank==3,"refit opens matching YR preview")
		if DisplayServer.get_name()!="headless":
			await RenderingServer.frame_post_draw
		panel.free()
	ui.free()
	BattleRequest.rules_mode=MatchRules.RA2
	check(not Talents.enabled(codec.objects[emitter_id],Talents.GROWTH),"classic disables YR talents")
	scene.free()

func check_contact_fog() -> void:
	BattleRequest.configure_skirmish(MatchRules.EXTENDED,{"map_size":2400})
	var scene=load("res://scenes/battle.tscn").instantiate()
	add_child(scene)
	var world=scene.battle
	for actor in world.units+world.buildings: actor.free()
	world.units.clear()
	world.buildings.clear()
	var ship=world.spawn_unit("DEST","ally",Vector2(180,180))
	var tank=world.spawn_unit("HTNK","enemy",Vector2(1700,800))
	var infantry=world.spawn_unit("E1","enemy",Vector2(1820,800))
	var plane=world.spawn_unit("R3HARBINGER","enemy",Vector2(1800,1700))
	var fog=preload("res://scripts/world/fog_of_war.gd").new()
	world.add_child(fog)
	world.fog=fog
	fog.setup(world)
	tank.hp=5000
	for rank in 4:
		BattleRequest.combat_context.card_ranks.ps_contact=rank
		var duration:float=[3.0,3.5,4.0,5.0][rank]
		var old:=Vector2(1700,800)
		tank.position=old
		infantry.position=old+Vector2(120,0)
		fog.rebuild()
		check(not world.actor_visible_to("ally",tank) and not infantry.visible,"no contact beyond scout sight")
		tank.receive_hit(10,"shell",{},ship,"RA3_EXPANSION")
		fog.rebuild()
		var cooldown:float=[30,28,25,22][rank]
		check(ship.special.contact_cd==cooldown,"configured first-mark cooldown at rank "+str(rank))
		check(is_equal_approx(ship.special.contact_left,duration) and infantry.visible,"first damage shares unit vision at rank "+str(rank))
		tank.position=Vector2(1800,1700)
		fog.rebuild()
		check(not infantry.visible and plane.visible and not fog.is_visible_at("ally",old),"moving mark loses old footprint and reveals new neighbors")
		Unit.FactionCards.tick(ship,duration-0.01)
		tank.receive_hit(10,"shell",{},ship,"RA3_EXPANSION")
		check(is_equal_approx(ship.special.contact_left,duration),"same-target damage refreshes duration")
		Unit.FactionCards.tick(ship,duration+0.01)
		fog.rebuild()
		check(not plane.visible and not tank.visible and fog.is_explored_at("ally",tank.position),"expiry leaves explored terrain only")
		Unit.FactionCards.tick(ship,cooldown-2*duration-0.01)
		tank.receive_hit(10,"shell",{},ship,"RA3_EXPANSION")
		check(not ship.special.has("contact_target") and is_equal_approx(ship.special.contact_cd,0.01),"no early retrigger or reset on refresh")
		Unit.FactionCards.tick(ship,0.01)
	plane.receive_hit(1,"shell",{},ship,"RA3_EXPANSION")
	fog.rebuild()
	check(plane.visible and is_same(ship.special.contact_target,plane),"aircraft can carry a report at cooldown boundary")
	Unit.FactionCards.tick(ship,22.0)
	infantry.receive_hit(1,"shell",{},ship,"RA3_EXPANSION")
	fog.rebuild()
	check(infantry.visible and not plane.visible,"mark transfers to infantry and closes previous sight")
	var dolphin=world.spawn_unit("DLPH","ally",ship.position)
	infantry.receive_hit(1,"shell",{},dolphin,"RA3_EXPANSION")
	Unit.FactionCards.tick(ship,6.0)
	fog.rebuild()
	check(infantry.visible and Unit.FactionCards.contact_matches(dolphin,infantry),"expiring one report leaves a second reporter's sight")
	dolphin.receive_hit(dolphin.hp*100,"shell",{},tank,"RA3_EXPANSION")
	fog.rebuild()
	check(not infantry.visible and not infantry.special.has("contact_reporters"),"loss of the last reporter ends shared sight")
	scene.free()

func check_slope_drive(world,attacker) -> void:
	var dt:=1.0/60.0
	for rank in 4:
		BattleRequest.combat_context.card_ranks.ap_slope=rank
		var tank=world.spawn_unit("HTNK","ally",Vector2(900+rank*100,1100))
		tank.collision_mask=0
		tank._hull_prev=0
		tank.hull_angle=0
		var slot:=UnitSkillLayout.index(tank,1)
		var normal:float=tank.move_speed
		check(tank.use_ability(slot),"Rhino activates stationary rank "+str(rank))
		Unit.FactionCards.tick(tank,2.8)
		check(tank.move_speed==normal and not tank.special.has("slope_speed"),"waiting does not grant speed")
		tank.velocity=Vector2.RIGHT*normal
		Unit.FactionCards.tick(tank,dt)
		check(not tank.special.has("slope_speed"),"blocked movement intent does not start timer")
		tank.move_and_collide(tank.velocity*dt)
		Unit.FactionCards.tick(tank,dt)
		var expected:float=normal*(1.0+[0.10,0.25,0.30,0.50][rank])
		tank._move_toward(tank.position+Vector2(500,0),dt,false)
		check(is_equal_approx(tank.velocity.length(),expected),"steering honors acceleration rank "+str(rank))
		attacker.position=tank.position+Vector2.RIGHT*100
		var before:float=tank.hp
		tank.receive_hit(100,"cannon",{},attacker,"RA3_EXPANSION")
		check(is_equal_approx(before-tank.hp,100*(1.0-tank.ability_at(slot).value)),"moving front armor persists")
		tank.velocity=Vector2.ZERO
		Unit.FactionCards.tick(tank,1.0)
		tank.move_and_collide(Vector2.RIGHT*2)
		Unit.FactionCards.tick(tank,0.97)
		check(float(tank.special.slope_left)<0.02 and tank.ability_info(slot).active,"restarting does not refresh moving window")
		Unit.FactionCards.tick(tank,0.02)
		check(not tank.ability_info(slot).active and is_equal_approx(tank.move_speed,normal),"two seconds end both effects")
		before=tank.hp
		tank.receive_hit(100,"cannon",{},attacker,"RA3_EXPANSION")
		check(is_equal_approx(before-tank.hp,100),"post-expiry front damage is normal")
		world.units.erase(tank)
		tank.free()
