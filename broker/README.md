# stonemux broker

agent 跨机器消息中转服务。极薄、单文件、FastAPI + SQLite。

## 运行

```bash
# 设置共享密钥（同一 broker 的所有客户端用同一个）；不设置则自动生成并写入 ~/.stonemux/broker.token
export STONEMUX_TOKEN="<你的密钥>"

# 可选：改端口 / 监听地址 / 数据目录
export STONEMUX_PORT=8765        # 默认 8765
export STONEMUX_HOST=0.0.0.0     # 默认 0.0.0.0（内网可达）
export STONEMUX_DATA_DIR=~/.stonemux

uv run broker.py
```

## 接口

所有接口需请求头 `Authorization: Bearer <token>`。

| 方法 | 路径 | 说明 |
|---|---|---|
| GET | `/health` | 健康检查（无需鉴权） |
| POST | `/msg` | 发送消息，返回 `{id, status:"pending"}` |
| GET | `/msg?to=<id>&status=<s>` | 拉取发给 `<id>` 的消息（可按状态过滤） |
| GET | `/msg/<id>` | 查询单条消息（回执状态） |
| POST | `/msg/<id>/ack` | 更新状态，body `{"status":"delivered"\|"read"}` |
| POST | `/msg/<id>/reply` | 回复，原消息置 `replied` 并新建消息发回 |

### 信封格式

```json
{
  "id": "...", "from": "alice-codex", "to": "bob-claude",
  "content_type": "task",            // message | task
  "subject": "...", "body": "...",
  "attachments": [{"name": "diff.patch", "data_b64": "<base64>"}],
  "reply_to": null, "created_at": "...",
  "status": "pending"                // pending→delivered→read→replied
}
```

> 附件以 base64 内联，单条（含附件）上限 8MB。大文件以后单独做上传接口。

## 自检

先启动 broker，再跑：

```bash
export STONEMUX_TOKEN="<和 broker 同一个密钥>"
uv run smoke_test.py            # 默认打 http://127.0.0.1:8765
```

走完 发送→拉取→ack→reply→回执 全流程，逐步打印 PASS/FAIL。

## curl 速查

```bash
T="Authorization: Bearer $STONEMUX_TOKEN"; B=http://127.0.0.1:8765

# 发送
curl -s -H "$T" -H 'Content-Type: application/json' -d \
  '{"from":"alice-codex","to":"bob-claude","content_type":"task","subject":"对齐","body":"看一下"}' \
  $B/msg

# 拉取
curl -s -H "$T" "$B/msg?to=bob-claude&status=pending"

# ack
curl -s -H "$T" -H 'Content-Type: application/json' -d '{"status":"read"}' $B/msg/<id>/ack

# 回复
curl -s -H "$T" -H 'Content-Type: application/json' -d '{"from":"bob-claude","body":"收到"}' $B/msg/<id>/reply
```
