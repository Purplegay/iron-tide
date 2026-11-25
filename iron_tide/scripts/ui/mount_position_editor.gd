extends ColorRect
## Edit a draft in the workshop preview's own 3D world. Only Save writes the profile.
signal closed(saved:bool)
const Styles=preload("res://scripts/units/unit_cosmetics.gd")
const AXES := [Vector3.RIGHT,Vector3.UP,Vector3.BACK]
const COLORS := [Color("#ff807c"),Color("#87dc9c"),Color("#72bbff")]
const SLOT_NAMES := {"top":"顶部装饰","wing":"悬浮挂件","tail":"尾部挂件"}
const HANDLE := 74.0

# The three fixed cameras share the model, light and attachment with the editing view.
class AlignmentView extends TextureRect:
	var viewport:=SubViewport.new()
	var camera:=Camera3D.new()
	var anchor:Node3D
	var extent:float

	func setup(model:Ra3UnitModel,point:Node3D,center:Vector3,direction:Vector3,up:Vector3,span:float) -> void:
		anchor=point
		extent=span
		expand_mode=TextureRect.EXPAND_IGNORE_SIZE
		mouse_filter=Control.MOUSE_FILTER_IGNORE
		viewport.transparent_bg=true
		viewport.gui_disable_input=true
		viewport.world_3d=model.viewport.find_world_3d()
		add_child(viewport)
		viewport.add_child(camera)
		camera.projection=Camera3D.PROJECTION_ORTHOGONAL
		camera.cull_mask=model.camera.cull_mask
		camera.current=true
		var basis:=model.hull.global_basis.orthonormalized()
		camera.look_at_from_position(center+basis*direction*span*2.5,center,basis*up)
		texture=viewport.get_texture()
		resized.connect(_resize)
		_resize()

	func _resize() -> void:
		viewport.size=Vector2i(size).max(Vector2i(2,2))
		camera.size=extent*1.2*maxf(1.0,size.y/maxf(size.x,1.0))
		refresh()

	func refresh() -> void:
		viewport.render_target_update_mode=SubViewport.UPDATE_ONCE
		queue_redraw()

	func _draw() -> void:
		if not is_instance_valid(anchor) or size.x<2 or size.y<2:return
		var center:=size*0.5
		var ink:=Color("#7b95a780")
		draw_dashed_line(Vector2(0,center.y),Vector2(size.x,center.y),ink,1,5)
		draw_dashed_line(Vector2(center.x,0),Vector2(center.x,size.y),ink,1,5)
		var point:=camera.unproject_position(anchor.global_position)*size/Vector2(viewport.size)
		draw_arc(point,7,0,TAU,28,Color("#ffdd86"),1.5,true)
		draw_rect(Rect2(Vector2.ZERO,size),Color("#34495e"),false,1)

var alignment_views:Array[AlignmentView]=[]
var stage := Control.new()
var overlay := Control.new()
var scene_view := SubViewport.new()
var camera := Camera3D.new()
var controls: Array[SpinBox] = []
var status := Label.new()
const CosmeticAnchor=preload("res://scripts/units/cosmetic_anchor.gd")
var mount:CosmeticAnchor
var parts:=OptionButton.new()
var tilt_spin:=SpinBox.new()
var rotation_controls:Array[SpinBox]=[]
var rotation_xy:=Vector2i.ZERO
var mode_picker:=OptionButton.new()
var selected_axis:=2
var initial_angles:=Vector3i.ZERO
var ring_last:=0.0
var ring_delta:=0.0
var ring_tangent:=Vector2.ZERO
const ROTATE=3
var size_spin:=SpinBox.new()
var stretch_controls:Array[SpinBox]=[]
var size_percent:=100
var stretch:=Vector3i(100,100,100)
var drag_mode:=0
var edit_mode:=0 # Move, uniform scale, axis stretch, rotate.
var initial_size:=100
var initial_stretch:=Vector3i(100,100,100)
var save_button:Button
var part:=""
var tilt:=0
var initial_tilt:=0
var draft:Vector3i
var unit_id:String
var slot:String
var focus:Vector3
var span:float
var yaw:=0.7
var pitch:=0.43
var zoom:=1.0
var drag_button:=0
var drag_axis:=-1 # 0..2 axis, 3 screen plane
var press:Vector2
var initial:Vector3i
var axis_pixels:Vector2
var plane_depth:float

func open(model:Ra3UnitModel,id:String,key:String) -> void:
	unit_id=id
	slot=key
	mount=model.hull.get_node("CosmeticMount/"+slot)
	draft=MetaProgress.attachment_position(id,slot)
	var pose:=MetaProgress.attachment_pose(id,key)
	part=pose.part
	tilt=pose.pitch
	var angles:=MetaProgress.attachment_rotation(id,key)
	rotation_xy=Vector2i(angles.x,angles.y)
	var dimensions:=MetaProgress.attachment_size(id,key)
	size_percent=dimensions.size
	stretch=dimensions.stretch
	var box:=model.hull_bounds
	span=maxf(1.0,box.size.length())
	focus=model.hull.to_global(box.get_center())
	color=Color("#121c28")
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var margin:=MarginContainer.new()
	add_child(margin)
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for edge in ["left","right","top","bottom"]: margin.add_theme_constant_override("margin_"+edge,16)
	var column:=VBoxContainer.new()
	margin.add_child(column)
	column.add_child(UiKit.make_label("%s　/　%s · 位置、旋转与尺寸" % [model.actor.display_name,SLOT_NAMES[key]],22,UiKit.COL_ACCENT_2))
	var hint:=UiKit.make_label("W 移动 · E 旋转 · R 缩放 · T 拉伸；旋转时拖彩色圆环，X/Y/Z 选轴，←/→ 调角度（Shift 精调、Ctrl 15°）。右键环绕，中键平移，滚轮缩放镜头。",15,UiKit.COL_TEXT)
	hint.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	column.add_child(hint)
	stage.clip_contents=true
	stage.size_flags_vertical=Control.SIZE_EXPAND_FILL
	var views:=GridContainer.new()
	views.columns=2
	views.size_flags_vertical=Control.SIZE_EXPAND_FILL
	column.add_child(views)
	stage.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	views.add_child(stage)
	var frame:=SubViewportContainer.new()
	stage.add_child(frame)
	frame.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	frame.stretch=true
	frame.mouse_filter=Control.MOUSE_FILTER_IGNORE
	frame.add_child(scene_view)
	scene_view.world_3d=model.viewport.find_world_3d()
	scene_view.transparent_bg=true
	scene_view.gui_disable_input=true
	scene_view.msaa_3d=Viewport.MSAA_2X
	scene_view.add_child(camera)
	camera.projection=Camera3D.PROJECTION_ORTHOGONAL
	camera.cull_mask=model.camera.cull_mask
	camera.current=true
	stage.add_child(overlay)
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.mouse_filter=Control.MOUSE_FILTER_IGNORE
	overlay.draw.connect(_draw_handles.bind(overlay))
	_view_label(stage,"自由视图 · 拖动调整")
	for spec in [["正视 · 左右 / 高低",Vector3.RIGHT,Vector3.UP],["侧视 · 前后 / 高低",Vector3.BACK,Vector3.UP],["俯视 · 车头向上",Vector3.UP,Vector3.RIGHT]]:
		var view:=AlignmentView.new()
		view.size_flags_horizontal=Control.SIZE_EXPAND_FILL
		view.size_flags_vertical=Control.SIZE_EXPAND_FILL
		views.add_child(view)
		view.setup(model,mount,focus,spec[1],spec[2],span)
		_view_label(view,spec[0])
		alignment_views.append(view)
	stage.gui_input.connect(_stage_input)
	get_window().focus_exited.connect(_release_drag)
	stage.resized.connect(overlay.queue_redraw)
	var modes:=HBoxContainer.new()
	column.add_child(modes)
	modes.add_child(UiKit.make_label("鼠标操作",14,UiKit.COL_TEXT))
	mode_picker.name="TransformMode"
	for caption in ["移动挂点 W","整体缩放 R","分轴拉伸 T","三轴旋转 E"]:mode_picker.add_item(caption)
	modes.add_child(mode_picker)
	mode_picker.item_selected.connect(_set_mode)
	modes.add_child(UiKit.make_label("Shift 拖中心缩放／拖轴拉伸；Alt 拖动俯仰；旋转环 Ctrl 吸附 15°",14,UiKit.COL_TEXT))
	var binding:=HBoxContainer.new()
	column.add_child(binding)
	binding.add_child(UiKit.make_label("附属于",14,UiKit.COL_TEXT))
	binding.add_child(parts)
	parts.add_item("车体 · 原挂点")
	parts.set_item_metadata(0,"")
	var labels:Dictionary=Styles.PARTS.get(id,{})
	for bone:String in labels:
		if mount.rig.find_bone(bone)<0: continue
		parts.add_item(labels[bone])
		parts.set_item_metadata(parts.item_count-1,bone)
		if bone==part:parts.select(parts.item_count-1)
	parts.item_selected.connect(func(index:int):
		part=parts.get_item_metadata(index)
		set_draft(draft))
	for i in 3:
		binding.add_child(UiKit.make_label(["X 侧倾","Y 偏航","Z 俯仰"][i],14,COLORS[i]))
		var spin:=tilt_spin if i==2 else SpinBox.new()
		spin.min_value=-180;spin.max_value=180;spin.step=1;spin.suffix="°"
		spin.value=_angles()[i]
		binding.add_child(spin);rotation_controls.append(spin)
		spin.value_changed.connect(func(v:float):
			var next:=_angles();next[i]=roundi(v);_set_angles(next))
	var fields:=HBoxContainer.new()
	column.add_child(fields)
	for i in 3:
		fields.add_child(UiKit.make_label(["X 前后","Y 高低","Z 左右"][i],14,COLORS[i]))
		var spin:=UiKit.make_spin(draft[i],-Styles.SHIFT_LIMIT,Styles.SHIFT_LIMIT,1)
		spin.suffix="%"
		fields.add_child(spin)
		controls.append(spin)
		spin.value_changed.connect(func(value:float):
			var next:=draft
			next[i]=roundi(value)
			set_draft(next))
	var sizes:=HBoxContainer.new()
	column.add_child(sizes)
	sizes.add_child(UiKit.make_label("整体缩放",14,UiKit.COL_TEXT))
	size_spin.name="OverallScale"
	size_spin.min_value=Styles.SIZE_MIN
	size_spin.max_value=Styles.SIZE_MAX
	size_spin.step=1
	size_spin.suffix="%"
	size_spin.value=size_percent
	sizes.add_child(size_spin)
	size_spin.value_changed.connect(func(value:float):
		size_percent=roundi(value)
		set_draft(draft))
	for i in 3:
		sizes.add_child(UiKit.make_label(["X 长度","Y 高度","Z 宽度"][i],14,COLORS[i]))
		var spin:=UiKit.make_spin(stretch[i],Styles.SIZE_MIN,Styles.SIZE_MAX,1)
		spin.name="Stretch"+str(i)
		spin.suffix="%"
		sizes.add_child(spin)
		stretch_controls.append(spin)
		spin.value_changed.connect(func(value:float):
			stretch[i]=roundi(value)
			set_draft(draft))
	var actions:=HBoxContainer.new()
	column.add_child(actions)
	for caption in ["复位挂点","取消","保存并返回"]:
		var button:=UiKit.make_button(caption)
		actions.add_child(button)
		match caption:
			"复位挂点": button.pressed.connect(func():
				parts.select(0)
				part=""
				tilt=0
				rotation_xy=Vector2i.ZERO
				size_percent=100
				stretch=Vector3i(100,100,100)
				tilt_spin.set_value_no_signal(0)
				set_draft(Vector3i.ZERO))
			"取消": button.pressed.connect(func():closed.emit(false))
			"保存并返回":
				save_button=button
				button.pressed.connect(_save)
	actions.add_child(status)
	Events.meta_changed.connect(_update_cost)
	set_draft(draft)
	actions.get_child(2).grab_focus()

func _view_label(parent:Control,title:String) -> void:
	var label:=UiKit.make_label(title,14,UiKit.COL_ACCENT_2)
	label.mouse_filter=Control.MOUSE_FILTER_IGNORE
	parent.add_child(label)
	label.position=Vector2(8,4)

func _changed() -> bool:
	return draft!=MetaProgress.attachment_position(unit_id,slot) or MetaProgress.attachment_pose(unit_id,slot)!={"part":part,"pitch":tilt} or MetaProgress.attachment_rotation(unit_id,slot)!=_angles() or MetaProgress.attachment_size(unit_id,slot)!={"size":size_percent,"stretch":stretch}

func _update_cost() -> void:
	if save_button==null:return
	var fee:=Styles.ADJUST_COST if _changed() else 0
	save_button.text="保存并返回 · %d 券" % fee
	save_button.disabled=MetaProgress.balance("credits")<fee
	status.text="军需券余额 %d%s" % [floori(MetaProgress.balance("credits"))," · 余额不足" if save_button.disabled else ""]

func _save() -> void:
	if MetaProgress.save_attachment(unit_id,slot,draft,part,tilt,size_percent,stretch,rotation_xy.x,rotation_xy.y):
		closed.emit(true)
	else: status.text="位置未保存，可重试。"

func set_draft(value:Vector3i) -> void:
	var limit:=Vector3i.ONE*Styles.SHIFT_LIMIT
	draft=value.clamp(-limit,limit)
	mount.configure(part,tilt,draft,Vector3(stretch)*float(size_percent)/10000.0,rotation_xy)
	for i in rotation_controls.size():rotation_controls[i].set_value_no_signal(_angles()[i])
	size_spin.set_value_no_signal(size_percent)
	for i in stretch_controls.size():stretch_controls[i].set_value_no_signal(stretch[i])
	_update_cost()
	for i in controls.size():controls[i].set_value_no_signal(draft[i])
	overlay.queue_redraw()
	_update_camera()
	for view in alignment_views:
		view.extent=span*_size_framing()
		view._resize()

func _size_framing() -> float:
	return maxf(1.0,float(size_percent)*maxi(stretch.x,maxi(stretch.y,stretch.z))/10000.0)

func _update_camera() -> void:
	var direction:=Vector3(sin(yaw)*cos(pitch),sin(pitch),cos(yaw)*cos(pitch))
	camera.size=span*1.2*_size_framing()/zoom
	camera.position=focus+direction*span*2.5
	camera.look_at(focus)
	overlay.queue_redraw()

func _screen(p:Vector3) -> Vector2:
	return camera.unproject_position(p)*stage.size/Vector2(scene_view.size)

func _axis_step(i:int) -> Vector2:
	var axis_basis:=mount.editing_basis()
	if edit_mode in [1,2]:axis_basis=axis_basis*mount.rotation_basis()
	var shift:Vector3=axis_basis*AXES[i]*0.01
	return _screen(mount.global_position+shift)-_screen(mount.global_position)

func _draw_handles(canvas:Control) -> void:
	if not is_instance_valid(mount) or scene_view.size.x<2:return
	var center:=_screen(mount.global_position)
	if edit_mode==ROTATE:
		for i in 3:
			var points:=_ring_points(i)
			canvas.draw_polyline(points,Color("#14212d"),6,true)
			canvas.draw_polyline(points,COLORS[i],3.5 if i==selected_axis else 2,true)
			canvas.draw_string(ThemeDB.fallback_font,points[8]+Vector2(5,-5),["X","Y","Z"][i],HORIZONTAL_ALIGNMENT_LEFT,-1,16,COLORS[i])
		canvas.draw_circle(center,4,Color("#ffdd86"))
		canvas.draw_string(ThemeDB.fallback_font,center+Vector2(-60,HANDLE+30),"%s  %d°"%[["X 侧倾","Y 偏航","Z 俯仰"][selected_axis],_angles()[selected_axis]],HORIZONTAL_ALIGNMENT_LEFT,-1,16,COLORS[selected_axis])
		return
	for i in 3:
		var step:=_axis_step(i)
		if step.length()<0.15:continue
		var axis:=step.normalized()
		var tip:=center+axis*HANDLE
		canvas.draw_line(center,tip,Color("#14212d"),5,true)
		canvas.draw_line(center,tip,COLORS[i],2.5,true)
		if edit_mode==0:
			canvas.draw_colored_polygon(PackedVector2Array([tip,tip-axis*12+axis.orthogonal()*5,tip-axis*12-axis.orthogonal()*5]),COLORS[i])
		else:canvas.draw_rect(Rect2(tip-Vector2.ONE*5,Vector2.ONE*10),COLORS[i])
		canvas.draw_string(ThemeDB.fallback_font,tip+Vector2(4,-2),["X","Y","Z"][i],HORIZONTAL_ALIGNMENT_LEFT,-1,15,COLORS[i])
	canvas.draw_circle(center,6.0,Color("#ffdd86"))

func _axis_at(point:Vector2) -> int:
	var center:=_screen(mount.global_position)
	if point.distance_to(center)<=9:return 3
	var closest:=-1
	var best:=9.0
	for i in 3:
		var step:=_axis_step(i)
		if step.length()<0.15:continue
		var tip:=center+step.normalized()*HANDLE
		var distance:=point.distance_to(Geometry2D.get_closest_point_to_segment(point,center,tip))
		if distance<best:
			closest=i
			best=distance
	return closest

func _plane_point(point:Vector2,depth:float) -> Vector3:
	return camera.project_position(point*Vector2(scene_view.size)/stage.size,depth)

func _angles() -> Vector3i:
	return Vector3i(rotation_xy.x,rotation_xy.y,tilt)

func _set_angles(value:Vector3i) -> void:
	rotation_xy=Vector2i(value.x,value.y)
	tilt=value.z
	set_draft(draft)

func _set_mode(value:int) -> void:
	_release_drag()
	edit_mode=value
	mode_picker.select(value)
	overlay.queue_redraw()

func _ring_radius() -> float:
	# Fixed screen size, independent of the accessory's non-uniform scale.
	var at:=mount.global_position
	var pixels:=_screen(at+camera.global_basis.x).distance_to(_screen(at))
	return HANDLE/maxf(1,pixels)

func _ring_points(axis:int) -> PackedVector2Array:
	var points:=PackedVector2Array()
	var basis:=mount.editing_basis().orthonormalized()
	var radius:=_ring_radius()
	for j in 73:
		var angle:=TAU*j/72.0
		var local:Vector3=(AXES[(axis+1)%3]*cos(angle)+AXES[(axis+2)%3]*sin(angle))*radius
		points.append(_screen(mount.global_position+basis*local))
	return points

func _ring_at(point:Vector2) -> int:
	var best:=9.0
	var result:=-1
	# Resolve exact crossings in favor of the axis explicitly selected by keyboard.
	for axis in [selected_axis,(selected_axis+1)%3,(selected_axis+2)%3]:
		var points:=_ring_points(axis)
		for j in points.size()-1:
			var distance:=point.distance_to(Geometry2D.get_closest_point_to_segment(point,points[j],points[j+1]))
			if distance<best-0.05:best=distance;result=axis
	return result

func _ring_angle(point:Vector2,axis:int) -> float:
	var basis:=mount.editing_basis().orthonormalized()
	var pixel:=point*Vector2(scene_view.size)/stage.size
	var origin:=camera.project_ray_origin(pixel)
	var ray:=camera.project_ray_normal(pixel)
	var normal:Vector3=basis*AXES[axis]
	var denominator:=normal.dot(ray)
	if absf(denominator)<.08:return NAN # Edge-on ring uses screen tangent drag.
	var intersection:=origin+ray*(normal.dot(mount.global_position-origin)/denominator)
	var local:=basis.inverse()*(intersection-mount.global_position)
	return atan2(local.dot(AXES[(axis+2)%3]),local.dot(AXES[(axis+1)%3]))

func _begin_rotation(point:Vector2,axis:int) -> void:
	selected_axis=axis
	initial_angles=_angles()
	ring_last=_ring_angle(point,axis)
	ring_delta=0
	var points:=_ring_points(axis)
	var nearest:=0
	for j in 72:
		if point.distance_squared_to(points[j])<point.distance_squared_to(points[nearest]):nearest=j
	ring_tangent=(points[(nearest+1)%72]-points[(nearest+71)%72]).normalized()
	overlay.queue_redraw()

func _rotate_drag(event:InputEventMouseMotion) -> void:
	var angle:=_ring_angle(event.position,drag_axis)
	if is_finite(angle) and is_finite(ring_last):
		ring_delta+=rad_to_deg(wrapf(angle-ring_last,-PI,PI))
		ring_last=angle
	else:ring_delta=(event.position-press).dot(ring_tangent)*0.8
	var amount:=ring_delta*(.2 if event.shift_pressed else 1.0)
	if event.ctrl_pressed:amount=snappedf(amount,15)
	_set_angles(_rotated_angles(initial_angles,drag_axis,amount))

func _rotated_angles(from:Vector3i,axis:int,degrees:float) -> Vector3i:
	# Apply rotation around the displayed anchor axis, then store Euler angles.
	# Adding Euler components directly would rotate around a different axis after yaw.
	var basis:=Basis(AXES[axis],deg_to_rad(degrees))*Basis.from_euler(Vector3(from)*PI/180.0)
	return Vector3i((basis.get_euler()*180.0/PI).round())

func _release_drag() -> void:
	drag_button=0

func _stage_input(event:InputEvent) -> void:
	if event is InputEventMouseButton:
		if not event.pressed:
			if event.button_index==drag_button:drag_button=0
			return
		if drag_button!=0:return
		if event.button_index in [MOUSE_BUTTON_WHEEL_UP,MOUSE_BUTTON_WHEEL_DOWN]:
			zoom=clampf(zoom*(1.18 if event.button_index==MOUSE_BUTTON_WHEEL_UP else 1/1.18),0.4,4)
			_update_camera()
		elif event.button_index in [MOUSE_BUTTON_LEFT,MOUSE_BUTTON_RIGHT,MOUSE_BUTTON_MIDDLE]:
			press=event.position
			initial=draft
			initial_size=size_percent
			initial_stretch=stretch
			if event.button_index==MOUSE_BUTTON_LEFT:
				initial_tilt=tilt
				drag_mode=ROTATE if edit_mode==ROTATE else (2 if event.shift_pressed else edit_mode)
				drag_axis=4 if event.alt_pressed else (_ring_at(press) if drag_mode==ROTATE else _axis_at(press))
				if drag_axis<0:return
				if drag_axis<3:
					if drag_mode==ROTATE:_begin_rotation(press,drag_axis)
					else:axis_pixels=_axis_step(drag_axis)
				plane_depth=-camera.to_local(mount.global_position).z
			drag_button=event.button_index
		stage.accept_event()
	elif event is InputEventMouseMotion and drag_button!=0:
		match drag_button:
			MOUSE_BUTTON_RIGHT:
				yaw-=event.relative.x*0.01
				pitch=clampf(pitch+event.relative.y*0.01,-1.45,1.45)
				_update_camera()
			MOUSE_BUTTON_MIDDLE:
				focus+=_plane_point(event.position-event.relative,span*2.5)-_plane_point(event.position,span*2.5)
				_update_camera()
			MOUSE_BUTTON_LEFT:
				if drag_axis==4:
					tilt_spin.value=clampi(initial_tilt+roundi((press.y-event.position.y)*0.5),-180,180)
				elif drag_mode==ROTATE:
					_rotate_drag(event)
				elif drag_mode!=0:
					var amount:=roundi((press.y-event.position.y)*0.6) if drag_axis==3 else roundi((event.position-press).dot(axis_pixels.normalized())*0.6)
					if drag_mode==1 or drag_axis==3:
						size_percent=clampi(initial_size+amount,Styles.SIZE_MIN,Styles.SIZE_MAX)
					else:
						stretch=initial_stretch
						stretch[drag_axis]=clampi(initial_stretch[drag_axis]+amount,Styles.SIZE_MIN,Styles.SIZE_MAX)
					set_draft(draft)
				elif drag_axis==3:
					var world_delta:=_plane_point(event.position,plane_depth)-_plane_point(press,plane_depth)
					var local_delta:=mount.editing_basis().inverse()*world_delta
					set_draft(initial+Vector3i((local_delta*100.0).round()))
				else:
					var next:=initial
					next[drag_axis]+=roundi((event.position-press).dot(axis_pixels)/axis_pixels.length_squared())
					set_draft(next)
		stage.accept_event()

func _input(event:InputEvent) -> void:
	if not event is InputEventKey or not event.pressed or not is_visible_in_tree():return
	if event.keycode==KEY_ESCAPE and not event.echo:
		get_viewport().set_input_as_handled();closed.emit(false);return
	var focused:=get_viewport().gui_get_focus_owner()
	if focused is LineEdit or focused is TextEdit:return
	if event.alt_pressed or event.meta_pressed or drag_button!=0:return
	var handled:=true
	match event.keycode:
		KEY_W:_set_mode(0)
		KEY_E:_set_mode(ROTATE)
		KEY_R:_set_mode(1)
		KEY_T:_set_mode(2)
		KEY_X,KEY_Y,KEY_Z:
			_set_mode(ROTATE)
			selected_axis=[KEY_X,KEY_Y,KEY_Z].find(event.keycode)
			overlay.queue_redraw()
		KEY_LEFT,KEY_RIGHT:
			if edit_mode==ROTATE:
				var step:=1 if event.shift_pressed else (15 if event.ctrl_pressed else 5)
				_set_angles(_rotated_angles(_angles(),selected_axis,step*(-1 if event.keycode==KEY_LEFT else 1)))
			else:handled=false
		_:handled=false
	if handled:get_viewport().set_input_as_handled()
