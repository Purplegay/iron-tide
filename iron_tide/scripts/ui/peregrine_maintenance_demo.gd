extends RefCounted
const LENGTH=34.0

static func sample(t:float) -> Dictionary:
	var clock:=fposmod(t,LENGTH)
	# First landing at 2; shield-only hit at 6; exit at 10; second landing at 12.
	var grounded:=clock>=2 and clock<10 or clock>=12 and clock<31 or clock>=33
	var shield:=20 if clock>=2 and clock<6 or clock>=33 else 10 if clock>=6 and clock<10 else 0
	var quiet:=clampf(clock-2,0,4) if clock<6 else clampf(clock-6,0,4) if clock<10 else maxf(0,clock-12) if clock<31 else maxf(0,clock-33)
	var hp:=50+2*(clampf(clock-5,0,1)+clampf(clock-9,0,1)+clampf(clock-15,0,16))
	var lift:=20.0 if clock<1 else 20*(2-clock) if clock<2 else 0.0 if grounded else 20*(clock-10) if clock<11 else 20*(12-clock) if clock<12 else 20*(clock-31) if clock<32 else 20*(33-clock)
	var cd:=maxf(0,32-clock) if clock>=2 and clock<33 else 63-clock if clock>=33 else 0.0
	return {"time":clock,"grounded":grounded,"shield":shield,"hp":hp,"quiet":quiet,"lift":lift,"cooldown":cd,
		"ammo":2 if clock<8 else 3 if clock<16 else 4,
		"phase":"初始已耗2发、无有效命中；满员机场旁按J" if clock<1 else "下降1秒，不占停机位" if clock<2 else "落地获20盾，连续无伤3秒才开始回血" if clock<6 else "第6秒敌伤由盾吸收，无伤等待重新计3秒" if clock<10 else "起飞立即消盾；再次落地仍在30秒间隔内" if clock<15 else "第二次落地无盾，满3秒无伤仍能正常回血" if clock<33 else "原30秒间隔已结束，第三次落地才再次得盾"}

static func draw(view,width:float) -> void:
	var s:=sample(view.elapsed);var t:float=s.time
	var hero:=Vector2(width*.23,96);var airport:=Vector2(width*.78,103)
	view._text(Vector2(8,22),"停机护罩 · 受伤推迟回血，反复下降不刷盾",UiKit.COL_GOLD)
	view._text(Vector2(8,43),s.phase,UiKit.COL_DIM)
	view._sprite("GAAIRC",airport,.28)
	view._text(airport+Vector2(-44,25),"机场停机位满",UiKit.COL_DIM)
	view.stage.draw_line(hero+Vector2(-22,9),hero+Vector2(22,9),Color(0,0,0,.35),5)
	view._sprite("ORCA",hero-Vector2(0,s.lift),.7,false,Color.WHITE,2)
	if s.shield>0:view.stage.draw_arc(hero,31,0,TAU,32,Color(.4,1,.6),2)
	if t>=5.7 and t<6:view.stage.draw_circle(Vector2(width*.58,85).lerp(hero,(t-5.7)/.3),3,Color.ORANGE)
	view._text(Vector2(8,126),"生命%.1f/100 · 护盾%d · 弹药%d/4"%[s.hp,s.shield,s.ammo],UiKit.COL_OK)
	view._text(Vector2(8,142),"无伤等待%.1f/3秒 · 发盾间隔%.1f秒 · 指挥Lv.0"%[minf(3,s.quiet) if s.grounded else 0,s.cooldown],Color.CYAN)
