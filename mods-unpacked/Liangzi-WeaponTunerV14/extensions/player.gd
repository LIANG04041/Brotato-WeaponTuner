extends "res://entities/units/player/player.gd"
## WeaponTuner V14 - 玩家扩展（唯一注入点）
## 在游戏内提供【武器调整】按钮与数值面板；不扩展 weapon.gd 基类。

const WT_PANEL_SCRIPT := "res://mods-unpacked/Liangzi-WeaponTunerV14/debug_panel.gd"

var _wt_panel = null
var _wt_toggle_btn: Button = null
var _wt_canvas: CanvasLayer = null
var _wt_recalc_logged: bool = false


func _ready() -> void:
	._ready()
	if player_index == 0:
		call_deferred("_wt_setup_ui")


func _wt_button_style() -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.02, 0.02, 0.03, 0.94)
	sb.border_color = Color(1.0, 0.86, 0.28, 0.75)
	sb.set("border_width_left", 1)
	sb.set("border_width_right", 1)
	sb.set("border_width_top", 1)
	sb.set("border_width_bottom", 1)
	sb.set("corner_radius_top_left", 3)
	sb.set("corner_radius_top_right", 3)
	sb.set("corner_radius_bottom_left", 3)
	sb.set("corner_radius_bottom_right", 3)
	return sb


func _wt_setup_ui() -> void:
	if not is_instance_valid(self) or not is_inside_tree():
		return

	# 重开局时清理旧 UI，并解除上一局可能残留的暂停
	var old = get_tree().root.get_node_or_null("WTunerCanvas")
	if old != null:
		old.queue_free()
	if get_tree().paused:
		get_tree().paused = false

	_wt_canvas = CanvasLayer.new()
	_wt_canvas.name = "WTunerCanvas"
	_wt_canvas.layer = 100
	# 暂停时 UI 层仍要处理输入，否则打开面板后无法点按钮关闭
	_wt_canvas.pause_mode = Node.PAUSE_MODE_PROCESS
	get_tree().root.add_child(_wt_canvas)

	# 左下角开关按钮（游戏同款黑底白字黄描边）
	_wt_toggle_btn = Button.new()
	_wt_toggle_btn.name = "WTunerToggle"
	_wt_toggle_btn.text = " 武器调整 "
	var wt_font = load("res://resources/fonts/actual/base/font_22.tres")
	if wt_font != null:
		_wt_toggle_btn.set("custom_fonts/font", wt_font)
	_wt_toggle_btn.set("custom_styles/normal", _wt_button_style())
	_wt_toggle_btn.set("custom_colors/font_color", Color(1, 1, 1, 1))
	_wt_toggle_btn.set("custom_colors/font_color_hover", Color(1, 0.86, 0.28, 1))
	_wt_toggle_btn.anchor_left = 0.0
	_wt_toggle_btn.anchor_right = 0.0
	_wt_toggle_btn.anchor_top = 1.0
	_wt_toggle_btn.anchor_bottom = 1.0
	_wt_toggle_btn.margin_left = 12.0
	_wt_toggle_btn.margin_right = 124.0
	_wt_toggle_btn.margin_top = -44.0
	_wt_toggle_btn.margin_bottom = -12.0
	_wt_toggle_btn.mouse_filter = Control.MOUSE_FILTER_STOP
	_wt_canvas.add_child(_wt_toggle_btn)

	var script = load(WT_PANEL_SCRIPT)
	if script != null:
		_wt_panel = script.new()
		_wt_canvas.add_child(_wt_panel)
		if _wt_panel.has_method("setup"):
			_wt_panel.setup(self)
		_wt_panel.hide_panel()
		_wt_toggle_btn.connect("pressed", self, "_wt_on_toggle")
		ModLoaderLog.info("界面就绪：开关按钮与数值面板已创建", "Liangzi-WeaponTunerV14:Main")
	else:
		ModLoaderLog.info("错误：面板脚本加载失败", "Liangzi-WeaponTunerV14:Main")


func _wt_on_toggle() -> void:
	if _wt_panel != null and _wt_panel.has_method("toggle_panel"):
		_wt_panel.toggle_panel()


func _physics_process(delta: float) -> void:
	._physics_process(delta)
	if player_index != 0 or _wt_panel == null:
		return
	if _wt_panel.has_method("tick"):
		_wt_panel.tick(delta)


## 游戏每波/拾道具/升级都会重算数值，这里在其后立即盖回我们的修改
func update_player_stats(reset_current_health := false) -> void:
	.update_player_stats(reset_current_health)
	if player_index == 0 and _wt_panel != null and is_instance_valid(_wt_panel):
		if _wt_panel.has_method("reapply_after_recalc"):
			_wt_panel.reapply_after_recalc()
			if not _wt_recalc_logged:
				_wt_recalc_logged = true
				ModLoaderLog.info("跨波保护已激活", "Liangzi-WeaponTunerV14:Main")
