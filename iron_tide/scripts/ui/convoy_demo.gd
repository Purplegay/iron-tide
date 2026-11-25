extends RefCounted
const CARDS=["ap_convoy_crew","ps_convoy_mirror","ap_convoy_press","ps_convoy_heat"]
const CYAN=Color("#83dedb")
const AMBER=Color("#f1b755")
const PHASES={
	"FV":[[
		["驶出两格","视野 +2 格"],["步兵入座","车速 +15%"],["行驶后转向","弯道灯 · 半径四格"],["发现寄生车辆","移除恐怖机器人"],["慢行三秒","发现隐形敌车"],["受到攻击","减伤 90% → 0%"]
	],[
		["停车脱战","修复至半血"],["乘员获得经验","车组同步获授经验"],["实体步兵下车","无敌两秒"],["友军跌至半血以下","力场每秒治疗 4%"],["导弹逼近友军","镜像吸引一枚导弹"],["友车跌破两成生命","获得 15% 护盾"]
	]],
	"HARV":[[
		["停在矿点附近","视野 +2 格"],["空闲采矿","双倍铲量 · 双倍仓容"],["击毁敌车","回收原仓 5%"],["带矿起步","车速 +15%"],["受到伤害","耗矿吸收一半伤害"],["友车跌至半血以下","抢修机连续维修六秒"]
	],[
		["车体停车","普攻增伤 10%"],["第一轮、第二轮","第三轮同时攻击第二个敌人"],["连续命中同一车","第三击减速"],["每击毁一名敌人","5 / 10 / 20 次解锁碾压"],["连续命中工事","第四击产生范围溅射"],["摧毁作战实验室","10% 瞬爆 · 无辐射"]
	]]
}

static func draw(d,width:float) -> void:
	var page:int=d.talent.selected
	var rank:int=d.levels.selected
	var t:float=d.elapsed/d.duration()
	var id:String=d.hero_id
	var phase:Array=PHASES[id][page][rank]
	var from:=Vector2(width*.27,78)
	var to:=Vector2(width*.69,78)
	var stage=d.stage
	var active:=t>=.4
	var friend:bool=(id=="FV" and (page==1 or rank in [1,2,3])) or (id=="HARV" and page==0 and rank==5)
	var moving:bool=(id=="FV" and page==0 and rank in [0,1,2,4]) or (id=="HARV" and page==0 and rank==3)
	if moving:from.x+=width*.14*minf(1,t/.4)
	var other:="E1" if id=="FV" and ((page==0 and rank==1) or (page==1 and rank in [1,2])) else "MTNK"
	if id=="HARV" and page==1 and rank>=4:other="NATECH"
	d._sprite(id,from,1.0)
	d._sprite(other,to,.85,false,Color.WHITE if friend else Color("#f7ab88"))
	if active:
		var ink:=CYAN if friend else AMBER
		var pulse:=fmod((t-.4)*5,1.0)
		if page==1 or (id=="FV" and rank in [2,3,4]):
			stage.draw_arc(to,12+pulse*19,0,TAU,40,Color(ink,1-pulse*.7),2,true)
		stage.draw_dashed_line(from+Vector2(12,-9),to-Vector2(14,8),Color(ink,.65),2,5)
		if id=="HARV" and page==1 and rank==3:
			d._text(Vector2(width*.40,44),"%d%%"%mini(500,100+20*floori(t*24)),AMBER)
	d._text(Vector2(width*.08,130),str(phase[1 if active else 0]),CYAN if active else Color.WHITE)

static func card(s) -> String:
	var t:float=s.elapsed
	var a:Vector2=s.A
	var b:Vector2=s.B
	if s.card!="ap_convoy_press":s.actor(a,s.ALLY)
	match s.card:
		"ap_convoy_crew":
			var pick:=clampf((t-1)/1.2,0,1)
			s.draw_rect(Rect2(123,17,100,24),s.MUTED,false,1)
			s.draw_string(ThemeDB.fallback_font,Vector2(130,34),"工程师   大兵",HORIZONTAL_ALIGNMENT_LEFT,-1,12,s.ALLY)
			if pick<1:s.actor(b.lerp(a,pick),s.BONUS,PI,false)
			else:s.ring(a,23,s.ALLY)
			return "手动点名 · 按当前科技列出普通步兵" if t<1 else ("乘员入座 · 冷却 %d 秒"%[40,36,32,28][s.preview_rank])
		"ps_convoy_mirror":
			s.actor(b,s.FOE,PI,false)
			for i in 3:s.shot(a,b,.3+i)
			if t>=3:
				var mirror:=a+Vector2(58,-23)
				s.actor(mirror,Color(s.ALLY,.75),0,false);s.ring(mirror,15,s.ALLY)
				for i in 5:s.shot(mirror,b,3.2+i)
			return "同一炮塔连续工作三轮" if t<3 else "副炮塔独立射击 · 效率 %d%%"%[50,60,70,80][s.preview_rank]
		"ap_convoy_press":
			var firing:=a.lerp(b,.35)
			var miner:=a.lerp(firing,clampf((t-1.4)/2.0,0,1))
			s.actor(miner,s.ALLY)
			s.actor(b,s.FOE,PI,false)
			s.actor(b-Vector2(35,0),s.FOE,PI,false)
			if t<3.4:s.draw_dashed_line(miner,firing,s.ALLY,2,6)
			s.draw_line(firing,b,Color(s.BONUS,.65),2)
			s.shot(firing,b,4.0,true)
			if t>=4.0:
				s.draw_dashed_line(firing+Vector2(18,8),b+Vector2(0,8),s.BONUS,8,9)
				return "热锭出膛 · 封路 %.1f 秒"%maxf(0,9.0-t)
			if t<1.4:return "原仓 1/4 · 热锭备妥，预览驶近路线和弹道"
			return "Auto W · 两个敌车在弹道上，自动驶入五格" if t<3.4 else "进入射程 · 压锤 0.6 秒"
		"ps_convoy_heat":
			var keep:=1+.5*int(s.preview_rank)
			var heat:=clampf(t,0,4) if t<5 else maxf(0,4-maxf(0,t-5-keep))
			var gear:=3 if heat>=4 else 2 if heat>=2 else 1
			s.actor(b,s.FOE,PI,false)
			if t<5:s.shot(a,b,t-fmod(t,.65/([1,1.3,1.6][gear-1])))
			for i in 3:s.draw_rect(Rect2(122+i*29,28,23,8),s.BONUS if i<gear else s.MUTED)
			return "第 %d 档 · %s"%[gear,"持续射击" if t<5 else "停火保温" if t<5+keep else "余热回落"]
	return ""

