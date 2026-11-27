# 美国首关任务电厂占领房色（手动存档 3）

玩家截图反馈占领后仍为红色。只读原档，使用隔离 APPDATA 副本冷读确认 `CAPOWR05/06` 已属 ally，其他六座仍 neutral，属于表现故障。原档 SHA-256 前后均 `ECB1575B3D86506F640557F038F8FCE4561F560D292F8B2C01E04CB047C5592D`。

- `tools/allied_first_media.mjs` 将 NEWURBAN `CNPOWR.shp` 仅调色板 16–31 号房色阶烘为项目蓝 #57a8ff，保留其他固定颜料（红色等）。不改所有权、耐久或供电。更新 CAPOWR 常规页以及 8 帧/1 页双倍细节；`shp_detail_audit` 验源和输出哈希并核查 69,162 个本底像素。静态图目视房色区域为蓝、其余细节保留。
- `house_color.gd` 首关八座电厂中立按零售 PowerHouse 灰 `Grey=0,0,131`，占领后用当前玩家设置的房色。项目不强改玩家偏好。`battle_snapshot.gd` 应用完旧的序列化字段后重算首关电厂房色，避免档里的旧 `_col` 覆盖新色。旧档无需迁移。
- Godot 4.7.2 隐藏无头：实际菜单新出击、工程师走到门口占领，25/25（`color2-fresh`）；最终独立进程 `tests/allied_first_playable.tscn -- --slot3-color` 真实副本 15/15，exit 0、stderr 空，检查房归属、运行时颜色、中立材质、实际加载贴图房色基准及双倍细节（`color3-slot3`）。日志 `.validation/allied01-playable/`。用隔离默认蓝验证；未开窗口验最终合成像素，也未加载玩家设置文件，只验证与当前房色代码一致。未修改玩家档/进程，未打包。
