#!/bin/bash
# 打包成 dmg（ad-hoc 签名、未公证）
set -euo pipefail

cd "$(dirname "$0")/.."

APP_NAME="gofree"
VOL_NAME="gofree"
DIST_DIR="dist"
DMG_PATH="$DIST_DIR/gofree.dmg"

./tools/build.sh

APP_PATH="build/Build/Products/Release/$APP_NAME.app"
if [ ! -d "$APP_PATH" ]; then
    echo "找不到 $APP_PATH" >&2
    exit 1
fi

STAGING="$(mktemp -d)"
trap 'rm -rf "$STAGING"' EXIT

echo "==> 准备 dmg 内容"
cp -R "$APP_PATH" "$STAGING/"
ln -s /Applications "$STAGING/Applications"

cat > "$STAGING/首次打开说明.txt" <<'TXT'
gofree 未使用 Apple 开发者证书签名（未公证），首次打开会被 Gatekeeper 拦截。

打开方式（任选一种）：

1. 系统设置 → 隐私与安全性 → 向下滚动找到「gofree」→ 点「仍要打开」→ 确认。
2. 终端执行：
   xattr -dr com.apple.quarantine "/Applications/gofree.app"

都没有风险，只是因为没有付费开发者账号做公证。
TXT

mkdir -p "$DIST_DIR"
rm -f "$DMG_PATH"

echo "==> 生成 dmg"
hdiutil create \
    -volname "$VOL_NAME" \
    -srcfolder "$STAGING" \
    -fs HFS+ \
    -format UDZO \
    -imagekey zlib-level=9 \
    -ov \
    "$DMG_PATH" >/dev/null

echo "==> 完成：${DMG_PATH}（$(du -h "$DMG_PATH" | cut -f1)）"