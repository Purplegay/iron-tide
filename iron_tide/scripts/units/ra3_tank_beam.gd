extends Node2D
## Endpoints follow the actual muzzle and target. Destroyed targets retain
## their last hit point for lightning already emitted by the two coils.
const FX=preload("res://scripts/units/ra3_tank_fx.gd")
const P=preload("res://scripts/units/ra3_gunship_impact.gd")
const LIGHTNING_MATERIAL=preload("res://shaders/ra3_tesla_streak.tres")
var battle:Battle
var source:WeakRef
var target:WeakRef
var muzzle_name:String
var spectrum:=false
var harpoon:=false
var coil_link:=false
var age:=0.0
var end_point:Vector2
var layers:Array[Dictionary]=[]
var tip_times:Dictionary={}

static func spawn(unit,victim,tractor:bool,link:bool=false):
	if DisplayServer.get_name()=="headless":return null
	var world=unit._battle_world()
	if not world.position_visible_to("ally",unit.position):return null
	var node=load("res://scripts/units/ra3_tank_beam.gd").new()
	node.battle=world;node.source=weakref(unit);node.target=weakref(victim);node.harpoon=tractor;node.coil_link=link
	node.spectrum=not tractor and not link and Effects.Looks.current(unit)=="spectrum"
	node.position=unit._weapon_muzzle();node.end_point=node.endpoint(victim)
	node.muzzle_name="FX_HARPOON" if tractor else "FX_WEAPON_%02d"%(int(unit.special.ra3_barrel)+1)
	world.effects_root.add_child(node);node.add_to_group("reaper_particles")
	node.build()
	node._process(0)
	return node

func build() -> void:
	if harpoon:
		for spec in FX.bank.lasers:
			var a:Dictionary=spec.attrs
			var line:=Line2D.new();add_child(line);line.width=float(a.LaserWidth)*1.5
			line.texture=load(FX.ROOT_FX+str(spec.maps[0]))
			var shader:=ShaderMaterial.new();shader.shader=preload("res://shaders/ra3_harpoon.gdshader")
			shader.set_shader_parameter("beam_map",load(FX.ROOT_FX+str(spec.maps[0])))
			shader.set_shader_parameter("cloud_map",load(FX.ROOT_FX+str(spec.maps[1])))
			shader.set_shader_parameter("emissive",Ra3BoneAnimation.vector(spec.emissive))
			shader.set_shader_parameter("tile",Vector2(float(a.Texture1_VTile),float(a.Texture2_VTile)))
			shader.set_shader_parameter("scroll",Vector2(float(a.Texture1_VScrollRate),float(a.Texture2_VScrollRate)))
			line.texture_mode=Line2D.LINE_TEXTURE_STRETCH;line.material=shader
			layers.append({"line":line})
	else:
		for entry in P.child(FX.bank.effects[FX.bank.tesla],"NuggetList").children:
			var data:Dictionary=FX.bank.particles[entry.attrs.Particle]
			var line:=Line2D.new();add_child(line)
			line.texture=Effects.Looks.SPECTRUM if spectrum else load(FX.ROOT_FX+str(data.attrs.ParticleTexture)+".png")
			line.texture_mode=Line2D.LINE_TEXTURE_STRETCH
			if not spectrum:line.material=LIGHTNING_MATERIAL
			line.width=P.range_value(P.child(data,"Size"),1)*1.5
			var waves:Array=[]
			for set_ in P.child(data,"Draw/Lightning").children:
				if set_.tag=="RandomSet":
					var begin:=Vector3(P.range_value(P.child(set_,"StartAmplitude")),P.range_value(P.child(set_,"StartFrequency")),P.range_value(P.child(set_,"StartPhase")))
					var change:=Vector3(P.range_value(P.child(set_,"EndAmplitudeChange")),P.range_value(P.child(set_,"EndFrequencyChange")),P.range_value(P.child(set_,"EndPhaseChange")))
					waves.append({"begin":begin,"change":change})
			var start:=P.range_value(P.child(data,"InitialDelay"))/30.0
			var life:=P.range_value(P.child(data,"Lifetime"))/30.0
			layers.append({"line":line,"data":data,"waves":waves,"start":start,"duration":life+(float(data.attrs.SystemLifetime)-1)/30.0,"scale":P.range_value(P.child(P.child(data,"Colors"),"ColorScale"),1)})

func _process(dt:float) -> void:
	if battle.paused:return
	var unit=source.get_ref();var victim=target.get_ref()
	if harpoon and (not AlliedAbilities.alive(unit) or not AlliedAbilities.alive(victim) or unit.special.get("harpoon_target")!=victim or not unit.special.get("soviet_mode",false)):
		queue_free();return
	if AlliedAbilities.alive(unit) and unit._ra3_model!=null:position=unit._ra3_model.bone_world(muzzle_name)
	if AlliedAbilities.alive(victim):end_point=endpoint(victim)
	visible=battle.position_visible_to("ally",position) and battle.position_visible_to("ally",end_point)
	if harpoon and AlliedAbilities.alive(unit) and AlliedAbilities.alive(victim):
		visible=visible and unit._weapon_aligned(victim)
	age+=dt
	rotation=Iso.eff_angle();scale=Iso.up()
	var end:=Iso.dir(end_point-position)
	var alive_layer:=false
	for row in layers:
		var line:Line2D=row.line
		if harpoon:
			line.points=PackedVector2Array([Vector2.ZERO,end])
			line.material.set_shader_parameter("age",age)
			alive_layer=true
			continue
		var t:float=age-row.start
		line.visible=t>=0 and t<row.duration
		alive_layer=alive_layer or t<row.duration
		if not line.visible:continue
		var color:=P.color_at(row.data,t/row.duration*100.0)
		line.default_color=(Color.WHITE if spectrum else color)*float(row.scale);line.default_color.a=1
		var waves:Array[Vector3]=[]
		var segments:=32
		for params in row.waves:
			var wave:Vector3=params.begin+params.change*t*30.0
			waves.append(wave)
			segments=maxi(segments,ceili(absf(wave.y)*4.0))
		var normal:=end.normalized().orthogonal()*minf(1,end.length()/300.0)
		var points:=PackedVector2Array()
		points.resize(segments+1)
		for i in segments+1:
			var u:=float(i)/segments
			var offset:=0.0
			for wave in waves:
				offset+=wave.x*sin(wave.y*u*TAU+wave.z)
			points[i]=end*u+normal*offset*sin(PI*u)
		line.points=points
	if not alive_layer:queue_free()
	if harpoon and visible and battle.effects_root.get_child_count()<128:
		var bursts:Array=[]
		for id in FX.bank.tips:
			if age<float(tip_times.get(id,0.0)):continue
			var data:Dictionary=FX.bank.particles[id]
			tip_times[id]=age+maxf(1.0,P.range_value(P.child(data,"BurstDelay"),1))/30.0
			bursts.append(FX.source_entry(id))
		if not bursts.is_empty():FX.emit_entries(battle,end_point,bursts,end.angle())

func endpoint(victim) -> Vector2:
	return preload("res://scripts/units/tesla_support.gd").tip(victim) if coil_link else FX.hit_point(victim)
