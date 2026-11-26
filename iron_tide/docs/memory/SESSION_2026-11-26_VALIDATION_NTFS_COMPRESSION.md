# 2026-11-26 服务器缓存清理与 IronTide 原路径压缩

用户明确确认范围：KFramework_server 的七个已标为 disposable 的测试 run 删除；IronTide 两个 `.validation` 和两个 Temp 根下 IronTide 测试副本的资源文件、两个 `.validation` 内的 `.itsave` 做 NTFS 原路径无损压缩。保留主工程、玩家存档、唯一备份、受保护证据、活动目录及共享链接。

## 最终结果

| 项目 | 数量 | 本次实际处理文件的分配空间变化 |
|---|---:|---:|
| KFramework_server 可淘汰测试 run | 7 个 | 删除文件逻辑大小 8.73 GiB |
| IronTide 资源副本 | 408,335 个文件 | 47.50 → 45.49 GiB，节省 2.01 GiB |
| IronTide 测试存档 | 6,531 个文件 | 45.21 → 19.46 GiB，节省 25.75 GiB |

压缩总计节省 27.76 GiB，最终保持压缩的文件为 414,866 个。分配空间按 Windows GetCompressedFileSizeW 和卷簇大小核对。服务器删除量为逻辑文件字节，不冒充独立物理回收量。

磁盘可用空间在本轮开始时为 765,462,405,120 字节，最终审计时为 790,112,620,544 字节，净增加 22.96 GiB，最终约 735.85 GiB 可用。期间同机其他任务持续运行并写入文件，因此整盘净变化与本任务文件统计分开报告。

## 删除范围和保全

既有 Tools/HarnessArtifacts/cache_lifecycle.py 的 prune 逻辑经一次性白名单适配调用，仅发现用户确认的七个 run；原实现中的身份、生命周期、目录链接、锁及宽限期检查保留。未修改原工具源码。清理结果 errors 为空，七个目录均已不存在。

完整白名单在 `delete-allowlist.json`，结果在 `server-prune-result.json`。历史 worktree 源码备份、其他 active/pinned/unregistered 缓存、数据库、配置作者源和当前业务代码均未纳入删除。

## 压缩与验收

- 使用 Windows FSCTL_SET_COMPRESSION 默认 LZNT1，对选中文件逐个处理；保持路径、文件格式和逻辑字节。未给目录设置未来新文件的压缩继承。
- 文件句柄禁止并发写入和删除，逐文件计算压缩前后 SHA-256；检查逻辑长度、压缩属性和分配空间。所有成功处理的文件通过哈希核验。
- 不跟随目录链接；共享硬链接、只读/权限受限或占用文件、已压缩文件、当次开始后改变的文件以及小于一个簇的文件跳过。跨批次的跳过次数可能重复，最终成功文件数按完整路径去重。
- 动态保护列表包含 grid-shared-probe、traffic-loop-detail、traffic-sweep-shadow 等正在测试的目录。初始约定保护的 static-combat 在测试结束后被后续批次选中四个测试存档；其内容一直与原哈希一致，收尾已撤回这四个文件的压缩属性，并核验原分配空间恢复。最终统计已扣除这四个文件，原操作记录和恢复记录均保留。
- 最终审计逐一核对所有成功操作的前后哈希对、路径范围、跨批次去重、汇总数值、四项恢复状态和七目录删除结果；errors 为空，all_hash_pairs_and_scopes_verified=true。
- 未改动游戏或服务器业务代码，不涉及 shared battle ECS 同步，不启动 Unity 或游戏做行为测试。辅助脚本语法检查通过；本轮验证针对清理和压缩本身。
- 后续使用已压缩测试副本测量资源读取耗时时，应记录其压缩状态；主工程资源未做压缩。

## 证据

权威证据目录：`C:/Users/admin/KFramework_server/.harness-cache/cache-maintenance-20261126/`

- `final-audit.json`：最终汇总与范围、哈希审计。
- `compression-restored-exclusions.json`：四个初始保护存档的恢复记录。
- `compression-files.jsonl.gz` 和各分批子目录同名文件：逐文件压缩前后哈希、分配空间与跳过记录。
- `compression-result.json`、`compression-scope.json` 及各分批子目录同名文件：本轮范围、活动保护前缀和分批结果。
- `prune_authorized.py`、`compress_irontide.py`、`compress_partition.py`、`restore_initial_exclusion.py`、`verify_results.py`：本轮维护入口，范围绑定本次确认，不是后台自动清理任务。

API 依据：[FSCTL_SET_COMPRESSION](https://learn.microsoft.com/en-us/windows/win32/api/winioctl/ni-winioctl-fsctl_set_compression)、[GetCompressedFileSizeW](https://learn.microsoft.com/en-us/windows/win32/api/fileapi/nf-fileapi-getcompressedfilesizew)。
