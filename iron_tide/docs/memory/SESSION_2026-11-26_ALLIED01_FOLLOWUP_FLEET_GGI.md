# 美国首关：后续舰队、桥段恢复、开场重装大兵与全局 AI 取证

接 `ALL01UMD_SCRIPT_RECHECK.tsv`、`SESSION_2026-11-26_ALLIED01_DREAD_AI.md`、`SESSION_2026-11-26_ALLIED01_CROSSING_MIDPOINT.md`。本轮是四项的首批落地，不是完成四项。

- `067DD9FC/089D5A8C`：追加 DX/DY/DZ 三无畏舰及 ST/SU/SV/SW 四海蝎，明确用动作 80 航点，不读 TeamType 默认点。过去时代影片交控后约一模拟秒执行（原链相对时间的近似）。DY/DZ 复用实际炮击脚本；四海蝎按原图巡逻环及各自入口顺序航行，状态存入实体。DX 只生成，原动作 `46,131138` 编码目标未实现。脚本完成采用已有近似，不宣称全部航程或炮击一致。
- `0693BF3C` 执行动作 `130,0,16`，即恢复 BridgeHouse 起始建筑。盟军穿越中点检查该房零售行，恢复界内初始存活段及原始耐久，保留原始 0 HP 的 CASANF10 断口，不补界外 CASANF14。未接完整分层通行。`07A89E6C -> 07A89C0C / 079B8BBC / 079BAE6C` 是附着对象链，`07A89CFC` 等标签未在原始 Structures 行上找到直接对应；不能用「任意段击毁清全桥」猜补。坍塌待追实际标签接入。
- GGI：`0A81253C` 指向 N（13），`Unit_Eva_GuardianGI` 的零售音频 `cevau75.wav` 来自 `langmd.mix > audiomd.mix > 0xeefaed08`，转 PCM，工具 `allied_first_media.mjs` 可重建。新开局交控后 1 模拟秒查 N 附近真实盟军 GGI，给伊娃语音、中文提示和雷达事件；不补播已越过时点旧档。是提示近似，不包含原镜头、闪烁、诱饵坦克和 `Flash_GGI` 后接战。
- 全局 AI 取自 `ra2md.mix > localmd.mix > 0x116f3f76` 的 `aimd.ini`，SHA256 `5df41eaec00a78d0760ef5eecdf27d65ae1cd537309c7eac973318266986f89d`。全局表 165 条、原图覆盖 ID 165/165 命中，地图没有私有 AITriggerTypes。French、Confederation、YuriCountry、Special、Soviet2House 初始 IQ 都是 0；已找到地图 action 3 唯一 `Build_Dom 0B8A090C` 启动 Confederation 房 7。仍要核查全局条件、各房实际工厂、启用时序和生产，不开启通用遭遇战 AI。本轮只取证，没有接生产。

Godot 4.7.2 隐藏无头隔离：`tests/allied_first_playable.tscn -- --ggi-intro` 20/20；`--reported-slot2 --followup-fleet` 26/26，含实际海蝎航行、桥段恢复断口、写档（推进时钟/跳过影片使用夹具）；`--cold-followup` 3/3，独立进程查舰数、巡逻状态及重复调用。均退出 0，stderr 空。日志 `.validation/allied01-playable/four-*.{out,err}`。未碰玩家原档，未有头或打包。尚未验通关、海战真实伤害、桥上桥下、其他房生产及完整开场。
