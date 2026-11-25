extends "res://tests/base_recovery_regression.gd"
const A=preload("res://scripts/rules/academy.gd")
const F=preload("res://scripts/units/furnace_legend.gd")
const L=preload("res://scripts/rules/hero_loadouts.gd")
const Counts=preload("res://scripts/world/production_counts.gd")

func _ready() -> void:
	output_dir=OS.get_environment("IRON_TIDE_REPORT_DIR")
	if output_dir.is_empty() or not OS.get_user_data_dir().contains("CodexIronTideValidation"):get_tree().quit(2);return
	await get_tree().process_frame
	MetaProgress.reset_save()
	await preload("res://tests/hero_contract_ui_cases.gd").run(self)
	MetaProgress.reset_save()
	await preload("res://tests/card_upgrade_cost_cases.gd").run(self)
	MetaProgress.reset_save()
	await preload("res://tests/hero_contract_pool_cases.gd").run(self)
	MetaProgress.reset_save()
	for n in 20000:
		seed(n)
		if randf()<0.0035 and A.ContractPool.candidates(MetaProgress).pick_random().id=="furnace_contract":
			seed(n)
			var rows:=A.draw(MetaProgress,1,true)
			check(rows.size()==1 and rows[0].id=="furnace_contract","contract real draw")
			break
	check(not MetaProgress.skill_unlocked(F.ACTIVE),"contract alone does not unlock cards")
	MetaProgress.reset_save()
	MetaProgress.academy.card_shards=499
	check(not A.purchase(MetaProgress,"furnace_contract"),"insufficient shards")
	MetaProgress.academy.card_shards=500
	check(A.purchase(MetaProgress,"furnace_contract") and MetaProgress.academy.card_shards==0,"500 shard redemption")
	check(not A.purchase(MetaProgress,"furnace_contract"),"no duplicate contract")
	MetaProgress.academy.hero_builds={"E2":50,"E1":50}
	start(MatchRules.EXTENDED)
	BattleRequest.skirmish_config.difficulty=2
	var hero=battle.spawn_unit("E2","ally",Vector2(900,900))
	var other=battle.spawn_unit("E1","ally",Vector2(1100,1000))
	A.promote(MetaProgress,battle,"E2",hero)
	A.promote(MetaProgress,battle,"E1",other)
	var hq=battle._place_building("NACNST","enemy",Vector2(1500,900),true)
	hq.hp=1600
	hq.receive_hit(100,"shell",{},hero)
	hq.receive_hit(20000,"shell",{},other)
	check(not battle.allied_state.get("furnace_takedown",false),"assist and other named hero final blow excluded")
	var enemy=battle.spawn_unit("BORIS","enemy",Vector2(1550,1050))
	var prior:float=battle.allied_state.get("furnace_damage",0)
	enemy.hp=80
	enemy.receive_hit(20000,"shell",{},hero)
	check(battle.allied_state.get("furnace_takedown",false),"Furnace personally kills enemy hero")
	check(is_equal_approx(battle.allied_state.get("furnace_damage",0)-prior,80),"overkill excluded")
	Counts.settle(battle,true)
	Counts.settle(battle,true)
	check(MetaProgress.academy.furnace_tasks.damage==prior+80 and not MetaProgress.academy.furnace_tasks.get("peace",false),"unique settlement and hero attacked")
	await finish()
	start(MatchRules.EXTENDED)
	hero=battle.spawn_unit("E2","ally",Vector2(900,900))
	A.promote(MetaProgress,battle,"E2",hero)
	enemy=battle._place_building("NACNST","enemy",Vector2(1000,900),true)
	enemy.max_hp=10000;enemy.hp=10000
	enemy.receive_hit(20000,"shell",{},hero)
	check(battle.allied_state.get("furnace_takedown",false),"Furnace personally demolishes enemy construction yard")
	Counts.settle(battle,false)
	await finish()
	check(MetaProgress.academy.furnace_tasks.damage==10000,"damage accumulates across matches")
	start(MatchRules.EXTENDED)
	BattleRequest.skirmish_config.difficulty=2
	Counts.settle(battle,true)
	await finish()
	check(MetaProgress.skill_unlocked(F.ACTIVE) and MetaProgress.skill_unlocked(F.PASSIVE),"hard win without spawning hero grants both cards")
	MetaProgress.save();MetaProgress.load_save()
	check(L.equip(MetaProgress,"E2","active",F.ACTIVE) and L.equip(MetaProgress,"E2","passive",F.PASSIVE),"independent W/passive equipment")
	check(not MetaProgress.set_unit_skill("E2","active",0,F.ACTIVE) and not L.equip(MetaProgress,"HTNK","passive",F.PASSIVE),"ordinary conscript and other hero cannot equip")
	for rank in 4: await exercise_cards(rank)
	var panel:=preload("res://scripts/ui/furnace_contract_panel.gd").new()
	add_child(panel);panel.refresh()
	check(panel.get_child_count()==1 and preload("res://scripts/ui/progression_icon.gd").texture(F.PASSIVE)!=null,"panel and dragon icons")
	panel.free()
	await exercise_gallery()
	FileAccess.open(output_dir.path_join("result.json"),FileAccess.WRITE).store_string(JSON.stringify({"checks":checks,"failed":failed}))
	print("FURNACE checks=",checks.size()," failed=",failed)
	get_tree().quit(0 if failed==0 else 1)

func exercise_gallery() -> void:
	var ui=load("res://scenes/meta.tscn").instantiate()
	add_child(ui)
	MetaProgress.academy.erase("furnace_contract")
	MetaProgress.academy.card_shards=10
	ui._set_page("pool")
	var groups:OptionButton=ui.pool_body.get_node("TrainingGroup")
	for i in groups.item_count:
		if groups.get_item_metadata(i)=="英雄":groups.item_selected.emit(i);break
	check(ui.training_group=="英雄","fourth training group opens hero contract")
	await exercise_pool_scroll(ui)
	await exercise_expansion_previews(ui)
	var open:Button=ui.pool_body.find_child("FurnacePreview",true,false)
	var redeem:Button=ui.pool_body.find_child("FurnaceRedeem",true,false)
	check(not open.disabled and redeem.disabled,"ten shards can preview but cannot redeem")
	open.pressed.emit()
	var demo=ui.get_node("FurnaceDemo")
	check(demo.stage.mode=="furnace_contract","pool opens the combined demonstration")
	demo.set_rank(3,F.ACTIVE)
	demo.set_rank(1,F.PASSIVE)
	demo.playback.user_seek(3.5)
	await get_tree().process_frame
	var state:Dictionary=demo.stage.sample()
	check(not demo.stage.playing and state.shield==0.8 and state.guards and state.guard_left==3 and state.summon_cd==59,"combined scene uses separate ranks, lifespan and cooldown")
	demo.playback.user_seek(6)
	check(demo.stage.sample().prone and demo.stage.sample().blast_age==0.5,"damage break ripples while still prone")
	demo.stage.ending=1
	check(not demo.stage.sample().prone and demo.stage.sample().blast_age==0.5,"standing releases the shield")
	demo.stage.ending=2
	demo.playback.user_seek(11.3)
	state=demo.stage.sample()
	check(state.prone and state.shield==0 and state.blast_age<0,"natural expiration has no splash")
	demo.selects[1].pressed.emit()
	demo.playback.user_seek(3)
	check(not demo.stage.sample().air and not demo.stage.sample().guards,"W-only demonstration")
	demo.selects[2].pressed.emit()
	demo.playback.user_seek(3)
	check(not demo.stage.sample().prone and demo.stage.sample().guards,"passive can trigger independently of W")
	demo.find_child("Back",true,false).pressed.emit()
	await get_tree().process_frame
	check(not ui.has_node("FurnaceDemo") and ui._page=="pool" and MetaProgress.academy.card_shards==10 and not MetaProgress.academy.has("furnace_contract"),"close returns to pool without purchase")
	ui.pool_body.get_node("CardDemos").pressed.emit()
	var gallery=ui.get_node("FactionCardDemos")
	for id in ["furnace_contract",F.ACTIVE,F.PASSIVE]:
		for i in gallery.picker.item_count:
			if gallery.picker.get_item_metadata(i)!=id:continue
			gallery.picker.item_selected.emit(i)
			var nested=gallery.get_node("HeroDemo")
			check(nested.stage.mode==id and nested.badge.material!=null,"hero gallery demo and gold shimmer "+id)
			nested.find_child("Back",true,false).pressed.emit()
			await get_tree().process_frame
			break
	gallery.free()
	MetaProgress.academy.card_shards=500
	ui._refresh_pool()
	ui.pool_body.find_child("FurnaceRedeem",true,false).pressed.emit()
	check(MetaProgress.academy.furnace_contract and MetaProgress.academy.card_shards==0,"redeem through hero category")
	ui._refresh_pool()
	ui.pool_body.find_child("FurnacePreview",true,false).pressed.emit()
	check(ui.has_node("FurnaceDemo"),"owned contract still opens")
	ui.get_node("FurnaceDemo").free()
	ui._set_page("heroes")
	for id in [F.ACTIVE,F.PASSIVE]:
		ui.heroes.equipment.demo_requested.emit(id,"E2")
		demo=ui.get_node("FurnaceDemo")
		check(demo.stage.mode==id and demo.return_text=="返回英雄养成","hero equipment routes to its own demonstration "+id)
		demo.free()
	ui.free()
	await get_tree().process_frame
	await get_tree().process_frame

func exercise_pool_scroll(ui) -> void:
	ui.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
	for resolution in [Vector2(1280,720),Vector2(1600,900),Vector2(2048,1152)]:
		ui.size=resolution
		ui.pool_scroll.scroll_vertical=0
		for frame in 8: await get_tree().process_frame
		var scroll:ScrollContainer=ui.pool_scroll
		var bar:=scroll.get_v_scroll_bar()
		check(scroll.get_global_rect().end.y<=ui.get_global_rect().end.y and scroll.size.y>0,"pool viewport fits window "+str(resolution))
		check(bar.max_value>bar.page,"four hero contracts overflow into scroll range "+str(resolution))
		var tabs_y:float=ui.pool_tab.global_position.y
		scroll.scroll_vertical=int(bar.max_value)
		for frame in 3: await get_tree().process_frame
		var bottom:Control=ui.pool_body.get_child(ui.pool_body.get_child_count()-1)
		check(bottom.get_global_rect().end.y<=scroll.get_global_rect().end.y+1,"last catalog line reachable at bottom "+str(resolution))
		check(is_equal_approx(tabs_y,ui.pool_tab.global_position.y),"page tabs remain fixed while scrolling "+str(resolution))
		var last_hero:Control=ui.pool_body.get_node("HeroContract_HTNK")
		scroll.ensure_control_visible(last_hero)
		for frame in 3: await get_tree().process_frame
		check(last_hero.get_global_rect().intersects(scroll.get_global_rect()),"last hero contract can be brought into view "+str(resolution))
	ui._set_page("heroes")
	check(not ui.pool_scroll.visible,"pool scroll region hides on another page")
	ui._set_page("pool")
	check(ui.pool_scroll.visible and ui.pool_body.visible,"pool scroll region returns with pool page")
	ui.pool_scroll.scroll_vertical=0
	for frame in 8: await get_tree().process_frame

func exercise_expansion_previews(ui) -> void:
	var before:Dictionary=MetaProgress.academy.duplicate(true)
	var currency:Dictionary=MetaProgress.currency.duplicate(true)
	var unlocked:Array=MetaProgress.unlocked_skills.duplicate()
	for hero_id in preload("res://scripts/rules/expansion_contracts.gd").cards():
		var panel=ui.pool_body.get_node_or_null("HeroContract_"+hero_id)
		check(panel!=null and panel.is_visible_in_tree(),"pool exposes hero contract "+hero_id)
		if panel==null:continue
		for id in preload("res://scripts/rules/expansion_contracts.gd").cards()[hero_id]:
			var button:Button=panel.find_child("Demo_"+id,true,false)
			check(button!=null and not button.disabled,"unowned card can preview "+id)
			if button==null:continue
			button.pressed.emit()
			var gallery=ui.get_node_or_null("FactionCardDemos")
			check(gallery!=null,"pool opens hero card demo "+id)
			if gallery==null:continue
			check(gallery.stage.card==id and gallery.refit_unit==hero_id,"preview routes to correct hero and skill "+id)
			for rank in 4:
				gallery.levels.item_selected.emit(rank)
				gallery.playback.user_seek(3)
				check(gallery.stage.preview_rank==rank and not gallery.summary.text.is_empty(),"preview rank "+id+str(rank))
			var back:Button=null
			for child in gallery.find_children("*","Button",true,false):
				if child.text=="返回卡池":back=child
			check(back!=null,"hero card demo returns to pool "+id)
			if back!=null:back.pressed.emit()
			else:gallery.queue_free()
			await get_tree().process_frame
			check(not ui.has_node("FactionCardDemos") and ui._page=="pool" and ui.training_group=="英雄","return preserves hero category "+id)
	check(MetaProgress.academy==before and MetaProgress.currency==currency and MetaProgress.unlocked_skills==unlocked,"hero previews do not purchase or change progression")

func exercise_cards(rank:int) -> void:
	MetaProgress.academy.get_or_add("levels",{})[F.ACTIVE]=rank
	MetaProgress.academy.levels[F.PASSIVE]=rank
	start(MatchRules.EXTENDED)
	var h=battle.spawn_unit("E2","ally",Vector2(1100,1100))
	A.promote(MetaProgress,battle,"E2",h)
	var i:=UnitSkillLayout.index(h,1)
	battle.select_unit(h,false)
	check(i>=0 and battle.request_ability(i)==1 and h.is_prone(),"deploys through HUD command rank %d"%rank)
	if i<0 or not h.special.has(F.STANCE):await finish();return
	check(is_equal_approx(h.skills[i].cd_left,[120,80,70,50][rank]) and not F.ACTIVE in preload("res://scripts/units/auto_w.gd").SUPPORTED,"manual cooldown")
	check(is_equal_approx(Unit.TankHero.Shield.amount(h),h.max_hp*[0.5,0.6,0.65,0.8][rank]),"shield size")
	h.special.hero_speed_floor=900
	h.add_buff("speed",20,4,"test")
	h._recompute_bonuses()
	check(is_equal_approx(h.move_speed,h._base_speed*[0.05,0.1,0.12,0.15][rank]),"locked crawl speed")
	var foe=battle.spawn_unit("E2","enemy",h.position+Vector2(55,0))
	var far=battle.spawn_unit("E2","enemy",h.position+Vector2(90,0))
	var buddy=battle.spawn_unit("E2","ally",h.position+Vector2(-50,0))
	var old:float=foe.hp
	var multiplier: float = [2.0, 2.25, 2.5, 3.0][rank]
	var reference:float = h._base_atk * multiplier
	check(is_equal_approx(h.bonuses.attack_bonus,reference),"ranked Furnace deployment firepower")
	var standing_bonuses: Dictionary = h.bonuses.duplicate()
	standing_bonuses.attack_bonus = h._base_atk
	var standing_damage := CombatMath.full_damage(h._active_weapon(),foe.armor,standing_bonuses,null,foe.ra2_armor,0.0,foe)
	var prone_damage := CombatMath.full_damage(h._active_weapon(),foe.armor,h.bonuses,null,foe.ra2_armor,0.0,foe)
	check(is_equal_approx(prone_damage,standing_damage * multiplier),"actual weapon damage scales by stance rank")
	check("本级卧倒攻击 %s 倍" % A.skill_number(multiplier) in A.skill_description(GameData.get_skill(F.ACTIVE),rank),"card tooltip reports current attack multiplier")
	if rank%2==0:
		for shot in 40:
			if Unit.TankHero.Shield.amount(h)<=0:break
			h.receive_hit(h.max_hp*0.1,"bullet")
		check(foe.hp<old,"ordinary shield break splashes")
		old=foe.hp
		h.use_ability(i)
		check(foe.hp==old,"no double splash on standing")
	else:
		h.use_ability(i)
		check(foe.hp<old,"standing with shield splashes")
	var remaining:float=h.skills[i].cd_left
	check(not h.is_prone() and battle.request_ability(i)==1 and h.is_prone(),"W redeploys during shield cooldown")
	screen.hud._rebuild_ability_bar()
	screen.hud.ability_box.notification(Container.NOTIFICATION_SORT_CHILDREN)
	var passive_icon:TextureRect = screen.hud.ability_box.get_node("PassiveSkillIcon")
	var active_icon:TextureRect = screen.hud._ability_btns[1].get_meta("skill_texture")
	check(passive_icon.size == active_icon.size and passive_icon.material != null and passive_icon.tooltip_text==h.passive_desc(),"passive fits the active card artwork size and retains shimmer and tooltip")
	screen.hud._update_ability_live()
	var button: Button = screen.hud._ability_btns[1]
	check(not button.disabled and button.get_node("CooldownClock").visible and "起身 · 盾" in button.get_meta("name_label").text,"W remains clickable and labels its shield countdown")
	check(Unit.TankHero.Shield.amount(h)==0 and h.skills[i].cd_left==remaining and is_equal_approx(h.bonuses.attack_bonus,reference),"unshielded stance retains firepower and recharge")
	old=foe.hp
	check(battle.request_ability(i)==1 and not h.is_prone() and foe.hp==old and h.skills[i].cd_left==remaining,"standing without shield neither bursts nor restarts recharge")
	check(is_equal_approx(h.bonuses.attack_bonus,h._base_atk),"standing removes Furnace attack multiplier")
	check(is_equal_approx(buddy.bonuses.attack_bonus,buddy._base_atk),"ordinary conscript attack unchanged")
	check(far.hp==far.max_hp and buddy.hp==buddy.max_hp,"splash radius and friendly exclusion")
	var plane=battle.spawn_unit("JUMPJET","enemy",h.position+Vector2(110,0))
	plane.logistics.air_lift=1.0
	F.tick(h,0.3)
	var cars:Array=battle.units.filter(func(u):return u.special.has(F.GUARD))
	check(cars.size()==2 and h.special.get("furnace_flak_cd",0)==60,"paired flak vehicles and sixty-second cooldown")
	if cars.size()==2:
		var baseline=battle.spawn_unit("HTK","ally",Vector2(600,600))
		var car=cars[0]
		check(is_equal_approx(car.max_hp,baseline.max_hp*[0.5,1.5,1.8,2.0][rank]) and is_equal_approx(car.special[F.GUARD].rate,[1,1.2,1.25,1.3][rank]),"trained HP and shot rate")
		var life:float=[2,4,5,7][rank]
		F.tick(car,life/2)
		check(is_equal_approx(car.hp,car.max_hp*0.75),"accelerating decay")
		F.tick(car,life/2)
		check(car._dead and car.hp==0,"expires on schedule")
		F.tick(h,59.9)
		check(battle.units.filter(func(u):return u.special.has(F.GUARD)).size()==2,"no summons before 60s")
		F.tick(h,0.11)
		check(battle.units.filter(func(u):return u.special.has(F.GUARD)).size()==4,"still-visible air contact retriggers at sixty seconds")
		h.skills[i].cd_left=0
		h.use_ability(i)
		check(Unit.TankHero.Shield.amount(h)>0 and h.skills[i].cd_left>0,"next deployment grants a shield after recharge")
		old=foe.hp
		F.tick(h,10.0)
		check(foe.hp==old and h.special.has(F.STANCE) and Unit.TankHero.Shield.amount(h)==0,"natural expiry keeps stance without burst")
		if rank==3:
			var codec=preload("res://scripts/save/battle_snapshot.gd").new()
			var snapshot:Dictionary=codec.capture(battle)
			codec.restore(battle,snapshot)
			var restored=battle.units.filter(func(u):return u.special.get("academy_hero")=="E2")[0]
			check(is_equal_approx(restored.bonuses.attack_bonus,restored._base_atk * 3.0),"loaded prone hero restores rank three firepower")
			check(restored.special.has(F.STANCE) and is_equal_approx(restored.special.furnace_flak_cd,50.0) and UnitSkillLayout.index(restored,1)>=0,"loaded battle preserves stance, summon cooldown and W")
	await finish()
