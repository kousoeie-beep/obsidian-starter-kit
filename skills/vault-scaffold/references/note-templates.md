# 生成するノートとテンプレートの中身

テンプレートはコアの Templates プラグインで動く構文だけを使う（`{{date}}` `{{time}}` `{{title}}`）。
Templater は初期構成では入れない。覚えることを増やさないため。

---

## 00_はじめに.md（全型で作る・最初に読ませるノート）

`<用途>` にはユーザーが答えた用途をそのまま入れる。フォルダ一覧は実際に作ったものに置き換える。

```markdown
# はじめに

この vault は **<用途>** のために作りました。

## まず3つだけ

1. **書く場所に迷ったら `01_受信箱`。** 整理は後でいい。
2. **ノートの中で `[[` と打つ**と、他のノートにつながる。これが Obsidian の主役。
3. **消えない。** すべて自分のパソコンの中の普通のテキストファイル。

## フォルダの意味

| フォルダ | 何を入れるか |
|---|---|
| `01_受信箱` | 思いついたこと全部。行き先が決まったら移す |
| `02_日々の記録` | その日のこと。左のカレンダーか `Cmd+P` →「デイリーノート」 |
| `03_ノート` | 育てるノート。受信箱から昇格させたもの |
| `Templates` | ひな形。自分では触らなくていい |
| `Attachments` | 貼った画像やPDFの置き場。自動で入る |

## よく使う操作（これだけ覚えれば足りる）

| やりたいこと | 操作 |
|---|---|
| 新しいノート | `Cmd+N` |
| 別のノートを探す | `Cmd+O`（名前を打つと候補が出る） |
| 全部から検索 | `Cmd+Shift+F` |
| 何でもできる窓 | `Cmd+P` |
| ノートをつなぐ | 本文で `[[` と打つ |

※ Windows は `Cmd` を `Ctrl` に読み替えてください。

## 続けるコツ

- **フォルダを増やしたくなっても、しばらく我慢する。** 同じ種類のノートが3つたまってから増やす
- **きれいに書こうとしない。** 走り書きでいい。後から AI に整えてもらえる
- **毎日書かなくていい。** 思い出したときに開けばいい

## AI に手伝ってもらう

このフォルダでターミナルを開いて `claude` と打つと、Claude Code がこの vault を読める状態で起動します。

| コマンド | 何が起きるか |
|---|---|
| `/vault-guide` | 使い方を、今の vault の中身に合わせて教えてくれる |
| `/vault-save` | 今の会話の中身をノートにして残してくれる |
| `/vault-ask` | 「あの件どうだっけ」を vault の中から答えてくれる |
| `/vault-lint` | 散らかりを点検して直してくれる |
```

---

## _ログ.md（全型で作る・AI が追記していく）

```markdown
---
type: log
updated: {{date:YYYY-MM-DD}}
---

# ログ

このファイルは AI が書きます。**新しいものが上**です。
何をしたか分からなくなったら、ここを上から読んでください。

## <YYYY-MM-DD>

- vault を作成しました（用途：<用途>）
```

## _いまの文脈.md（全型で作る・AI が上書きする）

```markdown
---
type: context
updated: {{date:YYYY-MM-DD}}
---

# いまの文脈

このファイルは AI が書きます。**次に開いたときに最初に読む引き継ぎ**です。
古くなったら上書きされます（履歴は `_ログ.md` に残ります）。

---

vault を作ったところです。まだ中身はほとんどありません。
次は、何か1つメモを書いてみるところから。
```

> **500語以内。** 長くなったら、古い話を `_ログ.md` に落として、ここは今の状況だけにする。

---

## Templates/デイリーノート.md

```markdown
---
created: {{date:YYYY-MM-DD}}
tags: [daily]
---

# {{date:YYYY-MM-DD}}

## 今日やること
- [ ] 

## メモ


## 気づいたこと

```

---

## Templates/メモ.md

```markdown
---
created: {{date:YYYY-MM-DD}}
tags: []
---

# {{title}}


## 関連

```

---

## Templates/議事録.md

```markdown
---
type: meeting
date: {{date:YYYY-MM-DD}}
参加者: []
tags: [議事録]
---

# {{title}}

## 決まったこと


## 宿題
- [ ] 

## 話したこと


## 次回

```

> 参加者は `[[名前]]` で書く。そうすると人のノートから「この人が出た会議」を全部たどれる。

---

## Templates/案件.md

```markdown
---
type: project
status: 進行中
created: {{date:YYYY-MM-DD}}
関係者: []
tags: [案件]
---

# {{title}}

## 概要


## 現在地


## 決まっていること


## 未決

```

---

## Templates/手順書.md

```markdown
---
type: howto
updated: {{date:YYYY-MM-DD}}
tags: [手順書]
---

# {{title}}

## これは何のための手順か


## 手順
1. 

## つまずきやすいところ

```

---

## Templates/人.md

```markdown
---
type: person
所属: 
tags: [人]
---

# {{title}}

## メモ


## この人が出てくるノート
（下の「バックリンク」に自動で出ます）
```

---

## Templates/文献.md

```markdown
---
type: source
著者: 
出典: 
読了日: 
tags: [文献]
---

# {{title}}

## 引用（相手の言葉）
> 

## 自分の言葉で言うと

```

---

## Templates/まとめ.md

```markdown
---
type: note
created: {{date:YYYY-MM-DD}}
tags: []
---

# {{title}}

## 結論


## 根拠


## 出典
- [[]]
```

---

## 型 E（AI wiki）用のテンプレート

`Templates/concept.md`

```markdown
---
type: concept
status: seed
created: {{date:YYYY-MM-DD}}
updated: {{date:YYYY-MM-DD}}
tags: []
---

# {{title}}

## 要約


## 詳細


## 関連
- [[]]

## 出典
- [[]]
```

`Templates/entity.md`

```markdown
---
type: entity
status: seed
created: {{date:YYYY-MM-DD}}
updated: {{date:YYYY-MM-DD}}
tags: []
---

# {{title}}

## これは何か


## 関係するもの
- [[]]

## 出典
- [[]]
```

`Templates/source.md`

```markdown
---
type: source
status: seed
created: {{date:YYYY-MM-DD}}
updated: {{date:YYYY-MM-DD}}
出典URL: 
tags: []
---

# {{title}}

## 要点


## ここから作ったページ
- [[]]
```

---

## Base ファイル

Bases はコア機能。`.base` ファイルを作るとテーブル表示になる。
**構文は最小限にとどめる。** 凝ったものが必要になったら kepano/obsidian-skills の `obsidian-bases` skill を使う。

`すべてのノート.base`

```yaml
filters:
  and:
    - 'file.ext == "md"'
    - '!file.name.contains("Template")'
views:
  - type: table
    name: すべて
    order:
      - file.name
      - file.mtime
    sort:
      - property: file.mtime
        direction: DESC
```

> `filters` を省くと、ノート以外（画像・PDF・`.base` 自身）まで一覧に並ぶ。
> 「すべてのノート」という名前と中身を一致させるため、`file.ext == "md"` を必ず入れる。

`議事録一覧.base`（型 B / D）

```yaml
filters:
  and:
    - 'type == "meeting"'
views:
  - type: table
    name: 議事録
    order:
      - file.name
      - date
      - 参加者
    sort:
      - property: date
        direction: DESC
```

`案件一覧.base`（型 B）

```yaml
filters:
  and:
    - 'type == "project"'
views:
  - type: table
    name: 進行中
    filters:
      and:
        - 'status == "進行中"'
    order:
      - file.name
      - status
      - 関係者
  - type: table
    name: すべて
    order:
      - file.name
      - status
```

> `.base` を作ったあと Obsidian で開いて、表が出るか必ず確認する。
> 構文が違うと表が空になる。空だったらフィルタを外した最小形に戻す。
