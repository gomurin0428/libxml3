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
| `function:tree.h:xmlAddChild` | partial | 限定 node types、same-document/documentless subtree、adjacent text merge。cross-document move と属性追加は未対応。 | [tests/dom-test.c](../tests/dom-test.c), [tests/oom-test.c](../tests/oom-test.c) | not-proved |
| `function:tree.h:xmlChildElementCount` | partial | 現在のUTF-8/UTF-16・読み取り専用DOMサブセット内。全オプション・全ノード型の等価性は未確認。 | [tests/api-test.c](../tests/api-test.c) | not-proved |
| `function:tree.h:xmlDocGetRootElement` | partial | 現在のUTF-8/UTF-16・読み取り専用DOMサブセット内。全オプション・全ノード型の等価性は未確認。 | [tests/api-test.c](../tests/api-test.c) | not-proved |
| `function:tree.h:xmlDocSetRootElement` | partial | 文書 root の検証済み置換。comments/PI と旧 root の detached ownership を維持。 | [tests/dom-test.c](../tests/dom-test.c), [tests/oom-test.c](../tests/oom-test.c) | not-proved |
| `function:tree.h:xmlFirstElementChild` | partial | 現在のUTF-8/UTF-16・読み取り専用DOMサブセット内。全オプション・全ノード型の等価性は未確認。 | [tests/api-test.c](../tests/api-test.c) | not-proved |
| `function:tree.h:xmlFreeDoc` | partial | 現在のUTF-8/UTF-16・読み取り専用DOMサブセット内。全オプション・全ノード型の等価性は未確認。 | [tests/api-test.c](../tests/api-test.c) | not-proved |
| `function:tree.h:xmlFreeNode` | partial | 非-document subtree を安全に unlink して反復解放。C DOM ownership は SPARK proof 対象外。 | [tests/dom-test.c](../tests/dom-test.c) | not-proved |
| `function:tree.h:xmlGetProp` | partial | 現在のUTF-8/UTF-16・読み取り専用DOMサブセット内。全オプション・全ノード型の等価性は未確認。 | [tests/api-test.c](../tests/api-test.c) | not-proved |
| `function:tree.h:xmlHasProp` | partial | 現在のUTF-8/UTF-16・読み取り専用DOMサブセット内。全オプション・全ノード型の等価性は未確認。 | [tests/api-test.c](../tests/api-test.c) | not-proved |
| `function:tree.h:xmlNewDoc` | partial | XML 1.0 の文書作成と所有権付き単一ノード arena。C DOM ownership は SPARK proof 対象外。 | [tests/dom-test.c](../tests/dom-test.c), [tests/oom-test.c](../tests/oom-test.c) | not-proved |
| `function:tree.h:xmlNewNode` | partial | 要素 node と library-owned namespace borrowing のみ。C DOM ownership は SPARK proof 対象外。 | [tests/dom-test.c](../tests/dom-test.c), [tests/oom-test.c](../tests/oom-test.c) | not-proved |
| `function:tree.h:xmlNewText` | partial | UTF-8 text node 作成のみ。C DOM ownership は SPARK proof 対象外。 | [tests/dom-test.c](../tests/dom-test.c), [tests/oom-test.c](../tests/oom-test.c) | not-proved |
| `function:tree.h:xmlNextElementSibling` | partial | 現在のUTF-8/UTF-16・読み取り専用DOMサブセット内。全オプション・全ノード型の等価性は未確認。 | [tests/api-test.c](../tests/api-test.c) | not-proved |
| `function:tree.h:xmlNodeGetContent` | partial | 現在のUTF-8/UTF-16・読み取り専用DOMサブセット内。全オプション・全ノード型の等価性は未確認。 | [tests/api-test.c](../tests/api-test.c) | not-proved |
| `function:tree.h:xmlUnlinkNode` | partial | 通常 child unlink のみ。attribute unlink は拒否。 | [tests/dom-test.c](../tests/dom-test.c) | not-proved |
| `function:xmlerror.h:xmlCopyError` | partial | Deep-copies owned strings transactionally for valid zero-initialized or previously reset destinations. | [tests/error-test.c](../tests/error-test.c), [tests/oom-test.c](../tests/oom-test.c), [tests/fuzz-test.c](../tests/fuzz-test.c) | not-proved |
| `function:xmlerror.h:xmlGetLastError` | partial | per-OS-thread last-error retrieval; supported numeric diagnostics and exact message text remain a documented subset. | [tests/error-test.c](../tests/error-test.c), [tests/error-snapshot.c](../tests/error-snapshot.c) | not-proved |
| `function:xmlerror.h:xmlResetError` | partial | Resets caller-owned xmlError records; foreign pointers remain caller responsibility. | [tests/error-test.c](../tests/error-test.c), [tests/fuzz-test.c](../tests/fuzz-test.c) | not-proved |
| `function:xmlerror.h:xmlResetLastError` | partial | Explicitly clears the calling thread's last error and owned strings. | [tests/error-test.c](../tests/error-test.c) | not-proved |
| `function:xmlstring.h:xmlStrEqual` | partial | 現在のUTF-8/UTF-16・読み取り専用DOMサブセット内。全オプション・全ノード型の等価性は未確認。 | [tests/api-test.c](../tests/api-test.c) | not-proved |
| `function:xmlstring.h:xmlStrcmp` | partial | 現在のUTF-8/UTF-16・読み取り専用DOMサブセット内。全オプション・全ノード型の等価性は未確認。 | [tests/api-test.c](../tests/api-test.c) | not-proved |
| `function:xmlstring.h:xmlStrlen` | partial | 現在のUTF-8/UTF-16・読み取り専用DOMサブセット内。全オプション・全ノード型の等価性は未確認。 | [tests/api-test.c](../tests/api-test.c) | not-proved |
| `macro:xmlmemory.h:xmlFree` | partial | 通常の解放呼び出しのみ。上流のallocator変数/マクロ差し替えは非互換。 | [tests/api-test.c](../tests/api-test.c) | not-proved |
| `variable:xmlmemory.h:xmlFree` | partial | 通常の解放呼び出しのみ。上流のallocator変数/マクロ差し替えは非互換。 | [tests/api-test.c](../tests/api-test.c) | not-proved |
