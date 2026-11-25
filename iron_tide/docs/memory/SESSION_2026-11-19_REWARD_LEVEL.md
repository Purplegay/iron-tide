# 奖励Buff等级显示修复

用户截图高效引擎奖励缺少等级。根因：screen.gd::build_shop已有buff等级提示，但公共card()仅trait_buff显示层数，buff奖励没有当前/获得后等级。

修改scripts/expedition/screen.gd::card()，kind=buff时增加“当前等级 N / 3 → 获得后 M / 3”，读取Expedition.state.buffs和item.levels，最高3级。公共card用于奖励和商店，商店原有Lv提示仍保留。未改数值/购买/奖励规则。

新增tests/expedition_reward_level_display_regression.gd，真实奖励场景隔离用户目录2/2通过，exit0无stderr。测试先start完整远征再设engines=1、奖励engines+1，检查真实Label为“当前等级 1 / 3 → 获得后 2 / 3”。证据临时目录 C:/Users/admin/AppData/Local/Temp/IronTideRewardLevel-e2a3dd3b0e914ab9a732747275e483d5。未截图验观感、未打包提交推送。
