# 心灵控制与解除原声音效

用户指出被控制和解除控制原本都有音效。用 `ra2pipe/lib/yr_source.mjs` 读取本机 Steam 尤复零售 `expandmd01.mix`：`rulesmd.ini` 指定 `YuriMindControlSound=YuriMindControl`、`MindClearedSound=MindCleared`，心灵控制塔的 `MultipleMindControlTower` 使用 `Controller` 弹头，未单列武器 `Report`。`soundmd.ini` 两项样本分别为 `iyurat1a` 与 `gmindcle`，均 `Type=global`、`Volume=80`、`MinVolume=70`，优先级分别为 critical / high。项目已在 `data/ra2/hollywood_audio.json` 收录两段，不重导素材。

原来只有尤里复制人的直接夺取和主动释放路径播放；尤里 X、精神控制车和控制塔的路径缺失。`scripts/units/allied_abilities.gd` 统一控制成功与解除后的音效，`scripts/units/head_games_weapons.gd` 的控制塔接入夺取入口。失效控制者由受控目标的状态更新恢复归属并播解除音；精神控制车每个仍存活且归还的目标只触发一次。重复命中、再次清理、没有实际归属变化的旧标记不播。两段走全局 SFX 池，不因镜头距离消失；未复刻原版优先级、最低音量和声像细则。没有改控制对象、持续条件或原视觉效果；未改心灵支配仪及百合子的独立技能。

Godot 4.7.2 无头，从隔离用户目录加载 `tests/mind_control_audio_regression.tscn`，使用真实遭遇战，标准及扩展模式共 34/34 通过，退出 0，stderr 空。逐一执行三种单位的精控武器和塔选敌，验证实际归属、全局播放器装入的 WAV 与次数；覆盖精神控制车双目标、塔失效、重复命中和清理。证据 `.validation/mind-control-audio-20261126/{result.json,stdout.txt,stderr.txt}`。未在玩家战局人工试听、未重跑完整战役或存读档、未打包。
