# EIGoScript — While（繰り返し）構文まとめ

---

## 構文ルール

* ループ開始: `We keep repeating the (sequence|<Name> sequence):`
* ループ本体はインデント or 改行で区切られた複数文（ピリオド or セミコロン）
* ループ終了条件: `until <boolean-clause>, then we stop (Name)? .`

  * ここだけは必ず `then` を使う（and不可）
* 任意で`Name`付きも可
* ループ内で `let ... be ...` や `print ...` などビルトイン動詞も使える

---

## サンプル: index を 0 から 10 まで出力する

```eigoscript
let index be 0.
We keep repeating the sequence:
  print index.
  let index be index + 1.
until index is greater than 10, then we stop.
```

---

### 解説

* `let index be 0.` : 変数 index を 0 で初期化
* `We keep repeating the sequence:` : ループ開始
* ループ本体（インデント/改行で複数文）

  * `print index.` : index の値を出力
  * `let index be index + 1.` : index を 1 増やす
* `until index is greater than 10, then we stop.` : 10 を超えたら終了

---

## 他のルール・特徴

* ループ名の指定もOK： `We keep repeating the Outer sequence:`
* ブロック終端をピリオドで明示
* ループ抜け条件以外は `and`/`then` どちらも可
