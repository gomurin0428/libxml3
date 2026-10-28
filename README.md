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
`xmlFreeNs`、`xmlCopyNamespace`、`xmlNewNsProp`、`xmlSetNsProp`、`xmlUnsetNsProp`、`xmlNewProp`、
`xmlSetProp`、`xmlUnsetProp`、`xmlRemoveProp`、`xmlFreeProp` をサポートします。
`xmlGetNsList` / `xmlGetNsListSafe` は node と祖先要素の明示 `nsDef` を近い順・宣言順に
列挙し、同じ prefix は最初の宣言だけを含めます。組み込み `xml` binding は追加せず、
`doc` 引数は無視します。返却配列は `xmlFree` で解放し、各 namespace pointer は借用です。
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
両APIは `Max_Input` 上限を適用し、`xmlCharStrndup` の `len` 超過は読み取り前に拒否します。
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
解放します。合計サイズ上限超過は拒否し、正の右側spanを読む前に上限を確認します。
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
`xmlGetLastChild` は要素に限定せず、document・element・属性値の末尾 child を取得します。
`xmlFreeNodeList` / `xmlFreePropList` は指定位置から末尾までの兄弟列と子ツリーを解放し、
残る親・直前の兄弟のリンクを安全に更新します。名前空間の参照保持もSPARK側で扱います。
`xmlNodeGetAttrValue` は名前空間付き属性の取得を、成功・属性なし・確保/上限/変換/内部エラーの戻り値で区別します。
名前空間検索は文書のない要素の `xml` 宣言も必要時にSPARK側で作成し、再利用します。
`xmlValidateName` / `xmlValidateNCName` / `xmlValidateQName` / `xmlValidateNMToken`
はUnicodeを含むXML名を、コロン・先頭文字・前後のXML空白の規則に従って検査します。
`xmlSplitQName2` / `xmlSplitQName3` は名前検証を行わず、NUL終端の raw byte 列を最初の
コロンだけで分割します。最初のコロンが先頭・末尾にある場合や、コロンなしでは NULL、後続のコロン・空白・不正な
UTF-8 はそのまま扱います。QName2 は prefix/local の独立コピーを返し `xmlFree` で解放し、
QName3 は入力内の local suffix を借用して prefix の byte length を返します。失敗時は QName2
の prefix 出力を NULL にし、QName3 の length 出力を変更しません。
`xmlBuildQName` も raw byte 列を扱います。NULL prefix は入力 name を借用して返しますが、
空 prefix は省略せず `:name` を構築します。十分な出力 buffer があればそこへ書き、足りなければ
指定した出力 buffer を変更せず `xmlFree` で解放する新規 allocation を返します。
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
