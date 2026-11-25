extends RefCounted
const BASE_LENGTH=30.0
const HUNTER_LENGTH=24.0

static func sample(t:float,hunter:=false) -> Dictionary:
	var clock:=fposmod(t,HUNTER_LENGTH if hunter else BASE_LENGTH)
	var part:=int(clock/6);var local:=clock-part*6
	var start:=20.0 if hunter and part==2 else 100.0
	var hp:=start
	var qualifies:=false
	var attacker:="E2"
	var title:=""
	if hunter:
		attacker=["DOG","SNIPE","DOG","HTNK"][part]
		title=["反猎杀 · 致命犬扑最多扣最大生命的1/3","反猎杀 · 致命狙击同样限伤，保留低级护盾","反猎杀 · 低血仍可能阵亡","反猎杀 · 普通坦克炮不受此上限保护"][part]
		if local>=1:hp=maxf(0,start-100.0/3) if part<3 else 0.0
		qualifies=part<2
	else:
		title=["脱离杀线 · 单次20伤害，存活后自身获盾","脱离杀线 · 单次10伤害，未达到15%门槛","脱离杀线 · 三次10伤害不能累计触发","脱离杀线 · 致命伤不会发放救命护盾","脱离杀线 · 单次恰好15伤害也能触发"][part]
		if local>=1:
			if part==2:hp=100-mini(3,int(local))*10
			else:hp=[80.0,90.0,70.0,0.0,85.0][part]
		qualifies=part in [0,4]
	var shield:=10 if qualifies and local>=1.2 and local<4.2 else 0
	var phase:="等待攻击" if local<1 else "① 已扣生命，判定存活" if local<1.2 and qualifies else "② 同次受伤触发 · 自身护盾10" if shield>0 else "③ 护盾到期，生命不返还" if qualifies else "本次阵亡 · 不产生护盾" if hp<=0 else "每次实际生命损失不足15 · 无护盾"
	return {"part":part,"time":local,"hp":hp,"shield":shield,"dead":hp<=0,"phase":phase,"title":title,"attacker":attacker,
		"cd":maxf(0,31-local) if qualifies and local>=1 else 0.0,"repeat":not hunter and part==2}

static func draw(view,width:float,hunter:=false) -> void:
	var s:=sample(view.elapsed,hunter)
	var at:=Vector2(width*.4,92);var enemy:=Vector2(width*.78,92)
	view._text(Vector2(8,22),s.title,UiKit.COL_GOLD)
	view._text(Vector2(8,44),s.phase,UiKit.COL_DIM)
	view._sprite(s.attacker,enemy,.7 if s.attacker=="HTNK" else 1.1,false,Color.WHITE,2)
	if not s.dead:view._sprite("TANY",at,1.25)
	else:
		view.stage.draw_line(at+Vector2(-12,-24),at+Vector2(12,0),Color.ORANGE,2)
		view.stage.draw_line(at+Vector2(12,-24),at+Vector2(-12,0),Color.ORANGE,2)
	for hit:float in [1.,2.,3.] if s.repeat else [1.]:
		if s.time>=hit-.2 and s.time<hit+.2:view.stage.draw_line(enemy+Vector2(0,-15),at+Vector2(0,-15),Color.ORANGE,2)
	if s.shield>0:view.stage.draw_arc(at+Vector2(0,-15),29,0,TAU,32,Color.CYAN,2)
	view._text(at+Vector2(-45,25),"谭雅 · 生命 %.1f/100"%s.hp,UiKit.COL_OK)
	view._text(at+Vector2(-45,44),"自身护盾 %d/100"%s.shield,Color.CYAN)
	view._text(enemy+Vector2(-21,25),"攻击者",UiKit.COL_DIM)
	if s.cd>0:view._text(Vector2(8,65),"触发间隔 %.1f秒；扣血与获盾分拍展示"%s.cd,UiKit.COL_DIM)
