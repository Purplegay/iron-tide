extends RefCounted
## RA3-style formation preview. The second world press takes ownership from box/pan.
const Ghost=preload("res://scripts/world/formation_ghost.gd")
const MeshView=preload("res://scripts/world/formation_mesh_view.gd")
var preview_root:Node2D
var ghosts:Dictionary={}
var meshes:Dictionary={}
var held := 0
var anchor := Vector2.ZERO
var preview_pixel := Vector2.ZERO
var start_pixel := Vector2.ZERO
var initial_heading := 0.0
var heading := 0.0
var columns := 1
var members: Array = []
var assigned: Dictionary = {}

func reset() -> void:
	held = 0
	if is_instance_valid(preview_root):
		preview_root.hide()
		preview_root.queue_free()
	preview_root=null
	ghosts.clear()
	meshes.clear()
	members.clear()
	assigned.clear()

func available(world, u) -> bool:
	return world.actor_alive(u) and u.side == "ally" and not u._deployed and u.embarked_in == null and u.move_speed > 0 and u.powered_unit.reason(u).is_empty() and (not AlliedAbilities.frozen(u) or u.special.has("leizhu") and preload("res://scripts/units/leizhu_insulation.gd").mobile(u))

func handle(world, event: InputEvent) -> bool:
	if held:
		if event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
			world.cancel_pointer_gestures()
			return true
		if event is InputEventMouseMotion:
			if (event.button_mask & held) != held:
				world.cancel_pointer_gestures()
				return true
			if held == (MOUSE_BUTTON_MASK_LEFT | MOUSE_BUTTON_MASK_RIGHT):
				update(world, event.position)
			return true
		if event is InputEventMouseButton and event.button_index in [MOUSE_BUTTON_LEFT,MOUSE_BUTTON_RIGHT]:
			var mask := 1 << (int(event.button_index)-1)
			if event.pressed:
				held |= mask
			else:
				held &= ~mask
				if held == 0:
					var valid := members.filter(func(u): return available(world,u) and u in world.selected_units)
					if not valid.is_empty() and not world._pointer_over_ui():
						world._issue_move_slots(valid, assigned, anchor, false, false, heading)
					reset()
			world.move_order_overlay.queue_redraw()
			return true
		return false
	if not event is InputEventMouseButton or not event.pressed or world._pointer_over_ui(): return false
	if world.command_mode != "" or world.cast_slot >= 0 or world.armed_build != "": return false
	var left_first: bool = event.button_index == MOUSE_BUTTON_RIGHT and world.dragging and event.position.distance_to(world.drag_start_screen) <= world._click_slop
	var right_first: bool = event.button_index == MOUSE_BUTTON_LEFT and world._rmb_panning and world._pan_button == MOUSE_BUTTON_RIGHT and not world._rmb_moved
	if not left_first and not right_first: return false
	var selected: Array = world.selected_units.filter(func(u): return available(world,u))
	if selected.is_empty(): return false
	start_pixel = event.position
	anchor = world.get_canvas_transform().affine_inverse() * start_pixel
	var center := Vector2.ZERO
	for u in selected:
		center += u.global_position
	center /= selected.size()
	initial_heading = selected[0].hull_angle if center.distance_to(anchor) < 1.0 else center.direction_to(anchor).angle()
	world.cancel_pointer_gestures()
	members = selected
	held = MOUSE_BUTTON_MASK_LEFT | MOUSE_BUTTON_MASK_RIGHT
	update(world, start_pixel)
	return true

func update(world, pixel: Vector2) -> void:
	preview_pixel = pixel
	var drag := pixel - start_pixel
	members = members.filter(func(u): return available(world,u))
	var count := members.size()
	if count == 0:
		reset()
		return
	var new_heading := initial_heading + drag.x * PI / 180.0
	var width := clampi(ceili(sqrt(float(count))) - roundi(drag.y / 24.0),1,count)
	if not assigned.is_empty() and is_equal_approx(new_heading,heading) and width == columns and assigned.size() == count: return
	heading = new_heading
	columns = width
	assigned.clear()
	var spacing: float = world._formation_spacing(members)
	var forward := Vector2.from_angle(heading)
	var slots: Array = []
	var rows := ceili(float(members.size()) / columns)
	for i in members.size():
		var row := i / columns
		var in_row := mini(columns, members.size()-row*columns)
		var across := float(i%columns) - (in_row-1)*0.5
		slots.append(anchor + spacing*(forward.orthogonal()*across + forward*((rows-1)*0.5-row)))
	assigned = world._assign_move_slots(members,slots,anchor)
	sync_models(world.move_order_overlay)
	world.move_order_overlay.queue_redraw()

func refresh(world) -> void:
	if held and members.any(func(u):return not available(world,u)):
		update(world,preview_pixel)

func sync_models(canvas:Node2D) -> void:
	if not is_instance_valid(preview_root):
		preview_root=Node2D.new()
		var tint:=ShaderMaterial.new()
		tint.shader=preload("res://shaders/formation_ghost.gdshader")
		preview_root.material=tint
		canvas.add_child(preview_root)
	for u in ghosts.keys():
		if not assigned.has(u):
			ghosts[u].hide()
			ghosts[u].queue_free()
			ghosts.erase(u)
	var order:=assigned.keys()
	order.sort_custom(func(a,b):return Iso.dir(assigned[a]).y<Iso.dir(assigned[b]).y)
	for u in order:
		var ghost=ghosts.get(u)
		if ghost==null:
			var view:SubViewport
			if u._ra3_model!=null:
				view=meshes.get(u.unit_id)
				if view==null:
					view=MeshView.new()
					preview_root.add_child(view)
					view.build(u._ra3_model)
					meshes[u.unit_id]=view
			ghost=Ghost.new()
			ghost.use_parent_material=true
			ghost.bind(u,view)
			preview_root.add_child(ghost)
			ghosts[u]=ghost
		preview_root.move_child(ghost,-1)
		ghost.position=assigned[u]
		ghost.hull_angle=heading
		ghost.turret_angle=heading
		ghost.aim_dir=Vector2.from_angle(heading)
		if ghost.model_view!=null:ghost.model_view.face(heading)
		ghost.queue_redraw()
