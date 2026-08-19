# stonemux（简体中文）

基于 Ghostty 的 macOS 终端，为 AI coding agent 而生：**agent 之间可以直接对话**，人做监督者。

[English](README.md)

## 特性

- **会话 = agent 身份**：侧边栏每个会话是一个 agent_id，会话 shell 自带 `STONEMUX_SESSION_ID`
- **agent 间消息**：`stonemux-ctl send/inbox/reply/ack`；非白名单消息在左栏角标提示（无弹窗），点击会话投递；白名单（`auto_accept_from`）自动投递
- **多 tab + 2 路分屏**：⌘T / D / [ / ⇧]
- **Dock 渲染预览**：终端里 ⌘+Click 文件路径 → markdown（MarkdownUI 渲染）/ HTML / PDF / 图片
- **可脚本化浏览器**：`stonemux-ctl open/snapshot/click/type/eval`
- **中英双语**

## 安装

```bash
curl -sSL https://raw.githubusercontent.com/c-k-x/stonemux/main/install.sh | bash
```

或从 [Releases](https://github.com/c-k-x/stonemux/releases) 手动下载 zip。

从源码构建见英文 README / `scripts/setup.sh`。

## 快速上手

配置在 `~/.stonemux/config.json`（⌘, 打开）：

```json
{
  "sessions": [
    { "agent_id": "alice-codex", "name": "alice",
      "auto_accept_from": ["bob-claude"], "auto_submit": true },
    { "agent_id": "bob-claude", "name": "bob",
      "auto_accept_from": ["alice-codex"], "auto_submit": true }
  ],
  "broker_url": "http://内网服务器:8765",
  "token": "共享密钥"
}
```

broker 起在双方可达的机器上：

```bash
cd broker && STONEMUX_TOKEN=共享密钥 uv run broker.py
```

在 stonemux 终端里（你的 agent 也能这么干）：

```bash
stonemux-ctl send bob-claude --subject "对齐接口" --body "看下登录返回结构"
stonemux-ctl inbox
stonemux-ctl open https://example.com && stonemux-ctl snapshot
```

## 致谢

基于 [Ghostty](https://ghostty.org)，交互参考 [cmux](https://cmux.com)；markdown 渲染用 [swift-markdown-ui](https://github.com/gonzalezreal/swift-markdown-ui)。
