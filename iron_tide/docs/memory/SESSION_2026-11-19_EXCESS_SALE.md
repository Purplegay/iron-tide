# 一键售出多余人员（2026-11-19）

用户截图：第2关灰熊坦克超过跨关人数上限，希望一键售出多余人员。

已完成：
- scripts/expedition/run.gd 新增 excess_sale(run) 无副作用预览及 sell_excess_personnel() 原子提交。
- 先解除每个兵种人数上限，再解除本章总人数上限；只卖刚好超限部分；英雄不计入也不出售，复用 dismiss_before 优先普通/低军衔，保留特装/高军衔及现有遣散返还补给规则。
- 数量来源统一用Army.inventory，出售后折叠survivors、清空reinforcements、同步特装小队数与active_roster，一次commit；无多余时重复操作不发放补给。
- scripts/expedition/screen.gd 营地所有ready页签上方，仅有超额人数时显示「一键售出多余人员 · N 个 · 获得 X 补给」，点击直接完成，显示最近出售结果。军团说明同步更新。
- 本功能解决兵种人数/本章人口上限，不自动整队移除超额兵种种类（预备编制最多4种）或代选出战编制。

验证：tests/expedition_excess_sale_regression.gd 隔离用户目录13/13通过，exit=0 stderr空；涵盖6灰熊卖2、准确返还、预览不修改、英雄保护、特装保留、总人口、真实营地按钮及数量、一次提交、重复点击、磁盘重读。
测试临时目录 C:/Users/admin/AppData/Local/Temp/IronTideExcessSale-0353490961d84fa28fb356d36f7f8b11，verified.log及verified-error.log；按钮补测初次类型推断错误修正后复跑成功。未人工截图确认视觉，未打包提交推送。用户正式存档未直接操作，工作区其他修改保留。
