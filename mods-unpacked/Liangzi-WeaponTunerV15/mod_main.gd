extends Node
## 武器数值调整 Mod V15 入口
## V15 新增：原生「属性」面板上点数值即可直接修改。

const MOD_DIR := "Liangzi-WeaponTunerV15"
const LOG_NAME := "Liangzi-WeaponTunerV15:Main"
const HUB_NAME := "WT15Hub"

var mod_dir_path := ""


func _init() -> void:
	mod_dir_path = ModLoaderMod.get_unpacked_dir().plus_file(MOD_DIR)
	install_script_extensions()


func install_script_extensions() -> void:
	# 玩家层：左下角【武器调整】按钮与完整数值面板
	ModLoaderMod.install_script_extension(mod_dir_path.plus_file("extensions/player.gd"))
	# 原生属性面板：主要页与次要页，数值可点击编辑
	ModLoaderMod.install_script_extension(mod_dir_path.plus_file("extensions/stat_container.gd"))
	ModLoaderMod.install_script_extension(mod_dir_path.plus_file("extensions/secondary_stat_container.gd"))


func _ready() -> void:
	_ensure_hub()
	ModLoaderLog.info("V15 已就绪：属性面板点数值直接改；左下角【武器调整】打开完整面板。", LOG_NAME)


func _ensure_hub() -> void:
	if get_tree() == null:
		return
	if get_node_or_null("/root/" + HUB_NAME) != null:
		return
	var hub_script = load(mod_dir_path.plus_file("editor_hub.gd"))
	if hub_script == null:
		ModLoaderLog.info("错误：编辑中枢脚本加载失败", LOG_NAME)
		return
	var hub = hub_script.new()
	hub.name = HUB_NAME
	get_tree().root.add_child(hub)
	ModLoaderLog.info("编辑中枢已创建", LOG_NAME)
