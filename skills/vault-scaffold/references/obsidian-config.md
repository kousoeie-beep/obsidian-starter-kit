# `.obsidian/` の設定ファイル

「設定済みの状態を渡す」の実体。ここを書いておくと、ユーザーは開いた瞬間から書き始められる。

## 前提（重要）

- **Obsidian を終了してから書く。** 起動中だと、Obsidian が終了時に自分の状態で上書きして、書いた内容が消える。
- **既存ファイルがある場合は上書きせずマージする。** キーを足すだけにして、ユーザーが変えた値は残す。
- Obsidian のバージョンによって形式が変わることがある。書いたあと Obsidian が起動して正常に読めれば成功。
  読めない形式だった場合、Obsidian は黙って既定値に戻すので、**開いたあとに設定画面で確認してもらう**。

> **実機で確認済み（2026-08-07 / macOS）。** 以下の内容で vault を作り、Obsidian で開いて終了させたところ、
> `core-plugins` の `bases` `daily-notes` `templates` `properties` `file-recovery`、
> `app` の `newFileLocation` `newFileFolderPath` `alwaysUpdateLinks` `attachmentFolderPath`、
> `daily-notes` の `folder` `template`、`templates.folder`、`graph.colorGroups` は
> **すべてそのまま保持された**（＝Obsidian に受け入れられている）。
> 唯一の変化は、`core-plugins.json` に未指定だった `slash-command: false` が
> Obsidian 側で補完されたことだけ。`.base` とテンプレートも無傷だった。
>
> つまり **未指定のキーは Obsidian が勝手に補ってくれる**ので、全キーを列挙する必要はない。

---

## core-plugins.json

コアプラグインの有効・無効。**プラグインを別途インストールする必要はない**（Obsidian に最初から入っている機能のスイッチ）。

```json
{
  "file-explorer": true,
  "global-search": true,
  "switcher": true,
  "graph": true,
  "backlink": true,
  "outgoing-link": true,
  "tag-pane": true,
  "page-preview": true,
  "daily-notes": true,
  "templates": true,
  "note-composer": true,
  "command-palette": true,
  "editor-status": true,
  "bookmarks": true,
  "outline": true,
  "word-count": true,
  "file-recovery": true,
  "properties": true,
  "bases": true,
  "canvas": true,
  "footnotes": false,
  "slides": false,
  "audio-recorder": true,
  "workspaces": false,
  "markdown-importer": false,
  "zk-prefixer": false,
  "random-note": false,
  "publish": false,
  "sync": true,
  "webviewer": false
}
```

- `bases` — Notion のようなデータベース表示。**コア機能なのでプラグイン導入不要**
- `properties` — frontmatter を画面上で編集できる。初心者には有効にしておく
- `file-recovery` — 誤って消したときに戻せる。必ず有効
- `sync` / `publish` — 有料機能のスイッチ。有効でも契約していなければ何も起きない

型 D（チーム共有）と E（AI wiki）では `daily-notes` を `false` にする。

---

## app.json

```json
{
  "alwaysUpdateLinks": true,
  "newFileLocation": "folder",
  "newFileFolderPath": "01_受信箱",
  "attachmentFolderPath": "Attachments",
  "useMarkdownLinks": false,
  "showUnsupportedFiles": false
}
```

- `alwaysUpdateLinks` — ノート名を変えたときにリンクを自動で追従。**これが無いとリンクが壊れて挫折する**
- `newFileLocation: "folder"` + `newFileFolderPath` — 新規ノートが必ず受信箱に入る。「どこに作られたか分からない」を防ぐ
- `attachmentFolderPath` — 貼った画像が散らからない
- `useMarkdownLinks: false` — `[[ノート名]]` 形式を使う（Obsidian の標準）

`newFileFolderPath` は型ごとに変える：

| 型 | newFileFolderPath |
|---|---|
| A / B / C | `01_受信箱` |
| D | `01_受信箱` |
| E | `wiki/concepts`（`.raw/` は原資料の置き場なので新規作成先にしない） |

### 型 E（AI wiki）で追加するキー

Claude Code 用のファイルを Obsidian の画面から隠す。

```json
{
  "userIgnoreFilters": [
    ".claude/",
    "CLAUDE.md"
  ]
}
```

`Templates/` は隠さない（型 E でもテンプレート機能を使うため）。

---

## daily-notes.json

**型 D（チーム共有）と型 E（AI wiki）では、このファイルを作らない。**
（`core-plugins.json` の `daily-notes` も `false` にする）

```json
{
  "folder": "02_日々の記録",
  "format": "YYYY-MM-DD",
  "template": "Templates/デイリーノート"
}
```

- `format` は必ず `YYYY-MM-DD`。並び順が日付順になり、他のツールとも揃う
- `template` は拡張子なしのパス
- **`template` が指すファイルを必ず一緒に作ること。** 無いとデイリーノートにテンプレートが当たらない

型別の値：

| 型 | folder | template | 作るか |
|---|---|---|---|
| A | `02_日々の記録` | `Templates/デイリーノート` | 作る |
| B | `01_受信箱` | `Templates/デイリーノート` | 作る |
| C | `02_日々の記録` | `Templates/デイリーノート` | 作る |
| D | — | — | **作らない** |
| E | — | — | **作らない** |

---

## templates.json

```json
{
  "folder": "Templates"
}
```

---

## appearance.json

```json
{
  "baseFontSize": 16,
  "accentColor": ""
}
```

見た目は好みなので最小限にする。ダーク／ライトの切り替えはユーザーに任せる（設定 → 外観）。

---

## graph.json

グラフビューをフォルダごとに色分けする。何がどこにあるか一目で分かるようになる。

```json
{
  "collapse-filter": false,
  "showTags": false,
  "showAttachments": false,
  "hideUnresolved": true,
  "showOrphans": true,
  "collapse-color-groups": false,
  "colorGroups": [
    { "query": "path:01_受信箱", "color": { "a": 1, "rgb": 14701138 } },
    { "query": "path:02_日々の記録", "color": { "a": 1, "rgb": 5431378 } },
    { "query": "path:03_ノート", "color": { "a": 1, "rgb": 5450097 } }
  ],
  "showArrow": true,
  "textFadeMultiplier": -1,
  "nodeSizeMultiplier": 1.5,
  "lineSizeMultiplier": 1.2,
  "centerStrength": 0.5,
  "repelStrength": 12,
  "linkStrength": 1,
  "linkDistance": 120,
  "scale": 1
}
```

- `query` は作った型のフォルダ名に合わせて書き換える
- `rgb` は10進数。色は何でもよいが、フォルダごとに変える
- `showOrphans: true` — 孤立ノートを表示する。初心者は最初リンクを張らないので、隠すと「何も出ない」になる

> グラフの色は、Obsidian を閉じたときに一度リセットされることがある。
> その場合はグラフ設定 → カラーグループで一度だけ再追加すれば、以後は保持される。

---

## 書かないファイル

- `hotkeys.json` — ユーザーのキーボード設定を勝手に変えない
- `workspace.json` — 画面レイアウト。Obsidian が自動生成する
- `community-plugins.json` — 初期構成ではコミュニティプラグインを入れない（`plugins.md` 参照）
