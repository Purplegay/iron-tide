extends VBoxContainer
## Read-only illustration. Sprites are drawn directly; no battle actors or orders are created.
const Academy=preload("res://scripts/rules/academy.gd")
const THREATS := ["DOG","DRON","HTNK","DESO","TERROR","CLEG"]
const ATTACKS := ["犬扑","恐怖机器人扑击","履带碾压","辐射致命一击","恐怖分子自爆","超时空擦除"]
const WARHEADS := ["ParasiteDog","YR_SOV_Parasite","","RadSite","YR_SOV_TerrorBombWH",""]
const PERIOD := 6.0
var hero_id:=""
var talent:=OptionButton.new()
var levels:=OptionButton.new()
var pause_button:Button
var stage:=Control.new()
var caption:=Label.new()
var elapsed:=0.0
var playing:=true
var playback_speed:=1.0
var playback:Control
var revival_status:Label

func _ready() -> void:
	add_child(UiKit.make_label("英雄专属天赋演示",18,UiKit.COL_ACCENT_2))
	var bar:=HBoxContainer.new()
	add_child(bar)
	talent.add_item("随行护卫")
	talent.add_item("战场生存")
	bar.add_child(talent)
	bar.add_child(levels)
	pause_button=UiKit.make_button("暂停")
	bar.add_child(pause_button)
	var replay:=UiKit.make_button("重播")
	bar.add_child(replay)
	stage.custom_minimum_size.y=148
	stage.clip_contents=true
	add_child(stage)
	revival_status=UiKit.make_label("",20,UiKit.COL_ACCENT_2)
	revival_status.name="RevivalCountdown"
	add_child(revival_status)
	playback=preload("res://scripts/ui/demo_playback.gd").new();add_child(playback)
	playback.bind(self,&"elapsed",duration,refresh_preview,pause_button)
	caption.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	add_child(caption)
	stage.draw.connect(_draw_demo)
	talent.item_selected.connect(func(_i): _select_talent())
	levels.item_selected.connect(func(_i): restart())
	pause_button.pressed.connect(func():
		playing=not playing
		pause_button.text="暂停" if playing else "继续")
	replay.pressed.connect(restart)
	visibility_changed.connect(func(): set_process(is_visible_in_tree()))
	set_process(is_visible_in_tree())

func show_hero(id:String) -> void:
	if hero_id==id:return
	hero_id=id
	stage.custom_minimum_size.y=184 if id=="TTNK" else 148
	stage.material=preload("res://scripts/units/leizhu_art.gd").preview_material() if id=="TTNK" else null
	if id=="ORCA":stage.material=preload("res://scripts/units/peregrine_art.gd").preview_material()
	stage.texture_filter=CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS if id in ["TTNK","ORCA"] else CanvasItem.TEXTURE_FILTER_PARENT_NODE
	var tank:=id in Unit.TankHero.IDS
	talent.set_item_text(0,"战术中枢" if tank else "随行护卫")
	talent.set_item_text(1,"重装生存" if tank else "战场生存")
	if id in Academy.Stars.IDS:
		for i in 2:talent.set_item_text(i,Academy.Stars.TITLES[id][i])
	if id in Unit.Convoy.IDs:
		for i in 2:talent.set_item_text(i,Unit.Convoy.Talents.TITLES[id][i])
	if id in Academy.Commandos.IDS:
		for i in 2:talent.set_item_text(i,Academy.Commandos.TITLES[id][i])
	if id=="ORCA":
		for i in 2:talent.set_item_text(i,preload("res://scripts/units/peregrine.gd").TITLES[i])
	if id=="TTNK":
		for i in 2:talent.set_item_text(i,preload("res://scripts/units/leizhu.gd").TITLES[i])
	_select_talent()

func _select_talent() -> void:
	var escorts:=talent.selected==0
	var count:=Academy.ESCORT_RANKS.size() if escorts else Academy.SURVIVAL_STAGES.size()
	if hero_id in Academy.Commandos.IDS or hero_id in Unit.Convoy.IDs:count=6
	if hero_id=="ORCA":count=6 if escorts else preload("res://scripts/units/peregrine_defense.gd").OPEN_RANK+1
	if hero_id=="TTNK":count=(preload("res://scripts/units/leizhu_command.gd").OPEN_RANK if escorts else preload("res://scripts/units/leizhu.gd").OPEN_RANK)+1
	if hero_id in Academy.Stars.IDS:count=3
	levels.clear()
	for i in count: levels.add_item("预览 Lv.%d" % i)
	var key:="hero_escort_ranks" if escorts else "hero_survival_ranks"
	levels.select(clampi(int(MetaProgress.academy.get(key,{}).get(hero_id,0)),0,count-1))
	restart()

func restart() -> void:
	elapsed=0.0
	playing=true
	pause_button.text="暂停"
	refresh_caption()
	playback.sync()

func refresh_caption() -> void:
	var rank:=levels.selected
	if hero_id in Academy.Stars.IDS:
		caption.text=Academy.Stars.TRAITS[hero_id][talent.selected][rank]
		refresh_preview();return
	if hero_id in Unit.Convoy.IDs:
		caption.text="Lv.%d　%s"%[rank,Unit.Convoy.Talents.TRAITS[hero_id][talent.selected][rank]]
		refresh_preview();return
	if hero_id=="TTNK":
		caption.text="Lv.%d　%s 此前各级效果同时生效。"%[rank,(preload("res://scripts/units/leizhu_command.gd").COMMAND if talent.selected==0 else preload("res://scripts/units/leizhu_defense.gd").DEFENSE)[rank]]
		refresh_preview();return
	if hero_id=="ORCA":
		caption.text="Lv.%d　%s 空中补弹 %d 秒/发；此前各级效果同时生效。"%[rank,preload("res://scripts/units/peregrine_command.gd").COMMAND[rank],8-rank] if talent.selected==0 else "Lv.%d　%s 此前各级效果同时生效。"%[rank,preload("res://scripts/units/peregrine_defense.gd").DEFENSE[rank]]
		refresh_preview();return
	if hero_id in Academy.Commandos.IDS:
		if hero_id=="TANY":caption.text="Lv.%d　%s 此前各级效果同时生效。"%[rank,(preload("res://scripts/units/tanya_talents.gd").COMMAND if talent.selected==0 else preload("res://scripts/units/tanya_talents.gd").DEFENSE)[rank]]
		elif talent.selected==0:caption.text="Lv.%d　%s 此前各级效果同时生效。"%[rank,preload("res://scripts/units/boris_command.gd").COMMAND[rank]]
		else:caption.text="Lv.%d　%s 此前各级效果同时生效。"%[rank,preload("res://scripts/units/boris_radio.gd").DEFENSE[rank]]
	elif hero_id in Unit.TankHero.IDS:
		caption.text="Lv.%d　%s。此前各级效果同时生效。" % [rank,(Unit.TankHero.COMMAND if talent.selected==0 else Unit.TankHero.DEFENSE)[rank]]
	elif talent.selected==0:
		caption.text="%s出厂，%s随队前往集结点。" % [Academy.HEROES[hero_id],Academy.escort_description(rank)]
	else:
		caption.text="Lv.%d 新增效果　%s。此前各级效果同时生效。" % [rank,Academy.SURVIVAL_STAGES[rank]]
	refresh_preview()

func is_revival_demo() -> bool:
	return hero_id in Unit.TankHero.IDS and talent.selected==0 and levels.selected==1

func duration() -> float:
	if hero_id=="ORCA" and talent.selected==0 and levels.selected==5:return preload("res://scripts/ui/peregrine_split_demo.gd").LENGTH
	if hero_id=="ORCA" and talent.selected==1 and levels.selected in [1,3]:return preload("res://scripts/ui/peregrine_cycle_defense_demo.gd").duration(levels.selected)
	if hero_id=="ORCA" and ((talent.selected==0 and levels.selected==4) or (talent.selected==1 and levels.selected==0)):return preload("res://scripts/ui/peregrine_formation_demo.gd").LENGTH
	if hero_id=="ORCA" and talent.selected==0 and levels.selected in [0,2,3]:return preload("res://scripts/ui/peregrine_sensor_demo.gd").duration(levels.selected)
	if hero_id=="BORIS" and talent.selected==1 and levels.selected in [1,5]:return preload("res://scripts/ui/boris_lethal_demo.gd").duration(levels.selected)
	if hero_id=="BORIS" and talent.selected==1 and levels.selected in [3,4]:return preload("res://scripts/ui/boris_support_demo.gd").duration(levels.selected)
	if hero_id=="BORIS" and talent.selected==0 and levels.selected in [1,4]:return preload("res://scripts/ui/boris_rifle_demo.gd").duration(levels.selected)
	if hero_id=="TANY" and talent.selected==1 and levels.selected>=3:return preload("res://scripts/ui/tanya_survival_demo.gd").duration(levels.selected)
	if hero_id=="TANY" and talent.selected==0 and levels.selected in [3,4]:return preload("res://scripts/ui/tanya_assault_demo.gd").duration(levels.selected)
	if hero_id=="TANY" and talent.selected==0 and levels.selected in [1,2]:return preload("res://scripts/ui/tanya_target_demo.gd").duration(levels.selected)
	if hero_id=="TANY" and talent.selected==0 and levels.selected==5:return preload("res://scripts/ui/tanya_chain_demo.gd").LENGTH
	if hero_id=="TANY" and talent.selected==1 and levels.selected<=1:return preload("res://scripts/ui/tanya_damage_demo.gd").BASE_LENGTH if levels.selected==0 else preload("res://scripts/ui/tanya_damage_demo.gd").HUNTER_LENGTH
	if hero_id=="BORIS" and talent.selected==0 and levels.selected in [2,3,5]:return preload("res://scripts/ui/boris_air_support_demo.gd").duration(levels.selected)
	if hero_id=="BORIS" and talent.selected==1 and levels.selected==2:return preload("res://scripts/ui/boris_control_demo.gd").LENGTH
	if hero_id=="ORCA" and talent.selected==0 and levels.selected==1:return preload("res://scripts/ui/peregrine_reload_demo.gd").MOUNT_LENGTH
	if hero_id=="ORCA" and talent.selected==1 and levels.selected==2:return preload("res://scripts/ui/peregrine_reload_demo.gd").SIGNATURE_LENGTH
	if hero_id=="TANY" and talent.selected==1 and levels.selected==2:return preload("res://scripts/ui/tanya_swim_demo.gd").LENGTH
	if hero_id=="TTNK" and talent.selected==1 and levels.selected>=4:return preload("res://scripts/ui/leizhu_safety_demo.gd").duration(levels.selected)
	if hero_id=="TTNK" and talent.selected==1:return 24.0 if levels.selected==0 else 12.0 if levels.selected==3 else preload("res://scripts/ui/leizhu_defense_demo.gd").duration(levels.selected)
	if hero_id=="TTNK" and talent.selected==0 and levels.selected>0:return 16.0 if levels.selected==4 else 12.0
	if hero_id=="ORCA" and talent.selected==1 and levels.selected==4:return preload("res://scripts/ui/peregrine_maintenance_demo.gd").LENGTH
	if hero_id=="ORCA" and talent.selected==1 and levels.selected==5:return preload("res://scripts/ui/peregrine_crash_demo.gd").LENGTH
	return Unit.TankHero.REVIVE_SECONDS+2.0 if is_revival_demo() else PERIOD

func refresh_preview() -> void:
	var peregrine_repair:=hero_id=="ORCA" and talent.selected==1 and levels.selected==5
	revival_status.visible=is_revival_demo() or peregrine_repair
	if peregrine_repair:
		revival_status.text=preload("res://scripts/ui/peregrine_crash_demo.gd").caption(elapsed)
		stage.queue_redraw();return
	if revival_status.visible:
		revival_status.text=preload("res://scripts/ui/revival_indicator.gd").caption(Unit.TankHero.REVIVE_SECONDS-elapsed) if elapsed<Unit.TankHero.REVIVE_SECONDS else "已复活 · 本局次数已用"
	stage.queue_redraw()

func _process(dt:float) -> void:
	if hero_id.is_empty() or not playing:return
	elapsed=fmod(elapsed+dt*playback_speed,duration())
	refresh_preview()

func _sprite(id:String,foot:Vector2,scale_factor:float,walk:=false,tint:=Color.WHITE,facing:=6,hero_visual:=true) -> void:
	if hero_visual and hero_id=="ORCA" and id=="ORCA":
		preload("res://scripts/units/peregrine_art.gd").draw_preview(stage,foot,scale_factor,12 if facing==2 else 28,tint)
		return
	if hero_id=="TTNK" and id=="TTNK":
		preload("res://scripts/units/leizhu_art.gd").draw_preview(stage,foot,64*scale_factor,0 if facing==6 else 16,tint)
		return
	var art:=RA2Art.art(id)
	if art.is_empty():return
	var seq:=RA2Art.seq(id)
	var frame:=maxi(0,RA2Art.seq_frame(seq,"Walk" if walk else "Guard",facing,int(elapsed*9)))
	var rect:=RA2Art.draw_rect(art,0,[frame],0,scale_factor)
	rect.position+=foot
	RA2Art.draw_sprite(stage,art,rect,RA2Art.src_rect(art,frame),tint)

func _text(pos:Vector2,s:String,ink:=Color.WHITE) -> void:
	stage.draw_string(ThemeDB.fallback_font,pos,s,HORIZONTAL_ALIGNMENT_LEFT,-1,14,ink)

func _draw_demo() -> void:
	if hero_id.is_empty():return
	stage.draw_rect(Rect2(Vector2.ZERO,stage.size),Color("#142331"))
	var width:=minf(540,stage.size.x)
	stage.draw_set_transform(Vector2((stage.size.x-width)*0.5,0),0,Vector2.ONE)
	if hero_id in Academy.Stars.IDS:
		preload("res://scripts/ui/hollywood_talent_demo.gd").draw(self,width);return
	if hero_id in Unit.Convoy.IDs:
		preload("res://scripts/ui/convoy_demo.gd").draw(self,width);return
	if hero_id=="TTNK":
		var stopped:bool=talent.selected==1 and levels.selected==5 and preload("res://scripts/ui/leizhu_safety_demo.gd").sample(5,elapsed).stopped
		stage.material.set_shader_parameter("online",not stopped)
		preload("res://scripts/ui/leizhu_demo.gd").draw(self,width);return
	if hero_id=="ORCA":
		preload("res://scripts/ui/peregrine_demo.gd").draw(self,width)
		return
	if hero_id in Academy.Commandos.IDS:
		if hero_id=="BORIS" and talent.selected==1 and levels.selected>0:
			preload("res://scripts/ui/boris_radio_demo.gd").draw(self,width)
			return
		if hero_id=="BORIS" and talent.selected==0 and levels.selected>0:
			preload("res://scripts/ui/boris_command_demo.gd").draw(self,width)
			return
		if hero_id=="TANY" and levels.selected>0:
			preload("res://scripts/ui/tanya_talent_demo.gd").draw(self,width)
			return
		preload("res://scripts/ui/hero_commando_demo.gd").draw(self,width)
		return
	if hero_id in Unit.TankHero.IDS:
		_draw_tank_demo(width)
		return
	if talent.selected==0:
		var start:=Vector2(width*0.16,90)
		var rally:=Vector2(width*0.78,86)
		_sprite("GAPILE" if hero_id=="E1" else "NAHAND",start,0.62)
		stage.draw_dashed_line(start,rally,Color("#63889b"),1,6)
		stage.draw_circle(rally,7,UiKit.COL_OK,false,2)
		var ranks:Array=Academy.ESCORT_RANKS[levels.selected]
		for i in range(ranks.size()+1):
			var t:=clampf((elapsed-i*0.34)/2.3,0,1)
			if t<=0:continue
			var offset:=Vector2.ZERO if i==0 else Vector2(-30-ceili(i/2.0)*42,36 if i%2==1 else -23)
			var point:=start.lerp(rally+offset,t)
			_sprite(hero_id,point,1.25,t<1)
			_text(point+Vector2(-12,-39),Academy.HEROES[hero_id] if i==0 else "★".repeat(ranks[i-1]),UiKit.COL_GOLD)
		_text(Vector2(width*0.70,136),"兵营集结点",UiKit.COL_OK)
	else:
		var rank:=levels.selected
		var temporal:=rank==5
		var victim:={"hp":120.0,"max_hp":120.0,"special":{"academy_hero":hero_id,"hero_survival_rank":rank}}
		var hp:=0.0
		if rank==2: hp=120
		elif not temporal: hp=120-Academy.survival_damage(victim,240,WARHEADS[rank],"")
		_sprite(THREATS[rank],Vector2(width*0.17,93),0.95)
		_text(Vector2(8,134),ATTACKS[rank],UiKit.COL_GOLD)
		for i in 2:
			var point:=Vector2(width*(0.48+0.32*i),88)
			var fraction:=1.0 if elapsed<1 else (hp/120.0 if i==1 else 0.0)
			if temporal: fraction=clampf(1-(elapsed-1)/(4.0 if i==1 else 2.0),0,1)
			if elapsed>=1 and (elapsed<1.25 or (temporal and fraction>0)):
				stage.draw_line(Vector2(width*0.19,70),point+Vector2(0,-12),Color("#81d9ff") if temporal else UiKit.COL_GOLD,2)
			if fraction>0:_sprite(hero_id,point,1.3,false,Color("#9adfff") if temporal and elapsed>=1 else Color.WHITE)
			var bar:=Rect2(point+Vector2(-45,7),Vector2(90,6))
			stage.draw_rect(bar,Color("#354350"))
			stage.draw_rect(Rect2(bar.position,Vector2(bar.size.x*fraction,6)),UiKit.COL_ACCENT_2 if temporal else UiKit.COL_OK)
			var status:="%d / 120" % roundi(fraction*120)
			if temporal:status="已擦除" if fraction==0 else "剩余 %.1f 秒" % (fraction*(4 if i==1 else 2))
			_text(point+Vector2(-44,33),("普通兵" if i==0 else Academy.HEROES[hero_id])+"  "+status)
		if temporal:_text(Vector2(8,20),"擦除时间对照 · 示例基准 2 秒",UiKit.COL_DIM)

func _draw_tank_demo(width:float) -> void:
	var rank:=levels.selected
	var point:=Vector2(width*0.32,92)
	var enemy:=Vector2(width*0.75,92)
	var phase:=elapsed/PERIOD
	if talent.selected==0 and rank==1:
		var recovery:=clampf(elapsed/Unit.TankHero.REVIVE_SECONDS,0,1)
		var preview:=Unit.TankHero.revival_preview(recovery)
		var left:float=preview.left
		_sprite(hero_id,point,1.15,false,Color(0.45,0.4,0.35) if recovery<1 else Color.WHITE)
		var fraction:float=preview.fraction
		stage.draw_rect(Rect2(point+Vector2(-50,10),Vector2(100,7)),Color("#354350"))
		stage.draw_rect(Rect2(point+Vector2(-50,10),Vector2(100*fraction,7)),UiKit.COL_OK)
		_text(Vector2(12,24),preview.title,UiKit.COL_GOLD)
		_text(enemy+Vector2(-75,0),"%.1f 秒后复苏" % left if recovery<1 else "复苏 · 次数已用")
		_text(Vector2(12,138),"15 秒复活演示 · 生命上限 -50% / 攻击 -30% / 移速 +15%")
		return
	_sprite(hero_id,point,1.15)
	if talent.selected==1 and rank==0:
		var sample_time:=phase*Unit.TankHero.Shield.PREVIEW_DURATION
		var sample:=Unit.TankHero.Shield.preview(sample_time)
		var fraction:float=sample.fraction
		_text(Vector2(12,24),"重装生存 0 级 · 静止蓄盾（加速演示）",UiKit.COL_GOLD)
		_text(Vector2(12,138),sample.label)
		_sprite("MTNK",enemy,1.0)
		stage.draw_rect(Rect2(point+Vector2(-45,14),Vector2(90,5)),Color("#354350"))
		if fraction>0:
			stage.draw_circle(point+Vector2(0,-15),43,Color(0.3,0.85,1.0,0.10))
			stage.draw_arc(point+Vector2(0,-15),43,0,TAU,32,Unit.TankHero.Shield.COLOR,2)
			stage.draw_rect(Rect2(point+Vector2(-45,14),Vector2(90*fraction/Unit.TankHero.Shield.LIMIT,5)),Unit.TankHero.Shield.COLOR)
		if sample_time>=11 and sample_time<11.3:stage.draw_line(enemy,point,Color.ORANGE,2)
		if sample_time>=Unit.TankHero.Shield.PREVIEW_BREAK and sample_time<Unit.TankHero.Shield.PREVIEW_BREAK+Unit.TankHero.Shield.Wave.LIFE:
			stage.draw_line(enemy,point,Color.ORANGE,2)
			Unit.TankHero.Shield.Wave.paint(stage,point,90,sample_time-Unit.TankHero.Shield.PREVIEW_BREAK,0.5)
		return
	if talent.selected==0:
		stage.draw_arc(point,64+phase*18,0,TAU,48,Color(0.3,0.8,1,1-phase),2)
		_sprite("SUB" if rank==0 else "GGI",enemy,1.0)
		stage.draw_dashed_line(point,enemy,Color.CYAN,2,5)
		_text(Vector2(12,24),["反潜扫描 · 出场同时侦察所有敌对基地","","友军速度追平 · 光环不叠加","部署友军射程 +2 格 · 自身除外"][rank],UiKit.COL_GOLD)
		if rank==3:stage.draw_arc(enemy,45,0,TAU,48,UiKit.COL_OK,2)
	else:
		if rank == 5:
			var airborne := enemy + Vector2(0, -24)
			_sprite("ORCA", airborne, 1.0)
			var shell := point.lerp(airborne, phase) + Vector2.UP * sin(PI * phase) * 18.0
			stage.draw_circle(shell, 3, UiKit.COL_GOLD)
			_text(Vector2(12,24), "主炮对空 · 伤害 50%", UiKit.COL_GOLD)
			_text(Vector2(12,138), "受到致命爆炸时，单次最多扣除 2/3 最大生命")
			return
		var threats:=["MTNK","DRON","CLEG","DESO","CLEG"]
		_sprite(threats[rank],enemy,1.1)
		if phase>0.25:stage.draw_line(enemy,point,Color(0.6,0.8,1,1-phase),2)
		_text(Vector2(12,24),["0 级 · 静止蓄盾","寄生伤害 ×0.1 · 车体稳定","视野 +3 格","防碾压 · 生化伤害 ×0.7","保持行动 · 移动与开火速度 ×0.5"][rank],UiKit.COL_GOLD)
