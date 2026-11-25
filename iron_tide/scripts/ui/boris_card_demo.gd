extends RefCounted
const W="ap_boris_corridor"

static func sample(id:String,rank:int,time:float) -> Dictionary:
	var card:=GameData.get_skill(id)
	if id==W:
		var phase:="静止呼叫 0.6 秒 · 移动／控制会打断，不扣冷却" if time<.6 else ("呼叫成功 · 攻击力与校射收益锁定 · 预警 1.2 秒" if time<1.8 else "固定三点依次落弹 · 鲍里斯离开或死亡不取消")
		if time>=4.5:phase="另例：再次开始呼叫" if time<4.9 else "呼叫未满0.6秒即移动 → 取消炮火，保留校射章，不扣冷却"
		return {"damage":200.0*float(card.values.damage[rank]),"cooldown":float(card.cooldown_by_rank[rank]),"text":phase+" · 每发 %.0f 攻击力伤害"%(200.0*float(card.values.damage[rank]))}
	var count:=clampi(int(time/2)+1,1,3) if time<5 else (3 if time>=8 and time<20 else 0)
	var used:=3 if time>=5 else count
	if time>=8:return {"count":count,"radius":1.0,"damage":1.0,"text":"另例：不施放，保留3章 · 脱离伤害往来 %.1f/12秒"%(time-8) if time<20 else "脱离伤害往来满12秒 → 全部校射章清空"}
	return {"count":count,"radius":1+used*float(card.values.radius[rank]),"damage":1+used*float(card.values.damage[rank]),"text":"步枪直击攒章 · 每2秒1章，最多3章" if time<5 else "本次消耗3章：伤害+%d%% / 半径+%d%%；W与米格仅先触发的一方享受"%[roundi(300*float(card.values.damage[rank])),roundi(300*float(card.values.radius[rank]))]}

static func draw(stage) -> String:
	var t:float=stage.elapsed
	var state:=sample(stage.card,stage.preview_rank,t)
	stage.actor(stage.A+(Vector2(minf(30,(t-4.9)*20),0) if stage.card==W and t>=4.9 else Vector2.ZERO),stage.ALLY)
	if stage.card==W:
		if t<.6 or (t>=4.5 and t<4.9):stage.ring(stage.A,24,stage.BONUS)
		for i in 3:
			var at:Vector2=stage.B+Vector2((i-1)*48,0)
			stage.actor(at,stage.FOE,PI,false)
			var hit:=1.8+i*.8
			if t>=.6 and t<hit:stage.ring(at,22,Color(1,.4,.15,.65))
			if t>=hit-.3 and t<hit:
				var y:float=lerpf(-75,0,clampf((t-hit+.3)/.3,0,1))
				stage.draw_line(at+Vector2(0,y-12),at+Vector2(0,y),stage.BONUS,3)
			if t>=hit and t<hit+.5:stage.ring(at,22+(t-hit)*22,Color(1,.3,.1,1-(t-hit)*2))
	else:
		stage.actor(stage.B,stage.FOE,PI,false)
		for i in 3:
			stage.shot(stage.A,stage.B,float(i)*2)
			stage.draw_rect(Rect2(stage.A+Vector2(-24+i*18,30),Vector2(12,10)),stage.BONUS if i<int(state.count) else stage.MUTED)
		if t>=5 and t<8:
			stage.ring(stage.B,24,stage.MUTED)
			stage.ring(stage.B,24*float(state.radius),stage.BONUS)
			stage.shot(stage.A,stage.B,5.0,true)
	return state.text
