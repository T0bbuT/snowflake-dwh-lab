-- ========================================
-- Snowflake Git Workspaceのセットアップ
-- ---------------------------------------
-- Git Workspaceを作成して、既存のgitリポジトリと接続することでsnowsight上で
-- リポジトリの内容を参照・編集し、commit/pushまで行える
-- ========================================
-- 前提条件
-- ========================================
-- ロール: ACCOUNTADMIN（または CREATE INTEGRATION 権限を持つロール）
-- リポジトリ: 最低1つのブランチが存在すること（空リポジトリは不可）
-- ネットワーク: パブリックネットワーク経由での接続（Private Link環境ではOAuth非対応）
-- ========================================

-- ========================================
-- Step 1: OAuth を使った GitHub API インテグレーション作成
-- ========================================
-- GitHub の場合、Snowflake GitHub App（事前構成済みOAuth2アプリ）が使えるため
-- OAuthアプリの登録やリダイレクトURIの設定は不要
USE ROLE ACCOUNTADMIN;

CREATE OR REPLACE API INTEGRATION github_api_integration
  API_PROVIDER = git_https_api
  API_ALLOWED_PREFIXES = ('https://github.com')
  API_USER_AUTHENTICATION = (TYPE = SNOWFLAKE_GITHUB_APP)
  ENABLED = TRUE;

-- 作成後の確認
SHOW API INTEGRATIONS;
DESCRIBE INTEGRATION github_api_integration;

-- ========================================
-- Step 2: Snowsight上でGit Workspaceを作成してリポジトリと接続
-- ========================================
-- API統合の作成後、以下の手順を実施：
--   1. Snowsightにサインイン
--   2. Projects → Workspaces → 「From Git repository」を選択
--   3. リポジトリ URL を入力（例: https://github.com/my-user/my-repo-name）
--   4. API インテグレーション: github_api_integration を選択
--   5. 認証方式で「OAuth2」を選択し「Sign in」をクリック
--   6. GitHub側で Snowflake Computing アプリを Authorize
--      - Read access to metadata
--      - Read and write access to code
--      の権限を付与すること
--   7. Repository access で対象リポジトリへのアクセスを指定 → Save
--   8. 「Create」をクリックして完了
--
-- ※ 管理者が一度 Authorize すれば、同アカウント内の全ユーザーが利用可能

-- ========================================
-- Step 3: Workspace上でのGit操作（参考）
-- ========================================
-- ブランチ切替:  Changes タブ → ブランチドロップダウンから選択
-- 新規ブランチ:  Changes タブ → ブランチドロップダウン → + New
-- リモート取得:  Changes タブ → Pull ▼ → Fetch All
-- 差分確認:      Changes タブ → 変更ファイルを選択（M=変更, A=追加, D=削除）
-- コミット&プッシュ: Changes タブ → コミットメッセージ入力 → Push
-- コンフリクト解消: Push時に検出 → Pull → インラインdiffで解決 → 再Push

-- ========================================
-- クリーンアップ（不要になった場合）
-- ========================================
-- DROP INTEGRATION github_api_integration;
-- DROP SECRET IF EXISTS my_db.my_schema.git_secret;