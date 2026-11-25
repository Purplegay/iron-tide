extends RefCounted

static func duration(rank:int) -> float:
	return 8.0 if rank==3 else 48.0 if rank==4 else 16.0

static func sample(rank:int,t:float) -> Dictionary:
	var clock:=fposmod(t,duration(rank))
	if rank==3:
		return {"time":clock,"hp":100 if clock<3 else 80,"shield":10 if clock>=3 and clock<6 else 0,"dead":false,"hidden":false,"flash":false,
			"gap":maxf(48,120-clock*60),"title":"翻越履带 · 碾压无效，仍保留实体碰撞","phase":"车辆接近，在接触位置停下" if clock<3 else "正常炮击仍扣20生命，再获得低级10盾" if clock<6 else "低级护盾到期，不返还已损生命"}
	if rank==4:
		var hp:=30 if clock<1 else 20 if clock<2 else 15 if clock<2.2 else 10 if clock<41 else 9 if clock<42 else 44 if clock<43 else 24
		var flash:=clock>=1 and clock<2.5 or clock>=43 and clock<44.5
		var cd:=maxf(0,(41 if clock<43 else 83)-clock) if clock>=1 else 0.0
		return {"time":clock,"hp":hp,"shield":10 if clock>=43 and clock<46 else 0,"dead":false,"hidden":false,"flash":flash,"cooldown":cd,
			"title":"闪光脱离 · 1.5秒禁火，冷却与血线都要满足",
			"phase":"初始生命30，等待敌伤" if clock<1 else "掉至20，近步兵禁火；坦克仍能继续发射" if clock<2 else "先前在途炮弹扣5生命" if clock<2.2 else "闪光期间新发射的炮弹再扣5生命" if clock<3 else "保持低血，等待40秒冷却" if clock<41 else "冷却已好，但没恢复血线：再次受伤不闪光" if clock<42 else "外部治疗到44生命，重新满足血线条件" if clock<43 else "再受20伤害到24：闪光＋低级10盾"}
	var part:=int(clock/8);var local:=clock-part*8
	var death:=5.0 if part==0 else 2.0
	var dead:=local>=death
	return {"time":local,"part":part,"hp":0 if dead else 100 if local<1 else 1,"shield":10 if local>=1 and local<4 and not dead else 0,
		"dead":dead,"hidden":local>=1 and local<3 and not dead,"flash":false,"used":local>=1,
		"title":"最后一搏 · 每段独立对照，均只有一次机会",
		"phase":"等待普通致命炮击" if local<1 else "后续范围伤仍可击杀，本局次数不会返还" if dead else "保留1生命＋低级10盾；隐形禁攻2秒，仍可移动" if local<3 else "隐形结束恢复行动；本局最后一搏已用"}

static func draw(view,width:float,rank:int) -> void:
	var s:=sample(rank,view.elapsed);var t:float=s.time
	var a:=Vector2(width*.3,94);var enemy:=Vector2(width*.8,94)
	view._text(Vector2(8,22),s.title,UiKit.COL_GOLD)
	view._text(Vector2(8,44),s.phase,UiKit.COL_DIM)
	if rank==3:enemy=a+Vector2(s.gap,-3)
	if rank==5 and t>=1:a.x+=minf(t-1,2)*18
	if not s.dead:view._sprite("TANY",a,1.2,rank==5 and s.hidden,Color(1,1,1,.25 if s.hidden else 1))
	else:preload("res://scripts/ui/tanya_chain_demo.gd").ruin(view,a)
	view._sprite("HTNK",enemy,.6,false,Color.WHITE,6)
	if s.shield>0:view.stage.draw_arc(a+Vector2(0,-15),29,0,TAU,32,Color.CYAN,2)
	view._text(a+Vector2(-52,26),"生命 %d/100"%s.hp,UiKit.COL_OK)
	view._text(a+Vector2(-52,45),"自身护盾 %d"%s.shield,Color.CYAN)
	if rank==3:
		view.stage.draw_line(a+Vector2(-35,-22),a+Vector2(-35,14),Color.GRAY,5)
		if t>=2.7 and t<3:view.stage.draw_circle(enemy.lerp(a,(t-2.7)/.3)-Vector2(0,15),3,Color.ORANGE)
		view._text(enemy+Vector2(-26,33),"不能穿车",UiKit.COL_DIM)
	elif rank==4:
		var soldier:=Vector2(width*.6,96)
		view._sprite("E2",soldier,1.05,false,Color.WHITE,2)
		if s.flash:
			view.stage.draw_arc(soldier+Vector2(0,-15),26,0,TAU,30,Color.YELLOW,2)
			view._text(soldier+Vector2(-25,27),"禁火",Color.GOLD)
		if t>=.8 and t<2:view.stage.draw_circle(enemy.lerp(a,(t-.8)/1.2)-Vector2(0,15),3,Color.ORANGE)
		if t>=1.4 and t<2.2:
			view.stage.draw_circle(enemy.lerp(a,(t-1.4)/.8)-Vector2(0,15),3,Color.YELLOW)
			view._text(enemy+Vector2(-46,27),"仍可开炮",Color.ORANGE)
		for hit:float in [1.,41.,43.]:
			if t>=hit-.1 and t<hit:view.stage.draw_line(soldier+Vector2(0,-15),a+Vector2(0,-15),Color.ORANGE,2)
		view._text(Vector2(width*.53,140),"闪光冷却 %.1f秒"%s.cooldown,Color.CYAN)
	else:
		var death:=5.0 if s.part==0 else 2.0
		if t>=.8 and t<1:view.stage.draw_circle(enemy.lerp(a,(t-.8)/.2)-Vector2(0,15),3,Color.ORANGE)
		if t>=death and t<death+.5:view.stage.draw_arc(a,22+(t-death)*35,0,TAU,30,Color.ORANGE,3)
		view._text(enemy+Vector2(-54,30),"隐形期间范围爆炸" if s.part==1 else "窗口结束后再受伤",UiKit.COL_DIM)
		view._text(Vector2(width*.57,140),"本局次数已用" if s.used else "本局次数可用",Color.CYAN)
