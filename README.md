# GitHub Helper Scripts

GitHub リポジトリ管理を補助するスクリプト集。

## 前提条件

- [GitHub CLI (`gh`)](https://cli.github.com/) がインストール済みであること
- 対象リポジトリ・Org への適切な権限があること
- SAML SSO が必要な Org の場合は `gh auth refresh` で認可済みであること

---

## add_topic.sh

リポジトリにトピックを追加する。トピックが既に存在する場合でも重複せず正常終了する。

### 使い方

```bash
./gh-helper/add_topic.sh <repo_url> <topic_name>
```

### 例

```bash
./gh-helper/add_topic.sh https://github.com/example-org/my-repo java
```

### 出力例

```
✓ 'java' -> example-org/my-repo (topics: java)
```

---

## add_team_permission.sh

GitHub チームにリポジトリへの権限を付与する。

### 使い方

```bash
./add_team_permission.sh <repo_url> <team_slug> <permission>
```

| 権限 | 説明 |
|------|------|
| `pull` | 読み取りのみ |
| `push` | 読み書き |
| `triage` | Issue / PR のトリアージ |
| `maintain` | リポジトリ管理（設定変更を除く） |
| `admin` | フル管理権限 |

### 例

```bash
./add_team_permission.sh https://github.com/example-org/api-server team_a admin
./add_team_permission.sh https://github.com/example-org/api-server team_b push
```

### 出力例

```
✓ admin 権限を付与: team_a -> example-org/api-server
```

### team_slug の確認方法

```bash
gh api /orgs/<org>/teams --jq '.[].slug'
```
