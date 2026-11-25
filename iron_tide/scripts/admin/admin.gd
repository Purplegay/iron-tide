extends Control
## admin/ 后台主界面。通过主菜单的「后台」按钮进入。
## 标签页：数据编译器 / 经济调参 / GM 控制台 / 系统状态。

const DataCompilerScript := preload("res://scripts/admin/data_compiler.gd")
const EconomyEditorScript := preload("res://scripts/admin/economy_editor.gd")
const GMConsoleScript := preload("res://scripts/admin/gm_console.gd")
@onready var kit = UiKit

func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)

	var bg := ColorRect.new()
	bg.color = Color(0.04, 0.05, 0.07)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bg)

	var vb := VBoxContainer.new()
	vb.set_anchors_preset(Control.PRESET_FULL_RECT)
	vb.add_theme_constant_override("separation", 8)
	vb.add_theme_constant_override("margin_left", 12)
	add_child(vb)

	# 顶栏
	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", 10)
	vb.add_child(top)
	top.add_child(kit.make_label("IRON TIDE · 后台控制台", 22, kit.COL_ACCENT_2))
	var sub := kit.make_label("红警3 风格 RTS · 数值与运营的一站式调整台", 13, kit.COL_DIM)
	top.add_child(sub)
	var sp := Control.new()
	sp.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(sp)
	var back := kit.make_button("返回主菜单")
	back.pressed.connect(func(): get_tree().change_scene_to_file("res://scenes/main.tscn"))
	top.add_child(back)

	vb.add_child(kit.divider())

	var tabs := TabContainer.new()
	tabs.size_flags_vertical = Control.SIZE_EXPAND_FILL
	tabs.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vb.add_child(tabs)

	# 数据编译器
	var dc = DataCompilerScript.new()
	dc.name = "数据编译器"
	tabs.add_child(dc)

	# 经济调参
	var ee = EconomyEditorScript.new()
	ee.name = "经济调参"
	tabs.add_child(ee)
	var tuning=preload("res://scripts/admin/progression_editor.gd").new()
	tuning.name="天赋技能调参";tuning.embedded=true;tabs.add_child(tuning)

	# GM 控制台
	var wrap := Control.new()
	wrap.name = "GM 控制台"
	tabs.add_child(wrap)
	var gc = GMConsoleScript.new()
	gc.embed_mode = true
	wrap.add_child(gc)

	# 系统状态
	var info := _make_info_tab()
	info.name = "系统状态"
	tabs.add_child(info)

func _make_info_tab() -> Control:
	var sc := kit.make_scroll()
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 6)
	vb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sc.add_child(vb)

	vb.add_child(kit.make_label("数据文件", 15, kit.COL_ACCENT))
	for row in [
		["units.json", "%d 个单位 · %d 个建筑" % [GameData.units.size(), GameData.buildings.size()]],
		["combat.json", "%d 攻击类型 × %d 护甲类型" % [GameData.combat_attack_types.size(), GameData.combat_armor_types.size()]],
		["factions.json", "%d 个阵营" % GameData.factions.size()],
		["meta.json", "%d 档位 · %d 升级项" % [GameData.meta_config.get("tiers", []).size(), GameData.meta_config.get("upgrades", []).size()]],
		["waves.json", "%d 个关卡" % GameData.missions.size()],
		["cards.json", "抽卡占位（enabled=%s）" % str(GameData.cards.get("enabled", false))],
	]:
		vb.add_child(kit.make_label("  • %s：%s" % [row[0], row[1]], 13, kit.COL_TEXT))

	vb.add_child(kit.hsep(8))
	vb.add_child(kit.make_label("局外存档", 15, kit.COL_ACCENT))
	vb.add_child(kit.make_label("  军需券：%d" % int(MetaProgress.balance("credits")), 13, kit.COL_GOLD))
	vb.add_child(kit.make_label("  战略核心：%d" % int(MetaProgress.balance("cores")), 13, kit.COL_ACCENT))
	vb.add_child(kit.make_label("  当前档位：%s" % MetaProgress.current_tier_data().get("name", MetaProgress.current_tier), 13, kit.COL_TEXT))
	vb.add_child(kit.make_label("  已解锁档位：%s" % str(MetaProgress.unlocked_tiers), 13, kit.COL_TEXT))
	var bonus := MetaProgress.stat_bonuses()
	vb.add_child(kit.make_label("  全局加成：攻击 ×%.2f / 减伤 ×%.2f / 生命 ×%.2f / 速度 ×%.2f / 建造 ×%.2f" % [
		bonus.attack_bonus, bonus.defense_bonus, bonus.hp_bonus, bonus.speed_bonus, bonus.build_bonus
	], 13, kit.COL_OK))
	vb.add_child(kit.make_label("  挂机速率：军需券 %.0f/时 · 核心 %.1f/时 · 上限 %.1f 小时" % [
		MetaProgress.hourly_rate().credits, MetaProgress.hourly_rate().cores, MetaProgress.cap_hours()
	], 13, kit.COL_TEXT))

	vb.add_child(kit.hsep(8))
	vb.add_child(kit.make_label("说明", 15, kit.COL_ACCENT))
	var note := kit.make_label(
		"数据编译器与经济调参器会直接改写内存配置并即时生效；点各页的「保存到磁盘」可写回 res://data/。\n" +
		"注意：仅在使用 Godot 编辑器运行或调试时 res:// 可写，导出的发行包内为只读，会提示写入失败。\n" +
		"单位/建筑的克制倍率在「数据编译器 → 克制矩阵」页调整，倍率 >1 即代表克制。", 13, kit.COL_DIM)
	note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	note.custom_minimum_size = Vector2(760, 0)
	vb.add_child(note)
	return sc

func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
		get_tree().change_scene_to_file("res://scenes/main.tscn")
