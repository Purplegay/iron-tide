# 夜枭／猎蛛精修原稿

2026-11-17，v0.29.11。使用内置 imagegen，透明输出，未使用 CLI/API 回退。

- `night_owl_00.png` ～ `night_owl_07.png`：每组 4 个连续方向、3 行为飞行／半展开／完全展开。
- `rift_hunter_00.png` ～ `rift_hunter_07.png`：每组 4 个连续方向、3 行为站姿／迈步 A／迈步 B。
- 每张 1448×1086，每格 362×362；8 组覆盖原有 32 朝向，保留原稿的方向顺序，没有插值生成方向。
- [generation.json](generation.json) 保存选用生成文件标识及完整实际提示词。旋翼中心人工核对登记在 [rotor-registration.json](rotor-registration.json)，坐标为原稿像素，按组／姿态／列排列。
- **gait 子目录是已拒绝候选，不是运行来源**：用户指出新稿出现多腿，要求停止；编译器已移除其消费，实际所有姿态均恢复使用本目录初版精修原稿。保留 [gait/generation.json](gait/generation.json) 仅用于记录失败过程，不得因后台回归通过而重新接入。

编辑参考以旧 `direct32` 原稿逐格提取并重排，使用 `ra2pipe/night_hunter_detail_guides.gd`；无方向推算。正面加入认可概念图作为材质细节参考；夜枭背面单独限制尾梁为不透明装甲，避免模型将尾梁误当座舱。方向错误或前后结构错乱的候选不打包。

运行资源由 `ra2pipe/night_hunter_detail_pack.gd` 生成，环境变量 `IRON_SKIN_SOURCE` 指向本目录、`IRON_SKIN_OUTPUT` 指向候选输出目录，在 Godot 项目上下文下使用 `--headless --script <编译器绝对路径>`。先检查输出，再替换 assets/cosmetics/night_hunters 中两张 WebP 和 JSON 并后台重新导入。该离线步骤保留主体和边缘抗锯齿、排除游离残点，四边留白并校准锚点；不创造新方向、不叠帧融合。

最终使用 288 像素格无损图集，逻辑格仍为 128；原稿不进入游戏运行加载。详细验证、资源尺寸及性能边界见 [精修记录](../../../NIGHT_HUNTER_DETAIL_0297.md)。AI 原稿与后台断言通过不代表使用者已确认视觉表现。
