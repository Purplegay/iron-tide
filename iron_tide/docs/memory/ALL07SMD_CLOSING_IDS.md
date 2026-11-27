# 《脑死》收尾：完整零售 ID 对照

## 剩余 8 条任务

| 零售 ID | 原名 | 结论 | 行为及验证 |
|---|---|---|---|
| 0960EE5C | Establish_Base_D | 任务驱动（含近似和未执行动作） | 主房防守：3 组防守招募、4 组同房新兵招募、两组 5 人增援；按航点选最近可用同房反应炉，实测生成、进炉和冷读。 |
| 04F32AFC | Africa_Defenses | 任务驱动（含近似和未执行动作） | 非洲防守：3 组招募、两组 4 人增援、启用本房敌对门；实测生成、接令和冷读。 |
| 090AD17C | PrismCheese1 | 任务驱动（含近似和未执行动作） | 以现有部队组光棱预防队；航点 40→41→40→39，再循环 41→40→39；实测触发及接令，未走完自然全程。 |
| 0955DD2C | Start_GIs | 原图禁用，无启用源 | Start_GIs：4 GI、2 重装大兵的空降原图为禁用；未发现启用引用，不派兵。 |
| 0EE0857C | Set_Charge | 原图禁用，无启用源 | Set_Charge：原图为禁用；未发现启用引用，不改变超武充能。 |
| 078F61FC | Enable_Oil_Grabbers | 原图全难度掩码关闭 | Enable_Oil_Grabbers 有建造场启用引用，但简单/普通/困难均为 0；不打开。 |
| 061BD4EC | Activate_Oil_Grabbers | 原图禁用，唯一启用源全难度关闭 | Activate_Oil_Grabbers 只由 078F61FC 启用，不派定时队；现有发现油井分支不变。 |
| 09197EDC | Yuri3_Lose_ConYard | 原图零动作，不适用 | Yuri3_Lose_ConYard 无动作及后继；不是缺失的第三房胜负链。 |

## 剩余 6 条本图 AI

| 零售 ID | 原名 | 房、门槛及编组 | 验证 |
|---|---|---|---|
| 0C576C3C | Yuri_AntiPrism_1 | 主房／反光棱：≥2 SREF → 4 LTNK、1 CAOS | 目录与真实前置已验；未单队出厂。 |
| 13525D8C | Yuri_EngineerRush_1 | 主房／工程师突袭：≥1 GAPOWR → 1 YURI、1 VIRUS、2 YENGINEER | 负条件、选队、完整出厂、占领命令、近场真实到门转属。 |
| 095192DC | Yuri2_AntiRT_1 | 非洲／反遥控坦克：≥3 ROBO → 4 INIT、4 BRUTE | 正式选队，未单队实测。 |
| 0A5A71BC | Africa_Floater1 | 非洲／雷鸣飞碟：普通、困难，≥2 ATESLA → 2 DISK | 正式选队，未单队实测。 |
| 05ED315C | Africa_AntiTesla01 | 非洲／反磁暴线圈：≥2 TESLA → 3 TELE | 正式选队，未单队实测。 |
| 05ED772C | Yuri_AntiTesla01 | 主房／反磁暴线圈：≥2 TESLA → 3 TELE | 正式选队，未单队实测。 |

完整原文及此前各批见 [088 条任务](ALL07SMD_SCRIPT_RECHECK.tsv) 与 [084 条本图 AI](ALL07SMD_AI_RECHECK.tsv)。
