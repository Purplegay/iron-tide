# 乌贼与恐怖机器人宿主死亡核对（2026-11-26）

## 玩家操作与结果

己方巨型乌贼缠住敌舰、或己方恐怖机器人钻入敌车后，如果由其他己方单位击毁宿主，寄生者通常随宿主死亡，不会归还。只有寄生者自己的持续伤害击毁宿主时，才尝试脱离并仍归原阵营。参照实现里铁幕保护寄生者可使其在外部击毁宿主时脱离；外伤压制、可通行落点也可能改变结果。此轮没有把第三方击杀改成必定归还。

## 依据与现有入口

`../refs/ts-ra2/src/game/gameobject/trait/ParasiteableTrait.ts` 的 `NotifyDestroy.onDestroy`：forced 或未受无敌保护且 `shouldSupressParasite` 为真则销毁寄生者，否则 `evictOrDestroyParasite`。`shouldSupressParasite` 将非寄生者击杀判为压制，并考虑近期大额外伤。脱离时若地形不可通行或附近找不到落点，仍会销毁寄生者。此为仓库中的尤复参照实现，不等同于零售游戏逐帧实测。

本工程 `scripts/units/unit.gd::_die` 调用 `SovietSpecials.host_sinking` 及 `SovietWeapons.release_drone/cleanse`；乌贼考虑 `iron_left`、击杀来源与 `squid_suppression`，机器人按击杀来源分支。`scripts/units/soviet_specials.gd::release_squid` 还会搜索水域脱离点，找不到时可能消耗乌贼。寄生者并未变为敌方所有，所谓“归还”是恢复可操作的原阵营单位。

## 修改与验证

仅新增 `tests/parasite_host_death_regression.gd/.tscn`，没有改动生产规则或玩家存档。Godot 4.7.2 headless 以隔离的 `%TEMP%/IronTideParasiteValidation` APPDATA 及报告目录运行真实遭遇战场景；双方生成乌贼/驱逐舰、机器人/重型坦克，实际附着后经 `receive_hit` 击毁宿主，断言第三方击杀销毁寄生者、自身击杀脱离且仍归己方、宿主引用清理，并覆盖铁幕乌贼外部击杀脱离。结果 15/15，exit 0，stderr 空；报告 `result.json`、`stdout.txt`、`stderr.txt` 在该隔离目录。

未覆盖零售程序实机逐帧、桥上与码头/无可用水域的落点、机器人被修理/传送驱除、外伤压制阈值的边界值、存读档后附着再击杀及完整玩家操作链。未经这些验证，不推断这些分支全都等价。
