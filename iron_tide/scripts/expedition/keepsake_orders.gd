extends Node2D

const Gifts=preload("res://scripts/expedition/commander_keepsakes.gd")
const Ground=preload("res://scripts/world/american_paradrop.gd")
const Sidebar=preload("res://scripts/ui/superweapon_sidebar.gd")
const COLOR:=Color("#73e8ff")
var world
var id:String
var area:Dictionary
var state:Dictionary
var aiming:=false
var button:Button
var charge_mask: Sidebar.ChargeMask
var instruction:Label
const RULER_TARGET := "左键点地面空降；按住拖动调整车头，松开投放。右键取消。"
var aim_anchor := Vector2.INF
var aim_press_screen := Vector2.ZERO
var aim_cursor_screen := Vector2.ZERO
const DROP_TIME := 0.55
const AREA_HINT := {"volkov":"炮击圈内敌军", "seojin":"呼叫四架飞机轰炸圈内敌军", "edith":"追踪圈内敌军，照亮脚下一格，持续 30 秒", "sami":"治疗圈内己方地面部队"}
var rearm_seconds := 600.0
const DRIVE_TIME := 1.5

func setup(battle,owner_id:String,opening_cooldown:int = 0) -> void:
	world=battle
	id=owner_id
	area=Gifts.area_at_rank(id,Gifts.rank(id))
	rearm_seconds=Gifts.use_cooldown(600,id,Expedition.state)
	if id in ["qiao", "mara"]: world.pointer_gestures_cancelled.connect(cancel_directional_drag)
	var orders:Dictionary=world.allied_state.get_or_add("commander_orders",{})
	if world.allied_state.has("commander_order"):
		orders[id]=world.allied_state.commander_order
		world.allied_state.erase("commander_order")
	state=orders.get_or_add(id,{"cooldown":float(opening_cooldown),"cooldown_total":float(opening_cooldown)} if opening_cooldown > 0 else {})
	add_to_group("expedition_keepsake_orders")
	if state.has("exposure_cd"):
		state.cooldown = clampf(float(state.exposure_cd), 0.0, rearm_seconds)
		state.erase("exposure_cd")
	if state.get("used", false) and not state.has("cooldown"):
		state.cooldown = rearm_seconds
		if id == "su" and state.erase("photo_left"):
			for actor in world.units + world.buildings:
				if world.actor_alive(actor): actor.special.erase("keepsake_photo")
	state.erase("used")
	if id == "lin" and state.erase("rally"):
		for unit in world.units:
			if world.actor_alive(unit): unit.special.erase("keepsake_passenger")
	if state.has("breach_left") and not state.has("cooldown"):
		state.cooldown = rearm_seconds - clampf(5.0 - float(state.breach_left), 0.0, 5.0)
	if state.has("burn_left") and is_instance_valid(world.fog): world.fog.rebuild()
	z_index=DepthLayers.ORDER_PREVIEW
	set_process_input(false)
	refresh()

func mount(support_button:Button) -> void:
	button=support_button
	charge_mask=button.get_node("Charge")
	button.icon=Gifts.icon(id)
	button.pressed.connect(press)
	update_rank()

func update_rank() -> void:
	area=Gifts.area_at_rank(id,Gifts.rank(id))
	if state.has("cooldown") and not state.has("cooldown_total"):
		state.cooldown_total = rearm_seconds
	rearm_seconds = Gifts.use_cooldown(600,id,Expedition.state)
	if is_instance_valid(button):
		button.tooltip_text="%s\n%s" % [Gifts.ITEMS[id].name,Gifts.guide_for_run(id,Expedition.state)]
		if id=="ines":button.tooltip_text+="\n瞄准时：实线为伏击范围，虚线为侦照范围。"
	refresh()

func refresh() -> void:
	if is_instance_valid(button):
		button.text="取消瞄准" if aiming else Gifts.ITEMS[id].order
		if state.has("breach_left"):button.text="缺口齐射"
		var remaining := ceili(float(state.get("cooldown", 0)))
		button.disabled = remaining > 0 and not state.has("breach_left")
		update_charge_mask()
		if button.disabled:
			button.text += "\n%d:%02d" % [floori(remaining / 60.0), remaining % 60]
	if not aiming:
		aim_anchor = Vector2.INF
		if is_instance_valid(instruction): instruction.hide()
	set_process_input(aiming)
	if AREA_HINT.has(id) or id == "mara":
		if aiming: world.set_meta("keepsake_area_cursor", id)
		elif world.get_meta("keepsake_area_cursor", "") == id: world.remove_meta("keepsake_area_cursor")
	set_process(aiming and (AREA_HINT.has(id) or id in ["ines", "vera", "qiao", "lin", "mara"]))
	queue_redraw()

func _process(_delta:float) -> void:
	queue_redraw()

func ready_to_act() -> bool:
	return (float(state.get("cooldown", 0)) <= 0 or state.has("breach_left")) and not world.ended and not world.paused and not get_tree().paused

func press() -> void:
	if not ready_to_act():return
	for other in get_tree().get_nodes_in_group("expedition_keepsake_orders"):
		if other!=self and other.world==world and other.aiming:
			other.aiming=false
			other.refresh()
	if id == "yusuf":
		var rates := Gifts.freight_rates(Gifts.rank(id))
		var fee: int = rates.base
		for unit in world.units:
			if available(unit) and unit.is_harvester:
				fee += int(rates.bonus)
		var joint := pair_present()
		if joint:
			fee *= 2
			start_cooldown(Gifts.use_cooldown(240,id,Expedition.state))
		world.credit_side("ally", fee)
		var center := get_canvas_transform().affine_inverse() * get_viewport_rect().get_center()
		show_freight_receipt(center, fee)
		Ra2Sfx.play("Bonus")
		finish(joint)
		return
	if id == "greta":
		var joint := pair_present()
		for unit in world.units:
			if not world.actor_alive(unit) or unit.side != "ally" or unit.is_air or unit.is_harvester: continue
			if not is_armed_vehicle(unit): continue
			unit._cd_timer = 0.0 if joint else maxf(unit._cd_timer * 0.5, 0.0)
			unit.add_buff("west_shift", 10.0, 0.5, "西站换班")
		finish(joint)
		return
	if id == "nadya":
		var affected := clock_targets()
		if affected.is_empty():
			hint("战场上没有可干扰的敌方地面部队。")
			return
		for unit in affected:
			unit._cd_timer = maxf(unit._cd_timer, 5.0)
			unit._cancel_burst()
		if pair_present(): queue_event("global_clock", Vector2.ZERO, 5.0, 380)
		finish(false)
		return
	if id=="su":
		start_cooldown(rearm_seconds)
		state.burn_left=4.0
		state.burn_joint=pair_present()
		if is_instance_valid(world.fog):world.fog.rebuild()
		refresh()
		return
	if aiming:aiming=false;refresh();return
	if state.has("breach_left"):salvo()
	else:
		aiming=true
		if AREA_HINT.has(id): show_instruction("左键点地面，%s。右键取消。" % AREA_HINT[id])
		elif id == "mara": show_instruction("按住左键锁定中间的轰炸圈，拖动调整航向，松开呼叫飞机。右键取消。")
		elif id == "qiao": show_instruction(RULER_TARGET)
		elif id == "lin": show_instruction("左键确认救援，亮圈中的部队获得护盾，5 秒后在脚下引爆护盾，随即撤回基地。右键取消。")
		elif id == "vera": show_instruction("左键点地面，召下闪电攻击圈内敌军。右键取消。")
		else: hint("点战场指定目标，再点指令可取消。")
	refresh()

func _input(event:InputEvent) -> void:
	if not aiming or not ready_to_act() or not world.world_input_enabled():return
	if event is InputEventKey and event.pressed and event.keycode==KEY_ESCAPE:
		aiming=false;refresh();get_viewport().set_input_as_handled();return
	if id in ["qiao", "mara"] and directional_input(event):
		get_viewport().set_input_as_handled()
		return
	if event is InputEventMouseButton and event.pressed and not world._pointer_over_ui():
		if event.button_index==MOUSE_BUTTON_RIGHT:aiming=false
		elif event.button_index==MOUSE_BUTTON_LEFT:
			var point:Vector2=world.get_canvas_transform().affine_inverse() * event.position
			aiming=not fire_at(point)
		else:return
		get_viewport().set_input_as_handled()
		refresh()

func cancel_directional_drag() -> void:
	if aim_anchor.is_finite():
		aiming = false
		refresh()

func directional_input(event: InputEvent) -> bool:
	if event is InputEventMouseMotion and aim_anchor.is_finite():
		if not (event.button_mask & MOUSE_BUTTON_MASK_LEFT):
			cancel_directional_drag()
		else:
			aim_cursor_screen = event.position
			queue_redraw()
		return true
	if not event is InputEventMouseButton:return false
	if event.button_index == MOUSE_BUTTON_RIGHT and event.pressed and aim_anchor.is_finite():
		cancel_directional_drag()
		return true
	if event.button_index != MOUSE_BUTTON_LEFT:return false
	if event.pressed:
		if world._pointer_over_ui():return false
		var point: Vector2 = world.get_canvas_transform().affine_inverse() * event.position
		if Rect2(Vector2.ZERO, Vector2.ONE * world.map_size).has_point(point):
			aim_anchor = point
			aim_press_screen = event.position
			aim_cursor_screen = event.position
		return true
	if not aim_anchor.is_finite():return false
	aim_cursor_screen = event.position
	aiming = not fire_at(aim_anchor)
	aim_anchor = Vector2.INF
	refresh()
	return true

func show_instruction(message:String) -> void:
	if not is_instance_valid(instruction):
		instruction = Label.new()
		world.hud.add_child(instruction)
		instruction.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		instruction.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		instruction.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		instruction.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		instruction.mouse_filter = Control.MOUSE_FILTER_IGNORE
		instruction.add_theme_color_override("font_color", Color.WHITE)
		instruction.add_theme_color_override("font_outline_color", Color.BLACK)
		instruction.add_theme_constant_override("outline_size", 5)
		instruction.add_theme_font_size_override("font_size", 21)
	instruction.text = message
	instruction.show()

func hint(message:String) -> void:
	Events.emit_message(message,COLOR)

func available(unit) -> bool:
	return unit is Unit and world.actor_alive(unit) and unit.side=="ally" and unit.embarked_in==null and not unit.special.has("expansion_temporary") and not unit.special.has("expedition_mission_unit")

func ground_troop(unit) -> bool:
	return available(unit) and not unit.is_air and not unit.is_harvester and unit.deploy_building_id()=="" and preload("res://scripts/expedition/catalog.gd").group(unit.unit_id) in ["infantry","vehicle"]

func aid_targets(point: Vector2) -> Array[Unit]:
	var patients: Array[Unit] = []
	var radius_squared: float = area.radius * area.radius
	for unit in world.units:
		if not is_instance_valid(unit) or unit.hp >= unit.max_hp or point.distance_squared_to(unit.position) > radius_squared: continue
		if ground_troop(unit) and unit.can_receive_healing(): patients.append(unit)
	return patients

func find_type(kind:String,units:Array):
	for unit in units:
		if available(unit) and unit.unit_id==kind:return unit
	return null

func is_armed_vehicle(unit) -> bool:
	return preload("res://scripts/expedition/catalog.gd").group(unit.unit_id) == "vehicle" and float(unit.weapon.get("damage", 0)) > 0

func first_tank():
	for unit in world.selected_units:
		if ground_troop(unit) and is_armed_vehicle(unit):return unit
	return null

func pair_present() -> bool:
	for kind:String in Gifts.ITEMS[id].partners:
		if find_type(kind,world.units)==null:return false
	return true

func hostile(actor) -> bool:
	return world.actor_alive(actor) and BattleRequest.is_house(actor.side) and not BattleRequest.friendly("ally",actor.side) and (not actor is Unit or (actor.embarked_in==null and not actor.is_air)) and world.actor_visible_to("ally",actor)

func clock_targets() -> Array:
	var result := []
	for unit in world.units:
		if world.actor_alive(unit) and BattleRequest.is_house(unit.side) and not BattleRequest.friendly("ally", unit.side) and not unit.is_air and unit.embarked_in == null:
			result.append(unit)
	return result

func targets(point:Vector2,radius:float) -> Array:
	var hits:Array=[]
	for actor in world.units+world.buildings:
		if hostile(actor) and point.distance_to(actor.position)<=radius+actor.radius:hits.append(actor)
	return hits

func reveal_impact(point:Vector2, radius:float) -> void:
	if is_instance_valid(world.fog):
		world.fog._reveal("ally", point, radius, world.fog.BLAST_SIGHT_SECONDS)

func reveal_sweep(a:Vector2, b:Vector2, radius:float) -> void:
	if not is_instance_valid(world.fog): return
	var length := a.distance_to(b)
	var steps := maxi(1, ceili(length / radius))
	for i in steps:
		reveal_impact(a.lerp(b, (i + 0.5) / steps), radius + length / (2.0 * steps))

func hurt(actor,amount:float,type:String="shell",source=null) -> void:
	if world.actor_alive(actor):actor.receive_hit(amount,type,{},source)

func line(a:Vector2,b:Vector2,power:float,style:String,structure_factor:=1.0,source=null) -> Array:
	reveal_sweep(a, b, 24.0)
	Effects.spawn_beam(a,b,COLOR,style,4,0.55)
	var hits:Array=[]
	if a.is_equal_approx(b):return hits
	for actor in world.units+world.buildings:
		if not hostile(actor):continue
		var nearest:=Geometry2D.get_closest_point_to_segment(actor.position,a,b)
		if nearest.distance_to(actor.position)>float(actor.radius)+24:continue
		hits.append(actor.get_instance_id())
		hurt(actor,power*(structure_factor if actor is Building else 1.0),"electric" if style=="tesla" else "shell",source)
	return hits

func start_cooldown(seconds: float) -> void:
	state.cooldown = seconds
	state.cooldown_total = seconds

func finish(joint:bool) -> void:
	if not state.has("cooldown"):start_cooldown(rearm_seconds)
	if joint:state.record_pending=true
	save_record()
	refresh()

func save_record() -> void:
	if not state.get("record_pending",false):return
	if Gifts.inscribe(id,Expedition.state,true):
		world.hud.show_field_transmission(Gifts.ITEMS[id].name,Gifts.ITEMS[id].after,id)
	if MetaProgress.contact_transcripts.get(id,{}).has("joint_record"):state.erase("record_pending")

func fire_at(point:Vector2,_target=null) -> bool:
	if state.has("breach_left") or not ready_to_act() or not Rect2(Vector2.ZERO,Vector2.ONE*world.map_size).has_point(point):return false
	var joint:=pair_present()
	match id:
		"lin":
			var riders := rescue_targets(point)
			if riders.is_empty():
				show_instruction("请把救援圈移到己方步兵或作战车辆上。右键取消。")
				return false
			for unit in riders:
				unit.special.rescue_shield = true
				unit.queue_redraw()
			state.rescue_left = 5.0
			state.rescue_blast_radius = area.blast
			joint = false
		"vera":
			var sky_offset:Vector2 = world.get_canvas_transform().affine_inverse().basis_xform(Vector2.UP * 360.0)
			Effects.spawn_beam(point + sky_offset, point, COLOR, "tesla", 5, 0.55)
			Effects.spawn_impact(point, COLOR, area.radius)
			reveal_impact(point, area.radius)
			var victims := targets(point, area.radius)
			for actor in victims:
				hurt(actor, 450, "electric")
			joint = joint and not victims.is_empty()
		"volkov":
			reveal_impact(point, area.radius)
			var victims := targets(point, area.radius)
			Effects.spawn_impact(point,Color.ORANGE,area.radius)
			for actor in victims: hurt(actor, 480 if joint else 320)
			joint = joint and not victims.is_empty()
		"qiao":
			for actor in world.units + world.buildings:
				if world.actor_alive(actor): actor.special.erase("qiao_track_hit")
			var route := ruler_route(point)
			var event := queue_event("ruler", point, DROP_TIME + DRIVE_TIME, 280.0)
			event.end = route.end
			event.heading = route.heading
			event.width = route.width
			event.joint = joint
			if int(Expedition.state.get("cycle", 1)) >= 3:
				world.hud.show_field_transmission("乔远", "还记得上回那条窄路吗？这次我多量了一道履带。后面的车，跟上。", id)
			joint = false
		"mara":
			var heading := aim_heading(point)
			for leg in (2 if joint else 1):
				var flight := queue_event("beacon_flight", point, BEACON_DURATION + leg * 1.6, 240)
				flight.radius = area.radius
				flight.heading = heading if leg == 0 else -heading
				flight.return_strike = leg == 1
			joint = false
		"seojin":
			for i in 4:
				var bomb := queue_event("lark",point,2.4 + i * 0.28,180 if joint else 120)
				bomb.radius = area.radius
				bomb.lane = i
				bomb.joint = joint
			joint = false
		"edith":
			var marked := false
			for actor in world.units + world.buildings:
				if not world.actor_alive(actor) or not BattleRequest.is_house(actor.side) or BattleRequest.friendly("ally",actor.side): continue
				if actor is Unit and actor.embarked_in != null: continue
				if point.distance_squared_to(actor.position) > area.radius * area.radius: continue
				actor.special.reed_watch = true
				marked = true
			if not marked:
				show_instruction("请把侦察圈移到敌军所在的位置。右键取消。")
				return false
			state.watch_left = 30.0
			if joint and is_instance_valid(world.fog): world.fog._reveal("ally",point,area.reveal,10.0)
			queue_redraw()
		"sami":
			var patients := aid_targets(point)
			for unit in patients:
				unit.heal(unit.max_hp * (0.40 if joint else 0.20))
			joint = joint and not patients.is_empty()
			Ra2Sfx.play("HealCrate")
		"ines":
			if is_instance_valid(world.fog):world.fog._reveal("ally",point,area.reveal,6)
			var actors:=targets(point,area.radius)
			for actor in actors:
				actor.special.keepsake_photo=actor.hp
				Effects.spawn_impact(actor.position,COLOR,25)
			state.photo_left=1.0
			state.photo_joint=joint
			state.photo_chain_radius=area.chain
			start_cooldown(rearm_seconds)
			refresh();return true
		_:return false
	finish(joint)
	return true

func salvo() -> void:
	var at:Vector2=state.breach_point
	for actor in world.units:
		if hostile(actor) and actor.special.has("keepsake_breach"):at=actor.position;break
	var count:=0
	for unit in world.units:
		if not available(unit) or unit.unit_id!="APOC" or unit.position.distance_to(at)>unit.attack_range+50:continue
		var axis:Vector2=unit.position.direction_to(at)
		for i in 2:
			var offset:=axis.orthogonal()*(5 if i==0 else -5)
			line(unit.position+offset,at+axis*320+offset,float(unit._active_weapon().get("damage",100)),"laser",1.0,unit)
		count+=1
		if count==3:break
	if count==0:hint("缺口附近需要有天启坦克。");return
	state.erase("breach_left")
	finish(true)

func rescue_targets(point:Vector2) -> Array:
	var candidates:Array = []
	for unit in world.units:
		if ground_troop(unit) and unit.position.distance_squared_to(point) <= area.radius * area.radius:
			candidates.append(unit)
	candidates.sort_custom(func(a,b):
		var a_health:float = float(a.hp) / a.max_hp
		var b_health:float = float(b.hp) / b.max_hp
		if a_health != b_health: return a_health < b_health
		return a.position.distance_squared_to(point) < b.position.distance_squared_to(point))
	return candidates.slice(0,4)

func rescue_landing(unit) -> Vector2:
	var base:Vector2 = world.player_start()
	for ring in 5:
		for sector in maxi(1,ring * 6):
			var offset := Vector2.RIGHT.rotated(TAU * sector / maxi(1,ring * 6)) * ring * 128.0
			var spot := Ground.open_ground(world,base + offset,unit)
			if spot.is_finite(): return spot
	return Vector2.INF

func recall() -> void:
	var blast_radius := float(state.get("rescue_blast_radius", Gifts.ITEMS.lin.area.blast))
	state.erase("rescue_blast_radius")
	var moved:=0
	var chrono:bool=find_type("CLEG",world.units)!=null
	for unit in world.units:
		if not world.actor_alive(unit) or not unit.special.erase("rescue_shield"): continue
		unit.queue_redraw()
		if not ground_troop(unit): continue
		var spot := rescue_landing(unit)
		if not spot.is_finite():continue
		var origin:Vector2=unit.position
		reveal_impact(origin, blast_radius)
		Effects.spawn_impact(origin, COLOR, blast_radius)
		for enemy in targets(origin, blast_radius):
			hurt(enemy, 240)
		var weapon:Dictionary=unit._active_weapon()
		if chrono and float(weapon.get("damage",0))>0:
			for i in 2:
				var event:=queue_event("echo",origin,0.4+0.7*i,float(weapon.damage))
				event.burst=maxi(1,int(weapon.get("burst",1)));event.reach=unit.attack_range
				event.type=weapon.get("attack_type","shell");event.warhead=weapon.get("ra2_warhead","")
				event.bonuses=unit.bonuses.duplicate(true)
				event.art=unit.unit_id;event.angle=unit.hull_angle
		unit.order_stop();unit.velocity=Vector2.ZERO;unit.position=spot
		unit.reset_physics_interpolation()
		Effects.spawn_beam(origin,spot,COLOR,"laser",2,.35)
		moved+=1
	if moved == 0: hint("撤离结束，基地附近没有成功接回部队。")

const BEACON_SPACING := 155.0
const BEACON_INTERVAL := 0.38
const BEACON_DURATION := 2.8
const FIRST_IMPACT := 1.25

func aim_heading(point: Vector2) -> Vector2:
	var axis: Vector2 = world.player_start().direction_to(point)
	if aim_anchor.is_finite() and aim_cursor_screen.distance_to(aim_press_screen) >= Battle.SELECTION_CLICK_SLOP:
		var cursor: Vector2 = world.get_canvas_transform().affine_inverse() * aim_cursor_screen
		axis = aim_anchor.direction_to(cursor)
	return Vector2.RIGHT if axis == Vector2.ZERO else axis

func beacon_drop(center: Vector2, heading: Vector2, index: int) -> Vector2:
	return center + heading * (index - 1) * BEACON_SPACING

func draw_beacon_flight(event: Dictionary) -> void:
	var elapsed := BEACON_DURATION - float(event.left)
	if elapsed < 0: return
	var axis: Vector2 = event.heading
	var first := beacon_drop(event.at, axis, 0)
	var speed := BEACON_SPACING / BEACON_INTERVAL
	var ground := first + axis * (elapsed - FIRST_IMPACT + 0.28) * speed
	var lift := Vector2(0, -72)
	draw_circle(ground, 16, Color(0, 0, 0, 0.32))
	var art := RA2Art.art("BEAG" if event.return_strike else "ORCA")
	if not art.is_empty():
		var size := RA2Art.frame_size(art)
		var frame := RA2Art.facing_index(axis.angle(), int(art.get("facings",8))) + int(art.get("facing_offset",0))
		RA2Art.draw_sprite(self, art, Rect2(ground + lift - size * 0.5, size), RA2Art.src_rect(art, frame), Color.WHITE)
	for index in 3:
		var until_hit := FIRST_IMPACT + index * BEACON_INTERVAL - elapsed
		if until_hit > 0 and until_hit <= 0.28:
			var bomb := beacon_drop(event.at, axis, index) + lift * until_hit / 0.28
			draw_line(bomb + Vector2.UP * 12, bomb, Color.ORANGE, 4, true)
			draw_circle(bomb, 5, Color.GOLD)

func queue_event(kind:String,at:Vector2,delay:float,power:float) -> Dictionary:
	var event:={"kind":kind,"at":at,"left":delay,"power":power}
	state.get_or_add("events",[]).append(event)
	queue_redraw()
	return event

func update_charge_mask() -> void:
	if is_instance_valid(charge_mask):
		var left := 0.0 if state.has("breach_left") else float(state.get("cooldown",0))
		charge_mask.set_remaining(left / maxf(1.0, float(state.get("cooldown_total",rearm_seconds))))

func show_freight_receipt(anchor: Vector2, fee: int) -> void:
	var holder := Node2D.new()
	holder.transform = Transform2D(Iso.eff_angle(), Iso.up(), 0.0, anchor)
	add_child(holder)
	var label := Label.new()
	label.text = "+%d" % fee
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.add_theme_font_size_override("font_size", 24)
	label.add_theme_color_override("font_color", Color.GOLD)
	label.add_theme_constant_override("outline_size", 5)
	holder.add_child(label)
	label.position = Vector2(-label.get_minimum_size().x * 0.5, -48)
	var tween := holder.create_tween()
	tween.tween_property(label, "position:y", -94.0, 1.5)
	tween.parallel().tween_property(label, "modulate:a", 0.0, 0.5).set_delay(1.0)
	tween.tween_callback(holder.queue_free)

func advance_cooldown(seconds:float) -> void:
	var previous := float(state.cooldown)
	var remaining := maxf(0.0, previous - seconds)
	if remaining > 0: state.cooldown = remaining
	else:
		state.erase("cooldown")
		state.erase("cooldown_total")
		state.erase("freight_received")
		if previous > 0.0 and not state.has("breach_left"):
			Ra2Sfx.play_support_ready(world)
	if ceili(previous) != ceili(remaining): refresh()
	else: update_charge_mask()

func advance_exposure(seconds:float) -> void:
	var before:=float(state.burn_left)
	var left:=maxf(0.0,before-seconds)
	state.burn_left=left
	for pulse in range(ceili(before)-ceili(left)):
		for actor in world.units+world.buildings:
			if not world.actor_alive(actor) or not BattleRequest.is_house(actor.side) or BattleRequest.friendly("ally",actor.side):continue
			if actor is Unit and actor.embarked_in!=null:continue
			if world.get_viewport_rect().has_point(world.get_global_transform_with_canvas()*actor.position):
				Effects.spawn_impact(Effects.hit_position(actor),Color.ORANGE_RED,24)
			hurt(actor,60.0 if state.burn_joint else 30.0,"fire")
			if state.burn_joint:state.record_pending=true
	if left==0.0:
		state.erase("burn_left")
		state.erase("burn_joint")
		if is_instance_valid(world.fog):world.fog.rebuild()

func ruler_route(at:Vector2) -> Dictionary:
	var axis := aim_heading(at)
	var length := 900.0
	for i in 2:
		if not is_zero_approx(axis[i]):
			var boundary := float(world.map_size) if axis[i] > 0 else 0.0
			length = minf(length, (boundary - at[i]) / axis[i])
	return {"end": at + axis * maxf(length, 0), "heading": axis, "width": area.wide_half_width if int(Expedition.state.get("cycle", 1)) >= 3 else area.half_width}

func drive_position(event:Dictionary, left:float) -> Vector2:
	return Vector2(event.at).lerp(event.end, clampf(1.0 - left / DRIVE_TIME, 0, 1))

func advance_tank(event:Dictionary, previous:float) -> void:
	if event.left > DRIVE_TIME: return
	var a := drive_position(event, previous)
	var b := drive_position(event, event.left)
	reveal_sweep(a, b, event.width)
	if previous > DRIVE_TIME: Effects.spawn_impact(a, Color.SANDY_BROWN, event.width)
	for actor in world.units + world.buildings:
		if not hostile(actor) or actor.special.has("qiao_track_hit"): continue
		var closest := a if a.is_equal_approx(b) else Geometry2D.get_closest_point_to_segment(actor.position, a, b)
		if closest.distance_to(actor.position) > float(event.width) + actor.radius: continue
		actor.special.qiao_track_hit = true
		hurt(actor, event.power * (2.0 if actor is Building else 1.0))
		if event.joint: state.record_pending = true

func advance(seconds:float) -> void:
	if state.has("watch_left"):
		state.watch_left -= seconds
		if state.watch_left <= 0:
			state.erase("watch_left")
			for actor in world.units + world.buildings:
				if is_instance_valid(actor): actor.special.erase("reed_watch")
		queue_redraw()
	if state.has("cooldown"): advance_cooldown(seconds)
	if state.has("burn_left"): advance_exposure(seconds)
	if not (state.has("rescue_left") or state.has("breach_left") or state.has("photo_left") or state.has("events") or state.has("record_pending")):return
	if state.has("breach_left"):
		state.breach_left-=seconds
		if state.breach_left<=0:
			state.erase("breach_left");refresh()
	if state.has("photo_left"):
		state.photo_left-=seconds
		if state.photo_left<=0:
			state.erase("photo_left")
			var chain_radius := float(state.get("photo_chain_radius", Gifts.ITEMS.ines.area.chain))
			state.erase("photo_chain_radius")
			var resolved:=false
			for actor in world.units+world.buildings:
				if not world.actor_alive(actor) or not actor.special.has("keepsake_photo"):continue
				actor.special.erase("keepsake_photo")
				var at:Vector2=actor.position
				reveal_impact(at, chain_radius if state.photo_joint else 60.0)
				if not hostile(actor):continue
				Effects.spawn_beam(at+Vector2(70,-70),at,COLOR,"laser",2,.4)
				hurt(actor,200.0)
				if id=="ines" and state.photo_joint:
					for other in targets(at,chain_radius):
						if other!=actor:
							Effects.spawn_beam(at,other.position,COLOR,"laser")
							hurt(other,200);resolved=true;break
				elif state.photo_joint:resolved=true
			if resolved: state.record_pending = true
			save_record()
	var events:Array=state.get("events",[])
	for event:Dictionary in events.duplicate():
		var previous := float(event.left)
		event.left-=seconds
		if event.kind == "beacon_flight":
			for index in 3:
				var threshold := BEACON_DURATION - FIRST_IMPACT - index * BEACON_INTERVAL
				if previous > threshold and event.left <= threshold:
					var at := beacon_drop(event.at, event.heading, index)
					var radius := float(event.get("radius",Gifts.ITEMS.mara.area.radius))
					reveal_impact(at, radius)
					Effects.spawn_impact(at, Color.ORANGE, radius)
					for actor in targets(at, radius):
						hurt(actor, event.power)
						if event.return_strike: state.record_pending = true
			if event.left <= 0: events.erase(event)
			queue_redraw()
			continue
		if event.kind == "lark":
			if previous > 1.0 and event.left <= 1.0:
				var radius := float(event.get("radius",Gifts.ITEMS.seojin.area.radius))
				reveal_impact(event.at, radius)
				Effects.spawn_impact(event.at,Color.ORANGE,radius)
				for actor in targets(event.at,radius):
					hurt(actor,event.power)
					if event.joint: state.record_pending = true
			if event.left <= 0: events.erase(event)
			queue_redraw()
			continue
		if event.kind == "ruler":
			advance_tank(event, previous)
			queue_redraw()
			if event.left <= 0: events.erase(event)
			continue
		if event.left>0:continue
		events.erase(event)
		if event.kind == "global_clock":
			for unit in clock_targets():
				if world.actor_visible_to("ally", unit) and world.get_viewport_rect().has_point(world.get_global_transform_with_canvas() * unit.position):
					Effects.spawn_impact(unit.position, COLOR, 32)
				hurt(unit, event.power)
				state.record_pending = true
		elif event.kind=="flare":
			reveal_impact(event.at, 145.0)
			Effects.spawn_impact(event.at,Color.ORANGE,110)
			for actor in targets(event.at,145):
				hurt(actor,event.power)
				if event.get("return_strike",false):state.record_pending=true
		else:
			for shot in int(event.burst):
				var nearby:=targets(event.at,event.reach)
				if nearby.is_empty():break
				var target=nearby[0]
				reveal_impact(target.position, target.radius + 48.0)
				Effects.spawn_beam(event.at,target.position,COLOR,"laser",2,.35)
				target.receive_hit(event.power,event.get("type","shell"),event.get("bonuses",{}),null,event.get("warhead",""))
				state.record_pending=true
		queue_redraw()
	if events.is_empty():state.erase("events")
	if state.has("rescue_left"):
		state.rescue_left -= seconds
		if state.rescue_left <= 0:
			state.erase("rescue_left")
			recall()
	if state.get("record_pending",false):
		state.retry=float(state.get("retry",0))-seconds
		if state.retry<=0:state.retry=3.0;save_record()

func _draw() -> void:
	if state.has("watch_left"):
		for actor in world.units + world.buildings:
			if world.actor_alive(actor) and actor.special.has("reed_watch") and world.actor_visible_to("ally",actor):
				draw_arc(actor.position,actor.radius+6,0,TAU,32,Color.GOLD,2,true)
	if aiming and id == "mara" and ready_to_act() and world.world_input_enabled() and (aim_anchor.is_finite() or not world._pointer_over_ui()):
		var at := aim_anchor if aim_anchor.is_finite() else get_local_mouse_position()
		var heading := aim_heading(at)
		for index in 3:
			var drop := beacon_drop(at, heading, index)
			draw_circle(drop, area.radius, Color(COLOR, 0.10))
			draw_arc(drop, area.radius, 0, TAU, 80, COLOR, 3, true)
		var end := beacon_drop(at, heading, 2)
		draw_line(beacon_drop(at, heading, 0), end, COLOR, 3, true)
		for angle in [-0.5, 0.5]: draw_line(end, end - heading.rotated(angle) * 32, COLOR, 4, true)
	if aiming and id == "lin" and ready_to_act() and world.world_input_enabled() and not world._pointer_over_ui():
		var at := get_local_mouse_position()
		draw_circle(at, area.radius, Color(COLOR, 0.12))
		draw_arc(at, area.radius, 0, TAU, 96, COLOR, 3, true)
		for unit in rescue_targets(at):
			draw_arc(unit.position, unit.radius + 9, 0, TAU, 40, Color.WHITE, 3, true)
	if aiming and id == "qiao" and ready_to_act() and world.world_input_enabled() and (aim_anchor.is_finite() or not world._pointer_over_ui()):
		var at := aim_anchor if aim_anchor.is_finite() else get_local_mouse_position()
		if Rect2(Vector2.ZERO, Vector2.ONE * world.map_size).has_point(at):
			var route := ruler_route(at)
			var tip:Vector2 = route.end
			var axis: Vector2 = route.heading
			var tint := Color(COLOR, 0.22)
			draw_line(at, tip, tint, route.width * 2)
			draw_circle(at, route.width, tint)
			draw_circle(tip, route.width, tint)
			draw_line(at, tip, COLOR, 3, true)
			draw_line(tip, tip - axis.rotated(0.55) * 32, COLOR, 4, true)
			draw_line(tip, tip - axis.rotated(-0.55) * 32, COLOR, 4, true)
			if aim_anchor.is_finite():
				draw_ruler_tank(at, axis, 0.0, Color(1, 1, 1, 0.75))
	if aiming and (AREA_HINT.has(id) or id in ["ines", "vera"]) and ready_to_act() and world.world_input_enabled() and not world._pointer_over_ui():
		var center := get_local_mouse_position()
		var radius := float(area.radius)
		draw_circle(center,radius,Color(COLOR,0.10))
		draw_arc(center,radius,0,TAU,96,Color("#152a35"),4,true)
		draw_arc(center,radius,0,TAU,96,COLOR,2,true)
		if id == "sami" and Rect2(Vector2.ZERO, Vector2.ONE * world.map_size).has_point(center):
			var pulse := 0.65 + 0.35 * sin(Time.get_ticks_msec() * TAU / 1000.0)
			for unit in aid_targets(center):
				draw_arc(unit.position, unit.radius + 9, 0, TAU, 40, Color(0.04, 0.18, 0.10, pulse), 6, true)
				draw_arc(unit.position, unit.radius + 9, 0, TAU, 40, Color(0.43, 1.0, 0.53, pulse), 3, true)
		if id == "ines":
			for i in 48:
				var start := TAU*i/48.0
				draw_arc(center,area.reveal,start,start+TAU/96.0,4,Color(COLOR,0.8),2,true)
		draw_line(center-Vector2(8,0),center+Vector2(8,0),COLOR,2,true)
		draw_line(center-Vector2(0,8),center+Vector2(0,8),COLOR,2,true)
	for event:Dictionary in state.get("events",[]):
		if event.kind == "beacon_flight":
			draw_beacon_flight(event)
			continue
		if event.kind == "lark":
			var axis:Vector2 = world.player_start().direction_to(event.at)
			if axis == Vector2.ZERO: axis = Vector2.RIGHT
			var plane_at:Vector2 = event.at + axis * (1.0 - float(event.left)) * 400 + axis.orthogonal() * (float(event.lane)-1.5) * 48
			var art := RA2Art.art("BEAG")
			var size := RA2Art.frame_size(art)
			var frame := RA2Art.facing_index(axis.angle(),int(art.get("facings",8))) + int(art.get("facing_offset",0))
			if not art.is_empty(): RA2Art.draw_sprite(self,art,Rect2(plane_at-size*0.5,size),RA2Art.src_rect(art,frame),Color.WHITE)
			continue
		if event.kind == "ruler":
			var ground := drive_position(event, event.left)
			var height := clampf((event.left - DRIVE_TIME) / DROP_TIME, 0, 1) * 260.0
			draw_circle(ground, 20, Color(0,0,0,0.3))
			draw_ruler_tank(ground, event.get("heading", Vector2(event.at).direction_to(event.end)), height, Color.WHITE)
			continue
		if event.kind!="echo":continue
		var art:=RA2Art.art(event.art)
		if art.is_empty():draw_circle(event.at,19,Color(COLOR,.45));continue
		var size:=RA2Art.frame_size(art)
		var frame:=posmod(roundi(float(event.angle)/TAU*8),8)
		RA2Art.draw_sprite(self,art,Rect2(event.at-size*.5,size),RA2Art.src_rect(art,frame),Color(.5,.85,1,.48))

func draw_ruler_tank(ground: Vector2, heading: Vector2, height: float, tint: Color) -> void:
	var body := RA2Art.art("HTNK")
	if body.is_empty():return
	var facing := RA2Art.facing_index(heading.angle(), int(body.get("facings",8))) + int(body.get("facing_offset",0))
	var size := RA2Art.frame_size(body)
	var air := ground + get_canvas_transform().affine_inverse().basis_xform(Vector2.UP * height)
	RA2Art.draw_sprite(self,body,Rect2(air-size*0.5,size),RA2Art.src_rect(body,facing),tint)
