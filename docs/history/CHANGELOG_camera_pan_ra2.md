# CHANGELOG · 视角平移修复 + 右键拖拽平移（camera_pan_ra2）

本轮目标：
1. 修「鼠标拉到最底下平移视角有问题」。
2. 新增「**按住右键拖动即可平移视角**」的设定（另含中键）。

本轮的实现**直接对照红警2 逐帧逻辑还原**：源码取自
`https://github.com/huangkaoya/ts-redalert2`（TypeScript 版红警2），
关键三处：

| 红警2 源文件 | 作用 | 本轮吸收的结论 |
|---|---|---|
| `src/gui/screen/game/worldInteraction/CameraPanHandler.ts` | 拖拽平移 | 平移量 = 鼠标位移，**屏幕空间** |
| `src/gui/screen/game/worldInteraction/MapScrollHandler.ts` | 贴边滚屏 | 外沿 **3~4px** 触发；再按边两端 1/3（或 300px）叠加对角 |
| `src/gui/screen/game/worldInteraction/WorldInteraction.ts` | 鼠标分派 | **7px** 内算「单击」、超出算「拖拽」；MMB 恒为平移 |
| `src/engine/renderable/CameraPan.ts` | 平移坐标 | `pan.x/y` 直接叠加在**屏幕坐标**上 |

## 根因（为什么「拉最底下平移有问题」）
旧代码是**按世界轴**平移：
```gdscript
camera.position += dir.normalized() * speed   # dir 直接就是世界 x/y
```
但本工程相机是**等距 45° 旋转**的（`camera.rotation == Iso.cam_angle()`）。
世界轴 +y 在屏幕上其实是「右下 45°」。于是：
- **贴底边滚屏** → 世界 +y → 屏幕上看是斜着往右下走，而不是垂直向下；同理贴右边 → 斜着。
- 相机钳制又是 `clamp(position, 0, map_size)`，世界 +y 一旦顶到 `map_size`，
  **屏幕还没到底就先被卡死**（而屏幕上明明还有地图）——这正是「拉最底下平移有问题」的手感来源。

红警2 的平移坐标本来就是屏幕坐标（`computeCameraPanFromScreen`；`pan.x` 直接加进屏幕坐标），
所以「贴哪条边就往哪个屏幕方向滚」才是对的。

## 做法（`scripts/world/battle.gd`）
1. **平移改为屏幕空间**（核心修复）：
   ```gdscript
   ## 屏幕位移 -> 相机世界位移：先按各轴缩放反算，再按相机旋转回世界系
   func screen_pan_to_world(screen_delta: Vector2) -> Vector2:
       var z := camera.zoom
       return Vector2(screen_delta.x / maxf(0.001, z.x),
                      screen_delta.y / maxf(0.001, z.y)).rotated(camera.rotation)

   func pan_screen(screen_delta: Vector2) -> void:
       camera.position += screen_pan_to_world(screen_delta)
       clamp_camera_to_map()
   ```
   由此 **Δ屏幕 x 就是纯水平、Δ y 就是纯垂直**，不再斜走；
   `screen_pan_to_world((100,0))` 经冒烟实测让画面**恰好水平位移 −100px、垂直 0px**。
2. **贴边滚屏对齐红警2** `edge_pan_dir(mouse, vp)`：
   - 触发带 `_edge_margin` 由 24px 改为 **4px**（红警2 为 3~4px）——
     顺带解决「鼠标停在底部 HUD 上就误触发滚屏」。
   - 新增 `_edge_corner = 300`：贴住左右边时，靠上下 1/3（或 300px）**同时带动纵向对角**；贴上下边同理。四角因此能滚。
3. **相机钳制改为「取景框不许出地图」**（对齐红警2 `computeCameraPanLimits`）：
   `view_half_extent()` 算出旋转后取景框在世界轴上的半宽/半高，
   `clamp_camera_to_map()` 以此内缩钳制，**不再看到地图外**（缩放越大能界越远）。
   缩放到整图可见时自动锁定居中。
   `zoom_camera()` / `center_on()` / 5 个视角切换函数全部改为走这条钳制。
4. **新增右键拖拽平移**（红警2 `rightClickScroll` 语义）——本轮新「设定」：
   ```gdscript
   var right_click_scroll: bool = true   # 按住右键拖动 = 平移视角
   var right_click_move: bool = true     # 右键单击仍然下达移动/集火
   var edge_scroll_enabled: bool = true  # 鼠标贴边自动滚屏
   ```
   - 按下右键记录锚点；拖动超过 `_click_slop`(7px) 才判定为拖拽 → **抓取地图**（鼠标右移、视角左移）。
   - 未超过阈值就抬起 → 仍按**单击**处理（取消放置 → 取消指令模式 → 下达指令）。
   - **中键**同样可拖拽平移。
   - 用 `_input()` 而非 `_unhandled_input()` 接收，**拖拽经过 HUD 面板时不会断**。
   - 未开 `right_click_scroll` 时，右键回落到旧行为（按下即下令），不破坏既有操作。

## 冒烟（`ok=190 fail=0`，新增 10 项）
```
edge_pan_bottom / edge_pan_top_left_corner / edge_pan_center_none / edge_pan_bottom_diag_band
pan_screen_is_screen_aligned          # 屏幕位移 100px -> 画面恰好水平 -100px、垂直 0px
camera_clamped_view_inside_map        # 视图四边都在 [0, map_size] 内
rmb_scroll_arms_pan / rmb_drag_sets_moved / rmb_drag_pans_camera / rmb_release_disarms_pan
```
> 踩坑记录：无头模式下 `get_viewport_rect().size == (1600,1600)`；且 `Camera2D` 的
> 画布变换**不是同步刷新**的，直接改 `position` 后立刻读 `get_canvas_transform()` 拿到的是旧值，
> 必须先 `camera.force_update_scroll()`。

## 说明
- `right_click_scroll / right_click_move / edge_scroll_enabled` 目前是 `Battle` 上的公开开关
  （默认即红警2 默认），尚未接设置面板；如需做「设置界面」下一轮可接。
- 红警2 源码里 UI 是**用原版 SHP 贴图 + 调色板**画出来的（`public/` 只带 `general.csf` /
  `ini.mix` / 字体，**不含美术资源**），所以可吸收的是**排版逻辑/几何/交互规则**，美术仍需自制。
