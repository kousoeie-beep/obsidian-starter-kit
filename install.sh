#!/usr/bin/env bash
# ============================================================================
#  Obsidian Starter Kit — インストーラ
#
#  使い方（ターミナルに1行貼るだけ）:
#    curl -fsSL https://raw.githubusercontent.com/kousoeie-beep/obsidian-starter-kit/main/install.sh | bash
#
#  何をするか:
#    1. キット本体を ~/.obsidian-starter-kit に取得（2回目以降は更新）
#    2. Claude Code のコマンドとスキルを ~/.claude/ に配置
#    3. Obsidian と Claude Code が入っているか確認して、次の一手を表示
#
#  何をしないか:
#    - vault の作成はここではやらない（Claude Code で /vault-init を実行する）
#    - 既存の ~/.claude の設定は上書きしない（このキットのファイルだけ入れ替える）
# ============================================================================

set -euo pipefail

REPO_URL="${OSK_REPO_URL:-https://github.com/kousoeie-beep/obsidian-starter-kit.git}"
KIT_DIR="${OSK_KIT_DIR:-$HOME/.obsidian-starter-kit}"
CLAUDE_DIR="${OSK_CLAUDE_DIR:-$HOME/.claude}"

# このキットが提供するコマンド名（アンインストール時もこの一覧を使う）
COMMANDS=(vault-init vault-guide vault-save vault-ask vault-lint)
SKILLS=(vault-scaffold vault-operate vault-teach)

# ── 表示ヘルパー ─────────────────────────────────────────────────────────────
if [ -t 1 ]; then
  BOLD=$'\033[1m'; DIM=$'\033[2m'; GREEN=$'\033[32m'; YELLOW=$'\033[33m'
  RED=$'\033[31m'; CYAN=$'\033[36m'; RESET=$'\033[0m'
else
  BOLD=""; DIM=""; GREEN=""; YELLOW=""; RED=""; CYAN=""; RESET=""
fi

say()  { printf '%s\n' "$*"; }
ok()   { printf '%s✓%s %s\n' "$GREEN" "$RESET" "$*"; }
warn() { printf '%s!%s %s\n' "$YELLOW" "$RESET" "$*"; }
die()  { printf '%s✗ %s%s\n' "$RED" "$*" "$RESET" >&2; exit 1; }

say ""
say "${BOLD}Obsidian Starter Kit をインストールします${RESET}"
say "${DIM}Obsidian の vault を Claude Code で作れるようにするキットです${RESET}"
say ""

# ── 1. 前提コマンドの確認 ────────────────────────────────────────────────────
command -v git >/dev/null 2>&1 || die "git が見つかりません。Mac なら App Store の Xcode か、ターミナルで 'xcode-select --install' を実行してください。"

# ── 2. キット本体を取得 or 更新 ──────────────────────────────────────────────
if [ -d "$KIT_DIR/.git" ]; then
  say "キットを更新しています…"
  git -C "$KIT_DIR" fetch --quiet origin
  git -C "$KIT_DIR" reset --hard --quiet origin/HEAD 2>/dev/null \
    || git -C "$KIT_DIR" pull --quiet --ff-only
  ok "更新しました: $KIT_DIR"
elif [ -d "$KIT_DIR" ]; then
  die "$KIT_DIR がありますが git リポジトリではありません。中身を確認して削除してから、もう一度実行してください。"
else
  say "キットをダウンロードしています…"
  git clone --quiet --depth 1 "$REPO_URL" "$KIT_DIR"
  ok "ダウンロードしました: $KIT_DIR"
fi

# ── 3. Claude Code にコマンドとスキルを配置 ──────────────────────────────────
mkdir -p "$CLAUDE_DIR/commands" "$CLAUDE_DIR/skills"

# 前回このキットが入れたものの記録。ここに載っているものだけが上書き・削除の対象。
MANIFEST="$CLAUDE_DIR/.obsidian-starter-kit-manifest"
touch "$MANIFEST"

# 「他人のファイル」= 既に存在するが、このキットが入れた記録が無いもの
in_manifest() { grep -Fxq "$1" "$MANIFEST" 2>/dev/null; }

conflicts=()
for cmd in "${COMMANDS[@]}"; do
  target="commands/$cmd.md"
  if [ -e "$CLAUDE_DIR/$target" ] && ! in_manifest "$target"; then
    conflicts+=("$target")
  fi
done
for skill in "${SKILLS[@]}"; do
  target="skills/$skill"
  if [ -e "$CLAUDE_DIR/$target" ] && ! in_manifest "$target"; then
    conflicts+=("$target")
  fi
done

if [ "${#conflicts[@]}" -gt 0 ] && [ "${OSK_FORCE:-0}" != "1" ]; then
  say ""
  warn "同じ名前のファイルが既にあります。あなたが以前に作ったものかもしれません。"
  for c in "${conflicts[@]}"; do say "    $CLAUDE_DIR/$c"; done
  say ""
  say "上書きせずに中止しました。どちらかを選んでください。"
  say "  A) 既存のものを別名に変えるか、退避してから、もう一度実行する"
  say "  B) 上書きしてよければ、こう実行する:"
  say "       ${CYAN}OSK_FORCE=1 bash $KIT_DIR/install.sh${RESET}"
  say ""
  exit 1
fi

# 上書き前のバックアップ（--force で来た場合の保険）
BACKUP_DIR="$CLAUDE_DIR/.obsidian-starter-kit-backup"
backup_if_needed() {
  local target="$1"
  [ -e "$CLAUDE_DIR/$target" ] || return 0
  in_manifest "$target" && return 0        # 自分が入れたものは退避不要
  mkdir -p "$BACKUP_DIR/$(dirname "$target")"
  cp -R "$CLAUDE_DIR/$target" "$BACKUP_DIR/$target"
}

NEW_MANIFEST="$(mktemp)"

installed_commands=0
for cmd in "${COMMANDS[@]}"; do
  src="$KIT_DIR/commands/$cmd.md"
  [ -f "$src" ] || continue
  backup_if_needed "commands/$cmd.md"
  cp "$src" "$CLAUDE_DIR/commands/$cmd.md"
  printf '%s\n' "commands/$cmd.md" >> "$NEW_MANIFEST"
  installed_commands=$((installed_commands + 1))
done

installed_skills=0
for skill in "${SKILLS[@]}"; do
  src="$KIT_DIR/skills/$skill"
  [ -d "$src" ] || continue
  backup_if_needed "skills/$skill"
  rm -rf "${CLAUDE_DIR:?}/skills/$skill"
  cp -R "$src" "$CLAUDE_DIR/skills/$skill"
  printf '%s\n' "skills/$skill" >> "$NEW_MANIFEST"
  installed_skills=$((installed_skills + 1))
done

mv "$NEW_MANIFEST" "$MANIFEST"

[ "$installed_commands" -gt 0 ] || die "コマンドが1つも見つかりませんでした。リポジトリの中身を確認してください。"
ok "コマンド ${installed_commands} 個 / スキル ${installed_skills} 個 を配置しました"
if [ -d "$BACKUP_DIR" ]; then
  warn "上書きした既存ファイルは $BACKUP_DIR に退避しました"
fi

# ── 4. 周辺ツールの確認（無くても止めない） ──────────────────────────────────
say ""
say "${BOLD}環境を確認します${RESET}"

if command -v claude >/dev/null 2>&1; then
  ok "Claude Code: インストール済み"
  HAS_CLAUDE=1
else
  warn "Claude Code が見つかりません → https://claude.com/product/claude-code から先にインストールしてください"
  HAS_CLAUDE=0
fi

if [ -d "/Applications/Obsidian.app" ] || command -v obsidian >/dev/null 2>&1; then
  ok "Obsidian: インストール済み"
  HAS_OBSIDIAN=1
else
  warn "Obsidian が見つかりません → https://obsidian.md からダウンロードしてください（無料）"
  HAS_OBSIDIAN=0
fi

if command -v obsidian >/dev/null 2>&1; then
  ok "Obsidian CLI: 使えます（Claude Code が Obsidian を直接操作できます）"
else
  say "${DIM}  Obsidian CLI は Obsidian 1.12 以降に付属します。"
  say "  Obsidian の 設定 → General → Command line interface から有効にできます（任意）${RESET}"
fi

# ── 5. 次の一手 ──────────────────────────────────────────────────────────────
say ""
say "${GREEN}${BOLD}インストール完了${RESET}"
say ""
say "${BOLD}次にやること${RESET}"
step=1
if [ "$HAS_OBSIDIAN" -eq 0 ]; then
  say "  ${step}. Obsidian をインストール ${CYAN}https://obsidian.md${RESET}"
  step=$((step + 1))
fi
if [ "$HAS_CLAUDE" -eq 0 ]; then
  say "  ${step}. Claude Code をインストール ${CYAN}https://claude.com/product/claude-code${RESET}"
  step=$((step + 1))
fi
say "  ${BOLD}${step}. vault を置きたい場所でターミナルを開き、こう打つ:${RESET}"
say ""
say "       ${CYAN}claude${RESET}"
say "       ${CYAN}/vault-init${RESET}"
say ""
say "     質問は1つだけです。あとは全部そろった状態で出てきます。"
say ""
say "${DIM}使えるコマンド: /vault-init（作る） /vault-guide（教わる） /vault-save（残す）"
say "                /vault-ask（聞く）   /vault-lint（点検する）"
say "アンインストール: bash $KIT_DIR/uninstall.sh${RESET}"
say ""
