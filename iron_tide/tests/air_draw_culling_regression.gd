extends "res://tests/base_recovery_regression.gd"
class PoseProbe extends "res://scripts/units/unit_motion_pose.gd":
	var interpolation_calls:=0
	func hull(unit:Unit,blend:float)->float:
		interpolation_calls+=1
		return super.hull(unit,blend)

const Counters=preload("res://scripts/world/battle_call_counters.gd")
func render_counts(unit:Unit) -> Dictionary:
	unit.motion_pose.interpolation_calls=0
	var before_angles:=Vector2(unit.hull_angle,unit.turret_angle)
	Counters.start(98765)
	unit.queue_redraw()
	for i in 3:await get_tree().process_frame
	var result:={"calls":0,"builds":0}
	for row in Counters.take(98765):
		if row.name=="unit._draw":result={"calls":row.calls,"builds":row.iterations}
	Counters.stop(98765)
	result.interpolation_calls=unit.motion_pose.interpolation_calls
	check(Vector2(unit.hull_angle,unit.turret_angle)==before_angles,"draw restores authoritative bearings")
	return result
func _ready() -> void:
	output_dir=OS.get_environment("IRON_TIDE_REPORT_DIR")
	if output_dir.is_empty() or not OS.get_user_data_dir().contains("CodexIronTideValidation"):
		get_tree().quit(2);return
	start(MatchRules.EXTENDED)
	battle.fog=null
	var original_k:=Iso.K
	for id in ["MTNK"]+Array(Unit.CULLABLE_NATIVE_AIR):
		var unit:Unit=battle.spawn_unit(id,"ally",Vector2(40000,40000))
		unit.motion_pose=PoseProbe.new()
		unit.visible=true;unit.selected=false;unit.hovered=false
		check(unit._body_visibility!=null,id+" has native aircraft notifier")
		for preset in Iso.PRESETS:
			Iso.K=preset.k
			for fraction in [0.0,0.5,1.0]:
				unit.logistics.air_lift=fraction
				var lift:float=unit._visual_lift()
				var center:=RA2Art.art_dir(Vector2.UP*lift)
				check(unit._body_visibility.rect.has_point(center+Vector2(300,300)) and unit._body_visibility.rect.has_point(center-Vector2(300,300)),id+" altitude and sprite pad contained")
				for frame in range(0,mini(32,maxi(unit._ra2.get("rects",[]).size(),int(unit._ra2.get("facings",8)))),4):
					var body:=RA2Art.draw_rect(unit._ra2,unit.radius,[frame],lift,unit.RA2_SPRITE_SCALE)
					for corner in [body.position,body.end,Vector2(body.position.x,body.end.y),Vector2(body.end.x,body.position.y)]:
						check(unit._body_visibility.rect.has_point(RA2Art.art_dir(corner)),id+" native sprite corner inside culling bounds")
		Iso.K=original_k
		var outside:Dictionary=await render_counts(unit)
		check(outside.calls>0 and outside.builds==0 and outside.interpolation_calls==0,id+" offscreen draw exits before interpolation and building body",outside)
		unit.selected=true
		var selected:Dictionary=await render_counts(unit)
		check(selected.builds>0 and selected.interpolation_calls>0,id+" selected aircraft keeps full draw",selected)
		unit.selected=false;unit.special.controlled=null
		var marker:Dictionary=await render_counts(unit)
		check(marker.builds>0 and marker.interpolation_calls>0,id+" distant marker bypasses culling",marker)
		unit.special.erase("controlled")
		unit.global_position=battle.camera.get_screen_center_position()
		var inside:Dictionary=await render_counts(unit)
		check(inside.builds>0 and inside.interpolation_calls>0,id+" camera reentry redraws body",inside)
		battle.units.erase(unit);unit.free()
	Iso.K=original_k
	await finish()
	FileAccess.open(output_dir.path_join("result.json"),FileAccess.WRITE).store_string(JSON.stringify({"checks":checks,"failed":failed},"  "))
	get_tree().quit(0 if failed==0 else 1)
