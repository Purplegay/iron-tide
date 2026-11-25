extends "res://scripts/ui/hero_talent_demo.gd"
const Timeline=preload("res://scripts/ui/hero_combo_timeline.gd")
var metrics:=Label.new()

func _ready() -> void:
	add_child(UiKit.make_label("完整联动演示",18,UiKit.COL_ACCENT_2))
	stage.custom_minimum_size.y=180;stage.clip_contents=true;add_child(stage)
	stage.draw.connect(_draw_demo)
	caption.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;add_child(caption)
	metrics.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;add_child(metrics)
	playback=preload("res://scripts/ui/demo_playback.gd").new();add_child(playback)
	playback.bind(self,&"elapsed",duration,refresh_preview);playback.add_transport()
	var note:=UiKit.make_label("演示以 4 倍速播放，时间轴按实战秒数标记。技能数值见下方说明，飞行距离和连射节奏仅供参考。预览不会影响奖励或存档。",12,UiKit.COL_DIM)
	note.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;add_child(note)
	visibility_changed.connect(func():set_process(is_visible_in_tree()))
	set_process(is_visible_in_tree())

func show_hero(id:String) -> void:
	hero_id=id;elapsed=0;playing=true;refresh_preview()
	stage.material=preload("res://scripts/units/peregrine_art.gd").preview_material() if id=="ORCA" else null
	stage.texture_filter=CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS if id=="ORCA" else CanvasItem.TEXTURE_FILTER_PARENT_NODE

func duration() -> float:
	return Timeline.duration(hero_id) if not hero_id.is_empty() else 1.0

func _process(dt:float) -> void:
	if playing and not hero_id.is_empty():elapsed=fposmod(elapsed+dt*4*playback_speed,duration());refresh_preview()

func refresh_preview() -> void:
	if hero_id.is_empty():return
	var s:=Timeline.sample(hero_id,elapsed)
	caption.text=s.phase
	if hero_id=="ORCA":
		metrics.text="王牌航线Lv.1／滞空保障Lv.4 · 整备Lv.0 · 最大生命示例100\n弹药 %d/5 · 补弹 %.1f%%（%.2f秒/发）· 补满周期%d\n生命 %.1f · 整备盾 %.1f · 维护盾 %.1f · 移速×%.1f · 机场位0"%[s.ammo,s.progress*100,s.seconds,s.cycle,s.hp,s.shield,s.maintenance_shield,s.speed]
	elif hero_id=="BORIS":
		metrics.text="前线指挥Lv.5／战地电台Lv.3 · 三星 · 两张契约卡Lv.0\n射章%d/3 · 本轮六架对建筑伤害×%.2f／半径×%.2f\n空袭补充 %.1f秒%s · W冷却 %.1f秒\n接力发放%d次 · 补给发放%d次 · 生命%d/100"%[s.stamps,s.damage,s.radius,s.native_cd,"（编队未结束，尚未倒计时）" if s.occupied else "",s.w_cd,s.relay_grants,s.supplies,s.hp]
	else:
		metrics.text="移动变电站Lv.5／过载保险Lv.5 · 电庭Lv.1／电荷Lv.0\n电荷%d/3 · 夺取盾%.0f · 回收盾%.0f · 应急盾%.0f · 护套盾%.0f\n生命%d/100 · 友军生命%d/100 · 供电+%d／收支%d\nW冷却%.1f秒 · 电庭%s · 分流%s"%[s.charge,s.stolen,s.recycled,s.emergency,s.coil,s.hp,s.ally_hp,s.power,s.power-60,s.w_cd,"生效" if s.court else "关闭","生效" if s.divert else "关闭"]
	stage.queue_redraw()

func _draw_demo() -> void:
	if hero_id.is_empty():return
	stage.draw_rect(Rect2(Vector2.ZERO,stage.size),Color("#142331"))
	var width:=minf(540,stage.size.x)
	stage.draw_set_transform(Vector2((stage.size.x-width)*.5,0))
	var s:=Timeline.sample(hero_id,elapsed)
	if hero_id=="ORCA":_draw_air(width,s)
	elif hero_id=="BORIS":_draw_boris(width,s)
	else:_draw_tesla(width,s)

func _draw_air(width:float,s:Dictionary) -> void:
	var hero:=Vector2(width*.35,120-s.lift*35)
	var target:=Vector2(width*.82,110)
	_sprite("GAAIRC",Vector2(width*.13,145),.27)
	if s.parked:_sprite("ORCA",Vector2(width*.13,120),.45,false,Color.WHITE,6,false)
	_sprite("ORCA",hero,.8)
	_sprite("HTNK",target,.65)
	stage.draw_arc(hero-Vector2(0,10),30,0,TAU,32,Color.CYAN,2)
	var shots:Array=[1.0]
	for i in 5:shots.append(s.fill+1+i)
	for launch:float in shots:
		if elapsed>=launch and elapsed<launch+.4:stage.draw_circle(hero.lerp(target,(elapsed-launch)/.4),3,Color.ORANGE)
	_text(Vector2(12,22),"悬停射击 → 空中补满 → 打空余速 → 机场旁维护",UiKit.COL_GOLD)
	_text(Vector2(12,162),"普通飞机"+("停放加速" if s.parked else "已离场")+" · 游隼不需要返航",UiKit.COL_DIM)
	stage.draw_rect(Rect2(hero+Vector2(-35,16),Vector2(70,5)),Color.DIM_GRAY)
	stage.draw_rect(Rect2(hero+Vector2(-35,16),Vector2(70*s.progress,5)),Color.CYAN)

func _draw_boris(width:float,s:Dictionary) -> void:
	var hero:=Vector2(60,105)
	_sprite("BORIS",hero,1.1)
	var primary:=Vector2(width*.65,110);var secondary:=Vector2(width*.87,112)
	_sprite("NAPOWR",primary,.36);_sprite("NAPOWR",secondary,.32)
	for group in 2:
		var count:int=s.main if group==0 else s.secondary
		var destination:=primary if group==0 else secondary
		var impact:=8.0 if group==0 else 9.0
		var leave:=11.0 if group==0 else 13.0
		for i in count:
			var at:=Vector2(110+i*15,55).lerp(destination-Vector2(0,30),clampf((elapsed-6)/(impact-6),0,1))
			if elapsed>=impact:at=at.lerp(Vector2(width+20,45+i*8),clampf((elapsed-impact)/(leave-impact),0,1))
			_sprite("BPLN",at,.32)
		if elapsed>=impact and elapsed<impact+.4:stage.draw_arc(destination,22*s.radius,0,TAU,32,Color.ORANGE,2)
	_sprite("E2",Vector2(width*.43,128),1.0)
	if s.relay:stage.draw_arc(Vector2(width*.43,110),20,0,TAU,32,Color.CYAN,2)
	if s.pickup:stage.draw_rect(Rect2(hero+Vector2(24,-8),Vector2(13,13)),UiKit.COL_OK)
	if elapsed>=7 and elapsed<8.2:stage.draw_dashed_line(hero,primary,Color.RED,2,5)
	_text(Vector2(12,22),"三章 → 六架同轮 → 接力与补给各一次 → 全队结束补充",UiKit.COL_GOLD)
	_text(Vector2(12,162),"主队%d架 · 副队%d架 · %s"%[s.main,s.secondary,"仍占用本轮" if s.occupied else "尚未呼叫" if elapsed<6 else "独立补充计时"],Color.CYAN)

func _draw_tesla(width:float,s:Dictionary) -> void:
	var hero:=Vector2(width*.3,95);var enemy:=Vector2(width*.82,105);var ally:=Vector2(width*.52,120)
	_sprite("TTNK",hero,.7,false,Color(.5,.6,.65) if s.stopped else Color.WHITE)
	_sprite("HTNK",enemy,.6);_sprite("HTNK",ally,.6)
	_sprite("E2",hero+Vector2(43,25),.8,false,Color(.95,.6,.6))
	if s.court:
		var points:=PackedVector2Array([enemy+Vector2(-40,10),enemy+Vector2(0,-40),enemy+Vector2(40,10)])
		stage.draw_colored_polygon(points,Color(.2,.7,1,.15));stage.draw_polyline(points+PackedVector2Array([points[0]]),Color.CYAN,2)
		if fmod(elapsed-1,.5)<.15:stage.draw_line(points[0],enemy,Color.CYAN,2)
	if s.divert:stage.draw_line(hero,ally,Color(.3,1,.5,.5),2)
	if s.arc:stage.draw_arc(hero,70,0,TAU,48,Color.CYAN,3)
	for launch:float in [2,3,4]:
		if elapsed>=launch and elapsed<launch+.2:stage.draw_line(hero,enemy,Color.CYAN,3)
	if s.emergency>0:stage.draw_arc(hero,32,0,TAU,32,Color.GREEN,2)
	_text(Vector2(12,22),"电庭＋电荷 → 夺盾／回收／分流 → 停堆 → 恢复",UiKit.COL_GOLD)
	_text(Vector2(12,162),"供电+%d · 电荷%d/3 · %s"%[s.power,s.charge,"停堆中" if s.stopped else "电庭不会免费重开" if elapsed>=12 else "额外电伤不递归"],Color.CYAN)
