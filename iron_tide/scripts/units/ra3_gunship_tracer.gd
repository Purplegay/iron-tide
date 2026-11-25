extends Node2D
## Front TracerModelDraw is visual only; hit timing stays in the weapon payload.
const Impact=preload("res://scripts/units/ra3_gunship_impact.gd")
static var rules: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(Impact.ROOT+"gunship_weapons.json"))
var world: Battle
var texture: Texture2D
var streaks: Array[Dictionary]=[]
var age:=0.0
var width:=12.0
var lifetime:=35.0/30.0
var heroic:=false
var head_color:=Color.WHITE
var tail_color:=Color.WHITE
var hit_fx:=""

static func spawn(actor, point: Vector2) -> void:
	if DisplayServer.get_name()=="headless":return
	var result=load("res://scripts/units/ra3_gunship_tracer.gd").new()
	result.world=actor._battle_world();result.position=actor._weapon_muzzle();result.heroic=actor.veteran_level>=3
	var live: Array=result.world.get_tree().get_nodes_in_group("ra3_gunship_tracers").filter(func(n):return result.world.is_ancestor_of(n))
	if live.size()>=64:live[0].free()
	result.world.add_child(result);result.add_to_group("ra3_gunship_tracers")
	result.setup(point,actor)

func setup(point: Vector2, actor=null) -> void:
	var definition: Dictionary=rules.tracers[1 if heroic else 0]
	var data: Dictionary=definition.attrs
	texture=load(Impact.ROOT+str(data.Texture)+".png")
	width=float(data.Width)*1.5;lifetime=float(data.FrameLifeTime)/30.0
	for pair in [["HeadColor","head_color"],["TailColor","tail_color"]]:
		var color: Dictionary=Impact.child(definition,pair[0]).attrs
		set(pair[1],Color(float(color.r),float(color.g),float(color.b),float(color.a)))
	hit_fx=str(data.get("TracerHitFx",""))
	var mat:=CanvasItemMaterial.new();mat.blend_mode=CanvasItemMaterial.BLEND_MODE_ADD;material=mat
	# Fractional density must survive shots. Rounding each 0.1s burst always made 2.
	var credit:=float(actor.get_meta("ra3_tracer_credit",0.0)) if actor!=null else 0.0
	for frame in 3:
		credit+=randf_range(float(data.MinTracersPerFrame),float(data.MaxTracersPerFrame))
		while credit>=1.0:
			credit-=1.0
			var spread:=deg_to_rad(randf_range(-1,1)*float(data.SpreadAngle))
			var offset: Vector2=(point-position).rotated(spread)
			var finish:=Iso.dir(offset)
			streaks.append({"start":frame/30.0,"end":finish,"point":position+offset,"hit":false,
				"speed":randf_range(float(data.MinSpeed),float(data.MaxSpeed))*30.0*1.5,
				"length":randf_range(float(data.MinLength),float(data.MaxLength))*1.5})
	if actor!=null:actor.set_meta("ra3_tracer_credit",credit)

func _process(delta: float) -> void:
	if is_instance_valid(world) and world.paused:return
	age+=delta
	if age>=lifetime:queue_free();return
	for streak in streaks:
		if not streak.hit and (age-float(streak.start))*float(streak.speed)>=(streak.end as Vector2).length():
			streak.hit=true
			if hit_fx=="FX_BulletHitSovietVet":
				load("res://scripts/units/ra3_gunship_bullet_hit.gd").spawn(world,streak.point,streak.point-position,true)
	visible=world.position_visible_to("ally",global_position)
	z_index=DepthLayers.entity_z(global_position,world.map_size)+2
	queue_redraw()

func _draw() -> void:
	Iso.begin(self)
	for streak: Dictionary in streaks:
		var t:=age-float(streak.start)
		if t<0:continue
		var distance: float=streak.end.length()
		var head: float=t*streak.speed
		if head>distance+float(streak.length):continue
		var direction: Vector2=streak.end.normalized()
		var a:=direction*maxf(0,head-float(streak.length));var b:=direction*minf(distance,head)
		var side:=direction.orthogonal()*width*0.5
		draw_polygon(PackedVector2Array([a-side,b-side,b+side,a+side]),PackedColorArray([tail_color,head_color,head_color,tail_color]),PackedVector2Array([Vector2(0,0),Vector2(1,0),Vector2(1,1),Vector2(0,1)]),texture)
