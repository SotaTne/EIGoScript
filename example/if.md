# EIGoScript — 条件分岐構文まとめ（2025/05/31時点）

EIGoScriptでは「自然な英語」かつ「明確な論理分岐」を実現するため、以下のような構文ルールを採用しています。

---

## 1. 基本構文

- **条件とアクションをカンマで接続し、`and`または`but`で分岐を表現します。**

x is even, and print “even”

- 左側がtrueの時だけ右側を実行します。

---

## 2. 否定分岐

- **`but`を使うことで、左条件がfalseの場合のみ右側を実行します。**

x is even, but print “odd”

- 直前の条件がfalseの時のみ右を評価。

---

## 3. else（デフォルト）分岐：`otherwise`

- **分岐チェーンの末尾に`otherwise`を使うことでelse相当の処理を実現できます。**
- `otherwise`はand/but分岐チェーンの最後、例外的に使う特別な表現です。
- 伝播せず、他の分岐や単文には使えません。

x is even, and print “even”, otherwise print “not even”.

---

## 4. 分岐チェーン（if-elif-else相当）

- **複数の条件分岐は、and/but/otherwiseをカンマ区切りで連結します。**

mod x 15 is 0, and print “FizzBuzz”,
otherwise mod x 5 is 0, and print “Buzz”,
otherwise mod x 3 is 0, and print “Fizz”,
otherwise print x.

- 上から順に評価し、どこかで条件成立した時点で実行し打ち切り
- どれもtrueでない場合にonly最後のotherwiseが実行される

---

## 5. 複数文の実行（ブロック）

- **and/butの右に複数の文を実行したいときは`do the following:`でブロックを開始し、`That is all.`で終端します。**

x is even, and do the following:
print “even”;
print x;
That is all.

- ネストも可能

---

## 6. 分岐構文の伝播ルール

- `otherwise`はand/but分岐チェーンの末尾限定
- 否定パス（but）の右側にも再びand/but/otherwiseで論理チェーンを形成できる
- `and`は左がtrue時のみ右を、`but`は左がfalse時のみ右を実行

---

## 7. サンプル集

### 7.1 if/elseの1行表現

x is even, and print “even”, otherwise print “odd”.

### 7.2 elif相当の多段分岐

to mod x 15 is 0, and print “FizzBuzz”,
otherwise to mod x 5 is 0, and print “Buzz”,
otherwise to mod x 3 is 0, and print “Fizz”,
otherwise print x.

### 7.3 ブロックで複数文

x is positive, and do the following:
print “positive”;
print x;
That is all., otherwise print “non-positive”.

---

## 8. 注意点

- `otherwise`は**例外的な表現**として分岐チェーンの最後にのみ使用すること
- ピリオドは、文やブロック、分岐チェーンの最後でのみ使う（1行につき1ピリオド推奨）
- and/but/otherwiseで分岐がネストできる

---

## 9. 英語としての自然さとプログラミング表現のバランス

- 実際の英語では「, and」「, but」で文を繋ぐのはやや口語的だが、EIGoScriptの分岐設計としては直感的で非常にわかりやすい
- 条件→アクションが一目で分かるので可読性が高い

---

この仕様は2025年5月31日時点での設計です。
