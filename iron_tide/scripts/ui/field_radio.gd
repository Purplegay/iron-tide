extends PanelContainer

signal speaker_changed(contact_id:String)

const MIN_READ_SECONDS := 8.0
const CHARACTERS_PER_SECOND := 5.0

var speaker:Label
var body:Label
var waiting:Array[Dictionary]=[]
var _playback:Tween

func _ready() -> void:
	mouse_filter=Control.MOUSE_FILTER_IGNORE
	self_modulate.a=0.32
	add_theme_stylebox_override("panel",UiKit.panel_style(Color("#102029e8"),Color("#528c8e"),2,1,9))
	var column:=VBoxContainer.new()
	column.mouse_filter=Control.MOUSE_FILTER_IGNORE
	add_child(column)
	speaker=UiKit.make_label("",15,UiKit.COL_SIDE_MISSION)
	body=UiKit.make_label("",17,UiKit.COL_SIDE_MISSION)
	for label in [speaker,body]:
		label.add_theme_constant_override("outline_size",3)
		label.add_theme_color_override("font_outline_color",Color("#101820e0"))
		label.mouse_filter=Control.MOUSE_FILTER_IGNORE
		label.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
		column.add_child(label)
	hide()

func transmit(who:String,message:String,contact_id:String) -> void:
	var turns := message.split("\n", false)
	for i in turns.size():
		var voice := who
		var text := turns[i]
		var portrait_id := contact_id
		if i > 0 and text.contains("："):
			var separator := text.find("：")
			voice = text.left(separator)
			text = text.substr(separator + 1)
			if voice != who.get_slice(" · ", 0):
				portrait_id = ""
		waiting.append({"speaker":voice,"message":text,"contact_id":portrait_id})
	if not visible:_show_next()

func _show_next() -> void:
	if waiting.is_empty():
		speaker_changed.emit("")
		hide()
		return
	var entry:Dictionary=waiting.pop_front()
	speaker_changed.emit(entry.contact_id)
	speaker.text=entry.speaker
	body.text=entry.message
	modulate.a=1.0
	show()
	_playback=create_tween().set_ignore_time_scale(true).set_pause_mode(Tween.TWEEN_PAUSE_STOP)
	_playback.tween_interval(maxf(MIN_READ_SECONDS,body.text.length()/CHARACTERS_PER_SECOND))
	_playback.tween_property(self,"modulate:a",0.0,0.35)
	_playback.finished.connect(_show_next)
