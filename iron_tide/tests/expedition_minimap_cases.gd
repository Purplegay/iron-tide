extends RefCounted

static func main_marks(marks:Array) -> Array:
	return marks.filter(func(mark):return not mark.get("optional",false) and mark.status!="base")

static func inspect(t,tasks) -> void:
	var minimap=t.screen.hud.minimap
	var marks:Array=minimap.objective_marks()
	var kind:String=tasks.state.kind
	var stage:int=tasks.state.stage
	var expected:int={"capture":1,"control":3,"research":2,"rescue":2,"escort":4,"supply":2,"radar":1,"assault":1,"annihilate":0,"boss":3,"defend":3}[kind]
	t.check(minimap.objectives==tasks and main_marks(marks).size()==expected,"minimap shows only current public task targets "+str(stage))
	if stage==1:
		var had_storms:bool=t.battle.allied_state.has("lightning_storms")
		var previous:Array=t.battle.allied_state.get("lightning_storms",[])
		t.battle.allied_state.lightning_storms=[{"started":true,"side":"enemy","time":0.0,"rules":{"duration_frames":180}}]
		t.check(minimap.objective_marks().is_empty(),"radar jamming also suppresses objective markers")
		if had_storms:t.battle.allied_state.lightning_storms=previous
		else:t.battle.allied_state.erase("lightning_storms")
		t.check(main_marks(minimap.objective_marks()).size()==expected,"objectives return after radar jamming ends")
	for marker:Dictionary in marks:
		t.check(minimap._to_map(marker.local).distance_to(marker.position)<0.01,"objective minimap projection round trip "+str(stage)+marker.key)
		t.check(minimap._get_tooltip(marker.local).contains(marker.title),"objective tooltip names target "+str(stage)+marker.key)
		if not t.battle.position_visible_to("ally",marker.position):t.check(marker.color.a>0,"public objective remains marked in fog "+str(stage)+marker.key)
		if marker.key=="command":
			t.check(marker.status=="locked" and marker.color==Color("#b5bbc7") if tasks.actor("command").special.get("expedition_protected",false) else marker.status=="active","boss marker follows actual protection "+str(stage))
	if kind=="escort" or stage==20:
		var key:String="convoy0" if kind=="escort" else "command"
		var target=tasks.actor(key)
		var original:Vector2=target.global_position
		target.global_position+=Vector2(40,30)
		for marker:Dictionary in minimap.objective_marks():
			if marker.key==key:t.check(marker.position==target.global_position,"moving mission actor updates minimap "+str(stage))
		target.global_position=original
	if kind=="rescue":
		t.clear_enemies()
		t.battle.spawn_unit("E1","ally",tasks.state.points[0])
		tasks.tick(20)
		t.check(tasks.state.rescued==[0],"partial rescue fixture completes only first point")
		for marker:Dictionary in minimap.objective_marks():
			t.check(marker.status==("done" if marker.key=="point0" else "active"),"rescue marker distinguishes completed and pending "+marker.key)
			if marker.key=="point0":t.check(marker.color==Color("#80ef9a"),"completed rescue marker is green")

static func completed(t,tasks) -> void:
	var all_marks:Array=t.screen.hud.minimap.objective_marks()
	var markers:Array=main_marks(all_marks)
	var expected:Dictionary={}
	for source in tasks.field_ops.markers(): expected[source.key]=source
	for mark in all_marks:
		if not mark.get("optional",false):continue
		var source:Dictionary=expected.get(mark.key,{})
		t.check(source.get("position")==mark.position and source.get("status")==mark.status,"optional marker follows its own task after victory "+str(tasks.state.stage)+mark.key)
		expected.erase(mark.key)
	t.check(expected.is_empty(),"all current optional tasks remain represented "+str(tasks.state.stage))

	for marker:Dictionary in markers:
		if marker.key.begins_with("point"):t.check(marker.status=="done","completed task point is green "+str(tasks.state.stage)+marker.key)
		else:t.check(tasks.actor(marker.key)!=null,"destroyed targets leave no stale minimap marks "+str(tasks.state.stage)+marker.key)
	if tasks.state.kind in ["supply","assault","radar","boss"]:t.check(markers.is_empty(),"completed destruction task clears minimap targets "+str(tasks.state.stage))
