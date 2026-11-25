extends "res://tests/base_recovery_regression.gd"
const Status=preload("res://scripts/ui/unit_status.gd")
const Expansion=preload("res://scripts/units/expansion_visual.gd")

func _ready() -> void:
	output_dir=OS.get_environment("IRON_TIDE_REPORT_DIR")
	if output_dir.is_empty() or not OS.get_user_data_dir().contains("CodexIronTideValidation"):get_tree().quit(2);return
	MetaProgress.reset_save()
	start(MatchRules.EXTENDED)
	if battle.fog!=null:battle.fog.free();battle.fog=null
	var audited:Array=[]
	for id in GameData.unit_index:
		var actor=battle.spawn_unit(id,"ally",Vector2(1200,1200))
		check(actor!=null,"unit catalog status adapter spawns "+id)
		if actor==null:continue
		actor.add_buff("attack",10,.2,"火力提升")
		actor.add_buff("tesla_emp",4,0,"电磁瘫痪")
		var before:Dictionary=actor.special.duplicate(true)
		var buffs_before:Array=actor.buffs.duplicate(true)
		var entries:Array=actor.buff_entries()
		check(entries.any(func(e):return e.kind=="attack") and entries.any(func(e):return e.kind=="tesla_emp"),"all unit kinds share ordinary buff and debuff cells "+id)
		var ids:Array=[]
		for e in entries:
			check(not ids.has(e.id) and not Status.tooltip(e).is_empty() and Status.Icons.texture(e.icon)!=null,"unique status and tooltip and icon "+id+"/"+e.id)
			ids.append(e.id)
		check(actor.special==before and actor.buffs==buffs_before,"status inspection does not mutate gameplay "+id)
		audited.append(id)
		battle.units.erase(actor);actor.free()
		await get_tree().process_frame
	await check_empty_and_scrap_bar()
	preload("res://tests/world_status_fade_cases.gd").run(self)
	check_chrono_countdown()
	check_chrono_ivan()
	var hero=battle.spawn_unit("E1","ally",Vector2(1200,1200))
	hero.passive={"id":"ps_watch_succession"}
	hero.special.progression_v1={"heat_charges":2,"arc_count":1,"scrap":[5.0,12.0],"mark":{"left":4.0,"charges":3},"dive_boost":2.0,"dive_cloak":1.0}
	hero.special.chrono_left=3.0
	hero.special.ivan_bomb={"left":5.0}
	hero.add_buff("attack",10,.2,"火力提升")
	var hud=screen.hud
	hero.add_buff("speed",1,.1,"已到期状态")
	for buff in hero.buffs:
		if buff.kind=="speed":buff.left=0
	check(not hero.buff_entries().any(func(e):return e.kind=="speed"),"expired ordinary buffs never appear as permanent states")
	battle.select_unit(hero,false);battle._emit_selection()
	hud._rebuild_buff_bar()
	check(hud._buff_chips.size()==hero.buff_entries().size(),"all simultaneous expansion statuses get independent HUD cells")
	var heat=hud._buff_chips["expansion_heat_charges"]
	var scrap=hud._buff_chips["expansion_scrap"]
	check(heat.tooltip_text.contains("层数：2") and scrap.tooltip_text.contains("12"),"stack count and individual armor durability are in tooltips")
	hero.special.progression_v1.heat_charges=3
	hero.special.progression_v1.scrap=[8.0]
	hero.special.progression_v1.mark.left=2
	hud._update_buff_live()
	check(heat==hud._buff_chips["expansion_heat_charges"] and heat.tooltip_text.contains("层数：3") and scrap.tooltip_text.contains("层数：1"),"live stacks update independently without rebuilding cells")
	check(hud._buff_chips["expansion_mark"].tooltip_text.contains("剩余："),"timed status tooltip exposes countdown")
	hero.special.progression_v1.erase("dive_cloak")
	hud._update_buff_live()
	check(not hud._buff_chips.has("expansion_dive_cloak") and hud._buff_chips.has("expansion_dive_boost"),"expired status disappears without removing another state")
	hud._toggle_unit_menu()
	for frame in 5:await get_tree().process_frame
	check(hud.unit_menu_collapsed and hud.buff_panel.is_visible_in_tree(),"collapsed unit menu retains compact status cells")
	check(not hud.buff_panel.get_global_rect().intersects(hud.ability_panel.get_global_rect()),"compact status cells do not overlap skill buttons")
	check(not hud.buff_panel.get_global_rect().intersects(hud._compact_vitals.get_global_rect()),"compact status cells do not overlap health or experience")
	for chip in hud._buff_chips.values():
		check(chip.size.x<=28 and chip.size.y<=28 and chip.mouse_filter==Control.MOUSE_FILTER_STOP,"compact square consumes mouse input and has no wide text")
	var details:=preload("res://scripts/ui/battle_effect_details.gd").describe(hero)
	check(details.contains("层数：3"),"passive detail popup consumes same status descriptions")
	for i in 48:hero.add_buff("status_fixture_"+str(i),5,0,"溢出布局检查")
	hud._update_buff_live()
	for frame in 8:await get_tree().process_frame
	var scroll:ScrollContainer=hud.buff_box.get_parent()
	check(scroll.get_h_scroll_bar().max_value>scroll.get_h_scroll_bar().page,"many simultaneous states use horizontal scrolling")
	scroll.scroll_horizontal=int(scroll.get_h_scroll_bar().max_value)
	for frame in 4:await get_tree().process_frame
	var last:Control=hud.buff_box.get_child(hud.buff_box.get_child_count()-1)
	check(last.get_global_rect().end.x<=scroll.get_global_rect().end.x+1,"last status remains reachable when overflowing")
	check(not hud.buff_panel.get_global_rect().intersects(hud.ability_panel.get_global_rect()) and not hud.buff_panel.get_global_rect().intersects(hud._compact_vitals.get_global_rect()),"scrollbar height preserves separation from skills and vitals")
	var enemy=battle.spawn_unit("MTNK","enemy",Vector2(1400,1200))
	enemy.special.hero_stationary_shield={"hp":123.0,"left":10.0}
	var shield=enemy.buff_entries().filter(func(e):return e.id=="hero_stationary_shield")[0]
	check(not Status.tooltip(shield).contains("123"),"enemy shield tooltip preserves hidden exact health")
	hero._dead=true
	hud._update_buff_live()
	check(not hud.buff_panel.visible and hero.buff_entries().is_empty(),"dead unit hides all status cells")
	BattleRequest.combat_context.unit_talents={"R3REAPER":{"reaper_fire_control":3}}
	var tower=battle._place_building("R3REAPERTURRET","ally",Vector2(1800,1800),true)
	var mount=preload("res://scripts/buildings/ra3_reaper_emplacement.gd").mount(tower)
	mount.attack_target=enemy
	mount.special.reaper_heat={enemy:[2.0,3.0]}
	battle.select_building(tower)
	hud._rebuild_buff_bar()
	check(hud._buff_unit()==mount and hud._buff_chips.has("stack_主热"),"deployed Reaper retains its unit stack cells after converting to a building")
	check(hud._buff_chips["stack_主热"].tooltip_text.contains("层数：2"),"deployed Reaper tooltip shows actual target heat layers")
	await finish()
	FileAccess.open(output_dir.path_join("result.json"),FileAccess.WRITE).store_string(JSON.stringify({"checks":checks,"failed":failed,"audited_units":audited},"  "))
	print("UNIT STATUS units=",audited.size()," checks=",checks.size()," failed=",failed)
	get_tree().quit(0 if failed==0 else 1)

func check_chrono_countdown() -> void:
	var unit=battle.spawn_unit("CLEG","ally",Vector2(1200,1200))
	unit.special.chrono_left=6.0
	for i in 12:unit.add_buff("chrono_ui_fixture_"+str(i),10,0,"拥挤状态")
	var before:Dictionary=unit.special.duplicate(true)
	var origin:=Vector2(100,200)
	var indicator:=Status.chrono_indicator(unit,origin)
	check(indicator.text=="恢复 %.1fs"%BattleClock.real_seconds(6.0) and unit.special==before,"chrono countdown displays real remaining seconds without mutating recovery")
	var bar:Rect2=unit.hp_bar_rect()
	check(indicator.rect.end.x<origin.x+bar.position.x and indicator.rect.end.y<origin.y+bar.position.y-4,"chrono countdown clears crowded icons and health label")
	battle.select_unit(unit,false);battle._emit_selection();screen.hud._rebuild_buff_bar()
	check(screen.hud._buff_chips.has("chrono_left") and unit.buff_entries().size()>6,"chrono remains independently available with more than six world statuses")
	AlliedAbilities.tick_actor(unit,1.0)
	screen.hud._update_buff_live()
	check(Status.chrono_indicator(unit,origin).text=="恢复 %.1fs"%BattleClock.real_seconds(5.0) and screen.hud._buff_chips.chrono_left.entry.left==5.0,"world countdown and HUD cell both follow actual recovery timer")
	AlliedAbilities.tick_actor(unit,5.0)
	screen.hud._update_buff_live()
	check(Status.chrono_indicator(unit,origin).is_empty() and not screen.hud._buff_chips.has("chrono_left"),"expired recovery removes both countdown displays")
	battle.units.erase(unit);unit.free();battle.clear_selection()

func check_chrono_ivan() -> void:
	var special=preload("res://scripts/units/soviet_specials.gd")
	var unit=battle.spawn_unit("CIVAN","ally",Vector2(950,1200))
	var target=battle.spawn_unit("HTNK","enemy",Vector2(1200,1200))
	check(AlliedAbilities.teleport(unit,target.position+Vector2(42,0)),"chrono Ivan uses actual teleport entry")
	var left:float=unit.special.get("chrono_left",0.0)
	check(left>0 and not special.accepts_bomb(unit,target),"chrono Ivan recovery prevents planting")
	battle.select_unit(unit,false);battle._emit_selection();screen.hud._rebuild_buff_bar()
	check(Status.chrono_indicator(unit,Vector2.ZERO).get("text","")=="恢复 %.1fs"%BattleClock.real_seconds(left) and screen.hud._buff_chips.has("chrono_left"),"chrono Ivan real recovery appears in world and HUD")
	AlliedAbilities.tick_actor(unit,left*0.5)
	screen.hud._update_buff_live()
	check(Status.chrono_indicator(unit,Vector2.ZERO).get("text","")=="恢复 %.1fs"%BattleClock.real_seconds(left*0.5) and is_equal_approx(screen.hud._buff_chips.chrono_left.entry.left,left*0.5),"chrono Ivan displays actual remaining recovery")
	AlliedAbilities.tick_actor(unit,left)
	screen.hud._update_buff_live()
	check(Status.chrono_indicator(unit,Vector2.ZERO).is_empty() and not screen.hud._buff_chips.has("chrono_left") and special.accepts_bomb(unit,target),"chrono Ivan countdown clears when planting becomes available")
	unit._fire_shot(target)
	check(target.special.has("ivan_bomb") and not unit.special.has("ivan_bomb"),"chrono Ivan fuse belongs to planted target rather than planter")
	battle.select_unit(target,false);battle._emit_selection();screen.hud._rebuild_buff_bar()
	var fuse:float=target.special.ivan_bomb.left
	var chip=screen.hud._buff_chips.get("ivan_bomb")
	check(chip!=null and chip.entry.kind=="ivan_bomb" and chip.entry.left==fuse,"real planted bomb supplies HUD numeric countdown")
	special.tick_actor(target,1.0)
	screen.hud._update_buff_live()
	check(screen.hud._buff_chips.get("ivan_bomb")==chip and is_equal_approx(chip.entry.left,fuse-1.0),"planted fuse updates existing countdown cell")
	special.remove_bomb(target,false)
	screen.hud._update_buff_live()
	check(not screen.hud._buff_chips.has("ivan_bomb"),"disarmed bomb removes countdown")
	battle.clear_selection()
	for actor in [unit,target]:
		battle.units.erase(actor);actor.free()

func check_empty_and_scrap_bar() -> void:
	var tank=battle.spawn_unit("HTNK","ally",Vector2(1200,1200))
	var hud=screen.hud
	battle.select_unit(tank,false);battle._emit_selection()
	hud._rebuild_buff_bar()
	check(tank.buff_entries().is_empty() and hud.buff_panel.is_visible_in_tree() and hud.buff_empty.visible,"selected idle tank retains a labeled empty Buff bar")
	hud._toggle_unit_menu()
	for frame in 6:await get_tree().process_frame
	check(hud.buff_panel.is_visible_in_tree() and hud.buff_empty.is_visible_in_tree(),"collapsed idle tank keeps the empty Buff bar")
	check(not hud.buff_panel.get_global_rect().intersects(hud._compact_vitals.get_global_rect()),"empty Buff bar clears collapsed vitals")
	tank.passive={"id":"ps_spine_scrap"}
	for rank in 4:
		BattleRequest.combat_context.card_ranks.ps_spine_scrap=rank
		var before:Dictionary=tank.special.duplicate(true)
		hud._update_buff_live()
		var chip=hud._buff_chips.get("expansion_scrap")
		check(chip!=null and chip.entry.stacks==0 and chip.entry.limit==int(Expansion.R.value(tank,"ps_spine_scrap","count")),"Steel Scavenger zero stacks retain the equipped rank limit "+str(rank))
		check(tank.special==before and not hud.buff_empty.visible,"reading zero scrap does not create gameplay state "+str(rank))
	var original=hud._buff_chips["expansion_scrap"]
	tank.special.progression_v1={"scrap":[10.0,20.0]}
	hud._update_buff_live()
	check(hud._buff_chips["expansion_scrap"]==original and original.entry.stacks==2 and original.tooltip_text.contains("20"),"scrap pickup updates existing cell with real durability")
	tank.special.progression_v1.scrap.clear()
	hud._update_buff_live()
	check(hud._buff_chips["expansion_scrap"]==original and original.entry.stacks==0 and original.tooltip_text.contains("当前无额外装甲"),"depleted scrap returns to zero without hiding the bar or implying protection")
	tank.passive={}
	hud._update_buff_live()
	check(hud._buff_chips.is_empty() and hud.buff_panel.visible and hud.buff_empty.visible,"removing final effect restores empty state instead of hiding Buff bar")
	tank.add_buff("armor",5,.1,"装甲提升")
	hud._update_buff_live()
	check(hud._buff_chips.has("armor") and not hud.buff_empty.visible,"first timed buff replaces the empty state")
	tank.buffs.clear()
	hud._update_buff_live()
	check(hud.buff_panel.visible and hud.buff_empty.visible,"last timed buff ending preserves the bar")
	battle.selected_units.clear()
	hud._rebuild_buff_bar()
	check(not hud.buff_panel.visible,"cleared selection hides Buff bar")
	battle.select_unit(tank,false)
	hud._update_buff_live()
	check(hud.buff_panel.visible and hud.buff_empty.visible,"live polling restores an empty selection even with unchanged empty signature")
	hud._toggle_unit_menu()
	BattleRequest.combat_context.card_ranks.erase("ps_spine_scrap")
	battle.selected_units.clear()
	battle.units.erase(tank);tank.free()
