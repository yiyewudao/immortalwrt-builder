#!/bin/sh
# 把 extra-packages/ 里的第三方 .apk / .run 整理到 ImageBuilder 的 packages/ 目录
BASE_DIR="extra-packages"
TEMP_DIR="$BASE_DIR/temp-unpack"
TARGET_DIR="packages"

rm -rf "$TEMP_DIR" "$TARGET_DIR"
mkdir -p "$TEMP_DIR" "$TARGET_DIR"

for run_file in "$BASE_DIR"/*.run; do
    [ -e "$run_file" ] || continue
    echo "解压 $run_file"
    sh "$run_file" --target "$TEMP_DIR" --noexec
done

find "$TEMP_DIR" -type f -name "*.apk" -exec cp {} "$TARGET_DIR"/ \;
find "$BASE_DIR" -mindepth 2 -maxdepth 2 -type f -name "*.apk" ! -path "$TEMP_DIR/*" \
  -exec cp {} "$TARGET_DIR"/ \;

echo "第三方 apk 已整理至 $TARGET_DIR/ (共 $(ls "$TARGET_DIR"/*.apk 2>/dev/null | wc -l) 个)"
