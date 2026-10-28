#!/usr/bin/env python3
"""
===============================================================================
品質チェックの一括実行: Silver / Gold
===============================================================================
スクリプトの目的:
    tests/quality_checks_silver.sql と tests/quality_checks_gold.sql を
    Snowflake CLI(snow)で実行し、結果の一覧とFAIL・WARNの件数・例を表示する。

終了コード:
    0: FAILなし(WARNのみの場合も0。内容の確認を促すメッセージを表示する)
    1: FAILが1件以上ある
    2: SQLの実行失敗、または結果を取得・解釈できなかった

使用例:
    python3 tests/run_quality_checks.py -c my_connection \
        --role SYSADMIN --warehouse COMPUTE_WH --db "$DB"

使用上の注意:
    - 参照のみで、DBの再作成やロードは行わない。
    - 標準ライブラリのみを使う。snow はPATH上にあるものを使う。
===============================================================================
"""

import argparse
import json
import subprocess
import sys
from pathlib import Path

EXIT_OK = 0
EXIT_FAIL = 1
EXIT_ERROR = 2

TESTS_DIR = Path(__file__).resolve().parent
CHECK_FILES = {
    "silver": TESTS_DIR / "quality_checks_silver.sql",
    "gold": TESTS_DIR / "quality_checks_gold.sql",
}
REQUIRED_COLUMNS = ("check_id", "check_name", "severity", "failed_rows", "status", "examples")
STATUSES = ("PASS", "FAIL", "WARN")


class CheckError(Exception):
    """SQLの実行失敗、または結果を解釈できなかったことを表す。"""


def parse_args(argv):
    parser = argparse.ArgumentParser(description="Silver / Goldの品質チェックを実行する")
    parser.add_argument("-c", "--connection", required=True, help="snowの接続名")
    parser.add_argument("--role", help="使用するロール(省略時は接続の既定値)")
    parser.add_argument("--warehouse", help="使用するウェアハウス(省略時は接続の既定値)")
    parser.add_argument("--db", required=True, help="対象DB名(SQLの -D db= に渡す)")
    parser.add_argument(
        "--layer",
        choices=("all", "silver", "gold"),
        default="all",
        help="実行するレイヤ(既定: all)",
    )
    args = parser.parse_args(argv)
    if not args.db.strip():
        parser.error("--db に空文字は指定できません")
    return args


def run_check_file(args, sql_file):
    command = ["snow", "sql", "-c", args.connection]
    if args.role:
        command += ["--role", args.role]
    if args.warehouse:
        command += ["--warehouse", args.warehouse]
    command += ["-f", str(sql_file), "-D", f"db={args.db}", "--format", "json"]

    try:
        completed = subprocess.run(command, capture_output=True, text=True, check=False)
    except FileNotFoundError as e:
        raise CheckError("snow コマンドが見つかりません") from e

    if completed.returncode != 0:
        detail = (completed.stderr or completed.stdout).strip()
        raise CheckError(f"SQLの実行に失敗しました(終了コード {completed.returncode})\n{detail}")

    return parse_rows(completed.stdout)


def parse_rows(stdout):
    try:
        data = json.loads(stdout)
    except json.JSONDecodeError as e:
        raise CheckError(f"結果をJSONとして解釈できません: {e}\n{stdout.strip()[:500]}") from e

    # 複数ステートメントの場合はステートメントごとのリストになるため、最後の結果を使う
    if isinstance(data, list) and data and isinstance(data[0], list):
        data = data[-1]
    if not isinstance(data, list) or not data:
        raise CheckError("品質チェックの結果が0行です")

    rows = []
    for raw in data:
        if not isinstance(raw, dict):
            raise CheckError(f"想定外の行形式です: {raw!r}")
        # Snowflakeは引用符なしの列名を大文字で返すため、小文字にそろえる
        row = {key.lower(): value for key, value in raw.items()}
        missing = [col for col in REQUIRED_COLUMNS if col not in row]
        if missing:
            raise CheckError(f"結果に列がありません: {', '.join(missing)}")
        if row["status"] not in STATUSES:
            raise CheckError(f"想定外のstatusです: {row['check_id']} {row['status']!r}")
        rows.append(row)
    return rows


def print_results(layer, rows):
    print(f"== {layer} ({len(rows)}件) ==")
    for row in rows:
        print(f"  {row['status']:<4}  {row['check_id']:<4}  {row['failed_rows']:>6}  {row['check_name']}")
    print()


def print_findings(title, rows):
    print(f"-- {title}: {len(rows)}件 --")
    for row in rows:
        print(f"  {row['check_id']} {row['check_name']}")
        print(f"    該当行数: {row['failed_rows']}  例: {row['examples'] or '(なし)'}")
    print()


def main(argv=None):
    args = parse_args(argv)
    layers = list(CHECK_FILES) if args.layer == "all" else [args.layer]

    all_rows = []
    for layer in layers:
        try:
            rows = run_check_file(args, CHECK_FILES[layer])
        except CheckError as e:
            print(f"ERROR: {layer} の品質チェックを実行できませんでした。\n{e}", file=sys.stderr)
            return EXIT_ERROR
        print_results(layer, rows)
        all_rows += rows

    fails = [row for row in all_rows if row["status"] == "FAIL"]
    warns = [row for row in all_rows if row["status"] == "WARN"]
    if fails:
        print_findings("FAIL", fails)
    if warns:
        print_findings("WARN", warns)

    passes = len(all_rows) - len(fails) - len(warns)
    print(f"対象DB: {args.db}  PASS {passes}件 / FAIL {len(fails)}件 / WARN {len(warns)}件")
    if fails:
        print("結果: FAIL。examples を手がかりに調査してください。")
        return EXIT_FAIL
    if warns:
        print("結果: WARNあり。件数と例を確認し、仕様どおりか判断してください。")
    else:
        print("結果: すべてPASSです。")
    return EXIT_OK


if __name__ == "__main__":
    sys.exit(main())
