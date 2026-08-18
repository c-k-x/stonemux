#!/usr/bin/env bash
# stonemux-ctl 冒烟脚本（M4 全自动验证）。
# 前置：stonemux 在跑（已写 ~/.stonemux/ctl.json）。
set -u
CTL=/tmp/stonemux-dd/Build/Products/Debug/stonemux-ctl
PASS=0; FAIL=0

check() {  # check <名字> <条件结果 0/非0>
  if [ "$2" -eq 0 ]; then echo "[PASS] $1"; PASS=$((PASS+1)); else echo "[FAIL] $1"; FAIL=$((FAIL+1)); fi
}

# 1. sessions 列表
OUT=$("$CTL" sessions 2>&1); check "sessions 列出会话" $([ $? -eq 0 ] && echo 0 || echo 1)
echo "$OUT" | grep -q "agent_id"; check "sessions 含 agent_id" $?

# 2. open + url + title
"$CTL" open https://example.com >/dev/null 2>&1; check "open example.com" $?
sleep 3
"$CTL" url 2>/dev/null | grep -q "example.com"; check "url 含 example.com" $?
"$CTL" title 2>/dev/null | grep -q "Example Domain"; check "title = Example Domain" $?

# 3. eval + snapshot
"$CTL" eval "document.title" 2>/dev/null | grep -q "Example Domain"; check "eval document.title" $?
[ -n "$("$CTL" snapshot 2>/dev/null | head -1)" ]; check "snapshot 非空" $?

# 4. type + click（搜索页）
"$CTL" open "https://duckduckgo.com/html/" >/dev/null 2>&1
sleep 3
"$CTL" type "input[name=q]" "stonemux" 2>&1 >/dev/null; check "type 输入关键词" $?
"$CTL" click "input[type=submit]" 2>&1 >/dev/null; check "click 提交" $?
sleep 3
"$CTL" snapshot 2>/dev/null | grep -qi "stonemux"; check "snapshot 含结果" $?

# 5. 负例：坏 token（直接构造坏凭据请求验证 unauthorized）
python3 - "$CTL" <<'PY'
import json, socket, sys
ctl = json.load(open(__import__('os').path.expanduser('~/.stonemux/ctl.json')))
s = socket.socket(socket.AF_UNIX, socket.SOCK_STREAM)
s.connect(ctl['socket_path'])
req = {"token": "bad-token", "command": {"sessions": {}}}
s.sendall((json.dumps(req) + "\n").encode())
line = s.makefile().readline()
resp = json.loads(line)
sys.exit(0 if (resp.get("ok") is False and "unauthorized" in (resp.get("error") or "")) else 1)
PY
check "坏 token 被拒" $?

echo
echo "结果: PASS=$PASS FAIL=$FAIL"
[ "$FAIL" -eq 0 ]
