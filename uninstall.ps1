# Obsidian Starter Kit — アンインストーラ（Windows / PowerShell 版）
# 使い方: powershell -ExecutionPolicy Bypass -File $HOME\.obsidian-starter-kit\uninstall.ps1
#
# -ExecutionPolicy Bypass は、Windows の既定でスクリプトファイルの実行が
# 禁止されている（Restricted）環境でも動くようにするため。
#
# 消すのは「このキットが入れた記録が残っているもの」だけです。
# あなたの vault・ノートには一切触れません。

$ErrorActionPreference = 'Stop'

$ClaudeDir = if ($env:OSK_CLAUDE_DIR) { $env:OSK_CLAUDE_DIR } else { Join-Path $HOME '.claude' }
$KitDir    = if ($env:OSK_KIT_DIR)    { $env:OSK_KIT_DIR }    else { Join-Path $HOME '.obsidian-starter-kit' }
$ManifestPath = Join-Path $ClaudeDir '.obsidian-starter-kit-manifest'
$BackupDir    = Join-Path $ClaudeDir '.obsidian-starter-kit-backup'

if (-not (Test-Path $ManifestPath)) {
    Write-Host "このキットのインストール記録が見つかりません（$ManifestPath）"
    Write-Host "何も削除しませんでした。"
    exit 0
}

$removed = 0
foreach ($rel in (Get-Content $ManifestPath)) {
    if ([string]::IsNullOrWhiteSpace($rel)) { continue }
    $target = Join-Path $ClaudeDir $rel
    if (Test-Path $target) {
        Remove-Item $target -Recurse -Force
        $removed++
    }
}
Remove-Item $ManifestPath -Force
Write-Host "✓ $removed 件を削除しました"

if (Test-Path $BackupDir) {
    Write-Host ""
    Write-Host "インストール時に退避したファイルを書き戻しています…"
    Get-ChildItem $BackupDir -Recurse -File | ForEach-Object {
        $rel = $_.FullName.Substring($BackupDir.Length + 1)
        $dst = Join-Path $ClaudeDir $rel
        New-Item -ItemType Directory -Force -Path (Split-Path $dst) | Out-Null
        Copy-Item $_.FullName $dst -Force
        Write-Host "  戻しました: $rel"
    }
    Remove-Item $BackupDir -Recurse -Force
}

Write-Host ""
Write-Host "キット本体（$KitDir）は残してあります。完全に消す場合は:"
Write-Host "  Remove-Item -Recurse -Force $KitDir"
Write-Host ""
Write-Host "あなたの vault とノートは削除していません。"
