extends "res://entities/units/player/player.gd"
## WeaponTuner - 玩家扩展（唯一注入点）
## 提供一个独立调试面板，用鼠标 +/- 或输入数字实时修改角色与当前持有武器的每一项数值。
## 不扩展 weapon.gd 基类，避免破坏其字节码子类的符号表。

const WT_PANEL_SCRIPT := "res://mods-unpacked/Liangzi-WeaponTunerV12/debug_panel.gd"

var _wt_panel = null
var _wt_toggle_btn: Button = null
var _wt_canvas: CanvasLayer = null
var _wt_tick: float = 0.0
var _wt_recalc_logged: bool = false   # 跨波保护诊断日志只输出一次


func _ready() -> void:
	._ready()
	if player_index == 0:
		call_deferred("_wt_setup_ui")


## 建立面板 + 一个左下角的开关按钮（纯鼠标操作，绕开键盘输入冲突）
func _wt_setup_ui() -> void:
	if not is_instance_valid(self) or not is_inside_tree():
		return

	# 重开局时清理旧 UI，避免残留多个按钮/面板
	# 同时解除上一局可能残留的暂停（比如面板开着时死亡/重开），防止新局卡在暂停
	var old = get_tree().root.get_node_or_null("WTunerCanvas")
	if old != null:
		old.queue_free()
	if get_tree().paused:
		get_tree().paused = false

	_wt_canvas = CanvasLayer.new()
	_wt_canvas.name = "WTunerCanvas"
	_wt_canvas.layer = 100
	# 关键：暂停时 UI 层仍要处理输入，否则打开面板暂停后按钮点不动、无法关闭
	_wt_canvas.pause_mode = Node.PAUSE_MODE_PROCESS
	get_tree().root.add_child(_wt_canvas)

	# 开关按钮（左下角）
	_wt_toggle_btn = Button.new()
	_wt_toggle_btn.name = "WTunerToggle"
	_wt_toggle_btn.text = " 武器调试 "
	# 应用游戏自带中文字体，避免中文显示为方块
	var wt_font = load("res://resources/fonts/actual/base/font_22.tres")
	if wt_font != null:
		_wt_toggle_btn.set("custom_fonts/font", wt_font)
	_wt_toggle_btn.anchor_left = 0.0
	_wt_toggle_btn.anchor_right = 0.0
	_wt_toggle_btn.anchor_top = 1.0
	_wt_toggle_btn.anchor_bottom = 1.0
	_wt_toggle_btn.margin_left = 12.0
	_wt_toggle_btn.margin_right = 120.0
	_wt_toggle_btn.margin_top = -42.0
	_wt_toggle_btn.margin_bottom = -12.0
	_wt_toggle_btn.mouse_filter = Control.MOUSE_FILTER_STOP
	_wt_canvas.add_child(_wt_toggle_btn)

	# 面板实例
	var script = load(WT_PANEL_SCRIPT)
	if script != null:
		_wt_panel = script.new()
		_wt_canvas.add_child(_wt_panel)
		if _wt_panel.has_method("setup"):
			_wt_panel.setup(self)
		_wt_panel.hide_panel()
		_wt_toggle_btn.connect("pressed", self, "_wt_on_toggle")
		ModLoaderLog.info("界面就绪：开关按钮与面板已创建", "Liangzi-WeaponTunerV12:Main")
	else:
		ModLoaderLog.info("错误：面板脚本加载失败", "Liangzi-WeaponTunerV12:Main")


func _wt_on_toggle() -> void:
	if _wt_panel != null and _wt_panel.has_method("toggle_panel"):
		_wt_panel.toggle_panel()


# ---------------- 帧循环（hook 原版存在的 _physics_process） ----------------

func _physics_process(delta: float) -> void:
	._physics_process(delta)
	if player_index != 0 or _wt_panel == null:
		return
	# 每帧传真实 delta，由面板内部按 0.2 秒自主节流（武器变化检测 + 数值刷新）
	if _wt_panel.has_method("tick"):
		_wt_panel.tick(delta)


# ---------------- 根治跨波重置：hook 游戏自己的数值重算 ----------------
## 游戏在每波开始、拾取道具、升级时都会调用 update_player_stats，
## 它会用 RunData 的数据重算 max_stats 并覆盖 current_stats。
## 我们在这个函数执行完之后立刻把 override 盖回去，
## 保证"本回合改的数值到下一波不被重置"。
func update_player_stats(reset_current_health := false) -> void:
	.update_player_stats(reset_current_health)
	if player_index == 0 and _wt_panel != null and is_instance_valid(_wt_panel):
		if _wt_panel.has_method("reapply_after_recalc"):
			_wt_panel.reapply_after_recalc()
			if not _wt_recalc_logged:
				_wt_recalc_logged = true
				ModLoaderLog.info("跨波保护已激活：游戏重算数值后会自动盖回你的修改", "Liangzi-WeaponTunerV12:Main")
