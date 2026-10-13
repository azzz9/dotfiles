---
name: "herdr-nvim-nixos-install"
description: "NixOSでherdr-nvimを導入し、stub-ldとlibz.so.1による配布バイナリの起動失敗を補正する。"
version: 1
created: "2026-10-05"
updated: "2026-10-05"
---
## When to Use
NixOSでChmaraX/herdr-nvimを導入するとき。特にherdr plugin installがgeneric Linuxバイナリを起動できず失敗するとき。

## Procedure
1. Herdrスキルを読み、HERDR_ENV=1、バージョン、既存設定を確認する。
2. タグを固定してLuaプラグインを既存のNeovim管理方式で導入し、setup()を呼ぶ。Herdrのprefix+eとprefix+oをtoggleとpick-fileへ割り当てる。
3. 通常インストールを試す。stub-ldで失敗した場合は配布バイナリを取得しpatchelf --print-neededで全依存を列挙する。
4. 使用中のnixpkgsでglibc、stdenv.cc.cc.lib、zlib、patchelfのstoreパスを評価する。一時BASH_ENVのcurl関数からcommand curlを実行し、成功後bin/herdr-nvim.tmpへpatchelf --set-interpreterと--set-rpathを適用する。そのBASH_ENVをherdr plugin install --ref TAG --yesだけに渡して再試行する。
5. ELFが参照するstoreディレクトリをnix-store --add-root --indirect --realiseで ~/.local/state/herdr-nvim/nix-roots 以下に登録する。
6. 設定を反映してherdr server reload-configを実行し、実際のNeovimとHerdrサイドバーを確認する。

## Pitfalls
- v1.1.0 Linuxバイナリの依存はlibz.so.1、libgcc_s.so.1、libm.so.6、libc.so.6だった。版ごとに確認する。
- ローカルELFのstore参照はGC rootにならない。明示的rootが必要。
- 更新時はバイナリ補正とLua側の版合わせを再確認する。
- sidebar daemonの自動Lua注入は普通のnvimには及ばない。検証で実agentへsubmitしない。

## Verification
1. herdr plugin listとaction listで版とアクションを確認する。
2. 反映済みnvimでexists(':Herdr') == 2と <leader>ac の登録をassertする。
3. Herdrのpane readでsidebar表示を確認し、toggleで元のレイアウトに戻す。