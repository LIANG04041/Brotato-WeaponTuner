extends Node
## 武器数值调整 Mod V14 入口
## 由 Godot Mod Loader 在启动阶段调用 _init()，安装脚本扩展。

const MOD_DIR := "Liangzi-WeaponTunerV14"
const LOG_NAME := "Liangzi-WeaponTunerV14:Main"

var mod_dir_path := ""


func _init() -> void:
	mod_dir_path = ModLoaderMod.get_unpacked_dir().plus_file(MOD_DIR)
	install_script_extensions()


func install_script_extensions() -> void:
	# 只扩展 player.gd，不扩展 weapon.gd 基类（其 .gdc 子类符号表脆弱）
	ModLoaderMod.install_script_extension(mod_dir_path.plus_file("extensions/player.gd"))


func _ready() -> void:
	ModLoaderLog.info("V14 已就绪：点击左下角【武器调整】按钮打开面板。", LOG_NAME)
