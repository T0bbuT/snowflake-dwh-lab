/*
================================
DB、スキーマの作成
================================
コードの目的:
    本コードは'DATA_WAREHOUSE'という名前の新しいデータベースを作成します。
    もし同名のデータベースが存在した場合、それは上書きされます。
    その後、3つのスキーマ('bronze', 'silver', 'gold')を作成します。

注意:
    本コードを実行すると、既存の'DATA_WAREHOUSE'という名前のデータベースは完全にその内容が削除されます。
    全てのデータが永久に失われてしまいますので、
    本コードを実行する際は慎重に、適切なバックアップがあることを確認してください。
*/

-- ロール、ウェアハウスの設定
USE ROLE SYSADMIN;
USE WAREHOUSE COMPUTE_WH;   -- 存在しない場合は適当なウェアハウスを選択

-- データベース作成
CREATE OR REPLACE DATABASE DATA_WAREHOUSE;
USE DATABASE DATA_WAREHOUSE;

-- スキーマ作成
CREATE OR REPLACE SCHEMA STAGING;   -- csvデータを入れるための専用スキーマ
CREATE OR REPLACE SCHEMA BRONZE;
CREATE OR REPLACE SCHEMA SILVER;
CREATE OR REPLACE SCHEMA GOLD;