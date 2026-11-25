extends CanvasLayer
const Keys=preload("res://scripts/ui/battle_hotkeys.gd")
const Reserve=preload("res://scripts/units/tesla_reserve.gd")
var actor
var hud
var _was_paused:=false
var _battle_was_paused:=false
var _pause_acquired:=false
var body:Label
var clock:=0.0

static func describe(target) -> String:
	if not is_instance_valid(target) or not AlliedAbilities.alive(target):return "该单位已离场。"
	if target is Building and target.building_id=="R3REAPERTURRET":
		var mount=target.get_node_or_null("ReaperMount")
		if is_instance_valid(mount):return "部署形态 · "+describe(mount)
	var lines:=PackedStringArray([target.display_name+" · 被动与天赋", "以下是这支单位本局可用的效果，有些需要满足特定条件才会触发。"])
	if target.special.get("brutal_armor", false):
		lines.append("凶残3 · 坦克装甲：最终受到的伤害 ×0.9")
	if target.special.has("brutal_shield"):
		var cap: float = target.max_hp * 0.5
		var value := "%s / %s" % [HpBar.shield_number(target.special.brutal_shield),HpBar.shield_number(cap)] if target.side == "ally" else "%d%%" % roundi(100.0 * float(target.special.brutal_shield) / maxf(cap,1.0))
		lines.append("凶残3 · 建筑护盾：" + value)
	var id:String=target.unit_id if target is Unit else target.building_id
	if target is Unit and not target.passive.is_empty():
		lines.append("\n装配被动 · %s · Lv.%d\n%s"%[target.passive_name(),target._equipped_card_rank(target.passive.id),target.passive_desc()])
	elif target is Building:
		for pair in [["card_armor","ps_armor_plating"],["flak_card","ps_barrage"]]:
			if float(target.special.get(pair[0],0))<=0:continue
			var definition:=GameData.get_skill(pair[1])
			var rank:=int(target.special.get("card_armor_rank",0)) if pair[0]=="card_armor" else int(BattleRequest.combat_context.get("card_ranks",{}).get(pair[1],0))
			lines.append("\n装配被动 · %s · Lv.%d\n%s"%[definition.name,rank,MetaProgress.Academy.skill_description(definition,rank,float(target.special[pair[0]]))])
	if target is Building and target.side=="ally" and BattleRequest.unit_loadout(id).get("passive")=="ps_zero_arc":
		var card:=GameData.get_skill("ps_zero_arc")
		lines.append("\n装配被动 · 零点放电\n"+MetaProgress.Academy.skill_description(card,int(BattleRequest.combat_context.get("card_ranks",{}).get(card.id,0))))
	if target is Building:
		for entry in preload("res://scripts/units/expansion_visual.gd").entries(target):lines.append("\n当前状态 · "+entry.text+(" %.1fs"%entry.left if entry.left>0 else ""))
	var options:=MetaProgress.talent_options(id)
	for talent:String in options:
		if not BattleRequest.has_unit_talent(id,talent,target.side):continue
		var definition:Dictionary=options[talent]
		var rank:=MetaProgress.talent_rank(id,talent,BattleRequest.combat_context.get("unit_talents",{}))
		var detail:=str(definition.desc)
		if definition.has("native_profile") and target is Unit:
			for spec in Unit.Training.PROFILES.get(id,[]):
				var base:=Unit.Training.base_value(id,spec[0])
				var value:=Unit.Training.projected(base,spec[2],Unit.Training.scale(target))
				if spec[2]=="down":value=base/Unit.Training.timing_scale(target)
				detail+="\n%s：%s%s"%[spec[1],String.num(value,2),spec[3]]
			if id in ["AMCV","SMCV","DOG","SOV_DOG"]:detail+="\n%s防御系数 +%d%%"%["车形态" if id in ["AMCV","SMCV"] else "正面 120°",(rank+1)*10]
		elif talent=="bunker_optics":
			detail+="\n驻军总射程：%.2f 格"%preload("res://scripts/rules/bunker_talent.gd").range_cells(rank)
		else:
			var rule:Dictionary=definition.get("ranks",[])[rank-1] if rank>0 else {}
			if definition.has("base"):
				detail+="\n%s：%s%s"%[definition.get("stat","效果"),str(rule.get("value",definition.base)),definition.get("suffix","")]
			if rule.has("charge_seconds"):
				detail+="\n每 %s 秒叠层，每层伤害 +%d%%，持续 %s 秒，最多 %d 层。"%[str(rule.charge_seconds),roundi((float(rule.damage)-1)*100),str(rule.linger),ceili(float(rule.linger)/float(rule.charge_seconds))]
			for field in ["intervals","stack_limits","heal_seconds","cooldown_reduction"]:
				if definition.has(field):detail+="\n%s：%s%s"%[{"intervals":"叠层间隔","stack_limits":"层数上限","heal_seconds":"回血持续","cooldown_reduction":"攻击间隔减少"}[field],str(definition[field][rank]),{"intervals":" 秒","stack_limits":" 层","heal_seconds":" 秒","cooldown_reduction":"%"}[field]]
		lines.append("\n本局已启用天赋 · %s · Lv.%d\n%s"%[definition.name,rank,preload("res://scripts/rules/progression_parameters.gd").describe(talent,detail)])
	if target is Unit:
		if target.special.has("convoy"):
			var state:Dictionary=target.special.convoy
			for page in 2:
				var rank:int=target.special.hero_command_rank if page==0 else target.special.hero_survival_rank
				lines.append("\n%s · Lv.%d"%[Unit.Convoy.Talents.TITLES[id][page],rank])
				for level in rank+1:lines.append(Unit.Convoy.Talents.TRAITS[id][page][level])
			if id=="HARV":lines.append("矿量 %d%% · 热锭 %d 枚 · 体积 %d%% · 射速 ×%s"%[roundi(100*target.cargo/maxf(1,state.base_hold)),floori(4*target.cargo/maxf(1,state.base_hold)),state.volume,Unit.Convoy.Cards.rate(target)])
		var shield:=Unit.TankHero.Shield.describe(target)
		if not shield.is_empty():lines.append("\n当前护盾 · "+shield)
		if target.special.has("hero_wreck"):lines.append("\n当前状态 · 英雄残骸，战斗天赋暂停。"+preload("res://scripts/ui/revival_indicator.gd").state(target).get("text",""))
		elif is_instance_valid(target.embarked_in):lines.append("\n当前状态 · 已进入载具／建筑，效果仍受乘员规则限制。")
		elif AlliedAbilities.frozen(target):
			lines.append("\n当前状态 · 持续冻结，绝缘缓行允许50%移速；不能开火／施法，仍会被擦除。" if target.special.has("leizhu") and preload("res://scripts/units/leizhu_insulation.gd").mobile(target) else "\n当前状态 · 冻结，行动与触发受冻结规则限制。")
		var reserve:=Reserve.caption(target)
		if not reserve.is_empty():lines.append("\n当前状态 · "+reserve)
		if target.special.has("academy_hero") and not target.special.has("convoy"):
			var command:=int(target.special.get("hero_command_rank",0))
			var defense:=int(target.special.get("hero_survival_rank",0))
			var commando:bool=target.special.academy_hero in MetaProgress.Academy.Commandos.IDS
			lines.append("\n英雄天赋 · 指挥 Lv.%d／生存 Lv.%d"%[command,defense])
			if commando:
				var tanya:bool=target.special.academy_hero=="TANY"
				var titles=MetaProgress.Academy.Commandos.TITLES[target.special.academy_hero]
				var commands=preload("res://scripts/units/tanya_talents.gd").COMMAND if tanya else preload("res://scripts/units/boris_command.gd").COMMAND
				var defenses=preload("res://scripts/units/tanya_talents.gd").DEFENSE if tanya else preload("res://scripts/units/boris_radio.gd").DEFENSE
				lines.append_array(track_lines(titles[0],commands,command))
				lines.append_array(track_lines(titles[1],defenses,defense))
			elif target.special.get("academy_hero")=="ORCA":
				lines.append_array(track_lines("王牌航线",preload("res://scripts/units/peregrine_command.gd").COMMAND,command))
				lines.append_array(track_lines("滞空保障",preload("res://scripts/units/peregrine_defense.gd").DEFENSE,defense))
			elif target.special.get("academy_hero")=="TTNK":
				lines.append_array(track_lines("移动变电站",preload("res://scripts/units/leizhu_command.gd").COMMAND,command))
				lines.append_array(track_lines("过载保险",preload("res://scripts/units/leizhu_defense.gd").DEFENSE,defense))
			elif Unit.TankHero.active(target):
				lines.append("战术中枢：")
				for i in range(mini(command+1,Unit.TankHero.COMMAND.size())):lines.append(Unit.TankHero.COMMAND[i])
				lines.append("重装生存：")
				for i in range(mini(defense+1,Unit.TankHero.DEFENSE.size())):lines.append(Unit.TankHero.DEFENSE[i])
			else:
				lines.append("随行护卫："+MetaProgress.Academy.escort_description(command))
				for i in range(mini(defense+1,MetaProgress.Academy.SURVIVAL_STAGES.size())):lines.append(MetaProgress.Academy.SURVIVAL_STAGES[i])
		for effect in target.buff_entries():
			lines.append("\n当前状态 · "+preload("res://scripts/ui/unit_status.gd").tooltip(effect))
	if lines.size()==2:lines.append("\n当前没有已装配的被动卡、已启用的专属天赋或临时效果。")
	return "\n".join(lines)

static func track_lines(title:String,descriptions:Array,rank:int) -> PackedStringArray:
	var lines:=PackedStringArray([title+"："])
	for i in range(mini(rank+1,descriptions.size())):lines.append("Lv.%d　%s"%[i,descriptions[i]])

	return lines

static func open(hud,target) -> void:
	if Keys.modal_count>0 or not is_instance_valid(target):return
	hud.battle.cancel_pointer_gestures()
	var panel=load("res://scripts/ui/battle_effect_details.gd").new();panel.actor=target;panel.hud=hud
	hud.add_child(panel)

func _ready() -> void:
	layer=110;process_mode=Node.PROCESS_MODE_ALWAYS;Keys.modal_count+=1
	if is_instance_valid(hud) and is_instance_valid(hud.battle):
		_was_paused=get_tree().paused
		_battle_was_paused=hud.battle.paused
		hud.battle.paused=true
		get_tree().paused=true
		_pause_acquired=true
		hud.pause_btn.text="继续"

	var shade:=ColorRect.new();shade.color=Color(0.02,0.03,0.05,0.9);add_child(shade);shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var margin:=MarginContainer.new();shade.add_child(margin);margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side in ["left","right","top","bottom"]:margin.add_theme_constant_override("margin_"+side,30)
	var column:=VBoxContainer.new();margin.add_child(column)
	var close:=UiKit.make_button("关闭被动／天赋详情（Esc）");column.add_child(close);close.pressed.connect(queue_free)
	column.add_child(UiKit.make_label("对局已暂停 · 关闭后恢复原暂停状态 · 多选时显示技能栏代表单位",13,UiKit.COL_GOLD))
	var scroll:=ScrollContainer.new();scroll.size_flags_vertical=Control.SIZE_EXPAND_FILL;column.add_child(scroll)
	body=UiKit.make_label("",17,UiKit.COL_TEXT);body.size_flags_horizontal=Control.SIZE_EXPAND_FILL;body.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;scroll.add_child(body)
	refresh()

func refresh() -> void:
	var text:=describe(actor)
	if body.text!=text:body.text=text

func _process(delta:float) -> void:
	clock-=delta
	if clock<=0:clock=0.25;refresh()

func _input(event:InputEvent) -> void:
	if event is InputEventKey:
		get_viewport().set_input_as_handled()
		if event.pressed and event.keycode==KEY_ESCAPE:queue_free()

func _exit_tree() -> void:
	Keys.modal_count=maxi(0,Keys.modal_count-1)
	if _pause_acquired and is_instance_valid(hud) and is_instance_valid(hud.battle) and not hud.battle.ended:
		get_tree().paused=_was_paused
		hud.battle.paused=_battle_was_paused
		hud.pause_btn.text="继续" if _was_paused else "暂停"
	_pause_acquired=false
