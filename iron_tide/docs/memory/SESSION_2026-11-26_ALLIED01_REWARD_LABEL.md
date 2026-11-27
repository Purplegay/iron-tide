# 美国首关奖励栏误显示无尽挑战

用户截图指出「时间流逝」通关奖励栏显示「无尽挑战 · 按波数结算」。原因：首关漏配 `first_win_reward`，`campaign_command.gd` 将该字段缺失直接作为无尽分支，实际 `waves.json` 首关并非无尽；`battle_rewards.gd` 也依赖该字段走标准战役结算。

`data/waves.json` 按其他尤复剧情关的项目配置补首胜战略点 200、军需券 1200、钻石 30，重打经共用规则为 10/60/0。`campaign_command.gd` 仅在 `endless` 时显示按波数结算；有限关缺配奖励时显示无通关奖励。未补发旧场次、未动玩家档、未改关卡流程。

Godot 4.7.2 隐藏无头，隔离 APPDATA，`res://tests/campaign_completion.tscn -- --write --allied-first-rewards` 13/13、exit 0、stderr 空；用实际战役选关 UI 检查首胜、重打、完成标记、真实无尽文案，结算入口用标准 `CampaignPayout.settle` 夹具，未重打首关确认实际结算画面、未做有头或打包。日志 `.validation/allied01-reward/test.{out,err}`。
