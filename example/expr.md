# EIGoScript: Expr と ESema (英文文型分析) 設計仕様

## 概要

EIGoScript は「英語のように読める」プログラミング言語であり、文法的な自然さを重要視しています。そのため、文(文式)の評価を 2 階階で行います:

* **Parser**: Expr (式) を結構的に分析
* **ESema (English Semantic Analyzer)**: Expr を英語文法の観点から評価

この分離により、一要の式 (Expr)が文章の中で **文、語、語節、従子節** などの値を取りうるようになります。

---

## 1. Expr の概念

**Expr = 式 = 文にも語にも語節にもなりうる文法機能単位**

Parser では下記のようなものをすべて Expr として構文的に取り込む:

| 種類  | 例                                 | 解説                         |
| --- | --------------------------------- | -------------------------- |
| 文   | `call greet with name.`           | S + V の文                   |
| 名語  | `name`, `"Hello"`, `number`       | 定数・ラベル等                    |
| to句 | `to be happy`, `to greet someone` | 目的節・助詞付き語節                 |
| 名詞節 | `the result of sum with a and b`  | `Let A be ...` の O/C になりうる |
| 従子節 | `when age is over 30`             | 条件・時刻・理由など                 |

---

## 2. Parser と ESema の分離

### Parser

* Expr を定義的に認識
* AST としてノード化 (種類付きの何も評価しない)
* `ExprNode`, `CallExpr`, `TextLiteral`, `ToClause` などを作る

### ESema

* Parser の ExprNode を **5文型解析** (SV, SVC, SVO, SVOO, SVOC)
* 文法的に成立するかを判定
* 不適切な場所での `call` などを警告/エラー
* 従子節や目的語の前置等もチェック

---

## 3. ケーススタディ

### 例 1: 文法的に不適

```eigoscript
Let A be call sum with a and b.   # ❌ call文をOに置くのは文法不適
```

### 例 2: Expr を語節化

```eigoscript
Let A be the result of sum with a and b.   # ✅ 名詞句
Let A be value when we call sum with a and b.  # ✅ 従属節
```

---

## 4. Expr の利点

* Parser のコードは簡素に
* 英文文法エラーを出しやすい
* 5文型による文法解析は教育的価値も高い
* AST の表現力を保ったまま、文法評価だけ分離可

---

## 5. 今後の設計方針

* `Expr` は広範囲な形を許可
* `ESema` で必要な文法チェック
* 5文型を基本型とし、未条件の表現は `style warning`として判定

---

## 6. マーカー文 (ESema 上のメッセージ案)

* "This is a verb. But you tried to treat it as a noun. Are you American?"
* "Great. You wrote a complete sentence where only a name should be. Classic."
* "The Queen would be disappointed with that sentence structure."

これらは、EIGoScriptのイギリスの相構として辞書的な価値も持たせます。
