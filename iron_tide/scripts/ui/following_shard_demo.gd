extends RefCounted
const LENGTH:=24.0
const START:=Vector2(270,60)
const NEIGHBOR:=Vector2(325,65)
const RADIUS:=42.0

static func sample(rank:int,time:float) -> Dictionary:
	var t:=fposmod(time,LENGTH)
	var part:=int(t/6)
	var local:=fposmod(t,6)
	var landed:=part==1 and local>=1.4
	var dead:=part==2 and local>=1.4
	var rocket:=part==3
	var travel:=clampf(local-1,0,.4 if part in [1,2] else .8)*75
	var point:=START+Vector2(travel,0)
	var active:=not rocket and not landed and local>=1 and local<1.8
	var exploded:=part in [0,2] and local>=1.8
	var value:float=MetaProgress.talent_options("FLAKT")["following_shard"].values.damage[rank]*100
	var title:String=["普通直击挂载 · 飞入机群后空爆","未爆先落地 · 破片立即解除","目标死亡 · 原定时间在死亡空中坐标爆炸","可拦截火箭不是飞机 · 不挂破片"][part]
	var text:="命中即可挂载 · 不要求击杀"
	if active:text="破片倒计时 %.1fs · 触发间隔 %.1fs"%[1.8-local,maxf(0,5-local)]
	if exploded:text="一次空爆 · 主目标与邻机各%.0f%%，不递归"%value
	if landed:text="已落地：取消挂载，不产生空爆"
	if dead and active:text="已死亡：固定死亡空中位置 · 仍剩%.1fs"%(1.8-local)
	if rocket:text="普通防空可命中火箭 · 本天赋不授予挂载"
	return {"time":t,"local":local,"part":part,"active":active,"value":value,"charges":0,"text":text,"title":title,
		"point":point,"landed":landed,"dead":dead,"rocket":rocket,"exploded":exploded,"flash":exploded and local<2.05,
		"left":1.8-local if active else 0.,"cooldown":maxf(0,5-local) if not rocket and local>=1 else 0.,
		"primary_hits":1 if exploded and not dead else 0,"neighbor_hits":1 if exploded and point.distance_to(NEIGHBOR)<=RADIUS else 0}

static func draw(preview,origin:Vector2,s:Dictionary) -> void:
	preview.draw_string(ThemeDB.fallback_font,Vector2(10,20),s.title,HORIZONTAL_ALIGNMENT_LEFT,-1,11,Color.GOLD)
	preview.draw_string(ThemeDB.fallback_font,Vector2(10,39),"位置示意 · 0.8秒延迟 · 半径1.2格 · 地面不受伤",HORIZONTAL_ALIGNMENT_LEFT,-1,10,Color.GRAY)
	var at:Vector2=s.point+Vector2(0,25 if s.landed else 0)
	if s.rocket:
		preview.draw_line(at-Vector2(8,0),at+Vector2(8,0),Color.SALMON,5)
		preview.draw_string(ThemeDB.fallback_font,at+Vector2(-15,-12),"火箭",HORIZONTAL_ALIGNMENT_LEFT,-1,10,Color.SALMON)
	elif s.dead:
		preview.draw_line(at-Vector2(6,6),at+Vector2(6,6),Color.GRAY,2)
		preview.draw_line(at+Vector2(-6,6),at+Vector2(6,-6),Color.GRAY,2)
	else:preview.draw_circle(at,8,Color.GRAY if s.landed else Color.SALMON)
	preview.draw_circle(NEIGHBOR,8,Color.SALMON)
	preview.draw_circle(Vector2(325,113),6,Color.GRAY)
	preview.draw_string(ThemeDB.fallback_font,Vector2(338,116),"地面",HORIZONTAL_ALIGNMENT_LEFT,-1,10,Color.GRAY)
	if s.local>=1 and s.local<1.12:preview.draw_line(origin,START,Color.SKY_BLUE,2,true)
	if s.active:preview.draw_arc(s.point,13,0,TAU,24,Color.GOLD,2,true)
	if s.flash:preview.draw_arc(s.point,RADIUS,0,TAU,32,Color.GOLD,3,true)
	preview.draw_string(ThemeDB.fallback_font,Vector2(205,94),"追加：主目标%d次／邻机%d次"%[s.primary_hits,s.neighbor_hits],HORIZONTAL_ALIGNMENT_LEFT,-1,10,Color.GOLD)
	preview.draw_string(ThemeDB.fallback_font,Vector2(205,130),"触发间隔剩余 %.1fs"%s.cooldown,HORIZONTAL_ALIGNMENT_LEFT,-1,11,Color.GRAY)
