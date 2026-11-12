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
`make compare-system` はOS付属版での補助比較です。OS付属版が古い場合、基準版で直っている既知の差
（`eng/compare_system.py` の `KNOWN_DIFFERENCES`。該当する版を明記）だけを正規化してから比較し、それ以外の差は失敗にします。

`make build` は通常実行用の `lib/libxml3.so` を生成します。証明用の
アサーション・事前／事後条件・ghost 処理は実行時に評価せず、入力検査、
Ada の範囲チェックと整数オーバーフロー検査は維持します（`-gnatp` は使用しません）。
`make build-development` は全アサーションを有効にした開発用ライブラリを
`lib/development/libxml3.so` に生成し、オブジェクトも通常実行用と分離します。
`make test-development` はこのライブラリで公開 API の小規模回帰を実行します。
開発用では全体整合性の再計算が非常に重く、深いツリーの性能測定には適しません。
`make prove` と Ada のコア／接続層テストは引き続き全アサーションを有効にし、
通常実行用プロファイルによって証明条件を省略しません。
記録済みの証明結果（[docs/proof-report.md](docs/proof-report.md)）は `make prove-units` で再現します。
記録と同じ設定（timeout 120秒、memlimit 4096MB）でユニットごとに GNATprove を実行し、最後に
全ユニットの集計に未証明・justified が無いことを確認します。中断した場合は
`make prove-units-resume` で続きから再開できます。
DOM コアは、どのユニットも1回の実行で証明が終わるように、親の `XML3_DOM`（モデル・述語・小さな操作）と子ユニットに分けています。
子ユニットは次の7つです。
- 非公開: `Graph_Lemmas`、`Links`、`Projection`、`Marking`、`Freeing`
- 公開: `Releases`（`Take_Release` / `Acknowledge_Release`）、`Retirement`（部分木の解放と子の退役）

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
`xmlAddChild`、`xmlAddSibling`、`xmlAddPrevSibling`、`xmlAddNextSibling`、`xmlNewChild`、`xmlNewTextChild`、`xmlNodeAddContent`、`xmlNodeAddContentLen`、`xmlNodeSetContent`、`xmlNodeSetContentLen`、`xmlUnlinkNode`、`xmlFreeNode`、`xmlNewNs`、`xmlSetNs`、
`xmlFreeNs`、`xmlCopyNamespace`、`xmlNewNsProp`、`xmlSetNsProp`、`xmlUnsetNsProp`、`xmlNewProp`、
`xmlSetProp`、`xmlUnsetProp`、`xmlRemoveProp`、`xmlFreeProp`、`xmlCopyNode`、`xmlDocCopyNode`、
`xmlCopyProp`、`xmlCopyDoc` をサポートします。
`xmlNodeAddContent` / `xmlNodeAddContentLen` / `xmlTextConcat` の本文はSPARKで計測し、
C側の中間Stringなしで新しい所有領域へ直接コピーします。未登録nodeとscalar限定APIの
不適切なkindは入力読み取り前に拒否し、既存本文を入力として使う場合もコピー完了まで旧領域を保持します。
`xmlNodeSetContent` / `xmlNodeSetContentLen` も登録照合・入力計測をSPARKで行い、
scalar本文は直接コピーします。要素・属性だけはSPARK内のバッファで文字参照を復号し、
新しい本文の準備・接続に成功してから旧子ノードを解放します。
`xmlNodeSetLang` の入力もSPARKで要素登録・種類を確認してから計測/コピーし、
既存のqualified-property編集へ渡します。C側で言語文字列を変換しません。
`xmlGetNsList` / `xmlGetNsListSafe` は node と祖先要素の明示 `nsDef` を近い順・宣言順に
列挙し、同じ prefix は最初の宣言だけを含めます。組み込み `xml` binding は追加せず、
`doc` 引数は無視します。返却配列は `xmlFree` で解放し、各 namespace pointer は借用です。
deprecated な `xmlStringGetNodeList` / `xmlStringLenGetNodeList` は、NULL/empty 入力に NULL を返し、
predefined/numeric reference だけを展開した独立の detached text node を返す限定サブセットです。
未知/general entity や malformed reference は拒否し、entity-reference node は作成しません。
正の長さは最初の NUL または指定長まで、負の長さは NUL 終端です。長さ 0 は入力を読まず
NULL を返し、固定版の unsafe な先頭 byte read は再現しません。
計測はSPARK側で行い、C側の中間Stringは作りません。NULL入力・長さ0は文書にも触れず、
それ以外は文書の登録照合を入力読み取りより先に行います。既存の復号用バッファはSPARK内に残ります。

`xmlGetPredefinedEntity` は `lt`、`gt`、`amp`、`apos`、`quot` の完全一致だけを
検索します。返る entity record と name/content の文字列は共有された read-only の
library-lifetime 借用データであり、解放・変更・link・managed DOM 編集 API への受け渡しを
してはいけません。lookup は allocation せず、DTD/general entity、external entity loading、
editable entity node は実装しません。native pointer の readability、byte effects、layout、
lifetime、C ABI と完全な public semantics は trusted/unproved boundary です。
`xmlGetDocEntity` は NULL または登録済み document を受け付け、同じ定義済み実体だけを
検索します。DTD は未対応です。NULL name なら document を検査せず NULL、その他では
document を確認してから name を読みます。不正な document は診断 115 と NULL で拒否し、
成功・不一致では診断を保持して allocation しません。結果は document の寿命と独立です。

`xmlNodeListGetRawString` は managed な開始 node と next-sibling chain の直下だけを走査し、
text/CDATA のみを連結します。descendant には降りず、他の node kind は飛ばします。`doc` は無視され、
NULL list は NULL を返します。`inLine != 0` は UTF-8 検査なしで raw bytes をコピーし、
`inLine == 0` は各 node の bytes を個別に UTF-8 検証し、連結後に XML 文字を検証して
特殊文字を escape します。
選択可能な text がない non-NULL list は独立した空文字列を返し、返却値は `xmlFree` で解放します。
`xmlNodeListGetString` も同じ bounded direct-sibling query を使います。`inLine != 0` は raw bytes を複製し、
`doc` を無視します。`inLine == 0` は NULL または登録済み Document_Node の `doc` を受け入れ、
この mode だけ各 node の UTF-8 を個別に検証し、連結後に XML 文字を検証します。
開始 node の親が attribute なら tab/LF を数値参照へ、quote を `&quot;` へ変換します。
text では tab/LF/quote を raw のまま残し、CR は `&#13;`、非 ASCII は大文字 hex の文字参照にします。
この subset は document encoding を保持しないため、UTF-8 document でも既定 encoding 用の文字参照を返します。
NULL list は NULL、選択 text のない non-NULL list は独立した空文字列です。
返却値は source DOM と独立し `xmlFree` で解放できます。OOM は NULL として返り、source DOM は変更しません。
HTML/entity expansion は未対応です。
`xmlNewNs` のhref/prefixはSPARKで計測してコピーします。nonNULL要素は登録・種類を
先に確認し、不正なら両入力を読みません。NULL/空の区別と既存の宣言・所有権処理を保ちます。
`xmlSearchNs` / `xmlSearchNsByHref` の検索入力も登録確認後にSPARKで計測・コピーし、
親走査・隠蔽判定と文書なしnodeの組み込みxml宣言の作成・再利用は既存処理を使います。
属性の取得・存在確認も名前/URIをSPARK内で計測・コピーします。要素の登録・種類を
先に確認し、借用属性と独立した属性値の所有権、namespaceフィルタは従来どおりです。
`xmlNewProp` の名前/値もSPARK内で計測・コピーし、既存の属性作成・接続・失敗時の
巻き戻しを再利用します。単独属性、重複名の末尾追加、NULL値と空値の区別を維持します。
`xmlNewNsProp` / `xmlSetNsProp` も共通のSPARK入力経路を使い、要素と名前空間の
登録確認後に読み取ります。URIによる照合・旧値保持・namespace所有権の契約は維持します。
`xmlSetProp` のQName/値も要素の登録確認後にSPARK内で計測・コピーし、既存の
prefix解決、非修飾属性の更新、暗黙XML namespaceの作成・失敗時の巻き戻しを再利用します。
`xmlUnsetProp` / `xmlUnsetNsProp` は共通SPARK経路で登録確認・名前の計測/コピー・
削除を行い、非修飾/URI照合を区別します。C側の汎用文字列走査・変換ヘルパーは不要になりました。

`xmlCopyNode`、`xmlDocCopyNode`、`xmlCopyProp`、`xmlCopyDoc` は、SPARKの
`XML3_DOM_Store.Copies` が既存のノード作成・接続・namespace検索/作成・解放を組み合わせて
コピーします。`extended` は0がノードだけ、2が要素の属性とnamespace宣言まで、それ以外が
子孫を含む全体です。コピーしたノードのnamespaceは libxml2 の `xmlStaticCopyNode` と同じ順で、
コピー側で見える同じprefixの宣言、元の木の宣言をコピーの最上位に宣言し直したもの、
重複しないprefix（`a1` など）の新しい宣言の順に決めます。途中で失敗した場合は作成済みの
コピーを解放します。固定版2.15.4と同じ出力になることを `make test-copy` で比較しています。
libxml2との差は次のとおりです。
- `xmlCopyProp` のコピーは親がNULLのまま返します。libxml2は親を `target` に向けますが
  リストにはつなぎません。`xmlAddChild` で付けるか `xmlFreeProp` で解放してください。
- 要素の行番号（`xmlGetLineNo`）はコピーしません。
- 親のない兄弟リストを表せないため、`xmlCopyNodeList`、`xmlDocCopyNodeList`、
  `xmlCopyPropList` は未対応です。namespace宣言（`xmlNs`）を `xmlCopyNode` でコピーすることも
  できません。DTDとIDは対象外です。

`xmlReadFile` と `xmlParseFile` はファイル（`-` なら標準入力）を読み、`xmlReadMemory` と同じ解析を
ファイル名をURLとして行うので、解析エラーはファイル名を持ちます。ファイル名は libxml2 の `xmlFdOpen` と同じく、
`file:` URI だけを接頭辞の後でアンエスケープし、それ以外はそのまま使います（SPARKの `XML3_File_Paths`）。
開けない場合は libxml2 の `xmlCtxtErrIO` と同じ `XML_FROM_IO` のエラーを記録します（`failed to load "名前": 理由`、
str1にファイル名、見つからない場合は警告、それ以外は致命的）。読めない場合（ディレクトリなど）は
ファイル名付きで1行1列目の致命的エラーです。コードと文言はSPARKの `XML3_IO_Errors` の表で決め、
読み込み自体は小さなCヘルパーで行います。固定版2.15.4と同じ結果になることを `make test-input` で比較しています。
公開 `xmlDoc` に `URL` フィールドがないこと、圧縮入力とネットワークURL、`xmlReadMemory` が受け付けない解析オプションは
対象外です。解析コンテキストのAPI（`xmlNewParserCtxt`、`xmlCtxtReadMemory` など）は未対応です。

`xmlNewNodeEatName`、`xmlNewDocNodeEatName`、`xmlNewNsPropEatName` は通常の生成と同じノードを作り、
渡された名前を成否にかかわらず `xmlFree` で解放します（ノードは名前の複製を持ちます）。
`xmlNodeBufGetContent` はノードの内容を、`xmlAttrSerializeTxtContent` は属性値としてエスケープした文字列を
`xmlBuffer` に追加します。後者は libxml2 と同じく、文書にエンコーディングがない場合として非ASCII文字を
16進の文字参照（不正なUTF-8は `&#xFFFD;`）にします。`xmlGetBufferAllocationScheme` /
`xmlSetBufferAllocationScheme` は libxml2 2.15 と同じく固定値と何もしない関数、`xmlFreeNsList` は
連結した名前空間宣言を順に解放します。

`xmlBuffer` 系（`xmlBufferCreate`、`xmlBufferCreateSize`、`xmlBufferCreateStatic`、`xmlBufferFree`、
`xmlBufferEmpty`、`xmlBufferShrink`、`xmlBufferGrow`、`xmlBufferResize`、`xmlBufferAdd`、`xmlBufferAddHead`、
`xmlBufferCat`、`xmlBufferCCat`、`xmlBufferWriteCHAR`、`xmlBufferWriteChar`、`xmlBufferWriteQuotedString`、
`xmlBufferContent`、`xmlBufferLength`、`xmlBufferDetach`、`xmlBufferSetAllocationScheme`、`xmlBufferDump`）は、
サイズの決め方（既定256バイト、倍増または使用量+要求量+101）、先頭を削った分のずれ（`content` と `contentIO`）、
戻り値まで libxml2 2.15.4 の `XML_BUFFER_ALLOC_IO` と同じにしました。大きさ・確保・コピーの判断は
SPARKの `XML3_Byte_Buffers` で行い、アダプタは公開構造体との読み書きだけを行います。
`xmlNodeDump` はSPARKのシリアライザをノード単位で使い、要素とその子孫、テキスト、CDATA、コメント、PI、
属性（先頭の空白付き）、文書（UTF-8宣言付き）を書き出します。`level` は0〜100に丸め、`format` のとき
子孫を字下げします（テキストを含む要素の中は字下げしません）。`xmlElemDump`、`xmlDocDump`、
`xmlDocFormatDump` はストリームへ、`xmlSaveFile`、`xmlSaveFormatFile`、`xmlSaveFileEnc`、
`xmlSaveFormatFileEnc` はファイルへ書きます。ファイル名は libxml2 と同じく、スキームのない名前を
URIとしてアンエスケープし、`file:` URI は接頭辞の後をアンエスケープし、`-` は標準出力にします
（SPARKの `XML3_File_Paths`）。実際のファイル操作だけを小さなCヘルパー（`xml3_file_io.c`）で行います。
固定版2.15.4と同じ出力になることを `make test-output` で比較しています。libxml2との差は次のとおりです。
- エンコーディングはUTF-8だけです。圧縮出力は対象外です。
- ファイル名は、正しいURI参照でなくてもアンエスケープします。シリアライズに失敗した場合はファイルを作りません。
- シリアライザは整形式で書けない木（`--` を含むコメントなど）を拒否します（libxml2はそのまま書きます）。

`xmlCopyNamespace` は libxml3 が管理する live namespace facade のみを source として受け付け、
href/prefix の bytes と NULL/empty の区別を独立した detached namespace にコピーします。
source の `next`、`context`、`_private` はコピーせず、返却された reservation は呼び出し側が
`xmlFreeNs` で解放します。node から参照されている間は Store の pin が storage を保持します。
foreign・stale pointer の検証、namespace list のコピー、native pointer/ABI の安全性は対象外です。
`xmlStrdup` は非NULLのNUL終端文字列を上限内で複製し、`xmlStrndup` は指定された長さの
raw bytes を埋め込みNULを含めて正確に複製して末尾NULを付加します。後者の長さ0は
入力を読み取らず、所有権付きの空文字列を返し、負または上限超過の長さは拒否します。
NULL入力はNULLを返し、返却値は `xmlFree` で解放します。UTF-8検証は行わず、native
pointer、読み取り可能性、allocation、ABI は信頼境界です。
`xmlCharStrdup` は `char *` 版の `xmlStrdup` で、`xmlCharStrndup` は `char *` 入力を
最大 `len` bytes 読み、先にNULがあればそこで止まります。後者は `xmlStrndup` と異なり
指定長の埋め込みNUL以降をコピーしません。0長は入力を読まず、NULLまたは負長はNULLを返し、
両APIは `Max_Bytes` 上限を適用し、`xmlCharStrndup` の `len` 超過は読み取り前に拒否します。
複製APIの走査・コピーはSPARK側で直接行い、C文字列の中間コピーは不要です。
入力byteは高位bitも含め変換・UTF-8検証せず保持し、
返却値は `xmlFree` で解放します。pinned reference はNULが早期にあっても `len+1` bytesを
allocationしますが、余剰tailは未規定です。libxml3はコピーprefix+NULだけを確保し、
余剰capacityもallocation-size equivalenceも保証しません。テストは定義済み文字列内容のみを比較します。
`xmlStrchr` は最初の一致した非NUL byteの入力内pointerを借用して返します。
元の入力が有効な間だけ利用でき、借用ポインタ自体は解放しません。
NULL入力、
検索値0、またはNUL以前に一致がなければNULLです。検索値0でもNUL terminatorは返しません。
payload offset `0..Max_Bytes-1` を調べ、境界offset `Max_Bytes` のNULは許容します。
境界まで一致もNULもない場合はエラーを記録してNULLを返しますが、検索範囲内に一致があれば
それ以降を読まず成功するため、長い文字列を一律拒否する上限ではありません。allocation、
書き込み、UTF-8変換は行わず、実際のnative読み取り可能範囲、pointer、byte内容、address計算は
信頼境界です。
`xmlStrstr` と `xmlStrcasestr` は NUL 終端の raw byte 列から最初の substring を探し、
一致した入力内 pointer を借用して返します。どちらかの入力が NULL なら NULL、非NULL
haystack の空 needle は haystack pointer をそのまま返し、haystack を読みません。入力と
pattern は最初の NUL で終端し、重なった入力、UTF-8 の途中 byte、その他の raw bytes を
そのまま扱います。`xmlStrcasestr` は `A`–`Z` と pinned reference の `[` -> `{` を
byte-map しますが、Unicode case folding や XML/UTF-8 検証は行いません。早い一致や空
needle は全体を走査せず、`Max_Bytes` 未満の payload と境界の NUL を調べます。境界より
先の non-NUL byte が必要なら診断を記録して NULL を返しますが、長い文字列を一律拒否する
上限ではありません。返却 pointer は入力が有効な間だけ使い、`xmlFree` せず、allocation・
書き込み・transcodeも行いません。native pointer、読み取り可能範囲、byte内容、address
計算、完全なAPI意味論は信頼境界です。
`xmlStrsub(str, start, len)` は独立した `xmlFree` 所有の raw-byte copy を返します。
NULL入力、負の `start`/`len` は診断なしでNULLです。start byte を検証するため `0..start` を走査し、
その範囲でNULを見つけた場合もNULLです。`len == 0` でもstartを検証して空allocationを返します。
有効なstartの後は文字列終端で切り詰めず、指定された `len` byteを正確にコピーし、
最後にNULを付けます。したがって呼び出し側はそのspan全体を読めるようにする必要があります。
埋め込みNUL、UTF-8断片、その他のbyteを検証・変換しません。`start < Max_Bytes` と
`len <= Max_Bytes - start` を読み取り前に確認し、範囲超過は診断付きNULLです。
実際のnative pointer/読み取り可能範囲/byte内容、allocationとwrite、address計算、完全なAPI意味論は
信頼境界です。
`xmlStrcmp`、`xmlStrEqual`、`xmlStrcasecmp` は SPARK
`XML3_Text.Buffers.Compare_Terminated` の byte scan を共有します。同一 pointer は読み取りなしで
比較結果0、`xmlStrEqual` は1です。NULL/NULLも等しく、片側だけNULLなら左NULLが-1、右NULLが+1です。
`xmlStrcmp` は unsigned byte 差、`xmlStrEqual` はraw byte equalityを返します。
`xmlStrcasecmp` は `A`–`Z` に加えて `[` を `{` に写す pinned reference の byte-map quirk を保ちます。
Unicode case folding、UTF-8検証、transcoding、allocation、mutation、C-string変換は行いません。
scan は offset `0..Max_Bytes` を調べ、不一致またはNULで終了します。境界まで同じ非NUL byteが続く場合は
診断を記録して `xmlStrcmp` / `xmlStrcasecmp` が -1 を返し、この値は順序比較として信頼できません。
`xmlStrEqual` はその場合0を返すため、診断も確認してください。早期不一致、NUL、NULL、同一pointerは
上限より前に終了できます。小さな `Last` を使う Ada helper test と形式検証で上限動作を確認し、
公開C APIの巨大文字列で上限を動的に試してはいません。foreign pointerの有効性、読み取り可能範囲・
実際のbyte内容、address計算、完全なAPI意味論は信頼境界です。
`xmlStrlen` は最初のNULまでのraw byte数を返し、NULLなら0です。不正UTF-8 byteもdecodeせず
byteとして数えます。SPARK `Read_Length` はoffset `0..Max_Bytes` を調べ、境界位置のNULを
受け入れます。範囲内にNULがなければDOM error 115を記録して-1を返します。この値はempty string
を意味する結果ではないので、呼び出し側はdiagnosticを確認してください。予期しないC-side例外は
DOM error 1を記録して-1を返します。pinned referenceは
`INT_MAX` を超える長さを0にしますが、このsubsetは `Max_Bytes` でscanを制限し、未終端の
cap超過を診断します。早期に終端する長い文字列を一律拒否するものではありません。
`Max_Bytes` は `Integer'Last - 16` です。
cap動作は小さい `Last` を渡すAda helper testで確認し、巨大な公開C stringは動的に構築していません。
allocation・mutation・transcoding・UTF-8/XML validationは行いません。SPARKはscan bounds、
result range、status contractを証明しますが、native reads、pointerの有効性・読み取り可能範囲・
実byte内容、C diagnostic mapping、完全なAPI意味論は信頼境界です。raw-byte、Unicode byte count、
guard-page vectorsはreferenceとlibxml3の両方で、no-allocation testはlibxml3のみで実行します。
`xmlCheckUTF8` は NUL 終端列を strict UTF-8 として検査し、NULL・不正・途中で切れた列は0、
空列は1を返します。NULで検査を終え、その後のbyteは読みません。ASCII controlとUnicode
noncharacterもUTF-8として正しければ1です。これはUTF-8 byte encodingだけの検査で、XML文字の
許容性やXML text validityを判定しません。overlong encoding、surrogate、U+10FFFFを超える
scalarは拒否します。pinned referenceが受け入れるこれらの非canonical encodingを拒否するのは、
危険なmalformed UTF-8の受容を再現しない意図的な安全差です。malformed入力では診断を記録しません。
既存のXML parsing、name/content validationのXML文字制約は変更しません。
offset `0..Max_Bytes` を調べ、境界NULは受け入れますが、その範囲で終端しない入力はDOM error 115を
記録して0を返します。予期しないC-side例外はDOM error 1と0です。最大4 byteのstack bufferを使い、
allocation・mutation・transcodingを行いません。小さい `Last` のAda testでcap動作を検査し、
巨大な公開C stringは構築していません。SPARKの証明範囲は走査制御・index bounds・native call
preconditionsであり、native byteの実値や読み取り可能範囲、pointer妥当性、C mapping、完全な
Unicode API意味論は信頼境界です。通常・malformed・guard-page vectorsはreferenceとlibxml3の両方で、
referenceだけが受け入れる非canonical casesは期待値を分け、no-allocation testはlibxml3のみで実行します。
`xmlGetUTF8Char` は `*len` bytes以内から先頭のUTF-8 scalarをdecodeし、成功時にcode pointと消費byte数を返します。
`utf == NULL`、`len == NULL`、または `*len < 1` は `-1` です。`len` が非NULLなら無効入力では `*len = 0`、
ただし `*len < 1` ではbyteを読みません。NULはcode point 0、幅1として返します。ASCII controlとUnicode
noncharacterも有効なencodingなら受け入れ、XML character validityは検査しません。strict UTF-8として
overlong、surrogate、U+10FFFF超過と不正・truncated sequenceは `-1` / `*len = 0` で、診断は記録しません。
pinned referenceが `F8`–`FF` leadをmaskしてdecodeする差も再現せず、例として `F8 90 80 80` と
`FC 80 80 80` は拒否します。またreferenceは `*len < 1` の確認前に `utf[0]` を読むため、このsubsetは
その危険なreadを避けます。予期しないC-side例外はDOM error 1、`*len = 0`、`-1` です。
allocationやinput mutation、transcodingはしません。shared vectorsとguard-page exact-span testはreferenceとlibxml3で実行し、
referenceのpermissive vectorsは両方で期待値を分けます。`*len == 0` のunreadable-pointer安全testとOOM/no-allocation
testはlibxml3のみです。native pointer validity、`*len` 分のreadable extent、actual bytes、C-side mappingは信頼境界です。
`xmlUTF8Strlen` はNUL終端UTF-8列のUnicode scalar数を返し、byte数やgrapheme cluster数ではありません。
combining sequenceは構成scalarごとに数え、normalizationもしません。NULL・malformed・truncated・
overlong・surrogate・U+10FFFF超過などstrict UTF-8でない入力は診断なしで-1、空列は0で、最初のNULで停止します。
ASCII controlとUnicode noncharacterはvalid UTF-8なら数えますが、XML character validityは判定しません。
pinned referenceがoverlong、surrogate、範囲外scalar、また連続する2個のcontinuation byteを
1 scalarとして数える挙動は再現せず、strictに拒否します。`Max_Bytes` 位置までにNULを確認できない場合はDOM error 115と-1、
予期しない例外はDOM error 1と-1です。allocation、mutation、transcodingは行いません。
小さい `Last` のAda helper testでcapを確認し、巨大な公開C stringは構築していません。
SPARKは走査制御、scalar counter/bounds、status/result contract、native-call preconditionsを証明しますが、
Unicode意味論全体、native bytes/readable extent、pointer validity、C mappingは信頼境界です。
`xmlUTF8Strpos` は0-based Unicode scalar位置を探し、一致位置へのborrowed pointerを返します。NULL inputまたは負の位置は
診断なしでNULL、位置0はinput pointerを読み取りなしで返します。位置が範囲内なら、そこまでのprefixだけをstrict UTF-8として
検査し、target scalarとsuffixは読み取りも検証もしません。位置がscalar lengthと等しい場合はNULのaddressを読み取りなしで返し、
それより先ならNULLです。したがって全文字列のvalidation oracleではありません。ASCII controlとUnicode noncharacterは許可されますが、
XML character validationはしません。overlong、surrogate、U+10FFFF超過、およびpinned referenceが受け入れる5-byte sequenceは
検査対象prefix内なら拒否し、これは意図的な安全差です。prefixがinclusive `Max_Bytes` まで未解決ならDOM error 115とNULL、
予期しないC-side例外はDOM error 1とNULLです。allocation・input mutation・normalizationは行いません。
返却pointerはinputのlifetime中だけ有効で、`xmlFree`しません。小さい `Last` のAda testでcapを検査し、巨大な公開C stringは
構築していません。SPARKはscan control、index/offset bounds、status/result contractとnative-call preconditionsを対象にし、
foreign pointer validity/readable extent、actual bytes、C mapping、完全なUnicode意味論はtrusted boundaryです。
`xmlUTF8Strsize` は最大 `len` 個のUnicode scalarに対応するbyte数を返し、終端NULは含めません。scalar数であり、
grapheme数ではありません。NULL inputまたは `len <= 0` は読み取りなしで0です。要求数より短い文字列は最初のNULまでの
byte数を返します。要求したscalar数に到達した時点で停止し、その後のsuffixは検査しません。訪問prefixにmalformed、
truncatedまたはnoncanonicalなstrict UTF-8があれば、部分byte数ではなく診断なしで-1です。referenceのinvalid UTF-8
動作は保証されないため、この実装は不正な訪問prefixを明示的に拒否します。ASCII controlとUnicode noncharacterは許可しますが、
XML character validationはしません。inclusive `Max_Bytes` まで走査が未解決ならDOM error 115と-1、予期しない例外は
DOM error 1と-1です。allocation、input mutation、normalizationは行いません。小さい `Last` のAda testでcapを確認し、
巨大な公開C stringは構築していません。SPARKはscan control、byte-offset bounds、status/result contractとnative-call
preconditionsを対象にし、foreign pointer validity/readable extent、actual bytes、C mapping、完全なUnicode意味論はtrusted boundaryです。
`xmlUTF8Size` は完全なUTF-8検証ではなく、先頭byteだけを分類します。NULLなら読み取りなしで-1、それ以外はbyte 0だけを読み、
以降のbyteやNUL終端は確認しません。`0x00..0x7f`（NULを含む）は1、`0xc2..0xdf` は2、`0xe0..0xef` は3、
`0xf0..0xf4` は4、それ以外は-1です。そのため、単独の `0xe2` や `0xed 0xa0 0x80` の先頭は、それぞれ幅3を返しますが、
後続byte、truncation、scalarの有効性は検査されません。先頭の1 byteだけ読み取り可能な非NUL終端bufferでも動作します。通常の有効・無効
先頭byteではallocation・mutation・diagnosticはなく、予期しない例外だけDOM error 1と-1になります。pinned referenceも先頭だけを
読みますが、`0xc0..0xc1`、`0xf5..0xf7`、`0xf8..0xfb`、`0xfc..0xfd`、`0xfe` に幅を返します。この実装はUnicode leadではない
これらを拒否します。実際のUTF-8妥当性検証やdecodeには `xmlCheckUTF8` または `xmlGetUTF8Char` を使います。SPARK helperの
結果の範囲・NULL時のcontract・native-callの前提を証明しますが、foreign byte、pointer validity/readable byte、C mapping、完全なAPI意味論はtrusted boundaryです。
全256先頭byteをそれぞれPROT_NONE直前の最後のreadable byteに置くguard test、単独の非NUL終端1-byte input、
allocationなしの挙動をtestします。
`libxml/uri.h` は `xmlURIEscapeStr` / `xmlURIUnescapeString` / `xmlNormalizeURIPath` に対応します。
`xmlURIEscapeStr` はbyte単位のpercent-encodingで、英数字と
`-._~!*'()@` および例外リストに含まれるbyteを保持し、それ以外をuppercase `%HH` にします。
URI/UTF-8の検証や正規化ではなく、例外指定なしの `%` は `%25`、空白は `%20` となります。
結果は独立したNUL終端領域で `xmlFree` が必要です。NULL入力はNULL、空入力は空文字列のコピーです。
SPARK側で長さを計算して一度だけ確保し、上限・確保失敗では部分結果を返しません。入力・例外リストの
実際に読む範囲は安定してreadableである必要があり、native memoryとC ABIはtrusted boundaryです。
`xmlURIUnescapeString` は `%HH` をbyteへ戻します。不完全・不正な `%` と `+` はそのままです。
正の長さは埋め込みNULを含む指定byte数、0以下は最初のNULまでを処理します。`%00` もNULへ戻す
低level処理で、URI/UTF-8の検証ではありません。出力先がNULLなら `xmlFree` が必要な独立領域を返し、
指定済みならその領域を返します。出力先は結果と終端NULを保持できる容量が必要です。同一ポインタでの
in-place処理は確保不要、それ以外の非空出力は一時領域を経由して部分overlapにも対応します。
そのため指定済みの別出力先でもOOMになり得ますが、その場合は元の出力先を変更しません。
`xmlNormalizeURIPath` はURIのpath部分だけをin-place・確保不要で正規化します。
連続 `/` と `.` を除去し、`..` は直前の通常segmentを取り消します。
相対pathの余分な先頭 `..` は保持し、絶対pathはrootより上へ進みません。
固定版の `..//..` → `../`、`/../a` → `/../a` という不整合は再現しません。
成功は0、NULLと走査上限超過は-1で、上限超過は書き換え前に診断115を返します。
空入力は書き込みもしません。非空入力は元の終端まで書き込み可能な、安定した領域が必要です。
backslash・percent sequence・UTF-8・queryは解釈しません。URI全体の解析・解決、
filesystemのcanonicalizationやdirectory traversal防止ではなく、pathだけの処理です。
`libxml/parserInternals.h` から公開するのは deprecated な低level UTF-8 writer
`xmlCopyCharMultiByte(xmlChar *out, int val)` と `xmlCopyChar(int len, xmlChar *out, int val)` の2つだけです。
Unicode scalar valueをUTF-8 byte列として1..4 byte書き、追加のNUL terminatorは付けません。`val == 0` は1 byteのNULを書きます。
`xmlCopyChar` の `len` は互換性のため無視され、capacityではありません。呼出側は実際の幅に十分な書込み可能で安定した領域を用意します。
全scalar value（XMLで禁止されるcontrolやnoncharacterを含む）をencodingし、XML character validationはしません。
負値、U+10FFFF超、surrogate、NULL outputは0を返し、surrogate拒否はstrict UTF-8の安全差です。
通常の成功・拒否ではallocationやdiagnosticを行わず、sticky errorを変更しません。output pointerの有効性・extentは検査せず、
他の `parserInternals.h` APIも対応範囲に含みません。既存のXML parser/name validationは引き続きstrictです。
`xmlUTF8Charcmp` は最初の文字のbyteを比較し、Unicode code pointの減算ではありません。両方NULLなら0、左だけNULLなら-1、右だけNULLなら1で、NULL分岐では非NULL側を読みません。両方nonNULLなら左leadを `UTF8_Lead_Size` で分類し、無効なleadは右を読む前に診断付き-1です。分類幅（1..4、NULは1）の範囲で最初のunsigned-byte差を返し、差・NUL・幅で停止します。不一致なら直ちに返して残りをdecodeも検証もしないため、`E2 x` 対 `E3 y` は診断なしの-1、`a` 対 `0xff` は診断なしの-158です。byte比較が等しい場合だけ `Get_UTF8_Char` で左の先頭scalarを検証してから0を返し、same-pointer比較でも検証を省きません。equalなmalformed/truncated/overlong/surrogate/out-of-range prefixは診断付き-1となり、pinned referenceの0と意図的に異なります。有効な先頭文字ではpinned referenceと同じbyte差を返し、suffixは無視します。case folding、normalization、grapheme matching、XML character validationは行わず、controlとnoncharacterもUTF-8として許可します。無効文字の診断は通常 `XML_FROM_TREE` / `XML_ERR_INVALID_CHAR`（error 9）ですが、診断allocation失敗時は標準OOM error 2、予期しない例外はerror 1となり、いずれも結果は-1です。通常比較はallocationせず入力も変更しませんが、診断はallocationすることがあります。成功比較は既存last errorを消さないため、診断された-1と通常のbyte差-1を区別するには呼び出し前にerrorをresetし、呼び出し後に確認します。上限は左leadが示す最大4 byteです。入力は実際に触れるbyte範囲でreadableかつ安定している必要があり、equal prefixではaliasでも先頭scalar全体またはNULまで読むことがあります。SPARKは結果範囲 `-255..255` と `Invalid => -1` のcontractおよびnative-call preconditionsを対象とし、native byte、readability、pointer validity/stability、C mapping/ABI、完全なUnicode意味論はtrusted boundaryです。
`xmlUTF8Strloc` はpatternの最初のUnicode scalarと一致するsource内の最初のscalar indexを返し、byte offsetではありません。
patternのsuffixは無視しますが、最初のpattern scalarとmatchまでのsource scalarはstrict UTF-8として検証します。
malformed/truncated/overlong/surrogate/out-of-rangeな訪問prefixは診断なしで-1となり、match後のsuffixは検査しません。
NULL pointerがどちらかなら他方を読まず-1です。無効なpattern scalarはsourceを読む前に拒否します。
空patternは意図的に保持するreference互換の例外で、非empty sourceならbyte 0だけを読み0を返し、UTF-8検証はしません。
empty sourceなら-1です。normalization、case folding、grapheme countingは行わず、control/noncharacterもUTF-8としては許可します。
通常のmatch/no-match/malformed入力ではallocation・mutation・diagnosticはありません。inclusive `Max_Bytes` まで未解決なら
DOM error 115と-1、予期しない例外ならDOM error 1と-1です。patternは最初のscalarまで、sourceはmatch scalarまたはNULまで
readableかつ走査中に安定している必要があり、match scalarはNULなしでguard page直前に終わっても構いません。
SPARKは走査・scalar index bounds、status/result contract、native-call preconditionsを対象としますが、native bytes、
readable extent/pointer validity、stability、C ABI/mapping、完全なUTF-8 API意味論はtrusted boundaryです。
`xmlUTF8Strndup` は最大 `len` 個のUnicode scalarを訪問prefixだけstrict UTF-8として検証し、
そのraw bytesを新しいNUL終端allocationへコピーします。NULL inputまたは負の `len` は読み取り・allocation・
診断なしでNULL、非NULL inputの `len == 0` はinputを読まずに新しい空文字列を返します。正の `len` は要求scalar数または
最初のNULで停止し、未訪問suffixは検査しません。訪問prefixのmalformed・truncated・noncanonical encodingはallocation前に
部分コピーなしで診断なしのNULLとなります。返却値はcallerが `xmlFree` するowned copyで、inputを変更・解放しません。
ASCII controlとUnicode noncharacterはUTF-8として許可しますが、XML character validationはしません。referenceのinvalid
UTF-8動作は保証されず、strict prefix拒否は意図的な安全差です。inclusive `Max_Bytes` までscanが未解決ならDOM error 115とNULL、
allocation failureは標準のDOM error 2、予期しない例外はDOM error 1とNULLです。小さい `Last` のAda testでcapを確認し、
巨大な公開C stringは構築していません。SPARKはscan、span/byte bounds、status/result contract、native-call preconditionsを対象にし、
native bytes/readable extent、pointer validity、allocationの実動作、C ABI/mapping、完全なUnicode API意味論はtrusted boundaryです。
shared malformed/reference・guard-page vectorsはreferenceとlibxml3の両方で実行し、OOM/no-allocation testはlibxml3のみです。
`xmlUTF8Strsub` は `start` から最大 `len` 個のUnicode scalarを新しいNUL終端owned copyへ複製します。
NULL input、負の引数、範囲外の開始位置はNULLです。`start` は要求したscalar数までのprefixをstrict UTF-8として検証し、
その後の選択範囲もコピーする範囲だけ検証します。訪問したskipped/selected prefixのmalformed・truncated・noncanonical
encodingは診断なしでNULLとなり、末尾の未訪問byteは検査しません。`len == 0` でもskipped prefixは検証しますが、
選択targetは読みません。`start == 0 && len == 0` はinputを読まずempty copyを作り、scalar lengthでのstartは
正のlenでもempty copyを返します。返却値はcaller所有で `xmlFree` し、inputは変更・解放しません。
scalar countであり、byte/grapheme countではなく、normalization/transcodingもしません。ASCII controlとUnicode
noncharacterはUTF-8として有効ですがXML character validationではありません。pinned referenceがskip中のnon-NUL
continuation byteを検査しない挙動に対し、strict rejectionは意図的な安全差です。inclusive `Max_Bytes` のglobal cap
超過はDOM error 115、allocation failureはerror 2、予期しない例外はerror 1を記録してNULLを返します。小さい `Last` の
Ada testsでglobal capを確認し、巨大な公開C stringは構築していません。native bytes/readable stable extents、pointer validity/
offset arithmetic、allocation、C mapping/ABI、完全なUnicode API意味論はtrusted boundaryです。
`xmlStrncmp` と `xmlStrncasecmp` は正の `len` の範囲でbyte単位に比較し、
Max_Input cutoffを設けずC `int` の正の全範囲（early exit時の `INT_MAX` を含む）を受け付け、
最初の不一致、NUL、または長さ境界で停止します。`len <= 0` はpointer判定より先に0を返し、
同一pointerは0、NULLの左辺は-1、NULLの右辺は+1です。`xmlStrncmp` はunsigned byte差を返します。
`xmlStrncasecmp` は `A`–`Z` に32を加え、さらに `[` を `{` に写す pinned reference の
byte-map quirk を保持します。これはUnicode case foldingではありません。比較でallocationや
C-string変換は行いませんが、foreign pointerの有効性、実際のbyte内容と読み取り可能範囲は
信頼境界です。
`xmlStrncatNew` は `str1` のNUL終端部分と `str2` の指定byte spanを新しい
NUL終端allocationへコピーします。負の `len` は `str2` のNUL終端長として扱い、
`str1 == NULL` なら `xmlStrndup` 相当のコピーになります。非NULLの `str1` では
NULLの `str2` または有効長0なら `str1` の複製、それ以外は `str1` と `str2` の
raw bytes（埋め込みNULを含む）の連結です。入力は変更されず、返却値は `xmlFree` で
解放します。計測とコピーはSPARK側で直接行い、C文字列の中間コピーは不要です。
合計サイズ上限超過は拒否し、正の右側spanを読む前に上限を確認します。
UTF-8検証は行いません。native pointerの有効性、allocation、byte writes、ABIは信頼境界です。
`xmlStrcat` と `xmlStrncat` は no-op 以外では `cur` を消費するAPIです。`cur` はNULLか、
呼び出し側が所有する `xmlFree` 互換allocationの先頭でなければならず、literalやDOMから借りた
pointerを渡してはいけません。no-op 以外の呼び出し後、元の `cur` は成功・通常の失敗のいずれでも
解放済みなので再利用・再解放しません。返却allocationは `xmlFree` で解放します。
`xmlStrcat` は `add` のNUL終端byte列を追加し、NULLの `add` は `cur` をそのまま返します。
空 `add` は非NULL `cur` なら読み取りなしでno-opですが、NULL `cur` なら所有可能な空文字列を作ります。
`xmlStrncat` はNULL `add` または `len == 0` を負の長さ判定より先にno-opとして扱います。
非NULL `add` に対する負の `len` は診断なしで `cur` を消費してNULLを返します。正の `len` は
埋め込みNULを含む指定byte数を正確にコピーし、その後にNULを追加します。
追加文字列と既存prefixの長さは `Max_Bytes` に制限します。`xmlStrncat` の正の長さが上限を超える場合は
両入力の読み取り前に検出します。`xmlStrcat` は `add` を先に走査し、既存prefixの走査を残りcap内に
制限します。境界位置のNULは受け入れ、NULなしでcapを超える場合はDOM error 115を診断します。
allocation失敗は既存OOM診断となり、いずれのエラーでも `cur` は消費されます。
入力のUTF-8/XML検証やtranscodingは行いません。
実装は `cur` を `realloc` せず新しいallocationへcopyしてから旧 `cur` を解放するため、
`add` が `cur` 内を指すaliasも読めます。常に新しいbufferを作るのでpeak memoryとcopy workが増え得ます。
SPARKはbounded length、native call preconditions、status/result contractを証明しますが、native byte
reads/writes、allocation/free、pointerの有効性と所有権は信頼境界です。shared ordinary/guard-page
vectorsはpinned referenceとlibxml3の両方で実行し、alias/cap/OOM/free-count checksはlibxml3-onlyです。
`xmlNewDocNode` / `xmlNewDocRawNode` は文書に所属する未接続の要素を作成します。
前者は文字参照を展開し、後者は入力をそのままテキスト子に保持します。
`xmlNewNode`・子要素・文書付き属性も共通のSPARK入力経路を使います。名前と本文を読む前に
文書・親・namespaceを登録表で照合し、C側では中間Stringを作りません。名前とraw本文は
既存の所有領域へ直接コピーし、参照展開する本文だけはSPARK内の入力・復号バッファを使います。
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
`xmlAddPrevSibling` / `xmlAddNextSibling` は、親に接続された managed content sibling の
直前・直後へ node identity を保って挿入します。通常 child、document の comment/PI と
唯一の root、既存 `Attach_Child` 規則に従う attribute-value text が対象で、隣接 text は
結合しません。NULL/self、attribute sibling、parentless list、cycle、追加 document root、
cross-document move は変更せず拒否します。属性 sibling、親なしの sibling list、
namespace reconciliation は対象外です。
`xmlReplaceNode` は同一文書の managed node を old の正確な位置へ移し、old を detached
node として返します。middle/first/last child、同一文書内の別 parent に接続中の node の移動、
明示的に切り離した node、
document root の置換、old の子孫を root へ昇格する置換、`cur == NULL` の unlink を扱い、
adjacent text は結合しません。attribute と non-attribute の不一致は upstream の harmless
quirk として old を変更せず返します。一方、両方が attribute の置換、cross-document move、
cycle、extra document root は DOM graph の安全性のため変更せず拒否します。old == cur、
NULL/unmanaged/parentless old も拒否します。返された old は独立して編集・解放でき、
document を先に解放した後も detached ownership の範囲で使用できます。
`xmlGetLastChild` は要素に限定せず、document・element・属性値の末尾 child を取得します。
`xmlFreeNodeList` / `xmlFreePropList` は指定位置から末尾までの兄弟列と子ツリーを解放し、
残る親・直前の兄弟のリンクを安全に更新します。名前空間の参照保持もSPARK側で扱います。
`xmlNodeGetAttrValue` は名前空間付き属性の取得を、成功・属性なし・確保/上限/変換/内部エラーの戻り値で区別します。
名前空間検索は文書のない要素の `xml` 宣言も必要時にSPARK側で作成し、再利用します。
`libxml/valid.h` の `xmlValidateNameValue` / `xmlValidateNamesValue` /
`xmlValidateNmtokenValue` / `xmlValidateNmtokensValue` は、名前または名前列の
字句検査だけを行い、有効なら 1、それ以外は 0 を返します。DTD・ID の登録や参照解決は
行いません。NULL・空・不正 UTF-8・走査上限超過も 0 で、確保と診断変更はしません。
列の区切りは一つ以上の SPACE だけです。固定版の安全な癖として Nmtokens だけは
先頭の XML 空白と末尾の SPACE も許しますが、途中や末尾の TAB/LF/CR は許しません。
名前規則と UTF-8 復号は既存の SPARK 検査と共通化し、NUL または最初の不正文字で
読み取りを止めます。native pointer の読み取り可能性と C ABI は信頼境界です。

`xmlValidateName` / `xmlValidateNCName` / `xmlValidateQName` / `xmlValidateNMToken`
はUnicodeを含むXML名を、コロン・先頭文字・前後のXML空白の規則に従って検査します。
`space` が非0なら前後のXML空白だけを許し、正常は0、不正は1、NULL・走査上限・内部例外は-1です。
SPARKの共通走査へ入力ポインタを直接渡し、C文字列のコピー・確保・診断変更は行いません。
NULまたは最初の不正文字で停止し、末尾空白の後に非ASCII byteがあれば後続UTF-8を読まず拒否します。
`xmlSplitQName2` / `xmlSplitQName3` は名前検証を行わず、NUL終端の raw byte 列を最初の
コロンだけで分割します。最初のコロンが先頭・末尾にある場合や、コロンなしでは NULL、後続のコロン・空白・不正な
UTF-8 はそのまま扱います。QName2 は prefix/local の独立コピーを返し `xmlFree` で解放し、
QName3 は入力内の local suffix を借用して prefix の byte length を返します。失敗時は QName2
の prefix 出力を NULL にし、QName3 の length 出力を変更しません。
QName3 はSPARKでポインタを直接走査し、最初のコロンの次のbyteが非NULなら即座に返します。
local の末尾・UTF-8は検査せず、文字列コピーも行いません。通常は確保・診断変更なし、
走査上限で判定できなければ診断115とNULLです。借用先を残す必要があれば入力の解放前にコピーします。
QName2も同じSPARK検索を使い、残りのlocalを元入力からの上限内で計測してからコピーします。
C文字列の中間コピーは作らず、2つ目の確保に失敗すればprefixを解放し、両出力をNULLに保ちます。
`xmlBuildQName` も raw byte 列を扱います。NULL prefix は入力 name を借用して返しますが、
空 prefix は省略せず `:name` を構築します。十分な出力 buffer があればそこへ書き、足りなければ
指定した出力 buffer を変更せず `xmlFree` で解放する新規 allocation を返します。
計測と構築はSPARKが直接行い、C文字列の中間コピーは作りません。十分なbufferでも入力byteと
重なる場合は一時領域へ構築してから転送します。その確保に失敗すればbufferを変更しません。
`xmlStrQEqual` は QName の prefix/name/value を raw byte として比較します。NULL prefix は
`xmlStrEqual(name, value)` 相当で、NULL/NULL と同一 pointer は1です。非NULL prefix では
name/value も非NULLでなければならず、prefix の literal bytes、colon、name の bytes を
NUL まで比較します。空 prefix は常に0を返し、name/valueを読みません。これは、pinned
reference の空 prefix path が空 value の終端後を読む unsafe な挙動と、NUL後の `:name` tail
を解釈する挙動を再現しないためです。guard-page と NUL-then-`:name` の安全性テストは
libxml3-only で、固定版との比較対象には含めません。比較には `Max_Bytes` の
scan cap があり、上限を越える追加読み取りが必要なら診断を記録して0を返します。
早い一致・不一致は返るため、長い入力を一律拒否するものではありません。allocation・
書き込み・XML name/UTF-8検証は行わず、native pointer、
読み取り可能範囲、byte内容、完全な意味論は信頼境界です。
要素の前向き走査に加え、`xmlLastElementChild` / `xmlPreviousElementSibling` による
末尾・前方への走査も可能です。コメント・テキスト等は飛ばします。
`xmlTextMerge` は通常のテキストノードを結合し、成功時だけ第二引数を切り離して解放します。
同じ文書のノード、または文書に属さない第二引数に対応します。
`xmlTextConcat` は text・CDATA・comment・PI に限定した長さ指定追記です。
要素・属性は変更せず拒否し、負の長さでは NUL 終端文字列を読みます。
`xmlNodeIsText` / `xmlIsBlankNode` は、SPARK 管理中の node の種別と XML 空白を
読み取り専用で判定します。CDATA は後者の対象ですが、前者では text としません。
`libxml/chvalid.h` は upstream で deprecated の `xmlIsChar`, `xmlIsBlank`,
`xmlIsBaseChar`, `xmlIsCombining`, `xmlIsDigit`, `xmlIsExtender`,
`xmlIsIdeographic`, `xmlIsPubidChar` の8 scalar classifier と
`xmlCharInRange` を公開します。
`xmlIsChar` は XML 1.0 Char の範囲 (TAB/LF/CR, U+0020–D7FF, E000–FFFD,
10000–10FFFF) を 1、それ以外を 0 と判定し、許可範囲内の supplementary noncharacter を
追加除外しません。`xmlIsBlank` は U+0009・U+000A・U+000D・U+0020 のみ 1 です。
`xmlIsDigit`, `xmlIsExtender`, `xmlIsIdeographic`, `xmlIsPubidChar`,
`xmlIsBaseChar`, `xmlIsCombining` は現代の Unicode category ではなく、
upstream の `chvalid.h` / `codegen/ranges.inc` に由来する歴史的な固定集合です:
`xmlIsDigit` は U+0030–0039, 0660–0669, 06F0–06F9, 0966–096F, 09E6–09EF,
0A66–0A6F, 0AE6–0AEF, 0B66–0B6F, 0BE7–0BEF, 0C66–0C6F, 0CE6–0CEF,
0D66–0D6F, 0E50–0E59, 0ED0–0ED9, 0F20–0F29 のみを 1 とし、Tamil の U+0BE6 は含みません。
`xmlIsExtender` は U+00B7, 02D0–02D1, 0387, 0640, 0E46, 0EC6, 3005,
3031–3035, 309D–309E, 30FC–30FE のみを 1 とします。`xmlIsIdeographic` は
U+3007, 3021–3029, 4E00–9FA5 のみを 1 とします。`xmlIsPubidChar` は XML PubidChar
の ASCII 集合 (SPACE/LF/CR, ASCII 英数字, `-'()+,./:=?;!*#@$_%`) のみを 1 とし、
TAB は含みません。その他の値はすべて 0 です。
`xmlIsBaseChar` は pinned reference の197個の16-bit範囲と sub-256 の5範囲、
`xmlIsCombining` は同 reference の95個の16-bit範囲をそのまま判定します。
BaseChar 集合は CJK ideograph U+4E00 を含まず、Combining 集合は U+0346 を含みません。
引数は UTF-8 byte でなく unsigned scalar number で、高い unsigned 値も安全に 0 になります。
これらの歴史的分類は locale/現代 Unicode category ではなく、現在の NCName 検証規則にも使われません
(例: U+037F, `a` に続く U+0346, U+0BE6, U+9FA6 は引き続き NCName に使えます)。
scalar classifier は pure SPARK helper を使い、pointer access・allocation・diagnostic・
DOM access・lock・native range-table access を行いません。
`xmlCharInRange` は別の generic lookup で、`val < 0x10000` なら short table、
それ以外なら full unsigned domain の long table を選び、inclusive な `low..high`
range を overflow-safe な lower-middle binary search で調べます。
選択された count が正で byte span を `ptrdiff_t` で表せ、table が非NULLの場合だけ検索し、
NULL group・非正の count・NULL table・表現上限を超える count では診断なしで0を返します。未選択の配列は読みません。
descriptor 全体と選択された table は readable/aligned で、呼び出し中に変更されない必要があります。
table は caller 所有の borrowed data で、昇順・非重複を前提とします。
全表の順序検証は行わず、巨大な実配列を使うテストもありません。
global `xmlIs*Group` tables, header macros, DTD subsystem は対象外です。
C ABI、native layout/pointer/extents/byte reads と完全な upstream 意味論は信頼境界です。
`libxml/tree.h` の `xmlIsXHTML` は、固定版 `tree.c:8851` に合わせて
NUL 終端 byte 列を case-sensitive に比較します。両引数が NULL の場合のみ -1、
それ以外は public ID `-//W3C//DTD XHTML 1.0 Strict//EN`,
`-//W3C//DTD XHTML 1.0 Frameset//EN`, `-//W3C//DTD XHTML 1.0 Transitional//EN`
の3種を先に照合し、次に system URI
`http://www.w3.org/TR/xhtml1/DTD/xhtml1-strict.dtd`,
`http://www.w3.org/TR/xhtml1/DTD/xhtml1-frameset.dtd`,
`http://www.w3.org/TR/xhtml1/DTD/xhtml1-transitional.dtd` の3種を照合します。
一致なら 1、その他は 0 です。public ID が一致すれば system ID は判定に使いません。
未知の byte 列は UTF-8 検査せず 0 となり、URI 解決・DTD 読み込み・HTML parsing は行いません。
allocation・diagnostic・lock・DOM access はありません。native pointer/readability、
byte access、C ABI と完全な upstream 意味論は信頼境界です。
`xmlNodeGetLang` は node と ancestor の最寄りの `xml:lang` を所有権付きで返し、
空の値も継承を止めます。`xmlNodeGetSpacePreserve` は element のみを対象にし、
`default` / `preserve` 以外の値は ancestor まで探索します。対応する setter は
element に `xml:lang` / `xml:space` を設定し、NULL language は空値、space の
0 は `default`、非0は `preserve` です。
`xmlEncodeSpecialChars` は有効なUTF-8/XML文字列の `<`・`>`・`&`・
二重引用符・CRをエスケープし、`xmlFree` で解放する独立した文字列を返します。
NULL入力はNULL、空入力は空のコピーです。文書引数は参照しません。不正な文字を
黙って置換・保持せず診断付きで拒否し、DTD・一般実体の処理は追加しません。
走査・UTF-8/XML検査・出力計測・構築をSPARKで直接行い、C文字列の中間コピーはありません。
不正な文字以降は読まず、サイズ確認後に確保し、構築失敗では部分出力を解放します。
`xmlEncodeEntitiesReentrant` は NULL input なら文書を検証せず診断なしで NULL を返し、
non-NULL input では `doc == NULL` または登録済み文書のみを受け付け、空 input は独立した空文字列になります。
文書の登録確認を入力読み取りより先に行い、不正な文書なら入力には触れません。
`Escape_Special_Bytes` に直接渡すため、ここにもC文字列の中間コピーはありません。
`<`・`>`・`&` は名前付き参照、CR は `&#13;`、非ASCIIは大文字 hex の文字参照にし、
quote・TAB・LF は保持します。document encoding は保持しないため、明示 UTF-8 文書でも非ASCIIを参照化します。
不正UTF-8/XMLは診断付きで拒否し、既存参照や一般実体の展開・HTML処理はしません。
出力は独立した `xmlFree` 所有で DOM は変更せず、allocation failure は NULL を返します。
native pointer/byte reads, allocation/copy/free, ABI と完全な C semantics は信頼境界に残ります。
`xmlGetNodePath` は管理中の node の構造的な経路を独立した `xmlFree` 所有文字列で返します。
文書は `/`、要素は `/name`、属性は `/@name`、値の text は `/@name/text()`、
text/CDATA は `/text()`、comment は `/comment()`、PI は
`/processing-instruction('target')` です。兄弟中の同種要素・text/CDATA・comment・
同一targetのPIは複数時に `[1]` などの位置を付けます。default-namespace要素は `*` と表示し、
この場合は他の要素名・namespaceの兄弟も同じwildcard occurrenceとして数えます。
それ以外のnamespace要素はlocal nameと同じprefix（または同じnamespace参照）で比較し、
URIは比較しません。従ってこれはURI解決済みの一意なXPathではありません。document自身を
除き、ancestor documentは経路に含めず、detached nodeは自身を起点とします。
不正なUTF-8/XML名・prefix・PI targetは不正な経路文字列を生成せず診断付きで拒否します
（固定版のraw malformed name挙動との差）。完全な公開C意味論は未証明で、native pointer/readability、
allocation/byte write、ABI/status mappingはtrusted boundaryです。
`xmlGetLineNo` は管理中 node の parser source line を 0..65535 で返します。
これは元入力の解析位置であり、編集・再シリアライズ後の位置ではありません。
行の走査は LF のみを改行として数え、CR は単独でも CRLF の一部でも行を進めません。
この standalone-CR の扱いは固定版の harmless な互換性クィークに合わせたものです。文字参照で
得た改行は入力改行として数えません。
parsed の element/text/comment/PI は保存した source position を unlink・移動・rename・
content edit 後も保持しますが、65535 に達した値は bounded neighbor fallback の結果に
依存することがあります。構築 element/text/comment/PI と合成 attribute-value text は0です。
attribute と CDATA は previous-sibling/element-parent fallback を使い、detached 時に -1 と
なることがあり、移動後は継承する行が変わることがあります。NULL・document・未登録 facade は-1です。
65535 の fallback は最大5 nodeの範囲で行い、`XML_PARSE_BIG_LINES` は未対応です。
line 情報は内部 Store に保持し、public node struct field や直接書き込みAPIは追加しません。
native pointer/ABI と完全な公開 C 意味論は trusted boundary です。
`xmlNodeSetName` は管理中の element・attribute・PI の名前を独立所有領域へ
コピーして変更します。空・不正UTF-8・不正NCName、PIの予約名 `xml`、
非namespace属性の `xmlns`、expanded name が衝突する属性名は診断付きで拒否し、
失敗時は元の名前・値・リンクを変更しません。NULL と未対応node kindはno-opです。
attributeの衝突では既存propertyを削除せず、失敗して安全側に倒します。name ownership
はcontent ownershipと独立して保持されるため、content置換やdocument解放後も
managed detached nodeの名前は有効です。entity referenceや完全な公開C意味論は未対応・未証明で、
native pointer/readability、allocation/byte write、ABI/status mappingはtrusted boundaryです。
`xmlSetProp` は namespace-aware QName を
解決し、malformed QName と未束縛 prefix を拒否します。`xmlDocDumpMemoryEnc`
は明示的なUTF-8出力とNULL encodingをサポートし、encoding名のASCII大小文字を区別せず、
文書の登録確認後にSPARKで最大6byte（終端を含む）だけを読みます。
不正文書ではencodingを読まず、不正な名前は最初の不一致で拒否し、中間C文字列コピーは作りません。
明示指定では宣言に指定表記を保持します。`xmlDocDumpMemory` とNULL encodingでは
encoding宣言を省き、text・属性・namespace URIの非ASCII文字を大文字16進の文字参照にします。
名前・comment・PI・CDATAのUTF-8は保持します。XML 1.0以外、未対応encoding、無効なXML名・文字・
namespaceは拒否します。source encoding/standalone metadata は保持されず宣言には
出力しません。このため元文書のencodingへの暗黙復帰はせず、NULLは常に上記の既定出力です。
空のencoding名は拒否します。`xmlDocDumpFormatMemory` / `xmlDocDumpFormatMemoryEnc`
はformat=0で通常出力、非0で2空白の字下げ・改行を追加します。固定版の既定設定に合わせ、
字下げは60空白で頭打ちです。Text/CDATA（空白だけのTextも含む）を直接持つ要素の
subtree全体では整形を抑制し、後続の兄弟では再開します。DOM自体には空白を追加しませんが、
整形結果を再読み込みすると追加した字下げはTextになります。字下げ用global設定の変更、
ファイル出力、DTD等は未対応です。
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

読み込みオプションはSPARKの`Parser.Options.Classify`で
通常・HUGE・未対応に分類します。対応するNOERROR/NOWARNING/NONET/HUGE以外のbitと
負値は拒否し、HUGEで未対応機能を有効にはしません。`xmlReadMemory`ではencoding名の
判定後、本文を読む前に分類し、既存の診断の優先順位を保ちます。

通常 parser profile は name component/PI target を 50,000 bytes、decoded value
を 10,000,000 bytes、深さを 256 に制限します。`XML_PARSE_HUGE` はそれぞれ
10,000,000 bytes、1,000,000,000 bytes、2,048 に拡張します。文書全体の 64 KiB
上限や 2,048-node policy cap はなく、heap arena は必要に応じて拡張します。
作業領域のサイズ検査・4領域の確保・部分失敗の解放と容量増加の計算はSPARKの
`Parser.Workspaces`が担当します。C側にはarray overlay・再試行・lock・診断変換が残ります。
これらは表現・割り当て可能性の保証や完全な DoS 防止を意味せず、
詳細な既知の互換差と境界は compatibility/assurance 文書を参照してください。

UTF-16 の binary input には、明示長を渡せる `xmlReadMemory` を使用します。
`xmlNewDoc` のversionはSPARKで計測し、文書所有領域へ直接コピーします。
NULLは`1.0`、それ以外は空文字列や不正UTF-8もそのまま保持する既存仕様で、
XML 1.1の解析対応を意味しません。C側の中間Stringは作りません。
text/comment/CDATA/PI作成APIの本文もSPARKで計測し、所有領域へ直接コピーします。
文書付きでは本文を読む前に文書の登録を確認します。長さ指定は最初のNULまたは
指定byte数までで、NULL本文と空本文を区別します。PI targetも文書照合後にSPARKで
計測・直接コピーし、名前の妥当性は従来どおり出力時に検査します。
`xmlReadDoc`/`xmlParseDoc` はSPARKの上限付き走査で最初のNULまで測るため、
binary UTF-16 用ではありません。NULL入力は診断を保持してNULLを返し、空文字列は
空文書として解析エラーになります。長さ計測自体は確保・コピーを行いません。
DOM の名前と値は常に UTF-8 です。`UTF-8`/`UTF8`、`UTF-16`/`UTF16`、
`UTF-16LE`、`UTF-16BE` は ASCII case-insensitive で、generic UTF-16 は
little-endian です。明示encoding名はSPARKで最大9byte（終端込み）を直接読み、
対応する名前がなくなった時点で停止します。C側の走査・文字列変換はありません。
XML宣言のencoding分類とも対応表を共用します。明示 encoding は宣言より優先しますが宣言文法は検査され、
不明な encoding を暗黙 fallback しません。自動検出と宣言の不一致は成功時 warning
113 になります。変換前の malformed UTF-16 は IO/code 81 at 1:1、parser error
position は変換後 UTF-8 の character column で示されます。
UTF-16のnative入力はSPARKで直接計測・変換し、出力領域の確保と変換失敗時の解放も
SPARK内で行います。既存のString decoderとサロゲート判定・UTF-8生成を共用し、
空の変換結果も独立領域を確保します。入力は変換中に読み取り可能かつ安定している必要があり、
nativeメモリのbyte効果・allocator・ABIは引き続き信頼境界です。
その前後のBOM判定・先頭の切り出し・解放もSPARKで扱います。自動検出は最大4byte、
明示UTF-8は最大3byte、明示UTF-16は最大2byteを読み、2byte未満なら判定では読みません。
UTF-8は元入力の借用、UTF-16変換後は所有領域として区別し、借用入力は解放しません。

エラー API は `xmlGetLastError`、明示 reset/copy と OS thread ごとの所有状態を
提供し、成功後も直前のエラーを保持します。診断のmessage・URL/file・追加文字列の
計測と独立コピーは既存のSPARK byteコピーを使い、NULLと空文字列・任意byteを区別して保ちます。
各文字列の上限は共通の`XML3_Text.Max_Bytes`で、上限・確保失敗は従来のOOM経路へ写像します。
5文字列の一括複製と途中失敗時の解放はSPARKの`XML3_Error_Records`へまとめています。
threadごとのスロット遷移も同じunitの`Error_Slot`・`Clear_Slot`・`Install`・
`Install_Out_Of_Memory`が担い、通常recordの5文字列は解放し、静的messageを借用する
緊急recordはゼロ化のみとします。`Decide_Copy`と`Select_Last_Error`が
`xmlCopyError`と`xmlGetLastError`の判定順を表します。
数値・context/node値とNULLの保持、失敗時の空状態を契約で扱い、失敗後は残りの文字列を読みません。
公開レコードへの置換・TLS・緊急診断とnative所有権の前提は引き続き証明外です。

parseの再試行ループ自体もSPARKの`XML3_Parser.Attempts.Run`が駆動します。初期容量から
workspaceの確保・1回のattempt・解放を繰り返し、`Outcomes.After_Attempt`に従って終了・
node上限報告・容量拡大を選びます。loop不変式と各出口のassertionでworkspaceが空であること、
容量のloop variantでループの停止を証明しています。1回のattemptの停止性は
access-to-subprogram型に`Always_Terminates`を付けられないため信頼前提のままで、
address overlay・DOM lock・nativeのread呼び出し・例外からstatusへの写像は引き続き
adapterの`Build_Arena`が担い、全例外を捕捉するため証明済みループへ例外は漏れません。
code/domainからmessage種別を選ぶ方針はSPARKの`XML3_Diagnostic_Messages.Kind_For`にあります。
code固有の対応が優先し、次にdomain 8のUTF-8とdomain 3のnamespace、最後に汎用messageです。
code 4は入力があれば開始tag、なければ空文書のmessageになります。負のcodeはdomain側の
messageへ写像します。message本文と静的addressの表はtrustedなadapter側に残ります。
status から公開する (domain, code) の組を選ぶ方針はSPARKの`XML3_Diagnostic_Codes`
にあります。DOM操作のstatus、入力変換の結果、parseの報告種別、および
encoding・option拒否の定数を一か所で扱い、報告しない場合も明示します。
parse要求の受理順序はSPARKの`XML3_Parser.Requests`にあります。引数検査、encoding、
optionの順を段階ごとの関数で表し、引数が不正な場合にencoding名を読まないことを
明示します。
parse入口が公開するstatusの決定はSPARKの`XML3_Parser.Statuses`にあります。
読み取り結果・受理段階・入力変換の結果を`Public_Status`へ写像し、診断の公開後に
threadの最新errorがOOMならNo_Memoryへ置き換える判定（`After_Report`）、警告付きで成功した
parseがOOMを記録した場合に文書を破棄してNo_Memoryにする判定（`Settle_Parse`）、
例外時のstatus（`After_Exception`）、入力変換の失敗を入力の先頭位置付きで報告するか、メモリ不足として位置なしで報告するか（`Report_For_Preparation`）も同じunitで扱います。成功statusが置き換えで
変わらないこと、文書の破棄は成功parseに限ることを契約で示します。TLSのOOM判定の読み取り、
文書の解放、C ABIのstatus値への変換は引き続きadapterに残ります。
DOM操作の入口が返す`int`の決め方はSPARKの`XML3_DOM_Results`にあります。
- `Removal`: 属性の削除（`xmlUnsetProp`など）。削除できたときだけ0、それ以外は-1です。
- `Update`: 内容の更新（`xmlNodeSetContent`など）。成功は0、メモリ不足は-1、その他の失敗は1です。
- `Lookup`: 検索（`xmlNodeGetAttrValue`、`xmlGetNsListSafe`）。値があれば0、無ければ1、その他の失敗は-1です。
- `Space_Code`と`Truth`: `xmlNodeGetSpacePreserve`と`xmlNodeIsText`などの値です。
adapter自身が検出した失敗（引数検査と例外ハンドラ）は`Status_Of`で同等のstatusに直し、同じ関数で戻り値を決めます。
例外の捕捉、lock、native呼び出し、診断の公開は引き続きadapterに残ります。
使えない引数を診断として公開するかどうかも`XML3_DOM_Results`で決めます。各呼び出し箇所は操作の種類（`Operation_Class`）を名乗ります。
- 公開する: 編集・生成・検索、`xmlDocGetRootElement`、`xmlGetNodePath`、node listの文字列取得、`xmlEncodeEntitiesReentrant`
- 公開しない: nodeの判定、要素の移動、子要素数、`xmlNodeGetContent`、継承する`xml:lang`/`xml:space`、属性の検索、namespace一覧
C入口がlockを取る前に行う引数検査はSPARKの`XML3_Entry_Guards`にあります。
入口は共通の検査ごとにまとめ、`Rules`の表で、どのpointer引数が必須か、2つの引数が別物である必要があるか（`xmlReplaceNode`）、
拒否したときに引数不正の診断を公開するか、libxml2と同じく黙って返すかを決めます。
診断を公開するのは`xmlDocDumpMemory`系、`xmlNewChild`系、`xmlNodeSetLang`系、`xmlNewProp`系、`xmlSetProp`・`xmlUnsetProp`系、`xmlRemoveProp`です。
adapterはどのpointerがNULLかを調べ、拒否時の戻り値を返すだけです。
文字列系の入口の診断と`int`の戻り値はSPARKの`XML3_Text_Results`で決めます。
対応する長さを超えた文字列は未対応text、確保の失敗はメモリ不足として公開します。不正な文字列や存在しない文字列は通常の答えなので、
`xmlEncodeSpecialChars`を除いて何も公開しません。戻り値は`Validity`（`xmlCheckUTF8`）、`Measure`（`xmlUTF8Strlen`、`xmlStrlen`など）、
`Location`（`xmlUTF8Strloc`）、`Path_Code`（`xmlNormalizeURIPath`）、`Equality`（`xmlStrQEqual`、`xmlStrEqual`）で決めます。
adapter自身の失敗原因は`XML3_Diagnostic_Codes.Adapter_Failure`で名前を付け、
`For_Failure`が(domain, code)へ写像します。lock失敗・想定外例外は(2,1)、引数不正・
未対応text・namespaceの想定外例外は(2,115)、不正文字は(2,9)、確保失敗は(6,2)、
解析器の想定外例外は(1,1)で、組が同じ原因も別の値として残します。
診断の行・列計算もSPARKの`Location_At`を使い、解析器の開始行計算と共用します。
LFだけで改行し、列はUTF-8継続byte以外を数えます。CR・TABも1列として扱い、
UTF-8検証や表示幅計算は行いません。位置0は先頭、末尾を超える位置はEOFへ制限します。
互換方針は、last-error 保持など害のない
既知の挙動は可能な範囲で合わせる一方、memory corruption、不正 access、無制限な
resource use、悪用可能な upstream bug は再現しないことです。固定版との既知の差は
比較で明示し、namespace の fail-closed 動作と value near-limit 差も保持します。
