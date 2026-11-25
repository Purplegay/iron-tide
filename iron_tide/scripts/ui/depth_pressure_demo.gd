extends RefCounted
const LENGTH:=52.0
const SHIELD_DURATION=preload("res://scripts/units/expansion_2_submarine.gd").SHIELD_DURATION

static func sample(rank:int,time:float) -> Dictionary:
	var t:=fposmod(time,LENGTH)
	var part:=0 if t<30 else 1 if t<42 else 2
	var local:=t if part==0 else t-30 if part==1 else t-42
	var grant:=10.5 if part==1 else 24. if part==0 and local>=24 else 4.
	var shots:Array[float]=[]
	shots.assign([6.] if part==0 else [3.5,6.5] if part==1 else [8.])
	var last_shot:=-1.
	for shot:float in shots:
		if local>=shot:last_shot=shot
	var idle:=minf(4,local-last_shot if last_shot>=0 else local)
	var value:float=GameData.get_skill("ps_depth_pressure").values.shield[rank]*100
	var maximum:=value*10
	var active:=local>=grant and local<grant+SHIELD_DURATION and not (part==2 and local>=7)
	var shield:=maximum if active else 0.
	if active and ((part==0 and local>=7 and local<24) or (part==2 and local>=6)):shield*=.5
	var hp:=993. if part==2 and local>=7 else 1000.
	var cooldown:=maxf(0,grant+20-local) if local>=grant else 0.
	var moving:=local>=1 and local<3 or part==0 and local>=10 and local<12
	var distance:=clampf(local-1,0,2)*14+(clampf(local-10,0,2)*14 if part==0 else 0.)
	var title:String=["停火蓄盾 · 移动不打断 · 二十秒间隔","连续停火不足四秒 · 开火重新计时","耗盾与破盾 · 溢出伤害扣生命"][part]
	var text:="连续停火 %.1f / 4秒 · 移动不重置"%idle
	if cooldown>0:text="护盾 %.0f / %.0f · 剩余%.1fs · 间隔%.1fs"%[shield,maximum,maxf(0,grant+SHIELD_DURATION-local) if active else 0.,cooldown]
	if part==0 and local>=6 and local<7:text="开火重置停火计时 · 原护盾不清除／不续时"
	if part==0 and local>=4+SHIELD_DURATION and local<24:text="护盾到期 · 仍需等待触发间隔 %.1fs"%cooldown
	if part==1 and local>=3.5 and local<10.5:text="开火后重新停火 %.1f / 4秒 · 尚未获得护盾"%idle
	if part==2 and local>=7:text="护盾已破 · 生命扣7 · 间隔%.1fs，不立即补盾"%cooldown
	return {"time":t,"local":local,"part":part,"active":active,"value":value,"charges":0,"text":text,"title":title,
		"shield":shield,"maximum":maximum,"hp":hp,"cooldown":cooldown,"idle":idle,"left":maxf(0,grant+SHIELD_DURATION-local) if active else 0.,
		"moving":moving,"distance":distance,"shots":shots,"surface_left":maxf(0,NavalContact.dive_delay()-(local-last_shot)) if last_shot>=0 else 0.}

static func sync_actor(actor,s:Dictionary) -> void:
	actor.velocity=Vector2.RIGHT.rotated(Iso.eff_angle())*42 if s.moving else Vector2.ZERO
	if s.surface_left>0:actor.special.dive_remaining=s.surface_left
	else:actor.special.erase("dive_remaining")

static func trace(stage,from:Vector2,to:Vector2,time:float,hit:float,color:Color) -> void:
	if time>=hit-.4 and time<hit:stage.draw_circle(from.lerp(to,(time-hit+.4)/.4),3,color)
	if time>=hit and time<hit+.12:stage.ring(to,12,color)

static func draw(stage,s:Dictionary) -> void:
	var a:Vector2=Vector2(66,74)+Vector2(s.distance,0)
	var b:=Vector2(280,74)
	stage.draw_string(ThemeDB.fallback_font,Vector2(8,14),s.title,HORIZONTAL_ALIGNMENT_LEFT,-1,11,stage.BONUS)
	stage.draw_string(ThemeDB.fallback_font,Vector2(8,30),"最大生命1000示例 · 不改变原生浮潜／探测",HORIZONTAL_ALIGNMENT_LEFT,-1,10,stage.MUTED)
	stage.actor(a,stage.ALLY);stage.actor(b,stage.FOE,PI,false)
	if s.active:stage.ring(a,26,stage.ALLY)
	for start:float in s.shots:trace(stage,a,b,s.local,start+.4,stage.ALLY)
	if s.part==0:trace(stage,b,a,s.local,7,stage.FOE)
	if s.part==2:
		trace(stage,b,a,s.local,6,stage.FOE);trace(stage,b,a,s.local,7,stage.FOE)
	stage.draw_string(ThemeDB.fallback_font,Vector2(8,113),"自身生命 %.0f · 护盾 %.0f / %.0f"%[s.hp,s.shield,s.maximum],HORIZONTAL_ALIGNMENT_LEFT,-1,11,stage.ALLY)
	stage.draw_string(ThemeDB.fallback_font,Vector2(8,129),"护盾结算伤害：半盾后剩余盾+7" if s.part==2 else "射击节奏和弹速仅供参考，护盾单独计时",HORIZONTAL_ALIGNMENT_LEFT,-1,10,stage.MUTED)
