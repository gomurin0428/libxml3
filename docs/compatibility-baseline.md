# 互換性の基準と進め方

## 固定する対象

主基準は **libxml2 2.15.4**、上流タグ `v2.15.4` のコミット
`96498992efa48d52b0e8b83058bd88dbdaf153c1` です。
[上流ソース](https://github.com/GNOME/libxml2/tree/v2.15.4) の公開Cヘッダーを
対象とし、既存Cソースの再コンパイルを許容します。ABI互換は対象外です。
OS付属のlibxml2（Ubuntuでは2.9系）は補助的な回帰比較先であり、主基準として取り違えません。
基準版で直っている古い版の既知の差は `eng/compare_system.py` に版の範囲付きで記録します。

`compat/baseline.json` がタグ・コミット・ビルドオプションの唯一の設定元です。
Linux x86_64 / Clang 14 / C11で、CMake既定の機能に加えてlegacy、HTTP互換stub、
Schematron、thread allocatorを有効化します。
抽出器と参照ライブラリのコンパイラをともにClang 14に固定します。HTTP有効化はネットワーク機能の
復活ではありません。ICU・TLSは無効で、iconvは有効です。
Windows、Cygwin、別コンパイラ、機能無効構成との条件付き宣言差分は未監査です。
したがって、この台帳だけで全プラットフォームの全APIを網羅したとは主張しません。

## 台帳と証拠

`compat/api-inventory.json` はインストール対象の46ヘッダーをlibclangで解析した
宣言台帳です。関数、変数、typedef、コールバック、struct/union、フィールド、
enum/定数、マクロを区別し、宣言・ヘッダー・行番号・ヘッダーSHA-256を保存します。
前方宣言と定義は統合します。匿名の型はソース位置で識別します。
型表記にClangが付加するソース位置はincludeディレクトリからの相対パス
（`libxml/encoding.h:205:5` 等）で保存し、チェックアウト先に依存させません。
型・行番号・ヘッダーハッシュの差は引き続き検出します。マクロの字句は変更しません。
マクロにはインクルードガードやコンパイラ補助マクロも含まれるため、合計件数を
API互換率の分母に使ってはいけません。ヘッダーの使用許諾は `compat/Copyright.libxml2`。

allocatorのマクロと公開変数は排他的な宣言なので、同じ固定ヘッダーから
thread allocator構成と、`xmlversion.h` 読み込み後に
`LIBXML_THREAD_ALLOC_ENABLED` をundefしたglobal allocator構成を別々に解析して
統合します。各宣言の `profiles` に由来を記録します。実行比較用ライブラリは
thread allocator有効構成の一つのみで、global allocator動作の比較までは行いません。
`nm -D` で得た全exportが関数/変数台帳に存在することも検査します。

`compat/coverage.json` は現在評価した項目の実装範囲・テスト・証明境界です。
未評価を「実装完了」にせず、partialは狭いプロファイルのみを意味します。
通常呼び出せる `xmlFree` も、上流の変更可能なallocator変数/マクロとは非互換です。
構造体フィールドの型・可変性、コールバック、定数の意味なども今後評価します。
生成された[概要](api-coverage.md)と機械可読の全台帳を一緒に管理します。
C APIへの証明ステータスは現在すべて `not-proved` です。公開DOM操作の状態遷移・
所有権・寿命判断はSPARK Store/Runtimeへ接続済みですが、C ABI・native pointer・
allocator・mutexは信頼境界です。SPARKの検証結果をC APIやXML全仕様の証明として
数えません。最新の証明範囲と記録は [assurance.md](assurance.md) と
[proof-report.md](proof-report.md) を参照してください。

## 再現手順

```sh
./eng/bootstrap.sh
make reference        # 初回は上流を取得。システムlibxml2は変更しない
make check-inventory  # 抽出器テスト、台帳/レポート差分、exportとの照合
make compare          # 固定2.15.4。ヘッダーと実行時バージョンを確認
make compare-system   # OSのlibxml2による補助比較
```

参考ライブラリを用意していない `make compare` は明示的に失敗します。
構成ごとにCMakeキャッシュを分離し、ビルド前にコンパイラ・オプション・
インストール先の実設定を照合します。設定が変わった場合はインストールしません。
勝手にシステム版へ切り替えません。現在の比較コーパスは既存の15例であり、
未実装APIが試験済みになるわけではありません。
`make inventory` で再生成、`eng/api_inventory.py --report-only` で保存済み台帳から
レポートのみ再生成できます。ヘッダーハッシュが変われば再生成も拒否します。
基準変更時は、タグ・コミット・構成・旧新API差分を独立したPRで監査してから
旧台帳を置き換え、coverageの不明キーをすべて解消してください。

## 段階ごとの完了条件

1. **基盤（今回）**: バージョン・構成の固定、宣言台帳、主/補助比較の分離。
2. **XML読み込み**: 名前空間→Unicode名→文字コード/宣言/エラー→設定可能な資源制限。
3. **DOM変更と保存**: 作成・移動・削除・コピー・限定的な明示UTF-8メモリ出力、
   所有権の契約。
4. **I/Oとストリーミング**: コールバック/ファイル、push、SAX、reader/writer。
5. **上位機能**: DTD/エンティティ、XPath、HTML、XInclude、Schema/Relax NG、C14N等。
6. **実アプリ置換**: 再コンパイル、適合性テスト、比較ファジング、継続証明。

各段階は対応API、値・エラー・所有権・副作用の比較、回帰テスト、証明の更新を
揃えて完了とします。未実装動作のstubで成功を返して実装数を増やしません。
将来の互換動作と安全プロファイル（外部アクセス/資源制限）は明示的に区別し、
安全制限による差を互換だと呼ばない方針です。現時点ではどちらの完全実装もありません。

シリアライズは `xmlDocDumpMemoryEnc` の明示的な UTF-8 指定だけを実装範囲とします。
encoding名は ASCII case-insensitive で照合し、XML宣言には呼び出し側の表記を保持します。
XML 1.0以外、未知・空のencoding、XML名/文字/namespaceの不正状態は安全側で拒否します。
これはlibxml2の全シリアライズ動作との等価性を意味しません。暗黙encoding、
`xmlDocDumpMemory`、formatting、ファイル保存、DTD、namespace修復は対象外です。
Documentに保持されないsource encodingとstandalone metadataは出力宣言に含めません。
要素のないDocumentはXML宣言だけを出力する場合があります。
