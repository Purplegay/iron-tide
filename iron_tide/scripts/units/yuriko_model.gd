extends SubViewport
## Both native Uprising rigs use their own ScriptedModelDraw clips in battle and the skill viewer.
const Book = preload("res://scripts/units/yuriko_school.gd")
const MODEL_FILE := "JapanYurikoTech1.glb"
const SCHOOL_FILE := "JUCommandoTech1.glb"
const Psi = preload("res://scripts/units/yuriko.gd")
static var hospital_states: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(Psi.ART+"model_states.json"))
static var school_states: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(Psi.ART+"school_states.json"))
var states: Dictionary
var outfit := -1
var journal_head := false
var studio: Node3D
var hover_fx
var active_clip := ""
const FRAME_WIDTH := 102.0
const MIN_PIXELS := 384
const Density = preload("res://scripts/units/ra3_fx_resolution.gd")
var body: Node3D
var head_bone: int
var rig: Skeleton3D
var animator: AnimationPlayer
var shield: MeshInstance3D
var action := ""
var requested := ""
var elapsed := 0.0

func _ready() -> void:
	size = Vector2i(MIN_PIXELS,MIN_PIXELS)
	msaa_3d = Viewport.MSAA_4X
	transparent_bg = true
	own_world_3d = true
	render_target_update_mode = SubViewport.UPDATE_WHEN_VISIBLE
	studio = Node3D.new()
	add_child(studio)
	hover_fx=preload("res://scripts/units/yuriko_hover.gd").new()
	studio.add_child(hover_fx)
	preload("res://scripts/units/ra3_lighting.gd").install(studio)
	var camera := Camera3D.new()
	studio.add_child(camera)
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = 68
	camera.position = Vector3(0,59,86.60254)
	camera.rotation_degrees.x = -30
	set_skin(0)

func set_skin(index:int) -> void:
	var use_journal:=index==Book.WEDDING_OUTFIT or Book.journal_head_equipped()
	if index==outfit and journal_head==use_journal and body!=null: return
	var previous_turn:=body.rotation.y if is_instance_valid(body) else 0.0
	if body!=null: body.free()
	outfit=clampi(index,0,Psi.SKINS.size()-1)
	states=hospital_states if outfit==0 else school_states.duplicate()
	if outfit==1:states.erase("USER_7")
	if outfit in [2,Book.WEDDING_OUTFIT]:
		for chapter_two_state in ["TRANS_boredToSlam","REACT_5","TRANS_slamToBored"]:states.erase(chapter_two_state)
	journal_head=use_journal
	var directory:String=Psi.ART if journal_head else Psi.ART+"classic/"
	var scene:PackedScene=load(directory+(MODEL_FILE if outfit==0 else SCHOOL_FILE))
	body=scene.instantiate()
	body.rotation.y=previous_turn
	studio.add_child(body)
	rig = body.find_children("*","Skeleton3D",true,false)[0]
	if outfit==Book.WEDDING_OUTFIT:bind_wedding_outfit()
	head_bone=rig.find_bone("pivot_560dc963")
	animator = body.find_children("*","AnimationPlayer",true,false)[0]
	animator.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
	shield = body.find_child("YurikoShield",true,false)
	var shield_file:="FXYURIKOSHIELD" if outfit==0 else "FXYURIKOSHIELDUPGRADE"
	var source:Dictionary=JSON.parse_string(FileAccess.get_file_as_string(Psi.ART+shield_file+".json"))
	shield.material_override=preload("res://scripts/units/yuriko_power_fx.gd").shell_material(source)
	shield.material_override.set_shader_parameter("opacity",1.15)
	shield.visible = false
	requested=""
	action=""
	pose("STATE_bored",0,false)

func bind_wedding_outfit() -> void:
	var garment=preload("res://assets/ra3/yuriko/wedding/BridalOutfit.glb").instantiate()
	var original:MeshInstance3D=body.find_child("YurikoBody",true,false)
	var dress:MeshInstance3D=garment.find_child("BridalOutfit",true,false)
	original.mesh=dress.mesh
	original.skin=dress.skin
	garment.free()

func entrance() -> String:
	return "COMING_OUT_OF_FACTORY" if outfit==1 else "USER_7"

func resolve(state:String) -> String:
	if outfit>0:
		match state:
			"USER_7": return entrance()
			"USER_8": return "PACKING"
			"TRANS_boredToAttention": return "TRANS_IdleToSelected"
			"TRANS_attentionToBored": return "TRANS_SelectedToIdle"
	return state

func duration(state: String) -> float:
	var row: Dictionary = states[state]
	return float(row.get("duration",animator.get_animation(active_clip if action==state and not active_clip.is_empty() else row.clip).length))

func begin(state: String) -> void:
	action = state
	elapsed = 0.0
	var row: Dictionary = states[state]
	active_clip=row.clip
	if row.has("variants"):
		var weights:=PackedFloat32Array()
		for variant in row.variants: weights.append(variant.weight)
		active_clip=row.variants[RandomNumberGenerator.new().rand_weighted(weights)].clip
	var clip: Animation = animator.get_animation(active_clip)
	animator.play(active_clip,float(row.blend_frames)/30.0,clip.length/duration(state))
	animator.seek(0,true)

func transition(previous: String, next: String) -> String:
	if next=="REACT_5": return "TRANS_boredToSlam"
	if previous=="REACT_5" and next in ["SELECTED","STATE_bored"]: return "TRANS_slamToBored"
	if previous=="STATE_bored" and next=="SELECTED": return "TRANS_boredToAttention"
	if previous=="SELECTED" and next=="STATE_bored": return "TRANS_attentionToBored"
	return next

func pose(state: String, dt: float, transitions := true, force_loop := false) -> void:
	if shield.visible:shield.material_override.set_shader_parameter("age",hover_fx.time)
	state=resolve(state)
	if not states.has(state):state="STATE_bored"
	if state != requested:
		var first := transition(requested,state) if transitions else state
		requested = state
		begin(resolve(first))
	var length := duration(action)
	elapsed += dt
	animator.advance(dt)
	if elapsed >= length:
		if action != requested: begin(requested)
		elif force_loop or states[action].mode == "LOOP" or states[action].restart:
			var remainder := fmod(elapsed,length)
			begin(action)
			animator.advance(remainder)
			elapsed = remainder

func actor_state(u) -> String:
	if u._dead: return "DYING SPLATTED" if u._crush_death else "DYING"
	if outfit>0 and u.special.has("para_height"):return "PARACHUTING"
	if u.special.has("psi_flight") or u.special.has("psi_air_pull") or u.special.has("para_height"): return "STUNNED_FLAILING"
	if u._stun_timer>0 or u.special.has("psi_holder"): return "STUNNED"
	if outfit==0 and (requested in ["STUNNED","STUNNED_FLAILING"] or (requested=="STUNNED_STANDING_UP" and elapsed<duration(requested))): return "STUNNED_STANDING_UP"
	if states.has("REACT_5") and u.special.has("psi_held") and not preload("res://scripts/units/yuriko.gd").held(u).is_empty(): return "REACT_5"
	if u.special.has("psi_cast_anim"): return "USER_8"
	if u.special.has("psi_fire_anim"): return u.special.get("psi_fire_react","FIRING_A")
	if u.velocity.length_squared()>8: return "MOVING"
	if u.special.has("psi_intro_anim"): return "USER_7"
	return "SELECTED" if u.selected else "STATE_bored"

func blast_ray_delay() -> float:
	var state:Dictionary=states.PACKING
	var clip:Animation=animator.get_animation(state.clip)
	return (28.0/30.0)*duration("PACKING")/clip.length

func head_offset() -> Vector2:
	var p:=body.transform*rig.transform*rig.get_bone_global_pose(head_bone).origin
	return Vector2(p.x,p.z*.5-p.y*sqrt(.75))*1.5

func fit_pixels(screen_width: float) -> void:
	# Two 3D samples per display pixel on each axis, including window stretch.
	var side:=clampi(ceili(screen_width*2.0/128.0)*128,MIN_PIXELS,1536)
	if size.x!=side: size=Vector2i(side,side)

func sync_actor(u, dt: float) -> void:
	if u.is_inside_tree() and u.embarked_in==null and u.is_visible_in_tree():
		fit_pixels(FRAME_WIDTH*Density.pixel_density(u))
	var equipped:=int(u.special.get("yuriko_skin",0))
	if equipped!=outfit:
		equipped=preload("res://scripts/units/yuriko_school.gd").usable_outfit(equipped)
		u.special.yuriko_skin=equipped
		set_skin(equipped)
	var tint:Color=Psi.COLORS[outfit] if u.selected else Color(.51,.51,.984)
	var active:bool=not u._dead and u.embarked_in==null
	hover_fx.advance(dt,tint,active)
	shield.visible = not u._dead and u.special.has("psi_shield")
	var state := actor_state(u)
	hover_fx.update_movement(state=="MOVING",active and not u.special.has("para_height") and not u.special.has("psi_flight") and not u.special.has("psi_holder") and not u.special.has("psi_air_pull"),tint)
	if state not in ["USER_7","SELECTED","STATE_bored"]: u.special.erase("psi_intro_anim")
	body.rotation.y = Iso.eff_angle()-(u.aim_dir.angle() if state.begins_with("FIRING_A") else u.hull_angle)
	pose(state,dt)
