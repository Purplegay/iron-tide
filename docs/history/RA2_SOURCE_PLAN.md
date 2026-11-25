# 红警2 源码（ts-redalert2）吸收计划

来源：`https://github.com/huangkaoya/ts-redalert2`（TypeScript 版红警2，Vite + ECS）
本地克隆：`%TEMP%\ts-ra2`（本会话临时；重取：`git clone --depth 1 <url>`）
规模：`src/**` 约 **1271** 个 `.ts/.tsx`。

## 一、一个必须先说清的结论
**红警2 的 UI 不是 CSS 画的，是用原版 SHP 贴图 + 调色板逐像素贴出来的。**
仓库 `public/` 只带了这些：

```
general.csf / ra2md.csf     文本（含所有 UI 文案 key，如 tip:team01）
ini.mix / ra2cd.mix         规则/INI 打包（非美术）
fonts/*                     RA2 位图字体
locale.json
```

`SidebarTabs.ts` 就是直接 `getSprite("ra2:sidebar...")` + `aggregatedSprite`，
美术数据来自**用户本机安装的红警2**（该项目的 README 也要求自行提供游戏资源）。
→ **能吸收的是「排版逻辑 / 几何数值 / 交互规则 / 文案 key」，美术资源拿不到**（法律上也拿不到）。
所以「UI 直接用」= 用它的**结构与数值**来驱动我们自己的 `Ra3Skin` 程序化皮肤，而不是照搬贴图。

## 二、可直接吸收的模块清单（按性价比排序）

### 1. 局内交互（已吸收，见 `CHANGELOG_camera_pan_ra2.md`）
`src/gui/screen/game/worldInteraction/`
- `CameraPanHandler.ts` — 拖拽平移（已吸收）
- `MapScrollHandler.ts` — 贴边滚屏：4px 带 + 1/3 角部扩展（已吸收）
- `WorldInteraction.ts` — 事件分派：**7px 单击/拖拽判定**、MMB 恒平移（已吸收）
- `ArrowScrollHandler.ts`、`UnitSelectionHandler.ts`、`CommandBarHandler`、
  `DefaultActionHandler.ts`、`MapHoverHandler.ts`、`PlacementMode`、`Tooltip`、`Messages`
- `keyboard/KeyBinds.ts` — **完整热键表**（下一轮可逐条对齐：Tab=切换标签、Q/W/E…）
- `MapPanningHelper.ts` — 平移↔地图坐标/边界换算（我们已用 `view_half_extent` 等价实现）

### 2. HUD 侧栏与指令甲板（**下一批主力**）
`src/gui/screen/game/component/hud/`
- `SidebarCard.ts` (22KB) — 建造图标网格：**2 列**，水平间距 **3px**、垂直 **2px**，
  含「建造进度扇形擦除」「选中/悬停/不可用」「电力不足变红」等状态机
- `SidebarTabs.ts` (3.1KB) — **4 个页签**（`Tip:Tab1..4`），每页签 4 帧状态：
  `0=常态 / 1=选中 / 2=禁用 / 3=闪烁`，**闪烁周期 250ms**；tab 间距 `tabSpacing`
- `SidebarPower.ts` / `SidebarCredits.ts` — 电力、资金数字牌
- `SidebarRadar.ts` + `Minimap.tsx` (21KB) — 雷达小地图（含拖拽视角、框选、雷达事件）
- `CommandBar/` — `CommandBarButtonType.ts` 列全了按钮：
  `Separator / BugReport / Beacon / Cheer / Deploy / Guard / PlanningMode / Stop /
  Team01..03 / TypeSelect`；`commandButtonConfigs.ts` 给出图标与 tooltip key
- `SuperWeaponTimers.ts` — 超武倒计时（我们 `ability` 栏可对齐）
- `Hud.ts` (29KB) — 总装配
→ 这份正是之前待拍板的「**红警3 底部指令甲板**」重构所需的权威排版来源。

### 3. 其它（按需）
- 选择/编队、寻路与流场、单位指令：`src/engine/...`、`src/game/...`
- 抽卡相关无（红警2 没有），我们的抽卡系统继续自研
- INI 与数值：`ini.mix`/`ra2cd.mix` 的 INI 解析（可作我们数值编辑器的参考）

## 三、建议的推进顺序
1. **已完成**：视角平移（贴边/拖拽/中键/钳制）← 本轮
2. **下一批**：`KeyBinds.ts` 热键对齐 + `SidebarCard/Tabs` 排版落地
   （把生产区从右栏挪到底部甲板：页签行 + 图标网格；资源/电力牌在左、选中信息卡在甲板右端）
3. **再下**：`CommandBar` 按钮集对齐（Deploy/Guard/Stop/Team01-03/TypeSelect）+ 超武倒计时样式
4. 小地图（雷达）交互对齐 `Minimap.tsx`：右键点地面移动视角、拖拽框选

> 注意：我们已有 `Ra3Skin` 程序化铬合金皮肤（`scripts/ui/ra3_skin.gd`），
> 吸收红警2 时**排版与交互用红警2、材质仍用 Ra3Skin**，避免退回到「纯色扁平卡片」。
