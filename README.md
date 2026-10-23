# Docker Go Skeleton

Go Webアプリケーションの開発・ビルド環境です。nginx、Go＋Air、MySQL、PostgreSQL、RedisをDocker Composeで起動します。本番では生成したバイナリをsystemdで実行し、Dockerを必要としません。

Goアプリケーション自体は含みません。HTTPサーバは利用者自身が実装してください。フレームワークやディレクトリ構成の指定もありません。`src/`をモジュールルートとし、初期状態は空です。`src/`と`dist/`はGit管理対象外なので、アプリケーションのバージョン管理とバックアップは別途行ってください。

## 採用バージョン

| ソフトウェア | 指定バージョン |
|---|---|
| Go公式イメージ | `golang:1.27.3-bookworm` |
| Air | `v1.67.4` |
| nginx | `1.31` |
| MySQL | `9.7` |
| PostgreSQL | `18` |
| Redis | `7` |

2026-10-23に[Go公式配布情報](https://go.dev/dl/?mode=json)と[公式Dockerタグ定義](https://github.com/docker-library/official-images/blob/master/library/golang)でGo 1.27.3を確認しました。[Air v1.67.4](https://github.com/air-verse/air/releases/tag/v1.67.4)の[go.mod](https://github.com/air-verse/air/blob/v1.67.4/go.mod)はGo 1.26.0を要求します。GoとAirは固定し、その他のイメージタグはPHP版を踏襲しています。後者は同じタグでも更新されます。

Docker Engine、Compose v2.20以降相当（`depends_on.required`対応）、Make、POSIXシェルをホスト側で利用します。Goのホストインストールは不要です。Linux/WSLではLinux側のディレクトリを推奨します。

## ディレクトリ構成

```text
.
├── .env.sample
├── .gitignore
├── Makefile
├── docker-compose.yml
├── docker/
│   ├── go/          # Dockerfile、Air設定、開発・本番ビルドスクリプト
│   ├── nginx/       # Dockerfile、HTTPプロキシテンプレート
│   ├── mysql/init/init.sql
│   └── postgres/init/init.sql
├── scripts/setup.sh
├── deploy/
│   ├── systemd/app.service.example
│   ├── nginx/app.conf.example
│   └── caddy/Caddyfile.example
├── src/             # 空。利用者のGoモジュール
└── dist/            # 本番バイナリ
```

Gitは空ディレクトリを保存しないため、clone・ZIP展開後はsetupを実行してください。setupは既存ファイルや所有者・権限を変更しません。

## 初期セットアップ

### ZIPで取得する場合

GitHub上に新規リポジトリを作らず、手元に開発環境を用意する方法です。以下はLinux/WSLのホスト側シェルで実行し、`curl`と`unzip`が必要です。`my-go-app`は任意のプロジェクト名に変更できます。`docker-go-skeleton-main`や`my-go-app`、保存するZIPが既に存在する場合は、上書きせず別名または別の作業ディレクトリを使用してください。

```bash
# ZIPをダウンロード
curl -fL -o docker-go-skeleton.zip \
  https://github.com/gallu/docker-go-skeleton/archive/refs/heads/main.zip

# ZIPを展開
unzip docker-go-skeleton.zip

# ディレクトリ名を変更
mv docker-go-skeleton-main my-go-app

# プロジェクトへ移動
cd my-go-app

# 初期セットアップ
sh scripts/setup.sh

# 環境変数ファイルを作成
cp .env.sample .env

# 不要になったZIPを削除
rm ../docker-go-skeleton.zip
```

Privateリポジトリは匿名ではダウンロードできません。Public公開後はGitHubアカウントなしでも取得できます。ZIPにはGit履歴が含まれないため、Gitで管理する場合は必要に応じて`git init`してください。ただし、既定では`src/`と`dist/`はGit管理対象外です。[GitHub公式のZIP取得説明](https://docs.github.com/en/repositories/working-with-files/using-files/downloading-source-code-archives)も参照してください。

### GitHub Templateから作成する場合

GitHubにログインし、このリポジトリの「Use this template」→「Create a new repository」から所有者・名前・公開範囲を指定して作成し、新しいリポジトリをcloneします。詳細は[GitHub公式ドキュメント](https://docs.github.com/en/repositories/creating-and-managing-repositories/creating-a-repository-from-a-template)を参照してください。

### 取得後の初期化とアプリ配置

以下はすべてリポジトリルートのホスト側シェルで実行します。
ZIPの手順でsetupと`.env`作成を済ませた場合は、次の2コマンドを省略してGoモジュールの初期化へ進んでください。

```bash
sh scripts/setup.sh
cp .env.sample .env  # 既存.envがある場合は上書きせず確認する
```

ホストにGoがある場合の初期化:

```bash
cd src
go mod init example.com/myapp
cd ..
```

ホストにGoがない場合も、依存サービスやAirを起動せず初期化できます。

```bash
docker compose run --rm --no-deps --build --user "$(id -u):$(id -g)" \
  -e GOCACHE=/tmp/go-build -e GOPATH=/tmp/gopath go \
  go mod init example.com/myapp
```

`src/main.go`などを利用者が作成します。以下は最小HTTPサーバの例です（自動生成はされません）。

```go
package main

import (
    "fmt"
    "log"
    "net"
    "net/http"
    "os"
    "time"
)

func main() {
    port := os.Getenv("GO_PORT")
    if port == "" {
        port = "8080"
    }
    // 開発コンテナでは全インターフェース、本番では127.0.0.1を指定する。
    host := os.Getenv("GO_HOST")
    mux := http.NewServeMux()
    mux.HandleFunc("/", func(w http.ResponseWriter, r *http.Request) {
        fmt.Fprintln(w, "Hello, Go")
    })
    server := &http.Server{
        Addr: net.JoinHostPort(host, port), Handler: mux,
        ReadHeaderTimeout: 5 * time.Second,
    }
    log.Fatal(server.ListenAndServe())
}
```

Dockerは`GO_PORT`を環境変数として渡すだけです。アプリ自身が読み取り、nginxの転送先と同じポートで待ち受ける必要があります。開発時に`127.0.0.1`だけで待ち受けると別コンテナのnginxから接続できません。本番サンプルの`GO_HOST`もアプリ側での対応が必要です。実際のアプリではSIGTERM/SIGINTに対するgraceful shutdownも実装してください。

## 設定

`.env`は省略可能です。未設定または空文字でも以下が適用されます。ホストの環境変数は`.env`より優先されます。

| 変数 | 既定値 | 役割 |
|---|---|---|
| WEB_PORT | 8081 | ホスト側nginx公開ポート |
| GO_PORT | 8080 | Go HTTPサーバのポート |
| GO_BUILD_TARGET | . | srcを基準とした単一のmainパッケージ |
| GO_BINARY_NAME | app | dist内の本番ファイル名 |
| GOOS | linux | 本番対象OS |
| GOARCH | amd64 | 本番対象CPU |
| CGO_ENABLED | 0 | cgo使用の有無（開発・本番共通） |

例えば`.env`を`vi .env`で編集します。

```dotenv
WEB_PORT=9081
GO_PORT=9090
GO_BUILD_TARGET=./cmd/server
GO_BINARY_NAME=server
GOOS=linux
GOARCH=arm64
```

これで`src/cmd/server/`を開発・本番ともにビルドします。`GO_BUILD_TARGET`に`./...`や複数パッケージは指定しません。`GO_BINARY_NAME`は英数字、`.`、`_`、`-`からなるファイル名とし、パスや`.`、`..`は指定できません。

Composeの`${VAR:-default}`はホスト側で展開されます。nginx設定の`${GO_PORT}`は公式イメージの起動時envsubstで展開します。対象を`GO_PORT`だけに限定し、`$host`などのnginx変数を保持します。シェルスクリプト内の変数はコンテナ内で展開されます。Compose内でコンテナに`$`を渡す場合は`$$`でエスケープします。

本番用OS・CPUはコンテナ内の`GO_BUILD_OS`・`GO_BUILD_ARCH`に渡し、build.shでのみ`GOOS`・`GOARCH`へ適用します。開発用Airはコンテナ自身のOS・CPUでビルドするため、クロスコンパイル先の指定に影響されません。

必要なら`COMPOSE_PROJECT_NAME`も設定してください。同じ名前を別ディレクトリで共有すると同じDocker資産を操作するので、プロジェクトごとに固有の名前を使用します。

## 起動とAir

```bash
make up        # nginx、Go、Redis、MySQL、PostgreSQL
make up-mysql  # nginx、Go、Redis、MySQL
make up-pg     # nginx、Go、Redis、PostgreSQL
make ps
make logs
```

`http://localhost:8081/`へアクセスします。ポート変更時は`WEB_PORT`の値を使用してください。DB切替コマンドは不要側DBを停止してから起動します。データは保持します。profilesなしの`docker compose up`ではDBは起動しません。Goは選択されたDBのhealthcheck成功を待ちます。アプリ側にも接続リトライ・切断回復が必要です。

nginxだけがホストへポートを公開します。Go・DB・RedisはComposeネットワーク内のサービス名で接続します。ホスト公開がないことは、ネットワーク内の他サービスからの接続を禁止する意味ではありません。

Goコンテナは`src/go.mod`がなければ次のエラーで終了します。再起動ポリシーは設定していません。

```text
Go application is not initialized.
Please create src/go.mod and a Go application.
Example: cd src && go mod init example.com/myapp
```

初期化・アプリ配置後、もう一度`make up`してください。`go.mod`はあるがコンパイルできない場合はAirがエラーをログに出して監視を継続します。`.go`、`go.mod`、`go.sum`、テンプレート等の保存で再ビルドし、成功後にプロセスを起動します。ビルドエラー時は古いプロセスを停止する設定です。nginxは起動直後や再ビルド中に502を返すことがあります。

開発バイナリ・エラーログはコンテナ内の`/tmp/air/`に置き、本番の`dist/`と分離します。vendor・tmp・dist・.gitは監視対象外です。ファイル変更を検知できない環境では`docker/go/air.toml`の`[build]`に`poll = true`を追加してイメージを再ビルドしてください。

Go・Air設定変更後もup系は`--build`で再ビルドします。通常のソース変更ではupを再実行する必要はありません。

## DB・Redis接続

| サービス | 接続先（Goコンテナ内から） | ユーザー / パスワード | DB |
|---|---|---|---|
| MySQL | mysql:3306 | app / app | app、app_testing |
| PostgreSQL | postgres:5432 | app / app | app、app_testing |
| Redis | redis:6379 | 認証なし | 既定DB 0 |

MySQL rootは`root` / `root`、PostgreSQL管理者は`postgres` / `root`です。**これらは開発専用の初期認証情報です。本番環境で使用しないでください。** DBドライバーやRedisクライアントはアプリ側で選定・導入します。

```bash
make exec-mysql
# MySQLコンテナ内
mysql -u app -p app
# パスワード入力: app
```

```bash
make exec-pg
# PostgreSQLコンテナ内
psql -h localhost -U app -d app
# パスワード入力: app
```

```bash
# ホスト側からコンテナ内のRedis CLIを実行
docker compose exec redis redis-cli ping
```

DB初期化SQLはnamed volumeが空の初回のみ実行されます。SQL変更後にコンテナを再起動しても既存DBへ再適用されません。既存データには必要なSQLを確認して手動適用し、削除して作り直す場合は先にバックアップしてください。PostgreSQL 18のvolumeは`/var/lib/postgresql`へマウントします。旧メジャーバージョンのDB volumeを流用しないでください。

RedisはPHP版同様、AOFなしの開発用途です。永続化を保証しません。DBやRedisをホストのGUIから操作する場合は、利用者が必要なサービスだけ`127.0.0.1`へのports設定を追加してください。

## Makeコマンド

| コマンド | 動作 |
|---|---|
| make up | 両DBを含む開発環境起動・ビルド |
| make up-mysql | PostgreSQLを停止しMySQL構成を起動 |
| make up-pg | MySQLを停止しPostgreSQL構成を起動 |
| make down | 全profilesのコンテナ・ネットワークを削除。DB volume保持 |
| make clean | 当該Composeプロジェクトのコンテナ・ネットワーク・ローカルビルドイメージ・volumeを削除 |
| make ps | 全profilesの状態表示 |
| make logs | 全profilesのログを継続表示 |
| make exec-go | Goコンテナのbash |
| make exec-mysql | MySQLコンテナのbash |
| make exec-pg | PostgreSQLコンテナのbash |
| make build | 一時Goコンテナで本番用バイナリ生成 |
| make all-clean | Docker全体の`docker system prune -f` |
| make disintegrate | Docker全体の`docker system prune -a --volumes -f` |

`make down`と`make clean`はホストの`src/`・`dist/`を削除しません。`make clean`はDBデータを削除します。実行前にプロジェクト名とバックアップを確認してください。

**`make all-clean`と`make disintegrate`は他プロジェクトにも影響します。動作確認目的で実行しないでください。** 前者はDocker全体の停止コンテナ、未使用ネットワーク、dangling image、ビルドキャッシュを削除します。後者はさらに未使用イメージ全般・未使用の匿名volumeを削除します。named volumeの扱いはDockerバージョン・コマンド仕様を確認してください。`--volumes`を指定しても、現在のDockerではすべてのnamed volumeを削除する意味ではありません。

## 本番バイナリのビルド

ホスト側で実行します。

```bash
make build
file dist/app
```

GoコンパイラはDocker内のものを使い、開発コンテナの常時起動もnginx・DB・Redisの起動も不要です。`docker compose run --rm --no-deps --build`で実行し、既定で`linux/amd64`、`CGO_ENABLED=0`の`dist/app`を生成します。依存モジュールの取得にはネットワークが必要です。

一時ディレクトリへビルドしてから同じファイルシステム上で置き換えます。失敗時は非ゼロ終了し、不完全な新規成果物は残しません。既存の正常なバイナリがあればそのまま残るため、**コマンドの成功を確認してから配布してください**。同じ出力名への並列ビルドは避けてください。

複数mainがある場合も指定した一つだけをビルドします。バッチは個別指定してください。

```bash
GO_BUILD_TARGET=./cmd/server GO_BINARY_NAME=server make build
GO_BUILD_TARGET=./cmd/batch GO_BINARY_NAME=batch make build
GOOS=linux GOARCH=arm64 make build
```

Linux/WSLでは`make build`を実行したユーザーのUID/GID（`id -u`・`id -g`）で本番ビルド用の一時コンテナを実行します。`GOCACHE=/tmp/go-build`、`GOPATH=/tmp/gopath`、`GOMODCACHE=/tmp/gopath/pkg/mod`を指定し、キャッシュは一時コンテナの削除とともに破棄します。ビルドで`go.mod`・`go.sum`を作成・更新する場合も同じUID/GIDで書き込みます。`src/`内の更新対象と`dist/`には実行ユーザーの書き込み権限が必要です。

既存の`dist/app`がroot所有でも、親の`dist/`に書き込み・実行権限があり、sticky bitなどによる削除制限がなければ、ビルド成功後に実行ユーザー所有の新しいバイナリへ置き換えられます。`dist/`自体がroot所有で書き込めない場合は、管理者がそのディレクトリの権限を個別に調整してください。setupやビルドはホストの`src/`・`dist/`を再帰的にchown/chmodしません。開発用Goコンテナ・Airの実行ユーザーと設定は変更していません。

所有者の一致を想定する対応範囲はLinux/WSLのLinuxファイルシステム上です。macOSのDocker DesktopやWindows側のファイルシステムでは、共有ファイルの所有者・権限はマウント方式に依存するためUID/GIDの一致を保証しません。WindowsのPowerShell/cmdでの直接実行は対象外です。WSLのLinux側シェルとファイルシステムを使用してください。

### Goバージョンとcgo

`GOTOOLCHAIN=local`をDockerfileとComposeに設定し、暗黙のツールチェーン切替・取得を禁止します。`go.mod`が新しいGoを要求するとGo標準のエラーになります。アプリの要求を確認して`docker/go/Dockerfile`の公式Goパッチバージョンを更新し、Airの互換性も確認したうえで再ビルドしてください。実装を確認せずgo.modのバージョンだけ引き下げないでください。

cgoが必要なら`.env`の`CGO_ENABLED=1`に変更できます。Debian版Goイメージを使いますが、必要なCライブラリやヘッダーはアプリに応じてDockerfileへ追加します。クロスコンパイル時は対象OS/CPU用のCコンパイラ・ライブラリと`CC`等の設定が別途必要です。単にGOOS/GOARCHを変えるだけでは対応できません。cgo使用時は本番のlibc・動的ライブラリ互換性も確認してください。

## Docker不要の本番デプロイ例

以下はLinux＋systemdを想定した手動手順の例です。専用ユーザー作成、`/opt`・`/etc`への設置、サービス起動は本番サーバの管理権限が必要です。実際のパス・ドメイン・認証・バックアップ方針に合わせて変更してください。このリポジトリのサンプルを配置するだけでは設定は適用されません。

### 1. ビルドと転送（開発ホスト）

本番のCPUに合わせてビルドします。

```bash
GOOS=linux GOARCH=amd64 make build
scp dist/app deploy@example.com:/tmp/app-upload
# または rsync -av dist/app deploy@example.com:/tmp/app-upload
```

転送後はサイズ・チェックサム等で成果物を確認してください。固定名の一時ファイルは同時デプロイを避けます。

### 2. ユーザーとディレクトリ（本番サーバ）

以下は専用ユーザーが未作成の場合です。既存ユーザーがある場合は先に用途を確認します。

```bash
sudo useradd --system --user-group --home-dir /opt/app --shell /usr/sbin/nologin app
sudo install -d -o root -g app -m 0750 /opt/app /etc/app
sudo install -o root -g app -m 0750 /tmp/app-upload /opt/app/app.new
sudo mv /opt/app/app.new /opt/app/app
sudo vi /etc/app/app.env
```

`/etc/app/app.env`の例:

```dotenv
GO_PORT=8080
GO_HOST=127.0.0.1
```

```bash
sudo chown root:app /etc/app/app.env
sudo chmod 0640 /etc/app/app.env
```

systemdのEnvironmentFileはシェルスクリプトではありません。`export`やコマンド置換は記述しません。DB等の本番設定もアプリの仕様に合わせます。本番のDB・Redisは別途準備してください。アプリに書込みが必要な場合は、バイナリ設置場所とは別に専用ユーザーが書けるデータディレクトリを用意します。

### 3. systemdの設置と操作（本番サーバ）

`deploy/systemd/app.service.example`をサーバへ転送してから設置します。

```bash
sudo install -m 0644 app.service.example /etc/systemd/system/app.service
sudo systemctl daemon-reload
sudo systemctl enable app
sudo systemctl start app
sudo systemctl status app
sudo journalctl -u app -f
```

サンプルは非rootの`app`ユーザー、絶対パス`/opt/app/app`、WorkingDirectory、任意のEnvironmentFile、異常終了時の5秒後再起動を指定しています。EnvironmentFileの先頭の`-`はファイル省略を許可します。アプリは標準出力・標準エラーへログを出し、journalで確認します。

```bash
sudo systemctl stop app
sudo systemctl start app
sudo systemctl restart app
sudo systemctl status app
sudo journalctl -u app -n 100 --no-pager
```

### 4. nginxまたはCaddy（本番サーバ）

どちらか一方を選び、Goは`127.0.0.1:8080`で待ち受けます。`ss -ltn`等で実際の待ち受けを確認してください。アプリがGO_HOSTを無視している場合、systemdの設定だけでは外部公開を防げません。

nginxは`deploy/nginx/app.conf.example`を参考に、ドメインを変更してサーバのinclude先へ設置します。例はHTTPのみです。HTTPSの証明書取得・更新、443の設定、HTTPからのリダイレクトは環境に合わせて追加してください。

```bash
sudo nginx -t
sudo systemctl reload nginx
```

Caddyは`deploy/caddy/Caddyfile.example`を参考に`/etc/caddy/Caddyfile`へ設定します。公開ドメインがサーバを指すA/AAAAレコード、外部からの80/443到達性、証明書発行局への通信、証明書を保存できるCaddyのデータ領域を準備します。一般的な公開ドメイン構成では自動HTTPSを利用できます。nginxとCaddyで同じ80/443を取り合わないようにしてください。

```bash
sudo caddy validate --config /etc/caddy/Caddyfile --adapter caddyfile
sudo systemctl reload caddy
```

nginx/Caddyのインストール・ユニット名・設定include先はサーバの配布形態によって異なります。プロキシ経由のHTTPSアクセスを確認します。アプリで転送ヘッダーを信頼する場合は、信頼するプロキシを限定してください。

### 5. 更新とロールバック（本番サーバ）

再ビルド・転送後、実行中の`/opt/app/app`へ直接scpしません。同一ファイルシステム上に別名で設置し、renameで切り替えます。再起動時には短時間の停止が発生します。

```bash
sudo install -o root -g app -m 0750 /tmp/app-upload /opt/app/app.new
sudo cp -p /opt/app/app /opt/app/app.previous
sudo mv -f /opt/app/app.new /opt/app/app
sudo systemctl restart app
sudo systemctl status app
sudo journalctl -u app -n 100 --no-pager
curl --fail http://127.0.0.1:8080/
```

失敗時は旧版のコピーを別名で準備して戻します。

```bash
sudo cp -p /opt/app/app.previous /opt/app/app.rollback
sudo mv -f /opt/app/app.rollback /opt/app/app
sudo systemctl restart app
```

DBスキーマ変更がある場合はバイナリだけのロールバックでは戻らないため、別途互換性・移行・バックアップ計画が必要です。ユニットを変更した場合はdaemon-reloadも実行します。Dockerは本番に不要ですが、テンプレート等の外部ファイルを使うアプリではそれらも転送してください。

## 設計の参照元とGo資料

[PHP版docker-app-skeleton](https://github.com/gallu/docker-app-skeleton/tree/3ed6f9ead5fb3f636c01809f6de873c9df6575a3)のREADME、Compose、Makefile、Dockerfile、設定、初期化SQL・setupを参照しました。DB profiles・認証情報・永続化・コマンド体系を引き継ぎ、PHP-FPMのFastCGIをGo HTTPへのプロキシへ変更しました。PHP固有拡張・Composer・storage権限変更は含めず、Air・本番ビルド・systemd例を追加しています。PHP版リポジトリは変更しません。

- [Go公式: モジュールのレイアウト](https://go.dev/doc/modules/layout)
- [Go公式: How to Write Go Code](https://go.dev/doc/code)
- [Go公式: Modules Reference](https://go.dev/ref/mod)
- [golang-standards/project-layout](https://github.com/golang-standards/project-layout) — **非公式の参考例**です。Go公式標準や必須構成ではありません。
- [Air公式](https://github.com/air-verse/air)
- [Docker公式: Compose変数展開](https://docs.docker.com/compose/how-tos/environment-variables/variable-interpolation/)
- [Caddy公式: Automatic HTTPS](https://caddyserver.com/docs/automatic-https)

## この環境での検証結果

2026-10-23、Linux/WSL2、Docker Engine 29.7.2、Compose 5.5.0で確認しました。検証時は`COMPOSE_PROJECT_NAME=go-skeleton-verify`、`WEB_PORT=18081`、`GO_PORT=18080`を指定し、既存プロジェクトから分離しました。

| 確認内容・コマンド | 結果 |
|---|---|
| `docker compose --profile mysql --profile postgres config --quiet` | 成功 |
| `.env`なし、各変数が空文字、別env-fileでポート・ターゲット変更 | 既定値・変更値の反映を確認 |
| `docker compose -p go-skeleton-verify build go nginx` | 成功 |
| 空srcで`docker compose -p go-skeleton-verify run --rm --no-deps go dev.sh` | 期待どおり終了コード1、初期化案内を表示 |
| `make up`、`make up-mysql`、`make up-pg` | 起動中サービス一覧で両DB・片側DBの切替を確認 |
| `docker compose exec nginx nginx -t` | 成功 |
| `docker compose exec go air -v` | Air起動確認 |
| MySQL `SHOW DATABASES`、PostgreSQL `pg_database`参照 | app・app_testing作成を確認 |
| `docker compose exec redis redis-cli ping` | PONG |
| 一時HTTPサーバの作成・編集 | nginx経由の応答、Airによる変更反映を確認 |
| 意図的なGo構文エラー、その後の修正 | ログ出力・Air監視継続・復旧を確認 |
| `GO_BUILD_TARGET=./cmd/server` | 開発・本番ビルド成功。無効なルートmainに影響されないことも確認 |
| `make down`後の`make build` | 他サービス停止のままdist/appを生成 |
| `file dist/app`、arm64指定のビルド | x86-64・aarch64のLinux ELF形式を確認 |
| コンパイルエラー時の`make build` | 非ゼロ終了、一時成果物削除、既存バイナリのハッシュ保持を確認 |
| go.modにGo 1.99.0を指定 | Go 1.27.3とGOTOOLCHAIN=localを示す標準エラーで失敗 |
| `sh -n scripts/setup.sh docker/go/*.sh`、`git diff --check` | 成功 |

一時Goプログラム・テスト成果物は削除し、`src/`と`dist/`を空に戻しました。検証コンテナ・ネットワークと検証専用DB volumeは削除しました。Dockerイメージ・ビルドキャッシュは残しています。

本番サーバへの配置、systemdの実起動、自動HTTPSの証明書発行、cgoを使うアプリ、arm64バイナリの実行は未検証です。`make clean`・`make all-clean`・`make disintegrate`は実行せずコマンド定義を確認しました。アプリを含まないため、アプリ固有のunit test・静的解析は実行していません。

## ライセンス

本プロジェクトはMIT Licenseで公開しています。
商用・非商用を問わず、利用・改変・再配布が可能です。

利用・再配布に際しては、MIT Licenseに従い、
著作権表示およびライセンス表示を保持してください。

詳細は [LICENSE](LICENSE) を参照してください。
