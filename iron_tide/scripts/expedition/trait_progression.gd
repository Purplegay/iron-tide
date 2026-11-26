extends RefCounted
# First four entries are layers 0..3; the last is added for each layer after 3.
const STATS := {
	"siege_team":{"hit":[0.0,0.02,0.04,0.06,0.01]},
	"pursuit":{"hit":[0.0,0.02,0.04,0.06,0.01]},
	"infantry":{"hp":[0.0,0.10,0.20,0.30,0.05]},
	"vehicle":{"hp":[0.0,0.10,0.20,0.30,0.05],"reduction":[0.0,0.0,0.10,0.15,0.01]},
	"air":{"hp":[0.0,0.10,0.20,0.25,0.03]},
	"naval":{"hp":[0.0,0.10,0.20,0.25,0.03]},
	"fortify":{"hit":[0.0,0.0,0.10,0.15,0.03],"reduction":[0.0,0.08,0.12,0.15,0.01]},
	"mobile":{"speed":[0.0,0.08,0.12,0.15,0.01],"march":[0.0,0.0,0.15,0.25,0.03]},
	"support":{"recovery":[0.0,0.10,0.15,0.20,0.02],"discount":[0.0,0.0,0.15,0.25,0.02]},
	"energy":{"hit":[0.0,0.08,0.12,0.15,0.03]},
	"artillery":{"hit":[0.0,0.08,0.12,0.15,0.03]},
	"special":{"hp":[0.0,0.10,0.15,0.20,0.03],"hit":[0.0,0.0,0.20,0.30,0.03]}
}
const LABELS := {"hp":"生命","hit":"直击伤害","reduction":"额外减伤","speed":"移速","march":"行军首击","recovery":"战后额外恢复","discount":"整备费用降低"}
const OPENINGS := {
	"siege_team":"连续直击同一目标时额外造成 10% 伤害。",
	"pursuit":"换目标直击额外造成 15% 伤害。",
	"infantry":"战地包扎：步兵击杀敌方单位恢复 4% 最大生命，冷却 6 秒；以步兵收尾稳住战线。",
	"vehicle":"行进抢修：持续行驶 2 秒后，每秒恢复 0.5% 最大生命，最多恢复至 50%；残血装甲可撤出抢修再接敌。",
	"air":"起飞掩护：正常补满弹药获得 5% 最大生命护盾；返航补弹后带盾出击，9 层升级为 20%。",
	"naval":"巡航屏障：8 秒未受击且没有攻击目标，获得 8% 最大生命护盾，冷却 20 秒；脱战整修后再压线。",
	"fortify":"掩护射击：停稳 2 秒后命中，使目标对我方的直击伤害降低 10%，持续 2 秒，冷却 6 秒；与重炮 9 层压制取较强者。",
	"mobile":"突击掩护：行军首击触发时获得 5% 最大生命护盾，沿用三格行军与 8 秒冷却；6 层再回血，9 层缩短触发间隔。",
	"support":"战地急救：全军每 5 秒为低于 50% 生命的单位恢复 1% 最大生命，最多至 50%；6 层升级为不限血量的 2% 医疗。",
	"energy":"能量回流：不同兵种在 4 秒内交替命中同一目标，能量单位触发协同时恢复 3% 最大生命，沿用目标 4 秒协同冷却。",
	"artillery":"暴露弱点：目标被标记满 2 秒后，重炮标定命中使其随后 3 秒受到全军直击额外 +10%，沿用目标 6 秒标定冷却；与能量 9 层过载取较强者。",
	"special":"破袭掩护：命中任务目标或低于 35% 生命的敌人，获得 5% 最大生命护盾，冷却 6 秒；9 层击杀同时刷新本项冷却。"
}
const BUILDS := {
	"siege_team":"集中火力持续攻击耐久目标，切换目标会重新计数。",
	"pursuit":"轮流点射两个敌人，再集中火力兑现追击。",
	"infantry":"中期持续医疗稳住步兵线；终局把溢出治疗存成护盾，配合随军医疗与护盾放电匣。",
	"vehicle":"中期驻车补盾再出击；终局驻车装填三发突击弹，移动接敌后连续强击。",
	"air":"中期返航补弹同时修复；终局满弹带盾再出击，三发强化弹配合归航整备印章。",
	"naval":"中期交战抢修持续压线；终局低血触发隔舱护盾，带盾炮击反哺维修。",
	"fortify":"中期停稳建立护盾阵地；终局护盾承伤积累反击，适合大兵／重装大兵站线。",
	"mobile":"中期移动、首击、回血形成游击循环；终局降低行军首击距离和冷却，配合灰熊飞轮反复突击。",
	"support":"中期全军医疗降低持续战损；终局把高血量维护转为全军进攻窗口。",
	"energy":"中期直击充盾；终局让不同兵种交替集火，过载标记继续放大全军后续直击。",
	"artillery":"中期开幕炮击削弱高血目标；终局标定重击压制敌方输出，为阵地军团创造安全射击窗口。",
	"special":"中期靠破袭与收尾回血；终局击杀刷新处决与治疗冷却，连续收割残血目标。"
}

static func value(key:String,stat:String,count:int) -> float:
	var curve:Array=STATS.get(key,{}).get(stat,[])
	if curve.is_empty():return 0.0
	var level:=clampi(count,0,9)
	return float(curve[mini(level,3)])+maxi(0,level-3)*float(curve[4])

static func summary(key:String,count:int) -> String:
	if count<=0:return "尚未获得"
	var parts:PackedStringArray=[]
	for stat:String in STATS[key]:
		var amount:=value(key,stat,count)
		if amount>0:parts.append(str(LABELS[stat])+" +%d%%"%roundi(amount*100))
	var condition:String={"vehicle":"减伤需持续行驶触发；","fortify":"攻防需停稳 2 秒；","special":"伤害加成仅对任务目标；"}.get(key,"")
	return condition+"，".join(parts)

static func growth_description(key:String) -> String:
	var lines:PackedStringArray=[]
	for count in range(1,10):lines.append("%d 层：%s"%[count,summary(key,count)])
	return "\n".join(lines)
