extends Control
## Two synchronized, isolated visual lanes. Numbers come from the actual training
## formulas; only presentation time is compressed for long fuses/cooldowns.
const Training=preload("res://scripts/rules/skill_training.gd")
const Pounce=preload("res://scripts/units/dog_pounce.gd")
const Leap=preload("res://scripts/units/ra3_reaper_leap.gd")
const BLUE=Color("#71d8ff")
const GOLD=Color("#ffd47c")
const RED=Color("#ff8b76")
const GREEN=Color("#b5f473")
const DIM=Color("#6c8294")
const ORIGIN=Vector2(100,92)
const TARGET=Vector2(390,92)
const LOGICAL=Vector2(560,340)

class ModelView extends "res://scripts/ui/unit_showcase.gd":
	func _process(_dt:float) -> void:pass
	func _animate() -> void:pass
	func _draw() -> void:pass
	func _visibility() -> void:
		super._visibility()
		if actor!=null:actor.process_mode=Node.PROCESS_MODE_DISABLED
	func pose(point:Vector2,clock:float,moving:bool,fire:float,deployed:bool,alpha:float) -> void:
		if actor==null:return
		actor.process_mode=Node.PROCESS_MODE_DISABLED
		actor.position=viewport.canvas_transform.affine_inverse()*point
		# Convert horizontal screen aim back to the world-facing system.
		var heading:=(viewport.canvas_transform.affine_inverse().basis_xform(Vector2.RIGHT)).angle()
		actor.hull_angle=heading;actor.turret_angle=heading;actor.aim_dir=Vector2.from_angle(heading)
		actor._anim=clock;actor._walk_phase=fposmod(clock*1.4,1)
		actor.velocity=Vector2.from_angle(heading)*42 if moving else Vector2.ZERO
		actor._fire_anim_time=fire;actor._muzzle=maxf(0,0.12-fire) if fire>=0 else 0
		actor._deployed=deployed
		actor.modulate=Color(1,1,1,alpha);actor.queue_redraw()

var unit_id:=""
var profile:=""
var rank:=0
var elapsed:=0.0
var playing:=true
var playback_speed:=1.0
var models:Array=[]
var overlay:Control

func _ready() -> void:
	custom_minimum_size=LOGICAL
	clip_contents=true;mouse_filter=Control.MOUSE_FILTER_IGNORE
	for i in 2:
		var model:=ModelView.new();add_child(model);models.append(model)
		model.custom_minimum_size=Vector2.ZERO
		model.viewport.size=Vector2i(560,145)
		model.stretch_mode=TextureRect.STRETCH_SCALE
	overlay=Control.new();overlay.mouse_filter=Control.MOUSE_FILTER_IGNORE;add_child(overlay)
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.draw.connect(draw_overlay)
	resized.connect(layout)
	visibility_changed.connect(func():set_process(is_visible_in_tree()))

func configure(id:String) -> void:
	unit_id=id;profile=str(Training.PROFILES[id][0][0])
	for model in models:
		model.show_unit(id)
		model.actor.set_physics_process(false)
		model.actor.selected=false
		model.actor.trial={"skin":"stock","paint":"stock","weapon":"stock","top":"stock","wing":"stock","tail":"stock","track":"stock"}
		model.refresh_outfit()
		# The battlefield field compositor needs a scene-color background. This
		# comparison uses its own coverage overlay, not an uninitialized viewport.
		var field_fx=model.actor.get_node_or_null("Ra3MirageFx")
		if field_fx!=null:field_fx.hide()
		model.viewport.size=Vector2i(560,145)
		# Keep only visual model nodes; no global targeting/AI membership.
		for group in model.actor.get_groups():model.actor.remove_from_group(group)
	layout();refresh()

func layout() -> void:
	var factor:=size.x/LOGICAL.x
	for i in models.size():
		models[i].position=Vector2(0,24+i*156)*factor
		models[i].size=Vector2(560,145)*factor

func value(level:int) -> float:
	var spec:Array=Training.PROFILES[unit_id][0]
	return Training.projected(Training.base_value(unit_id,profile),str(spec[2]),1.0 if level<0 else 1.3+level*0.3)

func time_rate() -> float:
	return maxf(1,Training.base_value(unit_id,profile)/4.0) if profile in ["fuse","riot","mcv"] else 1.0

func period() -> float:
	if profile=="attack_cd":return 2*(Pounce.LEAP_SECONDS+Training.base_value(unit_id,profile))+4
	if profile in ["fuse","riot","mcv"]:return Training.base_value(unit_id,profile)+3*time_rate()
	return 8.0

func _process(delta:float) -> void:
	if unit_id.is_empty() or not playing:return
	elapsed=fposmod(elapsed+delta*time_rate()*playback_speed,period())
	refresh()

func sample(level:int) -> Dictionary:
	var v:=value(level)
	var s:={"at":ORIGIN,"target":TARGET,"moving":false,"fire":-1.0,"deployed":false,"alpha":1.0,"phase":"","hit":false,"progress":0.0,"amount":v,"clock":elapsed,"target_hp":1.0}
	var t:=elapsed
	match profile:
		"attack_cd":
			var combat_end:=period()-2.0
			if t<combat_end:
				var cycle:=Pounce.LEAP_SECONDS+v
				var part:=fposmod(maxf(0,t-0.6),cycle)
				var leap:=t>=0.6 and part<Pounce.LEAP_SECONDS
				var p:=clampf(part/Pounce.LEAP_SECONDS,0,1)
				s.at=ORIGIN.lerp(TARGET-Vector2(20,0),p) if leap else (ORIGIN if t<0.6 else TARGET-Vector2(20,0))
				if leap:s.at.y-=sin(p*PI)*30
				s.moving=leap;s.fire=part if leap else -1.0
				s.hit=t>=0.6 and part>=Pounce.LEAP_SECONDS and part<Pounce.LEAP_SECONDS+0.25
				s.target_hp=1.0 if leap or t<0.6 else 0.0
				s.progress=clampf((part-Pounce.LEAP_SECONDS)/maxf(0.001,v),0,1)
				s.phase="扑向目标 · 接触命中" if leap else ("准备扑击" if t<0.6 else "命中后等待 %.2f 秒" % v)
			else:
				var front:=t<combat_end+1
				var defense:=1.0 if level<0 else 1.0+0.1*(level+1)
				s.target=Vector2(210,80) if front else Vector2(25,108)
				s.hit=fposmod(t-combat_end,1)>0.3
				s.target_hp=(100.0/defense if front else 100.0)/100.0
				s.phase=("正面 120° · 100 伤害 → %.1f" % (100/defense)) if front else "侧后方 · 100 伤害 → 100"
		"deploy_def":
			s.deployed=t>=1 and t<6;s.hit=t>=2 and t<5.5
			s.target_hp=clampf(1-(maxf(0,t-2)*0.12/v if s.deployed else 0),0,1)
			s.phase="部署 · 防御 ×%.2f" % v if s.deployed else "起身 · 部署防护不生效"
		"chrono_time":
			var wait:=3.0*v
			s.at=ORIGIN if t<0.7 else Vector2(265,92)
			s.alpha=0.3 if t>=0.5 and t<0.8 else 1.0
			s.progress=clampf((t-0.8)/wait,0,1)
			s.fire=fposmod(t-0.8-wait,0.8) if t>=0.8+wait else -1.0
			s.phase="传送残影 → 恢复中 %.1f 秒" % maxf(0,wait-t+0.8) if s.fire<0 else "恢复完成 · 可以开火"
		"siege_range":
			s.at=Vector2(190,92)
			s.deployed=t>1;s.fire=fposmod(t-2,1) if t>2 else -1.0
			s.progress=v/2.0;s.phase="降落部署 → 射程额外 +%.1f 格" % v
		"radiation":
			s.deployed=t>=1 and t<6;s.progress=clampf((t-1)/0.8,0,1) if s.deployed else 0.0
			s.target_hp=clampf(1-maxf(0,minf(t,6)-1)*0.1*(1+v*0.01),0,1)
			s.phase="持续辐射 · 伤害 +%.1f%%（范围不变）" % v if s.deployed else "起身 · 停止辐射"
		"fuse":
			s.at=ORIGIN.lerp(TARGET-Vector2(20,0),clampf(t/time_rate(),0,1))
			s.moving=t<time_rate();s.progress=clampf((t-time_rate())/v,0,1)
			s.hit=t>=time_rate()+v;s.target_hp=0 if s.hit else 1
			s.phase="安置炸弹" if t<time_rate() else ("引爆" if s.hit else "引信剩余 %.1f 秒" % maxf(0,v-t+time_rate()))
		"arrival":
			var wait:=4.0*v
			s.progress=clampf((t-1)/wait,0,1);s.hit=t>1+wait
			s.phase="激光指示 · 米格接近" if not s.hit else "米格抵达 · 投弹"
		"mcv":
			var start:=time_rate();s.progress=clampf((t-start)/v,0,1)
			s.alpha=1-s.progress;s.deployed=s.progress>=1
			s.phase="车形态 · 防御 +%d%%" % (0 if level<0 else 10*(level+1)) if t<start else ("展开完成 · 车形态防护失效" if s.deployed else "展开中 · %.2f / %.2f 秒" % [maxf(0,t-start),v])
		"prism":
			s.fire=fposmod(maxf(0,t-1),1.5) if t>1 else -1.0;s.hit=s.fire>=0 and s.fire<0.4
			s.phase="主光束命中 → 分裂光束 ×%.2f（单束受主炮上限约束）" % v
		"field","emp":
			s.at=Vector2(230,92)
			s.deployed=t>1 and t<6;s.progress=smoothstep(1,2,t)*(1-smoothstep(6,7,t))
			s.phase=("展开 → 友军进入隐形范围" if profile=="field" else "切换磁场 → 邻近敌军瘫痪") if t<6 else "收起 → 效果结束"
		"riot":
			s.fire=t if t<time_rate() else -1.0;s.progress=clampf((t-time_rate())/v,0,1)
			s.hit=t<time_rate() or t>=time_rate()+v
			s.phase="暴乱横扫" if s.hit else "冷却 %.1f / %.1f 秒" % [maxf(0,v-t+time_rate()),v]
		"drag":
			s.progress=clampf((t-1)*v/300.0,0,1);s.target=TARGET.lerp(ORIGIN+Vector2(65,0),s.progress)
			s.phase="磁力鱼叉牵引 · %.0f 像素/秒" % v if s.progress<1 else "贴身研磨"
		"leap":
			var takeoff:=Leap.TAKEOFF_SECONDS
			var p:=clampf((t-1-takeoff)/1.1,0,1)
			s.at=ORIGIN.lerp(Vector2(305,92),p);s.at.y-=sin(p*PI)*68
			s.deployed=p>=1;s.progress=clampf((t-1-takeoff-1.1)/0.6,0,1)
			s.phase="收腿准备 → 跳跃" if not s.deployed else "落地部署 · 伤害半径 %.1f" % v
	return s

func refresh() -> void:
	if unit_id.is_empty():return
	for i in 2:
		var s:=sample(-1 if i==0 else rank)
		models[i].pose(s.at,elapsed,s.moving,s.fire,s.deployed,s.alpha)
		var a=models[i].actor
		if profile=="siege_range":
			preload("res://scripts/units/siege_chopper.gd").appearance(a,"SCHD" if s.deployed else "SCHP")
			a.logistics.air_lift=0.0
		a.special.erase("walker_jump");a.special.erase("walker_deployed")
		if profile=="leap":
			if elapsed>1 and not s.deployed:a.special.walker_jump={"age":elapsed-1,"takeoff_seconds":Leap.TAKEOFF_SECONDS,"flight":1.1}
			a.special.walker_deployed=s.deployed
		elif profile in ["drag","emp"]:a.special.soviet_mode=elapsed>1 and elapsed<6
		if a._ra3_model!=null:a._ra3_model.sync_pose()
	overlay.queue_redraw()

func explanation() -> String:
	match profile:
		"attack_cd":return "扑击接触目标才命中；天赋缩短两次扑咬间隔，不改变跳跃飞行速度。正面 120° 有防护，侧后方无此加成。"
		"chrono_time":return "演示固定传送距离，原恢复需 3 秒；上下两组使用相同距离。"
		"arrival":return "演示固定米格入场距离，原等待 4 秒；只缩短抵达等待，不缩短返航或再充能。"
		"mcv":return "车形态防护在展开为建筑后失效；上下两组比较相同展开过程。"
		"prism":return "仅强化分裂光束，主光束不增伤；单条分裂光束仍受主光束伤害上限约束。"
		"field","emp","leap":return "灰圈为未强化范围，彩色圈为当前等级范围；目标是否被覆盖随等级变化。"
	return "上方未强化，下方使用所选等级。演示读取当前战斗公式，长引信／冷却按标注倍速展示；不会改变存档或战斗状态。"

func text(at:Vector2,line:String,color:=Color.WHITE,font_size:=13) -> void:
	overlay.draw_string(ThemeDB.fallback_font,at,line,HORIZONTAL_ALIGNMENT_LEFT,-1,font_size,color)

func sprite(id:String,at:Vector2,alpha:=1.0,sequence:="Guard",clock:=0.0,scale_factor:=1.5) -> void:
	var art:=RA2Art.art(id)
	if art.is_empty():return
	var seq:=RA2Art.seq(id)
	var frame:=maxi(0,RA2Art.seq_frame(seq,sequence,2,int(clock*16)))
	var rect:=RA2Art.draw_rect(art,0,[frame],0,scale_factor);rect.position+=at
	RA2Art.draw_sprite(overlay,art,rect,RA2Art.src_rect(art,frame),Color(1,1,1,alpha))

func ring(at:Vector2,radius:float,color:Color) -> void:
	var points:=PackedVector2Array()
	for i in 65:points.append(at+Vector2.from_angle(i*TAU/64.0)*Vector2(radius,radius*0.4))
	overlay.draw_polyline(points,color,1.8,true)

func bar(at:Vector2,progress:float,color:Color,width:=85.0) -> void:
	overlay.draw_rect(Rect2(at,Vector2(width,5)),Color("#384955"))
	overlay.draw_rect(Rect2(at,Vector2(width*clampf(progress,0,1),5)),color)

func burst(at:Vector2,t:float,color:Color) -> void:
	var p:=fposmod(t,0.6)/0.6
	for j in 8:
		var direction:=Vector2.from_angle(j*TAU/8)
		overlay.draw_line(at+direction*(4+p*9),at+direction*(10+p*18),Color(color,1-p),2,true)

func beam(from:Vector2,to:Vector2,color:Color) -> void:
	overlay.draw_line(from,to,Color(color,0.2),7,true)
	overlay.draw_line(from,to,color,2,true)

func draw_overlay() -> void:
	if unit_id.is_empty():return
	var factor:=size.x/LOGICAL.x
	for lane in 2:
		overlay.draw_set_transform(Vector2(0,24+lane*156)*factor,0,Vector2.ONE*factor)
		var s:=sample(-1 if lane==0 else rank)
		var color:=DIM if lane==0 else BLUE
		text(Vector2(8,0),"未强化" if lane==0 else "天赋 Lv.%d" % rank,color,15)
		if time_rate()>1:text(Vector2(370,0),"演示 ×%.1f 倍速" % time_rate(),DIM)
		overlay.draw_line(Vector2(15,99),Vector2(540,99),Color(0.3,0.4,0.5,0.3),1)
		var t:=elapsed
		match profile:
			"attack_cd":
				if t<period()-2:
					if s.target_hp>0:sprite("E2" if unit_id=="DOG" else "E1",TARGET)
					if s.hit:burst(TARGET-Vector2(0,18),t,RED)
					bar(Vector2(285,110),s.progress,color)
				else:
					sprite("E2",s.target)
					var fan:=PackedVector2Array([ORIGIN])
					for i in 25:fan.append(ORIGIN+Vector2.from_angle(-PI/3+i*PI/36)*Vector2(66,35))
					overlay.draw_colored_polygon(fan,Color(color,0.18))
					if s.hit:beam(s.target-Vector2(0,18),ORIGIN-Vector2(0,12),RED);burst(ORIGIN-Vector2(0,12),t,color)
					bar(Vector2(70,112),1-s.target_hp*0.5,color)
			"deploy_def":
				sprite("E2",TARGET)
				if s.hit:
					var bullet:=TARGET.lerp(ORIGIN,fposmod(t*2,1))
					overlay.draw_circle(bullet-Vector2(0,12),3,RED)
					if s.deployed:ring(ORIGIN,34,color)
				bar(Vector2(65,112),s.target_hp,color)
			"chrono_time":
				sprite("HTNK",TARGET,1,"Guard",0,0.8)
				if t>=0.5 and t<1.2:ring(ORIGIN,22+(t-0.5)*28,color);ring(Vector2(265,92),25,color)
				bar(Vector2(220,112),s.progress,color)
				if s.fire>=0:beam(s.at-Vector2(0,25),TARGET-Vector2(0,18),color)
			"siege_range":
				var radius:=125+float(s.amount)*25
				if s.deployed:ring(s.at,125,DIM);ring(s.at,radius,color)
				var target:Vector2=s.at+Vector2(168,0)
				sprite("HTNK",target,1,"Guard",0,0.7)
				if s.fire>=0 and radius>=168 and s.fire<0.35:beam(s.at-Vector2(0,15),target-Vector2(0,8),GOLD);burst(target,s.fire,GOLD)
			"radiation":
				var target:=ORIGIN+Vector2(110,0);sprite("HTNK",target,1,"Guard",0,0.7)
				if s.deployed:
					for j in 3:ring(ORIGIN,(85+fposmod(t+j*0.3,1)*55)*s.progress,Color(GREEN,0.7))
				bar(target+Vector2(-30,-45),s.target_hp,GREEN)
			"fuse":
				sprite("GAPOWR",TARGET,0.2 if s.hit else 1,"Guard",0,0.35)
				if t>=time_rate() and not s.hit:
					overlay.draw_circle(TARGET-Vector2(0,30),6,RED if int(t*3)%2 else GOLD)
					bar(Vector2(345,112),s.progress,RED)
				if s.hit:burst(TARGET-Vector2(0,25),t-time_rate()-s.amount,GOLD)
			"arrival":
				sprite("GAPOWR",TARGET,1,"Guard",0,0.35)
				if t>1:beam(ORIGIN-Vector2(0,18),TARGET-Vector2(0,30),RED)
				var plane:=Vector2(535,10).lerp(TARGET-Vector2(0,35),s.progress)
				sprite("MIG",plane,1,"Guard",0,0.65)
				if s.hit:burst(TARGET-Vector2(0,20),t,GOLD)
			"mcv":
				if s.progress>0:sprite("GACNST" if unit_id=="AMCV" else "NACNST",ORIGIN,s.progress,"Guard",0,0.35)
				bar(Vector2(60,112),s.progress,color)
				if t<time_rate():ring(ORIGIN,55,color)
			"prism":
				sprite("HTNK",TARGET,1,"Guard",0,0.7)
				for pos in [Vector2(485,48),Vector2(480,110)]:sprite("HTNK",pos,1,"Guard",0,0.6)
				if s.hit:
					beam(ORIGIN-Vector2(0,35),TARGET-Vector2(0,16),BLUE)
					for pos in [Vector2(485,48),Vector2(480,110)]:beam(TARGET-Vector2(0,16),pos-Vector2(0,10),color);burst(pos,t,GOLD)
					text(Vector2(440,88),"Split ×%.2f" % s.amount,color)
			"field","emp":
				var base:=Training.base_value(unit_id,profile);var radius:=float(s.amount)/base*74
				ring(s.at,74,DIM)
				if s.progress>0:ring(s.at,radius*s.progress,color)
				for dist in [58,110,150]:
					var covered:bool=s.progress>0.9 and dist<=radius
					var pos:Vector2=s.at+Vector2(dist,5)
					sprite("MTNK",pos,0.25 if profile=="field" and covered else 1,"Guard",0,0.65)
					if profile=="emp" and covered:burst(pos-Vector2(0,15),t,color)
			"riot":
				for pos in [Vector2(340,65),Vector2(390,92),Vector2(450,115)]:sprite("HTNK",pos,1,"Guard",0,0.7)
				if s.hit:beam(ORIGIN-Vector2(0,25),Vector2(320+fposmod(t,1)*150,55+fposmod(t,1)*65),GOLD)
				bar(Vector2(220,110),s.progress,color,190)
			"drag":
				sprite("MTNK",s.target,1,"Guard",0,0.7)
				if t>=1:beam(ORIGIN-Vector2(0,26),s.target-Vector2(0,18),GREEN)
				if s.progress>=1:burst(s.target,t,GOLD)
			"leap":
				var landing:=Vector2(305,92)
				ring(landing,45,DIM)
				for dist in [35,70,92]:sprite("E2",landing+Vector2(dist,0),1,"Guard",0,1.2)
				if s.deployed:
					var radius:float=s.amount*0.6
					ring(landing,radius*s.progress,GOLD)
					for dist in [35,70,92]:
						if dist<=radius:burst(landing+Vector2(dist,-12),t,GOLD)
		text(Vector2(8,139),s.phase,color,12)
	overlay.draw_set_transform(Vector2.ZERO)
