extends RefCounted
## Retail map cells, not a procedural layout with a retail name.
const IDS := ["yr_isleland","yr_ice_age","yr_crctbrd","yr_deepfrze","yr_riverram","yr_mojosprt","yr_unrepent","yr_irvineca","yr_monsterm","yr_transylv","yr_highexpr","yr_moonpatr", "yr_hidvally", "yr_dunepatr", "yr_dryheat", "yr_groundze", "yr_fourcorners", "yr_tourofegypt", "yr_bayopigs", "yr_pacific", "yr_seaofiso", "yr_tsunami", "yr_potomac", "yr_amazon", "yr_lostlake", "yr_shrapnel", "yr_arena", "yr_oceansid", "yr_hills", "yr_valley", "yr_dustbowl", "yr_newhghts", "yr_hailmary", "yr_grinder"]
const NAMES := ["尤复 · Islands on the Land","尤复 · Ice Age","尤复 · Circuit Board","尤复 · 深度冻结","尤复 · 狂暴河流","尤复 · 魔力之魂","尤复 · 不屈战区","尤复 · 尔湾战区","尤复 · 巨兽战区","尤复 · 古堡战区","尤复 · 高爆战区","尤复 · 月面战区", "尤复 · 隐秘山谷", "尤复 · 沙丘巡逻", "尤复 · 干热沙地", "尤复 · 零点城区", "尤复 · 四角战区", "尤复 · 埃及之旅", "红警2 · 猪湾", "红警2 · 太平洋高地", "红警2 · 隔绝之海", "红警2 · 海啸", "红警2 · 波托马克河", "红警2 · 亚马孙河谷", "红警2 · 失落之湖", "红警2 · 弹片山", "红警2 · 竞技场", "红警2 · 海滨", "红警2 · 丘陵", "红警2 · 宝石谷", "红警2 · 沙尘盆地", "红警2 · 新高地", "红警2 · 孤注一掷", "红警2 · 绞肉机"]
const CELL := 55.0
static var _cache:Dictionary={}

static func has(id:String) -> bool:return id in IDS

static func data(id:String) -> Dictionary:
	if not has(id):return {}
	if not _cache.has(id):
		var row:Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://data/maps/%s.json"%id))
		var mask:=PackedByteArray();mask.resize(int(row.side)*int(row.side))
		row.ore_ground = {}
		for tile:Array in row.cells:
			var kind:=int(tile[2])
			if kind in [11, 12, 13, 14]: row.ore_ground[Vector2i(tile[0],tile[1])] = true
			# FinalAlert Defines.h: 0x0c is dirt road, NOT rock; 0x0f is impassable.
			# FinalAlert Loading.cpp also classifies the 0x0a shore type as water.
			mask[int(tile[1])*int(row.side)+int(tile[0])]=2 if kind in [9,10] else (4 if kind in [15,0,7] else 1)
		var settings: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/maps/ore/%s.json" % id))
		var variants := {}
		for i in row.resources.size():
			var resource: Array = row.resources[i]
			variants[Vector2i(resource[0], resource[1])] = int(settings.variants[i]) - 1
		settings.variants = variants
		settings.theater = "ubn" if row.theater=="NEWURBAN" else str(row.theater).left(3).to_lower()
		settings.growth_seconds = float(settings.growth_frames) / BattleClock.RULE_TICKS_PER_SECOND
		settings.drill_seconds = INF if settings.drills.is_empty() else ceilf(1.0 / float(settings.drills[0][3])) / BattleClock.RULE_TICKS_PER_SECOND
		row.drill_cells = {}
		for drill: Array in settings.drills:
			var cell := Vector2i(drill[0], drill[1])
			row.ore_ground.erase(cell)
			row.drill_cells[cell] = true
		row.ore_rules = settings
		row.low_bridge_cells = {}
		row.bridge_base = {}
		var bridge_cells := {}
		for tile:Array in row.bridges:
			bridge_cells[Vector2i(tile[0],tile[1])] = true
			row.ore_ground.erase(Vector2i(tile[0], tile[1]))
			var index:=int(tile[1])*int(row.side)+int(tile[0])
			row.bridge_base[Vector2i(tile[0],tile[1])] = int(mask[index])
			if str(tile[2]).begins_with("LOBRDG"):
				row.low_bridge_cells[Vector2i(tile[0],tile[1])] = true
				mask[index] = 1 # A low deck carries land traffic and closes the water lane.
			else:
				mask[index] = 1 | (mask[index] & 2)
		row.bridge_decks = []
		row.bridge_sections = {}
		row.bridge_section_by_cell = {}
		# Connected retail deck cells, cached with the map; never scan tiles per unit tick.
		while not bridge_cells.is_empty():
			var first: Vector2i = bridge_cells.keys()[0]
			var pending := [first]
			bridge_cells.erase(first)
			var bounds := Rect2(Vector2(first)*CELL,Vector2.ONE*CELL)
			while not pending.is_empty():
				var point: Vector2i = pending.pop_back()
				bounds = bounds.merge(Rect2(Vector2(point)*CELL,Vector2.ONE*CELL))
				for offset in [Vector2i.LEFT,Vector2i.RIGHT,Vector2i.UP,Vector2i.DOWN]:
					var neighbor: Vector2i = point+offset
					if bridge_cells.erase(neighbor): pending.append(neighbor)
			row.bridge_decks.append(bounds)
			var overlay := ""
			for tile: Array in row.bridges:
				if Vector2i(tile[0],tile[1]) == first: overlay = str(tile[2]); break
			var geometry = preload("res://scripts/world/bridge_sections.gd")
			var sections: Array = geometry.split(bounds,geometry.native_horizontal(overlay,bounds))
			row.bridge_sections[bounds] = sections
			for tile: Array in row.bridges:
				var cell := Vector2i(tile[0],tile[1])
				var center := (Vector2(cell)+Vector2.ONE*0.5)*CELL
				if not bounds.has_point(center): continue
				for section: Rect2 in sections:
					if section.has_point(center): row.bridge_section_by_cell[cell] = section; break
		row.mask=mask
		_cache[id]=row
	return _cache[id]

static func size_for(id:String) -> float:return float(data(id).side)*CELL

static func flags(id:String,point:Vector2) -> int:
	var row:=data(id)
	var x:=floori(point.x/CELL);var y:=floori(point.y/CELL)
	if x<0 or y<0 or x>=int(row.side) or y>=int(row.side):return 0
	return row.mask[y*int(row.side)+x]

# Older saves could place ships inside low bridges. Only relocate those hulls,
# after the restored buildings, occupants and water grid are all available.
static func recover_low_bridge_ships(world) -> void:
	if not has(world.map_layout()): return
	var deck_cells: Dictionary = data(world.map_layout()).low_bridge_cells
	if deck_cells.is_empty(): return
	for ship in world.units:
		if not world.actor_alive(ship) or not ship.is_naval or ship.is_amphibious or ship.embarked_in != null: continue
		var start_cell := Vector2i((ship.position / CELL).floor())
		if not deck_cells.has(start_cell) or world.path_service.in_naval_water(ship.position): continue
		var water := _free_water_near_deck(world, ship, start_cell)
		if water.is_finite():
			ship.position = water
			ship.reset_physics_interpolation()
			if not ship.has_move_order: ship.move_target = water

static func _free_water_near_deck(world, ship, start_cell: Vector2i) -> Vector2:
	for ring in range(1, 9):
		var best := Vector2.INF
		var best_distance := INF
		for y in range(-ring, ring + 1):
			for x in range(-ring, ring + 1):
				if maxi(absi(x), absi(y)) != ring: continue
				var point := (Vector2(start_cell + Vector2i(x,y)) + Vector2(0.5,0.5)) * CELL
				var distance: float = ship.position.distance_squared_to(point)
				if distance >= best_distance or not world.path_service.in_naval_water(point) or world.path_service.is_blocked(point, true): continue
				var occupied := false
				for other in world.units:
					if other == ship or not world.actor_alive(other) or other.embarked_in != null or other.is_air_target(): continue
					if point.distance_to(other.position) < ship.radius + other.radius:
						occupied = true
						break
				if not occupied:
					best = point
					best_distance = distance
		if best.is_finite(): return best
	return Vector2.INF

static func start(id:String,enemy:=false) -> Vector2:
	var points:Array=data(id).starts
	var first:=Vector2(points[0][1],points[0][2])*CELL
	if not enemy:return _spawn_clear(id,first)
	var farthest:=first
	for entry:Array in points:
		var point:=Vector2(entry[1],entry[2])*CELL
		if point.distance_squared_to(first)>farthest.distance_squared_to(first):farthest=point
	return _spawn_clear(id,farthest)

static func _spawn_clear(id:String,anchor:Vector2) -> Vector2:
	# Retail waypoints mark a starting area, not a guaranteed building footprint.
	for ring in range(12):
		for step in maxi(1,ring*8):
			var point:=anchor+Vector2.RIGHT.rotated(TAU*step/maxi(1,ring*8))*ring*CELL
			if clear_rect(id,Rect2(point-Vector2.ONE*100,Vector2.ONE*200)):return point
	return anchor

static func water(id:String) -> Array:
	# Merge adjacent equal row runs; the runtime shader does not create one node per cell.
	var row:=data(id);var result:Array=[];var previous:Dictionary={}
	for y in int(row.side):
		var current:Dictionary={};var x:=0
		while x<int(row.side):
			if (int(row.mask[y*int(row.side)+x])&2)==0:x+=1;continue
			var begin:=x
			while x<int(row.side) and (int(row.mask[y*int(row.side)+x])&2)!=0:x+=1
			var key:=Vector2i(begin,x)
			if previous.has(key):
				var index:int=previous[key];var rect:Rect2=result[index];rect.size.y+=CELL;result[index]=rect;current[key]=index
			else:
				current[key]=result.size();result.append(Rect2(begin*CELL,y*CELL,(x-begin)*CELL,CELL))
		previous=current
	return result

static func clear_rect(id:String,rect:Rect2,naval:=false) -> bool:
	var lo:Vector2i=Vector2i((rect.position/CELL).floor())
	var hi:Vector2i=Vector2i(((rect.end-Vector2.ONE*0.01)/CELL).floor())
	var row := data(id)
	var side := int(row.side)
	var required := 2 if naval else 1
	if lo.x < 0 or lo.y < 0 or hi.x >= side or hi.y >= side:
		return false
	var mask: PackedByteArray = row.mask
	var drills: Dictionary = row.drill_cells
	for y in range(lo.y,hi.y+1):
		for x in range(lo.x,hi.x+1):
			if row.bridge_base.has(Vector2i(x,y)) or drills.has(Vector2i(x,y)) or (mask[y*side+x] & required) == 0:
				return false
	return true

static func populate(world) -> void:
	if not BattleSaves.pending.is_empty():return
	var row:=data(world.map_layout())
	var ore = load("res://scripts/world/native_ore.gd")
	ore.install_drills(world)
	for resource:Array in row.resources:
		ore.spawn(world, Vector2i(resource[0],resource[1]),str(resource[2]),int(resource[3]))
	world.allied_state.native_ore_version = 1
	# Preserve native neutral sites for which we have verified building art.
	for site:Array in row.structures:
		var id:String=site[0]
		if not RA2Art.has_art(id):continue
		var point:=Vector2(site[1],site[2])*CELL
		var source:Dictionary=row.site_types[id]
		var dimensions:PackedStringArray=str(source.foundation).split("x")
		if dimensions.size()==2:
			point+=Vector2(-(float(dimensions[1])-1),(float(dimensions[0])-1))*CELL*.5
		if world.buildings.any(func(b):return b.position.distance_to(point)<b.radius+50):continue
		if id in ["CAOILD","CAHSE01","CABHUT"]:
			load("res://scripts/world/civilian_sites.gd").create(world,id,point)
		else:
			var definition:Dictionary={"id":id,"name":"中立建筑 · "+id,"faction":"civilian","hp":float(source.strength),"armor":"structure","ra2_armor":str(source.armor),"radius":38.0,"sight":float(source.sight)*CELL,"foundation":str(source.foundation),"cost":0,"power":0,"tags":["civilian"],"base_normal":false}
			if str(source.canbeoccupied).to_lower()=="yes":
				definition.garrison_slots=int(source.maxnumberoccupants)
				definition.garrison_weapons=GameData.get_building("NABNKR").garrison_weapons
			var building:=Building.new()
			building.setup(definition,"neutral",point,world,true)
			world.add_child(building);world.buildings.append(building)
			building._buildup_play=-1
	bind_bridge_huts(world)

# Retail huts are separate structures; associate each with its adjacent deck.
# Also called after snapshot restore, since older saves lack this association.
static func bind_bridge_huts(world) -> void:
	var decks: Array = data(world.map_layout()).bridge_decks
	for hut in world.buildings:
		if not world.actor_alive(hut) or hut.building_id != "CABHUT": continue
		var closest := Rect2()
		var distance := CELL * 4.0
		for span: Rect2 in decks:
			var reach: float = hut.position.distance_to(hut.position.clamp(span.position,span.end))
			if reach < distance:
				distance = reach
				closest = span
		if closest.has_area():
			hut.special.bridge_span = closest
			if not hut.special.has("bridge_repaired"): hut.special.bridge_repaired = true

static func find_base_site(world,anchor:Vector2,bid:String,miner_id:String="") -> Vector2:
	var poly := Building.placement_poly(GameData.get_building(bid))
	var footprint := Placement.aabb(poly)
	var apron := Rect2()
	if not miner_id.is_empty():
		apron = Building.refinery_apron(poly, float(GameData.get_unit(miner_id).radius))
	for ring in range(18):
		for step in maxi(1,ring*8):
			var point:Vector2=world.snap_build_pos(anchor+Vector2.RIGHT.rotated(TAU*step/maxi(1,ring*8))*ring*55)
			if apron.has_area():
				var work_area := Rect2(point + apron.position, apron.size)
				if not clear_rect(world.map_layout(), work_area):continue
				if world.buildings.any(func(b): return work_area.intersects(Placement.aabb(b.footprint_poly(), b.position), true)):continue
			if clear_rect(world.map_layout(),Rect2(footprint.position+point,footprint.size)) and world._skirmish_spot_ok(point,90):return point
	return Vector2.INF
