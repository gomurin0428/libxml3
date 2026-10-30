# C ソース/API 互換性

libxml3 は `libxml3.so` という別名の共有ライブラリです。以下は実装済みの
再コンパイル向けサブセットであり、libxml2 の ABI、構造体サイズ、SONAME、
未記載のフィールドを提供しません。

全API互換への主基準はlibxml2 2.15.4です。
[固定基準・台帳・工程](compatibility-baseline.md)を参照してください。

## ヘッダーと API

`libxml/entities.h` は `xmlEncodeSpecialChars`、`xmlEncodeEntitiesReentrant`、
`xmlGetPredefinedEntity`、`xmlGetDocEntity` を公開します。`xmlEncodeSpecialChars` の文書引数は
固定版と同じく未使用です。NULL入力は診断なしでNULL、空入力は独立した空文字列を
返します。`<`・`>`・`&`・二重引用符を定義済み実体参照、CRを `&#13;` に置換し、
apostrophe・LF・TAB・有効な非ASCII文字は保持します。既存の参照も通常の文字列として
エスケープします。結果は呼び出し側が `xmlFree` で解放し、入力の所有権は変わりません。
固定版の不正な制御文字を `&#xFFFD;` に置換する動作、不正UTF-8やXMLで無効なUnicode
文字を保持する動作は再現せず、診断とNULLで失敗します。走査・展開サイズは
`Max_Bytes` までで、確保失敗でも入力は保持します。`Escape_Special_Bytes` がC文字列の
中間コピーなしで直接処理します。`Escape_Bytes_Pass` はUTF-8/XML検査・計測・構築を共有し、
NULまたは最初の不正な単位で停止します。構築時は計測済みサイズを上限にし、失敗時は
部分出力を解放します。これはDTD・一般実体対応ではなく、XML文字列のエスケープのみです。
pointerの有効性・読み取り可能範囲と安定性、native byte effects、allocator、ABIと完全な
公開意味論は信頼境界に残ります。String版 `Escape_Special` は内部DOM用途に残しています。

`xmlEncodeEntitiesReentrant` は NULL input なら `doc` を検証せず、診断なしで NULL を返します。
non-NULL input では `doc == NULL` または登録済み Document_Node を受け付け、空 input も独立した空文字列にします。
Store/Runtime は入力をaddressのまま受け取り、文書の登録確認に失敗すると入力を読まずに拒否します。
成功後に `Escape_Special_Bytes` で直接検証・計測・構築し、C文字列の中間コピーは作りません。
走査・展開上限の超過は共通の resource-limit 診断（code 114）です。旧C文字列変換で走査上限を
検出した場合の code 115 とは異なります。不正UTF-8/XML・不正文書は引き続き code 115 です。
`<`・`>`・`&` は名前付き参照、CR は `&#13;`、非ASCIIは大文字 hex の文字参照にし、quote・TAB・LF は保持します。
document encoding はモデルに保持しないため、明示 UTF-8 文書でも非ASCIIを文字参照にします。
不正UTF-8/XMLは診断と NULL で拒否し、不正文字置換・保持の reference 動作は再現しません。
既存参照の展開、一般実体・HTML処理は対象外です。結果は独立した `xmlFree` 所有で DOM を変更せず、
allocation failure は NULL を返します。native pointer/readability, byte access, allocation/copy/free,
ABI と完全な C semantics は信頼境界に残ります。

`xmlNodeIsText` は text のみで 1、CDATA を含む他の kind・NULL・未登録 node で 0 です。
`xmlIsBlankNode` は text/CDATA の content が NULL・空・XML 空白のみなら 1、他は 0 です。
空白は space・tab・LF・CR に限り、垂直タブ・form feed・NBSP・全角空白は含めません。
判定は child の内容に再帰せず、管理中の content 長を上限に読み取ります。
追記・置換・結合後や文書先行解放後も同じ管理状態を使い、DOM・所有権を変更しません。
外部で作った構造体や C 構造体フィールドの直接書換えは対象外です。

`libxml/chvalid.h` は upstream で deprecated の `xmlIsChar`, `xmlIsBlank`,
`xmlIsBaseChar`, `xmlIsCombining`, `xmlIsDigit`, `xmlIsExtender`,
`xmlIsIdeographic`, `xmlIsPubidChar` の8 scalar classifier と
`xmlCharInRange` を公開します。
`xmlIsChar` は XML 1.0 Char production の TAB/LF/CR, U+0020–D7FF, E000–FFFD,
10000–10FFFF を 1、それ以外を 0 と判定し、許可範囲内の supplementary noncharacter を追加除外しません。
`xmlIsBlank` は U+0009・U+000A・U+000D・U+0020 のみ 1、それ以外を 0 とします。
`xmlIsBaseChar` と `xmlIsCombining` は current name rules ではなく、
pinned upstream `chvalid.h` / `codegen/ranges.inc` の歴史的 range set を再現します:
前者は197個の16-bit範囲と sub-256 の5範囲、後者は95個の16-bit範囲です。
BaseChar 集合に U+4E00 は含まれず、Combining 集合に U+0346 は含まれません。
`xmlIsDigit` は歴史的な固定集合 U+0030–0039, 0660–0669, 06F0–06F9, 0966–096F,
09E6–09EF, 0A66–0A6F, 0AE6–0AEF, 0B66–0B6F, 0BE7–0BEF, 0C66–0C6F,
0CE6–0CEF, 0D66–0D6F, 0E50–0E59, 0ED0–0ED9, 0F20–0F29 のみを 1 とし、
Tamil の U+0BE6 は含みません。`xmlIsExtender` は U+00B7, 02D0–02D1, 0387,
0640, 0E46, 0EC6, 3005, 3031–3035, 309D–309E, 30FC–30FE のみ、
`xmlIsIdeographic` は U+3007, 3021–3029, 4E00–9FA5 のみを 1 とします。
`xmlIsPubidChar` は XML PubidChar の ASCII 集合 (SPACE/LF/CR, ASCII 英数字,
`-'()+,./:=?;!*#@$_%`) のみを 1 とし、TAB は含みません。
これらは現代の Unicode category や locale ではなく、その他の値はすべて 0 です。
引数は UTF-8 bytes でなく unsigned scalar number で、高い unsigned 値は安全に false になります。
scalar classifier は pure SPARK helper を使い、pointer/native range-table access・allocation・diagnostic・DOM access・lock を行いません。
歴史的分類は現在の NCName 規則に適用しません (U+037F, `a` に続く U+0346,
U+0BE6 と U+9FA6 も引き続き受理されます)。
`xmlCharInRange` は別の generic lookup です。`val < 0x10000` なら short table、
それ以外なら full unsigned domain の long table を選び、inclusive `low..high`
range を overflow-safe な lower-middle binary search で調べます。選択された count が正で
byte span を `ptrdiff_t` で表せ、table が非NULLの場合だけ検索します。NULL group・非正の count・
NULL table・表現上限を超える count では診断なしで0を返します。descriptor 全体は readable/aligned
である必要がありますが、未選択の配列は読みません。range table は caller 所有の
borrowed data で、昇順・非重複かつ readable/aligned であり、呼び出し中に変更されない必要があります。
global `xmlIs*Group` tables, upstream header macros, DTD subsystem は未対応です。
C ABI、native layout/pointer/extents/byte reads と完全な upstream 意味論は信頼境界に残ります。

`xmlNodeGetLang` は node 自身から parent をたどり、最寄りの XML namespace
`lang` の値を独立した `xmlFree` 所有文字列として返します。空または NULL 値の属性も
空文字列として継承を止めます。`xmlNodeGetSpacePreserve` は element のみを受け付け、
XML namespace の `space` が `preserve` なら 1、`default` なら 0、それ以外や未指定なら
ancestor を検索し、見つからなければ -1 です。`xml:lang` は text・attribute・comment
などの node からも継承します。文書所属だけでは値を継承しません。
`xmlNodeSetLang` / `xmlNodeSetSpacePreserve` は element のみを変更し、成功 0、
不正引数 1、確保失敗 -1 です。NULL language は属性の削除でなく空値を設定し、
space の 0 は `default`、その他の値は `preserve` です。QName の namespace 解決、
親走査、値判定、所有権は SPARK Store/Runtime にあり、native pointer/ABI は信頼境界です。

`libxml/tree.h` の `xmlIsXHTML` は固定版 `tree.c:8851` の identifier 判定を実装します。
両方 NULL の場合のみ -1、それ以外は public ID
`-//W3C//DTD XHTML 1.0 Strict//EN`, `-//W3C//DTD XHTML 1.0 Frameset//EN`,
`-//W3C//DTD XHTML 1.0 Transitional//EN` の3種を先に照合し、続いて system URI
`http://www.w3.org/TR/xhtml1/DTD/xhtml1-strict.dtd`,
`http://www.w3.org/TR/xhtml1/DTD/xhtml1-frameset.dtd`,
`http://www.w3.org/TR/xhtml1/DTD/xhtml1-transitional.dtd` の3種を照合します。
一致は 1、その他は 0 で、public ID が一致した場合 system ID は無視します。
照合は NUL 終端 byte 列の case-sensitive な完全一致です。
UTF-8 検証、URI 解決、DTD 読み込み、HTML parsing、allocation、diagnostic、lock、
DOM access はありません。native pointer/readability、byte access、ABI と完全な
upstream 意味論は信頼境界です。

`xmlTextConcat` は text・CDATA・comment・PI のみに追記し、成功で 0、失敗で -1 を返します。
要素・属性・document・未登録 node は内容を変えず拒否し、NULL content でも kind を検査します。
非負の長さは読み取り上限、0 では入力を読みません。負の長さ（-1 以外も固定版と同様）は
NUL 終端文字列として読みます。NULL content は無変更ですが、非NULLの空入力は
NULL content を空文字列へ変えます。既存 content と重なる入力にも対応します。
固定版と違い、正の長さでも最初の NUL で読み取りを止め、その後のバイトを保持しません。
XML参照の展開はせず、UTF-8・comment/PI delimiter の検査は出力時に行います。
確保失敗では既存 content・リンク・所属を保ちます。`xmlNodeAddContent[Len]` の
対象 kind・長さ・戻り値の規約は変更していません。

`xmlTextMerge` は通常の text node の内容を順に結合し、第一引数の位置を保ったまま
第二引数を切り離して解放します。隣接している必要はなく、属性内の text にも対応します。
片方の node が NULL なら他方を変更せず返します（この場合は node kind も検査しません）。
両方 non-NULL なら同一 node・未登録 node・text 以外を拒否します。第二引数の content が
NULL なら第一引数の content pointer を保ち、空文字列なら結合用の空バッファを確保します。
同じ文書、または文書に属さない第二引数のみ対応し、異なる文書所属は変更せず拒否します。
参照展開はせず、UTF-8/XML 検査は出力時です。no-escape text variant は未対応です。
成功後の第二引数を再利用・再解放してはいけません。確保失敗では両方の内容・リンクを保持します。
`xmlAddChild` の text 結合も同じ Store 処理を使い、NULL content の第二引数では
第一引数の NULL/空文字列の違いを変えないようにしました。

`xmlLastElementChild` / `xmlPreviousElementSibling` は要素・文書の末尾や直前の sibling から
SPARK 管理状態のリンクをたどり、最初に見つかった element を返します。
text・CDATA・comment・PI を飛ばし、NULL・該当なし・不適切な node kind では NULL です。
切り離し・再接続後のリンクも同じ管理状態を参照します。結果は既存 node のポインタで、
新しいノードや文字列を確保しません。fragment・HTML・DTD・entity node は未対応です。
文書の末尾走査は対応しますが、文書や属性を起点とする previous-sibling 走査は NULL です。

インストール対象ヘッダーは `libxml3.h` と次の五つです。

* `libxml/parser.h`: `xmlInitParser`、`xmlCleanupParser`、`xmlReadMemory`、
  `xmlParseMemory`、`xmlReadDoc`、`xmlParseDoc`
* `libxml/tree.h`: ノード型、`xmlDocGetRootElement`、`xmlFreeDoc`、
  `xmlNewDoc`、`xmlNewNode`、`xmlNewText`、`xmlNewTextLen`、`xmlNewDocText`、`xmlNewDocTextLen`、`xmlNewDocProp`、`xmlDocSetRootElement`、`xmlAddChild`、`xmlAddSibling`、`xmlAddPrevSibling`、`xmlAddNextSibling`、
  `xmlNodeAddContent`、`xmlNodeAddContentLen`、`xmlNodeSetContent`、`xmlNodeSetContentLen`、`xmlNodeGetLang`、`xmlNodeGetSpacePreserve`、`xmlNodeSetLang`、`xmlNodeSetSpacePreserve`、`xmlNewChild`、`xmlNewTextChild`、
  `xmlUnlinkNode`、`xmlFreeNode`、
  `xmlNewNs`、`xmlSetNs`、`xmlFreeNs`、`xmlCopyNamespace`、`xmlNewNsProp`、`xmlSetNsProp`、
  `xmlUnsetNsProp`、
  `xmlNodeGetContent`、`xmlGetNodePath`、`xmlGetLineNo`、`xmlGetProp`、`xmlHasProp`、`xmlSearchNs`、
  `xmlSearchNsByHref`、`xmlGetNsList`、`xmlGetNsListSafe`、`xmlHasNsProp`、
  `xmlGetNsProp`、`xmlGetNoNsProp`、`xmlBuildQName`、`xmlSplitQName2`、`xmlSplitQName3`、
  要素 sibling/child 関数
* `libxml/xmlstring.h`: `xmlStrchr`、`xmlStrstr`、`xmlStrcasestr`、`xmlStrsub`、`xmlStrcmp`、`xmlStrcasecmp`、`xmlStrncmp`、`xmlStrncasecmp`、`xmlStrEqual`、`xmlStrQEqual`、`xmlStrlen`、`xmlCheckUTF8`、`xmlUTF8Strlen`、`xmlUTF8Strsize`、`xmlUTF8Size`、`xmlUTF8Charcmp`、`xmlUTF8Strloc`、`xmlUTF8Strndup`、`xmlUTF8Strsub`、`xmlUTF8Strpos`、`xmlGetUTF8Char`、`xmlStrdup`、`xmlStrndup`、`xmlCharStrdup`、`xmlCharStrndup`、`xmlStrncatNew`、`xmlStrcat`、`xmlStrncat`
* `libxml/xmlmemory.h`: `xmlFree`
* `libxml/uri.h`: `xmlURIEscapeStr` / `xmlURIUnescapeString` / `xmlNormalizeURIPath`。他のURI APIは未対応
* `libxml/parserInternals.h`: `xmlCopyCharMultiByte` と `xmlCopyChar` のみ。deprecated な低level writerであり、parser-internals subsystem全体は未対応
* `libxml/xmlerror.h`: `xmlError` の互換レイアウト、last-error の取得・リセット・コピー
* `libxml/xmlversion.h`: libxml3 のバージョン識別子
* `libxml3.h`: 上記の包括ヘッダーと `xml3ReadMemory`

`XML_ELEMENT_NODE` (1)、`XML_ATTRIBUTE_NODE` (2)、`XML_TEXT_NODE` (3)、
`XML_CDATA_SECTION_NODE` (4)、`XML_PI_NODE` (7)、`XML_COMMENT_NODE` (8)、
`XML_DOCUMENT_NODE` (9)、`XML_NAMESPACE_DECL` (18) を使用します。C++ からは
`extern "C"` で利用できます。

### UTF-8 文字比較

`xmlUTF8Charcmp` は最初の文字幅だけをunsigned byteとして比較し、Unicode code pointを減算しません。両方NULLなら0、左だけNULLなら-1、右だけNULLなら1で、NULL分岐では非NULL側を読みません。両方nonNULLなら左leadを `UTF8_Lead_Size` で分類し、無効leadは右を読む前にerror 9 / -1です。幅1..4（NULは1）内で最初のbyte差を返し、差・NUL・幅で停止します。不一致は直ちに返し、全sequenceをdecode/validateしません（`E2 x` 対 `E3 y` は診断なし-1、`a` 対 `0xff` は診断なし-158）。byte一致時だけ `Get_UTF8_Char` が左のfirst scalarを検証してから0を返し、same-pointerでも検証します。malformed/truncated/overlong/surrogate/out-of-rangeなequal prefixはerror 9 / -1となり、pinned referenceの0とは異なります。有効なfirst character同士はreferenceと同じbyte差で、suffixは無視します。case folding、normalization、grapheme matching、XML character validationは行わず、control/noncharacterはUTF-8として許可します。C adapterは `Invalid` を `XML_FROM_TREE` / `XML_ERR_INVALID_CHAR` に写像しますが、diagnostic allocation失敗時は標準OOM error 2、予期しない例外はerror 1を報告し、結果はいずれも-1です。比較は通常allocationせず入力を変更しませんが診断はallocationすることがあります。成功比較は旧last errorを消しません。診断された-1を正当なbyte差-1と区別するには事前にlast errorをresetして確認してください。左文字幅の最大4 byte以外にcapはありません。入力は触れたbyte範囲でreadableかつ安定している必要があり、equal prefixの検証はaliasでもfirst scalar全体またはNULまで読む場合があります。SPARKの結果範囲・`Invalid => -1` contractとnative-call preconditionsは、native byte、readability、pointer validity/stability、C mapping/ABI、完全なUnicode意味論を証明しません。

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

`xmlSearchNs` / `xmlSearchNsByHref` は、文書を持たない node で組み込み `xml` binding が
見つからない場合、最も近い element に宣言を作成します。text・属性からも親へたどり、
要素の祖先がない単独 text/属性では作成しません。作成失敗は NULL とエラーで返し、
既存の宣言を保ちます。成功後の再検索は同じ namespace を返します。
宣言は既存 Store の規則で末尾に追加します（固定版の先頭追加とは順序が異なります）。
prefix 検索は NULL href の宣言を飛ばしますが、href 検索は NULL と空文字列を区別します。
NULL href 宣言も同じ prefix の祖先宣言を href 検索で隠す、という固定版の扱いを保ちます。

`xmlGetNsList` / `xmlGetNsListSafe` は管理対象 node facade のみを対象とし、node から祖先へたどり、各 element の namespace
宣言を近い要素順・`nsDef` 宣言順に返します。同じ prefix（default prefix を含む）は
最も近い宣言だけを含み、NULL / 空 href の宣言も列挙します。`doc` は無視され、
implicit `xml` binding と、`node->ns` にだけ存在して祖先に宣言されていない binding は
追加しません。safe API は出力を先に NULL にし、出力 pointer が NULL、node が NULL、
namespace facade、未管理 node、または空の結果では 1、結果があれば 0、配列確保失敗では
-1 を返します。legacy API は空・無効入力・失敗で NULL を返します。返却配列は呼び出し側が
`xmlFree` で解放し、配列内の namespace pointer は借用で、元 node の寿命を超えて保持できません。
ネイティブ pointer / 配列 ABI と完全な public semantics は証明対象外です。

### 限定的な作成・編集 API

`xmlNewDoc`、`xmlNewNode`、`xmlNewText`、`xmlNewTextLen`、`xmlNewDocText`、`xmlNewDocTextLen`、`xmlNewDocProp`、`xmlDocSetRootElement`、
`xmlAddChild`、`xmlNewChild`、`xmlNewTextChild`、`xmlNodeAddContent`、`xmlNodeAddContentLen`、`xmlNodeSetContent`、`xmlNodeSetContentLen`、`xmlUnlinkNode`、`xmlFreeNode`、`xmlNewNs`、`xmlSetNs`、
`xmlFreeNs`、`xmlCopyNamespace`、`xmlNewNsProp`、`xmlSetNsProp`、`xmlUnsetNsProp`,
`xmlNodeGetLang`、`xmlNodeGetSpacePreserve`、`xmlNodeSetLang`、
`xmlNodeSetSpacePreserve` を実装しています。
`xmlNewDoc` は
version が NULL の場合 `"1.0"` を使い、渡された C string は値を検証せずコピー
します。SPARKの`Measure`で上限内のNULを探し、文書所有の領域へ直接byteコピー
するため、C側の走査・中間Stringはありません。空文字列も独立した終端領域を持ち、
元のversion文字列を解放しても利用できます。走査上限超過は従来どおりcode115、
確保失敗はOOMで、部分的な文書を返しません。parser が受け付ける文書は XML 1.0 です。`xmlNewNode` の name と
`xmlNewText` の content は NUL 終端 byte string としてコピーされますが、
XML name/UTF-8 の妥当性検証は行いません。`xmlNewText(NULL)` は content が NULL
の text node を作ります。

`xmlAddChild` は document/element 親と element、text、comment、CDATA、PI 子を
扱い、element 親には managed attribute も追加できます。document 親への text/CDATA
直下追加と、すでに root がある document への別 element 追加は拒否します。隣接 text は
入力内容を先に確保してから既存末尾に結合し、既存末尾のポインターを返します。
attribute の接続は属性が文書未所属、または接続先と同じ文書に所属する場合に限り、cross-document move は
属性と親の状態を変えず拒否します。既存属性との照合は local-name bytes と namespace-href
bytes による expanded name で行い、namespace object が異なっても href が同じなら一致します。
null namespace は namespace object と区別し、non-null namespace の null href は拒否します。
最初の一致属性は新属性の Attach 成功後に解放されます。既に最後の属性を再追加する場合は、
先行する重複があっても no-op です。namespace reconciliation は行いません。
`xmlUnlinkNode` は通常 child に加え、管理中の attribute も切り離します。
親の property list を更新し、属性の parent/prev/next を NULL にしますが、値の子・文書所属・
namespace と owner pin は保持します。NULL と既に未接続の node は no-op です。
文書や namespace pointer、未登録 facade は拒否します。切り離しに native allocation は不要です。
属性は文書を先に解放しても利用でき、`xmlFreeProp` で解放します。この保持は安全性のための
固定版との差異です。切り離しても cross-document move や namespace reconciliation は許可しません。

`xmlAddSibling` は、親に接続された管理中 node を基準に、兄弟列の末尾へ追加します。
Store で親と node 種別を検査して `Add_Child` を再利用し、通常 child と属性の混在は拒否します。
同じ node を両引数に渡す場合は NULL、別 node を基準に既存末尾を再指定する場合は no-op です。
element/document 親の通常 child と、element 親の属性に対応します。テキスト結合時は末尾を返し、
入力 node を解放します。確保失敗では両 node の内容とリンクを保持します。属性では expanded name
が一致する旧属性を接続成功後に解放します。親のない兄弟列・属性値内部への兄弟追加は未対応です。
文書所属・循環・document 直下の text/CDATA・複数 root の制約は `xmlAddChild` と同じです。

`xmlAddPrevSibling` / `xmlAddNextSibling` は親を持つ managed content sibling の直前または
直後に挿入します。対象は element の通常 child、document 直下の comment/PI と唯一の
root、および既存 `Attach_Child` が許す attribute-value text です。NULL/self、attribute
sibling、document node、parentless sibling list、cycle、追加 document root、cross-document
move は graph を変えずに拒否します。すでに隣接している child は同じ node pointer を返し、
通常の insert/reorder は node identity を維持して確保を行いません。隣接 text は結合せず、
attribute sibling・parentless list・cross-document insertion・namespace reconciliation は
未対応です。公開 C API は partial / not-proved であり、SPARK model の構造・順序・所属
contract の検証を native pointer/ABI、facade projection、C status mapping、完全な API 意味論の
証明と同一視しません。

`xmlReplaceNode` は old の parent/prev/next の位置へ、同じ文書に所属する cur を挿入し、
old を parent/prev/next のない detached node として返します。通常の child の first/middle/last
置換、別 parent に接続中または detached の同一文書内 node の移動、document root の置換と
old の子孫の root 昇格、`cur == NULL`
の unlink をサポートし、adjacent text は結合しません。attribute/non-attribute mismatch は
変更せず old を返す upstream quirk を保持します。両方が attribute の場合は duplicate-name
や ownership bypass を避けるため安全に拒否し、cross-document move、cycle、extra document root
も既存の Store graph 検査により拒否します。old == cur、NULL/unmanaged/parentless old、
unmanaged cur は拒否します。C adapter は null/lock/status/exception の変換だけを担当し、
pointer validity、facade synchronization、ABI、native allocation/free と full public semantics は
trusted boundary / public implementation partial として残ります。

`xmlGetLastChild` は管理中の node の末尾 child を kind で絞らず返します。要素以外にも
text/comment/CDATA/PI、document の末尾 child、属性値の text を取得できます。
NULL・child のない node・namespace・未登録 facade は NULL です。読み取りでは内容や
リンクを変更せず、native allocation を行わず、既存の last error も消去しません。

`xmlFreeNodeList` / `xmlFreePropList` は指定 node / attribute から `next` の末尾までを、
各 subtree・属性値を含めて解放します。NULL は no-op、未登録 pointer と種別違いは拒否します。
`xmlFreeNodeList` は document 自体・attribute 自体・namespace を受け付けませんが、
document の child と attribute 値の text は対象です。`xmlFreePropList` は qualified
attribute にも対応し、namespace 宣言や残る利用者の参照は保持します。
安全性のため、固定版と異なり attached list の親・直前の兄弟のリンクも自動で更新します。
参照版テストはこのリンクだけを呼び出し側で修復し、解放済み pointer を利用しません。
一覧の走査・解放・寿命判断はSPARK側で行い、最後に一度 native facade を同期します。

`libxml/valid.h` の `xmlValidateNameValue` / `xmlValidateNamesValue` /
`xmlValidateNmtokenValue` / `xmlValidateNmtokensValue` は字句検査のみです。
XML 1.0 の Name / Names / Nmtoken / Nmtokens を既存の名前分類・厳密な UTF-8
復号と共有し、有効なら 1、NULL/空/不正文字/走査上限超過なら 0 を返します。
DTD 検証・ID の一意性・IDREF の参照解決は行いません。colon は各位置で許され、QName
検証とは異なります。Names は SPACE 区切りで前後の空白を禁止します。Nmtokens は
固定版同様、先頭だけ XML 空白全般を飛ばし、末尾の SPACE も受け付けます。
区切りや末尾の TAB/LF/CR は受け付けません。確保・文書参照・診断変更はなく、NUL や
最初の不正文字で走査を止めます。上限は `Max_Bytes` で、巨大な C 入力の構築ではなく
小さい上限の Ada 検査で境界を確認します。native pointer readability/extent、byte effects、
C ABI と完全な public semantics は trusted/unproved です。

`xmlValidateName` / `xmlValidateNCName` / `xmlValidateQName` / `xmlValidateNMToken`
はXML 1.0第五版の名前文字をUTF-8で検査します。Nameはコロンを許可し、NCNameは禁止、
QNameは任意のprefixと必須のlocal nameをそれぞれNCNameとして検査します。
NMTokenは非空の名前文字列で、数字・結合文字なども先頭に置けます。
`space` が非0なら前後のXML空白（space/tab/CR/LF）だけを許可し、内部空白は禁止です。
正常は0、不正な名前・UTF-8は1、NULL・走査上限・内部例外は-1です。
NUL終端までが対象で、名前空間の束縛は検査せず、既存のlast errorも変更しません。
入力ポインタをSPARKの `Text.Buffers.Validate_Name` / `Scan_Name` へ直接渡し、
`valid.h` の字句検査と共通の有界走査・文字分類・UTF-8復号を使います。C側は mode/flag と
戻り値の変換だけで、文字列コピー・確保はありません。NUL・最初の不正文字で停止し、
末尾空白の後の非ASCII byteは後続byteを読まず拒否します。上限前に不正を確定すれば1、
判定がつかず上限を越える読み取りが必要なら-1で、途中までの名前を正常扱いしません。
上限は小さい `Last` のAda検査で確認し、巨大なC入力そのものは構築していません。
native pointer readability/extent、byte effects、C ABI、完全な公開意味論は証明外です。

`xmlSplitQName2` / `xmlSplitQName3` は QName の lexical validation や namespace 解決ではなく、
NUL 終端 input の最初の `:` だけを探す raw-byte split です。埋め込み NUL より後は見ません。
`:` がない、先頭にある、または
最初の `:` が末尾なら split せず NULL を返し、後続の `:`、空白、不正 UTF-8 は local/raw
byte の一部として保持します。`xmlSplitQName2` は prefix と local の独立した NUL 終端コピーを
返し、各 pointer は `xmlFree` で解放します。prefix の out pointer は先に NULL にされ、split
失敗時も NULL です。`xmlSplitQName3` は input 内の local suffix を借用して返し、prefix の
byte length を成功時だけ `int` 出力します。失敗時は length を変更しません。borrowed pointer の
有効期間は original input と同じで、入力を書き換えると参照先も変わります。QName3 の suffix は
解放せず、input が生存する間だけ使います。どちらも DOM/Store 状態を変更せず、stateless な C
adapter は mutex を使いません。
両方とも `QNames.Locate_Prefix` が直接入力を走査し、先頭コロンやNULで
直ちに停止します。最初のコロンの次の1byteが非NULなら、local の残り・終端・UTF-8は読まず
借用位置を返します。QName2はその後、localの終端まで元入力からの同じ上限内で計測し、
既存の `Buffers.Copy_Span` でprefixとlocalを独立にコピーします。C文字列の中間コピーは
不要です。2つ目の確保に失敗したらprefixを解放し、両出力をNULLに保ち、既存のmemory診断を
報告します。判定不能な走査上限はNULLと診断115で、QName2のprefix出力はNULL、QName3の
lengthは変更しません。上限は小さい `Last` のAda検査で確認し、巨大なC入力は構築していません。
通常は診断を変更せず、分割不能とQName3成功時は確保不要です。エラー診断経路は確保を伴う場合があります。
native pointer readability/extents、byte effects、pointer/array ABI、完全な公開意味論は
proof 範囲外です。Unicode test は library と
固定版の両方で実行しますが、OOM allocation injection は libxml3 側だけで、固定版には実行しません。

`xmlBuildQName` は `ncname` / `prefix` の lexical validation や namespace 解決をせず、NUL 終端
byte 列を `prefix:name` として組み立てます。NULL `ncname` または負の `len` は NULL を返し、
入力を読みません。NULL prefix は元の name pointer を借用して返しますが、非NULLの空 prefix は
`":name"` を作ります。prefix がある場合、必要容量は両 byte length と colon・NUL の合計で、
`XML3_Text.Max_Bytes` 以下でなければなりません。
`memory` に十分な容量があれば同じ pointer を返してそこへ書き、足りない場合は caller buffer を
変更せず新しい allocation を返します。新規 allocation だけを `xmlFree` し、caller buffer と
borrowed name は解放しません。計測・サイズ予約・構築はSPARKが直接行い、C文字列の中間コピーは
不要です。colonとNULの容量を先に予約し、nameを計測した残りの上限内でprefixを計測します。
走査・合計サイズ上限は診断115、確保失敗はmemory診断です。十分なcaller bufferが入力の
コピー対象byteと重なる場合だけ一時領域へ構築して転送・解放し、確保失敗ではbufferを保持します。
重ならず容量が足りる場合は確保不要です。重複領域の安全性はlibxml3側だけで固定版比較はしません。
native allocation/free/byte effects、address-to-integer conversion、pointer readability/extents、
C ABI、完全な公開意味論は証明外です。
`xmlStrQEqual` は prefix/name/value を raw byte として比較します。NULL prefix は
`xmlStrEqual(name, value)` 相当で、NULL/NULL と同一 pointer は1です。非NULL prefix
では name と value も非NULLである必要があり、prefix の literal bytes、colon、name の bytes
を NUL まで比較します。空 name は許可し、追加の colon と不正 UTF-8 byte を XML name として
検証しません。各入力は最初の NUL で終端し、その後の byte は比較しません。空 prefix は安全のため常に0を
返し、name/valueを読みません。pinned reference の do/while は空 prefix と空 value の
NULを比較した後に value を進めて terminator 後を読む unsafe path を持ち、NUL-then-`:name`
tail も解釈し得ますが、libxml3 はこれを再現しません。guard-page とその tail のテストは
libxml3-only で、固定版では実行しません。比較は早い不一致・一致または pointer
identity で終了します。`Max_Bytes` のscan capを越える追加読取りが必要な場合は診断を記録して
0を返します。したがって上限は長い入力を一律拒否するものではありません。allocation・
書き込み・UTF-8変換は行わず、
native byte読み取り、pointer/読み取り範囲、byte内容、完全なAPI意味論は信頼境界です。

`xmlNodeGetAttrValue` は名前空間URIを指定して属性値の独立コピーを取得します。
成功は `0`、属性なしは `1`、確保・上限・文字列変換・内部エラーは `-1` で、失敗時の出力は NULL です。
NULL URI は「名前空間なし」で、`xmlGetProp` の「名前空間不問」とは異なります。
固定版同様、NULL node/name/out や要素以外は `1`。未登録 facade も検索対象にしません。
空の属性値は空文字列のコピーを返し、属性なしと区別します。返却値は `xmlFree` で解放します。
DTD の既定値や未対応実体は対象外です。

`xmlNodeAddContent` は raw UTF-8 C string を追加し、entity reference を展開しません。
element/attribute の末尾に text child があればその content を置換して同じ facade を
保ち、なければ `"text"` node を追加します。text、CDATA、comment、PI は content を
連結します。NULL/empty content と document node は no-op、NULL node と未登録 facade
は失敗します。無効な XML 文字列は保持し、serializer 側で検査します。
追記APIはnodeの登録照合（`xmlTextConcat` はkind検査も）を入力読み取りより先に行います。
計測はSPARKのbounded helperを共用し、C側の中間Stringは作りません。新bufferへ旧本文と
native suffixをコピーした後でowner/pinを置き換え、入力が旧本文内を指す場合も保持します。
新しいtext childの作成には既存のnative span constructorを使います。読み取り可能な入力範囲と安定性は呼び出し側の前提です。
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
長さ 0 は空の本文として扱い、要素の children を空にします。固定版の parser は
長さ 0 でも先頭 byte を読み、非 NUL なら空の text child を作るため、この挙動は再現しません。
両setterはC側でStringを作らず、SPARKでnodeの登録照合をしてから入力を計測します。
scalarはnative spanを直接コピーし、要素・属性だけは入力/復号バッファを使います。
NULL本文は長さによらずNULL、長さ0のnon-NULL本文は空として扱います。未登録nodeと
non-NULL本文への過大な長さ指定は入力を読まずcode115で拒否します。旧本文や旧子の本文を
入力として使っても、必要なコピー・復号が終わるまでは解放しません。
`xmlNodeAddContentLen` は raw text を長さ指定で追記します。置換とは異なり、長さ 0 以下
または NULL content は何もしません。正の長さは最初の NUL または指定末尾までを読み、
NUL 後の見えない bytes は保存しません。先頭が NUL でも正の長さの入力なら、必要に応じて
空の text child や空文字列を作る固定版の挙動を保ちます。この判断と text 結合・接続・後始末は
SPARK 側です。UTF-8 の途中で区切られた raw byte も追記でき、出力時に完成した文字列を検査します。
`xmlNewTextLen` は同じ bounded 変換で raw text を作ります。non-NULL content で負の長さなら
NULL を返し、長さ 0 なら pointer を読まず空の文字列を持つ text を作ります。NULL content は
長さによらず content pointer が NULL の text を作ります。NUL 後の見えない bytes は保存しません。
`xmlNewDocText` / `xmlNewDocTextLen` は同じ raw text に所属文書を設定します。文書の children
には接続せず、親は NULL のままです。NULL doc は文書なしの text を作り、non-NULL doc は
管理中の live document に限ります。文書の owner を保持するため、接続前や unlink 後に
`xmlFreeDoc` を呼んでも text を編集・解放できます。失敗時は未公開 text を取り除きます。
deprecated な `xmlStringGetNodeList` / `xmlStringLenGetNodeList` も公開宣言に合わせて限定実装します。
NULL/empty input は NULL、predefined/numeric reference は展開し、未知/general entity、malformed
reference、無効 UTF-8/XML は操作全体を拒否します。entity-reference node は作りません。
返すのは detached text node で、non-NULL doc は登録済み live document に限り、Doc owner pin により
文書を先に解放しても node を編集・解放できます。長さ指定 API は負数を NUL 終端として扱い、
正数は最初の NUL または指定 byte 数まで読みます。長さ 0 は pointer を読み取らず NULL を返します。
固定版はこの場合に先頭 byte を読むため、非empty input で空 node を返す挙動を意図的に再現しません。
この API は固定版 libxml2 2.15.4 で deprecated です。C boundary はアドレス/長さの転送、
lock、Runtime dispatch、status/diagnostic mapping のみで、document 検査・計測・decode・node 作成は SPARK
Store/Runtime 側です。NULL入力・長さ0は文書にも触れず診断を保持し、それ以外は文書照合を
入力読み取りより先に行います。不正文書は入力が空でもcode115で拒否します。C側の中間Stringはなく、
入力・復号バッファはSPARK内にあります。native pointer/byte validity、allocation/copy、ABI と完全な C semantics は
信頼境界に残ります。
`xmlNodeListGetRawString` は `doc` 引数を無視し、NULL list には NULL を返します。開始 list facade は
Store の registered live node でなければならず、foreign pointer は native dereference 前に拒否します。
開始 node と next-sibling chain の直下だけを進み、text/CDATA の content を順に連結します。
descendant は走査せず、comment/element/PI 等は飛ばします。`inLine != 0` は raw bytes をそのまま保持し、
UTF-8/XML 検査はしません。`inLine == 0` は各 content node を結合前に個別に UTF-8 検証し、
連結後に XML 文字を検証して特殊文字を escape するため、node 境界で分割された不正 UTF-8 も拒否します。
non-NULL list に選択対象の
text/CDATA がなければ、独立した `xmlFree` 所有の空文字列を返します。entity-reference node は未対応で、
`xmlNodeListGetString` は同じ bounded direct-sibling query を共有します。`inLine != 0` は raw bytes を
複製して `doc` を無視します。`inLine == 0` は `doc == NULL` または登録済み Document_Node だけを受け入れ、
各選択 node の UTF-8 を個別に検証した後、XML 文字を検証して escaping します。attribute mode は開始 node の
親から決まり、attribute の tab/LF は数値参照、quote は `&quot;`、text の tab/LF/quote は raw のままです。
CR は `&#13;`、非 ASCII は大文字 hex 数値参照にします。document encoding は保持しないため、明示 UTF-8 document に対しても
reference の UTF-8 出力とは異なり得ます。出力は独立所有で `xmlFree` 解放です。HTML 固有の escaping と
entity expansion は未対応です。DOM は読み取り専用で、失敗時に変更しません。
NULL list は NULL、選択 text のない non-NULL list は独立した空文字列を返します。
OOM は NULL として返り、source list の links は変更しません。OOM failure/retry は `tests/oom-test.c` で検査します。
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

`xmlCopyNamespace` は管理中の live namespace facade だけを source として受け付け、
href/prefix の byte 列を独立してコピーし、NULL と empty string の有無を保持した
detached namespace を返します。source の `next`、`context`、`_private` はコピーせず、
返却された reservation は呼び出し側が `xmlFreeNs` で解放します。node に設定した namespace
は Store の pin で source 解放後も保持されます。foreign・stale pointer、namespace list の
コピー、native pointer validity と ABI はこの実装の対象外で、完全な public semantics は
証明していません。

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
未対応です。`xmlDocDumpMemoryEnc` は明示 UTF-8 とNULL encodingで XML 1.0 をメモリ出力し、
明示指定では宣言に指定 encoding 表記を保持します。文書は登録済みのlive facadeと照合してから
encodingを読み、不正文書・kind違いではencodingに触れません。SPARKの `Read_UTF8_Name` が
最大6byte（終端を含む）でUTF-8名を確認し、最初の不一致で停止します。C文字列の中間コピーはなく、
5文字の表記だけを固定長フィールドへ保持します。空文字列と余分なsuffixは拒否し、NULLだけが既定指定です。
この経路は整形出力を含む4つのメモリ出力APIで共用します。`xmlDocDumpMemory` とNULL encodingは
encoding宣言を省き、text・属性・namespace URIの非ASCII scalarを大文字16進の文字参照にします。
名前・comment・PI・CDATAはUTF-8のまま保持するため、出力全体がASCIIになる保証はありません。
空のencoding名はNULLとは区別して拒否します。source encoding/standalone metadata は保持されず、
元文書にencoding宣言があっても復元しない点は固定版と異なります。DTD、file output
は未対応です。C入口は既存の出力adapterを共用し、検査・文字参照化・二段階出力はSPARK側にあります。
失敗では出力NULL・長さ0を返し、元DOMは変更しません。成功結果は独立したxmlFree所有です。
`xmlDocDumpFormatMemory` / `xmlDocDumpFormatMemoryEnc` は同じ出力経路を使用します。
format=0は整形なし、非0（負値も含む）は固定版の既定設定に合わせた2空白と改行です。
字下げは深さ30で60空白に制限します。Text/CDATAを直接持つ要素ではsubtree全体の
整形を抑制し、閉じた後に兄弟の整形を再開します。空白だけのTextも抑制対象です。
元DOMの子・内容は変更せず、失敗時は未完成の出力を返しません。ただし要素のみの内容には
出力上の空白が加わり、再読み込みではTextになります。xmlIndentTreeOutput/
xmlTreeIndentString等のglobal設定変更は未対応です。
読み込んだPIもデータなし（例 `<?p?>`、content=NULL）と、空のデータ
（例 `<?p ?>`、contentは非NULLの空文字列）を区別します。target直後の区切り空白は
データに含めず、空白だけのデータは1空白付きPIとして出力します。通常・整形出力の
どちらもこの区別を保ち、`xmlNodeGetContent` はどちらも所有権付きの空文字列を返します。
要素のない document は宣言のみを出力する場合があります。
`xmlNewComment` / `xmlNewPI` は既存のSPARK作成・寿命管理を使って独立nodeを作成します。
raw文字列はコピーし、NULLと空contentを区別します。NULL PI targetは拒否しますが、
XML名・文字、予約target、comment/PIの構文はシリアライズ時に検査します。
NULL contentのcommentは出力しません。`xmlNewDocComment` / `xmlNewDocPI` は同じ処理で
文書を指定できます。NULL doc は文書なしの作成、non-NULL doc は管理中の live document
に限り、親への接続は行いません。所属文書の owner を保持し、文書先行解放後も独立した
comment/PI とコピー済みの target/content は編集・解放できます。node登録callback は未対応です。
`xmlNewText` / `xmlNewTextLen`、文書付きtext、comment、PI、CDATAの本文入力は
共通のSPARK直接走査・コピーを使い、C側で中間Stringを作りません。文書付きでは
登録済み文書の照合を名前・本文読み取りより先に行います。PI targetもSPARKで計測し、
同じ所有領域へ直接コピーします。NULL targetは入力を読まず診断を変更せずNULLを返し、
空・不正UTF-8・予約targetは作成時に拒否せず、従来どおり出力時に検査します。
長さ指定は指定byte数を越えず、NULL本文と空本文を区別し、従来のcode115診断を保ちます。
`xmlNewCDataBlock` も同じ文書保持と bounded input 計測を使います。name は NULL、
raw content はコピーされ、NULL/empty は区別します。non-NULL content の負の長さは拒否、
長さ0では入力を読みません。最初のNULまでだけを保持し、後続の隠れたbytesは保持しません。
UTF-8/XML文字の検査は出力時に行い、`]]>` は複数CDATAに分割して値を保持します。

要素・子要素・文書付き属性の共通の入力計測・コピーはSPARK側にあり、文書・親・namespaceの登録照合を入力読み取りより先に
行います。不正なcontext/namespace pointerは直接参照しません。C側の中間Stringはなく、名前と
raw本文は所有領域へ直接コピーします。参照展開する本文はSPARK内の入力・復号バッファを使い、
既存の厳格な復号規則を保ちます。この経路は `xmlNewNode`・子要素・文書付き属性とも共通です。
`xmlNewDocNode` / `xmlNewDocRawNode` は要素とその text child に文書を設定しますが、
要素自体の parent は NULL のままです。NULL doc では文書なしの subtree を作成します。
指定した namespace を保持し、NULL namespace では継承しません。name はコピーします。
`xmlNewDocNode` は既存 `xmlNewChild` と同じ predefined/numeric reference decoder を使い、
不正・未対応の参照や不正 UTF-8 を拒否します。固定版の構文エラーの黙殺は再現しません。
`xmlNewDocRawNode` は raw content を保持し、検査・escaping は出力時に行います。
raw の空文字列は空 text child を作り、NULL は作りません。文書・namespace の寿命、
要素作成後に text 確保が失敗した場合の後始末は SPARK Store/Runtime が管理します。
dictionary interning、登録callback、一般実体の展開は未対応です。
`xmlNewDocProp` は未接続の無namespace属性を作成します。作成後は `xmlAddChild` で
属性が文書未所属、または接続先と同じ文書に所属する場合に element parent へ接続できます。
NULL doc では文書なし、
non-NULL doc は管理中の live document に限り、属性はその owner を保持するため
文書先行解放後も `xmlFreeProp` まで存続します。値は `xmlNewDocNode` と同じ範囲で
文字参照を展開し、NULL/空文字列はどちらも text child を作りません。NULL name と
colon を含む name、無効または未対応の参照は拒否し、失敗時に未公開属性を残しません。
この constructor 自体は namespace付き属性を作成しません。detached attribute 単独の
シリアライズは対象外です。native pointer と C ABI は信頼境界です。

呼び出し中、入力バッファは読み取り可能かつ不変である必要があります。入力は
借用されて DOM にコピーされ、以後保持されません。`xmlFreeDoc` は現在接続されて
いる文書 subtree と document の参照を解放します。detached node が残る場合は
その arena backing も保持され、node の解放には `xmlFreeNode`、detached attribute
の解放には `xmlFreeProp` を使います。
`xmlFreeDoc` 後の document handle は使用できません。`xmlNodeGetContent` と
`xmlGetProp` の返却値は `xmlFree` で解放してください。`xmlStrlen` は最初のNULまでの
raw byte数を返し、NULLなら0です。不正UTF-8 byteもdecodeせずbyteとして数えます。
`xmlGetNodePath` は管理中のnodeの構造をたどり、独立した `xmlFree` 所有文字列を返します。
document自身は `/`、elementは `/name`、prefix付きelementは `/prefix:name`、
default-namespace elementは `/*`、attributeは `/@name` または `/@prefix:name` です。
attribute occurrence indexは出しません。text/CDATAは同じ `/text()` category、commentは
`/comment()`、PIは `/processing-instruction('target')` です。同じcategoryの兄弟が複数なら
`[1]` 等を付け、singletonはindexなしです。default-namespace wildcardは他の名前やnamespaceの
兄弟を含む全elementと一致します。それ以外は同じlocal-name bytesと同じnamespace参照、
または双方の等しいprefix bytesで比較し、URIは比較しません。等しいprefixでURIだけ異なる場合も
一致するため、これはURI解決済みの一意なXPathではなく構造診断用です。documentは要求node自身
の場合だけ出力し、detached nodeは自身から始めます。名前はescapeせずUTF-8 bytesで出力します。
不正UTF-8/XML名・prefix・PI targetは診断付きNULLで拒否し、malformed raw nameをコピーする
固定版の挙動は再現しません。NULL、namespace pointer、未登録facadeも拒否します。DOMを変更せず、
document解放後に残るmanaged detached nodeからも取得できます。SPARK Storeがregistry解決、
live/range検査、親・兄弟・property chainのbounded traversal、照合、正確な二段階の計測・出力を
行います。C adapterはNULL/lock/Runtime/status/exceptionだけを扱います。proofは内部計算・契約に
限られ、native pointer readable extent、allocation、byte copy/write、ABI/status mapping、完全な
public C semanticsはtrusted / not-provedです。
`xmlGetLineNo` は parser が記録した元入力上の行番号を返し、シリアライズ後の行位置は追跡しません。
LFだけを1行として数え、CRは単独でもCRLFの一部でも行を進めません。これは固定版の
standalone-CRに合わせた harmless な挙動です。文字参照で復号された改行は行を進めません。
parsed の element/text/comment/PI は解析時の行を保持しますが、65535 に飽和した値は
neighbor fallback に依存します。attribute と CDATA は bounded sibling/parent fallback を使い、
detached 時に -1 となることがあり、移動後は継承する行が変わることがあります。構築 element/text/comment/PI
と合成attribute-value textは0、NULL/document/未登録facadeは-1です。65535を上限とし、
fallbackは最大5 nodeをたどります。
`XML_PARSE_BIG_LINES` は parser option として未対応です。行番号は内部SPARK Storeに保持し、
public node struct fieldや直接書き込みAPIは追加しません。完全なC意味論、native pointerとABIは
trusted / not-provedです。
`xmlNodeSetName` は管理中のelement・attribute・PIだけを対象に、名前を新しい独立所有
領域へコピーしてから旧名を解放します。空・不正UTF-8・不正NCName、PI targetの
大文字小文字を無視した `xml`、非namespace属性の `xmlns`、同じnamespace URIと
local nameを持つ既存属性との衝突はDOM error 115で拒否し、元の名前pointer・値・
linksを保持します。異なるURIの同じlocal nameは許可し、prefixだけが異なる同URIの
衝突は拒否します。content置換後もnameは独立して保持され、NULLと未対応kindは
no-opです。referenceはduplicate expanded nameを許す一方、このsubsetでは競合を原子的に拒否し、
既存propertyを削除しません。entity referenceと完全な公開C意味論はsubset外です。C adapterはraw pointer、lock、
status/diagnostic mappingだけを扱い、名前検証・allocation・DOM projectionはSPARKで
行います。native pointer/readability、allocator、byte writes、ABIはtrusted boundaryです。
SPARK `Read_Length` は `0..Max_Bytes` を走査し、境界位置のNULを受け入れます。
その範囲にNULがなければDOM error 115を記録して-1を返します。これはempty stringを
意味しないerror sentinelなので、呼び出し側はdiagnosticを確認してください。
予期しないC-side exceptionはDOM error 1を記録して-1を返します。
pinned referenceは `INT_MAX` を超える長さを0にしますが、このsubsetは `Max_Bytes`
(`Integer'Last - 16`) で走査を制限し、未終端のcap超過を診断します。早期に終端する長い文字列を一律拒否する
ものではありません。cap動作は小さい `Last` を渡すAda helper testで確認し、巨大な公開C
stringは動的に構築していません。allocation・mutation・transcoding・UTF-8/XML validation
はありません。`xmlStrdup` は NUL 終端 byte 列を上限内で複製し、
`xmlStrndup` は指定長の raw bytes を埋め込みNULも含めて複製します。長さ0では
入力を読み取らず所有権付き空文字列を返し、負または上限超過の長さは拒否します。
どちらも NULL 入力なら NULL を返し、返却値は `xmlFree` で解放してください。
SPARKは scan bounds、result range、status contractを検証しますが、native read、
pointerの有効性・読み取り可能範囲・実byte内容、C diagnostic mapping、完全なAPI意味論は
信頼境界です。raw-byte、Unicode byte count、guard-page vectorsはreferenceとlibxml3の両方で、
no-allocation testはlibxml3のみで実行します。`xmlCharStrdup` は `char *` 入力をNUL終端byte列として複製し、
`xmlStrdup` と同じ内容を返します。`xmlCharStrndup` はNULL入力または負長でNULLを返し、
非NULL・非負入力では最大 `len` bytesを読み、早いNULで止まります。これは指定長のraw spanを
埋め込みNUL込みで複製する `xmlStrndup` とは異なります。長さ0は読み取りなしで所有権付き
空文字列を返します。両APIは `Max_Bytes` 上限を適用し、`xmlCharStrndup` の `len` 超過は
読み取り前に拒否します。`Copy_Byte_Prefix` が直接走査し、`Copy_Span` が独立したコピーを
作ります。他の複製APIも `Concatenate_Bytes` 経由で直接処理し、C文字列の中間コピーは
不要です。高位bitを含む入力byteを変更・
transcodeせず、UTF-8検証も行いません。返却値は `xmlFree` で解放してください。
pinned reference は早いNULの後も `len+1` bytesを確保しますが、そのtailは未規定です。
libxml3はコピーしたprefixと末尾NULのみを確保し、余剰capacityやallocation-size equivalence
は保証しません。テストは未規定tailを検査せず、定義済みの返却文字列だけを比較します。
native pointerの有効性・読み取り範囲、allocation、byte reads/writes、ABI、完全な公開意味論は信頼境界です。
`xmlCheckUTF8` は strict UTF-8 encodingを検査し、NULL・malformed・truncated入力で0、空入力で1を
返します。最初のNULで停止し、その後は読みません。overlong encoding、surrogate、U+10FFFFを超える
scalarは拒否しますが、ASCII controlやUnicode noncharacterはUTF-8として受け入れます。したがって
この結果はXML character validityを示しません。既存のXML parsingとname/content validationの
XML文字制約は変更しません。pinned referenceは上記の非canonical encodingを
受け入れるため、libxml3は危険なmalformed形式を拒否する意図的な安全差があります。
malformed UTF-8は診断なしで0ですが、`Max_Bytes` までにNULを見つけられないscan-limitは
DOM error 115を記録して0を返し、予期しない例外はDOM error 1と0です。境界位置のNULは有効です。
この検査は最大4 byteのstack bufferでstreamし、allocation・mutation・transcodingを行いません。
cap testは小さい `Last` を使うAda helperで行い、巨大な公開C stringは構築していません。
形式証明はscan control・index bounds・native-call preconditionsを対象にし、native byte/readable bounds、
foreign pointer validity、C diagnostic mapping、完全なUnicode API意味論はtrusted boundaryです。
通常・malformed・guard-page testsはpinned referenceとlibxml3の両方で比較します。
permissive vectorsも両方で実行して期待値を分け、no-allocation/OOM testsはlibxml3-onlyです。
`xmlGetUTF8Char` は `*len` bytes以内の先頭scalarだけをdecodeし、成功時はcode pointを返して `*len` を消費byte数に更新します。
NULL `utf`、NULL `len`、または `*len < 1` は `-1`。`len` が有効ならNULL `utf` / invalid / truncated入力で `*len = 0` とし、
`*len < 1` では何も読まず `*len = 0` にします。NUL byteはcode point 0、幅1として有効です。ASCII controlとUnicode
noncharacterはvalid encodingなら許可しますが、XML character validationはしません。不正sequenceでは診断なしで
`-1` / `*len = 0` を返し、unexpected C-side exceptionはDOM error 1を記録して同じ結果です。allocation、
input mutation、transcoding、XML validationは行いません。strict decoderはoverlong、surrogate、U+10FFFF超過、
不正lead/continuationを拒否します。pinned referenceが `F8`–`FF` leadをmaskする挙動（例: `F8 90 80 80`、
`FC 80 80 80`）を再現しないこと、およびreferenceが `*len < 1` 確認前に `utf[0]` を読む挙動を再現しないことは、
意図的な二つの安全差です。shared vectors、guard-page exact-span、permissive vectorsはreferenceとlibxml3の双方で
実行し、期待値を分けます。zero-lengthのunreadable pointer testとOOM/no-allocation testはlibxml3-onlyです。
native pointer validity、readable extent、実byte、C-side exception/status mappingは信頼境界です。
`xmlUTF8Strlen` はNUL終端UTF-8列のUnicode scalar数を返します。NULL・malformed・truncated・noncanonical
encodingは診断なしで-1、空列は0で、最初のNULで停止します。これはbyte数やgrapheme cluster数ではなく、
combining sequenceも個々のscalarとして数え、Unicode normalizationもしません。ASCII controlとUnicode
noncharacterは有効なencodingなら受け入れますが、XML character validityは検査しません。pinned referenceの
overlong、surrogate、範囲外scalar、および連続する2個のcontinuation byteを1 scalarとして数える挙動は再現せず、
strict UTF-8以外は拒否します。
`Max_Bytes` 位置までにNULを確認できないとDOM error 115と-1、予期しない例外はDOM error 1と-1です。
allocation、input mutation、transcodingはありません。小さい `Last` のAda testsでcap動作を確認し、巨大な公開C stringは
構築していません。SPARKはcounter/loop/index bounds、status/result contract、native-call preconditionsを対象にし、
foreign pointer validity/readable extent、実bytes、C mapping、完全なUnicode API意味論はtrusted boundaryです。
shared normal/malformed・guard-page vectorsはreferenceとlibxml3の両方で実行し、permissive reference casesは期待値を分け、
no-allocation/OOM testはlibxml3のみです。
`xmlUTF8Strpos` は0-based Unicode scalar位置へのborrowed pointerを返します。NULL inputと負の位置は診断なしでNULL、
位置0はpointerを読み取りなしで返します。正の位置は要求位置より前のprefixだけをstrict UTF-8として検査し、target scalarと
suffixは読まず検証しません。位置がscalar lengthならNULのaddressを読まずに返し、それより先ならNUL確認後にNULLです。
そのため全文字列のvalidation oracleではありません。ASCII controlとUnicode noncharacterは許可し、XML character validationはしません。
overlong、surrogate、範囲外scalarおよびpinned referenceが許容する5-byte sequenceは訪問prefix内なら拒否する意図的な安全差です。
`Max_Bytes` までprefixが未解決ならDOM error 115、予期しない例外はDOM error 1を記録してNULLを返します。
allocation、input mutation、normalizationはありません。返却pointerはinputのlifetime中だけ有効で、`xmlFree`しません。
小さい `Last` のAda testsでcapを確認し、巨大な公開C stringは作りません。SPARKは走査・index/offset bounds、
status/result contract、native-call preconditionsを対象にしますが、foreign pointer validity/readable extent、actual bytes、
C mapping、完全なUnicode API意味論は信頼境界です。共有reference/permissive・guard-page testsは両方で実行し、
期待値を分けます。OOM/no-allocation testはlibxml3のみです。
`xmlUTF8Strsize` は最大 `len` 個のUnicode scalarに対応するraw byte数を返し、NUL byteは含めません。`len <= 0` または
NULL inputは読み取りなしで0、文字列が要求数より短ければ最初のNULまでのbyte数です。要求数に達した時点で止まり、その後の
suffixは検査しません。訪問prefixのmalformed・truncated・noncanonical UTF-8は部分値なしの-1で、診断は記録しません。
referenceのinvalid UTF-8動作は保証されないため、不正な訪問prefixは明示的に拒否します。ASCII controlとUnicode noncharacterは
UTF-8として有効ですがXML character validationはしません。inclusive `Max_Bytes` まで走査が未解決ならDOM error 115と-1、
予期しない例外ならDOM error 1と-1です。allocation、input mutation、normalizationはありません。小さい `Last` のAda testで
capを確認し、巨大な公開C stringは作っていません。SPARKはscan control、byte-offset bounds、status/result contractと
native-call preconditionsを対象にしますが、foreign pointer validity/readable extent、actual bytes、C mapping、完全なUnicode意味論は
信頼境界です。共有malformed/reference・guard-page vectorsは両方で実行し、invalid UTF-8のreference比較は対象vectorの期待値だけを
比較します。OOM/no-allocation testはlibxml3のみです。
`xmlUTF8Size` はUTF-8全体をvalidate/decodeせず、lead byteだけから幅を分類します。NULLなら読み取りなしで-1、それ以外はbyte 0を
一度だけ読み、それ以降やNUL終端は参照しません。`0x00..0x7f`（NUL含む）は1、`0xc2..0xdf` は2、`0xe0..0xef` は3、
`0xf0..0xf4` は4、その他は-1です。したがって非NUL終端の1-byte readable bufferでも使用でき、単独の `0xe2` は3を返します。
後続byte、truncation、surrogate、scalar rangeは検証しないので、これはUTF-8/XML validity oracleではありません。通常のvalid/invalid
lead結果にallocation・mutation・diagnosticはなく、予期しないC例外はDOM error 1と-1です。pinned referenceは `0xc0..0xc1` に2、
`0xf5..0xf7` に4、`0xf8..0xfb` に5、`0xfc..0xfd` に6、`0xfe` に7を返しますが、この実装はこれらinvalid Unicode leadersを拒否します。
有効性検証やdecodeには `xmlCheckUTF8` / `xmlGetUTF8Char` を使います。全256 byte valuesをPROT_NONE直前の最後のreadable byteに
それぞれ置くguard test、単独の非NUL終端1-byte input、OOM no-allocation testを実施します。SPARK helperはlead分類とresult contractを担いますが、native byte/readable pointer、
pointer validity、C mapping/ABI、完全なAPI意味論はtrusted boundaryです。

`xmlCopyCharMultiByte` と `xmlCopyChar` は `parserInternals.h` で公開する deprecated writerです。Unicode scalarを1..4 byteのUTF-8として出力し、追加のNUL terminatorは付けません（scalar 0はliteral NUL 1 byte）。`xmlCopyChar` の `len` は無視され、書込みcapacityではありません。呼出側は実際の出力幅に足る、書込み可能で安定した領域を用意する必要があります。XMLで禁止されるcontrolやnoncharacterもUTF-8としてencodingし、XML character validationは行いません。負値、U+10FFFF超、surrogate、NULL outputは0を返して書込みません。surrogate拒否はstrict UTF-8を守る意図的な安全差です。通常の成功・拒否ではallocationやdiagnosticを行わず、sticky errorを保持します。output pointerの有効性・extent、native byte内容、C ABIと完全なupstream semanticsは信頼境界です。既存のXML character/parser/name validationは変更せず、parser-internals subsystemの他APIも未対応です。

`xmlUTF8Strloc` はpatternの最初のUnicode scalarと一致する最初のsource位置を、byte offsetではなく0-based scalar indexで返します。
`Find_UTF8_Character` は `Measure_UTF8_Prefix` でpatternの最初のscalarだけをstrictに検証し、残りのpattern suffixは無視します。
sourceはmatch scalarを含む訪問scalarごとにstrict UTF-8検証し、match後は読みません。malformed・truncated・overlong・surrogate・
out-of-rangeの訪問prefix、または通常の不一致は診断なしで-1です。無効な最初のpattern scalarはsourceを読む前に拒否します。
NULLのどちらかは他方を読まず-1です。空patternではreference互換の例外として、非empty sourceのbyte 0だけを読み0を返し、
sourceのUTF-8検証はしません。empty sourceは-1です。ASCII controlとnoncharacterはvalid UTF-8であり、normalization・case folding・
grapheme matchingはありません。allocation・mutationはなく、inclusive `Max_Bytes` まで未解決ならDOM error 115と-1、
予期しない例外ならDOM error 1と-1です。patternは最初のscalarまで、sourceはmatch scalarまたはNULまでreadableかつ安定している必要があり、
match scalarはNULなしでguard page直前に終われます。C adapterはstatus/index/errorを対応付けるだけです。
SPARKはscan control、scalar index bounds、status/result contract、native-call preconditionsを対象にしますが、native bytes、
readability/pointer validity/stability、C ABI/mapping、完全なUTF-8 API意味論はtrusted boundaryです。
referenceとstrict実装で期待値の異なるmalformed vectors、空patternの例外、DOM lifecycle、exact-span guard cases、no-allocationをテストします。
`xmlUTF8Strndup` は最大 `len` 個のUnicode scalarに対応する訪問prefixだけをstrict UTF-8として検証し、
そのraw bytesを新しいNUL終端のowned copyへ複製します。NULL inputまたは負の `len` は読み取り・allocation・診断なしでNULL、
非NULL inputの `len == 0` はinputを読まずに新しい空文字列を返します。正の `len` は要求scalar数または最初のNULで止まり、
後続suffixは検証しません。訪問prefixのmalformed・truncated・noncanonical encodingはallocation前に部分copyなしで
診断なしのNULLです。返却値はcallerが `xmlFree` し、inputは変更・解放しません。ASCII controlとUnicode noncharacterは
UTF-8として許可しますが、XML character validationはしません。referenceのinvalid UTF-8動作は保証されず、strictな訪問prefix拒否は
意図的な安全差です。inclusive `Max_Bytes` まで未解決ならDOM error 115とNULL、allocation failureはDOM error 2、
予期しない例外はDOM error 1とNULLです。小さい `Last` のAda testでcapを確認し、巨大な公開C stringは作っていません。
SPARKはscan、span/byte bounds、status/result contract、native-call preconditionsを対象にしますが、native bytes/readable extent、
pointer validity、allocation実動作、C mapping/ABI、完全なUnicode意味論は信頼境界です。共有malformed/reference・guard-page vectorsは
両方で実行し、OOM/no-allocation testはlibxml3のみです。
`xmlUTF8Strsub` は `start` から最大 `len` 個のUnicode scalarに対応する新しいNUL終端owned copyを返します。NULL input、
負の `start` / `len`、または範囲外の開始位置はNULLで、最初の二つはreads/allocation/diagnosticsなしです。スキップするprefixは
`Find_UTF8_Position` でstrict UTF-8として検証し、次に選択prefixだけを同じstrict規則で検証してコピーします。`len == 0` でも
skipped prefixを検証しますがtarget byteは読みません。`start == 0 && len == 0` はinput readなしで空copyを確保し、
scalar lengthでのstartは正のlenでもempty copyを返します。訪問したskipped/selected bytesがmalformed、truncated、または
noncanonicalならallocation前に診断なしでNULLとなり、未訪問suffixは検査しません。scalar数でありbyte/grapheme数ではなく、
normalization/transcodingはしません。返却copyはcaller所有で `xmlFree` し、inputは変更・解放しません。ASCII controlとUnicode
noncharacterはUTF-8として許可しますがXML character validationはしません。pinned referenceの `xmlUTF8Strsub` はskip時に
non-NUL continuation valuesを検査しません。この実装がそれらもstrictに拒否するのは意図的な安全差です。ひとつのinclusive
`Max_Bytes` capをscan全体に適用し、start位置でresetしません。cap errorは115、allocation errorは2、unexpected exceptionは1で
NULLです。小さい `Last` のAda testでglobal capを確認し、巨大な公開C stringは構築していません。native bytes/readable stable
extents、pointer validity/offset arithmetic、allocation、C mapping/ABI、完全なUnicode意味論は信頼境界です。
`xmlStrchr` はNUL終端raw byte列内で最初の一致した非NUL byteを探し、入力を借用する
pointerを返します。返却値は `xmlFree` で個別に解放しません。NULL inputまたは検索値0は
読み取りなしでNULLを返し、NUL byte自体は
検索できません。payload offset `0..Max_Bytes-1` を走査し、offset `Max_Bytes` のNULは
許容します。一致がなければここまでの検索で終端を確認し、終端なしなら診断を記録してNULLを
返します。早い一致は即座に返るので、この上限は長い入力を一律拒否するものではありません。
allocation・書き込み・UTF-8変換は行いません。native byte読み取り、読み取り可能範囲、
pointer validity/address arithmetic、C診断mapping、完全なAPI意味論は信頼境界です。
`xmlStrstr` と `xmlStrcasestr` は NUL 終端 raw byte 列の最初の substring を探し、
一致した haystack 内 pointer を借用して返します。どちらかが NULL なら NULL、非NULL
haystack と空 needle なら haystack pointer を読み取りなしで返します。haystack と pattern は
最初の NUL で終端し、重なった入力、UTF-8 の途中 byte、その他の raw bytes をそのまま扱い、
XML name/UTF-8 validation や transcode は行いません。`xmlStrcasestr` は A-Z に加えて
pinned reference の `[` -> `{` byte-map quirk を使い、Unicode case folding ではありません。
最初の一致を返し、`Max_Bytes` 未満の payload と境界の NUL を調べます。境界より先の
non-NUL byte が必要なら diagnostic を記録して NULL を返しますが、早い一致と空 needle は
全体を走査しないため、長い入力の一律拒否ではありません。結果は入力の lifetime 中だけ
有効な borrowed pointer で、個別に `xmlFree` しません。allocation・書き込みは行わず、
native pointer/読み取り範囲/byte内容/address arithmetic、C status mapping、完全なAPI意味論は
信頼境界です。共有 substring vectors と全非NUL byte pair の比較は libxml3 と pinned
reference の両方で実行し、substring guard-page ケースも両方で実行します。OOM/no-allocation
検査のみ libxml3-only です。
`xmlStrsub` は検証済みstartから独立した `xmlFree` 所有のsliceを返します。NULLまたは負の
start/lenは診断なしでNULLです。startの妥当性は byte 0 から start inclusive までNULがないことを調べて
判定するため、start byte がNULなら `len == 0` でも失敗します。有効なstartは `len == 0` でも
空allocationを返します。正の長さでは NUL で切り詰めず指定された `len` raw bytesをコピーし、
コピー範囲内の埋め込みNULやUTF-8断片も保持します。呼び出し側は指定span全体を読める必要が
あります。`start < Max_Bytes` と `len <= Max_Bytes - start` は読み取り前に検査し、上限超過は
診断とNULLになります。UTF-8/XML-name validationやtranscodeは行いません。共有slice vectorsと
guard-pageケースはreferenceとlibxml3の両方で実行し、OOM検査と上限専用ケースはlibxml3-onlyです。
native pointer/読み取り可能範囲/実byte内容、allocation freshness・writes、address計算、C mapping、
完全なAPI意味論は信頼境界です。
`xmlStrncmp` と `xmlStrncasecmp` は `Max_Input` cutoffなしでC `int` の
正の全範囲（早期停止時の `INT_MAX` を含む）までraw byteを比較し、
不一致・NUL・上限で停止します。`len <= 0` はpointer判定より先に0を返し、同一pointerは0、
NULLの左辺は-1、NULLの右辺は+1です。`xmlStrncmp` はunsigned byte差を返します。
`xmlStrncasecmp` は `A`–`Z` に32を加え、`[` も `{` に写す pinned reference のbyte-map
quirkを保持します。これはUnicode case foldingではありません。比較自体はallocationも
C-string変換も行いませんが、foreign pointerの有効性、byte内容、読み取り可能範囲は信頼境界です。
`xmlStrcmp`、`xmlStrEqual`、`xmlStrcasecmp` は SPARK `Buffers.Compare_Terminated` を共有し、
最初の不一致またはNULで停止します。同一pointerは読み取りなしで一致し、NULL/NULLも一致、
片側だけNULLなら左NULLが-1、右NULLが+1です。`xmlStrcmp` は unsigned byte 差、
`xmlStrEqual` はraw byte equalityを返します。`xmlStrcasecmp` は `A`–`Z` と `[`→`{` の
pinned byte-map quirkを保ち、Unicode foldingやUTF-8 validation/transcodingは行いません。
scan は `0..Max_Bytes` を読み、境界の不一致またはNULで完了します。同じ非NUL byteがcapまで続き、
さらなる読み取りが必要なら診断付き `-1` を返します。これは `xmlStrcmp` / `xmlStrcasecmp` で
信頼できる順序値ではなく、呼び出し側は診断を確認してください。`xmlStrEqual` はこの場合0です。
不一致・NUL・NULL・同一pointerによる早期終了があるため、長い文字列を一律拒否するものではありません。
小さい `Last` を与えた内部Ada helper testと形式検証がcap挙動の根拠であり、公開C APIのcap長文字列を
動的に試したとは主張しません。C adapterはscalar dispatchとdiagnostic mappingのみを行います。
shared byte vectorsとguard-page casesはpinned referenceとlibxml3の両方で実行し、OOM/no-allocation
checkはlibxml3-onlyです。SPARKはloop bounds、result range、native preconditions、cap failure contractを
証明しますが、native pointer/readable bounds/actual bytes、address arithmetic、C mapping、完全なAPI意味論は
信頼境界です。
`xmlStrncatNew` は負の `len` を `str2` のNUL終端長として扱い、
`str1 == NULL` なら `xmlStrndup` 相当、非NULLの `str1` ではNULLの `str2` または
有効長0なら `str1` の複製、それ以外では `str1` と `str2` の指定byte spanを連結します。
正の長さでは埋め込みNULや部分UTF-8もそのままコピーし、入力は変更しません。
返却値は `xmlFree` で解放してください。SPARKの `Concatenate_Bytes` が直接計測・コピーし、
C文字列の中間コピーは不要です。右側の有効長を先に決め、残りの `Max_Bytes` 上限内で左側を
計測します。合計上限超過では正の右側spanを読む前に拒否し、右側の指定長だけで上限を超える
場合は両入力を読みません。`Copy_Pair` は消費型の追記とも共有しますが、このAPIは失敗時も
入力を解放・変更しません。pinned reference build も共通の
文字列テストを実行し、上限超過・OOM注入はlibxml3-onlyで検査します。
native pointer、読み取り可能性、allocation、byte reads/writes、ABI、完全な公開意味論は信頼境界です。
`xmlStrcat` / `xmlStrncat` はno-op以外で `cur` を消費します。`cur` はNULLまたは呼び出し側所有の
`xmlFree` 互換allocationの先頭に限り、literalやDOMから借りたpointerは渡せません。消費する呼び出し後に
旧 `cur` を使ったり解放したりしてはいけません。`xmlStrcat` は `add` のNUL終端byte列を追加し、
NULLの `add` は `cur` を返します。空 `add` は非NULL `cur` ならno-op、NULL `cur` なら所有可能な
空文字列を作ります。`xmlStrncat` はNULL `add` または `len == 0` なら負の長さ判定前にno-opです。
非NULL `add` で `len < 0` の場合は診断なしで `cur` を消費しNULLを返します。正の `len` は
埋め込みNULを含む指定raw bytesを正確にcopyします。`xmlStrcat` は `add` を先に走査し、prefixは
残りcap内で走査します。境界NULは受け入れ、NULなしでcapを超える場合はDOM error 115を診断します。
`xmlStrncat` の正の長さが `Max_Bytes` を超える場合は両入力の読み取り前に拒否します。
cap failureは診断付きNULL、OOMは既存OOM診断となり、いずれも既存 `cur` を消費します。
結果はNUL終端の新しいallocationです。
実装は新しいallocationを作ってcopyしてから旧 `cur` を解放するため、`add` が旧buffer内を指すaliasも
安全に読み取ります。これはrealloc型参照実装の危険なalias経路を再現しない意図的な安全差であり、
常時copyによりpeak memory/copy workが増え得ます。UTF-8/XML validationやtranscodingはしません。
shared vectorsとguard-page casesはpinned referenceとlibxml3の両方で実行し、alias・cap・OOM/free-count
testsはlibxml3-onlyです。SPARKのlength/bounds/status-result proofはactual native reads/writes/allocation/free、
pointer validity、caller ownershipを証明しません。
NULL 入力、サイズ不正、非対応オプション、
エンコーディング、構文エラーは通常 API では NULL を返します。
`xml3ReadMemory` は `XML3_STATUS_*` を通じて理由を返します。
NUL 終端の `xmlReadDoc`/`xmlParseDoc` は呼び出し側が提供する有効な C 文字列を
必要とし、SPARKの`Measure`で最初のNULまでを計測します。`Max_Bytes`位置の
終端までを許し、終端が範囲内になければNULLを返して解析しません。
NULL入力は診断を保持し、空文字列は空文書エラーになります。計測自体は
確保・コピーをせず、終端後のbyteを読みません。`xmlReadMemory` の
長さは C `int` で表現可能で、コアの表現境界内でなければなりません。

## 対応範囲と資源プロファイル

`xmlReadMemory` は UTF-8 と UTF-16LE/BE を受け付け、DOM 内の名前と値は常に UTF-8
です。UTF-16 は matching BOM、XML 宣言を示す BOMless byte signature、または明示
encoding で判定します。encoding 名は ASCII 大文字小文字を区別せず、
`UTF-8`/`UTF8`、`UTF-16`/`UTF16`、`UTF-16LE`、`UTF-16BE` を認識します。
明示名は `XML3_Encoding.Buffers.Classify_Bytes` が最大9byte（終端込み）を直接読み、候補がなくなった
最初のbyteで停止します。C側の走査・文字列変換を使わず、XML宣言のString分類とも対応表を共用します。
NULLは自動検出指定、空名・不完全な名前・余分なsuffixはcode 32で拒否します。
入力buffer/sizeの初期検査は引き続き名前を読む前に行い、不正な名前ではXML本文を読みません。
generic `UTF-16`/`UTF16` は pinned libxml2 built-in handler の観測に合わせて
little-endian として扱います。明示 encoding は XML 宣言より優先しますが、
宣言の文法検査は省略しません。未知の明示 encoding は code 32 で拒否し、
暗黙の UTF-8 fallback は行いません。自動検出 encoding と宣言の不一致は
成功した parse で warning code 113 を保持します。UTF-8/no-BOM の文書が
`UTF-16` を宣言していても decoder を途中切替せず code 81 で拒否します。

UTF-16 の binary input には長さを受け取る `xmlReadMemory` を使用してください。
NUL 終端文字列を測る `xmlReadDoc`/`xmlParseDoc` は binary UTF-16
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
`xmlGetPredefinedEntity` の対応範囲は exact-name の `lt`、`gt`、`amp`、`apos`、`quot`
だけです。返却される entity record と name/content は共有 read-only の library-lifetime
borrowed data で、呼び出し側は free、mutation、link、managed-DOM editing API への入力を
してはいけません。lookup は allocation しません。DTD/general entity subsystem、external
entity loading、editable entity node はありません。public enum と record layout の宣言は
これら未実装の entity kind を有効にしません。native pointer readability、byte effects、
layout、lifetime、C ABI、完全な public C semantics は trusted または未証明です。
`xmlGetDocEntity` は DTD のない対応 document または NULL に限り、同じ定義済み実体を
返します。一般実体や外部 subset を黙って読み飛ばす実装ではなく、DTD の作成・読み込み
自体が未対応です。NULL name は document を調べず NULL を返します。non-NULL name では
SPARK の登録情報で document を先に確認し、不正・異種の pointer は直接参照せず
診断 115 と NULL で拒否します。この場合 name も読みません。正常な検索・不一致は
確保せず診断を保持し、返却データの寿命・借用制約は `xmlGetPredefinedEntity` と同じです。
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
stop at the first NUL and are not binary UTF-16 entry points. UTF-16 prevalidation errors
report IO/code 81 at 1:1 before parsing; parser positions refer to decoded
UTF-8 character columns. The frozen observations in `tests/encoding-oracle.json`
are compared without normalizing snapshot fields, with explicit per-case reasons
for intentional libxml3 differences. A 1 GB value allocation is not tested.

## URI の byte エスケープ

`xmlURIEscapeStr` は入力の先頭NULまでをbyte単位で処理します。ASCII英数字、
`-._~!*'()@`、例外リストに含まれるbyteを保持し、他のbyteをuppercase `%HH` にします。
固定版の `@` と旧RFCのmarkの扱いを保ち、空白を `+` にするform encodingではありません。
既存のpercent sequenceも特別扱いせず、`%` が例外にない場合は `%25` にします。
UTF-8やURIの検証・正規化ではなく、不正UTF-8のbyteやcontrolもencodingし、例外ならそのまま残します。
URI全体、path/query等の構成要素に適切な例外を選ぶ責任は呼び出し側にあります。

NULL入力はNULL、空入力は独立した空文字列を返します。成功結果はNUL終端され、
元入力・例外リストを解放しても利用でき、呼び出し側が `xmlFree` で解放します。
例外リストは必要なbyteに対してのみ検索し、一致/NULで停止します。NULL・空入力や
既定で保持するbyteだけなら例外リストは読みません。検索結果はbyteごとに記憶します。
入力と例外リストのaliasを許しますが、実際に読む範囲は安定してreadableである必要があります。

SPARKで出力長を計算して一度だけ正確なサイズを確保し、固定版の余剰容量・再確保手順は再現しません。
出力長と例外検索には既存の `Max_Bytes` 上限があり、超過は診断115とNULL、確保失敗はOOM診断とNULLです。
部分的な出力は返さず、元入力を変更・解放しません。成功とNULL入力は既存診断を保持します。
native allocation/free/read/write、入力の有効性・extent・安定性、C ABIと完全な意味論はtrusted boundaryです。
URI全体の解析・解決は未対応です。pathだけの正規化は後述の `xmlNormalizeURIPath` で行います。

`xmlNormalizeURIPath` はNUL終端されたpathをin-place・allocation-freeで正規化し、0を返します。
連続 `/` は単一separatorにし、`.` を除き、`..` で直前の通常segmentを除きます。
`a/.` と `a/b/..` は `a/`、`a/..` は空文字列です。相対pathの先頭 `..` は保持します。
絶対pathはrootで止め、`/../a` と `/a/../../a` は `/a` です。
固定版 `uri.c` の `xmlNormalizePath` は余分な `..` の判断に元の出力先byteを参照し、
`..//..` を `../` にして親階層を落とす一方、`/../a` の `..` は残します。
このpathの意味を誤る挙動は再現せず、入力先頭の `/` の有無を一度だけ判定して保持します。
テストには固定版の期待値とこの意図的な差異を分けて記録しています。
NULLは-1で診断を変えず、空入力は書き込みも行いません。成功も既存診断を保持します。
`Max_Bytes` 超過は変更前に-1と診断115で失敗します。巨大なC入力ではなく小さいAda上限で検査します。
backslashはseparatorではなく、percent sequence・UTF-8・XML文字・query/fragmentは解釈しません。
URI全体やfilesystem/symlinkのcanonicalization、アクセス制御やtraversal防止には使えません。
非空入力は元の終端までwritable、走査中は安定している必要があります。
native pointer・extent・byte内容と読み書き・C ABI・完全な意味論はtrusted boundaryです。

`xmlURIUnescapeString` は大文字・小文字の `%HH` をbyteへ戻し、不完全・不正な `%` と `+` は
そのまま残します。正の `len` は埋め込みNULを含む指定byte数を処理し、0以下は最初のNULまでです。
`%00` はNULへ戻ります。出力も埋め込みNULを含み得るため、`strlen` はbinary結果の長さにはなりません。
URI、path、XML文字、UTF-8の妥当性検証は行わず、利用箇所に応じた検証は呼び出し側の責任です。
NULL入力はNULLで出力先も触りません。出力先NULLなら独立した `xmlFree` 対象の領域を返し、
指定済みなら同じポインタを返します。結果の末尾には追加のNULを1byte書き込みます。

入力は実際に処理する全byteが安定してreadable、出力先は復号結果のbyte数+1がwritableである必要があります。
入力長には `Max_Bytes` 上限があり、復号後に短くなる場合でも入力長超過は診断115とNULLです。
固定版の `len + 1` overflowは再現しません。同一ポインタのin-place処理と指定出力先への空出力は確保不要です。
それ以外は入力長+1の領域へ一度復号し、指定出力先があれば完成した結果だけをコピーして一時領域を解放します。
出力先が入力の途中を指す場合も、固定版の未処理入力の破壊は再現しません。一方、この安全性のため
非空の別出力先を渡した場合も確保が必要になります。確保失敗はOOM診断とNULLで、入出力先は変更しません。
通常成功とNULL入力は既存診断を保持します。native bytes、copy/free/read/write、extent・安定性、ABIと
完全な公開意味論は証明範囲外です。出力先のcapacityを受け取るAPIではないため容量自体は検査できません。

## 保証について

`XML3_Text`、`XML3_Parser`、`XML3_Namespaces`、`XML3_Encoding` の固定境界コアは
proof project に含まれます。証明範囲は実行時境界、算術、契約、終了性であり、
libxml2 との機能的同等性や全ての脆弱性がないことを証明するものではありません。
C adapter、FFI、公開ポインター、allocator 境界は形式検証の対象外です。
DOM Store の論理 topology、owner/reservation accounting、namespace retention と
mutation/release policy は SPARK proof の対象です。
完全な libxml2 API 目標と現在の実装を混同しないでください。
