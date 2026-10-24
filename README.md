# libxml3（実験的）

libxml3 は、Ada/SPARK の固定境界 XML コアと、再コンパイルを前提にした
libxml2 風 C ソース/API サブセットを実験するプロジェクトです。
`libxml2.so.2` と同じ ABI や完全な libxml2 互換性は提供しません。

## セットアップとビルド

Ubuntu では `libxml2-dev`、`pkg-config`、Ada の GNAT/GPRbuild が必要です。
新しい環境では次のスクリプトが必要な Ubuntu 依存関係と固定版ツールチェーンを
セットアップします（`sudo -n` を使用するため、非対話 sudo が必要です）。

```sh
./eng/bootstrap.sh
export PATH="$HOME/.local/share/ada/candidate-14/bin:$PATH"
make build
make test-api
make reference
make test-encoding
make test-dom
make test-attributes
make check-inventory
make compare
make check
```

互換性の主基準は **libxml2 2.15.4** です。固定ソースから作る比較先と
公開宣言台帳・段階別の完了条件は [互換性基準](docs/compatibility-baseline.md)、
現在の評価範囲は [API台帳](docs/api-coverage.md) を参照してください。
`make compare-system` はOS付属版での補助比較です。

`make prove` は固定境界コア（`src/xml3_text.*`、`src/xml3_parser.*`、
`src/xml3_namespaces.*`、`src/xml3_encoding.*`）と、新しい DOM 状態・反映基盤
（`src/xml3_dom.*`、`src/xml3_dom_bridge.*`）を GNATprove で検査します。
名前空間は読み取りと
参照 API のみをサポートし、完全な XML/namespace conformance は主張しません。
**公開 C API はまだ旧 DOM 実装を使っており、新基盤への切替前です。**
新基盤の寿命・参照数・反映／解放手順の契約は証明対象ですが、現行 C API の
所有権、外部ポインター、ネイティブ allocator は保証範囲外です。保証範囲の詳細は
[docs/assurance.md](docs/assurance.md) と、コアの実行結果を記録した
[docs/proof-report.md](docs/proof-report.md) を参照してください。

## C の例

```c
#include <libxml3.h>

int main(void) {
    xmlDocPtr doc = xmlReadMemory("<root/>", 7, 0, 0, XML_PARSE_NONET);
    if (!doc) return 1;
    xmlFreeDoc(doc);
    return 0;
}
```

```sh
cc -Iinclude example.c -Llib -Wl,-rpath,"$PWD/lib" -lxml3 -o example
```

主なサブセットは、UTF-8/UTF-16LE/BE のメモリ入力、要素・属性・テキスト・CDATA・
コメント・PI の DOM 閲覧、読み取り専用の namespace lookup に加え、
限定的な DOM 作成・編集・解放 API、文字列関数、所有権付き getter です。
`xmlNewDoc`、`xmlNewNode`、`xmlNewText`、`xmlDocSetRootElement`、
`xmlAddChild`、`xmlUnlinkNode`、`xmlFreeNode` と namespace-free attribute の
作成・更新・削除 API をサポートします。attribute 名に colon は使えません。
namespace 作成・編集、namespace-qualified attribute 編集、copy、文書間移動、
serialization は未対応です。
構造 fields の直接変更はサポートしません。固定上限や
非対応機能を含む実際の API 一覧は [docs/compatibility.md](docs/compatibility.md)
にあります。将来の完全 API 互換は目標であり、現在の実装が達成したという意味
ではありません。

通常 parser profile は name component/PI target を 50,000 bytes、decoded value
を 10,000,000 bytes、深さを 256 に制限します。`XML_PARSE_HUGE` はそれぞれ
10,000,000 bytes、1,000,000,000 bytes、2,048 に拡張します。文書全体の 64 KiB
上限や 2,048-node policy cap はなく、C adapter は heap arena を必要に応じて
拡張します。これらは表現・割り当て可能性の保証や完全な DoS 防止を意味せず、
詳細な既知の互換差と境界は compatibility/assurance 文書を参照してください。

UTF-16 の binary input には、明示長を渡せる `xmlReadMemory` を使用します。
`xmlReadDoc`/`xmlParseDoc` は `strlen` を使うため binary UTF-16 用ではありません。
DOM の名前と値は常に UTF-8 です。`UTF-8`/`UTF8`、`UTF-16`/`UTF16`、
`UTF-16LE`、`UTF-16BE` は ASCII case-insensitive で、generic UTF-16 は
little-endian です。明示 encoding は宣言より優先しますが宣言文法は検査され、
不明な encoding を暗黙 fallback しません。自動検出と宣言の不一致は成功時 warning
113 になります。変換前の malformed UTF-16 は IO/code 81 at 1:1、parser error
position は変換後 UTF-8 の character column で示されます。

エラー API は `xmlGetLastError`、明示 reset/copy と OS thread ごとの所有状態を
提供し、成功後も直前のエラーを保持します。互換方針は、last-error 保持など害のない
既知の挙動は可能な範囲で合わせる一方、memory corruption、不正 access、無制限な
resource use、悪用可能な upstream bug は再現しないことです。固定版との既知の差は
比較で明示し、namespace の fail-closed 動作と value near-limit 差も保持します。
