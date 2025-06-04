## For‑each 反復構文（最終版）

### 1. 構文

```
We go through each <iterator> in <range‑or‑collection> [in the <Label>]:
  <statements>;
  ...
That’s everything [in the <Label>].
```

| 部分 | 説明 |
|------|------|
| `<iterator>` | ループ変数。型は書かず **名前だけ**（例: `i`, `item`） |
| `<range‑or‑collection>` | 反復対象<br>• **数値範囲** → `any number between <start> and <end>[, stepping by <step>]`<br>• **コレクション** → `the shopping list`, `values`, など |
| `in the <Label>` | **任意**ラベル。付ける場合は開始句・終了句で同じ語を使う |
| `:` | 本体開始 |
| `<statements>;` | 命令文。セミコロンで区切る |
| `That’s everything …` | ループ終了宣言 |

---

### 2. 使用例

#### 2‑1. 数値範囲（ステップ付き）

```eigoscript
We go through each i in any number between 0 and 10, stepping by 2:
  print i;
That’s everything.
```

#### 2‑2. コレクション

```eigoscript
We go through each item in the shopping list:
  print item;
That’s everything.
```

#### 2‑3. ラベル付き & ネスト

```eigoscript
We go through each item in the shopping list in the Outer:
  We go through each i in any number between 0 and 5 in the Inner:
    print item + " × " + i;
  That’s everything in the Inner;
That’s everything in the Outer.
```

---

### 3. 規約まとめ

1. **イテレータは名前だけ**（`i`, `item`, …）。型は書かない。  
2. **数値範囲**は `any number between A and B`、ステップは `stepping by N`。  
3. **終了句**は固定フレーズ `That’s everything.`  
   - ラベル付きなら `That’s everything in the <Label> loop.`  
4. インデント＋セミコロンで複数文を並べる。  
5. 範囲・コレクションは自由に拡張 OK。
