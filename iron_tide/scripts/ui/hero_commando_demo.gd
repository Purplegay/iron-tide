extends RefCounted
## Uses the same thresholds/durations as the live Lv.0 traits, with a read-only timeline.
static func escape_sample(t:float) -> Dictionary:
	return preload("res://scripts/ui/tanya_damage_demo.gd").sample(t)

static func draw(view,width:float) -> void:
	if view.hero_id=="TANY" and view.talent.selected==1:
		preload("res://scripts/ui/tanya_damage_demo.gd").draw(view,width);return
	var at:=Vector2(width*0.4,92)
	var enemy:=Vector2(width*0.78,92)
	var t:float=view.elapsed
	var active:=false
	var title:=""
	if view.hero_id=="TANY":
		if view.talent.selected==0:
			view._sprite("NAPOWR",enemy,0.55)
			at=at.lerp(enemy-Vector2(35,0),clampf(t,0,1))
			active=t>=1 and t<3
			title="接近建筑 → 安装 C4 → 减伤 15% 持续 2 秒"
	else:
		if view.talent.selected==0:
			view.stage.draw_arc(at,45,0,TAU,40,Color.GRAY,1.5)
			view.stage.draw_arc(at,65,0,TAU,40,Color.CYAN,1.5)
			view.stage.draw_arc(at,53,0,TAU,40,UiKit.COL_GOLD,1.5)
			title="青色：增加 1 格视野　金色：原有武器射程"
		else:
			active=t>=2 and t<4.5
			if t>=4:at.x+=minf(t-4,1)*65
			view._sprite("E1",enemy,1.1,false,Color.WHITE,2)
			if t>=2.5 and t<2.8:view.stage.draw_line(enemy+Vector2(0,-15),at+Vector2(0,-15),Color.ORANGE,2)
			title="停留 2 秒 → 远程减伤 15% → 移动后保留 0.5 秒"
	view._sprite(view.hero_id,at,1.25,view.hero_id=="BORIS" and view.talent.selected==1 and t>=4 and t<5)
	if active:view.stage.draw_arc(at+Vector2(0,-15),29,0,TAU,32,Color.CYAN,2)
	view._text(Vector2(8,22),title,UiKit.COL_GOLD)
