extends "res://ui/menus/shop/stat_container.gd"
## WeaponTuner V15：让原生「属性-主要」面板每行数值可直接点击修改


func _ready() -> void:
	_wt15_hook_value()


func _wt15_hook_value() -> void:
	if _value == null or not is_instance_valid(_value):
		return
	_value.mouse_filter = Control.MOUSE_FILTER_PASS
	_value.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	if not _value.is_connected("gui_input", self, "_wt15_on_value_input"):
		_value.connect("gui_input", self, "_wt15_on_value_input")


func _wt15_on_value_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == BUTTON_LEFT and event.pressed:
		_wt15_open_editor()
		accept_event()


func _wt15_player_index() -> int:
	var pi = FocusEmulatorSignal.get_player_index(self)
	if pi is int and pi >= 0:
		return pi
	return 0


func _wt15_get_hub():
	var hub = get_node_or_null("/root/WT15Hub")
	if hub != null:
		return hub
	var store = get_node_or_null("/root/ModLoaderStore")
	if store != null:
		hub = store.get_node_or_null("WT15Hub")
		if hub != null:
			return hub
	var arr = get_tree().get_nodes_in_group("wt15_hub")
	if arr.size() > 0:
		return arr[0]
	return null


func _wt15_open_editor() -> void:
	var hub = _wt15_get_hub()
	if hub == null:
		ModLoaderLog.info("编辑中枢未就绪", "Liangzi-WeaponTunerV15:Stat")
		return
	var pi := _wt15_player_index()
	var cur: float = Utils.get_stat(key_hash, pi)
	var gain: float = RunData.get_stat_gain(key_hash, pi)
	var title: String = str(key)
	hub.open(key_hash, pi, title, cur, gain, self, true)
