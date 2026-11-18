extends "res://entities/units/player/player.gd"
## WeaponTuner V15 - 玩家扩展
## 提供【武器调整】按钮与完整数值面板；不扩展 weapon.gd 基类。
## 所有成员统一加 wt15_ 前缀，避免与其他同挂 player.gd 的 Mod（含旧版本）冲突。

const WT15_PANEL_SCRIPT := "res://mods-unpacked/Liangzi-WeaponTunerV15/debug_panel.gd"

var wt15_panel = null
var wt15_toggle_btn: Button = null
var wt15_canvas: CanvasLayer = null
var wt15_recalc_logged: bool = false


func _ready() -> void:
	._ready()
	if player_index == 0:
		wt15_register_to_hub()
		call_deferred("wt15_setup_ui")


func wt15_register_to_hub() -> void:
	var hub = get_node_or_null("/root/WT15Hub")
	if hub == null:
		var store = get_node_or_null("/root/ModLoaderStore")
		if store != null:
			hub = store.get_node_or_null("WT15Hub")
	if hub == null:
		var arr = get_tree().get_nodes_in_group("wt15_hub")
		if arr.size() > 0:
			hub = arr[0]
	if hub != null:
		hub.player = self


func wt15_button_style() -> StyleBoxFlat:
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


func wt15_setup_ui() -> void:
	if not is_instance_valid(self) or not is_inside_tree():
		return

	# 重开局时清理旧 UI，并解除上一局可能残留的暂停
	var old = get_tree().root.get_node_or_null("WTuner15Canvas")
	if old != null:
		old.queue_free()
	if get_tree().paused:
		get_tree().paused = false

	wt15_canvas = CanvasLayer.new()
	wt15_canvas.name = "WTuner15Canvas"
	wt15_canvas.layer = 100
	# 暂停时 UI 层仍要处理输入，否则打开面板后无法点按钮关闭
	wt15_canvas.pause_mode = Node.PAUSE_MODE_PROCESS
	get_tree().root.add_child(wt15_canvas)

	# 左下角开关按钮（游戏同款黑底白字黄描边）
	wt15_toggle_btn = Button.new()
	wt15_toggle_btn.name = "WTuner15Toggle"
	wt15_toggle_btn.text = " 武器调整 "
	var wt_font = load("res://resources/fonts/actual/base/font_22.tres")
	if wt_font != null:
		wt15_toggle_btn.set("custom_fonts/font", wt_font)
	wt15_toggle_btn.set("custom_styles/normal", wt15_button_style())
	wt15_toggle_btn.set("custom_colors/font_color", Color(1, 1, 1, 1))
	wt15_toggle_btn.set("custom_colors/font_color_hover", Color(1, 0.86, 0.28, 1))
	wt15_toggle_btn.anchor_left = 0.0
	wt15_toggle_btn.anchor_right = 0.0
	wt15_toggle_btn.anchor_top = 1.0
	wt15_toggle_btn.anchor_bottom = 1.0
	wt15_toggle_btn.margin_left = 12.0
	wt15_toggle_btn.margin_right = 124.0
	wt15_toggle_btn.margin_top = -44.0
	wt15_toggle_btn.margin_bottom = -12.0
	wt15_toggle_btn.mouse_filter = Control.MOUSE_FILTER_STOP
	wt15_canvas.add_child(wt15_toggle_btn)

	var script = load(WT15_PANEL_SCRIPT)
	if script != null:
		wt15_panel = script.new()
		wt15_canvas.add_child(wt15_panel)
		if wt15_panel.has_method("setup"):
			wt15_panel.setup(self)
		wt15_panel.hide_panel()
		wt15_toggle_btn.connect("pressed", self, "wt15_on_toggle")
		ModLoaderLog.info("界面就绪：开关按钮与数值面板已创建", "Liangzi-WeaponTunerV15:Main")
	else:
		ModLoaderLog.info("错误：面板脚本加载失败", "Liangzi-WeaponTunerV15:Main")


func wt15_on_toggle() -> void:
	if wt15_panel != null and wt15_panel.has_method("toggle_panel"):
		wt15_panel.toggle_panel()


func _physics_process(delta: float) -> void:
	._physics_process(delta)
	if player_index != 0 or wt15_panel == null:
		return
	if wt15_panel.has_method("tick"):
		wt15_panel.tick(delta)


## 游戏每波/拾道具/升级都会重算数值，这里在其后立即盖回我们的修改
func update_player_stats(reset_current_health := false) -> void:
	.update_player_stats(reset_current_health)
	if player_index == 0 and wt15_panel != null and is_instance_valid(wt15_panel):
		if wt15_panel.has_method("reapply_after_recalc"):
			wt15_panel.reapply_after_recalc()
			if not wt15_recalc_logged:
				wt15_recalc_logged = true
				ModLoaderLog.info("跨波保护已激活", "Liangzi-WeaponTunerV15:Main")
