## EIGoScript: 動詞定義構文（最新版）

### 1. 動詞の定義（ヘッダー）

```eigoscript
I define a svo verb called add.
It takes x. // o部分のみわかる
```

* `<svo>` 部分は、`sv`, `svo`, `svc`, `svoc`, `svoo` など五文型を指定
* `add` の部分が動詞名
* `It takes ...` でパラメータ列挙（カンマ or and で繋ぐ）

---

### 2. 動詞本体（説明ブロック）

#### 基本型（構文型省略）

```eigoscript
I define a svoo verb called add . It takes x and y.
I explain add:
  give back x + y.
I finish the explanation.
```

#### 構文型を明示する場合

```eigoscript
I explain svoc introduce:
  print name. you print a nameでもOk 結果は同じ
  print job.
  give back "ok".
I finish the explanation.
```

---

### 3. ポイントまとめ

* `I explain <動詞名>:` … 一般的なパターン
* `I explain <構文型> <動詞名>:` … 五文型を明示したい/する場合
* パラメータは `It takes x and y.` の形式で揃える（型は不要でOK）
