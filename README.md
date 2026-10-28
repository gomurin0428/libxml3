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

`make build` は通常実行用の `lib/libxml3.so` を生成します。証明用の
アサーション・事前／事後条件・ghost 処理は実行時に評価せず、入力検査、
Ada の範囲チェックと整数オーバーフロー検査は維持します（`-gnatp` は使用しません）。
`make build-development` は全アサーションを有効にした開発用ライブラリを
`lib/development/libxml3.so` に生成し、オブジェクトも通常実行用と分離します。
`make test-development` はこのライブラリで公開 API の小規模回帰を実行します。
開発用では全体整合性の再計算が非常に重く、深いツリーの性能測定には適しません。
`make prove` と Ada のコア／接続層テストは引き続き全アサーションを有効にし、
通常実行用プロファイルによって証明条件を省略しません。

`make prove` は固定境界コア（`src/xml3_text.*`、`src/xml3_parser.*`、
`src/xml3_namespaces.*`、`src/xml3_encoding.*`）と、DOM 状態・反映・Store・
parser materialization・Runtime（`src/xml3_dom*.{ads,adb}`）を GNATprove で検査します。
名前空間の読み取り・参照と限定的な宣言／qualified attribute 編集をサポートし、
完全な XML/namespace conformance は主張しません。
公開 DOM API は共通の SPARK Store/Runtime に委譲され、pthread mutex の
trusted Ada/C Guard で直列化されます。Runtime の DOM 操作は証明対象ですが、
C ABI 変換、外部ポインターとネイティブレイアウト、allocator、mutex 自体は
形式証明の対象外です。保証範囲の詳細は [docs/assurance.md](docs/assurance.md) と
[docs/proof-report.md](docs/proof-report.md) を参照してください。
これらの資料には
mutex 同期、allocator の非再入、非同期 cancellation を行わないこと、および
借用 facade の並行使用・解放を呼び出し側が同期することを前提として記録しています。
`make check` は DOM コア、C facade 投影、公開 API の並列回帰を実行します。

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
コメント・PI の DOM 閲覧、namespace lookup に加え、
限定的な DOM 作成・編集・解放 API、文字列関数、所有権付き getter です。
`xmlNewDoc`、`xmlNewNode`、`xmlNewText`、`xmlNewTextLen`、`xmlNewDocText`、`xmlNewDocTextLen`、`xmlNewDocProp`、`xmlDocSetRootElement`、
`xmlAddChild`、`xmlNewChild`、`xmlNewTextChild`、`xmlNodeAddContent`、`xmlNodeAddContentLen`、`xmlNodeSetContent`、`xmlNodeSetContentLen`、`xmlUnlinkNode`、`xmlFreeNode`、`xmlNewNs`、`xmlSetNs`、
`xmlFreeNs`、`xmlNewNsProp`、`xmlSetNsProp`、`xmlUnsetNsProp`、`xmlNewProp`、
`xmlSetProp`、`xmlUnsetProp`、`xmlRemoveProp`、`xmlFreeProp` をサポートします。
`xmlNewDocNode` / `xmlNewDocRawNode` は文書に所属する未接続の要素を作成します。
前者は文字参照を展開し、後者は入力をそのままテキスト子に保持します。
`xmlNewDocProp` は任意の管理中文書に所属する未接続・無namespaceの属性を作成します。
値の文字参照は展開し、NULL/空文字列はいずれも text child を作りません。
属性は `xmlFreeProp` で解放でき、文書先行解放後も保持されます。`xmlAddChild` で
文書未所属の属性、または接続先と同じ文書に所属する属性を要素へ接続できます。
既存属性との照合は local name と namespace
href による expanded name で行い、接続成功後に一致属性を置き換えます。既に最後の属性なら
重複があっても no-op です。namespace reconciliation と detached attribute の単独シリアライズは
このサブセットではサポートしません。
`xmlUnlinkNode` は属性も切り離せます。値・文書所属・namespace の保持は継続し、
切り離した属性は編集・同一文書内での再接続・`xmlFreeProp` による解放ができます。
`xmlAddSibling` は親に接続された node の兄弟列の末尾へ追加します。通常 child と属性は
混在させず、text の結合・同じ expanded name の属性の置換は `xmlAddChild` と共通です。
親のない兄弟列、文書間移動、属性値内部への兄弟追加は未対応です。
要素の前向き走査に加え、`xmlLastElementChild` / `xmlPreviousElementSibling` による
末尾・前方への走査も可能です。コメント・テキスト等は飛ばします。
`xmlTextMerge` は通常のテキストノードを結合し、成功時だけ第二引数を切り離して解放します。
同じ文書のノード、または文書に属さない第二引数に対応します。
`xmlTextConcat` は text・CDATA・comment・PI に限定した長さ指定追記です。
要素・属性は変更せず拒否し、負の長さでは NUL 終端文字列を読みます。
`xmlNodeIsText` / `xmlIsBlankNode` は、SPARK 管理中の node の種別と XML 空白を
読み取り専用で判定します。CDATA は後者の対象ですが、前者では text としません。
`xmlNodeGetLang` は node と ancestor の最寄りの `xml:lang` を所有権付きで返し、
空の値も継承を止めます。`xmlNodeGetSpacePreserve` は element のみを対象にし、
`default` / `preserve` 以外の値は ancestor まで探索します。対応する setter は
element に `xml:lang` / `xml:space` を設定し、NULL language は空値、space の
0 は `default`、非0は `preserve` です。
`xmlSetProp` は namespace-aware QName を
解決し、malformed QName と未束縛 prefix を拒否します。`xmlDocDumpMemoryEnc`
は明示的なUTF-8出力のみをサポートし、encoding名のASCII大小文字を区別せず、
宣言には指定表記を保持します。XML 1.0以外、未対応encoding、無効なXML名・文字・
namespaceは拒否します。source encoding/standalone metadata は保持されず宣言には
出力しません。暗黙encoding、formatting、ファイル出力、DTD等は未対応です。
`xmlNewComment` / `xmlNewPI` と文書付きの `xmlNewDocComment` / `xmlNewDocPI` で
コメント・処理命令も作成できます。
`xmlNewCDataBlock` は長さ指定でCDATAを作り、文書を指定してもまだ親へ接続しません。
作成時はraw文字列をコピーし、XML構文・文字・予約PI名の検査は出力時に行います。
NULLと空のcontentは区別し、NULL contentのコメントは出力しません。
属性／namespace copy と文書間移動も未対応です。
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
