# Snowflake CLI キーペア認証 設定ガイド

MFA認証が有効な環境では、Snowflake CLIからパスワードのみで接続できません。
キーペア認証を設定することで、CLIからの接続が可能になります。

## 全体の流れ

1. キーペアの作成（ローカル）
2. 公開鍵をユーザーに登録（Snowflake）
3. Snowflake CLI の接続設定（ローカル）
4. 接続テスト（ローカル）

---

## 1. 秘密鍵を生成

```bash
openssl genrsa 2048 | openssl pkcs8 -topk8 -inform PEM -out rsa_key.p8 -nocrypt
```

## 2. 公開鍵を生成

```bash
openssl rsa -in rsa_key.p8 -pubout -out rsa_key.pub
```

## 3. 鍵を安全な場所に保存

```bash
mkdir -p ~/.snowflake
mv rsa_key.p8 ~/.snowflake/
mv rsa_key.pub ~/.snowflake/
chmod 0600 ~/.snowflake/rsa_key.p8
```

---

## 4. 公開鍵をユーザーに登録（Snowflake で実行）

公開鍵の中身を取得します。

```bash
cat ~/.snowflake/rsa_key.pub
```

出力から `-----BEGIN PUBLIC KEY-----` / `-----END PUBLIC KEY-----` ヘッダーと改行を除いた文字列をコピーし、以下の SQL を Snowsight 等で実行します。

```sql
ALTER USER <YOUR_USERNAME> SET RSA_PUBLIC_KEY='<公開鍵の文字列>';
```


## 5. 登録の確認（Snowflake で実行）

```sql
DESC USER <YOUR_USERNAME>;
```

`RSA_PUBLIC_KEY_FP` に値が入っていれば登録成功です。

---

## 6. Snowflake CLI の接続設定

`~/.snowflake/connections.toml` に以下を追加します。

```toml
[my_connection]
account = "<YOUR_ACCOUNT>"
user = "<YOUR_USERNAME>"
authenticator = "SNOWFLAKE_JWT"
private_key_file = "~/.snowflake/rsa_key.p8"
warehouse = "<YOUR_WAREHOUSE>"
role = "<YOUR_ROLE>"
```

## 7. 接続テスト

```bash
snow connection test -c my_connection
```

成功すれば設定完了です。
