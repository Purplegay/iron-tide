# v0.25.46.2 · 卡牌演示入口动态计数

卡池演示按钮不再写死“四组”“八张”。数量直接读取演示窗口使用的 `FactionCardGallery.IDS`，当前为 **13 张**；以后增删演示卡时，入口随界面重建自动更新。文案改为“技能卡演示 · 查看 13 张卡的 0～3 级演示”。

统计的是可演示卡牌，不是整个卡池的 18 张，也不受玩家已收集数量影响。未改抽卡概率、卡牌效果或玩家存档。

验证：复用现有 academy 回归，headless／CREATE_NO_WINDOW 隔离运行 746 项通过，包含真实养成界面创建；没有脚本错误。本次不新增测试。演示列表核对为 13 项，目标源码与测试副本一致。测试套件退出时仍有原有字体／CanvasItem／ObjectDB 资源释放警告。日志：`C:\Users\admin\Temp\iron-v025462-20261105\academy\console.log`。

未弹出测试窗口；界面观感 `pending_user_visual_confirmation`。
