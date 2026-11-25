extends Node
const Preview=preload("res://scripts/ui/unit_showcase.gd")
const Looks=preload("res://scripts/units/night_hunter_skin.gd")
class BenchUnit extends Preview.DisplayUnit:
	static var draw_us:=0
	func _draw() -> void:
		var started:=Time.get_ticks_usec()
		super._draw()
		draw_us+=Time.get_ticks_usec()-started
var actors:Array=[]
var samples:Array[float]=[]
var draw_samples:Array[float]=[]
var tick_samples:Array[float]=[]
var frames:=0
var previous:=0
var started:=0.0
var output:String
var baseline_script
var baseline_shader

func _ready() -> void:
	output=OS.get_environment("IRON_TIDE_REPORT_DIR")
	if output.is_empty() or not OS.get_user_data_dir().contains("CodexIronTideValidation"):get_tree().quit(2);return
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	Engine.max_fps=0
	var baseline:=OS.get_environment("IRON_SKIN_BASELINE")
	if not baseline.is_empty():
		baseline_script=load(baseline.path_join("night_hunter_skin.gd"))
		baseline_shader=load(baseline.path_join("night_hunter.gdshader"))
		for key in ["night_owl_direct32","rift_hunter_direct32"]:
			var image:=Image.load_from_file(baseline.path_join(key+".png"))
			baseline_script.resources[key]={"tex":ImageTexture.create_from_image(image),"image":image}
			baseline_script.metadata[key]=JSON.parse_string(FileAccess.get_file_as_string(baseline.path_join(key+".json")))
	var view:=SubViewport.new();view.size=Vector2i(1280,720);view.world_2d=World2D.new();view.render_target_update_mode=SubViewport.UPDATE_ALWAYS
	add_child(view)
	view.canvas_transform=Transform2D(Iso.dir(Vector2.RIGHT),Iso.dir(Vector2.DOWN),Vector2.ZERO)
	var display:=TextureRect.new();display.texture=view.get_texture();display.size=Vector2(1280,720);add_child(display)
	for i in 64:
		var id:="SCHP" if i%2==0 else "DRON"
		if OS.get_environment("IRON_SKIN_BENCH_KIND")=="heli":id="SCHP"
		var actor=BenchUnit.new();actor.set_meta("stack_preview",true)
		actor.trial.skin=Looks.SKINS[id]
		actor.setup(GameData.get_unit(id),"ally",view.canvas_transform.affine_inverse()*Vector2(75+(i%8)*155,75+(i/8)*85))
		view.add_child(actor);actor.set_physics_process(false);actor.set_process(false)
		if baseline_script!=null:
			var rig=baseline_script.new();rig.id=id;rig.surface=ShaderMaterial.new();rig.surface.shader=baseline_shader
			rig.surface.set_shader_parameter("drone",id=="DRON");actor.night_skin=rig;actor.material=rig.surface
		actor.velocity=Vector2(60,0);actors.append(actor)
	previous=Time.get_ticks_usec()

func _process(_dt:float) -> void:
	if actors.is_empty():return
	var now:=Time.get_ticks_usec()
	if frames>=180:
		samples.append((now-previous)/1000.0)
		draw_samples.append(BenchUnit.draw_us/1000.0)
	BenchUnit.draw_us=0
	previous=now
	if frames==180:started=Time.get_unix_time_from_system()
	for i in actors.size():
		var actor=actors[i]
		actor.hull_angle=Iso.eff_angle()+frames*.012+i*.1;actor.turret_angle=actor.hull_angle
		actor._walk_phase=fposmod(frames/40.0,1.0);actor._anim=frames/60.0
		actor.night_skin.tick(actor,1.0/60);actor.queue_redraw()
	if frames>=180:tick_samples.append((Time.get_ticks_usec()-now)/1000.0)
	frames+=1
	if samples.size()<1200:return
	samples.sort()
	draw_samples.sort();tick_samples.sort()
	var report:={"units":64,"frames":samples.size(),"p50_ms":samples[samples.size()/2],"p95_ms":samples[int(samples.size()*.95)],"draw_calls":Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME),"texture_bytes":Performance.get_monitor(Performance.RENDER_TEXTURE_MEM_USED),"measurement_unix_start_s":started,"measurement_unix_end_s":Time.get_unix_time_from_system()}
	report.draw_cpu_p50_ms=draw_samples[draw_samples.size()/2];report.tick_cpu_p50_ms=tick_samples[tick_samples.size()/2]
	FileAccess.open(output.path_join("result.json"),FileAccess.WRITE).store_string(JSON.stringify(report,"  "))
	print("SKIN_RENDER_BENCH ",JSON.stringify(report));get_tree().quit()
