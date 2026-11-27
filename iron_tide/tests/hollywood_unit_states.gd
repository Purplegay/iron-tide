extends RefCounted

const States = preload("res://scripts/units/hollywood_infantry.gd")
const Mining = preload("res://scripts/world/slave_mining.gd")
const Garrison = preload("res://scripts/units/civilian_orders.gd")
const Repack = preload("res://scripts/world/construction_repack.gd")

static func effects_at(w,image:String,point:Vector2) -> Array:
	return w.effects_root.get_children().filter(func(f): return f is Ra2Fx and f.anim.image==image and f.global_position.is_equal_approx(point))

static func gatling_impacts_at(w,point:Vector2) -> int:
	const RifleFx = preload("res://scripts/core/rifle_fx_batch.gd")
	var count:=effects_at(w,"PIFFPIFF",point).size()
	for batch in w.effects_root.get_children():
		if batch is not RifleFx: continue
		for entry in batch.entries:
			if entry.anim.image=="PIFFPIFF" and batch.to_global(entry.point).is_equal_approx(point):
				count+=1
	return count

static func gatling_projectiles(t,w,cannon,ground_target) -> void:
	var air=w.spawn_unit("ZEP","ally",ground_target.position)
	air.logistics.air_lift=100.0
	w.fog.rebuild()
	var stages:Array=cannon._turret_art.gatling.stages
	for i in 3:
		cannon.special.gattling_charge=0.0 if i==0 else stages[i-1]
		for aerial in [false,true]:
			var victim=air if aerial else ground_target
			cannon.attack_target=victim
			var direction:Vector2=victim.global_position-cannon.global_position
			cannon._turret_art.angle=direction.angle()
			var spec:Dictionary=cannon.data.guns[2*i+int(aerial)]
			var projectile:=GameData.ra2_projectile(spec.ra2_projectile)
			var muzzle:Vector2=cannon._weapon_muzzle()
			var flash:=Ra2Fx.pick_directional(GameData.ra2_muzzle_anims(spec.ra2_weapon_id),Iso.dir(direction))
			var contact:=Effects.hit_position(victim)
			var flashes:=effects_at(w,flash,muzzle).size()
			var impacts:=gatling_impacts_at(w,contact)
			var hp:float=victim.hp
			var fired:bool=cannon._fire()
			var tag:String=spec.name
			t.check(projectile.get("inviso",false) and projectile.get("aa",false)==aerial and victim.is_air_target()==aerial and fired and cannon.weapon.name==tag and victim.hp<hp,tag+" 使用正确弹道并在开火当帧扣血")
			t.check(effects_at(w,flash,muzzle).size()==flashes+1 and gatling_impacts_at(w,contact)==impacts+1,tag+" 炮口与目标真实高度各生成原版特效")
			var rounds:Array=w.projectiles_root.get_children().filter(func(shot): return shot is Projectile and shot.attacker_bonus.get("impact_weapon")==spec.ra2_weapon_id and shot.shooter()==cannon)
			t.check(not rounds.is_empty() and rounds.all(func(shot): return shot.ra2_inviso and shot._detonated and shot.is_queued_for_deletion()),tag+" 不留下任何飞行圆点")
	# The last shot was AA. Target validation must look at the next gun, not that cached weapon.
	var wall=w._place_building("GAWALL",cannon.side,cannon.position+Vector2(55,0),true)
	t.check(wall!=null and not cannon._valid_weapon_target(ground_target),"盖特由对空切回对地时，地面射线仍受围墙阻挡")
	cannon.weapon=cannon.data.guns[4]
	t.check(wall!=null and WallArt.shot_blocked(w,cannon,air,cannon.weapon) and cannon._valid_weapon_target(air),"盖特由对地切到对空时，射线不被下方围墙拦截")
	if wall!=null: wall._die()

static func barrel_pixels(art:Dictionary,points:Array) -> bool:
	var image:=RA2Art.sprite_image(art)
	if image==null or points.size()!=int(art.facings)*int(art.poses): return false
	for index in points.size():
		var rect:=Rect2i(RA2Art.src_rect(art,index))
		var at:=Vector2i(floori(points[index][0]),floori(points[index][1]))+rect.position
		var covered:=false
		for dx in range(-1,2):
			for dy in range(-1,2):
				var p:=at+Vector2i(dx,dy)
				if rect.has_point(p) and image.get_pixelv(p).a>0.1: covered=true
		if not covered: return false
	return true

# Sample only the battlefield at the actor, in a frozen scene. A second identical
# render must be pixel-stable before comparing the left and right turret poses.
static func picture(actor) -> Image:
	actor.queue_redraw()
	await RenderingServer.frame_post_draw
	var image:Image=actor.get_viewport().get_texture().get_image()
	var centre:Vector2=actor.get_global_transform_with_canvas().origin
	var logical:=Rect2(centre-Vector2(65,85),Vector2(130,110))
	return image.get_region(Rect2i(actor.get_viewport().get_final_transform()*logical))

static func render_turrets(t,w) -> void:
	var bunker=w.buildings.filter(func(b):return b.building_id=="NATBNK" and not b.special.get("occupants",[]).is_empty())[0]
	var gun=w.buildings.filter(func(b):return b.building_id=="YAGGUN")[0]
	var lasher=w.units.filter(func(u):return u.unit_id=="LTNK" and u.embarked_in==null)[0]
	var gat=w.spawn_unit("YTNK","ally",w.player_start())
	t.check(w._post_layer.grade.shader.resource_path=="res://shaders/hollywood_daylight.gdshader" and w.ground.modulate.is_equal_approx(Color(0.90,0.90,0.72)), "第二关使用原图地表昼光和无额外调色的战场后期")
	for art in [gun._turret_art.art,lasher._ra2_tur,gat._ra2_tur]:
		t.check(art.get("palette_lit",false) and RA2Art.sprite_grade(art)==Color.WHITE,"原版色表炮塔按烘焙明暗绘制")
	for actor in [gun,bunker,lasher]:
		w.spawn_unit("E1","ally",actor.position+Vector2(85,0))
	w.fog.rebuild()
	w.get_tree().paused=true
	for actor in [gun,bunker,lasher,gat]:
		var turret=actor.special.occupants[0] if actor==bunker else actor
		var id:String=actor.building_id if actor is Building else actor.unit_id
		if actor is Building: actor._buildup_play=-1
		if actor==bunker: bunker._tick_anim_state(5)
		w.center_on(actor.position)
		w.camera.force_update_scroll()
		if actor==gun: actor._turret_art.angle=0
		else: turret.turret_angle=0
		await picture(actor)
		var left:=await picture(actor)
		var repeat:=await picture(actor)
		if actor==gun: actor._turret_art.angle=PI
		else: turret.turret_angle=PI
		var right:=await picture(actor)
		if "--save-turret-frames" in OS.get_cmdline_user_args():
			left.save_png("user://"+id+"_a.png")
			right.save_png("user://"+id+"_b.png")
		t.check(actor.visible and left.get_data()==repeat.get_data() and left.get_data()!=right.get_data(),id+" 固定车身或基座，实际战场画面随炮塔转向变化")
		if actor==gun or actor==gat:
			if actor==gun: actor._turret_art.spin_pose=1
			else: turret.special.barrel_phase=1.0
			var spinning:=await picture(actor)
			t.check(right.get_data()!=spinning.get_data(),id+" 固定炮塔朝向，炮管第二帧实际改变画面")
		if actor==bunker:
			Garrison.evacuate(bunker,true)
			var empty:=await picture(actor)
			t.check(not bunker.special.occupants.has(turret) and empty.get_data()!=right.get_data(),"撤车后碉堡地台保留，驻车炮塔消失")
	if "--save-turret-frames" in OS.get_cmdline_user_args():
		var factory=w.buildings.filter(func(b):return b.building_id=="YAWEAP")[0]
		w.spawn_unit("E1","ally",factory.position+Vector2(85,0))
		w.fog.rebuild()
		factory._buildup_play=-1
		w.center_on(factory.position)
		w.camera.force_update_scroll()
		await picture(factory)
		var image:Image=factory.get_viewport().get_texture().get_image()
		var centre:Vector2=factory.get_global_transform_with_canvas().origin
		var crop:=Rect2(centre-Vector2(178,166),Vector2(356,252))
		image.get_region(Rect2i(factory.get_viewport().get_final_transform()*crop)).save_png("user://YAWEAP.png")

static func run(t,w) -> void:
	for pair in [["INIT",42],["LTNK",32]]:
		var count:int=w.units.filter(func(u):return u.unit_id==pair[0]).size()
		t.check(count==pair[1],"%s 开场预置 %d/%d" % [pair[0],count,pair[1]])
	for id in ["E1","GGI","ENGINEER"]:
		var seq:=RA2Art.seq(id)
		t.check(RA2Art.seq_frame(seq,"Prone",7,0)==128,id+" 卧姿使用原版六帧方向步长")
	var p:Vector2=w.player_start()
	var y=w.spawn_unit("YURI","ally",p)
	y.set_fire_stance("none")
	var inf=w.spawn_unit("E1","enemy",p+Vector2(80,0))
	var ally=w.spawn_unit("E1","ally",p+Vector2(75,0))
	var distant=w.spawn_unit("E1","enemy",p+Vector2(185,0))
	var tank=w.spawn_unit("MTNK","enemy",p+Vector2(95,0))
	var air=w.spawn_unit("JUMPJET","enemy",p+Vector2(110,0))
	t.check(y.deploy() and States.pose(y)=="Deploy" and not y.deploy(),"尤里进入展开，重复部署无效")
	y._physics_process(6.5/15)
	t.check(inf.hp==inf.max_hp,"展开完成前不伤害步兵")
	y._physics_process(1.0/15)
	t.check(States.pose(y)=="Deployed" and inf.hp==inf.max_hp,"展开后按武器预备时间等待")
	y._physics_process(float(y.special.psi_fire_at)-float(y.special.psi_elapsed)+.001)
	var rings:=effects_at(w,"RING1",y.global_position)
	var psi_socket:=Vector2.from_angle(y.hull_angle)*(15.0*55/256)
	var psi_height:=Vector2.UP*(140.0*30/256)
	t.check(rings.size()==1 and rings[0].draw_offset.is_equal_approx(Iso.dir(psi_socket)+psi_height),"心灵波从尤里头部展开并保留脚下的范围中心")
	t.check(inf.hp<inf.max_hp and States.pose(y)=="Deployed" and ally.hp==ally.max_hp and distant.hp==distant.max_hp and tank.hp==tank.max_hp and air.hp==air.max_hp,"心灵波在展开后命中范围内敌兵，友军、圈外、空中和装甲单位保持生命")
	t.check(y.deploy(),"再次部署指令提前收起")
	y._physics_process(2.0/15)
	t.check(States.pose(y)=="Undeploy" and RA2Art.fx("RING1").get("tex")!=null,"脉冲特效与收起序列")
	y._physics_process(6.0/15)
	t.check(not y.special.has("psi_elapsed") and not y.deploy(),"收起后冷却仍生效")
	y._physics_process(4.0)
	y._cd_timer=0
	t.check(y.deploy(),"冷却结束可以再次部署")
	y._physics_process(float(y.data.undeploy_ticks)/15)
	t.check(States.pose(y)=="Undeploy","原版 150 逻辑帧到期自动收起")
	y._physics_process(.41)
	y._fire_shot(distant,true)
	var hit:=Effects.hit_position(distant)
	t.check(effects_at(w,"YURICNTL",y._weapon_muzzle()).size()==1 and effects_at(w,"YURICNTL",hit).size()==1,"心控施法与命中分别在两端生成原版动画")
	AlliedAbilities.special_shot(y,distant,y._active_weapon())
	t.check(effects_at(w,"YURICNTL",hit).size()==1 and not GameData.ra2_sound_files("YuriMindControl").is_empty() and not GameData.ra2_sound_files("MindCleared").is_empty(),"重复控制不重播命中，控制和解除均有原声")
	t.check(distant.special.get("controller")==y and RA2Art.fx("MINDANIM").get("tex")!=null,"普攻控制及受控循环贴图")
	const Psychic = preload("res://scripts/world/yuri_support.gd")
	y.selected = false
	distant.selected = false
	AlliedAbilities.tick_actor(distant, 2.0)
	t.check(Psychic.visible_control_source(w, distant, {}) == y,"超过 20 个规则帧后仍显示未选中对象的心控弧线")
	y._die()
	t.check(distant.side=="enemy" and not distant.special.has("controller"),"释放控制后恢复原阵营")
	var g=w.spawn_unit("YTNK","ally",p)
	for rank in [0,2]:
		g.veteran_level=rank
		var stages:Array=g.data.stages if rank==0 else g.data.elite_stages
		for i in 3:
			g.special.gatling_charge=0 if i==0 else stages[i-1]
			for aerial in [false,true]:
				var gun:Dictionary=g._weapon_for_target(air if aerial else tank)
				var expected:String=("AA" if aerial else "AG")+"Gattling"+("" if i==0 else str(i+1))+("E" if rank==2 else "")
				t.check(gun.name==expected and gun.ra2_aa==aerial and not GameData.ra2_muzzle_anims(gun.ra2_weapon_id).is_empty() and not GameData.ra2_impact_anims(gun.ra2_warhead).is_empty(),"盖特选枪及炮口命中 "+expected)
	g.attack_target=air
	w.fog.rebuild()
	var air_hp:float=air.hp
	g._fire_shot(air,true)
	t.check(air.hp<air_hp,"真实空中目标遭盖特实弹命中")
	var lasher=w.units.filter(func(u):return u.unit_id=="LTNK" and u.embarked_in==null)[0]
	for hull in [lasher,g,w.units.filter(func(u):return u.unit_id=="SMIN")[0]]:
		var row:Array=hull.data.hollywood_fx.primary
		hull.hull_angle=0.0
		hull.turret_angle=0.0
		var first:Vector2=hull._weapon_muzzle()
		hull.turret_angle=PI
		hull.hull_angle=PI
		var delta_socket:Vector2=first-hull._weapon_muzzle()
		if hull.unit_id=="SMIN":
			t.check(delta_socket.is_equal_approx(Vector2(row[0],row[1])*2*55/256),"矿车炮口随朝向旋转")
		else:
			t.check(delta_socket.length()>20 and barrel_pixels(hull._ra2_tur,hull._weapon_art.muzzles),hull.unit_id+" 全方向、各炮管姿态的开火点落在炮口像素上")
		var stages:Array=[]
		for fraction in [1.0,0.45,0.1,1.0]:
			hull.hp=hull.max_hp*fraction
			stages.append(hull.DamageParticles.stage(hull))
		t.check(stages==[0,1,2,0] and RA2Art.fx("SGRYSMK1").get("tex")!=null,hull.unit_id+" 损伤冒烟与火花按血量增强，修复后停止")
	lasher._grant_veteran(2,false)
	t.check(lasher._weapon_for_target(tank).name=="ATGUNE","狂风坦克精英主炮")
	g.set_fire_stance("none")
	g.attack_target=null
	g._physics_process(0.5)
	t.check(g.special.gatling_charge==0,"停火后转速回落")
	var cannon=w.buildings.filter(func(b):return b.building_id=="YAGGUN")[0]
	t.check(int(cannon._turret_art.art.poses)==2 and barrel_pixels(cannon._turret_art.art,cannon._turret_art.muzzles),"固定盖特炮的两种 HVA 姿态及 32 个朝向均有实体炮口")
	var victim_at_gun=w.spawn_unit("MTNK","ally",cannon.position+Vector2(110,0))
	cannon._process(GameData.ra2_buildup_seconds()+0.1)
	w.fog.rebuild()
	cannon.attack_target=victim_at_gun
	var shot_angle:float=cannon.global_position.angle_to_point(victim_at_gun.global_position)
	cannon._turret_art.angle=shot_angle
	cannon._think=2.0
	cannon._cd=0.0
	var victim_hp:float=victim_at_gun.hp
	cannon._process(0.01)
	var firing_audio=cannon.get_node_or_null("GatlingReport")
	t.check(cannon._gatling_followup_target==victim_at_gun and victim_at_gun.hp<victim_hp,"固定盖特首发立即扣血，并保留同目标第二发")
	victim_hp=victim_at_gun.hp
	cannon._process(0.1)
	t.check(cannon._gatling_followup_target==null and cannon._cd>0 and victim_at_gun.hp<victim_hp,"固定盖特装填期间第二发立即扣血")
	t.check(firing_audio!=null and firing_audio.playing and firing_audio==cannon.get_node_or_null("GatlingReport") and g.has_node("GatlingReport"),"车炮各用独立的持续枪声")
	if firing_audio!=null:
		t.check(firing_audio.stream.loop_mode==AudioStreamWAV.LOOP_FORWARD and firing_audio.stream.loop_begin>0 and firing_audio.stream.loop_end>firing_audio.stream.loop_begin,"盖特枪声跨过起转段后按采样点持续循环")
		firing_audio._process(2.0)
		t.check(firing_audio.releasing and firing_audio.stream==Ra2Sfx._stream(firing_audio.files.back()),"停火播放收尾录音")
	cannon._turret_art.angle=shot_angle+PI
	t.check(not cannon._fire(),"固定盖特炮未转到射向时等待")
	cannon._turret_art.angle=shot_angle
	cannon._tick_gatling(2.0,false)
	cannon._tick_gatling(1.0/15,true)
	t.check(cannon._turret_art.spin_pose==1 and cannon._fire(),"盖特炮从原版第二个炮管姿态实射")
	cannon._tick_gatling(400.0/15,true)
	t.check(cannon._fire() and cannon.weapon.name=="AGGattling3","持续射击后的固定盖特炮使用三档地面武器")
	cannon._tick_gatling(1.0,false)
	t.check(cannon._turret_art.spin_pose==0 and cannon.special.gattling_charge==0,"固定盖特炮停转归位")
	gatling_projectiles(t,w,cannon,victim_at_gun)
	var bunker=w.buildings.filter(func(b):return b.building_id=="NATBNK" and not b.special.get("occupants",[]).is_empty())[0]
	var guard=bunker.special.occupants[0]
	var rect:Rect2=guard.HollywoodTurrets.bunker_rect(bunker,guard)
	t.check(bunker._ra2.key=="NATBNKBB" and RA2Art.visible_sprite_rect(bunker._ra2,rect,RA2Art.src_rect(bunker._ra2,0)).has_area(),"坦克碉堡使用可见的原版地台")
	var intruder=w.spawn_unit("MTNK","ally",bunker.position+Vector2(120,0))
	w.fog.rebuild()
	guard.turret_angle=PI
	var hull_direction:float=guard.hull_angle
	bunker.attack_target=intruder
	guard._cd_timer=0
	guard._think_timer=0
	guard.set_fire_stance("free")
	Garrison.tick(guard,0.1)
	t.check(guard._cd_timer<=0 and guard.turret_angle!=PI and guard.hull_angle==hull_direction,"碉堡内狂风只转炮塔，未对准时不发射")
	for tick in 60:
		Garrison.tick(guard,0.1)
		if guard._cd_timer>0: break
	var local_tip:=Iso.dir(guard._weapon_muzzle()-bunker.global_position)
	var frame:int=guard.HollywoodTurrets.frame(guard)
	var point:Array=guard._weapon_art.muzzles[frame]
	t.check(guard._cd_timer>0 and local_tip.distance_to(rect.position+Vector2(point[0],point[1])*Unit.RA2_SPRITE_SCALE)<0.01,"驻堡狂风转正后从堡内炮管发射")
	var house=w.buildings.filter(func(b):return b.side=="neutral" and b.data.has("garrison_weapons"))[0]
	var city_houses:Array=w.buildings.filter(func(b):return b.data.get("hollywood_art",false) and b.data.has("garrison_slots"))
	t.check(city_houses.size()==109 and city_houses.all(func(b):return b.data.get("fire_ports",[]).size()==b.data.garrison_slots),"原图 109 栋可驻军建筑的每个席位均有射孔")
	var init=w.spawn_unit("INIT","ally",house.position)
	init.receive_hit(1)
	t.check(init.is_prone() and States.pose(init)=="Down","新兵受击后开始卧倒")
	States.tick(init,.2)
	init._fire_anim_time=0.05
	t.check(States.pose(init)=="FireProne" and init._ramped_speed(.1)==init.move_speed*.5,"卧射和爬行速度")
	init._fire_anim_time=-1
	States.tick(init,1.75)
	t.check(States.pose(init)=="Up","压制到期播放起身")
	States.tick(init,.1)
	t.check(not init.is_prone(),"站姿恢复")
	house._buildup_play=-1
	Garrison.enter(init,house)
	for rank in [0,2]:
		init.veteran_level=rank
		var gun:=Garrison.weapon(init)
		t.check(init.embarked_in==house and Garrison.has_gunner(house) and gun.get("ra2_weapon_id")==("YR_HOL_UCPsychicJab" if rank==0 else "YR_HOL_UCElitePsychicJab"),"新兵驻军选枪 %d" % rank)
		var victim=w.spawn_unit("E1","enemy",house.position+Vector2(85,0))
		w.fog.rebuild()
		house.attack_target=victim
		init._cd_timer=0
		init._think_timer=0
		Garrison.tick(init,.1)
		var flashes:=effects_at(w,"UCINIT",init._weapon_muzzle())
		t.check(not flashes.is_empty() and is_equal_approx(flashes.back().tint.a,.5),"新兵在民房射孔播放半透明原版火光 %d" % rank)
		t.check(victim.hp<victim.max_hp and init._cd_timer>0,"新兵从楼内开火命中 %d" % rank)
	var other=w.spawn_unit("INIT","ally",house.position)
	Garrison.enter(other,house)
	var ports:Array=house.data.fire_ports
	var spacing:=Vector2(ports[1][0]-ports[0][0],ports[1][1]-ports[0][1])
	var target_shift:=Iso.dir(other._weapon_muzzle()-init._weapon_muzzle())
	t.check(other.embarked_in==house and not spacing.is_zero_approx() and target_shift.is_equal_approx(spacing*Building.RA2_SPRITE_SCALE),"同楼两名新兵各自使用原版席位坐标")
	var carrier=w.spawn_unit("BFRT","ally",p)
	var passenger=w.spawn_unit("INIT","ally",p)
	t.check(passenger.logistics.request_board(carrier),"新兵接受战斗要塞登车指令")
	passenger.logistics.tick(0)
	if OpenTopped.active(passenger):
		var port:=OpenTopped.muzzle(passenger)
		passenger.attack_target=tank
		passenger._fire_shot(tank,true)
		t.check(effects_at(w,"GUNFIRE",port).size()==1 and effects_at(w,"UCINIT",port).is_empty(),"要塞乘员从车顶座位播放 GUNFIRE")
	else: t.check(false,"新兵登上要塞射击")
	var dinosaur=w.units.filter(func(u):return u.unit_id=="DNOA")[0]
	t.check(dinosaur._weapon_for_target(ally).name=="TRexInfBite" and dinosaur._weapon_for_target(tank).name=="TRexBite","霸王龙对步兵、车辆分别选枪")
	for clip in ["Walk","Idle2","Die1","Die2"]:
		var cue:Dictionary=dinosaur.data.sequence_sounds[clip]
		t.check(not GameData.ra2_sound_files(cue.sound).is_empty(),"霸王龙原版动作音 "+clip)
	for star in w.units.filter(func(u):return u.special.has("hollywood_star")):
		star.hp-=5
		var before:float=star.hp
		star._tick_hero_self_heal(star._hero_heal_interval)
		t.check(AlliedAbilities.flag(star,"ImmuneToPsionics") and star.hp==before+1,star.unit_id+" 免疫与自然回血")
		if star.unit_id=="STLN":
			t.check(star._weapon_for_target(house).name=="STALGREN" and star._weapon_for_target(ally).name=="STALGUN" and not star._weapon_domain_valid(tank),"史泰龙步兵及建筑武器，跳过无效车甲")
	mining(t,w)

static func mine_route(t,w) -> void:
	var state:Dictionary=w.allied_state.hollywood
	state.briefing=false
	state.patrols_started=true
	w.spawn_unit("E1","ally",w.player_start())
	Engine.time_scale=4.0
	var collected := false
	var saw_mine := false
	var balances := {}
	var delivered := false
	for step in 2100:
		var credits:float=w.enemy_funds
		await w.get_tree().physics_frame
		for site in w.buildings:
			if not w.actor_alive(site) or site.building_id!="YAREFN": continue
			saw_mine=true
			for worker in site.special.get("slave_crew",[]):
				if not w.actor_alive(worker): continue
				var previous:float=balances.get(worker,0)
				collected=collected or worker.cargo>0
				if previous>0 and worker.cargo==0 and w.enemy_funds>credits:
					delivered=true
					break
				balances[worker]=worker.cargo
			if delivered:break
		if delivered:break
	t.check(saw_mine,"原图预置矿车自动找到部署位置")
	t.check(collected,"矿工自行走到原图矿点并装矿")
	t.check(delivered,"矿工自行走回矿场，在交矿帧增加资金")
	Engine.time_scale=1.0

static func check_mining_portrait(t,w,actor,id:String,cameo:String) -> void:
	if actor is Building:
		w.select_building(actor)
	else:
		w.select_unit(actor,false)
	w.hud._rebuild_selection_strip()
	var icons:Array = w.hud.sel_strip_box.get_children().filter(func(tile): return tile is UnitIcon and tile.data.get("id") == id)
	t.check(icons.size()==1 and icons[0].cameo_texture!=null and icons[0].cameo_texture.resource_path=="res://assets/ra2/cameo/%s.png"%cameo,id+" 选中栏使用 "+cameo)
	w.clear_selection()

static func mining(t,w) -> void:
	var vehicle=w.units.filter(func(u):return u.unit_id=="SMIN")[0]
	check_mining_portrait(t,w,vehicle,"SMIN","SMINICON")
	t.check(is_equal_approx(GameData.ra2_build_time(vehicle.data),58.8),"矿车原规则工时 58.8 秒（1750 × 0.8 倍率）")
	t.check(vehicle.can_deploy() and vehicle.deploy_building_id()=="YAREFN","矿车部署入口")
	var deployed=false
	for ore in w.get_tree().get_nodes_in_group("resource_nodes"):
		for i in 8:
			var p:Vector2=w.snap_build_pos(ore.position+Vector2.from_angle(i*TAU/8)*180)
			if w.construction_deploy_check(vehicle,p).ok:
				vehicle.position=p
				deployed=vehicle.deploy()
				break
		if deployed: break
	t.check(deployed,"从矿区合法位置展开")
	if not deployed:return
	var site=w.buildings.filter(func(b):return b.building_id=="YAREFN")[0]
	check_mining_portrait(t,w,site,"YAREFN","SMINICON")
	t.check(is_equal_approx(GameData.ra2_build_time(site.data),84.525),"展开型矿场独立建造规则工时 84.525 秒")
	site._process(GameData.ra2_buildup_seconds()+.1)
	Mining.deployed(w,site,.5)
	var crew:Array=site.special.slave_crew
	t.check(crew.size()==5 and crew.all(func(u):return w.actor_alive(u) and u.unit_id=="SLAV") and not site._turret_art.art.is_empty(),"部署建筑保留炮塔并产出五名矿工")
	var worker=crew[0]
	check_mining_portrait(t,w,worker,"SLAV","E2ICON")
	var heading:float=site._turret_art.angle
	site._turret_art.angle=0
	var east:Vector2=site._weapon_muzzle()
	site._turret_art.angle=PI
	t.check((east-site._weapon_muzzle()).is_equal_approx(Vector2(240.0*55/256,0)),"部署后矿场的枪口跟随炮塔")
	site._turret_art.angle=heading
	var ore=worker.special.get("mine_node")
	t.check(ore!=null and worker.has_move_order,"矿工自行找到矿点并收到采集路线")
	if ore==null:return
	worker.order_stop(false)
	worker.special.erase("mine_node")
	worker.position=site.position
	Mining.work(w,site,worker,.5)
	t.check(w.path_service.zone_at(worker.position)==0 and is_instance_valid(worker.special.get("mine_node")) and worker.has_move_order,"矿工从矿场阻挡格重新选矿并收到出发命令")
	worker.special.mine_node=ore
	worker.position=ore.position
	var before:float=ore.amount
	Mining.work(w,site,worker,10)
	t.check(ore.amount==before-1 and worker.cargo==1 and States.pose(worker)=="Shovel","实际矿量减少一份，矿工执行铲矿")
	worker.cargo=worker.data.storage
	worker.position=site._spawn_point("SLAV")
	var credits:float=w.enemy_funds
	var value:float=worker.cargo_value()
	t.check(not site.special.has("ore_smoke_left"),"矿工尚未交矿时四个排烟口不启动")
	Mining.work(w,site,worker,.5)
	var vents:Array=site.data.hollywood_fx.vents
	var ports:Array=vents.map(func(v):return Vector3i(v[0],v[1],v[2]))
	t.check(ports==[Vector3i(-85,-85,220),Vector3i(-85,90,220),Vector3i(95,-85,220),Vector3i(95,90,220)] and is_equal_approx(site.special.get("ore_smoke_left",0),2.0),"交矿触发四个原版位置的排烟，持续 30 规则帧")
	site._process(2.01)
	t.check(not site.special.has("ore_smoke_left") and site.special.get("ore_smoke_puffs",[]).size()==3,"排烟结束时保留间隔十帧喷出的三批烟")
	site._process(6.0)
	t.check(not site.special.has("ore_smoke_puffs"),"尾烟自然消散并清除状态")
	t.check(worker.cargo==0 and w.enemy_funds==credits+value,"送达矿场后按实物价值结算")
	var victim=crew[1]
	victim._die(null,true)
	t.check(site.data.regen_ticks==500,"矿工补员间隔取原版 500 规则帧")
	Mining.deployed(w,site,499.0/15.0)
	t.check(not w.actor_alive(crew[1]),"第 499 帧仍在等待补员")
	Mining.deployed(w,site,1.0/15.0 + 0.000001)
	t.check(w.actor_alive(crew[1]) and crew[1]!=victim,"冷却后替补矿工")
	var codec=preload("res://scripts/save/battle_snapshot.gd").new()
	site.data.erase("hollywood_fx")
	var old_house=w.buildings.filter(func(b):return b.data.get("hollywood_art",false) and b.data.has("garrison_slots"))[0]
	var house_point:Vector2=old_house.position
	old_house.data.erase("fire_ports")
	var old_cannon=w.buildings.filter(func(b):return b.building_id=="YAGGUN")[0]
	var cannon_point:Vector2=old_cannon.position
	for gun in old_cannon.data.guns+[old_cannon.data.weapon,old_cannon.weapon]:
		gun.ra2_projectile=str(gun.ra2_projectile).trim_prefix("YR_HOL_")
	old_cannon._cd=0.65
	codec.restore(w,codec.capture(w))
	var cannon=w.buildings.filter(func(b):return b.building_id=="YAGGUN" and b.position==cannon_point)[0]
	var all_guns:Array=cannon.data.guns+[cannon.data.weapon,cannon.weapon]
	t.check(all_guns.all(func(gun):return GameData.ra2_projectile(gun.ra2_projectile).get("inviso",false)) and is_equal_approx(cannon._cd,0.65),"旧档盖特换用隐形弹道，保留装填进度")
	w.paused=false
	w.get_tree().paused=false
	site=w.buildings.filter(func(b):return b.building_id=="YAREFN")[0]
	var restored=w.buildings.filter(func(b):return b.position==house_point and b.data.has("garrison_slots"))[0]
	t.check(site.data.has("hollywood_fx") and restored.data.fire_ports.size()==restored.data.garrison_slots,"读入没有特效字段的单位定义后恢复炮口和驻军射孔")
	var saved:Array=site.special.slave_crew
	t.check(saved.size()==5 and saved.all(func(u):return w.actor_alive(u)),"读档恢复矿工实例关联")
	var checked:=Repack.check(w,site)
	t.check(checked.ok and Repack.execute(w,site),"收起矿场 "+str(checked.reason))
	if not checked.ok:return
	var packed=w.units.filter(func(u):return u.unit_id=="SMIN" and u.special.has("slave_crew"))[0]
	t.check(saved.all(func(u):return u.embarked_in==packed),"收起后保留五名原矿工")
	var liberator=w.spawn_unit("E1","ally",packed.position+Vector2(80,0))
	var shot := Projectile.new()
	w.add_child(shot)
	shot.setup(liberator.position,packed,{"attack_type":"shell"},100000.0,{},liberator.side,liberator)
	shot._explode()
	t.check(saved.all(func(u):return u.side=="ally" and u.embarked_in==null),"摧毁矿车后释放原矿工")
