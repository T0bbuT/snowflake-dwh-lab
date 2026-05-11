# Snowflake Git Workspace セットアップガイド

Git Workspace を作成して既存の Git リポジトリと接続することで、Snowsight 上でリポジトリの内容を参照・編集し、commit/push まで行えます。

## 前提条件

- **ロール:** ACCOUNTADMIN（または `CREATE INTEGRATION` 権限を持つロール）
- **リポジトリ:** 最低1つのブランチが存在すること（空リポジトリは不可）
- **ネットワーク:** パブリックネットワーク経由での接続（Private Link 環境では OAuth 非対応）

---

## Step 1: OAuth を使った GitHub API インテグレーション作成

GitHub の場合、Snowflake GitHub App（事前構成済み OAuth2 アプリ）が使えるため、OAuth アプリの登録やリダイレクト URI の設定は不要です。

```sql
USE ROLE ACCOUNTADMIN;

CREATE OR REPLACE API INTEGRATION github_api_integration
  API_PROVIDER = git_https_api
  API_ALLOWED_PREFIXES = ('https://github.com')
  API_USER_AUTHENTICATION = (TYPE = SNOWFLAKE_GITHUB_APP)
  ENABLED = TRUE;
```

作成後の確認:

```sql
SHOW API INTEGRATIONS;
DESCRIBE INTEGRATION github_api_integration;
```

---

## Step 2: Snowsight 上で Git Workspace を作成してリポジトリと接続

API 統合の作成後、以下の手順を実施します。

1. Snowsight にサインイン
2. **Projects → Workspaces → 「From Git repository」** を選択
3. リポジトリ URL を入力（例: `https://github.com/<user>/<repo>`）
4. API インテグレーションで `github_api_integration` を選択
5. 認証方式で「OAuth2」を選択し **「Sign in」** をクリック
6. GitHub 側で **Snowflake Computing** アプリを Authorize
   - Read access to metadata
   - Read and write access to code
7. Repository access で対象リポジトリへのアクセスを指定 → **Save**
8. **「Create」** をクリックして完了

---

## Step 3: Workspace 上での Git 操作（参考）

| 操作 | 手順 |
|------|------|
| ブランチ切替 | Changes タブ → ブランチドロップダウンから選択 |
| 新規ブランチ | Changes タブ → ブランチドロップダウン → **+ New** |
| リモート取得 | Changes タブ → Pull ▼ → **Fetch All** |
| 差分確認 | Changes タブ → 変更ファイルを選択（M=変更, A=追加, D=削除） |
| コミット & プッシュ | Changes タブ → コミットメッセージ入力 → **Push** |
| コンフリクト解消 | Push 時に検出 → Pull → インライン diff で解決 → 再 Push |

---

## クリーンアップ（不要になった場合）

```sql
DROP INTEGRATION github_api_integration;
DROP SECRET IF EXISTS <YOUR_DB>.<YOUR_SCHEMA>.git_secret;
```
