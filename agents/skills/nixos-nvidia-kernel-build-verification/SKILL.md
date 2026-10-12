---
name: "nixos-nvidia-kernel-build-verification"
description: "NixOSでNVIDIAドライバを導入する際、カーネル互換性を実ビルドで確認してから次回起動へ適用する。"
version: 1
created: "2026-10-04"
updated: "2026-10-04"
---
## When to Use
NixOSのnouveauからNVIDIA公式ドライバへ切り替えるとき。特にlinuxPackages_latestを使用する環境。

## Procedure
1. 現在の設定、GPU、ロード済みモジュール、sudo権限を読み取りで確認する。
2. root設定に直接触る前に、元設定と相対importのコピーをユーザーが書ける専用ディレクトリに作る。GPUは既存NixOSオプションで設定する。
3. 候補のassertionsを評価し、候補そのものをnix-build '<nixpkgs/nixos>' -A system -I nixos-config=<候補の絶対パス> --no-out-linkでビルドする。
4. 最新カーネルでモジュールがコンパイル失敗したらログの原因を確認し、独自ソースパッチより標準pkgs.linuxPackagesでのビルドを先に比較する。
5. ビルド成功後に元設定のバックアップを作り候補を適用する。GPU切替ではnixos-rebuild bootを使い、ユーザーが作業を保存した後に再起動する。sudoパスワードをチャットで要求しない。
6. 再起動後にnvidia-smi、lsmod、uname -r、/run/current-systemとsystem profileの一致、実際のcompositorのGPU使用を確認する。音声機器もwpctl statusで再確認する。

## Pitfalls
- 設定評価成功はカーネルモジュールのビルド成功ではない。
- kernel7.2.8とNVIDIA open595.71.05の組み合わせではos-interface.cのstrncpy implicit declarationで失敗した観測例がある。kernel6.18.54では同ドライバのシステムビルドと実機起動に成功した。バージョン固定の普遍則にはしない。
- boot適用は実行中システムの切替ではない。再起動前に導入完了と断言しない。
- 音声出力の認識と実際に音が聞こえることは別の検証。

## Verification
1. 候補そのもののシステムビルドが成功する。
2. 再起動後nvidia-smiで目的GPUとドライバを確認でき、nouveauは未ロード。
3. 実際のデスクトップcompositorがNVIDIA GPUを使用している。