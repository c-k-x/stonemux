#!/usr/bin/env bash
# stonemux 一键安装：从 GitHub Releases 下载预构建包，装到 /Applications 与 /usr/local/bin。
# 用法: curl -sSL .../install.sh | bash      或      ./install.sh [tag]
set -euo pipefail

REPO=${STONEMUX_REPO:-c-k-x/stonemux}
VER=${1:-latest}

if [ "$VER" = "latest" ]; then
  URL="https://github.com/$REPO/releases/latest/download/stonemux-macos.zip"
else
  URL="https://github.com/$REPO/releases/download/$VER/stonemux-macos.zip"
fi

TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT

echo "==> 下载 $URL"
curl -fSL -o "$TMP/stonemux-macos.zip" "$URL"
unzip -o -q "$TMP/stonemux-macos.zip" -d "$TMP"

echo "==> 安装到 /Applications 与 /usr/local/bin"
rm -rf /Applications/stonemux.app
cp -R "$TMP/stonemux.app" /Applications/
mkdir -p /usr/local/bin
cp -f "$TMP/stonemux-ctl" /usr/local/bin/stonemux-ctl
chmod +x /usr/local/bin/stonemux-ctl

# 未签名应用：移除隔离属性，避免 Gatekeeper 拦截
xattr -dr com.apple.quarantine /Applications/stonemux.app 2>/dev/null || true

# 未签名版无公证，去除 Gatekeeper 隔离属性（内部工具零成本惯例；全路径绕开 rtk 代理）
/usr/bin/xattr -dr com.apple.quarantine /Applications/stonemux.app 2>/dev/null || true

echo "==> 完成。打开 /Applications/stonemux.app 即可；ctl: $(command -v stonemux-ctl)"
