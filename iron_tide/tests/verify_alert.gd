extends Node
const Alert=preload("res://scripts/expedition/red_alert.gd")
const Meter=preload("res://scripts/ui/uprising_threat_meter.gd")
class WorldFixture extends Node:
	var allied_state:Dictionary={}
	var ended:=false
	var paused:=false
	var faction:="allied"
	func roster_faction(_side:String)->String:return faction
var checks:=0
var failures:Array=[]
func check(ok:bool,label:String)->void:
	checks+=1
	if not ok:failures.append(label)
func _ready()->void:
	var output:=OS.get_environment("IRON_TIDE_REPORT_DIR")
	if not OS.get_user_data_dir().contains("CodexIronTideValidation"):get_tree().quit(2);return
	var layer:=CanvasLayer.new();add_child(layer)
	var root:=Control.new();layer.add_child(root);root.position=Vector2(30,40)
	for faction in ["allied","soviet"]:
		var world:=WorldFixture.new();world.faction=faction;add_child(world)
		var dock:=Control.new();root.add_child(dock);dock.position=Vector2(0 if faction=="allied" else 280,0)
		var button=load("res://scripts/ui/uprising_red_alert_button.gd").new();dock.add_child(button);button.setup(world);button.build_status(dock);button.set_process(false)
		var title:=Label.new();dock.add_child(title);title.text=faction;title.position=Vector2(0,-20)
		check(button.threat_bar.soviet==(faction=="soviet"),faction+" mapping")
		for state in ["charging","ready","full","half","last"]:
			var left:float={"full":Alert.DURATION,"half":Alert.DURATION/2,"last":Alert.DURATION/24}.get(state,0.0)
			world.allied_state[Alert.KEY]={"charge":1 if state=="ready" else 0,"threat":24500.0 if state=="charging" else 0.0,"left":left}
			button._process(1.0)
			await get_tree().process_frame
			await RenderingServer.frame_post_draw
			var image=get_viewport().get_texture().get_image()
			var xform:Transform2D=get_viewport().get_stretch_transform()*dock.get_global_transform_with_canvas()
			var rect:=Rect2i(xform*Rect2(0,0,218,190))
			var crop:=image.get_region(rect);crop.resize(654,570,Image.INTERPOLATE_NEAREST)
			check(crop.save_png(output.path_join(faction+"-"+state+"-control.png"))==OK,faction+state+" screenshot")
			if left>0:
				check(Meter.lit_time_segments(button.threat_bar.time_fraction)==int({"full":24,"half":12,"last":1}[state]),faction+state+" segment count")
			check(button.reveal== (1.0 if state=="ready" else 0.0),faction+state+" button visibility")
	FileAccess.open(output.path_join("control-result.json"),FileAccess.WRITE).store_string(JSON.stringify({"checks":checks,"failures":failures},"  "))
	print("CONTROL VERIFY ",checks," failures=",failures)
	get_tree().quit(0 if failures.is_empty() else 1)
