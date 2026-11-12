# SPARK proof evidence

## Result

`Diagnostic_Messages.Kind_For` now owns the code/domain message selection
policy as one pure total expression function with no globals. It proves that
every `int` code and domain yields a `Message_Kind`, so the adapter can index
its text table without a range or exception path; a negative code takes the
domain fallback rather than raising. The message texts, their static
addresses and the kind-to-address table remain trusted adapter data, and this
contract makes no claim about libxml2 wording. A bridge regression compares
the function against a test-local copy of the previous ordered if-chain over
codes -3 .. 130 plus `int'First`/`int'Last`, domains -2 .. 12 plus the
extremes and both input flags, and asserts every kind is reachable.

`XML3_Error_Records` now owns cloning, partial-copy rollback and release of the
five diagnostic strings. Its record declaration keeps the existing C layout;
`XML3_Errors` uses a subtype rather than a second native representation. The
contracts preserve numeric/context/node values and NULL presence on success
and clear the temporary record on failure or release. Copies stop at the first
failure. Native readability/stability, allocation freshness, distinct ownership
and byte effects remain assumptions; these structural contracts do not prove
foreign memory safety or exception behavior. Public record replacement, TLS
and emergency-record selection remain trusted. Native tests exercise every
allocation failure, exactly-once prefix cleanup, length-limit rollback,
unreadable unused fields, independent copies, repeated release and retry.
GNATprove proves 1 check each for `Clone`, `Copy_Field`, `Free_Pointer` and
`Release`; the `Same_Metadata` and `Same_String_Presence` predicates have no
checks. `Release` carries five trusted native-call termination warnings.

The same unit now owns the per-thread slot transitions. `Error_Slot` pairs the
C-layout record with the emergency flag, keeping the record first so the
published `xmlError` address is unchanged. `Clear_Slot` releases the owned
strings of a normal record and only zeroes an emergency one, whose message is
borrowed from the static table; its postcondition is the empty slot, so the
flag is the invariant that stands for "borrowed" and no owning release can run
on a borrowed message. `Install` clears the slot and moves the replacement in,
with a postcondition that the slot now holds the old replacement value and the
replacement is empty, so the strings keep exactly one owner.
`Fill_Out_Of_Memory` and `Install_Out_Of_Memory` set the (6, 2, 3, message)
diagnostic from the `Out_Of_Memory` expression function, the latter marking the
slot as emergency. `Decide_Copy` reproduces the ordered `xmlCopyError`
decision (NULL operand or emergency destination reject, identical operands are
already copied, otherwise clone) and `Select_Last_Error` the published-record
choice. GNATprove proves 1 check each for `Clear_Slot`, `Install`,
`Fill_Out_Of_Memory` and `Install_Out_Of_Memory`, and 0 for the two decision
functions and `Out_Of_Memory`. One flow warning notes that the slot
`Clear_Slot` writes in `Install_Out_Of_Memory` is overwritten by the
out-of-memory fields; the call is still required for its release effect.
A bridge regression installs and clears owned and emergency slots, checks that
a static message survives both clearing and replacement, and compares
`Decide_Copy` over all 16 flag combinations and `Select_Last_Error` over its
inputs against test-local copies of the former adapter order.

`Text.Location_At` now owns the error adapter's line/column scan and is reused
for parser opening-tag lines. It has no global/native/allocator effects and
proves positive counter bounds and safe scan arithmetic under `Max_Bytes`.
Position zero stays at the start, positions beyond EOF clamp to available bytes,
and offsets are independent of the String lower bound. Tests cover every byte
class, LF/CR/continuation prefixes, empty input, maximum position/index values,
and pinned CRLF/multibyte/TAB diagnostics copied across input overwrite, reset
and a successful retry. Full Unicode/diagnostic semantics, C mapping and native
input adaptation are not implied by these range contracts.

Diagnostic message/file/payload duplication now reuses the proved
`Text.Buffers.Concatenate_Bytes` path, removing the error adapter's direct
strlen/malloc/memcpy implementation. The per-string copy algorithm is reused
without new algorithm coverage or a proof of full `xmlCopyError` semantics. Tests cover
NULL/empty/raw bytes, NUL at a protected page boundary, independent copies after
source protection and record reset, copied URLs reused in diagnostics, small
scan limits and allocation-failure rollback/retry including empty strings.
The helper retains its existing native assumptions and common byte cap; cap
failures map to the existing OOM path. Public error-record replacement, TLS,
exception mapping and native ABI remain trusted.

`Parser.Options.Classify` now owns the allowed-bit and HUGE-profile policy in
SPARK, replacing C adapter bit tests. Its pure contract characterizes accepted
non-negative masks and HUGE selection; no input/allocator/diagnostic effects
are introduced. The adapter keeps encoding-error precedence and rejects
unsupported options before reading the memory input. Tests cover every accepted
combination and individual bit, negative values, guarded rejection, diagnostic
allocation failures, and edit/output/reparse lifetimes with profile-dependent
depth limits. GNATprove proves 4 checks for `Parser.Options.Classify`. C
ABI/ordering/diagnostic mapping and complete semantics remain outside that
contract.

Parser workspaces now use `XML3_Parser.Workspaces` for checked native allocation,
partial-allocation rollback, release/reset, initial capacity and capped doubling.
The four native allocation calls and minimum one-byte scratch blocks are retained.
Per-block bounds are checked before multiplication; native sizes/layout, allocator
freshness and byte effects remain trusted. The C adapter retains array overlays,
the retry loop, locking and status/exception/diagnostic mapping; allocation-size
rejection keeps the existing no-memory mapping. Tests cover small byte limits,
growth to the cap without large allocation, each failed allocation and all remaining
blocks freed once, repeated release, arena-growth OOM/retry and source-free
edit/serialize/reparse workflows. Complete ownership and parser semantics are not
proved by the non-null/reset contracts. Node/name allocation sizes are derived
from `XML3_Parser.Node'Max_Size_In_Storage_Elements` and
`XML3_Namespaces.Name_Info'Max_Size_In_Storage_Elements`, not hard-coded. Those
attributes are declared in the non-SPARK private part of `XML3_Parser.Native_Sizes`
because GNATprove does not accept them in SPARK; their correspondence to native
allocation byte units and C/Ada layout remains trusted. GNATprove proves 10 checks
for `Workspaces.Allocate`, 1 for `Initial_Capacity`, 2 for `Next_Capacity`, and
1 for `Release`; `Empty` and `Ready` have 0 checks. The
`XML3_Parser.Native_Sizes` package summary has 0 checks.

Parse attempt and outcome policy now lives in `XML3_Parser.Outcomes`.
`After_Attempt` decides whether an attempt is finished, needs a larger arena or
has reached the node cap, and its postcondition ties growth to a capacity below
`Workspaces.Capacity'Last` so the adapter's growth step stays in range.
`Report_For` selects the published diagnostic from the finished read status and
the parser diagnostic code: none, the parser diagnostic, out of memory,
internal error, unsupported feature, or resource limit. A node cap reached
without a parser diagnostic now reports the resource-limit diagnostic
(domain 1, code 114) instead of the former internal error; the C status stays
`Status_Limit_Exceeded`. The adapter keeps allocation, locking, the native
read call, the C status mapping, thread-local out-of-memory inspection,
document release after a failed report and exception handling; none of those
are proved. GNATprove proves 1 check for `After_Attempt` and 1 for
`Report_For`. Tests exercise every read status against the initial, middle,
next-to-last and last capacity and against diagnostic codes 0, 1, 4, 114 and
115, compared with the adapter's former decisions, alongside the existing
arena-growth OOM/retry and large-document reuse cases.

The attempt loop that applies those decisions now lives in
`XML3_Parser.Attempts`. `Run` starts from `Workspaces.Initial_Capacity`,
allocates a workspace, calls one `Attempt_Procedure`, releases the workspace
and then follows `Outcomes.After_Attempt`: finish, report the node limit, or
grow through `Workspaces.Next_Capacity`. A loop invariant states that the
workspace is empty at every iteration start, assertions state that it is empty
at every exit after a successful allocation, and a loop variant on the growing
capacity proves that the retry loop terminates; its postcondition states that
`Arena_Exhausted` never leaves `Run`. GNAT rejects `Always_Terminates` on an
access-to-subprogram type, so the termination of a single attempt stays a
trusted property of the supplied procedure and `Run` carries no
`Always_Terminates` aspect; the loop's own progress and release pairing are
proved. The adapter supplies the attempt: `Build_Arena` keeps the address
overlays, the DOM lock, the native read call and the exception-to-status
mapping, and because it catches `Storage_Error`, `Lock_Error` and all other
exceptions, the attempt cannot propagate one into the proved loop. GNATprove
proves 10 checks for `Run`; the package and `Attempt_Procedure` summaries have
0 checks. Tests drive `Run` with a scripted attempt: two exhausted arenas then
a parsed document (three attempts over the initial capacity and its two
successors, each with ready buffers), a malformed document on the first
attempt, and a byte limit that makes allocation fail, which reports no memory
without running an attempt.

The remaining status-to-code selection lives in `XML3_Diagnostic_Codes`.
`For_Operation` maps a `DOM_Constructors.Construction_Status` and the
validation flag to the published (domain, code) pair, `For_Preparation` maps
an `Encoding.Buffers.Conversion_Result`, and `For_Report` maps the
`Parser.Outcomes.Report_Kind` of a finished parse; named constants cover the
unsupported-encoding and unsupported-option rejections. The optional result
records whether any diagnostic is published, so the adapter reports exactly
when the policy says to. Message texts, the choice between the full and the
simple report procedure, the C status values, thread-local out-of-memory
inspection and exception handling stay in the trusted adapter. The three
functions and the package summary each prove 0 checks because they are total
expression functions over enumerations. Tests compare every input value
against a test-local copy of the adapter's former literals and check each
named constant.

Parse request admission is staged in `XML3_Parser.Requests`.
`Check_Arguments` decides from the buffer pointer and the size alone,
`After_Encoding` runs only once the arguments are admitted, and
`After_Options` only once the encoding is admitted; `Huge_Requested`
reports the HUGE profile. The staging makes the ordering requirement
explicit: the adapter cannot read the caller's encoding name before the
argument check has accepted the request, because the first stage takes no
encoding input. `Admit` composes the three stages and specifies the whole
order for review and testing. Codes come from
`Diagnostic_Codes.For_Admission`; the adapter keeps reading the native
encoding pointer, publishing the diagnostic, the thread-local
out-of-memory fixup and the C status mapping. The package and its five
functions each prove 0 checks. Tests compare `Admit` with a test-local copy
of the former adapter order over every combination of buffer presence,
the sizes `int'First`, −1, 0, 1, the maximum input, one past it and
`int'Last`, every requested encoding and every option profile, assert that
the staged functions agree with the composition and that every admission
kind occurs; a C test parses with an unreadable (`PROT_NONE`) encoding
pointer and a rejected buffer argument to show the name is not read.

The published status of a parse entry point is selected in
`XML3_Parser.Statuses`. `For_Read`, `For_Admission` and `For_Preparation`
map the read status, the admission stage and the input preparation result
onto `Public_Status`; each postcondition states that `OK` is selected exactly
for a parsed document, an admitted request and a converted input.
`After_Report` applies the thread-local out-of-memory fixup and is proved to
leave `OK` unchanged and to change any other status only to `No_Memory`.
`Settle_Parse` combines both fixups of the former `Parse_And_Report`; its
postcondition states that a document is discarded only for a successful
parse that ends as `No_Memory`, that the settled status is `OK` exactly when
the parse succeeded and the document is kept, and that nothing changes when
no out-of-memory error is recorded. `After_Exception` never selects `OK`.
`Report_For_Preparation` selects how a failed input preparation is
published: malformed UTF-16 and the conversion limit are reported at the
start of the input (line 1, column 1), and running out of memory without a
position. Its postcondition states that a converted input publishes nothing
and that the unpositioned report is used only where `For_Preparation`
already selects `No_Memory`, so the adapter can apply `After_Report` to
every failed preparation without changing the former result.
Each of the seven functions proves 1 check (its postcondition) and the
package proves 0, with no warnings.
The adapter reads `Last_Error_Is_OOM` once after the diagnostic is published,
frees the document when told to, and converts the result to the C status
values through one total `Status_Code`. Tests compare every read status,
report kind and out-of-memory flag, every admission kind and every
preparation result with a test-local copy of the former adapter code, and
assert the C value of each literal.

The `int` results of the DOM entry points are selected in
`XML3_DOM_Results`. Each convention is a function of the operation status:

* `Removal` (`xmlUnsetProp`, `xmlUnsetNsProp`, `xmlRemoveProp`): 0 exactly
  when the operation succeeded and removed an attribute, otherwise -1.
* `Update` (`xmlNodeSetContent(Len)`, `xmlNodeAddContent(Len)`,
  `xmlNodeSetLang`, `xmlNodeSetSpacePreserve`): 0 exactly on success, -1
  when out of memory, 1 for other failures. `xmlTextConcat` uses the
  text-only variant, which never answers 1.
* `Lookup` (`xmlNodeGetAttrValue`, `xmlGetNsListSafe`): 0 exactly when a
  value is returned, 1 when there is none or the arguments name none, -1
  for other failures.
* `Space_Code` (`xmlNodeGetSpacePreserve`) and `Truth` (`xmlNodeIsText`,
  `xmlIsBlankNode`).

`Status_Of` maps an adapter failure cause (an argument guard or an exception
handler) onto the status it stands for, so a failure the adapter detects
itself returns the same value as the equivalent status from the operation.
Its postcondition states that it never selects success, that it selects
`No_Memory` exactly for an allocation failure, and that for the DOM causes
`Diagnostic_Codes.For_Failure` publishes the same code as
`Diagnostic_Codes.For_Operation` does for that status. `Status_Of`,
`Removal`, `Update` and `Lookup` each prove 1 check (the postcondition);
the package, `Space_Code` and `Truth` prove 0. The adapter keeps the
exception handlers, the lock, the native calls and the publication of
diagnostics. Tests compare every status and flag with a
test-local copy of the former inline expressions and assert the value each
former handler and guard returned.

`XML3_DOM_Results` also decides whether an unusable argument is published.
Each call site names an `Operation_Class`, and `Reports_Invalid_Argument`
holds the policy. Edits, constructors, searches, `xmlDocGetRootElement`,
`xmlGetNodePath`, the node-list text getters and
`xmlEncodeEntitiesReentrant` publish a diagnostic. The queries that answer
"nothing" stay silent: node tests, element navigation, the child count,
`xmlNodeGetContent`, inherited `xml:lang`/`xml:space`, property lookups
and the namespace list. `Diagnostic_For` combines the class with
`Diagnostic_Codes.For_Operation`. Its postcondition (1 check) states that
success publishes nothing, that every failure other than an unusable
argument is published, and that an unusable argument is published exactly
for the reporting classes. Tests compare all twelve classes and every status
with the Boolean flag each call site used to pass.

The argument checks the C entry points make before they take the DOM lock
are selected in `XML3_Entry_Guards`. Entry points are grouped by the check
they share. For each group, the constant `Rules` table states which of up to
two pointer arguments must be present, whether the two must differ
(`xmlReplaceNode`), and whether a refusal publishes the invalid-argument
diagnostic. Six groups publish: the `xmlDocDumpMemory` family,
`xmlNewChild`/`xmlNewTextChild`, `xmlNodeSetLang`/`xmlNodeSetSpacePreserve`,
`xmlNewProp`/`xmlNewNsProp`, the set and unset property calls, and
`xmlRemoveProp`. The other groups return silently, as libxml2 does for
them. `Admit` decides a call; its postcondition (1 check) states that an
admitted call has every required argument, that a call with all arguments
present and distinct is admitted, and that a refusal is reported exactly
for the reporting groups. `Diagnostic_For` (1 check) selects
`DOM_Invalid_Argument` for a reported refusal and nothing otherwise. The
adapter computes which pointers are NULL through one `Refused` helper,
publishes the selected diagnostic and returns each entry point's refusal
value. Tests compare every group and all eight presence combinations with a
test-local copy of the former inline conditions.

`XML3_DOM_Store.Copies` implements `xmlCopyNode`, `xmlDocCopyNode`,
`xmlCopyProp` and `xmlCopyDoc` as a composition of existing Store
operations: `Content.New_Doc_Content` creates each copy from the source's
name and content bytes, `Attach` links it, `Create_Namespace`,
`Set_Namespace` and `Queries.Lookup_Namespace` select and declare its
namespace in the order `xmlStaticCopyNode` and `xmlCopyPropInternal` use,
and `Release` removes everything a failed copy created. The subtree is
visited in document order with an explicit cursor rather than recursion;
every loop is bounded by the node or namespace count at entry, and every
source reference is checked to be live before it is read, so a change to
the source during the copy ends it with an internal error instead of an
unchecked access. The contracts state that the Store invariant is kept and
that a copy is returned exactly when the status is `Created`. They do not
state that the copy is equal to the source; `make test-copy` compares the
copies with those of the pinned libxml2. Inside this child unit the
invariant is written out as a local ghost function, because calling the
parent's `Ready` from a child requires the invariant itself.
`Queries.Lookup_Namespace` now also states `Ready` in its postcondition,
which its body already established.

`XML3_Byte_Buffers` implements the `xmlBuffer` operations of libxml2
2.15.4 (`XML_BUFFER_ALLOC_IO`) on a view of the public struct: the
allocation base, the offset of the content after a shrink, the used bytes
and the size. `Well_Formed` (the used bytes stay below the size, the block
stays within `INT_MAX`, an empty view has no block) is a precondition and
postcondition of every operation; `Grown_Size` is proved to leave room for
the requested bytes. Byte moves go through `Move_Bytes`, which takes base
and index so that the native offsets need no non-null contract. Text taken
from the buffer itself stays valid: `Add` reads it before releasing the old
block, and `Add_Head` and `Add_Quoted` work on a copy of text that lies in
the block (`Inside`), since moving the content or appending a quote could
overwrite or release it first. libxml2 reads such text after the move or
the release. `Add_Attribute_Text` (`xmlAttrSerializeTxtContent`) escapes
attribute text as libxml2's `xmlSerializeText` does for a document without
an encoding; `Hex_Reference` reproduces `xmlSerializeHexCharRef`, including
its choice of the first digit, and the loop over the text is bounded by a
variant. `XML3_Serialization.Render` now also serializes a
single node (`xmlNodeDump`): the node itself without a declaration, an
attribute with its leading space, or a whole document; a separate
`Nesting` counter bounds the descent while `Depth` adds the starting
level to the indentation. `XML3_DOM_Store.Serialization.Dump_Node` clamps
the level to 0 .. 100. `XML3_File_Paths` plans how a file name becomes a
path (unescape, skipped `file:` prefix, standard output for `-`). The
system calls are in `src/xml3_file_io.c`, outside the proof.

`XML3_File_Paths.Plan_Input` decides how the name given to `xmlReadFile`
or `xmlParseFile` becomes a path (only a `file:` URI is unescaped after its
prefix), and the spec-only `XML3_IO_Errors` maps each `XML_IO_*` code to
the text libxml2's `xmlErrString` gives it and to the level of the record:
a warning for a missing file, fatal otherwise. Reading the file is in
`src/xml3_file_io.c`, outside the proof; the parse is the proved memory
parse.

The string entry points select their diagnostics and `int` results in
`XML3_Text_Results`.

* **Diagnostics.** One total function per status type maps the status of a
  SPARK string operation onto the published code: `For_UTF8`, `For_Search`,
  `For_Path`, `For_URI_Escape`, `For_Special_Escape`, `For_Append`,
  `For_Concatenate`, `For_Slice`, `For_Comparison`, `For_Build`, `For_Split`
  and `For_Prefix`, plus `For_Limit` and `For_Malformed` for the Boolean
  outcomes. A string beyond the supported length is reported as unsupported
  text and a failed allocation as out of memory. An invalid or absent string
  is an ordinary answer and publishes nothing, except in
  `xmlEncodeSpecialChars`, where text that cannot be encoded is reported.
* **Results.** `Validity` (`xmlCheckUTF8`), `Measure` (`xmlUTF8Strlen`,
  `xmlUTF8Strsize`, `xmlStrlen`), `Location` (`xmlUTF8Strloc`), `Path_Code`
  (`xmlNormalizeURIPath`) and `Equality` (`xmlStrQEqual`, `xmlStrEqual`).
  The postconditions of `Measure` and `Location` state that -1 is answered
  exactly when there is no measure or match.

`For_Limit`, `For_Malformed`, `For_Special_Escape`, `Location` and both
`Measure` functions prove 1 check each; the other functions are total
expression functions and prove 0. The adapter keeps the native calls, the
pointer results and the exception handlers. A handler answers through the
same result function as an invalid string. Tests compare every status of
every type with a test-local copy of the former adapter code and literals.

The adapter's own failure causes are named in
`Diagnostic_Codes.Adapter_Failure` and mapped by `For_Failure`. The eight
causes are `Lock_Failure` and `Unexpected_Exception` (domain 2, code 1),
`Unexpected_Namespace_Exception`, `Invalid_Argument` and `Unsupported_Text`
(domain 2, code 115), `Invalid_Character` (domain 2, code 9),
`Allocation_Failure` (domain 6, code 2) and `Parser_Exception` (domain 1,
code 1). Causes that share a pair stay distinct so that every call site
still names what happened. The adapter reports through one `Report_Failure`
helper, leaving the exception handlers, the argument guards, the reported
level and the file address as trusted adapter behavior. `For_Failure`
proves 0 checks; tests compare all eight causes with a test-local copy of
the former adapter literals.

UTF-16 native conversion uses `Encoding.Buffers.Convert_UTF16` and its bounded
two-pass helper, moving measure/allocate/fill/failure cleanup out of the C adapter.
String and native paths share code-unit assembly, surrogate validation and UTF-8
encoding. Native extents/stability, byte effects, allocator/ABI and full semantics
remain trusted. `Prepare_Input` now performs bounded header detection, BOM
skipping and optional conversion. `Release_Input` frees only owned conversion
storage and resets its view, never freeing borrowed UTF-8. `Detect_Bytes` uses
the existing String `Detect` on at most 4/3/2 bytes for automatic/explicit UTF-8/
explicit UTF-16 input, with no detection reads for fewer than two input bytes.
Parser span adaptation and diagnostics remain at the C boundary. Tests compare
header-prefix views with String detection/conversion, ownership and repeat
release, plus endian/length limits, empty output,
malformed pairs, guarded input and input-protection/output/reparse/edit lifetimes;
OOM walks include successful XML and BOM-only empty-document failure.
GNATprove proves 6 checks for `Detect_Bytes`, 5 for `Prepare_Input`, 1 for
`Release_Input`, 4 for `Convert_UTF16`, and 17 for `Convert_UTF16_Pass`;
`Decode_UTF16` proves 32 checks (2 warnings), its `Unit_At` 4,
`Decode_UTF16_Pair` 2, and `Read_UTF16_Unit` 0.
`XML3_Text.Location_At` proves 13 checks for bounded line/column accounting;
the parser's `Line_At` wrapper proves 4 checks while reusing that helper.
These establish the written bounds and scan safety, not complete diagnostic
or Unicode correctness.

The proof switches for this source revision were:

```sh
/root/.local/share/ada/candidate-14/bin/gnatprove -P proof.gpr --mode=all --prover=cvc5,z3 --timeout=120 --memlimit=4096 -j4
```

`make prove-units` (`eng/prove_units.py`) runs GNATprove with these switches
one compilation unit at a time (`-u <unit>.ads <unit>.adb`) from a clean
object directory. GNATprove analyzes units modularly, so the union of the
per-unit runs covers the same verification conditions as a single
whole-project run, while each run stays short and `make prove-units-resume`
can continue an interrupted run. A unit fails on its own unproved or error
messages. After the last unit, the script requires the summary GNATprove
aggregates over the object directory to list all 49 units, with no
justified or unproved check and no entity reported as not proved.

The `Effects_Valid` assertion at the end of `XML3_DOM.Import.Adopt`
(`xml3_dom-import.adb`) did not prove within 120 s / 4096 MB on the machine
used for this record; the previous revision needed `--timeout=600
--memlimit=8192` for that unit. `Adopt` now states, through a loop invariant
over the destination owners, that an owner in the `Releasing` state was kept
from the destination before the import (the adopted slot is `Live`) and
therefore has no references or reservations. With that, the whole unit
proves with the switches above. On the same machine and switches, the
previous body still leaves that assertion unproved.

`XML3_DOM` is split into child units so that every unit proves within one
run. On the machine used for this record the former single unit needed more
than two hours. The parent keeps the model (types, views, the validity
predicates and accessors) and the small operations. Body-only helpers move to
private children:

* `XML3_DOM.Graph_Lemmas`: pin, holder-count and namespace-link lemmas and
  the new frame lemmas.
* `XML3_DOM.Links`: unlink, append, replace and sibling-placement lemmas and
  link updates.
* `XML3_DOM.Projection`: `Set_Node_Projection_Internal`, formerly in the
  private part of the parent.
* `XML3_DOM.Marking`: subtree marking, relinking and attachment checks.
* `XML3_DOM.Freeing`: node retirement and marked-subtree freeing.

Two groups of public operations move to public children:

* `XML3_DOM.Releases`: `Take_Release` and `Acknowledge_Release`.
* `XML3_DOM.Retirement`: `Free_Subtree`, `Free_Subtree_With_Namespaces`,
  `Empty_Attribute_Content_Lemma`, `Retire_Attribute_Children` and
  `Retire_Element_Children`.

Their contracts are unchanged. Callers add the matching `with` and `use`
clauses.

Moving code across units changes the context the SMT solvers see, and
several hard goals that proved inside the single unit failed in the
children. The failures were not timeouts: the solvers gave up quickly, and
small unrelated edits moved which goal failed. One cause is that `=` on
arrays and records is element-wise in SPARK. Facts stated as
`After.Graph = Before.Graph` therefore do not transfer to applications such
as `Holder_Count (Snapshot_Nodes (After), ...)`. The affected procedures now
call small ghost lemmas, each proved on its own, in place of large quantifier
instantiations:

* `Owner_Step_Effects`: one owner-count step keeps `Effects_Valid`.
* `Facades_Frame` and `Facades_Same_Graph`: facades survive slot resets and
  unchanged graphs.
* `Tree_Links_Frame` and `Same_Tree_Links`: sibling and child validity
  depend only on tree links.
* `Held_Pins_Live`: per-pin liveness from "every held owner is live".
* `Namespace_Owners_Live` and `Namespace_Links_Frame`: element-wise
  preconditions for `Preserve_Namespace_Links`.
* `Unlinked_Fields`, `Unlink_Fields_Raw` and `Replaced_Namespace_Fields`:
  the fields kept by unlinking and by child replacement.
* `Node_Links_Of` and `Ranges_From_Links`: per-node validity and the range
  properties of a valid state.

`Unlink`'s postcondition additionally states that slot states and tree
ranks are kept and only the unlinked node's parent changes.

The 39 units of an earlier revision were proved in one clean
`make prove-units` run, resumed with `make prove-units-resume` across the
environment's two-hour invocation limit. Later revisions add ten units,
`XML3_DOM_Results`, `XML3_Text_Results`, `XML3_Entry_Guards`,
`XML3_DOM_Store.Copies`, `XML3_Byte_Buffers`, `XML3_File_Paths`,
`XML3_IO_Errors`, `XML3_Parser.Contexts`, `XML3_Save_Contexts` and
`XML3_URIs`, and
change eight of those 39 units: `XML3_Parser.Statuses`, `XML3_Error_Records`
(the per-thread error mark and the handler choice),
`XML3_DOM_Runtime`, `XML3_DOM_Store.Queries` (postcondition),
`XML3_Serialization` and `XML3_DOM_Store.Serialization` (node mode and
the `xmlsave.h` output style) and,
as clients of the changed `Queries` specification, `XML3_DOM_Store.Content`
and `XML3_DOM_Store.Properties`. `eng/prove_units.py` proved each new or
changed unit again in the same object directory, and GNATprove aggregated
all 49. The sources of the other 31 units are unchanged (see the source
identities below). All 49 units prove with the switches above.
The longest units take
47 min (`XML3_DOM.Releases`), 41 min (`XML3_DOM.Marking`), 40 min
(`XML3_DOM.Links`) and 29 min (`XML3_DOM`). The eight `XML3_DOM` units hold
6,316 prover checks, against 5,749 for the former single unit; the
difference is the new lemmas and hint assertions.

Result: **15,155 checks, 1,946 by flow analysis and 13,209 by provers; 0
unproved, 0 justified, and 0 `pragma Assume`**. The aggregate includes namespace editing through
Store/Runtime, retained namespace ownership, failure rollback, explicit UTF-8,
default-encoding, and formatted memory serialization, `xmlNodeAddContent`, `xmlNodeAddContentLen`,
`xmlNodeSetContent`, `xmlTextMerge`, `xmlTextConcat`, `xmlNodeIsText`,
`xmlIsBlankNode`, `xmlNodeGetLang`, `xmlNodeGetSpacePreserve`,
`xmlNodeSetLang`, `xmlNodeSetSpacePreserve`,
`xmlNewChild`, `xmlNewTextChild`, `xmlNewDocText`, `xmlNewDocTextLen`,
`xmlNewDocComment`, `xmlNewDocPI`, `xmlNewDocNode`, `xmlNewDocRawNode`,
`xmlNewDocProp`, managed-attribute attachment through `xmlAddChild`, managed
attribute unlink through `xmlUnlinkNode`, managed sibling insertion through
`xmlAddSibling`, previous/next sibling insertion through
`xmlAddPrevSibling` / `xmlAddNextSibling`, managed node/attribute list release through
`xmlFreeNodeList` / `xmlFreePropList` and `Runtime.Release_List` /
`Store.Release_List`, `xmlNewCDataBlock`, `xmlGetNodePath` through
`Runtime.Get_Path` / `Store.Queries.Get_Path`, `xmlLastElementChild`,
`xmlPreviousElementSibling`, and `xmlGetLastChild` through the SPARK
Store/Runtime. The internal `Store.Replace_Node` and `Runtime.Replace_Node`
operations for `xmlReplaceNode` are analyzed (41 and 1 checks, respectively),
including their written status/result contracts and use of existing graph
operations. This does not prove the C adapter, native facade synchronization,
ABI, or complete public semantics. `xmlStringGetNodeList` and
`xmlStringLenGetNodeList` route
through `Runtime.Parse_Content_List` / `Store.Content.Parse_Content_List`,
the analyzed strict text decoder, and the existing document-owned text
constructor. `xmlNodeListGetRawString` routes through `Runtime.Get_List_Content`
and `Store.Queries.Get_List_Content`. `xmlNodeListGetString` shares that bounded
query and uses the analyzed `XML3_Text.Buffers.Escape_Special` and
`Character_Reference` helpers. The new `xmlNodeGetAttrValue` getter reuses the already-analyzed
`Runtime.Get_Property` / `Store.Queries.Find_Property` / `Get_Content` path;
its C status/output-pointer mapping is outside the proof. The native
`Find_Property` overload now receives name/URI addresses for all six public
attribute getters/existence queries. Registered-element/kind checks precede
measurement/copy into SPARK Strings; existing String lookup and `Get_Content`
retain namespace filtering and borrowed/copy ownership. Measurement failure
maps to `Limit_Exceeded` (code 114, safe getter -1/NULL), not invalid-node/missing
status. Guarded input, NULL/empty filters, Unicode local names, aliased fields,
copied values used after document release, serialization/reparse/editing and
invalid-context read avoidance are execution tests. Native extents/stability,
byte effects, allocation and ABI remain trusted. GNATprove proves 14 checks
for the native `Store.Queries.Find_Property` overload (2 warnings), 16 for its
String overload, 1 for `Runtime.Find_Property`, and 2 for `Runtime.Get_Property`.
The native `Properties.Create_Property` overload also receives `xmlNewProp`
name/value addresses directly, validates a non-NULL registered element before
input reads, and measures/copies into SPARK Strings. Existing String construction
retains colon rejection, raw values, detached/appended attribute ownership and
rollback, NULL/empty value distinctions and duplicate ordering. Scan exhaustion
maps to resource-limit code 114; invalid elements return code 115 without input
reads. Guarded input, overlapping name/value sources, alias copies from existing
attributes, source protection and original-attribute release before output,
reparse/editing are execution tests. Native extents/stability, byte effects,
allocation and ABI remain trusted. GNATprove proves 15 checks for the native
`Store.Properties.Create_Property` overload (2 warnings), 28 for the existing
String overload (2 warnings), and 1 for `Runtime.Create_Property`.
`xmlNewNsProp` / `xmlSetNsProp` now share native
`Properties.Edit_Namespace_Property`: registered element/namespace checks and
non-NULL namespace-href validation precede name/value measurement and SPARK-local
copying. Existing String constructors/updaters retain URI matching, NULL/empty
value behavior, detached creation, raw values, attachment preservation, Ready
and rollback contracts. Scan failure maps to 114, invalid context to 115.
Guarded input, input protection, copies and updates from old attribute fields,
equivalent-URI prefix replacement, release/serialize/reparse/edit workflows are
execution tests; native extents/stability, byte effects, allocator/ABI and complete
semantics remain trusted.
GNATprove proves 25 checks (2 warnings) for native
`Store.Properties.Edit_Namespace_Property`, and 1 check each for
`Runtime.Create_Namespace_Property` and `Runtime.Set_Namespace_Property`.
`xmlUnsetProp` / `xmlUnsetNsProp` forward to common native
`Properties.Unset_Property`: register-check element/namespace before name reads,
measure/copy in SPARK, preserve no-namespace/URI lookup, plain-only colon rejection,
and corresponding release kind. Existing Store invariants and lookup/release are
reused. Missing attributes leave diagnostics unchanged; invalid contexts report115,
scan exhaustion114. C byte scanning/string conversion helpers and dedicated
exception, and Runtime's duplicate Has_Colon are removed. Guarded input protection,
duplicate ordering, own-name aliases, output/reparse/edit and native-allocation-free
removal are tested; invalid-facade rejection is libxml3-only. Native extents/stability,
byte effects, allocator/ABI and full public semantics remain trusted.
GNATprove reports 20 checks (2 warnings) for `Store.Properties.Unset_Property`;
`Runtime.Unset_Property` and `Runtime.Unset_Namespace_Property` each have 0 checks.
The native `Properties.Set_Qualified_Property` overload receives `xmlSetProp`
QName/value addresses after registered-element checks, measures/copies into
SPARK-local Strings and reuses existing QName validation/resolution, unqualified
updates, implicit XML namespace creation/rollback and Ready/Result contracts.
`Set_XML_Property` still calls the existing String overload. Invalid elements
report 115 without input reads; scan exhaustion reports 114 rather than former
conversion error 115. Guarded input, overlapping sources, old-field aliases,
documentless editing followed by attachment/output/reparse/edit are execution
tests. Native extents/stability, byte effects, allocator/ABI and full public
semantics remain trusted.
GNATprove proves 16 checks (2 warnings) for native
`Store.Properties.Set_Qualified_Property`, 38 checks (1 warning) for its
existing String overload, and 1 check for `Runtime.Set_Qualified_Property`.
The public
`xmlValidateName`, `xmlValidateNCName`, `xmlValidateQName`, and
`xmlValidateNMToken` adapters now pass pointers directly to the analyzed
`XML3_Text.Buffers.Validate_Name` / `Scan_Name`, without a C-string copy.
They share the bounded state machine with the four `valid.h` value predicates.
Their bounds, termination, and written result contracts are proved, not complete
lexical equivalence, native pointer readability/extents, byte effects, C ABI,
or C return-code mapping.
The four `valid.h` value validators delegate to
`XML3_Text.Buffers.Valid_Name_Value` / `Scan_Name`. The scanner reuses
`Name_Character` (0 checks), also used by `Name_Width` (19),
`XML3_Text.Valid_Name` (23, via `Name_Width`), and
`XML3_Text.Buffers.Valid_Name` (4). `Scan_Name` proves 9 checks,
`Validate_Name` 2, and `Valid_Name_Value` 2. These checks cover the bounded
scan's control flow, termination, and written result contracts, not native
pointer readability/extents, byte effects, C ABI, or complete lexical
equivalence.
No DTD or ID/IDREF semantics are proved or implemented by these APIs.
`xmlSplitQName2` and `xmlSplitQName3` share `XML3_Text.QNames.Locate_Prefix`.
QName2's `Split` measures the local tail with the original absolute scan cap
via `Buffers.Measure`'s start offset, then reuses `Copy_Span` twice. Failure
of the second allocation frees the prefix and leaves both outputs NULL.
No intermediate C-string copy is made. QName3 returns
the borrowed local address after checking only its first byte, without a
C-string copy or a scan through the local tail. The proof covers first-colon
length bounds, output/status contracts, and allocation/cleanup control flow
for copying splits. Native pointer readability/extents, byte effects,
allocation/copy/free, pointer arithmetic, C ABI/status mapping, and complete
public semantics remain trusted or outside proof. Reference/guard-page tests
cover early stops and copying the borrowed suffix before freeing its owner;
small-cap Ada tests cover unresolved lookup/copy limits without resetting the
budget at the local suffix. OOM injection is libxml3-only. The pure
`Prefix_Length` helper remains analyzed but is not on these C API paths.
`xmlCharInRange` selects the short table below 65536 and the long table for the
rest of the unsigned domain, then searches inclusive endpoints using the
overflow-safe lower-middle calculation. GNATprove discharges 16 checks for
`XML3_Text.Buffers.Character_In_Range`, including selected-count/stride bounds,
search indices, and loop termination. The scalar group/entry loads in
`XML3_Native_Memory` are explicitly `SPARK_Mode => Off`; they are not proved.
Caller-provided ranges must be readable, aligned, sorted, disjoint, and stable
during the call. Tests compare valid tables with the pinned reference and
exercise unsigned boundaries, guard pages, ignored inaccessible table halves,
malformed selected metadata on libxml3 only, and the no-allocation path. Native
pointer validity/extents/layout/actual reads, C ABI, and complete semantics
remain trusted or outside proof; this is a generic range lookup, not a
Unicode/XML validator.
`xmlURIEscapeStr` uses `XML3_Text.Buffers.Escape_URI` for bounded,
byte-wise percent encoding with lazy cached exception-list searches. The
optional `Find_Byte` limit defaults to `Max_Bytes`, preserving existing
search behavior; `URI_Image` proves 6 checks, `Escape_URI` 18, and `Find_Byte`
3. These checks cover the image width, bounded measurement/search and written
status/result contracts, not native allocation, bytes, reads or writes,
pointer validity/extent/stability, C ABI, or complete URI semantics. Tests
compare all nonzero byte values with the fixed reference and cover arbitrary
non-UTF-8 bytes, aliasing, guarded early stops, limits and OOM retry.
`xmlNormalizeURIPath` delegates to `XML3_Text.Buffers.Normalize_URI_Path`.
The helper proves 32 checks for bounded measurement before mutation, segment
and output-position arithmetic, in-place copy preconditions, loop termination,
and the status contract. These checks do not prove normalized byte values,
native byte effects, pointer validity or writable extents, C ABI, or complete
path semantics. Tests cover reference behavior, deliberate upstream
root-detection differences, idempotence, byte values, guarded termini,
read-only empty input, and the allocation-free path.
`xmlURIUnescapeString` delegates to `XML3_Text.Buffers.Unescape_URI`.
`URI_Hex` proves 1 check and `Unescape_URI` 19, covering the hex-result range,
bounded input-span traversal, native-call preconditions and status/result/
target contracts. They do not prove decoded byte values, target capacity,
native reads/writes, scratch allocation/copy/free, pointer validity or full
public semantics. Tests cover positive and terminator-based lengths, embedded
NULs, malformed escapes, exact in-place and overlapping buffers, limits and
allocation-failure preservation.
`xmlGetPredefinedEntity` reuses the pure `Entity_Name` mapping (1 check),
`Entity_Value` (0 checks), and exact `Find_Entity` matching (2 checks) in the
shared decoder. Its bounded native-name lookup proves 1 check for
`Get_Predefined_Entity` and reuses `Matches_Literal` (5 checks). The static
`XML3_Native_Memory.Predefined_Entity` record/string table is in
`SPARK_Mode => Off`; its native layout, pointers, lifetimes, byte contents and
address effects are not formally proved. The public API remains partial and
not-proved: C-string conversion, native pointer readability, C ABI, and
complete entity semantics remain trusted boundaries.
`xmlGetDocEntity` delegates to the analyzed
`Runtime.Get_Document_Entity` (1 check) and
`Store.Queries.Get_Document_Entity` (3 checks); its registration guard
`Registered_Document` discharges 8 checks. A NULL name returns before document
registration or name access; otherwise the Store query validates NULL or
registered document facades before calling the already-bounded predefined
lookup. This covers the SPARK query and its status/result contract, not C
diagnostic mapping, C ABI, native name readability, static record layout or
lifetime, byte contents, or complete public semantics.
`xmlBuildQName` uses `XML3_Text.QNames.Build` for direct bounded measurement
and byte construction without C-string conversion. Its budget first reserves
colon/NUL, measures the name, and measures the prefix within the remainder.
`Overlaps` compares nonempty spans by subtracting the smaller address value
from the larger, rather than forming potentially overflowing end addresses.
A sufficient overlapping caller buffer uses a temporary allocation, copied
back only after successful construction; failure preserves the caller buffer.
Sufficient non-overlapping buffers need no allocation. The written result/status
contract and scalar bounds are checked, not native address-to-integer mapping,
pointer validity/extents, allocation/free/byte effects, C ABI, or full public
semantics. GNATprove discharges 18 checks for `Build` and 2 for `Overlaps`.
Overlap safety is tested only for libxml3, not reference equivalence.
`xmlEncodeSpecialChars` exports from `libxml/entities.h` and uses
`XML3_Text.Buffers.Escape_Special_Bytes` without C-string materialization.
`Escape_Bytes_Pass` performs bounded direct UTF-8/XML validation, measurement
and construction, stopping at NUL or the first invalid unit. It shares
`Get_UTF8_Char`, `Special_Image`, `Character_Reference`, and `UTF8_Image`.
Allocation follows successful measurement; the write pass uses that measured
size as its cap and failures free partial output. The written proof covers
scalar bounds, loop/index/overflow checks, native-call preconditions and the
status/result relationship, not complete output semantics. GNATprove discharges
17 checks for `Escape_Bytes_Pass` and 5 for `Escape_Special_Bytes`; the
String-based `Escape_Special` has 39 checks. Tests cover the fixed
replacements, NULL/empty behavior, Unicode, input immutability, ownership,
round-trip serialization, invalid-input rejection, and OOM retry. The API is
partial and not-proved at the public C level: pointer validity/readable extents,
ABI/status mapping, native allocation/free and actual byte effects,
and complete libxml2 semantics remain trusted. The document argument is
unused as in pinned libxml2 2.15.4; malformed UTF-8/XML is rejected rather than
silently repaired or preserved, and no DTD/entity expansion is provided. The
String-based `Escape_Special` remains for internal DOM callers and emits one
analyzer warning because `Validate_UTF8`'s `Error` output is unused.
`xmlEncodeEntitiesReentrant` passes its input address directly through
Runtime/Store `Encode_Entities`. `Registered_Document` runs before any input
read; invalid documents return NULL without dereferencing document or input.
`Escape_Special_Bytes` is shared with `xmlEncodeSpecialChars`, using
`Non_ASCII => True, Quotes => False`, and `Encoding_Status` maps its result.
The Store `Encode_Entities` query proves 3 checks and its Runtime wrapper 1.
It escapes `<`, `>`, and `&`
with named references, CR as `&#13;`, and valid non-ASCII as uppercase
hexadecimal references; quotes, TAB, and LF remain literal. NULL input is
returned before document validation, while non-NULL input permits only NULL
or a registered document. The proof covers the shared bounded validation,
escaping, and status/result contracts. No C-string conversion remains on this
path; native pointer extents/stability, byte effects, allocation/free, C
NULL/diagnostic mapping, ABI, and complete C semantics remain trusted. Its
behavior intentionally rejects invalid UTF-8/XML rather than repairing or
preserving it; document encoding is not retained, so explicit UTF-8 documents
can differ from reference output. General-entity expansion and HTML behavior
are unsupported. Scan/expansion caps map to resource-limit diagnostic 114,
instead of the former C-string scan-cap diagnostic 115; invalid text/document
still maps to 115. Guard pages cover rejection before input reads and early
invalid-unit stopping. Public C integration and OOM retry are exercised by
`tests/unicode-test.c` and `tests/oom-test.c`.
`xmlStrQEqual` uses `XML3_Text.QNames.Compare` for raw-byte prefix/name/value
comparison. The proof covers status initialization, NULL-prefix pointer
identity, scalar loop bounds, and the status postcondition relating equality
to NULL/pointer-identity inputs. NULL prefix
delegates the string-equality behavior, while non-NULL prefix comparison
requires non-NULL name/value and a literal prefix, colon, and name through
NUL. Empty prefix returns Different without reading name/value, deliberately
not reproducing the pinned reference's unsafe post-terminator read or its
NUL-then-`:name` tail quirk. Guard-page and tail cases are libxml3-only.
Early mismatches return immediately; equality requiring reads beyond the
`Max_Bytes` scan cap maps to limit error plus zero rather than silent equality.
Native reads, foreign
pointer validity/bounds, actual bytes, address arithmetic, C mapping, and full
equivalence remain trusted. XML-name and UTF-8 validation are not performed.
`xmlStrdup`, `xmlStrndup` and `xmlCharStrdup` delegate to the direct SPARK
`Concatenate_Bytes` path. `xmlCharStrndup` uses `Copy_Byte_Prefix` to scan at
most the requested byte count, stopping at NUL without reading beyond that
count, then calls the shared `Copy_Span` allocator/copier. NULL/negative and
over-limit requests return before any input reads; non-NULL zero-length input
gets an owned empty allocation. No C-string materialization is needed.
`Copy_Byte_Prefix` proves 8 checks.
The SPARK proof checks scalar bounds, written status/result contracts and native
preconditions, not native pointer validity/extents, allocation freshness,
actual bytes/effects, ABI or full public semantics. Raw-byte, guard-page and
free-input→parse-output cases run against the pinned reference; small-cap and
OOM/retry tests are libxml3-only. The reference may allocate `len + 1` even
after an early NUL, whereas libxml3 allocates only the copied prefix and
terminator. Tests compare defined contents, not unspecified spare capacity or
allocation-size equivalence. `Duplicate` remains for internal Ada strings.
`xmlStrchr` uses `XML3_Text.Buffers.Find_Byte` to perform a bounded raw-byte
search and return the first matching non-NUL position. The written
status/position contract and loop bounds are proved; NULL input and search
value zero produce no match without reading. The scan permits a terminator at
the `Max_Bytes` boundary and reports a limit only when no match or terminator
is found within the cap; early matches in longer strings return immediately.
The C adapter maps that position to a borrowed pointer and maps limit or
unexpected failures to error plus NULL. Native byte reads, pointer validity,
readable memory bounds, actual contents, address arithmetic, C diagnostics,
and full public semantics remain trusted. Tests cover byte values, NUL
termination, borrowed-pointer behavior, guard-page boundaries, and no native
allocations.
`xmlStrstr` and `xmlStrcasestr` use `XML3_Text.Buffers.Find_Substring` and the
shared C `Search_Result` mapping. The SPARK contract proves that a match has
non-NULL inputs and a position below `Max_Bytes`, while non-matches leave the
position at zero; loop/read preconditions are discharged. NULL arguments return
no match, and an empty needle returns the non-NULL haystack pointer without
reading the haystack. The scan handles raw bytes through the first NUL,
overlapping aliases, and UTF-8 fragments without validation or transcoding.
The case-insensitive path retains the pinned `[` to `{` byte-map quirk rather
than Unicode case folding. A boundary NUL is accepted, matches ending there
can succeed, and required non-NUL data beyond the cap maps to diagnostic plus
NULL. Early matches avoid a full scan. Native reads, foreign pointer validity
and bounds, actual contents, address arithmetic, C error mapping, borrowed
lifetime, and complete API equivalence remain trusted.
Shared substring vectors, byte-pair comparisons, and guard-page cases run
against both the pinned reference and libxml3; the OOM/no-allocation test is
libxml3-only.
`xmlStrsub` uses `XML3_Text.Buffers.Slice`. SPARK proves its scalar
status/result contract, checked arithmetic/ranges, and native-call
preconditions (12 checks). NULL input and negative indices return no slice
without a diagnostic. Otherwise the helper checks for NUL from offset zero through `start`, even
when `len` is zero; a valid zero-length slice allocates an owned empty result.
It copies exactly `len` bytes after the validated start, including embedded
NUL and following raw bytes, then appends a terminator. This is a readable-span
contract, not clamping at the source string's NUL. The supported subset checks
`start < Max_Bytes` and `len <= Max_Bytes - start` before native reads and
reports a limit error plus NULL when those bounds are exceeded. Native pointer
validity, readable bounds and actual bytes, allocation freshness and writes,
address arithmetic, C status mapping, and full public semantics remain
trusted. Shared slice vectors and guard-page cases run against both the pinned
reference and libxml3; cap and OOM checks are libxml3-only. No XML-name or
UTF-8 validation or transcoding is performed.
`xmlStrncmp` and `xmlStrncasecmp` use `XML3_Text.Buffers.Compare_Bounded`.
SPARK proves bounded loop control and the -255 .. 255 result contract; the
scan accepts the full nonnegative C `int` bound without a `Max_Input` cutoff,
and may stop on an early mismatch or NUL. The case-insensitive byte map
preserves the pinned `A`–`Z` mapping and its
additional `[` to `{` quirk, not general Unicode folding. These routines do
not allocate or convert C strings. `Native.Byte_At`, actual foreign-memory
contents/bounds, pointer validity, and full public semantics remain trusted.
Tests compare all byte pairs and exercise protected-page early exits.
`xmlStrcmp`, `xmlStrEqual`, and the new `xmlStrcasecmp` share
`XML3_Text.Buffers.Compare_Terminated`, which uses the same byte scan. The
terminated comparison accepts identical pointers and NULL ordering before any
native read, then scans offsets 0 through `Max_Bytes` inclusive, stopping at
the first mismatch or NUL. If equal non-NUL bytes remain through the boundary,
the helper reports a limit result and returns -1; the C adapter diagnoses it.
That sentinel is not a reliable ordering result. The ordering APIs return it,
while `xmlStrEqual` maps the error to 0. Unexpected C-side exceptions are also
diagnosed and yield -1 for the ordering APIs and 0 for equality. The
case-insensitive routine preserves the pinned `[` to `{` map quirk without
Unicode case folding, validation, or transcoding. SPARK proves loop bounds,
native-call preconditions, result range, and the cap-failure contract; actual
foreign pointer validity, readable bounds/bytes, C error mapping, and full
semantics remain trusted. Shared byte-pair and guard-page cases run against
both libxml3 and the pinned reference; OOM/no-allocation checks are
libxml3-only. The cap-specific test invokes the Ada helper with a small `Last`;
no public C string near the cap is dynamically constructed.
`xmlStrlen` delegates to `XML3_Text.Buffers.Measure`, using `Read_Length` to
scan through the inclusive bound and accept a NUL at `Last`. NULL succeeds
with length zero. An unresolved scan returns failure with length zero; the C
adapter records DOM error 115 and returns -1, not a reliable empty-string
result. Unexpected C-side exceptions map to DOM error 1 and -1. This bounded
subset uses `Max_Bytes` (`Integer'Last - 16`) and intentionally differs from the pinned reference's zero for lengths
above `INT_MAX`. A reduced `Last` tests this path without constructing a huge
public C string. SPARK proves `Read_Length` (4 checks) and `Measure` (2
checks), including scan bounds, result/status contracts, and native-call
preconditions. Actual native reads/bytes, pointer validity and readable
bounds, C diagnostics/mapping, exception behavior, and complete semantics
remain trusted. Shared raw-byte, Unicode-byte-count, and guard-page tests run
against both implementations; the no-allocation test is libxml3-only.
`xmlCheckUTF8` uses `XML3_Text.Buffers.Check_UTF8` to stream NUL-terminated
input through a four-byte stack buffer, validating each scalar with
`XML3_Text.Validate_UTF8 (XML_Only => False)`. This rejects malformed,
truncated, overlong, surrogate, and out-of-range encodings, while accepting
ASCII controls and Unicode noncharacters; XML character validity is separate.
Existing XML parsing and name/content validation retain their XML-character
checks.
The stricter result intentionally differs from the pinned reference's
permissive acceptance of noncanonical encodings. NULL/malformed input returns
0 without a diagnostic, empty input returns 1, and a boundary NUL is accepted.
If no NUL is found within `Max_Bytes`, DOM error 115 is recorded and 0 returned;
unexpected exceptions map to error 1 and 0. No allocation, mutation, or
transcoding occurs. `Scan_UTF8` implements the shared bounded streaming scan.
`Count_UTF8` delegates to it, and `Check_UTF8` delegates to `Count_UTF8`,
preserving whole-string validity and cap behavior. `Measure_UTF8_Prefix` uses the shared `Scan_UTF8`
loop and stops at the requested scalar count or first NUL. `Scan_UTF8` is
proved for 26 checks, `Count_UTF8`, `Check_UTF8`, and `Measure_UTF8_Prefix` for
1 each, and `Validate_UTF8` for 21. These cover scan/counter control, scalar
and byte-offset bounds, status/result contracts, and native-call preconditions,
not actual foreign bytes, readable bounds, pointer validity, C diagnostics, or
complete API semantics. Reduced-cap Ada tests avoid constructing a huge
public C string. Shared ordinary/malformed and guard-page vectors run against
the pinned reference and libxml3, with invalid-input expectations compared
only for the tested vectors; the no-allocation test is libxml3-only.
`xmlUTF8Strlen` returns the number of Unicode scalar values before the first
NUL, not bytes or grapheme clusters; combining sequences are counted scalar by
scalar and no normalization occurs. Empty input returns 0. NULL, malformed,
truncated, overlong, surrogate, out-of-range, or unsupported UTF-8 returns -1
without a diagnostic, while ASCII controls and Unicode noncharacters count as
valid UTF-8 but are not thereby validated as XML characters. The strict
scanner deliberately rejects malformed forms permissively counted by the
pinned reference, including overlongs, surrogates, out-of-range scalars, and
two-continuation-byte sequences. Failure to find NUL through `Max_Bytes` records
error 115 and returns -1; unexpected exceptions map to error 1 and -1. It
allocates nothing, mutates no input, and does not transcode. Reduced-`Last`
Ada tests cover the cap; no huge public C string is constructed. `Scan_UTF8`
is proved for 26 checks and `Count_UTF8` for 1; these cover counter/loop/index
bounds, status/result contracts, and native-call preconditions, not complete
Unicode API semantics or actual foreign bytes.
Native pointer validity/readable extent and C-side diagnostic/exception
mapping remain trusted. Shared reference/malformed and guard-page tests run
against both implementations with expected permissive-vector results
separated; OOM/no-allocation tests are libxml3-only.
`xmlUTF8Strpos` delegates to `XML3_Text.Buffers.Find_UTF8_Position` and the
shared `Scan_UTF8` scanner. It returns a borrowed pointer at a zero-based
Unicode scalar offset, validating only the preceding prefix. Position zero
returns the input pointer without reading; after a matched prefix, neither the
target scalar nor its suffix is read or validated. At the exact scalar length,
it returns the NUL address without reading that byte. NULL input, negative or
out-of-range positions, and malformed visited prefixes return NULL without a
diagnostic. ASCII controls and Unicode noncharacters are valid UTF-8 but are
not thereby XML-character validated. The strict scanner deliberately rejects
overlongs, surrogates, out-of-range scalars, and five-byte sequences accepted
by the pinned reference. An unresolved scan through `Max_Bytes` records error
115; unexpected exceptions map to error 1. No allocation, input mutation, or
normalization occurs; the returned pointer is borrowed and must not be freed.
Reduced-`Last` Ada tests cover the cap; no huge public C string is constructed.
`Scan_UTF8` is proved for 26 checks and `Find_UTF8_Position` for 1; GNATprove
covers scan control, position/counter bounds, status/result contracts, and
native-call preconditions, not complete Unicode semantics or actual foreign
bytes. Pointer validity/readable extent and C mapping remain trusted.
Shared reference-permissive and guard-page tests run against both
implementations with differing expectations; OOM/no-allocation checks are
libxml3-only.
`xmlUTF8Strsize` uses `XML3_Text.Buffers.Measure_UTF8_Prefix` to return the
raw byte size of up to the requested number of Unicode scalars, excluding the
terminating NUL. NULL input or a nonpositive count returns 0 without reading.
A shorter string returns the bytes before NUL; after reaching the requested
scalar count, the following scalar and suffix are not inspected. A malformed,
truncated, or noncanonical strict UTF-8 prefix returns -1 without a partial
size or diagnostic. Reference behavior for invalid UTF-8 is not guaranteed;
this implementation rejects malformed visited prefixes. ASCII controls and
Unicode noncharacters are valid UTF-8, not XML-character validation. An
unresolved scan through inclusive `Max_Bytes` records error 115 and returns -1;
unexpected exceptions map to error 1 and -1. No allocation, input mutation, or
normalization occurs. Reduced-`Last` Ada tests cover the cap; no huge public C
string is constructed. `Measure_UTF8_Prefix` is proved for 1 check; GNATprove
covers scan control, byte-offset bounds,
status/result contracts, and native-call preconditions, not full Unicode
semantics or actual foreign bytes. Pointer validity/readable extent, actual
bytes, and C mapping remain trusted. Shared malformed/reference and
guard-page vectors run against both implementations; OOM/no-allocation checks
are libxml3-only.
`xmlUTF8Size` delegates lead-byte classification to
`XML3_Text.Buffers.UTF8_Lead_Size`. NULL returns -1 without a read; otherwise
exactly byte zero is read, with no follow-up read or required NUL terminator.
It returns 1 for `0x00..0x7f` (including NUL), 2 for `0xc2..0xdf`, 3 for
`0xe0..0xef`, 4 for `0xf0..0xf4`, and -1 for all other leads. This is not
UTF-8/XML validation: a lone `0xe2` or surrogate-leading `0xed` returns 3
without checking truncation, continuations, or scalar validity. One readable
non-terminated byte is sufficient. Normal results allocate nothing, mutate no
input, and record no diagnostic; unexpected exceptions map to error 1 and -1.
The pinned reference also reads only the lead but assigns widths to invalid
leaders `0xc0..0xc1`, `0xf5..0xf7`, `0xf8..0xfb`, `0xfc..0xfd`, and `0xfe`;
this implementation rejects them. Validation/decoding uses `xmlCheckUTF8` or
`xmlGetUTF8Char`. The guard-page loop places each of the 256 byte values at the
final readable byte before `PROT_NONE`; standalone non-terminated one-byte
inputs and no-allocation behavior are also tested. GNATprove proves 2
`UTF8_Lead_Size` checks for its result/null contract and native-call precondition. These checks do
not establish native bytes, readable extent/pointer validity, C mapping/ABI,
or complete Unicode/API semantics.
`xmlUTF8Charcmp` uses `XML3_Text.Buffers.Compare_UTF8_Character`, whose
contract bounds the result to -255..255 and requires `Result = -1` when
`Invalid`; these contracts do not prove byte-order equivalence or Unicode
semantics. Both NULL pointers return 0; a single NULL returns -1 for a NULL
left pointer or 1 for a NULL right pointer without reading the other pointer.
For non-NULL pointers, only the left lead is classified first; an invalid lead
returns invalid/-1 before reading right. The helper then compares at most the
left lead width (1..4, including NUL width 1) as unsigned bytes and returns the
first nonzero difference immediately, without decoding or validating either
full sequence. Equal bytes alone trigger `Get_UTF8_Char` validation of the
left first scalar before 0, including for aliased pointers. Equal malformed,
truncated, overlong, surrogate, or out-of-range prefixes return invalid/-1
instead of the pinned reference's 0. Thus `E2 x` versus `E3 y` is -1 without
diagnosis and `a` versus `0xff` is -158 without diagnosis. Valid first
characters retain the reference byte difference; suffixes are ignored, with no
case folding, normalization, grapheme matching, or XML-character validation.
The C adapter maps invalid to DOM error 9 (`XML_FROM_TREE` /
`XML_ERR_INVALID_CHAR`) and returns the numeric result; diagnostic allocation
failure may map to standard OOM error 2, and unexpected exceptions map to
error 1 and -1. Normal comparisons allocate nothing and do not mutate either
input, but diagnostics may
allocate. Success preserves any old last error, so callers must reset/check it
when distinguishing diagnosed failure from a legitimate -1. Caller memory
must remain stable/readable through accessed bytes; equality can read the
complete first scalar or NUL even for aliases. There is no cap beyond the
four-byte left width. GNATprove does not establish actual native bytes,
pointer validity/readability/stability, C mapping/ABI, or complete Unicode
behavior. The C/reference tests include 169 valid-character pairs, early
nonzero differences without diagnostics, malformed equal prefixes, aliases,
guard-page boundaries, and diagnostic-allocation failure/retry.
`xmlUTF8Strloc` delegates to `XML3_Text.Buffers.Find_UTF8_Character`, which
measures the pattern's first scalar with `Measure_UTF8_Prefix` using a four-byte
bound, copies that scalar to a local buffer, and passes it to the shared
`Scan_UTF8`. The scanner strictly validates a source scalar before comparing
it and returns the first match before advancing; other existing callers use
the empty default pattern and retain their previous behavior. The C adapter
only maps status, index, and diagnostics. The result is a zero-based Unicode
scalar index for the first occurrence of the pattern's first scalar, not a
byte offset. The pattern suffix and source suffix after a match are ignored.
The first pattern scalar and every visited source scalar through the match are
strictly validated; malformed/truncated/noncanonical prefixes and ordinary
no-match return -1 without diagnostics. NULL either pointer returns -1 without
reading the other. The preserved empty-pattern quirk returns 0 for a nonempty
source after reading only byte zero, without validating it; empty source
returns -1. Normal outcomes allocate nothing or mutate input. Inclusive
`Max_Bytes` exhaustion maps to error 115/-1 and unexpected exceptions to
error 1/-1. Inputs must remain readable and stable through the first pattern
scalar and through the matched scalar or NUL; the matching scalar may end at a
guard page without a terminator. GNATprove covers scan control, scalar-index
bounds, status/result contracts, and native-call preconditions, not native
bytes, readable extent, pointer validity/stability, C ABI/mapping, or complete
UTF-8/API semantics. C/reference and Ada tests cover scalar indexing,
first-scalar-only matching, malformed-prefix divergence, empty-pattern
behavior, DOM lifetime, exact-span guard cases, and no allocation.
GNATprove proves 6 checks for `Find_UTF8_Character` and 26 for `Scan_UTF8`;
these cover result bounds/status and scanner control, not native bytes or
complete UTF-8 behavior.
`xmlUTF8Strndup` delegates through `UTF8_Str_Sub_Copy` to
`XML3_Text.Buffers.Copy_UTF8_Slice` at start zero. That helper finds the start
and delegates the selected prefix to `Copy_UTF8_Prefix`, which validates before
`Copy_Span` creates an independent NUL-terminated allocation. NULL input or a
negative count returns NULL without reads or allocation; a non-NULL zero count
makes a new empty copy without reading input. Positive counts stop at the
requested scalar count or first NUL, leaving the suffix unvalidated. A
malformed, truncated, or noncanonical visited prefix fails before allocation
with NULL, no partial copy, and no diagnostic. The result is caller-owned and
freed with `xmlFree`; input is not mutated or freed. Cap exhaustion maps to
error 115, allocation failure to standard memory error 2, and unexpected
exceptions to error 1. Controls and noncharacters are valid UTF-8, not
XML-character validation; strict malformed-prefix rejection is an intentional
difference from unspecified/permissive invalid-reference behavior.
`xmlUTF8Strsub` also uses `Copy_UTF8_Slice`: `Find_UTF8_Position` validates the
skipped prefix, and `Copy_UTF8_Prefix` validates/copies only the selected span
through `Copy_Span`. NULL input and negative arguments return NULL without
reads/allocation; a start beyond the scalar length returns NULL. Count zero
still validates skipped scalars but does not read the target; start zero/count
zero performs no input reads and returns a fresh empty copy. Starting at the
scalar length returns an empty copy even with positive count. The `Last` cap is
global across skipped and selected bytes, not reset at the start. Malformed
skipped/selected data fails before allocation; suffix after the selected span
is not validated. Returned storage is owned by the caller; input is unchanged.
The pinned reference may skip non-NUL continuation bytes without verifying
them; strict checking is an intentional safety difference. `Copy_Span` and
existing `Slice` prove 6 checks each; `Copy_UTF8_Prefix` and
`Copy_UTF8_Slice` prove 2 each, and `Find_UTF8_Position` proves 1. The shared C
`Slice_Result` maps diagnostics for both UTF-8 adapters outside SPARK proof.
Proof covers scan/span control, bounds, contracts, and native-call preconditions,
not native bytes, readable/stable extents, pointer/offset validity, allocation,
C ABI/mapping, or complete Unicode semantics. Reduced-`Last` Ada tests cover
the global cap; no huge public C string is constructed. Shared malformed/
reference and guard-page vectors run against both implementations; OOM/
no-allocation checks are libxml3-only.
`xmlGetUTF8Char` delegates decoding to `XML3_Text.Buffers.Get_UTF8_Char`, which
reads at most the caller's `*len` bytes and returns one strict UTF-8 scalar.
NULL `utf`, NULL `len`, and `*len < 1` return -1; a writable length is zeroed
on failure, and `*len < 1` causes no input read. NUL returns code point 0 with
width 1; controls and noncharacters are accepted as valid UTF-8. Invalid,
truncated, overlong, surrogate, out-of-range, and unsupported lead sequences
return -1 without a diagnostic. Unexpected C exceptions map to error 1, zero
length, and -1. No allocation, input mutation, transcoding, or XML character
validation occurs.
The strict decoder deliberately rejects the pinned reference's F8..FF
lead-byte masking and its read of `utf[0]` before checking `*len < 1`.
`Get_UTF8_Char` proves 12 checks for scalar control, loop/index/overflow safety,
width bounds, and native-call preconditions; actual input bytes, pointer
validity/readable extent, C mapping, and complete Unicode API semantics remain
trusted. Shared normal, malformed, exact-span guard-page, and permissive
reference vectors run against both implementations with differing expectations
for the latter; the zero-length unreadable-pointer and no-allocation checks are
libxml3-only.
`xmlCopyCharMultiByte` and `xmlCopyChar` use pure `XML3_Text.UTF8_Width` and
`UTF8_Image`, then `XML3_Text.Buffers.Write_UTF8_Char`. GNATprove discharges
1, 25, and 10 checks for those helpers respectively. `Write_UTF8_Char`
checks its bounded loop and contract before calling the existing trusted
`XML3_Native_Memory.Write_Byte`. `XML3_Text.Decode` and
`XML3_Encoding.Decode_UTF16` reuse the shared encoder and prove 65 and 32
checks respectively. These results cover SPARK scalar calculation, bounds,
and written contracts, not native byte contents, output pointer validity or
extent, C ABI, or complete API semantics. Exhaustive scalar round trips,
sentinels, exact-width guard pages, ignored-`len` values, sticky-error
preservation, and no-allocation behavior are tested; the C adapters and native
writes remain outside the proof.

`xmlStrncatNew` uses `XML3_Text.Buffers.Concatenate_Bytes` directly without
C-string conversion. It obtains the effective right length first, then measures
the left under the remaining cap. Excessive positive lengths fail before reading
either input; a combined overflow fails before copying the right span.
`Concatenate_Bytes` proves 6 checks and `Copy_Pair` proves 9 checks. `Copy_Pair`
shares fresh allocation and raw-span copying with `Build_Append`,
but this API never frees its inputs. The String-based `Concatenate`/`Fits`
remain available for Ada `Duplicate`. Scalar bounds and written contracts are
checked; native allocation, pointer validity/readable extents, actual bytes and
effects, ABI and complete public semantics remain outside proof. Raw-byte,
guard-page and lifecycle cases run against the pinned reference; bounded-failure
and OOM cases are libxml3-only.
`xmlStrcat` and `xmlStrncat` use `XML3_Text.Buffers.Append`, whose
`Read_Length`/`Build_Append` helpers scan bounded lengths, allocate a fresh
result, copy the selected raw-byte spans and append NUL. `Append` frees the old
`cur` unless the status is `Unchanged`. NULL `add` and bounded length zero are
no-ops before negative-length handling; a negative length with non-NULL `add`
returns NULL without a diagnostic and consumes `cur`. Positive bounded spans
copy exactly the requested byte count, including embedded NUL. The append
result is independent and `xmlFree`-owned; `cur` must be NULL or a caller-owned
free-compatible allocation base, not a literal or borrowed DOM pointer, and
must not be reused after a consuming call.
Allocating before copying and freeing avoids the reference realloc alias
hazard when `add` points into `cur`; always-copy can increase peak memory and
copy work. `xmlStrcat` scans `add` first and bounds prefix scanning by the
remaining `Max_Bytes`; a NUL at the boundary is accepted, while an unresolved
scan reports DOM error 115. `xmlStrncat` rejects lengths above the cap before
reading either source. Cap failures return diagnostic NULL and consume `cur`;
OOM uses the existing diagnostic and also consumes `cur`. SPARK proves
`Read_Length` (4 checks),
`Build_Append` (6), `Concatenate_Bytes` (6), `Copy_Pair` (9), `Append` (1), bounded arithmetic, native-call
preconditions, and status/result contracts; actual native reads/writes,
allocation freshness/free, pointer validity, caller ownership, C mapping, and
complete API semantics remain trusted. Shared ordinary/null/empty/raw-span/
negative/parse and guard-page cases run against the reference and libxml3;
alias/cap/OOM/free-count cases are libxml3-only.
Namespace searches through `xmlSearchNs` / `xmlSearchNsByHref` route through
`Runtime.Search_Namespace` / `Store.Queries.Lookup_Namespace`, which composes
the pure `Search_Namespace` query with lazy XML-binding creation for
documentless managed nodes. The pure query remains the qualified-property
rollback path. C adapters and libxml2 semantic equivalence, including
append-versus-prepend declaration ordering, remain outside the proof.
Both C adapters now forward native search values to the native
`Lookup_Namespace` overload. Registration is checked before input measurement;
`Measure` and `Read_String` create a SPARK-local input before invoking the
existing String lookup. NULL values remain distinct from empty strings, and
NULL nodes retain the C no-op diagnostic behavior. The ignored document argument,
guarded search input, ancestor shadowing, implicit XML reuse, source protection,
serialization/reparse/editing and aliased namespace-field queries are tested.
Native readable extent/stability and byte effects remain trusted, not proved.
Unregistered nodes now report code 115 instead of a silent NULL; failed input
measurement retains code 115, while ordinary no-match leaves diagnostics unchanged.
GNATprove proves 11 checks for the native `Store.Queries.Lookup_Namespace`
overload (with 1 analyzer warning), 13 for its existing String overload, and 1
for `Runtime.Search_Namespace`.
Namespace-list collection through `xmlGetNsList` / `xmlGetNsListSafe` routes
through `Runtime.Get_Namespace_List` / `Store.Queries.Get_Namespace_List` and
`Collect_Namespaces`. Its bounded two-pass Store traversal selects explicit
declarations from managed node ancestry, deduplicates prefixes nearest-first,
and excludes implicit bindings and namespace references that are not declared
in scope. It ignores `doc` and returns a caller-owned array of borrowed
namespace pointers. The SPARK proof includes traversal, capacity, status and
cleanup checks; native address allocation/writes, C array representation,
pointer validity, and complete public semantics remain outside the proof.
`xmlNewNs` forwards native href/prefix addresses through `Runtime.Create_Namespace`
to the native overload of `Store.Create_Namespace`. Non-NULL elements are checked
against the registration table and element kind before either input is read.
`Measure` bounds each NUL-terminated input, then SPARK Strings feed the unchanged
namespace constructor, duplicate-prefix checks, attachment and rollback path.
NULL and empty href/prefix remain distinct. No intermediate C String is built.
Tests cover both guarded inputs, NULL/empty combinations, copying from another
namespace followed by its release, serialization/reparse/editing and invalid-node
read avoidance. Native pointer validity/extents/stability, allocation/byte effects,
ABI and complete public semantics remain trusted.
GNATprove proves 14 checks for the native `Store.Create_Namespace` overload and
0 for `Runtime.Create_Namespace` (the existing String overload proves 30).

`xmlCopyNamespace` routes through `Runtime.Copy_Namespace` /
`Store.Copy_Namespace`: the Store resolves a live managed namespace facade,
copies stored href/prefix byte spans independently while preserving NULL versus
empty fields, then delegates detached reservation creation to the existing
constructor. Source `next`, `context`, and `_private` fields are omitted.
Proof covers Store identity, span selection, status/result contracts, and
constructor control flow; native reads/writes and allocation, C/native pointer
validity and layout, ABI details, and complete public semantics remain outside.
Reference comparison covers returned namespace values and links; the
node-pin-lifetime scenario and OOM injection are libxml3-only tests.
`Compare_UTF8_Character` proves 1 check for its result-range and invalid-status
contract, not full byte-order or Unicode equivalence. The QName proof includes
5 checks for `Locate_Prefix` (bounds and its written output/status contract),
18 for `Build`, 2 for `Overlaps`, 8 for `Compare`, 10 for `Prefix_Length`,
and 6 for `Split`.
`Locate_Prefix` does not prove native byte contents or `Native.Offset` pointer
semantics. `XML3_Text.Buffers.Read_Length` has 4 checks and `Measure` has 2.
`XML3_Text.Buffers.Case_Map` has 1 check,
`Compare_Bounded` has 1, `Compare_Scan` has 4, `Compare_Terminated` has 1,
`Concatenate` has 12, `Duplicate` has 1, `Find_Byte` has 3,
`Find_Substring` has 8, `Fits` has 0, and `Slice` and `Copy_Span` have 6 each.
The 765 entity
summaries report 0 flow errors, 191 warnings, and 0 `pragma Assume`
statements; warnings are not counted as discharged verification conditions.
The `Unescape_URI` warning notes that the initial value of `Span` has no
effect because the value is assigned by the bounded length branch before use.
The two `Escape_URI` warnings note that `Found`'s initialization has no
effect and its returned search position is not used; membership is determined
by `Find_Byte`'s status.

**Analyzer caveat:** generation of representation information for the trusted
`xml3_dom_allocation.ads` spec failed (`cannot generate code for file ...
(package spec)`); GNATprove continued with partial representation data. This
warning is not resolved by the successful proof. Native representation/layout
is outside the claim. One additional benign warning reports that the
initialization of `Existing` in `Store.Properties.Add_Property` has no effect,
because `Find_Matching_Property` initializes that `out` parameter before use.
Trusted external-termination warnings also remain. The string-duplicate,
namespace-list, namespace-copy, QName, substring-search, and slicing paths
include trusted termination
diagnostics for native reads, allocation, writes and frees; an unreachable/no-effect
diagnostic also remains for the portable pointer-array size guard on this 64-bit
host. The workspace unit adds eight such native-call diagnostics: four for
`Allocate` and four for `Free`. These are distinct from the 181 per-entity
analyzer warnings above and do not prove allocator side effects.
The `Get_Path` entities contribute 11 warnings: one input-mode warning on the
Runtime wrapper, unused helper outputs, and trusted native-call termination
warnings. They do not represent unproved checks.

The unedited analyzer summary is in [proof-summary.txt](proof-summary.txt).
This is a proof of the selected SPARK units and their written contracts, not
of the entire C ABI, native memory layout, synchronization implementation, or
full XML conformance. Public DOM APIs now delegate to the SPARK Store/Runtime;
the adapter and the native boundary remain trusted. See [assurance.md](assurance.md).

| Category | Checks |
| --- | ---: |
| Data dependencies | 558 |
| Initialization | 1,065 |
| Non-aliasing | 1 |
| Runtime checks | 6,283 |
| Assertions | 1,839 |
| Functional contracts | 4,998 |
| Termination | 411 |
| **Total** | **15,155** |

The analyzer's counts are verification conditions, not vulnerabilities, test
cases, or supported APIs. `Parse`, `Decode`, namespace `Resolve`, and
`Decode_UTF16` have explicit `Always_Terminates` aspects; the implicit
termination of `XML3_Text.Valid_Name` is also proved from its loop variants.
Termination is not a wall-clock or resource bound.

## Reproduction

The current record was produced on Ubuntu 24.04.5 x86_64 (glibc 2.39); earlier
records were verified on Ubuntu 22.04.5 x86_64 (glibc 2.35). Both use the Alire packages
`gnat_native=14.2.1`, `gprbuild=26.0.1`, and `gnatprove=14.1.1`.
The compiler banner is 14.2.0; the analyzer reports `0.0w`, while 14.1.1
identifies its pinned package. Bundled Why3 is 1.6.0+git, cvc5 is 1.1.2,
and Z3 is 4.13.0. The recorded full proof uses these increased-time switches
through `make prove-units`, not the default `make prove` target:

```sh
make prove-units          # clean start, one unit at a time
make prove-units-resume   # continue an interrupted run
```

Each unit is analyzed with
`gnatprove -P proof.gpr --mode=all --prover=cvc5,z3 --timeout=120 --memlimit=4096 -j4 -u <unit>.ads <unit>.adb`.

`proof.gpr` sets `--level=2 --report=all --checks-as-errors=on` and enables
assertions independently of the production profile. Unproved checks must
fail the command. No assumptions, proof exemptions, weakened contracts, or
new SPARK-off DOM logic were introduced. The aggregate uses the existing
proof session; it is not a cold-cache performance claim. The output is
`obj/proof/gnatprove/gnatprove.out`.

The project contains nineteen complete SPARK units: text, text buffers, QName,
parser, namespaces, encoding, DOM, bridge, constructors, Store, Store.Content,
queries, properties, documents, serialization, Runtime, import, materialize,
and the serialization core. Two trusted specs, native memory and DOM
allocation, bring the analyzer's unit count to twenty-one. Their bodies are not
proved: four allocation bodies and fifteen native-memory bodies are explicitly
`SPARK_Mode => Off`. All nineteen SPARK units were fully analyzed. The C
adapter, mutex/controlled guard, and error handling are not in
the proof project. Native layout/freshness, pointer validity, allocator and
thread-runtime correctness are assumptions, not consequences of ID equations.

## Verified implementation path

Public parsing follows `Runtime.Read → Documents.Read → Parse → Resolve →
Materialize.Build → Store.Adopt_Arena → Import.Adopt → Synchronize`.
`Discard_Arena` retires an unpublished source after failed adoption and then
releases its backing state. Failed adoption leaves that source valid and
caller-owned until cleanup. Errors remain distinct from memory exhaustion.

`Materialize.Has_PI_Data` distinguishes a PI with no data from a separator
followed by empty data by comparing the parser's `Value_First` position with
the target's `Name_Last`. The predicate is shared by `Add_Node_Budget` and
`Fill_Node`: absent data remains a NULL content pointer without an
arena terminator allocation, while present-but-empty data receives an owned
empty string. This preserves the distinction during parse, serialization,
and reparsing without a serializer or C-adapter special case.

`xmlDocDumpMemory` delegates to `xmlDocDumpMemoryEnc` with NULL encoding, and a
NULL encoding passed to `xmlDocDumpMemoryEnc` selects the same default mode.
The two format variants share that adapter and pass the scalar format flag as
a Boolean through Runtime and Store into `XML3_Serialization.Render`. All four
APIs reach the same SPARK serializer. Runtime/Store pass the encoding address
without C-string conversion. Store compares registered live document facades
before reading encoding, including rejecting unregistered/wrong-kind pointers
without dereferencing them. `Read_UTF8_Name` uses at most six native byte reads
and stops at the first mismatch; a fixed five-character field preserves case.
Its `Matches_UTF8_Byte` predicate is shared with the renderer's String check.
NULL selects default mode in Store; empty/unsupported names and suffixes fail
without fallback. Guard pages cover short names, invalid prefixes/suffixes,
valid names ending at the page boundary, and unreadable document/encoding
pointers; all eight ASCII-case combinations preserve their spelling. The
round-trip test frees the encoding name and source document before reparsing.
The unformatted APIs and `format=0`
retain compact output. Any nonzero format value, including negative values,
enables two-space indentation capped at 60 spaces. Before descending, the
serializer scans an element's immediate children; a direct Text or CDATA child
(including whitespace-only Text) suppresses indentation and inserted newlines
throughout that element subtree, then formatting resumes for following
siblings. The serializer does not mutate the DOM, but inserted output
whitespace becomes Text if the result is reparsed.

The default encoding mode omits the encoding declaration and emits non-ASCII
scalar text, attribute values, and namespace URIs as uppercase hexadecimal
character references; names, comments, processing instructions, and CDATA
retain raw UTF-8. `Render` reads immutable Store state, validates and measures
iteratively before allocation, then emits through the same traversal into an
exact-size native buffer. GNATprove reports 1 check for Runtime
`Dump_Memory_Encoding`, 7 for Store `Serialization.Dump`, 3 each for
`Read_UTF8_Name` and `Matches_UTF8_Byte`, 4 for `Is_UTF8`, and 9 for `Render`.
Within `Render`, `Put_Character_Reference` has 1 check, `Emit_Text` has 17,
and `Pass` has 23, including the formatting traversal. These SPARK checks and
written contracts do not prove native pointer readability, complete XML
conformance, or libxml2 lexical equivalence. Native
allocation, pointer extents/stability, mutex behavior, and native
byte reads/writes remain trusted. The C adapter handles pointer/scalar/null
conversion, output initialization, lock acquisition, and status/exception
mapping. Source encoding and standalone metadata are not retained; default
output therefore does not restore the parsed source encoding.

`xmlNodeAddContent` and `xmlNodeAddContentLen` use the same
`Runtime.Add_Content` and `XML3_DOM_Store.Content.Append` path, whose Store
contract requires and restores `Ready (S)`. C forwards addresses/length/mode;
Store validates the registered facade before measuring native input via
`Measure` or `Measure_Byte_Prefix`. Store derives `Has_Input` to distinguish a
positive-length leading NUL, which materializes empty text/content when needed,
from a zero/nonpositive-length or NULL-input no-op. Raw bytes are not decoded;
foreign-pointer readability/extents/stability and native byte effects remain outside GNATprove.
Guard-page checks, empty-text allocation failure/retry, and UTF-8 split-append
repair are runtime evidence, not additional formal claims.
The private `Replace_Content` helper requires a non-pending projection and
explicitly postconditions a non-null, valid, editable Store with projection
complete and facades present. Its frame preserves node and namespace counts,
unrelated live node views, and all target-node fields other than content
address, length, and pin on success; a non-success status leaves the target
node unchanged.
It accepts native spans for both append and scalar replacement; the obsolete
String path has been removed.
Append copies old content and the measured suffix into a fresh owned buffer
before projection/pin updates, keeping aliased old content live until both
copies finish. Creating a trailing text child reuses `Create_Node`'s native
span path. There is no intermediate input String in either append path.
Serialization tests cover guarded exact-count/terminated inputs, source
protection before serialization/free/reparse/editing, native self-aliasing,
invalid-facade/kind read avoidance and NULL/zero/nonpositive-length distinctions.
GNATprove proves 36 checks for `Store.Content.Append`, 67 for private
`Replace_Content`, and 1 for `Runtime.Add_Content`. `Store.Content.Set` proves
34 checks and `Runtime.Set_Content` proves 1.
`xmlNodeSetContent` routes through `Runtime.Set_Content` and
`XML3_DOM_Store.Content.Set`. C forwards addresses and the original integer
length; Store validates the registered facade before native measurement.
Scalar input uses the shared native-span replacement helper without an
intermediate String. Element/Attribute input is copied into SPARK buffers and decoded before
mutation; the replacement text child is attached before old children are
retired. The `Retained_Ancestor` ghost lemma relates current live ancestry to
the original state for the iterative namespace-aware retirement frame.
`Retire_One_Element_Child` requires a live element and child, valid sibling
links, and `Child /= Keep`; its postcondition frames the element's child
endpoints and the retained child's sibling links while preserving counts,
capacity, Store validity, and facade/owner guarantees. The `Replace_Content`
frame preserves unrelated live nodes and, on success, changes only the target
content address, length, and pin. No element-wise namespace-entry frame is
claimed. Runtime tests cover append and replacement semantics, decoding,
aliasing, facade and detached namespace-owner lifetime, and allocation-failure
rollback/retry; those are test evidence, not formal claims.

`xmlNodeSetContentLen` uses `Measure` for negative lengths and
`Measure_Byte_Prefix` for bounded nonnegative lengths in Store. NULL input
skips measurement and length rejection; zero length never reads the input.
Unregistered facades and oversized non-NULL input lengths fail before input
reads. Native pointer readability/extents/stability, byte effects, allocator,
ABI and complete public semantics remain trusted boundaries. Runtime tests
exercise guarded bounded/terminated input, source protection followed by
serialization/free/reparse/editing, scalar self-aliasing, and replacement
from content in a child that is then retired.
The pinned reference parser reads `content[0]` even when `len` is
zero, so the guard-page case is library-only; the safe empty-value behavior is
test evidence, not a formal pointer-safety claim.

`xmlNewChild` routes through `Runtime.New_Child` and
`XML3_DOM_Store.Content.New_Child`. The Store helper requires and restores
`Ready (S)` and postconditions that the result is non-null exactly on
`Created`. The implementation decodes content before constructing nodes,
constructs the element and optional text child, attaches the text before
attaching the element to its parent, and releases unpublished nodes on failure.
These helper contracts do not claim full API-level rollback or libxml2 semantic
equivalence; namespace inheritance, construction behavior, and failure
preservation are covered by tests.

`xmlNewTextChild` uses the same helper and contract through a raw-content mode.
The Store measures input and copies it directly into owned storage; it does not
decode references or validate XML/UTF-8 in this mode. A text child is created
when content is non-NULL, including an empty string; NULL content creates no
text child. Its `Ready (S)` and result/status guarantees do not claim full
API-level semantic proof. Raw reference preservation, NULL/empty distinction,
namespace behavior, serialization rejection and repair of invalid content,
detached-parent lifetime, and allocation-failure retry are test evidence.

`xmlNewTextLen` selects `Text_Node` in the shared
`Runtime.New_Doc_Content` / `Store.Content.New_Doc_Content_Bytes` path. SPARK
rejects negative lengths only when content is non-NULL, then measures the raw
prefix with `Measure_Byte_Prefix` and copies it into shared owner storage. NULL content
remains NULL for any length; a non-NULL zero-length input creates empty content
without reading the pointer. Embedded NUL ends the retained prefix. Pointer
validity and actual byte effects remain outside GNATprove; guard-page, NULL/empty,
serialization, detached-node, and allocation-failure cases are runtime
evidence for the API wrapper, not a pointer-safety proof claim.

`xmlNewDocText`, `xmlNewDocTextLen`, `xmlNewDocComment`, `xmlNewDocPI`, and
`xmlNewCDataBlock`
route through `Runtime.New_Doc_Content`, `Store.Content.New_Doc_Content_Bytes`,
and the existing `XML3_DOM_Store.Content.New_Doc_Content`. The shared Store operation accepts
text, CDATA, comment, PI, and empty element kinds, requires and restores `Ready (S)`, and relates a
non-NULL result to `Created` status. It validates a non-NULL document before
constructing the node, re-finds the document and new node after construction,
then uses the existing `Set_Node_Projection` contract to set `Document` and
`Doc_Pin` without attaching the node as a child. The projection contract
preserves owner reference invariants; failed affiliation releases the
unpublished node. The C constructors share one private `New_Content_Node`
helper for address/mode forwarding, locking, status reporting, and exception mapping;
this removes the duplicate document-text adapter but does not move graph or
ownership decisions into C. PI target and content
scan bounds and size/status relations are in SPARK. Native readability, input
stability, byte effects and ABI remain trusted. These existing contracts do not establish complete
public API semantics or rollback; NULL/bounded input behavior, document
validation, unattached construction, serialization, document-first release,
and allocation-failure retry are runtime evidence. Registration callbacks and
native PI dictionary interning are unsupported.

`xmlNewDocNode` / `xmlNewDocRawNode` use `Runtime.New_Doc_Node` and
`Store.Content.New_Doc_Node`. This operation reuses `New_Doc_Content` for an
empty element with an explicit namespace, then constructs and attaches a text
child when required. `New_Child` delegates its construction phase here before
attaching the unpublished element to the parent; `xmlNewNode` delegates to the
same documentless path. Decoding/raw handling, affiliation, namespace pins and
failure cleanup remain in SPARK, with no parallel C ownership logic. The new
operation's contract restores `Ready` and relates result/status; full public
API behavior, reference semantics and C pointer validity remain outside the
formal claim. Runtime tests cover decoded/raw input, copied names and content,
NULL/empty distinctions, subtree document affiliation without attachment,
namespace retention after document-first release, and allocation-failure retry.

`xmlNewDocProp` uses `Runtime.New_Doc_Node` / `Store.Content.New_Doc_Node`
with the attribute mode to create a detached, unnamespaced property. The SPARK
path owns document affiliation, value-reference decoding, child construction,
and failure cleanup; the C adapter selects the mode, forwards addresses, locks,
and maps statuses/errors without traversing DOM fields.
The tested NULL/empty behavior, document-first attribute lifetime, rejected
invalid references/names, and OOM preservation are runtime evidence. Managed
attributes can be attached to an element through `xmlAddChild`, subject to the
same-document/documentless restriction; the API's complete C semantics, native
pointer validity, and ABI are not formally proved.

`Store.Add_Child` dispatches managed attributes to
`Store.Properties.Add_Property`; `Store.Queries.Find_Matching_Property` compares
local-name bytes and namespace-href bytes. A null namespace is distinct from a
namespace object, and a non-null namespace with a null href is rejected.
Re-adding the parent's last attribute is a no-op even when an earlier duplicate
exists. Otherwise the matching attribute is released only after the incoming
attribute attaches successfully. Core attachment still rejects cross-document
moves, preserving both attributes. `xmlUnlinkNode` also supports detaching a
managed attribute while retaining its value, document affiliation, namespace,
and owner pin. Namespace reconciliation and detached-attribute serialization
remain unsupported. These Store checks do not establish full public C semantics
or native-boundary safety.

`xmlAddSibling` delegates from the shared C `Add_Node` adapter through
`Runtime.Add_Sibling` to `Store.Add_Sibling`. The Store resolves both managed
facades, rejects self-insertion and attribute/content kind mismatches, requires
a live managed parent, and delegates to `Store.Add_Child`. The aggregate
includes the Store/Runtime path, but does not prove full public C semantics,
native links or ABI, mutex behavior, or pointer validity. Pinned-reference
tests cover supported append/reorder, tail no-op, text coalescing, and
expanded-name attribute replacement; safety and lifetime extensions are
library-only runtime tests.

`xmlAddPrevSibling` and `xmlAddNextSibling` dispatch through
`Runtime.Insert_Sibling` to `Store.Insert_Sibling`; the SPARK core
`XML3_DOM.Insert_Sibling` proves 80 checks, the Store operation proves 10, and
the Runtime operation proves 1. The verified core uses the existing attachment
path followed by direct tail placement and proves its written graph-preservation
contracts. Native pointer validity, ABI mapping, synchronization, and complete
public C semantics remain outside the proof.

`xmlNewCDataBlock` selects `CData_Node` in the same C/Runtime/Store path. The
core `Create_Node` postcondition explicitly guarantees a null `Name` address
and zero `Name_Length` for CDATA; this is a specific proved projection
guarantee, not a full API semantics claim. SPARK rejects a negative
length before reading non-NULL content, then performs the shared bounded-prefix
scan. NULL content is accepted at any length, and zero length does not read the
pointer. Native pointer validity and actual byte effects remain outside GNATprove. Copying,
NULL/empty distinction, CDATA delimiter splitting and serialization/reparse,
invalid UTF-8 rejection and repair, document-first release, and OOM retry are
runtime evidence for behavior rather than complete semantic proof.

`xmlNodeIsText` / `xmlIsBlankNode` use `Runtime.Test_Node` / `Store.Queries.Test_Node`.
Runtime declares both managed state and foreign memory as `Input`; the Store
query does not mutate the graph or allocate content. Its failure postcondition
requires a false result. Kind checks and XML-whitespace scanning occur in SPARK,
bounded by managed content length. Native byte access remains trusted.
Tests cover text versus CDATA, NULL/empty/XML-only whitespace,
non-XML whitespace, other node kinds, mutation-driven classification changes,
document-first release and rejection of unmanaged facades. These are runtime
semantic checks, not a claim of complete C API proof. Common cases also run against
the pinned reference; document-first release and unmanaged facades are
library-specific checks.

`xmlIsChar`, `xmlIsBlank`, `xmlIsBaseChar`, `xmlIsCombining`, `xmlIsDigit`,
`xmlIsExtender`, `xmlIsIdeographic`, and `xmlIsPubidChar` use the pure
`XML3_Text.XML_Char`, `XML3_Text.XML_Blank`, `XML3_Text.XML_Base_Char`,
`XML3_Text.XML_Combining`, `XML3_Text.XML_Digit`, `XML3_Text.XML_Extender`,
`XML3_Text.XML_Ideographic`, and `XML3_Text.XML_Pubid_Char` classifiers. The
helpers are analyzed in SPARK; proof output has no checks for the first seven
and one proved check for `XML_Pubid_Char`. The exported C adapters, narrowing
boundary, ABI, and complete upstream semantics remain outside the proof.
Runtime tests sweep code points through U+110000, check unsigned high values
and ensure current NCName behavior is unchanged; the no-allocation OOM
operation checks the native allocation counter. `XML_Base_Char` uses the
pinned historical 197 short ranges plus five ranges below U+0100 and excludes
U+4E00; `XML_Combining` uses the pinned 95 short ranges and excludes U+0346.
These fixed historical sets are not current Unicode categories or current
NCName rules (U+037F and `a` followed by U+0346 remain accepted), nor a DTD
subsystem. Only the function symbols are implemented; header macros and
range-group APIs remain unsupported.

`xmlIsXHTML` is implemented by `XML3_Text.Buffers.Is_XHTML`, using the bounded
`Matches_Literal` helper for exact NUL-terminated byte comparisons. The proof
summary reports 7 checks for `Is_XHTML` and 5 for `Matches_Literal`. The
function checks both-NULL before matching the three known XHTML 1.0 public IDs
first and the three system URIs second; a public match skips the system ID.
The C adapter only converts the integer result. UTF-8 validation, URI
resolution, DTD loading and HTML parsing are not performed. Runtime tests cover
the return matrix, truncated prefixes, guard-page boundaries, and a matched
public ID with an unreadable system pointer; these do not prove native pointer
validity or full public C semantics.

`xmlNodeGetLang` / `xmlNodeGetSpacePreserve` use
`Runtime.Get_Inherited_XML_Property` / `Store.Queries.Get_Inherited_XML_Property`;
setters forward addresses through `Runtime.Set_XML_Property` to
`Store.Properties.Set_XML_Property`, then reuse `Set_Qualified_Property`.
The native entry validates the registered element and kind before measuring
language input with `Measure` and copying it into a SPARK String. NULL language
sets an empty value rather than deleting the attribute; space mode uses only
constant values (zero→default, nonzero→preserve). The existing qualified-property
Ready/ownership/namespace rollback paths are unchanged. No language String is
constructed in C. Tests cover guard-page input, inherited lookup after source
protection, serialization/free/reparse/editing, aliased old attribute content,
invalid-facade/kind read avoidance and raw invalid UTF-8/XML storage followed by
serialization rejection and repair.
The Store owns the bounded parent walk, node-kind and exact XML-namespace checks,
space-value comparison and temporary-buffer cleanup. The C adapters only
convert inputs/outputs, lock and map status. Focused inherited-value, setter,
reparenting, serialization, copy-lifetime and OOM rollback tests are runtime
evidence, not complete semantic proof of the public APIs or native boundary.
GNATprove proves 16 checks for `Store.Properties.Set_XML_Property` and 1 for
`Runtime.Set_XML_Property`.

`xmlTextConcat` reuses `Runtime.Add_Content` / `Store.Content.Append` with a
scalar-only policy checked before input reads and the empty-input no-op. Existing
`Replace_Content` contracts preserve unrelated nodes and the target on failure,
and restrict successful target changes to content, length and content pin.
The C adapter shares address/length/mode forwarding, locking and result mapping;
it performs no DOM traversal. Scalar kinds, NULL/empty input, bounded and negative
lengths, aliasing, guard pages, retained document lifetime, serialization/reparse
and native OOM retry are runtime evidence, not a complete public semantic proof.

`xmlTextMerge` uses `Runtime.Merge_Text` / `Store.Merge_Text`, also shared by
`Add_Child` coalescing. The Store contract restores `Ready` and relates a successful result to the
first non-NULL operand and returns NULL on failure. For non-NULL content the
existing core `XML3_DOM.Merge_Text` contract guarantees target content/pin,
target parent preservation, source tombstoning and valid state. Source NULL
content instead uses the normal release path without replacing target bytes.
Native buffer allocation precedes graph mutation. This is not a complete
public semantic/atomicity proof: nonadjacent and attribute text, NULL/empty
distinctions, retained document lifetime, allocation-failure state preservation
and retry are covered by C regression tests. Cross-document source affiliation
and no-escape text variants remain unsupported; the native boundary is trusted.

`xmlLastElementChild` and `xmlPreviousElementSibling` extend the existing
`Store.Queries.Select_Element` with reverse traversal over `Last_Child` and
`Previous`. Node-kind filtering and bounded scanning execute in SPARK; the
C selector is shared with root/first/next queries and performs no native-link
traversal. The existing contract relates failed status to NULL result/zero
count; nearest-element selection semantics are runtime-tested, not claimed as
fully proved. Tests include mixed non-element siblings, detach/reinsert,
document and attribute inputs, and retained subtree navigation after document
release. No ownership mutation or result allocation is introduced.

`xmlGetLastChild` uses the same `Select_Element` Store/Runtime path with
`Last_Child_Node` mode. Store resolves the facade and returns its live managed
last child without filtering node kind; the C adapter uses the shared selector
and reads no native `last` field. Document children and attribute-value text
are included. Runtime tests cover node kinds, empty and unsupported inputs,
unlink/reappend and replacement, detached-tree lifetime, and zero native
allocations. The aggregate includes the SPARK selection unit and its written
contracts, not complete public API semantics or native pointer validity.

Public construction, root replacement, attachment/text merging, unlinking,
release, namespace creation/assignment/free, namespace-qualified property
mutation and read-only queries use the same Store. `xmlNewComment` and
`xmlNewPI` use the same `New_Doc_Content` Store/Runtime operation as their
document-affiliated counterparts.
Constructed namespaces retain one owner reservation; parsed declarations use
their document arena.
Subtree release detaches declarations before retiring their elements, while
borrower pins keep the native storage alive. Qualified `xmlSetProp` resolves
validated QNames in Store and rolls back implicit XML declarations on failure.
Property lookup/content retrieval and lookup/removal each execute as
one Runtime operation. A trusted pthread mutex serializes these operations;
there is no legacy fallback. `GNAT.Threads` forces the tasking runtime so
foreign pthreads have separate secondary stacks and exception state.

The DOM invariants cover bidirectional links, ranks/cycle prevention, document
propagation, reference counts versus actual holders, namespace ownership,
rollback and release ordering. The Store validates live IDs and facade
identity. Those checks do not make arbitrary foreign pointers safe to read.

The bridge projects native fields before emitting a release, calls native
free, then acknowledges. IDs cannot be reused before acknowledgement. Releasing
namespace fields are cleared first. Native projection avoids storing unchanged
fields; this avoids unrelated writes into an independently used document.
Caller synchronization is still required for borrowed pointers to the same
mutable document and for concurrent release.

`Ancestor_Descent` separates the recursive ghost calculation from its wrapper
contract. `Prepare_Subtree` uses the existing `Leaf_Ancestor_Lemma` to mark
only the root when it has neither children nor properties; non-leaf behavior
is unchanged. The same graph/rank/mark contracts remain. This removes repeated
ancestor walks during incremental leaf construction without weakening proof.

## Execution profiles and regression evidence

Production uses `-O2 -gnato` without `-gnata`; explicit validation, range and
integer-overflow checks remain. Development keeps `-gnata -gnato -g` and a
separate object/library directory. `proof.gpr` and core/bridge unit tests
remain assertion-enabled. No `-gnatp` or assertion-policy suppression is used
to discharge proof obligations.

The focused comment/PI construction tests passed:

```sh
make tests/serialization-test tests/serialization-test-reference
LD_LIBRARY_PATH=lib ./tests/serialization-test --misc
LD_LIBRARY_PATH=build/reference/lib ./tests/serialization-test-reference
```

They cover constructed top-level and child comments/PIs, raw input copying,
NULL and empty content, Unicode, reparsing, invalid comment/PI text and
reserved PI targets, output failure followed by removal/retry, and detached
node lifetime after freeing the document. The pinned libxml2 2.15.4 reference
build runs the shared exact-output cases, including constructed comments/PIs.

`make test-content-edit` passed for both the library and pinned libxml2 2.15.4
reference builds. The `dom-new-child` and `dom-new-text-child` OOM walks each
injected failures at both allocation sites and passed the successful retry.
The development content-edit build and test also passed.

```sh
make -k test-development test-oom test-dom test-api test-serialization \
  test-sanitize check check-inventory
```

The full command passed. It includes development and sanitizer content-edit
tests; serializer tests passed in both library and reference builds. The
inventory check's Python suite reported five passing tests, and `make inventory`
regenerated API coverage successfully. Clang printed its existing deprecation
warnings for `SAX.h`, `nanoftp.h`, and `xmlunicode.h`.

Regression coverage includes connected parse/edit/query/release and Store
reuse, two-document preservation, detached subtree lifetime after source
document release, literal/duplicate/null/empty property values, merge rollback,
native fields and document links, and invalid-input diagnostics. The stronger
detached-lifetime assertion is intentionally excluded from libxml2 reference
runs rather than reproducing unsafe reference behavior.

Native bridge tests wrap allocation/free to check exactly-once cleanup and
projection-before-release. The Documents regression fails Store allocation
after successful materialization, checks that every unpublished allocation
was freed once, and successfully reuses the Store. Public OOM walks exercise
allocation failures and state preservation. Lock tests cover exceptions and
injected lock/unlock errors. A 1 MiB string-allocation failure checks that the
exported wrapper catches the exception. Read-only mmap pages check that
identical node/document/namespace projection performs no writes.

Independent pthread tests inspect native fields and query/mutate separate
documents; they do not intentionally race read/free on the same facade. The
production pthread regression also passed twenty separate invocations during
the earlier tasking-runtime fix; that twenty-run probe was not repeated here.
Tests are evidence for the trusted boundary, not a
formal proof of it. ASan/UBSan instrumentation applies to the C test side;
the Ada library is not thereby fully sanitizer-instrumented.

An earlier local diagnostic probe (not repeated for this change) constructed
and attached a 12,000-node chain in
1.685536 s of construction plus 1.259977 s of attachment on this VM. The
probe checked each returned pointer and completed cleanup. This single
observation is not a benchmark guarantee or a general scalability claim;
whole-Store scans remain, and non-leaf operations may be much more expensive.
The repository's unchanged 12,000-depth regression is a separate test gate.

## `xmlGetNodePath`

`xmlGetNodePath` routes through `Runtime.Get_Path` to
`Store.Queries.Get_Path`. The Store resolves only registered facades before
metadata reads, checks live/ranged nodes and namespaces, and validates
path-relevant parent, property, child, and sibling chains with bounded walks.
The shared `XML3_Text.Buffers.Valid_Name` helper rejects invalid UTF-8/XML
names, prefixes, and PI targets rather than copying malformed path syntax.
Output length is measured before a single exact-size allocation; a second
bounded traversal reverse-prepends path components without recursion or an
ancestor array, frees the result on failure, and writes the terminator only
after emitted length matches the measured length. The reference's harmless
default-namespace wildcard and equal-prefix/different-URI matching quirks are
preserved; full XPath namespace resolution is not claimed.

GNATprove discharges 8 checks for `Get_Path`, 17 for `Occurrence`, 7 for
`Measure`, 14 for `Emit`, and 27 for `Write_Component`. These cover internal
control flow, bounds, arithmetic, and written contracts, not complete public
C semantics. Native pointer readability, allocation/free, byte copying and
writes, pointer arithmetic, ABI/status/diagnostic mapping, and full libxml2
semantics remain trusted or unproved.

`make test-text-buffers test-dom test-serialization tests/header-smoke.o
tests/oom-test` passed. The `node-path` OOM walk injected failure at index 0
and reached the expected no-site exit status 2 at index 1; the DOM
ASan/UBSan run with leak detection passed. Shared reference cases cover path
categories and namespace quirks; malformed constructed names, unregistered
facades, detached lifetime, and OOM cleanup are library-only checks.

## `xmlGetLineNo`

`xmlGetLineNo` resolves a registered facade before querying the Store. The
parser records a capped source line with a monotone cursor; only LF advances
it, matching the fixed reference's harmless standalone-CR quirk. The bounded
Store query returns stored lines for parsed element/text/comment/PI nodes and
uses a five-node neighbor fallback for saturated lines and eligible attribute
or CDATA nodes. Attribute/CDATA results may be -1 when detached or inherit a
different line after a move. Constructed element/text/comment/PI and synthetic
attribute-value text have line 0; NULL, document, and unregistered facades
return -1. The C adapter, native pointers, ABI, and complete public semantics
are outside the proof.

GNATprove discharges 7 checks for `Advance_Line`, 13 for `Line_At_Node`, 5 for
`Get_Line_Number`, and 1 for the Runtime wrapper. The API tests cover mixed
markup and source positions, LF-only counting, character references,
constructed nodes, saturation, edits and moves, and no-allocation lookup.

## `xmlNodeSetName`

`xmlNodeSetName` routes through the thin C lock/status adapter to
`Runtime.Set_Name` and `Store.Content.Set_Name`. The Store resolves a
registered facade before reading native node metadata and rejects unsupported
kinds before measuring the caller's name. Bounded UTF-8/XML-name validation,
reserved-name checks, expanded-name attribute conflict detection, exact
allocation/copy control flow, and projection are performed in SPARK. A
successful rename installs a separately owned `Name_Pin`; it is not aliased
to the mutable content owner. The model's holder predicate deduplicates owner
references when two pin fields intentionally identify one owner, and ordinary
content/document/namespace projections preserve the name pin. Existing
projection deltas retire the old owner only after the new name is installed.
Failure preserves the old name, content, links, namespace, and facade identity.

The supported node kinds are elements, attributes, and processing
instructions. Empty or malformed UTF-8 names, invalid NCNames, PI target
`xml` (case-insensitively), unnamespaced attribute `xmlns`, and duplicate
attribute expanded names fail with a DOM diagnostic. NULL and unsupported
kinds are no-ops. Conflicting attributes are rejected rather than deleted.
Entity references and complete public C semantics remain outside this subset.
Native pointer validity/readability, allocation, byte copying, ABI/status
mapping, and diagnostic delivery remain trusted boundaries.

## `xmlStringGetNodeList` / `xmlStringLenGetNodeList`

The C adapters forward the input address and length, perform locking, Runtime dispatch, and
status/diagnostic mapping. `Store.Content.Parse_Content_List` validates a
registered document before reading the input, uses the strict SPARK text
decoder for UTF-8/XML and predefined/numeric references, and constructs one
detached text node through the existing document-owner path. General/unknown
entities and malformed input are rejected atomically; no entity-reference
nodes are created. Empty input returns NULL. A zero length returns NULL without
reading the input, deliberately avoiding the reference's unsafe first-byte
read. The proof covers the selected SPARK Store/Runtime/decoder contracts, not
native pointer validity, allocation/copy, ABI, diagnostics,
or complete public semantics.
`Measure` handles every negative length; `Measure_Byte_Prefix` bounds positive
lengths and stops at NUL. NULL input and explicit zero length bypass document
validation and preserve diagnostics. Other invalid documents are rejected with
code115 even for empty input, without reading it. Measured `Read_String` and
`Decode` buffers remain in SPARK; this is not a streaming decoder. Guard-page
tests protect the original input before attachment, serialization/free/reparse
and editing; native-only tests cover unreadable documents/inputs, zero/NULL
diagnostic preservation, leading NUL and over-limit rejection.
GNATprove proves 16 checks for `Store.Content.Parse_Content_List` and 1 for
the `Runtime.Parse_Content_List` wrapper.

## `xmlNodeListGetRawString`

The thin C adapter ignores `doc`, returns NULL for a NULL list, and performs
locking, Runtime dispatch, and status/diagnostic mapping. The SPARK query checks
that the starting facade is registered before native metadata access, then
measures and copies only direct text/CDATA content in the bounded next-sibling
chain; it does not descend or mutate the DOM. Nonzero `inLine` preserves raw
bytes without UTF-8/XML validation. Zero `inLine` validates each selected node's
UTF-8 independently before concatenation, then validates XML characters and
escapes special characters, rejecting malformed content split across node
boundaries. A non-NULL list with no selected text produces an independently
`xmlFree`-owned empty string. Entity-reference nodes are unsupported. The proof covers the query's bounded
walk, size arithmetic, and status/result contracts, not native pointer
validity/readability, allocation/copy/free, ABI, or complete C semantics.

## `xmlNodeListGetString`

The thin C adapter performs scalar handling, locking, Runtime dispatch, and
status/diagnostic mapping. The SPARK query shares the direct text/CDATA bounded
next-sibling walk and does not descend or mutate the DOM. Nonzero `inLine`
duplicates raw bytes and ignores `doc`. Escaped mode accepts a NULL or registered
document and validates each selected node's UTF-8 independently before
concatenation; XML character validation and escaping then operate on the joined
content. Attribute escaping is selected from the starting node's parent.
Attribute tabs and line feeds are numeric references and quotes use `&quot;`, while text tabs,
line feeds, and quotes remain literal. Non-ASCII characters become uppercase
hexadecimal character references because this subset does not retain document
encoding; explicit UTF-8 documents can therefore differ from reference output.
The returned allocation is independent and freed with `xmlFree`; NULL list
returns NULL, while a non-NULL list with no selected text returns an allocated
empty string. Output-allocation failure returns NULL without changing the
source links, as exercised by the OOM integration tests. HTML-specific behavior
and entity expansion are unsupported.
The proof covers the bounded query, strict per-node UTF-8 checks, escaper,
character-reference helper, and written status/result contracts—not C pointer
validity/readability, native allocation/copy/free, ABI, or complete C semantics.

## Input encoding-name classification

`XML3_Encoding.Buffers.Classify_Bytes` replaces the C encoding-name scan and String
conversion. Its candidate set shares all six aliases with String `Classify`,
which is also used for XML declaration matching. At most nine bytes (including
NUL) are read; losing the last candidate returns Unsupported immediately.
The postcondition distinguishes NULL/Unspecified from non-NULL classifications.
The C adapter retains buffer/size priority and code-32/OOM mapping; no decoder,
BOM, explicit-override, or declaration policy changes. Guard pages cover
truncated/unsupported names and rejection before XML reads; all aliases run
through input overwrite/free, DOM use, output, document free and reparsing
against the pinned reference. GNATprove reports 3 checks for `Classify_Bytes`;
the shared `Classify`, `Equal_Name`, and `Upper` contribute 1, 5, and 1 checks.
These contracts do not prove native pointer extents/stability or byte effects;
ABI, diagnostic mapping and full public semantics remain trusted.

## NUL-terminated document input

`xmlReadDoc` and `xmlParseDoc` now use the existing SPARK `Measure`/`Read_Length`
instead of the C scan. The inclusive `Max_Bytes` bound and failure/zero-length
contract are unchanged; the adapter calls the parser only when a NUL was found.
NULL input retains diagnostics while an empty string reaches the parser.
Measurement adds no allocation or copy and does not inspect bytes after NUL.
Pinned-reference tests cover guard-page terminators, embedded NUL, empty input,
and protected original input followed by DOM use, output, document free and
reparsing. Existing small-bound tests exercise the helper's scan limit; they
do not allocate a maximum-sized C input. Pointer readability/extents/stability,
actual byte reads, C ABI and full public parser semantics remain trusted.

## Native document-version construction

`Store.New_Document` measures non-NULL version input using SPARK `Measure` and
passes the address/length to shared `Construct`/`Create_Node` machinery. NULL
retains the `1.0` String path. The optional native content path retains all
owner/node/namespace preservation and result contracts, sizes the same owner
block, copies the version bytes directly, and appends NUL. Its precondition
excludes competing String content. Missing bounded terminators retain code115;
allocation failures return no document. Guard-page/pinned-reference cases
cover empty and arbitrary bytes and protect the original input before DOM use,
serialization/free/reparse. OOM walks cover default, explicit and empty versions
with retry. These contracts do not prove native readability, input stability,
actual byte effects, allocation/free, ABI or full public semantics.
GNATprove discharges 7 checks for `Store.New_Document`, 0 for the Runtime
wrapper, 9 for `Store.Construct`, 462 for `Create_Node`, and 22 for
`Allocate_Node_Buffer`; the shared `Measure` proves 2 checks.

## Direct raw-content constructors

The nine text, document-text, comment, document-comment, CDATA, PI, and
document-PI constructors pass the content address and mode through the C
adapter and Runtime to `Store.Content.New_Doc_Content_Bytes`. The Store checks
kind and registered-document status before reading content. NULL content skips
length checks and reads; terminated input uses `Measure`, while bounded input
rejects negative or oversized lengths before `Measure_Byte_Prefix` scans up to
the count or first NUL. The resulting span enters the existing
`New_Doc_Content` / `Construct` / `Create_Node` owner and rollback path.
Zero-length input reads nothing; NULL and empty content remain distinct.

GNATprove discharges 12 checks for `New_Doc_Content_Bytes`, 1 for the Runtime
wrapper, 23 for shared `New_Doc_Content`, 14 for `Find_Registered_Node`, 6 for
`Measure_Byte_Prefix`, and 3 for `Copy_Byte_Prefix`; `Create_Node` and
`Allocate_Node_Buffer` prove 462 and 22 checks, respectively. The shared
`Measure` proves 2 checks. Small-bound Ada tests cover NULL, zero, exact count,
and early NUL; guard-page/reference tests cover all nine APIs, source
protection, DOM use, serialization/free/reparse, and invalid document/content
combinations. Existing OOM walks cover retry and document-first release.
Native extents/readability/stability, byte effects, allocation/free, ABI, and
complete API semantics remain trusted or outside proof.

### Direct PI targets

`xmlNewPI` and `xmlNewDocPI` forward the non-NULL target address through the
same byte entry as PI content. It rejects an unregistered document before
measuring either input, then uses `Measure` for the target span. That span
drives checked sizing, direct copy/NUL termination, and the existing name
projection contract; target syntax remains deferred to serialization, while
the C NULL-target early return and diagnostic behavior are retained. Tests
cover guard-page ASCII, Unicode, empty, reserved, malformed, and raw-byte
targets, source protection, independent target/content ownership, output for
valid names, and empty-target OOM retry. The shared proof covers 12 checks for
`New_Doc_Content_Bytes`, 462 for `Create_Node`, 22 for
`Allocate_Node_Buffer`, and 2 for `Measure`. Native pointer extents/stability,
byte effects, allocation/free, ABI, and complete public semantics remain
trusted or outside proof.

## Direct container inputs

The six element/child/document-property constructors forward name and content
addresses through `Runtime.New_Doc_Node` / `New_Child`. Registered document,
parent and namespace lookup precedes either input scan. The new namespace
lookup compares model facades without reading native namespace fields; shared
`Construct` uses the same lookup. Names use the existing native-name span path,
including the attribute colon rejection in `New_Doc_Content`.

Raw input is measured and copied directly by the existing constructor; decoded
input uses a measured `Read_String` buffer plus the existing `Decode` buffer in
SPARK. It is not a streaming decoder. `Construct_Container` shares element or
attribute creation, text-child attachment and unpublished-node cleanup. The
`Ready` and result/status contracts remain; native extents/stability, byte
effects, ABI and complete public semantics are outside the formal claim.
Guard-page/reference tests protect both sources before namespace-aware
attachment, serialization/free/reparse and editing. Native-only checks reject
unreadable contexts/namespaces before reading either source, preserve each
API's NULL-name diagnostic behavior and retain malformed-reference/colon-name
rejection. Existing OOM walks cover failure rollback, retry and retained owners.
GNATprove proves 14 checks for `Construct_Container`, 18 for `Store.Content.New_Doc_Node`,
19 for `New_Child`, 23 for `New_Doc_Content`, 14 for `Find_Registered_Namespace`,
and 9 for `Store.Construct`; the Runtime `New_Doc_Node` and `New_Child` wrappers
prove 1 check each. Shared `Create_Node` and `Allocate_Node_Buffer` prove 462
and 22 checks, respectively.

## Source identity (SHA-256)

The following 131 hashes identify the source files and build/test configuration
for the proof result above; feature behavior and trust boundaries are
described in the preceding sections.

```text
a45e80673f3dce7805b588850a5b670dbac0e74db306603ef90c47256affc997  src/xml3_c.adb
51a4a0f25ed3943b062ad4ccf06e57767aa21b4b291f4978362af50d0dabd44b  src/xml3_c.ads
8a280b48c8dd1327f90f4d80b2c112a5d56a49b713cb6cd72164e31baf9a312b  include/libxml3.h
66072f8c4567c0b34ec94f316694791a290f312f6dad53fad4f6a2be770683fd  include/libxml/chvalid.h
c182792b54b0c427b508002c06c6228f7efb31f3b81dc45179c7c7febcb50909  include/libxml/entities.h
60048419b81a8ad53de631cbbfde91954bf2d8b6995adbefe6a1b8d153d05f03  include/libxml/parserInternals.h
3a409df2cb5d7bda0004d19a4c1045d6bae6408ff9ca9ca7cd5e728b571273c7  include/libxml/uri.h
c688643449bc09c9977197b5b78325eaced0b8852e6bf0dd3497952bb081a5c6  include/libxml/valid.h
6c0361c1444457c482a6d969f7b88b824c2c33accea3265466129d75b19893a5  src/xml3_dom-import.adb
64707d2b0c629bbc574ed89d97aa4aedc643bde9744d13bf7ffcb3ae7c3f5ddf  src/xml3_dom-import.ads
af96365a55310b08822701ae7765f861d6009b5369cdc9d972b4bc52654fea35  src/xml3_dom-materialize.adb
11b0272dbbf8cf7988fb7c96ef8f104f22db1a1390e2c3f5df0bd6d3f6ef60c1  src/xml3_dom-materialize.ads
0cbbd78bc6aebb168b14c51672a158d02f48e8deb65129f62a24f6c6d89f294e  src/xml3_dom.adb
1d21f5aa8d046b01223c79968469165fdec025ab552a5e61e1f3e33d785d7337  src/xml3_dom-graph_lemmas.ads
f3055b8a3f4a31dae5082f40d0e2d3c06b0741e48614068c4fe06f79e3f00a9a  src/xml3_dom-graph_lemmas.adb
8dfb6cbc413d6336688c577114c428df1788e873cde1bc5003671d5516fd2c2d  src/xml3_dom-links.ads
631c8eb994586ca94c1999fb0ef772bfd5a47fee2b02945fc02e6e1ae4b16a20  src/xml3_dom-links.adb
f8c1654a156442676fffed41640fefa0f01c2651a080db9cae04cb4e50ad01a5  src/xml3_dom-projection.ads
d7d7ca6095ccbf6a226fbafdda2ced49caa1e0e254632e465fae9f468004cf5c  src/xml3_dom-projection.adb
12d6df733990913a81d0521a01c7a662512e16985dd3c3287e311dde56c52d48  src/xml3_dom-marking.ads
8de5c461b7d5ef9deeb95213ada3ec29efdbe24d69ba0d04b95c062dbc8915a7  src/xml3_dom-marking.adb
3363247b3c4f54ecaa8a609c816715e5f3353fde53fbe36b364f1c94633cfdfa  src/xml3_dom-freeing.ads
48ac11b56a65dda9d47a047be12c1c823a51244c3b391453d07474d7345fa4b7  src/xml3_dom-freeing.adb
8bd7f8aefdde8cb8966c66340dc6d12671973a7ac50bb2e19be10b932596cf57  src/xml3_dom-releases.ads
f4228210e38aef044d6946f0534ce75dd694d2013a432f7c87adf4bbd9d8ad53  src/xml3_dom-releases.adb
619497e8aeea7da0826c033eaf04b66f15d9c81998953b138fbaca484b0b57c2  src/xml3_dom-retirement.ads
a58b9d174bd5a233d1fd868ea670b4ff3a3c099c321cf2bc806348b00ee5c417  src/xml3_dom-retirement.adb
3db488d5b5453f4638293e2b3c8bc0ec5df56900707f08f88ef249176500ce9e  src/xml3_dom.ads
1b0b582fc5ab3c34e5d96d5fce20b536426df9f68fbe4b4e99423785eb978002  src/xml3_dom_allocation.adb
38c4ff80e2a8bafa63579a0cb03026926cb4ad4ee44d2324d86842e119ac1c05  src/xml3_dom_allocation.ads
17de99a6befdb1eab490fd275377a956401e58e2a48de0c9cecada643064bbb3  src/xml3_dom_bridge.adb
a62a5e86be7f9e74c7618d38a3210b4e31842d1cba5304ad3cf4efd7d32987b8  src/xml3_dom_bridge.ads
b16ad801efff504362bd0b8be9601be333ef99c2345cd37cf8985f6c627ef53b  src/xml3_dom_constructors.adb
8bb87036e5063a4d4e5ae33a1e03a2fe460e6f75966f4c4f39b409f8dd9141e8  src/xml3_dom_constructors.ads
3d5be8acf4a2e8936fab93435465be0a3610833a7e00cf06c292c3e2e13b9f35  src/xml3_dom_lock.adb
3787e7d43e9a139612f97575b069cd407d06bc6f770e1fd88ae4628ecf0810bb  src/xml3_dom_lock.ads
804f1a3371bc434ce35784d7605c6a8153f401b55da2fbb8a49145a71bc42e1b  src/xml3_dom_mutex.c
fcdacb00835f90864c65ad759f12ef93e96d02ae057c85b327b4afa46fae3892  src/xml3_dom_runtime.adb
50e0706fc185b7d8019b365573432cff5db0662322232bea4aeffefa1cbec1e9  src/xml3_dom_runtime.ads
48971614e213e183e073609c06983881fe1c6727bfec0476b5b198f87588e470  src/xml3_dom_store-content.adb
9be716f2c2de451c7a5c025d487b7fe92f7bab6a5a6efce4b5e50d7b90949a22  src/xml3_dom_store-content.ads
339c4be671e09933bce76f0a2bee178907eaf295e429b47fbf66868c93a698a7  src/xml3_dom_store-documents.adb
6c52972b1a9bedcd5032918c0ae52efce069d7ab512555822beec7c833aae4c3  src/xml3_dom_store-documents.ads
39b9ab4d1ec8b4f8f54ff0cfd13c890de61997e56544cfb740f0b099a585bbd8  src/xml3_dom_store-properties.adb
335071995c50a800cf07f0f479c2712878b49edac9940cf3aca32322f306abbf  src/xml3_dom_store-properties.ads
264cc8a1b8b7867cd61b0ffba47719c4b9bee3238b5777483377933ff7ab19b0  src/xml3_dom_store-queries.adb
7857b82b6bfb4ab6562a21548bcb48f39c02303012c1e95ea7a5869847641e66  src/xml3_dom_store-queries.ads
61dac86f279fa767332d341e9b1519978973444068895e508e2d50bf7cf0a659  src/xml3_dom_store-serialization.adb
d556e31d6a1efbb46b902e1bccec60e011e87be5d6a5e7cad3e53ae6f620c822  src/xml3_dom_store-serialization.ads
3d63803caff59bd5791c849800084f16a55c0eefc0d4adab82a7b1f2380bc2a2  src/xml3_dom_store.adb
a6fce5e266f862563bdc60c908dd82d3b4b6e43e85a95fb569fa5d3f291ce8f5  src/xml3_dom_store.ads
4cd0836509d8859bd5ec708a51dea1282b7e5af903611211bb2f745750938a43  src/xml3_encoding.adb
a1fc38d820142fb7c9bee27e9defd4a637ab75b60720bb21589467f86754573f  src/xml3_encoding.ads
28a7fea5a94bb0db015deb93b66d88ac2d459bc45c52a84bdd9e85ef32ef8a95  src/xml3_encoding-buffers.adb
140f58f4fb0edd3c4466e976f2995e404b454514160541869e6438d1c23307fa  src/xml3_encoding-buffers.ads
53fed6a5a3374aa4f67ff6865a0d703274f89bfd44f036285a2166a31d843cfe  src/xml3_error_tls.c
368ed07c92dd5366760bc4b12f0b298d7b5999cae15b631ef087f252a370d102  src/xml3_errors.adb
8cd2d2fedd9befc9f727d8f9055c94250484c83a543be7dcd9b1b6c76452199e  src/xml3_diagnostic_messages.ads
5731a2fbf1783f9b160e1562c00371f2758263b2a2509c93e05ca693a15130a3  src/xml3_diagnostic_codes.ads
0cd13c4023d7da1d60c8e3ea830b903b78cbcd2c7ea796b1a2b4a0296c79a36f  src/xml3_errors.ads
09734ebf88516572b7fbd7dc1b023316755d8ab156d7fcce58e2c785c0ec219f  src/xml3_namespaces.adb
055155bfd5a5e8b1c55cba12d27739810c9e70c6e3bb979f2aee07d4e9372831  src/xml3_namespaces.ads
9635087d455bb29a987535cc5ce1f04fb33fd59ef2b67f6af967279495113e1f  src/xml3_native_memory.adb
253b7461252644c8b3d4135feba70582d31163dc1d2e6d44813beb1cc18dad6b  src/xml3_native_memory.ads
f2fdbfe6f216161279e01d8d92865681219620eb456f9d82a188bcad48fde183  src/xml3_parser.adb
fd4127642cf4b1d1bd7aee6d821bc671bae2de239d4fd902242eeb70ded73337  src/xml3_serialization.adb
a6e878d31db01b95cc73cc2080f950709e96c50000160371ca7b89f115d50304  src/xml3_serialization.ads
5883e231cf0b6c7d7d81f6958665c21d77188f1bae9678a3706e4372c5c686df  src/xml3_parser.ads
b65a6b5269e0a457b0362da1986fb73db64415f9ac5588b5cd1d475dbdc3a9cb  src/xml3_parser-native_sizes.ads
0c5d33581cb7ad90b48c57387566c9cc7fef9e117dee90deb0b13c551918a486  src/xml3_parser-attempts.ads
3f3e9bcb409c200964ef366a9803ccd146f77f00e28404ca79c52a0e30c86f7c  src/xml3_parser-attempts.adb
dd8bc8decd0750060ca05fecd2522078d80a198292f76f0e7396e1ef07796fe5  src/xml3_parser-options.ads
c2b4a1f34d55437337a9934733cd5123dc326b5e83c965df1c53947e76c9fb7f  src/xml3_parser-outcomes.ads
53dc47e2a48012d545f0e6ca3483932a246faa9226f99c5a1cb7a630628b41cc  src/xml3_parser-requests.ads
44ae59e8a3376cb11dbe157f1af3e0df276d5e5d913beaf87bb4cb793fed8cc6  src/xml3_parser-statuses.ads
d907d72a35b735f909e90159649e161a9e4eeb537d3cd5b8587e2190afec0203  src/xml3_parser-contexts.ads
50e786dbb39401878a4a405fbf814f4ee6b0187900f75aa365f723a6608a690a  src/xml3_dom_results.ads
70811a782487da090c7f51455548bf53a2178bb4aea0f348aef605025c5875cd  src/xml3_text_results.ads
75d63d2900b4a894f24c6f534b30b51f38f8ae04c4418301c23c7214635bdb05  src/xml3_entry_guards.ads
9098d98c40c85a401839f9e09fd3dab870757985bda1d9dc5a54212edb6175de  src/xml3_dom_store-copies.ads
588c73ceb48578ab1fef8c169f6d75123067b14edc35702b37ec48e255d5f695  src/xml3_dom_store-copies.adb
e173f0b2b834d7b0fdf2024c8198e5e3a1b569259f0d0e3d850c024cc3f9bc3c  src/xml3_byte_buffers.ads
452e885ddf2a4598b0d18df3e3360011d29d905e220a3e14b5a3abc2bf78bbed  src/xml3_byte_buffers.adb
7d2f71bd3d7fec7e838ce6c27113b7249e6d9343c79e02ff4d4575ac1c84ed7b  src/xml3_file_paths.ads
b9b9d84b59941b17c1c0bd670c7e262669ad00a2296631e73d2e26d0ed19d578  src/xml3_file_paths.adb
f0841ece62ede37ac2aeafb0e605bea88bfb2484781797b10a990baca9b02c6e  src/xml3_io_errors.ads
eb863314fb418d26796ea1b0bbe834a91879e7d5d5342e0442b1b6a408397424  src/xml3_save_contexts.ads
4fa669d36c9d354cef611de538a2b2e488b1adb0b3da3d7b9d56e4ef64185434  src/xml3_uris.ads
e529e984b7dc90952bd771c26368ff473c4a95b7e994cec4905d0fb12ffdd7ab  src/xml3_uris.adb
4b43adf88af05f6c81c8c1e33f58ecb427de967c49869d5236f007628c49848b  src/xml3_parser-options.adb
ef51236d3edd0dc04e8fa02c2d52315792ac053b5a4e68b021cd97f9063a80ee  src/xml3_parser-workspaces.ads
614951b049130edcefaeddb3239f02d04eec6315dbf6fce61f355324c5082839  src/xml3_parser-workspaces.adb
7e4bd00be06a5c10475e8ddf61f96d6506f8ab16579ef1b04dcff900de16b2f7  src/xml3_text.adb
09ed865f956f0e09bf54f4aa6bb8e5ca5ede9ff144d15492ca37c3c3c8343c84  src/xml3_text.ads
05e393dd15e0bcd89400ce784838371941f95bd1ac2e129fdb396f4cba94485e  src/xml3_text-qnames.adb
8fb4f085a0ade03d03c58f9e0d50a5349f500479afd2ac7c59eeaefcc00f0302  src/xml3_text-qnames.ads
c2f728b3a16edb4e8e591130e4a77da753e3f459430600428914b623bcc00cae  src/xml3_text-buffers.adb
0135b3c7fb6f240713b5de5e49650d4b39a6977f3463f16dfa629d3c0c6da599  src/xml3_text-buffers.ads
d26474b2a939148a4be5361e30910b9e703e0029c5c1c24428947f956cf99c5a  include/libxml/tree.h
703fd38d8b1c2e6708a11c8dca8866fe922b071bb545e9d26587dac29a544d0c  include/libxml/xmlstring.h
8b172f3cd4b44a79e9837c10dad5db226f0241562bb922c01bb6cbfdcde92eb1  proof.gpr
57627b512338fb7221748af16c268faedb77cbca94184c6aac1b13e62552e9af  libxml3.gpr
90ecfdadd2b0e762f2203f3c3dd0d337414f4d0f35ff50776914a87620f3c3b7  libxml3.sym
aa70959e3e060bd61dcf39cd3fc67e212ee709dfb9c4896827e6c98589ff458c  Makefile
0fac6d07736e217b2988b08c096aca1d31218a14bde5429eaf404937d9d5f77b  eng/prove_units.py
8f5accaeda91e17a81b7be66c2469847a093375ea8a6de69d06b50d0bf53f8fc  tests/error-test.c
a52de86fc8f3faf3aadefe52b3b69778e7ae0ab6779f1efdd97b2dc4fd9ccf07  tests/oom-test.c
d76816a43eeb8515242b31fa5e8a64d3787c3a8a6e3a0df0dbe87a14516ff48a  tests/serialization-test.c
29cd3ab92b2dc021fb9b338ec36b1bf944d3ff06f71715b50fd051d93afe7ead  tests/oom-shim.c
b04c201006fc5ec124c5cde853d89c69ccffe306c34ec69b150834df41b03cce  tests/text_buffers_test.gpr
b4c2736f60339806353483ca0a0e4d585e4960c7f6988da16b2875caf0fc2ef7  tests/text_buffers_test.adb
78eda3401c2326ebaf3d69e5f8d06b52cc7e6006af3e1ebaa9420b5f90e73999  .github/workflows/manual.yml
cb4af7a636be3bab93bc2e9bcd746b990e1ce8f36e5f0b175601944a7b9052f6  src/xml3_error_records.ads
d200fabffa4a2a434647d2fc1eac91a7df6ae1f4a68777b55be8d7308421328f  src/xml3_error_records.adb
12b31fb627e06379e10aad76a8ba942eed16162a9f96fc0b69d45f157c6a7ad7  tests/dom_bridge_test.adb
79a9cd119dbc87f81cf02460f416fdebafb23797bbfbc5038b9462973b0ba808  tests/dom_bridge_test.gpr
1c6e72ecf48a046d130676549fd36c78e834f49a2750ac73b3880a15ed328cee  tests/dom_bridge_facade.c
de39b5a991725333eb8fe1ac485e641d5ad8ab58ecae6788f838c0268a25079e  tests/copy-test.c
bcfe6c992c1e40680aef3163590d7e46c6d3d2c96540849805866439a939d251  tests/output-test.c
ffd91cf400eeec27207cf0a919a36cd615bbb3c10d5213b6d82516110992cc90  tests/input-test.c
f5384b35c3951c33d6a5c66b562b4c45d7906a11dfc3baf78d7ffb175cf8a5fc  tests/context-test.c
4f26f4a141d45ea5e6eb44488d12f0e6d6f31ebaa0a076a6b1b46f837285c29f  tests/save-test.c
a5d8c06a69110f289962af1bca9b4b659053a43659673e33631ee40d8f8e8d1d  tests/handler-test.c
d7ede60942a024f6775ffc9d4e1f2e78e45ae64ca5735989f4638c19354eb8ca  tests/uri-test.c
b38191e8ef55e1b125d3af3dd971d667f1b6108c50ce2c801d1c6dfe02f41b1c  tests/uri-build-test.c
82b0e8746626c25714520da45d7e6716c99da010125852405cec94df86bbf761  tests/format-test.c
79baaa129e9dde87491db5230af515ba63e2bc4ac9a60b6de986d660d57b77ad  tests/memory-test.c
7975704364f8752e5bcd452953db036f6b12a34f743a46429c107648dc82887c  include/libxml/xmlsave.h
4cc63357f09653642769d79d40d4c92ec6bbf205553a0350a65726241fff5b1a  include/libxml/xmlIO.h
d8f9e296e83bce81a95d9e67bfdd393a6e3f8f3bf812ab9efe53af5f20eb66cf  src/xml3_format.c
e5d6b5e83e2242191a0e5c86bd18c1be8a53f1bf3b68d38a3409ea8303481443  src/xml3_memory.c
```

A source or contract change invalidates this record until proof is rerun.
Solver percentages can vary without changing the obligations. The proof
assumes the compiler, translator, solvers and runtime model are sound;
resource exhaustion and foreign-memory behavior remain outside it.
