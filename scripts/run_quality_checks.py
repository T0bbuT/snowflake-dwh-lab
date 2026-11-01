#!/usr/bin/env python3
"""
===============================================================================
品質チェック一括実行: Silver・Gold
===============================================================================
スクリプトの目的:
    tests/ の品質チェック(Silver・Gold)を snow で順に実行し、結果を1つの表に
    まとめて表示する。FAILがあれば終了コード1で終わる。

使い方:
    python3 scripts/run_quality_checks.py --db "$DB" -c my_connection

終了コード:
    0: FAILなし(WARNのみの場合を含む)
    1: FAILが1件以上
    2: snow の実行に失敗(接続エラー、対象DB・テーブルが存在しないなど)

使用上の注意:
    - リポジトリのルートで実行する。
    - チェックは参照のみ。片方がFAILでも、両方のチェックを最後まで実行する。
===============================================================================
"""

import argparse
import json
import subprocess
import sys

CHECKS = [
    ("silver", "tests/quality_checks_silver.sql"),
    ("gold", "tests/quality_checks_gold.sql"),
]
ROLE = "SYSADMIN"
WAREHOUSE = "COMPUTE_WH"


def run_check(sql_file, db, connection):
    """チェックSQLを実行し、結果の行(dictのリスト)を返す。失敗時はNone。"""
    command = [
        "snow", "sql",
        "-c", connection,
        "--role", ROLE,
        "--warehouse", WAREHOUSE,
        "-f", sql_file,
        "-D", f"db={db}",
        "--format", "json",
    ]
    result = subprocess.run(command, capture_output=True, text=True)
    if result.returncode != 0:
        sys.stderr.write(result.stderr or result.stdout)
        return None
    rows = json.loads(result.stdout)
    # 複数のステートメントを含む場合は文ごとのリストになるため、最後の結果を使う
    if rows and isinstance(rows[0], list):
        rows = rows[-1]
    return rows


def run_quality_checks(db, connection):
    """全チェックを実行して結果を表示し、終了コード(0/1/2)を返す。"""
    results = []
    has_error = False
    for layer, sql_file in CHECKS:
        print(f"実行中: {layer} ({sql_file}) on {db}", file=sys.stderr)
        rows = run_check(sql_file, db, connection)
        if rows is None:
            print(f"エラー: {layer} のチェックを実行できませんでした", file=sys.stderr)
            has_error = True
            continue
        results.extend((layer, row) for row in rows)

    print(f"{'layer':<7} {'check_id':<8} {'status':<6} {'failed_rows':>11}  check_name")
    for layer, row in results:
        print(
            f"{layer:<7} {row['CHECK_ID']:<8} {row['STATUS']:<6} "
            f"{row['FAILED_ROWS']:>11}  {row['CHECK_NAME']}"
        )
        if row["STATUS"] != "PASS" and row["EXAMPLES"]:
            print(f"{'':<36}examples: {row['EXAMPLES']}")

    counts = {status: 0 for status in ("PASS", "WARN", "FAIL")}
    for _, row in results:
        counts[row["STATUS"]] += 1
    print()
    print(f"PASS {counts['PASS']}件 / WARN {counts['WARN']}件 / FAIL {counts['FAIL']}件")

    if has_error:
        print("結果: 実行エラーあり")
        return 2
    if counts["FAIL"] > 0:
        print("結果: FAILあり")
        return 1
    print("結果: FAILなし")
    return 0


def main():
    parser = argparse.ArgumentParser(description="Silver・Goldの品質チェックをまとめて実行する")
    parser.add_argument("--db", required=True, help="対象DB名(例: DATA_WAREHOUSE)")
    parser.add_argument("-c", "--connection", default="my_connection", help="snow の接続名")
    args = parser.parse_args()
    return run_quality_checks(args.db, args.connection)


if __name__ == "__main__":
    sys.exit(main())
