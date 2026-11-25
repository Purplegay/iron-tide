extends "res://tests/bridge_sections_regression.gd"

func exercise(mode:String) -> void:
	BattleRequest.configure_skirmish(mode,{"map_layout":"yr_unrepent","opening":"mcv","fog_of_war":false})
	screen=load("res://scenes/battle.tscn").instantiate();add_child(screen);screen.process_mode=Node.PROCESS_MODE_DISABLED
	battle=screen.battle
	var ground:Ground
	for child in battle.get_children():
		if child is Ground:ground=child
	var image:Image=ground._surface.texture.get_image()
	if image.is_compressed():image.decompress()
	var art=ground.bridge_art
	check(art.frames.has("BRIDGE1:0") and art.frames.has("BRIDGE1:7") and art.frames.has("BRIDGE1:8"),"retail high bridge intact and both broken edge frames imported")
	for name in ["BRIDGE1","BRIDGE2","BRIDGEB1","BRIDGEB2"]:
		var cell:=Vector2i(10,10)
		var direction:=Vector2i.RIGHT if name.ends_with("2") else Vector2i.DOWN
		check(not art.frames[name+":0"].is_invisible() and not art.frames[name+":7"].is_invisible() and not art.frames[name+":8"].is_invisible(),name+" real intact/broken art has visible pixels")
		check(art.overlay_key([10,10,name,0],{cell-direction:true})==name+":7",name+" preceding broken section uses leading edge")
		check(art.overlay_key([10,10,name,0],{cell+direction:true})==name+":8",name+" following broken section uses trailing edge")
		check(art.overlay_key([10,10,name,0],{cell:true}).is_empty(),name+" destroyed section has no deck")
	var row:Dictionary=Native.data("yr_unrepent")
	check(row.bridges.size()==43 and row.bridge_decks.size()==4,"all forty-three high deck cells and four connected spans retained")
	for tile:Array in row.bridges:
		var pixel:=Vector2i((float(tile[0])+.5)*24,(float(tile[1])+.5)*24)
		check(image.get_pixelv(pixel)!=art.ground.get_pixelv(pixel),"actual baked bridge covers navigation cell "+str(pixel))
	for current:Rect2 in row.bridge_decks:
		var parts:Array=Bridges.sections(battle,current)
		var begin:=Vector2(current.get_center().x,current.position.y-27.5)
		var end:=Vector2(current.get_center().x,current.end.y+27.5)
		var tank=battle.spawn_unit("MTNK","ally",begin);activate(tank);tank.order_move(end)
		for tick in 900:
			await get_tree().physics_frame
			tank._physics_process(1.0/30.0)
			if not tank.has_move_order:break
		check(tank.position.distance_to(end)<35,"actual tank crosses high span "+str(current),tank.position)
		tank.free();battle.units=battle.units.filter(is_instance_valid)
		var middle:Rect2=parts[parts.size()/2]
		Bridges.damage_section(battle,middle,Bridges.strength())
		check(battle.path_service.is_blocked(middle.get_center()) and ground.bridge_art.patches.size()==1,"destroyed high deck closes land path and creates native patch")
		var cells:Dictionary={Vector2i((middle.get_center()/55).floor()):true}
		var edge_keys:Array=[]
		for tile:Array in row.bridges:
			var key:String=art.overlay_key(tile,cells)
			if key in ["BRIDGE1:7","BRIDGE1:8"]:edge_keys.append(key)
		check(edge_keys.size()==2 and edge_keys[0]!=edge_keys[1],"high bridge damage uses opposing BRIDGE frames instead of low bridge art")
		var codec=BattleSaves.Snapshot.new();codec.restore(battle,bytes_to_var(var_to_bytes(codec.capture(battle))))
		check(codec.error.is_empty() and ground.broken_bridges==[middle] and ground.bridge_art.patches.size()==1,"paused binary restore keeps high bridge gap and visual")
		var huts:Array=battle.buildings.filter(func(b):return b.special.get("bridge_span")==current)
		check(not huts.is_empty(),"high span has a bound repair hut")
		if not huts.is_empty():preload("res://scripts/world/civilian_sites.gd").repair(huts[0])
		check(ground.bridge_art.patches.is_empty() and not battle.path_service.is_blocked(middle.get_center()),"real hut repair restores complete baked bridge and road")
		get_tree().paused=false;battle.paused=false
	await finish()
