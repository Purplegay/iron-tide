# v0.25.63.1 · 英雄天赋状态文字分色

英雄天赋列表「已生效」改为绿色、「待解锁」改为灰色，等级与说明保持原色。覆盖英雄坦克战术中枢／重装生存和步兵战场生存。采用 UiKit.COL_OK 与 COL_DIM，未改等级条件、价格或存档。

说明控件改用自动高度 RichTextLabel，关闭内部滚动和鼠标拦截，保留页面滚动和自动换行。

## 验证

独立源码快照、隔离 APPDATA，Godot --headless + CREATE_NO_WINDOW，无可见测试窗口。服务、数据库、网络依赖为 none。

- hero_talent_cost_regression：245 项断言通过。
- tank_hero_regression：79 项断言通过。

合计 324 项，退出码均为 0，无脚本错误。费用测试包含主动制造保存失败的边界；两套脚手退出仍有 FontAdvanced／CanvasItem／ObjectDB 资源泄漏日志，本轮未处理或声称干净退出。

证据：C:/Users/admin/Temp/iron-talent-status-20261105-a/。已核对 hero_progression.gd 与验收快照一致。保留并行的 v0.25.63 及其它改动，未提交、推送或打包。

pending_user_visual_confirmation：实际配色、自动高度和换行仍待使用者确认。
