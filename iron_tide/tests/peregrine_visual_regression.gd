extends "res://tests/peregrine_service_regression.gd"
const FX=preload("res://scripts/units/peregrine_visual.gd")

func _ready() -> void:
	output_dir=OS.get_environment("IRON_TIDE_REPORT_DIR")
	if output_dir.is_empty() or not OS.get_user_data_dir().contains("CodexIronTideValidation") or DisplayServer.get_name()=="headless":get_tree().quit(2);return
	await get_tree().process_frame
	var hero=service_hero();place_service(hero)
	var ordinary=battle.spawn_unit("ORCA","ally",hero.position+Vector2(160,0))
	check(hero.peregrine_fx!=null and ordinary.peregrine_fx==null,"only promoted aircraft installs visual rig")
	check(FX.state(hero).thrust==1 and FX.state(hero).gear==0,"cruise has thrust and stowed landing gear")
	battle.camera.position=hero.position;battle.camera.reset_smoothing();Iso.apply_to(battle.camera,2);battle.camera.force_update_scroll()
	hero.motion_pose.capture(hero)
	var rig=hero.peregrine_fx
	for yaw in [0.,PI*.5,PI,PI*1.5]:
		hero.hull_angle=yaw;hero.motion_pose.capture(hero)
		hero.peregrine_fx=null;var native=await picture(hero)
		hero.peregrine_fx=rig;var enhanced=await picture(hero)
		check(hash(native.get_data())!=hash(enhanced.get_data()),"actual GPU thrust rendered at heading "+str(yaw))
	var nodes:=get_tree().get_node_count();var prior:Dictionary=hero.special.duplicate(true)
	var hp:float=hero.hp;var ammo:int=hero.logistics.ammo;var position:Vector2=hero.position
	for i in 1000:rig.tick(hero,.016)
	check(hero.special==prior and hero.hp==hp and hero.logistics.ammo==ammo and hero.position==position,"visual clock leaves authoritative state untouched")
	check(get_tree().get_node_count()==nodes and rig.clock<60,"visual animation allocates no scene nodes and bounds its clock")
	check(hero.deploy(),"maintenance starts through player deploy command")
	P.tick(hero,.5)
	check(FX.state(hero).gear>0 and FX.state(hero).gear<1 and FX.state(hero).thrust>0,"descent progressively extends gear before touchdown")
	await picture(hero)
	P.tick(hero,.5);hero.hp=hero.max_hp*.5
	check(FX.state(hero).gear==1 and FX.state(hero).thrust==0 and not FX.state(hero).healing,"grounded maintenance stops engines before healing starts")
	P.tick(hero,3.1)
	check(FX.state(hero).healing,"healing lamp follows actual quiet window and missing health")
	await picture(hero)
	hero.special.peregrine.maintenance.quiet=0
	check(not FX.state(hero).healing,"interrupted quiet window removes healing lamp")
	hero.order_move(hero.position+Vector2(100,0));hero.flight.altitude(1,.01)
	check(FX.state(hero).gear<1 and FX.state(hero).thrust>0,"actual climb retracts gear and restarts engines")
	await finish()
	hero=service_hero();make_wreck(hero)
	check(FX.state(hero).broken and FX.state(hero).thrust==0,"lethal crash immediately shuts down engines")
	P.tick(hero,1)
	battle.camera.position=hero.position;battle.camera.reset_smoothing();battle.camera.force_update_scroll();hero.motion_pose.capture(hero)
	var before=await picture(hero)
	hero.peregrine_fx.tick(hero,.7)
	var after=await picture(hero)
	check(hash(before.get_data())!=hash(after.get_data()),"wreck smoke animates despite full 1000-percent durability")
	check(hero.hp==hero.max_hp and FX.state(hero).gear==1,"wreck visual does not depend on low-HP damage particles")
	var codec=BattleSaves.Snapshot.new();var snap:Dictionary=codec.capture(battle);codec.restore(battle,snap);hero=get_hero()
	check(codec.error.is_empty() and hero.peregrine_fx!=null and FX.state(hero).broken,"real snapshot restore reconstructs wreck visual rig")
	hero.special.hero_wreck.repair_elapsed=1.0
	check(FX.state(hero).repair,"engineer repair state enables welding lamp")
	await picture(hero)
	S.recover(hero)
	check(not FX.state(hero).broken and not FX.state(hero).repair and hero.hp==hero.max_hp,"recovery removes damaged appearance and welding")
	hero.flight.altitude(1,.1)
	check(FX.state(hero).thrust>0 and FX.state(hero).gear<1,"recovered aircraft climbs with live altitude-driven gear and thrust")
	await picture(hero)
	await finish()
	var saved:=FileAccess.get_file_as_bytes(MetaProgress.SAVE_PATH)
	var page=preload("res://scripts/ui/hero_progression.gd").new();add_child(page);page.selected="ORCA";page.refresh()
	check(page.preview.actor.peregrine_fx!=null,"hero progression preview installs hover visual without promotion")
	page.preview.playing=false;var clock:float=page.preview.actor.peregrine_fx.clock;page.preview._process(1)
	check(page.preview.actor.peregrine_fx.clock==clock,"paused preview freezes visual clock")
	page.selected="TTNK";page.refresh()
	check(page.preview.actor.peregrine_fx==null,"changing hero cannot leak aircraft effects")
	page.free()
	check(FileAccess.get_file_as_bytes(MetaProgress.SAVE_PATH)==saved,"appearance preview never writes player profile")
	FileAccess.open(output_dir.path_join("result.json"),FileAccess.WRITE).store_string(JSON.stringify({"checks":checks,"failed":failed,"screenshots":0},"  "))
	get_tree().quit(0 if failed==0 else 1)

func picture(hero) -> Image:
	hero.queue_redraw()
	await get_tree().process_frame;await RenderingServer.frame_post_draw
	var image:=get_viewport().get_texture().get_image()
	var ratio:=Vector2(image.get_size())/get_viewport().get_visible_rect().size
	var center:Vector2=hero.get_global_transform_with_canvas()*RA2Art.art_dir(Vector2(0,-hero._visual_lift()))
	return image.get_region(Rect2i((center-Vector2(65,40))*ratio,Vector2(130,95)*ratio).intersection(Rect2i(Vector2i.ZERO,image.get_size())))
