---
name: "drive-firefox-via-bidi"
description: "このPCの Firefox を自動操作する (WebDriver BiDi)。「ブラウザ自動化」「画面を操作して」「ログインして退会して」「Cookie を別プロファイルに移す」「Cloudflare のチェックボックスが押せない」がトリガー。NixOS デスクトップに browser MCP が無いときの標準手段。"
version: 1
created: "2026-10-12"
updated: "2026-10-12"
---
## When to Use
Pi のセッションにブラウザ MCP が無いのに、実ブラウザで Web 作業 (ログイン、解約・退会、フォーム入力、スクレイプ) が要るとき。ユーザーが自分の Firefox でログインして Cookie を渡してくれる運用も含む。ヘッドレスではなく、ユーザーの画面に見える Firefox を動かす。

## Procedure
1. `node ~/Projects/account-cancellation/fx.mjs start` で `firefox --new-instance --profile=$HOME/.cache/fxauto/profile --remote-debugging-port=9222` を起動し、12秒ほど待つ。
2. サブコマンドで操作する: status / contexts / newtab / nav / text / eval / jsfile / click / clickreal / clicktext / clickxy / fill / type / press / shot / html / waitfor / closetab / stop / restart。
3. タブは `--url=<部分文字列>` で指定する。`--tab=N` はセッションごとに順番が変わるので使わない。
4. ページ内で動かす JS はファイルに書いて `jsfile <file> [args...]` で渡す。ファイル内では `__ARGS` で引数が読める。長い1行 JS を bash に直接書くと安全網に止められる。
5. ユーザーのログインを使うときは `~/Projects/account-cancellation/sync-cookies.sh` を実行する。メインのプロファイルの cookies.sqlite (+ -wal) を自動化プロファイルへコピーして再起動する。メインのブラウザは止まらない。
6. Cloudflare の Turnstile や「Just a moment...」が出たら自動化では通れないと判断し、ユーザーの Firefox でログインしてもらってから Cookie を同期する。
7. 終わったら `node fx.mjs stop` で自動化 Firefox を閉じる。

## Pitfalls
- Firefox は同時に1セッションしか許さない。ソケットを閉じるだけでは解放されないので、必ず `session.end` を送る。怠ると次回 `session not created: Maximum number of active sessions` になる。
- `send()` のタイムアウト用 setTimeout を clear しないと node が30秒生き残る。応答時に必ず clearTimeout する。
- bash から `pkill -f <自動化プロファイルのパス>` を撃つと、自分のコマンドラインにも一致してシェルごと死ぬ。pidfile を使うか、`fxauto[/]profile` のように括弧を入れた正規表現をスクリプト内から使う。
- `navigator.webdriver` は true のままで、`dom.webdriver.enabled=false` を prefs.js に入れても変わらない。Cloudflare はこれを見ている。
- 座標クリック自体はページに届く (elementFromPoint と入力欄のフォーカスで確認できる) が、Turnstile のチェックボックスは shadow root の中にあり、合成クリックに反応しない。
- `clicktext` は innerText の前方一致。改行を含むラベルは一致しないので clickreal (CSS) か JS クリックを使う。position:fixed の要素は offsetParent が null なので、可視判定に offsetParent を使うとモーダルを取りこぼす。
- モーダルの確認ボタンが背景ボタンと同名のことがある (GeoGuessr の CANCEL SUBSCRIPTION など)。押しても反応しないときは座標の違う同名ボタンを疑う。
- 自動化 Firefox を再起動するとタブは復元されない (新規プロファイル)。必要なタブは開き直す。
- Gmail を読むときは `div[role=main] tr` を拾う。描画が遅いので 6〜8秒待つ。

## Verification
1. 画面は必ず `shot` で撮って画像として確認する (描画されていなければ意味がない)。
2. サイト側の表示が変わったことを読み戻す (例: 会員種別、解約後の文言、ログアウト表示)。
3. 相手が送る確認メールを Gmail で検索する (例: Paddle の解約確認、Bitfan の解約完了)。