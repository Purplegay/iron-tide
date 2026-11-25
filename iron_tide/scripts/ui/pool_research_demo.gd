extends RefCounted

const PASSIVE := ["ps_flank_cover", "ps_swimming", "ps_emergency_plate", "ps_rally_guard"]

static func supports(id:String) -> bool:
	return Unit.PoolCards.ACTIVES.has(id) or id in PASSIVE

static func result(id:String,rank:int) -> String:
	match id:
		"ap_sonar_jam":return "敌舰装填暂停 %d 秒" % (2+rank)
		"ap_ivan_trigger":return "引信剩一半时引爆，造成 %d%% 伤害" % (70+5*rank)
		"ap_carrier_reserve":return "增派两架，增援窗口 %d 秒" % [10,13,16,20][rank]
		"ap_chrono_return":return "返回传送起点，冷却 %d 秒" % [36,32,28,24][rank]
		"ap_extra_volley":return "追加一轮射击，冷却 %d 秒" % [30,27,24,21][rank]
		"ap_scout_flare":return "照亮前方迷雾 %d 秒" % (4+rank)
		"ps_swimming":return "渡水上岸，继续执行移动命令"
		"ps_flank_cover":return "队友少受 %d%% 伤害，分摊部分再减 %d%%" % [4+2*rank,5+5*rank]
		"ps_emergency_plate":return "这次命中减伤 %d%%" % (20+5*rank)
		"ps_rally_guard":return "双方各挡一击，冷却 %d 秒" % (60-10*rank)
	return ""

static func paint(s) -> String:
	var t:float=s.elapsed
	var phase:=clampf((t-2)/2.5,0,1)
	var a:Vector2=s.A
	var b:Vector2=s.B
	var before:=t<2
	var trigger: String
	match s.card:
		"ap_sonar_jam":
			trigger="敌舰正在装填"
			s.actor(a,s.ALLY);s.actor(b,s.FOE)
			s.draw_rect(Rect2(b-Vector2(32,30),Vector2(64,5)),s.MUTED)
			s.draw_rect(Rect2(b-Vector2(32,30),Vector2(14+minf(t,2)*14,5)),s.BONUS)
			if not before:s.ring(b,20+fmod(t*15,14),s.ALLY)
		"ap_carrier_reserve":
			trigger="常规舰载机已经起飞，目标仍在射程内"
			s.actor(a,s.ALLY);s.actor(b,s.FOE)
			for i in (1 if before else 3):s.actor(a.lerp(b,fmod(t*.18+i*.16,1))+Vector2(0,-20+i*13),s.ALLY,0,false)
		"ap_chrono_return":
			trigger="恢复还剩3秒，附近有3名敌人"
			s.ring(a,17,s.MUTED);s.actor(b-Vector2(70,0) if before else a,s.ALLY)
			for i in 3:s.actor(b+Vector2(-20*i,22*i-20),s.FOE)
		"ap_extra_volley":
			trigger="武器对准目标，即将开火"
			s.actor(a,s.ALLY);s.actor(b,s.FOE);s.shot(a,b,2);s.shot(a,b,2.65,true)
		"ap_ivan_trigger":
			trigger="已装弹的目标旁又出现两名敌人"
			s.actor(a,s.ALLY);s.actor(b,s.FOE)
			for sign_y in [-1,1]:s.actor(b+Vector2(-30,sign_y*lerpf(48,20,minf(t/2,1))),s.FOE)
			if not before:s.ring(b,15+phase*36,s.BONUS)
		"ap_scout_flare":
			trigger="前进方向被迷雾遮挡"
			s.actor(a,s.ALLY);s.draw_rect(Rect2(180,36,145,63),Color.DARK_SLATE_GRAY)
			if not before:s.draw_circle(b,32,s.MUTED);s.actor(b,s.FOE);s.ring(b,32,s.BONUS)
		"ps_swimming":
			trigger="收到前往对岸的移动命令"
			s.draw_rect(Rect2(115,41,95,55),Color.STEEL_BLUE);s.actor(a.lerp(b,t/6),s.ALLY)
		"ps_rally_guard":
			trigger="离队8秒后重新靠近友军"
			var pos:=a.lerp(b-Vector2(33,0),minf(t/2,1));s.actor(pos,s.ALLY);s.actor(b,s.ALLY,0,false)
			if not before:s.ring(pos,18,s.BONUS);s.ring(b,18,s.BONUS)
		"ps_flank_cover":
			trigger="身旁友军受到直接命中"
			var friend:=a+Vector2(50,10);s.actor(a,s.ALLY);s.actor(friend,s.ALLY,0,false);s.actor(b,s.FOE);s.shot(b,friend,1.55)
			if not before:s.draw_line(friend,a,s.BONUS,3);s.ring(a,18,s.BONUS)
		"ps_emergency_plate":
			trigger="本次命中将使生命降到一半以下"
			s.actor(a,s.ALLY);s.actor(b,s.FOE);s.shot(b,a,1.55)
			if not before:s.ring(a,19,s.BONUS)
	var label:="Auto W" if Unit.PoolCards.ACTIVES.has(s.card) else "被动"
	s.draw_string(ThemeDB.fallback_font,Vector2(8,20),label+" · "+trigger,HORIZONTAL_ALIGNMENT_CENTER,334,12,Color.WHITE)
	return "等待触发" if before else result(s.card,s.preview_rank)
