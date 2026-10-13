---
name: "apply-one-home-manager-file"
description: "Home Manager の一つの管理ファイルだけを反映する。別作業の変更を反映せず .zshenv などを更新したい場合に使う。"
version: 1
created: "2026-10-05"
updated: "2026-10-05"
---
## When to Use
作業ツリーに別作業の変更があり、Home Manager 全体の activation を避けたい場合。

## Procedure
1. 既存のファイルと元の Nix 設定を読み、最小変更を加える。
2. 未追跡ファイルを含める必要がある場合は path:/absolute/repo で評価する。config.home.file のキーを --apply builtins.attrNames で確認する。.zshenv のキーは ./.zshenv の場合がある。
3. 対象の homeConfigurations.<machine>.config.home.file."<key>".source のみを nix build --impure --no-link --print-out-paths でビルドする。
4. 現在のファイルとの差分と構文を検査し、意図した変更だけの場合に限り管理 symlink を新しい store ファイルへ付け替える。
5. nix-store --add-root <persistent-state-path> --indirect --realise <store-file> で GC root を登録する。実際の利用経路で確認する。シェルは script -q -e -c で PTY 上の対話シェルを検証する。

## Pitfalls
- 全体の activation は別作業の変更まで反映する。
- 通常のユーザー symlink は Nix GC root ではない。
- 次回の Home Manager activation でも維持できるよう元の Nix 設定を変更しておく。

## Verification
1. 生成ファイルの差分が要求された変更だけである。
2. 実際の利用経路で新しい挙動を観測する。
3. 生成した store ファイルに GC root がある。