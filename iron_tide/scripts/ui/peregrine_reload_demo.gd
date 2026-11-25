extends RefCounted
## Independent previews use explicit command ranks and no card/airport acceleration.
const MOUNT_LENGTH=10.0
const SIGNATURE_LENGTH=40.0

static func sample(t:float,mount:bool) -> Dictionary:
	var part:=0 if mount or t<10 else 1 if t<20 else 2
	var local:=t if mount or part==0 else t-10 if part==1 else t-20
	var seconds:=7.0 if mount else 8.0
	var capacity:=5 if mount else 4
	var shots:=0 if local<1 else 2 if part==2 and local>=2 else 1
	var restored:=mini(shots,maxi(0,int(floor((local-1)/seconds)))) if local>=1 else 0
	var ammo:=capacity-shots+restored
	var complete:=shots>0 and ammo==capacity
	var valid:=part!=1
	var hit:=valid and local>=2
	var progress:=0.0 if shots==0 or complete else fmod(local-1,seconds)/seconds
	return {"part":part,"time":local,"seconds":seconds,"capacity":capacity,"ammo":ammo,
		"hp":65 if not mount and complete and hit else 60,"full":complete,"hit":hit,
		"progress":progress,"reveal":valid and local>=2 and local<(6 if part==2 else 5),
		"title":"备用挂架 · 五发弹仓，空中每 7 秒补一发" if mount else ["检修签章 · 有效命中后补满回血","检修签章 · 空地强攻，补满也不回血","检修签章 · 消耗两发，仅补一发不回血"][part]}

static func draw(view,a:Vector2,b:Vector2,mount:bool) -> void:
	b=Vector2(b.x,a.y)
	var s:=sample(view.elapsed,mount)
	var t:float=s.time
	view._text(Vector2(8,22),s.title,UiKit.COL_GOLD)
	view._text(Vector2(8,42),"示例：王牌航线 Lv.%d · 无机场／卡牌补弹加速"%(1 if mount else 0),UiKit.COL_DIM)
	view._sprite("ORCA",a,.7,false,Color.WHITE,2)
	if s.part!=1:view._sprite("HTNK",b,.65)
	else:
		view.stage.draw_line(b-Vector2(8,8),b+Vector2(8,8),Color.GRAY,2)
		view.stage.draw_line(b+Vector2(-8,8),b+Vector2(8,-8),Color.GRAY,2)
	for launch:float in [1.0,2.0] if s.part==2 else [1.0]:
		if t>=launch and t<launch+1:view.stage.draw_circle(a.lerp(b,t-launch),3,Color.ORANGE)
	if s.reveal:view.stage.draw_arc(b,30,0,TAU,32,Color(.3,.8,1,.7),1.5)
	view.stage.draw_rect(Rect2(a+Vector2(-44,18),Vector2(88,5)),Color.DIM_GRAY)
	view.stage.draw_rect(Rect2(a+Vector2(-44,18),Vector2(88*s.progress,5)),Color.CYAN)
	view._text(a+Vector2(-48,38),"弹药 %d/%d"%[s.ammo,s.capacity],Color.CYAN)
	view._text(a+Vector2(-48,56),"满弹 · 无需返航" if mount and s.full else "补弹 %.1f/7 秒"%(s.progress*7) if mount else "生命 %d/100"%s.hp,UiKit.COL_OK)
	var status:="等待开火" if t<1 else "普通导弹在途" if t<2 else "空地：无有效命中" if s.part==1 else "有效命中 · 等待补满" if not s.full else "补满：回复 5 生命"
	if mount and t>=2:status="固定落点揭示 3 秒" if s.reveal else "完成空中补弹" if s.full else "等待第 5 发补回"
	if s.part==2 and s.ammo==3 and t>=9:status="仅 3/4 发 · 不回血"
	view._text(b+Vector2(-88,30),status,UiKit.COL_OK)
	if not mount:view._text(b+Vector2(-88,49),"补满不返机场、不占机位",UiKit.COL_DIM)
