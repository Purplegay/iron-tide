extends Node
const Memory=preload("res://scripts/ui/progression_bookmarks.gd")
var checks:Array=[]
var failed:=0
var surface:SubViewport
func check(ok:bool,label:String) -> void:
	checks.append({"name":label,"passed":ok})
	if not ok:failed+=1;print("FAIL ",label)
func settle() -> void:
	for frame in 5:await get_tree().process_frame
func screen():
	var ui=load("res://scenes/meta.tscn").instantiate()
	surface.add_child(ui)
	return ui
func _ready() -> void:
	if not OS.get_user_data_dir().contains("CodexIronTideValidation") or OS.get_environment("IRON_TIDE_REPORT_DIR").is_empty():get_tree().quit(2);return
	run.call_deferred()
func run() -> void:
	surface=SubViewport.new();surface.size=Vector2i(1280,720);add_child(surface)
	MetaProgress.reset_save()
	var wallet:Dictionary=MetaProgress.currency.duplicate()
	var ui=screen()
	ui._set_page("heroes");await settle()
	var hero=ui.heroes
	for i in hero.picker.item_count:
		if hero.picker.get_item_metadata(i)=="HTNK":hero.picker.select(i);hero.picker.item_selected.emit(i);break
	await settle();hero.scroll_vertical=330;await settle()
	var hero_y:int=hero.scroll_vertical
	check(hero_y>0,"hero content can scroll")
	for i in hero.picker.item_count:
		if hero.picker.get_item_metadata(i)=="E1":hero.picker.select(i);hero.picker.item_selected.emit(i);break
	await settle();hero.scroll_vertical=90;await settle()
	for i in hero.picker.item_count:
		if hero.picker.get_item_metadata(i)=="HTNK":hero.picker.select(i);hero.picker.item_selected.emit(i);break
	await settle()
	check(hero.scroll_vertical==hero_y,"each hero remembers an independent scroll offset")
	Events.meta_changed.emit();await settle()
	check(hero.selected=="HTNK" and hero.scroll_vertical==hero_y,"hero purchase refresh retains current view")
	ui._set_page("units");ui._unit_sel="IVAN";ui._rebuild_unit_detail();await settle()
	var list_scroll:ScrollContainer=ui.unit_list.get_parent()
	var detail_scroll:ScrollContainer=ui.unit_detail.get_parent()
	list_scroll.scroll_vertical=480;detail_scroll.scroll_vertical=260;await settle()
	var list_y:int=list_scroll.scroll_vertical
	var detail_y:int=detail_scroll.scroll_vertical
	check(list_y>0 and detail_y>0,"both unit panels can scroll")
	Events.meta_changed.emit();await settle()
	check(ui._unit_sel=="IVAN" and detail_scroll.scroll_vertical==detail_y and list_scroll.scroll_vertical==list_y,"purchase refresh preserves unit and both offsets")
	ui._set_page("heroes");await settle()
	check(hero.selected=="HTNK" and hero.picker.get_item_metadata(hero.picker.selected)=="HTNK" and hero.scroll_vertical==hero_y,"tab return preserves hero selection and scroll")
	ui._set_page("units");await settle()
	check(ui._unit_sel=="IVAN" and detail_scroll.scroll_vertical==detail_y and list_scroll.scroll_vertical==list_y,"tab return preserves unit panels")
	ui._unit_sel="GGI";ui._rebuild_unit_detail();await settle()
	check(detail_scroll.scroll_vertical==0,"new unit starts at its own top")
	detail_scroll.scroll_vertical=120;await settle()
	var ggi_y:int=detail_scroll.scroll_vertical
	ui._unit_sel="IVAN";ui._rebuild_unit_detail();await settle()
	check(detail_scroll.scroll_vertical==detail_y,"different units keep independent detail offsets")
	detail_scroll.scroll_vertical+=33;list_scroll.scroll_vertical+=37;await settle()
	detail_y=detail_scroll.scroll_vertical;list_y=list_scroll.scroll_vertical
	ui.free();await settle()
	ui=screen();await settle();ui._set_page("units");await settle()
	check(ui._unit_sel=="IVAN" and ui.unit_detail.get_parent().scroll_vertical==detail_y and ui.unit_list.get_parent().scroll_vertical==list_y,"recreated screen restores unit from disk")
	ui._unit_sel="GGI";ui._rebuild_unit_detail();await settle()
	check(ui.unit_detail.get_parent().scroll_vertical==ggi_y,"other unit offset survives recreation")
	ui._set_page("heroes");await settle()
	check(ui.heroes.selected=="HTNK" and ui.heroes.scroll_vertical==hero_y,"recreated hero page restores disk bookmark")
	ui._set_page("units");await settle()
	var filter_index:int=ui._faction_ids.find("soviet")
	ui.unit_filter_opt.select(filter_index);ui.unit_filter_opt.item_selected.emit(filter_index)
	ui.exclusive_filter.button_pressed=true;ui._unit_sel="IVAN";ui._rebuild_unit_detail();await settle()
	ui.free();await settle();ui=screen();ui._set_page("units");await settle()
	check(ui._unit_filter=="soviet" and ui.exclusive_filter.button_pressed and ui._unit_sel=="IVAN","unit filters persist with selection")
	ui.free();await settle()
	var memory=Memory.new();memory.set_value("hero","removed_id");memory.set_value("unit","removed_id");memory.set_value("faction","removed_id");memory.save()
	ui=screen();ui._set_page("heroes");await settle()
	check(MetaProgress.Academy.HEROES.has(ui.heroes.selected),"invalid hero falls back safely")
	ui._set_page("units");await settle()
	check(ui._unit_filter=="" and (ui._unit_sel=="" or ui.refit_roster.has(ui._unit_sel)),"invalid unit and filter fall back safely")
	check(MetaProgress.currency==wallet and MetaProgress.owned_talent_points==0,"UI preferences never change progression wallet or points")
	ui.free();await settle()
	FileAccess.open(OS.get_environment("IRON_TIDE_REPORT_DIR").path_join("result.json"),FileAccess.WRITE).store_string(JSON.stringify({"checks":checks,"failed":failed}))
	print("BOOKMARKS checks=",checks.size()," failed=",failed)
	get_tree().quit(failed)
