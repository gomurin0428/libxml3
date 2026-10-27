# API台帳（生成物）

基準: libxml2 2.15.4 / `96498992efa48d52b0e8b83058bd88dbdaf153c1`。

これは宣言の台帳です。関数の存在・型の一致・テスト成功・形式証明は別の指標です。
未記載のcoverageは未評価・未比較・未証明を意味します。完全互換率は算出しません。
対象構成外の条件付き宣言は含まず、マクロにはヘッダーガード等も含みます。
抽出範囲・再生成手順は [compatibility-baseline.md](compatibility-baseline.md) を参照。

## 宣言種別

| 種別 | 件数 |
| --- | ---: |
| callback | 86 |
| constant | 1288 |
| enum | 48 |
| field | 666 |
| function | 1405 |
| macro | 324 |
| struct | 98 |
| typedef | 250 |
| union | 2 |
| variable | 22 |

## ヘッダー

| ヘッダー | 宣言数 |
| --- | ---: |
| HTMLparser.h | 104 |
| HTMLtree.h | 24 |
| SAX.h | 1 |
| SAX2.h | 37 |
| c14n.h | 11 |
| catalog.h | 54 |
| chvalid.h | 48 |
| debugXML.h | 12 |
| dict.h | 16 |
| encoding.h | 95 |
| entities.h | 48 |
| globals.h | 1 |
| hash.h | 38 |
| list.h | 36 |
| nanoftp.h | 1 |
| nanohttp.h | 18 |
| parser.h | 506 |
| parserInternals.h | 111 |
| pattern.h | 29 |
| relaxng.h | 86 |
| schemasInternals.h | 373 |
| schematron.h | 31 |
| threads.h | 20 |
| tree.h | 471 |
| uri.h | 33 |
| valid.h | 106 |
| xinclude.h | 27 |
| xlink.h | 36 |
| xmlIO.h | 87 |
| xmlautomata.h | 26 |
| xmlerror.h | 832 |
| xmlexports.h | 11 |
| xmlmemory.h | 41 |
| xmlmodule.h | 12 |
| xmlreader.h | 135 |
| xmlregexp.h | 19 |
| xmlsave.h | 32 |
| xmlschemas.h | 74 |
| xmlschemastypes.h | 41 |
| xmlstring.h | 33 |
| xmlunicode.h | 1 |
| xmlversion.h | 35 |
| xmlwriter.h | 87 |
| xpath.h | 198 |
| xpathInternals.h | 149 |
| xpointer.h | 3 |

## 現在の実装・比較範囲

比較テストの実行結果はPRに記録します。下表はテストへの対応付けで、全入力の等価性を主張しません。

| 宣言 | 実装 | 範囲 | テスト | C APIの証明 |
| --- | --- | --- | --- | --- |
| `function:parser.h:xmlCleanupParser` | partial | 現在のUTF-8/UTF-16・読み取り専用DOMサブセット内。全オプション・全ノード型の等価性は未確認。 | [tests/api-test.c](../tests/api-test.c) | not-proved |
| `function:parser.h:xmlInitParser` | partial | 現在のUTF-8/UTF-16・読み取り専用DOMサブセット内。全オプション・全ノード型の等価性は未確認。 | [tests/api-test.c](../tests/api-test.c) | not-proved |
| `function:parser.h:xmlParseDoc` | partial | NUL終端UTF-8入力の読み取り専用DOMサブセット内。strlenを使うためbinary UTF-16入力には使用できない。全オプション・全ノード型の等価性は未確認。 | [tests/api-test.c](../tests/api-test.c), [tests/error-test.c](../tests/error-test.c) | not-proved |
| `function:parser.h:xmlParseMemory` | partial | 現在のUTF-8/UTF-16・読み取り専用DOMサブセット内。全オプション・全ノード型の等価性は未確認。 | [tests/api-test.c](../tests/api-test.c), [tests/error-test.c](../tests/error-test.c) | not-proved |
| `function:parser.h:xmlReadDoc` | partial | NUL終端UTF-8入力の読み取り専用DOMサブセット内。strlenを使うためbinary UTF-16入力には使用できない。全オプション・全ノード型の等価性は未確認。 | [tests/api-test.c](../tests/api-test.c), [tests/error-test.c](../tests/error-test.c) | not-proved |
| `function:parser.h:xmlReadMemory` | partial | 現在のUTF-8/UTF-16・読み取り専用DOMサブセット内。全オプション・全ノード型の等価性は未確認。 | [tests/api-test.c](../tests/api-test.c), [tests/error-test.c](../tests/error-test.c), [tests/fuzz-test.c](../tests/fuzz-test.c), [tests/resource-test.c](../tests/resource-test.c), [tests/encoding-test.c](../tests/encoding-test.c), [tests/encoding-resource-test.c](../tests/encoding-resource-test.c), [tests/compare-encoding.py](../tests/compare-encoding.py) | not-proved |
| `function:tree.h:xmlAddChild` | partial | 限定 node types と same-document/documentless subtree。document parent は text/CDATA 直下と second root を拒否。adjacent text merge。cross-document move と属性追加は未対応。 | [tests/dom-test.c](../tests/dom-test.c), [tests/oom-test.c](../tests/oom-test.c) | not-proved |
| `function:tree.h:xmlChildElementCount` | partial | 現在のUTF-8/UTF-16・読み取り専用DOMサブセット内。全オプション・全ノード型の等価性は未確認。 | [tests/api-test.c](../tests/api-test.c) | not-proved |
| `function:tree.h:xmlDocGetRootElement` | partial | 現在のUTF-8/UTF-16・読み取り専用DOMサブセット内。全オプション・全ノード型の等価性は未確認。 | [tests/api-test.c](../tests/api-test.c) | not-proved |
| `function:tree.h:xmlDocSetRootElement` | partial | descendant root promotion を含む文書 root 置換。旧 root subtree の detached ownership を維持。 | [tests/dom-test.c](../tests/dom-test.c), [tests/oom-test.c](../tests/oom-test.c) | not-proved |
| `function:tree.h:xmlFirstElementChild` | partial | 現在のUTF-8/UTF-16・読み取り専用DOMサブセット内。全オプション・全ノード型の等価性は未確認。 | [tests/api-test.c](../tests/api-test.c) | not-proved |
| `function:tree.h:xmlFreeDoc` | partial | 現在接続された tree を解放し document 参照を落とす。detached live node/namespace がある parsed arena は参照解放まで保持。全ノード型の等価性は未確認。 | [tests/api-test.c](../tests/api-test.c), [tests/dom-test.c](../tests/dom-test.c) | not-proved |
| `function:tree.h:xmlFreeNode` | partial | element/text/comment/CDATA/PI subtree のみ unlink して反復解放。document/attribute/namespace pointer は code 115 で拒否。C DOM ownership は SPARK proof 対象外。 | [tests/dom-test.c](../tests/dom-test.c) | not-proved |
| `function:tree.h:xmlFreeProp` | partial | attribute を解放。attached pointer は先に安全に unlink し、detached pointer も解放。qualified attribute も対応し、namespace declaration は解放しない。 | [tests/attribute-test.c](../tests/attribute-test.c), [tests/namespace-edit-test.c](../tests/namespace-edit-test.c) | not-proved |
| `function:tree.h:xmlGetProp` | partial | 現在のUTF-8/UTF-16・読み取り専用DOMサブセット内。全オプション・全ノード型の等価性は未確認。 | [tests/api-test.c](../tests/api-test.c) | not-proved |
| `function:tree.h:xmlHasProp` | partial | 現在のUTF-8/UTF-16・読み取り専用DOMサブセット内。全オプション・全ノード型の等価性は未確認。 | [tests/api-test.c](../tests/api-test.c) | not-proved |
| `function:tree.h:xmlNewDoc` | partial | version NULL 時は1.0、指定 C string はそのままコピー。XML 1.0 制限は parser に適用。C DOM ownership は SPARK proof 対象外。 | [tests/dom-test.c](../tests/dom-test.c), [tests/oom-test.c](../tests/oom-test.c) | not-proved |
| `function:tree.h:xmlNewNode` | partial | 要素 node と library-owned namespace borrowing。raw name string をコピーし XML name/UTF-8 検証なし。C DOM ownership は SPARK proof 対象外。 | [tests/dom-test.c](../tests/dom-test.c), [tests/oom-test.c](../tests/oom-test.c) | not-proved |
| `function:tree.h:xmlNewNs` | partial | href/prefix をコピーして standalone または element 宣言を作成。NULL と empty prefix/href を区別し、同じ要素の local prefix 重複を拒否。constructed namespace は明示 reservation を持つ。 | [tests/namespace-edit-test.c](../tests/namespace-edit-test.c), [tests/oom-test.c](../tests/oom-test.c), [tests/dom_core_test.adb](../tests/dom_core_test.adb), [tests/dom_bridge_test.adb](../tests/dom_bridge_test.adb) | not-proved |
| `function:tree.h:xmlNewNsProp` | partial | namespace-aware detached/attached attribute を作成。local name と値をコピーし、NULL value と empty value を区別。expanded name が異なる重複 local name を許す。 | [tests/namespace-edit-test.c](../tests/namespace-edit-test.c), [tests/oom-test.c](../tests/oom-test.c) | not-proved |
| `function:tree.h:xmlNewProp` | partial | colon のない namespace-free attribute を raw C string から作成。XML name/UTF-8 検証なし。NULL value は child なし、empty value は text child。C DOM ownership は SPARK proof 対象外。 | [tests/attribute-test.c](../tests/attribute-test.c), [tests/oom-test.c](../tests/oom-test.c) | not-proved |
| `function:tree.h:xmlNewText` | partial | raw C string content をコピーし UTF-8 検証なし。NULL content は NULL のまま。C DOM ownership は SPARK proof 対象外。 | [tests/dom-test.c](../tests/dom-test.c), [tests/oom-test.c](../tests/oom-test.c) | not-proved |
| `function:tree.h:xmlSetNs` | partial | element/attribute の namespace reference のみを変更し、NULL で解除。unknown facade は Store identity lookup で拒否し、node content/document pin を保持。 | [tests/namespace-edit-test.c](../tests/namespace-edit-test.c), [tests/dom_bridge_test.adb](../tests/dom_bridge_test.adb) | not-proved |
| `function:tree.h:xmlSetNsProp` | partial | URI と local name で既存属性を照合。既存 attribute address、`_private`、list position を保持し、新値確保後に namespace/value を更新。 | [tests/namespace-edit-test.c](../tests/namespace-edit-test.c), [tests/oom-test.c](../tests/oom-test.c) | not-proved |
| `function:tree.h:xmlNextElementSibling` | partial | 現在のUTF-8/UTF-16・読み取り専用DOMサブセット内。全オプション・全ノード型の等価性は未確認。 | [tests/api-test.c](../tests/api-test.c) | not-proved |
| `function:tree.h:xmlNodeGetContent` | partial | 現在のUTF-8/UTF-16・読み取り専用DOMサブセット内。全オプション・全ノード型の等価性は未確認。 | [tests/api-test.c](../tests/api-test.c) | not-proved |
| `function:tree.h:xmlRemoveProp` | partial | attached namespace-free または qualified attribute を安全に unlink/free。detached attribute は拒否。 | [tests/attribute-test.c](../tests/attribute-test.c), [tests/namespace-edit-test.c](../tests/namespace-edit-test.c), [tests/oom-test.c](../tests/oom-test.c) | not-proved |
| `function:tree.h:xmlSetProp` | partial | no-namespace property を従来どおり更新し、prefix を含む QName は SPARK で NCName 検証・scope 解決。unbound/malformed prefix は code 115。documentless `xml:lang`/`xml:space` は暗黙 XML namespace を作成する。 | [tests/attribute-test.c](../tests/attribute-test.c), [tests/namespace-edit-test.c](../tests/namespace-edit-test.c), [tests/oom-test.c](../tests/oom-test.c) | not-proved |
| `function:tree.h:xmlUnlinkNode` | partial | 通常 child unlink のみ。attribute unlink は拒否。 | [tests/dom-test.c](../tests/dom-test.c) | not-proved |
| `function:tree.h:xmlUnsetProp` | partial | 同名の namespace-free attribute を削除。欠落・非対応は -1。C DOM ownership は SPARK proof 対象外。 | [tests/attribute-test.c](../tests/attribute-test.c), [tests/oom-test.c](../tests/oom-test.c) | not-proved |
| `function:tree.h:xmlUnsetNsProp` | partial | namespace URI と local name で属性を照合して削除。欠落時は -1。 | [tests/namespace-edit-test.c](../tests/namespace-edit-test.c) | not-proved |
| `function:tree.h:xmlFreeNs` | partial | attached または parsed/unowned namespace の手動解放を拒否。detached constructed namespace の explicit reservation を一度解放し、borrower pin が残る間は保持。NULL は no-op。 | [tests/namespace-edit-test.c](../tests/namespace-edit-test.c), [tests/dom_core_test.adb](../tests/dom_core_test.adb), [tests/dom_bridge_test.adb](../tests/dom_bridge_test.adb) | not-proved |
| `function:xmlerror.h:xmlCopyError` | partial | Deep-copies owned strings transactionally for valid zero-initialized or previously reset destinations. | [tests/error-test.c](../tests/error-test.c), [tests/oom-test.c](../tests/oom-test.c), [tests/fuzz-test.c](../tests/fuzz-test.c) | not-proved |
| `function:xmlerror.h:xmlGetLastError` | partial | per-OS-thread last-error retrieval; supported numeric diagnostics and exact message text remain a documented subset. | [tests/error-test.c](../tests/error-test.c), [tests/error-snapshot.c](../tests/error-snapshot.c) | not-proved |
| `function:xmlerror.h:xmlResetError` | partial | Resets caller-owned xmlError records; foreign pointers remain caller responsibility. | [tests/error-test.c](../tests/error-test.c), [tests/fuzz-test.c](../tests/fuzz-test.c) | not-proved |
| `function:xmlerror.h:xmlResetLastError` | partial | Explicitly clears the calling thread's last error and owned strings. | [tests/error-test.c](../tests/error-test.c) | not-proved |
| `function:xmlstring.h:xmlStrEqual` | partial | 現在のUTF-8/UTF-16・読み取り専用DOMサブセット内。全オプション・全ノード型の等価性は未確認。 | [tests/api-test.c](../tests/api-test.c) | not-proved |
| `function:xmlstring.h:xmlStrcmp` | partial | 現在のUTF-8/UTF-16・読み取り専用DOMサブセット内。全オプション・全ノード型の等価性は未確認。 | [tests/api-test.c](../tests/api-test.c) | not-proved |
| `function:xmlstring.h:xmlStrlen` | partial | 現在のUTF-8/UTF-16・読み取り専用DOMサブセット内。全オプション・全ノード型の等価性は未確認。 | [tests/api-test.c](../tests/api-test.c) | not-proved |
| `macro:xmlmemory.h:xmlFree` | partial | 通常の解放呼び出しのみ。上流のallocator変数/マクロ差し替えは非互換。 | [tests/api-test.c](../tests/api-test.c) | not-proved |
| `variable:xmlmemory.h:xmlFree` | partial | 通常の解放呼び出しのみ。上流のallocator変数/マクロ差し替えは非互換。 | [tests/api-test.c](../tests/api-test.c) | not-proved |
