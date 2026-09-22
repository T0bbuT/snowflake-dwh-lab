# Snowflakeによるデータウェアハウス構築

ERP・CRM由来の販売データをSnowflakeへ取り込み、クレンジング・統合を経て分析用データモデルを提供する個人プロジェクトです。
ローカルのCSVを入力として、Bronze / Silver / Goldの3層でデータを管理します。

## 実装していること

- Snowflake CLIを使用した、ローカルCSVから内部ステージへのアップロード
- ストアドプロシージャによるBronze / Silverのロード
- 重複排除、欠損・不整合の補正、コード値や日付形式の標準化
- ERP・CRMデータを統合したディメンション／ファクトビューの提供
- Event Tableへのロード状況・処理件数・エラーの記録
- Silver / Goldを対象としたデータ品質チェック
- 必須CSVが不足している場合に、既存のBronzeデータを保持してロードを中止する制御

## データアーキテクチャ

データ基盤は、Bronze / Silver / Goldの3層で構成するメダリオンアーキテクチャを採用しています。

![データアーキテクチャ](docs/data_architecture.drawio.svg)

- **Bronze**: ERP・CRM由来のCSVを、項目構造を保って取り込むレイヤ
- **Silver**: データのクレンジング・標準化・統合を行うレイヤ
- **Gold**: 分析やレポート向けに、スタースキーマを構成するディメンション／ファクトビューを提供するレイヤ

Bronze / Silverのロードは `TRUNCATE` と `INSERT` による全件入れ替え方式です。現在は入力CSVの内容を最新状態として反映し、SCDなどの履歴管理は実装していません。

## 対象データと分析用途

データソースは、CSVファイルとして提供されるERP・CRMの2系統です。Silverで各ソースをクレンジング・標準化し、Goldで顧客、商品、売上を結合可能な単一のデータモデルに整理します。

Goldのデータモデルでは、主に次の分析用途を想定しています。

- 顧客属性ごとの購買傾向
- 商品・カテゴリー別の販売実績
- 期間別の販売トレンド

Goldの各ビューの定義は[データカタログ](docs/data_catalog.md)を参照してください。

## セットアップ手順

初めて構築するときは、[セットアップとデータ更新の実行順序](docs/setup.md)を参照してください。
接続準備 → DB・ステージ・テーブル・プロシージャの作成 → ログ設定 → CSVアップロード → Bronze / Silverのロード → Goldの作成・品質確認までをまとめています。構築後のデータ更新や、定義変更時の再実行範囲も同じページに記載しています。

### CSVの取り込み手順

ローカルの `datasets/` にあるCSVをSnowflake CLIで内部ステージへアップロードし、Bronzeテーブルへ取り込みます。
実行コマンドは[セットアップガイドの手順7以降](docs/setup.md#7-csvをステージへアップロードする)、オプションやエラー時の説明は[CSVアップロードの補足](docs/load-local-csv.md)を参照してください。

## リポジトリ構成

主要なディレクトリの役割は次のとおりです。個別の実行ファイルと実行順序は[セットアップガイド](docs/setup.md)にまとめています。

```text
snowflake-dwh-lab/
├── datasets/             # 取り込み元のERP・CRMデータ
├── docs/                 # 設計資料・セットアップ手順・検証記録
├── scripts/
│   ├── setup/            # 初回構築・再構築
│   ├── logging/          # Event Tableとロードログの設定・確認
│   ├── bronze/           # Bronzeのテーブル定義・ロード処理
│   ├── silver/           # Silverのテーブル定義・変換処理
│   └── gold/             # Goldの分析用ビュー定義
└── tests/                # Silver / Goldのデータ品質チェック
```

## 参考・謝辞

本プロジェクトは、Baraa Khatib Salkini氏の[SQL Data Warehouse Project](https://github.com/DataWithBaraa/sql-data-warehouse-project)を出発点としており、コード・データ・図の一部を利用しています。元プロジェクトのSQL Server向け構成を参考にしつつ、Snowflake向けのデータ取り込み、レイヤ設計、ロード処理、ログ、品質検証などを再設計・実装しています。

関連講座: [SQL Data Warehouse Portfolio Project（YouTube）](https://www.youtube.com/playlist?list=PLNcg_FV9n7qaUWeyUkPfiVtMbKlrfMqA8)

## ライセンス

本リポジトリは[MITライセンス](LICENSE)の下で公開されています。
