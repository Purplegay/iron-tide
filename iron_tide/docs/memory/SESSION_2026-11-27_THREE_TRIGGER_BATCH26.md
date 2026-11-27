# 第 26 批 · 三关剩余八条任务触发器结项

三关零售地图共 681 条任务触发器。第 25 批后有接线 673 条、未接 8 条。本次新增正式战场效果 1 条，另 7 条按用户确认的原图无绑定口径结项。当前有接线 674 条（18 条标记为已接并专项验证，656 条为部分接线），7 条经原图核验无对象效果，未处置 0 条。既有部分接线仍保留原范围。本批只处理这八条任务。

## 苏一返城电厂

SOV01UMD 原标签 `0C46AA5C` 的触发链为 `097DDE6C → 0951918C → 0C46AB3C`。六座建筑的原房是 Alliance。原图 Structures 依次为 GAPOWRA (78,111)、GAPOWRB (80,126)、GAPOWRC (91,116)、GAPOWRD (112,113)、GAPOWRE (128,116)、GAPOWRF (119,82)。

第二次穿越入口执行既有 `0BDC985C` 时启用 `0BDCDD0C`。后者等 8 秒启用 `0C46AB3C`，再过 1 秒执行自身停用与动作 14，目标房 0 为 Americans。在现版 2.8 秒旋涡内继续计算这条原链，旋涡结束时尚余 6.2 秒。本批沿用现有上游镜头触发时点。

`tools/export_time_shift_fleet.mjs` 经共享标签反查提取目标房、原址和六种绑定类型。`scripts/world/time_shift_retail_cleanup.gd` 在离开旧金山时依类型、标签和实际地基中心匹配原厂。仅保存存活原厂的归属、生命、维修和俘获等任务状态，侏罗纪不生成这些建筑。返城时在原位置恢复，计时到点后现存目标转给 Americans，并按现有阵营映射刷新电力与房色。独立玩家同型建筑不参与。转属后允许玩家再次占领。无此改动前已离开旧金山的旧档缺少原厂存活记录，按已有记录恢复，不从地图补造六座。

## 另外七条逐 ID 结项

|关卡与原 ID|动作对象|原标签|原图启用或强制来源|核验|
|---|---|---|---|---|
|苏一 `0441BAAC`|旧金山对象转交美军|`0975F31C`|`0C4A628C`|无绑定|
|好莱坞 `0930C39C`|转交尤里|`0931D05C`|无，原始停用|无绑定|
|好莱坞 `0ACD381C`|唤醒光棱|`0ACD0F4C`|`08D5E88C`|无绑定|
|好莱坞 `08E7FB5C`|唤醒坦克|`08E7F47C`|`08E7FF3C`|无绑定|
|好莱坞 `07F39F3C`|控制巴士|`07F39A4C`|原始启用|无绑定|
|好莱坞 `07F31BAC`|控制第二辆巴士|`07F3162C`|原始启用|无绑定|
|好莱坞 `07F3122C`|控制第三辆巴士|`07F32F4C`|原始启用|无绑定|

`tools/retail_trigger_bindings.mjs` 反向遍历链接触发器并枚举所有对应标签，再扫描标签定义以外的全部 MAP 段引用，覆盖地格、单位、建筑、空军、小队和动作。`tools/export_three_mission_triggers.mjs` 对这七个具体 ID 分别断言原标签、零引用、唯一动作 14 和预期启用/强制来源。没有把它们接到同名巴士、光棱或坦克。详细原定义、Events、Actions 和结果见 [逐 ID 任务表](THREE_MISSION_TRIGGER_COVERAGE.tsv)。

## 验证

以 IronTide 的 `iron_tide/` 为 cwd，使用既有 `.validation/three-trigger-ai-19/` 的三份 Steam 原图。两个导出器检查 MAP 的 SHA-256。复跑 `node tools/export_time_shift_fleet.mjs .validation/three-trigger-ai-19/sov01umd.map` 和 `node tools/export_three_mission_triggers.mjs docs/memory/THREE_MISSION_TRIGGER_COVERAGE.tsv .validation/three-trigger-ai-19/sov01umd.map .validation/three-trigger-ai-19/all02umd.map .validation/three-trigger-ai-19/sov07umd.map`。

Godot 4.7.2 隐藏无头，独立 APPDATA/LOCALAPPDATA，命令为 `Godot --headless --path . res://tests/<场景>.tscn -- --campaign-test-no-autosave [--用例]`。三个冷读各自从 seed 专用目录复制对应测试槽位，在独立进程恢复。最终日志在 `.validation/three-trigger-26/`。首次损毁测试在开场保护期造成无效攻击，修正测试阶段后重新跑了正式种档及全部冷读。以下只计最终运行。

|场景|用例|通过断言|
|---|---|---:|
|time_shift|six-grid-transfer，六座全存活，原址与另建同型厂隔离|14|
|time_shift|seed-grid-transfer，供电阶段击毁 F 厂，保存三个断点|17|
|time_shift|cold-grid-archive，slot1 在侏罗纪读回五份存活记录|12|
|time_shift|cold-grid-before，slot2 转属前摧毁 E 厂，实际只转四座|11|
|time_shift|cold-grid-after，slot3 转属后重新占领无重发|3|
|time_shift|write-crossings，带旋涡种档的既有主线至胜利|65|
|time_shift|默认主线至胜利|61|
|hollywood_campaign|retail-closure21，原房全灭后继等既有回归|15|

8 组共 198 项通过，退出码均为 0，stderr 均为空。主线验收使用既有自动化任务步骤；未做有头目测或人工自然通关。没有操作玩家存档或发布安装包。
