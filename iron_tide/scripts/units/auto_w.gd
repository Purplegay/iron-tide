extends RefCounted
## Only equipped W cards. Native Q/E and player orders remain authoritative.
const TECH := "auto_w"
const PREFS := "user://auto_w_preferences.cfg"
const DEFAULT := "__all__"
const SPLIT = preload("res://scripts/units/ra3_reaper_split.gd")
const TESLA = preload("res://scripts/buildings/tesla_pulse.gd")
const Expansion=preload("res://scripts/units/auto_w_expansion.gd")
const Tactical=preload("res://scripts/units/auto_w_tactical.gd")
const Maneuvers=preload("res://scripts/units/auto_w_maneuvers.gd")
const MANUAL_ONLY={"ap_convoy_crew":"乘员由玩家手动选择。","ap_furnace_bastion":"卧倒／起身由玩家控制，避免无冷却姿态反复切换。"}
const SUPPORTED := ["ap_convoy_press","ap_bilge_repair", "ap_wing_guard", "ap_smoke", "ap_overdrive", "ap_focus_fire", "ap_tesla_chain", "ap_shock_pulse", "ap_twin", "ap_slope", "ap_decoy", "reaper_split_fire"]
const INTERVAL := 0.25
const CELL := 256.0
const HINTS := {
	"ap_bilge_repair":"生命低于 85% 时施放，移动不打断抢修。",
	"ap_wing_guard":"空中最近 3 秒受到攻击时施放。",
	"ap_smoke":"最近 3 秒受伤且生命低于 70% 时施放。",
	"ap_overdrive":"正在移动且距离当前目的地超过 5 格时施放。",
	"ap_focus_fire":"已有可攻击目标、武器对准且即将开火时施放。",
	"ap_tesla_chain":"即将开火，且主目标周围 2 格内还有可见地面敌人时施放。",
	"ap_shock_pulse":"范围内至少 2 名可见地面敌人；生命低于 40% 时，1 名即可。",
	"ap_twin":"主炮模式下，即将开始下一轮双炮攻击时施放。",
	"ap_slope":"停车且最近 3 秒遭到车首左右 60° 内敌人攻击时施放。",
	"ap_decoy":"最近 3 秒受伤且正在执行移动指令时施放，不自动撤退。",
	"reaper_split_fire":"保留主目标；生命至少 80%，或剩余血量至少为副目标的 2 倍时，向侧炮射界内低血量敌人分火。有效的手动副目标优先。",
}

static func preferences() -> Dictionary:
	var cfg := ConfigFile.new()
	var result := {}
	if cfg.load(PREFS) == OK and cfg.has_section("units"):
		for id in cfg.get_section_keys("units"):
			var value = cfg.get_value("units", id)
			if value is bool: result[id] = value
	return result

static func world_of(actor):
	return actor.battle if actor is Building else actor._battle_world()

static func type_id(actor) -> String:
	return actor.building_id if actor is Building else actor.unit_id

static func unlocked(actor) -> bool:
	if not is_instance_valid(actor) or actor.side != "ally" or not BattleRequest.extensions_enabled(): return false
	var world = world_of(actor)
	return world != null and world.production_technology.is_unlocked(TECH, actor.side)

static func card_id(actor) -> String:
	if actor is Building: return TESLA.card_id(actor) if TESLA.available(actor) else ""
	var ability: Ability = actor.ability_at(UnitSkillLayout.index(actor, 1))
	return ability.id if ability != null else ""

static func enabled(actor) -> bool:
	if not unlocked(actor) or not supported(card_id(actor)): return false
	return preference_enabled(actor, world_of(actor))

static func preference_enabled(actor, world) -> bool:
	var state: Dictionary = world.allied_state.get("auto_w_preferences", BattleRequest.combat_context.get("auto_w_preferences", {}))
	return bool(state.get(type_id(actor), state.get(DEFAULT,true)))

static func set_group(world, actors: Array, value: bool) -> bool:
	var types := {}
	for actor in actors:
		if is_instance_valid(actor) and unlocked(actor) and supported(card_id(actor)): types[type_id(actor)] = value
	if types.is_empty(): return false
	var saved := preferences()
	saved.merge(types, true)
	var state: Dictionary = world.allied_state.get("auto_w_preferences", BattleRequest.combat_context.get("auto_w_preferences", {})).duplicate()
	state.merge(types, true)
	return _save(world,saved,state)

static func available(world) -> bool:
	return world!=null and BattleRequest.extensions_enabled() and world.production_technology.is_unlocked(TECH,"ally")

static func set_all(world,value:bool) -> bool:
	if not available(world):return false
	# Replace type overrides as well as the default, including unbuilt/future types.
	var state := {DEFAULT:value}
	return _save(world,state,state.duplicate())

static func _save(world,saved:Dictionary,state:Dictionary) -> bool:
	var cfg := ConfigFile.new()
	for id in saved: cfg.set_value("units", id, saved[id])
	if cfg.save(PREFS + ".tmp") != OK or DirAccess.rename_absolute(PREFS + ".tmp", PREFS) != OK:
		Events.emit_message("Auto W 开关未保存，请重试。")
		return false
	world.allied_state.auto_w_preferences = state
	return true

static func add_global_control(box:Control,hud) -> HBoxContainer:
	var row:=HBoxContainer.new()
	row.name="AutoWGlobalControls"
	row.hide()
	box.add_child(row)
	row.add_child(UiKit.make_label("Auto W",13,UiKit.COL_ACCENT_2))
	var silver := Ra3Skin.plate_from(Color("#bfc5cb"), Color("#e7eaed"), 3, 4, false)
	for value in [true,false]:
		var button:=UiKit.make_button("全开" if value else "全关",13)
		button.name="AutoWAllOn" if value else "AutoWAllOff"
		button.size_flags_horizontal=Control.SIZE_EXPAND_FILL
		button.toggle_mode = true
		for slot in ["pressed", "hover_pressed"]:
			button.add_theme_stylebox_override(slot, silver)
		for slot in ["font_pressed_color", "font_hover_pressed_color"]:
			button.add_theme_color_override(slot, Color("#18212a"))
		button.tooltip_text="统一设置所有己方兵种，包括后续生产单位；之后仍可单独调整。只控制已支持 Auto 的 W，手动 W 与 Q/E 不受影响。"
		button.pressed.connect(func():
			if set_all(hud.battle,value):
				hud._rebuild_ability_bar()
				Events.emit_message("Auto W 已全开" if value else "Auto W 已全关")
			refresh_global_selection(row, hud.battle))
		row.add_child(button)
	return row

static func refresh_global_selection(row: HBoxContainer, world) -> void:
	var state: Dictionary = world.allied_state.get("auto_w_preferences", BattleRequest.combat_context.get("auto_w_preferences", {}))
	var default_on := bool(state.get(DEFAULT, true))
	var mixed := state.values().has(not default_on)
	var on: Button = row.get_node("AutoWAllOn")
	var off: Button = row.get_node("AutoWAllOff")
	on.set_pressed_no_signal(default_on and not mixed)
	off.set_pressed_no_signal(not default_on and not mixed)

static func add_control(box: Control, actor, w_button: Button, hud) -> void:
	if not unlocked(actor):return
	if not supported(card_id(actor)):
		if MANUAL_ONLY.has(card_id(actor)):
			w_button.tooltip_text += "\n" + str(MANUAL_ONLY[card_id(actor)])
		return
	var button := Button.new()
	button.flat = true
	button.set_meta("ra3_skip", true)
	button.toggle_mode = true
	button.set_pressed_no_signal(enabled(actor))
	button.focus_mode = Control.FOCUS_NONE
	for slot in ["normal", "hover", "pressed", "hover_pressed", "focus"]:
		button.add_theme_stylebox_override(slot, StyleBoxEmpty.new())
	button.custom_minimum_size = Vector2(12, 12)
	button.draw.connect(func():
		var center := Vector2(6, 6)
		var tint := Color("8ce3b6") if button.button_pressed else Color("c2c8cf")
		var fill := Color("244d39a8") if button.button_pressed else Color("22282f99")
		button.draw_circle(center, 5.5, fill, true, -1, true)
		button.draw_arc(center, 5.25, 0, TAU, 24, Color(tint, 0.75), 0.8, true)
		button.draw_string(ThemeDB.fallback_font, Vector2(0, 9), "A", HORIZONTAL_ALIGNMENT_CENTER, 12, 8, tint))
	button.size = button.custom_minimum_size
	button.name = "AutoWToggle"
	button.tooltip_text = ("Auto W 已开\n" if enabled(actor) else "Auto W 已关\n") + hint(card_id(actor)) + "\n按兵种记住 Auto W 开关；多选统一切换。仅自动释放当前 W，不改变 Q/E 或移动命令。也可右键 W 图标切换。"
	var toggle := func():
		if not is_instance_valid(actor): return
		var actors: Array = hud.battle.selected_units.duplicate()
		if actors.is_empty(): actors = [actor]
		if set_group(hud.battle, actors, not enabled(actor)):
			refresh_global_selection(hud.auto_w_controls, hud.battle)
			hud._rebuild_ability_bar()
	button.pressed.connect(toggle)
	w_button.gui_input.connect(func(event):
		if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_RIGHT:
			w_button.accept_event()
			toggle.call())
	w_button.add_child(button)
	button.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT, Control.PRESET_MODE_KEEP_SIZE)
	button.offset_left = -12
	button.offset_right = 0
	button.offset_top = 0

static func record_hit(actor, damage: float, source) -> void:
	if damage <= 0 or not unlocked(actor): return
	actor.special.auto_w_hit_left = 3.0
	actor.special.erase("auto_w_attacker")
	var attacker = source.shooter() if is_instance_valid(source) and source is Projectile else source
	if is_instance_valid(attacker) and (attacker is Unit or attacker is Building) and AlliedAbilities.alive(attacker) and not BattleRequest.friendly(attacker.side,actor.side): actor.special.auto_w_attacker = attacker

static func tick(actor, delta: float) -> void:
	var _call_log_scope = preload("res://scripts/world/battle_call_counters.gd").enter(29)
	if actor.special.has("auto_w_hit_left"):
		actor.special.auto_w_hit_left = maxf(0, float(actor.special.auto_w_hit_left) - delta)
	# evaluate() checks the live card, owner, tech and preference on the think tick.
	if actor.side != "ally" or not BattleRequest.extensions_enabled(): return
	var left := float(actor.get_meta("auto_w_think", float(actor.get_instance_id() % 15) / 60.0)) - delta / maxf(1.0, Engine.time_scale)
	actor.set_meta("auto_w_think", left if left > 0 else INTERVAL)
	if left <= 0: evaluate(actor)

static func contacts(actor, center: Vector2, radius: float) -> Array:
	var world = world_of(actor)
	var epoch := Engine.get_physics_frames() / maxi(1, roundi(INTERVAL * Engine.physics_ticks_per_second))
	var cache: Dictionary = world.get_meta("auto_w_contacts", {})
	if cache.get("epoch", -1) != epoch:
		var cells := {}
		for target in world.units + world.buildings:
			if not AlliedAbilities.alive(target): continue
			var cell := Vector2i((target.global_position / CELL).floor())
			if not cells.has(cell): cells[cell] = []
			cells[cell].append(target)
		cache = {"epoch": epoch, "cells": cells}
		world.set_meta("auto_w_contacts", cache)
	var result: Array = []
	# Building foundation edges can be inside the query while their center is outside.
	var margin := Vector2.ONE * (radius + 256.0)
	var low := Vector2i(((center - margin) / CELL).floor())
	var high := Vector2i(((center + margin) / CELL).floor())
	for x in range(low.x, high.x + 1):
		for y in range(low.y, high.y + 1):
			for target in cache.cells.get(Vector2i(x,y), []):
				if not AlliedAbilities.alive(target) or (target.side not in ["ally","enemy"] and not BattleRequest.house_teams.has(target.side)) or BattleRequest.friendly(target.side,actor.side): continue
				if target is Unit and (target.is_air_target() or target.embarked_in != null): continue
				if not world.actor_visible_to(actor.side, target): continue
				var point: Vector2 = target.closest_footprint_point(center) if target is Building else target.global_position
				if center.distance_squared_to(point) <= radius * radius: result.append(target)
	return result

static func firing_soon(unit) -> bool:
	if unit.fire_stance == "none" and not unit.attack_ordered: return false
	var target = unit.attack_target
	if not AlliedAbilities.alive(target) or BattleRequest.friendly(target.side,unit.side): return false
	if not unit._battle_world().actor_visible_to(unit.side, target): return false
	if not unit._weapon_target_valid(target) or not unit._weapon_aligned(target) or not unit.logistics.can_start_volley(): return false
	if unit.unit_id == "R3APOC":
		var mount: Dictionary = unit.special.get("soviet_mounts", {}).get("R3APOC", {})
		return not unit.special.get("soviet_mode", false) and float(mount.get("left", 0)) <= INTERVAL and int(mount.get("used", 0)) == 0
	return unit._cd_timer <= INTERVAL and unit._burst_left == 0

static func evaluate(actor) -> bool:
	var _call_log_scope = preload("res://scripts/world/battle_call_counters.gd").enter(30)
	# Cargo cannot cast W. Keep the think/hit clocks in tick(), but reject this
	# state before resolving equipped cards, technology and preferences.
	if is_instance_valid(actor) and actor is Unit and actor.embarked_in != null:
		preload("res://scripts/world/battle_call_counters.gd").iterations(79,1)
		return false
	if not unlocked(actor) or not AlliedAbilities.alive(actor): return false
	var world = world_of(actor)
	if not preference_enabled(actor, world): return false
	if world.paused or world.ended or world.get_tree().paused or world.cast_slot >= 0 or not world.command_mode.is_empty(): return false
	var index := -1
	var ability: Ability
	var id := ""
	if actor is Building:
		id = card_id(actor)
	else:
		index = UnitSkillLayout.index(actor, 1)
		ability = actor.ability_at(index)
		if ability == null: return false
		id = ability.id
	if not supported(id) or (AlliedAbilities.frozen(actor) and id != "ap_chrono_return"): return false
	if actor is Building:
		if not TESLA.ready(actor): return false
		if id=="ap_focus_fire":
			if actor.data.has("garrison_weapons"):
				for occupant in actor.special.get("occupants",[]):
					if AlliedAbilities.alive(occupant) and occupant._cd_timer<=INTERVAL and AlliedAbilities.alive(occupant.attack_target) and preload("res://scripts/units/civilian_orders.gd").order_block_reason(actor,occupant.attack_target).is_empty():return TESLA.use(actor)
				return false
			return TESLA.use(actor) if actor._cd<=INTERVAL and actor._valid_weapon_target(actor.attack_target) and actor.is_operational() and (actor._turret_turn_speed<=0 or actor._turret_art.aligned(actor.attack_target.global_position-actor.global_position)) else false
		var enemies := contacts(actor, actor.global_position, 275.0)
		return TESLA.use(actor) if enemies.size() >= (1 if actor.hp < actor.max_hp * 0.4 else 2) else false
	if actor.embarked_in != null or actor._stun_timer > 0 or actor.repairing or not actor.power_disabled_reason().is_empty(): return false
	if actor.special.has("hero_wreck") or actor.special.has("walker_jump") or actor.special.has("para_height") or actor.special.get("gm_stationary",false): return false
	if not actor.ability_ready(index) or ability.is_active(): return false
	if id=="ap_convoy_press":return preload("res://scripts/units/convoy_cards.gd").automatic(actor,ability)
	if id in Unit.PoolCards.ACTIVES: return Unit.PoolCards.automatic(actor, ability, index)
	var hurt := float(actor.special.get("auto_w_hit_left", 0)) > 0
	if id in Maneuvers.SUPPORTED:
		var visible_contacts:Array=contacts(actor,actor.position,preload("res://scripts/rules/progression_parameters.gd").number("mechanic/faction","buoy_range")) if id=="ap_buoy" and not actor.special.has("buoy_left") else []
		return Maneuvers.evaluate(actor,index,hurt,visible_contacts)
	if id in Tactical.SUPPORTED:return Tactical.evaluate(actor,index,firing_soon(actor))
	if id in Expansion.SUPPORTED:return Expansion.evaluate(actor,index,hurt,firing_soon(actor),contacts(actor,actor.position,2*Ra2Damage.PX_PER_CELL))
	var trigger := false
	match id:
		"ap_bilge_repair": trigger = actor.hp < actor.max_hp * 0.85
		"ap_wing_guard": trigger = hurt and actor.is_air_target()
		"ap_smoke": trigger = hurt and actor.hp < actor.max_hp * 0.7
		"ap_overdrive": trigger = actor.has_move_order and actor._moving() and actor.global_position.distance_to(actor.move_target) > 5 * Ra2Damage.PX_PER_CELL
		"ap_focus_fire", "ap_twin": trigger = firing_soon(actor)
		"ap_tesla_chain":
			if firing_soon(actor):
				trigger = contacts(actor, actor.attack_target.global_position, 2 * Ra2Damage.PX_PER_CELL).any(func(target): return target != actor.attack_target)
		"ap_shock_pulse":
			if actor.fire_stance == "none" and not actor.attack_ordered: return false
			trigger = contacts(actor, actor.global_position, ability.radius).size() >= (1 if actor.hp < actor.max_hp * 0.4 else 2)
		"ap_slope":
			var attacker = actor.special.get("auto_w_attacker")
			if hurt and not actor._moving() and AlliedAbilities.alive(attacker) and world.actor_visible_to(actor.side, attacker):
				trigger = absf(angle_difference(actor.hull_angle, actor.global_position.angle_to_point(attacker.global_position))) <= PI / 3.0
		"ap_decoy": trigger = hurt and actor.has_move_order and actor._moving() and not actor.special.has("echo_cloaked") and not actor.special.has("decoy_origin")
		"reaper_split_fire":
			if not SPLIT.engaged(actor) or SPLIT.secondary(actor) != null: return false
			var best = null
			var radius := float(SPLIT.Pose.definitions.rounds.grenade.max_range) * 1.5 + float(actor.special.get("hero_range_aura",0))
			for target in contacts(actor, actor.global_position, radius):
				if not SPLIT.valid_enemy(actor,target) or SPLIT.choose_side(actor,target)<0: continue
				if actor.hp < actor.max_hp * 0.8 and actor.hp < target.hp * 2: continue
				if best == null or target.hp < best.hp or (target.hp == best.hp and target.get_instance_id() < best.get_instance_id()): best = target
			return SPLIT.assign(actor, best) if best != null else false
	return actor.use_ability(index) if trigger else false

static func supported(id:String) -> bool:
	return id in Unit.PoolCards.ACTIVES or id in SUPPORTED or id in Expansion.SUPPORTED or id in Tactical.SUPPORTED or id in Maneuvers.SUPPORTED

static func hint(id:String) -> String:
	if id in Unit.PoolCards.ACTIVES: return Unit.PoolCards.ACTIVES[id]
	return str(HINTS.get(id,Expansion.HINTS.get(id,Tactical.HINTS.get(id,Maneuvers.HINTS.get(id,MANUAL_ONLY.get(id,""))))))
