extends Control
const Psi = preload("res://scripts/units/yuriko.gd")
const KEYS := ["burst","Lure","Shield","Slam"]
const SHORTCUTS := [KEY_Q,KEY_W,KEY_E,KEY_R]
var command
var actor
var frame:TextureRect
var face:TextureButton
var points:Button
var slots:Dictionary={}
var health:ColorRect
var support_time:=Label.new()

func _ready() -> void:
	name="YurikoSelectionBar"
	mouse_filter=Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT)
	offset_left=-372
	offset_right=-18
	offset_top=-191
	offset_bottom=-105
	frame=TextureRect.new()
	frame.texture=load(Psi.ART+"SelectionDetails.png")
	var trim:=ShaderMaterial.new()
	trim.shader=preload("res://shaders/yuriko_hud.gdshader")
	frame.material=trim
	frame.mouse_filter=Control.MOUSE_FILTER_IGNORE
	frame.texture_filter=CanvasItem.TEXTURE_FILTER_LINEAR
	add_child(frame)
	face=TextureButton.new()
	face.position=Vector2(50,9)
	face.size=Vector2(65,65)
	face.ignore_texture_size=true
	face.stretch_mode=TextureButton.STRETCH_SCALE
	face.pressed.connect(command.open)
	add_child(face)
	face.add_child(support_time)
	support_time.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	support_time.offset_top=-18
	support_time.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
	support_time.mouse_filter=Control.MOUSE_FILTER_IGNORE
	support_time.add_theme_font_size_override("font_size",13)
	support_time.add_theme_constant_override("outline_size",4)
	support_time.add_theme_color_override("font_outline_color",Color("#201523"))
	points=Button.new()
	# Center the button on the circular inset in SelectionDetails.png.
	points.position=Vector2(11,24)
	points.size=Vector2(35,35)
	points.flat=true
	points.tooltip_text="查看本场已习得技能"
	points.pressed.connect(command.open)
	add_child(points)
	for i in KEYS.size():
		var b:=TextureButton.new()
		b.position=Vector2(122+i*56.6,11)
		b.size=Vector2(46,48)
		b.ignore_texture_size=true
		b.stretch_mode=TextureButton.STRETCH_SCALE
		b.pressed.connect(activate.bind(KEYS[i]))
		preload("res://scripts/ui/skill_cooldown_clock.gd").attach(b)
		var seconds:=Label.new()
		seconds.name="CooldownSeconds"
		seconds.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
		seconds.vertical_alignment=VERTICAL_ALIGNMENT_CENTER
		seconds.mouse_filter=Control.MOUSE_FILTER_IGNORE
		seconds.add_theme_font_size_override("font_size",20)
		seconds.add_theme_constant_override("outline_size",4)
		seconds.add_theme_color_override("font_outline_color",Color("#211326"))
		b.add_child(seconds)
		seconds.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		seconds.hide()
		var letter:=Label.new()
		letter.name="Shortcut"
		letter.text=OS.get_keycode_string(SHORTCUTS[i])
		letter.position=Vector2(2,-1)
		letter.mouse_filter=Control.MOUSE_FILTER_IGNORE
		letter.add_theme_font_size_override("font_size",13)
		letter.add_theme_constant_override("outline_size",4)
		letter.add_theme_color_override("font_outline_color",Color("#231526"))
		b.add_child(letter)
		slots[KEYS[i]]=b
		add_child(b)
	health=ColorRect.new()
	health.position=Vector2(123,66)
	health.mouse_filter=Control.MOUSE_FILTER_IGNORE
	add_child(health)
	hide()

func bind(u) -> void:
	actor=u
	visible=is_instance_valid(u) and u.unit_id==Psi.ID and u.side=="ally"
	if visible: refresh()

func hotkey(code:int) -> bool:
	var index:=SHORTCUTS.find(code)
	if index<0 or not AlliedAbilities.alive(actor) or not actor.selected:return false
	refresh()
	if not slots[KEYS[index]].disabled:activate(KEYS[index])
	return true

func activate(key:String) -> void:
	if not is_instance_valid(actor) or not actor.selected:return
	command._power(key)
	refresh()

func refresh() -> void:
	if not AlliedAbilities.alive(actor) or not actor.selected:
		hide()
		return
	var world=actor._battle_world()
	var index:=Psi.skin(world)
	var color:Color=Psi.COLORS[index]
	frame.material.set_shader_parameter("accent",color)
	health.color=color
	health.size=Vector2(214*clampf(actor.hp/maxf(1.0,actor.max_hp),0,1),5)
	face.texture_normal=load(Psi.ART+Psi.PORTRAITS[index]+".png")
	support_time.visible=actor.special.has("psi_support_left")
	if support_time.visible:support_time.text=Psi.deployment_clock(actor.special.psi_support_left)
	face.tooltip_text="百合子 · "+Psi.SKINS[index]+"　点击查看战场指令与衣装"
	points.text=str(Psi.training(world).learned.size())
	for key in KEYS:
		var b:TextureButton=slots[key]
		var rank:=1 if key=="burst" else Psi.rank(world,key)
		var icon:String={"Slam":"PsychicSlam","Lure":"PsychicLure","Shield":"Shield"}.get(key,"")
		var action:String="Throw" if key=="Slam" and not Psi.held(actor).is_empty() else key
		var tex:String="Psychokinesis" if key=="burst" else icon+str(maxi(1,rank))
		b.texture_normal=load(Psi.ART+tex+".png")
		b.disabled=rank==0 or not Psi.ready(actor,action)
		b.self_modulate=Color(.48,.48,.48,1) if b.disabled else Color.WHITE
		var remaining:=float(actor.special.get("psi_cd_"+action,0.0)) if rank>0 else 0.0
		b.get_node("CooldownClock").update_timer(remaining,Psi.cooldown_duration(actor,action,rank))
		var seconds:Label=b.get_node("CooldownSeconds")
		seconds.visible=remaining>0.0
		if seconds.visible:seconds.text=str(ceili(BattleClock.real_seconds(remaining)))
		var label:String="掷出" if action=="Throw" else Psi.NAMES.get(key,"灵能爆发 · 手动 Q")
		b.tooltip_text=label+(" · 未习得" if rank==0 else " · %d 级"%rank if key!="burst" else "")
