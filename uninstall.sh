#!/usr/bin/env bash
# Obsidian Starter Kit — アンインストーラ
# 使い方: bash ~/.obsidian-starter-kit/uninstall.sh
#
# 消すのは「このキットが入れた記録が残っているもの」だけです。
# あなたが自分で作った同名のコマンドや、vault・ノートには一切触れません。

set -euo pipefail

CLAUDE_DIR="${OSK_CLAUDE_DIR:-$HOME/.claude}"
KIT_DIR="${OSK_KIT_DIR:-$HOME/.obsidian-starter-kit}"
MANIFEST="$CLAUDE_DIR/.obsidian-starter-kit-manifest"
BACKUP_DIR="$CLAUDE_DIR/.obsidian-starter-kit-backup"

if [ ! -f "$MANIFEST" ]; then
  echo "このキットのインストール記録が見つかりません（${MANIFEST}）"
  echo "何も削除しませんでした。"
  exit 0
fi

removed=0
while IFS= read -r target; do
  [ -n "$target" ] || continue
  if [ -e "$CLAUDE_DIR/$target" ]; then
    rm -rf "${CLAUDE_DIR:?}/$target"
    removed=$((removed + 1))
  fi
done < "$MANIFEST"

rm -f "$MANIFEST"
echo "✓ ${removed} 件を削除しました"

# インストール時に退避した既存ファイルがあれば書き戻す
if [ -d "$BACKUP_DIR" ]; then
  echo ""
  echo "インストール時に退避したファイルを書き戻しています…"
  (cd "$BACKUP_DIR" && find . -type f -print0) | while IFS= read -r -d '' f; do
    rel="${f#./}"
    mkdir -p "$CLAUDE_DIR/$(dirname "$rel")"
    cp -R "$BACKUP_DIR/$rel" "$CLAUDE_DIR/$rel"
    echo "  戻しました: $rel"
  done
  rm -rf "$BACKUP_DIR"
fi

echo ""
echo "キット本体（${KIT_DIR}）は残してあります。完全に消す場合は:"
echo "  rm -rf $KIT_DIR"
echo ""
echo "あなたの vault とノートは削除していません。"
