extends Node
func _ready() -> void:
	if not ProjectSettings.get_setting("application/config/use_custom_user_dir",false):get_tree().quit(2);return
	var output:=OS.get_environment("IRON_TIDE_REPORT_DIR")
	Expedition.start("美国","",20261120)
	var run:Dictionary=Expedition.state
	run.phase="ready";run.stage=19;run.supplies=200
	run.heroes=["E1","TANY"];run.wounded_heroes=[]
	run.buffs={"engines":2,"armor":1,"veterans":1}
	run.routes=preload("res://scripts/expedition/campaign.gd").routes(run)
	run.shop=[{"kind":"training","id":"E1","price":12,"original_price":25,"discounted":true,"quality":0,"sold":false,"locked":false},{"kind":"native","id":"E1","price":40,"original_price":80,"discounted":true,"quality":1,"sold":false,"locked":false}]
	var ui=load("res://scenes/expedition.tscn").instantiate();add_child(ui)
	for extent:Vector2i in [Vector2i(1280,720),Vector2i(960,640)]:
		get_window().size=extent
		for page:int in [0,1,2]:
			ui.tab=page;ui.build()
			await get_tree().process_frame;await get_tree().process_frame
			await RenderingServer.frame_post_draw
			get_viewport().get_texture().get_image().save_png(output.path_join("camp-%dx%d-tab%d.png"%[extent.x,extent.y,page]))
	print("CAMP VISUAL captured six real UI views")
	get_tree().quit()
