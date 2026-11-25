extends "res://tests/progression_bookmarks_regression.gd"

func screen():
	var ui=preload("res://scripts/screens/paint_screen.gd").new()
	surface.add_child(ui)
	ui.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	return ui

func choose(ui,id:String) -> void:
	for i in ui.units.item_count:
		if ui.units.get_item_metadata(i)==id:
			ui.units.select(i);ui.units.item_selected.emit(i);return
	check(false,"unit available: "+id)

func category(ui,index:int) -> void:
	ui.series.select(index);ui.series.item_selected.emit(index)

func run() -> void:
	surface=SubViewport.new();surface.size=Vector2i(900,500);add_child(surface)
	MetaProgress.reset_save()
	var wallet:Dictionary=MetaProgress.currency.duplicate(true)
	var cosmetics:Dictionary=MetaProgress.unit_cosmetics.duplicate(true)
	var memory=Memory.new();memory.set_value("unit","GGI");memory.save()
	var ui=screen();await settle()
	check(ui.series.selected==0 and not ui.unit_id.is_empty(),"fresh workshop has safe defaults")
	category(ui,1);choose(ui,"HTNK");ui.exclusive_only.button_pressed=true;await settle()
	ui.workshop.scroll_vertical=120;await settle()
	var offset:int=ui.workshop.scroll_vertical
	check(offset>0,"workshop scroll available")
	ui.free();await settle();ui=screen();await settle()
	check(ui.series.selected==1 and ui.unit_id=="HTNK" and ui.exclusive_only.button_pressed,"recreated workshop restores category unit and filter")
	check(ui.workshop.scroll_vertical==offset,"recreated workshop restores scroll")
	category(ui,0);choose(ui,"R3MIRAGE");await settle()
	ui.workshop.scroll_vertical=210;await settle()
	var ra3_offset:int=ui.workshop.scroll_vertical
	category(ui,2);choose(ui,"NAREFN");await settle()
	category(ui,1);await settle()
	check(ui.unit_id=="HTNK" and ui.workshop.scroll_vertical==offset,"YR category retains its own unit and scroll")
	category(ui,0);await settle()
	check(ui.unit_id=="R3MIRAGE" and ui.workshop.scroll_vertical==ra3_offset,"RA3 category retains its own unit and scroll")
	ui.exclusive_only.button_pressed=false;await settle()
	check(ui.unit_id=="R3MIRAGE","filter toggle keeps eligible selection")
	ui.free();await settle();ui=screen();await settle()
	check(ui.series.selected==0 and ui.unit_id=="R3MIRAGE" and not ui.exclusive_only.button_pressed,"unchecked filter persists")
	category(ui,2);await settle()
	check(ui.unit_id=="NAREFN","building category selection survives recreation")
	ui.free();await settle()
	memory=Memory.new()
	check(memory.get_value("unit","")=="GGI","workshop leaves progression bookmarks intact")
	memory.set_value("paint_series","removed_category");memory.set_value("paint_unit/ra3","removed_unit");memory.save()
	ui=screen();await settle()
	check(ui.series.selected==0 and ui.units.item_count>0 and ui.unit_id==str(ui.units.get_item_metadata(ui.units.selected)),"removed category and unit fall back safely")
	check(MetaProgress.currency==wallet and MetaProgress.unit_cosmetics==cosmetics,"UI memory changes neither wallet nor equipped cosmetics")
	ui.free();await settle()
	FileAccess.open(OS.get_environment("IRON_TIDE_REPORT_DIR").path_join("result.json"),FileAccess.WRITE).store_string(JSON.stringify({"checks":checks,"failed":failed}))
	print("PAINT BOOKMARKS checks=",checks.size()," failed=",failed)
	get_tree().quit(failed)
