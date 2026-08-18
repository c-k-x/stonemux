# /// script
# requires-python = ">=3.10"
# dependencies = []
# ///
"""
stonemux broker 自检脚本（零依赖，标准库 urllib）。

用法:
    先启动 broker:  STONEMUX_TOKEN=<token> uv run broker.py
    再运行本脚本:   STONEMUX_TOKEN=<同一个 token> uv run smoke_test.py
    可选:           STONEMUX_BROKER_URL=http://127.0.0.1:8765

走完 发送→拉取→ack→reply→回执 全流程，逐步打印 PASS/FAIL；任一失败退出码非 0。
"""
from __future__ import annotations

import base64
import json
import os
import sys
import urllib.error
import urllib.request

BASE = os.environ.get("STONEMUX_BROKER_URL", "http://127.0.0.1:8765").rstrip("/")
TOKEN = os.environ.get("STONEMUX_TOKEN", "")

A = "alice-codex"  # 发送方
B = "bob-claude"   # 接收方

_failed = False


def _call(method: str, path: str, payload: dict | None = None, auth: bool = True):
    url = BASE + path
    data = json.dumps(payload).encode() if payload is not None else None
    req = urllib.request.Request(url, data=data, method=method)
    req.add_header("Content-Type", "application/json")
    if auth:
        req.add_header("Authorization", f"Bearer {TOKEN}")
    with urllib.request.urlopen(req) as resp:
        return json.loads(resp.read().decode())


def check(name: str, cond: bool, detail: str = ""):
    global _failed
    mark = "PASS" if cond else "FAIL"
    if not cond:
        _failed = True
    print(f"[{mark}] {name}" + (f"  -> {detail}" if detail and not cond else ""))


def main() -> int:
    if not TOKEN:
        print("请先设置 STONEMUX_TOKEN（与 broker 相同）")
        return 2

    # 1. 健康检查
    h = _call("GET", "/health", auth=False)
    check("health", h.get("ok") is True, str(h))

    # 2. 发送（task + 附件）
    diff_b64 = base64.b64encode(b"hello diff").decode()
    sent = _call(
        "POST",
        "/msg",
        {
            "from": A,
            "to": B,
            "content_type": "task",
            "subject": "对齐登录接口",
            "body": "请看一下返回结构",
            "attachments": [{"name": "diff.patch", "data_b64": diff_b64}],
        },
    )
    mid = sent.get("id", "")
    check("send 返回 id", bool(mid), str(sent))

    # 3. 接收方拉取 pending
    msgs = _call("GET", f"/msg?to={B}&status=pending")
    hit = next((m for m in msgs if m["id"] == mid), None)
    check("拉取到刚发的消息", hit is not None, f"共{len(msgs)}条")
    if hit:
        check("附件 base64 原样", hit["attachments"][0]["data_b64"] == diff_b64)

    # 4. ack 置 read
    ack = _call("POST", f"/msg/{mid}/ack", {"status": "read"})
    check("ack -> read", ack.get("status") == "read", str(ack))

    # 5. 单条查询确认 read
    one = _call("GET", f"/msg/{mid}")
    check("查询状态=read", one.get("status") == "read", str(one.get("status")))

    # 6. 回复
    rep = _call("POST", f"/msg/{mid}/reply", {"from": B, "body": "收到，返回结构没问题"})
    rid = rep.get("id", "")
    check("reply 返回 id", bool(rid), str(rep))
    check("reply.reply_to 指向原消息", rep.get("reply_to") == mid)

    # 7. 原消息变 replied
    one2 = _call("GET", f"/msg/{mid}")
    check("原消息状态=replied", one2.get("status") == "replied", str(one2.get("status")))

    # 8. 发送方收到回复
    back = _call("GET", f"/msg?to={A}")
    got_reply = any(m["id"] == rid and m["reply_to"] == mid for m in back)
    check("发送方收到回执消息", got_reply, f"共{len(back)}条")

    # 9. 鉴权：错误 token 应 401
    try:
        req = urllib.request.Request(BASE + "/msg?to=" + B)
        req.add_header("Authorization", "Bearer wrong-token")
        urllib.request.urlopen(req)
        check("错误 token 被拒绝", False, "竟然通过了鉴权")
    except urllib.error.HTTPError as e:
        check("错误 token 被拒绝", e.code == 401, str(e.code))

    print("\n结果:", "全部通过 ✅" if not _failed else "存在失败 ❌")
    return 1 if _failed else 0


if __name__ == "__main__":
    sys.exit(main())
