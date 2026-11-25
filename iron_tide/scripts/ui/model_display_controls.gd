extends CheckBox
## Shared menu/battle option; signals keep multiple open controls consistent.
func _ready() -> void:
	name = "ModelSmoothing"
	text = "模型边缘柔化"
	tooltip_text = "开启：柔化单位、建筑放大后的像素边缘。关闭：原像素风格。\n立即生效并记住选择；不会增加原素材细节，文字与按钮保持清晰。"
	add_theme_font_size_override("font_size", 14)
	set_pressed_no_signal(MetaProgress.model_smoothing)
	toggled.connect(MetaProgress.set_model_smoothing)
	MetaProgress.model_smoothing_changed.connect(set_pressed_no_signal)
