extends Node
const Psi = preload("res://scripts/units/yuriko.gd")
const WAIT_FOR_LIFT := "WaitForLift"
var world
var popup: PopupPanel
var content: VBoxContainer
var strip
var outfit: OptionButton
var portrait: TextureRect
var points: Label
var notice: Label
var powers := {}
var pending := ""
var marker
var swallow_release := false
var elapsed := 0.0

class Marker extends Node2D:
	var command
	var decal:=Sprite2D.new()
	const CURSORS:={"Lure":"Target_Yuriko_Lure","Slam":"Target_Yuriko_Slam1","Throw":"Target_Yuriko_Slam2"}

	func _ready() -> void:
		var additive:=CanvasItemMaterial.new()
		additive.blend_mode=CanvasItemMaterial.BLEND_MODE_ADD
		decal.material=additive
		decal.texture_filter=CanvasItem.TEXTURE_FILTER_LINEAR
		decal.hide()
		add_child(decal)

	func show_decal(power:String,point:Vector2,radius:float) -> void:
		var id:String=CURSORS[power]
		if decal.get_meta("cursor_id","")!=id:
			decal.texture=load(Psi.FX.FOLDER+id+".png")
			decal.set_meta("cursor_id",id)
		var data:Dictionary=Psi.FX.bank.media.cursors[id]
		decal.position=point
		decal.scale=Vector2.ONE*(2.0*radius)/decal.texture.get_width()
		decal.modulate.a=lerpf(data.minimum,data.maximum,.5+.5*sin(Time.get_ticks_msec()*.001*TAU*float(data.hz)))
		decal.show()
	func _draw() -> void:
		decal.hide()
		var w = command.world
		if w.ended: return
		if command.pending.is_empty() or command.pending==WAIT_FOR_LIFT: return
		var u = Psi.hero(w)
		if u == null: return
		var p := get_global_mouse_position()
		var level := Psi.rank(w,"Slam" if command.pending=="Throw" else command.pending)
		var start:=Psi.cast_position(u,p)
		if not start.is_finite():return
		if start!=u.position:
			draw_dashed_line(u.position,start,Color.SKY_BLUE,2,9)
		if command.pending=="Throw":
			for target in Psi.held(u):
				var lift:=Psi.lift_height(target)
				var last: Vector2 = target.position + RA2Art.art_dir(Vector2(0,-lift))
				for i in range(1,17):
					var t:=i/16.0
					var height:=lift*(1.0-t)+30.0*sin(PI*t)
					var next: Vector2 = target.position.lerp(p,t)+RA2Art.art_dir(Vector2(0,-height))
					draw_line(last,next,Psi.COLOR,2)
					last=next
			show_decal(command.pending,p,Psi.THROW_RADIUS)
		else:
			draw_line(start,p,Psi.COLOR,2)
			show_decal(command.pending,p,Psi.area_radius(command.pending,level))

func open() -> void:
	if world.ended: return
	pending = ""
	if not is_instance_valid(popup):
		popup = PopupPanel.new()
		popup.name = "YurikoMenu"
		add_child(popup)
	build()
	popup.popup_centered(pop_size())

func pop_size() -> Vector2i:
	var available := get_viewport().get_visible_rect().size
	return Vector2i(minf(580,available.x-16),minf(570,available.y-16))

func build() -> void:
	for child in popup.get_children():
		popup.remove_child(child)
		child.queue_free()
	powers.clear()
	var scroll := ScrollContainer.new()
	popup.add_child(scroll)
	content = VBoxContainer.new()
	content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content.add_theme_constant_override("separation",8)
	scroll.add_child(content)
	var heading := HBoxContainer.new()
	content.add_child(heading)
	portrait = TextureRect.new()
	portrait.texture = load(Psi.ART+Psi.PORTRAITS[Psi.skin(world)]+".png")
	portrait.expand_mode=TextureRect.EXPAND_IGNORE_SIZE
	portrait.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	portrait.custom_minimum_size=Vector2(62,62)
	heading.add_child(portrait)
	var title := UiKit.make_label("百合子 · 灵能天赋",22,Psi.COLOR)
	title.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	heading.add_child(title)
	var close := UiKit.make_button("关闭")
	close.pressed.connect(popup.hide)
	heading.add_child(close)
	outfit=OptionButton.new()
	outfit.name="YurikoOutfit"
	const Book=preload("res://scripts/units/yuriko_school.gd")
	for i in Psi.SKINS.size():
		outfit.add_item("换装 · %s（%s）"%[Psi.SKINS[i],Book.outfit_label(i)])
		outfit.set_item_disabled(i,not Book.outfit_unlocked(i))
	outfit.select(Psi.skin(world))
	outfit.item_selected.connect(_dress)
	content.add_child(outfit)
	var actions := HBoxContainer.new()
	content.add_child(actions)
	var summon := UiKit.make_button("召唤 · 免费")
	summon.name="Summon"
	summon.icon=load(Psi.ART+"FactionIconYuriko.png")
	summon.add_theme_constant_override("icon_max_width",22)
	summon.pressed.connect(_summon)
	actions.add_child(summon)
	var demo := UiKit.make_button("技能演示")
	demo.pressed.connect(_demo)
	actions.add_child(demo)
	notice=UiKit.make_label("",14,UiKit.COL_TEXT)
	notice.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	content.add_child(notice)
	var u = Psi.hero(world)
	if u != null: notice.text="选中百合子可使用已习得的灵能技能。"
	elif preload("res://scripts/expedition/rules.gd").active() and not preload("res://scripts/expedition/rules.gd").context().get("yuriko_recruited",false):
		var book=preload("res://scripts/units/yuriko_school.gd")
		notice.text=book.RETURN_HINT if book.recruited_before() else "与百合子重逢后，完成她的情报委托并获胜，即可在本轮远征召唤。"
		summon.disabled=true
	elif world.allied_state.get("yuriko_summoned",false): notice.text="本战区的召唤次数已用完。"
	else: notice.text="需要一座完工的己方兵营和畅通的出口。每场可召唤一次，支援 %d 秒。"%Psi.deployment_duration(world)
	summon.disabled=summon.disabled or u!=null or world.allied_state.get("yuriko_summoned",false)
	points=UiKit.make_label("",16,UiKit.COL_GOLD)
	content.add_child(points)
	var bar := HFlowContainer.new()
	content.add_child(bar)
	for key in ["burst","Lure","Shield","Slam"]:
		var label:String={"burst":"Q 灵能爆发","Lure":"W 心灵控制","Shield":"E 灵能护盾","Slam":"R 念力投掷"}[key]
		var b:=UiKit.make_button(label,14)
		b.pressed.connect(_power.bind(key))
		bar.add_child(b)
		powers[key]=b
	refresh()

func refresh() -> void:
	var state:=Psi.training(world)
	points.text="已习得 %d / 15　·　在主菜单「百合子手记」中分配灵能点" % state.learned.size()
	var u=Psi.hero(world)
	if u!=null and u.special.has("psi_support_left"):
		notice.text="百合子支援剩余 "+Psi.deployment_clock(u.special.psi_support_left)
	elif world.allied_state.get("yuriko_summoned",false):notice.text="本场召唤次数已用完。"
	for key in powers:
		var level:=1 if key=="burst" else Psi.rank(world,key)
		var action = "Throw" if key=="Slam" and u!=null and not Psi.held(u).is_empty() else key
		powers[key].disabled=u==null or level<=0 or not Psi.ready(u,action)

func _dress(index:int) -> void:
	Psi.dress(world,index)
	var equipped:=Psi.skin(world)
	outfit.select(equipped)
	portrait.texture=load(Psi.ART+Psi.PORTRAITS[equipped]+".png")
	if is_instance_valid(strip) and strip.visible:strip.refresh()

func _summon() -> void:
	if Psi.summon(world):
		popup.hide()
		Events.emit_message("百合子已从兵营出发。",Psi.COLOR)
	else: notice.text="召唤未成功，请检查己方兵营、出口和战场暂停状态。"

func _demo() -> void:
	var demo = preload("res://scripts/ui/yuriko_demo.gd").new()
	popup.add_child(demo)
	demo.play(Psi.skin(world))

func _power(key:String) -> void:
	var u=Psi.hero(world)
	if u==null: return
	pending=""
	if key=="burst":
		u.use_ability(UnitSkillLayout.index(u,0))
	elif key=="Shield":
		Psi.shield(u)
	else:
		pending="Throw" if key=="Slam" and not Psi.held(u).is_empty() else key
		Events.emit_message("左键选择落点，右键取消。" if pending=="Throw" else "左键选择灵能目标位置，右键取消。",Psi.COLOR)
	if is_instance_valid(popup):popup.hide()

func sync_slam_phase() -> void:
	if pending!=WAIT_FOR_LIFT and pending!="Throw":return
	var u=Psi.hero(world)
	if not AlliedAbilities.alive(u):
		pending=""
	elif Psi.held(u).is_empty():
		if pending=="Throw" or u.special.get("psi_order",{}).get("key","")!="Slam":pending=""
	elif pending==WAIT_FOR_LIFT:
		pending="Throw"
		Events.emit_message("目标已升空，左键选择落点。",Psi.COLOR)

func _input(event:InputEvent) -> void:
	if swallow_release and event is InputEventMouseButton and event.button_index==MOUSE_BUTTON_LEFT and not event.pressed:
		swallow_release=false
		get_viewport().set_input_as_handled()
		return
	if pending.is_empty(): return
	sync_slam_phase()
	if pending.is_empty(): return
	if not world.world_input_enabled():
		pending=""
		return
	var cancel_key = event is InputEventKey and event.pressed and event.keycode==KEY_ESCAPE
	var cancel_click = event is InputEventMouseButton and event.pressed and event.button_index==MOUSE_BUTTON_RIGHT
	if cancel_key or cancel_click:
		if pending==WAIT_FOR_LIFT:
			var u=Psi.hero(world)
			if u!=null:u.order_stop(false)
		pending=""
		get_viewport().set_input_as_handled()
	elif event is InputEventMouseButton and event.pressed:
		if event.button_index==MOUSE_BUTTON_LEFT and not world._pointer_over_ui():
			if pending!=WAIT_FOR_LIFT:
				choose_point(world.get_canvas_transform().affine_inverse()*event.position)
			swallow_release=true
		else: return
		get_viewport().set_input_as_handled()

func choose_point(point:Vector2) -> void:
	var u=Psi.hero(world)
	if u==null or not Psi.order_power(u,pending,point):
		Events.emit_message("该位置无法施放。",Psi.COLOR)
		if pending not in ["Slam","Throw"]:pending=""
	elif pending=="Slam":
		pending=WAIT_FOR_LIFT
		sync_slam_phase()
	else:
		pending=""

func _process(dt:float) -> void:
	if not is_instance_valid(world):return
	if not is_instance_valid(marker):
		marker=Marker.new()
		marker.command=self
		marker.z_index=50
		world.add_child(marker)
	if world.ended:
		if is_instance_valid(popup) and popup.visible: popup.hide()
		pending=""
	sync_slam_phase()
	if not pending.is_empty() or marker.get_meta("was_targeting",false):
		marker.queue_redraw()
		marker.set_meta("was_targeting",not pending.is_empty())
	elapsed+=dt
	if elapsed>.15:
		elapsed=0
		if is_instance_valid(strip) and strip.visible:strip.refresh()
		if is_instance_valid(popup) and popup.visible:refresh()
