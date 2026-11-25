extends RefCounted
const CARD:="ap_escort_water"
const IDS:=["caster","near","next","fourth"]
const POINTS:=[Vector2(40,62),Vector2(113,62),Vector2(202,62),Vector2(285,62)]

static func duration() -> float:
	var values:Dictionary=GameData.get_skill(CARD).values
	return float(values.duration.max())+float(values.relay_duration.max())+2

static func sample(rank:int,time:float) -> Dictionary:
	var values:Dictionary=GameData.get_skill(CARD).values
	var t:=fposmod(time,duration())
	var life:float=values.duration[rank]
	var defense:float=values.defense[rank]
	var active:=t<life
	var count:int=values.targets[rank]
	var members:Array=["caster"]
	for i in 3:
		if members.size()<=count and [1.2,1.8,3.0][i]<=float(values.radius[rank]):members.append(IDS[i+1])
	var health:Dictionary={"caster":1000.,"near":600.,"next":800.,"fourth":900.}
	var cap:float=1000*values.relay_cap[rank]
	var stored:=0.0
	var hit_times:Array=[]
	for i in members.size():
		var at:float=life*(.2+.6*i/maxi(1,members.size()-1))
		hit_times.append(at)
		if t>=at:
			var damage:=Ra2Damage.quantize(450*(1-defense))
			health[members[i]]-=damage;stored=minf(cap,stored+450-damage)
	var recipient:String=members[0]
	for id:String in members:
		if health[id]<health[recipient]:recipient=id
	var shield:=stored if not active and t<life+float(values.relay_duration[rank]) else 0.0
	var shield_before:=shield
	if t>=life+2 and float(values.relay_duration[rank])>2:
		shield=maxf(0,shield-200)
		health[recipient]-=maxf(0,200-stored)
	var text:="共享储量 %.0f / %.0f · 重叠只计最强水幕"%[stored,cap]
	if not active:text="转给最低生命比例舰船 · 护盾 %.0f · 不回血"%shield
	if t>=life+float(values.relay_duration[rank]):text="余波护盾到期 · 本次储量已结算，不会再次发放"
	return {"time":t,"active":active,"value":defense*100,"charges":members.size() if active else 0,"guarded":members if active else [],
		"depart":clampf((t-2)/1.5,0,1),"text":text,"members":members,"health":health,"stored":stored,"cap":cap,"recipient":recipient,
		"shield":shield,"shield_before":shield_before,"transfer":not active and t<life+.6,"life":life,"hit_times":hit_times,
		"shield_left":maxf(0,life+float(values.relay_duration[rank])-t) if not active else 0.0}

static func draw(stage,s:Dictionary) -> void:
	stage.draw_string(ThemeDB.fallback_font,Vector2(8,14),"水幕减伤%d%% → 余波接力 · 示例施法舰生命1000"%s.value,HORIZONTAL_ALIGNMENT_LEFT,-1,10,stage.ALLY)
	stage.draw_string(ThemeDB.fallback_font,Vector2(8,30),"共享 %.0f / %.0f · 最低血量比例接盾"%[s.stored,s.cap],HORIZONTAL_ALIGNMENT_LEFT,-1,11,stage.BONUS)
	for i in IDS.size():
		var id:String=IDS[i];var point:Vector2=POINTS[i]
		stage.actor(point,stage.ALLY,0,i==0)
		if id in s.guarded:stage.ring(point,18,Color.CYAN)
		if id==s.recipient and s.shield>0:stage.ring(point,22,Color(.3,1,.8))
		var label:String=["本舰","近舰","已选舰","候选舰"][i]
		if id not in s.members:label="未保护"
		stage.draw_string(ThemeDB.fallback_font,point+Vector2(-25,24),label,HORIZONTAL_ALIGNMENT_LEFT,-1,10,stage.MUTED)
		stage.draw_string(ThemeDB.fallback_font,point+Vector2(-27,39),"血 %.0f/1000"%s.health[id],HORIZONTAL_ALIGNMENT_LEFT,-1,9,stage.ALLY)
		if id in s.members:
			var at:float=s.hit_times[s.members.find(id)]
			if s.time>=at-.3 and s.time<at:
				var p:Vector2=(point+Vector2(0,-25)).lerp(point,(s.time-at+.3)/.3)
				stage.draw_line(p,p+Vector2(0,-5),stage.FOE,2,true)
		if s.transfer and id in s.members and id!=s.recipient:
			var destination:Vector2=POINTS[IDS.find(s.recipient)]
			stage.draw_line(point,destination,Color(.2,1,.8,.4),1.5,true)
			stage.draw_circle(point.lerp(destination,clampf((s.time-s.life)/.6,0,1)),3,Color.CYAN)
	if not s.active:stage.draw_string(ThemeDB.fallback_font,Vector2(8,123),"接力盾 %.0f · 剩余 %.1fs · 到期后2秒演示承伤200"%[s.shield,s.shield_left],HORIZONTAL_ALIGNMENT_LEFT,-1,10,stage.BONUS)
