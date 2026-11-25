extends RefCounted

static func draw(view,width:float) -> void:
	if view.talent.selected==1 and view.levels.selected>0:
		if view.levels.selected>=4:
			preload("res://scripts/ui/leizhu_safety_demo.gd").draw(view,width);return
		if view.levels.selected==3:
			preload("res://scripts/ui/leizhu_insulation_demo.gd").draw(view,width);return
		preload("res://scripts/ui/leizhu_defense_demo.gd").draw(view,width);return
	if view.talent.selected==0 and view.levels.selected>0:
		preload("res://scripts/ui/leizhu_command_demo.gd").draw(view,width);return
	var t:float=view.elapsed
	var hero:=Vector2(width*.25,88)
	var target:=Vector2(width*.75,88)
	if view.talent.selected==0:
		view._text(Vector2(8,22),"高压标定 · 第二发消耗标定，不重新施标",UiKit.COL_GOLD)
		view._sprite("TTNK",hero,.75)
		view._sprite("HTNK",target,.65,false,Color(.95,.6,.6))
		var first:=t>=1 and t<3
		if first:view.stage.draw_arc(target,31,0,TAU,28,Color.CYAN,2)
		if (t>=1 and t<1.25) or (t>=3 and t<3.25):view.stage.draw_line(hero,target,Color(.65,.85,1),3)
		view._text(target+Vector2(-65,40),"等待首发" if t<1 else "标定剩余 %.1f 秒"%(5-t) if first else "第二发 +10% · 标定消耗",Color.CYAN)
	else:
		view._text(Vector2(8,22),"线圈护套 · 移动中停火也能准备",UiKit.COL_GOLD)
		hero.x+=minf(t,4)*20
		view._sprite("TTNK",hero,.75,t<4)
		var shielded:bool=(t>=4 and t<10) or t>=22
		if shielded:view.stage.draw_arc(hero,32,0,TAU,32,Color(.65,.8,1),2)
		view._text(hero+Vector2(-65,40),"停火 %.1f/4 秒"%t if t<4 else "护套盾 8/100" if shielded else "护盾消退 · 间隔 %.1f 秒"%(22-t),Color.CYAN)
		view._text(Vector2(8,142),"4 秒生成 · 10 秒消退 · 22 秒再次生成；破盾不爆炸",UiKit.COL_OK)
