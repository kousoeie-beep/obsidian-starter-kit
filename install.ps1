# ============================================================================
#  Obsidian Starter Kit — インストーラ（Windows / PowerShell 版）
#
#  使い方（PowerShell に1行貼るだけ）:
#    [Net.ServicePointManager]::SecurityProtocol=[Net.SecurityProtocolType]::Tls12; irm https://raw.githubusercontent.com/kousoeie-beep/obsidian-starter-kit/main/install.ps1 | iex
#
#  先頭の TLS 指定は Windows PowerShell 5.1 対策。5.1 は環境によって既定の
#  セキュリティプロトコルが TLS 1.2 でなく、GitHub への接続が無言で失敗する。
#
#  何をするか:
#    1. キット本体を %USERPROFILE%\.obsidian-starter-kit に取得（2回目以降は更新）
#    2. Claude Code のコマンドとスキルを %USERPROFILE%\.claude\ に配置
#    3. Obsidian と Claude Code が入っているか確認して、次の一手を表示
#
#  同名のファイルが既にある場合は、上書きせずに中止します。
# ============================================================================

$ErrorActionPreference = 'Stop'

$RepoUrl   = if ($env:OSK_REPO_URL)   { $env:OSK_REPO_URL }   else { 'https://github.com/kousoeie-beep/obsidian-starter-kit.git' }
$KitDir    = if ($env:OSK_KIT_DIR)    { $env:OSK_KIT_DIR }    else { Join-Path $HOME '.obsidian-starter-kit' }
$ClaudeDir = if ($env:OSK_CLAUDE_DIR) { $env:OSK_CLAUDE_DIR } else { Join-Path $HOME '.claude' }

$Commands = @('vault-init','vault-guide','vault-save','vault-ask','vault-lint')
$Skills   = @('vault-scaffold','vault-operate','vault-teach')

function Say  { param($m) Write-Host $m }
function Ok   { param($m) Write-Host "✓ $m" -ForegroundColor Green }
function Warn { param($m) Write-Host "! $m" -ForegroundColor Yellow }
function Die  { param($m) Write-Host "✗ $m" -ForegroundColor Red; exit 1 }

Say ""
Say "Obsidian Starter Kit をインストールします"
Say "Obsidian の vault を Claude Code で作れるようにするキットです"
Say ""

# ── 1. 前提コマンドの確認 ────────────────────────────────────────────────────
if (-not (Get-Command git -ErrorAction SilentlyContinue)) {
    Die "git が見つかりません。https://git-scm.com/download/win からインストールしてください。"
}

# ── 2. キット本体を取得 or 更新 ──────────────────────────────────────────────
if (Test-Path (Join-Path $KitDir '.git')) {
    Say "キットを更新しています…"
    git -C $KitDir fetch --quiet origin
    git -C $KitDir pull --quiet --ff-only
    Ok "更新しました: $KitDir"
} elseif (Test-Path $KitDir) {
    Die "$KitDir がありますが git リポジトリではありません。中身を確認して削除してから、もう一度実行してください。"
} else {
    Say "キットをダウンロードしています…"
    git clone --quiet --depth 1 $RepoUrl $KitDir
    Ok "ダウンロードしました: $KitDir"
}

# ── 3. Claude Code にコマンドとスキルを配置 ──────────────────────────────────
New-Item -ItemType Directory -Force -Path (Join-Path $ClaudeDir 'commands') | Out-Null
New-Item -ItemType Directory -Force -Path (Join-Path $ClaudeDir 'skills')   | Out-Null

$ManifestPath = Join-Path $ClaudeDir '.obsidian-starter-kit-manifest'
$Manifest = if (Test-Path $ManifestPath) { Get-Content $ManifestPath } else { @() }

# 記録が消えていても、中身が同じならそれは以前入れたこのキット自身。他人のものではない。
function Test-SameAsKit {
    param($Src, $Dst)
    if (-not (Test-Path $Src) -or -not (Test-Path $Dst)) { return $false }
    $srcIsDir = (Get-Item $Src).PSIsContainer
    $dstIsDir = (Get-Item $Dst).PSIsContainer
    if ($srcIsDir -ne $dstIsDir) { return $false }
    if (-not $srcIsDir) {
        return (Get-FileHash $Src).Hash -eq (Get-FileHash $Dst).Hash
    }
    # ディレクトリ：相対パス＋ハッシュの一覧が一致するか
    function Get-Fingerprint($root) {
        Get-ChildItem $root -Recurse -File | ForEach-Object {
            "$($_.FullName.Substring($root.Length))|$((Get-FileHash $_.FullName).Hash)"
        } | Sort-Object
    }
    $a = @(Get-Fingerprint (Resolve-Path $Src).Path)
    $b = @(Get-Fingerprint (Resolve-Path $Dst).Path)
    if ($a.Count -ne $b.Count) { return $false }
    return -not (Compare-Object $a $b)
}

# 既存が「守るべき他人のファイル」かどうか
function Test-Foreign {
    param($Rel, $Src)
    $dst = Join-Path $ClaudeDir $Rel
    if (-not (Test-Path $dst))        { return $false }  # そもそも無い
    if ($Manifest -contains $Rel)     { return $false }  # 自分が入れた記録がある
    if (Test-SameAsKit $Src $dst)     { return $false }  # 記録は無いが中身が同じ＝キット自身
    return $true
}

$conflicts = @()
foreach ($cmd in $Commands) {
    $rel = "commands/$cmd.md"
    if (Test-Foreign $rel (Join-Path (Join-Path $KitDir "commands") "$cmd.md")) { $conflicts += $rel }
}
foreach ($skill in $Skills) {
    $rel = "skills/$skill"
    if (Test-Foreign $rel (Join-Path (Join-Path $KitDir "skills") "$skill")) { $conflicts += $rel }
}

if ($conflicts.Count -gt 0 -and $env:OSK_FORCE -ne '1') {
    Say ""
    Warn "同じ名前のファイルが既にあります。あなたが以前に作ったものかもしれません。"
    foreach ($c in $conflicts) { Say "    $ClaudeDir\$c" }
    Say ""
    Say "上書きせずに中止しました。上書きしてよければ、こう実行してください:"
    Say "  `$env:OSK_FORCE='1'; powershell -ExecutionPolicy Bypass -File $KitDir\install.ps1"
    Say ""
    exit 1
}

$BackupDir = Join-Path $ClaudeDir '.obsidian-starter-kit-backup'
$NewManifest = @()

$installedCommands = 0
foreach ($cmd in $Commands) {
    $src = Join-Path (Join-Path $KitDir "commands") "$cmd.md"
    if (-not (Test-Path $src)) { continue }
    $rel = "commands/$cmd.md"
    $dst = Join-Path $ClaudeDir $rel
    # 退避するのは守るべき他人のファイルだけ。キット自身を退避すると
    # アンインストール時に書き戻ってコマンドが残る。
    if (Test-Foreign $rel $src) {
        New-Item -ItemType Directory -Force -Path (Join-Path $BackupDir 'commands') | Out-Null
        Copy-Item $dst (Join-Path $BackupDir $rel) -Force
    }
    Copy-Item $src $dst -Force
    $NewManifest += $rel
    $installedCommands++
}

$installedSkills = 0
foreach ($skill in $Skills) {
    $src = Join-Path (Join-Path $KitDir "skills") "$skill"
    if (-not (Test-Path $src)) { continue }
    $rel = "skills/$skill"
    $dst = Join-Path $ClaudeDir $rel
    if (Test-Foreign $rel $src) {
        New-Item -ItemType Directory -Force -Path (Join-Path $BackupDir 'skills') | Out-Null
        Copy-Item $dst (Join-Path $BackupDir $rel) -Recurse -Force
    }
    if (Test-Path $dst) { Remove-Item $dst -Recurse -Force }
    Copy-Item $src $dst -Recurse -Force
    $NewManifest += $rel
    $installedSkills++
}

$NewManifest | Set-Content $ManifestPath

if ($installedCommands -eq 0) { Die "コマンドが1つも見つかりませんでした。リポジトリの中身を確認してください。" }
Ok "コマンド $installedCommands 個 / スキル $installedSkills 個 を配置しました"
if (Test-Path $BackupDir) { Warn "上書きした既存ファイルは $BackupDir に退避しました" }

# ── 4. 周辺ツールの確認 ──────────────────────────────────────────────────────
Say ""
Say "環境を確認します"

$hasClaude = [bool](Get-Command claude -ErrorAction SilentlyContinue)
if ($hasClaude) { Ok "Claude Code: インストール済み" }
else { Warn "Claude Code が見つかりません → https://claude.com/product/claude-code" }

$obsidianPaths = @(
    (Join-Path $env:LOCALAPPDATA 'Obsidian\Obsidian.exe'),
    (Join-Path ${env:ProgramFiles} 'Obsidian\Obsidian.exe')
)
$hasObsidian = ($obsidianPaths | Where-Object { Test-Path $_ }).Count -gt 0
if ($hasObsidian) { Ok "Obsidian: インストール済み" }
else { Warn "Obsidian が見つかりません → https://obsidian.md （無料）" }

# ── 5. 次の一手 ──────────────────────────────────────────────────────────────
Say ""
Write-Host "インストール完了" -ForegroundColor Green
Say ""
Say "次にやること"
$step = 1
if (-not $hasObsidian) { Say "  $step. Obsidian をインストール https://obsidian.md"; $step++ }
if (-not $hasClaude)   { Say "  $step. Claude Code をインストール https://claude.com/product/claude-code"; $step++ }
Say "  $step. vault を置きたい場所で PowerShell を開き、こう打つ:"
Say ""
Say "       claude"
Say "       /vault-init"
Say ""
Say "     質問は1つだけです。あとは全部そろった状態で出てきます。"
Say ""
Say "使えるコマンド: /vault-init（作る） /vault-guide（教わる） /vault-save（残す）"
Say "                /vault-ask（聞く）   /vault-lint（点検する）"
Say "アンインストール: powershell -ExecutionPolicy Bypass -File $KitDir\uninstall.ps1"
Say ""
