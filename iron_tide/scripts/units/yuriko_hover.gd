extends Node3D
const ART := "res://assets/ra3/yuriko/"
const FX = preload("res://shaders/yuriko_hover.gdshader")
var ring: MeshInstance3D
var updraft: MeshInstance3D
var time := 0.0
var ground: BackBufferCopy
var wake: CPUParticles2D

func make_layer(mesh: PrimitiveMesh, rising: bool) -> MeshInstance3D:
	var material := ShaderMaterial.new()
	material.shader = FX
	material.set_shader_parameter("rising", rising)
	var layer := MeshInstance3D.new()
	layer.mesh = mesh
	layer.material_override = material
	layer.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(layer)
	return layer

func _ready() -> void:
	var ground_plane := PlaneMesh.new()
	ground_plane.size = Vector2(20, 20)
	ring = make_layer(ground_plane, false)
	var veil := QuadMesh.new()
	veil.size = Vector2(17, 11)
	updraft = make_layer(veil, true)
	updraft.position.y = 5.0
	updraft.rotation_degrees.x = -30.0

func attach_distortion(u) -> void:
	if not is_instance_valid(u):return
	ground=BackBufferCopy.new()
	ground.name="YurikoGroundDistortion"
	ground.show_behind_parent=true
	ground.copy_mode=BackBufferCopy.COPY_MODE_RECT
	ground.rect=Rect2(-34,-34,68,68)
	u.add_child(ground)
	var ripple:=Polygon2D.new()
	ripple.polygon=PackedVector2Array([Vector2(-26,-26),Vector2(26,-26),Vector2(26,26),Vector2(-26,26)])
	ripple.uv=PackedVector2Array([Vector2.ZERO,Vector2.RIGHT,Vector2.ONE,Vector2.DOWN])
	var mat:=ShaderMaterial.new()
	mat.shader=preload("res://shaders/yuriko_hover_distortion.gdshader")
	mat.set_shader_parameter("normal_map",load(ART+"FXSphereNRM.png"))
	mat.set_shader_parameter("haze",load(ART+"FX_DebrisBlur01.png"))
	ripple.material=mat
	ground.add_child(ripple)
	# The terrain emitter lives in the battle canvas so old particles stay where they were born.
	wake=CPUParticles2D.new()
	wake.name="YurikoMovementWake"
	wake.emitting=false
	wake.local_coords=false
	wake.show_behind_parent=true
	wake.amount=10
	wake.lifetime=0.34
	wake.randomness=0.25
	wake.texture=preload("res://assets/ra3/yuriko/FXPsyonicMind.png")
	wake.emission_shape=CPUParticles2D.EMISSION_SHAPE_SPHERE
	wake.emission_sphere_radius=3.0
	wake.spread=180.0
	wake.gravity=Vector2.ZERO
	wake.initial_velocity_min=3.0
	wake.initial_velocity_max=10.0
	wake.angle_max=360.0
	wake.angular_velocity_min=-85.0
	wake.angular_velocity_max=85.0
	wake.scale_amount_min=0.14
	wake.scale_amount_max=0.20
	wake.anim_offset_max=1.0
	var fade:=Gradient.new()
	fade.offsets=PackedFloat32Array([0.0,0.12,1.0])
	fade.colors=PackedColorArray([Color.TRANSPARENT,Color.WHITE,Color.TRANSPARENT])
	wake.color_ramp=fade
	var ink:=ShaderMaterial.new()
	ink.shader=preload("res://shaders/yuriko_movement_wake.gdshader")
	wake.material=ink
	u.add_child(wake)

func update_movement(moving:bool, grounded:bool, color:Color) -> void:
	if wake==null:return
	wake.visible=grounded
	wake.emitting=grounded and moving
	wake.self_modulate=color

func advance(dt:float, color:Color, active:bool) -> void:
	visible=active
	if ground!=null: ground.visible=active
	if not active:return
	time=fmod(time+dt,600.0)
	for layer: MeshInstance3D in [ring, updraft]:
		layer.material_override.set_shader_parameter("tint", color)
		layer.material_override.set_shader_parameter("age", time)
	if ground!=null: ground.get_child(0).material.set_shader_parameter("clock",time)
