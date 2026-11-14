#!/bin/sh
# 建置公開網站：把要發布的檔案複製到 dist/。
# Cloudflare 每次建置都會執行這支腳本，之後 `npx wrangler deploy` 只上傳 dist/。
# 新增網站要用的檔案或資料夾時，把路徑加到下面的 PUBLISH 清單（一行一個，相對於倉庫根目錄）。
set -eu

cd "$(dirname "$0")/.."

PUBLISH="
index.html
"

rm -rf dist
mkdir -p dist

for item in $PUBLISH; do
  if [ ! -e "$item" ]; then
    echo "build-site: 找不到 $item" >&2
    exit 1
  fi
  mkdir -p "dist/$(dirname "$item")"
  cp -R "$item" "dist/$item"
done

# 基本防呆：首頁必須存在而且帶有資料，否則讓建置失敗，不要發布壞掉的網站。
if ! grep -q 'const LOG = \[' dist/index.html; then
  echo "build-site: dist/index.html 沒有 LOG 資料，中止" >&2
  exit 1
fi

echo "build-site: 已輸出到 dist/"
find dist -type f | sort
