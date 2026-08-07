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

# 「他人のファイル」= 既に存在し、記録にも無く、しかも中身がこのキットと違うもの
in_manifest() { grep -Fxq "$1" "$MANIFEST" 2>/dev/null; }

# 記録が消えていても、中身が同じならそれは以前入れたこのキット自身。他人のものではない。
same_as_kit() {
  local src="$1" dst="$2"
  if [ -f "$src" ] && [ -f "$dst" ]; then
    cmp -s "$src" "$dst"
  elif [ -d "$src" ] && [ -d "$dst" ]; then
    diff -rq "$src" "$dst" >/dev/null 2>&1
  else
    return 1
  fi
}

# 既存が「守るべき他人のファイル」かどうか
is_foreign() {
  local target="$1" src="$2"
  [ -e "$CLAUDE_DIR/$target" ] || return 1        # そもそも無い
  in_manifest "$target" && return 1                # 自分が入れた記録がある
  same_as_kit "$src" "$CLAUDE_DIR/$target" && return 1  # 記録は無いが中身が同じ＝キット自身
  return 0
}

conflicts=()
for cmd in "${COMMANDS[@]}"; do
  target="commands/$cmd.md"
  if is_foreign "$target" "$KIT_DIR/commands/$cmd.md"; then
    conflicts+=("$target")
  fi
done
for skill in "${SKILLS[@]}"; do
  target="skills/$skill"
  if is_foreign "$target" "$KIT_DIR/skills/$skill"; then
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

# 上書き前のバックアップ（OSK_FORCE で来た場合の保険）
# 退避するのは「守るべき他人のファイル」だけ。キット自身を退避すると、
# アンインストール時にそれが書き戻ってコマンドが残ってしまう。
BACKUP_DIR="$CLAUDE_DIR/.obsidian-starter-kit-backup"
backup_if_needed() {
  local target="$1" src="$2"
  is_foreign "$target" "$src" || return 0
  mkdir -p "$BACKUP_DIR/$(dirname "$target")"
  cp -R "$CLAUDE_DIR/$target" "$BACKUP_DIR/$target"
}

NEW_MANIFEST="$(mktemp)"

installed_commands=0
for cmd in "${COMMANDS[@]}"; do
  src="$KIT_DIR/commands/$cmd.md"
  [ -f "$src" ] || continue
  backup_if_needed "commands/$cmd.md" "$src"
  cp "$src" "$CLAUDE_DIR/commands/$cmd.md"
  printf '%s\n' "commands/$cmd.md" >> "$NEW_MANIFEST"
  installed_commands=$((installed_commands + 1))
done

installed_skills=0
for skill in "${SKILLS[@]}"; do
  src="$KIT_DIR/skills/$skill"
  [ -d "$src" ] || continue
  backup_if_needed "skills/$skill" "$src"
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

# ── 5. vault を作る ──────────────────────────────────────────────────────────
# curl | bash で実行されると標準入力がスクリプト本体で埋まるため、
# 対話は /dev/tty から読む。tty が無い環境（CI）では対話をスキップする。
create_vault() {
  local dest="$1" type_dir="$2"
  [ -d "$KIT_DIR/vault-templates/$type_dir" ] || { warn "型 $type_dir が見つかりません"; return 1; }
  if [ -e "$dest" ] && [ -n "$(ls -A "$dest" 2>/dev/null)" ]; then
    warn "$dest は空ではありません。vault は作りませんでした。"
    say "  空のフォルダを指定してもう一度実行してください。"
    return 1
  fi
  mkdir -p "$dest"
  cp -R "$KIT_DIR/vault-templates/$type_dir/." "$dest/"
  find "$dest" -name ".gitkeep" -delete 2>/dev/null || true
  local today; today=$(date +%Y-%m-%d)
  # ログと文脈に日付を入れる
  if [ -f "$dest/_ログ.md" ]; then
    printf '## %s\n\n- vault を作成しました\n' "$today" >> "$dest/_ログ.md"
    sed -i.bak "s/^updated: $/updated: $today/" "$dest/_ログ.md" && rm -f "$dest/_ログ.md.bak"
  fi
  [ -f "$dest/_いまの文脈.md" ] && { sed -i.bak "s/^updated: $/updated: $today/" "$dest/_いまの文脈.md"; rm -f "$dest/_いまの文脈.md.bak"; }
  return 0
}

# フォルダ名を変える。番号プレフィックスは保ち、名前部分だけ差し替える。
# リネームしたら .obsidian の参照と 00_はじめに.md の表も追従させる。
# ここを怠ると「新規ノートの作成先」や「デイリーノートの保存先」が
# 存在しないフォルダを指したままになり、Obsidian 側で黙って壊れる。
rename_folders() {
  local dest="$1"
  local dirs=() d
  while IFS= read -r d; do dirs+=("$(basename "$d")"); done \
    < <(find "$dest" -maxdepth 1 -type d -name "[0-9][0-9]_*" | sort)
  [ "${#dirs[@]}" -eq 0 ] && return 0

  local newnames=()
  if [ -n "${FOLDER_NAMES:-}" ]; then
    IFS=',' read -ra newnames <<< "$FOLDER_NAMES"
  elif [ -r /dev/tty ]; then
    say ""
    say "${BOLD}フォルダ名を変えますか？${RESET}"
    say "  ${DIM}そのままでよければ Enter を押していってください。${RESET}"
    say "  ${DIM}先頭の番号（並び順を固定するためのもの）は自動で付きます。${RESET}"
    say ""
    local ans
    for d in "${dirs[@]}"; do
      printf "  %s → " "$d"
      read -r ans < /dev/tty || ans=""
      newnames+=("$ans")
    done
  else
    return 0
  fi

  local i=0 new prefix old_esc new_esc
  for d in "${dirs[@]}"; do
    new="${newnames[$i]:-}"
    i=$((i + 1))
    [ -z "$new" ] && continue
    prefix="${d%%_*}"
    case "$new" in [0-9][0-9]_*) ;; *) new="${prefix}_${new}" ;; esac
    [ "$new" = "$d" ] && continue
    [ -e "$dest/$new" ] && { warn "$new は既にあります。$d はそのままにしました"; continue; }
    mv "$dest/$d" "$dest/$new"

    # .obsidian の参照を追従
    old_esc=$(printf '%s' "$d" | sed 's/[&/\]/\\&/g')
    new_esc=$(printf '%s' "$new" | sed 's/[&/\]/\\&/g')
    for jf in app.json daily-notes.json graph.json; do
      [ -f "$dest/.obsidian/$jf" ] || continue
      sed -i.bak "s/\"$old_esc\"/\"$new_esc\"/g; s/path:$old_esc/path:$new_esc/g" "$dest/.obsidian/$jf"
      rm -f "$dest/.obsidian/$jf.bak"
    done
    # 00_はじめに.md の表も追従
    if [ -f "$dest/00_はじめに.md" ]; then
      sed -i.bak "s/\`$old_esc\`/\`$new_esc\`/g" "$dest/00_はじめに.md"
      rm -f "$dest/00_はじめに.md.bak"
    fi
    ok "  $d → $new"
  done
}

VAULT_PATH="${OSK_VAULT:-}"
VAULT_TYPE="${OSK_VAULT_TYPE:-}"
FOLDER_NAMES="${OSK_FOLDERS:-}"

# 引数からも受け取れるようにする
#   bash -s -- --vault ~/path --type 2 --folders "受信箱,MTG,案件,手順,人"
while [ $# -gt 0 ]; do
  case "$1" in
    --vault)   VAULT_PATH="$2"; shift 2 ;;
    --type)    VAULT_TYPE="$2"; shift 2 ;;
    --folders) FOLDER_NAMES="$2"; shift 2 ;;
    *) shift ;;
  esac
done

# 引数も環境変数も無く、対話できるなら聞く
if [ -z "$VAULT_PATH" ] && [ -r /dev/tty ]; then
  say ""
  say "${BOLD}続けて vault（ノートの入れ物）を作りますか？${RESET}"
  say "  作らない場合はそのまま Enter を押してください。"
  say ""
  say "  1) 個人のメモをためたい"
  say "  2) 仕事のメモと議事録をためたい"
  say "  3) 勉強したことを残したい"
  say "  4) チームで手順書を共有したい"
  say ""
  printf "  番号を入力（作らないなら Enter）: "
  read -r VAULT_TYPE < /dev/tty || VAULT_TYPE=""
  if [ -n "$VAULT_TYPE" ]; then
    printf "  どこに作りますか？ [%s/Documents/my-vault]: " "$HOME"
    read -r VAULT_PATH < /dev/tty || VAULT_PATH=""
    [ -z "$VAULT_PATH" ] && VAULT_PATH="$HOME/Documents/my-vault"
  fi
fi

VAULT_CREATED=0
if [ -n "$VAULT_PATH" ]; then
  case "${VAULT_TYPE:-1}" in
    1|個人)   TYPE_DIR="1_個人" ;;
    2|仕事)   TYPE_DIR="2_仕事" ;;
    3|学習)   TYPE_DIR="3_学習" ;;
    4|チーム) TYPE_DIR="4_チーム" ;;
    *)        TYPE_DIR="1_個人" ;;
  esac
  # ~ を展開
  VAULT_PATH="${VAULT_PATH/#\~/$HOME}"
  if create_vault "$VAULT_PATH" "$TYPE_DIR"; then
    ok "vault を作りました: $VAULT_PATH"
    rename_folders "$VAULT_PATH"
    VAULT_CREATED=1
  fi
fi

# ── 6. 次の一手 ──────────────────────────────────────────────────────────────
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
if [ "$VAULT_CREATED" -eq 1 ]; then
  say "  ${BOLD}${step}. Obsidian を開いて、この vault を選ぶ:${RESET}"
  say ""
  say "     Obsidian を起動 → ${BOLD}「フォルダを vault として開く」${RESET} →"
  say "     ${CYAN}$VAULT_PATH${RESET} を選ぶ"
  step=$((step + 1))
  say ""
  say "  ${BOLD}${step}. 最初に ${CYAN}00_はじめに${RESET}${BOLD} を読む${RESET}"
  say ""
  say "${DIM}  AI に手伝わせたいときは、この vault のフォルダで claude を起動してください。${RESET}"
else
  say "  ${BOLD}${step}. vault を置きたい場所でターミナルを開き、こう打つ:${RESET}"
  say ""
  say "       ${CYAN}claude${RESET}"
  say "       ${CYAN}/vault-init${RESET}"
  say ""
  say "     質問は1つだけです。あとは全部そろった状態で出てきます。"
fi
say ""
say "${DIM}使えるコマンド: /vault-init（作る） /vault-guide（教わる） /vault-save（残す）"
say "                /vault-ask（聞く）   /vault-lint（点検する）"
say "アンインストール: bash $KIT_DIR/uninstall.sh${RESET}"
say ""
