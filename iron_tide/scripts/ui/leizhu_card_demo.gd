extends RefCounted
const W="ap_leizhu_court"

static func sample(id:String,rank:int,t:float) -> Dictionary:
	var card:=GameData.get_skill(id)
	if id==W:
		var life:=float(card.values.life[rank])
		var nodes:=0 if t<.5 or t>=life+.5 else (3 if t<life*.4 else (2 if t<life*.7 else 1))
		return {"nodes":nodes,"life":life,"hp":1000*float(card.values.hp[rank]),"damage":200*float(card.values.damage[rank])*.5,"slow":float(card.values.slow[rank]),"text":"三极覆盖区域" if nodes==3 else "毁一极：仅余两极连线" if nodes==2 else "不足两极：立即断电" if nodes==1 else "电极尚未放置" if t<.5 else "到期全部消散"}
	var count:=0 if t<1 or t>=3 and t<5 or t>=14 else (1 if t<2 or t>=5 and t<6 else 2)
	var flash:=t>=3 and t<3.5
	return {"count":count,"flash":flash,"radius":float(card.values.radius[rank]),"damage":200*float(card.values.damage[rank]),"text":"第三击：自身周围放电，清空电荷" if flash else "8秒无新层：全部消退" if t>=14 else "每秒最多一层 · 当前 %d/3"%count}

static func draw(stage) -> String:
	var t:float=stage.elapsed;var state:=sample(stage.card,stage.preview_rank,t)
	if stage.card==W:
		stage.actor(Vector2(45,80),stage.ALLY)
		var poly:=PackedVector2Array([Vector2(210,44),Vector2(270,118),Vector2(150,118)])
		stage.actor(Vector2(210,86),stage.FOE,PI,false)
		if state.nodes==3:stage.draw_colored_polygon(poly,Color(.2,.65,1,.14))
		for i in 3:
			if i<3-state.nodes:continue
			stage.draw_rect(Rect2(poly[i]-Vector2(4,9),Vector2(8,18)),stage.BONUS)
			stage.draw_circle(poly[i]-Vector2(0,12),3,stage.ALLY)
		if state.nodes==3:
			for i in 3:stage.draw_line(poly[i],poly[(i+1)%3],stage.ALLY,2)
		elif state.nodes==2:stage.draw_line(poly[1],poly[2],stage.ALLY,3)
		if state.nodes>=2:
			stage.actor(Vector2(210,118),stage.FOE,PI,false)
			if fposmod(maxf(0,t-.5),.5)<.12 and t>=1:stage.ring(Vector2(210,118),13,stage.BONUS)
		stage.draw_string(ThemeDB.fallback_font,Vector2(12,18),"示例攻击200 · 单极耐久%.0f（生命1000）"%state.hp,HORIZONTAL_ALIGNMENT_LEFT,-1,11,stage.ALLY)
		stage.draw_string(ThemeDB.fallback_font,Vector2(12,34),"每0.5秒 %.0f · 减速%d%% · 持续%.0fs"%[state.damage,roundi(state.slow*100),state.life],HORIZONTAL_ALIGNMENT_LEFT,-1,11,stage.BONUS)
	else:
		var at:=Vector2(110,86);var main:=Vector2(285,86);var nearby:=Vector2(62,110)
		stage.actor(at,stage.ALLY);stage.actor(main,stage.FOE,PI,false);stage.actor(nearby,stage.FOE,PI,false)
		for fire_time in [1.,2.,3.,5.,6.]:stage.shot(at,main,fire_time)
		for i in 3:stage.draw_circle(at+Vector2((i-1)*10,-29),3,stage.BONUS if i<state.count else stage.MUTED)
		if state.flash:stage.ring(at,state.radius*25,stage.ALLY);stage.ring(nearby,13,stage.BONUS)
		stage.draw_string(ThemeDB.fallback_font,Vector2(12,18),"自身%.2f格 · 伤害%.0f（示例攻击200）"%[state.radius,state.damage],HORIZONTAL_ALIGNMENT_LEFT,-1,11,stage.ALLY)
		stage.draw_string(ThemeDB.fallback_font,Vector2(12,34),"在本人有效电庭内：半径额外+0.5格",HORIZONTAL_ALIGNMENT_LEFT,-1,11,stage.BONUS)
	return state.text
