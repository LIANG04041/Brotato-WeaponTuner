extends "res://entities/units/player/player.gd"
## WeaponTuner V14 - 玩家扩展（唯一注入点）
## 在游戏内提供【武器调整】按钮与数值面板；不扩展 weapon.gd 基类。
## 注意：所有成员名统一加 wt14_ 前缀，避免与其他同挂 player.gd 的 Mod（含本 Mod 旧版本）冲突。

const WT14_PANEL_SCRIPT := "res://mods-unpacked/Liangzi-WeaponTunerV14/debug_panel.gd"

var wt14_panel = null
var wt14_toggle_btn: Button = null
var wt14_canvas: CanvasLayer = null
var wt14_recalc_logged: bool = false


func _ready() -> void:
	._ready()
	if player_index == 0:
		call_deferred("wt14_setup_ui")


func wt14_button_style() -> StyleBoxFlat:
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


func wt14_setup_ui() -> void:
	if not is_instance_valid(self) or not is_inside_tree():
		return

	# 重开局时清理旧 UI，并解除上一局可能残留的暂停
	var old = get_tree().root.get_node_or_null("WTuner14Canvas")
	if old != null:
		old.queue_free()
	if get_tree().paused:
		get_tree().paused = false

	wt14_canvas = CanvasLayer.new()
	wt14_canvas.name = "WTuner14Canvas"
	wt14_canvas.layer = 100
	# 暂停时 UI 层仍要处理输入，否则打开面板后无法点按钮关闭
	wt14_canvas.pause_mode = Node.PAUSE_MODE_PROCESS
	get_tree().root.add_child(wt14_canvas)

	# 左下角开关按钮（游戏同款黑底白字黄描边）
	wt14_toggle_btn = Button.new()
	wt14_toggle_btn.name = "WTuner14Toggle"
	wt14_toggle_btn.text = " 武器调整 "
	var wt_font = load("res://resources/fonts/actual/base/font_22.tres")
	if wt_font != null:
		wt14_toggle_btn.set("custom_fonts/font", wt_font)
	wt14_toggle_btn.set("custom_styles/normal", wt14_button_style())
	wt14_toggle_btn.set("custom_colors/font_color", Color(1, 1, 1, 1))
	wt14_toggle_btn.set("custom_colors/font_color_hover", Color(1, 0.86, 0.28, 1))
	wt14_toggle_btn.anchor_left = 0.0
	wt14_toggle_btn.anchor_right = 0.0
	wt14_toggle_btn.anchor_top = 1.0
	wt14_toggle_btn.anchor_bottom = 1.0
	wt14_toggle_btn.margin_left = 12.0
	wt14_toggle_btn.margin_right = 124.0
	wt14_toggle_btn.margin_top = -44.0
	wt14_toggle_btn.margin_bottom = -12.0
	wt14_toggle_btn.mouse_filter = Control.MOUSE_FILTER_STOP
	wt14_canvas.add_child(wt14_toggle_btn)

	var script = load(WT14_PANEL_SCRIPT)
	if script != null:
		wt14_panel = script.new()
		wt14_canvas.add_child(wt14_panel)
		if wt14_panel.has_method("setup"):
			wt14_panel.setup(self)
		wt14_panel.hide_panel()
		wt14_toggle_btn.connect("pressed", self, "wt14_on_toggle")
		ModLoaderLog.info("界面就绪：开关按钮与数值面板已创建", "Liangzi-WeaponTunerV14:Main")
	else:
		ModLoaderLog.info("错误：面板脚本加载失败", "Liangzi-WeaponTunerV14:Main")


func wt14_on_toggle() -> void:
	if wt14_panel != null and wt14_panel.has_method("toggle_panel"):
		wt14_panel.toggle_panel()


func _physics_process(delta: float) -> void:
	._physics_process(delta)
	if player_index != 0 or wt14_panel == null:
		return
	if wt14_panel.has_method("tick"):
		wt14_panel.tick(delta)


## 游戏每波/拾道具/升级都会重算数值，这里在其后立即盖回我们的修改
func update_player_stats(reset_current_health := false) -> void:
	.update_player_stats(reset_current_health)
	if player_index == 0 and wt14_panel != null and is_instance_valid(wt14_panel):
		if wt14_panel.has_method("reapply_after_recalc"):
			wt14_panel.reapply_after_recalc()
			if not wt14_recalc_logged:
				wt14_recalc_logged = true
				ModLoaderLog.info("跨波保护已激活", "Liangzi-WeaponTunerV14:Main")
