extends RefCounted
const LENGTH=127.0

static func sample(t:float) -> Dictionary:
	var clock:=fposmod(t,LENGTH)
	var attempt:=0 if clock<10 else 1 if clock<61 else 2 if clock<121 else 3
	var start:float=[1.,10.,61.,121.][attempt]
	var used:=0 if clock<1 else 1 if clock<61 else 2
	var charge:bool=clock>=1 and clock<5 or clock>=61 and clock<63
	var left:=5-clock if attempt==0 and charge else 65-clock if charge else 0.0
	var cd:=maxf(0,(61 if clock<61 else 121)-clock) if used>0 else 0.0
	var disarmed:=attempt==2 and clock>=63
	return {"time":clock,"attempt":attempt,"start":start,"used":used,"remaining":2-used,"cooldown":cd,
		"charge":charge,"left":left,"primary_dead":clock>=start,"secondary_dead":attempt==0 and clock>=5,"disarmed":disarmed,
		"title":["首次拆楼：转移4秒炸药，消耗第1次","冷却中再次拆楼：不转移，也不额外扣次数","冷却结束：第2次转移，被拆仍消耗次数","冷却已结束但次数用尽：不再转移"][attempt]}

static func draw(view,width:float) -> void:
	var s:=sample(view.elapsed);var t:float=s.time
	var hero:=Vector2(width*.12,100)
	var first:=Vector2(width*.43,95);var second:=Vector2(width*.76,95)
	view._text(Vector2(8,22),s.title,UiKit.COL_GOLD)
	view._text(Vector2(8,42),"同一局连续场景 · 时间 %.1f秒 · 每段为另一组邻楼"%t,UiKit.COL_DIM)
	view._sprite("TANY",hero,1.15)
	if not s.primary_dead:view._sprite("NAPOWR",first,.38)
	else:ruin(view,first)
	if not s.secondary_dead:view._sprite("NAPOWR",second,.38)
	else:ruin(view,second)
	if t>=s.start and t<s.start+.4:
		view.stage.draw_arc(first,25+(t-s.start)*50,0,TAU,32,Color.ORANGE,2)
		if s.attempt in [0,2]:view.stage.draw_line(first,second,Color.ORANGE,2)
	if s.charge:
		view.stage.draw_circle(second+Vector2(0,-24),4,Color.ORANGE if fmod(t,.5)<.25 else Color.YELLOW)
		view._text(second+Vector2(-34,-40),"C4 %.1f秒"%s.left,Color.GOLD)
	if s.secondary_dead and t<5.5:view.stage.draw_arc(second,30+(t-5)*40,0,TAU,32,Color.ORANGE,2)
	if s.attempt==2:
		var engineer:=second+Vector2(52-20*clampf(t-61,0,2),18)
		view._sprite("SENGINEER",engineer,.9,t<63)
		if s.disarmed:view._text(second+Vector2(-48,-40),"已拆除 · 建筑保留",UiKit.COL_OK)
	view._text(first+Vector2(-35,25),"原生C4拆楼",UiKit.COL_DIM)
	view._text(second+Vector2(-42,25),"未生成炸药" if s.attempt in [1,3] else "工程师保留" if s.disarmed else "不再递归转移" if s.secondary_dead else "邻楼",UiKit.COL_DIM)
	view._text(Vector2(8,142),"本局剩余 %d/2 次　冷却 %.1f/60秒"%[s.remaining,s.cooldown],Color.CYAN)

static func ruin(view,at:Vector2) -> void:
	view.stage.draw_line(at+Vector2(-20,-16),at+Vector2(20,10),Color.ORANGE,3)
	view.stage.draw_line(at+Vector2(20,-16),at+Vector2(-20,10),Color.ORANGE,3)
