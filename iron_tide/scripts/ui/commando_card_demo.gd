extends RefCounted
const ACTIVE="ap_tanya_breach"
const PASSIVE="ps_tanya_rhythm"

static func sample(id:String,rank:int,time:float) -> Dictionary:
	if id in ["ap_leizhu_court","ps_leizhu_charge"]:return preload("res://scripts/ui/leizhu_card_demo.gd").sample(id,rank,time)
	if id in ["ap_peregrine_hunt","ps_peregrine_rearm"]:return preload("res://scripts/ui/peregrine_card_demo.gd").sample(id,rank,time)
	if id in ["ap_boris_corridor","ps_boris_receipt"]:return preload("res://scripts/ui/boris_card_demo.gd").sample(id,rank,time)
	var card:=GameData.get_skill(id)
	if id==ACTIVE:
		return {"damage":200.0*float(card.values.damage[rank]),"cooldown":float(card.cooldown_by_rank[rank]),"active":time>=.5 and time<3.1,"text":"示例攻击200 · 每枚 %.0f伤害（护甲前） · 第三枚被敌人击毁，不爆炸"%(200.0*float(card.values.damage[rank]))}
	var life:=float(card.values.life[rank])
	var active:=time>=1.0 and time<1.0+life
	return {"active":active,"life":life,"defense":float(card.values.defense[rank]),"text":"双枪击杀敌步兵" if time<1 else ("节拍 %.1fs · 移速+25%% / 远程减伤%d%% · 期间击杀不续时"%[1+life-time,roundi(card.values.defense[rank]*100)] if active else "节拍结束 · 8秒触发间隔尚未结束" if time<9 else "触发间隔结束，可以再次触发")}

static func draw(stage) -> String:
	if stage.card in ["ap_leizhu_court","ps_leizhu_charge"]:return preload("res://scripts/ui/leizhu_card_demo.gd").draw(stage)
	if stage.card in ["ap_peregrine_hunt","ps_peregrine_rearm"]:return preload("res://scripts/ui/peregrine_card_demo.gd").draw(stage)
	if stage.card in ["ap_boris_corridor","ps_boris_receipt"]:return preload("res://scripts/ui/boris_card_demo.gd").draw(stage)
	var t:float=stage.elapsed
	var state:=sample(stage.card,stage.preview_rank,t)
	var a:Vector2=stage.A
	var b:Vector2=stage.B
	stage.actor(a,stage.ALLY)
	stage.actor(b,stage.FOE,PI,false)
	if stage.card==ACTIVE:
		for i in 3:
			var launch:=.5+.35*i
			var end:Vector2=b+Vector2(-40,(i-1)*34)
			if t<launch:continue
			if i==2 and t>=2.0:
				if t<2.4:
					stage.shot(b,end,1.7)
					stage.draw_line(end-Vector2(6,6),end+Vector2(6,6),stage.FOE,2)
					stage.draw_line(end-Vector2(-6,6),end+Vector2(-6,6),stage.FOE,2)
				continue
			if t<launch+.4:
				var progress:=clampf((t-launch)/.4,0,1)
				var point:=a.lerp(end,progress)-Vector2(0,sin(progress*PI)*28)
				stage.draw_rect(Rect2(point-Vector2(4,3),Vector2(8,6)),stage.BONUS)
			elif t<launch+1.9:
				stage.draw_rect(Rect2(end-Vector2(5,4),Vector2(10,8)),stage.BONUS)
				stage.ring(end,12,stage.BONUS)
			else:
				var fade:=clampf(1.0-(t-launch-1.9)/.5,0,1)
				if fade>0:stage.ring(end,25,Color(1,.6,.2,fade))
	else:
		stage.shot(a,b,.75)
		if state.active:
			stage.ring(a,26,stage.BONUS)
			for i in 3:stage.draw_line(a-Vector2(20+i*7,-10),a-Vector2(24+i*7,-10),stage.ALLY,2)
		if t>=2 and t<2.3:stage.shot(a,b,1.75)
	return state.text
