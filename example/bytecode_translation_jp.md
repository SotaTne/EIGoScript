## 第14章 バイトコードの断片

> もし理論ばかりに時間を使っていると気づいたら、実践にも少し目を向けてみよう。理論がより良くなるはずだ。もし実践ばかりに時間を使っていると気づいたら、理論にも少し目を向けてみよう。それによって実践も向上するだろう。  
> — ドナルド・クヌース

私たちはすでに、`jlox` によって Lox 言語の完全な実装を手にしています。では、なぜこの本はまだ終わらないのでしょう？その理由の一つは、jlox が JVM に多くの処理を任せているからです。インタプリタがハードウェアに近いところまでどのように動作するのかを理解したければ、そういった部分を自分たちで作り上げる必要があります。

もちろん、2つ目のインタプリタでは C の標準ライブラリに頼っています。たとえばメモリの割り当てや、C コンパイラがマシンコードの詳細から私たちを守ってくれます。そもそもそのマシンコード自体、チップ上のマイクロコードによって動作しているかもしれません。そして C のランタイムは、オペレーティングシステムにメモリページを要求しています。つまり、この本を本棚に収めたいのであれば、どこかで妥協する必要があるのです。

さらに根本的な問題は、jlox は単純に「遅すぎる」ということです。構文木を歩いて実行するタイプのインタプリタは、高水準で宣言的な言語には適していますが、一般的な命令型言語、特に Lox のようなスクリプト言語には向きません。

次のような小さなスクリプトを考えてみてください：

```lox
fun fib(n) {
  if (n < 2) return n;
  return fib(n - 1) + fib(n - 2); 
}

var before = clock();
print fib(40);
var after = clock();
print after - before;

```

これは、実際にフィボナッチ数を計算するには非常に非効率的な方法です。私たちの目的は、インタプリタがどれくらい速く動作するかを測ることなので、効率的なプログラムを書くことではありません。多くの作業（たとえ無意味であっても）をする遅いプログラムは、性能のテストにはうってつけです。

私のラップトップでは、このコードを jlox で実行すると約72秒かかります。同じことを C で書いたプログラムでは、わずか0.5秒で完了します。動的型付きのスクリプト言語は、静的型付きで手動のメモリ管理ができる言語には敵いませんが、100倍以上遅くなる必要もないのです。

jlox をプロファイラにかけてホットスポットの最適化を始めることもできますが、それにも限界があります。この実行モデル——構文木を歩く——自体が根本的に適していないのです。これをどれだけマイクロ最適化しても、AMCグレムリンをSR-71ブラックバードに磨き上げることはできません。

私たちは、コアとなる実行モデルを再考する必要があります。この章では、その新しいモデルである「バイトコード」と、それに基づく新しいインタプリタ clox の構築を始めます。

### 14.1 Bytecode?

エンジニアリングにおいて、選択には必ずトレードオフが伴います。なぜ私たちがバイトコード方式を採用するのかを理解するために、他のいくつかの選択肢と比較してみましょう。

#### 14.1.1 なぜASTを歩かないのか？

私たちが今使っているインタプリタには、いくつかの利点があります：

- まず、すでに作り終えているという点です。これは単純ですが重要で、このスタイルのインタプリタは実装がとても簡単です。実行時のコード表現が構文に直結しており、パーサから必要なデータ構造への移行はほぼ無意識に行えます。
- ポータブルであること。現在のインタプリタはJavaで書かれており、Javaが動作するあらゆるプラットフォームで利用できます。同じアプローチでCによる実装も可能で、あらゆるシステム上で実行できます。

これらは確かに利点です。しかし欠点もあります。それは、メモリ効率が非常に悪いということです。各構文要素はASTノードになり、例えば `1 + 2` のようなシンプルな式でも、多数のオブジェクトとポインタを含む構造体の集合になります。

このようにデータがヒープ上に分散していると、空間的局所性が著しく低下します。モダンなCPUは、RAMからの読み込みよりもはるかに速く処理をこなします。この差を埋めるためにキャッシュが存在します。CPUはメモリから一部のバイトを読み込むとき、隣接するバイトもまとめてキャッシュに読み込みます。もし次に必要なデータがキャッシュライン内にあれば、高速にアクセスできます。

ですがASTのような構造では、ポインタをたどるたびにキャッシュの外に出てしまい、読み込み待ちによるCPUの停止が発生します。また、GC（ガベージコレクション）によってメモリ内の配置が変更されると、ノードの位置関係も壊れてしまいます。

この他にもインタフェースディスパッチやVisitorパターンなど、構文木ベースのインタプリタにはさまざまなオーバーヘッドが存在します。ですが、局所性の問題だけでも、より良いコード表現を模索する価値は十分にあります。

#### 14.1.2 なぜネイティブコードにコンパイルしないのか？

本当に速さを求めるなら、すべての間接層を取り払ってマシンコード（機械語）を生成するべきです。マシンコード——その響きからして速そうですよね。

最速の言語たちは、実際にマシンコードをターゲットにしています。アーキテクチャの命令セットに直接対応させたコンパイラを作ることは、性能面では最強の選択肢です。

ですが、簡単ではありません。現代のプロセッサは複雑で、多数の命令と最適化技術が積み重ねられています。レジスタの割り当て、パイプライン処理、命令スケジューリングなど、すべてに精通しなければなりません。

加えて、ポータビリティは完全に失われます。あるアーキテクチャ向けに数年かけて作ったバックエンドは、他のCPUアーキテクチャでは使えません。各命令セットごとに個別の対応が必要になります。

LLVMのようなプロジェクトを使えば、多くの作業を共通化できますが、それでもコード生成と命令選択の部分は個別実装が必要です。

#### 14.1.3 バイトコードとは何か？

ここまでを整理してみましょう：

- ASTウォーク型インタプリタ：シンプルかつポータブルだが遅い
- ネイティブコード：超高速だが複雑でプラットフォーム依存

バイトコードはその中間の立場です。完全なネイティブコードの速度には及びませんが、実装が比較的容易で、なおかつ大幅な性能向上を見込めます。

構造的にはマシンコードに似ています。密な線形バイト列として命令を並べ、キャッシュにも優しい設計です。ただし、命令セットは仮想的なもので、より高水準で単純化されています。

この「理想的な仮想命令セット」を動かすために、仮想マシン（VM）を作ります。VMはバイトコードを一命令ずつ読み取り、適切な処理を行います。

このエミュレーション層にはオーバーヘッドがありますが、対価として得られる移植性は非常に高いです。CでVMを実装すれば、任意のハードウェア上で動かすことができます。

Pascalの p-code のような初期のバイトコードも、移植性を最優先して設計されました（p は portable の略です）。

このアプローチは、Python、Ruby、Lua、OCaml、Erlang など多くの言語が採用しています。私たちの新しいインタプリタ `clox` も、これに倣います。

今後の章では、`clox` のためのバイトコード生成、VM実行、各命令の実装などを段階的に進めていきます。

### 14.2 Getting Started

始めるのに最適な場所、それは `main()` 関数です！おなじみのテキストエディタを開いて、まずは次のように入力しましょう。

```c
#include "common.h"

int main(int argc, const char* argv[]) {
  return 0;
}
```

この小さな種から、私たちは仮想マシン全体を育てていくことになります。C言語は私たちにあまり多くのものを提供してくれないため、まずは土壌を整える必要があります。その一部をまとめておくのがこのヘッダファイルです：

```c
#ifndef clox_common_h
#define clox_common_h

#include <stdbool.h>
#include <stddef.h>
#include <stdint.h>

#endif
```

インタプリタ全体で使う定数や型などをまとめる場所として、このファイルは便利です。今のところは `NULL` や `size_t`、C99 で追加された `bool` 型、そして明示的なサイズの整数型（例：`uint8_t`）などを定義しています。

---

これで最初の準備が整いました。次のセクションでは、実際に「バイトコードの断片（チャンク）」を定義するモジュールを作成していきます。

### 14.3 Chunks of Instructions

次に、バイトコードをどのように表現するかを定義するモジュールを作っていきます。「chunk（チャンク）」という言葉を、私はバイトコードの一連のまとまりを指すために使っていました。なので、これを正式名称として採用します。

```c
#ifndef clox_chunk_h
#define clox_chunk_h

#include "common.h"

#endif
```

私たちのバイトコード形式では、それぞれの命令が1バイトのオペコード（opcode）を持ちます。この数値がどの種類の命令か（加算・減算・変数参照など）を決定します。

```c
#include "common.h"

typedef enum {
  OP_RETURN,
} OpCode;
```

今はまだ `OP_RETURN` という単一の命令だけを用意しています。これは「現在の関数からリターンする」という意味になります。今の段階ではこの命令は特に役立ちませんが、最もシンプルな命令の一つなのでここから始めます。

---

#### 14.3.1 命令の動的配列

バイトコードは命令列です。後に、命令と一緒に関連データも保存する必要が出てくるので、それらをまとめる構造体を今のうちに用意しておきましょう。

```c
typedef struct {
  uint8_t* code;
} Chunk;
```

この時点では、バイト列のラッパーとしての役割だけを持っています。ただし、バイトコードのサイズはあらかじめ分からないため、配列は動的に拡張可能である必要があります。

動的配列は非常に便利なデータ構造です。あまり派手な選択肢には思えませんが、以下のような利点があります：

- キャッシュに優しい密な格納構造
- 要素へのインデックスアクセスが定数時間
- 配列末尾への追加も定数時間で可能

こうした利点は、Javaの `ArrayList` クラスで `jlox` においても利用していました。Cではこれを自分で実装する必要があります。

```c
typedef struct {
  int count;
  int capacity;
  uint8_t* code;
} Chunk;
```

新しい要素を追加する場合、`count < capacity` なら既に十分なスペースがあります。その場合は新しい要素をそのまま格納して `count` を1つ増やすだけです。

もし余裕がなければ、配列を拡張する処理が必要です。このとき既存の要素を新しいメモリにコピーします。これでは `O(n)` に見えるかもしれませんが、実際にはアモルタイズド解析により `O(1)` と見なすことができます。

---

構造体ができたので、操作関数を作りましょう。Cにはコンストラクタがないため、明示的な初期化関数を使います：

```c
void initChunk(Chunk* chunk);
```

実装は以下の通りです：

```c
#include <stdlib.h>
#include "chunk.h"

void initChunk(Chunk* chunk) {
  chunk->count = 0;
  chunk->capacity = 0;
  chunk->code = NULL;
}
```

最初は完全に空の状態から始めます。生の配列すら確保されません。

次に、バイト列の末尾に命令を追加する関数を作ります：

```c
void writeChunk(Chunk* chunk, uint8_t byte);
```

中身はこちら：

```c
void writeChunk(Chunk* chunk, uint8_t byte) {
  if (chunk->capacity < chunk->count + 1) {
    int oldCapacity = chunk->capacity;
    chunk->capacity = GROW_CAPACITY(oldCapacity);
    chunk->code = GROW_ARRAY(uint8_t, chunk->code, oldCapacity, chunk->capacity);
  }

  chunk->code[chunk->count] = byte;
  chunk->count++;
}
```

もし余裕がなければ、容量を増やしメモリを再確保します。そのために以下のようなヘッダを用意します：

```c
#ifndef clox_memory_h
#define clox_memory_h

#include "common.h"

#define GROW_CAPACITY(capacity) \
    ((capacity) < 8 ? 8 : (capacity) * 2)

#endif
```

配列の拡張時には、通常サイズを倍にします。これによりコピー回数を減らし、効率的なアロケーションが可能になります。

```c
#define GROW_ARRAY(type, pointer, oldCount, newCount) \
    (type*)reallocate(pointer, sizeof(type) * (oldCount), \
                      sizeof(type) * (newCount))

void* reallocate(void* pointer, size_t oldSize, size_t newSize);
```

この `reallocate()` は `malloc()` / `realloc()` / `free()` をまとめて扱う共通インターフェースです。

```c
#include <stdlib.h>
#include "memory.h"

void* reallocate(void* pointer, size_t oldSize, size_t newSize) {
  if (newSize == 0) {
    free(pointer);
    return NULL;
  }

  void* result = realloc(pointer, newSize);
  if (result == NULL) exit(1); // メモリ不足
  return result;
}
```

---

Cでは、メモリ管理も自分たちで行う必要があります。つまり、解放も忘れてはいけません。チャンクを解放する関数を追加しましょう：

```c
void freeChunk(Chunk* chunk);
```

```c
void freeChunk(Chunk* chunk) {
  FREE_ARRAY(uint8_t, chunk->code, chunk->capacity);
  initChunk(chunk);
}
```

これに使うマクロはこちら：

```c
#define FREE_ARRAY(type, pointer, oldCount) \
    reallocate(pointer, sizeof(type) * (oldCount), 0)
```

これで基本的なチャンク構造と命令の格納が可能になりました。次のセクションでは、このチャンクを人間が読める形式で表示する「逆アセンブラ（disassembler）」を実装します。

### 14.4 Disassembling Chunks

これまでに、バイトコードのチャンクを作るための簡単なモジュールができました。今度は実際にチャンクを手動で組み立てて、それを試してみましょう。

```c
int main(int argc, const char* argv[]) {
  Chunk chunk;
  initChunk(&chunk);
  writeChunk(&chunk, OP_RETURN);
  freeChunk(&chunk);
  return 0;
}
```

これはチャンクに1つの命令を追加し、すぐに解放するというシンプルなコードです。ですが、果たしてこのコードは本当に動いているのでしょうか？今のところ、バイト列をメモリに押し込んだだけなので、私たちにはそれが確認できません。

そこで、人間が読める形でチャンクの中身を出力する「逆アセンブラ（disassembler）」を作ります。

---

#### 逆アセンブラとは？

アセンブラとは、命令名（ADDやMULTなど）を書いたファイルをバイナリ形式の機械語に変換するプログラムのことです。逆アセンブラはその逆で、機械語バイナリから人間が読める命令リストを出力します。

私たちはそれに似たものを作ります。チャンクを受け取って、中の命令を1つずつ出力するツールです。Loxユーザーが使うことはありませんが、Loxを作る開発者にとっては、内部動作を確認できる大事なツールです。

---

`main()` 関数でチャンクを作ったあと、それを逆アセンブラに渡してみましょう：

```c
initChunk(&chunk);
writeChunk(&chunk, OP_RETURN);
disassembleChunk(&chunk, "test chunk");
freeChunk(&chunk);
```

この `disassembleChunk()` 関数を新しいヘッダに定義します：

```c
#ifndef clox_debug_h
#define clox_debug_h

#include "chunk.h"

void disassembleChunk(Chunk* chunk, const char* name);
int disassembleInstruction(Chunk* chunk, int offset);

#endif
```

---

次に、逆アセンブラの実装をしていきます。

```c
#include <stdio.h>
#include "debug.h"

void disassembleChunk(Chunk* chunk, const char* name) {
  printf("== %s ==\n", name);

  for (int offset = 0; offset < chunk->count;) {
    offset = disassembleInstruction(chunk, offset);
  }
}
```

チャンク全体を逆アセンブルする関数です。ヘッダ行を表示してから、`disassembleInstruction()` を使って1命令ずつ解析していきます。

このループでは、`offset` を `++` していない点に注目してください。命令ごとにサイズが異なる可能性があるため、次の命令の開始位置は関数から返してもらいます。

---

個々の命令を処理する `disassembleInstruction()` 関数は以下の通りです：

```c
int disassembleInstruction(Chunk* chunk, int offset) {
  printf("%04d ", offset);

  uint8_t instruction = chunk->code[offset];
  switch (instruction) {
    case OP_RETURN:
      return simpleInstruction("OP_RETURN", offset);
    default:
      printf("Unknown opcode %d\n", instruction);
      return offset + 1;
  }
}
```

まず命令の位置（バイトオフセット）を表示し、その位置にあるバイトを読み込んで命令コードとします。`switch` 文で命令を識別し、それぞれに対応する表示関数へと分岐します。

未知の命令だった場合も、何らかの情報を表示してクラッシュしないようにしています。

---

現在定義されている `OP_RETURN` 命令は、最もシンプルなものなので以下のように出力します：

```c
static int simpleInstruction(const char* name, int offset) {
  printf("%s\n", name);
  return offset + 1;
}
```

命令名を表示して、次の命令へ1バイト分進めます。今後、新しい命令を追加していくたびにこの `switch` 文と補助関数を拡張していくことになります。

---

実行すると以下のような出力が得られます：

```bash

== test chunk ==
0000 OP_RETURN

```

やりました！これは私たちのコード表現における「Hello, World!」のようなものです。チャンクを作成し、命令を書き込み、それを読み出して人間向けに表示することができました。

バイナリ形式での命令のエンコードとデコードの仕組みが機能していることを確認できました。

### 14.5 Constants

チャンク構造がある程度整ってきたので、今度はチャンクに「データ」を格納する機能を追加していきましょう。今は命令列だけですが、実行中の処理結果としての「値」も必要になります。

たとえば次のコードを考えてください：

```lox
1 + 2;
```

この中で「3」は実行時に生成される値であり、コードには現れません。しかし「1」と「2」はリテラル値としてソースコードに含まれています。これらの値をバイトコードに変換するためには、「定数を生成する命令」が必要です。そして、それらの値をどこかに保存しなければなりません。

---

#### 14.5.1 値の表現

まだコードは実行しませんが、定数はインタプリタの静的・動的両面に関係するため、どのように「値」を表現するかを今のうちに考えておく必要があります。

とりあえずシンプルな出発点として、`double` 型（倍精度浮動小数点数）だけをサポートします。もちろん、後から拡張する予定です。

```c
#ifndef clox_value_h
#define clox_value_h

#include "common.h"

typedef double Value;

#endif
```

この `typedef` によって、Cコード中では常に `Value` 型を使い、将来的な型の変更にも対応しやすくしておきます。

---

#### 14.5.2 定数配列（value array）

定数を保存するために、チャンクごとに「定数リスト（定数プール）」を持たせます。命令の中で「定数を読み込む」際には、このリストのインデックスを指定してアクセスします。

```c
typedef double Value;

typedef struct {
  int capacity;
  int count;
  Value* values;
} ValueArray;
```

チャンクの `code` 配列と同様に、`ValueArray` も現在のサイズと使用数を持ちます。

必要な関数群：

```c
void initValueArray(ValueArray* array);
void writeValueArray(ValueArray* array, Value value);
void freeValueArray(ValueArray* array);
```

それぞれの実装：

```c
#include <stdio.h>
#include "memory.h"
#include "value.h"

void initValueArray(ValueArray* array) {
  array->values = NULL;
  array->capacity = 0;
  array->count = 0;
}
```

```c
void writeValueArray(ValueArray* array, Value value) {
  if (array->capacity < array->count + 1) {
    int oldCapacity = array->capacity;
    array->capacity = GROW_CAPACITY(oldCapacity);
    array->values = GROW_ARRAY(Value, array->values,
                               oldCapacity, array->capacity);
  }

  array->values[array->count] = value;
  array->count++;
}
```

```c
void freeValueArray(ValueArray* array) {
  FREE_ARRAY(Value, array->values, array->capacity);
  initValueArray(array);
}
```

---

#### チャンクへの統合

チャンク構造に定数配列を追加します：

```c
typedef struct {
  int count;
  int capacity;
  uint8_t* code;
  ValueArray constants;
} Chunk;
```

初期化と解放時に、定数リストも対象に含めます：

```c
void initChunk(Chunk* chunk) {
  chunk->count = 0;
  chunk->capacity = 0;
  chunk->code = NULL;
  initValueArray(&chunk->constants);
}
```

```c
void freeChunk(Chunk* chunk) {
  FREE_ARRAY(uint8_t, chunk->code, chunk->capacity);
  freeValueArray(&chunk->constants);
  initChunk(chunk);
}
```

そして、新しい定数を追加し、そのインデックスを返す関数：

```c
int addConstant(Chunk* chunk, Value value) {
  writeValueArray(&chunk->constants, value);
  return chunk->constants.count - 1;
}
```

---

#### 14.5.3 定数命令

定数をチャンクに保存できるようになったので、それを実行時に「読み込む」命令を追加しましょう。たとえば以下のようなコード：

```lox
print 1;
print 2;
```

このコードに対応するバイトコードは、値1と2を定数配列に追加し、それを読み込んで `print` する命令になります。

新しい命令 `OP_CONSTANT` を定義します：

```c
typedef enum {
  OP_CONSTANT,
  OP_RETURN,
} OpCode;
```

この命令は、バイト列に1バイトのオペコード（OP_CONSTANT）と、それに続く1バイトの定数インデックスを持ちます。

手動で試すときはこうなります：

```c
initChunk(&chunk);
int constant = addConstant(&chunk, 1.2);
writeChunk(&chunk, OP_CONSTANT);
writeChunk(&chunk, constant);
writeChunk(&chunk, OP_RETURN);
```

---

このままでは `disassembleInstruction()` が `OP_CONSTANT` を理解できません。対応を追加します：

```c
case OP_CONSTANT:
  return constantInstruction("OP_CONSTANT", chunk, offset);
```

補助関数 `constantInstruction()` の実装：

```c
static int constantInstruction(const char* name, Chunk* chunk, int offset) {
  uint8_t constant = chunk->code[offset + 1];
  printf("%-16s %4d '", name, constant);
  printValue(chunk->constants.values[constant]);
  printf("'\n");
  return offset + 2;
}
```

定数値の表示には次の関数を使います：

```c
void printValue(Value value) {
  printf("%g", value);
}
```

これで定数命令 `OP_CONSTANT` を正しく逆アセンブルできるようになりました。1バイトの命令と、その直後のオペランド（定数インデックス）の2バイト分で構成されています。

この章では、チャンクに定数値を保存し、それを参照する命令のしくみを整備しました。

### 14.6 Line Information

チャンクは、実行時に必要なほとんどの情報を持っています。`jlox` では構文木（AST）をたくさんのクラスで表現していましたが、`clox` ではそれを「バイト列」「定数」「ソース行番号」の3つの配列に集約できます。

ただし、まだ1つだけ情報が足りていません。それは「エラー時に表示するソースの行番号」です。

`jlox` では、トークンが持つ行番号情報をASTノードに渡していましたが、`clox` では構文木が存在しないため、別の方法が必要です。

---

#### ソース行番号の保存方法

バイトコード命令が、ソースコードの何行目から生成されたのかを知る必要があります。そのため、チャンク内で命令に対応する行番号情報を保持します。

最も単純な実装は、「命令ごとに行番号を格納する整数の配列を別に用意する」方法です。これにより、各命令バイトのインデックスで対応する行番号を引くことができます。

たとえば：

```c
typedef struct {
  int count;
  int capacity;
  uint8_t* code;
  int* lines;
  ValueArray constants;
} Chunk;
```

この `lines` 配列は `code` 配列と並行しており、サイズと内容の対応が1対1です。

---

初期化時と解放時に `lines` も扱います：

```c
void initChunk(Chunk* chunk) {
  chunk->count = 0;
  chunk->capacity = 0;
  chunk->code = NULL;
  chunk->lines = NULL;
  initValueArray(&chunk->constants);
}
```

```c
void freeChunk(Chunk* chunk) {
  FREE_ARRAY(uint8_t, chunk->code, chunk->capacity);
  FREE_ARRAY(int, chunk->lines, chunk->capacity);
  freeValueArray(&chunk->constants);
  initChunk(chunk);
}
```

---

`writeChunk()` 関数を拡張し、行番号も引数で渡すようにします：

```c
void writeChunk(Chunk* chunk, uint8_t byte, int line);
```

```c
void writeChunk(Chunk* chunk, uint8_t byte, int line) {
  if (chunk->capacity < chunk->count + 1) {
    int oldCapacity = chunk->capacity;
    chunk->capacity = GROW_CAPACITY(oldCapacity);
    chunk->code = GROW_ARRAY(uint8_t, chunk->code, oldCapacity, chunk->capacity);
    chunk->lines = GROW_ARRAY(int, chunk->lines, oldCapacity, chunk->capacity);
  }

  chunk->code[chunk->count] = byte;
  chunk->lines[chunk->count] = line;
  chunk->count++;
}
```

---

#### 行情報の逆アセンブル表示

`writeChunk()` の呼び出し側でも、仮の行番号を与えておきます（のちにパーサから正確な行番号が渡されるようになります）：

```c
int constant = addConstant(&chunk, 1.2);
writeChunk(&chunk, OP_CONSTANT, 123);
writeChunk(&chunk, constant, 123);
writeChunk(&chunk, OP_RETURN, 123);
```

逆アセンブラでも行番号を表示するように変更します：

```c
int disassembleInstruction(Chunk* chunk, int offset) {
  printf("%04d ", offset);

  if (offset > 0 && chunk->lines[offset] == chunk->lines[offset - 1]) {
    printf("   | ");
  } else {
    printf("%4d ", chunk->lines[offset]);
  }

  uint8_t instruction = chunk->code[offset];
  switch (instruction) {
    case OP_CONSTANT:
      return constantInstruction("OP_CONSTANT", chunk, offset);
    case OP_RETURN:
      return simpleInstruction("OP_RETURN", offset);
    default:
      printf("Unknown opcode %d\n", instruction);
      return offset + 1;
  }
}
```

命令が前の行と同じ行から来ている場合は `|` を表示し、新しい行の場合のみ行番号を表示します。

---

たとえば次のような出力が得られます：

```
== test chunk ==
0000  123 OP_CONSTANT         0 '1.2'
0002    | OP_RETURN
```

このように、ソース行番号とバイトコード命令の関係を逆アセンブラで確認できるようになりました。

行番号情報は実行時に参照することはほとんどありませんが、エラーメッセージに正確な情報を表示するために不可欠です。

これで、チャンク構造は「命令列」「定数」「行番号情報」をすべて持ち、バイトコード実行のための準備が整いました。