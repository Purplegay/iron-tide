extends RefCounted
const AirSupport=preload("res://scripts/ui/boris_air_support_demo.gd")

static func value(id:String,key:String) -> float:
	return float(GameData.get_skill(id).values[key][0])

static func first_fill() -> float:
	return 8.0-2.0*(1.0/(1.0-value("ps_peregrine_rearm","reload"))-1.0)

static func duration(id:String) -> float:
	if id=="ORCA":return first_fill()+44
	if id=="BORIS":return 15+AirSupport.recharge()
	return 16.0

static func sample(id:String,t:float) -> Dictionary:
	if id=="ORCA":return peregrine(t)
	if id=="BORIS":return boris(t)
	return leizhu(t)

static func peregrine(t:float) -> Dictionary:
	var fill:=first_fill()
	var finish:=fill+36
	var step:=1.0-value("ps_peregrine_rearm","reload")
	var shots:=0
	var rounds:=0
	var progress:=0.0
	var ammo:=5
	if t>=1 and t<fill:
		ammo=4
		progress=(minf(t,3)-1)/7.0+clampf(t-3,0,2)/(7*step)+maxf(0,t-5)/7.0
	elif t>=fill+1 and t<finish:
		shots=mini(5,1+floori(t-fill-1))
		rounds=mini(5,floori((t-fill-1)/7))
		ammo=5-shots+rounds;progress=fmod(t-fill-1,7)/7
	var cycle:=int(t>=fill)+int(t>=finish)
	var shield:=minf(value("ps_peregrine_rearm","cap")*100,(1+cycle)*value("ps_peregrine_rearm","shield")*100)
	var landed:=t>=finish+2
	var empty_speed:=t>=fill+5 and t<fill+8
	var maintenance_shield:=20.0 if landed else 0.0
	var hp:=60.0+cycle*5+maxf(0,t-(finish+5))*2
	var phase:="悬停待命：初始满仓只带一层整备盾"
	if t>=1:phase="悬停发射并有效命中，原地空中补弹"
	if t>=3:phase="普通飞机停在机场：只加速游隼补弹，保留百分比"
	if t>=5:phase="普通飞机离场：恢复7秒/发，已有补弹百分比不清零"
	if t>=fill:phase="真实补满：叠一层整备盾；有效命中兑现检修回血5%"
	if t>=fill+1:phase="连续发射5发；补弹计时继续，最后一发打空"
	if t>=fill+5:phase="弹仓打空：移速+20%持续3秒，仍可选择原地悬停"
	if t>=fill+8:phase="逐发空中补弹：部分补回不叠盾、不回血"
	if t>=finish:phase="第二次真实补满：再叠一层盾并回血，周期资格刷新"
	if t>=finish+1:phase="在机场附近按J下降；不占停机位，持续空中补弹规则"
	if landed:phase="落地维护：独立20%护盾；连续无伤3秒后每秒回血2%"
	return {"phase":phase,"ammo":ammo,"progress":progress,"shield":shield,"hp":hp,"parked":t>=3 and t<5,
		"seconds":7*step if t>=3 and t<5 else 7.0,"cycle":cycle,"speed":1.2 if empty_speed else 1.0,
		"maintenance_shield":maintenance_shield,"landed":landed,"lift":1-clampf(t-finish-1,0,1),"fill":fill,"finish":finish}

static func boris(t:float) -> Dictionary:
	var stamps:=mini(3,maxi(0,1+floori((t-1)/2))) if t<6 else 0
	var occupied:=t>=6 and t<13
	var main:=4 if t>=6 and t<11 else 0
	var secondary:=2 if t>=6 and t<13 else 0
	var w_cd:=float(GameData.get_skill("ap_boris_corridor").cooldown_by_rank[0])
	var phase:="普通步枪每隔2秒有效命中，积累三枚射章"
	if t>=6:phase="原生空袭消耗三章：主4＋副2共六架继承同一增伤／扩圈"
	if t>=7:phase="独立施放W：不重置原生空袭占用；三章已用，W不再享受"
	if t>=8:phase="首枚炸弹命中：只发一轮空地接力，后续命中不续资格"
	if t>=9:phase="步兵消耗一次半装填；副队命中不重新发放"
	if t>=11:phase="主队正常离场：只落一份补给，副队仍在占用本轮"
	if t>=12:phase="拾取补给回复15%生命；另一架离场不会补发第二份"
	if t>=13:phase="六架全部结束：此刻才开始原生空袭完整补充"
	if t>=13+AirSupport.recharge():phase="原生补充完成：可再次呼叫；W保持自己的冷却"
	return {"phase":phase,"stamps":stamps,"main":main,"secondary":secondary,"occupied":occupied,
		"native_cd":maxf(0,AirSupport.recharge()-maxf(0,t-13)) if t>=6 else 0.0,"w_cd":maxf(0,w_cd-maxf(0,t-7)) if t>=7 else 0.0,
		"damage":1+3*value("ps_boris_receipt","damage"),"radius":1+3*value("ps_boris_receipt","radius"),
		"relay":t>=8 and t<9,"relay_grants":int(t>=8),"supplies":int(t>=11),"pickup":t>=11 and t<12,"hp":75 if t>=12 else 60}

static func leizhu(t:float) -> Dictionary:
	var stopped:=t>=9 and t<12
	var court:=t>=1 and t<minf(9,1+float(GameData.get_skill("ap_leizhu_court").values.life[1]))
	var charge:=0 if t<2 or t>=4 else 1 if t<3 else 2
	var stolen:=10.0 if t>=2 and t<3 else 0.0
	var recycled:=4.0 if t>=3 and t<5 else 0.0
	var phase:="进入缺电基地：基础收支-60，供电100后为+40"
	if t>=1:phase="开启三极电庭：减速＋每0.5秒DOT；DOT不积电荷"
	if t>=2:phase="第一发主电击打掉20敌盾：夺取盾10，积电荷1层"
	if t>=3:phase="第二发积2层；敌普通电击20先耗夺取盾10、扣血10，回收盾4"
	if t>=4:phase="第三发归零并以自身为中心放电；追加电伤不再积层或递归"
	if t>=5:phase="友军受普通电伤100：承担80，转移份额20×20%=4，耗尽回收盾"
	if t>=7:phase="转移伤害不生成回收盾；电庭DOT继续，但电荷仍为0"
	if t>=9:phase="普通致命伤：留1血＋40应急盾；停堆3秒，电庭／供电／分流停止"
	if t>=12:phase="存活结束停堆：恢复20生命，供电与分流恢复；电庭不重建，W不刷新"
	return {"phase":phase,"court":court,"charge":charge,"stolen":stolen,"recycled":recycled,"stopped":stopped,
		"power":0 if stopped else 100,"divert":not stopped,"hp":100 if t<3 else 90 if t<9 else 1 if t<12 else 20,
		"emergency":40 if t>=9 else 0,"coil":8 if t>=8 and t<9 else 0,"ally_hp":100 if t<5 else 20,
		"w_cd":maxf(0,float(GameData.get_skill("ap_leizhu_court").cooldown_by_rank[1])-maxf(0,t-1)) if t>=1 else 0.0,"arc":t>=4 and t<4.35}
