#!/usr/bin/env python3
"""
===============================================================================
検証DBでの一括検証: 構築・ロード・品質チェック・Goldの比較
===============================================================================
スクリプトの目的:
    リポジトリのSQLから検証DBを構築し、CSVのアップロードからGoldの品質チェック
    まで実行する。最後に検証DBと比較元DBのGoldの中身が一致するかを比べ、
    検証DBを削除する。作りを変えたときに結果が変わっていないことを確かめるため。

使い方:
    python3 scripts/verify_in_test_db.py -c my_connection

    --compare-db: 比較元のDB(既定: DATA_WAREHOUSE)
    --keep: 終了後も検証DBを削除せずに残す(失敗の調査用)

終了コード:
    0: ロード成功、品質チェックのFAILなし、Goldが一致
    1: 品質チェックでFAILあり、またはGoldに差分あり
    2: 構築・ロードの途中でエラー(ロードプロシージャが ERROR: ... を返した場合を含む)

使用上の注意:
    - 検証DB名は DATA_WAREHOUSE_VERIFY_<日時> で自動決定し、既存のDBと重なる場合は
      何もせずに終了する。
    - ログ出力先の設定(configure_event_target.sql)に ACCOUNTADMIN を使用する。
      設定するのは検証DB単位で、アカウント全体の設定は変更しない。
    - 途中で失敗しても、--keep を付けない限り検証DBを削除する。
===============================================================================
"""

import argparse
import json
import os
import subprocess
import sys
from datetime import datetime
from pathlib import Path

from run_quality_checks import run_quality_checks

REPO_ROOT = Path(__file__).resolve().parent.parent
TEST_DB_PREFIX = "DATA_WAREHOUSE_VERIFY_"
ROLE = "SYSADMIN"
WAREHOUSE = "COMPUTE_WH"

# docs/setup.md の手順1〜6
SETUP_FILES = [
    "scripts/setup/rebuild.sql",
    "scripts/logging/ensure_event_table.sql",
    "scripts/logging/configure_event_target.sql",
    "scripts/bronze/proc_load_bronze.sql",
    "scripts/silver/proc_load_silver.sql",
    "scripts/logging/configure_logging.sql",
]
CSV_DIRS = ["datasets/source_crm", "datasets/source_erp"]
REQUIRED_FILES = [
    "datasets/source_crm/cust_info.csv",
    "datasets/source_crm/prd_info.csv",
    "datasets/source_crm/sales_details.csv",
    "datasets/source_erp/CUST_AZ12.csv",
    "datasets/source_erp/LOC_A101.csv",
    "datasets/source_erp/PX_CAT_G1V2.csv",
]
GOLD_VIEWS = ["dim_customers", "dim_products", "fact_sales"]


class StepError(Exception):
    """構築・ロードの途中で失敗した。"""


def snow(args, connection, parse_json=False):
    """snow を実行する。失敗時は StepError。parse_json=True なら結果を返す。"""
    command = ["snow", *args, "-c", connection]
    if parse_json:
        command += ["--format", "json"]
    result = subprocess.run(command, capture_output=True, text=True)
    if result.returncode != 0:
        raise StepError(f"snow の実行に失敗しました: {' '.join(args[:3])}\n{result.stderr or result.stdout}")
    if parse_json:
        rows = json.loads(result.stdout)
        # 複数のステートメントを含む場合は文ごとのリストになるため、最後の結果を使う
        if rows and isinstance(rows[0], list):
            rows = rows[-1]
        return rows
    return None


def query(sql, connection):
    return snow(["sql", "--role", ROLE, "--warehouse", WAREHOUSE, "-q", sql], connection, parse_json=True)


def step(message):
    print(f"\n== {message}", flush=True)


def database_exists(db, connection):
    return bool(query(f"SHOW DATABASES LIKE '{db}'", connection))


def build_and_load(db, connection):
    """docs/setup.md の手順1〜12を実行する。"""
    step("手順1〜6: DB・テーブル・ログ設定・プロシージャを作成")
    for sql_file in SETUP_FILES:
        print(f"  {sql_file}", flush=True)
        snow(["sql", "-f", sql_file, "-D", f"db={db}"], connection)

    step("手順7: CSVをステージへアップロード")
    for csv_dir in CSV_DIRS:
        snow([
            "stage", "copy", f"{csv_dir}/*.csv", f"@{db}.STAGING.STG_CSV_FILES/{csv_dir}/",
            "--role", ROLE, "--database", db, "--schema", "STAGING",
            "--overwrite", "--no-auto-compress", "--refresh",
        ], connection)

    step("手順8: アップロード結果を確認")
    staged = {row["name"].split("/", 1)[1] for row in query(f"LIST @{db}.STAGING.STG_CSV_FILES", connection)}
    missing = [f for f in REQUIRED_FILES if f not in staged]
    if missing:
        raise StepError(f"ステージにないファイルがあります: {', '.join(missing)}")
    print(f"  {len(REQUIRED_FILES)}ファイルを確認")

    for label, procedure in [("手順9: Bronzeへロード", "BRONZE.LOAD_BRONZE"), ("手順10: Silverへロード", "SILVER.LOAD_SILVER")]:
        step(label)
        rows = query(f"CALL {db}.{procedure}()", connection)
        status = next(iter(rows[0].values()))
        print(f"  {status}")
        if status != "SUCCESS":
            raise StepError(f"{procedure} が SUCCESS を返しませんでした: {status}")

    step("手順12: Goldを作成")
    snow(["sql", "--role", ROLE, "--warehouse", WAREHOUSE, "-f", "scripts/gold/ddl_gold.sql", "-D", f"db={db}"], connection)


def compare_gold(db, compare_db, connection):
    """Goldの各ビューを比較元と比べ、差分がなければTrueを返す。"""
    step(f"Goldの比較: {db} と {compare_db}")
    selects = []
    for view in GOLD_VIEWS:
        test, base = f"{db}.GOLD.{view}", f"{compare_db}.GOLD.{view}"
        selects.append(
            f"SELECT '{view}' AS view_name,"
            f" (SELECT COUNT(*) FROM {test}) AS test_rows,"
            f" (SELECT COUNT(*) FROM {base}) AS base_rows,"
            f" (SELECT COUNT(*) FROM (SELECT * FROM {test} EXCEPT SELECT * FROM {base})) AS only_in_test,"
            f" (SELECT COUNT(*) FROM (SELECT * FROM {base} EXCEPT SELECT * FROM {test})) AS only_in_base"
        )
    rows = query(" UNION ALL ".join(selects), connection)

    print(f"  {'view':<14} {'検証DB':>8} {'比較元':>8} {'検証DBのみ':>10} {'比較元のみ':>10}")
    matched = True
    for row in rows:
        print(
            f"  {row['VIEW_NAME']:<14} {row['TEST_ROWS']:>8} {row['BASE_ROWS']:>8}"
            f" {row['ONLY_IN_TEST']:>10} {row['ONLY_IN_BASE']:>10}"
        )
        if row["TEST_ROWS"] != row["BASE_ROWS"] or row["ONLY_IN_TEST"] or row["ONLY_IN_BASE"]:
            matched = False
            show_examples(row["VIEW_NAME"], db, compare_db, connection)
    print(f"  結果: {'一致' if matched else '差分あり'}")
    return matched


def show_examples(view, db, compare_db, connection):
    for label, left, right in [("検証DBのみ", db, compare_db), ("比較元のみ", compare_db, db)]:
        rows = query(
            f"SELECT * FROM (SELECT * FROM {left}.GOLD.{view} EXCEPT SELECT * FROM {right}.GOLD.{view}) LIMIT 3",
            connection,
        )
        for row in rows:
            print(f"    {view} {label}: {json.dumps(row, ensure_ascii=False, default=str)}")


def main():
    parser = argparse.ArgumentParser(description="検証DBで構築からGoldの比較までを一括で実行する")
    parser.add_argument("-c", "--connection", default="my_connection", help="snow の接続名")
    parser.add_argument("--compare-db", default="DATA_WAREHOUSE", help="比較元のDB(既定: DATA_WAREHOUSE)")
    parser.add_argument("--keep", action="store_true", help="終了後も検証DBを削除しない")
    args = parser.parse_args()

    # rebuild.sql の !source などがリポジトリルート基準のパスを使うため
    os.chdir(REPO_ROOT)

    db = TEST_DB_PREFIX + datetime.now().strftime("%Y%m%d_%H%M%S")
    if db == args.compare_db.upper():
        print(f"エラー: 検証DB名が比較元と同じです: {db}", file=sys.stderr)
        return 2
    try:
        if database_exists(db, args.connection):
            print(f"エラー: 同じ名前のDBが既にあります: {db}", file=sys.stderr)
            return 2
    except StepError as e:
        print(f"エラー: {e}", file=sys.stderr)
        return 2

    print(f"検証DB: {db}（比較元: {args.compare_db}）")
    exit_code = 0
    try:
        build_and_load(db, args.connection)

        step("手順11・13: 品質チェック")
        check_code = run_quality_checks(db, args.connection)
        if check_code == 2:
            raise StepError("品質チェックを実行できませんでした")

        gold_matched = compare_gold(db, args.compare_db, args.connection)
        if check_code == 1 or not gold_matched:
            exit_code = 1
    except StepError as e:
        print(f"\nエラー: {e}", file=sys.stderr)
        exit_code = 2
    finally:
        if args.keep:
            print(f"\n検証DBを残しました: {db}")
            print(f'  削除: snow sql -c {args.connection} --role {ROLE} -q "DROP DATABASE {db};"')
        else:
            step(f"検証DBを削除: {db}")
            try:
                snow(["sql", "--role", ROLE, "-q", f"DROP DATABASE IF EXISTS {db}"], args.connection)
            except StepError as e:
                print(f"エラー: 検証DBを削除できませんでした。手動で削除してください: {db}\n{e}", file=sys.stderr)
                exit_code = 2

    result = {0: "成功（ロード成功・FAILなし・Gold一致）", 1: "要確認（FAILまたはGoldの差分あり）", 2: "エラー"}
    print(f"\n結果: {result[exit_code]}")
    return exit_code


if __name__ == "__main__":
    sys.exit(main())
