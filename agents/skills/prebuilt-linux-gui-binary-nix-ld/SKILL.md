---
name: "prebuilt-linux-gui-binary-nix-ld"
description: "NixOSで配布Linux GUIバイナリを管理者権限なしで動かす。nix-ldのライブラリ一覧に無いGUIライブラリのdlopen失敗を、storeライブラリを指すLD_LIBRARY_PATHラッパーで解消する。「failed to load libxcb」「libvulkan.so.1: cannot open shared object file」「libxkbcommon.so.0 が見つからない」「--helpは通るのにGUIが起動直後に落ちる」「Ternのような配布物のtar.gzを試したい」がトリガー。"
version: 1
created: "2026-10-12"
updated: "2026-10-12"
---
## When to Use
NixOSで配布物のLinuxバイナリ (tar.gz、AppImage、単体実行ファイル) を導入して試すとき。管理者権限を使わず、Home Managerのflakeにも入れずに済ませたい場合に使う。症状はGUIアプリが起動直後にpanicし、ログに `failed to load LIB: cannot open shared object file` が出る。恒久的にsystem側へ入れる場合は ../nixos-system-desktop-apps/SKILL.md、stub-ldとpatchelfで直す配布バイナリは ../herdr-nvim-nixos-install/SKILL.md を使う。

## Procedure
1. `--help` と `--version` を実行し、次に起動ログを取って実際に起動させる (`setsid nohup env -u LD_LIBRARY_PATH ./APP > /tmp/app.log 2>&1 &`)。CLIが通ることは起動の証拠にならない。
2. ログの `failed to load LIB` を読む。dlopenの依存はDT_NEEDEDに現れないので `readelf -d` では出ない。1つ直すと次のライブラリで落ちるので、`strings BINARY | grep -o -E 'lib[a-zA-Z0-9_+-]*\.so(\.[0-9]+)*' | sort -u` で候補を先に列挙する。
3. `ls $NIX_LD_LIBRARY_PATH/LIB` でnix-ldが持っているか確認する。無ければnix-ld既定一覧の穴。
4. `nix build --no-link --print-out-paths nixpkgs#libxcb nixpkgs#libxkbcommon nixpkgs#wayland nixpkgs#vulkan-loader nixpkgs#libGL nixpkgs#linux-pam nixpkgs#libpulseaudio` で揃える。libGLはlibglvndでlibEGL.so.1とlibGLESv2.so.2を含む。ドライバ用に `/run/opengl-driver/lib` を先頭に置く。
5. `writeShellScriptBin` でラッパーを作る。`pkgs.lib.makeLibraryPath` を列挙したライブラリに適用して `LD_LIBRARY_PATH` へ前置し、`exec バイナリ "$@"` する。バイナリの隣に `default.nix` を置き `nix-build --impure` する。cwdの `result` symlinkがGC rootになり、ラッパー本文がstoreパス名を持つのでライブラリもGCから守られる。
6. exec先はstoreコピーではなく手元の絶対パスにする。アプリが `current_exe()` で自分を再登録する場合 (デスクトップエントリ、URLハンドラ、MIME関連付け)、storeパスだと再ビルドのたびに壊れる。
7. ラッパーをPATHの通った場所へsymlinkする (`ln -sfn ~/.local/opt/APP/result/bin/APP ~/.local/bin/APP`)。検証は `env -u LD_LIBRARY_PATH ~/.local/bin/APP` で行い、プロセスと実ウィンドウの両方を見る。

## Pitfalls
- nix-ldの既定 `libraries` はGUIスタック (xcb、wayland、vulkan、EGL/GLES、xkbcommon、pam、pulse) を含まない。glibcとlibstdc++だけ解決するので `--help` は成功し、GUIスレッドで初めて落ちる。「動いた」と早合点しない。
- `pkill -f 'tern daemon'` のようなパターンは実行中の自分のシェルのコマンドラインにも一致し、自分を殺す。`[t]ern daemon` のように書く。
- `nix build --no-link` の結果はstoreにあるだけでGC rootではない。ラッパーの出力からstoreパス名として参照させて初めて守られる。手元の実行ファイルへの参照はrootにならない。
- アプリが自分で書くデスクトップエントリには起動時のexecパスがそのまま入る。バイナリを移動したら `Exec=` を直す。ラッパーを指しておけば、そのパスは再ビルドで変わっても安定する。
- 管理者権限は要らない。恒久策はsystem側の `programs.nix-ld.libraries` にライブラリを足すことだが、sudoとnixos-rebuildが要るので利用者の判断を仰ぐ。

## Verification
1. `env -u LD_LIBRARY_PATH ~/.local/bin/APP --version` が版を出力する。
2. `niri msg windows` にアプリのApp IDが出て、起動ログにpanicが無い。プロセスの存在だけで判断しない。
3. アプリのCLI経由の操作 (`APP ls` など) がラッパーから応答する。daemon型アプリではこれが接続確認になる。
4. `nix-store -q --references ~/.local/opt/APP/result` にライブラリのstoreパスが並ぶ。GC対策が効いていることの確認。