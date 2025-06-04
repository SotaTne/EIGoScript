# EIGoScript Function Definition

## 構文の基本形

I define a function called foo. It takes x, y, and z.
I explain foo:
  <statements>.
I finish the explanation.

---

## 詳細説明

- `I define a function called <関数名>.`
  - 関数の宣言。名前を定義します。

- `It takes <引数リスト>.`
  - 引数をカンマ区切りで指定。andもOK。
  - 型情報やas句は**現時点では省略**。

- `I explain <関数名>:`
  - 関数本体の開始。コロンと改行インデントで中身を記述。

- `<statements>.`
  - 命令文はピリオドで終了。セミコロンは不要。

- `I finish the explanation.`
  - 関数本体の終了宣言。`I finish it.` も可。

---

## サンプル1（引数のみ）

I define a function called pie. It takes a, b, and c.
I explain pie:
  print a + b + c.
I finish the explanation.

---

## サンプル2（引数なし）

I define a function called main.
I explain main:
  print "Hello".
I finish the explanation.

---

## 拡張のヒント

- 型が必要な場合は `It takes a as number, b as text.` などにも拡張可能。
- 本体ブロック名は `I explain <関数名>:` 以外にも柔軟に（たとえば `I describe <関数名>:`）。

---

## ポイント

- すべての文は**ピリオドで終了**。
- セミコロンやカンマ区切りは英語の感覚で柔軟に。
- `takes` はここでは「受け取る」（他動詞的用法）として自然です。
- 本体はコロン（:）で開始し、インデントで区切る。
