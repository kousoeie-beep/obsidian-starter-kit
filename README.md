# Obsidian Starter Kit

**Obsidian を「開いた瞬間から書ける状態」で作るキット。**
質問は1つだけ。フォルダも設定もテンプレートも揃った vault が出てきます。

Claude Code に投げるだけなので、ターミナルの知識は要りません。

---

## 使い方は2ステップ

### 1. インストール（1行）

**Mac / Linux** — ターミナルに貼る（`Command + Space` →「ターミナル」で開きます）

```bash
curl -fsSL https://raw.githubusercontent.com/kousoeie-beep/obsidian-starter-kit/main/install.sh | bash
```

**Windows** — PowerShell に貼る（スタートメニュー →「PowerShell」で開きます）

```powershell
[Net.ServicePointManager]::SecurityProtocol=[Net.SecurityProtocolType]::Tls12; irm https://raw.githubusercontent.com/kousoeie-beep/obsidian-starter-kit/main/install.ps1 | iex
```

> どちらも [git](https://git-scm.com/) が必要です。入っていなければインストーラが案内します。
> 同じ名前のコマンドが既にある場合は、**上書きせずに中止**して知らせます。

### 2. vault を作る

vault を置きたい場所（例：`書類` の中に作った空フォルダ）でターミナルを開いて、

```bash
claude
```

起動したら、こう打つだけです。

```
/vault-init
```

聞かれるのは **「この vault は何のために使いますか？」の1問だけ**。
あとはフォルダ・テンプレート・Obsidian の設定・最初に読むノートまで、まとめて作られます。

---

## 何が入るのか

`/vault-init` を実行すると、こういうものが一度に出てきます。

```
01_受信箱/          思いついたら何でもここ
02_日々の記録/      デイリーノート
03_ノート/          育てるノート
Templates/          ひな形（デイリー・メモ・議事録…）
Attachments/        画像やPDFの置き場
00_はじめに.md      最初に読むノート
CLAUDE.md           AI がこの vault を扱うときのルール
_ログ.md            AI の作業履歴（勝手に溜まっていく）
_いまの文脈.md      次に開いたとき AI が最初に読む引き継ぎ
.obsidian/          設定済み（デイリーノート・テンプレート・グラフの色分け）
```

### 使うほど育ちます

`_ログ.md` と `_いまの文脈.md` は **AI が自分で書きます。** あなたは触らなくて構いません。

- 何かノートを作ったり調べたりすると、`_ログ.md` に 1 行ずつ積み上がります
- 会話が一区切りつくと、`_いまの文脈.md` が上書きされます
- **次に `claude` を起動したとき、AI はまずこれを読みます。** 「前回どこまでやったか」を
  毎回説明し直す必要がありません

「あれ、何やったんだっけ」となったら `_ログ.md` を上から読めば分かります。
書きすぎないよう、**1 作業 1 行・文脈は 500 語まで**に制限してあります。

用途によって中身が変わります。

| 型 | こんな人に |
|---|---|
| 個人のセカンドブレイン | メモをためたい、忘れないようにしたい |
| 仕事のナレッジ | 議事録・案件・手順書を残したい |
| 学習・研究 | 勉強したこと、読んだ本を残したい |
| チーム共有 | みんなで手順書やナレッジを共有したい |
| AI ナレッジウィキ | AI に読ませる調査資料をためたい |

---

## 使えるコマンド

| コマンド | 何が起きるか |
|---|---|
| `/vault-init` | vault を作る（質問1つ） |
| `/vault-guide` | 使い方を教わる。**今の vault の中身に合わせて**、今つまずいている所だけ |
| `/vault-save` | 今の会話の中身をノートにして残す |
| `/vault-ask` | 「あの件どうだっけ」を自分のノートの中から答えてもらう |
| `/vault-lint` | リンク切れ・孤立ノート・散らかりを点検する |

---

## 設計の考え方

このキットは、Obsidian をやめてしまう理由に合わせて作ってあります。

| やめる理由 | このキットの対応 |
|---|---|
| 書き始めるまでの設定が多すぎる | 設定済みの状態を渡す。質問は1問だけ |
| 自由すぎて何をすればいいか分からない | 用途を聞いて型を当てる |
| フォルダ構成で悩んで手が止まる | フォルダは3〜5個。深い階層を作らない |
| プラグインを入れすぎて重くなる | 初期構成はコミュニティプラグイン **0個**。困ってから足す |
| 完璧に作ろうとして破綻する | 育つ前提。型を増やす手順を `CLAUDE.md` に書いておく |

### 技術的な前提（2026年8月時点）

- **MCP サーバーの設定は不要。** vault のフォルダで `claude` を起動すれば、Claude Code がファイルを直接読み書きできます
- **Obsidian CLI**（2026年2月・無料）を有効にすると、Claude Code が Obsidian そのものを操作できます。
  ただし **1.12.7 以降のインストーラ**が必要で、アプリ内の自動更新だけでは足りない場合があります
  （古いインストーラから更新した場合は [obsidian.md](https://obsidian.md) から入れ直し）。
  macOS では `/usr/local/bin` への登録に管理者権限を求められ、登録後はターミナルの再起動が必要です
- 一覧表は **Bases**（コア機能）を使います。Dataview のクエリ言語は覚えなくて構いません
- Obsidian は個人利用が無料で、**2025年2月から商用ライセンスも任意**になりました。会社で使えます

---

## もっと深く使いたくなったら

Obsidian の作者（kepano / Steph Ango）が公開している公式スキルを追加します。

```
/plugin marketplace add kepano/obsidian-skills
/plugin install obsidian@obsidian-skills
```

このキットは「vault を作って回す」層、kepano のスキルは「Markdown・Bases・Canvas を正確に扱う」層です。両方入れると噛み合います。

---

## 動作確認の状況

[CI](../../actions) で毎回 3 つの OS を通しています。

| 環境 | 状況 |
|---|---|
| **Windows** | 確認済み。**Windows PowerShell 5.1**（Windows 標準）と **PowerShell 7** の両方で、導入・再実行・衝突検出・アンインストール復元まで通過。PSScriptAnalyzer による 5.1 互換性チェックも通過 |
| **macOS** | 確認済み。クリーンな状態から導入・更新・衝突検出・アンインストール復元まで通過 |
| **Linux** | 確認済み（Debian のクリーンコンテナで 19 項目 ＋ CI） |
| **Obsidian 本体** | 確認済み。生成した `.obsidian/` 設定 13 項目が Obsidian に受理され、アプリ終了後も保持されることを実機で確認 |

うまくいかない場合は、[examples](examples/) の vault をダウンロードして
Obsidian の「フォルダを vault として開く」で選べば、同じ状態から始められます。

---

## 更新・アンインストール

更新は、インストールと同じコマンドをもう一度実行するだけです。

アンインストールは、**このキットが入れたものだけ**を消します（vault とノートには一切触りません）。
インストール時に退避した既存ファイルがあれば書き戻します。

```bash
# Mac / Linux
bash ~/.obsidian-starter-kit/uninstall.sh
```

```powershell
# Windows
powershell -ExecutionPolicy Bypass -File $HOME\.obsidian-starter-kit\uninstall.ps1
```

## 中身を確認してから実行したい場合

`curl ... | bash` は、ダウンロードしたスクリプトをその場で実行します。
中身を先に読みたい場合は、分けて実行してください。

```bash
curl -fsSL https://raw.githubusercontent.com/kousoeie-beep/obsidian-starter-kit/main/install.sh -o install.sh
less install.sh      # 中身を読む
bash install.sh
```

---

## ライセンス

MIT
