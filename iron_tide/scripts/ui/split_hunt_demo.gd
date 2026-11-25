extends RefCounted
## Illustrative damage is before armor; no player upgrades or live battle are changed.
const LENGTH:=20.0
const CELL:=28.0
const MAIN:=Vector2(309,56)

static func sample(rank:int,time:float) -> Dictionary:
	var t:=fposmod(time,LENGTH)
	var part:=int(t/4)
	var local:=fposmod(t,4)
	var elite:=part==4
	var weapon:Dictionary=GameData.get_unit("APOC")["elite_weapon" if elite else "weapon"]
	var attack:=200.0 if part==3 else 100.0
	var second:=MAIN+Vector2(-50,13) if part==0 or elite else MAIN+Vector2(-20,5)
	var targets:Array[Vector2]=[MAIN]
	var hits:Array[int]=[0]
	if part not in [1,3]:targets.append(second);hits.append(0)
	var rounds:Array=[]
	var active:=false
	for i in int(weapon.burst):
		var destination:Vector2=targets[i%targets.size()]
		var launch:float=.8+i*float(weapon.burst_delay)
		var impact:=launch+.46
		rounds.append({"at":launch,"impact":impact,"point":destination,"barrel":i%2})
		if local>=impact:
			for j in targets.size():
				if targets[j].distance_to(destination)<=CELL:hits[j]+=1
		if local>=impact and local<impact+.3:active=true
	var title:String=["双目标 · 左右分别命中","单目标 · 双炮仍然集火","近邻重叠 · 每枚分别结算","攻击成长 · 比例仍为10%","精英四发 · 不增弹数或射速"][part]
	var text:="仅示意追加伤害 · 直击照常 · 不递归"
	return {"time":t,"local":local,"part":part,"active":active,"value":10.0,"charges":rounds.size(),"attack":attack,"splash":attack*.1,"targets":targets,"hits":hits,"rounds":rounds,"radius":MetaProgress.talent_options("APOC").split_hunt.values.radius[rank],"title":title,"text":text}

static func draw(view,origin:Vector2,s:Dictionary) -> void:
	view.draw_string(ThemeDB.fallback_font,Vector2(10,18),s.title,HORIZONTAL_ALIGNMENT_LEFT,-1,12,Color.WHITE)
	view.draw_string(ThemeDB.fallback_font,Vector2(10,35),"攻击%.0f示例：每枚追加%.0f（护甲前）"%[s.attack,s.splash],HORIZONTAL_ALIGNMENT_LEFT,-1,11,Color.SKY_BLUE)
	view.draw_string(ThemeDB.fallback_font,Vector2(10,51),"副目标搜索%.1f格 · 溅射固定1格"%s.radius,HORIZONTAL_ALIGNMENT_LEFT,-1,10,Color.GRAY)
	for i in s.targets.size():
		var point:Vector2=s.targets[i]
		var label:=point+Vector2(10,-4) if i==0 else point+Vector2(-30,30)
		view.draw_circle(point,7,Color.SALMON)
		view.draw_string(ThemeDB.fallback_font,label,"主目标" if i==0 else "副目标",HORIZONTAL_ALIGNMENT_LEFT,-1,10,Color.SALMON)
		view.draw_string(ThemeDB.fallback_font,label+Vector2(0,15),"追加 %.0f × %d"%[s.splash,s.hits[i]],HORIZONTAL_ALIGNMENT_LEFT,-1,10,Color.GOLD)
	for shot:Dictionary in s.rounds:
		var color:=Color.GOLD if shot.barrel==0 else Color.SKY_BLUE
		var launch:Vector2=origin+Vector2(0,-5 if shot.barrel==0 else 5)
		var fraction:float=(s.local-shot.at)/.46
		if fraction>=0 and fraction<1:
			view.draw_line(launch.lerp(shot.point,maxf(0,fraction-.2)),launch.lerp(shot.point,fraction),color,2,true)
		if s.local>=shot.impact and s.local<shot.impact+.3:
			view.draw_arc(shot.point,CELL,0,TAU,32,color,2,true)
	if s.part==2:
		# Faint outlines keep the two independently counted blast areas readable after impact.
		for point in s.targets:view.draw_arc(point,CELL,0,TAU,32,Color(.9,.7,.2,.25),1,true)
