# v0.25.61 · 技能成长卡片快速装配

单位改造上方适用技能卡成长表新增独立的快速装配行，主动卡装入 W、被动卡装入被动槽，旁边显示当前技能。已装配时按钮标明并灰置；未拥有或不适用时不可点击。保留原有演示、培养及底部装配入口。

调用 MetaProgress.set_unit_skill 的原有兼容性、所有权及保存回滚逻辑。切换只替换相应槽位，卡牌所有权不变，不消耗货币。保存事件同步刷新上下入口，并通过原有滚动书签保留当前兵种、页面和滚动位置。

quick_equip_regression 的 18 项无窗口检查通过，覆盖未拥有拒绝、W／被动独立装配、替换、建筑卡、错误兵种拒绝、读档保留及滚动位置。隔离 Windows 桌面截图核对按钮位置、已装配状态和成长表，无弹窗。退出仍有既有 Texture／FontAdvanced／CanvasItem／ObjectDB 释放警告，无脚本错误。

本机证据：C:/Users/admin/Temp/irontide-tank-heroes-20261105-133253/quick-equip-final 和 quick-equip-visual。此次未打包或推送。
