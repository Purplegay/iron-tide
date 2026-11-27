# 美国首关：原图医院支线

接 `SESSION_2026-11-26_ALLIED01_SCRIPT_RECHECK.md`，本轮对原图 `ALL01UMD` 的 `Find_Hospital 0462B74C`、CellTag `0462CD1C`、`Power_Online 0691357C` 逐行复核。零售 PowerHouse 的 CATHOSP `1028391` 坐标 (102,78)，建筑原图 800 HP，6x4。格触发器为 x=102..111、y=78..83 周长 28 格，移植格 u=74..79、v=84..93；原图事件查 GlobalCleared 13 和 EnteredBy，发现后原始动作含揭示、提示、雷达、置全局旗标和原声 `Unit_Eva_TechHospital` → `cevau92`。得电触发器关闭该发现事件。

- `GameData` 给原址唯一医院接入现成原画/可占领定义和禁售，NativeMaps 不重复创建。`allied_first.gd` 仅供电前玩家地面单位在标记格触发，使用存档旗标作一次性本地代理，发原版语音、雷达 BE（56）、短暂揭示医院；持续标记是项目 HUD 补充，已占领或供电后撤除。不能逐条等同原版全球变量、视野图案和建筑闪烁。建筑 `_process` 复用已有原版规则自愈逻辑；快照恢复修正旧档中医院名称、可占与不可出售，不改归属。
- Godot 4.7.2 隔离无头 `tests/allied_first_playable.tscn -- --hospital` 25/25、日志 stderr 空，外层首轮等待没捕获退出码；`--cold-hospital` 2/2、`--retake` 23/23，exit 0、stderr 空。日志 `.validation/allied01-playable/recheck2-*.{out,err}`。测试用夹具踏入格和移动到入口附近，真实命令走最后一段才转属；实测治疗和独立进程恢复。未人为录音验证或有头截图，未实走从基地整条路、供电先后专项及未修订的医院炮击/恢复路径，未改用户档。脚本核对表把 0462B74C 改成近似接入，不宣称 334 条全量完成。下一批缺项仍有 `067DD9FC` 后续舰队、桥坍塌/恢复、开场 GGI 链和全局 AI。
