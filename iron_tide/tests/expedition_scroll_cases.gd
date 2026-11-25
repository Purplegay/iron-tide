extends RefCounted
const AttentionCases=preload("res://tests/expedition_attention_cases.gd")

static func position(t) -> int:
	await t.settle()
	var bar:VScrollBar=t.camp.scroll.get_v_scroll_bar()
	t.camp.scroll.scroll_vertical=mini(500,int(bar.max_value-bar.page)/2)
	await t.settle()
	t.check(t.camp.scroll.scroll_vertical>0,"scroll fixture has nonzero viewport position")
	return t.camp.scroll.scroll_vertical

static func unchanged(t,old_scroll:ScrollContainer,at:int,label:String) -> void:
	t.check(t.camp.scroll==old_scroll and old_scroll.scroll_vertical==at,label+" keeps scroll container and immediate position")
	for frame in 6:
		await t.get_tree().process_frame
		var bar:=old_scroll.get_v_scroll_bar()
		var expected:int=mini(at,maxi(0,int(bar.max_value-bar.page)))
		t.check(t.camp.scroll==old_scroll and old_scroll.scroll_vertical==expected,label+" stays at position through layout frame "+str(frame))

static func click(t,text:String,label:String) -> void:
	var matches:=AttentionCases.buttons(t.camp,text)
	var target:Button
	for entry in matches:
		if not entry.disabled:target=entry;break
	t.check(target!=null,label+" actionable button exists")
	if target==null:return
	var at:int=await position(t)
	var old_scroll:ScrollContainer=t.camp.scroll
	target.pressed.emit()
	await unchanged(t,old_scroll,at,label)

static func run(t) -> void:
	var original:Dictionary=Expedition.state.duplicate(true)
	var next:Dictionary=original.duplicate(true)
	next.supplies=10000;next.free_upgrade_stage=0
	Expedition.commit(next);t.camp.change_tab(1)
	await click(t,"锁定商品","locking merchandise")
	await click(t,"解除锁定","unlocking merchandise")
	await click(t,"刷新 ·","refreshing shop")
	await click(t,"购买 ·","buying merchandise")
	t.camp.change_tab(2);await t.settle()
	t.check(t.camp.scroll.scroll_vertical==0,"intentional tab change starts at top")
	await click(t,"攻防强化 +1","using free upgrade with reminder banner removed")
	t.check(not preload("res://scripts/expedition/growth.gd").free_available(Expedition.state),"free upgrade actually consumed during scroll test")
	var at:int=await position(t)
	var old_scroll:ScrollContainer=t.camp.scroll
	var dismissals:=AttentionCases.buttons(t.camp,"￥")
	t.check(not dismissals.is_empty(),"dismiss confirmation button exists")
	if not dismissals.is_empty():
		dismissals[0].pressed.emit()
		var dialog:ConfirmationDialog
		for child in t.camp.get_children():
			if child is ConfirmationDialog:dialog=child;break
		t.check(dialog!=null,"real dismissal confirmation opens")
		if dialog!=null:dialog.confirmed.emit()
		await unchanged(t,old_scroll,at,"confirmed dismissal")
	var id:String=t.camp.opening.keys()[0]
	at=await position(t);old_scroll=t.camp.scroll
	t.camp.upgrade_unit(id,0)
	await unchanged(t,old_scroll,at,"rejected stale free action")
	# Successful choices advance to a different reward page, so reset deliberately.
	next=Expedition.state.duplicate(true);next.phase="reward";next.reward_round="main";next.offers=[{"kind":"supplies","id":"bonus","amount":60}]
	var was_open:bool=t.camp.equipment_open
	t.camp.equipment_open=true # The one-card reward needs the owned equipment list to overflow.
	Expedition.commit(next);t.camp.build();await t.settle()
	t.check(t.camp.scroll.scroll_vertical==0,"entering reward page starts at top")
	await position(t)
	AttentionCases.buttons(t.camp,"选取奖励")[0].pressed.emit();await t.settle()
	t.check(Expedition.state.reward_round=="buff" and t.camp.scroll.scroll_vertical==0,"new bonus reward round resets instead of inheriting old scroll")
	await position(t)
	AttentionCases.buttons(t.camp,"选取奖励")[0].pressed.emit();await t.settle()
	t.check(Expedition.state.phase=="event" and t.camp.scroll.scroll_vertical==0,"new event page starts at top")
	t.camp.equipment_open=was_open
	Expedition.commit(original);t.camp.build();await t.settle()
