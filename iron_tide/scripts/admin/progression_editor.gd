extends Control
## A draft is separate from live combat. Only Apply mutates definitions; Save persists applied edits.
var embedded:=false
var model
var selector:ItemList
var search:LineEdit
var category:OptionButton
var form:VBoxContainer
var status:Label
var detail:RichTextLabel
var scroll:ScrollContainer
var selected:=""
var listed:Array[String]=[]
var drafts:Dictionary={}
var inputs:Dictionary={}
var shown:Array[String]=[]

func _ready() -> void:
	model=GameData.progression_tuning
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter=Control.MOUSE_FILTER_STOP
	var panel:=UiKit.make_panel(Color(.055,.07,.1,.99))
	add_child(panel);panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	if not embedded:panel.offset_left=32;panel.offset_top=32;panel.offset_right=-32;panel.offset_bottom=-32
	var outer:=VBoxContainer.new();panel.add_child(outer)
	var head:=HBoxContainer.new();outer.add_child(head)
	head.add_child(UiKit.make_label("天赋／技能调参",22,UiKit.COL_ACCENT))
	var spacer:=Control.new();spacer.size_flags_horizontal=Control.SIZE_EXPAND_FILL;head.add_child(spacer)
	if not embedded:
		var close:=UiKit.make_button("关闭（未应用草稿丢弃）");head.add_child(close);close.pressed.connect(queue_free)
	var hint:=UiKit.make_label("应用：更新本次运行所有阵营的配置与在场技能，不重置剩余CD或清除正在生效的状态。保存：下次启动继续使用。",13,UiKit.COL_DIM)
	hint.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;outer.add_child(hint)
	var filters:=HBoxContainer.new();outer.add_child(filters)
	search=LineEdit.new();search.name="TuningSearch";search.placeholder_text="搜索技能、英雄、机制或参数名（如护盾持续）";search.size_flags_horizontal=Control.SIZE_EXPAND_FILL;filters.add_child(search)
	category=OptionButton.new();category.add_item("全部");category.add_item("技能");category.add_item("天赋");category.add_item("英雄养成");category.add_item("机制参数");filters.add_child(category)
	search.text_changed.connect(func(_text):refresh_list());category.item_selected.connect(func(_index):refresh_list())
	var split:=HSplitContainer.new();split.size_flags_vertical=Control.SIZE_EXPAND_FILL;outer.add_child(split)
	selector=ItemList.new();selector.name="TuningList";selector.custom_minimum_size.x=285;selector.size_flags_vertical=Control.SIZE_EXPAND_FILL;split.add_child(selector)
	selector.item_selected.connect(func(index):select_key(listed[index]))
	var right:=VBoxContainer.new();right.size_flags_horizontal=Control.SIZE_EXPAND_FILL;split.add_child(right)
	detail=RichTextLabel.new();detail.custom_minimum_size.y=160;detail.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	detail.add_theme_font_size_override("normal_font_size",14);detail.add_theme_color_override("default_color",UiKit.COL_DIM)
	detail.meta_underlined=true;detail.meta_clicked.connect(focus_parameter);right.add_child(detail)
	scroll=UiKit.make_scroll();scroll.size_flags_vertical=Control.SIZE_EXPAND_FILL;scroll.follow_focus=true;right.add_child(scroll)
	form=VBoxContainer.new();form.size_flags_horizontal=Control.SIZE_EXPAND_FILL;scroll.add_child(form)
	var actions:=HBoxContainer.new();right.add_child(actions)
	var apply_button:=UiKit.make_button("应用本项");apply_button.name="ApplyTuning";actions.add_child(apply_button);apply_button.pressed.connect(apply_current)
	var save_button:=UiKit.make_button("保存已应用修改到本机");save_button.name="SaveTuning";actions.add_child(save_button);save_button.pressed.connect(save_applied)
	var reset_button:=UiKit.make_button("恢复本项原值");reset_button.name="ResetTuning";actions.add_child(reset_button);reset_button.pressed.connect(reset_current)
	status=UiKit.make_label(model.warning,13,UiKit.COL_GOLD);status.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;outer.add_child(status)
	var scope:=UiKit.make_label("英雄养成及固定机制参数已加入。秒／格／比例见字段名称；应用后影响后续触发，已生成的护盾和在途效果保留各自状态。出生属性用新建单位验证。",12,UiKit.COL_DIM)
	scope.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;outer.add_child(scope)
	refresh_list()

func refresh_list() -> void:
	selector.clear();listed.clear()
	var query:=search.text.strip_edges().to_lower()
	for key:String in model.records:
		var record:Dictionary=model.records[key]
		if category.selected>0 and record.kind!=category.get_item_text(category.selected):continue
		var title:="%s · %s [%s]"%[record.kind,record.name,record.unit]
		var searchable:=title+key
		for field:Dictionary in model.fields(key):searchable+=" "+str(field.label)
		if not query.is_empty() and not searchable.to_lower().contains(query):continue
		listed.append(key);selector.add_item(title);selector.set_item_tooltip(listed.size()-1,key)
	var index:=listed.find(selected)
	if index<0 and not listed.is_empty():index=0
	if index>=0:selector.select(index);select_key(listed[index])
	else:selected="";clear_form();detail.text="没有匹配的技能或天赋"

func clear_form() -> void:
	inputs.clear();shown.clear()
	for child in form.get_children():form.remove_child(child);child.queue_free()

func select_key(key:String) -> void:
	selected=key;clear_form()
	var record:Dictionary=model.records[key]
	if not drafts.has(key):drafts[key]=model.values(key)
	add_fields(key)
	if record.kind in ["技能","天赋"]:
		for related:String in preload("res://scripts/rules/progression_parameters.gd").related(key.get_slice("/",1) if record.kind=="技能" else key.get_slice("/",2)):
			form.add_child(UiKit.make_label("固定机制 · "+str(model.records[related].name),15,UiKit.COL_ACCENT))
			add_fields(related)
	if inputs.is_empty():form.add_child(UiKit.make_label("此项目没有已配置的可调数值。",14,UiKit.COL_DIM))
	refresh_description()
	scroll.scroll_vertical=0

func refresh_description() -> void:
	var record:Dictionary=model.records[selected]
	detail.clear()
	detail.add_text("%s\n%s\n%s"%[record.name,selected,record.live.get("desc","")])
	detail.add_text("\n快捷调整（点击下划线，定位到起始等级）：")
	for key:String in shown:
		detail.add_text("\n"+("固定机制 · "+str(model.records[key].name)+"：" if key!=selected else ""))
		var first:=true
		for target:Dictionary in parameter_targets(key):
			if not first:detail.add_text("　／　")
			first=false
			detail.push_color(UiKit.COL_ACCENT_2)
			detail.push_meta(target.input,RichTextLabel.META_UNDERLINE_ALWAYS,"定位到 "+str(target.label))
			detail.add_text(target.label)
			detail.pop();detail.pop()
	detail.scroll_to_line(0)

func parameter_targets(key:String) -> Array:
	var targets:Array=[]
	var groups:Dictionary={}
	for field:Dictionary in model.fields(key):
		var path:String=field.path
		var group:=path
		var rank:=-1
		var parts:=path.split("/")
		if parts[-1].is_valid_int():
			rank=int(parts[-1]);group=path.get_base_dir()
		elif parts[0]=="ranks" and parts.size()>2:
			rank=int(parts[1])+1;group="base" if parts[2]=="value" else "ranks/"+parts[2]
		elif path=="base":rank=0
		var target:={"input":path if key==selected else key+"|"+path,"label":field.label,"rank":rank}
		if not groups.has(group):groups[group]=targets.size();targets.append(target)
		elif rank<int(targets[groups[group]].rank):targets[groups[group]]=target
	return targets

func focus_parameter(meta:Variant) -> void:
	var path:=str(meta)
	if not inputs.has(path):return
	var spin:SpinBox=inputs[path]
	spin.get_line_edit().grab_focus()
	spin.get_line_edit().select_all()
	scroll.ensure_control_visible(spin)

func add_fields(key:String) -> void:
	shown.append(key)
	var record:Dictionary=model.records[key]
	if not drafts.has(key):drafts[key]=model.values(key)
	for field:Dictionary in model.fields(key):
		var row:=HBoxContainer.new();form.add_child(row)
		var label:=UiKit.make_label(field.label,14,UiKit.COL_TEXT);label.custom_minimum_size.x=245;row.add_child(label)
		var spin:=SpinBox.new();spin.min_value=minf(field.minimum,float(field.value));spin.max_value=field.maximum;spin.step=field.step
		spin.custom_minimum_size.x=140;spin.value=drafts[key][field.path];spin.tooltip_text=field.hint;row.add_child(spin);inputs[field.path if key==selected else key+"|"+field.path]=spin
		var original:=UiKit.make_label("原值 %s"%str(field.value),12,UiKit.COL_DIM);row.add_child(original)
		label.tooltip_text=field.path+"\n"+field.hint
		spin.value_changed.connect(func(value):drafts[key][field.path]=value;status.text="有未应用草稿："+str(record.name))

func apply_current() -> void:
	if selected.is_empty():return
	for path in inputs:inputs[path].apply()
	for key:String in shown:
		var error:String=model.validate(key,drafts[key])
		if not error.is_empty():status.text=error;return
	for key:String in shown:model.apply(key,drafts[key])
	status.text="已应用："+str(model.records[selected].name)+"及所列固定参数。尚未保存到本机。"
	select_key(selected)

func save_applied() -> void:
	var error:String=model.save()
	status.text=error if not error.is_empty() else "已保存已应用修改；未应用草稿未保存。位置："+ProjectSettings.globalize_path(model.STORE)

func reset_current() -> void:
	if selected.is_empty():return
	for key:String in shown:
		var error:String=model.apply(key,{})
		if not error.is_empty():status.text=error;return
		drafts.erase(key)
	select_key(selected)
	status.text="本项已恢复原值。点击保存后，下次启动也使用原值。"

func _unhandled_key_input(event:InputEvent) -> void:
	if not is_visible_in_tree():return
	if not embedded and event.is_action_pressed("ui_cancel"):queue_free()
	get_viewport().set_input_as_handled()
