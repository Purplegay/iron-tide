extends Node2D
## Independent shared visibility: 40-world-unit cells, persistent terrain exploration.
## Does not model terrain occlusion, stealth detection or remembered enemy buildings.

const CELL := 40.0
# An unpacked Allied or Soviet yard scouts 12 original cells instead of 8.
const CONSTRUCTION_YARD_SIGHT_SCALE := 1.5
const SCOUT_SIGHT_SECONDS := 5.0
const BLAST_SIGHT_SECONDS := 3.0
const DEATH_SIGHT_SECONDS := 3.0
const FIRE_REVEAL_SECONDS := 3.0
const FIRE_REVEAL_RADIUS := 120.0
const SUPERWEAPON_REVEAL_SECONDS := 10.0
const EXPEDITION_INTEL_SIGHT_SECONDS := 20.0
const MAX_HELD_SIGHT_SECONDS := maxf(SCOUT_SIGHT_SECONDS, SUPERWEAPON_REVEAL_SECONDS)
const SUPERWEAPON_REVEAL_RADIUS := 2.0 * Ra2Damage.PX_PER_CELL
const IVAN_BOMB_SIGHT := 3.0 * CELL
# Presentation only. Do not extend visibility/targeting while terrain fades.
const EXPLORED_OPACITY := 0.45
const FOG_RETURN_FADE := 1.2
var battle: Battle
var width := 0
var visible_cells: Dictionary = {}
var explored_cells: Dictionary = {}
var texture: ImageTexture
var mask_image: Image
var starting_ore: Dictionary = {}
var firing_positions: Dictionary = {}
var _held_buildings := {"ally": {}, "enemy": {}} # Coalesce a volley against the same building.
var sight_until := {"ally": {}, "enemy": {}}
var _lease_index: Dictionary = {}
const HeldSightLeases = preload("res://scripts/world/held_sight_leases.gd")
var _scouts:Dictionary = {} # Last sampled footprints, indexed by observing actor.
var _scout_sample_time := 0.0
var sight_clock := 0.0
var rebuild_count := 0
var _elapsed := 0.0
var minimap_mask_revision := 0
# Ordinary scouting is shared by allies. Batch the union of their discs in
# native image storage while keeping each observer's explored/held cells separate.
var _live_masks: Dictionary = {}
# One union per alliance for the buildings that did not move/change range.
# Rebuilt from current footprints on capture, destruction, power/weapon changes.
var _foundation_masks: Dictionary = {}
var _foundation_keys: Dictionary = {}
var _scout_tiles: Dictionary = {}
var _building_sight_cells: Dictionary = {}
var _white_cells: Image
var _previous_visible := PackedByteArray()
var _previous_explored := PackedByteArray()
var _fading_cells: Dictionary = {}

# Each worker writes one alliance's private CPU image. Scene nodes, permanent
# exploration, timers, texture uploads and publishing stay on the main thread.
class SightBatch:
	var points := PackedVector2Array()
	var radii := PackedFloat64Array()
	var mask: Image
	var width: int
	var task := -1
	var tiles: Dictionary = {}

	func rasterize() -> void:
		var next := {}
		for i in points.size():
			var point := points[i]
			var radius := radii[i]
			var tile: Dictionary = tiles.get(point,{})
			if tile.is_empty() or tile.radius != radius:
				var lo := Vector2i(maxi(0,floori((point.x-radius)/CELL)),maxi(0,floori((point.y-radius)/CELL)))
				var hi := Vector2i(mini(width-1,floori((point.x+radius)/CELL)),mini(width-1,floori((point.y+radius)/CELL)))
				if hi.x < lo.x or hi.y < lo.y: continue
				var image := Image.create(hi.x-lo.x+1,hi.y-lo.y+1,false,Image.FORMAT_LA8)
				image.fill(Color.TRANSPARENT)
				# Calculate in original world coordinates, including exact cell edges.
				for y in range(lo.y,hi.y+1):
					var dy := point.y-clampf(point.y,y*CELL,(y+1)*CELL)
					var span2 := radius*radius-dy*dy
					if span2 < 0: continue
					var span := sqrt(span2)
					var left := maxi(lo.x,ceili((point.x-span)/CELL)-1)
					var right := mini(hi.x,floori((point.x+span)/CELL))
					if left <= right: image.fill_rect(Rect2i(left-lo.x,y-lo.y,right-left+1,1),Color.WHITE)
				tile = {"radius":radius,"image":image,"origin":lo}
			var image: Image = tile.image
			mask.blit_rect_mask(image,image,Rect2i(Vector2i.ZERO,image.get_size()),tile.origin)
			next[point] = tile
		tiles = next # Bound retention to the current scouts; no moving-position history.

	static func raster_disc(image: Image, size: int, point: Vector2, radius: float) -> void:
		var lo := Vector2i(floori((point.x - radius) / CELL), floori((point.y - radius) / CELL))
		var hi := Vector2i(floori((point.x + radius) / CELL), floori((point.y + radius) / CELL))
		for y in range(maxi(0, lo.y), mini(size - 1, hi.y) + 1):
			var dy := point.y - clampf(point.y, y * CELL, (y + 1) * CELL)
			var span2 := radius * radius - dy * dy
			if span2 < 0: continue
			var span := sqrt(span2)
			var left := maxi(maxi(lo.x, 0), ceili((point.x - span) / CELL) - 1)
			var right := mini(mini(hi.x, size - 1), floori((point.x + span) / CELL))
			if left <= right: image.fill_rect(Rect2i(left, y, right - left + 1, 1), Color.WHITE)

	static func raster_vacated(image: Image, size: int, old: Dictionary, current: Dictionary) -> void:
		var p: Vector2 = old.point
		var radius: float = old.radius
		var lo := Vector2i(floori((p.x - radius) / CELL), floori((p.y - radius) / CELL))
		var hi := Vector2i(floori((p.x + radius) / CELL), floori((p.y + radius) / CELL))
		for y in range(maxi(0, lo.y), mini(size - 1, hi.y) + 1):
			var dy := p.y - clampf(p.y, y * CELL, (y + 1) * CELL)
			var span2 := radius * radius - dy * dy
			if span2 < 0: continue
			var span := sqrt(span2)
			var left := maxi(maxi(lo.x, 0), ceili((p.x - span) / CELL) - 1)
			var end := mini(mini(hi.x, size - 1), floori((p.x + span) / CELL)) + 1
			if left >= end: continue
			var skip_left := end
			var skip_end := end
			if not current.is_empty():
				var at: Vector2 = current.point
				var r: float = current.radius
				var offset_y := at.y - clampf(at.y, y * CELL, (y + 1) * CELL)
				var overlap2 := r * r - offset_y * offset_y
				if overlap2 >= 0:
					var overlap := sqrt(overlap2)
					skip_left = clampi(ceili((at.x - overlap) / CELL) - 1, left, end)
					skip_end = clampi(floori((at.x + overlap) / CELL) + 1, left, end)
			if skip_end <= skip_left:
				image.fill_rect(Rect2i(left, y, end - left, 1), Color.WHITE)
			else:
				if skip_left > left: image.fill_rect(Rect2i(left, y, skip_left - left, 1), Color.WHITE)
				if skip_end < end: image.fill_rect(Rect2i(skip_end, y, end - skip_end, 1), Color.WHITE)

func setup(world) -> void:
	battle = world
	width = ceili(battle.map_size / CELL)
	for side in (["ally","enemy"] if BattleRequest.house_teams.is_empty() else BattleRequest.house_teams.keys()):
		_held_buildings[side] = {}
		sight_until[side] = {}
		var cells := PackedByteArray()
		cells.resize(width * width)
		cells.fill(0)
		visible_cells[side] = cells.duplicate()
		explored_cells[side] = cells.duplicate()
	z_index = 4090
	process_priority = 100
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	for host in [battle, battle.enemy_root]:
		host.child_entered_tree.connect(_filter_spawned_actor)
	for host in [battle.effects_root, battle.projectiles_root]:
		host.child_entered_tree.connect(func(child): _filter_transient.call_deferred(child))
	_remember_starting_ore()
	rebuild()

func _filter_spawned_actor(actor) -> void:
	# Constructors set identity/position before add_child. Hide in that same call,
	# so an enemy produced on explored terrain cannot flash before the next tick.
	if actor is Unit or actor is Building:
		actor.visible = battle.actor_visible_to("ally", actor)

func _remember_starting_ore() -> void:
	# Starting resource intelligence keeps both economies usable on generated maps.
	# Remember terrain only: rebuild clears current visibility before any draw.
	for side in visible_cells:
		var nearest = null
		var distance := INF
		for actor in battle.units + battle.buildings:
			if not battle.actor_alive(actor) or actor.side != side:
				continue
			for ore in get_tree().get_nodes_in_group("resource_nodes"):
				if not is_instance_valid(ore) or ore.is_queued_for_deletion() or battle.in_water_world(ore.global_position):
					continue
				var d: float = actor.global_position.distance_squared_to(ore.global_position)
				if d < distance:
					distance = d
					nearest = ore
		if nearest != null:
			starting_ore[side] = nearest.global_position
			_reveal(side, nearest.global_position, CELL * 2.0)

func _process(delta: float) -> void:
	var _call_log_scope = preload("res://scripts/world/battle_call_counters.gd").enter(20)
	if battle == null or battle.ended or battle.paused or get_tree().paused:
		return
	sight_clock += maxf(0.0,delta)
	for side in _held_buildings: _held_buildings[side].clear()
	_advance_visual(maxf(0.0, delta))
	var reveal_expired := false
	var scout_cover := {} # Lazy, valid only for this synchronous expiry pass.
	for id in firing_positions.keys():
		firing_positions[id].remaining -= maxf(0.0, delta)
		if firing_positions[id].remaining <= 0.0:
			var expired: Dictionary = firing_positions[id]
			firing_positions.erase(id)
			# An independent held lease or current scout can cover this whole shot.
			# Remove the shot immediately; ordinary scout changes keep their cadence.
			if not reveal_expired:
				if _held_covers_firing(expired):
					preload("res://scripts/world/battle_call_counters.gd").iterations(84,1)
				elif _scout_covers_firing(expired,scout_cover):
					preload("res://scripts/world/battle_call_counters.gd").iterations(86,1)
				else: reveal_expired = true
	for host in [battle.effects_root, battle.projectiles_root]:
		for child in host.get_children():
			_filter_transient(child)
	_elapsed += delta
	var cadence := 0.1
	if battle is Battle and battle.frame_pacing != null:
		cadence = battle.frame_pacing.FOG_SECONDS[battle.frame_pacing.tier]
	# Ordinary scouting never outruns the 15 Hz world; immediate fire reveals
	# and expiry still publish synchronously through their existing paths.
	cadence = maxf(cadence, Engine.time_scale / 15.0)
	if reveal_expired or _elapsed >= cadence:
		rebuild()

# A sufficient held-sight proof only; unheld cells reject this proof.
# The caller separately checks current scouts before rebuilding. Held deadlines
# are read live, with the same strict expiry and alliance sharing as the stamps.
func _held_covers_firing(shot: Dictionary) -> bool:
	var _call_log_scope = preload("res://scripts/world/battle_call_counters.gd").enter(83)
	var owner: String = shot.side
	var observers: Array[Dictionary] = []
	for side in visible_cells:
		if side == owner or (BattleRequest.house_teams.has(side) and BattleRequest.friendly(side,owner)):
			observers.append(sight_until[side])
	if observers.is_empty(): return true
	var p: Vector2 = shot.position
	var radius := FIRE_REVEAL_RADIUS
	var lo := Vector2i(floori((p.x-radius)/CELL),floori((p.y-radius)/CELL))
	var hi := Vector2i(floori((p.x+radius)/CELL),floori((p.y+radius)/CELL))
	for y in range(maxi(0,lo.y),mini(width-1,hi.y)+1):
		var dy := p.y-clampf(p.y,y*CELL,(y+1)*CELL)
		var span2 := radius*radius-dy*dy
		if span2 < 0: continue
		var half_span := sqrt(span2)
		var left := maxi(maxi(lo.x,0),ceili((p.x-half_span)/CELL)-1)
		var right := mini(mini(hi.x,width-1),floori((p.x+half_span)/CELL))
		for x in range(left,right+1):
			var index := y*width+x
			for held: Dictionary in observers:
				preload("res://scripts/world/battle_call_counters.gd").iterations(83,1)
				if float(held.get(index,0.0)) <= sight_clock: return false
	return true

# A single currently alive friendly scout must contain the whole firing disc.
# The margin makes round-off conservative. Partial overlap is never sufficient.
# Snapshot only during this non-yielding pass; next frame reads deaths, ownership,
# transport, position, deployment and effective weapon/sight range again.
func _scout_covers_firing(shot: Dictionary, cache: Dictionary) -> bool:
	var _call_log_scope = preload("res://scripts/world/battle_call_counters.gd").enter(85)
	var owner: String = shot.side
	if not visible_cells.has(owner): return false
	if not cache.has(owner):
		var positions: Array[Vector2] = []
		var clearances: Array[float] = []
		for actor in battle.units + battle.buildings:
			preload("res://scripts/world/battle_call_counters.gd").iterations(85,1)
			if not battle.actor_alive(actor) or not visible_cells.has(actor.side) or not BattleRequest.friendly(owner,actor.side): continue
			if actor.special.has("expansion_temporary") or (actor is Unit and actor.embarked_in != null): continue
			var clearance := vision_radius(actor)-FIRE_REVEAL_RADIUS-0.01
			if clearance <= 0.0: continue
			positions.append(actor.global_position)
			clearances.append(clearance*clearance)
		cache[owner] = {"positions":positions,"clearances":clearances}
	var sources: Dictionary = cache[owner]
	var at: Vector2 = shot.position
	for i in sources.positions.size():
		if at.distance_squared_to(sources.positions[i]) < sources.clearances[i]: return true
	return false

## Reveal the shot location to the attacked side, never track an unseen retreat.
func reveal_attack(attacker, target) -> void:
	if not battle.actor_alive(attacker) or not battle.actor_alive(target):
		return
	if BattleRequest.friendly(attacker.side,target.side) or not visible_cells.has(target.side):
		return
	if attacker is Unit and attacker.embarked_in != null:
		return
	var observer: String = target.side
	var origin: Vector2 = attacker.global_position
	var previous: Dictionary = firing_positions.get(attacker.get_instance_id(), {})
	firing_positions[attacker.get_instance_id()] = {
		"side": observer, "position": origin, "remaining": FIRE_REVEAL_SECONDS,
	}
	# Hidden first shots must update targetability, sprites and the fog texture in
	# the same call. Already visible volleys only refresh their expiry/position.
	var changed := not is_visible_at(observer, origin)
	var ping_origin := changed and BattleRequest.friendly(observer, "ally")
	var player_building_changed := false
	if target is Building and visible_cells.has(attacker.side) and battle.actor_visible_to(attacker.side, target):
		if _hold_building(attacker.side, target):
			changed = true
			player_building_changed = attacker.side == "ally"
	if attacker is Building:
		changed = _hold_building(observer, attacker) or changed
	if changed:
		# A moving shot can replace an old footprint. Rebuild in that case to
		# revoke any expired vision, including temporary sight from another house.
		if not previous.is_empty() and (previous.side != observer or previous.position != origin):
			rebuild()
		else:
			_reveal(observer, origin, FIRE_REVEAL_RADIUS)
			# The reveal disc is shared with the observer's allies. The target
			# building footprint above is stamped for the attacking house only.
			if player_building_changed or BattleRequest.friendly("ally", observer):
				_publish_combat_sight()
	if ping_origin:
		Events.emit_radar_ping(origin, "firing_origin")

## A successful strategic launch exposes the source footprint and the target area.
## Existing held cells preserve expiry across saves without tracking a moved source.
func reveal_superweapon(source: Building, target := Vector2.INF) -> void:
	if not battle.actor_alive(source) or not source.broadcasts_superweapon() or not visible_cells.has(source.side): return
	for observer in visible_cells:
		if BattleRequest.friendly(observer,source.side): continue
		_hold_building(observer, source, SUPERWEAPON_REVEAL_SECONDS)
		_reveal(observer, source.global_position, SUPERWEAPON_REVEAL_RADIUS, SUPERWEAPON_REVEAL_SECONDS)
	if target.is_finite():
		var radius := SUPERWEAPON_REVEAL_RADIUS
		if source.sw_type()=="MultiMissile": radius=nuclear_reveal_radius()
		elif source.sw_type()=="LightningStorm": radius=storm_reveal_radius(source.superweapon.get("storm",{}))
		else: radius=maxf(radius,float(source.superweapon.get("radius",radius)))
		_hold_superweapon_area(target,radius)
	rebuild()

static func nuclear_reveal_radius() -> float:
	var payload: Dictionary = preload("res://scripts/core/yr_death_rules.gd").data().weapons.NUKEPAYLOAD
	return maxf(SUPERWEAPON_REVEAL_RADIUS,Ra2Damage.cells(payload.warhead)*Ra2Damage.PX_PER_CELL)

static func storm_reveal_radius(rules: Dictionary, version := 2) -> float:
	var cells := maxf(0.0,float(rules.get("cell_spread",10)))
	var spread := cells if version<2 else maxf(0.0,cells-1.0)*0.5
	# Cover square scatter corners, lightning-rod attraction and local bolt art.
	return spread*Ra2Damage.PX_PER_CELL*sqrt(2.0)+3.5*Ra2Damage.PX_PER_CELL

func _hold_superweapon_area(point: Vector2, radius: float) -> void:
	if not point.is_finite(): return
	# Broadcast to each observer once; ordinary alliance sharing would restamp peers.
	for observer in visible_cells:
		_stamp_one(observer,point,radius,SUPERWEAPON_REVEAL_SECONDS,false,{})

func reveal_superweapon_impact(point: Vector2, radius: float) -> void:
	_hold_superweapon_area(point,maxf(radius,SUPERWEAPON_REVEAL_RADIUS))
	_publish_combat_sight()

func _hold_active_superweapons() -> void:
	var launches: Array = battle.allied_state.get("soviet_nukes",[])
	if not launches.is_empty():
		var radius := nuclear_reveal_radius()
		for launch in launches:
			_hold_superweapon_area(launch.point,radius)
	for state in LightningStorm.storms(battle):
		_hold_superweapon_area(state.target,storm_reveal_radius(state.rules,int(state.get("version",1))))

func reveal_building_hit(observer: String, building: Building) -> void:
	if not visible_cells.has(observer) or observer == building.side or not battle.actor_visible_to(observer, building): return
	if _hold_building(observer, building): _publish_combat_sight()

## Cover the hull, including elevated art projected onto fog cells. Snapshot the
## cells so later shots renew their own local window without granting enemy sight.
func _hold_building(observer: String, building: Building, hold_seconds := FIRE_REVEAL_SECONDS) -> bool:
	var repeated: Dictionary = _held_buildings[observer]
	var id := building.get_instance_id()
	if hold_seconds > 0.0:
		if repeated.has(id) and hold_seconds <= FIRE_REVEAL_SECONDS: return false
		repeated[id] = true
	return _apply_building_sight(observer, _building_sight_indices(building), hold_seconds)

func _building_sight_indices(building: Building) -> PackedInt32Array:
	var id := building.get_instance_id()
	var rect := building.combat_sight_rect()
	var projection := Transform2D(Iso.dir(Vector2.RIGHT), Iso.dir(Vector2.DOWN), Vector2.ZERO)
	# The mask uses bilinear sampling. Include the four texels around each body pixel.
	var margin := (projection.x.abs() + projection.y.abs()) * CELL
	rect = Rect2(rect.position - margin, rect.size + 2.0 * margin)
	var cached: Dictionary = _building_sight_cells.get(id,{})
	if cached.get("rect") == rect and cached.get("projection") == projection and cached.get("position") == building.global_position and cached.get("width") == width:
		return cached.indices
	var ground := projection.affine_inverse() * rect
	ground.position += building.global_position
	var lo := Vector2i((ground.position / CELL).floor()).clampi(0, width - 1)
	var hi := Vector2i((ground.end / CELL).floor()).clampi(0, width - 1)
	var indices := _building_footprint_cells(rect, projection, building.global_position, lo, hi)
	_building_sight_cells[id] = {"rect":rect,"projection":projection,"position":building.global_position,"width":width,"indices":indices}
	return indices

func _apply_building_sight(observer: String, indices: PackedInt32Array, hold_seconds: float) -> bool:
	var cells: PackedByteArray = visible_cells[observer]
	var explored: PackedByteArray = explored_cells[observer]
	var held: Dictionary = sight_until[observer]
	var leases: HeldSightLeases = _lease_index.get(observer)
	var changed_leases: Array = []
	var until := sight_clock + hold_seconds
	var changed := false
	for index in indices:
		changed = changed or cells[index] == 0
		if hold_seconds > 0.0 and until > float(held.get(index, 0.0)):
			held[index] = until
			if leases != null: changed_leases.append(index)
		cells[index] = 1
		explored[index] = 1
	if leases != null and not changed_leases.is_empty(): leases.record(held, changed_leases, until)
	return changed

# All observers in a synchronous rebuild see the same current sprite footprint.
func _broadcast_site_sight(building: Building) -> void:
	var indices := PackedInt32Array()
	var prepared := false
	var stamped_teams := {}
	for observer in visible_cells:
		if BattleRequest.friendly(observer, building.side): continue
		if not prepared:
			indices = _building_sight_indices(building)
			prepared = true
		_apply_building_sight(observer, indices, 0.0)
		if not _live_masks.is_empty():
			var team = BattleRequest.house_teams.get(observer, observer)
			if stamped_teams.has(team): continue
			stamped_teams[team] = true
		_reveal(observer, building.global_position, SUPERWEAPON_REVEAL_RADIUS)


func _building_footprint_cells(rect: Rect2, projection: Transform2D, position: Vector2, lo: Vector2i, hi: Vector2i) -> PackedInt32Array:
	var indices := PackedInt32Array()
	for y in range(lo.y, hi.y + 1):
		for x in range(lo.x, hi.x + 1):
			var point := (Vector2(x, y) + Vector2(0.5, 0.5)) * CELL
			if rect.has_point(projection * (point - position)): indices.append(y * width + x)
	return indices

func _filter_transient(node) -> void:
	if not is_instance_valid(node) or not node is Node2D:
		return
	# Shared debris renderer lives at the origin and checks each fragment in _draw.
	if node.is_in_group("per_piece_fog_visibility"): return
	# Beams store world endpoints rather than setting their Node2D position.
	if node is Effects.Beam and node.sight_from.is_finite() and node.sight_to.is_finite():
		node.visible = is_visible_at("ally", node.sight_from) and is_visible_at("ally", node.sight_to)
	elif node.get("from") is Vector2 and node.get("to") is Vector2:
		node.visible = is_visible_at("ally", node.get("from")) and is_visible_at("ally", node.get("to"))
	else:
		node.visible = is_visible_at("ally", node.global_position)

func _index(p: Vector2) -> int:
	if p.x < 0.0 or p.y < 0.0 or p.x >= battle.map_size or p.y >= battle.map_size:
		return -1
	return int(p.y / CELL) * width + int(p.x / CELL)

func is_visible_at(side: String, p: Vector2) -> bool:
	var index := _index(p)
	return index >= 0 and visible_cells.has(side) and visible_cells[side][index] != 0

func is_explored_at(side: String, p: Vector2) -> bool:
	var index := _index(p)
	return index >= 0 and explored_cells.has(side) and explored_cells[side][index] != 0

func reset_exploration(side: String) -> void:
	if not explored_cells.has(side): return
	sight_until[side].clear()
	for id in _scouts.keys():
		if _scouts[id].side == side: _scouts.erase(id)
	explored_cells[side].fill(0)
	for id in firing_positions.keys():
		if firing_positions[id].side == side: firing_positions.erase(id)
	if side == "ally":
		_previous_visible.resize(width * width)
		_previous_visible.fill(0)
		_fading_cells.clear()
	# Current scouts and an operational satellite still provide real sight.
	rebuild()

## Project rule: retain scouting sight, but never leave the current weapon range blind.
## Read derived range each rebuild so deployment, elite weapons and IFV passengers agree.
func vision_radius(actor) -> float:
	if actor is Unit:
		var level:=int(BattleRequest.combat_context.get("expedition",{}).get("research",{}).get("intel",0)) if actor.side=="ally" else 0
		return _unit_vision_radius(actor)*(1.0+.01*int(level>=2)+.01*int(level>=6))
	if actor.special.has("expansion_temporary"):return 0.0
	var radius := maxf(CELL, actor.sight)
	if actor is Building and actor.building_id in ["GACNST", "NACNST"] and not actor.under_construction:
		radius = maxf(radius, actor.sight * CONSTRUCTION_YARD_SIGHT_SCALE)
	if actor is Unit: radius = maxf(radius, NavalContact.sensor_range(actor))
	if actor is Building and actor.data.has("garrison_weapons"):
		var garrison = preload("res://scripts/units/civilian_orders.gd")
		return maxf(radius, garrison.bunker_range(actor)) if garrison.has_gunner(actor) else radius
	var armed: bool = not actor.weapon.is_empty()
	if actor is Unit:
		armed = not actor.is_harvester and not actor._active_weapon().is_empty()
	var weapon_reach: float = OpenTopped.command_range(actor) if actor is Unit else actor.attack_range
	var result:=maxf(radius, weapon_reach) if armed else radius
	if actor is Unit and actor.passive.get("id")==Unit.DomainCards.SCOUT:result*=1.0+Unit.DomainCards.passive_bonus(actor,Unit.DomainCards.SCOUT)
	return result

func _unit_vision_radius(unit: Unit) -> float:
	if unit.special.has("expansion_temporary"): return 0.0
	var radius := maxf(maxf(CELL, unit.sight), NavalContact.sensor_range(unit))
	if not unit.mobile_yard.is_empty():
		radius = maxf(radius, float(unit.mobile_yard.get("sight", 300)) * CONSTRUCTION_YARD_SIGHT_SCALE)
	if not unit.is_harvester and not unit._active_weapon().is_empty():
		radius = maxf(radius, OpenTopped.command_range(unit))
	if unit.passive.get("id") == Unit.DomainCards.SCOUT:
		radius *= 1.0 + Unit.DomainCards.passive_bonus(unit, Unit.DomainCards.SCOUT)
	return radius+preload("res://scripts/units/progression_expansion_2.gd").sight(unit)

func hold_unit_sight(unit) -> void:
	_scouts.erase(unit.get_instance_id()) # Death supplies its own three-second sight.
	if unit.embarked_in != null or not visible_cells.has(unit.side): return
	_stamp_sight(unit.side,unit.global_position,vision_radius(unit), DEATH_SIGHT_SECONDS, true)
	if unit.special.has("spy_photo"):
		_stamp_sight(unit.side,unit.special.spy_photo,float(unit.data.recon_camera.radius), DEATH_SIGHT_SECONDS, true)

# A moving contact grants its current footprint only. Ordinary scout hold time
# would otherwise keep feeding live intelligence after the mark expired.
func reveal_contact(observer:String,target) -> void:
	if battle.actor_alive(target) and target.embarked_in==null and target.side!=observer:
		_reveal(observer,target.global_position,vision_radius(target))

func reveal_ivan_blast(side: String, point: Vector2) -> void:
	_reveal(side, point, IVAN_BOMB_SIGHT, BLAST_SIGHT_SECONDS)

func _reveal(side: String, p: Vector2, radius: float, hold_seconds := 0.0) -> void:
	_stamp_sight(side, p, radius, hold_seconds, false)

func _stamp_sight(side: String, p: Vector2, radius: float, hold_seconds: float, only_visible: bool, current: Dictionary = {}) -> void:
	if not _live_masks.is_empty() and hold_seconds == 0 and not only_visible and current.is_empty() and visible_cells.has(side):
		var team = BattleRequest.house_teams.get(side,side)
		_stamp_one(side,p,radius,hold_seconds,only_visible,current,_live_masks[team])
		return
	for member: String in BattleRequest.house_teams:
		if member != side and BattleRequest.friendly(member,side):
			_stamp_one(member,p,radius,hold_seconds,only_visible,current)
	_stamp_one(side,p,radius,hold_seconds,only_visible,current)

func _stamp_one(side: String, p: Vector2, radius: float, hold_seconds: float, only_visible: bool, current: Dictionary, live_mask: Image = null) -> void:
	if not visible_cells.has(side):
		return
	if live_mask != null:
		SightBatch.raster_disc(live_mask, width, p, radius)
		return
	var cells: PackedByteArray = visible_cells[side]
	var explored: PackedByteArray = explored_cells[side]
	var held: Dictionary = sight_until[side]
	var leases: HeldSightLeases = _lease_index.get(side)
	var changed_leases: Array = []
	var deadline := sight_clock + hold_seconds
	var lo := Vector2i(floori((p.x - radius) / CELL), floori((p.y - radius) / CELL))
	var hi := Vector2i(floori((p.x + radius) / CELL), floori((p.y + radius) / CELL))
	var r2 := radius * radius
	for y in range(maxi(0, lo.y), mini(width - 1, hi.y) + 1):
		# A disc intersects a contiguous span of cells in each row. Interior
		# cells need no individual nearest-corner distance test.
		var dy := p.y - clampf(p.y,y*CELL,(y+1)*CELL)
		var span2 := r2 - dy*dy
		if span2 < 0:continue
		var half_span := sqrt(span2)
		var left := maxi(maxi(lo.x,0),ceili((p.x-half_span)/CELL)-1)
		var right := mini(mini(hi.x,width-1),floori((p.x+half_span)/CELL))
		if left>right:continue
		var start := y*width+left
		var end := y*width+right+1
		if hold_seconds<=0 and not only_visible and current.is_empty():
			for index in range(start,end):
				cells[index]=1
				explored[index]=1
			continue
		# A moving scout holds only the part of its old footprint it just
		# vacated. Skip the overlapping horizontal span as one run.
		var skip_start := end
		var skip_end := end
		if not current.is_empty():
			var pos: Vector2 = current.point
			var r: float = current.radius
			var offset_y := pos.y - clampf(pos.y, y * CELL,(y + 1) * CELL)
			var overlap2 := r * r - offset_y * offset_y
			if overlap2 >= 0:
				var span := sqrt(overlap2)
				skip_start = clampi(y * width + ceili((pos.x - span) / CELL) - 1, start, end)
				skip_end = clampi(y * width + floori((pos.x + span) / CELL) + 1, start, end)
		var index := start
		while index < end:
			if index == skip_start and skip_end > index:
				index = skip_end
				continue
			if not only_visible or cells[index] != 0:
				if hold_seconds > 0 and deadline > float(held.get(index, 0.0)):
					held[index] = deadline
					if leases != null: changed_leases.append(index)
				if not only_visible:
					cells[index] = 1
					explored[index] = 1
			index += 1
	if leases != null and not changed_leases.is_empty(): leases.record(held, changed_leases, deadline)
	visible_cells[side] = cells
	explored_cells[side] = explored

static func bomb_position(actor) -> Vector2:
	var carrier = actor
	var visited := {}
	while carrier is Unit and is_instance_valid(carrier.embarked_in):
		if visited.has(carrier): return actor.global_position
		visited[carrier] = true
		carrier = carrier.embarked_in
	return carrier.global_position

func _begin_live_masks() -> void:
	var _call_log_scope = preload("res://scripts/world/battle_call_counters.gd").enter(67)
	if _white_cells == null or _white_cells.get_width()!=width:
		_white_cells=Image.create(width,width,false,Image.FORMAT_L8)
		# Visibility bytes are 0 or 1, not 0 or 255.
		_white_cells.fill(Color(1.0/255.0,1.0/255.0,1.0/255.0))
	for side in visible_cells:
		var team = BattleRequest.house_teams.get(side,side)
		if not _live_masks.has(team):
			var mask:=Image.create(width,width,false,Image.FORMAT_LA8)
			preload("res://scripts/world/battle_call_counters.gd").iterations(67,1)
			mask.fill(Color.TRANSPARENT)
			_live_masks[team]=mask

func _apply_live_masks() -> void:
	var _call_log_scope = preload("res://scripts/world/battle_call_counters.gd").enter(43)
	var area:=Rect2i(0,0,width,width)
	for layer:Dictionary in [visible_cells,explored_cells]:
		var converted := {}
		for side in visible_cells:
			var team = BattleRequest.house_teams.get(side,side)
			var input: PackedByteArray = layer[side]
			var variants: Array = converted.get_or_add(team, [])
			var reused := false
			# Allies often have identical inputs. Reuse only a byte-identical layer
			# with the same mask, and keep each observer's mutable result independent.
			for pair: Array in variants:
				if input == pair[0]:
					layer[side] = pair[1].duplicate()
					reused = true
					break
			if reused: continue
			var mask:Image=_live_masks[team]
			var surface:=Image.create_from_data(width,width,false,Image.FORMAT_L8,input)
			surface.blit_rect_mask(_white_cells,mask,area,Vector2i.ZERO)
			var result := surface.get_data()
			variants.append([input,result])
			layer[side]=result
	_live_masks.clear()

func _merge_foundation_masks(footprints:Dictionary) -> void:
	for side in visible_cells:
		var team = BattleRequest.house_teams.get(side,side)
		if not footprints.has(team):continue
		var points:Array=footprints[team]
		footprints.erase(team) # Each alliance contributes its union once.
		var mask:Image=_foundation_masks.get(team)
		if mask==null or mask.get_width()!=width or points!=_foundation_keys.get(team):
			mask=Image.create(width,width,false,Image.FORMAT_LA8)
			mask.fill(Color.TRANSPARENT)
			for v:Vector3 in points:
				_stamp_one(side,Vector2(v.x,v.y),v.z,0.0,false,{},mask)
			_foundation_keys[team]=points
			_foundation_masks[team]=mask
		var live:Image=_live_masks[team]
		live.blit_rect_mask(mask,mask,Rect2i(0,0,width,width),Vector2i.ZERO)

func _hold_vacated_scouts(scouts: Dictionary, remaining: float) -> void:
	var _call_log_scope = preload("res://scripts/world/battle_call_counters.gd").enter(42)
	# Small encounters do not amortize creating alliance masks.
	if _scouts.size() < 64:
		for id in _scouts:
			var old: Dictionary = _scouts[id]
			var current: Dictionary = scouts.get(id,{})
			if old == current: continue
			if current.get("side") != old.side: current = {}
			_stamp_sight(old.side,old.point,old.radius,remaining,false,current)
		return
	# Union each scout's OLD minus its OWN current footprint, not union(old)
	# minus union(current): another scout's death must not erase this hold time.
	var masks := {}
	for id in _scouts:
		var old: Dictionary = _scouts[id]
		var current: Dictionary = scouts.get(id, {})
		if old == current or not visible_cells.has(old.side): continue
		if current.get("side") != old.side: current = {}
		var team = BattleRequest.house_teams.get(old.side, old.side)
		if not masks.has(team):
			var mask := Image.create(width, width, false, Image.FORMAT_L8)
			mask.fill(Color.BLACK)
			masks[team] = mask
		SightBatch.raster_vacated(masks[team], width, old, current)
	var deadline := sight_clock + remaining
	for team in masks:
		var bytes: PackedByteArray = masks[team].get_data()
		var indices := PackedInt32Array()
		# Most pixels are empty: native byte search skips those without a script
		# iteration per map cell. L8 masks contain only 0 and 255.
		var index := bytes.find(255)
		while index >= 0:
			indices.append(index)
			index = bytes.find(255, index + 1)
		for side in visible_cells:
			if BattleRequest.house_teams.get(side, side) != team: continue
			var held: Dictionary = sight_until[side]
			var leases: HeldSightLeases = _lease_index.get(side)
			var changed_leases: Array = []
			var cells: PackedByteArray = visible_cells[side]
			var explored: PackedByteArray = explored_cells[side]
			preload("res://scripts/world/battle_call_counters.gd").iterations(42,indices.size())
			for i in indices:
				if deadline > float(held.get(i, 0.0)):
					held[i] = deadline
					if leases != null: changed_leases.append(i)
				cells[i] = 1
				explored[i] = 1
			if leases != null and not changed_leases.is_empty(): leases.record(held, changed_leases, deadline)
			visible_cells[side] = cells
			explored_cells[side] = explored

func _expire_held_sight() -> void:
	var _call_log_scope = preload("res://scripts/world/battle_call_counters.gd").enter(41)
	var pending := visible_cells.keys()
	while not pending.is_empty():
		var side: String = pending.pop_front()
		var held: Dictionary = sight_until[side]
		var identical := []
		# Compare BEFORE expiry mutates the source. Allied observers frequently
		# hold identical cells/deadlines, but saved or temporary reveals may differ.
		for i in range(pending.size()-1,-1,-1):
			if held == sight_until[pending[i]]:
				identical.append(pending[i])
				pending.remove_at(i)
		if identical.is_empty():
			var leases: HeldSightLeases = _lease_index.get(side)
			if leases == null:
				leases = HeldSightLeases.new()
				_lease_index[side] = leases
			visible_cells[side] = leases.expire(held, width * width, sight_clock)
			continue
		# Equal observers already amortize the original traversal. Avoid creating
		# six expiry indices for one common mask; keep observer dictionaries intact.
		_lease_index.erase(side)
		for member in identical: _lease_index.erase(member)
		var cells: PackedByteArray = visible_cells[side]
		cells.fill(0)
		preload("res://scripts/world/battle_call_counters.gd").iterations(41,held.size())
		var expired: Array = []
		for index in held.keys():
			if sight_clock >= float(held[index]):
				held.erase(index)
				expired.append(index)
			else: cells[int(index)] = 1
		visible_cells[side] = cells
		for member in identical:
			# Keep observer tables independent, including existing references to
			# their dictionaries. A subsequent reveal must not affect its peers.
			var observer: Dictionary = sight_until[member]
			# Mappings were equal before expiry. Only removed keys
			# can differ now; preserve references without copying every survivor.
			if not is_same(observer,held):
				preload("res://scripts/world/battle_call_counters.gd").iterations(71,held.size())
				for index in expired: observer.erase(index)
			visible_cells[member] = cells.duplicate()

func rebuild() -> void:
	var _call_log_scope = preload("res://scripts/world/battle_call_counters.gd").enter(21)
	rebuild_count += 1
	_elapsed = 0.0
	for side in _held_buildings: _held_buildings[side].clear()
	for id in _building_sight_cells.keys():
		if not is_instance_id_valid(id): _building_sight_cells.erase(id)
	_expire_held_sight()
	SupportSystems.apply_intelligence(self)
	if battle.units.size() >= 128: _begin_live_masks()
	var hollywood: Dictionary = battle.allied_state.get("hollywood", {})
	if hollywood.get("briefing", false):
		_reveal("ally", battle.Hollywood.briefing_point(hollywood), battle.Hollywood.BRIEFING_SIGHT)
	var batches := {}
	for team in _live_masks:
		var batch := SightBatch.new()
		batch.mask = _live_masks[team]
		batch.width = width
		batch.tiles = _scout_tiles.get(team,{})
		batches[team] = batch
	var scouts := {}
	var foundations := {}
	for actor in battle.units + battle.buildings:
		if not battle.actor_alive(actor): continue
		if actor is Building and not actor.under_construction and actor.broadcasts_superweapon() and visible_cells.has(actor.side):
			# Derive ongoing intelligence from the live site, including on old saves.
			_broadcast_site_sight(actor)
		if actor.special.has("contact_left"):
			reveal_contact(actor.side,actor.special.get("contact_target"))
		if actor.special.has("ivan_bomb"):
			_reveal(actor.special.ivan_bomb.side, bomb_position(actor), IVAN_BOMB_SIGHT)
		if actor is Unit and actor.embarked_in != null:
			continue
		if actor.special.has("reed_watch"):
			_reveal("ally", actor.global_position, 0.0)
		if actor.special.has("expansion_temporary"):continue
		var radius := vision_radius(actor)
		scouts[actor.get_instance_id()] = {"side":actor.side, "point":actor.global_position, "radius":radius}
		if actor is Building and not _live_masks.is_empty() and visible_cells.has(actor.side):
			var team = BattleRequest.house_teams.get(actor.side,actor.side)
			var positions: Array = foundations.get_or_add(team, [])
			positions.append(Vector3(actor.global_position.x,actor.global_position.y,radius))
		elif not batches.is_empty() and visible_cells.has(actor.side):
			var batch: SightBatch = batches[BattleRequest.house_teams.get(actor.side, actor.side)]
			batch.points.append(actor.global_position)
			batch.radii.append(radius)
		else:
			_reveal(actor.side, actor.global_position, radius)
		if actor is Unit:
			if actor.special.has("spy_photo"): _reveal(actor.side,actor.special.spy_photo,float(actor.data.recon_camera.radius))
			var drone = actor.special.get("parasite")
			if battle.actor_alive(drone) and drone.embarked_in == actor:
				_reveal(drone.side, actor.global_position, vision_radius(drone))
			var squid=actor.special.get("squid")
			if NavalContact.grip_host(squid)==actor:
				_reveal(squid.side,actor.global_position,vision_radius(squid))
	for shot in firing_positions.values():
		_reveal(str(shot.side), shot.position, FIRE_REVEAL_RADIUS)
	if not batches.is_empty():
		_merge_foundation_masks(foundations)
		for batch: SightBatch in batches.values():
			if batch.points.size() >= 24 and OS.get_processor_count() > 2:
				batch.task = WorkerThreadPool.add_task(batch.rasterize, false, "Alliance sight")
			else:
				batch.rasterize()
	# Only a vacated footprint starts a scout timer. A stationary scout that dies
	# or a separate temporary reveal must not refresh it for five more seconds.
	var remaining := SCOUT_SIGHT_SECONDS - (sight_clock - _scout_sample_time)
	if remaining > 0:
		_hold_vacated_scouts(scouts, remaining)
	_scouts = scouts
	_scout_sample_time = sight_clock
	if not batches.is_empty():
		for batch: SightBatch in batches.values():
			if batch.task >= 0: WorkerThreadPool.wait_for_task_completion(batch.task)
		for team in batches: _scout_tiles[team] = batches[team].tiles
		_apply_live_masks()
	_hold_active_superweapons()
	if battle.allied_state.get("commander_orders",{}).get("su",{}).has("burn_left"):
		for side:String in visible_cells:
			if BattleRequest.friendly("ally",side):
				visible_cells[side].fill(1)
				explored_cells[side].fill(1)
	_publish_combat_sight()

func _publish_combat_sight() -> void:
	var _call_log_scope = preload("res://scripts/world/battle_call_counters.gd").enter(45)
	preload("res://scripts/world/battle_call_counters.gd").iterations(45,battle.units.size()+battle.buildings.size())
	for actor in battle.units + battle.buildings:
		if not is_instance_valid(actor):
			continue
		actor.visible = (not (actor is Unit and actor.embarked_in != null)) and battle.actor_visible_to("ally", actor)
		if not actor.visible and actor.get("hovered") == true:
			actor.set_hovered(false)
	_sync_mask()

func _sync_mask() -> void:
	var _call_log_scope = preload("res://scripts/world/battle_call_counters.gd").enter(44)
	var initial := mask_image == null
	var visible_now: PackedByteArray = visible_cells.ally
	var explored_now: PackedByteArray = explored_cells.ally
	if not initial and visible_now == _previous_visible and explored_now == _previous_explored:
		return
	minimap_mask_revision += 1
	if initial:
		mask_image = Image.create(width, width, false, Image.FORMAT_RGBA8)
	# Compare unchanged spans in native packed-array code before visiting individual cells.
	const CHUNK := 512
	var start := 0
	while start < visible_now.size():
		var end := mini(start + CHUNK, visible_now.size())
		if initial or visible_now.slice(start, end) != _previous_visible.slice(start, end) or explored_now.slice(start, end) != _previous_explored.slice(start, end):
			_sync_mask_span(start, end, visible_now, explored_now, initial)
		start = end
	_previous_visible = visible_now.duplicate()
	_previous_explored = explored_now.duplicate()
	_upload_mask()

func _sync_mask_span(start: int, end: int, visible_now: PackedByteArray, explored_now: PackedByteArray, initial: bool) -> void:
	preload("res://scripts/world/battle_call_counters.gd").iterations(44,end-start)
	for i in range(start,end):
		if not initial and visible_now[i] == _previous_visible[i] and explored_now[i] == _previous_explored[i]:
			continue
		var alpha := 1.0
		if visible_now[i] != 0:
			alpha = 0.0
			_fading_cells.erase(i)
		elif explored_now[i] != 0:
			alpha = EXPLORED_OPACITY
			if not initial and _previous_visible[i] != 0:
				_fading_cells[i] = 0.0
				alpha = 0.0
			elif _fading_cells.has(i):
				alpha = mask_image.get_pixel(i % width, i / width).a
		else:
			_fading_cells.erase(i)
		mask_image.set_pixel(i % width, i / width, Color(0, 0, 0, alpha))

## Rebuilds never restart a fade; only regaining real sight resets its timer.
func _advance_visual(delta: float) -> void:
	var _call_log_scope = preload("res://scripts/world/battle_call_counters.gd").enter(46)
	if mask_image == null or _fading_cells.is_empty() or delta <= 0.0:
		return
	preload("res://scripts/world/battle_call_counters.gd").iterations(46,_fading_cells.size())
	var changed := false
	for i in _fading_cells.keys():
		var age: float = float(_fading_cells[i]) + delta
		_fading_cells[i] = age
		var alpha := EXPLORED_OPACITY * clampf(age / FOG_RETURN_FADE, 0.0, 1.0)
		var x := int(i) % width
		var y := int(i) / width
		if absf(mask_image.get_pixel(x, y).a - alpha) > 0.001:
			mask_image.set_pixel(x, y, Color(0, 0, 0, alpha))
			changed = true
		if age >= FOG_RETURN_FADE:
			_fading_cells.erase(i)
	if changed:
		_upload_mask()

func _upload_mask() -> void:
	var _call_log_scope = preload("res://scripts/world/battle_call_counters.gd").enter(22)
	if texture == null:
		texture = ImageTexture.create_from_image(mask_image)
	else:
		texture.update(mask_image)
	queue_redraw()

func _draw() -> void:
	if texture != null:
		draw_texture_rect(texture, Rect2(Vector2.ZERO, Vector2.ONE * width * CELL), false)
