extends RefCounted

# Read-only runtime inventory. No matching against implementation data here.
static func capture(world, phase: String) -> void:
	var folder := OS.get_environment("YR_MAP_INVENTORY_DIR")
	if folder.is_empty():return
	var sites:Array=[]
	for b in world.buildings:
		if not world.actor_alive(b):continue
		sites.append({"type":b.building_id,"pos":[b.position.x,b.position.y],"side":b.side,"color":b._col.to_html(false),"wing":b.special.get("head_games_wing"),"house":b.special.get("hollywood_house"),"beacon":b.special.get("head_games_beacon"),"foundation":str(b.data.get("foundation","1x1")),"hp":b.hp,"max_hp":b.max_hp,"art":not b._ra2.is_empty()})
	var lights=world.get_node_or_null("TransylvaniaLights")
	if lights!=null:
		for light in lights.get_children():
			if not light.has_meta("retail_light_type"):continue
			sites.append({"type":light.get_meta("retail_light_type"),"pos":[light.position.x,light.position.y],"foundation":"1x1","render_only":true,"color":light.modulate.to_html()})
	var f:=FileAccess.open(folder.path_join(world.map_layout()+"-"+phase+".json"),FileAccess.WRITE)
	if f!=null:f.store_string(JSON.stringify(sites))
