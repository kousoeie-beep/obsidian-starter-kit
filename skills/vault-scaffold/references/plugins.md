# プラグインの方針

## 初期構成では**コミュニティプラグインを1つも入れない**

理由：

1. コアプラグイン（最初から入っている機能）だけで、初心者に必要なことはすべてできる
2. コミュニティプラグインを増やすと**起動が3〜5秒遅くなる**。スマホでは体感がさらに悪い
3. プラグインを入れる作業そのものが挫折ポイントになる（安全モードの解除、検索、有効化…）
4. 2025年8月に **Bases** がコア機能になり、以前は Dataview が必要だった「一覧表示」がプラグイン無しでできるようになった

「まず5つ入れましょう」と書いてある記事は多いが、**書き始める前に5つ入れさせるのが挫折の原因**。
必要になってから足す。

---

## 欲しくなったときに勧めるもの（聞かれたら答える）

| 欲しくなること | プラグイン | 補足 |
|---|---|---|
| カレンダーから日記を開きたい | **Calendar** | 最初に足すならこれ |
| テンプレートに凝りたい | **Templater** | コアの Templates で足りなくなってから |
| 手書き・図を描きたい | **Excalidraw** | 重い。本当に描く人だけ |
| タスクを横断で管理したい | **Tasks** | 期日・繰り返しが要るなら |
| Git でバージョン管理したい | **Obsidian Git** | エンジニア以外には勧めない |
| 検索を強くしたい | **Omnisearch** | 標準検索で足りないと感じてから |

**Dataview は勧めない。** クエリ言語を覚える必要があり、同じことが Bases でノーコードでできる。
既に Dataview を使っている vault には触れない（動いているものを壊さない）。

---

## 入れ方（聞かれたときの案内文）

> 設定（左下の歯車）→ コミュニティプラグイン → 「コミュニティプラグインを有効化」→
> 「閲覧」から名前で検索 → インストール → 有効化

初回は「制限モード（安全モード）」の解除を求められる。これは第三者製のコードを動かす確認なので、
**入れるプラグインの名前を確認してから解除する**よう伝える。

---

## コアプラグインで何ができるか（プラグインを探す前に確認する）

| やりたいこと | コア機能 |
|---|---|
| 一覧表・データベース | **Bases**（`.base` ファイル） |
| 日記 | **デイリーノート** |
| ひな形 | **テンプレート** |
| 図・関係の可視化 | **グラフビュー** / **キャンバス** |
| ノートの分割・結合 | **ノートコンポーザー** |
| 全文検索 | **検索** |
| frontmatter の編集 | **プロパティ** |
| 誤削除からの復旧 | **ファイルリカバリー** |
| ブックマーク | **ブックマーク** |

「〇〇がしたい」と言われたら、まずこの表を見る。プラグインを探すのは最後。

---

## Obsidian CLI（Claude Code から Obsidian を直接操作する）

Obsidian 1.12（2026年2月）から**公式の CLI が同梱**されている。追加インストールも課金も不要。

有効化：Obsidian の 設定 → General → Command line interface

使えるようになると、Claude Code から Obsidian そのものを操作できる：

```bash
obsidian search query="議事録" limit=10
obsidian create name="新しいノート" content="# 見出し" template="メモ" silent
obsidian daily:append content="- [ ] 買い物"
obsidian property:set name="status" value="完了" file="案件A"
obsidian backlinks file="田中さん"
obsidian base:query ...
```

- **Obsidian が起動している必要がある**（起動中のアプリに接続する方式）
- `silent` を付けるとファイルを開かずに処理する
- 詳しくは `obsidian help`、または kepano/obsidian-skills の `obsidian-cli` skill

**MCP サーバーの設定は不要。** 2025年までの解説記事の多くは MCP を前提に書かれているが、
今は vault のフォルダで `claude` を起動するだけでファイルを直接読み書きでき、
さらに CLI があれば Obsidian の機能そのものを呼べる。

---

## もっと深いことをしたくなったら

Obsidian の作者（kepano）が公開している公式スキルを入れる。MIT ライセンス。

```
/plugin marketplace add kepano/obsidian-skills
/plugin install obsidian@obsidian-skills
```

内容：`obsidian-markdown`（wikilink・callout・properties を壊さず書く）、
`obsidian-bases`（`.base` の複雑な構文）、`json-canvas`（`.canvas` の編集）、
`obsidian-cli`、`defuddle`（Web ページを綺麗な markdown にする）。

このキットは「vault を作って回す」層、kepano のスキルは「ファイル形式を正確に扱う」層。
両方入れると噛み合う。
