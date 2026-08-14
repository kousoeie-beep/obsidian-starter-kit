#!/usr/bin/env bash
# vault の散らかりを診断する。読むだけで、何も変更しない。
#   使い方: bash diagnose.sh [vault のパス]
set -uo pipefail
V="${1:-.}"
cd "$V" || { echo "そのフォルダがありません: $V"; exit 1; }

# 除外はサブフォルダにも効くよう */ で書く。
# .git はサブリポジトリにもあり、.claude や node_modules はノートではない。
EX=(
  -not -path "*/.obsidian/*" -not -path "*/.git/*" -not -path "*/.claude/*"
  -not -path "*/node_modules/*" -not -path "*/.raw/*" -not -path "*/.trash/*"
)

echo "=============================================="
echo " 診断: $(pwd)"
echo "=============================================="

notes=$(find . -name "*.md" "${EX[@]}" | wc -l | tr -d ' ')
dirs=$(find . -type d -not -path "*/.obsidian*" -not -path "*/.git*" -not -path "*/.claude*" -not -path "*/node_modules*" -not -path . | wc -l | tr -d ' ')
depth=$(find . -name "*.md" "${EX[@]}" | awk -F/ '{print NF-1}' | sort -rn | head -1)
echo "規模: ノート ${notes}件 / フォルダ ${dirs}個 / 最大 ${depth:-0}階層"
echo ""

echo "── 散らかりの型 ──"
root_md=$(find . -maxdepth 1 -name "*.md" | wc -l | tr -d ' ')
[ "$root_md" -ge 10 ] && echo "  ● 置き場が無い: ルート直下に .md が ${root_md}件"
[ "${depth:-0}" -gt 3 ] && echo "  ● 深すぎる: 最大 ${depth}階層（2階層までが扱いやすい）"

empty=$(find . -type d -empty -not -path "*/.obsidian*" -not -path "*/.git*" -not -path "*/.claude*" -not -path "*/node_modules*" | wc -l | tr -d ' ')
[ "$empty" -gt 0 ] && echo "  ● 使われていない器: 空フォルダ ${empty}個（消しません。一覧は下に）"

att_dirs=$(find . \( -name "*.png" -o -name "*.jpg" -o -name "*.jpeg" -o -name "*.pdf" -o -name "*.gif" \) \
  "${EX[@]}" 2>/dev/null | xargs -n1 dirname 2>/dev/null | sort -u | wc -l | tr -d ' ')
att=$(find . \( -name "*.png" -o -name "*.jpg" -o -name "*.jpeg" -o -name "*.pdf" -o -name "*.gif" \) \
  "${EX[@]}" 2>/dev/null | wc -l | tr -d ' ')
[ "$att_dirs" -ge 5 ] && echo "  ● 添付置き場が未設定: ${att}件が ${att_dirs}フォルダに散在"

dup=$(find . -name "*.md" "${EX[@]}" | sed 's|.*/||' | sort | uniq -d | wc -l | tr -d ' ')
[ "$dup" -gt 0 ] && echo "  ● 同名ノートが ${dup}種類ある（移動時にパスを消せない）"
echo ""

echo "── ★ 移動で壊れるもの（最重要） ──"
links=$(grep -rho "\[\[[^]]*\]\]" --include="*.md" --exclude-dir=.git --exclude-dir=.claude --exclude-dir=node_modules . 2>/dev/null | wc -l | tr -d ' ')
paths=$(grep -rho "\[\[[^]]*/[^]]*\]\]" --include="*.md" --exclude-dir=.git --exclude-dir=.claude --exclude-dir=node_modules . 2>/dev/null | wc -l | tr -d ' ')
echo "  リンク総数        : ${links}"
echo "  パス付きリンク    : ${paths}  ← 移動すると壊れるのはこれだけ"
if [ "$paths" -gt 50 ]; then
  echo "  → 50件を超えています。移動前に必ず持ち主に件数を伝えること。"
elif [ "$paths" -gt 0 ]; then
  echo "  → 移動後に [[パス/名前]] を [[名前]] に書き換えること。"
else
  echo "  → パス付きリンクはありません。移動しても壊れません。"
fi
echo ""

echo "── 退避路 ──"
if git rev-parse --git-dir >/dev/null 2>&1; then
  if [ -z "$(git status --porcelain 2>/dev/null)" ]; then
    echo "  git 管理・clean → そのまま進んでよい"
  else
    echo "  git 管理だが未コミットの変更あり → 先にコミットしてもらうこと"
  fi
else
  echo "  git 管理外 → git init かバックアップを勧めること"
fi
echo ""

if [ "$empty" -gt 0 ]; then
  echo "── 空フォルダ（報告のみ・消さない） ──"
  find . -type d -empty -not -path "*/.obsidian*" -not -path "*/.git*" -not -path "*/.claude*" -not -path "*/node_modules*" | head -20 | sed 's|^|  |'
  echo ""
fi

echo "── 上位フォルダ（ノート数） ──"
find . -name "*.md" "${EX[@]}" | xargs -n1 dirname 2>/dev/null \
  | sort | uniq -c | sort -rn | head -12 | sed 's|^|  |'
