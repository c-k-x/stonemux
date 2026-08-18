# /// script
# requires-python = ">=3.10"
# dependencies = [
#   "fastapi>=0.110",
#   "uvicorn>=0.29",
# ]
# ///
"""
stonemux broker —— agent 跨机器消息中转服务（极薄、单文件）

运行:
    export STONEMUX_TOKEN="<共享密钥>"     # 不设置则自动生成并写入 ~/.stonemux/broker.token
    uv run broker.py                       # 默认监听 0.0.0.0:8765

接口（均需请求头 Authorization: Bearer <token>）:
    POST /msg                  发送消息
    GET  /msg?to=<id>&status=  拉取发给某人的消息
    GET  /msg/<id>             查询单条消息（回执状态）
    POST /msg/<id>/ack         更新状态（delivered/read）
    POST /msg/<id>/reply       回复（原消息置 replied，并新建消息发回）
    GET  /health               健康检查

存储: SQLite（~/.stonemux/broker.db）。附件以 base64 内联在消息里，
     单条（含附件）上限 8MB——跨机器传输够用，大文件以后单独做上传接口。
"""
from __future__ import annotations

import json
import os
import secrets
import sqlite3
import threading
from datetime import datetime, timezone
from pathlib import Path

import uvicorn
from fastapi import FastAPI, Header, HTTPException, Query
from pydantic import BaseModel, Field

# ---- 基础配置 ----
DATA_DIR = Path(os.environ.get("STONEMUX_DATA_DIR", str(Path.home() / ".stonemux")))
DB_PATH = DATA_DIR / "broker.db"
TOKEN_FILE = DATA_DIR / "broker.token"
HOST = os.environ.get("STONEMUX_HOST", "0.0.0.0")
PORT = int(os.environ.get("STONEMUX_PORT", "8765"))
MAX_BODY_BYTES = 8 * 1024 * 1024  # 单条消息（含附件 base64）上限 8MB，防内存打爆

_lock = threading.Lock()  # SQLite 写串行化，walking-skeleton 够用


def _now() -> str:
    """UTC ISO 时间戳，跨机器统一时区。"""
    return datetime.now(timezone.utc).isoformat()


def _load_token() -> str:
    """读共享密钥：优先环境变量，其次 token 文件；都没有则生成并保存（不打印明文）。"""
    tok = os.environ.get("STONEMUX_TOKEN")
    if tok:
        return tok.strip()
    if TOKEN_FILE.exists():
        return TOKEN_FILE.read_text().strip()
    DATA_DIR.mkdir(parents=True, exist_ok=True)
    tok = secrets.token_urlsafe(32)
    TOKEN_FILE.write_text(tok)
    TOKEN_FILE.chmod(0o600)
    print(f"[broker] 未检测到 token，已生成并写入 {TOKEN_FILE}（chmod 600）")
    return tok


TOKEN = _load_token()


def _db() -> sqlite3.Connection:
    conn = sqlite3.connect(DB_PATH)
    conn.row_factory = sqlite3.Row
    return conn


def _init_db() -> None:
    DATA_DIR.mkdir(parents=True, exist_ok=True)
    with _lock, _db() as conn:
        conn.execute(
            """
            CREATE TABLE IF NOT EXISTS messages (
                id           TEXT PRIMARY KEY,
                sender       TEXT NOT NULL,
                recipient    TEXT NOT NULL,
                content_type TEXT NOT NULL,
                subject      TEXT DEFAULT '',
                body         TEXT DEFAULT '',
                attachments  TEXT DEFAULT '[]',
                reply_to     TEXT,
                created_at   TEXT NOT NULL,
                status       TEXT NOT NULL
            )
            """
        )
        conn.execute(
            "CREATE INDEX IF NOT EXISTS idx_msg_to_status ON messages(recipient, status)"
        )


_init_db()

app = FastAPI(title="stonemux broker")


# ---- 鉴权 ----
def _auth(authorization: str | None) -> None:
    if authorization != f"Bearer {TOKEN}":
        raise HTTPException(status_code=401, detail="unauthorized")


# ---- 数据模型 ----
class Attachment(BaseModel):
    name: str
    data_b64: str = ""


class SendIn(BaseModel):
    # 线上字段名用 "from"；Python 保留字，故别名映射到 from_
    from_: str = Field(..., alias="from")
    to: str
    content_type: str = "message"
    subject: str = ""
    body: str = ""
    attachments: list[Attachment] = []
    reply_to: str | None = None
    model_config = {"populate_by_name": True}


class AckIn(BaseModel):
    status: str  # delivered | read


class ReplyIn(BaseModel):
    from_: str = Field(..., alias="from")
    body: str = ""
    attachments: list[Attachment] = []
    model_config = {"populate_by_name": True}


def _row_to_dict(row: sqlite3.Row) -> dict:
    """把 DB 行转成线上信封格式（sender→from、recipient→to、attachments 反序列化）。"""
    d = dict(row)
    d["from"] = d.pop("sender")
    d["to"] = d.pop("recipient")
    d["attachments"] = json.loads(d.get("attachments") or "[]")
    return d


# ---- 路由 ----
@app.get("/health")
def health():
    return {"ok": True}


@app.post("/msg")
def send_msg(msg: SendIn, authorization: str | None = Header(default=None)):
    _auth(authorization)
    if len(msg.model_dump_json(by_alias=True).encode()) > MAX_BODY_BYTES:
        raise HTTPException(status_code=413, detail="message too large")
    mid = secrets.token_hex(8)
    with _lock, _db() as conn:
        conn.execute(
            "INSERT INTO messages(id,sender,recipient,content_type,subject,body,attachments,reply_to,created_at,status)"
            " VALUES(?,?,?,?,?,?,?,?,?,?)",
            (
                mid,
                msg.from_,
                msg.to,
                msg.content_type,
                msg.subject,
                msg.body,
                json.dumps([a.model_dump() for a in msg.attachments]),
                msg.reply_to,
                _now(),
                "pending",
            ),
        )
    return {"id": mid, "status": "pending"}


@app.get("/msg")
def list_msg(
    to: str,
    status: str | None = Query(default=None),
    authorization: str | None = Header(default=None),
):
    _auth(authorization)
    sql = "SELECT * FROM messages WHERE recipient=?"
    args: list = [to]
    if status:
        sql += " AND status=?"
        args.append(status)
    sql += " ORDER BY created_at ASC"
    with _db() as conn:
        rows = conn.execute(sql, args).fetchall()
    return [_row_to_dict(r) for r in rows]


@app.get("/msg/{mid}")
def get_msg(mid: str, authorization: str | None = Header(default=None)):
    _auth(authorization)
    with _db() as conn:
        row = conn.execute("SELECT * FROM messages WHERE id=?", (mid,)).fetchone()
    if not row:
        raise HTTPException(status_code=404, detail="not found")
    return _row_to_dict(row)


@app.post("/msg/{mid}/ack")
def ack_msg(mid: str, ack: AckIn, authorization: str | None = Header(default=None)):
    _auth(authorization)
    if ack.status not in ("delivered", "read"):
        raise HTTPException(status_code=400, detail="status must be delivered|read")
    with _lock, _db() as conn:
        cur = conn.execute("UPDATE messages SET status=? WHERE id=?", (ack.status, mid))
        if cur.rowcount == 0:
            raise HTTPException(status_code=404, detail="not found")
    return {"id": mid, "status": ack.status}


@app.post("/msg/{mid}/reply")
def reply_msg(mid: str, reply: ReplyIn, authorization: str | None = Header(default=None)):
    _auth(authorization)
    with _lock, _db() as conn:
        orig = conn.execute("SELECT * FROM messages WHERE id=?", (mid,)).fetchone()
        if not orig:
            raise HTTPException(status_code=404, detail="not found")
        new_id = secrets.token_hex(8)
        conn.execute("UPDATE messages SET status='replied' WHERE id=?", (mid,))
        conn.execute(
            "INSERT INTO messages(id,sender,recipient,content_type,subject,body,attachments,reply_to,created_at,status)"
            " VALUES(?,?,?,?,?,?,?,?,?,?)",
            (
                new_id,
                reply.from_,
                orig["sender"],
                "message",
                f"Re: {orig['subject']}",
                reply.body,
                json.dumps([a.model_dump() for a in reply.attachments]),
                mid,
                _now(),
                "pending",
            ),
        )
    return {"id": new_id, "status": "pending", "reply_to": mid}


if __name__ == "__main__":
    print(f"[broker] 监听 http://{HOST}:{PORT}  数据: {DB_PATH}")
    uvicorn.run(app, host=HOST, port=PORT, log_level="warning")
