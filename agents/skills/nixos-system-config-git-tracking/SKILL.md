---
name: "nixos-system-config-git-tracking"
description: "NixOS のシステム設定を git 管理へ移すとき、またはコピーした設定が同じシステムをビルドするか検証するとき。「NixOSの設定もgit化したい」「dotfilesに入れたい」「/etc/nixos をリポジトリ管理にしたい」「drvPath が一致するか確認したい」がトリガー。nixos-rebuild の --file が module を受け付けない点、NIXOS_CONFIG での差し替え、deadnix が未使用 lambda 引数を落とす点、symlink 越しの相対 import 解決を含む。"
version: 1
created: "2026-10-04"
updated: "2026-10-04"
---
## When to Use
/etc/nixos の設定をリポジトリに取り込む作業と、取り込んだ設定が現在のシステムと同じか検証する作業に使う。OS 別ディレクトリへの分離、symlink 配線、drvPath による等価性検証までを扱う。flake の nixosConfigurations への移行は含まない。あれはシステムの nixpkgs pin が変わる別作業になる。

## Procedure
1. 対象を実測する。`du -sh /etc/nixos` と `find /etc/nixos -type f` でファイルを確定し、`configuration.nix.before-*` などのバックアップは取り込まない。
2. リポジトリに OS 別ディレクトリ (例 `nixos/`) を作る。`configuration.nix` は byte-identical でコピーする。`hardware-configuration.nix` は生成器の未使用引数だけ落とす。`{ config, lib, pkgs, modulesPath, ... }` の `pkgs` などが対象。
3. `git add` する。flake は tracked ファイルしか見ないので、未 add のファイルは check の対象外になる。
4. 等価性を drvPath で検証する。`nix-instantiate '<nixpkgs/nixos>' -A system -I nixos-config=<live>` と `<repo copy>` の出力を比較する。
5. `/etc/nixos/configuration.nix` をリポジトリのファイルへの symlink にする。`sudo mv` で旧ファイルを退避してから `sudo ln -s` する。Nix は symlink 越しに `./hardware-configuration.nix` を解決する。
6. symlink 経由の評価を確かめる。`NIXOS_CONFIG=<symlink path> nixos-rebuild dry-build` が exit 0 になることを見る。
7. README に再生成手順を書く。`nixos-generate-config --show-hardware-config` で出力し、未使用引数を落として戻す。

## Pitfalls
- `nixos-rebuild --file <module.nix>` は module ではなく評価済み式を期待する。実行すると `nix-build <file> -A config.system.build.toplevel` になり、`called without required argument 'config'` で落ちる。config を差し替えるときは `NIXOS_CONFIG` を使う。
- 外側の `nixos-rebuild -I nixos-config=<path>` は config 選択に効かない。存在しないパスを渡しても警告だけで exit 0 になり、既定の `/etc/nixos/configuration.nix` にフォールバックする。負の対照実験で確かめる。
- `deadnix --fail` は `...` があっても未使用の lambda 引数を報告する。生成された hardware-configuration.nix はそのままでは check に落ちる。
- byte-identical のコピーは `cmp` だけで検証できる。コメント整理は別コミットに分けると等価性の pin を壊さない。
- wiring には sudo が要る。agent は `/etc/nixos` を触れないので、コマンドを operator に渡す。

## Verification
1. `cmp /etc/nixos/configuration.nix <repo>/nixos/configuration.nix` が無出力で exit 0 になる (byte コピーの場合)。
2. live と repo copy の `nix-instantiate '<nixpkgs/nixos>' -A system -I nixos-config=...` が同一 drvPath を返す。
3. `NIXOS_CONFIG=<symlink path> nixos-rebuild dry-build` が exit 0 になる。
4. `deadnix --fail <repo>/nixos` が無出力で exit 0 になる。
5. 最終確認は operator の `sudo nixos-rebuild switch`。ここが唯一の実機確認になる。