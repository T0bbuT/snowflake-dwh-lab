/*
================================================================================
ログ保存先の作成
================================================================================
前提: DB・STAGINGスキーマをSYSADMINで作成済みであること。
Event Tableがなければ作成する。再実行しても既存ログは保持する。
出力先の設定は configure_event_target.sql、ログレベルは configure_logging.sql を参照。
================================================================================
*/

USE ROLE SYSADMIN;

CREATE EVENT TABLE IF NOT EXISTS DATA_WAREHOUSE.STAGING.LOAD_EVENTS;
