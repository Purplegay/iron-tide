# 盟军 01《时间流逝》CG 收藏预览

后续用户确认：CG 收藏节选是战役迁移的必交付项。已同步写入已安装的 `yr-campaign-porting` 技能和[仓库技能原文](../skills/yr-campaign-porting/SKILL.md)的整关验收硬门槛。本次规范更新不改游戏代码。

玩家截图显示已收藏 3/3，三张卡片仍为雪花。`campaign_cg_catalog.gd` 已登记三段可回看影片，但 `cg_collection.gd::POSTERS` 未登记对应预览，已解锁也落入 `SNOW`。现补登记 `assets/ui/cg_gallery/A01_{F00E,P01E,P02E}.webp` 和 Godot 导入文件；已收藏直接显示对应正片截图，未收藏仍显示雪花。不改影片、任务播放、奖励或存档。

片源是已移植的盟军 `ALL01UMD` 零售影片（`movmd03.mix` 经 `tools/allied_first_media.mjs` 转成 `assets/ra2/allied_first/*.ogv`）。取帧分别为 `A01_F00E` 61 秒、`A01_P01E` 2.2 秒、`A01_P02E` 4 秒。复跑：`ffmpeg -ss <秒> -i assets/ra2/allied_first/<ID>.ogv -frames:v 1 -vf scale=320:-2,setsar=1 -c:v libwebp -quality 86 assets/ui/cg_gallery/<ID>.webp`。

Godot 4.7.2 使用隔离 APPDATA 无头导入成功。`res://tests/cg_collection.tscn` 首进程 24/24、独立 `-- --cold` 62/62、均退出 0；首进程唯一警告来自测试主动模拟写盘失败。真实收藏场景检查三张卡片各自已收藏/未收藏时的纹理、着色器类型和禁用状态；冷读覆盖主菜单到收藏、原有回看流程、全部 17 个视频与预览的资源加载。测试总数从目录计算，不再硬编码 11。证据 `.validation/cg-allied01-preview/{import,seed,cold}.{out,err}`。已目视核对导出的截图素材，未启动有头游戏检查画面合成，未逐一回看这三段、未重打战役或打发行包。
