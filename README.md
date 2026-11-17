# Brotato 武器数值调试面板 Mod（WeaponTuner）

一个用于《土豆兄弟 / Brotato》的游戏内调试面板 Mod。通过左下角按钮打开一个**全中文面板**，用鼠标 `+ / -` 或输入数字，即可实时修改角色和当前持有武器的每一项数值。

> 基于 Godot Mod Loader 6.x，支持 Godot 3 版游戏。当前版本：**V12**。

## 功能特性

- **全中文界面**：字段、按钮、日志均为中文，使用游戏自带中文字体，无乱码方块。
- **角色数值**：生命上限、攻击力、移动速度、护甲、闪避（生命只改上限，不锁实时血）。
- **武器数值**：伤害、冷却（攻速）、命中、暴击率、暴击伤害、射程、击退、吸血、弹丸数、穿透、弹射、弹速、散布等——按每把武器实际拥有的字段自动列出。
- **数值写入存档**：每次修改立即存到 `%APPDATA%/Brotato/liangzi_weapon_tuner_save.json`，换局、重开、重启游戏后自动保持，不用反复改。面板【清档】按钮可恢复默认。
- **跨波不重置**：hook 游戏自身的 `update_player_stats()`，每波/拾取道具/升级重算数值后立即盖回你的修改。
- **打开自动暂停**：打开面板游戏自动暂停，可从容调整；关闭后恢复、修改生效。
- **武器升级自动跟随**：升级/合成会换新武器实例，面板按 `weapon_id` 动态匹配，改值不失效。

> 关于攻速：游戏内 **冷却（Cooldown）越小 = 射速越快**。把冷却调小即加攻速。

## 安装

1. 安装 [Godot Mod Loader](https://github.com/GodotModding/godot-mod-loader)（需对应 Brotato 的版本）。
2. Steam 库中右键《土豆兄弟》→ 属性 → 启动选项，填入 `--enable-mods`。
3. 从 [Releases](../../releases) 下载 `Liangzi-WeaponTunerV12.zip`，放到 Mod Loader 的 mods 目录（或游戏社区的创意工坊加载目录），在游戏 Mod 菜单中启用。
4. 进入一局游戏（主菜单没有 player 实例，面板只在对局内出现），点左下角【武器调试】按钮即可。

## 从源码打包

仓库中 `mods-unpacked/Liangzi-WeaponTunerV12/` 是 Mod 源码。打包时把该目录压缩为 zip，**zip 内保留 `mods-unpacked/Liangzi-WeaponTunerV12/` 这一层路径**：

```bash
python -c "
import zipfile, os
src = 'mods-unpacked/Liangzi-WeaponTunerV12'
with zipfile.ZipFile('Liangzi-WeaponTunerV12.zip','w',zipfile.ZIP_DEFLATED) as z:
    for root, _, files in os.walk(src):
        for f in files:
            p = os.path.join(root, f)
            z.write(p, p.replace(os.sep,'/'))
"
```

## 文件结构

```
mods-unpacked/Liangzi-WeaponTunerV12/
├── manifest.json          # Mod 元数据
├── mod_main.gd            # 入口：安装 script extension
├── debug_panel.gd         # 调试面板（存档层、override 应用层）
└── extensions/
    └── player.gd          # 唯一注入点：创建 UI + hook 数值重算
releases/
└── Liangzi-WeaponTunerV12.zip   # 可直接安装的打包文件
```

## 卸载

在游戏 Mod 菜单中禁用，或删除对应的 zip，并删除数值存档 `%APPDATA%/Brotato/liangzi_weapon_tuner_save.json`。

## 技术说明

- 唯一注入点是 `player.gd`，由它创建 `CanvasLayer` + 左下角开关按钮 + 右侧面板。
- 刻意**不扩展 `weapon.gd`**：它是大量 `.gdc` 字节码子类的基类，源码扩展会破坏子类符号表（实测导致连枷等武器加载失败）。
- 数值通过 `get(prop)/set(prop,value)` 通用读写 `current_stats`，覆盖所有字段而无需逐项写死。
- 改武器伤害后用原版同款方式同步 hitbox：`Hitbox.HitboxArgs.new().set_from_weapon_stats(stats)` 再 `hb.set_damage(...)`。
- 存档读写用 Godot 3 的 `JSON.parse` / `JSON.print` + `user://` 路径，与游戏自身实现一致。

## 许可

仅供个人学习与游戏调试使用。
