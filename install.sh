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
COMMANDS=(vault-init vault-guide vault-save vault-ask vault-lint vault-organize)
SKILLS=(vault-scaffold vault-operate vault-teach vault-organize)

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

# すでにある vault を Obsidian の登録情報から拾う。
# Obsidian は開いたことのある vault を obsidian.json に記録している。
list_existing_vaults() {
  node -e '
const fs=require("fs"), os=require("os"), path=require("path");
const home=os.homedir();
const cands=[
  path.join(home,"Library/Application Support/obsidian/obsidian.json"),
  path.join(home,".config/obsidian/obsidian.json"),
  path.join(process.env.APPDATA||"","obsidian","obsidian.json"),
];
for(const p of cands){
  try{
    if(!fs.existsSync(p)) continue;
    const j=JSON.parse(fs.readFileSync(p,"utf8"));
    for(const v of Object.values(j.vaults||{})){
      if(v && v.path && fs.existsSync(v.path)) console.log(v.path);
    }
    break;
  }catch(e){}
}' 2>/dev/null
}

# 既存 vault に「足りないものだけ」足す。既存のノートと設定は絶対に壊さない。
augment_vault() {
  local dest="$1" type_dir="$2"
  local src="$KIT_DIR/vault-templates/$type_dir"
  [ -d "$src" ] || { warn "型 $type_dir が見つかりません"; return 1; }

  # 何が足りないかを先に調べる
  local add_notes=() add_tmpls=() add_bases=() f base
  for f in 00_はじめに.md _ログ.md _いまの文脈.md; do
    [ -f "$dest/$f" ] || add_notes+=("$f")
  done
  if [ -d "$src/Templates" ]; then
    for f in "$src/Templates"/*.md; do
      [ -f "$f" ] || continue
      base=$(basename "$f")
      [ -f "$dest/Templates/$base" ] || add_tmpls+=("$base")
    done
  fi
  for f in "$src"/*.base; do
    [ -f "$f" ] || continue
    base=$(basename "$f")
    [ -f "$dest/$base" ] || add_bases+=("$base")
  done

  # 何も足りなければ終わり
  if [ "${#add_notes[@]}" -eq 0 ] && [ "${#add_tmpls[@]}" -eq 0 ] && [ "${#add_bases[@]}" -eq 0 ]; then
    ok "この vault には必要なものが揃っています。何も足しませんでした"
    return 0
  fi

  # 足すものを見せて確認する
  say ""
  say "${BOLD}この vault に足りないもの:${RESET}"
  [ "${#add_notes[@]}" -gt 0 ] && for f in "${add_notes[@]}"; do say "    $f"; done
  [ "${#add_tmpls[@]}" -gt 0 ] && say "    Templates/ に ${#add_tmpls[@]} 件（${add_tmpls[*]}）"
  [ "${#add_bases[@]}" -gt 0 ] && for f in "${add_bases[@]}"; do say "    $f"; done
  say ""
  say "  ${DIM}既にあるノート・フォルダ・設定は一切変更しません。${RESET}"
  if [ "${OSK_YES:-}" != "1" ]; then
    if [ -r /dev/tty ]; then
      printf "  足しますか？ (Y/n): "
      local ans; read -r ans < /dev/tty || ans=""
      case "$ans" in [nN]*) say "  何もしませんでした"; return 0 ;; esac
    else
      say "  ${DIM}（非対話のため何もしませんでした。OSK_YES=1 で実行すると足します）${RESET}"
      return 0
    fi
  fi

  local today; today=$(date +%Y-%m-%d)
  for f in "${add_notes[@]}"; do
    cp "$src/$f" "$dest/$f"
    if [ "$f" = "_ログ.md" ]; then
      printf '## %s\n\n- このキットの不足分を追加しました\n' "$today" >> "$dest/$f"
    fi
    sed -i.bak "s/^updated: $/updated: $today/" "$dest/$f" 2>/dev/null && rm -f "$dest/$f.bak"
  done
  if [ "${#add_tmpls[@]}" -gt 0 ]; then
    mkdir -p "$dest/Templates"
    for f in "${add_tmpls[@]}"; do cp "$src/Templates/$f" "$dest/Templates/$f"; done
  fi
  for f in "${add_bases[@]}"; do cp "$src/$f" "$dest/$f"; done

  # .obsidian は「既存の値を優先し、無いキーだけ足す」マージにする
  merge_obsidian_config "$dest" "$src"
  ok "足りないものを追加しました"
}

# .obsidian/*.json をマージ。既存の値は絶対に変えず、無いキーだけ補う。
merge_obsidian_config() {
  local dest="$1" src="$2"
  mkdir -p "$dest/.obsidian"
  local jf
  for jf in core-plugins.json app.json templates.json; do
    [ -f "$src/.obsidian/$jf" ] || continue
    if [ ! -f "$dest/.obsidian/$jf" ]; then
      cp "$src/.obsidian/$jf" "$dest/.obsidian/$jf"
      continue
    fi
    cp "$dest/.obsidian/$jf" "$dest/.obsidian/$jf.osk-backup"
    node -e '
const fs=require("fs");
const [dst,srcf]=process.argv.slice(1);
try{
  const cur=JSON.parse(fs.readFileSync(dst,"utf8"));
  const add=JSON.parse(fs.readFileSync(srcf,"utf8"));
  let changed=false;
  for(const k of Object.keys(add)){
    if(!(k in cur)){ cur[k]=add[k]; changed=true; }   // 既存の値は上書きしない
  }
  if(changed) fs.writeFileSync(dst, JSON.stringify(cur,null,2));
}catch(e){}' "$dest/.obsidian/$jf" "$src/.obsidian/$jf"
  done
}

# Hermes（Nous Research の AI エージェント）が入っていれば、作った vault を教える。
#
# Hermes の Obsidian 連携は「メモリプロバイダ」ではなく note-taking/obsidian という
# 同梱スキルで、vault の場所は OBSIDIAN_VAULT_PATH 環境変数で決まる（$HERMES_HOME/.env に書く）。
# 未設定だと ~/Documents/Obsidian Vault を黙って見に行き、しかも
# 「どこを見ているか」を知らせる仕組みが無いため、明示的に設定する意味がある。
#
# .env には API キーなどが入っているので、OBSIDIAN_VAULT_PATH の行以外は絶対に触らない。
link_hermes() {
  local vault="$1"
  local hermes_home="${HERMES_HOME:-$HOME/.hermes}"
  [ -d "$hermes_home" ] || return 0          # Hermes を使っていなければ何もしない
  local envfile="$hermes_home/.env"

  if [ -f "$envfile" ] && grep -q "^OBSIDIAN_VAULT_PATH=" "$envfile" 2>/dev/null; then
    local current
    current=$(grep "^OBSIDIAN_VAULT_PATH=" "$envfile" | head -1 | cut -d= -f2- | sed 's/^"//; s/"$//')
    if [ "$current" = "$vault" ]; then
      ok "Hermes は既にこの vault を見ています"
      return 0
    fi
    say ""
    warn "Hermes は別の vault を見ています:"
    say "    $current"
    if [ "${OSK_HERMES:-}" = "1" ]; then
      :                                       # 非対話で明示的に指定されたら切り替える
    elif [ -r /dev/tty ]; then
      printf "  この vault に切り替えますか？ (y/N): "
      local ans; read -r ans < /dev/tty || ans=""
      case "$ans" in [yY]*) ;; *) say "  そのままにしました"; return 0 ;; esac
    else
      return 0
    fi
    cp "$envfile" "$envfile.osk-backup"
    grep -v "^OBSIDIAN_VAULT_PATH=" "$envfile" > "$envfile.tmp" && mv "$envfile.tmp" "$envfile"
    say "  ${DIM}（元の .env は $envfile.osk-backup に退避しました）${RESET}"
  elif [ "${OSK_HERMES:-}" != "1" ] && [ -r /dev/tty ]; then
    say ""
    say "${BOLD}Hermes が見つかりました。${RESET}この vault を Hermes にも教えますか？"
    say "  ${DIM}教えると、Hermes からこの vault のノートを読み書きできます。${RESET}"
    printf "  教える？ (Y/n): "
    local ans; read -r ans < /dev/tty || ans=""
    case "$ans" in [nN]*) say "  そのままにしました"; return 0 ;; esac
  elif [ "${OSK_HERMES:-}" != "1" ]; then
    return 0
  fi

  touch "$envfile"
  printf 'OBSIDIAN_VAULT_PATH="%s"\n' "$vault" >> "$envfile"
  ok "Hermes にこの vault を教えました"
  say "  ${DIM}$envfile に OBSIDIAN_VAULT_PATH を設定${RESET}"
  say "  ${DIM}確認: hermes を起動して「vault のファイル一覧を出して」と頼むと、"
  say "        どこを見ているか分かります${RESET}"
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

AUGMENT_MODE=0

# 引数も環境変数も無く、対話できるなら聞く
if [ -z "$VAULT_PATH" ] && [ -r /dev/tty ]; then
  # すでに Obsidian を使っているなら、既存 vault を選べるようにする
  EXISTING=()
  while IFS= read -r line; do [ -n "$line" ] && EXISTING+=("$line"); done < <(list_existing_vaults)

  say ""
  if [ "${#EXISTING[@]}" -gt 0 ]; then
    say "${BOLD}すでに Obsidian を使っていますね。${RESET}どうしますか？"
    say "  ${DIM}何もしない場合はそのまま Enter を押してください。${RESET}"
    say ""
    say "  ${BOLD}n) 新しく vault を作る${RESET}"
    say ""
    say "  ${BOLD}または、いま使っている vault に足りないものだけ足す:${RESET}"
    vault_i=1
    for v in "${EXISTING[@]}"; do
      say "  $vault_i) $v"
      vault_i=$((vault_i + 1))
    done
    say ""
    printf "  番号か n を入力（何もしないなら Enter）: "
    read -r CHOICE < /dev/tty || CHOICE=""
    case "$CHOICE" in
      "") : ;;
      [nN]*) : ;;   # 新規作成へ進む（下の分岐で型を聞く）
      *[!0-9]*) warn "番号として読めませんでした。何もしません" ;;
      *)
        idx=$((CHOICE - 1))
        if [ "$idx" -ge 0 ] && [ "$idx" -lt "${#EXISTING[@]}" ]; then
          VAULT_PATH="${EXISTING[$idx]}"
          AUGMENT_MODE=1
        else
          warn "その番号の vault はありません。何もしません"
        fi
        ;;
    esac
  else
    CHOICE="n"
  fi

  # 新規作成の場合だけ型と場所を聞く
  WANT_NEW=0
  case "$CHOICE" in [nN]*) WANT_NEW=1 ;; esac
  if [ "$AUGMENT_MODE" -eq 0 ] && [ "$WANT_NEW" -eq 1 ]; then
    say ""
    say "${BOLD}どんな vault を作りますか？${RESET}"
    say ""
    say "  1) 個人のメモをためたい"
    say "  2) 仕事のメモと議事録をためたい"
    say "  3) 勉強したことを残したい"
    say "  4) チームで手順書を共有したい"
    say ""
    say "  ${BOLD}5) 全部やりたい（1〜3をまとめた形）${RESET}"
    say "     ${DIM}どれか1つに決められないとき。フォルダは後から減らせます${RESET}"
    say ""
    say "  ${BOLD}6) 用途を伝えて、AI に構造から設計してもらう${RESET}"
    say "     ${DIM}上に当てはまらないとき。Claude Code が必要です${RESET}"
    say ""
    printf "  番号を入力（やめるなら Enter）: "
    read -r VAULT_TYPE < /dev/tty || VAULT_TYPE=""
    if [ "$VAULT_TYPE" = "6" ]; then
      say ""
      say "${BOLD}AI に設計してもらう場合の手順:${RESET}"
      say ""
      say "  1. vault を置きたい場所に空のフォルダを作る"
      say "  2. そのフォルダでターミナルを開いて ${CYAN}claude${RESET} と打つ"
      say "  3. ${CYAN}/vault-init${RESET} と打つ"
      say ""
      say "  「この vault は何のために使いますか？」と聞かれるので、"
      say "  ${BOLD}やりたいことをそのまま書いてください。${RESET}"
      say "  ${DIM}例：顧客からもらった資料を整理して、打ち合わせの記録も残したい${RESET}"
      say ""
      say "  用途に合わせて、必要なフォルダだけを作ります。"
      VAULT_TYPE=""
    fi
    if [ -n "$VAULT_TYPE" ]; then
      printf "  どこに作りますか？ [%s/Documents/my-vault]: " "$HOME"
      read -r VAULT_PATH < /dev/tty || VAULT_PATH=""
      [ -z "$VAULT_PATH" ] && VAULT_PATH="$HOME/Documents/my-vault"
    fi
  fi
fi

# 引数で既存 vault を指定された場合も検知する（--vault が既に vault なら足すモード）
if [ -n "$VAULT_PATH" ] && [ "$AUGMENT_MODE" -eq 0 ]; then
  expanded="${VAULT_PATH/#\~/$HOME}"
  [ -d "$expanded/.obsidian" ] && { AUGMENT_MODE=1; VAULT_PATH="$expanded"; }
fi

VAULT_CREATED=0
if [ -n "$VAULT_PATH" ]; then
  case "${VAULT_TYPE:-1}" in
    1|個人)   TYPE_DIR="1_個人" ;;
    2|仕事)   TYPE_DIR="2_仕事" ;;
    3|学習)   TYPE_DIR="3_学習" ;;
    4|チーム) TYPE_DIR="4_チーム" ;;
    5|全部)   TYPE_DIR="5_全部" ;;
    *)        TYPE_DIR="1_個人" ;;
  esac
  VAULT_PATH="${VAULT_PATH/#\~/$HOME}"

  # 全部入りを選んだ人には、チーム共有だけは分けたほうがいいと伝える
  if [ "$TYPE_DIR" = "5_全部" ]; then
    say ""
    say "${DIM}  ※ チームで共有する vault は、これとは別に作ることをおすすめします。${RESET}"
    say "${DIM}    個人の日記が混ざった vault を共有すると事故になります。${RESET}"
  fi

  if [ "$AUGMENT_MODE" -eq 1 ]; then
    # 既存 vault：足りないものだけ足す。フォルダ構成は既存を尊重し、勝手に増やさない
    say ""
    say "${BOLD}既にある vault を調べます:${RESET} $VAULT_PATH"
    if augment_vault "$VAULT_PATH" "$TYPE_DIR"; then
      link_hermes "$VAULT_PATH"
      VAULT_CREATED=2
    fi
  elif create_vault "$VAULT_PATH" "$TYPE_DIR"; then
    ok "vault を作りました: $VAULT_PATH"
    rename_folders "$VAULT_PATH"
    link_hermes "$VAULT_PATH"
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
if [ "$VAULT_CREATED" -eq 2 ]; then
  # 既存 vault に足したときは、散らかっていれば整理も案内する
  if [ -n "${VAULT_PATH:-}" ] && [ -d "$VAULT_PATH" ]; then
    deep=$(find "$VAULT_PATH" -name "*.md" -not -path "*/.obsidian/*" -not -path "*/.git/*" \
             -not -path "*/.claude/*" 2>/dev/null | awk -F/ '{print NF}' | sort -rn | head -1)
    rootmd=$(find "$VAULT_PATH" -maxdepth 1 -name "*.md" 2>/dev/null | wc -l | tr -d ' ')
    basedepth=$(printf '%s' "$VAULT_PATH" | awk -F/ '{print NF}')
    reldepth=$(( ${deep:-0} - basedepth ))
    if [ "$reldepth" -gt 3 ] || [ "$rootmd" -ge 10 ]; then
      say ""
      say "${YELLOW}!${RESET} この vault は少し散らかっているようです（最大 ${reldepth} 階層 / ルート直下に .md が ${rootmd} 件）"
      say "  ${BOLD}整理したい場合は、この vault のフォルダで:${RESET}"
      say "       ${CYAN}claude${RESET}"
      say "       ${CYAN}/vault-organize${RESET}"
      say "  ${DIM}まず診断だけして、移動する前に必ず一覧で見せます。勝手には動かしません。${RESET}"
    fi
  fi
  say "  ${BOLD}${step}. Obsidian でこの vault を開き直す:${RESET}"
  say ""
  say "     ${CYAN}$VAULT_PATH${RESET}"
  say ""
  say "     ${DIM}開いている場合は、一度閉じて開き直すと設定が反映されます。${RESET}"
  step=$((step + 1))
  say ""
  say "  ${BOLD}${step}. 追加された ${CYAN}00_はじめに${RESET}${BOLD} を読む${RESET}"
  say ""
  say "${DIM}  既にあったノート・フォルダ・設定は変更していません。${RESET}"
elif [ "$VAULT_CREATED" -eq 1 ]; then
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
say "${DIM}使えるコマンド: /vault-init（作る）     /vault-guide（教わる） /vault-save（残す）"
say "                /vault-ask（聞く）     /vault-lint（点検する）"
say "                /vault-organize（散らかった vault を整理する）"
say "アンインストール: bash $KIT_DIR/uninstall.sh${RESET}"
say ""
