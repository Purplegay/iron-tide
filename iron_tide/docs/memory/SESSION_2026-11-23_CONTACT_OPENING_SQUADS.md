# 远征联络人开局编队

contact_catalog.gd 的 13 位联络人各有 opening_squad。field_operations.gd 的 setup 仅在新开战时部署到赴约联络人的独立友军席位。按既有地面可达性和 landing_clear 检查在基地周围寻找空位，调用普通 AI 单位生成和警戒命令，沿用现有上限。部署独立于电台问候与章节重试。

使用 Godot 4.7.2、独立 APPDATA，固定种子 7 的第 8 关双敌多线战，逐人通过 Expedition.launch 和实际 battle.tscn 开局。在 ai3 单位列表中核对每支小队的兵种和数量，最终 13/13 通过，exit 0，stderr 空。首轮四支三人编队只到两个，最终为这四队选用双单位。日志与夹具在 %TEMP%/IronTideSupport-47c896165b9d4b29845a856340ac497d，结果文件 final-out。验证覆盖开局生成，其他地图、飞机续航、冷读档及整场强度未实测。