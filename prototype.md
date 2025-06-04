# EIGoScript 言語仕様（最新版）

## 概要・コンセプト

**EIGoScript**は、「英語のように書けること」を目標に作られたプログラミング言語です。  
中学校レベルの英語をベースとし、構文はすべて英文法として正しい形で記述されます。  
また、LexerやParserの説明が常に英語でなされることへの皮肉を込めています。

### 特徴

- 英文法として正しく自然な文章だけが許されます。
- 文法エラー時は、「アメリカ人はまともなEnglish（イングランド語）を書けない」という英国風ジョークを含んだメッセージを返します。
- インデントは文法上は任意（あくまで見やすさの補助）です。
- Go以外のプログラミング言語で作ります(とりあえずWasmとの相性と書きやすさ・LLVMとの相性などからZig)

---

## 基本文法

### 関数定義・呼び出し

```eigoscript
I define function main.
I begin main's discussion.

  (処理内容を書く)

I end main's discussion.

Call main.
```

---

### 変数の宣言・代入

#### 宣言のみ

```eigoscript
name A as number.
```

#### 代入のみ

```eigoscript
Let A be 3.
```

#### 宣言＋代入

```eigoscript
name A as number, let it be 3.
```

※ `it` はとりあえず直前に定義した変数を指します。

---

### 条件分岐

```eigoscript
I do print "A wins" when A is greater than B.
otherwise, print "B wins".
```

---

### 繰り返し処理

```eigoscript
I repeat print A ten times.
```

---

## 引数付き関数

### 単一引数（型指定）

```eigoscript
I define function greet with text name.
```

### 複数引数（同一型）

```eigoscript
I define function add with some number A, B, and C.
```

### 複数引数（型が異なる場合）

```eigoscript
I define function introduce with text name, some number age, height, and text nationality.
```

---

## 戻り値付き関数

戻り値の型指定は `returning` を使います。

```eigoscript
I define function double with a number A, returning number.
I begin double's discussion.

  I give back A times 2.

I end double's discussion.
```

戻り値を受け取る場合：

```eigoscript
name result as number, let it be double of 3.
```

---

## 総合的なサンプルコード

```eigoscript
I define function introduce with text name, some number age, height, and text nationality, returning text.
I begin introduce's discussion.

  I give back "I am " + name + ", " + age + " years old, " + height + " cm tall, from " + nationality + "."

I end introduce's discussion.

name intro as text, let it be introduce with "Alice", 20, 160, and "Japan".
print intro.
```

---

## エラーメッセージ（皮肉）例

| 状況 | エラーメッセージ | 日本語訳 |
|------|----------------|---------|
| 文法エラー | "Oh dear. That’s not English. Are you perhaps from across the pond?" | おやおや、それは英語じゃないね。君は大西洋の向こうの人かな？ |
| ピリオド忘れ | "Ah, a sentence without a full stop. What are we, Americans?" | ああ、ピリオドのない文？我々はアメリカ人だったかな？ |
| be の抜け | "Missing ‘be’? Surely, one must ‘be’ to exist. Unlike your syntax." | beが抜けてるぞ。存在するにはbeが要るんだ、君の構文とは違ってな。 |

---

## 今後の予定・拡張案

- 四則演算やリストのサポート
- コメント機能の追加
- エラーメッセージのさらなる拡充
- 型推論や高度な構文の導入
