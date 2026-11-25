extends RefCounted
## Independent read-only examples; Q/save/repair labels describe the illustrated events.
const LENGTH:=68.0
const SPANS:=[14.0,17.0,17.0,10.0,10.0]
const FIRST:=Vector2(309,51)
const NEXT:=Vector2(239,111)

static func sample(rank:int,time:float) -> Dictionary:
	var t:=fposmod(time,LENGTH)
	var local:=t
	var part:=0
	while local>=SPANS[part]:local-=SPANS[part];part+=1
	var auto_on:=true
	if part==1:auto_on=local<1 or (local>=10 and local<12.65)
	if part==4:auto_on=local>=9
	var other_auto:=part==4 and (local<1 or local>=9)
	var repaired:=part==3 and local>=8.5
	var hits:=0 if local<.5 else mini(3,1+int((local-.5)/4))
	if repaired:hits=0
	var leap_at:=8.5 if part==0 else (12.5 if part in [1,2] else INF)
	var started:=local>=leap_at
	var active:=started and local<leap_at+.35
	var landed:=started and not active
	var tears:=clampi(int(floor(local-leap_at)),0,3) if started else 0
	var cooldown:=maxf(0,10-(local-leap_at)) if started else 0.0
	var candidate:=part!=2 or local>=10
	var title:String=["自动开启 · 满足条件跳宿","Q开关 · 读档与途中关闭","无新宿主 · 保留当前寄生","维修清除优先","多选Q · 混合状态统一切换"][part]
	var text:="三次有效跳伤＋宿主≤40%才判断"
	if part==1:
		if local>=12.85:text="已入新宿主 · 自动关 · 不撤回／不重置冷却"
		elif local>=12.65:text="途中按Q关闭 · 本次扑跃继续"
		elif local>=12.5:text="下一次正常跳伤 → 现在才跳宿"
		elif local>=10:text="Q重新开启 · 仍等下一次正常跳伤"
		elif local>=9:text="保存／读档示例 · 自动关、3次计数保留"
		elif local>=8.5:text="三跳＋低血已满足 · 自动关仍留原宿主"
		elif local>=1:text="按Q关闭 · 正常寄生继续，不清计数"
	elif part==2:
		if started:text="后续正常跳伤命中 · 再判断并跳宿"
		elif local>=10:text="合法新宿主出现 · 不立即跳，等下一跳伤"
		elif local>=8.5:text="无合法新宿主 · 不脱离、不扣冷却"
	elif part==3:
		if repaired:text="同帧维修先清除机器人 · 不跳宿、不留撕裂"
		elif local>=4.5:text="已两跳 · 维修将在第三跳前清除"
	elif part==4:
		if local>=9:text="再次群体Q → 全开 · 不立即跳宿"
		elif local>=1:text="群体Q → 全关 · 不清计数／不重置冷却"
		else:text="选中两只：A关、B开 · 按Q统一关闭"
	elif active:text="同一机器人扑跃0.35秒 · 可受伤"
	elif landed:text="已入新宿主 · 原宿主三跳撕裂 · 间隔10秒"
	return {"time":t,"local":local,"part":part,"active":active,"value":MetaProgress.talent_options("DRON").host_hunt.values.damage[rank]*100,"charges":hits,"auto":auto_on,"other_auto":other_auto,"repaired":repaired,"candidate":candidate,"leap_at":leap_at,"landed":landed,"cooldown":cooldown,"tears":tears,"title":title,"text":text}

static func animate(preview,s:Dictionary) -> void:
	var inverse:Transform2D=preview.viewport.canvas_transform.affine_inverse()
	preview.actor.visible=not s.repaired and (s.local<.5 or s.active)
	if s.local<.5:preview.actor.position=inverse*(Vector2(123,104).lerp(FIRST,s.local/.5))
	elif s.active:
		var progress:float=(s.local-s.leap_at)/.35
		preview.actor.position=inverse*(FIRST.lerp(NEXT,progress)+Vector2(0,-sin(progress*PI)*16))
		preview.actor.hull_angle=(inverse*FIRST).direction_to(inverse*NEXT).angle()

static func draw(view,s:Dictionary) -> void:
	view.draw_string(ThemeDB.fallback_font,Vector2(10,18),s.title,HORIZONTAL_ALIGNMENT_LEFT,-1,12,Color.WHITE)
	view.draw_string(ThemeDB.fallback_font,Vector2(10,35),"Q 自动%s · 换宿冷却 %.1fs"%["开" if s.auto else "关",s.cooldown],HORIZONTAL_ALIGNMENT_LEFT,-1,11,Color.SKY_BLUE)
	view.draw_circle(FIRST,10,Color.SALMON)
	if s.candidate and s.part!=3:view.draw_circle(NEXT,10,Color.SALMON)
	if not s.repaired:
		var host:Vector2=NEXT if s.landed else FIRST
		if not s.active and s.local>=.5:view.draw_circle(host,4,Color.SKY_BLUE)
		preload("res://scripts/ui/talent_stack_indicator.gd").paint(view,FIRST,"原宿主",s.charges,3,23)
	else:
		view.draw_line(FIRST-Vector2(14,0),FIRST+Vector2(14,0),Color.GREEN,3)
		view.draw_line(FIRST-Vector2(0,14),FIRST+Vector2(0,14),Color.GREEN,3)
	if s.part==4:
		view.draw_circle(NEXT,4,Color.SKY_BLUE)
		view.draw_string(ThemeDB.fallback_font,NEXT+Vector2(-30,23),"B 自动"+("开" if s.other_auto else "关"),HORIZONTAL_ALIGNMENT_LEFT,-1,11,Color.SKY_BLUE)
	for tick in [.5,4.5,8.5,12.5]:
		if not s.repaired and tick<=s.leap_at and absf(s.local-tick)<.13:view.draw_arc(FIRST,17,0,TAU,24,Color.SKY_BLUE,2,true)
	if s.cooldown>0:
		view.draw_string(ThemeDB.fallback_font,FIRST+Vector2(-55,42),"撕裂%d/3 · 每跳%d%%"%[s.tears,s.value],HORIZONTAL_ALIGNMENT_LEFT,-1,10,Color.GOLD)
		for index in range(1,4):
			if absf(s.local-s.leap_at-index)<.13:view.draw_arc(FIRST,21,0,TAU,24,Color.GOLD,2,true)
