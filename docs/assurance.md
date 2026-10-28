# Assurance boundary

This project is an experimental, independent Ada/SPARK implementation, not a
release of GNOME libxml2. It is not yet a complete libxml2 replacement.

## Intended proof claims

`proof.gpr` includes complete specs/bodies of `XML3_Text`, `XML3_Text.Buffers`,
`XML3_Text.QNames`, `XML3_Parser`,
`XML3_Namespaces`, `XML3_Encoding`, `XML3_DOM`, `XML3_DOM_Bridge`,
`XML3_DOM_Constructors`, `XML3_DOM_Store`, its `Queries`, `Properties`, and
`Documents` and `Serialization` children, `XML3_Serialization`,
`XML3_DOM_Runtime`, `XML3_DOM.Import`, and
`XML3_DOM.Materialize`, plus
the trusted interfaces of `XML3_DOM_Allocation` and `XML3_Native_Memory`.
GNATprove must establish all generated flow and run-time checks and the written
contracts for those units.
The parser is iterative. Its statically bounded nesting stack holds at most
2,048 elements; the normal profile permits depth 256 and `XML_PARSE_HUGE` permits
2,048. There is no fixed whole-document byte cap or 2,048-node policy cap. Input
indices are bounded by `XML3_Text.Max_Bytes = Integer'Last - 16`, and node IDs by
half that representation bound. The parser/decoder core has no allocator, filesystem,
network, or callback access. The C adapter supplies bounded node/name arrays and
heap scratch buffers, grows the arena geometrically when the parser reports
`Arena_Exhausted`, and reparses; native allocation, pointer arithmetic, and
foreign-pointer validity remain trusted.

The recorded result is listed in [proof-report.md](proof-report.md). It covers
the parser/decoder, DOM, parser-arena materializer, and the Store/Runtime
operations used by public C APIs, including bounded content append, namespace
lookup through `Runtime.Search_Namespace` / `Store.Queries.Lookup_Namespace`,
namespace editing, `xmlTextMerge`, `xmlTextConcat`, `xmlNodeIsText`, and `xmlIsBlankNode`
through `Store.Queries.Test_Node`, inherited `xml:lang` / `xml:space` lookup
through `Store.Queries.Get_Inherited_XML_Property` and mutation through
`Store.Properties.Set_Qualified_Property`, reverse element navigation through
`Store.Queries.Select_Element` (including `xmlGetLastChild`), detached
`xmlNewDocProp` construction through
`Runtime.New_Doc_Node` / `Store.Content.New_Doc_Node`, managed attribute
attachment through `Store.Add_Child` / `Store.Properties.Add_Property`, and
managed sibling insertion through `Runtime.Add_Sibling` / `Store.Add_Sibling`,
managed list release through `Runtime.Release_List` / `Store.Release_List`,
namespace-list traversal through
`Runtime.Get_Namespace_List` / `Store.Queries.Get_Namespace_List` /
`Collect_Namespaces`, namespace copying through `Runtime.Copy_Namespace` /
`Store.Copy_Namespace`, QName splitting through `XML3_Text.QNames.Prefix_Length`
and `Split`, raw-string duplication through `XML3_Text.Buffers.Duplicate`,
bounded concatenation through `XML3_Text.Buffers.Fits` and `Concatenate`,
fresh-allocation appending through `XML3_Text.Buffers.Append`,
QName building through `XML3_Text.QNames.Build`, raw substring search through
`XML3_Text.Buffers.Find_Substring`, raw slicing through
`XML3_Text.Buffers.Slice`, terminated byte comparisons through
`XML3_Text.Buffers.Compare_Terminated`, and explicit UTF-8 memory serialization.
The buffer helpers check bounded lengths, allocation sizing,
and call preconditions; native allocation and byte writes are trusted. The C
adapters, conversions, pointer validity and native ABI implementation are not
proved. The refreshed aggregate has 11,451 checks
(1,069 flow and 10,382 prover), no unproved or justified conditions, 0
`pragma Assume` statements, and 137 analyzer warnings. The representation-generation
diagnostic is recorded separately.
The parser postcondition requires every output node's parent to precede it and
every name/value span to lie within the input, including well-defined empty spans.
UTF-8 text-decoder output never exceeds its input length. The UTF-16 decoder
measures its exact UTF-8 output length before allocation and checks bounded
conversion arithmetic and writes. Numeric reference arithmetic is checked
before multiplication. Termination of core `Parse`, text and UTF-16 decoding,
and namespace `Resolve` is proved with `Always_Terminates` and loop variants;
this does **not**
claim an end-to-end CPU-time or memory-use theorem.

The proof establishes SPARK run-time bounds, arithmetic safety, written
contracts, and termination for the selected core units. It does not prove
functional equivalence of UTF-8/UTF-16 behavior to libxml2, XML conformance, or
absence of vulnerabilities. Conversion-buffer allocation, pointer arithmetic,
and the FFI remain outside proof.

An accepted document contains one root element with balanced, matching tags.
That XML-language property is tested and reviewed, **not formally proved by the
present contracts**. UTF-8 and XML character correctness are likewise tested
functional properties; run-time safety is not a proof of XML conformance.
The namespace resolver's contracts bound local-name/prefix spans and binding IDs.
They do not formally establish that a binding is the correct in-scope namespace
or that all namespace well-formedness rules are satisfied.

Proof status and the exact invocation/toolchain must be recorded in the proof
report. Merely compiling SPARK code, passing tests, or having a proof target does
not constitute a completed proof. No `Assume`, suppressed run-time checks,
false-positive annotations, or excluded parser bodies may be used to make the
proof gate pass.

## SPARK-backed DOM and public C routing

`XML3_DOM` stores the actual logical node, namespace, and owner slots used by
its operations. Contracts cover bidirectional links, rank-based cycle prevention,
subtree document propagation, and owner reference counts equal to distinct live
node holds plus explicit reservations. Rejected attachments preserve graph data.
Unlinked nodes can pin a retired document's allocation; IDs are not reused before
release acknowledgement. Allocation failure handling and copying the backing
state are separated from the trusted state allocator. Atomic `Replace_Root`
preserves the old root's sibling position, propagates the incoming subtree's
document holds, and leaves the replaced root detached but live. Its fallible
checks run before topology changes; failure preserves the logical graph.
Public projection setters reject document changes inconsistent with the target's
parent or direct children/properties. The private pin-only setter is used during
the core's controlled subtree propagation, not exposed to callers.
`Merge_Text` validates a prepared content buffer's metadata and reserved owner,
rebinds the target's content hold, and retires the source atomically in the logical
graph. Failure leaves the graph unchanged. Actual concatenated bytes and their
allocation bounds are not modeled by this operation; the caller must prepare the
buffer and retain its reservation through the commit.
The source may be detached or attached under another parent in the same
document; this intentional move/append behavior does not require same-parent
adjacency.

`XML3_DOM_Bridge.Synchronize` consumes the core's projection/release protocol.
Its proved control flow projects nodes and namespaces before issuing a release,
then calls native free before acknowledging that release. This establishes the
protocol per owner ID, not an unconditional theorem about arbitrary C addresses.
The native integration test additionally checks real C fields, retained document
storage, preserved `_private`, and exactly-once frees for its tracked allocations.

`XML3_DOM_Constructors.Create_Node` performs checked sizing, allocation,
registration, implicit XML namespace setup, and synchronization. Before
registration, a failed native block may be freed directly; after registration,
rollback uses subtree retirement, reservation release, and the effect protocol.
The contract preserves all pre-existing live nodes on success and failure,
including when backing-state capacity grows. Raw string writes, offset addresses,
allocation freshness/non-overlap, and correspondence to native layout remain
trusted external-memory operations. Integration tests exercise successful
document/element/text construction, invalid namespace/kind rejection, native
malloc failure, and retained namespace/document storage after detachment.

`XML3_DOM_Store` owns a private limited backing state and composes those
operations with facade lookup and synchronization. Lookup checks the metadata
ID range, live state and exact facade equality; the native metadata read itself
still assumes a valid library pointer. The store reclaims its backing state only
after no logical owners remain. `Add_Child` attaches ordinary children or merges
adjacent text using a prepared NUL-terminated buffer whose owner reservation is
released before synchronization; a rejected merge buffer therefore follows the
existing release protocol. Tests cover allocation failure with unchanged views,
real facade/content updates, source-clear-before-free ordering, repeated-tail
no-op, and final Store reclamation. `XML3_DOM_Runtime` owns the one private
Store as SPARK abstract state. Public DOM wrappers serialize complete Runtime
calls with the trusted `XML3_DOM_Lock` guard; the C layer does not maintain a
parallel DOM graph. `xmlNewComment`, `xmlNewPI`, `xmlNewDocComment`,
`xmlNewDocPI`, `xmlNewDocText`, `xmlNewDocTextLen`, and `xmlNewCDataBlock`
share `Runtime.New_Doc_Content` and `Store.Content.New_Doc_Content`. The
private C `New_Content_Node` helper handles input conversion, locking, status
reporting, and exception mapping for these content constructors without adding
a C ownership path.

`xmlNewDocProp` adapter uses `Runtime.New_Doc_Node` and
`Store.Content.New_Doc_Node` with `Attribute_Mode`; it supports only detached,
unnamespaced attributes. A managed attribute can subsequently be attached to an
element by `xmlAddChild` under the same-document/documentless restriction.
Standalone attribute serialization is not supported. Its complete public C
semantics are not proved.
The `xmlNewDocProp` path uses the shared C `New_Container_Node` helper for
marshalling, locking, and status mapping; graph and owner decisions stay in SPARK.
The shared `Store.Content.New_Doc_Content` operation accepts text, CDATA,
comment, and PI nodes as well as empty element/attribute containers; it maintains
`Ready (S)`, relates the result address to `Created` status, and uses the
existing `Set_Node_Projection` invariant to set document affiliation and owner
pin. The core `Create_Node` postcondition specifically guarantees a null name
and zero name length for CDATA nodes. These contracts do not prove complete
public API semantics or rollback. Raw comment/PI/CDATA content is copied at
construction; lexical and UTF-8 validity and CDATA delimiter splitting are
checked by serialization rather than claimed by the constructor contract.
The CDATA bounded scan is in the trusted C boundary; guard-page tests are
runtime evidence for pointer handling, not a pointer-safety proof.

`XML3_Serialization.Render` reads an immutable Store state, validates and
measures the supported XML 1.0 UTF-8 subset, then repeats the same iterative
traversal into an exact-size caller-owned buffer. Store and Runtime only route
the document facade and encoding; the C adapter initializes output slots,
converts the C string, holds the existing lock, and publishes the result.
Unsupported encodings, XML versions, malformed text, names, and namespace
states are rejected rather than repaired. Native allocation and byte access
remain trusted, and full libxml2 serializer equivalence is not claimed. These
new units are included in the current successful 11,451-check aggregate proof; see
[proof-report.md](proof-report.md) for the exact result and source hashes.
Source encoding and standalone metadata are not retained by the DOM and are
omitted from the declaration; an empty document may produce only the
declaration.

`Adopt_Arena` initializes an empty Store or performs overflow-checked growth for
nodes, namespaces and one owner before calling `Import.Adopt` exactly once.
Success synchronizes the destination and returns the imported document facade.
Failure preserves the complete source state and caller ownership; newly
initialized empty backing state is reclaimed with `Reclaim_Empty`. The native
source arena is never directly freed by adoption. Tests cover empty-Store,
map-allocation and growth-allocation failures, successful import and C facade
traversal, preservation of an existing document across a second import, and
detached-root lifetime through final Store cleanup.

`XML3_DOM_Store.Queries` adds internal, read-only element selection, property
lookup, namespace search, and content retrieval. Traversal uses Store node and
namespace IDs through `Node_View` and `Namespace_View`; it does not follow
native DOM links. Namespace scope is limited to element nodes, including when
queries originate from attribute values, and resolution errors remain
distinguishable from a normal no-match. `Get_Content` walks descendants in tree
order and returns a fresh NUL-terminated allocation owned by the caller, not the
Store. Regression tests cover mixed-document selection/property/namespace
results, default-namespace shadowing, a detached namespaced attribute value,
content ordering after a text move, and allocation failure followed by retry.
The Store unlink operation supports detaching attributes and is exposed through
`xmlUnlinkNode`. It updates property links while retaining document affiliation,
namespace references, content children and owner pins. Runtime delegates directly
to Store validation, with no native topology traversal in the C adapter. Public
tests cover middle/head/tail/sole-property unlink, repeat unlink, editing and
reattachment, namespace/document-first release, and no native allocation. Native byte comparison,
copying, allocation/free and address correspondence remain trusted boundary
operations. Public C getters route through these queries.

`Get_Namespace_List` performs a bounded two-pass traversal of managed node and
namespace IDs. The first pass counts visible declarations; the second writes
their borrowed facades into an exactly sized, caller-owned, NULL-terminated
array. List traversal uses declaration-only prefix resolution, so it does not
fall back to a node's namespace reference or synthesize the implicit `xml`
binding. It includes NULL/empty href declarations, deduplicates prefixes in
nearest-first order, and ignores the document argument. Store selection,
capacity checks, status and cleanup decisions are SPARK code; native address
allocation, array writes, pointer validity and the C ABI remain trusted. The
namespace pointers are borrowed and remain valid only while their owning node
is alive. Fixed-reference tests cover order, shadowing, NULL/empty hrefs,
element/text/attribute ancestry, and detach/reattach. Allocation failure and
document-first release are tested separately against libxml3.
Complete `xmlGetNsList` / `xmlGetNsListSafe` semantic equivalence is not proved.

`xmlAddSibling` resolves its reference node and incoming node through Store IDs,
rejects self-insertion and mixed attribute/content lists, then delegates to
`Store.Add_Child` using the reference node's managed parent. Text coalescing,
property replacement, document affiliation, and failure preservation reuse the
existing paths. Runtime is a passthrough; the C adapter shares only locking,
status and exception mapping with `xmlAddChild`, and reads no native DOM links.
Parentless sibling chains and children of attributes remain unsupported. Tests
cover append/reorder/merge and serialize/reparse, namespaced attribute replacement,
invalid and cross-document cases, document-first lifetime, and OOM retry.

`XML3_DOM_Store.Properties` adds internal namespace-free property creation and
replacement. Creation appends attributes, including duplicates; replacement
updates the first matching no-namespace attribute or creates one when absent.
Values are copied literally, with null values distinct from present empty
values. The implementation uses Store allocation, attachment, retirement and
synchronization operations; it does not traverse or mutate native DOM links.
Connected native tests cover literal bytes, duplicate attributes, allocation
rollback, null-versus-empty value children, and clearing the old value links
before its exactly-once native free. Public property APIs route through these
operations; C ABI conversion and facade projection remain trusted boundaries.

`xmlNodeAddContent` の分岐、末尾Textの選択、owner reservation、content projection、
attach/cleanup は SPARK Store/Runtime が管理します。C adapter は guarded Runtime 呼出し、
NUL終端 string の変換、戻り値変換に限定されます。既存の末尾 Text facade を保った
scalar replacement は新 buffer を登録・投影してから旧 buffer を同期解放します。
element/attribute に text child がない場合は SPARK が text node を作成して core の
`Attach_Child` に渡します。XML 構文の妥当性検査と escaping は serialization が担当します。
入力中の文字参照は解釈・展開せず、raw の `&` は出力時に escaping します。

`xmlNodeSetContent` も node-kind 分岐、XML reference decoder、subtree retirement、
owner/pin lifetime は SPARK Store/Runtime に置きます。predefined/numeric references は
element/attribute setter 入力でのみ decode し、literal whitespace は保持します。
malformed/unknown references と不正 UTF-8/XML scalar は element/attribute setter で mutation
前に拒否します。scalar Text/CDATA/comment/PI の入力は raw のまま保持し、その検証は
serialization 時に行われます。raw input reference は serializer で展開されず、XML syntax
validation/escaping は serialization 時に行われます。new child は完全に準備して attach
した後に旧 children を namespace-aware に retire し、失敗では旧 tree を保ちます。
DTD/entity node types と namespace repair は未対応です。

`xmlNewChild` は同じ Content/Runtime 層で namespace 継承、reference decoding、
新しい element/text の構築、接続と失敗時の後始末を行います。入力用 scratch は native
node を作る前に確保し、旧 parent への接続は準備完了後の最後に行います。C adapter は
文字列変換、NULL name の検査、mutex、結果・例外変換のみを担当します。Store 層の契約は
`Ready` と結果/status の整合性を保証し、API 全体の libxml2 等価性や rollback の完全な
意味論まで形式証明したという主張ではありません。

`xmlNewTextChild` は同じ Store operation の raw-content mode を使います。C adapter は
API に対応する mode と content が NULL かどうかを渡すだけで、raw copy と empty text の
作成判断は SPARK 側です。reference decoding はせず、XML/UTF-8 検査と escaping は出力時に
行います。NULL/empty の違い、literal reference の往復、出力拒否後の内容修復を検査します。

`xmlNodeSetContentLen` は C 境界で指定 byte 数内の文字列だけをコピーし、既存の
`Runtime.Set_Content` に渡します。長さ 0 なら pointer を読まず、負の長さなら通常の
NUL-terminated 変換です。この pointer 走査は形式証明外で、正の長さを指定した
非終端バッファと長さ 0 の入力を guard page で検査します。置換・所有権・解放判断は
既存の SPARK 実装のままです。新しい ABI entry の追加が証明範囲を広げる主張ではありません。

`xmlNodeAddContentLen` も同じ bounded string 変換を使います。C 境界は正の長さの non-NULL
入力かを渡し、Store が空の入力を無操作として扱うか、空の text として扱うかを決めます。
接続・文字列結合・失敗時の保持は既存の Append operation を再利用し、`Ready` 契約は
維持しています。guard page、空の text の確保失敗と再試行、UTF-8 の分割追記から出力への
回復は実行テストの根拠であり、C pointer の読み取り安全性の形式証明ではありません。

`xmlNewTextLen` は bounded C string 変換から既存の Runtime/Store constructor を呼びます。
長さ指定は C 境界だけの変更で、新しい所有権処理や証明範囲は追加しません。非終端入力・
長さ 0 の guard page、NULL/空文字列の違い、接続と出力、確保失敗後の再試行を実行検査します。

`xmlNewDocText` / `xmlNewDocTextLen` の document 検査・所属設定・失敗時の未公開 text の解放は
Store.Content が行います。Store operation の契約は `Ready (S)` の維持と `Created` status /
非 NULL `Result` の対応を保証します。`Set_Node_Projection` の既存契約を使って document と
Doc_Pin を設定し、owner reference invariant を維持します。これは API 全体の意味論や完全な
rollback の証明ではありません。C 境界では文字列変換と Runtime 呼び出しだけを行い、bounded
pointer scan は証明外です。document なし・NULL/長さの振る舞い、無接続 text、文書検査、
serialization、文書先行解放後の編集・最後の text 解放、確保失敗時の既存 tree の保持は公開
API の実行テストで検査します。

`xmlNodeIsText` / `xmlIsBlankNode` は `Runtime.Test_Node` / `Store.Queries.Test_Node`
で kind と XML 空白を判定します。Runtime の `Global` は managed state / native memory
とも `Input` で、Store も読み取り専用です。管理中の content 長を走査上限とし、
失敗時は False を返す契約です。C は mutex・結果・例外の変換だけを担当します。
ネイティブ byte 読み取りの正しさは信頼境界に残り、完全な C API 意味論の証明ではありません。

`xmlNodeGetLang` / `xmlNodeGetSpacePreserve` use the read-only
`Store.Queries.Get_Inherited_XML_Property` parent walk. Language returns a
caller-owned copy; space frees each temporary content copy and matches only
the exact `default` / `preserve` values. Kind checks, namespace filtering and
ancestor fallback are in SPARK. Setters route through the existing
`Store.Properties.Set_Qualified_Property` path for QName resolution and
rollback. The C adapter handles string conversion, locking, and status mapping.
Lookup/setter semantics, reparenting, serialization, copied-value lifetime,
and OOM rollback have runtime coverage; this does not prove the complete C
ABI, native pointer validity, or all public semantics.

`xmlTextConcat` の scalar kind 制限は `Store.Content.Append` で行い、空入力の
no-op 判定より先に検査します。内容の準備・pin 更新・確保失敗時の保持は既存の
`Replace_Content` 契約を再利用します。C は既存の文字列変換・mutex・戻り値変換を共用し、
node をたどりません。新しい入口の全意味論を証明したという主張ではなく、kind・長さ・
NULL/空・alias・guard page・文書先行解放・出力・確保失敗後の再試行を C テストで検査します。

`xmlTextMerge` は `Runtime.Merge_Text` / `Store.Merge_Text` を通り、`Add_Child` の
text 結合と共通です。C は引数の受け渡し・mutex・エラー変換のみで、kind・文書所属・
容量・結合・解放判断は Store にあります。新しい content を準備してから既存の
`XML3_DOM.Merge_Text` で pin 更新と source の退役を行い、Bridge が公開構造体を同期します。
第二引数の content が NULL の場合は通常の `Release` を使い、target content は変えません。
Store の事後条件は `Ready`、成功時の返却 pointer と失敗時の NULL を規定します。完全な公開APIの
原子性・文字列意味論・C pointer validity を証明したという主張ではなく、確保失敗時の
内容・リンク保持、NULL/空の違い、属性内 text、文書先行解放は実行テストで検査します。

`xmlLastElementChild` / `xmlPreviousElementSibling` の kind 検査・後方リンク走査は
`Store.Queries.Select_Element` が実行します。既存の root/first/next 選択と C adapter を
共通化し、C は Runtime 呼び出し・mutex・status/exception 変換のみです。
走査は node 数で有界で、native field を C でたどりません。非 element のスキップ、
編集後の順序、無接続 tree の文書先行解放後の走査は実行テストで検査します。
「最も近い element を返す」完全な選択意味論までを契約で証明したという主張ではありません。

`xmlGetLastChild` は同じ Store/Runtime 選択処理の `Last_Child_Node` mode を使い、
kind で絞り込まず管理中の末尾 child facade を返します。文書と属性の値も対象です。
C adapter は共通の入口を呼ぶだけで、native `last` field は読みません。切り離し・再接続・
内容置換後の結果、文書先行解放後の利用、native allocation 不要を実行テストで検査します。
戻り値の完全な公開意味論や native pointer validity を証明したという主張ではありません。

`xmlFreeNodeList` / `xmlFreePropList` は `Runtime.Release_List` / `Store.Release_List`
を通り、管理中の `Next` を保存して既存の `Free_Subtree_With_Namespaces` を反復します。
反復は node 数で有界で、各段階の `Valid`・`Can_Edit`・`Facades_Present` を維持します。
最後に一度 `Synchronize` / `Reclaim_Empty` を実行します。C は単体解放と共通の
mutex・Runtime 呼び出し・status/exception 変換のみで、native の `next` は読みません。
接続済み suffix の安全な切り離し、再編集・出力・再読み込み、文書先行解放、名前空間の
残存利用者、native allocation 不要を実行テストで検査します。完全な一覧解放の意味論・
全原子性・native pointer validity を証明したという主張ではありません。

XML名の4つの公開validatorは、SPARKの `Text.Valid_Name` でXML空白・コロン・先頭文字を
処理し、既存の `Name_Width` でUTF-8と名前文字を検査します。Globalはnullで、DOMや
所有権を変更しません。走査の範囲・停止性は証明対象です。XML名の完全な意味論は契約に
記述しておらず、固定版比較でUnicode境界・不正UTF-8・空白・QNameの形を検査します。
C pointerの妥当性・変換とstatus写像は従来どおり証明外です。

`xmlSplitQName2` / `xmlSplitQName3` は validation や namespace 解決ではなく、SPARK
`XML3_Text.QNames.Prefix_Length` が NUL 終端 byte 列の最初の colon と prefix byte length
を求める raw split です。QName2 の `Split` は prefix/local の independent copy、終端 byte、
部分確保失敗時の cleanup を管理し、QName3 は input 内の borrowed local suffix と成功時だけ
更新する length slot を返します。後続 colon、空白、不正 UTF-8 は検査せず raw bytes のままです。
DOM/Store は変更せず、C conversion limit/error mapping、native allocator/copy、pointer arithmetic
と ABI は trusted boundary です。Unicode 比較は pinned reference と libxml3 の両方で行い、
OOM allocation injection は libxml3 のみで実行します。

`xmlBuildQName` は SPARK `XML3_Text.QNames.Build` で size bound、buffer selection、
result/status 契約を扱います。NULL prefix は borrowed original pointer、empty prefix は colon
を含む新しい値です。C string conversion と pointer/ABI、native allocation/write は trusted
boundary です。overlapping input/output は libxml3 で入力を先にコピーして安全に扱いますが、
固定版との overlap equivalence は主張しません。
`xmlStrQEqual` は SPARK `XML3_Text.QNames.Compare` で prefix/name/value の raw-byte
比較を行います。NULL prefix は `xmlStrEqual` 相当の NULL/NULL・同一 pointer equality を
保ち、非NULL prefix は prefix、colon、name を NUL まで比較します。空 prefix は name/value
を読まず常に Different です。これは pinned reference の空-prefix do/while が空 value の
terminator 後を読む unsafe path を意図的に除外した安全性差分であり、NUL-then-`:name` tail
の解釈も再現しません。guard-page と tail のケースは libxml3-only です。SPARK は status
初期化、null/pointer identity 契約、scalar loop の範囲を検査します。早い mismatch/identity
は返り、`Max_Bytes` scan cap を越える追加読取りが必要な equality は
`Comparison_Limit_Exceeded` として C 側で diagnostic plus 0 に写像されます。
scan cap は長い入力の一律拒否ではありません。Native
byte reads、foreign pointer validity/bounds、actual contents、address arithmetic、C mapping、
full public equivalence remain trusted. XML-name/UTF-8 validation is not performed.
The comparison itself allocates nothing and performs no writes.

`xmlNodeGetAttrValue` は既存 `Runtime.Get_Property` / `Store.Queries.Find_Property` /
`Get_Content` を再利用します。C の共通入口は文字列変換・mutex・status 変換のみで、
従来の `xmlGetProp` / `xmlGetNsProp` / `xmlGetNoNsProp` も同じ入口を通ります。
属性検索・内容のコピーはSPARK側のままで、新たな所有権モデルは追加していません。
戻り値と出力 pointer の C ABI 契約そのものは証明外で、固定版比較と確保失敗テストで検査します。

公開 namespace 検索は `Store.Queries.Lookup_Namespace` を通ります。まず純粋な
`Search_Namespace` で検索し、必要な場合だけ最も近い文書なし element へ
`Store.Create_Namespace` で組み込み `xml` 宣言を追加します。C 境界には変更を加えません。
属性更新内部では純粋な検索を維持し、更新失敗時の宣言の巻き戻し処理は変えていません。
固定版比較・作成失敗後の再試行・既存宣言の保持・再検索の確保不要を実行検査します。

`xmlNewDocNode` / `xmlNewDocRawNode` は `Runtime.New_Doc_Node` と
`Store.Content.New_Doc_Node` を通り、既存 `New_Child` も同じ未接続要素の作成処理を使います。
文書・namespace の保持は `New_Doc_Content`、text 子の接続は既存の `Attach`、
途中失敗での非公開ノードの解放は既存の `Release` が担当します。C 側は API 種別の
選択・文字列変換・mutex・status/exception 変換だけを行い、`xmlNewNode` も共通経路です。
新しい Store operation の契約は `Ready` の保持と result/status の対応です。
全公開API意味論や C pointer の有効性を証明したという主張ではありません。

`xmlNewDocProp` は同じ `Runtime.New_Doc_Node` / `Store.Content.New_Doc_Node` を
`Attribute_Mode` で使い、未接続・無namespaceの属性を作ります。文書所属と owner pin、
値の参照展開、text child の作成、失敗時の解放は SPARK 側にあります。NULL doc と
管理中の live document を受け入れ、文書先行解放後も属性は `xmlFreeProp` まで保持します。
NULL/空値は text child なしです。`xmlAddChild` では、文書未所属の属性、または接続先と
同じ文書に所属する属性を要素へ接続できます。既存属性とは local name と namespace href の expanded name で照合し、
接続成功後に一致属性を解放します。既に最後の属性なら重複があっても no-op です。
`xmlUnlinkNode` で属性を切り離した後も文書・namespace を保持し、編集・再接続・解放ができます。
namespace reconciliation と detached attribute の単独シリアライズは未対応です。
API 全体の意味論や C pointer validity を証明した主張ではありません。

`xmlNewCDataBlock` も共通の C `New_Content_Node` と SPARK
`New_Doc_Content` を使います。C wrapper は non-NULL content の負の長さを走査前に拒否し、
bounded prefix を作ります。NULL content は長さを問わず受け入れ、長さ 0 は pointer を読みません。
core `Create_Node` の postcondition は CDATA の `Name` が NULL、`Name_Length` が 0 であることを
保証します。これは限定された構造保証であり、API 全体の意味論証明ではありません。内容コピー、
CDATA delimiter の出力分割、serialize/reparse、無効 UTF-8 の拒否と修復、document 先行解放後の
編集・解放は実行テストで検査し、C pointer の validity は証明外です。

Namespace editing extends the same Store/Runtime path. Constructed declarations
own one explicit reservation; node namespace pins are accounted separately.
Cross-owner attachment requires that retained reservation, and core invariants
require a live owner with a positive reservation and at most one retaining
namespace per owner. Namespace-aware lookup uses URI plus local name. QName
parsing and UTF-8 NCName validation for `xmlSetProp` occur in SPARK, and
documentless XML namespace creation is rolled back if the attribute operation
fails. Namespace-aware subtree release detaches declaration links before
retiring element nodes and releases constructed declaration reservations while
preserving namespace owners still borrowed by live nodes. The C adapter remains
limited to guarded ABI/string/status conversion and does not decide ownership
or release. Namespace-edit core/bridge and public C regressions cover retention,
cross-owner borrowing, rollback, attribute identity, and allocation failure.

The ghost `Count_Holders` helper retains the recursive holder-count definition
with a bounded-result postcondition and decreasing variant. `Holder_Count`
delegates to it while stating the same recurrence through the helper, avoiding
a recursively evaluated wrapper postcondition. `Valid` and `Pin_Equation` are
unchanged.

`XML3_DOM.Import.Adopt` consumes a single-owner source state after installing its
arena into a destination with capacity already reserved. Sorted maps reuse
unused slots and translate links/pins while preserving existing live entries.
The native arena is not copied or freed; only the source Ada state and temporary
integer maps are deallocated. Failed preflight or map allocation preserves both
graphs. Direct `Import.Adopt` requires worst-case append capacity without credit
for reusable holes; `Store.Adopt_Arena` performs checked initialization/growth
around that requirement. Synchronizing the destination updates native metadata
before the imported facades are exposed.
The bridge clears namespace pointer fields when the core's
`Namespace_Release_Required` reports a releasing owner, in addition to clearing
retired nodes. Native tests cover capacity/allocation rollback, slot reuse,
remapped IDs, detached lifetime and clearing before exactly-once release.

`XML3_DOM.Materialize.Build` converts successful internal `Parse` and `Resolve`
output into a fresh candidate arena. It assigns IDs and constructs
ownership/topology in SPARK, uses checked string budgeting, and validates the
candidate with executable shared graph predicates. The proved `Check_Arena`
postcondition establishes `Valid`, editability, facade presence, arena
ownership, and projection requirement; parser/resolver range facts alone are
not treated as proof of arbitrary graph structure. A successful source is then
adopted once and synchronized through the destination bridge. The integration
test exercises this full internal sequence on the mixed parser sample, checks
12 nodes and 4 namespaces through C facade traversal, validates destination
preservation and remapped metadata, injects failure at all three allocation
stages, and checks invalid-binding rejection with exactly-once cleanup. It also
checks detached lifetime and final arena release.

The materializer performs direct non-ghost construction and O(1) tail appends,
so its assembly work is linear in emitted nodes and namespaces. Assertion-enabled
ghost checks may be superlinear; no performance benchmark is claimed. Native
allocation/free, offsets, facade initialization, and byte/string writes remain
trusted primitives. The native layout/address correspondence is tested but not
proved. Ownership, graph topology, validation, release decisions, and policy
remain in SPARK.

`XML3_C` is an ABI adapter over `XML3_DOM_Runtime`. Parsing calls
`Documents.Read` with bounded C-allocated workspaces; constructors, queries,
mutation and release call typed Runtime operations. The adapter still performs
foreign pointer/string conversion and error translation and is not itself
formally proved. The Runtime delegates to proved Store operations; the public
API as a whole is not thereby claimed to be formally verified.

The adapter depends on `GNAT.Threads` to load GNAT's tasking runtime even
though the library creates no Ada tasks. On the supported Linux runtime,
foreign pthreads are registered automatically, giving each thread its own
secondary stack and exception state. A DOM mutex alone does not protect Ada
string conversions outside the locked Store operation. Foreign-thread
registration and runtime thread-local storage are trusted runtime services.

Native bodies remain trusted for pointer conversion, layout, allocation/free,
byte operations, metadata IDs and field writes. The caller of the foundation must
register addresses backed by the right live allocation, with unique owners and
non-overlapping facades, and ensure strings/ranges remain readable/writable.
These allocation/projection correspondence and address-uniqueness assumptions
are not established by the ID/reference-count equations. Native effect specs do
not model every C field or byte, so the bridge proof does not prove the native
body implements its projection command correctly. The C integration tests
exercise this correspondence without proving it for every layout or execution.

## Build profiles and executable contracts

The production library (`make build`, `lib/libxml3.so`) does not enable
`-gnata`: proof assertions, pre/postconditions, loop invariants, and ghost
computations are not dynamically evaluated. Explicit input/status checks and
Ada range checks remain enabled, with `-gnato` for integer overflow checks;
`-gnatp` is not used. Production uses `-O2`.

The development library (`make build-development`,
`lib/development/libxml3.so`) retains `-gnata` and `-gnato`. Its objects and
library are separate from production, so switching profiles cannot reuse
objects compiled under a different assertion policy. `make test-development`
runs focused public API regressions against this library. Global ghost
invariants can be extremely expensive; this profile is not a performance build.

`proof.gpr` and the Ada core/bridge test projects remain assertion-enabled and
independent of the library profile. No proof condition is removed or justified
by the production profile. A production test pass does not replace GNATprove
or development-profile testing, and neither profile proves the trusted boundary.

## Trusted / unproved boundary

* The Ada C-ABI adapter, C-compatible DOM object layout, allocations,
  deallocations, and foreign pointer/string conversions are outside SPARK.
  DOM topology, logical ownership, rollback and release decisions for exported
  wrappers are performed by proved Store/Runtime operations, not by the adapter.
  Callers must use these APIs rather than directly changing public tree links,
  and must not use a document handle after `xmlFreeDoc`.
* The pthread mutex and controlled Guard are trusted synchronization adapters;
  mutex correctness is not formally proved. Runtime calls are serialized, but
  asynchronous pthread cancellation and allocator callbacks that reenter the
  Runtime are unsupported. The libc allocator may itself use OS locks; no
  wait-free or deadline guarantee is made. Callers must synchronize concurrent
  access or release of borrowed facade pointers.
* `XML3_Native_Memory` and `XML3_DOM_Allocation` specs are analyzed, but their
  bodies are explicitly outside SPARK. The former performs no DOM traversal,
  ownership decision, or release scheduling; the latter only allocates/frees
  the Ada backing state and integer import maps. Their body correctness and foreign-memory assumptions
  are trusted, not discharged by the recorded proof result.
* `XML3_Errors` is also outside SPARK. Ada owns and copies error records and
  strings; the C shim provides only pthread TLS key access and thread-exit
  destructor dispatch. Allocator-failure tests exercise this boundary but do
  not prove it free of memory errors or exceptions.
* The C caller must supply readable input buffers of the declared length, valid
  NUL-terminated strings where required, and live handles created by this library.
  Use-after-free, forged pointers, double frees, and caller mutation of exposed
  structures are **not** made safe by the core proof.
* Compiler, Ada runtime, libc allocator, operating system, GNATprove/Why3 and SMT
  solvers are trusted. SPARK does not establish absence of `Storage_Error`.
* Side channels, application-level authorization, all possible denial-of-service
  attacks, thread races involving shared DOMs, and arbitrary environmental faults
  are not proved absent.

The defensive XML profile rejects DTDs and all declared/external entities. There
is no external resource resolver. This removes the external-entity and recursive
entity-expansion paths by design; it is not proof of security of an application
that subsequently interprets parsed text as a path, URL, command, or markup.

## Compatibility policy

The user-selected target is **C source/API compatibility with recompilation**,
not binary ABI compatibility or a replacement `libxml2.so.2`. The library uses its
own name, `libxml3`, and must not be loaded alongside libxml2 into the same symbol
namespace. Only APIs and structure fields explicitly listed in the compatibility
document are supported. The minimal DOM editor API includes `xmlNewDoc`,
`xmlNewNode`, `xmlNewText`, `xmlNewTextLen`, `xmlDocSetRootElement`,
`xmlAddChild`,
`xmlUnlinkNode`, `xmlFreeNode`, namespace APIs `xmlNewNs`, `xmlSetNs`,
`xmlFreeNs`, `xmlCopyNamespace`, `xmlNewNsProp`, `xmlSetNsProp`, `xmlUnsetNsProp`, and attribute
APIs `xmlNewProp`, `xmlSetProp`, `xmlUnsetProp`, `xmlRemoveProp`, and
`xmlFreeProp`. Attribute copying and cross-document moves remain deferred.
`xmlStrdup` and `xmlStrndup` copy raw bytes into `xmlFree`-owned,
NUL-terminated results; `xmlStrndup` copies exactly the requested length,
including embedded NUL bytes, and length zero does not read its input.
`xmlCharStrdup` delegates to the existing `xmlStrdup` adapter. `xmlCharStrndup`
uses the C `char *` prefix conversion and the existing SPARK duplication helper:
it stops at NUL within `len`, while raw `xmlStrndup` copies the exact span.
Length zero performs no input read; NULL/negative and over-`Max_Input` inputs
are rejected. Input bytes, including high-bit bytes, are copied without
transcoding or UTF-8 validation. The pinned reference allocates `len + 1`
even after an early NUL and leaves the tail unspecified; libxml3 allocates
only the copied prefix plus terminator. Tests compare defined contents only;
spare capacity and allocation-size equivalence are not promised. C conversion,
native pointer validity, allocation/writes, ABI, and complete semantics remain
trusted.
`xmlStrchr` calls the SPARK `XML3_Text.Buffers.Find_Byte` search. It returns a
borrowed input pointer to the first matching non-NUL byte; NULL input and a
zero search value return no match without reading, and NUL terminates the scan
but is not itself searchable. The scan checks payload offsets below
`Max_Bytes` and allows a NUL at the boundary offset; if there is no match or
terminator by that boundary, the adapter records an error and returns NULL.
An early match in a longer string succeeds, so this is a no-match scan cap,
not rejection of every longer input. SPARK proves the bounded status/position
contract. `Native.Byte_At`, foreign pointer validity, readable bounds, actual
bytes, native address arithmetic, C diagnostic mapping, and complete public
semantics remain trusted. The operation allocates nothing and does not modify
or transcode the input.
`xmlStrstr` and `xmlStrcasestr` use `XML3_Text.Buffers.Find_Substring` and
return the first matching borrowed haystack pointer. NULL arguments return no
match; a non-NULL haystack with an empty needle returns position zero without
reading the haystack. NUL terminates both raw-byte inputs, so overlapping
haystack/pattern pointers, UTF-8 fragments, and invalid bytes are not converted
or validated. The case-insensitive operation uses the pinned byte map,
including the `[` to `{` quirk, not Unicode case folding. The scan permits
payload offsets below `Max_Bytes` and a boundary NUL; a match ending at that
boundary succeeds, while required non-NUL data beyond the cap maps to
`Search_Limit_Exceeded` and then diagnostic plus NULL. Early matches and empty
needles return without scanning the whole source, so the cap is not blanket
rejection of long strings. SPARK proves the status/position postcondition and
loop bounds. The borrowed pointer lifetime, native reads, foreign pointer
validity/bounds, actual bytes, address arithmetic, C mapping, and full public
semantics remain trusted. The operation allocates nothing and performs no
writes.
Shared substring vectors and guard-page cases run against both the pinned
reference and libxml3; OOM/no-allocation checks are libxml3-only.
`xmlStrsub` uses `XML3_Text.Buffers.Slice` to validate the start and copy an
exact raw-byte span into an independent `xmlFree`-owned allocation. NULL input
or negative indices return NULL without a diagnostic. The scan rejects a NUL at any position from
zero through `start`, including for zero-length slices; a valid zero-length
slice still allocates an empty string. It does not clamp the requested length
at a later NUL, so callers must provide a readable span of `len` bytes.
`start < Max_Bytes` and `len <= Max_Bytes - start` are checked before reading;
limit violations map to diagnostic plus NULL. SPARK proves the scalar
status/result contract, checked bounds and native-call preconditions. Pointer
validity, readable bounds and actual bytes, fresh allocation and writes,
address arithmetic, C mapping, and complete public semantics remain trusted.
No XML-name or UTF-8 validation or transcoding occurs. Shared slice vectors
and guard-page cases run against both the pinned reference and libxml3;
upper-cap and OOM checks are libxml3-only.
`xmlStrncmp` and `xmlStrncasecmp` use `XML3_Text.Buffers.Compare_Bounded` for
bounded byte-by-byte comparisons, early exit, and a result in -255 .. 255.
The scan accepts the full nonnegative C `int` bound without a `Max_Input`
cutoff, and may stop on an early mismatch or NUL.
`xmlStrncasecmp` retains the pinned byte map (`A`–`Z` plus `[` to `{`), a
reference quirk rather than Unicode case folding. The comparison allocates
nothing and performs no C-string conversion; actual native byte reads,
pointer validity, available memory bounds, and complete API semantics remain
trusted.
`xmlStrcmp`, `xmlStrEqual`, and `xmlStrcasecmp` share
`XML3_Text.Buffers.Compare_Terminated` / `Compare_Scan`. Identical-pointer
and NULL decisions occur without native reads; otherwise the scan checks
offsets 0 through `Max_Bytes`, stopping at the first mismatch or NUL. A
mismatch or NUL at the boundary completes the comparison. Equal non-NUL bytes
through the cap produce a diagnostic and `Limit_Exceeded`, with -1 returned
for `xmlStrcmp` / `xmlStrcasecmp`; that is not a trustworthy ordering result.
`xmlStrEqual` maps the diagnostic result to 0. The case map retains the
pinned `A`–`Z` and `[` to `{` behavior, not Unicode folding. SPARK proves
loop bounds, native-call preconditions, result range, and the cap-failure
contract; actual native reads, foreign-pointer validity/bounds/bytes, C
diagnostic mapping, and full API semantics remain trusted. The small-cap
boundary test passes a small `Last` to the Ada helper; no public C string near
the cap is dynamically constructed. Shared byte-pair and guard-page cases run
against libxml3 and the pinned reference; OOM/no-allocation checks are
libxml3-only.
`xmlStrlen` delegates to `XML3_Text.Buffers.Measure`, which handles NULL as
successful zero and otherwise uses the shared `Read_Length` scan through
`0..Last` inclusive. A NUL at the boundary is accepted; an unresolved scan
returns a failed status and zero length, which the C adapter maps to DOM error
115 and -1. Unexpected C-side exceptions map to DOM error 1 and -1 rather
than a silent zero. The `Max_Bytes` bound (`Integer'Last - 16`) is a
deliberate safe subset: unlike
the pinned reference's zero for lengths above `INT_MAX`, an over-cap scan is
diagnosed and must not be treated as an empty string. Tests exercise the
helper with reduced `Last` values instead of constructing an enormous public
C string. SPARK proves `Read_Length` (2 checks) and `Measure` (2 checks),
including scan bounds, result/status contracts, and the native read
precondition; actual bytes, foreign pointer validity/readable bounds,
C-side mapping/exception behavior, and full semantics remain trusted. No
allocation, mutation, transcoding, or UTF-8/XML validation occurs. Shared
raw-byte, UTF-8-byte-count, and guard-page vectors run against both
implementations; the no-allocation OOM-shim check is libxml3-only.
`xmlCheckUTF8` streams at most one UTF-8 scalar at a time using a four-byte
stack buffer and calls `XML3_Text.Validate_UTF8` with `XML_Only => False`.
It accepts ASCII control bytes and Unicode noncharacters as well-formed UTF-8,
while rejecting overlong encodings, surrogates, out-of-range scalars, malformed
and truncated sequences. This checks UTF-8 encoding, not XML character validity.
Existing XML parsing and name/content validation retain their XML-character
checks.
Unlike the pinned reference's permissive acceptance of noncanonical encodings,
the strict rejection is intentional. NULL returns 0, an empty string returns 1,
malformed input returns 0 without a diagnostic, and a scan unresolved through
`Max_Bytes` records error 115 and returns 0; unexpected exceptions map to
error 1 and 0. A NUL at the inclusive boundary is accepted. The operation
allocates nothing, mutates nothing, and does not transcode. Reduced-cap Ada
tests cover the scan limit; no enormous public C string is constructed.
GNATprove covers loop/index bounds and native-call preconditions, not actual
foreign bytes, pointer validity/readable bounds, C diagnostic mapping, or full
Unicode API semantics. Shared normal/malformed and guard-page tests compare
with the reference; expected noncanonical-input results differ deliberately,
and the no-allocation OOM test is libxml3-only.
`xmlUTF8Strndup` uses `XML3_Text.Buffers.Copy_UTF8_Prefix` to validate only the
traversed strict-UTF-8 prefix and then make an independent, NUL-terminated
owned copy. NULL input or a negative count returns NULL without reading,
allocating, or recording a diagnostic; a non-NULL zero count allocates an empty
copy without reading input. Positive counts stop at the requested scalar count
or the first NUL, so unvisited suffix bytes are not validated. A malformed,
truncated, or noncanonical visited prefix returns NULL before allocation with no
partial copy or diagnostic. The returned copy is caller-owned and must be freed
with `xmlFree`; the input is neither mutated nor freed. ASCII controls and
Unicode noncharacters are accepted as UTF-8, not XML-character validation.
Unresolved scanning through `Max_Bytes` maps to error 115 and NULL, allocation
failure uses the standard memory error 2 and NULL, and unexpected exceptions map
to error 1 and NULL. The strict malformed-prefix rejection is an intentional
difference from unspecified/permissive invalid-reference behavior. `Copy_Span`
performs the bounded `Length + 1` allocation and byte copy; `Slice` delegates
to it without changing its semantics, while the shared C `Slice_Result` handles
status/diagnostic mapping for both substring and UTF-8 prefix-copy adapters.
GNATprove proves 6 checks each for `Copy_Span` and `Slice`, and 2 for
`Copy_UTF8_Prefix`, in addition to the shared scan and measurement checks; native bytes, readable and
stable extents, pointer validity, allocator behavior, C ABI/mapping, and complete
Unicode API semantics remain trusted. Reduced-`Last` Ada tests cover the cap;
no huge public C string is constructed. Shared malformed/reference and
guard-page vectors run against both implementations, and OOM/no-allocation
checks are libxml3-only.
`xmlGetUTF8Char` decodes one leading scalar with
`XML3_Text.Buffers.Get_UTF8_Char`, reading no more than the caller-provided
`*len` bytes. NULL input, NULL length pointer, or available length below one
returns -1; when writable, `len` is zeroed on failure. NUL decodes as code
point 0 with width 1, and ASCII controls and Unicode noncharacters are valid
UTF-8 scalars. Invalid, truncated, overlong, surrogate, out-of-range, and
unsupported lead bytes return -1 with width zero and no diagnostic. The C
adapter maps unexpected exceptions to DOM error 1, zero length, and -1.
Allocation, input mutation, transcoding, and XML character validation are absent.
The implementation deliberately rejects the pinned reference's F8..FF
lead-byte masking (for example, F8 90 80 80 and FC 80 80 80) and avoids its
read of `utf[0]` before checking `*len < 1`. GNATprove proves 12 checks for
`Get_UTF8_Char`, covering control/index/overflow safety, output width bounds,
and native-call preconditions, not complete Unicode-decoding semantics.
Pointer validity, readable extent, actual bytes, and C-side status/exception
mapping remain trusted. Shared vectors, permissive reference cases with
differing expectations, and exact-span guard-page tests run on both
implementations; zero-length unreadable-pointer and OOM/no-allocation tests
are libxml3-only.
`xmlUTF8Strlen` uses `XML3_Text.Buffers.Count_UTF8` to count Unicode scalar
values in a NUL-terminated UTF-8 string. It returns 0 for empty input, stops at
the first NUL, and returns -1 without a diagnostic for NULL or malformed,
truncated, overlong, surrogate, out-of-range, or otherwise noncanonical UTF-8.
ASCII controls and Unicode noncharacters are accepted as UTF-8, not validated
as XML characters. This counts scalars, not bytes or grapheme clusters, and
does not normalize text. The strict behavior deliberately differs from the
pinned reference's permissive treatment of some overlong, surrogate,
out-of-range encodings and of two consecutive continuation bytes as a scalar.
An unresolved scan through
`Max_Bytes` records error 115 and returns -1; unexpected exceptions map to
error 1 and -1. It performs no allocation, input mutation, or transcoding.
`Scan_UTF8` implements the shared bounded streaming scan.
`Count_UTF8` delegates to it, and `Check_UTF8` delegates to `Count_UTF8`,
preserving whole-string validity and cap behavior. `Measure_UTF8_Prefix` uses the same `Scan_UTF8` loop and
stops at the requested scalar count or first NUL. GNATprove proves 23 checks
for `Scan_UTF8`, 1 each for `Count_UTF8`, `Check_UTF8`, and
`Measure_UTF8_Prefix`, and 21 for `Validate_UTF8`. These cover scalar
counter/loop/index and byte-offset bounds, status/result contracts, and
native-call preconditions, not full Unicode semantics or actual foreign bytes.
Reduced-`Last` Ada tests exercise the cap; no huge public C string is
constructed. Pointer validity/readable extent, C mapping, and complete API
behavior remain trusted. Shared Unicode/reference and guard-page vectors run
against both implementations; no-allocation/OOM checks are libxml3-only.
`xmlUTF8Strpos` uses `XML3_Text.Buffers.Find_UTF8_Position` and the shared
`Scan_UTF8` helper to return a borrowed pointer to a zero-based Unicode scalar
position. It validates only the traversed prefix; position zero returns the
input without reading, and a target scalar or suffix is not read or validated.
At the exact scalar length it returns the NUL address without reading that
byte. NULL input, negative positions, positions beyond the end, or malformed
visited prefixes return NULL without a diagnostic. ASCII controls and Unicode
noncharacters are valid UTF-8, not XML-character validation. The strict prefix
scanner deliberately rejects overlongs, surrogates, out-of-range scalars, and
five-byte sequences accepted by the pinned reference. An unresolved prefix
through `Max_Bytes` records error 115; unexpected exceptions map to error 1.
There is no allocation, input mutation, or normalization, and returned pointers
must not be freed and are valid only while the input lives. Reduced-`Last` Ada
tests cover the cap; no huge public C string is constructed. GNATprove covers
scan control, scalar/offset bounds, status/result contracts, and native-call
preconditions, not full Unicode semantics, actual bytes, readable extent,
pointer validity, or C mapping. Shared reference-permissive and guard-page
vectors run against both implementations with differing expectations;
OOM/no-allocation checks are libxml3-only.
`xmlUTF8Strsize` returns the raw byte size of up to the requested number of
Unicode scalars, excluding the terminating NUL. NULL input or a nonpositive
count returns 0 without reading. A shorter string returns the bytes before
NUL; when the requested scalar count is reached, the scan stops before
inspecting the following scalar or suffix. A malformed, truncated, or
noncanonical strict UTF-8 prefix returns -1 without a partial size or
diagnostic. Reference behavior for invalid UTF-8 is not guaranteed; this
implementation explicitly rejects malformed visited prefixes. ASCII controls
and Unicode noncharacters are valid UTF-8, not XML-character validation.
Unresolved scanning through inclusive `Max_Bytes` maps to DOM error 115 and -1;
unexpected exceptions map to error 1 and -1. No allocation, input mutation, or
normalization occurs. Reduced-`Last` Ada tests cover the cap; no huge public C
string is constructed. GNATprove covers scan control, byte-offset bounds,
status/result contracts, and native-call preconditions, not full Unicode
semantics or actual foreign bytes. Pointer validity/readable extent, actual
bytes, and C mapping remain trusted. Shared malformed/reference and
guard-page vectors run against both implementations; OOM/no-allocation checks
are libxml3-only.
`xmlStrncatNew` uses `XML3_Text.Buffers.Fits` and `Concatenate` to prove the
bounded sum, allocation sizing, status/result contract, and native-call
preconditions. Its adapter checks a positive right-hand span against that sum
before conversion. C-string conversion, pointer validity, allocation, native
byte writes, and complete public semantics remain trusted.
`xmlStrcat` and `xmlStrncat` use `XML3_Text.Buffers.Append`. `Read_Length`
checks the NUL-terminated right side; `Build_Append` applies the bounded right
length and current-prefix length, allocates a separate result, copies raw bytes,
and appends NUL; `Append` consumes and frees `cur` unless the status is
`Unchanged`. NULL `add` and `xmlStrncat` length zero are no-ops before negative
length handling. A negative bounded length with non-NULL `add` returns NULL
without a diagnostic and consumes `cur`. Positive bounded lengths copy exactly
the requested span, including embedded NUL. Cap failures return diagnostic
NULL and consume `cur` with DOM error 115; allocation failure uses the existing
OOM diagnostic and also consumes `cur`. A non-NULL empty `xmlStrcat` source is
a no-op for non-NULL `cur`, while NULL `cur` produces an owned empty buffer.
Callers must pass NULL or the base of a caller-owned `xmlFree`-compatible
allocation; literals and borrowed DOM pointers are invalid, and old `cur` must
not be used after a consuming call.
The fresh-allocation path avoids reallocating `cur` before reading an `add`
pointer that aliases it, including a raw suffix after an embedded NUL. This is
an intentional safety difference from the reference's realloc path; always
copying can increase peak memory and copy work. SPARK proves bounded length and
size arithmetic, native-call preconditions, and the status/result contract
(`Read_Length`: 2 checks, `Build_Append`: 14, `Append`: 1). Native allocation
freshness, actual reads/writes/free, pointer validity, correct caller
ownership, C diagnostics/mapping, and complete API semantics remain trusted.
Shared ordinary/null/empty/raw-span/negative/parse and guard-page cases run
against both the pinned reference and libxml3. Alias/self/raw-tail cases,
public cap rejection, and OOM/free-count checks are libxml3-only.
UTF-8 validity and complete API
equivalence are not proved; native pointers, allocation, byte writes, and C
conversion remain trusted boundaries.
`xmlCopyNamespace` resolves only managed live namespace facades, copies the
stored href/prefix spans independently while preserving NULL versus empty
fields, and omits source `next`, `context`, and `_private` links. Reservation
release and node pins are handled by the Store; foreign/stale pointers and
native representation/ABI remain trusted boundaries. The only supported
serialization entry point is
`xmlDocDumpMemoryEnc` with an explicit UTF-8 encoding; default encoding,
formatting, DTD and file APIs are unsupported. Unsupported
operations fail without silently creating invalid links. Unsupported parser
options fail, not silently degrade.

The current profile supports XML 1.0 UTF-8 and UTF-16LE/BE input, Unicode NCNames and qualified
element/attribute names, namespace declarations and read-only namespace lookup,
attributes, text, the five predefined entities, numeric references, comments,
CDATA and processing instructions. Normal resource ceilings are 50,000 bytes
per QName component/PI target, 10,000,000 decoded bytes per value, and depth
256. `XML_PARSE_HUGE` raises these to 10,000,000 bytes, 1,000,000,000 bytes, and
depth 2,048 respectively; it does not enable DTD, recovery, or other unsupported
features. The DOM is always UTF-8. UTF-16 input uses the length-taking
`xmlReadMemory`; `xmlReadDoc`/`xmlParseDoc` use `strlen` and are not binary UTF-16
entry points. Names `UTF-8`/`UTF8`, `UTF-16`/`UTF16`, `UTF-16LE`, and
`UTF-16BE` are case-insensitive; generic UTF-16 selects little-endian. Explicit
encoding overrides the declaration while declaration grammar is still checked.
Unknown explicit names fail rather than falling back. Auto-detected declaration
mismatches produce warning 113 on success. Malformed UTF-16 is rejected before
the parser at IO/code 81 and 1:1; later parser positions use decoded UTF-8
character columns. These are tested behaviors, not a proof of functional
encoding equivalence. These per-component/per-value thresholds are distinct from whole-input
and representation bounds. XML declarations accept version 1.0, the supported
UTF-8/UTF-16 encoding aliases, and standalone yes/no, in XML order. CR/CRLF line endings
are normalized, and literal attribute whitespace is normalized to spaces while
character references retain their referenced characters. Names follow the XML 1.0
fifth-edition ranges, without Unicode normalization. Invalid or unbound namespace
declarations fail closed, including cases where libxml2 may return a tree alongside
namespace errors. DTD, XInclude, XPath, schemas, HTML parsing, other encodings, and recovery mode
are not implemented. Rejection is an intentional compatibility gap, not a claim
those features are universally unsafe. Namespace acceptance semantics are tested
and reviewed, not fully established by the proof contracts.

Full libxml2 API and XML conformance remain development goals. Follow-on work must
extend the compatibility inventory and assurance boundary together, rather than
label unverified new features as already proved.

Compatibility tests do not authorize copying unsafe upstream defects. The
implementation follows harmless documented/observed quirks such as preserving
the last error after success, while refusing to emulate memory corruption,
invalid accesses, unsafe/unbounded resource use, or exploitable bugs for
differential equality. Any accepted difference is explicit; the pinned
reference's attribute/CDATA/PI near-limit lookahead behavior is measured, not
turned into an unexplained libxml3 safety limit.
