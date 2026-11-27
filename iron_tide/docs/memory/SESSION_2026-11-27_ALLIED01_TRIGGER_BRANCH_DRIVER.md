# 盟军首关：原图驱动接控制器、场外转属与逐厂失败结算

接 `ALL01UMD_DRIVER_INVENTORY.md`、`SESSION_2026-11-27_ALLIED01_OFFMAP_YARD.md`、`SESSION_2026-11-27_ALLIED01_DRIVER_WIRING.md`。用户要求完成五项和触发器接线；本批是接线扩展，不是五项整体验收。

- `tools/export_allied_script_slice.mjs` 在 ALL01UMD 原 9 条增加 `0BD650AC/0BD6117C/045CEF3C/06178D0C`，从 `.validation/allied-ends-20261126/audit` 重建 `data/ra2/allied_script_slice.json`，首关 13 条，终关仍 43 条。原图总 334 条与全局 AI 165 条口径不变。
- `allied_first.gd` 让正式战场用 `allied_retail_script.gd` 按表推进 50 的晚期启用，通过 `045CEF3C` action 14/16 转移界外 YACNST 的脚本归属。早/晚控制器状态通过战场查询分别进入 `089EC19C` / `0BD6117C`；共用同一驱动快照继续按表庆祝/胜利，不另起计时。355 的指代仍用已登记目标代理，现有装甲/谭雅门槛保留，不宣称原版双链全部启停语义或场外实体生产完成。旧档无驱动时按旧计时/已启用旗标初始化。
- `06178D0C` 由当前逐厂损失门槛启用，执行原图动作 2 结算。原版逐厂变量门槛未替换，毁机仍是前一批项目近似。

Godot 4.7.2 隔离无头：`tests/allied_first_playable.tscn -- --power-loss` 24/24；`--reported-slot2 --carriers --late-dominator --save-victory-driver` 42/42；另进程 `--cold-victory-driver` 4/4。最终全 exit0、stderr 空。早线 `--reported-slot2 --carriers` 38/38、stderr 空（首次外层未捕获退出码），验证的是同版控制器驱动，早线测试人为复位控制器计时。全部用夹具推进时间/伤害，不是玩家自然通关；用真实旧档副本，未碰玩家原件。日志 `.validation/allied01-playable/drivers-final-{loss,late,cold}.{out,err}`、`driver2-early.{out,err}`。

未改完整金门桥、全局 AI 和完整开场；逐厂失败只接结算，控制器双线仍有上述代理。未图形验收或打包。
