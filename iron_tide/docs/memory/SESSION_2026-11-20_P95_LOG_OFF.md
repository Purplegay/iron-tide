# 用户明确允许干扰下测P95：已完成

用户说就算被阻碍仍测P95，覆盖先前禁止外部游戏在场测量的本轮限制；只作受干扰诊断，不宣称收益。开始进程列表为空，测试期间审计发现用户IronTideRuntime.exe PID43896，未停止/干预，按授权完成两场。

证据iron_tide/.validation/p95-log-off-20261120-181903/{slot2,slot3}/result.json、host-cpu.json、source-audit.json、log，summary.json。源码冻结自此前已通过shadow/UI验证的.validation/shadow-ui-20261120/project，去掉Unit shadow_observer钩子；保留测试副本campaign/runtime将field_operations preload改load及类型声明的兼容修正，非当前生产逐字节快照。属于phase1底层，phase2集中调度未接管。

Godot4.7.2真正Release IronTideRuntime.exe，未激活私有桌面1600x900，frame-only，host-cpu审计，1x，15Hz，max补步64，preserve-player，原slot2/3及同meta。无mirror-player-growth、不添兵不改AI。环境IRON_TIDE_CALL_LOG=0，profiler关闭，未创建performance_calls目录。每场60s。

slot2 371单位218建筑5AI，844帧，wall60.068758s，sim64.113777s；mean71.171507ms，P5064.751，P95115.184，P99211.293，max722.577；均值倒数约14.05FPS。host系统平均37.994%，其它负载估计32.424%。
slot3 334单位206建筑5AI，960帧，wall60.006587s，sim63.858717s；mean62.506857ms，P5060.637，P9584.761，P99134.795，max678.042；均值倒数约16.00FPS。

两场exit0无SCRIPT ERROR/ERROR/FAIL，source-audit changed=[]。外部游戏审计均measurement_requires_review=true；不是干净验收，不是ABBA，不与旧数据相减推导关闭日志或重构收益。模拟时间偏快约6%-7%保留，尚未解释。日志关闭后在此条件下仍明显卡顿，不能证明日志不是任何场景因素，但不能归咎持续大日志写入。

本轮性能测量完成，无新生产改动、未打包。报告需向用户给具体数值/干扰/限制。
