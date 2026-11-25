extends VBoxContainer
## Reusable read-only timeline. User seeking pauses until explicit playback.
## Programmatic position restores keep the caller's playback state.
const RATES := [0.25,0.5,0.75,1.0]
var target:Control
var clock_property:StringName
var length:Callable
var render:Callable
var pause_button:Button
var speed:OptionButton
var timeline:HSlider
var timestamp:Label
var scrubbing:=false

func _ready() -> void:
	var row:=HBoxContainer.new();add_child(row)
	row.add_child(UiKit.make_label("播放速度",13,UiKit.COL_DIM))
	speed=UiKit.make_option(["0.25×","0.5×","0.75×","1×"],3,14)
	speed.name="PlaybackSpeed";row.add_child(speed)
	speed.tooltip_text="相对于当前演示原速；长冷却演示原有的压缩倍速仍会单独标注。"
	timestamp=UiKit.make_label("0.0 / 0.0 秒",13,UiKit.COL_DIM)
	timestamp.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	timestamp.horizontal_alignment=HORIZONTAL_ALIGNMENT_RIGHT;row.add_child(timestamp)
	timeline=HSlider.new();timeline.name="DemoTimeline";timeline.step=0.01
	timeline.custom_minimum_size.y=24;timeline.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	timeline.tooltip_text="点击或拖动查看任意时刻并暂停；松开后保持暂停，点击继续恢复播放。"
	add_child(timeline)
	speed.item_selected.connect(func(i):if is_instance_valid(target):target.playback_speed=RATES[i])
	timeline.value_changed.connect(user_seek)
	timeline.drag_started.connect(begin_scrub)
	timeline.drag_ended.connect(end_scrub)

func bind(player:Control,clock:StringName,duration:Callable,redraw:Callable,pause:Button=null) -> void:
	target=player;clock_property=clock;length=duration;render=redraw;pause_button=pause
	sync()

func add_transport() -> void:
	var row:=HBoxContainer.new();add_child(row);move_child(row,0)
	pause_button=UiKit.make_button("暂停");row.add_child(pause_button)
	var replay:=UiKit.make_button("重播");row.add_child(replay)
	pause_button.pressed.connect(func():target.playing=not target.playing;sync())
	replay.pressed.connect(func():seek(0);target.playing=true;sync())

func begin_scrub() -> void:
	if not is_instance_valid(target):return
	scrubbing=true;target.playing=false;sync()

func end_scrub(_changed:bool) -> void:
	if not is_instance_valid(target):return
	scrubbing=false;target.playing=false;sync()

func user_seek(seconds:float) -> void:
	if not is_instance_valid(target):return
	target.playing=false
	seek(seconds)

func seek(seconds:float) -> void:
	if not is_instance_valid(target):return
	# Keep the right endpoint on the final frame instead of wrapping to zero.
	target.set(clock_property,clampf(seconds,0,maxf(0,float(length.call())-0.00001)))
	render.call();sync()

func restore_position(seconds:float,was_playing:bool) -> void:
	# A shorter rank preview must not wrap immediately and lose the compared pose.
	target.playing=was_playing and seconds<float(length.call())
	seek(seconds)

func sync() -> void:
	if not is_instance_valid(target) or not length.is_valid():return
	var duration:=maxf(0.01,float(length.call()))
	var current:=clampf(float(target.get(clock_property)),0,duration)
	timeline.set_block_signals(true);timeline.max_value=duration
	timeline.set_value_no_signal(current);timeline.set_block_signals(false)
	timestamp.text="%.1f / %.1f 秒" % [current,duration]
	if is_instance_valid(pause_button):pause_button.text="暂停" if target.playing else "继续"

func _process(_dt:float) -> void:
	if is_visible_in_tree():sync()
