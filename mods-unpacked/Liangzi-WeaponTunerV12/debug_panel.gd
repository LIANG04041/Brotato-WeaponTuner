extends Control
## 武器调试面板（V12：数值写入存档，跨局持续保存）
## 独立窗口，用鼠标点击 +/- 或直接输入数字，实时修改角色与当前持有武器的每一项数值。
##
## 核心机制：所有修改都记录到 override 字典，并应用到"当前活着"的对象上。
##   - 存档持久化：每次修改立即写入 user:// 存档文件（游戏存档同目录），
##     面板创建时读回。换局、死亡重开、重启游戏后自动恢复，不用反复改。
##     武器按 weapon_id（如 weapon_smg）存，不按槽位，避免不同局武器顺序不同串味。
##   - 打开面板自动暂停游戏、关闭面板恢复（UI 层设为暂停时仍处理，按钮可点，不会卡死）。
##   - 跨波不重置：hook 原版 update_player_stats()（每波/拾道具/升级都会调用），
##     在游戏用 RunData 重算完数值的同一时刻立即盖回 override，根治"下一波被冲掉"。
##   - 生命：只写 max_stats.health（生命上限），绝不写 current_stats.health（实时血），
##     实时血由游戏按新上限自然回满，不锁血。
##   - 武器：游戏每 N 发会临时替换 current_stats，升级/合成会换武器实例，
##     所以每帧按 weapon_id 重新解析当前武器并应用 override，改值不失效。
##   - 输入框聚焦时暂停自动刷新，避免打字被覆盖；回车或失焦立即应用，实时生效。

var _player = null

var _root: PanelContainer = null
var _scroll: ScrollContainer = null
var _content: VBoxContainer = null
var _title: Label = null

var _rows: Array = []
var _rebuild_timer: float = 0.0
var _check_timer: float = 0.0
var _visible: bool = true
var _weapon_sig: String = ""   # 当前武器实例签名，变化时重建

# 游戏自带字体（fallback 含简体中文字形），用于让面板中文正常显示
var _ui_font = null

const FONT_PATH := "res://resources/fonts/actual/base/font_22.tres"
const LOG_NAME := "Liangzi-WeaponTunerV12:Panel"
## 数值存档：user:// 对应 %APPDATA%/Brotato/（与游戏存档、mod 配置同目录）
const SAVE_PATH := "user://liangzi_weapon_tuner_save.json"

const ROW_H := 30
const BTN_W := 34
const EDIT_W := 90

# ============ 持久 override 层 ============
# 角色：{prop: value}；武器：{weapon_id: {prop: value}}（按武器 ID，跨局稳定）
var _player_overrides := {}
var _weapon_overrides := {}
# 正在编辑的行（聚焦的输入框），自动刷新时跳过它，避免覆盖用户输入
var _editing_info = null
# 暂停控制：记录本面板是否接管了暂停，避免误解除游戏自身的暂停
var _pause_owned: bool = false

# 角色 LiveStats 字段
const PLAYER_STATS := [
	{"prop": "health", "label": "生命上限", "step": 10, "int": true},
	{"prop": "damage", "label": "攻击力", "step": 1, "int": true},
	{"prop": "speed", "label": "移动速度", "step": 10, "int": true},
	{"prop": "armor", "label": "护甲", "step": 1, "int": true},
	{"prop": "dodge", "label": "闪避(0-1)", "step": 0.05, "int": false},
]

# 武器数值字段
const WEAPON_STATS := [
	{"prop": "damage", "label": "伤害", "step": 1, "int": true},
	{"prop": "cooldown", "label": "冷却(帧,越小越快)", "step": 1, "int": true},
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


func setup(player) -> void:
	_player = player
	_ui_font = load(FONT_PATH)
	if _ui_font == null:
		ModLoaderLog.info("警告：游戏字体加载失败，中文可能显示为方块", LOG_NAME)
	_load_overrides()
	_build_ui()


## 给控件统一设置中文字体
func _apply_font(control) -> void:
	if _ui_font != null and control != null:
		control.set("custom_fonts/font", _ui_font)


# ==================== 存档读写 ====================

## 从 user:// 存档读回 override。文件不存在/损坏时安全使用空值。
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
	ModLoaderLog.info("已从存档恢复数值：角色 %d 项 / 武器 %d 种（跨局保持）" % [_player_overrides.size(), _weapon_overrides.size()], LOG_NAME)


## 每次修改后立即写盘，保证换局/重启仍在。
func _save_overrides() -> void:
	var data := {"player": _player_overrides, "weapons": _weapon_overrides}
	var f := File.new()
	var err = f.open(SAVE_PATH, File.WRITE)
	if err != OK:
		ModLoaderLog.info("数值存档写入失败（%d）" % err, LOG_NAME)
		return
	f.store_string(JSON.print(data))
	f.close()


## 清档：清空 override 并删除存档，恢复游戏默认数值。
func _reset_saved() -> void:
	_player_overrides.clear()
	_weapon_overrides.clear()
	var dir := Directory.new()
	if dir.file_exists(SAVE_PATH):
		dir.remove(SAVE_PATH)
	ModLoaderLog.info("已清空数值存档，恢复游戏默认数值", LOG_NAME)
	_rebuild_rows()


func _build_ui() -> void:
	self.anchor_left = 1.0
	self.anchor_right = 1.0
	self.anchor_top = 0.0
	self.anchor_bottom = 0.0
	self.margin_left = -360.0
	self.margin_right = -12.0
	self.margin_top = 100.0
	self.margin_bottom = 700.0
	self.mouse_filter = Control.MOUSE_FILTER_STOP

	_root = PanelContainer.new()
	_root.name = "WTPanelRoot"
	_root.anchor_right = 1.0
	_root.anchor_bottom = 1.0
	_root.margin_left = 0
	_root.margin_top = 0
	_root.margin_right = 0
	_root.margin_bottom = 0
	add_child(_root)

	var vb := VBoxContainer.new()
	vb.anchor_right = 1.0
	vb.anchor_bottom = 1.0
	_root.add_child(vb)

	# 标题栏（含清档 / 关闭按钮）
	var header := HBoxContainer.new()
	vb.add_child(header)
	_title = Label.new()
	_title.text = "== 武器数值调试 =="
	_title.size_flags_horizontal = Label.SIZE_EXPAND_FILL
	_apply_font(_title)
	header.add_child(_title)

	var reset_btn := Button.new()
	reset_btn.text = "清档"
	reset_btn.rect_min_size = Vector2(40, 24)
	_apply_font(reset_btn)
	reset_btn.connect("pressed", self, "_reset_saved")
	header.add_child(reset_btn)

	var close_btn := Button.new()
	close_btn.text = "关闭"
	close_btn.rect_min_size = Vector2(44, 24)
	_apply_font(close_btn)
	close_btn.connect("pressed", self, "hide_panel")
	header.add_child(close_btn)

	_scroll = ScrollContainer.new()
	_scroll.size_flags_vertical = ScrollContainer.SIZE_EXPAND_FILL
	_scroll.anchor_right = 1.0
	_scroll.anchor_bottom = 1.0
	vb.add_child(_scroll)

	_content = VBoxContainer.new()
	_content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_scroll.add_child(_content)

	_rebuild_rows()


func _clear_rows() -> void:
	_rows.clear()
	_editing_info = null
	if _content == null:
		return
	for child in _content.get_children():
		child.queue_free()


## 计算当前武器实例签名：用每个武器节点的 instance ID + 武器 ID，任何武器替换/增减都会变化
func _compute_weapon_sig() -> String:
	if _player == null or not is_instance_valid(_player):
		return ""
	var weapons = _player.get("current_weapons")
	if weapons == null:
		return ""
	var parts := []
	for w in weapons:
		if is_instance_valid(w):
			var wid = str(w.get("weapon_id"))
			parts.append("%d:%s" % [w.get_instance_id(), wid])
		else:
			parts.append("null")
	var sig := ""
	for i in range(parts.size()):
		if i > 0:
			sig += "|"
		sig += parts[i]
	return sig


func _rebuild_rows() -> void:
	if _content == null or _player == null:
		return
	_clear_rows()
	_weapon_sig = _compute_weapon_sig()

	# ---- 角色区 ----
	var psec := Label.new()
	psec.text = "--- 角色（数值已存盘，跨局保持） ---"
	_apply_font(psec)
	_content.add_child(psec)

	var cs = _player.get("current_stats")
	if cs != null:
		for def in PLAYER_STATS:
			_add_player_row(def)

	# ---- 武器区 ----
	var weapons = _player.get("current_weapons")
	var wcount = weapons.size() if weapons != null else 0
	var wsec := Label.new()
	wsec.text = "--- 武器（%d，按武器种类存盘） ---" % wcount
	_apply_font(wsec)
	_content.add_child(wsec)

	if weapons != null:
		for i in range(weapons.size()):
			var weapon = weapons[i]
			if not is_instance_valid(weapon):
				continue
			var wlabel := Label.new()
			var wname := "武器"
			var wstats = weapon.get("stats")
			if wstats != null:
				var nm = wstats.get("name")
				if nm != null and str(nm) != "":
					wname = str(nm)
			wlabel.text = "[武器%d] %s" % [i + 1, wname]
			_apply_font(wlabel)
			_content.add_child(wlabel)

			var ws = weapon.get("current_stats")
			if ws == null:
				continue
			for def in WEAPON_STATS:
				var prop = def["prop"]
				if not _has_property(ws, prop):
					continue
				_add_weapon_row(i, def)

	if _title != null:
		_title.text = "== 武器调试 | 玩家1 | %d 把武器 ==" % wcount
	ModLoaderLog.info("面板构建完成：角色 %d 行，武器 %d 把；存档override 角色%d项/武器%d种" % [PLAYER_STATS.size(), wcount, _player_overrides.size(), _weapon_overrides.size()], LOG_NAME)


func _has_property(obj, prop: String) -> bool:
	if obj == null:
		return false
	for p in obj.get_property_list():
		if p.name == prop:
			return true
	return false


## 取某行对应武器的 weapon_id（跨局稳定的存档键）
func _weapon_id_of(info: Dictionary) -> String:
	if int(info.get("scope", -1)) != 1 or _player == null or not is_instance_valid(_player):
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


## 动态解析：根据行信息取到"当前活着"的目标对象。
func _resolve_target(info: Dictionary):
	if _player == null or not is_instance_valid(_player):
		return null
	if int(info["scope"]) == 0:
		# 生命走 max_stats（上限），不碰 current_stats（实时血）
		if str(info["prop"]) == "health":
			return _player.get("max_stats")
		return _player.get("current_stats")
	var weapons = _player.get("current_weapons")
	if weapons == null:
		return null
	var idx = int(info["widx"])
	if idx < 0 or idx >= weapons.size():
		return null
	var weapon = weapons[idx]
	if not is_instance_valid(weapon):
		return null
	return weapon.get("current_stats")


## 动态解析当前武器实例（武器行才有）
func _resolve_weapon(info: Dictionary):
	if _player == null or not is_instance_valid(_player) or int(info["scope"]) != 1:
		return null
	var weapons = _player.get("current_weapons")
	if weapons == null:
		return null
	var idx = int(info["widx"])
	if idx < 0 or idx >= weapons.size():
		return null
	var weapon = weapons[idx]
	return weapon if is_instance_valid(weapon) else null


func _add_player_row(def: Dictionary) -> void:
	var info = {
		"scope": 0,
		"widx": -1,
		"prop": str(def["prop"]),
		"step": float(def["step"]),
		"int": bool(def["int"]),
		"label": str(def["label"]),
	}
	_add_row(info)


func _add_weapon_row(widx: int, def: Dictionary) -> void:
	var info = {
		"scope": 1,
		"widx": widx,
		"prop": str(def["prop"]),
		"step": float(def["step"]),
		"int": bool(def["int"]),
		"label": "  " + str(def["label"]),
	}
	_add_row(info)


## 添加一行：[标签] [-] [数值输入框] [+]
func _add_row(info: Dictionary) -> void:
	var row := HBoxContainer.new()
	row.rect_min_size = Vector2(0, ROW_H)
	_content.add_child(row)

	var lbl := Label.new()
	lbl.text = info["label"]
	lbl.size_flags_horizontal = Label.SIZE_EXPAND_FILL
	lbl.rect_min_size = Vector2(130, 0)
	_apply_font(lbl)
	row.add_child(lbl)

	var minus := Button.new()
	minus.text = "-"
	minus.rect_min_size = Vector2(BTN_W, 24)
	_apply_font(minus)
	row.add_child(minus)

	var edit := LineEdit.new()
	edit.rect_min_size = Vector2(EDIT_W, 24)
	edit.align = 1 # ALIGN_CENTER
	_apply_font(edit)
	row.add_child(edit)

	var plus := Button.new()
	plus.text = "+"
	plus.rect_min_size = Vector2(BTN_W, 24)
	_apply_font(plus)
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
	var num = float(text)
	var target = _resolve_target(info)
	if target != null and abs(float(target.get(info["prop"])) - num) > 0.0001:
		_apply_value(info, num)


## 取某行当前应显示的 override 值（角色按 prop，武器按 weapon_id），无则 null
func _override_value(info: Dictionary):
	if int(info["scope"]) == 0:
		if _player_overrides.has(info["prop"]):
			return _player_overrides[info["prop"]]
		return null
	var wid = _weapon_id_of(info)
	if wid != "" and _weapon_overrides.has(wid) and _weapon_overrides[wid].has(info["prop"]):
		return _weapon_overrides[wid][info["prop"]]
	return null


func _refresh_row(info: Dictionary) -> void:
	# 正在编辑的行不刷新，避免覆盖用户输入
	if _editing_info == info:
		return
	var target = _resolve_target(info)
	if target == null:
		return
	var val = _override_value(info)
	if val == null:
		val = target.get(info["prop"])
	if val == null:
		return
	var edit: LineEdit = info["edit"]
	if not is_instance_valid(edit):
		return
	if info["int"]:
		edit.text = str(int(val))
	else:
		edit.text = "%.2f" % float(val)


func _on_step(info: Dictionary, direction: float) -> void:
	var target = _resolve_target(info)
	if target == null:
		return
	var val = float(target.get(info["prop"]))
	# 已有 override 时用 override 作为基准，避免游戏改回的值干扰连点
	var ov = _override_value(info)
	if ov != null:
		val = float(ov)
	var step = float(info["step"])
	var new_val = val + step * direction
	if info["int"]:
		new_val = round(new_val)
		new_val = max(1.0, new_val) if info["prop"] in ["damage", "cooldown", "health", "speed"] else new_val
	_apply_value(info, new_val)


func _on_text_entered(text: String, info: Dictionary) -> void:
	if text == null or str(text).strip_edges() == "":
		return
	var val = float(text)
	if info["int"]:
		val = round(val)
	_apply_value(info, val)


## 统一写值入口：记录 override（按 weapon_id）+ 立即应用 + 写盘存档
func _apply_value(info: Dictionary, new_val: float) -> void:
	if int(info["scope"]) == 0:
		_player_overrides[info["prop"]] = new_val
	else:
		var wid = _weapon_id_of(info)
		if wid == "":
			ModLoaderLog.info("警告：无法取得武器 ID，本次修改未存盘", LOG_NAME)
			return
		if not _weapon_overrides.has(wid):
			_weapon_overrides[wid] = {}
		_weapon_overrides[wid][info["prop"]] = new_val
	_apply_override_to(info, new_val)
	_refresh_row(info)
	_save_overrides()


## 把某个值应用到"当前活着"的目标对象（角色 current/max；武器 current+临时stats+hitbox+冷却）
func _apply_override_to(info: Dictionary, new_val: float) -> void:
	if _player == null or not is_instance_valid(_player):
		return
	var prop = str(info["prop"])
	if int(info["scope"]) == 0:
		# 生命上限：只写 max_stats，绝不写 current_stats（实时血交给游戏，不锁血）
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
	var stats = weapon.get("current_stats")
	if stats != null and _has_property(stats, prop):
		stats.set(prop, new_val)
	var every = weapon.get("_stats_every_x_shots")
	if every is Dictionary:
		for k in every:
			var s = every[k]
			if s != null and _has_property(s, prop):
				s.set(prop, new_val)
	if prop == "cooldown":
		weapon.set("_current_cooldown", new_val)
	if prop == "damage" and stats != null:
		var hb = weapon.get_node_or_null("Sprite/Hitbox")
		if hb != null and hb.has_method("set_damage"):
			var args = Hitbox.HitboxArgs.new().set_from_weapon_stats(stats)
			hb.set_damage(new_val, args)


## 每帧把所有 override 重新应用到当前活着的角色/武器。
## 武器按 weapon_id 匹配当前武器，无论槽位、跨局都正确。
func _reapply_all() -> void:
	if _player == null or not is_instance_valid(_player):
		return
	# 角色
	var cs = _player.get("current_stats")
	var ms = _player.get("max_stats")
	for prop in _player_overrides:
		var v = float(_player_overrides[prop])
		if prop == "health":
			if ms != null and _has_property(ms, prop):
				if int(ms.get(prop)) != int(v):
					ms.set(prop, int(v))
			continue
		if cs != null and _has_property(cs, prop):
			if abs(float(cs.get(prop)) - v) > 0.0001:
				cs.set(prop, v)
		if ms != null and _has_property(ms, prop):
			if abs(float(ms.get(prop)) - v) > 0.0001:
				ms.set(prop, v)
	# 武器：遍历当前武器，按 weapon_id 取存档 override
	var weapons = _player.get("current_weapons")
	if weapons == null:
		return
	for i in range(weapons.size()):
		var weapon = weapons[i]
		if not is_instance_valid(weapon):
			continue
		var wid = str(weapon.get("weapon_id"))
		if not _weapon_overrides.has(wid):
			continue
		var ov = _weapon_overrides[wid]
		var stats = weapon.get("current_stats")
		var damage_changed := false
		for prop in ov:
			var v = float(ov[prop])
			var need = false
			if stats != null and _has_property(stats, prop):
				if abs(float(stats.get(prop)) - v) > 0.0001:
					stats.set(prop, v)
					need = true
			if prop == "damage" and need:
				damage_changed = true
			var every = weapon.get("_stats_every_x_shots")
			if every is Dictionary:
				for k in every:
					var s = every[k]
					if s != null and _has_property(s, prop):
						if abs(float(s.get(prop)) - v) > 0.0001:
							s.set(prop, v)
		if damage_changed and stats != null:
			var hb = weapon.get_node_or_null("Sprite/Hitbox")
			if hb != null and hb.has_method("set_damage"):
				var args = Hitbox.HitboxArgs.new().set_from_weapon_stats(stats)
				hb.set_damage(stats.damage, args)


## 游戏调用 update_player_stats() 用 RunData 重算数值后，由 player 扩展立即调用本方法。
func reapply_after_recalc() -> void:
	_reapply_all()
	if _visible:
		for info in _rows:
			_refresh_row(info)


func show_panel() -> void:
	visible = true
	_visible = true
	var tree = get_tree()
	if tree != null and not tree.paused:
		tree.paused = true
		_pause_owned = true
	_rebuild_rows()
	ModLoaderLog.info("调试面板已打开：游戏已暂停，关闭后数值生效", LOG_NAME)


func hide_panel() -> void:
	visible = false
	_visible = false
	if _pause_owned:
		var tree = get_tree()
		if tree != null and tree.paused:
			tree.paused = false
		_pause_owned = false
	ModLoaderLog.info("调试面板已关闭：游戏已恢复", LOG_NAME)


func toggle_panel() -> void:
	if _visible:
		hide_panel()
	else:
		show_panel()


## 每帧：持续重新应用 override（即使面板隐藏也生效）+ 检测武器变化 + 刷新显示
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
