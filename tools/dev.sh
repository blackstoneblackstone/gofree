#!/bin/bash
# 调试循环：Debug 编译 + 重启菜单栏 App。改完代码跑一次即可。
# 改了 project.yml 或增删文件时，先跑一次 `xcodegen generate`。
set -euo pipefail

cd "$(dirname "$0")/.."

APP_NAME="gofree"
APP_PATH="build/Build/Products/Debug/$APP_NAME.app"

echo "==> 编译（Debug）"
xcodebuild \
    -project gofree.xcodeproj \
    -scheme gofree \
    -configuration Debug \
    -derivedDataPath build \
    build 2>&1 | grep -E "error:|warning:|BUILD" || true

if [ ! -d "$APP_PATH" ]; then
    echo "编译失败，没有产物：$APP_PATH" >&2
    exit 1
fi

echo "==> 重启 App"
pkill -f "$APP_PATH/Contents/MacOS/$APP_NAME" 2>/dev/null || true
sleep 0.4
open "$APP_PATH"

echo "==> 已启动：$APP_PATH"
echo "    菜单栏应出现「月/日 周X」；点开即可调试弹窗"