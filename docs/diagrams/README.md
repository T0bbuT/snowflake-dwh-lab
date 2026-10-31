# 図のソース

READMEなどに載せる図を、[D2](https://d2lang.com/)のコードで管理する。図を変えるときは `.d2` を編集し、SVGを生成し直して両方をコミットする。

| ソース | 生成するSVG | 掲載先 |
| --- | --- | --- |
| `data_architecture.d2` | `data_architecture.svg` | README「データアーキテクチャ」 |

## 生成方法

D2のCLIは `mise.toml` で管理している。リポジトリ直下で実行する。

```bash
mise install
d2 docs/diagrams/data_architecture.d2 docs/diagrams/data_architecture.svg
```

アイコン画像はSVGの中に埋め込まれるため、生成後のSVG単体で表示できる。

## アイコンの出典

`icons/` のSVGは、次のアイコンセットを元に色だけ変えたもの。`arrow.svg` と `arrow-outer.svg` は本リポジトリで作成した。

- `folder`、`db-*`、`bi`、`sql`、`ml`: [Tabler Icons](https://tabler.io/icons)（MIT License）
- `snowflake`: [Simple Icons](https://simpleicons.org/)（CC0 1.0）。Snowflakeのロゴは同社の商標。
