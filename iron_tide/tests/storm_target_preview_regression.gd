extends "res://tests/allied_abilities_regression.gd"
const Preview = preload("res://scripts/ui/storm_target_preview.gd")
var preview_canvas: Node2D
var preview_draws := 0

func draw_preview() -> void:
	Preview.draw(preview_canvas,battle,Vector2(1700,1600))
	preview_draws += 1

func exercise_mode(mode: String) -> void:
	setup_logistics_scene(mode,"美国")
	battle.power_low=false
	var source=battle._place_building("GAWEAT","ally",Vector2(1800,1800),true)
	source._buildup_play=-1
	source._sw_charge=source.sw_recharge()
	var point:=Vector2(1700,1600)
	check(not Preview.footprint(battle,point).has_area(),mode+": unarmed storm has no targeting area")
	var charge: float=source._sw_charge
	battle.arm_superweapon(source)
	var area: Rect2=Preview.footprint(battle,point)
	var cells:=maxi(1,int(source.superweapon.storm.cell_spread))
	check(area.has_area() and area.get_center()==point,mode+": armed storm exposes area centered at pointer")
	check(area.size==Vector2.ONE*cells*55.0,mode+": square matches actual configured cloud grid")
	preview_canvas=Node2D.new()
	preview_canvas.draw.connect(draw_preview)
	battle.add_child(preview_canvas)
	var draws_before:=preview_draws
	preview_canvas.queue_redraw()
	await get_tree().process_frame; await get_tree().process_frame
	check(preview_draws>draws_before,mode+": real canvas callback draws preview without a screenshot")
	preview_canvas.free()
	check("落雷区域" in battle.hud.cmd_hint_label.text,mode+": targeting hint explains area confirmation")
	var shifted:=point+Vector2(120,-80)
	check(Preview.footprint(battle,shifted).position==area.position+shifted-point,mode+": preview follows pointer without changing size")
	check(source._sw_charge==charge and LightningStorm.storms(battle).is_empty(),mode+": aiming does not spend or launch")
	# These are the same discrete coordinates used by StormClouds.advance.
	for x in cells:
		for y in cells:
			var strike:=point+(Vector2(x,y)-Vector2.ONE*(cells-1)*0.5)*55.0
			check(area.has_point(strike),mode+": configured scattered cloud point is inside preview")
	var original: Dictionary=source.superweapon.duplicate(true)
	source.superweapon=source.superweapon.duplicate(true)
	source.superweapon.storm.cell_spread=4
	check(Preview.footprint(battle,point).size==Vector2(220,220),mode+": preview consumes changed spread instead of hard-coded size")
	source.superweapon=original
	battle.arm_command("")
	check(not Preview.footprint(battle,point).has_area() and source._sw_charge==charge,mode+": cancel clears preview and keeps charge")
	battle.arm_superweapon(source); battle.power_low=true
	check(not Preview.footprint(battle,point).has_area(),mode+": loss of launch readiness hides preview")
	battle.power_low=false
	battle._issue_command_at(point)
	check(source._sw_charge==0 and battle.command_mode.is_empty(),mode+": map confirmation spends charge once and exits targeting")
	check(LightningStorm.storms(battle).size()==1 and LightningStorm.storms(battle)[0].target==point,mode+": real storm starts at selected center")
	check(not Preview.footprint(battle,point).has_area(),mode+": launch removes aiming region")
	screen.free(); Ra2Sfx.stop_all(); Music.stop()
	await get_tree().process_frame
