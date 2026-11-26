extends Control
class_name MiniMap
## 小地图：绘制战场缩略图，可点击/拖动来移动相机。

var _redraw_left := 0.0
var _camera_layer: Node2D
var battle: Battle
const Contacts=preload("res://scripts/expedition/contact_catalog.gd")
var radio_contact_id:=""
var _radio_portrait: TextureRect
var _radio_frame: ReferenceRect
var _radio_phase := 0.0
const RADIO_PULSE_SECONDS := 1.4
var objectives
var _dragging: bool = false
var _right_press := Vector2.INF
var _radar_history := PackedVector2Array()
var _radar_cursor := -1
var _radar_jump_ms := -1000
const Hotkeys = preload("res://scripts/ui/battle_hotkeys.gd")
const CampaignMarks = preload("res://scripts/ui/campaign_objective_marks.gd")
const PUBLIC_PINGS := ["friendly_support", "campaign_site", "campaign_discovery"]
var _ore_marks: Array = []
var _ore_signature := PackedInt64Array()
var _ore_projection := Transform2D.IDENTITY
var _ore_mask_revision := -1
var _ore_revision := -1
var _ore_sources: Array = []
var _ore_source_points := PackedVector2Array()
var _ore_source_cells := PackedInt32Array()
var _ore_source_empty := PackedByteArray()
var _ore_cell_states := PackedByteArray()
var _ore_source_mode := ""
var _ore_source_revision := -1
var _ore_source_fog: Object
var _ore_source_width := -1
var _ore_source_map_size := -1.0
var _ore_source_transform := Transform2D.IDENTITY
var _ore_sources_owned := false
var _pings: Array = []   # (B3) 雷达事件闪烁：{pos, kind, t, life}
var _projection_basis := Transform2D.IDENTITY
var _projection_size := Vector2.INF
var _projection_map := -1.0
var _layout := ""
var _world_edge := PackedVector2Array()
var _edge_uv := PackedVector2Array()
const NativeMaps = preload("res://scripts/world/native_maps.gd")
var _projection := Transform2D.IDENTITY

func setup(p_battle) -> void:
	clip_contents = true
	battle = p_battle
	objectives = null
	clear_radar_events()
	if _camera_layer == null:
		_camera_layer = Node2D.new()
		add_child(_camera_layer)
		_camera_layer.draw.connect(_draw_camera_outline)
	show_radio_contact("")
	_ore_revision = -1
	_ore_signature.clear()
	_ore_marks.clear()
	_ore_source_revision = -1
	_ore_sources_owned = false
	mouse_filter = Control.MOUSE_FILTER_STOP
	if not Events.radar_ping.is_connected(_on_radar_ping):
		Events.radar_ping.connect(_on_radar_ping)

## (B3) 收到雷达事件（受袭/建成）：入队并限流，供 _draw 闪烁。
func _on_radar_ping(world_pos: Vector2, kind: String) -> void:
	if not is_instance_valid(battle) or battle.ended or not world_pos.is_finite(): return
	_world_to_minimap()
	if not Geometry2D.is_point_in_polygon(world_pos, _world_edge): return
	if kind not in PUBLIC_PINGS and not battle.position_visible_to("ally", world_pos): return
	var life := 2.2 if kind == "ready" else (5.0 if kind in ["campaign_site", "campaign_discovery"] else 3.0)
	for pg in _pings:
		if pg.kind == kind and (pg.pos as Vector2).distance_squared_to(world_pos) < 55.0 * 55.0:
			return
	# Replace repeat alerts at the same spot rather than filling the history with one fight.
	for i in range(_radar_history.size() - 1, -1, -1):
		if _radar_history[i].distance_squared_to(world_pos) < 55.0 * 55.0:
			_radar_history.remove_at(i)
	_radar_history.append(world_pos)
	if _radar_history.size() > 8: _radar_history.remove_at(0)
	_radar_cursor = _radar_history.size() - 1
	_radar_jump_ms = -1000
	_pings.append({"pos": world_pos, "kind": kind, "t": 0.0, "life": life})
	if _pings.size() > 24:
		_pings = _pings.slice(_pings.size() - 24)
	queue_redraw()

func clear_radar_events() -> void:
	_pings.clear()
	_radar_history.clear()
	_radar_cursor = -1
	_radar_jump_ms = -1000
	queue_redraw()

func jump_to_radar_event() -> bool:
	if not _can_use_radar() or _radar_history.is_empty(): return false
	var now := Time.get_ticks_msec()
	_radar_cursor = _radar_history.size() - 1 if now - _radar_jump_ms > 400 else posmod(_radar_cursor - 1, _radar_history.size())
	_radar_jump_ms = now
	battle.center_on(_radar_history[_radar_cursor])
	return true

func _process(delta: float) -> void:
	if not _pings.is_empty():
		var keep: Array = []
		for pg in _pings:
			pg["t"] = float(pg["t"]) + delta
			if float(pg["t"]) < float(pg["life"]):
				keep.append(pg)
		_pings = keep
	if is_visible_in_tree():
		if not radio_contact_id.is_empty():
			_sync_radio_visibility()
			if _radio_portrait.visible:
				_radio_phase = fposmod(_radio_phase + BattleClock.control_delta(delta), RADIO_PULSE_SECONDS)
				_radio_frame.modulate.a = 0.68 + 0.32 * cos(TAU * _radio_phase / RADIO_PULSE_SECONDS)
				return
		_redraw_left -= BattleClock.control_delta(delta)
		if _redraw_left <= 0.0:
			_redraw_left = 0.20
			queue_redraw()
		if is_instance_valid(_camera_layer): _camera_layer.queue_redraw()

func _map_rect() -> Rect2:
	var boundary := _map_boundary()
	if boundary.is_empty(): return Rect2()
	var rect := Rect2(boundary[0], Vector2.ZERO)
	for point in boundary: rect = rect.expand(point)
	return rect

func _update_boundary(layout: String, map: float) -> void:
	_world_edge = PackedVector2Array([Vector2.ZERO, Vector2(map, 0), Vector2(map, map), Vector2(0, map)])
	if NativeMaps.has(layout):
		# Retail map edges run diagonally through the world cell grid.
		var low := Vector2.INF
		var high := -Vector2.INF
		for cell: Array in NativeMaps.data(layout).cells:
			var center := Vector2(cell[0] + cell[1] + 1, cell[1] - cell[0])
			low = low.min(center)
			high = high.max(center)
		low -= Vector2.ONE
		high += Vector2.ONE
		var corners := [low, Vector2(high.x, low.y), high, Vector2(low.x, high.y)]
		for i in corners.size():
			var d: Vector2 = corners[i]
			_world_edge[i] = Vector2(d.x - d.y, d.x + d.y) * (0.5 * NativeMaps.CELL)
	_edge_uv.clear()
	for point in _world_edge: _edge_uv.append(point / map)

func _world_to_minimap() -> Transform2D:
	if battle == null or float(battle.map_size) <= 0.0:
		return Transform2D.IDENTITY
	# Use the same basis as the visible battlefield, without camera translation.
	# Fit its full projected map, preserving rotation and vertical compression.
	var basis: Transform2D = battle.get_viewport().get_canvas_transform()
	basis.origin = Vector2.ZERO
	var map := float(battle.map_size)
	var layout := battle.map_layout()
	if layout != _layout or map != _projection_map:
		_update_boundary(layout, map)
		_layout = layout
	elif basis == _projection_basis and size == _projection_size:
		return _projection
	_projection_basis = basis
	_projection_size = size
	_projection_map = map
	var bounds := Rect2(basis * _world_edge[0], Vector2.ZERO)
	for corner in _world_edge:
		bounds = bounds.expand(basis * corner)
	var fit := maxf(0.000001, minf(size.x / maxf(bounds.size.x, 0.000001), size.y / maxf(bounds.size.y, 0.000001)))
	_projection = Transform2D(basis.x * fit, basis.y * fit, (size - bounds.size * fit) * 0.5 - bounds.position * fit)
	return _projection

func _map_boundary() -> PackedVector2Array:
	var projection := _world_to_minimap()
	return projection * _world_edge

func _to_map(local: Vector2) -> Vector2:
	var rect := _map_rect()
	if battle == null or rect.size.x <= 0.0:
		return Vector2.ZERO
	var map := float(battle.map_size)
	var point := _world_to_minimap().affine_inverse() * local
	if NativeMaps.has(_layout) and not Geometry2D.is_point_in_polygon(point, _world_edge):
		var nearest := _world_edge[0]
		for i in _world_edge.size():
			var candidate := Geometry2D.get_closest_point_to_segment(point, _world_edge[i], _world_edge[(i+1)%_world_edge.size()])
			if point.distance_squared_to(candidate) < point.distance_squared_to(nearest): nearest = candidate
		point = nearest
	return point.clamp(Vector2.ZERO, Vector2.ONE * map)

func _view_outline() -> PackedVector2Array:
	if battle == null or not is_instance_valid(battle.camera) or float(battle.map_size) <= 0.0:
		return PackedVector2Array()
	var rect := _map_rect()
	if rect.size.x <= 0.0:
		return PackedVector2Array()
	var viewport: Viewport = battle.get_viewport()
	var view: Rect2 = battle.camera_play_rect()
	var screen_to_world: Transform2D = viewport.get_canvas_transform().affine_inverse()
	var projection := _world_to_minimap()
	var polygon := PackedVector2Array()
	for corner in [view.position, Vector2(view.end.x, view.position.y), view.end, Vector2(view.position.x, view.end.y)]:
		var world: Vector2 = screen_to_world * corner
		polygon.append(projection * world)
	# At extreme zoom-out the viewport can extend beyond the world; keep its
	# visible footprint inside the map instead of drawing through the letterbox.
	var boundary := _map_boundary()
	var clipped := Geometry2D.intersect_polygons(polygon, boundary)
	return clipped[0] if not clipped.is_empty() else PackedVector2Array()

func _can_use_radar() -> bool:
	return is_instance_valid(battle) and battle.world_input_enabled() and not campaign_radar_offline() and not LightningStorm.radar_jammed(battle, "ally")

func _gui_input(event: InputEvent) -> void:
	if not _can_use_radar():
		cancel_drag()
		return
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT:
			# Start only over the drawn map. An active drag may cross the border.
			_dragging = event.pressed and Geometry2D.is_point_in_polygon(event.position, _map_boundary())
			if _dragging:
				_right_press = Vector2.INF
				battle.center_on(_focus_point(event.position))
			accept_event()
		elif event.button_index == MOUSE_BUTTON_RIGHT:
			var on_map := Geometry2D.is_point_in_polygon(event.position, _map_boundary())
			if event.pressed:
				_right_press = event.position if on_map and not _dragging else Vector2.INF
			else:
				var clicked := _right_press.is_finite() and _right_press.distance_to(event.position) <= 6.0
				_right_press = Vector2.INF
				if clicked and on_map and not battle.radar_ground_order(_to_map(event.position), event.shift_pressed, event.ctrl_pressed):
					battle.center_on(_focus_point(event.position))
			accept_event()
	elif event is InputEventMouseMotion:
		if _right_press.distance_to(event.position) > 6.0: _right_press = Vector2.INF
		if _dragging:
			battle.center_on(_to_map(event.position))
			accept_event()

func _focus_point(local: Vector2) -> Vector2:
	var best := _to_map(local)
	# Mission diamonds and visible event flashes have a few pixels of click tolerance.
	var error := 100.0
	var projection := _world_to_minimap()
	for pg in _pings:
		if pg.kind not in PUBLIC_PINGS and not battle.position_visible_to("ally", pg.pos): continue
		var distance := local.distance_squared_to(projection * (pg.pos as Vector2))
		if distance < error:
			error = distance
			best = pg.pos
	for mark in objective_marks():
		var distance := local.distance_squared_to(mark.local)
		if distance < error:
			error = distance
			best = mark.position
	return best

# Keep event history for manual recall, but stop flashing the previous objective.
func clear_objective_flashes() -> void:
	_pings = _pings.filter(func(pg): return pg.kind != "campaign_site")
	queue_redraw()

func cancel_drag() -> void:
	_dragging = false
	_right_press = Vector2.INF

func objective_marks() -> Array:
	var result:Array=[]
	if not is_instance_valid(battle) or LightningStorm.radar_jammed(battle,"ally"):return result
	var campaign_marks: Array = CampaignMarks.marks(battle, true)
	if campaign_marks.is_empty() and not is_instance_valid(objectives): return result
	var projection := _world_to_minimap()
	for marker: Dictionary in campaign_marks:
		marker.local = projection * Vector2(marker.position)
		result.append(marker)
	if not is_instance_valid(objectives): return result
	for marker:Dictionary in objectives.minimap_markers():
		var entry:=marker.duplicate()
		entry.local=projection*Vector2(marker.position)
		if marker.get("optional",false):entry.color=marker.get("color",UiKit.COL_SIDE_MISSION)
		else:
			match marker.status:
				"done": entry.color=Color("#80ef9a")
				"locked": entry.color=Color("#b5bbc7")
				_: entry.color=Color("#ffda59")
		result.append(entry)
	return result

func _get_tooltip(at_position: Vector2) -> String:
	if not is_instance_valid(battle): return ""
	if LightningStorm.radar_jammed(battle, "ally"): return "雷达受风暴干扰，暂时无法操作。"
	if campaign_radar_offline(): return "雷达离线。恢复雷达设施供电后可操作。"
	var help := "左键点击或拖动，移动镜头；右键命令部队移动或设置集结点。\n按 %s 跳到最近的雷达事件，快速连按可回看。" % Hotkeys.label("radar_event")
	if not radio_contact_id.is_empty():
		return str(Contacts.PEOPLE[radio_contact_id].name) + " · 通讯中\n" + help
	var hints:PackedStringArray=[]
	for marker:Dictionary in objective_marks():
		if marker.status=="base":
			if at_position.distance_squared_to(marker.local)<=196:hints.append("友军基地 · "+str(marker.title))
			continue
		if at_position.distance_squared_to(marker.local)<=100:
			var optional:bool=marker.get("optional",false)
			var status:String={"done":"已完成","locked":"已失败" if optional else "受保护，先完成前置目标","active":"进行中"}[marker.status]
			hints.append(("支线 · " if optional else "主线 · ")+str(marker.title)+" · "+status)
	if is_instance_valid(objectives):
		help += "\n菱形标记是公开任务目标：圆点表示进行中，勾表示已完成，横线表示不可用。"
	elif not battle.skirmish:
		help += "\n菱形标记指示任务地点，左键可跳到该位置。"
	return help if hints.is_empty() else "\n".join(hints) + "\n" + help

func _draw_objectives() -> void:
	for marker:Dictionary in objective_marks():
		var point:Vector2=marker.local
		if marker.has("contact_id"):
			var edge:=22.0 if marker.status=="base" else 18.0
			var color:=Color("#9ce8d8") if marker.status=="base" else UiKit.COL_SIDE_MISSION
			draw_portrait(marker.contact_id,Rect2(point-Vector2.ONE*edge/2,Vector2.ONE*edge),color)
			if marker.get("tracked",false):draw_arc(point,edge*0.8,0,TAU,28,color,2,true)
			continue
		var diamond:=PackedVector2Array([point+Vector2(0,-7),point+Vector2(7,0),point+Vector2(0,7),point+Vector2(-7,0),point+Vector2(0,-7)])
		draw_colored_polygon(diamond.slice(0,4),Color(0.04,0.05,0.07,0.95))
		draw_polyline(diamond,marker.color,2.0,true)
		if marker.get("tracked",false):draw_arc(point,10,0,TAU,24,marker.color,2,true)
		if marker.status=="done":draw_polyline(PackedVector2Array([point+Vector2(-3,0),point+Vector2(-1,2),point+Vector2(3,-3)]),marker.color,1.5,true)
		elif marker.status=="locked":draw_line(point+Vector2(-3,0),point+Vector2(3,0),marker.color,2.0)
		else:draw_circle(point,2.0,marker.color)

func show_radio_contact(id:String) -> void:
	var texture := Contacts.portrait(id)
	radio_contact_id = id if texture != null else ""
	if texture != null and _radio_portrait == null:
		_radio_portrait = TextureRect.new()
		_radio_portrait.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_radio_portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		_radio_portrait.stretch_mode = TextureRect.STRETCH_SCALE
		var shader := Shader.new()
		shader.code = "shader_type canvas_item; uniform vec2 crop = vec2(1.0); uniform vec2 pivot = vec2(0.5); uniform float lift; void vertex(){ UV = pivot + (UV - pivot) * crop - vec2(0.0, lift); }"
		var crop := ShaderMaterial.new()
		crop.shader = shader
		_radio_portrait.material = crop
		_radio_portrait.resized.connect(_frame_radio_portrait)
		add_child(_radio_portrait)
		_radio_portrait.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		_radio_frame = ReferenceRect.new()
		_radio_frame.editor_only = false
		_radio_frame.border_width = 3.0
		_radio_frame.border_color = Color("#98f5ec")
		_radio_frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_radio_portrait.add_child(_radio_frame)
		_radio_frame.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT, Control.PRESET_MODE_MINSIZE, 2)
	if _radio_portrait != null:
		_radio_portrait.texture = texture
		_frame_radio_portrait()
		_radio_phase = 0.0
		_radio_frame.modulate.a = 1.0
		_sync_radio_visibility()
	queue_redraw()

func _frame_radio_portrait() -> void:
	var image := _radio_portrait.texture
	var frame := _radio_portrait.size
	if image == null or frame.x <= 0 or frame.y <= 0: return
	var source := image.get_size()
	var scale_factor := maxf(frame.x / source.x, frame.y / source.y)
	var visible_y := clampf(frame.y / (source.y * scale_factor), 0.0, 1.0)
	var lift := minf(0.12 * visible_y, (1.0 - visible_y) * 0.5)
	var material_crop := _radio_portrait.material as ShaderMaterial
	material_crop.set_shader_parameter("crop", frame / (source * scale_factor))
	var pivot := Vector2(0.5,0.5)
	if image is AtlasTexture:
		var tile := image as AtlasTexture
		var sheet := tile.atlas.get_size()
		pivot = tile.region.get_center() / sheet
		lift *= tile.region.size.y / sheet.y
	material_crop.set_shader_parameter("pivot", pivot)
	material_crop.set_shader_parameter("lift", lift)

func _sync_radio_visibility() -> void:
	var active := not radio_contact_id.is_empty() and not LightningStorm.radar_jammed(battle, "ally")
	if active != _radio_portrait.visible:
		_radio_portrait.visible = active
		queue_redraw()
	_camera_layer.visible = not active

func draw_portrait(id:String,rect:Rect2,color:Color) -> void:
	var texture:=Contacts.portrait(id)
	if texture==null:return
	draw_rect(rect.grow(2),Color("#101820"))
	draw_texture_rect(texture,rect,false)
	draw_rect(rect.grow(1),color,false,1)

func _draw() -> void:
	var _call_log_scope = preload("res://scripts/world/battle_call_counters.gd").enter(35)
	if battle == null or (_radio_portrait != null and _radio_portrait.visible):
		return
	var s := size
	var map := float(battle.map_size)
	if map <= 0.0:
		return
	var projection := _world_to_minimap()
	var k := projection.x.length()
	# 背景
	draw_rect(Rect2(Vector2.ZERO, s), Color(0.04, 0.05, 0.07, 0.95))
	if LightningStorm.radar_jammed(battle, "ally"):
		draw_string(ThemeDB.fallback_font, Vector2(12, 24), "雷达受风暴干扰", HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color(0.7, 0.8, 0.9))
		return
	if campaign_radar_offline():
		draw_string(ThemeDB.fallback_font,Vector2(12,24),"雷达离线 · 需要空指部供电",HORIZONTAL_ALIGNMENT_LEFT,-1,14,Color.SILVER)
		return
	draw_set_transform_matrix(projection)
	draw_colored_polygon(_world_edge, Color(0.09, 0.11, 0.14))
	if preload("res://scripts/world/native_maps.gd").has(battle.map_layout()) and battle.ground._surface.texture!=null:
		draw_colored_polygon(_world_edge, Color.WHITE, _edge_uv, battle.ground._surface.texture)
	else:
		for water in battle.water_rects:
			draw_rect(water, Color(0.10, 0.25, 0.36))
	if battle.fog != null and battle.fog.texture != null:
		draw_colored_polygon(_world_edge, Color.WHITE, _edge_uv, battle.fog.texture)
	draw_set_transform_matrix(Transform2D.IDENTITY)
	# 资源点（T11）矿体已散成多枚小矿格：按邻近聚合成「一处一块」显示，避免糊成一片点阵
	var revision: int = battle.fog.minimap_mask_revision if battle.fog != null else - 1
	if _ore_revision != battle.radar_ore_revision or revision != _ore_mask_revision or not projection.is_equal_approx(_ore_projection):
		_refresh_ore_marks(projection)
		_ore_projection = projection
		_ore_mask_revision = revision
		_ore_revision = battle.radar_ore_revision
	for mk in _ore_marks:
		draw_circle(mk["p"], 2.5 + 0.7 * minf(int(mk["n"]), 6), Color(0.4, 0.9, 1.0) if mk["seen"] else Color(0.85, 0.64, 0.3))
	# 建筑
	for b in battle.buildings:
		if not is_instance_valid(b) or not battle.actor_alive(b) or not battle.actor_visible_to("ally", b):
			continue
		var p2: Vector2 = projection * b.global_position
		var col := Color(0.65, 0.65, 0.6) if b.side == "neutral" else Color(0.4, 0.7, 1.0) if BattleRequest.friendly(b.side,"ally") else Color(1.0, 0.45, 0.4)
		var sz: float = max(4.0, float(b.radius) * k * 1.6)
		if (not BattleRequest.skirmish and BattleRequest.mission_id=="yr_time_shift") or HouseColor.head_games() or HouseColor.hollywood_enemy(b.side): col = b._col
		draw_rect(Rect2(p2 - Vector2(sz, sz) * 0.5, Vector2(sz, sz)), col)
	# 单位
	for u in battle.units:
		if not is_instance_valid(u) or not battle.actor_alive(u) or not battle.actor_visible_to("ally", u):
			continue
		var p3: Vector2 = projection * u.global_position
		var col2 := Color(0.55, 0.85, 1.0) if BattleRequest.friendly(u.side,"ally") else Color(1.0, 0.55, 0.45)
		if (not BattleRequest.skirmish and BattleRequest.mission_id=="yr_time_shift") or HouseColor.head_games() or HouseColor.hollywood_enemy(u.side): col2 = u._col
		draw_circle(p3, 1.8, col2)
	# 雷达事件闪烁（B3）：受袭红环 / 建成黄环，随时间扩散淡出
	for pg in _pings:
		if pg["kind"] not in PUBLIC_PINGS and not battle.position_visible_to("ally", pg["pos"]):
			continue
		var pp: Vector2 = projection * (pg["pos"] as Vector2)
		var f: float = 1.0 - float(pg["t"]) / float(pg["life"])
		var blink: float = 0.35 + 0.65 * absf(sin(float(pg["t"]) * 9.0))
		var base: Color = Color(1.0, 0.9, 0.3, 0.9) if pg["kind"] in ["ready","campaign_site","campaign_discovery"] else Color(1.0, 0.35, 0.3, 0.95)
		if pg["kind"] == "firing_origin": base = Color("#ff982f")
		if pg["kind"] == "friendly_support": base = Color("#81dfff")
		base.a *= blink
		draw_arc(pp, 8.0 + 12.0 * (1.0 - f) if pg["kind"] in ["campaign_site","campaign_discovery"] else 4.0 + 5.0 * (1.0 - f), 0.0, TAU, 16, base, 2.0)
		draw_circle(pp, 2.0, base)
	# Hero reconnaissance uses battle time, including the remaining duration from a save.
	var marks: Dictionary = battle.allied_state.get("hero_scout_marks", {})
	for point: Vector2 in marks:
		var center: Vector2 = projection * point
		var phase := fposmod(float(marks[point]), 1.0)
		var gold := Color(1.0, 0.82, 0.22, 0.5 + 0.5 * phase)
		draw_arc(center, 6.0 + 6.0 * (1.0 - phase), 0.0, TAU, 24, gold, 2.0)
		draw_circle(center, 2.5, gold)
	# Public mission objectives remain readable above fog and ordinary radar dots.
	_draw_objectives()
	# 边框
	draw_rect(Rect2(Vector2.ZERO, s), Color(0.3, 0.45, 0.62), false, 2.0)

func campaign_radar_offline() -> bool:
	return is_instance_valid(battle) and battle.allied_state.has("hollywood") and not battle.Hollywood.radar_online(battle)

func _draw_camera_outline() -> void:
	if campaign_radar_offline():return
	if battle == null or LightningStorm.radar_jammed(battle, "ally"): return
	var outline := _view_outline()
	if outline.size() >= 3:
		outline.append(outline[0])
		_camera_layer.draw_polyline(outline, Color(0.9, 1.0, 1.0, 0.75), 1.5, true)

func _refresh_ore_marks(projection: Transform2D) -> void:
	# Fog changes anywhere used to recluster every ore cell. First compare only
	# the inputs that affect radar marks; harvesting a nonempty cell is unchanged.
	var signature := PackedInt64Array()
	var sources: Array = []
	var seen_states: Array[bool] = []
	var fog = battle.fog
	var sources_changed := _refresh_ore_sources(fog)
	var explored: PackedByteArray = fog.explored_cells.get("ally",PackedByteArray()) if fog!=null else PackedByteArray()
	var visible_cells: PackedByteArray = fog.visible_cells.get("ally",PackedByteArray()) if fog!=null else PackedByteArray()
	var cell_states := PackedByteArray()
	cell_states.resize(_ore_sources.size())
	for i in cell_states.size():
		var index := _ore_source_cells[i]
		if fog != null and (index < 0 or index >= explored.size() or explored[index] == 0): continue
		var seen := fog == null or (index < visible_cells.size() and visible_cells[index] != 0)
		if seen and _ore_source_empty[i] != 0: continue
		cell_states[i] = 2 if seen else 1
	if not sources_changed and cell_states == _ore_cell_states and projection.is_equal_approx(_ore_projection): return
	_ore_cell_states = cell_states
	for source_index in _ore_sources.size():
		if cell_states[source_index] == 0: continue
		var rn: ResourceNode = _ore_sources[source_index]
		if not is_instance_valid(rn): continue
		var seen := cell_states[source_index] == 2
		signature.append(rn.get_instance_id())
		signature.append(1 if seen else 0)
		sources.append(source_index)
		seen_states.append(seen)
	if signature == _ore_signature and projection.is_equal_approx(_ore_projection): return
	_ore_signature = signature
	_ore_projection = projection
	_ore_marks.clear()
	var bins := {}
	for source_index in sources.size():
		var seen: bool = seen_states[source_index]
		var p: Vector2 = projection * _ore_source_points[sources[source_index]]
		var cell := Vector2i((p / 5.0).floor())
		var match_index := -1
		# Preserve the original first matching mark, including cross-bin edges.
		# Avoid comparing each ore cell with every distant cluster on the map.
		for y in range(cell.y-1,cell.y+2):
			for x in range(cell.x-1,cell.x+2):
				for i:int in bins.get(Vector2i(x,y),[]):
					if (match_index < 0 or i < match_index) and p.distance_squared_to(_ore_marks[i]["p"]) < 25.0:
						match_index = i
		if match_index >= 0:
			_ore_marks[match_index]["n"] = int(_ore_marks[match_index]["n"]) + 1
			_ore_marks[match_index]["seen"] = _ore_marks[match_index]["seen"] or seen
		else:
			if not bins.has(cell): bins[cell] = []
			bins[cell].append(_ore_marks.size())
			_ore_marks.append({ "p": p, "n": 1, "seen": seen })

func _refresh_ore_sources(fog) -> bool:
	var nodes := battle.get_tree().get_nodes_in_group("resource_nodes")
	var width: int = fog.width if fog != null else -1
	var transform := battle.global_transform
	if _ore_sources_owned and nodes == _ore_sources and _ore_source_revision == battle.radar_ore_revision \
			and _ore_source_fog == fog and _ore_source_width == width and _ore_source_transform == transform and _ore_source_map_size == battle.map_size and _ore_source_mode == BattleRequest.rules_mode:
		return false
	_ore_sources = nodes
	_ore_source_points.resize(nodes.size())
	_ore_source_cells.resize(nodes.size())
	_ore_source_empty.resize(nodes.size())
	_ore_sources_owned = true
	for i in nodes.size():
		var node: ResourceNode = nodes[i]
		var point := node.global_position
		_ore_source_points[i] = point
		_ore_source_cells[i] = fog._index(point) if fog != null else -1
		_ore_source_empty[i] = int(node.is_empty())
		# Only direct battle children publish relocation/depletion revisions.
		# Foreign group members retain the original live-position behavior.
		_ore_sources_owned = _ore_sources_owned and node.get_parent() == battle
	_ore_source_revision = battle.radar_ore_revision
	_ore_source_fog = fog
	_ore_source_width = width
	_ore_source_map_size = battle.map_size
	_ore_source_transform = transform
	_ore_source_mode = BattleRequest.rules_mode
	return true
