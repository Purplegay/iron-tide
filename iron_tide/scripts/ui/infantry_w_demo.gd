extends RefCounted
const FLIGHT:=.46

static func duration(id:String) -> float:
	return 42. if id=="ap_anchor_pin" else 24.

static func sample(id:String,rank:int,time:float) -> Dictionary:
	return anchor(rank,time) if id=="ap_anchor_pin" else breather(rank,time)

static func anchor(rank:int,time:float) -> Dictionary:
	var t:=fposmod(time,42)
	var part:=int(t/6)
	var local:=fposmod(t,6)
	var deployed:=part!=2 and not (part==1 and local>=1.2)
	var accepted:=part<2 and local>=1
	var hit:=accepted and local>=1+FLIGHT
	var left:=maxf(0,1+FLIGHT+3-local) if hit else 0.
	var value:float=GameData.get_skill("ap_anchor_pin").values.slow[rank]*100
	var base:float=GameData.get_unit("GGI").deployed_weapon.cooldown
	var ordinary_cd:=maxf(0,.2+base-local) if part<2 and local>=.2 else 0.
	var point:=Vector2(286,73)
	if part==4:point.y-=25
	if part==5:point=Vector2(87,73)
	if part==6:point=Vector2(333,73)
	var title:String=["部署按W立即发射 · 不占普通装填","已发射后收起部署 · 在途技能弹继续命中","未部署不能施放 · 不消耗W冷却","无当前合法目标 · 不消耗W冷却","对空目标不合法 · 不消耗W冷却","导弹盲区内目标 · 不消耗W冷却","目标超出主武器射程 · 不消耗W冷却"][part]
	var text:="先普通开火，再独立按W · 无待命状态" if part<2 else "按W失败：没有技能弹，也不扣冷却"
	if accepted:text="W剩余 %.1fs · 普通装填照常 %.2fs"%[maxf(0,27-local),ordinary_cd]
	if left>0:text="技能弹命中一次 · 减速%d%%，剩余%.1fs"%[value,left]
	return {"time":t,"local":local,"part":part,"active":left>0,"value":value,"charges":0,"text":text,"title":title,
		"deployed":deployed,"accepted":accepted,"hit":hit,"left":left,"cooldown":maxf(0,27-local) if accepted else 0.,
		"ordinary_cd":ordinary_cd,"ordinary_hits":1 if part<2 and local>=.2+FLIGHT else 0,"point":point,"moving":false,"distance":0.,"speed":0.}

static func breather(rank:int,time:float) -> Dictionary:
	var t:=fposmod(time,24)
	var part:=int(t/8)
	var local:=fposmod(t,8)
	var value:float=GameData.get_skill("ap_battle_breather").values.speed[rank]*100
	var accepted:=part==0 and local>=1
	var active:=accepted and local<4
	var frozen:=part==2 and local<3
	var moving:=part==0 and local>=1.1 and local<4.1 or part==2 and local>=3.2 and local<5.2
	var distance:=clampf(local-1.1,0,3)*20+clampf(local-1.1,0,2.9)*20*value/100 if part==0 else clampf(local-3.2,0,2)*20 if part==2 else 0.
	var shots:Array=[.8,4.2] if part==0 else [2.] if part==1 else [4.2]
	var hits:=0
	for at:float in shots:
		if local>=at+FLIGHT:hits+=1
	var title:String=["三秒停火加速 · 已发射弹药继续命中","已部署拒绝换气 · 不会自动收起部署","冻结时拒绝换气 · 解冻也不会自动施放"][part]
	var text:="普通弹先发射，再按W换气" if part==0 else "按W失败：无加速、无技能冷却"
	if active:text="移速 +%d%% · 禁止新开火 %.1fs · 已在途弹保留"%[value,4-local]
	elif accepted:text="停火结束：可重新普通开火 · W仍剩 %.1fs"%maxf(0,23-local)
	return {"time":t,"local":local,"part":part,"active":active,"value":value,"charges":0,"text":text,"title":title,
		"deployed":part==1,"accepted":accepted,"frozen":frozen,"left":4-local if active else 0.,"cooldown":maxf(0,23-local) if accepted else 0.,
		"moving":moving,"distance":distance,"speed":20*(1+value/100 if active else 1),"can_fire":not active and not frozen,"shots":shots,"hits":hits}

static func sync_actor(actor,s:Dictionary) -> void:
	actor._deployed=s.deployed
	actor.velocity=Vector2.RIGHT.rotated(Iso.eff_angle())*s.speed if s.moving else Vector2.ZERO

static func projectile(stage,from:Vector2,to:Vector2,time:float,start:float,color:Color) -> void:
	var phase:float=(time-start)/FLIGHT
	if phase>=0 and phase<1:
		var tip:=from.lerp(to,phase)
		stage.draw_line(tip,from.lerp(to,maxf(0,phase-.12)),color,3,true)
	elif phase>=1 and phase<1.3:stage.ring(to,6+(phase-1)*24,color)

static func draw(stage,id:String,s:Dictionary) -> void:
	stage.draw_string(ThemeDB.fallback_font,Vector2(8,14),s.title,HORIZONTAL_ALIGNMENT_LEFT,-1,10,stage.BONUS)
	stage.draw_string(ThemeDB.fallback_font,Vector2(8,29),"这里演示技能何时生效，飞行时间仅供参考。原有武器照常开火。",HORIZONTAL_ALIGNMENT_LEFT,-1,9,stage.MUTED)
	var at:Vector2=stage.A+Vector2(s.distance,0)
	stage.actor(at,stage.ALLY)
	if id=="ap_anchor_pin":
		if s.part!=3:stage.actor(s.point,stage.FOE,PI,false)
		if s.part<2:
			projectile(stage,stage.A,s.point,s.local,.2,stage.ALLY)
			projectile(stage,stage.A,s.point,s.local,1.,stage.BONUS)
		if s.active:stage.ring(s.point,22,stage.BONUS)
		stage.draw_string(ThemeDB.fallback_font,Vector2(157,108),"普通装填 %.2fs · W冷却 %.1fs"%[s.ordinary_cd,s.cooldown],HORIZONTAL_ALIGNMENT_LEFT,-1,10,stage.ALLY)
		stage.draw_string(ThemeDB.fallback_font,Vector2(157,123),"普通命中%d次 · 技能命中%d次"%[s.ordinary_hits,1 if s.hit else 0],HORIZONTAL_ALIGNMENT_LEFT,-1,10,stage.BONUS)
	else:
		stage.actor(stage.B,stage.FOE,PI,false)
		for start:float in s.shots:
			var from:Vector2=stage.A+Vector2(breather(stage.preview_rank,s.part*8+start).distance,0)
			projectile(stage,from,stage.B,s.local,start,stage.ALLY)
		if s.active:stage.ring(at,24,stage.ALLY)
		if s.frozen:stage.draw_string(ThemeDB.fallback_font,at+Vector2(-12,-26),"冻结",HORIZONTAL_ALIGNMENT_LEFT,-1,11,stage.MUTED)
		if s.part==0 and s.local>=2 and s.local<2.7:stage.draw_string(ThemeDB.fallback_font,Vector2(151,60),"尝试新开火：被停火阻止",HORIZONTAL_ALIGNMENT_LEFT,-1,10,stage.FOE)
		stage.draw_string(ThemeDB.fallback_font,Vector2(160,110),"普通弹实际命中：%d次"%s.hits,HORIZONTAL_ALIGNMENT_LEFT,-1,10,stage.ALLY)
		stage.draw_string(ThemeDB.fallback_font,Vector2(160,125),"当前%s · W剩余%.1fs"%["可开火" if s.can_fire else "不能开火",s.cooldown],HORIZONTAL_ALIGNMENT_LEFT,-1,10,stage.BONUS)
