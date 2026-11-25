extends RefCounted

static func tracer_state(time:float,rank:int) -> Dictionary:
	var hits:=0
	for impact in [2.0,2.8,3.6]:
		if time>=impact:hits+=1
	var marked:=time>=1.0 and time<5.0 and hits<3
	var bonus:=float(GameData.get_skill("ap_tracer_mark").values.damage[rank])*100.0
	var text:="开启 W · 6秒内下一炮附加标记"
	if marked:text="标记 %.1fs · 剩余%d/3次 · 友军炮击 +%s%%"%[5.0-time,3-hits,MetaProgress.Academy.skill_number(bonus)]
	elif hits==3:text="三次增伤已用完 · 后续炮击恢复普通伤害"
	return {"marked":marked,"charges":3-hits if marked else 0,"hits":hits,"bonus":bonus,"text":text}

static func draw_tracer(stage) -> String:
	var state:=tracer_state(stage.elapsed,stage.preview_rank)
	var ally:=Vector2(150,30)
	stage.actor(ally,stage.ALLY)
	stage.draw_string(ThemeDB.fallback_font,Vector2(125,16),"友军载具",HORIZONTAL_ALIGNMENT_LEFT,-1,11,stage.ALLY)
	stage.shot(stage.A,stage.B,0.54)
	if stage.elapsed<1.0:stage.ring(stage.A,22,stage.BONUS)
	if state.marked:
		stage.ring(stage.B,22,stage.BONUS)
		stage.draw_line(stage.B+Vector2(-29,0),stage.B+Vector2(29,0),stage.BONUS,1)
		stage.draw_line(stage.B+Vector2(0,-29),stage.B+Vector2(0,29),stage.BONUS,1)
	for i in 3:
		stage.shot(ally,stage.B,1.54+i*0.8,true)
		stage.draw_rect(Rect2(stage.B+Vector2(-21+i*15,34),Vector2(11,7)),stage.BONUS if state.marked and i<state.charges else stage.MUTED)
	stage.shot(ally,stage.B,4.14)
	return state.text

static func draw(stage) -> String:
	var id:String=stage.card
	if GameData.get_skill(id).get("hero_expansion2",false):return preload("res://scripts/ui/commando_card_demo.gd").draw(stage)
	if GameData.get_skill(id).get("expansion2",false):return preload("res://scripts/ui/expansion_2_demo.gd").draw_card(stage)
	if id=="ap_mirror_fork":return preload("res://scripts/ui/mirror_fork_demo.gd").draw(stage)
	var t:float=stage.elapsed
	var a:Vector2=stage.A;var b:Vector2=stage.B
	stage.actor(a,stage.ALLY);stage.actor(b,stage.FOE,PI)
	match id:
		"ap_tracer_mark":
			return draw_tracer(stage)
		"ap_watch_posts","ps_watch_succession":
			for i in 3:
				var p:=a+Vector2(45+i*36,(i%2)*25-15)
				stage.actor(p,Color(stage.ALLY,.65))
				stage.shot(p,b,.8+i*.3)
				if id=="ps_watch_succession" and t>2:
					stage.draw_line(p,p+Vector2(0,-24),stage.BONUS if i==int(t/2)%3 else stage.MUTED,2)
			if id=="ap_watch_posts":
				if stage.preview_rank>=2:
					var air:=b+Vector2(0,-45)
					stage.actor(air,stage.FOE,PI,false)
					stage.draw_dashed_line(b,air,stage.MUTED)
					stage.shot(a,air,3)
					for i in 3:stage.shot(a+Vector2(45+i*36,(i%2)*25-15),air,3.2+i*.2)
				return "本体与三哨位卧倒 · 每座火力 %d%% · %s"%[roundi(float(GameData.get_skill(id).values.damage[stage.preview_rank])*100),"本体及哨位可对空" if stage.preview_rank>=2 else "2级解锁本体及哨位对空"]
			return "卧倒哨位随机继任 · 金旗2s · 失效重新选候补"
		"ap_north_twin":
			var x:float=60 if int(t/2)%2==0 else 150
			stage.actor(Vector2(x+60,70),Color(stage.ALLY,.4),0,false)
			stage.ring(Vector2(x,70),20,stage.BONUS);stage.draw_dashed_line(a,Vector2(210,70),stage.ALLY)
			return "存续期不限交换次数 · 召唤与交换独立冷却"
		"ps_north_echo":
			for i in 3:
				stage.draw_rect(Rect2(a+Vector2(i*16,-30),Vector2(10,8)),stage.BONUS,t>i)
			stage.shot(a,b,.5);stage.shot(a,b,2.0,true);stage.shot(a,b,3.0,true)
			return "直接命中记录 · 1.5s后重演 · 无需撤退"
		"ps_spine_scrap","ap_spine_crown":
			for i in 5:stage.draw_rect(Rect2(a+Vector2(i*12,-30),Vector2(9,7)),stage.BONUS,t<3 or id=="ps_spine_scrap")
			if id=="ap_spine_crown":
				for i in 4:stage.shot(a,b,.8+i*.25,true)
				if t>2:stage.ring(b,35,stage.BONUS)
			return "拾取废铁 · 逐片吸收伤害" if id=="ps_spine_scrap" else "基准1枚+消耗装甲 · .25s间隔 · 留减速区"
		"ap_tidal_decoy":
			stage.actor(a+Vector2(35,-20),Color(stage.ALLY,.4),0,false)
			stage.draw_dashed_line(b,a,stage.FOE)
			stage.shot(b,a,3,true)
			return "本人短潜脱离 · 敌人强制打诱饵 · 各自命中一次解除"
		"ap_seismic_anchor":
			var life:float=GameData.get_skill(id).values.life[stage.preview_rank]
			if t<1+life:stage.ring(b,35,stage.BONUS)
			if t>=1 and t<1+life:stage.ring(b,10+fmod(t,1)*25,stage.FOE)
			return "预警1s" if t<1 else ("每秒余震 · 减速区剩余 %.1fs / %ds"%[1+life-t,int(life)] if t<1+life else "区域结束 · 停止余震与减速")
		"ap_bomb_nests","ap_ink_mine":
			for i in (3 if id=="ap_bomb_nests" else 1):
				if t>=i*.6:stage.draw_circle(a+Vector2(40+i*35,25),6,stage.BONUS if t>=i*.6+.9 else stage.MUTED)
			return "三枚弹巢 · 每.6s释放 · 落地后布防" if id=="ap_bomb_nests" else "水雷布防.8s · 敌舰接近引爆并减速"
		"ps_zero_arc":
			for i in 3:stage.shot(a,b,.4+i,true)
			if t>2.4:stage.draw_line(b,b+Vector2(35,-30),stage.BONUS,2)
			return "同目标连续三击 · 第三击电弧跳向邻敌"
		"ps_prism_recycle":
			for i in mini(3,int(t)):stage.draw_circle(a+Vector2(i*15,-25),5,stage.BONUS)
			stage.shot(a,b,3,true)
			return "击杀存晶体 · 下次填弹消耗 · 主光束额外伤害"
		"ps_formation_cover":
			for i in 4:stage.actor(a+Vector2(35+i*24,(i%2)*25),Color(stage.ALLY,.7),0,false)
			stage.ring(a,40,stage.BONUS)
			return "邻近友机逐架叠加减伤 · 最多4层"
		"ps_deck_rotation":
			stage.actor(a+Vector2(50-t*7,-35),Color(stage.ALLY,.7),0,false)
			stage.draw_rect(Rect2(a+Vector2(0,25),Vector2(80*(1-t/6),6)),stage.BONUS)
			return "首架回收 · 缩短其他整备计时 · 冷却20s"
		"ps_drone_trip":
			stage.ring(b,18,stage.BONUS if t>2 else stage.MUTED)
			return "第三次寄生伤害 · 只定身 · 最短触发间隔4s"
		"ps_field_relay":
			stage.actor(a+Vector2(38,18),Color(stage.ALLY,maxf(0,1-t/2)),0,false)
			stage.ring(a,25,stage.BONUS)
			return "附近友军步兵阵亡 · 4s内下次填弹加速"
	return ""
