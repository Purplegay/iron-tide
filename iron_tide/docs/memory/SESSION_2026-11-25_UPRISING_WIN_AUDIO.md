# 起义时刻胜利播报和音乐

玩家要求胜利用《红警3：起义时刻》的播报与 BGM。起义 XML 的 LocalPlayerVictorious 分别指定盟军 Aeva、苏军 Seva、升阳 Ieva 三条 YouAreVictorious 录音，提取依据见 SESSION_2026-11-25_RA3_VICTORY_EVA.md。项目使用原有三条 WAV。尤里没有起义对应阵营，本次约定为实现侧暂借苏军胜利声音，代替旧 RA2 盟军回退。

ra2_sfx.gd 处理胜利卡的 EVA。music.json 标记盟、苏两首 Combat Uprising - Triumphal 为正式胜利曲。music.gd 在 finish_battle(true) 后优先选本阵营标记曲，尤里仅借用苏军的结算曲。music_regression.gd 已更新旧的苏军结算断言。

Godot 4.7.2 headless 在独立 APPDATA 中运行阵营夹具，实际调用胜利卡及 Music.finish_battle。修改前错误计数 4，修改后 0，盟苏尤三方音乐和四个阵营键的播报均核对播放状态及文件路径，关闭 EVA 后保持静音。证据 %TEMP%/it-victory-uprising-final.log。夹具退出时 Godot 提示 3 个 ObjectDB 实例和 1 个资源仍在使用。本次覆盖播放器和结算入口，未覆盖完整对局、人工听感、升阳配乐、完整音乐回归或导出包。