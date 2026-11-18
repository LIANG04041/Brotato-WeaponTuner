# Brotato 武器数值调整面板 Mod（WeaponTuner）

《土豆兄弟 / Brotato》游戏内数值调整面板。左下角按钮打开**全中文、游戏同款风格**的面板，用鼠标 `+ / -` 或输入数字，实时修改角色和当前武器数值，还能修改武器**原始数值**、一键跳波。

> 基于游戏内置 Godot Mod Loader 6.x。当前版本：**V14**。

## 下载

**最新版本 V14**：[Liangzi-WeaponTunerV14.zip](https://github.com/LIANG04041/Brotato-WeaponTuner/releases/download/v14.0/Liangzi-WeaponTunerV14.zip)

全部版本见 [Releases 页面](https://github.com/LIANG04041/Brotato-WeaponTuner/releases)。

## V14 新变化

1. **攻击速度改为倍率语义**：面板里显示的是「攻击速度」，`1` 倍为原速，`2` 倍快一倍，最大 `500` 倍，按一次 `+ / -` 改 `1` 倍。游戏内部使用的冷却帧会自动换算（`冷却 = 原始冷却 ÷ 攻速倍率`），不用再理解“冷却越小越快”。
2. **新增「原始数值」区**：可修改武器基础属性（原始冷却、原始伤害、原始暴击、原始弹丸数等），改完对同类武器生效，并随存档跨局保持。点面板上的【原始数值：显示/隐藏】按钮切换。
3. **UI 换成游戏同款**：半透明黑底、白色文字、米黄强调色、黑底描边按钮，与《土豆兄弟》菜单风格一致。标题下方还会显示当前武器的**攻速与伤害倍率摘要**。

## 功能特性

- **全中文界面**：字段、按钮、日志均为中文，使用游戏自带中文字体。
- **角色数值**：生命上限、攻击力、移动速度、护甲、闪避（生命只改上限，不锁实时血）。
- **武器当前数值**：攻击速度（倍率）、伤害、命中、暴击率、暴击伤害、射程、击退、吸血、弹丸数、穿透、弹射、弹速、散布等，按武器实际字段自动列出。
- **武器原始数值**：直接改武器基础 Resource，影响后续重新初始化/同类武器。
- **自选波数跳转**：面板顶部输入波数即可跳到该波，留空跳下一波。
- **自动存档**：修改立即写入 `%APPDATA%/Brotato/liangzi_weapon_tuner_save.json`，换局、重开、重启游戏后保持。【清档】恢复默认。
- **跨波不重置**：hook 游戏自身的 `update_player_stats()`，每波/拾道具/升级重算后立即盖回修改。
- **打开自动暂停**：打开面板暂停游戏，关闭后恢复、修改生效。
- **武器升级自动跟随**：升级/合成换新实例时按 `weapon_id` 动态匹配，改值不失效。
- **兼容 V13 存档**：旧存档里的“冷却”覆盖会自动折算成新的攻速倍率。

## 安装与使用

### 前置条件

- 游戏为《土豆兄弟》0.8 及以上版本。游戏**已内置** Mod Loader，玩家**不需要另外下载安装** Godot Mod Loader。
- 开启 Mod 支持：Steam 库中右键《土豆兄弟》→ 属性 → 通用 → 启动选项，填入 `--enable-mods`。

### 安装

1. 下载 [Liangzi-WeaponTunerV14.zip](https://github.com/LIANG04041/Brotato-WeaponTuner/releases/download/v14.0/Liangzi-WeaponTunerV14.zip)。
2. 把 zip **原样放入**游戏的 Mod 加载目录（Steam 创意工坊 Mod 的 content 目录，或 Mod Loader mods 目录），**不要解压**。
3. 启动游戏，在主菜单 **Mod** 菜单里启用本 Mod；个别情况需重启游戏。
4. 建议启用前备份存档：复制 `%APPDATA%/Brotato` 文件夹。

### 怎么用

1. **进入一局游戏**——主菜单没有玩家实例，面板只在对局内出现。
2. 点**左下角【武器调整】按钮**打开面板，游戏会自动暂停。
3. 调整数值：
   - **角色**：生命上限、攻击力、移动速度、护甲、闪避；
   - **武器当前数值**：`攻击速度(越大越快)` 填 `2` 即两倍速，`1` 为原速；其它字段照常改；
   - **原始数值**：点【原始数值：显示】展开，改原始冷却/原始伤害等；
   - 点每行 `+ / -` 按步长增减，或点输入框直接输入数字后回车。
4. **跳波**：顶部【跳到第几波】填波数（如 `15`）点【跳转】；留空则进入下一波。
5. 点【关闭】或再点左下角按钮，游戏恢复、修改生效。
6. 修改会自动存档，不用反复改；点【清档】可恢复默认。

## 从源码打包

仓库中 `mods-unpacked/Liangzi-WeaponTunerV14/` 是 Mod 源码。zip 内必须保留 `mods-unpacked/Liangzi-WeaponTunerV14/` 这一层路径：

```bash
python -c "
import zipfile, os
src = 'mods-unpacked/Liangzi-WeaponTunerV14'
with zipfile.ZipFile('Liangzi-WeaponTunerV14.zip','w',zipfile.ZIP_DEFLATED) as z:
    for root, _, files in os.walk(src):
        for f in files:
            p = os.path.join(root, f)
            z.write(p, p.replace(os.sep,'/'))
"
```

## 文件结构

```
mods-unpacked/Liangzi-WeaponTunerV14/
├── manifest.json          # Mod 元数据
├── mod_main.gd            # 入口：安装 script extension
├── debug_panel.gd         # 面板：UI、override、原始数值、存档、跳波
└── extensions/
    └── player.gd          # 唯一注入点：创建 UI + hook 数值重算
releases/
└── Liangzi-WeaponTunerV14.zip   # 可直接安装的打包文件
```

## 卸载

在游戏 Mod 菜单中禁用，或删除对应 zip，并删除数值存档 `%APPDATA%/Brotato/liangzi_weapon_tuner_save.json`。

## 技术说明

- 唯一注入点是 `player.gd`；刻意不扩展 `weapon.gd`（其 `.gdc` 字节码子类符号表脆弱）。
- 攻击速度是派生值：不改游戏字段语义，只把倍率换算成 `current_stats.cooldown`，因此与游戏自身的 `attack_speed_mod`、`additional_cooldown_multiplier` 等机制共存。
- 原始数值直接写 `weapon.stats`（Resource），游戏 `init_stats()` 时会基于它重新生成 `current_stats`。
- 跳波复用游戏自带调试菜单做法：`RunData.current_wave` + `reload_current_scene()` / `change_scene(MenuData.game_scene)`。
- 存档用 Godot 3 的 `JSON.parse` / `JSON.print` + `user://` 路径；V14 增加 `base_weapons` 段保存原始数值。

## 许可

仅供个人学习与游戏调试使用。
