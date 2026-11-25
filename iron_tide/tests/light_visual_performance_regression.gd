extends "res://tests/base_recovery_regression.gd"
const Anchor=preload("res://scripts/units/cosmetic_anchor.gd")
const Visual=preload("res://scripts/units/projectile_visual.gd")
class HiddenWorld extends Node2D:
	var queries:=0
	func position_visible_to(_side:String,_point:Vector2) -> bool:
		queries+=1
		return false

func _ready() -> void:
	output_dir=OS.get_environment("IRON_TIDE_REPORT_DIR")
	if output_dir.is_empty() or not OS.get_user_data_dir().contains("CodexIronTideValidation"):
		get_tree().quit(2);return
	start(MatchRules.RA2)
	var building:Building=battle.buildings[0]
	building.powered=true;building._buildup_play=-1;building.under_construction=false
	battle.power_low=false
	var requests:=0
	for i in 600:
		if building._refresh_power_warning():requests+=1
	check(requests==0,"powered healthy idle building: 600 redundant power redraw requests removed",requests)
	battle.power_low=true
	check(building._refresh_power_warning() and building._power_warning_visible,"outage starts warning")
	check(building._refresh_power_warning(),"outage breathing warning keeps animating")
	battle.power_low=false
	check(building._refresh_power_warning() and not building._power_warning_visible,"power restoration clears warning once")
	check(not building._refresh_power_warning(),"restored power does not redraw indefinitely")
	battle.power_low=true;building._refresh_power_warning();building.under_construction=true
	check(building._refresh_power_warning() and not building._power_warning_visible,"construction state clears old power warning")
	building.under_construction=false;building.powered=false
	check(not building._refresh_power_warning(),"non powered building has no warning work")
	var first:Node=Ra2Fx.play(battle,Vector2(1400,1400),"APMUZZLE",1.0,true)
	var second:Node=Ra2Fx.play(battle,Vector2(1450,1400),"APMUZZLE",1.0,true)
	check(first!=null and second!=null,"real muzzle assets instantiate")
	check(first.material==second.material and first.material.blend_mode==CanvasItemMaterial.BLEND_MODE_ADD,"bright effects share one additive material")
	var frame_before:int=first.frame
	first._process(0.2/first.fps)
	check(first.frame==frame_before,"animation stays on same frame before frame boundary")
	first._process(1.0/first.fps)
	check(first.frame>frame_before or first.is_queued_for_deletion(),"effect advances at native fps")
	first._process(100);second._process(100)
	check(first.is_queued_for_deletion() and second.is_queued_for_deletion(),"shared materials do not prevent effect cleanup")
	var root:=Node3D.new();add_child(root)
	var anchor=Anchor.new();root.add_child(anchor)
	anchor.default_origin=Vector3(2,3,4)
	for i in 32:
		anchor.angles=Vector3i(i*3,i*-2,i*5)
		anchor.offset=Vector3i(i,-i,2*i)
		anchor.dimensions=Vector3(1+i*.02,.5+i*.03,2-i*.01)
		anchor._sync_pose()
		var expected:=Transform3D(Basis.IDENTITY,anchor.default_origin)*Transform3D(Basis.from_euler(Vector3(anchor.angles)*PI/180.0)*Basis.from_scale(anchor.dimensions),Vector3(anchor.offset)*.01)
		check(anchor.transform.is_equal_approx(expected),"mount angles scale and offset invalidate cached pose "+str(i))
		anchor._sync_pose()
		check(anchor.transform.is_equal_approx(expected),"unchanged mount pose remains exact "+str(i))
	root.free()
	var world:=HiddenWorld.new();add_child(world)
	var host:=Node2D.new();world.add_child(host)
	var canvas:=Node2D.new();host.add_child(canvas)
	var points:Array[Vector2]=[]
	for i in 49:points.append(Vector2(i*4,10))
	for kind in ["fallback","wake","smoke"]:
		world.queries=0
		Visual.paint_path(canvas,points,kind,Color.WHITE,0.01,Color.WHITE)
		check(world.queries==49,"trail fog query once per point: "+kind,world.queries)
		world.queries=0
		Visual.paint_path(canvas,points,kind,Color.WHITE,0.01,Color.WHITE,101)
		check(world.queries==0,"expired trail does no visibility work: "+kind)
	world.free()
	await finish()
	FileAccess.open(output_dir.path_join("result.json"),FileAccess.WRITE).store_string(JSON.stringify({"checks":checks,"failed":failed}))
	get_tree().quit(0 if failed==0 else 1)
