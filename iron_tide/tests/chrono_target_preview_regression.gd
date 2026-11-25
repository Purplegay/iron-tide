extends "res://tests/allied_abilities_regression.gd"
const Preview=preload("res://scripts/ui/chrono_target_preview.gd")
const Chrono=preload("res://scripts/world/chronoshift.gd")
var preview_canvas:Node2D
var preview_point:=Vector2.ZERO
var preview_draws:=0

func draw_preview() -> void:
	Preview.draw(preview_canvas,battle,preview_point)
	preview_draws+=1

func check_draw(point:Vector2,label:String) -> void:
	preview_point=point
	preview_canvas=Node2D.new();battle.add_child(preview_canvas)
	preview_canvas.draw.connect(draw_preview)
	var before:=preview_draws
	preview_canvas.queue_redraw()
	await get_tree().process_frame;await get_tree().process_frame
	check(preview_draws>before,label)
	preview_canvas.free()

func exercise_mode(mode:String) -> void:
	setup_logistics_scene(mode,"美国")
	for group in ["obstacles","resource_nodes"]:
		for object in get_tree().get_nodes_in_group(group):object.free()
	for object in battle.units+battle.buildings:object.free()
	battle.units.clear();battle.buildings.clear()
	battle.water_rects=[];battle.path_service.set_water([]);battle._refresh_pathing()
	if battle.fog!=null:battle.fog.free();battle.fog=null
	battle.power_low=false
	var launcher=battle._place_building("GACSPH","ally",Vector2(1800,1800),true)
	launcher._buildup_play=-1;launcher._sw_charge=launcher.sw_recharge()
	var origin:=Vector2(1200,1200)
	var destination:=Vector2(2200,1600)
	var tank=actor("MTNK","ally",origin+Vector2(-55,-55))
	var foe=actor("HTNK","enemy",origin+Vector2(55,55))
	var edge=actor("MTNK","ally",origin+Vector2(82.5,-55))
	var outside=actor("MTNK","ally",origin+Vector2(100,0))
	var soldier=actor("E1","ally",origin)
	var charge:float=launcher._sw_charge
	check(Preview.areas(battle,origin).is_empty(),mode+" unarmed weapon has no chrono preview")
	battle.arm_superweapon(launcher)
	var preview:=Preview.areas(battle,origin)
	check(not preview.locked and preview.source.size==Vector2.ONE*165 and preview.source.get_center()==origin and not preview.target.has_area(),mode+" first phase shows actual three-cell source square")
	check("3×3" in screen.hud.cmd_hint_label.text,mode+" HUD explains source area")
	for x in range(-1,2):
		for y in range(-1,2):check(preview.source.has_point(origin+Vector2(x,y)*Chrono.CELL),mode+" all nine cells lie inside the preview")
	var selected:=Chrono.actors(battle,origin,"ally")
	check(selected.has(tank) and selected.has(foe) and selected.has(edge) and selected.has(soldier) and not selected.has(outside),mode+" rendered boundary agrees with friendly enemy infantry and edge selection")
	check(Preview.areas(battle,origin+Vector2(200,0)).source.get_center()==origin+Vector2(200,0),mode+" first phase follows pointer")
	await check_draw(origin,mode+" first-phase real canvas callback draws without screenshot")
	battle._issue_command_at(Vector2(2800,2800))
	check(not battle._chrono_source_point.is_finite() and launcher._sw_charge==charge,mode+" empty source click does not spend or lock")
	battle._issue_command_at(origin)
	preview=Preview.areas(battle,destination)
	check(preview.locked and preview.source.get_center()==origin and preview.target.get_center()==destination and preview.target.size==preview.source.size,mode+" second phase fixes source and moves matching destination square")
	check("目的地" in screen.hud.cmd_hint_label.text and "紫色" in screen.hud.cmd_hint_label.text,mode+" HUD distinguishes destination phase")
	await check_draw(destination,mode+" second-phase canvas draws both squares and connector")
	check(launcher._sw_charge==charge and tank.position==origin+Vector2(-55,-55),mode+" preview drawing never teleports or spends charge")
	check(not Preview.areas(battle,Vector2(-10,0)).can_confirm,mode+" outside-map destination is marked invalid")
	battle._issue_command_at(Vector2(-10,0))
	check(battle._chrono_source_point==origin and launcher._sw_charge==charge,mode+" invalid destination keeps aiming and charge")
	battle.power_low=true
	check(Preview.areas(battle,destination).is_empty(),mode+" power loss hides unavailable preview")
	battle.power_low=false
	battle._issue_command_at(destination)
	check(tank.position==destination+Vector2(-55,-55) and foe.position==destination+Vector2(55,55) and edge.position==destination+Vector2(82.5,-55),mode+" real teleport preserves offsets inside preview for both sides")
	check(outside.position==origin+Vector2(100,0) and soldier.hp<=0,mode+" existing outside-area and ordinary-infantry outcomes are unchanged")
	check(launcher._sw_charge==0 and battle.command_mode.is_empty() and not battle._chrono_source_point.is_finite() and Preview.areas(battle,destination).is_empty(),mode+" cast consumes once and clears both footprints")
	launcher._sw_charge=charge;battle.arm_superweapon(launcher);battle._issue_command_at(destination)
	battle.arm_command("")
	check(Preview.areas(battle,origin).is_empty() and not battle._chrono_source_point.is_finite() and launcher._sw_charge==charge,mode+" cancel clears source and target without spending")
	var weather=battle._place_building("GAWEAT","ally",Vector2(2500,2500),true)
	weather._buildup_play=-1;weather._sw_charge=weather.sw_recharge();battle.arm_superweapon(weather)
	check(Preview.areas(battle,origin).is_empty(),mode+" another weapon never displays chrono footprints")
	screen.free();Ra2Sfx.stop_all();Music.stop()
	await get_tree().process_frame
