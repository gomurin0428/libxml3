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
make compare
make check
```

`make prove` はコア（`src/xml3_text.*` と `src/xml3_parser.*`）だけの
既存 `proof.gpr` を GNATprove で検査します。C 境界やヒープ所有権は
SPARK の保証範囲外です。保証範囲の詳細は [docs/assurance.md](docs/assurance.md)
と、コアの実行結果を記録した [docs/proof-report.md](docs/proof-report.md)
を参照してください。

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

主な初期サブセットは、メモリ入力の読み取り、要素・属性・テキスト・CDATA・
コメント・PI の DOM 閲覧、文字列関数、所有権付き getter です。固定上限や
非対応機能を含む実際の API 一覧は [docs/compatibility.md](docs/compatibility.md)
にあります。将来の完全 API 互換は目標であり、現在の実装が達成したという意味
ではありません。
