# CHANGELOG · RA3 铬合金 UI 皮肤（ra3_ui_skin）

本轮目标：把「看起来像通用深色科幻 HUD」的界面，改成红警3 的铬合金界面质感。

## 根因（为什么会「不够还原」）
原 UI 全部由 `StyleBoxFlat`（纯色填充 + 1px 细边 + 小圆角）堆出来，
`UiKit` 里虽然有一层 `ra_*` 的「RA3 风格」封装，但它只是换了一组配色，
**没有任何材质特征**：没有金属渐变、没有镜面高光、没有 45° 倒角、
没有阵营色饰条、没有角标。所以无论怎么调配色都只能是「扁平深色卡片」。

## 做法（新增 `scripts/ui/ra3_skin.gd`，`class_name Ra3Skin`）
程序化生成「铬合金」贴图（`Image` → `ImageTexture`），再用 `StyleBoxTexture` 九宫格铺贴：

1. **三段式金属渐变**（亮顶 → 中段平台 → 暗底）。
   > 关键坑：九宫格会把贴图「中段」拉伸，若用线性渐变，面板中段会被拉成一块死板平色
   > —— 这正是上一版材质仍然发平的原因。必须让中段是平台色。
2. **顶部镜面高光带** + 最顶部 1px 镜面亮线（`gloss`）。
3. **45° 倒角** `_carve()`：只对角部小三角区逐像素削 alpha，开销可忽略；
   配合 2× 超采样 + LANCZOS 降采样得到抗锯齿边缘。
4. **3D 边线** `_rim()`：上/左亮、下/右暗，斜边渐变，形成真实倒角。
5. **阵营色饰条**（盟军青 / 苏联红 / 帝国金）压在面板顶边内侧。
6. **可交互格** (`tile()`)：下沉暗槽 + 内阴影 + 亮顶边；`normal / hover / pressed / active / disabled`
   五态，悬停泛青蓝、按下整格染阵营色（`BaseButton` 的 `pressed` 槽天然对应开关钮激活态，
   所以生产页签选中时会自动点亮）。
7. **角标** (`bracket`)：在大面板左上角区画「内折角」，九宫格会自动镜像到四角 ——
   这是红警3 面板最显眼的标志性元素。
8. **字体**：`FontVariation` + `set_spacing(SPACING_GLYPH, 1)` + `variation_embolden`
   模拟红警3 的工业窄体大写（Godot 无字距属性，用 glyph spacing 实现），并给文字加深色投影。
9. **通用换肤器** `Ra3Skin.upgrade_tree(root, accent)`：
   遍历控件树，**读取控件当前生效的 `StyleBoxFlat`（保留各处刻意设置的配色意图）**，
   就地翻译成对应槽位的 RA3 贴图（`BaseButton` → `tile`；`Panel/PanelContainer` → `plate`/`inset`；
   `ProgressBar` → `bar`；`Label/Button` → 字体 + 投影）。
   → 因此**无需改动既有控件树结构**，也不会覆盖各面板的配色设计；可反复调用，幂等。

## 接入点
- `scripts/ui/hud.gd` `_apply_ra3()`：整树换肤一次 + 挂 0.4s `Timer` 做**增量换肤**
  （应对运行期重建的控件，如选中条、技能栏、生产页签）。
- `scripts/ui/hud.gd` `_apply_ra3()`：**战术地图从右下角移到左下角** ——
  红警3 的雷达/战术地图在指令栏最左侧，这是 RA3 与 RA2/星际最显著的排版差别之一。
  小地图外框同时改成「下沉暗槽 + 青边」（`Ra3Skin.inset_from`）。

## 验证
- 导入无 Parse / SCRIPT ERROR；`Ra3Skin` 已注册为全局类。
- 冒烟回归 **`SMOKE_SUMMARY ok=180 fail=0`**（含 `ra3_rail_present` / `ra3_kit_panel` /
  `ra3_kit_button` / `iso_*` 22 项投影不变量，全部保持通过）。
- 实拍重出：`iso_ui.png`(整界面) / `iso_selbar.png`(底部指令条) / `iso_build.png`(建造) /
  `iso_ability.png`(技能栏)；另出 3× 放大局部用于核对倒角/高光/角标。

## 待做（下一批）
- 排版层：把右栏的生产区改成红警3 的「底部指令甲板」（页签行 + 图标网格 + 资源/电力牌），
  选中部队信息卡置于甲板右端。
- 材质层：图标格加「建造进度扇形擦除」、受损面板黑化/冒烟、电力不足时整栏泛红。
- 各面板标题栏加红警3 式的斜切标题块（现在只是普通 Label）。
