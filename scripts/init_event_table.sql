/*
================================================================================
Event Table セットアップ
================================================================================
目的:
    ストアドプロシージャからのログを永続的に記録するための Event Table を作成し、
    アカウントのアクティブ Event Table として設定する。

前提:
    - SYSADMIN / ACCOUNTADMIN ロールが必要
    - DB・STAGINGスキーマと両ロードプロシージャをSYSADMINで作成済みであること
    - 初回構築時、およびDB・プロシージャの再作成後に実行する

使用例:
    このスクリプトを上から順に実行する
================================================================================
*/

use role sysadmin;

-- Event Table の作成
create event table if not exists data_warehouse.staging.load_events;

-- アカウントのアクティブ Event Table として設定
use role accountadmin;
alter account set event_table = 'DATA_WAREHOUSE.STAGING.LOAD_EVENTS';

-- プロシージャのログレベルをINFOに設定
use role sysadmin;
alter procedure data_warehouse.bronze.load_bronze() set log_level = 'INFO';
alter procedure data_warehouse.silver.load_silver() set log_level = 'INFO';
