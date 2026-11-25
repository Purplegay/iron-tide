extends "res://tests/progression_bookmarks_regression.gd"
const Skins = preload("res://scripts/ui/unit_skin_picker.gd")

func choose(panel,value:String) -> void:
	for i in panel.picker.item_count:
		if panel.picker.get_item_metadata(i)==value:
			panel.picker.select(i);panel.picker.item_selected.emit(i);return
	check(false,"missing option "+value)

func panel_for(ui,id:String):
	ui._unit_sel=id;ui._rebuild_unit_detail()
	return ui.unit_detail.find_child("UnitSkinPicker",true,false)

func run() -> void:
	surface=SubViewport.new();surface.size=Vector2i(1280,720);add_child(surface)
	MetaProgress.reset_save()
	MetaProgress.owned_cosmetics={"winter":true,"cobalt_porcelain":true,"ice":true}
	MetaProgress.unit_cosmetics={"MTNK":{"weapon_fx":"stock"},"HTNK":{"skin":"winter"}}
	MetaProgress.save()
	var wallet:Dictionary=MetaProgress.currency.duplicate()
	var ui=screen();ui._set_page("units")
	var panel=panel_for(ui,"MTNK");await settle()
	check(panel!=null and panel.visible,"actual refit exposes skin picker")
	check(panel.picker.item_count==3,"YR lists stock shared skin and exclusive skin")
	var scroller:ScrollContainer=ui.unit_detail.get_parent()
	scroller.scroll_vertical=120;await settle();var offset:int=scroller.scroll_vertical
	choose(panel,"cobalt_porcelain");await settle()
	check(MetaProgress.cosmetic_style("MTNK").skin=="cobalt_porcelain","real UI equips exclusive skin")
	check(panel.preview.actor.cosmetic_outfit().skin=="cobalt_porcelain","preview consumes new appearance immediately")
	check(ui._page=="units" and ui._unit_sel=="MTNK" and scroller.scroll_vertical==offset,"equip retains page unit and scroll")
	check(MetaProgress.cosmetic_style("HTNK").skin=="winter" and MetaProgress.cosmetic_style("MTNK").has("weapon_fx"),"other unit and cosmetic slots unchanged")
	MetaProgress.unit_cosmetics.clear();MetaProgress.load_save()
	check(MetaProgress.cosmetic_style("MTNK").skin=="cobalt_porcelain","real saved appearance survives reload")
	DirAccess.make_dir_absolute(MetaProgress.SAVE_PATH+".tmp")
	choose(panel,"winter")
	check(MetaProgress.cosmetic_style("MTNK").skin=="cobalt_porcelain" and panel.picker.get_item_metadata(panel.picker.selected)=="cobalt_porcelain","failed save restores selector and persisted equipment")
	check(panel.preview.actor.cosmetic_outfit().skin=="cobalt_porcelain","failed save does not change model")
	DirAccess.remove_absolute(MetaProgress.SAVE_PATH+".tmp")
	choose(panel,"stock")
	check(not MetaProgress.cosmetic_style("MTNK").has("skin") and panel.preview.actor.cosmetic_outfit().skin=="stock","restore stock clears only skin slot")
	panel=panel_for(ui,"TNKD");await settle()
	choose(panel,"casemate_frame")
	check(not MetaProgress.cosmetic_style("TNKD").has("skin"),"locked skin cannot be equipped even by signal")
	var locked:=false
	for i in panel.picker.item_count:
		if panel.picker.get_item_metadata(i)=="casemate_frame":locked=panel.picker.is_item_disabled(i) and "未解锁" in panel.picker.get_item_text(i)
	check(locked,"locked exclusive displays acquisition requirement")
	panel=panel_for(ui,"R3MIRAGE");await settle()
	check(panel.slot=="paint" and panel.picker.item_count==2,"RA3 uses real paint catalog rather than YR skins")
	choose(panel,"ice")
	check(MetaProgress.cosmetic_style("R3MIRAGE").paint=="ice" and panel.preview.actor.cosmetic_outfit().paint=="ice","RA3 selection equips and previews paint")
	for id:String in ui.refit_roster:
		for value:String in Skins.choices(id):
			var key:="paint" if Skins.Styles.is_ra3(GameData.get_unit(id)) else "skin"
			check(Skins.Catalog.available(id,key,value),"compatible skin catalog "+id+" "+value)
	check(Skins.choices("TESLA").is_empty(),"unsupported building has no false skin selector")
	check(MetaProgress.currency==wallet,"switching skins never spends currency")
	ui.free();await settle();ui=screen();ui._set_page("units");await settle()
	check(ui._unit_sel=="R3MIRAGE","reopening refit retains last selected unit")
	panel=ui.unit_detail.find_child("UnitSkinPicker",true,false)
	check(panel.picker.get_item_metadata(panel.picker.selected)=="ice","reopening picker restores saved skin")
	ui.free();await settle()
	FileAccess.open(OS.get_environment("IRON_TIDE_REPORT_DIR").path_join("result.json"),FileAccess.WRITE).store_string(JSON.stringify({"checks":checks,"failed":failed}))
	get_tree().quit(failed)
