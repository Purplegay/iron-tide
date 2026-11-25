extends "res://scripts/units/ra3_reaper_particles.gd"
## Tank-specific retail FXLists. Billboard, drawable and targeted streak entries
## use their own render paths so a lightning strip is never a point sprite.
const ROOT_FX="res://assets/ra3/soviet/tank_fx/"
const NativeImpact=preload("res://scripts/units/ra3_gunship_impact.gd")
static var additive_distort:Shader
static var bank:Dictionary=JSON.parse_string(FileAccess.get_file_as_string(ROOT_FX+"source.json"))
var emitter_materials:Dictionary={}
var visual_pending:=0.0

func _init() -> void:
	share_material_updates=true

# Only this effect's identical emitter/start pairs share uniforms. Color,
# motion, size and lifetime remain per particle; effects never share clocks.
func emit(data:Dictionary,start:float,shared_material:ShaderMaterial=null) -> void:
	var materials:Dictionary=emitter_materials.get_or_add(str(data.attrs.id),{})
	super.emit(data,start,materials.get(start,shared_material))
	var row:Dictionary=rows.back()
	if not row.light:materials[start]=row.sprite.material

static func hit_point(target) -> Vector2:
	return target.art_center() if target.has_method("art_center") else Effects.hit_position(target)

static func impact_id(target,heading:float,tesla:bool) -> String:
	var group:="FactionStructureDamageFX" if target is Building else "VehicleDamageFX"
	if target is Unit:
		if AlliedAbilities.infantry(target):group="InfantryDamageFX"
		elif target.is_air_target():group="AircraftDamageFX"
	var rules:Dictionary=bank.damage[group]["SOVIET_TESLA" if tesla else "SOVIET_CANNON"]
	if rules.has("RearFX") and target is Unit:
		var angle:=absf(angle_difference(target.hull_angle,heading+PI))
		if angle>3.0*PI/4:return rules.RearFX
		if angle>PI/4:return rules.SideFX
	return rules.MajorFX

static func event(battle:Battle,point:Vector2,id:String,heading:float=0.0) -> void:
	if DisplayServer.get_name()=="headless" or not battle.position_visible_to("ally",point):return
	emit_entries(battle,point,Particle.child(bank.effects[id],"NuggetList").children,heading)

static func emit_entries(battle:Battle,point:Vector2,entries:Array,heading:float,single_burst:=false) -> void:
	if not battle.position_visible_to("ally",point):return
	if not battle.get_viewport_rect().grow(160).has_point(battle.get_global_transform_with_canvas()*point):return
	var fx=load("res://scripts/units/ra3_tank_fx.gd").new()
	fx.world=battle;fx.position=point;fx.texture_folder=ROOT_FX;fx.particle_bank=bank.particles
	battle.effects_root.add_child(fx);fx.add_to_group("reaper_particles")
	var drawable:Array=[]
	for entry in entries:
		var attrs:Dictionary=entry.attrs
		match str(entry.tag):
			"Sound":Ra2Sfx.play("RA3_TANK_"+str(attrs.Value),point)
			"TerrainScorch":
				if battle.in_water_world(point):continue
				var marks=battle.get_node_or_null("__decals")
				if marks==null:
					marks=DecalLayer.new();marks.name="__decals";marks.z_as_relative=false;marks.z_index=DepthLayers.DECAL;battle.add_child(marks)
				marks.add_scorch(point,float(attrs.Radius)*1.5,1.0)
			"ParticleSystem":
				if attrs.get("OnlyIfOnWater","")=="true" and not battle.in_water_world(point):continue
				var data:Dictionary=bank.particles[attrs.Particle]
				if attrs.Particle=="Sov_Apoc_TB_Grind":
					var sparks:=preload("res://scripts/units/ra3_apocalypse_grind.gd").new()
					sparks.setup(battle,point,heading-Iso.eff_angle(),data,preload("res://assets/ra3/soviet/tank_fx/FXWhiteTest3.png"))
					continue
				if Particle.child(data,"Draw/Gpu").get("attrs",{}).get("GeometryType","")=="TWO_QUADS":
					preload("res://scripts/units/ra3_tank_muzzle.gd").new().setup(battle,point,heading,data,ROOT_FX)
					continue
				if data.attrs.get("Type","")=="DRAWABLE":
					drawable.append(entry)
					continue
				if data.attrs.get("Type","")=="STREAK":continue
				var delay:=maxi(1,roundi(Particle.range_value(Particle.child(data,"BurstDelay"),1)))
				# A running attachment supplies its own emission clock. Only an event starts the whole system.
				var frames:=1 if single_burst else int(data.attrs.get("SystemLifetime",1))
				for start in range(0,frames,delay):
					fx.burst(attrs.Particle,start+Particle.range_value(Particle.child(data,"InitialDelay")),heading-Iso.eff_angle() if attrs.get("OrientToObject","")=="true" else 0.0)
	if not drawable.is_empty():
		var visual=NativeImpact.new()
		visual.world=battle;visual.position=point;visual.media_folder=ROOT_FX
		battle.add_child(visual);visual.add_to_group("ra3_gunship_impacts")
		visual._build(bank,drawable)
	fx._process(0)

static func source_entry(id:String) -> Dictionary:
	return {"tag":"ParticleSystem","attrs":{"Particle":id,"OrientToObject":"true"}}

func burst(id:String,start:float,heading:float=0.0) -> void:
	var first:=rows.size()
	super.burst(id,start,heading)
	var data:Dictionary=particle_bank[id]
	var gpu:Dictionary=Particle.child(data,"Draw/Gpu").get("attrs",{})
	var volume:=Particle.child(data,"Volume/Line")
	var cylinder:=Particle.child(data,"Volume/Cylinder/Offset")
	for i in range(first,rows.size()):
		var row:Dictionary=rows[i]
		if gpu.get("Shader","")=="GpuParticleDistort.fx":
			row.distorted=true
			if not row.sprite.material.has_meta("tank_distortion_configured"):
				row.sprite.material.set_meta("tank_distortion_configured",true)
				var shader:=preload("res://shaders/ra3_tank_particle_distort.gdshader")
				if data.attrs.get("Shader","")!="ALPHA":
					if additive_distort==null:
						additive_distort=Shader.new()
						additive_distort.code=shader.code.replace("render_mode unshaded;","render_mode unshaded, blend_add;")
					shader=additive_distort
				row.sprite.material.shader=shader
				row.sprite.material.set_shader_parameter("detail_map",load(ROOT_FX+str(gpu.DetailTexture)+".png"))
				row.sprite.material.set_shader_parameter("displacement",Vector4(float(gpu.MiscValue1),float(gpu.MiscValue2),float(gpu.MiscValue3),float(gpu.MiscValue4)))
				row.sprite.material.set_shader_parameter("columns",float(gpu.get("FramesPerRow",1)))
				row.sprite.material.set_shader_parameter("frames",float(gpu.get("TotalFrames",1)))
		var anchor:=Vector3.ZERO
		if not volume.is_empty():
			anchor=_vector(Particle.child(volume,"StartPoint")).lerp(_vector(Particle.child(volume,"EndPoint")),randf())
		elif not cylinder.is_empty():anchor=_vector(cylinder)
		row.origin+=anchor.rotated(Vector3.UP,-heading)
		row.gravity=float(Particle.child(data,"Physics/Default").get("attrs",{}).get("Gravity",0))
	var trail:Dictionary=Particle.child(data,"Draw/Trail")
	if trail.is_empty():return
	for i in range(first,rows.size()):
		var row:Dictionary=rows[i]
		var strip:=Line2D.new()
		strip.top_level=true
		strip.texture=row.sprite.texture
		strip.texture_mode=Line2D.LINE_TEXTURE_STRETCH
		var mat:=CanvasItemMaterial.new();mat.blend_mode=CanvasItemMaterial.BLEND_MODE_ADD
		strip.material=mat;row.sprite.add_child(strip)
		row.trail=strip;row.trail_life=float(trail.attrs.TrailLife)
		row.sprite.self_modulate.a=0

func _process(delta:float) -> void:
	if delta>0:
		if world.paused:return
		visual_pending+=delta
		if visual_pending+0.0000001<1.0/30.0:return
		delta=visual_pending
		visual_pending=0.0
	super._process(delta)
	var updated_materials:Dictionary={}
	for row in rows:
		if row.get("distorted",false) and not updated_materials.has(row.sprite.material):
			row.sprite.material.set_shader_parameter("seconds",maxf(0,age-row.start)/30)
			updated_materials[row.sprite.material]=true
		if not row.has("trail"):continue
		var t:=maxf(0.0,age-float(row.start))
		var tail:=maxf(0,t-float(row.trail_life))
		var motion:Vector3=row.velocity*(Particle.integral(t,row.drag)-Particle.integral(tail,row.drag))+row.drift*(t-tail)
		var head:Vector2=row.sprite.position
		var line:Line2D=row.trail
		line.modulate=row.sprite.modulate
		line.global_transform=global_transform
		line.visible=visible and row.sprite.visible
		line.points=PackedVector2Array([head-Vector2(motion.x,motion.z*0.5-motion.y*sqrt(0.75))*1.5,head])
		line.width=maxf(0.1,float(row.size)*1.5)

static func _vector(node:Dictionary) -> Vector3:
	var a:Dictionary=node.get("attrs",{})
	return Vector3(float(a.get("x",0)),float(a.get("z",0)),-float(a.get("y",0)))
