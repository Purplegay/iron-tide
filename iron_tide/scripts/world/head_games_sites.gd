extends RefCounted

const RETAIL = preload("res://data/head_games_sites.json")
const NAMES := {"CAEUR04":"欧洲民居","CAEUR1":"乡间小屋","CAEUR2":"乡间民居","CAEURO05":"石像","CAFRMA":"农家住宅","CABARN02":"谷仓","CATRAN01":"城堡墓室","CATRAN02":"城堡陵墓","CAWASH18":"喷泉","CAMSC06":"营火","CAARMY03":"军用帐篷","CAARMY04":"野战帐篷","CAPARS04":"欧式楼房","CAPARS06":"欧式街屋","CAFARM01":"农舍"}

static func lights(world) -> void:
	var group := Node2D.new()
	group.name = "TransylvaniaLights"
	group.z_index = DepthLayers.DECAL
	world.add_child(group)
	var gradient := GradientTexture2D.new()
	gradient.fill = GradientTexture2D.FILL_RADIAL
	gradient.fill_from = Vector2(.5,.5)
	gradient.fill_to = Vector2(1,.5)
	gradient.gradient = Gradient.new()
	gradient.gradient.colors = PackedColorArray([Color.WHITE, Color(1,1,1,0)])
	for row in RETAIL.data.lights:
		var sprite := Sprite2D.new()
		sprite.texture = gradient
		sprite.set_meta("retail_light_type",str(row[0]))
		sprite.position = Vector2(row[1],row[2])*55
		var radius := float(row[3])*55/256
		sprite.scale = Vector2.ONE*radius*2/gradient.get_width()
		sprite.modulate = Color(row[5],row[6],row[7],row[4]) if row[4]>0 else Color(0,0,0,-float(row[4]))
		if sprite.position==Vector2(50.5,70.5)*55:sprite.name="CATRAN02"
		if sprite.position==Vector2(109.5,151.5)*55:sprite.name="CATRAN01"
		group.add_child(sprite)

static func overlay_walls(world) -> void:
	for row in RETAIL.data.overlaySites:
		var military: bool = row[0]=="GAWALL"
		var b = world._place_building(row[0],"enemy" if military else "neutral",Vector2(row[1],row[2])*55,true)
		if b != null:
			b.special.native_wall_pitch = 55
			if military: world.HeadGames.assign_wing(b,1)

static func native_catalog(row:Dictionary) -> void:
	row.structures.append(["CAFARM01",-.5,101.5])
	row.site_types.CAFARM01 = {"strength":400,"armor":"wood","sight":4,"foundation":"2x2","canbeoccupied":"yes","maxnumberoccupants":6}
	var health := {}
	for site in RETAIL.data.sites:
		if site[4]=="Civilian House": health[Vector2(site[1],site[2])] = site[3]
	for site in row.structures: site.append(health.get(Vector2(site[1],site[2]),256))

static func super_site(world, clip:String, retail_type: String = ""):
	var entry: Array = {"csof001":["NAMISL",48091,0],"csof010":["GAWEAT",107018,1],"csof125":["YAPPET",85058,-1],"csof128":["YAGNTC",52075,-1]}[clip]
	if not retail_type.is_empty() and retail_type != entry[0]:return null
	var coord := int(entry[1])
	var point := Vector2(201.5-floori(coord/1000.0), coord%1000-10.5)*55
	var dims := str(GameData.get_building(entry[0]).foundation).split("x")
	point += Vector2(1-int(dims[1]),int(dims[0])-1)*27.5
	var building = world._place_building(entry[0],"enemy",point,true)
	if building != null:building.special.s07_launcher=true
	if building != null and int(entry[2])>=0: world.HeadGames.assign_wing(building,entry[2])
	return building
