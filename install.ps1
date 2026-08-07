# ============================================================================
#  Obsidian Starter Kit — インストーラ（Windows / PowerShell 版）
#
#  使い方（PowerShell に1行貼るだけ）:
#    [Net.ServicePointManager]::SecurityProtocol=[Net.SecurityProtocolType]::Tls12; iex ((irm https://raw.githubusercontent.com/kousoeie-beep/obsidian-starter-kit/main/install.ps1).TrimStart([char]0xFEFF))
#
#  1行が長いのには理由が2つある:
#   - 先頭の TLS 指定は Windows PowerShell 5.1 対策。5.1 は環境によって既定の
#     セキュリティプロトコルが TLS 1.2 でなく、GitHub への接続が無言で失敗する。
#   - TrimStart([char]0xFEFF) はこのファイルの BOM を落とすため。
#     このファイルは日本語を含むので UTF-8 BOM 付きで保存する必要がある
#     （BOM が無いと 5.1 が ANSI として読み、構文エラーになる）。
#     一方 irm | iex では BOM が文字列の先頭に残り、iex がコマンド名と誤認する。
#     ファイル実行には BOM が要り、iex には BOM が邪魔、という板挟みの解決策。
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
    $a = @(Get-Fingerprint (Resolve-Path $Src).Path.TrimEnd('\', '/'))
    $b = @(Get-Fingerprint (Resolve-Path $Dst).Path.TrimEnd('\', '/'))
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

# ── 5. vault を作る ──────────────────────────────────────────────────────────
function New-Vault {
    param($Dest, $TypeDir)
    $src = Join-Path (Join-Path $KitDir 'vault-templates') $TypeDir
    if (-not (Test-Path $src)) { Warn "型 $TypeDir が見つかりません"; return $false }
    if ((Test-Path $Dest) -and (Get-ChildItem $Dest -Force -EA SilentlyContinue).Count -gt 0) {
        Warn "$Dest は空ではありません。vault は作りませんでした。"
        Say "  空のフォルダを指定してもう一度実行してください。"
        return $false
    }
    New-Item -ItemType Directory -Force -Path $Dest | Out-Null
    Copy-Item (Join-Path $src '*') $Dest -Recurse -Force
    Get-ChildItem $Dest -Recurse -Force -Filter ".gitkeep" | Remove-Item -Force
    $today = Get-Date -Format 'yyyy-MM-dd'
    $logPath = Join-Path $Dest '_ログ.md'
    if (Test-Path $logPath) {
        (Get-Content $logPath -Raw).Replace("updated: `n", "updated: $today`n") | Set-Content $logPath -NoNewline
        Add-Content $logPath "## $today`n`n- vault を作成しました`n"
    }
    $ctxPath = Join-Path $Dest '_いまの文脈.md'
    if (Test-Path $ctxPath) {
        (Get-Content $ctxPath -Raw).Replace("updated: `n", "updated: $today`n") | Set-Content $ctxPath -NoNewline
    }
    return $true
}

# すでにある vault を Obsidian の登録情報から拾う。
function Get-ExistingVaults {
    $cands = @(
        (Join-Path $env:APPDATA 'obsidian\obsidian.json'),
        (Join-Path $HOME 'Library/Application Support/obsidian/obsidian.json'),
        (Join-Path $HOME '.config/obsidian/obsidian.json')
    )
    foreach ($p in $cands) {
        if (-not (Test-Path $p)) { continue }
        try {
            $j = Get-Content $p -Raw | ConvertFrom-Json
            $out = @()
            foreach ($v in $j.vaults.PSObject.Properties) {
                $path = $v.Value.path
                if ($path -and (Test-Path $path)) { $out += $path }
            }
            return $out
        } catch { return @() }
    }
    return @()
}

# 既存 vault に「足りないものだけ」足す。既存のノートと設定は絶対に壊さない。
function Update-Vault {
    param($Dest, $TypeDir)
    $src = Join-Path (Join-Path $KitDir 'vault-templates') $TypeDir
    if (-not (Test-Path $src)) { Warn "型 $TypeDir が見つかりません"; return $false }

    $addNotes = @(); $addTmpls = @(); $addBases = @()
    foreach ($f in @('00_はじめに.md','_ログ.md','_いまの文脈.md')) {
        if (-not (Test-Path (Join-Path $Dest $f))) { $addNotes += $f }
    }
    $srcTmpl = Join-Path $src 'Templates'
    if (Test-Path $srcTmpl) {
        foreach ($f in (Get-ChildItem $srcTmpl -Filter '*.md')) {
            if (-not (Test-Path (Join-Path (Join-Path $Dest 'Templates') $f.Name))) { $addTmpls += $f.Name }
        }
    }
    foreach ($f in (Get-ChildItem $src -Filter '*.base' -EA SilentlyContinue)) {
        if (-not (Test-Path (Join-Path $Dest $f.Name))) { $addBases += $f.Name }
    }

    if ($addNotes.Count -eq 0 -and $addTmpls.Count -eq 0 -and $addBases.Count -eq 0) {
        Ok "この vault には必要なものが揃っています。何も足しませんでした"
        return $true
    }

    Say ""
    Say "この vault に足りないもの:"
    foreach ($f in $addNotes) { Say "    $f" }
    if ($addTmpls.Count -gt 0) { Say "    Templates/ に $($addTmpls.Count) 件（$($addTmpls -join ' ')）" }
    foreach ($f in $addBases) { Say "    $f" }
    Say ""
    Say "  既にあるノート・フォルダ・設定は一切変更しません。"
    if ($env:OSK_YES -ne '1') {
        $ans = Read-Host "  足しますか？ (Y/n)"
        if ($ans -match '^[nN]') { Say "  何もしませんでした"; return $true }
    }

    $today = Get-Date -Format 'yyyy-MM-dd'
    foreach ($f in $addNotes) {
        Copy-Item (Join-Path $src $f) (Join-Path $Dest $f) -Force
        $p = Join-Path $Dest $f
        (Get-Content $p -Raw).Replace("updated: `n", "updated: $today`n") | Set-Content $p -NoNewline -Encoding UTF8
        if ($f -eq '_ログ.md') { Add-Content $p "## $today`n`n- このキットの不足分を追加しました`n" }
    }
    if ($addTmpls.Count -gt 0) {
        New-Item -ItemType Directory -Force -Path (Join-Path $Dest 'Templates') | Out-Null
        foreach ($f in $addTmpls) { Copy-Item (Join-Path $srcTmpl $f) (Join-Path (Join-Path $Dest 'Templates') $f) -Force }
    }
    foreach ($f in $addBases) { Copy-Item (Join-Path $src $f) (Join-Path $Dest $f) -Force }

    # .obsidian は既存の値を優先し、無いキーだけ補う
    $dstCfg = Join-Path $Dest '.obsidian'
    New-Item -ItemType Directory -Force -Path $dstCfg | Out-Null
    foreach ($jf in @('core-plugins.json','app.json','templates.json')) {
        $sp = Join-Path (Join-Path $src '.obsidian') $jf
        $dp = Join-Path $dstCfg $jf
        if (-not (Test-Path $sp)) { continue }
        if (-not (Test-Path $dp)) { Copy-Item $sp $dp -Force; continue }
        try {
            Copy-Item $dp "$dp.osk-backup" -Force
            $cur = Get-Content $dp -Raw | ConvertFrom-Json
            $add = Get-Content $sp -Raw | ConvertFrom-Json
            $changed = $false
            foreach ($k in $add.PSObject.Properties.Name) {
                if (-not $cur.PSObject.Properties.Name.Contains($k)) {
                    $cur | Add-Member -NotePropertyName $k -NotePropertyValue $add.$k
                    $changed = $true
                }
            }
            if ($changed) { $cur | ConvertTo-Json -Depth 10 | Set-Content $dp -Encoding UTF8 }
        } catch {}
    }
    Ok "足りないものを追加しました"
    return $true
}

# フォルダ名を変える。番号プレフィックスは保ち、名前部分だけ差し替える。
# リネームしたら .obsidian の参照と 00_はじめに.md の表も追従させること。
# 怠ると「新規ノートの作成先」が存在しないフォルダを指したまま黙って壊れる。
function Rename-Folders {
    param($Dest)
    $dirs = @(Get-ChildItem $Dest -Directory | Where-Object { $_.Name -match '^\d\d_' } | Sort-Object Name)
    if ($dirs.Count -eq 0) { return }

    $newnames = @()
    if ($FolderNames) {
        $newnames = $FolderNames -split ','
    } elseif (-not $env:CI) {
        Say ""
        Say "フォルダ名を変えますか？"
        Say "  そのままでよければ Enter を押していってください。"
        Say "  先頭の番号（並び順を固定するためのもの）は自動で付きます。"
        Say ""
        foreach ($d in $dirs) { $newnames += (Read-Host "  $($d.Name) → ") }
    } else { return }

    for ($i = 0; $i -lt $dirs.Count; $i++) {
        $old = $dirs[$i].Name
        $new = if ($i -lt $newnames.Count) { $newnames[$i].Trim() } else { '' }
        if (-not $new) { continue }
        $prefix = $old.Split('_')[0]
        if ($new -notmatch '^\d\d_') { $new = "${prefix}_$new" }
        if ($new -eq $old) { continue }
        if (Test-Path (Join-Path $Dest $new)) { Warn "$new は既にあります。$old はそのままにしました"; continue }
        Rename-Item (Join-Path $Dest $old) $new

        foreach ($jf in @('app.json','daily-notes.json','graph.json')) {
            $p = Join-Path (Join-Path $Dest '.obsidian') $jf
            if (Test-Path $p) {
                (Get-Content $p -Raw).Replace("`"$old`"", "`"$new`"").Replace("path:$old", "path:$new") |
                    Set-Content $p -NoNewline -Encoding UTF8
            }
        }
        $intro = Join-Path $Dest '00_はじめに.md'
        if (Test-Path $intro) {
            (Get-Content $intro -Raw).Replace("``$old``", "``$new``") | Set-Content $intro -NoNewline -Encoding UTF8
        }
        Ok "  $old → $new"
    }
}

$VaultPath = $env:OSK_VAULT
$VaultType = $env:OSK_VAULT_TYPE
$FolderNames = $env:OSK_FOLDERS

# 引数からも受け取る（--vault <path> --type <n> --folders "A,B,C"）
for ($i = 0; $i -lt $args.Count; $i++) {
    if ($args[$i] -in @('--vault','-Vault')) { $VaultPath = $args[$i+1]; $i++ }
    elseif ($args[$i] -in @('--type','-Type')) { $VaultType = $args[$i+1]; $i++ }
    elseif ($args[$i] -in @('--folders','-Folders')) { $FolderNames = $args[$i+1]; $i++ }
}

$AugmentMode = $false

# 対話（irm | iex でも Read-Host は使える）
if (-not $VaultPath -and -not $env:CI) {
    $existing = @(Get-ExistingVaults)
    $wantNew = $true
    if ($existing.Count -gt 0) {
        Say ""
        Say "すでに Obsidian を使っていますね。どうしますか？"
        Say "  何もしない場合はそのまま Enter を押してください。"
        Say ""
        Say "  n) 新しく vault を作る"
        Say ""
        Say "  または、いま使っている vault に足りないものだけ足す:"
        for ($i = 0; $i -lt $existing.Count; $i++) { Say "  $($i+1)) $($existing[$i])" }
        Say ""
        $choice = Read-Host "  番号か n を入力（何もしないなら Enter）"
        if (-not $choice) { $wantNew = $false }
        elseif ($choice -match '^[nN]') { $wantNew = $true }
        elseif ($choice -match '^\d+$') {
            $idx = [int]$choice - 1
            if ($idx -ge 0 -and $idx -lt $existing.Count) {
                $VaultPath = $existing[$idx]; $AugmentMode = $true; $wantNew = $false
            } else { Warn "その番号の vault はありません。何もしません"; $wantNew = $false }
        } else { Warn "番号として読めませんでした。何もしません"; $wantNew = $false }
    }

    if (-not $AugmentMode -and $wantNew) {
        Say ""
        Say "どんな vault を作りますか？"
        Say ""
        Say "  1) 個人のメモをためたい"
        Say "  2) 仕事のメモと議事録をためたい"
        Say "  3) 勉強したことを残したい"
        Say "  4) チームで手順書を共有したい"
        Say ""
        $VaultType = Read-Host "  番号を入力（やめるなら Enter）"
        if ($VaultType) {
            $defaultPath = Join-Path $HOME 'Documents\my-vault'
            $inputPath = Read-Host "  どこに作りますか？ [$defaultPath]"
            $VaultPath = if ($inputPath) { $inputPath } else { $defaultPath }
        }
    }
}

# 引数で既存 vault を指定された場合も検知する
if ($VaultPath -and -not $AugmentMode) {
    if (Test-Path (Join-Path $VaultPath '.obsidian')) { $AugmentMode = $true }
}

$VaultCreated = $false
if ($VaultPath) {
    $typeDir = switch ("$VaultType") {
        '1' { '1_個人' }; '2' { '2_仕事' }; '3' { '3_学習' }; '4' { '4_チーム' }
        default { '1_個人' }
    }
    if ($AugmentMode) {
        Say ""
        Say "既にある vault を調べます: $VaultPath"
        if (Update-Vault $VaultPath $typeDir) { $VaultCreated = $true }
    } elseif (New-Vault $VaultPath $typeDir) {
        Ok "vault を作りました: $VaultPath"
        Rename-Folders $VaultPath
        $VaultCreated = $true
    }
}

# ── 6. 次の一手 ──────────────────────────────────────────────────────────────
Say ""
Write-Host "インストール完了" -ForegroundColor Green
Say ""
Say "次にやること"
$step = 1
if (-not $hasObsidian) { Say "  $step. Obsidian をインストール https://obsidian.md"; $step++ }
if (-not $hasClaude)   { Say "  $step. Claude Code をインストール https://claude.com/product/claude-code"; $step++ }
if ($VaultCreated) {
    Say "  $step. Obsidian を開いて、この vault を選ぶ:"
    Say ""
    Say "     Obsidian を起動 → 「フォルダを vault として開く」 →"
    Say "     $VaultPath を選ぶ"
    $step++
    Say ""
    Say "  $step. 最初に 00_はじめに を読む"
    Say ""
    Say "  AI に手伝わせたいときは、この vault のフォルダで claude を起動してください。"
} else {
    Say "  $step. vault を置きたい場所で PowerShell を開き、こう打つ:"
    Say ""
    Say "       claude"
    Say "       /vault-init"
    Say ""
    Say "     質問は1つだけです。あとは全部そろった状態で出てきます。"
}
Say ""
Say "使えるコマンド: /vault-init（作る） /vault-guide（教わる） /vault-save（残す）"
Say "                /vault-ask（聞く）   /vault-lint（点検する）"
Say "アンインストール: powershell -ExecutionPolicy Bypass -File $KitDir\uninstall.ps1"
Say ""
