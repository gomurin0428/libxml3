# Assurance boundary

This project is an experimental, independent Ada/SPARK implementation, not a
release of GNOME libxml2. It is not yet a complete libxml2 replacement.

## Intended proof claims

`proof.gpr` includes complete specs/bodies of `XML3_Text`, `XML3_Parser`,
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
editing, `xmlTextMerge`, `xmlTextConcat`, `xmlNodeIsText`, and `xmlIsBlankNode`
through `Store.Queries.Test_Node`, inherited `xml:lang` / `xml:space` lookup
through `Store.Queries.Get_Inherited_XML_Property` and mutation through
`Store.Properties.Set_Qualified_Property`, reverse element navigation through
`Store.Queries.Select_Element`, detached `xmlNewDocProp` construction through
`Runtime.New_Doc_Node` / `Store.Content.New_Doc_Node`, managed attribute
attachment through `Store.Add_Child` / `Store.Properties.Add_Property`, and
managed sibling insertion through `Runtime.Add_Sibling` / `Store.Add_Sibling`,
and explicit UTF-8 memory serialization. The C adapters and native ABI
implementation are not proved. The refreshed aggregate has 11,071 checks
(932 flow and 10,139 prover), no
unproved or justified conditions, 0 `pragma Assume` statements, and 132
warnings. The representation-generation diagnostic is recorded separately.
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
new units are included in the successful 11,048-check aggregate proof; see
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
`xmlFreeNs`, `xmlNewNsProp`, `xmlSetNsProp`, `xmlUnsetNsProp`, and attribute
APIs `xmlNewProp`, `xmlSetProp`, `xmlUnsetProp`, `xmlRemoveProp`, and
`xmlFreeProp`. Attribute/namespace copying and cross-document moves remain
deferred. The only supported serialization entry point is
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
