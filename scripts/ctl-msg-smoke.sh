#!/usr/bin/env bash
# stonemux P5 消息动词冒烟脚本。
# 前置：stonemux 在跑（config 为 alice/bob 互配白名单+auto_submit），broker 在跑。
set -u
CTL=/tmp/stonemux-dd/Build/Products/Debug/stonemux-ctl
BROKER=http://127.0.0.1:8765
PASS=0; FAIL=0
check() { if [ "$2" -eq 0 ]; then echo "[PASS] $1"; PASS=$((PASS+1)); else echo "[FAIL] $1"; FAIL=$((FAIL+1)); fi }

# 1. 人审路径不变：probe 不在 bob 白名单 → 保持 pending，inbox 可见
"$CTL" send bob-claude --from probe --subject hi --body "hello bob" >/dev/null 2>&1
check "send probe→bob" $?
sleep 3
"$CTL" inbox --session bob-claude 2>/dev/null | grep -q "hello bob"
check "inbox 见到 pending（人审路径不变）" $?

ID=$("$CTL" inbox --session bob-claude 2>/dev/null | python3 -c "import json,sys; print(json.load(sys.stdin)[0]['id'])" 2>/dev/null)
[ -n "$ID" ]; check "取到消息 id" $?
"$CTL" ack "$ID" delivered >/dev/null 2>&1
check "ack delivered" $?

# 2. ctl reply
"$CTL" reply "$ID" --from bob-claude --body "got it" >/dev/null 2>&1
check "ctl reply" $?

# 3. 白名单自动路径：alice 信任 bob-claude → 自动审批+自动回车，status 直接 read
"$CTL" send alice-codex --from bob-claude --subject auto --body "ping-auto" >/dev/null 2>&1
check "send bob→alice（白名单）" $?
sleep 4
curl -s -H "Authorization: Bearer test-token" "$BROKER/msg?to=alice-codex" | python3 -c "
import json,sys
msgs=[m for m in json.load(sys.stdin) if m['body']=='ping-auto']
sys.exit(0 if msgs and msgs[-1]['status']=='read' else 1)"
check "自动路径：status=read（跳过人审）" $?

echo
echo "结果: PASS=$PASS FAIL=$FAIL"
[ "$FAIL" -eq 0 ]
