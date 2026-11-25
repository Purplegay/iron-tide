# 远征援助兵种自动取得本轮许可

用户确定普通和特装援助都在获得时授予该兵种本轮许可。army.gd 的 license_unit 统一登记目录与许可，run.gd 在特装招募成功时调用。旧档读入时按仍有成员的援军、幸存者和特装小队补登，恢复检查点时将本轮许可合入战场副本。market.gd 更新特装招募说明。

Godot 4.7.2 独立用户目录运行 tests/expedition_special_training.tscn，通过海豹部队招募、升级、补员、旧档补登和进入战场后的生产资格检查。最终日志见 %TEMP%/CodexIronTideValidation-aid-e85e56c3-a17e-4b2d-b446-ec9251801538/test.log。验证到战场许可判定，实际造兵仍依赖工厂与科技前置。
