# v0.25.72 · 单位改造直达涂装工房

- 改造详情的单位皮肤／涂装下增加「转入涂装」，打开当前兵种，不受上次工房浏览分类和兵种影响。
- 自动选择 RA3／尤复分类；若“仅看有专属外观”会隐藏该单位则取消筛选。超时空等不在普通生产目录的有效兵种也可由改造页直达。
- 工房沿用皮肤、挂件、武器特效的购买、解锁、预览、装配与保存规则。打开入口不会替用户购买或选择涂装。
- 从改造进入显示「返回单位改造」，回到原单位、原页签和滚动位置，更新皮肤选择与模型。主菜单直接进入仍返回主菜单。
- 工房浏览记忆保留；返回改造时重新读取共享偏好，避免旧页面覆盖工房刚保存的选择。

## 验证

- refit_paint_link_regression：32 项通过，覆盖 RA3 收割者、尤复美国大兵、超时空突击队的直达、分类、装配、返回、滚动与重复点击。
- paint_bookmarks_regression：12 项通过。
- refit_skin_regression：146 项通过，包括存档写失败的回滚路径。

共 190 项断言通过，全部使用隔离存档、headless / CREATE_NO_WINDOW，不弹测试窗口。没有进行图形验收；皮肤回归中的写失败告警为主动注入，退出时仍有已有 Texture / Font / CanvasItem / ObjectDB 释放告警。未修改玩家存档，未提交、推送或打包。

证据：C:/Users/admin/Temp/irontide-tank-heroes-20261105-133253/refit-paint-link/、paint-link-existing-memory/、paint-link-existing-skins/。
