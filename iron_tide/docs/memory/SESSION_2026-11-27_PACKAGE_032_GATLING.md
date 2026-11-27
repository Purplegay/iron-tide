# 2026-11-27 Windows 0.32 便携版：盖特机炮修复

用 `../tools/package_windows.py`、Godot 4.7.2 和本地 Release 模板导出 Windows x64 EXE/PCK，版本仍为 0.32，游戏数据隔离到 `%APPDATA%/IronTideFriends`。首轮因 `data/maps/time_shift_global_ai.json` 变化被源冻结校验拦截；第二轮冻结 16057 个源文件并完成导入、导出、主菜单启动，均 exit 0 / 0 错误。包基于已验证的冻结快照，后续工作区的 `data/maps/time_shift_global_ai.json`、`scripts/world/time_shift_global_ai.gd` 两项更新不在此包，差异列于包内 manifest；盖特相关四个生产文件无漂移。

上一版隔离测试档被此版拒绝，未绕过兼容检查，也未读取或修改玩家存档。使用同一成品 EXE/PCK 在独立目录新建 315 单位、236 建筑的测试档，同时验证六把固定盖特炮武器均加载为 Inviso。用外部临时探针恢复打包烟测，普通自动存档在烟测关闭，未进入远征；34 张原生地图及新成品档独立进程恢复均成功，314/314，exit 0，无脚本报错。未做有头图形验收或真实旧档测试。

成品：`%USERPROFILE%/Downloads/IronTide-0.32-Windows-x64-Gatling.zip`，871939065 字节，SHA-256 `377ee3163c324635b64a551e83f11f287fb30e086c46b5934ae74cd7e84e778a`。ZIP CRC 与各文件 SHA-256 测试通过，下载目录副本 SHA-256 一致。构建、日志和恢复脚本：`%TEMP%/IronRelease032-Gatling-20261127-210801/`，证据 `build/{delivery.json,smoke.json,battle-final.log,source-sha256.json}` 和 `fixture.log`。盖特故障专项见 `SESSION_2026-11-27_GATLING_INVISIBLE_PROJECTILES.md`。
