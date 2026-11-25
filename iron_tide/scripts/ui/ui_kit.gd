class_name UiKit
extends RefCounted
## UI 构建工具：统一的配色与控件工厂，避免每个界面重复写样式。

const COL_BG := Color(0.05, 0.065, 0.088, 0.96)
const COL_PANEL := Color(0.095, 0.115, 0.155, 0.97)
const COL_PANEL_2 := Color(0.12, 0.145, 0.19, 0.97)
const COL_LINE := Color(0.26, 0.4, 0.58, 0.85)
const COL_ACCENT := Color(0.34, 0.66, 1.0)
const COL_ACCENT_2 := Color(0.6, 0.85, 1.0)
const COL_WARN := Color(1.0, 0.55, 0.4)
const COL_OK := Color(0.45, 0.95, 0.6)
const COL_GOLD := Color(1.0, 0.82, 0.4)
const COL_SIDE_MISSION := Color.LIGHT_SKY_BLUE
const COL_TEXT := Color(0.87, 0.91, 0.97)
const COL_DIM := Color(0.58, 0.64, 0.72)

static func panel_style(bg: Color = COL_PANEL, border: Color = COL_LINE, radius: int = 6, w: int = 1, pad: int = 8) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = bg
	s.border_color = border
	s.set_border_width_all(w)
	s.set_corner_radius_all(radius)
	s.content_margin_left = pad
	s.content_margin_right = pad
	s.content_margin_top = pad - 2
	s.content_margin_bottom = pad - 2
	return s

static func make_label(text: String, size: int = 14, color: Color = COL_TEXT) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	return l

static func make_button(text: String, size: int = 14) -> Button:
	var b := Button.new()
	b.text = text
	b.add_theme_font_size_override("font_size", size)
	b.custom_minimum_size = Vector2(0, 32)
	b.add_theme_stylebox_override("normal", panel_style(Color(0.15, 0.19, 0.26), Color(0.28, 0.42, 0.6), 4, 1, 8))
	b.add_theme_stylebox_override("hover", panel_style(Color(0.21, 0.29, 0.4), Color(0.45, 0.72, 1.0), 4, 1, 8))
	b.add_theme_stylebox_override("pressed", panel_style(Color(0.14, 0.36, 0.62), Color(0.65, 0.88, 1.0), 4, 1, 8))
	b.add_theme_stylebox_override("disabled", panel_style(Color(0.1, 0.115, 0.145), Color(0.2, 0.24, 0.3), 4, 1, 8))
	b.add_theme_stylebox_override("focus", panel_style(Color(0, 0, 0, 0), Color(0, 0, 0, 0), 4, 0, 8))
	b.add_theme_color_override("font_color", COL_TEXT)
	b.add_theme_color_override("font_hover_color", Color(1, 1, 1))
	b.add_theme_color_override("font_disabled_color", Color(0.46, 0.5, 0.56))
	return b

static func make_panel(bg: Color = COL_PANEL, border: Color = COL_LINE, radius: int = 6, w: int = 1, pad: int = 8) -> PanelContainer:
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", panel_style(bg, border, radius, w, pad))
	return p

static func make_spin(value: float, minv: float, maxv: float, step: float = 1.0, size: int = 14) -> SpinBox:
	var s := SpinBox.new()
	s.min_value = minv
	s.max_value = maxv
	s.step = step
	s.value = value
	s.add_theme_font_size_override("font_size", size)
	s.custom_minimum_size = Vector2(84, 30)
	return s

static func make_option(items: Array, selected_idx: int = 0, size: int = 14) -> OptionButton:
	var o := OptionButton.new()
	o.add_theme_font_size_override("font_size", size)
	o.custom_minimum_size = Vector2(110, 30)
	for i in range(items.size()):
		o.add_item(str(items[i]), i)
	if selected_idx >= 0 and selected_idx < items.size():
		o.selected = selected_idx
	return o

static func make_line(text: String = "", size: int = 14) -> LineEdit:
	var l := LineEdit.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.custom_minimum_size = Vector2(140, 30)
	return l

static func make_check(text: String, pressed: bool = false) -> CheckBox:
	var c := CheckBox.new()
	c.text = text
	c.button_pressed = pressed
	c.add_theme_font_size_override("font_size", 14)
	return c

static func make_scroll() -> ScrollContainer:
	var s := ScrollContainer.new()
	s.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	s.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	return s

static func hsep(height: int = 6) -> Control:
	var c := Control.new()
	c.custom_minimum_size = Vector2(0, height)
	return c

static func divider() -> HSeparator:
	var s := HSeparator.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.3, 0.42, 0.58, 0.5)
	sb.content_margin_top = 1
	sb.content_margin_bottom = 1
	s.add_theme_stylebox_override("separator", sb)
	return s

# ==================== 红警3（RA3）风格扩充 ====================
const RA_PANEL := Color(0.050, 0.068, 0.094, 0.95)
const RA_PANEL_2 := Color(0.070, 0.092, 0.126, 0.96)
const RA_TILE := Color(0.086, 0.112, 0.148, 0.98)
const RA_TILE_HI := Color(0.125, 0.205, 0.290, 0.98)
const RA_EDGE := Color(0.20, 0.40, 0.55, 0.95)
const RA_CYAN := Color(0.38, 0.86, 1.0)
const RA_CYAN_DIM := Color(0.24, 0.52, 0.68)
const RA_TEXT := Color(0.86, 0.92, 0.98)
const RA_GOLD := Color(1.0, 0.83, 0.36)

static func ra_style(bg: Color, border: Color = RA_EDGE, radius: int = 3, pad: int = 8, top_accent: bool = true) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = bg
	s.border_color = border
	s.set_border_width_all(1)
	if top_accent:
		s.border_width_top = 2
	s.set_corner_radius_all(radius)
	s.content_margin_left = pad + 2
	s.content_margin_right = pad
	s.content_margin_top = pad
	s.content_margin_bottom = max(2, pad - 3)
	return s

static func ra_panel(bg: Color = RA_PANEL, border: Color = RA_EDGE, radius: int = 4, pad: int = 8) -> PanelContainer:
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", ra_style(bg, border, radius, pad, true))
	return p

static func ra_button(font_size: int = 12, height: int = 28) -> Button:
	var b := Button.new()
	b.add_theme_font_size_override("font_size", font_size)
	b.custom_minimum_size = Vector2(0, height)
	b.add_theme_stylebox_override("normal", ra_style(RA_TILE, Color(0.16, 0.30, 0.42), 3, 6, false))
	b.add_theme_stylebox_override("hover", ra_style(RA_TILE_HI, RA_CYAN, 3, 6, false))
	b.add_theme_stylebox_override("pressed", ra_style(Color(0.16, 0.42, 0.60, 0.96), Color(0.78, 0.96, 1.0), 3, 6, false))
	b.add_theme_stylebox_override("disabled", ra_style(Color(0.085, 0.10, 0.13, 0.9), Color(0.20, 0.24, 0.30), 3, 6, false))
	b.add_theme_stylebox_override("focus", ra_style(Color(0, 0, 0, 0), Color(0, 0, 0, 0), 3, 0, false))
	b.add_theme_color_override("font_color", RA_TEXT)
	b.add_theme_color_override("font_hover_color", Color(1, 1, 1))
	b.add_theme_color_override("font_pressed_color", Color(1, 1, 1))
	b.add_theme_color_override("font_disabled_color", Color(0.44, 0.49, 0.55))
	return b

static func ra_icon_tile(size: int = 44) -> Button:
	# 红警3 式方形命令/技能图标块（无文字，图标与热键角标由调用方叠加）
	var b := ra_button(10, size)
	b.custom_minimum_size = Vector2(size, size)
	b.clip_text = true
	b.focus_mode = Control.FOCUS_NONE
	b.add_theme_stylebox_override("normal", ra_style(RA_TILE, RA_EDGE, 3, 3, false))
	b.add_theme_stylebox_override("hover", ra_style(RA_TILE_HI, RA_CYAN, 3, 3, false))
	b.add_theme_stylebox_override("pressed", ra_style(Color(0.15, 0.40, 0.58, 0.98), Color(0.78, 0.96, 1.0), 3, 3, false))
	b.add_theme_stylebox_override("disabled", ra_style(Color(0.075, 0.09, 0.12, 0.92), Color(0.20, 0.26, 0.32), 3, 3, false))
	b.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	return b

static func ra_label(text: String, size: int = 12, col: Color = RA_TEXT) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", col)
	return l

static func ra_progress(fill: Color = RA_CYAN) -> ProgressBar:
	var p := ProgressBar.new()
	var bg := StyleBoxFlat.new()
	bg.bg_color = Color(0.03, 0.05, 0.07, 0.9)
	bg.set_corner_radius_all(2)
	var fg := StyleBoxFlat.new()
	fg.bg_color = fill
	fg.set_corner_radius_all(2)
	p.add_theme_stylebox_override("background", bg)
	p.add_theme_stylebox_override("fill", fg)
	p.show_percentage = false
	return p

static func color_for_mult(v: float) -> Color:
	if v >= 1.6:
		return Color(0.45, 1.0, 0.55)
	if v >= 1.15:
		return Color(0.7, 1.0, 0.6)
	if v >= 0.95:
		return COL_TEXT
	if v >= 0.6:
		return Color(1.0, 0.85, 0.5)
	return Color(1.0, 0.5, 0.45)
