extends Node
## WeaponTuner V15 - 原生属性面板编辑中枢
## 负责弹出输入框、写入 RunData 属性 effects、清理缓存并刷新面板。
## 数值来源：RunData.get_player_effects(idx)[key_hash]，面板显示走 Utils.get_stat（effects * gain）。

const LOG_NAME := "Liangzi-WeaponTunerV15:Edit"
const FONT_PATH := "res://resources/fonts/actual/base/font_22.tres"

const COL_PANEL_BG := Color(0.035, 0.035, 0.05, 0.96)
const COL_BTN_BG := Color(0.02, 0.02, 0.03, 0.94)
const COL_BTN_HOVER := Color(0.13, 0.12, 0.10, 0.98)
const COL_BORDER := Color(0.90, 0.88, 0.72, 0.55)
const COL_TEXT := Color(1, 1, 1, 1)
const COL_SUB := Color(0.78, 0.78, 0.78, 1)
const COL_ACCENT := Color(1.0, 0.86, 0.28, 1)

## 由 player 扩展注册，用于改完属性后让实际数值重算
var player = null

var _font = null
var _layer: CanvasLayer = null
var _panel: PanelContainer = null
var _title: Label = null
var _hint: Label = null
var _edit: LineEdit = null

var _cur_hash := 0
var _cur_index := 0
var _cur_gain := 1.0
var _cur_title := ""
var _cur_is_int := true
var _ctx = null
var _paused_by_us := false


func _ready() -> void:
	_font = load(FONT_PATH)
	_build()


func _style(bg: Color, border: Color, width := 1, radius := 0) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	sb.border_color = border
	sb.set("border_width_left", width)
	sb.set("border_width_right", width)
	sb.set("border_width_top", width)
	sb.set("border_width_bottom", width)
	sb.set("corner_radius_top_left", radius)
	sb.set("corner_radius_top_right", radius)
	sb.set("corner_radius_bottom_left", radius)
	sb.set("corner_radius_bottom_right", radius)
	return sb


func _fontify(control) -> void:
	if _font != null and control != null:
		control.set("custom_fonts/font", _font)


func _button(text: String) -> Button:
	var b := Button.new()
	b.text = text
	_fontify(b)
	b.set("custom_styles/normal", _style(COL_BTN_BG, COL_BORDER, 1, 3))
	b.set("custom_styles/hover", _style(COL_BTN_HOVER, COL_ACCENT, 1, 3))
	b.set("custom_styles/pressed", _style(COL_ACCENT, COL_ACCENT, 1, 3))
	b.set("custom_colors/font_color", COL_TEXT)
	b.set("custom_colors/font_color_hover", COL_ACCENT)
	b.set("custom_colors/font_color_pressed", Color(0, 0, 0, 1))
	return b


func _build() -> void:
	_layer = CanvasLayer.new()
	_layer.name = "WT15EditorLayer"
	_layer.layer = 120
	_layer.pause_mode = Node.PAUSE_MODE_PROCESS
	add_child(_layer)

	_panel = PanelContainer.new()
	_panel.name = "WT15EditorPanel"
	_panel.anchor_left = 0.5
	_panel.anchor_top = 0.5
	_panel.anchor_right = 0.5
	_panel.anchor_bottom = 0.5
	_panel.margin_left = -260.0
	_panel.margin_top = -110.0
	_panel.margin_right = 260.0
	_panel.margin_bottom = 110.0
	_panel.set("custom_styles/panel", _style(COL_PANEL_BG, COL_BORDER, 2, 5))
	_layer.add_child(_panel)

	var margin := MarginContainer.new()
	margin.set("custom_constants/margin_left", 18)
	margin.set("custom_constants/margin_right", 18)
	margin.set("custom_constants/margin_top", 14)
	margin.set("custom_constants/margin_bottom", 14)
	_panel.add_child(margin)

	var vb := VBoxContainer.new()
	vb.set("custom_constants/separation", 10)
	margin.add_child(vb)

	_title = Label.new()
	_title.align = Label.ALIGN_CENTER
	_fontify(_title)
	_title.set("custom_colors/font_color", COL_ACCENT)
	vb.add_child(_title)

	_hint = Label.new()
	_hint.align = Label.ALIGN_CENTER
	_fontify(_hint)
	_hint.set("custom_colors/font_color", COL_SUB)
	vb.add_child(_hint)

	_edit = LineEdit.new()
	_edit.align = LineEdit.ALIGN_CENTER
	_fontify(_edit)
	_edit.set("custom_styles/normal", _style(COL_BTN_BG, COL_BORDER, 1, 3))
	_edit.set("custom_styles/focus", _style(COL_BTN_BG, COL_ACCENT, 1, 3))
	_edit.set("custom_colors/font_color", COL_TEXT)
	_edit.set("custom_colors/caret_color", COL_ACCENT)
	_edit.connect("text_entered", self, "_on_text_entered")
	vb.add_child(_edit)

	var hb := HBoxContainer.new()
	hb.alignment = BoxContainer.ALIGN_CENTER
	hb.set("custom_constants/separation", 12)
	vb.add_child(hb)

	var ok := _button("确定")
	ok.rect_min_size = Vector2(110, 34)
	ok.connect("pressed", self, "_apply")
	hb.add_child(ok)

	var cancel := _button("取消")
	cancel.rect_min_size = Vector2(110, 34)
	cancel.connect("pressed", self, "close_panel")
	hb.add_child(cancel)

	_panel.hide()


func open(key_hash: int, player_index: int, title: String, cur_value: float, gain: float, ctx, is_int: bool) -> void:
	_cur_hash = key_hash
	_cur_index = player_index
	_cur_title = title
	_cur_gain = gain
	_cur_is_int = is_int
	_ctx = ctx
	_title.text = "修改：" + title
	_hint.text = "当前 %s ｜ 输入新数值后按回车" % _fmt(cur_value, is_int)
	_edit.text = _fmt(cur_value, is_int)
	_panel.show()
	if not get_tree().paused:
		get_tree().paused = true
		_paused_by_us = true
	_edit.grab_focus()
	_edit.select_all()


func _fmt(v: float, is_int: bool) -> String:
	if is_int:
		return str(int(round(v)))
	return "%.2f" % v


func _on_text_entered(_text: String) -> void:
	_apply()


func _apply() -> void:
	if _ctx == null:
		close_panel()
		return
	var txt := _edit.text.strip_edges()
	if txt == "":
		close_panel()
		return
	if not txt.is_valid_float():
		_hint.text = "请输入数字"
		return
	var v := float(txt)
	if _cur_is_int:
		v = round(v)
	var effects = RunData.get_player_effects(_cur_index)
	if effects == null:
		_hint.text = "取不到玩家属性数据"
		return
	# 面板显示值 = effects * gain，所以反解出 effects
	effects[_cur_hash] = v / max(_cur_gain, 0.0001)
	Utils.reset_stat_caches()
	if player != null and is_instance_valid(player) and player.has_method("update_player_stats"):
		player.update_player_stats()
	_refresh_ctx()
	ModLoaderLog.info("属性 [%s] 已设为 %s" % [_cur_title, str(v)], LOG_NAME)
	close_panel()


func _refresh_ctx() -> void:
	var p = _ctx
	while p != null:
		if p.has_method("update_player_stats"):
			p.update_player_stats(_cur_index)
			return
		p = p.get_parent()


func close_panel() -> void:
	_panel.hide()
	if _paused_by_us and get_tree().paused:
		get_tree().paused = false
	_paused_by_us = false
	_ctx = null
