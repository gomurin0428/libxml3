# C ソース/API 互換性

libxml3 は `libxml3.so` という別名の共有ライブラリです。以下は実装済みの
再コンパイル向けサブセットであり、libxml2 の ABI、構造体サイズ、SONAME、
未記載のフィールドを提供しません。

## ヘッダーと API

インストール対象ヘッダーは `libxml3.h` と次の五つです。

* `libxml/parser.h`: `xmlInitParser`、`xmlCleanupParser`、`xmlReadMemory`、
  `xmlParseMemory`、`xmlReadDoc`、`xmlParseDoc`
* `libxml/tree.h`: ノード型、`xmlDocGetRootElement`、`xmlFreeDoc`、
  `xmlNodeGetContent`、`xmlGetProp`、`xmlHasProp`、`xmlSearchNs`、
  `xmlSearchNsByHref`、`xmlHasNsProp`、`xmlGetNsProp`、`xmlGetNoNsProp`、
  要素 sibling/child 関数
* `libxml/xmlstring.h`: `xmlStrcmp`、`xmlStrEqual`、`xmlStrlen`
* `libxml/xmlmemory.h`: `xmlFree`
* `libxml/xmlversion.h`: libxml3 のバージョン識別子
* `libxml3.h`: 上記の包括ヘッダーと `xml3ReadMemory`

`XML_ELEMENT_NODE` (1)、`XML_ATTRIBUTE_NODE` (2)、`XML_TEXT_NODE` (3)、
`XML_CDATA_SECTION_NODE` (4)、`XML_PI_NODE` (7)、`XML_COMMENT_NODE` (8)、
`XML_DOCUMENT_NODE` (9)、`XML_NAMESPACE_DECL` (18) を使用します。C++ からは
`extern "C"` で利用できます。

## DOM と所有権

ヘッダーは、この実装が公開する構造体 prefix のみを定義し、libxml2 の完全な
構造体やその ABI を定義しません。`xmlNode` は `_private`、`type`、`name`、
`children`、`last`、`parent`、`next`、`prev`、`doc`、`ns`、`content`、
`properties`、`nsDef` を公開します。`xmlAttr` は `_private` から `ns` までの
属性 prefix、`xmlDoc` は `_private` から `doc` までの文書 prefix のみです。
`xmlNs` は `next`、`type`、`href`、`prefix`、`_private`、`context` を公開します。
DOM fields は読み取り専用です。アプリケーションが設定できる例外は `_private`
で、libxml3 はその値を参照・解放しません。個別 node/attribute の解放 API は
なく、DOM 全体を `xmlFreeDoc` で解放します。属性には値を持つテキスト子ノード
があります。名前と値は UTF-8 の NUL 終端文字列です。要素の `content` は NULL、
テキスト名は `"text"`、コメント名は
`"comment"`、CDATA 名は NULL、PI 名は target です。名前空間付き要素・属性の
`name` は local name です。名前空間宣言は通常の属性ではなく、宣言元要素の
`nsDef` にソース順で公開されます。要素と名前空間付き属性の `ns` は有効な binding
を指し、default namespace は無接頭辞属性には適用しません。`xmlns:xml` は明示
されても `nsDef` に重複登録せず、組み込み `xml` namespace は検索 API から取得
できます。`xmlNs.context` は NULL です。namespace records と文字列も文書所有で、
`xmlFreeDoc` が公開ポインターをたどらず一括解放します。

呼び出し中、入力バッファは読み取り可能かつ不変である必要があります。入力は
借用されて DOM にコピーされ、以後保持されません。文書と DOM は `xmlFreeDoc`
まで所有されます。`xmlNodeGetContent` と `xmlGetProp` の返却値は
`xmlFree` で解放してください。`xmlStrlen` は C `int` に収まらない長さに
対して `-1` を返します。NULL 入力、サイズ不正、非対応オプション、
エンコーディング、構文エラーは通常 API では NULL を返します。
`xml3ReadMemory` は `XML3_STATUS_*` を通じて理由を返します。
NUL 終端の `xmlReadDoc`/`xmlParseDoc` は最大 65,536 バイトを走査し、
その範囲に終端 NUL が必要です。

## 対応範囲と固定上限

メモリ入力は 1〜65,536 バイト、コアのノード数は 2,048、要素の深さは 64
です。入力は UTF-8 のみです。オプションは `XML_PARSE_NONET`、
`XML_PARSE_NOERROR`、`XML_PARSE_NOWARNING` のみ受理し、いずれも no-op です。
URL はメタデータとして無視され、ファイル、ネットワーク、外部エンティティ
resolver、callback、設定可能な XML allocator callback は使用しません。libxml3
は libxml2 と同名の `xml*` symbols を公開するため、同一プログラムで libxml2
と一緒に link しないでください。DOM と getter 文字列は C の `malloc`/`free`
allocator family を使用します。

DTD、未知の entity、複雑な libxml2 parser options、ファイル入力、
SAX、XInclude、検証、変更 API、XPath、スキーマ、エンコーディング変換は
未対応です。属性値と通常テキストでは predefined/numeric reference を処理し、
CDATA・コメント・PI は reference 展開しません。
名前空間の対応は読み取りと参照 API に限ります。QName は ASCII NCName の
単一 prefix/local-name 組だけを受理し、prefix は宣言済みでなければなりません。
無効な QName、予約 namespace binding、未束縛 prefix、または同じ expanded
attribute name は `XML3_STATUS_MALFORMED` として fail-closed で拒否します。
libxml2 が namespace error を報告しながら tree を返す入力でも、libxml3 は tree
を返しません。Unicode XML names、namespace mutation、namespace writer API は
未対応です。`xmlGetProp`/`xmlHasProp` は local name で検索し、URI を考慮する場合は
namespace-aware getter/query API を使用してください。
名前空間 URI の entity 参照には libxml2 版による差があります。固定ターゲットの
libxml2 2.15.4 と libxml3 は `urn:&amp;one` を `urn:&one` として扱いますが、
OS の libxml2 2.9.13 は同じ値を `urn:&#38;one` として返します。OS 版との補助比較は
この fixture で差分を報告します。合否判定には固定版 2.15.4 を使用してください。
固定版との比較を `make compare` に統合する変更は独立した
[PR #2](https://github.com/gomurin0428/libxml3/pull/2) に含まれます。
任意の C API sanitizer 実行では C 側の検査を有効にできますが、Ada allocator
とコンパイラ生成コードは完全には sanitizer 計測されません。

## 保証について

`XML3_Text` と `XML3_Parser` の固定境界コアには別の SPARK 契約と検査結果が
あります。`XML3_Namespaces` も proof project に含まれます。C adapter、FFI、
公開ポインター、allocator、所有権境界は形式検証の対象外です。完全な libxml2
API 目標と現在の実装を混同しないでください。
