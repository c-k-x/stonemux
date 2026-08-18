# stonemux · Walking-Skeleton 施工蓝图

> 一句话定位：**stonemux = 基于 Ghostty(libghostty) 的原生 macOS 终端，把"agent 之间跨机器发消息"做成一等公民。**
> 不 fork cmux；cmux 只作参考。核心代码由 AI 编写。

---

## 0. 生死原则
- **终端内核不自己造**：复用 libghostty（GhosttyKit）。护城河是"agent 消息层"，不是终端模拟。
- **消息层栈无关**：broker + 信封协议 + 人审 + 投递逻辑，与终端壳是原生还是 web 无关，一次写好可复用。
- **walking skeleton**：先跑通"发消息→人审→投递→回执"闭环，不追求 tab/主题/会话恢复等完整终端功能。

---

## 1. 三大部件

| 部件 | 技术 | 职责 |
|---|---|---|
| **终端壳** | Swift/AppKit + libghostty(GhosttyKit) + Metal 渲染 | 宿主 agent 会话的终端；提供 surface 读写/注入 |
| **消息层** | Swift（嵌入壳内）+ broker 客户端 | 收件箱、人审网关、投递、回执 |
| **broker** | Python(内网服务器) 极薄 HTTP | 跨机器中转 + 存储 |

---

## 2. libghostty 生命周期（施工核心，源自 cmux iOS GhosttyRuntime 提炼）

```
ghostty_init(argc, argv)                 # 一次性后端初始化，须 == GHOSTTY_SUCCESS
  ↓
config = ghostty_config_new()
ghostty_config_load_default_files(config)      # 读配置文件
ghostty_config_load_string(config, ...)        # 可选：内联配置
ghostty_config_finalize(config)
  ↓
填 ghostty_runtime_config_s:
  userdata        = self
  wakeup_cb       → 触发 tick/重绘
  action_cb       → 处理 OPEN_URL / RENDER / SET_TITLE / RING_BELL / ...
  read/write_clipboard_cb
  close_surface_cb
  ↓
app = ghostty_app_new(&runtimeConfig, config)   # 得 ghostty_app_t
  ↓
事件循环: ghostty_app_tick(app)                  # 由 wakeup 驱动
surface = ghostty_surface_new(...)              # 建终端实例 → Metal 渲染 + PTY
  ↓
清理: ghostty_app_free(app); ghostty_config_free(config)
```

**最小实现映射（stonemux 侧 Swift 类）：**
- `StonemuxRuntime`：对应上面 init→config→app_new→callbacks→tick（参考 cmux `GhosttyRuntime.swift`，551 行，路径见 §6）
- `StonemuxSurfaceView`：NSView + CAMetalLayer，承载一个 ghostty_surface 的渲染与键入
- `StonemuxApp/AppDelegate`：窗口、surface 编排、消息层接入点

---

## 3. 消息层设计（栈无关）

### 信封 envelope
```json
{
  "id": "...", "from": "<agent_id>", "to": "<agent_id>",
  "content_type": "message" | "task",
  "subject": "...", "body": "...",
  "attachments": ["<相对路径>"],
  "reply_to": null, "created_at": "...",
  "status": "pending" | "delivered" | "read" | "replied"
}
```
> 知识/技能不做新类型，走 attachments；接收端人审后决定去留。

### broker 最小 HTTP 接口（auth：单共享 token）
```
POST /msg                     发送
GET  /msg?to=<id>&status=pending   拉取
POST /msg/<id>/ack            更新状态(delivered/read)
POST /msg/<id>/reply          回执/回复
```
存储：SQLite 或 JSON 文件即可。

### 投递与人审
1. daemon/壳内客户端 poll broker → 收到发给"我"的消息
2. 壳内弹出审批（人看到 subject/body/附件）
3. 批准后：把 body 作为 prompt **注入目标 surface**（libghostty 写输入），或**新开一个 surface** 承载该任务
4. 完成后 reply → 发送方 status=replied

---

## 4. Walking-Skeleton 成功标准（可验证）
> A 机 stonemux 里发一条 `task`+附件 → B 机 stonemux 弹审批 → B 批准 → 投递进 B 的 agent surface → B 的 agent 处理并 reply → A 看到 status=replied。全程零手动复制粘贴。

**MVP 明确不做**：群聊/BBS、自动装技能/合 memory、加密(靠 token+内网)、tab/主题/会话恢复、iOS。

---

## 5. 构建顺序（Xcode 就绪后）
1. **备料**：`git submodule update --init ghostty` + `brew install zig`（版本见 cmux `scripts/ghostty-zig-version.sh`）。注意：**不需要** cmux setup 里的 Rust（那是 cmux 的 DiffSidecar，我们不用）。
2. **GhosttyKit**：`cd ghostty && zig build -Demit-xcframework=true -xcframework-target=universal -Doptimize=ReleaseFast` 产出 GhosttyKit.xcframework。
3. **里程碑1（hello-terminal）**：新建 Xcode app，链接 GhosttyKit，跑通 §2 生命周期 → 一个窗口里渲染出一个可交互 shell。**验证点：能打字、能回显。**
4. **里程碑2（消息闭环）**：接 broker + 收件箱 + 人审 + 投递。**验证点：§4 成功标准。**
5. **里程碑3（双机）**：A↔B 两台 Mac 端到端。

---

## 6. 关键参考（已 clone 在 /Users/mbj0599/code/tmp/cmux）
- **libghostty 生命周期最佳范本**：`Packages/iOS/CmuxMobileTerminal/Sources/CmuxMobileTerminal/GhosttyRuntime.swift`（551 行，init/config/app/回调/clipboard/action 全有）
- 终端核心包：`Packages/macOS/CmuxTerminalCore/`（功能很全，作深入参考，勿照搬）
- 巨型视图（勿照搬）：`Sources/GhosttyTerminalView.swift`（1.2 万行）
- C API 头：`ghostty/include/ghostty.h`（需拉取 ghostty 子模块后可见）
- 构建脚本参考：`scripts/setup.sh`、`scripts/ensure-ghosttykit.sh`、`scripts/ghostty-zig-version.sh`
- CLI/socket 能力参考（投递/通知原语）：`docs/cli-contract.md`

## 7. 环境与闸门（Phase 0 现状）
- ❌ 完整版 Xcode：未装（仅 Command Line Tools）→ **用户从 App Store 安装中**
- ❌ Zig：未装（`brew install zig`，版本需匹配 ghostty 要求）
- ❌ ghostty 子模块：未拉取（写操作暂被分类器阻塞，待恢复）
- ✅ Swift 5.10 / Homebrew / node25 / bun1.2 已就绪
