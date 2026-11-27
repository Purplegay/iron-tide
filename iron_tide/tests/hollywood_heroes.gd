extends Node
const Stars=preload("res://scripts/rules/hollywood_heroes.gd")
var errors:=0
var checks:=0

func check(ok:bool,label:String) -> void:
	checks+=1
	if not ok:errors+=1
	print("STUDIO ",ok," ",label)

func _ready() -> void:
	if not OS.get_user_data_dir().contains("CodexIronTideValidation"):
		get_tree().quit(2);return
	run.call_deferred()

func run() -> void:
	MetaProgress.reset_save()
	BattleRequest.configure_skirmish(MatchRules.EXTENDED,{"country":"美国","map_size":3200,"starting_funds":50000})
	BattleRequest.freeze_combat_context()
	var screen=load("res://scenes/battle.tscn").instantiate()
	add_child(screen)
	var w=screen.battle
	screen.process_mode=Node.PROCESS_MODE_DISABLED
	var meta_screen=load("res://scenes/meta.tscn").instantiate()
	add_child(meta_screen)
	meta_screen.hero_tab.pressed.emit()
	var page=meta_screen.heroes
	check(page.is_visible_in_tree(),"从养成页签打开原英雄界面")
	check(not page.hero_buttons.has("CLNT") and not GameData.building_production_block_reason(Stars.STUDIO).is_empty(),"首次招募前隐藏英雄和制造所")
	var saved_mission:Dictionary=w.mission
	var original_save:=BattleSaves.save_slot(w,"slot1")
	check(original_save.ok,"登记奖励前对局落盘")
	if original_save.ok:
		var envelope:Dictionary=BattleSaves.read_slot("slot1").info
		var old_units:=GameData.unit_index.duplicate()
		for id in Stars.IDS:old_units.erase(id)
		var old_structures:=GameData.building_index.duplicate()
		old_structures.erase(Stars.STUDIO)
		envelope.content=BattleSaves.digest(var_to_bytes([BattleSaves.Schema.FIELDS,old_units,old_structures,GameData.ra2_general,GameData.allied_capabilities]))
		var fixture:=FileAccess.open("user://previous-studio.itsave",FileAccess.WRITE)
		fixture.store_buffer(BattleSaves.pack_file(envelope));fixture.close()
		check(BattleSaves.read_path("user://previous-studio.itsave").ok,"旧目录指纹磁盘存档继续可读")
	w.mission=GameData.get_mission("yr_hollywood")
	w.skirmish=false
	w.allied_state.hollywood={"visited":{}}
	var cast:=[]
	for i in 3:
		var id=Stars.IDS[i]
		var u=w.spawn_unit(id,"ally",Vector2(900+i*80,1000))
		u.special.hollywood_star=Stars.NAMES[id]
		cast.append(u)
	var rewards=preload("res://scripts/rules/battle_rewards.gd")
	var result={"match_id":"studio-empty","win":true,"draw":false,"gm_forced":false}
	check(rewards.commit(w,result,false) and result.rewards.recruits.is_empty(),"未救援结算")
	cast[0].special.studio_rescued=true
	cast[2].special.studio_rescued=true
	cast[2].hp=0
	result.match_id="studio-lost";result.win=false
	check(rewards.commit(w,result,false) and not result.rewards.has("recruits"),"战败无招募")
	result.match_id="studio-partial";result.win=true
	check(rewards.commit(w,result,false) and result.rewards.recruits==["CLNT"],"救援存活、未救、阵亡分别结算")
	MetaProgress.load_save()
	check(MetaProgress.Academy.hero_build_count(MetaProgress,"CLNT")==1 and MetaProgress.Academy.hero_build_count(MetaProgress,"STLN")==0,"名单读档")
	BattleRequest.freeze_combat_context()
	check(GameData.units_from_building("soviet",Stars.STUDIO).size()==1,"部分入册制造所只列一人")
	var paid:Dictionary=MetaProgress.currency.duplicate(true)
	var stats:Dictionary=MetaProgress.stats.duplicate(true)
	w.allied_state.hollywood.visited["阿诺"]=true
	result.draw=true
	check(rewards.commit(w,result,false) and not result.rewards.has("recruits"),"已有凭证时平局无招募")
	result.draw=false
	result.gm_forced=true
	check(rewards.commit(w,result,false) and not result.rewards.has("recruits"),"已有凭证时 GM 强制胜利无招募")
	result.gm_forced=false
	check(rewards.commit(w,result,false) and result.rewards.get("already_settled",false) and result.rewards.get("recruits")==["ARND"],"同局再胜按旧档片场记录补招阿诺")
	check(rewards.commit(w,result,false) and result.rewards.get("recruits")==[],"同局相同名单再胜无新增")
	MetaProgress.load_save()
	check(MetaProgress.currency==paid and MetaProgress.stats==stats,"同局重复结算后钱包与胜场落盘不变")
	check(MetaProgress.Academy.hero_build_count(MetaProgress,"ARND")==1 and MetaProgress.Academy.hero_build_count(MetaProgress,"STLN")==0,"补招名单落盘且阵亡者仍未入册")
	cast[2].hp=cast[2].max_hp
	result.match_id="studio-repeat"
	check(rewards.commit(w,result,false) and result.rewards.recruits==["STLN"],"新局胜利只补剩余英雄")
	for u in cast:u.hp=0
	w.mission=saved_mission;w.skirmish=true
	w.allied_state.erase("hollywood")
	MetaProgress.unlock_skill("ap_smoke")
	MetaProgress.unlock_skill("ps_hollow_point")
	MetaProgress.currency.cores=27.76
	page.open_page()
	for id in Stars.IDS:
		var dot=page.hero_buttons[id].get_node_or_null("UpgradeDot")
		check(not page.Upgrade.skills(id,true) and (dot==null or not dot.visible),"持有技能卡但买不起天赋时无红点 "+id)
	MetaProgress.currency.cores=100000
	page.open_page()
	for id in Stars.IDS:
		page.hero_buttons[id].pressed.emit()
		check(page.hero_buttons[id].get_node("UpgradeDot").visible,"天赋可升级时红点可见 "+id)
		check(page.hero_buttons[id].icon!=null and page.hero_buttons[id].text.contains("中立"),"英雄名册头像 "+id)
		var portrait:Texture2D=page.hero_buttons[id].icon
		var production_icon=load(GameData.ra2_cameo_path(id))
		check(portrait is AtlasTexture and portrait==production_icon and portrait.get_width()*4==portrait.get_height()*5,"名册与生产栏共用裁切头像 "+id)
		for tree in 2:
			var action:="escort" if tree==0 else "survival"
			var button=page.escort if tree==0 else page.survival
			var key:="hero_escort_ranks" if tree==0 else "hero_survival_ranks"
			for level in 2:
				button.pressed.emit()
				check(MetaProgress.academy.get(key,{}).get(id)==level+1,"养成页升级 "+id+action+str(level))
			check(not page._purchase(action),"第三层封顶 "+id+action)
			page.talent_demo.talent.select(tree)
			page.talent_demo._select_talent()
			check(page.talent_demo.levels.item_count==3,"演示三级 "+id+action)
			for level in 3:
				page.talent_demo.levels.select(level)
				page.talent_demo.restart()
				page.talent_demo._process(.5)
				await get_tree().process_frame
				check(page.talent_demo.caption.text==Stars.TRAITS[id][tree][level] and page.talent_demo.elapsed>0,"播放 "+id+action+str(level))
		check(not page.hero_buttons[id].get_node("UpgradeDot").visible,"两树满级时英雄红点熄灭 "+id)
	BattleRequest.freeze_combat_context()
	check(Expedition.heroes("美国").has("CLNT") and Expedition.heroes("苏俄").has("CLNT"),"两阵营远征名册")
	var books=preload("res://scripts/expedition/hero_field_stories.gd")
	var run_state={"country":"苏俄","heroes":[],"frozen":BattleRequest.combat_context,"stage":4}
	for id in Stars.IDS:
		var kind:String=books.BOOK[id].kind
		var candidate:String=books.candidate(run_state,kind)
		while not candidate.is_empty() and candidate!=id:
			run_state.heroes.append(candidate)
			candidate=books.candidate(run_state,kind)
		var field=[{"kind":kind,"done":true,"hero_lead":id}]
		books.settle(run_state,field,{})
		check(id in run_state.heroes and books.chronicles.has(id),"远征个人委托胜利入队 "+id)
	w._place_building("GACNST","ally",Vector2(800,500),true)
	w._place_building("GAPOWR","ally",Vector2(1100,550),true)
	check(GameData.ra2_prereq_ok(Stars.STUDIO,["NAPOWR"]) and GameData.ra2_prereq_ok(Stars.STUDIO,["YAPOWR"]),"苏军和尤里供电建筑可用")
	check(w.single_structure("NAINDP") and not w.single_structure("GAPILE"),"保留原版工业工厂限建，普通兵营不限建")
	for country in ["Americans","British","Germans","French","Alliance","Russians","Confederation","Arabs","Africans"]:
		w._countries.ally=country
		w.request_structure(Stars.STUDIO)
		check(w.struct_queue.any(func(job):return job.id==Stars.STUDIO),"制造所进入建造队列 "+country)
		w.struct_queue.clear()
	w.request_structure(Stars.STUDIO)
	check(not w.structure_queue_block_reason(Stars.STUDIO).is_empty(),"生产中占用制造所名额")
	w.request_structure(Stars.STUDIO)
	check(w.struct_queue.filter(func(job):return job.id==Stars.STUDIO).size()==1,"禁止重复排队")
	w._tick_structure_jobs(1000.,w.struct_queue,w.struct_ready,"ally","building")
	check(not w.structure_queue_block_reason(Stars.STUDIO).is_empty() and w.limit_reason(Stars.STUDIO,"ally",true).is_empty(),"待放置占名额但允许落地")
	check(int(w.struct_ready.get(Stars.STUDIO,0))==1,"施工扣款完成待放置")
	var origin:Vector2=w._player_hq().position
	var site:=Vector2.INF
	for ring in range(2,16):
		for i in range(24):
			var point:Vector2=w.snap_build_pos(origin+Vector2.RIGHT.rotated(TAU*i/24)*ring*45)
			if w.build_spot_ok(point,GameData.get_building(Stars.STUDIO),true).ok:
				site=point;break
		if site.is_finite():break
	check(site.is_finite(),"基地旁有合法3×2位置")
	if not site.is_finite():get_tree().quit(1);return
	w.set_build_mode(Stars.STUDIO);w._try_place_building(site)
	var placed:Array=w.buildings.filter(func(b):return b.building_id==Stars.STUDIO)
	check(placed.size()==1 and not w.struct_ready.has(Stars.STUDIO),"落地消耗成品")
	if placed.is_empty():get_tree().quit(1);return
	var studio=placed[0]
	w.request_structure(Stars.STUDIO)
	check(w.struct_queue.all(func(job):return job.id!=Stars.STUDIO) and not w.limit_reason(Stars.STUDIO,"ally",true).is_empty(),"已建造禁止再次生产或放置")
	check(w.limit_reason(Stars.STUDIO,"enemy").is_empty(),"各方名额独立")
	var building_icon=load(GameData.ra2_cameo_path(Stars.STUDIO))
	check(building_icon is AtlasTexture and building_icon.get_width()*4==building_icon.get_height()*5 and building_icon.region.size.x<building_icon.atlas.get_width(),"制造所图标单独裁切")
	studio._buildup_play=-1
	check(studio.data.foundation==GameData.get_building("GAPILE").foundation and not studio._ra2.is_empty() and studio.footprint_poly()==Building.placement_poly(GameData.get_building("GAPILE")),"3×2 建筑贴图和地基")
	check(studio._buildup_art.get("count")==12 and studio._ra2_anim.size()==1,"摄影棚落成与胶片轮动画装配")
	w.selected_building=studio
	w.hud.select_prod_tab("infantry")
	var heroes:=[]
	for id in Stars.IDS:
		check(w.hud._unit_catalog().has(id) and studio.enqueue(id),"侧栏与实际生产队列 "+id)
		w.hud._update_production_live()
		var caption: String = w.hud._prod_status_labels[id].text
		check(caption.contains("$1000") and caption.contains("剩") and caption.contains("秒"),"训练卡费用和剩余时间 "+caption)
		var balance: float = w.funds
		var layer: Dictionary = studio._ra2_anim[0]
		var frame_before: int = studio._anim_frame_for(layer,studio._anim_layer(layer))
		studio._process(0.2)
		w.hud._update_production_live()
		check(w.funds < balance and w.hud._prod_status_labels[id].text != caption,"实际扣款与卡片倒计时 "+id)
		check(studio._anim_frame_for(layer,studio._anim_layer(layer)) != frame_before,"工作胶片轮推进 "+id)
		studio._tick_unit_queue(1000.,id)
		var found:Array=w.units.filter(func(u):return w.actor_alive(u) and u.unit_id==id and u.special.has("studio"))
		check(found.size()==1,"制造所完成出兵 "+id)
		if found.is_empty():continue
		var u=found[0]
		u.position=Vector2(1800+heroes.size()*100,2100)
		check(not studio.can_queue(id) and u.skills.is_empty() and u.passive.is_empty(),"在场上限及专属槽为空 "+id)
		heroes.append(u)
	if heroes.size()==3:talents(w,heroes)
	var codec=preload("res://scripts/save/battle_snapshot.gd").new()
	var snap:Dictionary=codec.capture(w)
	var disk:=BattleSaves.save_slot(w,"slot2")
	check(disk.ok and BattleSaves.read_slot("slot2").ok,"新英雄在场与天赋状态写盘并读回")
	var issue:=BattleSaves.validate(snap)
	check(issue.is_empty(),"对局存档校验 "+issue)
	if issue.is_empty():
		codec.restore(w,snap)
		var restored:Array=w.units.filter(func(u):return w.actor_alive(u) and u.special.get("academy_hero")=="ARND")
		check(restored.size()==1 and restored[0].special.studio.has("hard_cd") and restored[0].special.hero_survival_rank==2,"对局读档恢复天赋与硬汉冷却")
		var restored_studio = w.buildings.filter(func(b):return w.actor_alive(b) and b.side=="ally" and b.building_id==Stars.STUDIO)
		check(restored_studio.size()==1 and not w.limit_reason(Stars.STUDIO,"ally").is_empty(),"读取的制造所仍占限建名额")
		if restored_studio.size()==1:
			w.hud._toggle_pause()
			check(w.apply_building_action("sell",restored_studio[0]),"恢复战斗后可出售制造所")
			w.request_structure(Stars.STUDIO)
			check(w.struct_queue.any(func(job):return job.id==Stars.STUDIO),"出售后可重新建造")
			w._tick_structure_jobs(1000.,w.struct_queue,w.struct_ready,"ally","building")
			var rebuilt = w.deliver_ready_structure(Stars.STUDIO,"ally",site)
			check(w.actor_alive(rebuilt),"重新落地成功")
			if w.actor_alive(rebuilt):
				rebuilt.receive_hit(1000000.0)
				check(not w.actor_alive(rebuilt) and w.limit_reason(Stars.STUDIO,"ally").is_empty(),"摧毁后释放建造名额")
	print("STUDIO RESULT ",checks," checks ",errors," failed")
	get_tree().quit(1 if errors else 0)

func talents(w,heroes:Array) -> void:
	var clint=heroes[0]
	var arnie=heroes[1]
	var sly=heroes[2]
	var target=w.spawn_unit("E2","enemy",clint.position+Vector2(75,0))
	target.max_hp=100000;target.hp=100000
	clint.start_target_order(target,false,false)
	clint.attack_target=target
	clint._face(target.position)
	clint.hull_angle=clint.position.angle_to_point(target.position)
	clint.turret_angle=clint.hull_angle
	clint.aim_dir=Vector2.from_angle(clint.hull_angle)
	clint._cd_timer=0
	check(Stars.range_bonus(clint,target)>0,"点名射程")
	var fired:bool=clint._try_fire_ready()
	var quick:float=clint._cd_timer
	clint._cd_timer=0
	var fired_again:bool=clint._try_fire_ready()
	print("CLINT shots ",fired,"/",fired_again," cd ",quick,"/",clint._cd_timer," valid ",clint._weapon_target_valid(target)," aligned ",clint._weapon_aligned(target)," target ",clint.attack_target," HP ",target.hp)
	check(fired and fired_again and quick>0 and is_equal_approx(quick,clint._cd_timer*.2),"真实首发后冷却为普通冷却的20%")
	var pkt:={}
	Stars.shot(clint,target,pkt)
	check(is_equal_approx(pkt.get("attack_bonus",1.),1.8) and Stars.range_bonus(clint,target)==0,"两次命中后第三枪加成与首枪射程消耗")
	check(is_equal_approx(Stars.reload_factor(arnie,target),.9) and is_equal_approx(Stars.reload_factor(arnie,target),.8) and is_equal_approx(Stars.reload_factor(arnie,target),.7),"热枪三层")
	Stars.impact(arnie,target,{"studio_target":target})
	check(is_equal_approx(target.buff_value("electric_slow"),.4),"满热减速")
	arnie.hp=arnie.max_hp*.49
	var start:float=arnie.hp
	arnie.receive_hit(20,"bullet",{},target)
	check(arnie.special.studio.has("hard") and arnie.hp<start and arnie.buff_value("speed")>=.3,"半血受击、减伤与加速")
	start=arnie.hp
	Stars.tick(arnie,3)
	check(is_equal_approx(arnie.hp,start+arnie.max_hp*.25) and not arnie.special.studio.has("hard"),"硬汉结束回血")
	arnie.hp=arnie.max_hp*.45
	arnie.receive_hit(1,"bullet",{},target)
	check(not arnie.special.studio.has("hard"),"冷却中不触发")
	Stars.tick(arnie,57);arnie.receive_hit(1,"bullet",{},target)
	check(arnie.special.studio.has("hard"),"60秒到期半血可再次触发")
	Stars.impact(sly,target,{"studio_target":target})
	check(sly.buff_value("speed")>=.25,"命中获得游击步伐")
	sly.position+=Vector2(2*Ra2Damage.PX_PER_CELL,0)
	Stars.tick(sly,1)
	pkt={};Stars.shot(sly,target,pkt)
	check(pkt.get("studio_round")==1 and is_equal_approx(pkt.get("attack_bonus",1.),1.4),"移动两格回马枪")
	target.hp=0
	Stars.impact(sly,target,pkt);pkt={};Stars.shot(sly,target,pkt);Stars.impact(sly,target,pkt)
	check(pkt.get("studio_round")==2 and not sly.special.studio.has("return_round"),"击倒仅续一发")
	var fort=w._place_building("NAHAND","enemy",Vector2(2450,2200),true)
	var guard=w.spawn_unit("E2","enemy",fort.position+Vector2(25,0))
	guard.max_hp=100000;guard.hp=100000
	var totals:=[]
	for i in 3:
		pkt={};Stars.shot(sly,fort,pkt)
		var before:float=guard.hp
		totals.append(Stars.grenade_multiplier(sly,fort,pkt))
		fort.receive_hit(1,"bullet",pkt,sly)
		check((guard.hp<before)==(i>=1),"榴弹命中与守军溅射 "+str(i+1))
	check(totals==[1.2,1.2,1.7],"拆迁队第三发加成")
	# Four low-health foot soldiers in range. One normal hit can remove at most three.
	clint.position=Vector2(1500,2500)
	var line:Array=[]
	for i in 4:
		var soldier=w.spawn_unit("E2","enemy",clint.position+Vector2(50+i*15,0))
		soldier.hp=1;line.append(soldier)
	clint.start_target_order(line[0],false,false)
	clint._fire_shot(line[0],true)
	check(line.slice(0,3).all(func(u):return u.hp<=0) and line[3].hp>0,"实弹击杀连续补两枪，第四人存活")
	arnie.special.studio.heat=3
	Stars.impact(arnie,target,{"studio_target":target})
	check(is_equal_approx(Stars.reload_factor(arnie,line[3]),.7),"击倒后转火保留三层")
	sly.attack_target=fort
	sly.special.studio.erase("fort")
	var fort_hp:float=fort.hp
	var sent:=false
	sly._fire_shot(fort,true)
	for projectile in sly._pick_projectile_parent().get_children():
		if projectile is Projectile and projectile.shooter()==sly:
			projectile.target_point=fort.position
			projectile._explode()
			sent=true
	check(sent and fort.hp<fort_hp and sly.special.studio.get("fort_hits",0)==1,"实际榴弹发射与命中建筑")
