extends Node
## 用系统字体构建全局主题，保证中文在 Godot 默认字体缺失 CJK 字形时仍可正常显示。

const FONT_CANDIDATES := [
	"Microsoft YaHei UI", "Microsoft YaHei", "微软雅黑",
	"SimHei", "黑体", "SimSun",
	"Noto Sans CJK SC", "Noto Sans SC", "Source Han Sans SC",
	"PingFang SC", "Hiragino Sans GB",
	"Malgun Gothic", "sans-serif"
]

func _ready() -> void:
	var theme := Theme.new()
	var font := SystemFont.new()
	font.font_names = PackedStringArray(FONT_CANDIDATES)
	font.subpixel_positioning = TextServer.SUBPIXEL_POSITIONING_AUTO
	theme.default_font = font
	theme.default_font_size = 14
	var root := get_tree().root
	root.theme = theme
	# 常用控件字号
	theme.set_font_size("font_size", "Button", 14)
	theme.set_font_size("font_size", "Label", 14)
	theme.set_font_size("font_size", "LineEdit", 14)
	theme.set_font_size("font_size", "SpinBox", 14)
	theme.set_font_size("font_size", "OptionButton", 14)
	theme.set_font_size("font_size", "CheckBox", 14)
	theme.set_font_size("font_size", "TabContainer", 14)
