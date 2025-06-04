# EIGoScript ― entity（クラス相当）仕様

> ※ すべての関数／メソッドは必ずブロック形式：  
> &nbsp;&nbsp;`open …:` ～ `close ….`  
> 一行完結（`;` 終了）は禁止します。

---

## 1. entity 宣言

```eigoscript
I define an entity called Person with the fields:
  name as text,
  age as number.
```

- フィールドは `name as text` のように記述し、カンマまたは改行で区切る。
- 型名は無冠詞（`text`, `number`, `list of T`, `Box of T` なども可）
- 同じ型の複数フィールドは `x, y, and z as number` のように列挙可能。

---

## 2. メソッド定義

| 種別            | 宣言句テンプレート                                                       | 備考                                   |
|-----------------|--------------------------------------------------|----------------------------------------|
| **公開**        | `I define a function called <Name> for <Entity>:`                      | `for <Entity>` は必須                   |
| **非公開**      | `I define a function kept inside <Entity> called <Name>:`             | `for` は書かず、Entity 名は修飾内に含む |
| **共有 (static)** | `I define a function common to all <Entity> called <Name>:`          | Entity 名を必ず一度は書く（省略不可）   |

- **戻り値あり** は宣言句末尾に `; it returns <Type>.` を付加  
- **本体ブロック** は以下の通り：

```eigoscript
I begin the function <Name>:
  <statements>;
  ...
  I give back <expression>.   # 戻り値がある場合
I finish the function <Name>.  # または I finish it.
```

---

## 3. コンストラクタ (`init`)

```eigoscript
I define a function called init for Person with
  text name, number age:

I begin the function init:
  Let my name be name;
  Let my age be age;
I finish the function init.
```

---

## 4. インスタンス生成

### 4-A. `new` メソッドを定義

```eigoscript
I define a function common to all User called new with the parameters:
  name as text,
  age as number; it returns User.

I begin the function new:
  I create a User named result with these values:
    Let result's name be name;
    Let result's age be age;
  end this creation.
  I give back result.
I finish the function new.
```

### 4-B. `create` 構文（糖衣構文）

```eigoscript
I create a User named alice with these values:
  Let alice's name be "Alice";
  Let alice's age be 20;
end this creation.
```

または、より広い初期化処理を含む場合：

```eigoscript
I create a User named alice with this creation:
  Let alice's name be "Alice";
  Let alice's age be 20;
  call alice's greet;
end this creation.
```

- `create <Entity> named <var>` で変数を宣言し、初期化を始めます。
- `with these values:` は主に「値の設定」のために使います。
- `with this creation:` は「初期化ロジックも含む複合的な構築」に向いています。
- ブロックの終わりは必ず `end this creation.` と記述してください。

---

## 5. フィールド代入

```eigoscript
Let alice's name be "Bob".
Let my age be my age + 1.
```

- `Let <Object>'s <field> be <expression>.`  
- `<Object>` は変数名または `my`（メソッド内のみ）

---

## 6. 呼び出し規則

| 操作                  | 例                                |
|-----------------------|-----------------------------------|
| フィールド参照        | `print alice's age.`              |
| 公開メソッド呼び出し   | `call alice's greet.`             |
| 非公開メソッド呼び出し | （外部からはエラー）               |
| 共有(static) 呼び出し  | `call User's count.`              |
| 自身から呼ぶ           | `call my greet.`                  |

---

## 7. 型システム（TypeScript ライク）

- **Gradual typing**：暗黙の `any` 許容（警告）  
  - `use strict typing.` で厳格モード  
- **構造的互換**：フィールド構造が同じなら異なる entity 間で代入可  
- オーバーロード禁止、継承未導入

---

## 8. 完全サンプル

```eigoscript
# entity 定義
I define an entity called User with the fields:
  name as text,
  age as number.

# init コンストラクタ
I define a function called init for User with the parameters:
  name as text,
  age as number.

I begin the function init:
  Let my name be name;
  Let my age be age;
I finish the function init.

# new メソッド
I define a function common to all User called new with the parameters:
  name as text,
  age as number; it returns User.

I begin the function new:
  I create a User named result with these values:
    Let result's name be name;
    Let result's age be age;
  end this creation.
  I give back result.
I finish the function new.

# インスタンス生成
I create a User named alice with these values:
  Let alice's name be "Alice";
  Let alice's age be 20;
end this creation.

# 操作例
call alice's greet.
Let alice's name be "Bobby".
call User's new with "Charlie", 30.
```

---

## キーワード一覧

| キーワード                         | 意味                                    |
|------------------------------------|-----------------------------------------|
| `entity`                           | クラス相当構造体の宣言                   |
| `kept inside <Entity>`             | 非公開 (private) メソッド               |
| `common to all <Entity>`           | 共有 (static) メソッド                  |
| `for <Entity>`                     | 公開メソッドのレシーバ指定（必須）       |
| `my`                               | メソッド内のレシーバ自身                |
| `I create a <Entity> named <var>`  | インスタンスの生成＋初期化              |
| `Let <Obj>'s <field> be <expr>.`   | フィールドへの代入                      |
| `open …: … close ….`               | メソッド／関数ブロックの境界            |
| `with the fields:`                 | entity のフィールド宣言開始               |
| `x, y, and z as number`            | 同じ型のフィールドを列挙する構文         |
| `with the parameters:`             | 関数やメソッドの引数宣言開始             |