#!/usr/bin/env bash
# stonemux 源码构建一键准备：
# 1) 下载锁定的预构建 GhosttyKit.xcframework（校验 sha256）
# 2) xcodegen 生成工程
set -euo pipefail
cd "$(dirname "$0")/.."

GHOSTTY_SHA=11aa609d75dec882ef2f83171e2cbe887aeddbc5
GHOSTTYKIT_URL="https://github.com/manaflow-ai/ghostty/releases/download/xcframework-${GHOSTTY_SHA}-crashsubdir-cmux-crash-sentry-off-v1/GhosttyKit.xcframework.tar.gz"
GHOSTTYKIT_SHA=1a4acbcc9e0e5b20c0b4dad6660d0c08546a5d36192053834df960144fa8fdb9

command -v xcodegen >/dev/null 2>&1 || { echo "缺少 xcodegen：brew install xcodegen"; exit 1; }

XCFW=vendor/GhosttyKit.xcframework
if [ ! -d "$XCFW" ]; then
  echo "==> 下载锁定的预构建 GhosttyKit..."
  mkdir -p vendor
  TMP=$(mktemp -d)
  curl -fSL -o "$TMP/gk.tar.gz" "$GHOSTTYKIT_URL"
  echo "$GHOSTTYKIT_SHA  $TMP/gk.tar.gz" | shasum -a 256 -c -
  tar -xzf "$TMP/gk.tar.gz" -C vendor
  rm -rf "$TMP"
else
  echo "==> GhosttyKit 已存在，跳过下载"
fi

cd app && xcodegen generate
echo "==> 完成。构建："
echo "    xcodebuild -project app/stonemux.xcodeproj -scheme stonemux -configuration Release build"
