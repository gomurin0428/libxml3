# C ソース/API 互換性

libxml3 は `libxml3.so` という別名の共有ライブラリです。以下は実装済みの
再コンパイル向けサブセットであり、libxml2 の ABI、構造体サイズ、SONAME、
未記載のフィールドを提供しません。

全API互換への主基準はlibxml2 2.15.4です。
[固定基準・台帳・工程](compatibility-baseline.md)を参照してください。

## ヘッダーと API

インストール対象ヘッダーは `libxml3.h` と次の五つです。

* `libxml/parser.h`: `xmlInitParser`、`xmlCleanupParser`、`xmlReadMemory`、
  `xmlParseMemory`、`xmlReadDoc`、`xmlParseDoc`
* `libxml/tree.h`: ノード型、`xmlDocGetRootElement`、`xmlFreeDoc`、
  `xmlNewDoc`、`xmlNewNode`、`xmlNewText`、`xmlDocSetRootElement`、`xmlAddChild`、
  `xmlNodeAddContent`、`xmlNodeAddContentLen`、`xmlNodeSetContent`、`xmlNodeSetContentLen`、`xmlNewChild`、`xmlNewTextChild`、
  `xmlUnlinkNode`、`xmlFreeNode`、
  `xmlNewNs`、`xmlSetNs`、`xmlFreeNs`、`xmlNewNsProp`、`xmlSetNsProp`、
  `xmlUnsetNsProp`、
  `xmlNodeGetContent`、`xmlGetProp`、`xmlHasProp`、`xmlSearchNs`、
  `xmlSearchNsByHref`、`xmlHasNsProp`、`xmlGetNsProp`、`xmlGetNoNsProp`、
  要素 sibling/child 関数
* `libxml/xmlstring.h`: `xmlStrcmp`、`xmlStrEqual`、`xmlStrlen`
* `libxml/xmlmemory.h`: `xmlFree`
* `libxml/xmlerror.h`: `xmlError` の互換レイアウト、last-error の取得・リセット・コピー
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
属性 prefix、`xmlDoc` は `_private` から `doc` までの compact な文書 prefix に
`version` field を追加して公開します。upstream の `doc` と `version` の間にある
fields は省略しているため、これは upstream の `xmlDoc` layout や ABI の再現では
ありません。
`xmlNs` は `next`、`type`、`href`、`prefix`、`_private`、`context` を公開します。
DOM fields の直接変更はサポートせず、構造編集には下記 API を使用してください。
アプリケーションが設定できる例外は `_private` で、libxml3 はその値を参照・解放
しません。属性には値を持つテキスト子ノード
があります。名前と値は UTF-8 の NUL 終端文字列です。要素の `content` は NULL、
テキスト名は `"text"`、コメント名は
`"comment"`、CDATA 名は NULL、PI 名は target です。名前空間付き要素・属性の
`name` は local name です。名前空間宣言は通常の属性ではなく、宣言元要素の
`nsDef` にソース順で公開されます。要素と名前空間付き属性の `ns` は有効な binding
を指し、default namespace は無接頭辞属性には適用しません。`xmlns:xml` は明示
されても `nsDef` に重複登録せず、組み込み `xml` namespace は検索 API から取得
できます。`xmlNs.context` は NULL です。parsed namespace records と文字列は
document arena に格納されます。`xmlFreeDoc` は現在接続されている subtree を
反復解放して document の参照を解放しますが、detached live node や借用 namespace
が参照を保持している arena とその文字列は最後の参照が解放されるまで残ります。
node の `ns` は移動時に再調整されません。宣言 scope 外へ移動した node 自身の
lookup は NULL になり得ますが、子孫の lookup は shadowing を尊重して ancestor
の retained `ns` binding を参照します。

### 限定的な作成・編集 API

`xmlNewDoc`、`xmlNewNode`、`xmlNewText`、`xmlDocSetRootElement`、
`xmlAddChild`、`xmlNewChild`、`xmlNewTextChild`、`xmlNodeAddContent`、`xmlNodeAddContentLen`、`xmlNodeSetContent`、`xmlNodeSetContentLen`、`xmlUnlinkNode`、`xmlFreeNode`、`xmlNewNs`、`xmlSetNs`、
`xmlFreeNs`、`xmlNewNsProp`、`xmlSetNsProp`、`xmlUnsetNsProp` を実装しています。
`xmlNewDoc` は
version が NULL の場合 `"1.0"` を使い、渡された C string は値を検証せずコピー
します。parser が受け付ける文書は XML 1.0 です。`xmlNewNode` の name と
`xmlNewText` の content は NUL 終端 byte string としてコピーされますが、
XML name/UTF-8 の妥当性検証は行いません。`xmlNewText(NULL)` は content が NULL
の text node を作ります。

`xmlAddChild` は document/element 親と element、text、comment、CDATA、PI 子を
扱います。element 親ではこの子型を受け入れますが、document 親への text/CDATA
直下追加と、すでに root がある document への別 element 追加は拒否します。
隣接 text は入力内容を先に確保してから既存末尾に結合し、既存末尾のポインターを
返します。`xmlAddChild` による属性追加、`xmlUnlinkNode` による attribute unlink、
未対応 node type の編集は拒否します。

`xmlNodeAddContent` は raw UTF-8 C string を追加し、entity reference を展開しません。
element/attribute の末尾に text child があればその content を置換して同じ facade を
保ち、なければ `"text"` node を追加します。text、CDATA、comment、PI は content を
連結します。NULL/empty content と document node は no-op、NULL node と未登録 facade
は失敗します。無効な XML 文字列は保持し、serializer 側で検査します。
`xmlNodeSetContent` は text/CDATA/comment/PI の raw content を置換し、element/attribute
では predefined entity と decimal/hex numeric reference だけをデコードした replacement
text child を準備して attach し、その後で旧 child subtree を解放します。準備や attach が
失敗した場合は旧 tree を維持します。NULL と empty は scalar content で区別し、
element/attribute ではどちらも child を空にします。literal CR/LF/TAB は保持します。
element/attribute の入力に含まれる malformed/unknown references、invalid UTF-8/XML
characters は tree error 115 で拒否し、tree を変更しません。scalar node の入力は raw のまま
保持し、その検証は serialization 時に行います。DTD/general entity node type は未対応です。
これは安全側の拒否であり、upstream の無音動作や unbound namespace の修復を再現しません。
`xmlNewChild` は element/document の末尾に子要素を追加します。namespace が NULL のときは
element parent の namespace を継承し、明示指定時は登録済みの namespace を使います。
内容は `xmlNodeSetContent` と同じ限定的な reference decoder を使い、NULL/empty は子を
持たない要素になります。入力の検査・子要素と text の作成が完了してから親に接続し、
失敗時には未公開の領域だけを片付けます。document fragment/HTML/DTD/general entity は
未対応です。名前は `xmlNewNode` と同じくそのままコピーし、XML name 検査は出力時に行います。
`xmlNewTextChild` は同じ作成・接続処理を使いますが、内容を文字参照として解釈せずに
そのまま text に保存します。`&amp;` も5文字のままで、出力時に `&amp;amp;` になります。
NULL content は子を作らず、empty string は空の text 子を作る点も固定版と合わせています。
`xmlNewText` と同様に raw bytes を保持し、不正な UTF-8/XML 文字は出力時に拒否します。
`xmlNodeSetContentLen` は同じ置換処理を使い、正の長さは byte 数として扱い、その範囲の
最初の NUL または末尾までを読みます。長さ 0 では content を読みません。負の長さは
固定版と同じ NUL-terminated 入力です。NUL 後の見えない bytes を scalar の確保領域に
残す upstream の挙動は再現せず、論理的な文字列だけを保存します。要素・属性では途中で
切れた参照や UTF-8 を拒否し、元の tree を保持します。長さには既存の入力上限を適用します。
長さ 0 は空文字列として既存 setter に渡し、要素の children を空にします。固定版の parser は
長さ 0 でも先頭 byte を読み、非 NUL なら空の text child を作るため、この挙動は再現しません。
`xmlNodeAddContentLen` は raw text を長さ指定で追記します。置換とは異なり、長さ 0 以下
または NULL content は何もしません。正の長さは最初の NUL または指定末尾までを読み、
NUL 後の見えない bytes は保存しません。先頭が NUL でも正の長さの入力なら、必要に応じて
空の text child や空文字列を作る固定版の挙動を保ちます。この判断と text 結合・接続・後始末は
SPARK 側です。UTF-8 の途中で区切られた raw byte も追記でき、出力時に完成した文字列を検査します。
`xmlDocSetRootElement` は既存 root 内の descendant を新 root に昇格させられ、
旧 root subtree は detached のまま維持します。`xmlFreeNode` は element、text、
comment、CDATA、PI の subtree を先に安全に unlink してから反復解放します。
document、attribute、namespace pointer は code 115 で拒否します。これは呼び出し側に
unlink を要求する upstream 動作より安全な差です。

`xmlNewProp` と `xmlUnsetProp` は namespace-free attribute に限り、colon を含む名前を
拒否します。`xmlSetProp` は QName を解決でき、`xmlRemoveProp` と `xmlFreeProp` は
qualified attribute にも適用できます。`xmlNewProp(NULL, ...)` は detached attribute を作成し、
重複名は既存順の末尾に追加します。NULL value は text child なし、empty value は
empty text child です。`xmlSetProp` は同名の no-namespace attribute があれば
attribute pointer、`_private`、sibling links を保って値を置換し、なければ末尾に追加
します。置換時に旧 value children は解放されます。新しい値の割り当てを置換前に
完了するため、OOM では元の property list と値を保持します。`xmlUnsetProp` と
`xmlRemoveProp` は attached attribute を削除し、欠落・非対応の場合は `-1` を返します。
`xmlFreeProp` は detached attribute も解放でき、attached attribute は先に安全に
unlink します。これは attached attribute の unlink を呼び出し側に要求する upstream
動作より安全な差です。`xmlSetProp` の QName は単一 prefix/local-name 組に限り、
各部を UTF-8 NCName として検証します。unprefixed 名は no-namespace property の
既存動作を保ち、prefixed 名は有効 scope 内の binding を使います。Malformed QName
と未束縛 prefix は tree error 115 で拒否します。documentless node の `xml:lang` と
`xml:space` は XML namespace 宣言を作成または再利用し、後続の属性操作が失敗すると
暗黙宣言も rollback します。値は raw string として扱い、entity syntax を展開しません。

`xmlNewNs` は href/prefix をコピーし、NULL と empty string を区別します。同じ要素
上の重複 prefix は拒否し、失敗時は既存宣言 chain を変更しません。`xmlSetNs` は
element/attribute の namespace 参照のみを変更し、NULL で解除します。`xmlFreeNs`
は detached の独立作成 namespace のみを解放でき、attached 宣言や parsed namespace
の手動解放は拒否します。namespace が node から借用中であれば、その参照がなくなる
まで native storage は保持されます。subtree 解放では宣言 chain を unlink してから
element arena を解放し、独立作成宣言の reservation を一度だけ解放します。

`xmlNewNsProp` は detached/attached attribute を作り、異なる namespace 内の同じ
local name を許します。`xmlSetNsProp` と `xmlUnsetNsProp` は prefix/namespace pointer
ではなく namespace URI と local name で属性を照合します。置換は既存 attribute の
address、`_private`、list position と sibling links を保ち、allocation 失敗では
旧 namespace/value を保ちます。`xmlRemoveProp` と `xmlFreeProp` は qualified attribute
にも適用されます。

添付可能なのは documentless subtree または同一文書に属する subtree のみです。
他文書との移動や、別文書に関連付いた node の documentless parent への移動は
変更前に拒否されます。root replacement は元 root の sibling 位置を保ち、
top-level comment/PI を残します。既存 parsed arena は per-node 参照で保持され、
その arena の最後の live node/reference が解放されるまで全 arena memory を保持
することがあります。これは parsed strings の既存 inline 格納を保つための tradeoff
です。detached parsed node とその inherited namespace/attribute backing bytes は
source document が解放されても node 自体が解放されるまで有効です。借用 namespace
で作成した node も namespace owner を pin します。

caller は有効な library pointer lifetime、直接の tree field 書き換えをしないこと、
同時 mutation を避けること、double free をしないことに責任を持ちます。DOM の
logical topology、owner/reservation accounting、namespace retention と mutation/release
policy は SPARK Store が管理します。C adapter は guarded Runtime 呼び出し、ABI/string
変換、status 変換に限定されます。attribute/namespace copy と cross-document move は
未対応です。`xmlDocDumpMemoryEnc` は明示 UTF-8 の XML 1.0 メモリ出力だけをサポートし、
宣言には指定 encoding 表記を保持します。default encoding、formatting、DTD、file output
は未対応です。source encoding/standalone metadata は保持されず、宣言に出力しません。
要素のない document は宣言のみを出力する場合があります。
`xmlNewComment` / `xmlNewPI` は既存のSPARK作成・寿命管理を使って独立nodeを作成します。
raw文字列はコピーし、NULLと空contentを区別します。NULL PI targetは拒否しますが、
XML名・文字、予約target、comment/PIの構文はシリアライズ時に検査します。
NULL contentのcommentは出力しません。文書付き作成APIとnode登録callbackは未対応です。

呼び出し中、入力バッファは読み取り可能かつ不変である必要があります。入力は
借用されて DOM にコピーされ、以後保持されません。`xmlFreeDoc` は現在接続されて
いる文書 subtree と document の参照を解放します。detached node が残る場合は
その arena backing も保持され、node の解放には `xmlFreeNode`、detached attribute
の解放には `xmlFreeProp` を使います。
`xmlFreeDoc` 後の document handle は使用できません。`xmlNodeGetContent` と
`xmlGetProp` の返却値は
`xmlFree` で解放してください。`xmlStrlen` は C `int` に収まらない長さに
対して `-1` を返します。NULL 入力、サイズ不正、非対応オプション、
エンコーディング、構文エラーは通常 API では NULL を返します。
`xml3ReadMemory` は `XML3_STATUS_*` を通じて理由を返します。
NUL 終端の `xmlReadDoc`/`xmlParseDoc` は呼び出し側が提供する有効な C 文字列を
必要とし、表現可能な入力サイズを超える文字列は拒否します。`xmlReadMemory` の
長さは C `int` で表現可能で、コアの表現境界内でなければなりません。

## 対応範囲と資源プロファイル

`xmlReadMemory` は UTF-8 と UTF-16LE/BE を受け付け、DOM 内の名前と値は常に UTF-8
です。UTF-16 は matching BOM、XML 宣言を示す BOMless byte signature、または明示
encoding で判定します。encoding 名は ASCII 大文字小文字を区別せず、
`UTF-8`/`UTF8`、`UTF-16`/`UTF16`、`UTF-16LE`、`UTF-16BE` を認識します。
generic `UTF-16`/`UTF16` は pinned libxml2 built-in handler の観測に合わせて
little-endian として扱います。明示 encoding は XML 宣言より優先しますが、
宣言の文法検査は省略しません。未知の明示 encoding は code 32 で拒否し、
暗黙の UTF-8 fallback は行いません。自動検出 encoding と宣言の不一致は
成功した parse で warning code 113 を保持します。UTF-8/no-BOM の文書が
`UTF-16` を宣言していても decoder を途中切替せず code 81 で拒否します。

UTF-16 の binary input には長さを受け取る `xmlReadMemory` を使用してください。
NUL 終端文字列を `strlen` で測る `xmlReadDoc`/`xmlParseDoc` は binary UTF-16
entrypoint ではありません。UTF-16 prevalidation の malformed input は parse 前に
IO/code 81、line 1 column 1 として報告します。XML parser の位置は変換後 UTF-8
入力の decoded character column です。1 GB value profile は実際の大規模 allocation
では試していません。

文書全体に対する 64 KiB の上限はありません。通常プロファイル
では各 QName の prefix/local-name component および PI target はそれぞれ最大
50,000 bytes、各 decoded/normalized text・attribute・comment・CDATA・PI value は
最大 10,000,000 bytes、要素深さは 256 です。`XML_PARSE_HUGE` は各 name component
上限を 10,000,000 bytes、各 value 上限を 1,000,000,000 bytes、深さを 2,048 に
切り替えます。QName の prefix と local name は別々に数えます。value の上限は
参照の decode/正規化後の各 value に適用され、入力全体や文書内の全 value の合計
には適用されません。

これらは parser resource profile であり、コア表現上限とは別です。入力 byte index
の表現境界は `Integer'Last - 16`、node ID の表現境界はその半分です。2,048
node という総数上限はありません。C `int` の入力長が表現境界を超える場合は拒否
します。C adapter は呼び出しごとの heap workspace と DOM block を確保し、node
arena の不足時は上限まで幾何学的に拡張して同じ parser を再実行します。
SPARK core は allocator/FFI を使用しませんが、C adapter の割り当てや所有権境界は
proof 範囲外です。1 GB value profile の厳密な境界はその大きさで実 allocation
test をしていません。

2.15.4 との境界互換性には既知の差があります。固定版は通常の名前と PI target
50,000 bytes、通常の plain text 10,000,000 bytes を受理し、それぞれ 1 byte 超過を
拒否します。depth 256/257 および `XML_PARSE_HUGE` の depth 2,048/2,049 も
比較対象です。一方、固定版の attribute/CDATA/PI value には nominal limit より少し
小さい長さでも内部 buffer/lookahead による拒否が起きる場合があります。これを
libxml3 の profile と同じ ceiling に見せるために値を変更せず、未解消の互換性差
として扱います。

受理する option は `XML_PARSE_NONET`、`XML_PARSE_NOERROR`、
`XML_PARSE_NOWARNING`、`XML_PARSE_HUGE` のみです。前 3 つは no-op です。
`XML_PARSE_HUGE` は上記資源プロファイルだけを変更し、DTD、recovery、その他の
未対応機能を有効にしません。URL はメタデータとして無視され、ファイル、
ネットワーク、外部エンティティ resolver、callback、設定可能な XML allocator
callback は使用しません。libxml3 は libxml2 と同名の `xml*` symbols を公開する
ため、同一プログラムで libxml2 と一緒に link しないでください。DOM と getter
文字列は C の `malloc`/`free` allocator family を使用します。

DTD、未知の entity、複雑な libxml2 parser options、ファイル入力、
SAX、XInclude、検証、上記に列挙していない変更 API、XPath、スキーマ、
UTF-8/UTF-16 以外の encoding は未対応です。XML 読み込み時の属性値と通常テキストでは predefined/numeric reference を処理し、
CDATA・コメント・PI は reference 展開しません。
名前空間の対応は読み取りと参照 API に限ります。QName は XML 1.0 Fifth Edition の Unicode NCName の
単一 prefix/local-name 組だけを受理し、prefix は宣言済みでなければなりません。
無効な QName、予約 namespace binding、未束縛 prefix、または同じ expanded
attribute name は `XML3_STATUS_MALFORMED` として fail-closed で拒否します。
libxml2 が namespace error を報告しながら tree を返す入力でも、libxml3 は tree
を返しません。要素名・属性名・namespace prefix・PI target は UTF-8 で読み取り、
Unicode 正規化や大文字小文字変換をせず、元のバイト列を保持・比較します。
名前の先頭では結合文字を拒否し、補助平面は仕様どおり U+EFFFF まで受理します。
上記の限定的 namespace mutation API 以外の namespace writer API は未対応です。
`xmlGetProp`/`xmlHasProp` は local name で検索し、URI を考慮する場合は
namespace-aware getter/query API を使用してください。
名前空間 URI の entity 参照には libxml2 版による差があります。固定ターゲットの
libxml2 2.15.4 と libxml3 は `urn:&amp;one` を `urn:&one` として扱いますが、
OS の libxml2 2.9.13 は同じ値を `urn:&#38;one` として返します。OS 版との補助比較は
この fixture で差分を報告します。合否判定には固定版 2.15.4 を使用してください。
固定版との比較を `make compare` に統合する変更は独立した
[PR #2](https://github.com/gomurin0428/libxml3/pull/2) に含まれます。
任意の C API sanitizer 実行では C 側の検査を有効にできますが、Ada allocator
とコンパイラ生成コードは完全には sanitizer 計測されません。

## Error reporting and compatibility policy

`xmlGetLastError`, `xmlResetLastError`, `xmlCopyError`, and `xmlResetError` expose
the supported error-record lifecycle. Error state is per OS thread; a successful
read retains the prior error until explicit reset. Error code, domain, level,
line, column, and `int1` are compared for the cases covered by
`tests/error-oracle.json`. `make test-errors` also compares its five-step
`state_sequence` against both libraries in one process per library: malformed
input, successful input, NULL input, negative size, then reset and successful
input. For invalid literal XML characters, ASCII values are
reported in `int1`; literal non-ASCII invalid characters currently use `int1=0`
rather than a decoded code point. `str1`, `str2`, and `str3` are currently NULL;
payload parity and exact message wording are not yet supported. Secondary or
cascading diagnostics may differ where libxml3 preserves the precise first
failure. Invalid arguments that the pinned reference leaves silent also preserve
the prior error. Ada `XML3_Errors` owns error records and copied strings,
including the URL/file value. A pthread TLS destructor releases per-thread
records; this behavior, including foreign pthread callers, is tested on Linux
with glibc. Other POSIX platforms have not yet been validated.
Parser-context APIs and structured error-handler APIs are not implemented.

Compatibility follows a safety-first policy: mimic harmless documented or
observed API quirks, such as retaining the last error after a successful parse,
but do not emulate memory corruption, invalid memory access, unbounded or unsafe
resource use, or exploitable bugs for differential equality. Deviations are
tested and documented explicitly, not normalized away. The frozen
`tests/limit-error-oracle.json` records attribute, CDATA, and PI near-limit
lookahead behavior in libxml2 2.15.4. `make test-resources` reads those inputs
and numeric expectations directly and compares both libraries, with explicit
libxml3 expectations for the documented boundary differences. libxml3 retains its own
10,000,000-byte value ceiling rather than duplicating those internal buffer
quirks as unexplained limits. Namespace errors fail closed with no tree, even
where libxml2 returns a recovery tree; this is an incomplete recovery behavior,
not a claim that the upstream behavior is exploitable. The frozen DTD case is
also an explicit difference: libxml2 returns a tree while libxml3 rejects the
unsupported DTD feature with parser error code 115 and no tree.

Error reporting and allocator behavior are outside the formal SPARK proof.
The allocation-failure harness uses a C `malloc` interposer that delegates to
glibc `__libc_malloc`; it is not run under ASan leak checking because those
allocations bypass the sanitizer's allocator interception.

The length-taking `xmlReadMemory` entry point accepts UTF-8 and UTF-16LE/BE;
the DOM always stores names and values as UTF-8. Encoding names are ASCII
case-insensitive aliases `UTF-8`/`UTF8`, `UTF-16`/`UTF16`, `UTF-16LE`, and
`UTF-16BE`. Generic UTF-16 is little-endian to match the pinned built-in handler
observation. Explicit encoding takes precedence over the declaration, but does
not bypass declaration grammar. Unknown explicit encodings fail with code 32;
there is no silent fallback. An auto-detected/declaration mismatch is retained
as warning 113 on successful parse. UTF-8 without a BOM that claims UTF-16 is
not switched mid-document and fails with code 81. `xmlReadDoc`/`xmlParseDoc`
use `strlen` and are not binary UTF-16 entry points. UTF-16 prevalidation errors
report IO/code 81 at 1:1 before parsing; parser positions refer to decoded
UTF-8 character columns. The frozen observations in `tests/encoding-oracle.json`
are compared without normalizing snapshot fields, with explicit per-case reasons
for intentional libxml3 differences. A 1 GB value allocation is not tested.

## 保証について

`XML3_Text`、`XML3_Parser`、`XML3_Namespaces`、`XML3_Encoding` の固定境界コアは
proof project に含まれます。証明範囲は実行時境界、算術、契約、終了性であり、
libxml2 との機能的同等性や全ての脆弱性がないことを証明するものではありません。
C adapter、FFI、公開ポインター、allocator 境界は形式検証の対象外です。
DOM Store の論理 topology、owner/reservation accounting、namespace retention と
mutation/release policy は SPARK proof の対象です。
完全な libxml2 API 目標と現在の実装を混同しないでください。
