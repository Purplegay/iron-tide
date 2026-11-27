# 盟军首关：片头后的伊娃语音与任务目标

用户实玩反馈全屏片头结束后没听到 EVA、没有任务目标。原试玩只有战报和阶段标点，HUD 仍走通用部署标题，情报没有本关目标节点，交控没调用原图的开场 EVA。以前媒体夹具只验播放器实例，不能覆盖真实续音等待。

- `scripts/world/allied_first.gd`：全屏片头结束立即刷新战场目标；雷达小窗自然结束或跳过后，走既有 EVA 队列播零售 `EVA_EstablishBattlefieldControl`（原图 `Camera_Start 08A77A5C`；`evamd.ini` 的 Allied `ceva016`），显示中文伊娃通讯“派工程师占领发电厂，为时光机恢复供电”，并沿用公开目标闪点。把该语音安排在雷达简报之后避免重叠，非原版逐动作时序。
- `scripts/ui/hud.gd`：HUD 与「情报 → 本关总目标」显示当前任务、占领数量和供需数值，供电完成更新目标；不再显示通用部署计时。`scripts/ui/hollywood_film.gd`：仅首关 `A01_P01E` 雷达简报期间暂停战场，结束/跳过恢复，防止试玩尚未交还操作时队伍已交火；独立原声和画面继续播放。如另有暂停拥有者则不抢占。
- Godot 4.7.2 无头隔离 APPDATA，`tests/allied_first_playable.tscn -- --natural` 跳过全屏片头但让实际雷达视频和独立原声自然完成，音轨时间推进、留帧、交控、EVA 开始播放计数与目标共 20/20，最终 stderr 空。该进程的等待窗口未捕获退出码。跳过分支 20/20 和供电后独立进程 `-- --cold` 4/4，退出 0、stderr 空。证据 `.validation/allied01-playable/eva2-{natural,skip,cold}.{out,err}`。未人工监听、未做有头界面位置验收、未实等整部 102 秒全屏片头自然结束、未打包或修改玩家存档；完整逐句简报字幕仍待制作。
