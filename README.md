# Brotato 武器数值调试面板 Mod（WeaponTuner）

一个用于《土豆兄弟 / Brotato》的游戏内调试面板 Mod。通过左下角按钮打开一个**全中文面板**，用鼠标 `+ / -` 或输入数字，即可实时修改角色和当前持有武器的每一项数值，还能一键跳到指定波数。

> 基于 Godot Mod Loader 6.x，支持 Godot 3 版游戏。当前版本：**V13**。

## 下载

**最新版本 V13**：[Liangzi-WeaponTunerV13.zip](https://github.com/LIANG04041/Brotato-WeaponTuner/releases/download/v13.0/Liangzi-WeaponTunerV13.zip)

也可到 [Releases 页面](https://github.com/LIANG04041/Brotato-WeaponTuner/releases) 查看全部版本。

## 功能特性

- **全中文界面**：字段、按钮、日志均为中文，使用游戏自带中文字体，无乱码方块。
- **角色数值**：生命上限、攻击力、移动速度、护甲、闪避（生命只改上限，不锁实时血）。
- **武器数值**：伤害、冷却（攻速）、命中、暴击率、暴击伤害、射程、击退、吸血、弹丸数、穿透、弹射、弹速、散布等——按每把武器实际拥有的字段自动列出。
- **自选波数跳转**：面板顶部输入波数即可跳到该波，留空跳下一波（V13 新增）。
- **数值写入存档**：每次修改立即存到 `%APPDATA%/Brotato/liangzi_weapon_tuner_save.json`，换局、重开、重启游戏后自动保持，不用反复改。面板【清档】按钮可恢复默认。
- **跨波不重置**：hook 游戏自身的 `update_player_stats()`，每波/拾取道具/升级重算数值后立即盖回你的修改。
- **打开自动暂停**：打开面板游戏自动暂停，可从容调整；关闭后恢复、修改生效。
- **武器升级自动跟随**：升级/合成会换新武器实例，面板按 `weapon_id` 动态匹配，改值不失效。

> 关于攻速：游戏内 **冷却（Cooldown）越小 = 射速越快**。把冷却调小即加攻速。

## 安装与使用

### 前置条件

- 游戏为《土豆兄弟》0.8 及以上版本。游戏**已内置** Mod Loader，玩家**不需要另外下载安装** Godot Mod Loader。
- 开启 Mod 支持：Steam 库中右键《土豆兄弟》→ 属性 → 通用 → 启动选项，填入 `--enable-mods`。

### 安装

1. 下载 [Liangzi-WeaponTunerV13.zip](https://github.com/LIANG04041/Brotato-WeaponTuner/releases/download/v13.0/Liangzi-WeaponTunerV13.zip)。
2. 把 zip **原样放入**游戏的 Mod 加载目录（Steam 创意工坊 Mod 的 content 目录，或 Mod Loader 的 mods 目录），**不要解压**。
3. 启动游戏，在主菜单的 **Mod** 菜单里找到本 Mod 并勾选启用；个别情况需重启游戏才生效。
4. 建议启用前备份存档：复制 `%APPDATA%/Brotato` 文件夹。

### 怎么用

1. **进入一局游戏**——主菜单没有玩家实例，面板只在对局内出现。
2. 点屏幕**左下角的【武器调试】按钮**打开面板；打开时游戏会**自动暂停**，方便从容调整。
3. 在面板里改数值：
   - **角色**：生命上限、攻击力、移动速度、护甲、闪避；
   - **武器**：伤害、冷却（**冷却越小 = 射速越快**）、命中、暴击、射程等，按当前武器实际拥有的字段自动列出；
   - 点每行 **`+` / `-`** 按步长增减，或点数字输入框**直接输入数字后按回车**。
4. **跳波**：在面板上方【跳到第几波】输入框填波数（如 `15`），点【跳转】立即进入该波；留空点【跳转】则进入下一波。
5. 点【关闭】或再点一次左下角按钮，游戏**恢复运行，修改随即生效**。
6. 修改会**自动存档**：换局、死亡重开、重启游戏后都保持，不用反复改。想恢复游戏默认数值，点标题栏的【清档】按钮（同时会删除存档文件）。

## 从源码打包

仓库中 `mods-unpacked/Liangzi-WeaponTunerV13/` 是 Mod 源码。打包时把该目录压缩为 zip，**zip 内保留 `mods-unpacked/Liangzi-WeaponTunerV13/` 这一层路径**：

```bash
python -c "
import zipfile, os
src = 'mods-unpacked/Liangzi-WeaponTunerV13'
with zipfile.ZipFile('Liangzi-WeaponTunerV13.zip','w',zipfile.ZIP_DEFLATED) as z:
    for root, _, files in os.walk(src):
        for f in files:
            p = os.path.join(root, f)
            z.write(p, p.replace(os.sep,'/'))
"
```

## 文件结构

```
mods-unpacked/Liangzi-WeaponTunerV13/
├── manifest.json          # Mod 元数据
├── mod_main.gd            # 入口：安装 script extension
├── debug_panel.gd         # 调试面板（存档层、override 应用层、跳波）
└── extensions/
    └── player.gd          # 唯一注入点：创建 UI + hook 数值重算
releases/
└── Liangzi-WeaponTunerV13.zip   # 可直接安装的打包文件
```

## 卸载

在游戏 Mod 菜单中禁用，或删除对应的 zip，并删除数值存档 `%APPDATA%/Brotato/liangzi_weapon_tuner_save.json`。

## 技术说明

- 唯一注入点是 `player.gd`，由它创建 `CanvasLayer` + 左下角开关按钮 + 右侧面板。
- 刻意**不扩展 `weapon.gd`**：它是大量 `.gdc` 字节码子类的基类，源码扩展会破坏子类符号表（实测导致连枷等武器加载失败）。
- 数值通过 `get(prop)/set(prop,value)` 通用读写 `current_stats`，覆盖所有字段而无需逐项写死。
- 跳波复用游戏自带调试菜单的做法：设置 `RunData.current_wave`，战斗中 `reload_current_scene()`、非战斗时 `change_scene(MenuData.game_scene)`；留空时用游戏 `get_next_wave()` 取下一波。跳转前解除面板接管的暂停，避免暂停态下场景不刷新。
- 改武器伤害后用原版同款方式同步 hitbox：`Hitbox.HitboxArgs.new().set_from_weapon_stats(stats)` 再 `hb.set_damage(...)`。
- 存档读写用 Godot 3 的 `JSON.parse` / `JSON.print` + `user://` 路径，与游戏自身实现一致。

## 许可

仅供个人学习与游戏调试使用。
