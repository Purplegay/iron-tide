extends CanvasLayer
## Screen-space RA2 cursor. It never handles input or changes an order.

const SOVIET_CURSORS := preload("res://assets/ra2/cursors/soviet_superweapons.png")
const MOUSE_SHEET_PATH := "res://assets/ra2/cursors/mouse.png"
const MOUSE_ATLAS_PATH := "res://assets/ra2/cursors/mouse_atlas.png"
const MOUSE_ATLAS_META_PATH := "res://assets/ra2/cursors/mouse_atlas.json"
const ReaperSplit = preload("res://scripts/units/ra3_reaper_split.gd")
var battle
var sprite: Sprite2D
var state := ""
var frame := 0
var elapsed := 0.0
var metadata: Dictionary = {}
var textures: Dictionary = {}
var _owns_pointer := false
var _native_frames: Dictionary = {}
var _native_sheets: Dictionary = {}
var _installed_frame: AtlasTexture
var _previous_mode := Input.MOUSE_MODE_VISIBLE

func _ready() -> void:
	layer = 100
	process_mode = Node.PROCESS_MODE_ALWAYS
	var sheet := ResourceLoader.load(MOUSE_SHEET_PATH) as Texture2D if ResourceLoader.exists(MOUSE_SHEET_PATH) else null
	if sheet == null or not FileAccess.file_exists("res://assets/ra2/cursors/mouse.json"):
		push_warning("战场光标资源缺失，已使用系统鼠标。")
		set_process(false)
		return
	metadata = JSON.parse_string(FileAccess.get_file_as_string("res://assets/ra2/cursors/mouse.json"))
	sprite = Sprite2D.new()
	sprite.centered = false
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	add_child(sprite)
	sprite.hide()
	# YR MouseCursorType::SpyPlane, MOUSE.SHA 504..511, interval 4 at 15 ticks/s.
	# YR MouseCursorType::AirStrike, MOUSE.SHA frames 480..487.
	metadata.sequences["boris_airstrike"] = {"count":8,"offset":0,"hotspot":[27,21],"fps":3.75}
	metadata.sequences["spy_plane"] = {"count":8,"offset":0,"hotspot":[27,21],"fps":3.75}
	metadata.sequences["para_drop"] = {"count":10,"offset":0,"hotspot":[27,21],"fps":3.75}
	# MOUSE.SHA, YR mouse table entries 0x35 and 0x39. Iron has no timed advance.
	metadata.sequences["nuke"] = {"count":10,"offset":0,"hotspot":[27,21],"fps":3.75}
	metadata.sequences["iron"] = {"count":5,"offset":10,"hotspot":[27,21],"fps":0.0}
	for key in metadata.sequences:
		var sequence: Dictionary = metadata.sequences[key]
		var frames: Array = []
		for index in int(sequence.count):
			var cell := int(sequence.offset) + index
			var texture := AtlasTexture.new()
			texture.atlas = preload("res://assets/ra2/cursors/spy_plane.png") if key == "spy_plane" else sheet
			if key == "boris_airstrike": texture.atlas = preload("res://assets/ra2/cursors/boris_airstrike.png")
			if key in ["nuke","iron"]: texture.atlas = SOVIET_CURSORS
			if key == "para_drop": texture.atlas = preload("res://assets/ra2/cursors/american_paradrop.png")
			texture.region = Rect2((cell % int(metadata.cols)) * int(metadata.cell[0]), (cell / int(metadata.cols)) * int(metadata.cell[1]), metadata.cell[0], metadata.cell[1])
			frames.append(texture)
		textures[key] = frames
	_load_atlas_aliases()

func _load_atlas_aliases() -> void:
	if not ResourceLoader.exists(MOUSE_ATLAS_PATH) or not FileAccess.file_exists(MOUSE_ATLAS_META_PATH):
		return
	var atlas := ResourceLoader.load(MOUSE_ATLAS_PATH) as Texture2D
	var atlas_meta: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(MOUSE_ATLAS_META_PATH))
	var states: Dictionary = atlas_meta.get("states", {})
	for source_name in states:
		var range: Array = states[source_name]
		var key := _atlas_key(source_name)
		if key.is_empty() or textures.has(key):
			continue
		var frames: Array = []
		for cell in range(int(range[0]), int(range[1]) + 1):
			var texture := AtlasTexture.new()
			texture.atlas = atlas
			texture.region = Rect2((cell % int(atlas_meta.cols)) * int(atlas_meta.fw), (cell / int(atlas_meta.cols)) * int(atlas_meta.fh), int(atlas_meta.fw), int(atlas_meta.fh))
			frames.append(texture)
		textures[key] = frames
		metadata.sequences[key] = {"count": frames.size(), "hotspot": [27, 21], "fps": 15.0}
	# These are the semantic names used by the battle resolver. They retain the
	# original atlas art while keeping the older cursor API stable.
	_alias_cursor("blocked", "no_action")
	_alias_cursor("patrol", "guard")
	_alias_cursor("reverse_attack", "attack_move")
	_alias_cursor("reverse_cover", "guard")
	_alias_cursor("reaper_split", "attack_range")
	_alias_cursor("repair", "side_repair")
	_alias_cursor("repair_blocked", "no_repair")
	_alias_cursor("sell_blocked", "no_sell")
	_alias_cursor("enter", "occupy")
	_alias_cursor("enter_blocked", "no_occupy")
	_alias_cursor("deploy", "deploy")
	_alias_cursor("undeploy", "deploy")

func _atlas_key(source_name: String) -> String:
	return source_name.to_snake_case()

func _alias_cursor(alias: String, source: String) -> void:
	if textures.has(alias) or not textures.has(source):
		return
	textures[alias] = textures[source]
	metadata.sequences[alias] = metadata.sequences[source].duplicate(true)

func _process(delta: float) -> void:
	refresh(delta)

func _exit_tree() -> void:
	release_pointer()

func release_pointer() -> void:
	if _owns_pointer:
		if _installed_frame != null:
			Input.set_custom_mouse_cursor(null)
			_installed_frame = null
		else: Input.mouse_mode = _previous_mode
		_owns_pointer = false

func refresh(delta: float) -> void:
	if sprite == null:
		return
	var mouse := get_viewport().get_mouse_position()
	var active: bool = is_instance_valid(battle) and battle.world_input_enabled() \
		and not battle._pointer_over_ui() and get_viewport().get_visible_rect().has_point(mouse)
	if not active:
		sprite.hide()
		if is_instance_valid(battle): battle._set_hover(null)
		state = ""
		elapsed = 0.0
		release_pointer()
		return
	var next := sample_pointer(battle.get_global_mouse_position())
	if next != state:
		state = next
		elapsed = 0.0
	else:
		elapsed += delta
	var sequence: Dictionary = metadata.sequences[state]
	frame = int(elapsed * float(sequence.get("fps",metadata.fps))) % int(sequence.count)
	sprite.texture = textures[state][frame]
	sprite.position = mouse - Vector2(sequence.hotspot[0], sequence.hotspot[1])
	if get_viewport() is Window and DisplayServer.get_name() == "Windows":
		sprite.hide()
		var texture: AtlasTexture = textures[state][frame]
		if _installed_frame != texture:
			Input.set_custom_mouse_cursor(_native_frame(texture), Input.CURSOR_ARROW, Vector2(sequence.hotspot[0],sequence.hotspot[1]))
			_installed_frame = texture
			_owns_pointer = true
	else:
		sprite.show()
		if get_viewport() is Window and DisplayServer.get_name() != "headless" and not _owns_pointer:
			_previous_mode = Input.mouse_mode
			Input.mouse_mode = Input.MOUSE_MODE_HIDDEN
			_owns_pointer = true

func _native_frame(texture: AtlasTexture) -> Image:
	if not _native_frames.has(texture):
		if not _native_sheets.has(texture.atlas):
			_native_sheets[texture.atlas] = texture.atlas.get_image()
		_native_frames[texture] = _native_sheets[texture.atlas].get_region(Rect2i(texture.region))
	return _native_frames[texture]

func engineer_cursor(engineer, target) -> String:
	if preload("res://scripts/units/civilian_orders.gd").can_repair(engineer,target): return "repair"
	if target.side == engineer.side or (target.side == "neutral" and preload("res://scripts/units/civilian_orders.gd").civilian_garrison(target)): return "repair"
	return "enter"

func sample_pointer(world: Vector2) -> String:
	# Edge scrolling moves the entire world beneath a stationary cursor.
	# Actual clicks still perform their own pixel hit-test at dispatch.
	if battle.edge_panning and not battle.dragging and battle.command_mode.is_empty() and battle.armed_build.is_empty() and battle.cast_slot < 0 and not Input.is_key_pressed(KEY_CTRL):
		battle._set_hover(null)
		return "pan"
	if battle.dragging or battle._rmb_panning:
		battle._set_hover(null)
		return resolve(world)
	var hit = battle._pick_at(world, false)
	battle._set_hover(hit)
	# The closest unrestricted hit is also the closest friendly hit when it
	# is selectable and player-owned. Reuse only within this pointer sample.
	var friendly = hit if hit != null and hit.side == "ally" and (not hit is Unit or hit.unit_id != "PDPLANE") else null
	return resolve(world, hit == null, friendly, hit)

func resolve(world: Vector2, empty_pixels := false, friendly_hint = null, sampled_actor = null) -> String:
	if battle._rmb_panning or battle.dragging:
		return "pan" if battle._rmb_panning else "arrow"
	if battle.has_meta("keepsake_area_cursor"): return "iron"
	if battle.command_mode == "mcv_site": return "deploy" if battle.mcv_site(world).ok else "blocked"
	if not battle.armed_build.is_empty():
		return "move" if battle.build_spot_ok(world, GameData.get_building(battle.armed_build), true).ok else "blocked"
	if battle.command_mode == "superweapon" and is_instance_valid(battle._armed_superweapon):
		var source = battle._armed_superweapon
		match source.sw_type():
			"SpyPlane": return "spy_plane"
			"AmerParaDrop","ParaDrop": return "para_drop" if source.sw_ready() and preload("res://scripts/world/american_paradrop.gd").valid_zone(battle,world) else "blocked"
			"LightningStorm": return "power" if source.sw_ready() else "blocked"
			"Chronosphere", "ChronoSphere": return "chrono" if source.sw_ready() else "blocked"
			"IronCurtain", "MultiMissile":
				if not source.sw_ready() or not preload("res://scripts/units/soviet_specials.gd").can_aim_at(source,world): return "blocked"
				return "iron" if source.sw_type()=="IronCurtain" else "nuke"
	if battle.cast_slot >= 0:
		var caster = battle.selected_skill_unit()
		if is_instance_valid(caster):
			var skill = caster.ability_at(battle.cast_slot)
			if skill != null and skill.id=="ap_leizhu_court":
				var court=preload("res://scripts/units/leizhu_cards.gd")
				if not caster.ability_ready(battle.cast_slot) or not court.selectable(caster,world):return "blocked"
				return "attack" if court.placement(caster,world) else "move"
			if skill != null and skill.id == "allied_engineer":
				var site = battle.support_order_target(world)
				if not AlliedAbilities.can_order(caster, site, skill.id): return "enter_blocked"
				return engineer_cursor(caster, site)
	if battle.cast_slot >= 0 or battle.command_mode == "superweapon":
		return "attack"
	if battle.command_mode == Unit.ReverseAttack.ID:
		return "reverse_attack" if battle.selected_units.size() == 1 else "blocked"
	if battle.command_mode == Unit.YRTalents.REVERSE:
		return "reverse_cover" if battle.selected_units.size() == 1 else "blocked"
	if battle.command_mode == ReaperSplit.ID:
		return "reaper_split" if battle.selected_units.size() == 1 else "blocked"
	if battle.command_mode in ["repair", "sell"]:
		var action: String = battle.command_mode
		var building = battle._pick_building_at(world, "")
		return action if battle.building_action_reason(action, building).is_empty() else action + "_blocked"
	if battle.command_mode.is_empty() and Input.is_key_pressed(KEY_CTRL) and not ForceFire.selection(battle).is_empty():
		return "attack" if ForceFire.available(battle, ForceFire.pick(battle, world, sampled_actor, empty_pixels or sampled_actor != null)) else "blocked"
	if battle.command_mode == "attack_move":
		return "attack_move"
	if battle.command_mode == "patrol":
		return "patrol"
	if battle.command_mode == "move":
		return "move"
	var target = null if empty_pixels else battle._pick_enemy_at(world)
	if target != null and not battle.actor_alive(target):
		target = null
	if battle.has_selected_attack_building() and target!=null and battle.command_mode in ["","attack"]:
		return attack_cursor(target)
	if battle.command_mode == "attack":
		return attack_cursor(target) if target != null else ("attack" if ForceFire.available(battle, ForceFire.pick(battle, world, sampled_actor, empty_pixels or sampled_actor != null)) else "blocked")
	if battle.command_mode.is_empty() and battle.peregrine_air_order(target): return attack_cursor(target)
	var friendly = friendly_hint if friendly_hint != null else (null if empty_pixels else battle._pick_at(world))
	if is_instance_valid(battle.selected_building) and not Input.is_key_pressed(KEY_SHIFT) and not Input.is_key_pressed(KEY_CTRL):
		if battle.can_click_evacuate(friendly):
			return "undeploy"
	var deploy_target = battle.pointer_deploy_candidate()
	if deploy_target != null and deploy_target == friendly and not Input.is_key_pressed(KEY_SHIFT):
		if not deploy_target.deploy_building_id().is_empty(): return "deploy" if battle.construction_deploy_check(deploy_target).ok else "blocked"
		if deploy_target.unit_id == "SCHP" and not deploy_target.logistics.SiegeChopper.can_begin(deploy_target, not deploy_target.is_deployed()): return "blocked"
		if deploy_target.is_deployed():
			return "undeploy"
		return "deploy_infantry" if deploy_target.unit_id == "E1" else "deploy"
	var friendly_building = null if empty_pixels else battle._pick_building_at(world, "ally")
	if not Input.is_key_pressed(KEY_CTRL) and not battle.refinery_return_miners(friendly_building).is_empty():
		return "enter" if friendly_building.is_operational() else "enter_blocked"
	if battle.command_mode == "harvest":
		return "harvest"
	if not Input.is_key_pressed(KEY_CTRL):
		var landing: Dictionary = battle.airfield_order_status(friendly_building)
		if not landing.is_empty(): return "enter" if not landing.available.is_empty() else "enter_blocked"
	var special_target = battle.support_target_from_pick(world, friendly, true, empty_pixels)
	if special_target != null:
		for unit in battle.selected_units:
			var action := AlliedAbilities.default_order(unit, special_target)
			if action == "ivan_bridge": return "attack"
			if action == "allied_engineer": return engineer_cursor(unit, special_target)
			if not action.is_empty(): return "repair" if action in ["allied_repair", "allied_bridge", "tesla_charge"] else "enter"
	if not Input.is_key_pressed(KEY_CTRL):
		var boarding: Dictionary = battle.boarding_order_status(special_target)
		if not boarding.is_empty():
			return "enter" if not boarding.passengers.is_empty() else "enter_blocked"
	if battle.hero_miner_attack_order(target):
		return attack_cursor(target)
	if battle._cursor_on_ore(world):
		return "harvest"
	var depot = battle.repair_facility_from_pick(world, friendly_building)
	if depot != null and depot.is_repair_depot() and not battle.selected_units.is_empty():
		for unit in battle.selected_units:
			if battle.actor_alive(unit) and unit.can_repair_at(depot): return "repair"
		return "repair_blocked"
	if target != null and not battle.selected_units.is_empty():
		return attack_cursor(target)
	var selectable = friendly if friendly != null else battle.inspected_target_on(target)
	if is_instance_valid(selectable) and selectable.hp > 0.0 and not selectable.is_queued_for_deletion():
		return "select"
	if not battle.selected_units.is_empty() and battle.right_click_move:
		return "move"
	return "arrow"

func attack_cursor(target) -> String:
	if not can_attack(target): return "blocked"
	for unit in battle.selected_units:
		if not battle.actor_alive(unit) or unit.embarked_in != null or not unit.attack_domain_valid(target): continue
		if CommandoCombat.building_c4(unit, target): return "c4"
		if CommandoCombat.sabotage(unit, target): return "sabotage"
		if Unit.SovietSpecials.boris_airstrike_target(unit, target): return "boris_airstrike"
	return "attack"

func can_attack(target) -> bool:
	if battle.has_selected_attack_building():
		return battle.selected_building.attack_order_reason(target).is_empty()
	for unit in battle.selected_units:
		if AlliedAbilities.can_order(unit, target, "allied_disguise"): return true
		if not is_instance_valid(unit) or unit.hp <= 0.0 or unit.is_queued_for_deletion() or unit.embarked_in != null:
			continue
		if unit.is_ordinary_harvester() or unit.weapon.is_empty():
			continue
		if unit.attack_domain_valid(target):
			return true
	return false
