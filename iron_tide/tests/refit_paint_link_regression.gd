extends "res://tests/progression_bookmarks_regression.gd"

func run() -> void:
	surface=SubViewport.new();surface.size=Vector2i(1280,720);add_child(surface)
	MetaProgress.reset_save()
	MetaProgress.owned_cosmetics={"ice":true,"winter":true}
	MetaProgress.save()
	var wallet:Dictionary=MetaProgress.currency.duplicate(true)
	var memory=Memory.new()
	memory.set_value("paint_series","yr_units")
	memory.set_value("paint_unit/yr_units","HTNK")
	memory.set_value("paint_exclusive",true)
	memory.save()
	var ui=screen();ui._set_page("units")
	for id in ["R3REAPER","E1","CCOMAND"]:
		ui._unit_sel=id;ui._rebuild_unit_detail();await settle()
		var button=ui.unit_detail.find_child("OpenUnitPaint",true,false)
		check(button!=null,"refit shortcut exists "+id)
		var scroll:ScrollContainer=ui.unit_detail.get_parent()
		scroll.scroll_vertical=100;await settle()
		var offset:=scroll.scroll_vertical
		button.pressed.emit();await settle()
		var paint=ui.unit_paint
		check(is_instance_valid(paint) and paint.unit_id==id,"shortcut opens exact unit "+id)
		check(not ui.visible and paint.visible,"workshop replaces visible refit "+id)
		check(paint.series.selected==(0 if id=="R3REAPER" else 1),"correct workshop category "+id)
		check(paint.workshop.scroll_vertical==0,"direct link begins at model "+id)
		ui._open_unit_paint()
		check(ui.unit_paint==paint,"double open creates no duplicate")
		var key:="paint" if id=="R3REAPER" else "skin"
		var value:="ice" if key=="paint" else "winter"
		var option:OptionButton=paint.slots.find_child(key,true,false)
		for i in option.item_count:
			if option.get_item_metadata(i)==value:
				option.select(i);option.item_selected.emit(i);break
		await settle()
		check(MetaProgress.cosmetic_style(id).get(key,"")==value,"workshop equips current unit "+id)
		paint.back_button.pressed.emit();await settle()
		check(ui.visible and not is_instance_valid(ui.unit_paint) and ui._unit_sel==id and ui._page=="units","return keeps refit unit and tab "+id)
		check(scroll.scroll_vertical==offset,"return retains refit scroll "+id)
		var picker=ui.unit_detail.find_child("UnitSkinPicker",true,false)
		check(picker.picker.get_item_metadata(picker.picker.selected)==value,"return updates equipped skin "+id)
	ui.free();await settle()
	memory=Memory.new()
	check(memory.get_value("paint_unit/yr_units","")=="CCOMAND","refit exit preserves workshop bookmarks")
	check(MetaProgress.currency==wallet,"opening and owned equip do not spend currency")
	FileAccess.open(OS.get_environment("IRON_TIDE_REPORT_DIR").path_join("result.json"),FileAccess.WRITE).store_string(JSON.stringify({"checks":checks,"failed":failed}))
	get_tree().quit(failed)
