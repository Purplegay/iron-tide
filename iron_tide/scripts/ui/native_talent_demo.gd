extends VBoxContainer
## Read-only demonstration: never changes the player's ranks or battle context.
const Training=preload("res://scripts/rules/skill_training.gd")
const Stage=preload("res://scripts/ui/native_talent_stage.gd")
var stage:Control
var levels:OptionButton
var pause_button:Button
var caption:Label
var unit_id:=""
var playback:Control

func _ready() -> void:
	stage=Stage.new();stage.name="ActionStage";add_child(stage)
	var controls:=HBoxContainer.new();add_child(controls)
	levels=UiKit.make_option(["演示 0 级","演示 1 级","演示 2 级","演示 3 级"],0,14)
	levels.name="DemoLevel";controls.add_child(levels)
	pause_button=UiKit.make_button("暂停");pause_button.name="Pause";controls.add_child(pause_button)
	var replay=UiKit.make_button("重播");replay.name="Replay";controls.add_child(replay)
	playback=preload("res://scripts/ui/demo_playback.gd").new();add_child(playback)
	playback.bind(stage,&"elapsed",stage.period,stage.refresh,pause_button)
	caption=UiKit.make_label("",14,UiKit.COL_TEXT);caption.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;add_child(caption)
	levels.item_selected.connect(select_rank)
	pause_button.pressed.connect(func():stage.playing=not stage.playing;pause_button.text="暂停" if stage.playing else "继续")
	replay.pressed.connect(restart)

func configure(id:String,rank:int) -> void:
	unit_id=id;stage.configure(id);select_rank(rank);restart()

func select_rank(rank:int) -> void:
	stage.rank=clampi(rank,0,3);levels.select(stage.rank)
	caption.text=Training.talent_description(unit_id).split("\n")[stage.rank]+"\n"+stage.explanation()
	playback.restore_position(stage.elapsed,stage.playing)

func restart() -> void:
	stage.elapsed=0.0;stage.playing=true;pause_button.text="暂停";stage.refresh()
	playback.sync()
