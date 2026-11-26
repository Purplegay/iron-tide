extends RefCounted

# The preview shares the roster's rank selection, playback clock and native sprites.
static func draw(view,width:float) -> void:
	var t:float=view.elapsed
	var rank:int=view.levels.selected
	var defense:bool=view.talent.selected==1
	var hero:=Vector2(width*.22,103)
	var target:=Vector2(width*.64,101)
	var times:Array
	var label:String
	var building:=false
	var walk:=false
	var enemies:=1
	var damage:=1.0
	match view.hero_id:
		"CLNT":
			if defense:
				times=[1.0,2.2,3.4]
				damage=1.8 if rank==2 and t>=3.4 else (1.4 if rank>=1 and t>=2.2 else 1.0)
				label="点名 · 首枪 +1 格" if t<2.2 else "第 %d 枪 · 伤害 ×%.1f"%[3 if t>=3.4 else 2,damage]
			else:
				enemies=rank+1
				times=[1.0,1.2]
				if rank>=1:times.append(1.35)
				if rank==2:times.append(1.5)
				label="首发 → 仅 20% 冷却 → 第二发" if t<1.35 or rank==0 else "击倒后补枪 ×%d"%mini(rank,1 if t<1.5 else 2)
		"ARND":
			if defense:
				times=[]
				var active:=t>=1 and t<4
				walk=active and rank>=1
				hero.x+=minf(maxf(t-1,0),3)*13 if rank>=1 else 0.
				var hp:=1.0 if t<1 else (.75 if t>=4 and rank==2 else .5)
				view.stage.draw_rect(Rect2(hero+Vector2(-28,-49),Vector2(56,5)),Color.DIM_GRAY)
				view.stage.draw_rect(Rect2(hero+Vector2(-28,-49),Vector2(56*hp,5)),Color.LIME_GREEN)
				label="受伤至半血" if t<1 else ("硬汉 · 减伤 30%" if active else ("恢复 25% 生命" if rank==2 else "保护结束 · 冷却中"))
			else:
				enemies=2 if rank>=1 else 1
				times=[.7,1.6,2.4,3.1,3.8,4.5]
				label="热枪 · 逐发缩短间隔"
				if t>=3.1 and rank>=1:label="转移火力 · 保留 3 层"
				if t>=3.8 and rank==2:label="持续命中 · 减速 40%"
		"STLN":
			building=defense
			if defense:
				times=[1.0,2.5,4.0]
				label="第 1 发 · 对建筑增伤 20%"
				if t>=2.5:label="第 2 发 · 校准溅射" if rank>=1 else "第 2 发 · 直接命中"
				if t>=4:label="第 3 发 · 强化爆炸" if rank==2 else "第 3 发 · 直接命中"
			else:
				times=[.7,3.0] if rank<2 else [.7,3.0,3.9]
				walk=t>=.7 and t<2.8
				hero.x+=minf(maxf(t-.7,0),2.1)*24
				enemies=2 if rank==2 else 1
				label="命中 · 移速 +25%" if rank==0 or t<2.8 else ("回马枪 · 伤害 +40%" if t<3.9 or rank<2 else "击倒 · 赠送一次回马枪")
	view._sprite(view.hero_id,hero,1.35,walk)
	var aim:=target
	for i in enemies:
		var at:=target+Vector2(i*30,-i*13)
		if building:
			var art:=RA2Art.art("GAPILL")
			var rect:=RA2Art.draw_rect(art,0,[0],0,.45)
			rect.position+=at
			RA2Art.draw_sprite(view.stage,art,rect,RA2Art.src_rect(art,0),Color.WHITE)
			view._sprite("E2",at+Vector2(33,0),.85)
		else:
			var down:bool=(view.hero_id=="CLNT" and not defense and i<rank and t>=1.2+i*.15) or (view.hero_id=="ARND" and not defense and rank>=1 and i==0 and t>=3.1) or (view.hero_id=="STLN" and not defense and rank==2 and i==0 and t>=3.0)
			if not down:view._sprite("E2",at,1.05,false,Color.WHITE,2)
			else:aim=target+Vector2((i+1)*30,-(i+1)*13)
	for index in times.size():
		var age:float=t-float(times[index])
		if age<0 or age>.22:continue
		view.stage.draw_line(hero+Vector2(7,-18),aim+Vector2(0,-15),Color.GOLD,2)
		if building and index>=1 and rank>=index:
			view.stage.draw_arc(target,12+age*(140 if index==2 else 85),0,TAU,32,Color.ORANGE,3)
	view._text(Vector2(12,24),label,UiKit.COL_GOLD)
