extends "res://tests/special_mechanics_regression.gd"
const Old=preload("res://tests/apoc_before_ra3_tank_fx.gd")
const New=preload("res://scripts/units/ra3_tank_fx.gd")
var timings:Array=[]
var populations:Array=[]

func make_fx(old:bool,event:String):
	var fx=Old.new() if old else New.new()
	fx.world=battle;fx.position=Vector2(1200,1200)
	fx.texture_folder=New.ROOT_FX;fx.particle_bank=New.bank.particles
	battle.effects_root.add_child(fx);fx.set_process(false)
	for entry in New.Particle.child(New.bank.effects[event],"NuggetList").children:
		if entry.tag!="ParticleSystem":continue
		var data:Dictionary=New.bank.particles[entry.attrs.Particle]
		if data.attrs.get("Type","") in ["DRAWABLE","STREAK"]:continue
		if New.Particle.child(data,"Draw/Gpu").get("attrs",{}).get("GeometryType","")=="TWO_QUADS":continue
		if entry.attrs.get("OnlyIfOnWater","")=="true":continue
		var delay:=maxi(1,roundi(New.Particle.range_value(New.Particle.child(data,"BurstDelay"),1)))
		for start in range(0,int(data.attrs.get("SystemLifetime",1)),delay):
			fx.burst(entry.attrs.Particle,start+New.Particle.range_value(New.Particle.child(data,"InitialDelay")),0.7)
	fx._process(0)
	return fx

func materials(fx)->int:
	var unique:Dictionary={}
	for row in fx.rows:
		if not row.light:unique[row.sprite.material]=true
	return unique.size()

func equivalent(a,b)->bool:
	if a.rows.size()!=b.rows.size():return false
	for i in a.rows.size():
		var x:Dictionary=a.rows[i];var y:Dictionary=b.rows[i]
		for key in ["start","life","size","rate","damping","origin","velocity","drag","drift","angle","spin","alpha","color_scale","speed","gravity"]:
			if x.get(key)!=y.get(key):return false
		if x.sprite.texture!=y.sprite.texture or x.sprite.visible!=y.sprite.visible:return false
		if not x.sprite.position.is_equal_approx(y.sprite.position) or not is_equal_approx(x.sprite.rotation,y.sprite.rotation):return false
		if x.light:
			if not x.sprite.color.is_equal_approx(y.sprite.color) or not is_equal_approx(x.sprite.energy,y.sprite.energy):return false
		else:
			if not x.sprite.scale.is_equal_approx(y.sprite.scale) or not x.sprite.modulate.is_equal_approx(y.sprite.modulate):return false
			for param in ["columns","frames","frame","seconds"]:
				var p=x.sprite.material.get_shader_parameter(param);var q=y.sprite.material.get_shader_parameter(param)
				if p is float and q is float:
					if not is_equal_approx(p,q):return false
				elif p!=q:return false
	return true

func _ready():
	output_dir=OS.get_environment("IRON_TIDE_REPORT_DIR")
	if output_dir.is_empty() or not OS.get_user_data_dir().contains("CodexIronTideValidation"):get_tree().quit(2);return
	await get_tree().process_frame
	arena(MatchRules.EXTENDED)
	for event in [New.bank.cannon.fire,New.bank.cannon.hero_fire,New.bank.cannon.impacts[0],New.bank.cannon.impacts[1],"FX_SovietTankHit","FX_SovietTankHitCrit","FX_SovietTankHitCritS","FX_TeslaTrooperFire","FX_TeslaHit"]:
		seed(2713);var a=make_fx(true,event)
		seed(2713);var b=make_fx(false,event)
		check(equivalent(a,b),event+" original particle count and seeded parameters")
		populations.append({"event":event,"particles":a.rows.size(),"old_materials":materials(a),"new_materials":materials(b)})
		check(materials(b)<=materials(a),event+" shared materials bounded by original")
		for tick in 90:
			if a.rows.is_empty() or b.rows.is_empty():break
			a._process(1.0/60.0);a._process(1.0/60.0)
			b._process(1.0/60.0);b._process(1.0/60.0)
			check(equivalent(a,b),event+" 30Hz native motion/color/lifetime/animation "+str(tick))
		a.free();b.free()
	var pause_fx=make_fx(false,New.bank.cannon.fire)
	pause_fx._process(1.0/120.0);var prior:float=pause_fx.age
	battle.paused=true;pause_fx._process(1.0);battle.paused=false
	check(pause_fx.age==prior and is_equal_approx(pause_fx.visual_pending,1.0/120.0),"pause does not accumulate visual time")
	pause_fx._process(1.0/40.0)
	check(is_equal_approx(pause_fx.age,1.0),"accumulated substeps reach native frame without time loss")
	pause_fx.free()
	var center:Vector2=battle.get_global_transform_with_canvas().affine_inverse()*battle.get_viewport_rect().get_center()
	var before_nodes:int=battle.effects_root.get_child_count()
	New.emit_entries(battle,center,New.Particle.child(New.bank.effects[New.bank.cannon.fire],"NuggetList").children,0.0)
	var emitted=false
	for node in battle.effects_root.get_children().slice(before_nodes):
		if node is New:
			check(node.rows.size()==51 and materials(node)==3,"real default fire entry uses sharing without removing particles")
			emitted=true
	check(emitted,"visible default fire emit_entries constructed real adapter")
	for pass_index in 8:
		var row:Dictionary={}
		for old in ([true,false] if pass_index%2==0 else [false,true]):
			seed(871)
			var live:Array=[];var begin:=Time.get_ticks_usec()
			for i in 20:live.append(make_fx(old,New.bank.cannon.fire))
			row["old_spawn_us" if old else "new_spawn_us"]=Time.get_ticks_usec()-begin
			begin=Time.get_ticks_usec()
			for tick in 60:
				for fx in live:fx._process(1.0/60.0)
			row["old_update_us" if old else "new_update_us"]=Time.get_ticks_usec()-begin
			for fx in live:fx.free()
		timings.append(row)
	FileAccess.open(output_dir.path_join("result.json"),FileAccess.WRITE).store_string(JSON.stringify({"checks":checks,"failed":failed,"populations":populations,"timings":timings}))
	await finish()
	get_tree().quit(0 if failed==0 else 1)

