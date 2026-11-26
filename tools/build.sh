#!/bin/bash
# 构建 gofree（Release，ad-hoc 签名）并输出 .app 到 build/ 目录
set -euo pipefail

cd "$(dirname "$0")/.."

APP_NAME="gofree"
BUILD_DIR="build"
CONFIG="Release"

echo "==> 生成 Xcode 工程"
if command -v xcodegen >/dev/null 2>&1; then
    xcodegen generate
else
    echo "缺少 xcodegen（brew install xcodegen）；若已有 gofree.xcodeproj 可继续" >&2
fi

echo "==> 编译（${CONFIG}）"
xcodebuild \
    -project gofree.xcodeproj \
    -scheme gofree \
    -configuration "$CONFIG" \
    -derivedDataPath "$BUILD_DIR" \
    build

APP_PATH="$BUILD_DIR/Build/Products/$CONFIG/$APP_NAME.app"

echo "==> ad-hoc 签名"
codesign --force --deep --sign - "$APP_PATH"
codesign --verify --deep --strict --verbose=1 "$APP_PATH"

echo "==> 完成：$APP_PATH"
echo "    运行：open \"$APP_PATH\""