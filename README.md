# Brotato 数值调整 Mod（WeaponTuner）

《土豆兄弟 / Brotato》游戏内数值调整 Mod，提供两条互不干扰的修改路径：

- **改属性面板**：打开游戏自带的【属性】面板，鼠标点任意一行的数值，弹出的输入框里直接填新数字。
- **改武器**：点左下角【武器调整】按钮（游戏自动暂停），在面板里改角色数值、当前武器数值、武器原始数值，还能跳到指定波数。

> 基于游戏内置 Godot Mod Loader。当前版本：**V15**。

## 下载

**最新版本 V15**：[Liangzi-WeaponTunerV15.zip](https://github.com/LIANG04041/Brotato-WeaponTuner/releases/download/v15.0/Liangzi-WeaponTunerV15.zip)

全部版本见 [Releases 页面](https://github.com/LIANG04041/Brotato-WeaponTuner/releases)。

## 这版改了什么

1. **属性面板可以直接改数值了**：不用再开独立窗口，就在游戏原本的【属性】界面里点数字。
2. **修掉了一个「点了没反应」的 bug**：弹窗中枢原来挂在 `/root` 下，进对局换场景时被销毁，所以点击只会在日志里留一句「编辑中枢未就绪」。现在改挂到 ModLoader 的常驻单例下，换场景不丢。
3. 左下角【武器调整】完整面板与 V14 完全一致：攻速倍率、原始数值、游戏同款 UI、跨局存档、跳波全部保留。

## 功能一：直接改属性面板

在游戏自带的【属性】面板里原地改数值，改的是游戏自己的属性数据，所以立即生效、面板同步刷新。

- **主要页**：最大生命值、%伤害、%攻击速度、护甲、闪避、暴击率、%暴击伤害、攻击速度、幸运…
- **次要页**：生命再生、%生命窃取、近战/远程/元素伤害、工程学、范围、幸运、收获…

操作步骤：

1. 进入一局游戏，按游戏原本的方式打开【属性】面板。
2. 切到【主要】或【次要】页。
3. 把鼠标移到某一行**右侧的数值**上，光标会变成手型。
4. **左键点一下**，弹出「修改：XXX」窗口，里面已填好当前值。
5. 输入新数字，按 **回车** 或点【确定】。
6. 数字立刻变成你填的值，属性即时生效。弹窗打开期间游戏暂停，确认或取消后自动恢复。

> 说明：道具、临时效果等加成仍会继续叠加，改完后再吃加成会在新数值基础上变化。想改回原值，再点一次输入原数字即可。

## 功能二：直接改武器（左下角完整面板）

点屏幕**左下角【武器调整】按钮**打开，游戏自动暂停，纯鼠标操作。

**角色数值**：生命上限、攻击力、移动速度、护甲、闪避。生命只改上限，不会锁住实时血量。

**武器当前数值**：伤害、命中、暴击率、暴击伤害、射程、击退、吸血、弹丸数、穿透、弹射、弹速、散布等，按武器实际拥有的字段自动列出。

**攻击速度是倍率语义**：面板上写「攻击速度(越大越快)」，`1` 为原速、`2` 为两倍速、`10` 为十倍速，最高 `500`，每点一次 `+ / -` 改 `1`。内部自动换算成游戏冷却：`冷却 = 原始冷却 ÷ 倍率`。

**武器原始数值**：点【原始数值：显示】展开，可改原始冷却、原始伤害、原始暴击、原始弹丸数等基础属性。改这里影响的是武器底子，对同类武器与后续重新初始化都生效。

**其它操作**：

- 每行都能用 `+ / -` 按步长增减，也能直接点输入框打字回车。
- 顶部【跳到第几波】填波数（如 `15`）点【跳转】；留空则进入下一波。
- 点【关闭】或再点左下角按钮，游戏恢复、修改生效。
- 修改会自动存入 `%APPDATA%/Brotato/liangzi_weapon_tuner_save.json`，换局、重开、重启游戏后保持；点【清档】恢复默认。

## 安装

### 前置条件

- 游戏为《土豆兄弟》0.8 及以上版本。游戏**已内置** Mod Loader，**不需要**另外下载 Godot Mod Loader。
- 开启 Mod 支持：Steam 库右键《土豆兄弟》→ 属性 → 通用 → 启动选项，填入 `--enable-mods`。

### 安装步骤

1. 下载 [Liangzi-WeaponTunerV15.zip](https://github.com/LIANG04041/Brotato-WeaponTuner/releases/download/v15.0/Liangzi-WeaponTunerV15.zip)。
2. 把 zip **原样放入**游戏的 Mod 加载目录（Steam 创意工坊 Mod 的 content 目录，或 Mod Loader 的 mods 目录），**不要解压**。
3. 启动游戏，在主菜单 **Mod** 菜单里启用本 Mod；个别情况需重启游戏。
4. **同一个 Mod 只保留一个版本**：装过 V13/V14 的，请把旧 zip 移出加载目录，否则新旧版本会同时挂载、互相冲突（典型表现是点击无反应或面板重复）。
5. 建议启用前备份存档：复制 `%APPDATA%/Brotato` 文件夹。

## 常见问题

**点了数值没反应？**
V15 之前的版本有这个 bug，已修复。确认你装的是 V15 且旧版本 zip 已移出加载目录；再看 `%APPDATA%/Brotato/logs/modloader.log` 里有没有 `编辑中枢已创建：/root/ModLoaderStore/WT15Hub`。

**攻速填了没变快？**
攻速是倍率，填 `1` 就是原速。想变快填大于 1 的数，例如 `3`。

**改了下一波又变回去？**
完整面板的修改会 hook 游戏每波重算属性的函数并盖回，正常不会回滚。如果仍然回滚，确认没同时启用旧版本。

**面板文字是方块？**
本 Mod 使用游戏自带中文字体。若出现方块，说明游戏语言资源缺失，切一次语言再切回中文即可。

## 从源码打包

仓库中 `mods-unpacked/Liangzi-WeaponTunerV15/` 是 Mod 源码。zip 内必须保留 `mods-unpacked/Liangzi-WeaponTunerV15/` 这一层路径：

```bash
python -c "
import zipfile, os
src = 'mods-unpacked/Liangzi-WeaponTunerV15'
with zipfile.ZipFile('Liangzi-WeaponTunerV15.zip','w',zipfile.ZIP_DEFLATED) as z:
    for root, _, files in os.walk(src):
        for f in files:
            p = os.path.join(root, f)
            z.write(p, p.replace(os.sep,'/'))
"
```

## 文件结构

```
mods-unpacked/Liangzi-WeaponTunerV15/
├── manifest.json                     # Mod 元数据
├── mod_main.gd                       # 入口：安装 3 个 script extension + 创建编辑中枢
├── editor_hub.gd                     # 属性修改弹窗：写 effects、清缓存、刷新面板
├── debug_panel.gd                    # 完整面板：UI、override、原始数值、存档、跳波
└── extensions/
    ├── player.gd                     # 左下角按钮与完整面板 + hook 数值重算
    ├── stat_container.gd             # 「属性-主要」每行数值可点击
    └── secondary_stat_container.gd   # 「属性-次要」每行数值可点击
releases/
└── Liangzi-WeaponTunerV15.zip        # 可直接安装的打包文件
```

## 卸载

在游戏 Mod 菜单中禁用，或删除对应 zip，并删除数值存档 `%APPDATA%/Brotato/liangzi_weapon_tuner_save.json`。

## 技术说明

- 属性面板数值来源是 `RunData.get_player_stat` → `players_data[idx].effects[key_hash] * gain`。V15 直接写 `effects`，再 `Utils.reset_stat_caches()` 清缓存、调用 `player.update_player_stats()` 重算，最后刷新 `StatsContainer`。
- 编辑中枢挂在 `/root/ModLoaderStore/WT15Hub`（ModLoader 常驻单例下），并对 `wt15_hub` 组做兜底查找，避免换场景丢节点。
- 完整面板只注入 `player.gd`，刻意不扩展 `weapon.gd`（其 `.gdc` 字节码子类符号表脆弱，扩展会导致 `flail.gdc` 报未声明成员）。
- 攻速是派生值：不改游戏字段语义，只把倍率换算成 `current_stats.cooldown`。
- 跳波复用游戏自带调试菜单做法：`RunData.current_wave` + `reload_current_scene()` / `change_scene(MenuData.game_scene)`。
- 新增成员统一带 `wt15_` 前缀，`CanvasLayer` 命名 `WTuner15Canvas` / `WT15EditorLayer`，避免与其它同挂 `player.gd` 的 Mod 撞名。

## 许可

仅供个人学习与游戏调试使用。
