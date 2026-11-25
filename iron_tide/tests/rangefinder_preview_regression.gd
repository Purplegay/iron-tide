extends Node
## Run only in the isolated graphical QA project; exercises actual shop signals.
var failures:=0
var checks:=0
var folder:String

func check(ok:bool,message:String) -> void:
	checks+=1
	if not ok:
		failures+=1
		print("FAIL ",message)

func pick(picker:OptionButton,id:String) -> void:
	for i in picker.item_count:
		if picker.get_item_metadata(i)==id:
			picker.select(i)
			picker.item_selected.emit(i)
			return
	check(false,"missing option "+id)

func _ready() -> void:
	folder=OS.get_environment("IRON_TIDE_REPORT_DIR")
	if folder.is_empty() or not ProjectSettings.get_setting("application/config/use_custom_user_dir",false):
		get_tree().quit(2)
		return
	run.call_deferred()

func run() -> void:
	var outfits:=MetaProgress.unit_cosmetics.duplicate(true)
	var owned:=MetaProgress.owned_cosmetics.duplicate(true)
	var mounts:=MetaProgress.attachment_positions.duplicate(true)
	var team:=HouseColor.player_id
	MetaProgress.attachment_positions.clear()
	var images:Dictionary={}
	var shop=load("res://scenes/paint.tscn").instantiate()
	add_child(shop)
	pick(shop.units,"R3MIRAGE")
	for paint in ["stock","ice"]:
		for unlocked in [false,true]:
			MetaProgress.unit_cosmetics.clear()
			MetaProgress.owned_cosmetics.clear()
			if unlocked:MetaProgress.owned_cosmetics["rangefinder"]=true
			shop._select_unit("R3MIRAGE")
			pick(shop.slots.find_child("paint",true,false),paint)
			pick(shop.slots.find_child("top",true,false),"rangefinder")
			check(MetaProgress.cosmetic_owned("rangefinder")==unlocked,"actual ownership state")
			check((MetaProgress.cosmetic_style("R3MIRAGE").get("top")=="rangefinder")==unlocked,"only owned selection persists")
			var display=shop.preview
			display._inspect()
			display.set_process(false)
			display.view_heading=0.7
			display._display_heading()
			var actor=display.actor
			var model=actor._ra3_model
			var ornament=model.hull.get_node("CosmeticMount/top").get_child(0)
			for color in ["red","green"]:
				HouseColor.set_player_id(color)
				actor.refresh_house_color()
				check(ornament.optic_finish.get_shader_parameter("house_color")==actor._col,"paused sleeve follows "+color)
				for material in ornament.optic_cheeks:
					check(material.get_shader_parameter("enamel")==actor._col,"paused IFF strip follows "+color)
				check(is_equal_approx(ornament.optic_finish.get_shader_parameter("ice"),1.0 if paint=="ice" else 0.0),"paint remains independent from IFF")
				for i in 5:await get_tree().process_frame
				await RenderingServer.frame_post_draw
				var frame:Image=display.viewport.get_texture().get_image()
				var key:String=paint+"-"+color
				frame.save_png(folder.path_join(key+("-owned" if unlocked else "-locked")+".png"))
				if unlocked:check(frame.get_data()==images[key],"locked and owned shop pixels match "+key)
				else:images[key]=frame.get_data()
			check(images[paint+"-red"]!=images[paint+"-green"],"team switch changes rendered model")
	shop.free()
	MetaProgress.unit_cosmetics=outfits
	MetaProgress.owned_cosmetics=owned
	MetaProgress.attachment_positions=mounts
	HouseColor.set_player_id(team)
	MetaProgress.save()
	var report:={"checks":checks,"failed":failures}
	FileAccess.open(folder.path_join("result.json"),FileAccess.WRITE).store_string(JSON.stringify(report))
	print("RANGEFINDER PREVIEW ",JSON.stringify(report))
	get_tree().quit(1 if failures else 0)
