extends Node
## 武器调试入口脚本
## 由 Godot Mod Loader 在启动阶段调用 _init()，安装脚本扩展。

const MOD_DIR := "Liangzi-WeaponTunerV12"
const LOG_NAME := "Liangzi-WeaponTunerV12:Main"

var mod_dir_path := ""


func _init() -> void:
	mod_dir_path = ModLoaderMod.get_unpacked_dir().plus_file(MOD_DIR)
	install_script_extensions()


func install_script_extensions() -> void:
	# 只扩展 player.gd：在其层面遍历持有武器并修改属性。
	# 不扩展 weapon.gd —— 它是大量 .gdc 字节码子类的基类，用源码扩展会破坏子类符号表。
	ModLoaderMod.install_script_extension(mod_dir_path.plus_file("extensions/player.gd"))


func _ready() -> void:
	ModLoaderLog.info("武器调试已就绪：点击左下角【武器调试】按钮打开面板。", LOG_NAME)
