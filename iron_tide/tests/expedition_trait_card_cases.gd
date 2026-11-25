extends RefCounted
const Army=preload("res://scripts/expedition/army.gd")

static func cards(root:Node) -> Array:
	var result:Array=[]
	for child in root.get_children():
		if child.has_meta("trait_key"):result.append(child)
		result.append_array(cards(child))
	return result

static func inspect(t,prefix:String) -> void:
	var entries:=cards(t.camp)
	if entries.is_empty():return
	t.check(entries.size()==10,prefix+" compact overview contains all ten traits")
	for tile in entries:
		var key:String=tile.get_meta("trait_key")
		var count:int=Expedition.state.trait_buffs.get(key,0)
		var progress:ProgressBar=tile.find_child("LayerProgress",true,false)
		var title:Label=tile.find_child("TraitTitle",true,false)
		t.check(progress.max_value==9 and progress.value==count and ("%d / 9 层"%count) in title.text,prefix+" visible progress matches stacks "+key)
		t.check(tile.size.y<=110,prefix+" compact trait height "+key,tile.size.y)
		t.check(tile.mouse_filter==Control.MOUSE_FILTER_STOP and title.mouse_filter==Control.MOUSE_FILTER_IGNORE and progress.mouse_filter==Control.MOUSE_FILTER_IGNORE,prefix+" title and bar hover reaches tooltip owner "+key)
	var grid:GridContainer=entries[0].get_parent()
	t.check(grid.size.y<=(520 if grid.columns==2 else 420),prefix+" whole trait overview stays compact",grid.size)

static func run(t) -> void:
	var original:Dictionary=Expedition.state.duplicate(true)
	var dimensions:Vector2i=t.stage.size
	t.stage.size=Vector2i(800,600)
	for count in [0,2,3,5,6,8,9]:
		var next:Dictionary=original.duplicate(true)
		for key:String in Army.TRAITS:next.trait_buffs[key]=count
		next.tracked_traits=[]
		t.check(Expedition.commit(next),"prepare compact tooltip layer "+str(count))
		t.camp.change_tab(2);await t.settle()
		inspect(t,"tooltip layer "+str(count))
		var entries:=cards(t.camp)
		var popups:Array=[]
		var before:Dictionary=Expedition.state.duplicate(true)
		for tile in entries:
			var key:String=tile.get_meta("trait_key")
			var text:String=tile.tooltip_text
			t.check(Army.trait_audience(key,before) in text and Army.trait_detail(key,count) in text and "搭配建议" in text,"hover preserves audience active effects and build guide "+key+str(count))
			t.check(("下一层基础收益" in text)==(count<9),"maxed trait tooltip has no fictitious next level "+key+str(count))
			var hint:Label=tile.find_child("MilestoneHint",true,false)
			var threshold:=3 if count<3 else 6 if count<6 else 9
			t.check(("还差 %d 层"%(threshold-count)) in hint.text if count<9 else hint.text=="9 层终局已解锁","next milestone progress is exact "+key+str(count))
			var popup:Control=tile._make_custom_tooltip(text)
			t.stage.add_child(popup);popups.append(popup)
		await t.settle()
		for popup in popups:
			t.check(popup.size.x<=760 and popup.size.y<=576,"tooltip fits smallest supported viewport",popup.size)
			var text:Label=popup.get_child(0)
			t.check(text.autowrap_mode==TextServer.AUTOWRAP_WORD_SMART and text.get_line_count()>1,"tooltip uses bounded wrapping instead of one wide line")
			popup.free()
		t.check(Expedition.state==before,"opening tooltips never changes rewards or stacks")
	# The compact mark button still invokes the existing two-direction selection.
	var before_stacks:Dictionary=Expedition.state.trait_buffs.duplicate()
	for key:String in ["infantry","vehicle","air"]:
		for tile in cards(t.camp):
			if tile.get_meta("trait_key")==key:
				var mark:Button=tile.find_child("TrackButton",true,false)
				mark.pressed.emit();break
		t.check(key in Expedition.state.tracked_traits and Expedition.state.tracked_traits.size()<=2,"compact mark button updates direction "+key)
	t.check(Expedition.state.trait_buffs==before_stacks,"marking a compact trait never grants extra stacks")
	Expedition.commit(original);t.stage.size=dimensions;t.camp.build();await t.settle()
