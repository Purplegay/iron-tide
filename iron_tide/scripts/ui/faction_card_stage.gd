extends Control
## The schematic is drawn in a fixed coordinate space, then fitted to the panel.
const ALLY := Color("#66c9ed")
const FOE := Color("#ff9c75")
const BONUS := Color("#f3cf66")
const MUTED := Color("#63788b")
const A := Vector2(62,73)
const B := Vector2(286,73)
var card := ""
var magnitude := 0.0
var caption := ""
var elapsed := 0.0
var playing := true
var playback_speed:=1.0
var duration := 6.0

var preview_rank := 0
var mirror_ending:=0
var show_optional_hit := true
const Scope = preload("res://scripts/rules/skill_scope.gd")
const Showcase = preload("res://scripts/ui/unit_showcase.gd")
var caster_model_id := ""
var caster_model_is_hero := false
var caster_model: TextureRect
var caster_warmup_frames:=0

func configure_caster() -> void:
	var definition:=GameData.get_skill(card)
	var id:String=str(definition.allowed_units[0]) if Scope.exclusive(definition) else str(definition.get("demo_model",""))
	if definition.get("effect","")=="field_commission":id=str(definition.get("objective_unit",id))
	var hero:bool=card in ["ap_leizhu_court","ps_leizhu_charge","ap_peregrine_hunt","ps_peregrine_rearm"]
	var stale_preview:bool=is_instance_valid(caster_model) and caster_model.actor.special.has("expansion_2_preview_card") and caster_model.actor.special.expansion_2_preview_card!=card
	if id==caster_model_id and hero==caster_model_is_hero and is_instance_valid(caster_model) and not stale_preview:return
	if is_instance_valid(caster_model):caster_model.free()
	caster_model=null
	caster_model_id=id
	caster_model_is_hero=hero
	if id.is_empty() or not GameData.unit_index.has(id):return
	# Private render world: never spawn a live match actor or advance gameplay.
	caster_model=Showcase.new()
	add_child(caster_model)
	caster_model.show_unit(id)
	if hero:
		if id=="ORCA":preload("res://scripts/units/peregrine_visual.gd").install_preview(caster_model.actor)
		else:preload("res://scripts/units/leizhu_art.gd").install_preview(caster_model.actor)
	caster_model.hide()
	caster_model.set_process(false)
	caster_model.actor.process_mode=Node.PROCESS_MODE_DISABLED
	# Field/distortion nodes require live lifecycle ticks. The timeline draws its own
	# skill illustration; an uninitialized additive capture must not cover the model.
	var field_fx=caster_model.actor.get_node_or_null("Ra3MirageFx")
	if field_fx!=null:field_fx.hide()
	caster_warmup_frames=3
	sync_caster()

func sync_caster() -> void:
	if not is_instance_valid(caster_model):return
	caster_model.age=elapsed
	# The schematic aims screen-right; convert that direction to the isometric world.
	caster_model.view_heading=Iso.eff_angle()
	caster_model._animate()
	var model=caster_model.actor
	if model.hero_art!=null:model.hero_art.clock=elapsed;model.hero_art.tick(model,0)
	if model.peregrine_fx!=null:model.peregrine_fx.clock=elapsed
	if card in ["ap_watch_posts","ps_watch_succession"] or model.special.has("watch_post_preview"):
		model._deployed=card in ["ap_watch_posts","ps_watch_succession"]
		if model._deployed:model.special.watch_post_preview=true
		else:model.special.erase("watch_post_preview")
	model.velocity=Vector2.ZERO
	if card=="ap_decoy" and elapsed>0.5 and elapsed<1.3:model.velocity=Vector2.UP.rotated(Iso.eff_angle())*42
	if card=="ap_slope" and elapsed>2.2:model.velocity=Vector2.RIGHT.rotated(Iso.eff_angle())*42
	if GameData.get_skill(card).get("expansion2",false):preload("res://scripts/ui/expansion_2_demo.gd").sync_card(self)
	model.aim_dir=Vector2.from_angle(model.turret_angle)
	if model._ra3_model!=null:
		model._ra3_model.sync_pose()
		var shadow=model._ra3_model.get("ground_shadow")
		# The schematic has no terrain; omit the separate ground-shadow capture.
		if is_instance_valid(shadow):shadow.hide()
		model._ra3_model.viewport.render_target_update_mode=SubViewport.UPDATE_ONCE
	model.queue_redraw()
	caster_model.viewport.render_target_update_mode=SubViewport.UPDATE_ONCE

func configure(id: String, value: float, text: String, rank:=0) -> void:
	preview_rank=rank
	show_optional_hit=true
	card = id
	magnitude = value
	caption = text
	elapsed = 0.0
	duration = value + 2.8 if card == "ap_buoy" else 6.0
	if card == "ps_phase": duration = 11.5
	if card == "ap_twin": duration = float(GameData.get_skill("ap_twin").twin_windows[rank])+1.4
	if card == "ps_contact": duration = 3.8+Unit.FactionCards.contact_seconds(rank)
	if card == "ap_tesla_chain": duration = float(GameData.get_skill(card).duration)+1.4
	if card == "ap_mirror_fork":duration=float(GameData.get_skill(card).values.life[rank])+2.0
	if card == "ap_seismic_anchor":duration=float(GameData.get_skill(card).values.life[rank])+2.0
	if card=="ps_tanya_rhythm":duration=10.0
	if card=="ap_boris_corridor":duration=7.0
	if card=="ps_boris_receipt":duration=21.0
	if card=="ps_peregrine_rearm":duration=12.0
	if card=="ap_leizhu_court":duration=float(GameData.get_skill(card).values.life[rank])+2
	if card=="ps_leizhu_charge":duration=15.0
	if card in preload("res://scripts/ui/convoy_demo.gd").CARDS:duration=12 if card=="ps_convoy_heat" else 9
	if GameData.get_skill(card).get("expansion2",false):duration=preload("res://scripts/ui/expansion_2_demo.gd").duration(card)
	if GameData.get_skill(card).get("effect","")=="field_commission": duration=3.2+value*0.8
	if card in ["ap_smoke","ap_overdrive","ap_focus_fire"]: duration=float(GameData.get_skill(card).duration)+2.0
	playing = true
	configure_caster()
	sync_caster()
	queue_redraw()

func _process(delta: float) -> void:
	if caster_warmup_frames>0:
		caster_warmup_frames-=1
		queue_redraw()
	delta*=playback_speed
	if playing:
		if card=="ap_twin" and elapsed+delta>=duration: show_optional_hit=not show_optional_hit
		elapsed = fmod(elapsed + delta,duration)
		queue_redraw()

func actor(point: Vector2, color: Color, heading := 0.0, use_caster:=true) -> void:
	if use_caster and is_instance_valid(caster_model) and Color(color,1.0)==ALLY:
		# Keep the original source position, trajectory and alpha (including decoy ghosts).
		draw_texture_rect_region(caster_model.texture,Rect2(point-Vector2(42,36),Vector2(84,72)),Rect2(115,0,200,172),Color(1,1,1,color.a))
		return
	var triangle := PackedVector2Array()
	for v in [Vector2(14,0),Vector2(-9,-8),Vector2(-6,0),Vector2(-9,8)]:
		triangle.append(point + v.rotated(heading))
	draw_colored_polygon(triangle,color)

func ring(point: Vector2, radius: float, color: Color) -> void:
	draw_arc(point,radius,0,TAU,40,color,2,true)

func shot(from: Vector2, to: Vector2, start: float, empowered := false) -> void:
	var t := (elapsed-start)/0.46
	if t<0 or t>1.45:return
	var color := BONUS if empowered else ALLY
	if t<=1:
		var tip := from.lerp(to,t)
		draw_line(tip,from.lerp(to,maxf(0,t-0.22)),color,3,true)
	else:
		ring(to,6+24*(t-1),color)

func focus_shots(boosted:bool) -> Array[float]:
	var shots:Array[float]=[]
	var next:=0.5
	var interval:float=GameData.get_unit("E1").weapon.cooldown
	var end:=0.5+float(GameData.get_skill("ap_focus_fire").duration)
	while next<duration:
		shots.append(next)
		next+=interval*(1.0-magnitude/100.0 if boosted and next<end else 1.0)
	return shots

func draw_focus() -> String:
	for row in 2:
		var origin:=Vector2(62,40+row*57)
		var target:=Vector2(286,origin.y)
		actor(origin,ALLY if row==1 else MUTED);actor(target,FOE,PI)
		var shots:=focus_shots(row==1)
		var fired:=0
		var last:=0.5
		var next:=0.5
		for time in shots:
			shot(origin,target,time)
			if time<=elapsed:fired+=1;last=time
			elif next<=elapsed:next=time
		var progress:=clampf((elapsed-last)/maxf(0.01,next-last),0,1) if elapsed>=0.5 else 0.0
		draw_rect(Rect2(origin+Vector2(-25,14),Vector2(50,4)),MUTED)
		draw_rect(Rect2(origin+Vector2(-25,14),Vector2(50*progress,4)),ALLY)
		draw_string(ThemeDB.fallback_font,Vector2(110,origin.y-11),("聚焦" if row==1 else "原装")+" · 已发射 %d 发"%fired,HORIZONTAL_ALIGNMENT_LEFT,-1,12,ALLY if row==1 else MUTED)
	return "武器 CD -"+caption+" · 单发伤害不变" if elapsed>=0.5 and elapsed<0.5+float(GameData.get_skill(card).duration) else "强化未生效／已结束 · 新装填恢复常速"

func commission_state() -> Dictionary:
	var goal:=int(GameData.get_skill(card).objective_by_rank[preview_rank])
	var count:=clampi(floori((elapsed-1.2)/0.8),0,goal)
	return {"goal":goal,"count":count,"lab":elapsed>=2.8,"unlocked":count>=goal}

func draw_commission() -> String:
	var state:=commission_state()
	var seal:=card=="ps_chrono_commission"
	var product:=GameData.get_unit("CCOMAND" if seal else "CIVAN")
	var lab:=Vector2(35,34)
	draw_rect(Rect2(lab-Vector2(14,12),Vector2(28,24)),ALLY if state.lab else MUTED,false,2)
	draw_line(lab-Vector2(8,0),lab+Vector2(8,0),ALLY,2)
	draw_string(ThemeDB.fallback_font,Vector2(58,38),"作战实验室就绪" if state.lab else "无需实验室即可累计",HORIZONTAL_ALIGNMENT_LEFT,-1,12,ALLY)
	actor(A,ALLY)
	if not state.unlocked:
		actor(B,FOE,PI)
		if elapsed>=1.2:
			var cycle:=floori((elapsed-1.2)/0.8)
			var start:=1.2+cycle*0.8
			if seal: shot(A,B,start+0.08)
			else:
				draw_dashed_line(A,B,MUTED)
				draw_circle(B-Vector2(0,18),5,BONUS)
				if elapsed-start>0.5: ring(B,8+(elapsed-start-0.5)*65,BONUS)
			if elapsed-start>0.65: draw_line(B-Vector2(9,9),B+Vector2(9,9),BONUS,2)
	else:
		ring(B,23,ALLY)
		actor(B,ALLY,0.0,false)
		draw_string(ThemeDB.fallback_font,Vector2(178,42),str(product.name),HORIZONTAL_ALIGNMENT_CENTER,155,13,BONUS)
	draw_rect(Rect2(110,94,180,7),MUTED)
	draw_rect(Rect2(110,94,180*float(state.count)/state.goal,7),BONUS)
	if state.unlocked: return "本局已解锁 · 实验室＋兵营可生产；也可窃取科技" if state.lab else "任务已达标 · 建成实验室后可生产"
	return "%s %d/%d · 许可装在超时空单位，普通单位执行" % ["海豹击杀" if seal else "伊文引爆",state.count,state.goal]

func _draw() -> void:
	sync_caster()
	draw_rect(Rect2(Vector2.ZERO,size),Color("#152331"))
	var scale_factor := minf(size.x/350.0,size.y/154.0)
	draw_set_transform((size-Vector2(350,154)*scale_factor)*0.5,0,Vector2.ONE*scale_factor)
	draw_line(Vector2(20,110),Vector2(330,110),MUTED,1)
	var text := ""
	if preload("res://scripts/ui/pool_research_demo.gd").supports(card):
		text=preload("res://scripts/ui/pool_research_demo.gd").paint(self)
		draw_string(ThemeDB.fallback_font,Vector2(12,138),text,HORIZONTAL_ALIGNMENT_CENTER,326,12,Color.WHITE)
		return
	if card in preload("res://scripts/ui/convoy_demo.gd").CARDS:
		text=preload("res://scripts/ui/convoy_demo.gd").card(self)
		draw_string(ThemeDB.fallback_font,Vector2(12,138),text,HORIZONTAL_ALIGNMENT_CENTER,326,12,Color.WHITE)
		return
	if GameData.get_skill(card).get("expansion",false):
		text=preload("res://scripts/ui/expansion_card_stage.gd").draw(self)
		draw_string(ThemeDB.fallback_font,Vector2(12,138),text,HORIZONTAL_ALIGNMENT_CENTER,326,12,Color.WHITE)
		return
	match card:
		"ap_bilge_repair":
			var point:=A+Vector2(elapsed*15,0)
			actor(point,ALLY)
			var progress:=clampf((elapsed-.5)/4,0,1)
			draw_rect(Rect2(point+Vector2(-27,24),Vector2(54,6)),MUTED)
			draw_rect(Rect2(point+Vector2(-27,24),Vector2(54*(.35+progress*magnitude/100),6)),Color("#62edb0"))
			if elapsed>=.5 and elapsed<4.5:
				var cross:=point+Vector2(0,-22-fmod(elapsed*8,10))
				draw_line(cross-Vector2(4,0),cross+Vector2(4,0),BONUS,2)
				draw_line(cross-Vector2(0,4),cross+Vector2(0,4),BONUS,2)
			text="航行抢修 · 已恢复 %s%%" % String.num(progress*magnitude,1)
		"ps_anchor_reload":
			var ready:=elapsed>=2 and elapsed<5
			var point:=A+Vector2(maxf(0,elapsed-5)*45,0)
			actor(point,ALLY);actor(B,FOE,PI)
			if ready:ring(point,23,BONUS)
			var next:=.2
			while next<5:
				shot(A,B,next,next>=2)
				next+=1.2*(1.0-magnitude/100 if next>=2 else 1.0)
			text="停稳 %.1f / 2 秒" % elapsed if elapsed<2 else ("稳射 · 装填缩短 "+caption if ready else "起航 · 稳射解除")
		"ap_wing_guard":
			var point:=A+Vector2(elapsed*20,-12)
			actor(point,ALLY);actor(B,FOE,PI)
			var active:=elapsed>=.5 and elapsed<3.5
			if active:
				for side in [-1,1]:draw_arc(point+Vector2(0,side*17),15,-.5,.5,12,ALLY,2)
			for i in 4:shot(B,point,.7+i,active)
			text="翼侧流线 · 减伤 "+caption if active else "防护未开启／已结束"
		"ps_cruise_scout":
			var moving:=elapsed<5
			var point:=A+Vector2(minf(elapsed,5)*25,-10)
			actor(point,ALLY)
			var ready:=elapsed>=2 and moving
			ring(point,35*(1.0+magnitude/100 if ready else 1.0),BONUS if ready else MUTED)
			text="巡航 %.1f / 2 秒" % elapsed if elapsed<2 else ("瞭望 · 视野 +"+caption if ready else "停止飞行 · 视野收回")
		"ap_decoy":
			var point := A + Vector2(0,-28*smoothstep(0.5,1.3,elapsed))
			actor(point,Color(ALLY,0.3) if elapsed>=0.5 and elapsed<2.5 else ALLY)
			actor(B,FOE,PI)
			if elapsed>=0.5 and elapsed<2.5:
				actor(A,Color(ALLY,(2.5-elapsed)/2))
				draw_dashed_line(A,point,MUTED)
			shot(point,B,2.5,true)
			shot(point,B,4.5)
			text = "离开原位 · 残影 2 秒" if elapsed<2.5 else ("Echo · 破隐首发 +"+caption if elapsed<4 else "首发已消耗")
		"ps_phase":
			actor(A,ALLY)
			actor(B,FOE,PI)
			var stacks:=mini(3,floori(elapsed/3.0))
			preload("res://scripts/ui/talent_stack_indicator.gd").paint(self,A,"稳流",stacks,3,22)
			for i in 11: shot(A,B,0.15+i,i>=3)
			text = "Flux　%d / 3 层　当前增伤 +%s%%" % [stacks,String.num(magnitude*stacks,2)]
		"ap_twin":
			actor(A,ALLY)
			actor(B,FOE,PI)
			var mount := A+Vector2(0,-14)
			draw_circle(mount,4,ALLY)
			draw_arc(A,56,-0.56,0.56,18,ALLY,1.2)
			draw_arc(mount,45,-0.4,0.5,18,MUTED,1.2)
			var card_def:=GameData.get_skill("ap_twin")
			var gun:Dictionary=GameData.get_unit("R3APOC").weapon
			var interval:=float(gun.burst_delay)
			var cycle:=interval+float(gun.cooldown)
			var window:float=card_def.twin_windows[preview_rank]
			var guaranteed:int=card_def.twin_hits[preview_rank]
			for pair in 3:
				var left:=0.4+cycle*pair
				shot(A,B,left)
				shot(mount,B,left+interval,pair<guaranteed or (pair==2 and preview_rank==2 and show_optional_hit))
			text="校射窗口　"+Unit.FactionCards.twin_summary(preview_rank)
			if elapsed>window+0.4: text="校射结束"
			elif preview_rank==2 and elapsed>=0.4+2*cycle: text=("第三发触发 · 全额 +"+caption) if show_optional_hit else "第三发未触发 · 原伤害"
		"ps_limiter":
			var point := A+Vector2(48*minf(elapsed/4.5,1),0)
			actor(point,ALLY)
			actor(B,FOE,PI)
			if elapsed>=3 and elapsed<4.5:ring(point,21,BONUS)
			shot(B,point,3.1)
			text = ("连续行驶 %.1f / 3 秒" % elapsed) if elapsed<3 else ("钢甲减伤 "+caption if elapsed<4.5 else "停车 · 防护解除")
		"ap_buoy":
			var buoy := B-Vector2(50,0)
			var active := elapsed>=0.8 and elapsed<0.8+magnitude
			actor(A,ALLY)
			shot(A,buoy,0.14)
			if active:
				draw_circle(buoy,5,BONUS)
				ring(buoy,54,ALLY)
				ring(buoy,fmod((elapsed-0.8)*48,54),MUTED)
				actor(B,FOE,PI)
			text = "投放搜索浮标" if elapsed<0.8 else ("圈内可见 · 剩余 %.1f 秒" % (0.8+magnitude-elapsed) if active else "浮标失效 · 潜艇脱离侦测")
		"ps_contact":
			var contact:=B+Vector2(-22,18*sin(elapsed*0.9))
			var expiry:=2.36+Unit.FactionCards.contact_seconds(preview_rank)
			var active:=elapsed>=0.86 and elapsed<expiry
			actor(A,ALLY)
			if active:
				draw_circle(contact,40,Color(ALLY,0.13))
				ring(contact,40,ALLY)
				actor(contact+Vector2(26,8),FOE,PI)
			actor(contact,FOE,PI)
			shot(A,contact,0.4)
			shot(A,contact,1.9,true)
			text = "首击标记 · 共享目标视野" if elapsed<0.86 else ("Ping · 共享视野剩 %.1f 秒" % (expiry-elapsed if elapsed>=2.36 else expiry-1.5-elapsed) if active else "通报结束 · 恢复己方视野")
			if elapsed>=0.86:
				text+=" · 冷却剩 %d 秒" % ceili(maxf(0,Unit.FactionCards.contact_cooldown(preview_rank)-(elapsed-0.86)))
		"ap_slope":
			var speed:=Unit.FactionCards.slope_speed(preview_rank)
			var drive_time:=float(GameData.get_skill("ap_slope").drive_seconds)
			var travel:=maxf(0,elapsed-2.2)
			var point:=A+Vector2(18*(travel+minf(travel,drive_time)*speed),0)
			actor(point,ALLY)
			actor(B,FOE,PI)
			if travel<drive_time: draw_arc(point,25,-PI/3,PI/3,25,BONUS,4,true)
			shot(B,point,0.6)
			shot(B,point,2.8)
			shot(B,point,4.5)
			text="原地迎击 · 正面减伤 "+caption
			if travel>0:
				text=("起步加速 %d%% · 正面防护剩 %.1f 秒" % [roundi(speed*100),drive_time-travel]) if travel<drive_time else "突进结束 · 恢复常速"
		"ps_barrage":
			actor(A,ALLY)
			var plane := B+Vector2(0,-21)
			actor(plane,FOE,PI)
			draw_dashed_line(B,plane,MUTED)
			for i in 3:
				shot(A,plane,0.4+i,i==2)
				draw_circle(Vector2(140+i*15,92),4,BONUS if elapsed>=0.86+i and elapsed<3.6 else MUTED)
			if elapsed>=3.6: actor(B+Vector2(14,11),FOE,PI)
			text = "连续命中同一空中目标" if elapsed<2.4 else ("Burst · 第三击 +"+caption if elapsed<3.6 else "切换目标 · 重新计数")
		"ap_tesla_chain":
			actor(A,ALLY)
			actor(B,FOE,PI)
			var near:=B+Vector2(-45,-35)
			var other:=B+Vector2(20,32)
			actor(near,FOE,PI);actor(other,FOE,PI)
			var rule:=GameData.get_skill("ap_tesla_chain")
			for i in 6:
				var fire:=0.2+i*1.6
				shot(A,B,fire,i<3 and preview_rank>0)
				if fire<float(rule.duration):
					shot(B,near,fire+0.46,true)
					shot(B,other,fire+0.46,true)
			text="前三次主伤 +%s%% · 每次分叉 %s%%" % [MetaProgress.Academy.skill_number(rule.primary_bonus_by_rank[preview_rank]*100),MetaProgress.Academy.skill_number(rule.branch_by_rank[preview_rank]*100)]
			if elapsed>=3.4:text="强化次数已用完 · 仍继续分叉 · 剩余 %.1f 秒" % maxf(0,float(rule.duration)-elapsed)
			if elapsed>=float(rule.duration):text="8 秒结束 · 恢复普通电击，无分叉"
		"ap_shock_pulse":
			actor(Vector2(175,73),ALLY)
			actor(A,FOE);actor(B,FOE,PI)
			ring(Vector2(175,73),minf(105,elapsed*120),ALLY)
			text="卧倒射程 · 攻击力×"+caption+" · 减速25% / 3秒"
		"ps_grounding":
			actor(A,ALLY);actor(B,FOE,PI)
			var port:=A+Vector2(0,-22)
			actor(port,ALLY,0.0,false)
			shot(A,B,0.2);shot(port,B,1.0,true);shot(A,B,1.8)
			text="不同乘员协同 +"+caption if elapsed<1.6 else ("同目标冷却 3 秒 · 不叠层" if elapsed<4 else "等待新的双乘员命中")
		"ps_aftercurrent":
			var point:=B.lerp(A,clampf(elapsed/3.5,0,1))
			actor(point,ALLY,PI)
			draw_rect(Rect2(A-Vector2(17,12),Vector2(34,24)),MUTED,false,2)
			draw_dashed_line(point,A,ALLY)
			text="空弹返航加速 "+caption if elapsed<3.5 else "已落地 · 加速结束 · 正常装填"
		"reaper_split_fire":
			actor(A,ALLY);actor(B,FOE,PI)
			var other:=Vector2(280,108)
			actor(other,FOE,PI);shot(A,B,0.2);shot(A,other,0.6,true)
			text="W 指定副目标 · 侧炮伤害 "+caption
		"ps_chrono_commission", "ps_chrono_sabotage":
			text=draw_commission()
		"ap_smoke", "ps_armor_plating":
			var active:=card=="ps_armor_plating" or (elapsed>=0.5 and elapsed<0.5+float(GameData.get_skill(card).duration))
			actor(A,ALLY);actor(B,FOE,PI)
			if active:
				ring(A,24,BONUS)
				if card=="ap_smoke":
					for i in 6: draw_circle(A+Vector2(cos(i+elapsed)*19,sin(i+elapsed)*12),9,Color(MUTED,0.28))
			for i in ceili(duration): shot(B,A,0.3+i,active)
			text="防护中 · 受到伤害 -"+caption if active else "烟幕未生效／已结束 · 正常受伤"
		"ap_overdrive":
			var active:=elapsed>=0.5 and elapsed<0.5+float(GameData.get_skill(card).duration)
			var normal:=A+Vector2(elapsed*22,-22)
			var boosted:=A+Vector2(elapsed*22+clampf(elapsed-0.5,0,float(GameData.get_skill(card).duration))*22*magnitude/100,20)
			actor(normal,MUTED);actor(boosted,ALLY)
			if active: draw_dashed_line(A+Vector2(0,20),boosted,BONUS)
			text="常速对照 · 超载加速 +"+caption if active else "超载未生效／已结束 · 恢复常速"
		"ap_focus_fire":
			text=draw_focus()
		"ps_hollow_point":
			actor(A,ALLY);actor(B,FOE,PI)
			for i in ceili(duration): shot(A,B,0.3+i,true)
			text="单发伤害 +"+caption+" · 装填速度不变"
		_:
			actor(A,ALLY);actor(B,FOE,PI)
			text="这张卡的效果随等级变化，详情见下方说明"
	draw_string(ThemeDB.fallback_font,Vector2(12,138),text,HORIZONTAL_ALIGNMENT_CENTER,326,14,Color.WHITE)
