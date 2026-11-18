extends Control
## 武器数值调整面板 V14
## 相比 V13 的变化：
##  1) 武器“攻击速度”改为倍率语义：数值越大攻速越快（1~500 倍，步长 1）。
##     内部自动换算成游戏使用的 cooldown（冷却帧）：cooldown = 原始冷却 / 攻速倍率。
##  2) 新增“原始数值”区：可修改武器基础 Resource（stats）上的字段，
##     改完同类武器都会按新原始数值生效，并写入存档跨局保持。
##  3) UI 换成《土豆兄弟》同款：半透明黑底、白色文字、黄色强调、黑底按钮。
##
## 保留 V13 能力：鼠标 +/- 或输入数字、打开自动暂停、关闭生效、
## 跨波不重置（hook update_player_stats）、生命只改上限、跨局存档、自选波数跳转。

var _player = null

var _root: PanelContainer = null
var _scroll: ScrollContainer = null
var _content: VBoxContainer = null
var _title: Label = null
var _summary: Label = null

var _rows: Array = []
var _rebuild_timer: float = 0.0
var _check_timer: float = 0.0
var _visible: bool = true
var _weapon_sig: String = ""
var _show_base: bool = true

# 游戏自带字体（含简体中文字形）
var _ui_font = null
const FONT_PATH := "res://resources/fonts/actual/base/font_22.tres"
const LOG_NAME := "Liangzi-WeaponTunerV15:Panel"
## 与游戏存档同目录：%APPDATA%/Brotato/liangzi_weapon_tuner_save.json
const SAVE_PATH := "user://liangzi_weapon_tuner_save.json"

const ROW_H := 30
const BTN_W := 34
const EDIT_W := 92

const SCOPE_PLAYER := 0
const SCOPE_WEAPON := 1
const SCOPE_BASE := 2

const SPEED_PROP := "attack_speed"
const SPEED_MIN := 1.0
const SPEED_MAX := 500.0

# 《土豆兄弟》风格配色：黑底、白字、米黄强调、暗金描边
const COL_PANEL_BG := Color(0.035, 0.035, 0.05, 0.94)
const COL_BTN_BG := Color(0.02, 0.02, 0.03, 0.94)
const COL_BTN_HOVER := Color(0.13, 0.12, 0.10, 0.98)
const COL_BORDER := Color(0.90, 0.88, 0.72, 0.55)
const COL_TEXT := Color(1, 1, 1, 1)
const COL_SUB := Color(0.78, 0.78, 0.78, 1)
const COL_ACCENT := Color(1.0, 0.86, 0.28, 1)

# ============ 持久 override 层 ============
# 角色：{prop: value}
# 当前武器：{weapon_id: {prop: value}}
# 原始武器：{weapon_id: {prop: value}}
var _player_overrides := {}
var _weapon_overrides := {}
var _weapon_base_overrides := {}

# 正在编辑的行（聚焦的输入框），自动刷新时跳过它，避免覆盖用户输入
var _editing_info = null
# 记录本面板是否接管了暂停，避免误解除游戏自身的暂停
var _pause_owned: bool = false

# 波数跳转控件
var _wave_edit: LineEdit = null
var _wave_label: Label = null

# 角色 LiveStats 字段
const PLAYER_STATS := [
	{"prop": "health", "label": "生命上限", "step": 10, "int": true},
	{"prop": "damage", "label": "攻击力", "step": 1, "int": true},
	{"prop": "speed", "label": "移动速度", "step": 10, "int": true},
	{"prop": "armor", "label": "护甲", "step": 1, "int": true},
	{"prop": "dodge", "label": "闪避(0-1)", "step": 0.05, "int": false},
]

# 当前武器数值字段（攻速倍率越大越快）
const WEAPON_STATS := [
	{"prop": "attack_speed", "label": "攻击速度(越大越快)", "step": 1, "int": true},
	{"prop": "damage", "label": "伤害", "step": 1, "int": true},
	{"prop": "accuracy", "label": "命中(0-1)", "step": 0.05, "int": false},
	{"prop": "crit_chance", "label": "暴击率(0-1)", "step": 0.05, "int": false},
	{"prop": "crit_damage", "label": "暴击伤害", "step": 0.1, "int": false},
	{"prop": "min_range", "label": "最小射程", "step": 10, "int": true},
	{"prop": "max_range", "label": "最大射程", "step": 10, "int": true},
	{"prop": "knockback", "label": "击退", "step": 1, "int": true},
	{"prop": "knockback_piercing", "label": "击退穿透(0-1)", "step": 0.05, "int": false},
	{"prop": "lifesteal", "label": "吸血(0-1)", "step": 0.05, "int": false},
	{"prop": "effect_scale", "label": "效果强度", "step": 0.1, "int": false},
	{"prop": "recoil", "label": "后坐力", "step": 5, "int": true},
	{"prop": "nb_projectiles", "label": "弹丸数", "step": 1, "int": true},
	{"prop": "piercing", "label": "穿透数", "step": 1, "int": true},
	{"prop": "bounce", "label": "弹射数", "step": 1, "int": true},
	{"prop": "projectile_speed", "label": "弹速", "step": 100, "int": true},
	{"prop": "projectile_spread", "label": "散布(0-1)", "step": 0.05, "int": false},
]

# 原始数值（weapon.stats 资源）字段，可修改
const BASE_WEAPON_STATS := [
	{"prop": "cooldown", "label": "原始冷却(帧,越小越快)", "step": 1, "int": true},
	{"prop": "damage", "label": "原始伤害", "step": 1, "int": true},
	{"prop": "accuracy", "label": "原始命中(0-1)", "step": 0.05, "int": false},
	{"prop": "crit_chance", "label": "原始暴击率(0-1)", "step": 0.05, "int": false},
	{"prop": "crit_damage", "label": "原始暴击伤害", "step": 0.1, "int": false},
	{"prop": "min_range", "label": "原始最小射程", "step": 10, "int": true},
	{"prop": "max_range", "label": "原始最大射程", "step": 10, "int": true},
	{"prop": "knockback", "label": "原始击退", "step": 1, "int": true},
	{"prop": "knockback_piercing", "label": "原始击退穿透(0-1)", "step": 0.05, "int": false},
	{"prop": "lifesteal", "label": "原始吸血(0-1)", "step": 0.05, "int": false},
	{"prop": "effect_scale", "label": "原始效果强度", "step": 0.1, "int": false},
	{"prop": "recoil", "label": "原始后坐力", "step": 5, "int": true},
	{"prop": "nb_projectiles", "label": "原始弹丸数", "step": 1, "int": true},
	{"prop": "piercing", "label": "原始穿透数", "step": 1, "int": true},
	{"prop": "bounce", "label": "原始弹射数", "step": 1, "int": true},
	{"prop": "projectile_speed", "label": "原始弹速", "step": 100, "int": true},
	{"prop": "projectile_spread", "label": "原始散布(0-1)", "step": 0.05, "int": false},
]


func setup(player) -> void:
	_player = player
	_ui_font = load(FONT_PATH)
	if _ui_font == null:
		ModLoaderLog.info("警告：游戏字体加载失败，中文可能显示为方块", LOG_NAME)
	_load_overrides()
	_build_ui()


# ==================== 游戏同款 UI 样式 ====================

func _flat_style(bg: Color, border: Color, width: int = 1, radius: int = 0) -> StyleBoxFlat:
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
	sb.set("content_margin_left", 6)
	sb.set("content_margin_right", 6)
	sb.set("content_margin_top", 3)
	sb.set("content_margin_bottom", 3)
	return sb


## 给控件统一设置游戏自带中文字体
func _apply_font(control) -> void:
	if _ui_font != null and control != null:
		control.set("custom_fonts/font", _ui_font)


func _style_label(label, color: Color = COL_TEXT) -> void:
	_apply_font(label)
	label.set("custom_colors/font_color", color)


func _style_button(btn, accent: bool = false) -> void:
	_apply_font(btn)
	btn.set("custom_styles/normal", _flat_style(COL_BTN_BG, COL_BORDER, 1, 3))
	btn.set("custom_styles/hover", _flat_style(COL_BTN_HOVER, COL_ACCENT, 1, 3))
	btn.set("custom_styles/pressed", _flat_style(COL_ACCENT, COL_ACCENT, 1, 3))
	btn.set("custom_styles/focus", _flat_style(COL_BTN_BG, COL_ACCENT, 1, 3))
	btn.set("custom_colors/font_color", COL_ACCENT if accent else COL_TEXT)
	btn.set("custom_colors/font_color_hover", COL_ACCENT)
	btn.set("custom_colors/font_color_pressed", Color(0, 0, 0, 1))


func _style_edit(edit) -> void:
	_apply_font(edit)
	edit.set("custom_styles/normal", _flat_style(COL_BTN_BG, COL_BORDER, 1, 2))
	edit.set("custom_styles/focus", _flat_style(COL_BTN_BG, COL_ACCENT, 1, 2))
	edit.set("custom_colors/font_color", COL_TEXT)
	edit.set("custom_colors/selection_color", Color(1, 0.86, 0.28, 0.45))
	edit.align = 1


# ==================== 存档读写 ====================

func _load_overrides() -> void:
	var f := File.new()
	var dir := Directory.new()
	if not dir.file_exists(SAVE_PATH):
		ModLoaderLog.info("未找到数值存档，本局使用游戏默认数值", LOG_NAME)
		return
	var err = f.open(SAVE_PATH, File.READ)
	if err != OK:
		ModLoaderLog.info("数值存档打开失败（%d），使用默认数值" % err, LOG_NAME)
		return
	var text = f.get_as_text()
	f.close()
	var parsed = JSON.parse(text)
	if parsed.error != OK or not (parsed.result is Dictionary):
		ModLoaderLog.info("数值存档解析失败，使用默认数值", LOG_NAME)
		return
	var data: Dictionary = parsed.result
	if data.has("player") and data["player"] is Dictionary:
		for k in data["player"]:
			_player_overrides[str(k)] = float(data["player"][k])
	if data.has("weapons") and data["weapons"] is Dictionary:
		for wid in data["weapons"]:
			var sub = data["weapons"][wid]
			if sub is Dictionary:
				var d := {}
				for p in sub:
					d[str(p)] = float(sub[p])
				_weapon_overrides[str(wid)] = d
	# V14：原始数值存档（兼容老存档没有该字段的情况）
	if data.has("base_weapons") and data["base_weapons"] is Dictionary:
		for wid in data["base_weapons"]:
			var sub2 = data["base_weapons"][wid]
			if sub2 is Dictionary:
				var d2 := {}
				for p in sub2:
					d2[str(p)] = float(sub2[p])
				_weapon_base_overrides[str(wid)] = d2
	ModLoaderLog.info("已从存档恢复：角色%d项 / 当前武器%d种 / 原始武器%d种" % [_player_overrides.size(), _weapon_overrides.size(), _weapon_base_overrides.size()], LOG_NAME)


func _save_overrides() -> void:
	var data := {
		"player": _player_overrides,
		"weapons": _weapon_overrides,
		"base_weapons": _weapon_base_overrides,
	}
	var f := File.new()
	var err = f.open(SAVE_PATH, File.WRITE)
	if err != OK:
		ModLoaderLog.info("数值存档写入失败（%d）" % err, LOG_NAME)
		return
	f.store_string(JSON.print(data))
	f.close()


func _reset_saved() -> void:
	_player_overrides.clear()
	_weapon_overrides.clear()
	_weapon_base_overrides.clear()
	var dir := Directory.new()
	if dir.file_exists(SAVE_PATH):
		dir.remove(SAVE_PATH)
	ModLoaderLog.info("已清空数值存档，恢复游戏默认数值", LOG_NAME)
	_rebuild_rows()


# ==================== 界面构建 ====================

func _build_ui() -> void:
	self.anchor_left = 1.0
	self.anchor_right = 1.0
	self.anchor_top = 0.0
	self.anchor_bottom = 0.0
	self.margin_left = -430.0
	self.margin_right = -12.0
	self.margin_top = 78.0
	self.margin_bottom = 720.0
	self.mouse_filter = Control.MOUSE_FILTER_STOP

	_root = PanelContainer.new()
	_root.name = "WTPanelRoot"
	_root.anchor_right = 1.0
	_root.anchor_bottom = 1.0
	_root.set("custom_styles/panel", _flat_style(COL_PANEL_BG, COL_BORDER, 2, 6))
	add_child(_root)

	var vb := VBoxContainer.new()
	vb.anchor_right = 1.0
	vb.anchor_bottom = 1.0
	vb.set("custom_constants/separation", 4)
	_root.add_child(vb)

	# 标题栏
	var header := HBoxContainer.new()
	vb.add_child(header)
	_title = Label.new()
	_title.text = "武器数值调整"
	_title.align = Label.ALIGN_CENTER
	_title.size_flags_horizontal = Label.SIZE_EXPAND_FILL
	_style_label(_title, COL_ACCENT)
	header.add_child(_title)

	var reset_btn := Button.new()
	reset_btn.text = "清档"
	reset_btn.rect_min_size = Vector2(42, 26)
	_style_button(reset_btn)
	reset_btn.connect("pressed", self, "_reset_saved")
	header.add_child(reset_btn)

	var close_btn := Button.new()
	close_btn.text = "关闭"
	close_btn.rect_min_size = Vector2(46, 26)
	_style_button(close_btn)
	close_btn.connect("pressed", self, "hide_panel")
	header.add_child(close_btn)

	# 攻速 / 伤害倍率摘要（游戏同款黄白配色）
	_summary = Label.new()
	_summary.text = "攻速 x1.00    伤害 x1.00"
	_summary.align = Label.ALIGN_CENTER
	_style_label(_summary, COL_SUB)
	vb.add_child(_summary)

	# 波数控制行
	var wave_row := HBoxContainer.new()
	wave_row.rect_min_size = Vector2(0, 30)
	vb.add_child(wave_row)

	_wave_label = Label.new()
	_wave_label.text = "跳到第几波："
	_wave_label.rect_min_size = Vector2(92, 24)
	_style_label(_wave_label, COL_TEXT)
	wave_row.add_child(_wave_label)

	_wave_edit = LineEdit.new()
	_wave_edit.rect_min_size = Vector2(64, 24)
	_wave_edit.placeholder_text = "下一波"
	_style_edit(_wave_edit)
	wave_row.add_child(_wave_edit)

	var go_btn := Button.new()
	go_btn.text = "跳转"
	go_btn.rect_min_size = Vector2(50, 24)
	_style_button(go_btn)
	go_btn.connect("pressed", self, "_on_goto_wave")
	wave_row.add_child(go_btn)

	# 原始数值显示开关
	var base_btn := Button.new()
	base_btn.text = "原始数值：显示（点此隐藏）" if _show_base else "原始数值：隐藏（点此显示）"
	base_btn.rect_min_size = Vector2(0, 24)
	_style_button(base_btn)
	base_btn.connect("pressed", self, "_toggle_base")
	vb.add_child(base_btn)

	_scroll = ScrollContainer.new()
	_scroll.size_flags_vertical = ScrollContainer.SIZE_EXPAND_FILL
	_scroll.anchor_right = 1.0
	_scroll.anchor_bottom = 1.0
	vb.add_child(_scroll)

	_content = VBoxContainer.new()
	_content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_content.set("custom_constants/separation", 2)
	_scroll.add_child(_content)

	_rebuild_rows()


func _toggle_base() -> void:
	_show_base = not _show_base
	_rebuild_rows()
	ModLoaderLog.info("原始数值区：%s" % ("显示" if _show_base else "隐藏"), LOG_NAME)


func _clear_rows() -> void:
	_rows.clear()
	_editing_info = null
	if _content == null:
		return
	for child in _content.get_children():
		child.queue_free()


func _compute_weapon_sig() -> String:
	if _player == null or not is_instance_valid(_player):
		return ""
	var weapons = _player.get("current_weapons")
	if weapons == null:
		return ""
	var parts := []
	for w in weapons:
		if is_instance_valid(w):
			parts.append("%d:%s" % [w.get_instance_id(), str(w.get("weapon_id"))])
		else:
			parts.append("null")
	var sig := ""
	for i in range(parts.size()):
		if i > 0:
			sig += "|"
		sig += parts[i]
	return sig


func _section(text: String, color: Color = COL_ACCENT) -> void:
	var lbl := Label.new()
	lbl.text = text
	_style_label(lbl, color)
	_content.add_child(lbl)


func _rebuild_rows() -> void:
	if _content == null or _player == null:
		return
	_clear_rows()
	_weapon_sig = _compute_weapon_sig()

	_section("── 角色（存档保持，跨局有效）──")
	var cs = _player.get("current_stats")
	if cs != null:
		for def in PLAYER_STATS:
			_add_player_row(def)

	var weapons = _player.get("current_weapons")
	var wcount = weapons.size() if weapons != null else 0
	_section("── 武器（%d 把，按武器种类存档）──" % wcount)

	if weapons != null:
		for i in range(weapons.size()):
			var weapon = weapons[i]
			if not is_instance_valid(weapon):
				continue
			var wname := "武器"
			var wstats = weapon.get("stats")
			if wstats != null:
				var nm = wstats.get("name")
				if nm != null and str(nm) != "":
					wname = str(nm)
			_section("[武器%d] %s" % [i + 1, wname], COL_ACCENT)

			var ws = weapon.get("current_stats")
			if ws == null:
				continue
			_section("  当前数值（攻速越大越快）", COL_TEXT)
			for def in WEAPON_STATS:
				var prop = str(def["prop"])
				if prop == SPEED_PROP:
					_add_weapon_row(i, def)
				elif _has_property(ws, prop):
					_add_weapon_row(i, def)

			if _show_base and wstats != null:
				_section("  原始数值（改后对同类武器生效）", COL_SUB)
				for def2 in BASE_WEAPON_STATS:
					if _has_property(wstats, str(def2["prop"])):
						_add_base_weapon_row(i, def2)

	if _title != null:
		_title.text = "武器数值调整 | 玩家1 | %d 把武器" % wcount
	_refresh_summary()
	ModLoaderLog.info("面板构建完成：角色%d行 / 武器%d把 / 原始区%s" % [PLAYER_STATS.size(), wcount, ("开" if _show_base else "关")], LOG_NAME)


func _has_property(obj, prop: String) -> bool:
	if obj == null:
		return false
	for p in obj.get_property_list():
		if p.name == prop:
			return true
	return false


func _weapon_id_of(info: Dictionary) -> String:
	var scope = int(info.get("scope", -1))
	if scope != SCOPE_WEAPON and scope != SCOPE_BASE:
		return ""
	if _player == null or not is_instance_valid(_player):
		return ""
	var weapons = _player.get("current_weapons")
	if weapons == null:
		return ""
	var idx = int(info.get("widx", -1))
	if idx < 0 or idx >= weapons.size():
		return ""
	var weapon = weapons[idx]
	if not is_instance_valid(weapon):
		return ""
	return str(weapon.get("weapon_id"))


func _resolve_weapon(info: Dictionary):
	if _player == null or not is_instance_valid(_player):
		return null
	var scope = int(info.get("scope", -1))
	if scope != SCOPE_WEAPON and scope != SCOPE_BASE:
		return null
	var weapons = _player.get("current_weapons")
	if weapons == null:
		return null
	var idx = int(info.get("widx", -1))
	if idx < 0 or idx >= weapons.size():
		return null
	var weapon = weapons[idx]
	return weapon if is_instance_valid(weapon) else null


func _resolve_target(info: Dictionary):
	if _player == null or not is_instance_valid(_player):
		return null
	var scope = int(info["scope"])
	var prop = str(info["prop"])
	if scope == SCOPE_PLAYER:
		# 生命走 max_stats（上限），不碰 current_stats（实时血）
		if prop == "health":
			return _player.get("max_stats")
		return _player.get("current_stats")
	var weapon = _resolve_weapon(info)
	if weapon == null:
		return null
	if scope == SCOPE_BASE:
		return weapon.get("stats")
	# 攻击速度是派生值，没有真实属性，单独处理
	if prop == SPEED_PROP:
		return null
	return weapon.get("current_stats")


# ==================== 行控件 ====================

func _add_player_row(def: Dictionary) -> void:
	_add_row({
		"scope": SCOPE_PLAYER, "widx": -1,
		"prop": str(def["prop"]), "step": float(def["step"]),
		"int": bool(def["int"]), "label": "  " + str(def["label"]),
	})


func _add_weapon_row(widx: int, def: Dictionary) -> void:
	_add_row({
		"scope": SCOPE_WEAPON, "widx": widx,
		"prop": str(def["prop"]), "step": float(def["step"]),
		"int": bool(def["int"]), "label": "  " + str(def["label"]),
	})


func _add_base_weapon_row(widx: int, def: Dictionary) -> void:
	_add_row({
		"scope": SCOPE_BASE, "widx": widx,
		"prop": str(def["prop"]), "step": float(def["step"]),
		"int": bool(def["int"]), "label": "  " + str(def["label"]),
	})


func _add_row(info: Dictionary) -> void:
	var row := HBoxContainer.new()
	row.rect_min_size = Vector2(0, ROW_H)
	_content.add_child(row)

	var lbl := Label.new()
	lbl.text = info["label"]
	lbl.size_flags_horizontal = Label.SIZE_EXPAND_FILL
	lbl.rect_min_size = Vector2(160, 0)
	_style_label(lbl, COL_TEXT if int(info["scope"]) != SCOPE_BASE else COL_SUB)
	row.add_child(lbl)

	var minus := Button.new()
	minus.text = "-"
	minus.rect_min_size = Vector2(BTN_W, 24)
	_style_button(minus)
	row.add_child(minus)

	var edit := LineEdit.new()
	edit.rect_min_size = Vector2(EDIT_W, 24)
	_style_edit(edit)
	row.add_child(edit)

	var plus := Button.new()
	plus.text = "+"
	plus.rect_min_size = Vector2(BTN_W, 24)
	_style_button(plus)
	row.add_child(plus)

	info["edit"] = edit
	_rows.append(info)

	minus.connect("pressed", self, "_on_step", [info, -1.0])
	plus.connect("pressed", self, "_on_step", [info, 1.0])
	edit.connect("text_entered", self, "_on_text_entered", [info])
	edit.connect("focus_entered", self, "_on_edit_focus", [info])
	edit.connect("focus_exited", self, "_on_edit_unfocus", [info])

	_refresh_row(info)


func _on_edit_focus(info: Dictionary) -> void:
	_editing_info = info


func _on_edit_unfocus(info: Dictionary) -> void:
	if _editing_info == info:
		_editing_info = null
	var edit: LineEdit = info["edit"]
	if not is_instance_valid(edit):
		return
	var text = edit.text
	if text == null or str(text).strip_edges() == "":
		return
	var val = _clamp_value(info, float(text))
	var target = _resolve_target(info)
	if str(info["prop"]) == SPEED_PROP:
		var cur = _current_attack_speed(info)
		var ov = _override_value(info)
		if ov != null:
			cur = float(ov)
		if abs(cur - val) > 0.0001:
			_apply_value(info, val)
	elif target != null and abs(float(target.get(info["prop"])) - val) > 0.0001:
		_apply_value(info, val)


func _override_value(info: Dictionary):
	var scope = int(info["scope"])
	var prop = str(info["prop"])
	if scope == SCOPE_PLAYER:
		return _player_overrides.get(prop, null)
	var wid = _weapon_id_of(info)
	if wid == "":
		return null
	if scope == SCOPE_WEAPON:
		if _weapon_overrides.has(wid) and _weapon_overrides[wid].has(prop):
			return _weapon_overrides[wid][prop]
	else:
		if _weapon_base_overrides.has(wid) and _weapon_base_overrides[wid].has(prop):
			return _weapon_base_overrides[wid][prop]
	return null


func _base_cooldown_of(weapon) -> float:
	if weapon == null or not is_instance_valid(weapon):
		return 60.0
	var stats = weapon.get("stats")
	if stats != null and _has_property(stats, "cooldown"):
		var cd = float(stats.get("cooldown"))
		if cd > 0:
			return cd
	var cs = weapon.get("current_stats")
	if cs != null and _has_property(cs, "cooldown"):
		var cd2 = float(cs.get("cooldown"))
		if cd2 > 0:
			return cd2
	return 60.0


func _current_attack_speed(info: Dictionary) -> float:
	var weapon = _resolve_weapon(info)
	if weapon == null:
		return 1.0
	var base = _base_cooldown_of(weapon)
	var cs = weapon.get("current_stats")
	if cs == null or not _has_property(cs, "cooldown"):
		return 1.0
	var cd = float(cs.get("cooldown"))
	if base <= 0 or cd <= 0:
		return 1.0
	return clamp(base / cd, SPEED_MIN, SPEED_MAX)


func _refresh_row(info: Dictionary) -> void:
	if _editing_info == info:
		return
	var edit: LineEdit = info["edit"]
	if not is_instance_valid(edit):
		return
	var val = null
	if int(info["scope"]) == SCOPE_WEAPON and str(info["prop"]) == SPEED_PROP:
		var ov = _override_value(info)
		val = float(ov) if ov != null else _current_attack_speed(info)
	else:
		var target = _resolve_target(info)
		if target == null:
			return
		var ov2 = _override_value(info)
		val = float(ov2) if ov2 != null else float(target.get(str(info["prop"])))
	if val == null:
		return
	if info["int"]:
		edit.text = str(int(round(val)))
	else:
		edit.text = "%.2f" % val


func _clamp_value(info: Dictionary, val: float) -> float:
	var prop = str(info["prop"])
	if prop == SPEED_PROP:
		return clamp(val, SPEED_MIN, SPEED_MAX)
	if prop in ["accuracy", "crit_chance", "dodge", "knockback_piercing", "lifesteal", "projectile_spread"]:
		return clamp(val, 0.0, 1.0)
	if info["int"] and prop in ["cooldown", "damage", "health", "speed", "nb_projectiles"]:
		return max(1.0, val)
	return val


func _on_step(info: Dictionary, direction: float) -> void:
	var val: float = 0.0
	var ov = _override_value(info)
	if ov != null:
		val = float(ov)
	elif int(info["scope"]) == SCOPE_WEAPON and str(info["prop"]) == SPEED_PROP:
		val = _current_attack_speed(info)
	else:
		var target = _resolve_target(info)
		if target == null:
			return
		val = float(target.get(str(info["prop"])))
	var new_val = val + float(info["step"]) * direction
	if info["int"]:
		new_val = round(new_val)
	_apply_value(info, _clamp_value(info, new_val))


func _on_text_entered(text: String, info: Dictionary) -> void:
	if text == null or str(text).strip_edges() == "":
		return
	var val = float(text)
	if info["int"]:
		val = round(val)
	_apply_value(info, _clamp_value(info, val))


func _apply_value(info: Dictionary, new_val: float) -> void:
	var scope = int(info["scope"])
	var prop = str(info["prop"])
	if scope == SCOPE_PLAYER:
		_player_overrides[prop] = new_val
	else:
		var wid = _weapon_id_of(info)
		if wid == "":
			ModLoaderLog.info("警告：无法取得武器 ID，本次修改未存盘", LOG_NAME)
			return
		if scope == SCOPE_WEAPON:
			if not _weapon_overrides.has(wid):
				_weapon_overrides[wid] = {}
			_weapon_overrides[wid][prop] = new_val
		else:
			if not _weapon_base_overrides.has(wid):
				_weapon_base_overrides[wid] = {}
			_weapon_base_overrides[wid][prop] = new_val
	_apply_override_to(info, new_val)
	_save_overrides()
	if scope == SCOPE_BASE:
		# 原始数值变了，攻速/伤害摘要都要重算
		_reapply_all()
		_rebuild_rows()
	else:
		_refresh_row(info)
		_refresh_summary()


func _apply_attack_speed(weapon, speed: float, reset_now: bool) -> void:
	if weapon == null or not is_instance_valid(weapon):
		return
	var base = _base_cooldown_of(weapon)
	if base <= 0:
		return
	var cd := int(max(1.0, round(base / max(speed, 0.01))))
	var stats = weapon.get("current_stats")
	if stats != null and _has_property(stats, "cooldown"):
		stats.set("cooldown", cd)
	var every = weapon.get("_stats_every_x_shots")
	if every is Dictionary:
		for k in every:
			var s = every[k]
			if s != null and _has_property(s, "cooldown"):
				s.set("cooldown", cd)
	if reset_now:
		weapon.set("_current_cooldown", cd)


func _apply_override_to(info: Dictionary, new_val: float) -> void:
	if _player == null or not is_instance_valid(_player):
		return
	var prop = str(info["prop"])
	var scope = int(info["scope"])
	if scope == SCOPE_PLAYER:
		if prop == "health":
			var ms = _player.get("max_stats")
			if ms != null and _has_property(ms, prop):
				ms.set(prop, int(new_val))
			return
		var cs = _player.get("current_stats")
		if cs != null and _has_property(cs, prop):
			cs.set(prop, new_val)
		var ms2 = _player.get("max_stats")
		if ms2 != null and _has_property(ms2, prop):
			ms2.set(prop, new_val)
		return

	var weapon = _resolve_weapon(info)
	if weapon == null:
		return

	# 原始数值：直接改武器基础 Resource
	if scope == SCOPE_BASE:
		var base_stats = weapon.get("stats")
		if base_stats != null and _has_property(base_stats, prop):
			base_stats.set(prop, int(new_val) if info["int"] else new_val)
		return

	# 当前武器：攻击速度走派生换算
	if prop == SPEED_PROP:
		_apply_attack_speed(weapon, new_val, true)
		return

	var stats = weapon.get("current_stats")
	if stats != null and _has_property(stats, prop):
		stats.set(prop, new_val)
	var every = weapon.get("_stats_every_x_shots")
	if every is Dictionary:
		for k in every:
			var s = every[k]
			if s != null and _has_property(s, prop):
				s.set(prop, new_val)
	if prop == "damage" and stats != null:
		var hb = weapon.get_node_or_null("Sprite/Hitbox")
		if hb != null and hb.has_method("set_damage"):
			var args = Hitbox.HitboxArgs.new().set_from_weapon_stats(stats)
			hb.set_damage(new_val, args)


# ==================== 持续应用 / 摘要 ====================

func _reapply_all() -> void:
	if _player == null or not is_instance_valid(_player):
		return
	var cs = _player.get("current_stats")
	var ms = _player.get("max_stats")
	for prop in _player_overrides:
		var v = float(_player_overrides[prop])
		if prop == "health":
			if ms != null and _has_property(ms, prop) and int(ms.get(prop)) != int(v):
				ms.set(prop, int(v))
			continue
		if cs != null and _has_property(cs, prop) and abs(float(cs.get(prop)) - v) > 0.0001:
			cs.set(prop, v)
		if ms != null and _has_property(ms, prop) and abs(float(ms.get(prop)) - v) > 0.0001:
			ms.set(prop, v)

	var weapons = _player.get("current_weapons")
	if weapons == null:
		return
	for i in range(weapons.size()):
		var weapon = weapons[i]
		if not is_instance_valid(weapon):
			continue
		var wid = str(weapon.get("weapon_id"))

		# 原始数值：先盖回基础 Resource，攻速换算依赖它
		if _weapon_base_overrides.has(wid):
			var base_stats = weapon.get("stats")
			var base_ov = _weapon_base_overrides[wid]
			if base_stats != null:
				for bp in base_ov:
					var bv = float(base_ov[bp])
					if _has_property(base_stats, bp) and abs(float(base_stats.get(bp)) - bv) > 0.0001:
						base_stats.set(bp, int(bv) if str(bp) in ["cooldown", "damage", "min_range", "max_range", "knockback", "recoil", "nb_projectiles", "piercing", "bounce", "projectile_speed"] else bv)

		var ov = _weapon_overrides.get(wid, {})
		if not (ov is Dictionary):
			continue

		# 兼容 V13 老存档：旧的 cooldown 覆盖折算成攻速倍率
		if ov.has("_legacy_cooldown") and not ov.has(SPEED_PROP):
			var legacy_cd = float(ov["_legacy_cooldown"])
			var base_cd = _base_cooldown_of(weapon)
			if legacy_cd > 0 and base_cd > 0:
				ov[SPEED_PROP] = clamp(base_cd / legacy_cd, SPEED_MIN, SPEED_MAX)
				ov.erase("_legacy_cooldown")
				ov.erase("cooldown")
				_save_overrides()
				ModLoaderLog.info("已将旧存档的冷却数值折算为攻速倍率：%s" % wid, LOG_NAME)

		var stats = weapon.get("current_stats")
		var damage_changed := false
		for prop in ov:
			if prop == "_legacy_cooldown" or prop == "cooldown":
				continue
			var v = float(ov[prop])
			if prop == SPEED_PROP:
				_apply_attack_speed(weapon, v, false)
				continue
			var need = false
			if stats != null and _has_property(stats, prop) and abs(float(stats.get(prop)) - v) > 0.0001:
				stats.set(prop, v)
				need = true
			if prop == "damage" and need:
				damage_changed = true
			var every = weapon.get("_stats_every_x_shots")
			if every is Dictionary:
				for k in every:
					var s = every[k]
					if s != null and _has_property(s, prop) and abs(float(s.get(prop)) - v) > 0.0001:
						s.set(prop, v)
		if damage_changed and stats != null:
			var hb = weapon.get_node_or_null("Sprite/Hitbox")
			if hb != null and hb.has_method("set_damage"):
				var args = Hitbox.HitboxArgs.new().set_from_weapon_stats(stats)
				hb.set_damage(stats.damage, args)


func _refresh_summary() -> void:
	if _summary == null or not is_instance_valid(_summary):
		return
	var weapons = [] if _player == null or not is_instance_valid(_player) else _player.get("current_weapons")
	if weapons == null or weapons.size() == 0 or not is_instance_valid(weapons[0]):
		_summary.text = "攻速 x1.00    伤害 x1.00"
		return
	var weapon = weapons[0]
	var speed = _current_attack_speed({"scope": SCOPE_WEAPON, "widx": 0})
	var base_dmg := 0.0
	var cur_dmg := 0.0
	var base_stats = weapon.get("stats")
	var cs = weapon.get("current_stats")
	if base_stats != null and _has_property(base_stats, "damage"):
		base_dmg = float(base_stats.get("damage"))
	if cs != null and _has_property(cs, "damage"):
		cur_dmg = float(cs.get("damage"))
	var dmg_mult := 1.0
	if base_dmg > 0:
		dmg_mult = cur_dmg / base_dmg
	_summary.text = "攻速 x%.2f    伤害 x%.2f" % [speed, dmg_mult]


func reapply_after_recalc() -> void:
	_reapply_all()
	if _visible:
		for info in _rows:
			_refresh_row(info)
		_refresh_summary()


# ==================== 开关 / 跳波 / 帧循环 ====================

func show_panel() -> void:
	visible = true
	_visible = true
	var tree = get_tree()
	if tree != null and not tree.paused:
		tree.paused = true
		_pause_owned = true
	_rebuild_rows()
	ModLoaderLog.info("面板已打开：游戏暂停，关闭后数值生效", LOG_NAME)


func hide_panel() -> void:
	visible = false
	_visible = false
	if _pause_owned:
		var tree = get_tree()
		if tree != null and tree.paused:
			tree.paused = false
		_pause_owned = false
	ModLoaderLog.info("面板已关闭：游戏恢复", LOG_NAME)


func toggle_panel() -> void:
	if _visible:
		hide_panel()
	else:
		show_panel()


func _on_goto_wave() -> void:
	var run_data = get_node_or_null("/root/RunData")
	if run_data == null:
		ModLoaderLog.info("跳波失败：找不到 RunData 单例", LOG_NAME)
		return
	var target_wave: int = -1
	if _wave_edit != null and is_instance_valid(_wave_edit):
		var txt = str(_wave_edit.text).strip_edges()
		if txt != "" and txt.is_valid_integer():
			target_wave = int(txt)
	if target_wave < 1:
		if run_data.has_method("get_next_wave"):
			target_wave = int(run_data.call("get_next_wave"))
		else:
			target_wave = int(run_data.get("current_wave")) + 1

	if _pause_owned:
		var tree = get_tree()
		if tree != null and tree.paused:
			tree.paused = false
		_pause_owned = false
	_visible = false
	visible = false

	run_data.set("current_wave", target_wave)
	ModLoaderLog.info("跳波：current_wave 设为 %d" % target_wave, LOG_NAME)

	var tree2 = get_tree()
	if tree2 != null:
		if bool(run_data.get("wave_in_progress")):
			tree2.reload_current_scene()
			ModLoaderLog.info("跳波：战斗中，重载场景进入第 %d 波" % target_wave, LOG_NAME)
		else:
			var menu_data = get_node_or_null("/root/MenuData")
			var game_scene = menu_data.get("game_scene") if menu_data != null else null
			if game_scene != null:
				tree2.change_scene(game_scene)
				ModLoaderLog.info("跳波：切换场景进入第 %d 波" % target_wave, LOG_NAME)
			else:
				ModLoaderLog.info("跳波：current_wave 已设为 %d（下波生效）" % target_wave, LOG_NAME)


func tick(delta: float) -> void:
	if _player == null or not is_instance_valid(_player):
		return
	_reapply_all()
	if not _visible:
		return
	_check_timer += delta
	if _check_timer >= 0.2:
		_check_timer = 0.0
		var sig = _compute_weapon_sig()
		if sig != _weapon_sig:
			ModLoaderLog.info("检测到武器变化，自动重建面板", LOG_NAME)
			_rebuild_rows()
	_rebuild_timer += delta
	if _rebuild_timer >= 0.2:
		_rebuild_timer = 0.0
		for info in _rows:
			_refresh_row(info)
		_refresh_summary()
