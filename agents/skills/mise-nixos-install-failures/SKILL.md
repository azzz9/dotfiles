---
name: "mise-nixos-install-failures"
description: "NixOS で mise のツール導入が失敗するときの切り分け。`mise use -g node@*` の 404、`semver range \"*\" is not supported for node`、`exited with non-zero status: exit code 127` と https://nix.dev/permalink/stub-ld、`ValueError: too many values to unpack (expected 4, got 5)`（node の configure.py）、node が1時間ソースビルドされる、`all_compile` の既定。"
version: 2
created: "2026-10-10"
updated: "2026-10-10"
---
## When to Use
NixOS 上で `mise install` / `mise use` が失敗する、または想定外に遅いときに使う。エラーの型ごとに原因が違うので、まず下の型を見分ける。NixOS 以外や、mise 以外の unpatched バイナリ全般（herdr のプラグイン配布物など）にも同じ nix-ld の判断が効く。nix-ld を入れた直後にこれで詰まる例が多い。

## Procedure
1. エラー本文で型を見分ける。`HTTP status client error (404 Not Found) for url (https://nodejs.org/dist/v*/...)` は版指定の構文ミス。`exited with non-zero status: exit code 127` と stub-ld の URL は nix-ld 不在。`ValueError: too many values to unpack (expected 4, got 5)` はソースビルドに落ちて node の configure.py が C++ コンパイラを見つけられない経路。`we will fetch the source and compile` はソースビルドを選んでいる。
2. 構文ミスなら `*` を捨てて `node@latest`、`node@lts`、`node@24` のいずれかにする。mise は `*` を semver にできず版名の文字列として URL へ埋める。zsh では引用符なしの `node@*` がグロブとして展開され、`zsh: no matches found` で mise が起動する前に落ちる点も伝える。
3. nix-ld 不在なら `programs.nix-ld.enable = true;` を有効化して system を switch する。反映は `readlink -f /lib64/ld-linux-x86-64.so.2` が nix-ld を指すことで確認する。NixOS の既定 `programs.nix-ld.libraries` には glibc に加えて libstdc++（gcc）と zlib が入るので、node や libz.so.1 を必要とする配布バイナリはそのままで足りる。
4. ソースビルドを避けるなら `mise settings set all_compile false` を実行する。NixOS では `all_compile` の既定が無条件に true で、nix-ld の有無では変わらない。nix-ld を入れただけでは precompiled に切り替わらないので、この手順を飛ばすと configure.py の ValueError で落ちる。mise 2027.8.0 でこの自動既定は消える予定。
5. `~/.config/mise/config.toml` は home-manager 管理にしない。管理すると read-only symlink になり `mise use -g` が書けなくなる。設定は `mise settings set` でローカルに置く。
6. 実測は MISE_DATA_DIR・MISE_CONFIG_DIR・MISE_STATE_DIR・XDG_CACHE_HOME を /tmp へ向けて隔離して行う。ユーザーの mise 状態を触らずに、`mise use -n -g` の解決結果と `mise install` の取得 URL を観察できる。

## Pitfalls
- `mise use -g` は install が失敗すると config を書かない。壊れた版指定が config に残る心配は無いが、確認するなら失敗後に `~/.config/mise/` の有無を見る。
- precompiled を選ばせても、nix-ld が無いマシンでは起動時に exit 127 で失敗する。ダウンロード成功はインストール成功ではない。
- nix-ld が無いと `/lib64/ld-linux-x86-64.so.2` が stub-ld を指したままなので、node 以外の配布バイナリも同じ理由で落ちる。個別の patchelf 対応より先にシステム側を直すか判断する。
- nix-ld を入れて system を switch した直後でも、all_compile が true のままだと node はソースビルドに入る。`ValueError: too many values to unpack (expected 4, got 5)` を見たらこの経路を疑う。
- `sudo nixos-rebuild switch` が `experimental Nix feature 'flakes' is disabled` で落ちる場合は別件（リポジトリのマシン設定に `nix.settings.experimental-features` が無い）。`scripts/dotfiles.sh` は NIX_CONFIG を自前で export するので、手打ちのコマンドだけが落ちる。

## Verification
1. `node --version` が解決した版（例 v24.21.0）を出力する。ログイン zsh では `command -v node` が `~/.local/share/mise/shims/node` を返す。
2. インストール時のログが `mise ✓ node@X <秒> node-vX-linux-x64.tar.gz` で、ソースビルドの行が出ていない。
3. `mise current node` が同じ版を指す。
4. `mise settings get all_compile` が false（既定のままでよければ不要）。
5. nix-ld を入れたシステム設定の変更では、他マシンの `nixosConfigurations.<m>.config.system.build.toplevel.drvPath` が変わっていないことを比較して確認する。