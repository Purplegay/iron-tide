extends "res://tests/base_recovery_regression.gd"
const Demo=preload("res://scripts/ui/expansion_2_demo.gd")

func _ready() -> void:
	output_dir=OS.get_environment("IRON_TIDE_REPORT_DIR")
	if output_dir.is_empty() or not OS.get_user_data_dir().contains("CodexIronTideValidation") or DisplayServer.get_name()=="headless":
		get_tree().quit(2);return
	await get_tree().process_frame
	MetaProgress.reset_save()
	BattleRequest.configure_skirmish(MatchRules.EXTENDED,{"map_size":2400})
	aircraft_samples()
	cross_samples()
	hunt_samples()
	host_samples()
	armor_samples()
	shore_samples()
	reserve_samples()
	naval_samples()
	naval_talent_samples()
	soviet_samples()
	ifv_samples()
	pounce_crossfire_samples()
	tractor_samples()
	seal_samples()
	archive_samples()
	burning_samples()
	air_observation_samples()
	rotation_samples()
	evacuation_samples()
	convoy_samples()
	mirage_samples()
	pressure_samples()
	observer_samples()
	infantry_w_samples()
	calibration_samples()
	launcher_samples()
	infantry_motion_samples()
	prism_guard_samples()
	ranging_samples()
	shard_samples()
	var stage=preload("res://scripts/ui/faction_card_stage.gd").new()
	stage.size=Vector2(460,200);add_child(stage);stage.set_process(false)
	for card:Dictionary in GameData.raw_docs["progression_expansion_2.json"].skills:
		for level in 4:
			stage.configure(card.id,0,"",level);stage.playing=false
			var times:Array=[0.1,0.65,1.25,2.5,6.5]
			if card.id=="ps_mirage_gap":times=[.1,.99,1.,1.5,2.,2.5,2.99,3.,3.5,5.,5.99,6.,6.5,11.99,12.,12.99,13.,13.5,14.99,15.,15.9,16.1,17.,17.5,21.9,22.1,23.,23.5,27.9,28.1]
			if card.id=="ps_ballistic_archive":
				times=[]
				for part in 4:
					for clock in [.1,.2,.59,.6,.85,.99,1.,1.19,1.21,1.99,2.,2.99,3.,4.,5.99,6.,6.39,6.4,6.66,8.99,9.,9.49,9.5,9.9,10.2,11.9]:times.append(part*12+clock)
				times.append(48.1)
			if card.id=="ap_tractor_warhead":
				times=[]
				for part in 5:
					for clock in [.1,.99,1.01,2.49,2.51,3.99,4.,4.5,5.,5.99,6.,6.24,6.26,6.49,6.51,9.49,9.51,9.9]:times.append(part*10+clock)
				times.append(50.1)
			if card.id=="ps_last_calibration":times=aircraft_times()
			if card.id=="ap_prism_cross":times=[.1,.59,.6,.83,.85,1.05,1.19,1.2,1.43,1.45,2.0]
			if card.id=="ap_overload_seal":
				times=[]
				for part in 4:
					for clock in [.1,.49,.5,.75,.99,1.,1.12,1.3,1.5,2.,2.1,3.19,3.2,3.43,4.3,4.49+level,4.5+level,9.9]:times.append(part*10+clock)
				times.append(40.1)
			if card.id=="ps_burning_payload":
				times=[]
				for part in 3:
					for clock in [.1,.54,.99,1.,1.99,2.,2.99,3.,3.3,3.49,3.5,3.6,3.89,3.9,4.,4.39,4.4,4.9,5.,5.4,5.5,5.9,6.,6.4,6.9,7.5,7.99,8.,8.2,9.9]:times.append(part*10+clock)
				times.append(30.1)
			if card.id=="ps_shore_reserve":times=[.1,1.99,2.01,2+float(card.values.cloak[level])-.01,2+float(card.values.cloak[level])+.01,2+float(card.values.speed_time[level])+.01,6.01,8.1,10.01,10.49,10.51,10+float(card.values.speed_time[level])+.01,16.1]
			if card.id=="ps_evacuation_escort":times=[.1,.6,.99,1.,1.6,1.99,2.,2.6,3.,3.9,3.99,4.,6.99,7.,26.99,27.,27.99,28.,28.99,29.,30.99,31.,35.9,36.1,36.7,36.99,37.,43.9,44.1]
			if card.id in ["ap_anchor_pin","ap_battle_breather"]:
				times=[]
				var span:=6. if card.id=="ap_anchor_pin" else 8.
				for part in (7 if card.id=="ap_anchor_pin" else 3):
					for clock in [.1,.2,.65,.67,.799,.801,.99,1.001,1.101,1.199,1.201,1.259,1.261,1.459,1.461,2.001,2.99,3.001,3.201,3.99,4.001,4.101,4.201,4.459,4.461,4.661,5.201,5.9]:times.append(part*span+clock)
				times.append(Demo.duration(card.id)+.1)
			if card.id=="ap_observer_line":
				times=[]
				for part in 3:
					for clock in [.1,.99,1.001,2.199,2.201,2.359,2.361,2.999,3.001,4.999,5.001,6.999,7.001,7.9]:times.append(part*8+clock)
				times.append(24.1)
			if card.id=="ps_impact_calibration":
				times=[]
				for part in 4:
					for clock in [.1,.69,.71,.99,1.001,1.701,1.99,2.001,2.99,3.001,3.201,3.4,3.8,3.99,4.001,4.99,5.001,5.201,5.99,6.001,6.201,6.99,7.001,7.9]:times.append(part*8+clock)
				times.append(32.1)
			if card.id=="ps_convoy_repair":
				times=[.1,2.99,3.,4.,5.99,6.,8.99,9.,20.99,21.,22.,23.99,56.1]
				for part in 4:
					for clock in [.1,1.99,2.,2.99,3.,3.6,3.8,3.91,3.99,4.,4.99,5.,5.99,6.,7.9]:times.append(24+part*8+clock)
			if card.id=="ps_module_shell":times=[.1,.99,1.,2.99,3.,5.99,6.,9.99,10.,11.99,12.,13.,30.9,31.,40.49,40.5,40.99,41.,43.9,44.1]
			if card.id=="ps_low_observation":times=air_observation_times()
			if card.id=="ps_sea_air_crossfire":times=pounce_crossfire_times(card.id,level)
			if card.id=="ps_depth_pressure":
				times=[.1,.99,1.001,2.999,3.001,3.999,4.001,5.999,6.001,6.399,6.401,6.999,7.001,8.999,9.001,10.001,12.001,18.999,19.001,23.999,24.001,28.999,29.001,52.1]
				for clock in [.1,1.001,3.001,3.499,3.501,3.901,6.499,6.501,6.901,10.499,10.501,11.9]:times.append(30+clock)
				for clock in [.1,3.999,4.001,5.599,5.601,5.999,6.001,6.599,6.601,6.999,7.001,8.001,8.401,9.001,9.9]:times.append(42+clock)
			if card.id=="ps_anchor_armor":times=armor_times(level)
			if card.id=="ps_polar_link":times=soviet_times(card.id)
			if card.id in ["ap_escort_water","ap_gun_ballast"]:times=[.1,.29,.31,1.01,1.5,1.99,2.01,2.51,3.51,3.99,4.,4.01,6.01,7.99,8.1]
			if card.id=="ap_gun_ballast":
				for launch:float in Demo.sample(card.id,level,0).boosted:
					if launch<8:times.append(launch-.001);times.append(launch+.001)
			if card.id=="ap_flak_fan":times=soviet_times(card.id)
			if card.id=="ap_lure_pounce":times=pounce_crossfire_times(card.id,level)
			for clock:float in times:
				stage.elapsed=clock;stage.sync_caster();stage.queue_redraw()
				await get_tree().process_frame
				await RenderingServer.frame_post_draw
				check(stage.caster_model.actor!=null and not stage.caster_model.texture.get_size().is_zero_approx(),"GPU card frame "+card.id+" rank "+str(level)+" time "+str(clock))
				if card.id in ["ap_anchor_pin","ap_battle_breather"]:
					var infantry_w:=Demo.sample(card.id,level,clock)
					check(stage.caster_model.actor.is_deployed()==infantry_w.deployed and (stage.caster_model.actor.velocity.length()>0)==infantry_w.moving,"infantry W preview keeps or changes posture and walking only at scripted node")
				if card.id=="ps_depth_pressure":
					var pressure:=Demo.sample(card.id,level,clock)
					check((stage.caster_model.actor.velocity.length()>0)==pressure.moving and NavalContact.submerged(stage.caster_model.actor)==(pressure.surface_left<=0),"pressure model movement and native firing surface remain independent from shield")
				if card.id=="ap_observer_line":check((stage.caster_model.actor.velocity.length()>0)==Demo.sample(card.id,level,clock).moving,"observer model walks only during actual movement phase")
				if card.id=="ps_impact_calibration":
					var calibration:=Demo.sample(card.id,level,clock)
					check(stage.caster_model.actor._deployed==calibration.deployed and stage.caster_model.actor.is_air_target()!=calibration.deployed,"calibration preview switches actual deployed and airborne domain")
				if card.id=="ps_last_calibration":check_aircraft_actor(stage.caster_model.actor,clock,"card")
				if card.id=="ps_module_shell":check_ifv_actor(stage.caster_model.actor,Demo.sample(card.id,level,clock))
				if card.id=="ps_low_observation":check_air_observation_actor(stage.caster_model.actor,Demo.sample(card.id,level,clock))
				if card.id=="ps_convoy_repair":check((not stage.caster_model.actor.velocity.is_zero_approx())==Demo.sample(card.id,level,clock).moving,"convoy preview stops when actual movement is interrupted")
				if card.id=="ps_mirage_gap":check(stage.caster_model.actor.special.has("mirage_tree")==Demo.sample(card.id,level,clock).disguised,"mirage preview uses real tree disguise only in camouflage phases "+str(clock))
				if card.id=="ps_shore_reserve":
					var state:=Demo.sample(card.id,level,clock)
					check(preload("res://scripts/units/expansion_2_infiltration.gd").hidden(stage.caster_model.actor)==(state.cloak_left>0),"shore preview actually uncloaks on firing or expiry "+str(level)+str(clock))
	stage.configure("ps_last_calibration",0,"",3);stage.elapsed=17;stage.sync_caster()
	stage.configure("ps_burning_payload",0,"",3)
	check(stage.caster_model.actor.peregrine_fx==null and not stage.caster_model.actor.special.has("academy_hero"),"switch same-unit card clears Peregrine preview identity")
	stage.configure("ps_shore_reserve",0,"",3);stage.elapsed=2.1;stage.sync_caster()
	stage.configure("ps_evacuation_escort",0,"",3)
	check(not stage.caster_model.actor.special.get("progression_v2",{}).has("shore_cloak") and stage.caster_model.actor.passive.get("id")!="ps_shore_reserve","switch same commando card clears simulated cloak and equipment")
	stage.free()
	var preview=preload("res://scripts/ui/unit_showcase.gd").new()
	add_child(preview);preview.set_process(false)
	for pair in [["DRED","escort_magazine"],["ORCA","full_sortie"],["SUB","wake_fork"],["AEGIS","intercept_ranging"],["JUMPJET","hover_sighting"],["GGI","armor_ranging"],["SREF","prism_guard"],["E1","position_rotation"],["FV","steady_seat"],["DRON","host_hunt"],["SNIPE","sniper_relocate"],["E2","alternate_advance"],["SHK","reserve_transfer"],["FLAKT","following_shard"],["V3","launch_bulkhead"],["APOC","split_hunt"]]:
		for level in 4:
			preview.show_unit(pair[0],pair[1],level)
			preview.set_process(false)
			var times:Array=[.5,2.5,4.5,6.5]
			if pair[1]=="position_rotation":
				times=[]
				for part in 3:
					for clock in [.1,2.99,3.,3.99,4.001,4.99,5.,7.99,8.001,9.99,10.,12.99,13.,13.99,14.001,17.9]:times.append(part*18+clock)
					var state:=Demo.sample(pair[1],level,part*18)
					for shot:Dictionary in state.rounds:
						times.append(part*18+shot.at-.001);times.append(part*18+shot.at+.001)
					times.append(part*18+state.rearm+.001)
				times.append(54.1)
			if pair[1]=="host_hunt":times=host_times()
			if pair[1]=="steady_seat":times=[.1,3.99,4.,6.49,6.5,7.,10.49,10.5,11.99,12.,13.99,14.,17.99,18.,21.99,22.,23.9,24.1]
			if pair[1]=="hover_sighting":times=air_observation_times()
			if pair[1] in ["intercept_ranging","wake_fork"]:times=naval_talent_times(pair[1],level)
			if pair[1]=="full_sortie":times=aircraft_times()
			if pair[1]=="split_hunt":
				times=[]
				for part in 5:
					for clock in [.1,.8,1.25,1.27,1.39,1.51,1.63,2.,3.9]:times.append(part*4+clock)
				times.append(20.1)
			if pair[1] in ["launch_bulkhead","escort_magazine"]:times=launcher_times(pair[1],level)
			if pair[1]=="reserve_transfer":times=[.5,.99,1.01,3.99,4.01,5.99,6.99,7.01,8.99,9.01,9.49,9.51,16.99,17.01,20.49,20.51,23.9,24.1]
			if pair[1]=="prism_guard":
				times=[]
				for part in 3:
					for clock in [.1,.99,1.001,1.17,1.99,2.001,2.599,2.601,2.99,3.001,3.26,3.99,4.001,6.99,7.001,12.99,13.001,15.99]:times.append(part*16+clock)
				times.append(48.1)
			if pair[1]=="armor_ranging":
				times=[]
				for part in 5:
					for clock in [.1,.69,.71,.99,1.001,1.99,2.001,2.49,2.501,2.99,3.001,3.99,4.001,4.99,5.001,5.99,6.001,6.49,6.501,7.501,7.9]:times.append(part*8+clock)
				times.append(40.1)
			if pair[1]=="following_shard":
				times=[]
				for part in 4:
					for clock in [.1,.99,1.,1.11,1.13,1.39,1.401,1.79,1.801,2.04,2.06,4.99,5.01,5.9]:times.append(part*6+clock)
				times.append(24.1)
			if pair[1] in ["sniper_relocate","alternate_advance"]:times=infantry_motion_times(pair[1],level)
			for clock:float in times:
				preview.age=clock;preview._animate();preview.queue_redraw()
				await get_tree().process_frame
				await RenderingServer.frame_post_draw
				check(preview.actor!=null and not Demo.sample(pair[1],level,clock).text.is_empty(),"GPU talent frame "+pair[1]+" rank "+str(level)+" time "+str(clock))
				if pair[1] in ["sniper_relocate","alternate_advance"]:
					var motion:=Demo.sample(pair[1],level,clock)
					var point:Vector2=preview.viewport.canvas_transform*preview.actor.position
					check(point.is_equal_approx(Vector2(123-motion.distance,104)) and (preview.actor.velocity.length()>0)==motion.moving,"infantry model displacement and walking follow the explicit movement order")
				if pair[1] in ["launch_bulkhead","escort_magazine"]:
					check(preview.actor.special.missile_racks==Demo.sample(pair[1],level,clock).racks,"preview native launcher rack state follows each independent timeline")
				if pair[1]=="full_sortie":check_aircraft_actor(preview.actor,clock,"talent")
				if pair[1]=="steady_seat":check_ifv_actor(preview.actor,Demo.sample(pair[1],level,clock))
				if pair[1]=="armor_ranging":check(preview.actor.is_deployed()==Demo.sample(pair[1],level,clock).deployed,"ranging actor stands and redeploys at scenario boundary")
				if pair[1]=="position_rotation":check(preview.actor.is_deployed()==Demo.sample(pair[1],level,clock).deployed,"rotation preview actually stands and redeploys "+str(clock))
				if pair[1]=="hover_sighting":
					var state:=Demo.sample(pair[1],level,clock)
					check_air_observation_actor(preview.actor,state)
					var point:Vector2=preview.viewport.canvas_transform*preview.actor.position
					check(point.is_equal_approx(Vector2(123+state.distance,104 if state.airborne else 122)),"hover preview actually moves and lowers on landing "+str(clock),[point,state.distance,state.airborne])
				if pair[1]=="host_hunt":
					var state:=Demo.sample("host_hunt",level,clock)
					check(preview.actor.visible==(not state.repaired and (state.local<.5 or state.active)),"drone only visible during approach or physical leap "+str(clock))
	preview.free()
	FileAccess.open(output_dir.path_join("result.json"),FileAccess.WRITE).store_string(JSON.stringify({"checks":checks,"failed":failed,"renderer":RenderingServer.get_current_rendering_method(),"screenshots":0},"  "))
	print("EXPANSION_2_DEMO_RESULT ",checks.size()," checks, ",failed," failed")
	get_tree().quit(0 if failed==0 else 1)

func infantry_w_samples() -> void:
	for rank in 4:
		var id:="ap_anchor_pin"
		check(not Demo.sample(id,rank,.99).accepted and Demo.sample(id,rank,.99).ordinary_hits==1,"anchor has earlier ordinary hit but no pending skill before W")
		var launch:=Demo.sample(id,rank,1.001)
		check(launch.accepted and not launch.hit and is_equal_approx(launch.cooldown,25.999),"W immediately launches independent projectile and starts twenty-six-second cooldown")
		var base:float=GameData.get_unit("GGI").deployed_weapon.cooldown
		check(is_equal_approx(launch.ordinary_cd,maxf(0,.2+base-1.001)),"skill launch leaves prior native ordinary reload unchanged")
		var hit:=Demo.sample(id,rank,1.461)
		check(hit.hit and hit.ordinary_hits==1 and is_equal_approx(hit.value,[20.,25.,30.,35.][rank]) and is_equal_approx(hit.left,2.999),"skill impacts once and slows at rank without another ordinary hit")
		check(not Demo.sample(id,rank,4.461).active and Demo.sample(id,rank,4.461).cooldown>0,"slow expires independently of skill cooldown")
		var folded:=Demo.sample(id,rank,7.461)
		check(not folded.deployed and folded.hit and folded.active,"already launched skill still impacts after undeploy")
		for part in range(2,7):
			var rejected:=Demo.sample(id,rank,part*6+1.461)
			check(not rejected.accepted and not rejected.hit and rejected.cooldown==0 and not rejected.active,"undeployed absent air blind-zone and out-of-range rejection does not spend skill "+str(part))
		id="ap_battle_breather"
		var active:=Demo.sample(id,rank,1.001)
		check(active.active and not active.moving and not active.can_fire and active.hits==0 and is_equal_approx(active.cooldown,21.999),"breather starts three-second fire lock and independent cooldown without forcing movement")
		check(Demo.sample(id,rank,1.261).hits==1 and not Demo.sample(id,rank,2.001).can_fire and Demo.sample(id,rank,2.001).hits==1,"already fired projectile survives casting while attempted new fire emits nothing")
		check(is_equal_approx(Demo.sample(id,rank,1.2).speed,20*(1+[.15,.2,.25,.3][rank])) and Demo.sample(id,rank,4.001).speed==20,"movement speed applies only during effect")
		check(Demo.sample(id,rank,4.001).can_fire and not Demo.sample(id,rank,4.001).active and Demo.sample(id,rank,4.661).hits==2,"normal fire and later hit resume after exact three seconds")
		var walked:=Demo.sample(id,rank,4.201)
		check(is_equal_approx(walked.distance,60+58*[.15,.2,.25,.3][rank]) and not walked.moving,"movement integrates boost and short ordinary-speed tail before stopping")
		var deployed:=Demo.sample(id,rank,9.001)
		check(deployed.deployed and not deployed.accepted and deployed.cooldown==0 and deployed.can_fire,"rejected breather preserves deployed stance and normal weapon")
		var frozen:=Demo.sample(id,rank,17.001)
		var thaw:=Demo.sample(id,rank,19.201)
		check(frozen.frozen and not frozen.accepted and frozen.cooldown==0 and not frozen.can_fire and not thaw.active and thaw.cooldown==0 and thaw.moving,"frozen cast rejects, and thaw never automatically casts delayed breather")
		check(not Demo.sample(id,rank,24.1).active and Demo.sample(id,rank,24.1).hits==0,"breather loop resets local example")

func calibration_samples() -> void:
	for rank in 4:
		var id:="ps_impact_calibration"
		var high:float=[8.,12.,16.,20.][rank]
		var low:float=[8.,8.,8.,12.][rank]
		check(Demo.sample(id,rank,.99).value==0 and Demo.sample(id,rank,.99).zones[0].left==0,"calibration launches without granting zone before impact")
		var first:=Demo.sample(id,rank,1.001)
		check(first.ordinary==100 and is_equal_approx(first.value,high) and is_equal_approx(first.cooldown,5.999),"first direct impact grants field only after its own unboosted damage")
		var overlap:=Demo.sample(id,rank,3.201)
		check(is_equal_approx(overlap.ordinary,100+high) and is_equal_approx(overlap.seismic,100+high) and is_equal_approx(overlap.value,high),"ordinary cannon and actual W illustration each use one strongest multiplier")
		check(is_equal_approx(overlap.zones[0].left,1.799) and is_equal_approx(overlap.zones[1].left,2.799),"overlap and W pulses refresh neither four-second lifetime")
		var fallback:=Demo.sample(id,rank,5.201)
		check(is_equal_approx(fallback.value,low) and is_equal_approx(fallback.ordinary,100+low) and is_equal_approx(fallback.seismic,100+low),"both damage types fall back to weaker surviving region")
		var empty:=Demo.sample(id,rank,6.201)
		check(empty.value==0 and empty.ordinary==100 and empty.seismic==100 and empty.cooldown>0,"expired regions stop increasing damage; normal impact inside six-second interval generates no new field")
		var leave:=Demo.sample(id,rank,13.201)
		check(leave.value==0 and leave.ordinary==100 and leave.seismic==0 and leave.zones[1].left>0,"moving target leaves buff area and fixed W footprint without deleting zones")
		var air:=Demo.sample(id,rank,19.201)
		check(not air.deployed and air.value==0 and is_equal_approx(air.field_bonus,high) and is_equal_approx(air.ordinary,100+high) and air.seismic==100,"airborne source loses calibration while allied deployed cannon keeps existing field benefit")
		var fixed:=Demo.sample(id,rank,27.201)
		var fixed_tail:=Demo.sample(id,rank,29.201)
		check(fixed.value==20 and fixed.ordinary==120 and fixed.seismic==120 and fixed_tail.value==12 and fixed_tail.ordinary==112 and fixed_tail.seismic==112,"explicit independent twelve-plus-twenty example is never thirty-two on either damage path")
		var loop:=Demo.sample(id,rank,32.1)
		check(loop.deployed and loop.value==0 and loop.cooldown==0 and loop.ordinary_at<0,"replay clears previous fields and restores deployed source")

func launcher_times(id:String,rank:int) -> Array:
	var times:Array=[]
	var span:=Demo.LauncherDemo.span(id)
	var release:=Demo.LauncherDemo.departure(id)
	for part in (4 if id=="launch_bulkhead" else 3):
		for clock in [.001,release*.5-.001,release*.5+.001,release-.001,release+.001,release+.499,release+.501,release+.999,release+1.001,release+1.999,release+2.001,release+2.999,release+3.001,span-.01]:times.append(part*span+clock)
		if id=="escort_magazine":
			var state:=Demo.sample(id,rank,0)
			for clock in [state.delay-.001,state.delay+.001,release+state.delay-.001,release+state.delay+.001,release+state.reload-.001,release+state.reload+.001,release+state.reload+state.delay+.001,release+4.001,release+state.delay+4.001]:times.append(part*span+clock)
	times.append(Demo.duration(id)+.01)
	return times

func launcher_samples() -> void:
	for rank in 4:
		var id:="launch_bulkhead"
		var release:=Demo.v3_departure()
		var span:=Demo.LauncherDemo.span(id)
		var initial:=Demo.sample(id,rank,release-.001)
		var start:=Demo.sample(id,rank,release+.001)
		var pool:float=GameData.get_unit("V3").hp*[.04,.06,.08,.1][rank]
		check(not initial.active and initial.cooldown==0 and start.departed and is_equal_approx(start.shield,pool),"V3 only actual departure grants exact vehicle max-HP shield")
		check(is_equal_approx(start.left,2.999) and is_equal_approx(start.cooldown,11.999),"V3 shield and trigger interval are independent")
		check(not Demo.sample(id,rank,release+3.001).active and Demo.sample(id,rank,release+3.001).cooldown>0,"vehicle shield naturally expires without removing cooldown")
		var half:=Demo.sample(id,rank,span+release+.501)
		var broken:=Demo.sample(id,rank,span+release+1.001)
		check(is_equal_approx(half.shield,pool*.5) and half.hp==half.maximum and broken.shield==0 and broken.hp==broken.maximum-7,"vehicle absorption and exact seven overflow damage stay on vehicle")
		var rack:=Demo.sample(id,rank,span*2+release+1)
		check(rack.destroyed and not rack.departed and rack.shield==0 and rack.cooldown==0,"on-rack destruction never grants departure effect")
		var intercepted:=Demo.sample(id,rank,span*3+release+1.001)
		check(intercepted.destroyed and intercepted.active and is_equal_approx(intercepted.shield,pool),"intercepted unshielded rocket does not consume vehicle shield")
		id="escort_magazine";release=Demo.dread_departure();span=Demo.LauncherDemo.span(id)
		var s:=Demo.sample(id,rank,0)
		var reload:float=GameData.get_unit("DRED").rocket.reload*(1-[.08,.12,.16,.2][rank])
		var delay:float=GameData.get_unit("DRED").weapon.burst_delay
		pool=GameData.get_unit("DMISL").hp*[.3,.45,.6,.8][rank]
		check(is_equal_approx(s.reload,reload) and is_equal_approx(s.delay,delay) and is_equal_approx(s.racks[0],release+reload) and s.racks[1]==0,"Dread uses native burst delay and discounts only reload, not preparation")
		var only_first:=Demo.sample(id,rank,release+.001)
		check(is_equal_approx(only_first.missiles[0].shield,pool) and only_first.missiles[1].shield==0 and only_first.missiles[1].pending>0,"first missile receives shield while second is still raising")
		var both:=Demo.sample(id,rank,release+delay+.001)
		check(is_equal_approx(both.missiles[1].shield,pool) and is_equal_approx(both.missiles[1].remaining-both.missiles[0].remaining,delay),"two missiles gain independent max-durability pools and staggered reloads")
		var damage:=Demo.sample(id,rank,release+1.001)
		check(is_equal_approx(damage.missiles[0].shield,pool-5) and damage.missiles[0].hp==s.maximum and is_equal_approx(damage.missiles[1].shield,pool),"numerical interception consumes only first missile shield")
		var overflow:=Demo.sample(id,rank,release+2.001)
		check(overflow.missiles[0].shield==0 and overflow.missiles[0].hp==s.maximum-7 and is_equal_approx(overflow.missiles[1].shield,pool),"first shield exhaustion passes seven durability damage without consuming second shield")
		check(Demo.sample(id,rank,release+3.001).missiles[0].destroyed,"shielded missile can ultimately be shot down")
		var first_ready:=Demo.sample(id,rank,release+reload+.001)
		check(first_ready.racks[0]==0 and first_ready.racks[1]>0 and Demo.sample(id,rank,release+reload+delay+.001).racks[1]==0,"actual two rail timers refill independently at staggered shortened deadlines")
		var killed_rack:=Demo.sample(id,rank,span+release*.5+.001)
		check(killed_rack.missiles[0].destroyed and not killed_rack.missiles[0].departed and killed_rack.missiles[0].shield==0 and is_equal_approx(killed_rack.racks[0],reload-.001),"on-rack loss grants no shield and starts shortened reload at destruction")
		var direct:=Demo.sample(id,rank,span*2+release+.501)
		check(direct.missiles[0].destroyed and direct.missiles[0].shield==0 and direct.missiles[1].shield>0,"direct destruction removes a protected missile without affecting its sibling")
		var after_impact:=Demo.sample(id,rank,release+delay+4.001)
		check(after_impact.missiles[1].impact and after_impact.missiles[1].shield==0,"normal impact removes missile and its remaining shield together")

func infantry_motion_times(id:String,rank:int) -> Array:
	var times:Array=[]
	var first:=12. if id=="sniper_relocate" else 16.
	var span:=6. if id=="sniper_relocate" else 8.
	for clock in [.1,.99,1.001,1.19,1.201,1.99,2.001,2.199,2.201,2.99,3.001,3.99,4.001,4.201,5.001,5.99,6.001,6.89,6.901,6.99,7.001,7.99,8.001,8.99,9.001,9.201,10.001,10.501,11.001,12.001,12.501,12.701,13.201,13.401,15.9]:
		if clock<first:times.append(clock)
	for part in 4:
		for clock in [.1,.99,1.001,1.201,1.99,2.001,2.201,2.99,3.001,3.201,3.501,3.99,4.001,4.201,4.99,5.001,5.201,5.9,6.001,7.9]:
			if clock<span:times.append(first+part*span+clock)
	if id=="alternate_advance":
		for shot:Dictionary in Demo.sample(id,rank,0).rounds:
			times.append(shot.at-.001);times.append(shot.at+.001)
		times.append(6.9+Demo.sample(id,rank,0).quick+.001)
	times.append(Demo.duration(id)+.1)
	return times

func infantry_motion_samples() -> void:
	for rank in 4:
		var id:="sniper_relocate"
		var value:float=[15.,20.,25.,30.][rank]
		check(not Demo.sample(id,rank,.99).active and Demo.sample(id,rank,1.001).kills==1,"relocate starts on confirmed kill, not aim or firing preparation")
		var first:=Demo.sample(id,rank,1.001)
		check(first.active and not first.moving and first.distance==0 and is_equal_approx(first.left,1.999) and is_equal_approx(first.cooldown,7.999),"speed reward starts independent two/eight timers without forcing movement")
		check(is_equal_approx(Demo.sample(id,rank,1.3).speed,10*(1+value/100)) and Demo.sample(id,rank,3.001).speed==10 and Demo.sample(id,rank,3.001).moving,"walking receives rank speed then continues at base speed after expiry")
		var walk:=Demo.sample(id,rank,5.3)
		check(is_equal_approx(walk.distance,40+18*value/100) and not walk.moving,"actual diagram displacement integrates boosted and ordinary movement separately")
		check(Demo.sample(id,rank,9.001).active and is_equal_approx(Demo.sample(id,rank,9.001).cooldown,7.999),"fresh qualifying kill after interval starts next reward")
		var repeated:=Demo.sample(id,rank,14.001)
		check(repeated.kills==2 and is_equal_approx(repeated.left,.999) and is_equal_approx(repeated.cooldown,6.999),"another kill inside interval renews neither timer")
		for at in [19.3,25.3,31.3]:
			var excluded:=Demo.sample(id,rank,at)
			check(not excluded.active and excluded.cooldown==0 and excluded.speed==10 and excluded.moving,"nonlethal summon and additional-damage examples preserve ordinary movement")
		id="alternate_advance"
		var at_stop:=Demo.sample(id,rank,2.001)
		check(not Demo.sample(id,rank,1.99).active and at_stop.active and is_equal_approx(at_stop.left,4.999) and is_equal_approx(at_stop.cooldown,9.999),"advance requires full displacement then normal stop, not movement alone")
		var base:float=GameData.get_unit("E2").weapon.cooldown
		var quick:float=base*(1-[.1,.15,.2,.25][rank])
		var shot:=Demo.sample(id,rank,2.201)
		check(is_equal_approx(shot.remaining,quick-.001) and is_equal_approx(shot.damage,[110.,115.,120.,125.][rank]),"new ordinary reload and attack get exact rank benefit")
		check(Demo.sample(id,rank,4.5).moving and is_equal_approx(Demo.sample(id,rank,4.5).left,2.5) and is_equal_approx(Demo.sample(id,rank,6.001).left,.999),"moving and stopping again never refresh five-second benefit")
		var expired:=Demo.sample(id,rank,7.001)
		check(not expired.active and expired.discounted and is_equal_approx(expired.remaining,quick-.101),"expiry restores attack but keeps the discounted reload already started")
		var ordinary:=Demo.sample(id,rank,6.9+quick+.001)
		check(not ordinary.discounted and ordinary.damage==100 and is_equal_approx(ordinary.remaining,base-.001),"next post-expiry shot uses full native reload and base damage")
		check(not Demo.sample(id,rank,10.001).active and not Demo.sample(id,rank,12.001).active and Demo.sample(id,rank,13.201).active,"stop inside cooldown fails; cooldown expiry alone fails; fresh stop succeeds")
		check(not Demo.sample(id,rank,19.501).active and Demo.sample(id,rank,19.501).damage==100,"separated one-second walks do not combine")
		var turn:=Demo.sample(id,rank,25.5)
		check(turn.turning and not turn.moving and turn.distance==0 and turn.age==0 and not turn.active,"turning in place does not earn movement credit")
		check(Demo.sample(id,rank,34.5).controlled and not Demo.sample(id,rank,34.5).active and not Demo.sample(id,rank,35.001).active and Demo.sample(id,rank,37.001).active,"control discards old credit and only a fresh complete movement grants buff")
		check(not Demo.sample(id,rank,42.001).active and Demo.sample(id,rank,42.001).cooldown==0,"temporary summon cannot inherit movement talent")
		check(Demo.sample(id,rank,48.1).distance<1 and not Demo.sample(id,rank,48.1).active,"advance replay resets movement and effects")

func prism_guard_samples() -> void:
	for rank in 4:
		var id:="prism_guard"
		var maximum:float=[30.,40.,50.,60.][rank]
		check(not Demo.sample(id,rank,.99).active,"prism shield requires actual hit")
		var first:=Demo.sample(id,rank,1.001)
		check(first.charges==3 and first.shield==maximum and is_equal_approx(first.left,2.999) and is_equal_approx(first.cooldown,11.999),"three native victims grant rank shield with independent timers")
		var repeat:=Demo.sample(id,rank,2.001)
		check(repeat.shield==maximum and is_equal_approx(repeat.left,1.999) and is_equal_approx(repeat.cooldown,10.999),"later volley renews neither shield duration nor cooldown")
		check(not Demo.sample(id,rank,4.001).active and Demo.sample(id,rank,4.001).hp==1000 and Demo.sample(id,rank,4.001).cooldown>0,"natural expiry removes shield without HP damage")
		check(not Demo.sample(id,rank,12.99).active and is_equal_approx(Demo.sample(id,rank,13.001).shield,maximum),"next qualifying native volley after twelve seconds grants fresh shield")
		var half:=Demo.sample(id,rank,18.001)
		check(half.shield==maximum*.5 and half.hp==1000 and is_equal_approx(half.left,1.999),"partial absorption decreases shield only and never extends duration")
		var broken:=Demo.sample(id,rank,19.001)
		check(broken.broken and not broken.active and broken.hp==993 and broken.cooldown>0,"breaking hit passes exactly seven overflow damage and preserves cooldown")
		check(is_equal_approx(Demo.sample(id,rank,29.001).shield,maximum) and Demo.sample(id,rank,29.001).hp==993,"new shield never heals earlier overflow")
		var two:=Demo.sample(id,rank,33.001)
		var w:=Demo.sample(id,rank,34.601)
		check(two.charges==2 and not two.active and w.charges==2 and not w.active and w.cooldown==0,"two native victims plus W hitting three cannot grant shield")
		var fresh:=Demo.sample(id,rank,35.001)
		check(fresh.charges==1 and not fresh.active and fresh.cooldown==0,"next native volley starts a fresh distinct-victim set")
		check(is_equal_approx(Demo.sample(id,rank,36.001).shield,maximum) and not Demo.sample(id,rank,39.001).active,"later native three-target volley independently grants then expires")
		check(Demo.sample(id,rank,48.1).shield==0 and Demo.sample(id,rank,48.1).hp==1000,"prism demonstration loops without carrying shield or damage")

func ranging_samples() -> void:
	for rank in 4:
		var id:="armor_ranging"
		check(Demo.sample(id,rank,.99).charges==0 and Demo.sample(id,rank,1.001).charges==1,"ranging counts impact, never launch")
		var second:=Demo.sample(id,rank,2.001)
		check(second.active and second.charges==2 and second.damage==100 and is_equal_approx(second.left,3.999),"second hit grants four seconds without retroactive damage")
		check(is_equal_approx(Demo.sample(id,rank,3.001).damage,[108.,112.,116.,120.][rank]),"third ordinary hit receives exact bound-target rank damage")
		check(is_equal_approx(Demo.sample(id,rank,4.001).left,1.999),"subsequent hits do not renew four-second deadline")
		check(not Demo.sample(id,rank,6.001).active and Demo.sample(id,rank,6.001).charges==0,"expiry clears binding and count before next hit")
		check(Demo.sample(id,rank,6.501).charges==1 and Demo.sample(id,rank,6.501).damage==100,"post-expiry first hit starts fresh")
		check(Demo.sample(id,rank,7.501).active and Demo.sample(id,rank,7.501).damage==100,"fresh second hit grants new window without boosting itself")
		for part in [1,2,3]:
			var reset:=Demo.sample(id,rank,part*8+2.501)
			check(not reset.active and reset.charges==0,"retarget undeploy death clear prior two-hit window "+str(part))
			var first_at:float=3. if part==1 else 5.
			var first:=Demo.sample(id,rank,part*8+first_at+.001)
			var next:=Demo.sample(id,rank,part*8+first_at+1.001)
			check(first.charges==1 and not first.active and first.damage==100 and next.active and next.damage==100,"new binding requires two unboosted hits "+str(part))
		check(Demo.sample(id,rank,10.501).target==1 and Demo.sample(id,rank,26.501).dead,"retarget and death select new target, never old one")
		check(not Demo.sample(id,rank,18.501).deployed and Demo.sample(id,rank,20.001).deployed and Demo.sample(id,rank,20.001).charges==0,"redeployment alone restores no stack")
		var air:=Demo.sample(id,rank,35.001)
		check(air.air and air.charges==0 and not air.active and air.damage==100,"ordinary air impacts never count or gain armor ranging")
		check(Demo.sample(id,rank,40.1).charges==0 and Demo.sample(id,rank,40.1).last_hit<0,"ranging loop resets private example")

func shard_samples() -> void:
	for rank in 4:
		var id:="following_shard"
		var start:=Demo.sample(id,rank,1.)
		check(start.active and is_equal_approx(start.left,.8) and start.cooldown==4,"ordinary air hit attaches immediately and starts independent interval")
		check(is_equal_approx(start.value,[25.,35.,45.,55.][rank]),"shard rank damage follows ordinary attack percentage")
		check(start.point.distance_to(Demo.ShardDemo.NEIGHBOR)>Demo.ShardDemo.RADIUS,"neighbor starts outside blast radius before target moves")
		var end:=Demo.sample(id,rank,1.801)
		check(end.exploded and end.flash and not end.active and end.primary_hits==1 and end.neighbor_hits==1,"after point-eight seconds moving primary and new neighbor each receive one blast")
		check(not Demo.sample(id,rank,1.79).exploded and not Demo.sample(id,rank,2.06).flash,"burst has bounded onset and display lifetime")
		check(end.point!=start.point and end.point.distance_to(Demo.ShardDemo.NEIGHBOR)<=Demo.ShardDemo.RADIUS,"blast follows current plane position into aircraft group")
		var landed:=Demo.sample(id,rank,7.401)
		check(landed.landed and not landed.active and not landed.exploded and landed.cooldown>0,"landing cancels shard immediately without refunding trigger interval")
		check(not Demo.sample(id,rank,8.).exploded and Demo.sample(id,rank,8.).neighbor_hits==0,"cancelled landed shard never explodes later")
		var dead:=Demo.sample(id,rank,13.401)
		check(dead.dead and dead.active and not dead.exploded,"airborne death retains remaining delay at fixed death coordinate")
		var death_burst:=Demo.sample(id,rank,13.801)
		check(death_burst.point.is_equal_approx(dead.point) and death_burst.exploded and death_burst.primary_hits==0 and death_burst.neighbor_hits==1,"dead target does not move or receive another hit but nearby living aircraft are hit")
		var rocket:=Demo.sample(id,rank,19.801)
		check(rocket.rocket and not rocket.active and not rocket.exploded and rocket.cooldown==0,"interceptable rocket is not a valid aircraft attachment")
		check(Demo.sample(id,rank,5.).cooldown==0 and not Demo.sample(id,rank,5.).active,"cooldown expiry does not auto-attach without a new hit")
		check(not Demo.sample(id,rank,24.1).active and not Demo.sample(id,rank,24.1).exploded,"shard independent examples reset")

func mirage_samples() -> void:
	for rank in 4:
		var id:="ps_mirage_gap"
		check(Demo.sample(id,rank,.99).disguised and not Demo.sample(id,rank,.99).active,"camouflaged waiting alone grants no guard")
		var first:=Demo.sample(id,rank,1.)
		check(first.active and not first.disguised and first.left==2 and first.cooldown==12,"first shot leaves disguise and starts separate two-second guard and twelve-second interval")
		check(is_equal_approx(first.damage,[90.,86.,82.,78.][rank]) and first.other_damage==100,"only ordinary ranged example receives rank reduction")
		check(Demo.sample(id,rank,2.).left==1 and Demo.sample(id,rank,2.).cooldown==11,"later ordinary fire refreshes neither guard nor interval")
		check(Demo.sample(id,rank,2.99).active and not Demo.sample(id,rank,3.).active and Demo.sample(id,rank,3.).damage==100,"guard expires precisely after two seconds")
		check(Demo.sample(id,rank,5.).disguised and not Demo.sample(id,rank,6.).active and Demo.sample(id,rank,6.).cooldown==7,"new camouflage shot inside interval cannot trigger")
		check(Demo.sample(id,rank,12.99).disguised and Demo.sample(id,rank,13.).active and Demo.sample(id,rank,13.).cooldown==12,"fresh camouflage shot after interval grants next guard")
		check(not Demo.sample(id,rank,15.).active,"second guard has same finite duration")
		for clock in [17.,17.5,23.,23.5]:
			var s:=Demo.sample(id,rank,clock)
			check(not s.active and s.cooldown==0 and s.damage==100,"mirror and undisguised firing never grant guard "+str(clock))
		check(Demo.sample(id,rank,28.1).disguised and not Demo.sample(id,rank,28.1).active,"mirage demo resets")

func convoy_samples() -> void:
	for rank in 4:
		var id:="ps_convoy_repair"
		var rate:float=[.005,.007,.009,.011][rank]
		check(not Demo.sample(id,rank,2.99).active and Demo.sample(id,rank,3.).active and Demo.sample(id,rank,3.).hp==500,"convoy waits full three seconds and does not heal instantly on grant")
		check(Demo.sample(id,rank,3.).cooldown==18 and is_equal_approx(Demo.sample(id,rank,4.).hp,500+1000*rate),"convoy heals correct rank rate and starts independent interval")
		check(not Demo.sample(id,rank,6.).active and is_equal_approx(Demo.sample(id,rank,6.).hp,500+3000*rate),"convoy first repair lasts at most three seconds")
		check(not Demo.sample(id,rank,20.99).active and Demo.sample(id,rank,21.).active and Demo.sample(id,rank,21.).cooldown==18,"continuous valid movement rearms at eighteen-second interval")
		check(is_equal_approx(Demo.sample(id,rank,22.).hp,500+4000*rate),"second repair resumes without replaying prior healing")
		check(Demo.sample(id,rank,26.).preparation==0 and not Demo.sample(id,rank,26.).moving,"stopping before preparation ends clears accumulated movement")
		check(not Demo.sample(id,rank,29.99).active and Demo.sample(id,rank,30.).active,"resuming requires full three fresh seconds")
		for part in [2,3,4]:
			var offset:float=24+(part-1)*8
			var start:=Demo.sample(id,rank,offset+3.1)
			var end:=Demo.sample(id,rank,offset+4.1)
			var later:=Demo.sample(id,rank,offset+7.)
			check(start.active and not end.active and not later.active,"active convoy cancels on stop, distance or enemy damage "+str(part))
			check(is_equal_approx(end.healed,later.healed) and later.cooldown>0,"interrupted repair cannot continue healing or refund interval "+str(part))
			if part==3:check(end.point.distance_to(end.peer)>70,"companion departure is visibly beyond two-cell range")
			if part==4:check(is_equal_approx(end.hp,500+1000*rate-10),"enemy hit subtracts health and stops further repair")
		for clock in [4.,22.,27.,31.,36.1,44.1,52.1]:check(Demo.sample(id,rank,clock).peer_hp==500,"companions never inherit self repair "+str(clock))
		check(Demo.sample(id,rank,56.1).hp==500 and not Demo.sample(id,rank,56.1).active,"convoy demonstration resets")

func evacuation_samples() -> void:
	for rank in 4:
		var id:="ps_evacuation_escort"
		var exact:=Demo.sample(id,rank,1.)
		check(exact.hp==400 and exact.triggers==0 and not exact.active,"exact forty percent does not trigger escort")
		var first:=Demo.sample(id,rank,2.)
		check(first.hp==399 and first.triggers==1 and first.selected==[true,true,false] and not first.self_buff,"crossing selects nearest two eligible infantry without self buff")
		check(is_equal_approx(first.value,[15.,20.,25.,30.][rank]) and first.cooldown==25 and first.left==2,"rank speed and independent twenty-five-second interval")
		var outside:=Demo.sample(id,rank,3.9)
		check(outside.first.distance_to(Demo.EvacDemo.OWNER)>70 and outside.selected[0] and not outside.selected[2],"chosen moving ally retains buff outside radius without selecting replacement")
		check(Demo.sample(id,rank,3.99).active and not Demo.sample(id,rank,4.).active,"recipient boost ends at exactly two seconds")
		check(outside.triggers==1 and is_equal_approx(outside.cooldown,23.1),"continued low-health hit does not refresh interval")
		check(is_equal_approx(outside.first.x,115+1.9*20*(1+[.15,.2,.25,.3][rank])),"only existing moving ally advances at increased rank speed")
		check(not Demo.sample(id,rank,7.).first_moving,"existing movement order may stop independently of passive")
		var ready:=Demo.sample(id,rank,27.)
		check(ready.cooldown==0 and ready.hp<400 and ready.triggers==1 and not ready.active,"cooldown expiry and further low-health damage do not retrigger")
		check(Demo.sample(id,rank,28.).hp==400 and Demo.sample(id,rank,28.).triggers==1,"healing alone never triggers escort")
		var second:=Demo.sample(id,rank,29.)
		check(second.triggers==2 and second.selected==[false,true,true] and second.cooldown==25,"new crossing chooses current nearest infantry after prior mover left")
		check(not Demo.sample(id,rank,31.).active and Demo.sample(id,rank,31.).cooldown==23,"second boost still lasts only two seconds")
		var fatal:=Demo.sample(id,rank,37.)
		check(fatal.hp==0 and fatal.triggers==0 and not fatal.active and fatal.cooldown==0,"fatal hit cannot grant survival escort")
		check(Demo.sample(id,rank,44.1).hp==500 and Demo.sample(id,rank,44.1).triggers==0,"escort demonstration resets")

func rotation_samples() -> void:
	for rank in 4:
		var id:="position_rotation"
		var base:float=GameData.get_unit("E1").deployed_weapon.cooldown
		var quick:float=base*(1-[.1,.15,.2,.25][rank])
		check(not Demo.sample(id,rank,2.99).active and Demo.sample(id,rank,3.).charges==3,"rotation requires full three-second preparation")
		check(Demo.sample(id,rank,3.).interval==10,"rotation interval begins when three charges are granted")
		for i in 4:
			var s:=Demo.sample(id,rank,4+i*quick+.001)
			check(s.charges==maxi(0,2-i),"one rotation credit consumed per ordinary volley "+str(i))
			check(is_equal_approx(s.remaining,(quick if i<3 else base)-.001),"first three new reloads reduced; fourth has full native duration "+str(i))
		var pause:=Demo.sample(id,rank,25.9)
		check(pause.charges==2 and pause.remaining==0,"long mid-sequence ceasefire retains two charges without refilling")
		check(Demo.sample(id,rank,Demo.sample(id,rank,0).rearm+.001).charges==3,"new set requires expired ten-second interval and fresh ceasefire")
		check(Demo.sample(id,rank,40.99).charges==2 and Demo.sample(id,rank,41.).charges==0 and not Demo.sample(id,rank,41.).deployed,"standing clears unused rotation credits immediately")
		check(Demo.sample(id,rank,46.).deployed and Demo.sample(id,rank,46.).charges==0 and Demo.sample(id,rank,48.99).charges==0,"redeploy must finish full three-second preparation")
		check(Demo.sample(id,rank,49.).charges==3 and Demo.sample(id,rank,50.001).charges==2,"redeployed unit earns new set and spends one")
		check(Demo.sample(id,rank,54.1).charges==0,"rotation demonstration loops without retained credits")

func air_observation_times() -> Array:
	return [.1,1.99,2.,2.3,2.8,2.99,3.,3.99,4.,4.25,4.99,5.,5.99,6.,6.99,7.,7.2,7.99,8.,8.99,9.,10.99,11.,11.2,11.9,12.1]

func check_air_observation_actor(actor,s:Dictionary) -> void:
	check(is_equal_approx(actor.logistics.air_lift,1. if s.airborne else 0.),"air preview model changes airborne state on landing and takeoff")
	check((not actor.velocity.is_zero_approx())==s.moving,"air preview motion matches stationary or moving phase")

func air_observation_samples() -> void:
	for rank in 4:
		for id in ["ps_low_observation","hover_sighting"]:
			check(not Demo.sample(id,rank,1.99).active and Demo.sample(id,rank,2.).active,"air preparation needs complete two seconds "+id)
			check(Demo.sample(id,rank,7.99).active and not Demo.sample(id,rank,8.).active,"landing immediately removes air bonus "+id)
			check(Demo.sample(id,rank,8.5).age==0 and Demo.sample(id,rank,9.).age==0,"landing and new takeoff keep no previous preparation "+id)
			check(not Demo.sample(id,rank,10.99).active and Demo.sample(id,rank,11.).active,"takeoff needs fresh full two seconds "+id)
			check(not Demo.sample(id,rank,12.1).active,"air sequence resets "+id)
		var sight:=Demo.sample("ps_low_observation",rank,2.5)
		check(sight.moving and sight.active and sight.damage==0 and is_equal_approx(sight.sight,[.5,1.,1.5,2.][rank]),"moving observer grants only correct rank vision")
		check(Demo.sample("ps_low_observation",rank,4.).sight==0 and Demo.sample("ps_low_observation",rank,4.).age==0,"ordinary fire clears observation immediately")
		check(not Demo.sample("ps_low_observation",rank,5.99).active and Demo.sample("ps_low_observation",rank,6.).active and Demo.sample("ps_low_observation",rank,6.).moving,"observation recovers after two seconds even while moving")
		var hover:=Demo.sample("hover_sighting",rank,2.8)
		for time in [0.,.8,1.6,5.2,6.,6.8,9.2,10.,10.8]:
			var preparing:=Demo.sample("hover_sighting",rank,time)
			check(preparing.shots.has(time) and not preparing.active and preparing.damage==0,"demo fires during calibration without early damage bonus "+str(time))
		check(Demo.sample("hover_sighting",rank,2.).shots.has(2.) and Demo.sample("hover_sighting",rank,2.).active,"continuous stationary firing gains bonus at two seconds")
		check(hover.active and hover.sight==0 and is_equal_approx(hover.damage,[8.,12.,16.,20.][rank]),"ordinary hovering fire retains direct damage only")
		check(Demo.sample("hover_sighting",rank,3.).moving and Demo.sample("hover_sighting",rank,3.).damage==0,"moving immediately loses hover bonus")
		check(Demo.sample("hover_sighting",rank,5.).age==0 and not Demo.sample("hover_sighting",rank,6.99).active and Demo.sample("hover_sighting",rank,7.).active,"stopping needs new full calibration")
		check(Demo.sample("hover_sighting",rank,7.2).active,"new stationary fire does not consume calibrated bonus")

func burning_samples() -> void:
	for rank in 4:
		var id:="ps_burning_payload"
		var limit:=2 if rank==3 else 3
		var trigger:=float(limit)
		var events:Array=[[.99,0],[1.,1],[2.,0],[3.,0]] if rank==3 else [[.99,0],[1.,1],[2.,2],[3.,0]]
		for event in events:
			check(Demo.sample(id,rank,event[0]).charges==event[1],"normal direct impact alone advances burning counter "+str(event))
		var start:=Demo.sample(id,rank,trigger)
		check(start.limit==limit and start.active and start.left==3 and start.ticks[0]==0,"rank threshold creates three-second zone without an immediate DOT tick")
		check(Demo.sample(id,rank,1.5).text.contains("返航补弹不清零"),"demo explicitly explains cross-sortie accumulation")
		check(is_equal_approx(start.value*.5,[7.5,10.,12.5,15.][rank]),"half-second pulse is half rank damage percentage")
		for n in range(1,7):
			check(Demo.sample(id,rank,trigger+n*.5-.01).ticks[0]==n-1 and Demo.sample(id,rank,trigger+n*.5).ticks[0]==n,"each half-second boundary adds one burn pulse "+str(n))
		check(not Demo.sample(id,rank,trigger+3).active and Demo.sample(id,rank,trigger+3).flash,"final sixth pulse remains visible at zone expiry")
		check(Demo.sample(id,rank,8.).ticks[0]==6 and Demo.sample(id,rank,8.).charges==0,"expired zone has no further damage or recursively earned counts")
		check(Demo.sample(id,rank,12.).w_flash and Demo.sample(id,rank,12.).charges==1,"four W missiles have visible effect but do not count")
		check(Demo.sample(id,rank,13.).splash_flash and Demo.sample(id,rank,13.).charges==1,"splash-only impact does not count")
		check(Demo.sample(id,rank,14.).charges==(0 if rank==3 else 2) and Demo.sample(id,rank,15.).active and Demo.sample(id,rank,15.).charges==0,"eligible ordinary direct hits complete rank counter after excluded attacks")
		check(Demo.sample(id,rank,18.).ticks[0]==6 and not Demo.sample(id,rank,18.).active,"delayed threshold hit still produces exactly six pulses")
		var before:=Demo.sample(id,rank,23.89)
		var replaced:=Demo.sample(id,rank,23.9)
		var old_ticks:=3 if rank==3 else 1
		check(before.index==0 and before.charges==limit-1 and before.ticks[0]==old_ticks,"new hit sequence counts while original zone burns")
		check(replaced.index==1 and replaced.active and replaced.charges==0 and replaced.field==Demo.BurnDemo.SECOND,"next threshold hit replaces old zone at new location")
		var end:=Demo.sample(id,rank,27.)
		check(end.ticks[0]==old_ticks and end.ticks[1]==6 and not end.active,"replacement cancels old remaining pulses and grants new zone six pulses")
		check(not Demo.sample(id,rank,30.1).active and Demo.sample(id,rank,30.1).charges==0,"independent burning examples reset")

func archive_samples() -> void:
	for rank in 4:
		var id:="ps_ballistic_archive"
		var cut:float=[.1,.15,.2,.25][rank]
		check(not Demo.sample(id,rank,.99).active and Demo.sample(id,rank,1.).active,"archive awards only on building impact")
		var hit:=Demo.sample(id,rank,1.)
		check(hit.left==8 and is_equal_approx(hit.value,cut*100),"archive eight seconds and rank attack percentage")
		check(hit.original==4 and is_equal_approx(hit.remaining,4*(1-cut)),"archive cuts current remaining timer by rank fraction")
		check(is_equal_approx(Demo.sample(id,rank,2.).remaining,4*(1-cut)-1),"discounted timer continues without applying cut twice")
		check(Demo.sample(id,rank,5.99).charges==1 and Demo.sample(id,rank,6.).charges==0,"enhanced shot consumes qualification at launch")
		check(is_equal_approx(Demo.sample(id,rank,6.).second_bonus,cut*100),"same-building shot carries correct damage bonus")
		var intercepted:=Demo.sample(id,rank,6.41)
		check(intercepted.second_intercept and not intercepted.active and intercepted.charges==0,"intercepted enhanced shot does not refund archive")
		var failed:=Demo.sample(id,rank,13.)
		check(failed.first_intercept and not failed.hit and failed.charges==0 and failed.remaining==failed.original and failed.second_bonus==0,"intercepted first rocket grants neither credit nor reload cut")
		check(Demo.sample(id,rank,25.99).active and not Demo.sample(id,rank,26.).active,"retarget immediately clears pending archive")
		check(not Demo.sample(id,rank,27.).active and Demo.sample(id,rank,30.).second_bonus==0,"returning to original building never restores cleared credit")
		check(is_equal_approx(Demo.sample(id,rank,26.).remaining,4*(1-cut)-1),"retargeting does not undo already applied reload reduction")
		var idle:=Demo.sample(id,rank,37.)
		check(idle.active and idle.remaining==0 and idle.original==0,"zero remaining CD banks no reduction while damage credit exists")
		check(Demo.sample(id,rank,44.99).active and not Demo.sample(id,rank,45.).active,"unused archive expires exactly eight seconds after hit")
		check(Demo.sample(id,rank,45.5).second_bonus==0,"shot after expiry is unempowered")
		check(not Demo.sample(id,rank,48.1).active,"independent archive examples reset")

func seal_samples() -> void:
	for rank in 4:
		var id:="ap_overload_seal"
		var idle:=Demo.sample(id,rank,10.5)
		check(idle.active and idle.charges==3 and idle.left==4+rank,"seal full rank duration starts on cast")
		var before:=Demo.sample(id,rank,14.49+rank)
		var after:=Demo.sample(id,rank,14.5+rank)
		check(before.active and before.charges==3 and not after.active and after.charges==0,"holding fire expires exactly at rank duration")
		check(before.triggers==0 and after.triggers==0 and after.near_hits==0 and not after.flash,"idle seal never damages anyone")
		check(is_equal_approx(idle.value,[20.,25.,30.,40.][rank]),"seal caster attack percentage follows rank")
		check(Demo.sample(id,rank,.49).charges==0 and Demo.sample(id,rank,.5).charges==3,"seal has no charges before application")
		for event in [[.99,0],[1.,1],[2.09,1],[2.1,2],[3.19,2],[3.2,3],[4.3,3]]:
			var s:=Demo.sample(id,rank,event[0])
			check(s.triggers==event[1] and s.near_hits==event[1],"normal ordinary volleys trigger at most three shocks "+str(event))
		check(not Demo.sample(id,rank,3.2).active and Demo.sample(id,rank,3.2).flash,"third shot removes seal while final burst is visible")
		check(not Demo.sample(id,rank,3.43).flash and not Demo.sample(id,rank,4.3).flash,"spent seal does not repeat bursts on fourth shot")
		check(Demo.sample(id,rank,20.8).special_flash and Demo.sample(id,rank,20.8).charges==3,"enemy W has visible action but consumes no seal use")
		check(Demo.sample(id,rank,21.13).triggers==1 and Demo.sample(id,rank,21.31).triggers==1,"same volley and shots inside one second do not add shocks")
		var moved:=Demo.sample(id,rank,33.21)
		check(moved.triggers==3 and moved.near_hits==1 and moved.target.distance_to(Demo.SealDemo.NEIGHBOR)>Demo.SealDemo.RADIUS,"moving away protects former neighbors but target still shocks itself")
		check(Demo.sample(id,rank,10.5).cd==30 and is_equal_approx(after.cd,26-rank),"waiting out seal does not refund caster cooldown")
		check(Demo.sample(id,rank,40.1).triggers==0 and not Demo.sample(id,rank,40.1).active,"seal independent examples reset")

func tractor_samples() -> void:
	for rank in 4:
		var radius:float=[2.,2.25,2.5,3.][rank]*20
		for part in 5:
			var offset:float=part*10
			var before:=Demo.sample("ap_tractor_warhead",rank,offset+.99)
			var after:=Demo.sample("ap_tractor_warhead",rank,offset+6.01)
			check(before.charges==1 and after.charges==0,"one pending qualification consumed or expired "+str(part))
			check(is_equal_approx(after.radius,radius) and is_equal_approx(after.value,[35.,45.,55.,70.][rank]),"tractor rank range and attack coefficient")
			check(is_equal_approx(after.cd,[40.,37.,34.,30.][rank]-6.01),"interception and timeout never refund W cooldown")
			if part in [0,2,3]:
				check(not Demo.sample("ap_tractor_warhead",rank,offset+3.99).active and Demo.sample("ap_tractor_warhead",rank,offset+4.).active,"pit starts only at ordinary impact")
				check(Demo.sample("ap_tractor_warhead",rank,offset+5.99).active and not after.active and after.burst,"two-second pit ends in one final blast")
				check(after.victim_hit==(part!=3),"only victim still in radius takes terminal blast "+str(part))
				check(not Demo.sample("ap_tractor_warhead",rank,offset+8.).flash,"final explosion does not loop")
			elif part==1:
				var destroyed:=Demo.sample("ap_tractor_warhead",rank,offset+2.51)
				check(destroyed.intercepted and not destroyed.flying and not destroyed.active and not after.burst,"intercepted native rocket never generates pit or added explosion")
			else:
				check(Demo.sample("ap_tractor_warhead",rank,offset+5.99).charges==1 and Demo.sample("ap_tractor_warhead",rank,offset+6.).charges==0,"pending payload expires at six seconds before later launch")
				var plain:=Demo.sample("ap_tractor_warhead",rank,offset+6.51)
				check(plain.flying and not plain.payload and not Demo.sample("ap_tractor_warhead",rank,offset+9.9).active,"late ordinary rocket flies without tractor payload")
		var start:=Demo.sample("ap_tractor_warhead",rank,4.)
		var end:=Demo.sample("ap_tractor_warhead",rank,6.)
		check(is_equal_approx(start.point.distance_to(end.point),24.),"unobstructed diagram pulls 0.6 cells per second for two seconds")
		var wall:=Demo.sample("ap_tractor_warhead",rank,26.)
		check(is_equal_approx(wall.point.x,Demo.TractorDemo.CENTER.x+radius*.45+7) and wall.victim_hit,"wall stops body on its near side while final in-radius damage remains")
		check(Demo.sample("ap_tractor_warhead",rank,50.1).charges==1,"independent tractor examples reset")

func pounce_crossfire_times(id:String,rank:int) -> Array:
	var times:Array=[]
	if id=="ap_lure_pounce":
		for part in 5:
			for clock in [.01,.79,.81,.99,1.,1.64,1.65,2.99,3.,3.64,3.65,5.9]:times.append(part*6+clock)
			var start:=0. if part==3 else 1.
			var guard:float=[1.,1.25,1.5,2.][rank]
			times.append(part*6+start+guard-.001);times.append(part*6+start+guard+.001)
	else:
		for part in 3:
			var state:=Demo.sample(id,rank,part*10)
			for event:Dictionary in state.events:
				for clock in [event.at-.001,event.at+.001,event.at+.2,event.at+.5]:times.append(part*10+clock)
			for clock in [.5+state.interval-.001,.5+state.interval+.001,1.99,2.,9.9]:times.append(part*10+clock)
	times.append(30.1)
	return times

func pounce_crossfire_samples() -> void:
	for rank in 4:
		var guard:float=[1.,1.25,1.5,2.][rank]
		var before:=Demo.sample("ap_lure_pounce",rank,.99)
		var inside:=Demo.sample("ap_lure_pounce",rank,1.)
		var entered:=Demo.sample("ap_lure_pounce",rank,1.65)
		check(before.guard==0 and before.point.distance_to(Demo.PounceDemo.HOST)>2*Demo.PounceDemo.CELL,"approaching from outside two cells has no immunity")
		check(is_equal_approx(inside.guard,guard) and is_equal_approx(inside.point.distance_to(Demo.PounceDemo.HOST),2*Demo.PounceDemo.CELL),"exact two-cell entry grants rank guard")
		check(entered.entered and entered.guard==0 and entered.approach==0 and entered.burrow==2,"native entry immediately ends guard and approach, starts two-second burrow")
		check(Demo.sample("ap_lure_pounce",rank,3.65).burrow==0,"burrow benefit expires independently")
		for clock in [6.1,7.1,8.9,9.1]:
			var missed:=Demo.sample("ap_lure_pounce",rank,clock)
			check(missed.guard==0 and missed.point.distance_to(Demo.PounceDemo.HOST)>2*Demo.PounceDemo.CELL,"never-entered example never gains immunity")
		var invalid:=Demo.sample("ap_lure_pounce",rank,12.81)
		check(not invalid.target_valid and invalid.guard==0 and is_equal_approx(invalid.approach,2.19) and invalid.cd>0,"target invalidation cancels guard eligibility without refunding cast or approach clock")
		check(is_equal_approx(Demo.sample("ap_lure_pounce",rank,18.01).guard,guard-.01),"cast already inside range starts guard immediately")
		check(Demo.sample("ap_lure_pounce",rank,18.+guard+.001).guard==0 and Demo.sample("ap_lure_pounce",rank,23.9).guard==0,"immediate guard expires once and never regrants")
		var blocked:=Demo.sample("ap_lure_pounce",rank,25.)
		check(is_equal_approx(blocked.guard,guard) and not blocked.entered,"blocked approach can trigger guard at two cells but cannot invade")
		check(Demo.sample("ap_lure_pounce",rank,25.+guard+.001).guard==0,"blocked approach loses immunity on exact rank expiry")
		check(is_equal_approx(entered.value,[20.,30.,40.,50.][rank]) and is_equal_approx(entered.reload,[10.,15.,20.,25.][rank]),"pounce rank speed and parasite interval coefficients")
		var interval:float=[4.,3.5,3.,2.5][rank]
		var first:=Demo.sample("ps_sea_air_crossfire",rank,.501)
		var switched:=Demo.sample("ps_sea_air_crossfire",rank,1.501)
		check(first.primary=="air" and first.charges==1 and is_equal_approx(first.cd,interval-.001),"ordinary AA supplements sea and starts shared rank cooldown")
		check(switched.primary=="sea" and switched.charges==1 and is_equal_approx(switched.cd,interval-1.001),"retargeting sea keeps remaining shared cooldown without another supplement")
		check(Demo.sample("ps_sea_air_crossfire",rank,.5+interval+.001).cd==0,"shared interval actually expires")
		var again:=Demo.sample("ps_sea_air_crossfire",rank,.6+interval+.001)
		check(again.primary=="sea" and again.charges==2 and is_equal_approx(again.cd,interval-.001),"opposite domain supplement resumes once interval completes")
		for part in [1,2]:
			var missing:=Demo.sample("ps_sea_air_crossfire",rank,part*10+1.)
			var arrived:=Demo.sample("ps_sea_air_crossfire",rank,part*10+2.)
			check(missing.missing and missing.cd==0 and missing.charges==0,"missing opposite domain does not spend interval "+str(part))
			check(not arrived.missing and arrived.charges==1 and is_equal_approx(arrived.cd,interval) and arrived.primary==missing.primary,"appearing opposite target permits supplement without changing primary")
		check(Demo.sample("ps_sea_air_crossfire",rank,9.9).charges==2,"supplements cannot recursively generate more shots")
		check(Demo.sample("ps_sea_air_crossfire",rank,30.1).charges==0 and Demo.sample("ap_lure_pounce",rank,30.1).guard==0,"both timelines reset independent examples")

func check_ifv_actor(actor,state:Dictionary) -> void:
	check(actor.logistics.passengers.size()==(0 if state.unit.is_empty() else 1),"preview cargo agrees with timeline identity "+state.crew)
	if not actor.logistics.passengers.is_empty():
		var crew=actor.logistics.passengers[0]
		check(crew.unit_id==state.unit and crew.embarked_in==actor and not crew.visible and crew.get_groups().is_empty() and crew.process_mode==Node.PROCESS_MODE_DISABLED,"cargo stays private, hidden and outside all gameplay groups")
	check(AlliedAbilities.is_repair_ifv(actor)==(state.unit=="ENGINEER"),"actual preview weapon switches to repair mode only with engineer")
	var before=actor.logistics.passengers[0] if not actor.logistics.passengers.is_empty() else null
	Demo.IfvDemo.sync_actor(actor,state)
	check(is_same(before,actor.logistics.passengers[0] if not actor.logistics.passengers.is_empty() else null),"redrawing same passenger does not recreate or reset identity")

func ifv_samples() -> void:
	for rank in 4:
		var full:float=[500.,700.,900.,1200.][rank]
		for row in [[.99,0.,0.,0.,0],[1.,full,30.,40.,1],[3.,full*.75,28.,38.,1],[6.,full*.75,25.,35.,1],[10.,full*.75,21.,31.,1],[12.,full*.75,19.,29.,1],[13.,full*.75,18.,28.,1],[31.,0.,0.,10.,1],[40.5,0.,0.,.5,1],[41.,full,30.,40.,2]]:
			var state:=Demo.sample("ps_module_shell",rank,row[0])
			check(is_equal_approx(state.hp,row[1]) and is_equal_approx(state.left,row[2]) and is_equal_approx(state.cd,row[3]) and state.triggers==row[4],"module separate shield/cooldown timers, damaged pool and no refill "+str(rank)+str(row[0]))
		for row in [[3.99,"A",false],[4.,"A",true],[6.49,"A",true],[6.5,"B",false],[10.49,"B",false],[10.5,"B",true],[12.,"",false],[14.,"工程师C",false],[18.,"工程师C",false],[22.,"",false]]:
			var state:=Demo.sample("steady_seat",rank,row[0])
			check(state.crew==row[1] and state.active==row[2] and is_equal_approx(state.factor,1-[.08,.11,.14,.17][rank] if row[2] else 1.0),"seat exact identity and repair exclusion "+str(rank)+str(row[0]))
		check(Demo.sample("steady_seat",rank,4.1).moving and Demo.sample("steady_seat",rank,4.1).active,"moving carrier still matures its passenger timer")
		check(Demo.sample("steady_seat",rank,18.).age==4 and not Demo.sample("steady_seat",rank,18.).active,"engineer can mature clock without improving repair interval")
		check(Demo.sample("ps_module_shell",rank,44.1).triggers==0 and Demo.sample("steady_seat",rank,24.1).crew=="A","both examples reset cleanly")

func soviet_times(id:String) -> Array:
	var times:Array=[]
	if id=="ps_polar_link":
		for part in 8:
			for clock in [.1,.49,.51,1.99,2.,2.49,2.5,2.99,3.,3.49,3.5,3.99,4.,4.99,5.,5.9]:times.append(part*6+clock)
	else:
		for part in 3:
			for clock in [.1,.59,.6,.75,.77,2.6,4.6,4.99,5.,5.59,5.6,5.77,7.9]:times.append(part*8+clock)
	times.append(Demo.duration(id)+.1)
	return times

func soviet_samples() -> void:
	for rank in 4:
		var per_tick:float=[5.,7.5,10.,12.5][rank]
		for part in [0,3]:
			for row in [[1.99,0,false],[2.,0,true],[2.49,0,true],[2.5,1,true],[3.,2,true],[4.99,5,true],[5.,6,false]]:
				var state:=Demo.sample("ps_polar_link",rank,part*6+row[0])
				check(state.charges==row[1] and state.active==row[2],"polar six distinct half-second pulses "+str(rank)+str(part)+str(row[0]))
				check(is_equal_approx(state.extra_each,per_tick*row[1]) and state.middle_extra==0,"only endpoints receive coefficient-scaled DOT")
		for part in [1,2]:
			var state:=Demo.sample("ps_polar_link",rank,part*6+5.9)
			check(not state.formed and state.charges==0 and state.extra_each==0,"same-target or expired-window cannot produce link")
		check(not Demo.sample("ps_polar_link",rank,18.51).formed,"W branch alone never supplies second ordinary hit")
		for part in [4,5,6,7]:
			var before:=Demo.sample("ps_polar_link",rank,part*6+2.99)
			var broken:=Demo.sample("ps_polar_link",rank,part*6+3.)
			var later:=Demo.sample("ps_polar_link",rank,part*6+4.1)
			check(before.active and before.charges==1 and broken.broken and not broken.active and broken.charges==1,"invalid endpoint breaks before next scheduled DOT "+str(part))
			check(later.broken and later.charges==1 and not later.active,"broken chain never spontaneously resumes "+str(part))
			if part==4:
				check(Demo.SovietDemo.FIRST.distance_to(Demo.SovietDemo.endpoint(broken))>4*Demo.SovietDemo.CELL and Demo.SovietDemo.FIRST.distance_to(Demo.SovietDemo.endpoint(later))<3*Demo.SovietDemo.CELL,"drawn distance breaks at over four cells then returns without reconnecting")
		check(not Demo.sample("ps_polar_link",rank,48.1).formed,"polar loop resets independent examples")
		for part in 3:
			var attack:float=200. if part==1 else 100.
			var fraction:float=[.2,.25,.3,.35][rank]
			for clock in [.6,2.6,4.6,5.6]:
				var state:=Demo.sample("ap_flak_fan",rank,part*8+clock+.001)
				var expected:float=attack*fraction if part!=2 and clock<5 else 0.
				check(is_equal_approx(state.extra,expected) and is_equal_approx(state.main,attack+expected),"flak adds exactly one coefficient-scaled hit "+str(rank)+str(part)+str(clock))
				check(state.ground_extra==0 and state.friendly_extra==0 and state.far_extra==0,"flak extra excludes ground friend and out-of-radius")
				check(state.flash,"native instant flak flashes immediately at each example shot")
			check(Demo.sample("ap_flak_fan",rank,part*8+4.99).active and not Demo.sample("ap_flak_fan",rank,part*8+5.).active,"five-second arm expires independently of shot count")
			var before:=Demo.sample("ap_flak_fan",rank,part*8+.59)
			check(before.main==0 and not before.flash,"flak does not display impact before shot")
			check(not Demo.sample("ap_flak_fan",rank,part*8+7.9).flash,"flak impact does not repeat after final shot")
		check(Demo.sample("ap_flak_fan",rank,24.1).main==0,"flak loop clears prior shot totals")

func naval_talent_times(id:String,rank:int) -> Array:
	var times:Array=[]
	if id=="wake_fork":
		for part in 5:
			for clock in [.1,.39,.41,1.59,1.61,2.19,2.2,2.39,2.4,3.09,3.1,3.69,3.71,5.9]:times.append(part*6+clock)
	else:
		var span:float=Demo.GaugeDemo.span()
		for part in 4:
			var state:=Demo.sample(id,rank,part*span)
			for shot:Dictionary in state.shots:
				for clock in [shot.start-.001,shot.start+.001,shot.hit-.001,shot.hit+.001]:times.append(part*span+clock)
			for clock in [state.switch_at-.001,state.switch_at+.001,span-.1]:times.append(part*span+clock)
	times.append(Demo.duration(id)+.1)
	return times

func naval_talent_samples() -> void:
	for rank in 4:
		for part in 5:
			var before:=Demo.sample("wake_fork",rank,part*6+2.19)
			var contact:=Demo.sample("wake_fork",rank,part*6+2.201)
			var after:=Demo.sample("wake_fork",rank,part*6+3.101)
			check(not before.forked and contact.forked==(part in [0,4]),"water qualification requires actual main contact "+str(rank)+str(part))
			check(is_equal_approx(after.water,[3.,1.3,1.2,3.,3.][part]),"only traveled water segment counts "+str(part))
			check(is_equal_approx(contact.value,[30.,40.,50.,60.][rank]) and is_equal_approx(contact.range,[2.,2.5,3.,3.5][rank]),"fork independent rank damage and range "+str(rank))
			check(after.child_hit==(part==0) and not after.main_flying and not after.child_flying,"exactly one bounded child flight, no late repeating trace "+str(part))
			var before_start:=Demo.sample("wake_fork",rank,part*6+.39)
			check(not before_start.main_flying and not before_start.child_flying,"no torpedo before launch")
		var reached:=Demo.sample("wake_fork",rank,1.61)
		check(reached.water>2 and not reached.forked,"crossing two water cells alone cannot spawn child")
		var lost:=Demo.sample("wake_fork",rank,26.401)
		var returned:=Demo.sample("wake_fork",rank,27.71)
		check(lost.lost and Demo.ForkDemo.secondary_offset(lost).length()>lost.range*Demo.ForkDemo.CELL,"drawn escaping secondary exceeds actual shown rank radius")
		check(returned.lost and not returned.child_hit and Demo.ForkDemo.secondary_offset(returned).length()<returned.range*Demo.ForkDemo.CELL,"returning inside radius does not reacquire")
		check(not Demo.sample("wake_fork",rank,30.1).forked,"fork timeline resets without retaining prior child")
		var base:float=GameData.get_unit("AEGIS").weapon.cooldown
		var cut:float=[.1,.15,.2,.25][rank]
		var third:=.4+base*2
		var fourth:=.4+base*3
		var fifth:=fourth+base*(1-cut)
		var sixth:=fifth+base*(1-cut)
		for row in [[.4+.181,1,0],[.4+base+.181,2,0],[third+.181,0,2],[fourth+.001,0,1],[fifth+.001,0,0],[sixth+.181,1,0]]:
			var state:=Demo.sample("intercept_ranging",rank,row[0])
			check(state.hits==row[1] and state.charges==row[2],"three normal hits then exactly two reload credits "+str(rank)+str(row[0]))
		check(is_equal_approx(Demo.sample("intercept_ranging",rank,third+.181).wait,base-.181),"third hit does not retroactively shorten running reload")
		check(is_equal_approx(Demo.sample("intercept_ranging",rank,fourth+.001).wait,base*(1-cut)-.001),"first credit changes only its new reload")
		check(is_equal_approx(Demo.sample("intercept_ranging",rank,sixth+.001).wait,base-.001),"after two credits next cycle restores native reload")
		var span:float=Demo.GaugeDemo.span()
		for volley in 3:
			var first:=Demo.sample("intercept_ranging",rank,span+.4+base*volley+.181)
			var duplicate:=Demo.sample("intercept_ranging",rank,span+.4+base*volley+.301)
			check(first.hits==duplicate.hits and first.charges==duplicate.charges and first.hits==(volley+1 if volley<2 else 0),"second missile in same volley never counts twice")
		for part in [2,3]:
			var after_switch:=Demo.sample("intercept_ranging",rank,part*span+third+(.101 if part==2 else .501))
			check(after_switch.switched and after_switch.hits==0 and after_switch.charges==0,"switch discards acquisition or unspent charges "+str(part))
			var new_hit:=Demo.sample("intercept_ranging",rank,part*span+fourth+.181)
			check(new_hit.hits==1 and new_hit.charges==0,"only new target hit starts new acquisition")
		check(Demo.sample("intercept_ranging",rank,span*4+.1).hits==0,"gauge timeline loop resets")

func naval_samples() -> void:
	var base:float=GameData.get_unit("DEST").weapon.cooldown
	for rank in 4:
		for clock in [.1,1.99,2.,3.51,3.99,4.,4.01,7.99,8.1]:
			var state:=Demo.sample("ap_escort_water",rank,clock)
			var active:bool=fposmod(clock,Demo.duration("ap_escort_water"))<4
			check(state.guarded==(["caster","near","next"] if active else []) and state.charges==(3 if active else 0),"water fixed recipients, no replacement, expiry and loop "+str(rank)+str(clock))
			check(is_equal_approx(state.value,[12.,16.,20.,24.][rank]),"water rank defense "+str(rank))
		check(Demo.sample("ap_escort_water",rank,3.51).depart==1.,"selected ship actually departs while fourth moves nearer")
		var sample_state:=Demo.sample("ap_gun_ballast",rank,.1)
		var cut:float=[.20,.25,.30,.35][rank]
		var shots:Array[float]=sample_state.boosted
		check(is_equal_approx(sample_state.base,base) and is_equal_approx(sample_state.value,cut*100),"ballast uses native destroyer weapon and exact rank "+str(rank))
		check(is_equal_approx(shots[0],.3) and sample_state.boosted_wait==0,"ready weapon starts at same time, no invented initial wait")
		for index in range(shots.size()-1):
			var start:float=shots[index];var finish:float=shots[index+1]
			check(is_equal_approx(finish-start,base*(1-cut if start<4 else 1.0)),"ballast changes only newly started weapon cycles "+str(rank)+str(index))
			if start<8:
				var just_after:=Demo.sample("ap_gun_ballast",rank,start+.001)
				check(is_equal_approx(just_after.boosted_wait,finish-start-.001),"reload resets to the launched cycle duration")
			if start<4 and finish>4:
				var expired:=Demo.sample("ap_gun_ballast",rank,4.)
				check(is_equal_approx(expired.boosted_wait,finish-4.),"expiry preserves already shortened reload remainder")
		for clock in [.31,3.99,4.,4.01,7.99]:
			var state:=Demo.sample("ap_gun_ballast",rank,clock)
			check(is_equal_approx(state.speed,.85 if clock<4 else 1.0) and state.damage==(105 if clock<4 else 100),"ballast shows speed and incoming-damage tradeoff only while active "+str(clock))
			check(is_equal_approx(state.normal_x-state.boosted_x,minf(clock,4)*6*.15),"ballast movement loses distance then resumes equal speed")
		var reset:=Demo.sample("ap_gun_ballast",rank,8.1)
		check(reset.active and reset.boosted_wait==0 and is_equal_approx(reset.normal_x,.6),"ballast loop resets motion and reload")

func aircraft_times() -> Array:
	var times:Array=[]
	for part in 4:
		for clock in [.1,.99,1.01,1.5,2.01,3.01,3.5,4.01,5.99,6.01,6.81,7.3]:times.append(part*8+clock)
	times.append(32.1)
	return times

func check_aircraft_actor(actor,clock:float,kind:String) -> void:
	var state:=Demo.sample("full_sortie",0,clock)
	check((actor.peregrine_fx!=null)==state.hero and actor.logistics.ammo==state.ammo and actor.logistics.ammo_max==state.capacity,"preview identity and magazine "+kind+str(clock))
	if not state.hero:check(not actor.special.has("academy_hero"),"loop restores ordinary aircraft "+kind+str(clock))

func aircraft_samples() -> void:
	# Explicit expected states independently cover native one-round, normal four-round,
	# W consuming first, W consuming last, completed refill and looping backwards.
	var expected:Array=[
		[.99,1,true,true],[1.01,0,false,false],[5.99,0,false,false],[6.,1,true,true],[6.81,0,false,false],
		[8.99,4,true,true],[9.01,3,false,true],[10.61,1,false,true],[11.41,0,false,false],[14.,4,true,true],[14.81,3,false,true],
		[16.99,4,true,true],[17.01,2,false,true],[18.01,1,false,true],[19.01,0,false,false],[22.,4,true,true],
		[24.99,4,true,true],[25.01,3,false,true],[26.01,2,false,true],[27.01,0,false,false],[30.,4,true,true],[32.1,1,true,true]]
	for rank in 4:
		for id in ["ps_last_calibration","full_sortie"]:
			for row in expected:
				var state:=Demo.sample(id,rank,row[0])
				check(state.ammo==row[1] and state.first==row[2] and state.last==row[3],"independent aircraft cycle state "+id+str(rank)+str(row[0]))
			for clock in [17.5,27.5]:
				var state:=Demo.sample(id,rank,clock)
				check(not state.active,"W has no first/last enhancement "+id+str(rank)+str(clock))
				for shot:Dictionary in state.shots:
					if shot.w:check(not shot.boost,"W projectile never inherits ordinary bonus")
			var normal:=Demo.sample(id,rank,9.5 if id=="full_sortie" else 11.9)
			check(normal.active,"ordinary first/final impact is enhanced "+id+str(rank))
			var reset:=Demo.sample(id,rank,31.3)
			check(reset.active==(id=="full_sortie") and not reset.first and reset.last,"full refill restores first; next shot preserves last "+id+str(rank))

func cross_samples() -> void:
	const Ground=preload("res://scripts/units/expansion_2_ground.gd")
	for rank in 4:
		for row in [[.59,0,false],[.6,1,true],[.83,1,true],[.85,1,false],[1.19,1,false],[1.2,2,true],[1.43,2,true],[1.45,2,false],[2.,2,false]]:
			var state:=Demo.sample("ap_prism_cross",rank,row[0])
			check(state.charges==row[1] and state.active==row[2] and state.moving_hits==mini(row[1],1),"cross distinct pulses and deduplicated hit counts "+str(rank)+str(row[0]))
			check(is_equal_approx(state.value,[60.,75.,90.,110.][rank]),"cross preview exact rank coefficient "+str(rank))
		var first:=Demo.sample("ap_prism_cross",rank,.6)
		var second:=Demo.sample("ap_prism_cross",rank,1.2)
		check(Ground.in_cross(first.escape*2,Vector2.ZERO,Vector2.RIGHT) and not Ground.in_cross(second.escape*2,Vector2.ZERO,Vector2.RIGHT),"drawn escape positions agree with live cross geometry "+str(rank))

func hunt_samples() -> void:
	for rank in 4:
		for part in 5:
			var before:=Demo.sample("split_hunt",rank,part*4+.1)
			var after:=Demo.sample("split_hunt",rank,part*4+2.)
			var expected:Array=[[1,1],[2],[2,2],[2],[2,2]][part]
			check(before.hits.all(func(value):return value==0) and after.hits==expected,"independent direct-target/overlap splash counts "+str(rank)+str(part))
			check(is_equal_approx(after.splash,20. if part==3 else 10.) and after.value==10.,"all tiers preserve ten percent with attack growth "+str(rank)+str(part))
			check(after.rounds.size()==(4 if part==4 else 2),"normal double/elite quadruple preview retains native burst count")
			check(is_equal_approx(after.radius,[2.,2.5,3.,3.5][rank]),"rank only widens candidate search, not splash multiplier")
			if part in [1,3]:check(after.rounds.all(func(shot):return shot.point==after.targets[0]),"single-target preview sends every barrel to main")
			else:check(after.rounds[0].point==after.targets[0] and after.rounds[1].point==after.targets[1],"two-target preview alternates actual destinations")
			for shot:Dictionary in after.rounds:
				var edge:=Demo.sample("split_hunt",rank,part*4+shot.impact-.001)
				var hit:=Demo.sample("split_hunt",rank,part*4+shot.impact+.001)
				check(edge.hits!=hit.hits,"only arriving projectile increments splash count")
		var loop:=Demo.sample("split_hunt",rank,20.1)
		check(loop.part==0 and loop.hits==[0,0],"loop resets previous example without accumulated hits")

func host_times() -> Array:
	return [.1,.51,4.51,8.49,8.51,8.7,8.86,9.51,11.51,14.1,15.1,18.51,22.51,23.5,24.1,26.49,26.51,26.66,26.86,29.51,31.1,39.51,41.1,43.49,43.51,43.86,48.1,52.51,56.49,56.51,58.1,59.1,66.51,67.1,68.1]

func host_samples() -> void:
	for rank in 4:
		var before:=Demo.sample("host_hunt",rank,8.49)
		var leaping:=Demo.sample("host_hunt",rank,8.51)
		check(before.charges==2 and not before.active and leaping.charges==3 and leaping.active and leaping.auto,"default auto waits for third effective bite")
		for time in [22.51,23.5]:
			var off:=Demo.sample("host_hunt",rank,time)
			check(not off.auto and off.charges==3 and off.cooldown==0 and not off.active,"off/read-load example retains three bites without transfer")
		var enabled:=Demo.sample("host_hunt",rank,24.1)
		check(enabled.auto and not enabled.active and enabled.cooldown==0,"Q on does not trigger before next bite")
		var off_flight:=Demo.sample("host_hunt",rank,26.66)
		check(not off_flight.auto and off_flight.active and is_equal_approx(off_flight.cooldown,9.84),"Q off mid-leap keeps flight and declining cooldown")
		var landed:=Demo.sample("host_hunt",rank,26.86)
		check(not landed.auto and landed.landed and not landed.active,"Q off reaches new host without retracting")
		var absent:=Demo.sample("host_hunt",rank,39.51)
		var appeared:=Demo.sample("host_hunt",rank,41.1)
		check(not absent.candidate and absent.charges==3 and absent.cooldown==0 and appeared.candidate and appeared.cooldown==0,"candidate absence costs no cooldown and appearance alone does not jump")
		var repaired:=Demo.sample("host_hunt",rank,56.51)
		check(repaired.repaired and not repaired.active and repaired.charges==0 and repaired.tears==0 and repaired.cooldown==0,"repair removes parasite before third-bite hunt")
		var mixed:=Demo.sample("host_hunt",rank,58.5)
		var group_off:=Demo.sample("host_hunt",rank,59.1)
		var group_on:=Demo.sample("host_hunt",rank,67.1)
		check(not mixed.auto and mixed.other_auto and not group_off.auto and not group_off.other_auto and group_on.auto and group_on.other_auto and not group_on.active,"group Q resolves mixed state consistently without instant hunt")
		var final:=Demo.sample("host_hunt",rank,11.51)
		check(final.tears==3 and is_equal_approx(final.value,[30.,40.,50.,60.][rank]),"three residual pulses use exact rank fraction")
		var loop:=Demo.sample("host_hunt",rank,68.1)
		check(loop.part==0 and loop.auto and loop.charges==0 and loop.cooldown==0,"replay resets read-only scenario")

func armor_times(rank:int) -> Array:
	var times:Array=[2.99,3.01,3.51,4.01,4.13,4.51,6.01,7.99,8.01,25.9,26.1,26.99,27.01,49.9,50.1]
	var state:=Demo.sample("ps_anchor_armor",rank,0)
	for use:Dictionary in state.uses:times.append(use.at-.01);times.append(use.at+.01)
	for shot:Dictionary in state.rounds:times.append(shot.at+.01)
	for shot:Dictionary in Demo.sample("ps_anchor_armor",rank,26.1).rounds:times.append(shot.at-.01);times.append(shot.at+.01)
	return times

func armor_samples() -> void:
	for rank in 4:
		var ready:=Demo.sample("ps_anchor_armor",rank,3.01)
		var expired:=Demo.sample("ps_anchor_armor",rank,8.01)
		check(is_equal_approx(ready.front,[88.,84.,80.,76.][rank]) and ready.rear==100.,"front and rear direct damage comparison reads exact tier")
		check(not Demo.sample("ps_anchor_armor",rank,2.99).active and ready.active and Demo.sample("ps_anchor_armor",rank,7.99).active and not expired.active,"front guard prepares three seconds and lasts five")
		check(expired.front==100 and expired.charges==2,"guard expiry restores damage but preserves unused reload credit")
		check(Demo.sample("ps_anchor_armor",rank,4.01).charges==3,"initial undiscounted anti-air volley grants exactly three")
		check(Demo.sample("ps_anchor_armor",rank,4.13).charges==3,"second native missile does not add more credits")
		var cut:float=[.1,.15,.2,.25][rank]
		var base:float=GameData.get_unit("APOC").weapon.cooldown
		var previous:=4.0
		for index in 3:
			var wait:=.5 if index==0 else .25
			var consume:=previous+wait
			var next:=consume+(base-wait)*(1-cut)
			var before:=Demo.sample("ps_anchor_armor",rank,consume-.01)
			var after:=Demo.sample("ps_anchor_armor",rank,consume+.01)
			var fired:=Demo.sample("ps_anchor_armor",rank,next+.01)
			check(before.charges==3-index and after.charges==2-index and is_equal_approx(after.remaining,(base-wait)*(1-cut)-.01),"waiting reduction consumes once "+str(rank)+str(index))
			check(fired.charges==2-index and is_equal_approx(fired.remaining,base-.01) and not fired.discounted,"subsequent new reload is not shortened again; air volley does not replenish")
			previous=next
		var fourth:=Demo.sample("ps_anchor_armor",rank,previous+base+.01)
		check(fourth.charges==0 and is_equal_approx(fourth.remaining,base-.01),"fourth ordinary volley uses full native reload")
		var idle:=Demo.sample("ps_anchor_armor",rank,26.1)
		check(idle.idle and idle.charges==3 and idle.remaining==0,"independent idle example starts with retained unused credits")
		var reduced:=base*(1-cut)
		for index in 4:
			var fired:=Demo.sample("ps_anchor_armor",rank,27+index*reduced+.01)
			check(fired.charges==maxi(0,2-index) and is_equal_approx(fired.remaining,(reduced if index<3 else base)-.01),"idle consumes one credit per new reload; fourth full length "+str(rank)+str(index))
		var loop:=Demo.sample("ps_anchor_armor",rank,50.1)
		check(loop.charges==0 and loop.remaining==0,"armor demo loops without leftover credits")

func shore_samples() -> void:
	for rank in 4:
		var shore:=Demo.sample("ps_shore_reserve",rank,2.)
		check(is_equal_approx(shore.cloak_left,[1.,1.5,2.,2.5][rank]) and is_equal_approx(shore.speed_left,[2.,2.5,3.,3.5][rank]),"shore grants independent exact cloak/speed durations")
		var before:=Demo.sample("ps_shore_reserve",rank,10.49)
		var shot:=Demo.sample("ps_shore_reserve",rank,10.51)
		check(before.cloak_left>0 and shot.cloak_left==0 and shot.active and is_equal_approx(shot.speed_left,[2.,2.5,3.,3.5][rank]-.51),"firing clears only cloak, retaining speed timer")
		var natural:=Demo.sample("ps_shore_reserve",rank,3.+rank*.5+.01)
		check(natural.cloak_left==0 and natural.speed_left>0,"natural cloak expiry also preserves longer speed")
		var end:=Demo.sample("ps_shore_reserve",rank,12.+rank*.5+.01)
		check(end.speed_left==0 and not end.active,"speed ends on its own original deadline")
		var loop:=Demo.sample("ps_shore_reserve",rank,16.1)
		check(loop.local<2 and loop.cloak_left==0 and loop.speed_left==0,"shore replay clears both timers")

func reserve_samples() -> void:
	for rank in 4:
		var carry:float=[30.,45.,60.,75.][rank]
		for part in 3:
			var release:float=[7.,1.5,4.5][part]
			var before:=Demo.sample("reserve_transfer",rank,part*8+release-.01)
			var after:=Demo.sample("reserve_transfer",rank,part*8+release+.01)
			var used:float=[[100.,100.,100.,100.],[30.,45.,60.,75.],[50.,50.,60.,75.]][part][rank]
			check(before.active and is_equal_approx(before.stored,carry) and not after.active and after.stored==0,"stored bonus survives until the illustrated next main attack")
			check(is_equal_approx(after.fresh,[100.,0.,50.][part]) and is_equal_approx(after.used,used),"independent numerical oracle uses max rather than sum "+str(rank)+str(part))
			check(Demo.sample("reserve_transfer",rank,part*8+7.9).stored==0,"illustrated transfer-powered kill does not create another stored bonus")
		var held:=Demo.sample("reserve_transfer",rank,6.99)
		check(held.active and is_equal_approx(held.stored,carry),"no old five-second expiry in long-hold example")
		var loop:=Demo.sample("reserve_transfer",rank,24.1)
		check(loop.part==0 and loop.stored==0,"reserve replay resets only the private example")

func observer_samples() -> void:
	for rank in 4:
		var id:="ap_observer_line"
		check(not Demo.sample(id,rank,.99).active and Demo.sample(id,rank,1.001).active,"observer begins only at accepted W")
		var firing:=Demo.sample(id,rank,2.21)
		check(firing.shot and firing.active and is_equal_approx(firing.value,[1.,1.5,2.,2.5][rank]),"ordinary shot retains rank-specific sight")
		check(not Demo.sample(id,rank,2.37).shot,"observer beam does not repeat between firing nodes")
		check(Demo.sample(id,rank,6.999).active and not Demo.sample(id,rank,7.001).active,"stationary observer ends after six seconds")
		check(not Demo.sample(id,rank,7.001).moving and Demo.sample(id,rank,7.001).cooldown>17.9,"expiry independent from movement and W cooldown")
		check(is_equal_approx(Demo.sample(id,rank,10.).left,5.),"early movement example still grants full six seconds before cancellation")
		check(Demo.sample(id,rank,10.999).active and not Demo.sample(id,rank,11.001).active and Demo.sample(id,rank,11.001).moving,"early movement cancels observation")
		check(not Demo.sample(id,rank,13.001).active and not Demo.sample(id,rank,13.001).moving and Demo.sample(id,rank,13.001).cooldown>19.9,"stopping neither restores observation nor refunds cooldown")
		check(Demo.sample(id,rank,17.001).moving and not Demo.sample(id,rank,17.001).active and Demo.sample(id,rank,17.001).cooldown==0,"moving W rejected without cooldown")
		check(not Demo.sample(id,rank,19.001).moving and not Demo.sample(id,rank,19.001).active,"stop after rejected W does not automatically cast")
		check(not Demo.sample(id,rank,24.1).active and Demo.sample(id,rank,24.1).cooldown==0,"observer loop resets independent scenarios")

func pressure_samples() -> void:
	for rank in 4:
		var id:="ps_depth_pressure"
		var maximum:float=[50.,70.,90.,120.][rank]
		check(Demo.sample(id,rank,2.).moving and Demo.sample(id,rank,2.).idle==2.,"movement does not reset pressure accumulation")
		check(not Demo.sample(id,rank,3.999).active and is_equal_approx(Demo.sample(id,rank,4.001).shield,maximum),"pressure grants correct rank shield after four quiet seconds")
		check(is_equal_approx(Demo.sample(id,rank,6.001).shield,maximum) and Demo.sample(id,rank,6.001).idle<.01 and is_equal_approx(Demo.sample(id,rank,6.001).left,12.999),"fire resets idle without clearing or refreshing fifteen-second shield")
		check(is_equal_approx(Demo.sample(id,rank,7.001).shield,maximum*.5) and Demo.sample(id,rank,7.001).hp==1000.,"incoming damage consumes shield before health")
		check(Demo.sample(id,rank,9.001).active and Demo.sample(id,rank,18.999).active and not Demo.sample(id,rank,19.001).active,"shield persists past five seconds and expires fifteen seconds after grant even after firing")
		check(not Demo.sample(id,rank,23.999).active and is_equal_approx(Demo.sample(id,rank,24.001).shield,maximum),"twenty second interval measured from grant")
		check(not Demo.sample(id,rank,40.499).active and is_equal_approx(Demo.sample(id,rank,40.501).shield,maximum),"two early shots restart four second quiet requirement")
		check(is_equal_approx(Demo.sample(id,rank,48.001).shield,maximum*.5) and Demo.sample(id,rank,49.001).shield==0 and Demo.sample(id,rank,49.001).hp==993.,"broken shield overflows seven damage to health")
		check(Demo.sample(id,rank,49.001).cooldown>16.9 and not Demo.sample(id,rank,50.001).active,"breaking and firing do not bypass pressure cooldown")
		check(Demo.sample(id,rank,52.1).shield==0 and Demo.sample(id,rank,52.1).hp==1000.,"pressure independent scenarios reset on loop")
