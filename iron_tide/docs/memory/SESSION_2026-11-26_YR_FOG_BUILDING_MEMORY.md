# 尤复雾中建筑调查（2026-11-26）

- 本机 Steam 零售《尤里的复仇》用 `ra2pipe/lib/yr_source.mjs` 的 `YrSource` 只读提取 `expandmd01.mix` 内 `rulesmd.ini`（SHA-256 `3d341ef8a13a4b5ab24af2eef48ac94931ac2bb87d950fe3330a07e2d25672ef`）：`[General] FogOfWar=no`，`[MultiplayerDialogSettings] FogOfWar=no`，`[AudioVisual] ShroudGrow=no`。这只是零售默认设置，不等于引擎没有雾中物件路径，也不代表每张图或特殊揭蔽机制都按默认行为。
- 参考本地 `refs/ra2yr-resource/src/system/gap2_defs.cpp` 的 `CellClass::CreateFoggedObjects`（gamemd `0x486A70`，有反编译和汇编）：分配独立 `FoggedObjectClass` 向量，建筑走 `BuildingClass::CreateFoggedObjects`，非建筑走其它分支，非空向量挂在格子上。`anchors/ctor_types.json` 还有 `FoggedObjectClass::DrawRecord` 向量类型对应项。建筑重建源码本体是占位实现，不拿它推断零售不工作。以上支持把雾中建筑当独立显示记录，不等同于继续显示实时实体。
- Iron Tide 已区分当前视野 `visible_cells` 和已探索 `explored_cells`，但 `scripts/world/fog_of_war.gd` 更新实物显示、`scripts/ui/minimap.gd` 画建筑点均使用 `Battle.actor_visible_to`，常规路径要求建筑位置当前可见；没有独立的末次目击建筑记录，所以离开视野只剩地形，建筑消失。
- 建议若后续实现：灰雾显示上次目击的建筑外观，避免雾里建造、易主、损伤或拆毁透出实时信息；重新侦察才确认变化。显示记录与实时拾取、锁定、AI可见性分开，未探索黑幕不显示记录；检查小地图、跨格建筑、重遮蔽和存读档。这里是移植建议，未逐项声称为零售精确行为。
- 本轮仅检查零售规则、逆向路径及项目代码，未运行零售实机，未确认建筑各动画层、特殊重遮蔽、小地图和读档细节；没有修改玩法或玩家存档。
