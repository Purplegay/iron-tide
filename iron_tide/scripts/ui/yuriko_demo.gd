extends PopupPanel
const Psi = preload("res://scripts/units/yuriko.gd")
var ability: OptionButton
var level: OptionButton
var stage: Control
var preview:Node2D
var fired:=false
var aftershock:=false
var caption: Label
var time := 0.0
var model
var motion: OptionButton
const SCHOOL_NAMES:={"PACKING":"施法","COMING_OUT_OF_FACTORY":"出厂","LAUNCHED":"弹射","PARACHUTING":"空降","TRANS_toParachuting":"开伞","TRANS_fromParachuting":"收伞","DYING SPLATTED OVER_WATER":"落水","DYING OVER_WATER DYING_WASMOVING":"水中移动阵亡","DYING OVER_WATER":"水中阵亡","DYING DEATH_2":"中毒阵亡","DYING DEATH_3":"火焰阵亡","DYING_WASMOVING":"跑动阵亡","TRANS_IdleToSelected":"立正","TRANS_SelectedToIdle":"解除立正"}
const MOTIONS := {
	"STATE_bored":"待机","SELECTED":"选中","MOVING":"跑动","USER_7":"出场","USER_8":"施法",
	"FIRING_A REACT_1":"攻击步兵或空军","FIRING_A REACT_2":"攻击载具","FIRING_A REACT_3":"攻击建筑","FIRING_A":"攻击",
	"TRANS_boredToSlam":"举起目标","REACT_5":"维持悬空","TRANS_slamToBored":"放下目标",
	"STUNNED_FLAILING":"空中失衡","STUNNED":"倒地","STUNNED_STANDING_UP":"起身","DYING":"阵亡","DYING SPLATTED":"坠地阵亡",
	"TRANS_boredToAttention":"立正","TRANS_attentionToBored":"解除立正"
}
const KEYS := ["burst","Lure","Shield","Slam","Speed","Health","AttackDamage"]

func play(skin:=0) -> void:
	var box:=VBoxContainer.new()
	add_child(box)
	var controls:=HBoxContainer.new()
	box.add_child(controls)
	ability=OptionButton.new()
	for index in KEYS.size():
		var label:String=Psi.NAMES.get(KEYS[index],"灵能爆发")
		ability.add_item("QWER"[index]+" "+label if index<4 else label)
	controls.add_child(ability)
	level=OptionButton.new()
	controls.add_child(level)
	ability.item_selected.connect(choose)
	level.item_selected.connect(restart)
	var close:=UiKit.make_button("关闭演示")
	close.pressed.connect(hide)
	controls.add_child(close)
	stage=Control.new()
	stage.texture_filter=CanvasItem.TEXTURE_FILTER_LINEAR
	stage.custom_minimum_size=Vector2(400,145)
	stage.draw.connect(render_stage)
	box.add_child(stage)
	stage.clip_contents=true
	preview=Node2D.new()
	stage.add_child(preview)
	model=preload("res://scripts/units/yuriko_model.gd").new()
	stage.add_child(model)
	model.set_skin(skin)
	motion=OptionButton.new()
	motion.add_item("随技能播放")
	for state in model.states:
		if skin==1 and state=="USER_7":continue
		motion.add_item("原版动作 · "+str(MOTIONS.get(state,SCHOOL_NAMES.get(state,state))))
		motion.set_item_metadata(motion.item_count-1,state)
	box.add_child(motion)
	motion.item_selected.connect(restart)
	caption=UiKit.make_label("",14,UiKit.COL_TEXT)
	caption.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	box.add_child(caption)
	choose(0)
	popup_hide.connect(queue_free)
	popup_centered(Vector2i(460,265))

func choose(index:int) -> void:
	motion.select(0)
	level.clear()
	var count:=1 if index==0 else 3 if index<=3 else 2
	for i in count:level.add_item("%d 级"%(i+1))
	restart(0)

func restart(_index:int) -> void:
	time=0
	clear_preview()
	var rank:=level.selected+1
	match KEYS[ability.selected]:
		"burst":caption.text="敌人进入范围后手动按 Q。0.4 秒后爆发，造成 500 伤害并瘫痪载具。"
		"Shield":caption.text="护盾持续 %d 秒，拦截从外部打向罩内友军的攻击。"%(3+2*rank)
		"Lure":caption.text="控制半径 %d，最多 %d 名敌方步兵转向守卫。"%[roundi(Psi.area_radius("Lure",rank)),1+2*rank]
		"Slam":caption.text="按一次 R，左键选中半径 %.1f 内的目标。目标升空后，再左键点落点掷出。抓取冷却 %d 秒。"%[Psi.area_radius("Slam",rank),6-rank]
		"Speed":caption.text="同样的时间，升级后的百合子向前移动 %.1f%% 的距离。"%(100*pow(1.15,rank))
		"Health":caption.text="生命上限从 350 增至 %.1f。"%(350*pow(1.15,rank))
		"AttackDamage":caption.text="相同攻击命中目标时，伤害乘以 %.4f。"%pow(1.25,rank)
	model.requested=""
	update_model(0)
	stage.queue_redraw()

func _process(dt:float) -> void:
	if not visible or stage==null:return
	time+=dt
	if time>=5.0:
		time=fmod(time,5.0)
		clear_preview()
	update_preview()
	update_model(dt)
	stage.queue_redraw()

func clear_preview() -> void:
	for child in preview.get_children():child.free()
	fired=false
	aftershock=false

func guard_point(index:int,count:int)->Vector2:
	return Vector2(230,89)+Vector2.from_angle(TAU*index/count)*26

func update_preview() -> void:
	if motion.selected>0:return
	var key:String=KEYS[ability.selected]
	if key=="burst" and time>=2 and not fired:
		fired=true
		Psi.FX.show_fx(null,Vector2(67,94),"FX_JapanCommandoSecondaryFire",null,Vector2.ZERO,Vector2.RIGHT,null,preview)
	if key=="burst" and model.outfit>0 and not aftershock and time>=2.0+model.blast_ray_delay():
		aftershock=true
		Psi.FX.show_fx(null,Vector2(67,94),"FX_JapanCommandoBlast",null,Vector2.ZERO,Vector2.RIGHT,null,preview)
	if key=="Lure" and time>=1.5:
		var count:=1+2*(level.selected+1)
		if not fired:
			for i in count:
				Psi.FX.show_fx(null,guard_point(i,count),"Lure",null,Vector2.ZERO,Vector2.RIGHT,null,preview)
			fired=true
		for marker in preview.get_children():
			marker.preview_head=Vector2(67,94)+model.head_offset()*156.0/102.0

func update_model(dt:float) -> void:
	var state := "STATE_bored"
	var key: String = KEYS[ability.selected]
	if motion.selected>0: state=motion.get_item_metadata(motion.selected)
	elif key=="Speed": state="MOVING"
	elif key=="Slam" and time<2: state="REACT_5"
	elif key=="AttackDamage": state="FIRING_A REACT_2"
	elif key in ["Shield","Lure"] or (key=="burst" and time>=2 and time<4): state="USER_8"
	var screen: Transform2D=stage.get_viewport().get_stretch_transform()*stage.get_global_transform_with_canvas()
	model.fit_pixels(156.0*maxf(screen.x.length(),screen.y.length()))
	model.shield.visible=key=="Shield" and motion.selected==0
	model.body.rotation.y=-0.55
	model.pose(state,dt,motion.selected==0)
	model.hover_fx.advance(dt,Psi.COLORS[model.outfit],not state.begins_with("DYING"))

func render_stage() -> void:
	var key:String=KEYS[ability.selected]
	var rank:=level.selected+1
	var p:=Vector2(67,94)
	stage.draw_rect(Rect2(Vector2.ZERO,stage.size),Color("#14202a"))
	if key=="Speed":p.x+=time*35*pow(1.15,rank)
	stage.draw_texture_rect(model.get_texture(),Rect2(p-Vector2(78,98),Vector2(156,156)),false)
	var target:=Vector2(230,92)
	if key=="burst":
		target.x=245-minf(time,2)*56
		if time>=2.4:
			target.x+=25
	elif key=="Shield":
		stage.draw_arc(p+Vector2.UP*15,36,0,TAU,40,Psi.COLOR,2)
		stage.draw_line(target,p+Vector2(36,-8),Color.SALMON,2)
	elif key=="Slam":
		target.y-=minf(time,1)*42
		if time>2:
			var t:=clampf(time-2,0,1)
			target+=Vector2(t*96,42*t-30*sin(t*PI))
	elif key=="Lure":
		for i in 1+2*rank:
			var q:=guard_point(i,1+2*rank)
			stage.draw_circle(q,6,Color.SALMON if time<1.5 else Color.AQUAMARINE)
		return
	elif key=="Health":
		stage.draw_rect(Rect2(p+Vector2(-20,12),Vector2(64*pow(1.15,rank),5)),Color.AQUAMARINE)
		return
	elif key=="AttackDamage":
		stage.draw_rect(Rect2(target+Vector2(-18,-22),Vector2(68-minf(time,2)*15*pow(1.25,rank),5)),Color.SALMON)
		stage.draw_line(p,target,Psi.COLOR,2)
	elif key=="Speed":return
	stage.draw_circle(target,10,Color.SALMON)
