extends RefCounted
const W="ap_peregrine_hunt"

static func sample(id:String,rank:int,t:float) -> Dictionary:
	var card:=GameData.get_skill(id)
	if id==W:
		return {"damage":200*float(card.values.damage[rank]),"radius":float(card.values.radius[rank]),"cooldown":float(card.cooldown_by_rank[rank]),"text":"每枚 %.0f · 周围半伤 · 半径 %.1f 格"%[200*float(card.values.damage[rank]),float(card.values.radius[rank])]}
	var count:=1.0 if t<3 else (2.0 if t<5 else (1.5 if t<6 else (2.5 if t<9 else 5.0)))
	var shield:=minf(float(card.values.cap[rank]),count*float(card.values.shield[rank]))
	var linked:=t>=4 and t<8
	return {"shield":shield,"cap":float(card.values.cap[rank]),"linked":linked,"reload":8.0*(1-float(card.values.reload[rank])) if linked else 8.0,"text":("初始满仓一份盾" if t<1 else "部分补弹不叠盾" if t<3 else "补满叠盾，保留残盾" if t<5 else "受伤扣盾，补满再叠" if t<9 else "叠盾达到上限")+" · %.0f%% / %.0f%%"%[shield*100,float(card.values.cap[rank])*100]}

static func draw(stage) -> String:
	var t:float=stage.elapsed
	var state:=sample(stage.card,stage.preview_rank,t)
	stage.actor(stage.A,stage.ALLY)
	if stage.card==W:
		stage.draw_string(ThemeDB.fallback_font,Vector2(12,18),"四枚必中追猎 · 不可拦截 · 示例攻击力 200",HORIZONTAL_ALIGNMENT_LEFT,-1,11,stage.ALLY)
		stage.draw_string(ThemeDB.fallback_font,Vector2(12,34),"隐形／迷雾不断锁；失效后落至最后位置",HORIZONTAL_ALIGNMENT_LEFT,-1,11,stage.MUTED)
		var target:Vector2=stage.B+Vector2(0,sin(maxf(0,t-1)*2)*22)
		stage.actor(target,stage.FOE,PI,false)
		stage.actor(stage.B+Vector2(35,35),stage.FOE,PI,false)
		for i in 4:
			var age:=t-.4-.2*i
			var flank:Vector2=stage.A+Vector2(28,(28+8*(i/2))*(-1 if i%2==0 else 1))
			if age<0:continue
			var at:Vector2=stage.A.lerp(flank,clampf(age/.25,0,1)) if age<.25 else flank.lerp(target,clampf((age-.25)/.8,0,1))
			if age<1.05:
				stage.draw_line(at-Vector2(13,0),at,stage.ALLY,2);stage.draw_circle(at,3,Color.WHITE)
			elif age<1.5:stage.ring(target,24*state.radius,stage.BONUS)
	else:
		stage.ring(stage.A,25+state.shield*30,stage.ALLY)
		stage.draw_rect(Rect2(Vector2(28,120),Vector2(140,9)),stage.MUTED)
		stage.draw_rect(Rect2(Vector2(28,120),Vector2(140*state.shield/state.cap,9)),stage.ALLY)
		stage.actor(stage.B,stage.ALLY,PI,false)
		stage.draw_string(ThemeDB.fallback_font,stage.B+Vector2(-70,27),"机场有飞机停稳" if state.linked else "无停机联动",HORIZONTAL_ALIGNMENT_LEFT,-1,11,stage.ALLY if state.linked else stage.MUTED)
		stage.draw_string(ThemeDB.fallback_font,Vector2(12,18),"游隼补弹 %.2f 秒/发"%state.reload,HORIZONTAL_ALIGNMENT_LEFT,-1,11,stage.BONUS)
		stage.draw_string(ThemeDB.fallback_font,Vector2(12,34),"联动只加速游隼；停机飞机不加速",HORIZONTAL_ALIGNMENT_LEFT,-1,11,stage.MUTED)
	return state.text
