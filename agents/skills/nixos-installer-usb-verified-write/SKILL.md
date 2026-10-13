---
name: "nixos-installer-usb-verified-write"
description: "NixOS公式インストーラーISOをUSBへ書き込み、全範囲の読み戻し一致を確認する。"
version: 1
created: "2026-10-04"
updated: "2026-10-04"
---
## When to Use
NixOS minimalまたはgraphicalインストーラーのUSB作成・差し替え。データ消去の明示許可が必要。

## Procedure
1. lsblkで現在のUSBの機種・シリアル・容量・接続方式・マウント状態を取得する。過去の/dev/sdXは信用せず/dev/disk/by-idのUSB IDを使う。
2. 対象と全消去を明示し、ユーザーの許可を取得する。公式releases.nixos.orgからISOと.sha256を取得し、sha256sum -cで検証する。
3. 固定USB ID、シリアル、容量、USB接続、removable、書き込み可能、ISOサイズとハッシュを検証して停止できるスクリプトを作る。既定は読み戻し検証のみで、書き込みは明示フラグにする。
4. udisksctl unmountで対象パーティションをアンマウントする。管理者権限はpkexecで取得し、dd bs=4M iflag=fullblock conv=fsyncで書き込む。標準出力と標準エラーをpipefail付きteeでログ保存する。
5. blockdev --flushbufs後、cmp -n ISOのバイト数 ISO USBで全範囲を照合する。blockdev --rereadptとudevadm settleでパーティション情報を更新してラベルを確認する。
6. udisksctl power-offで安全に取り外し、書き込み検証と実機起動検証を区別して報告する。

## Pitfalls
- ddの転送進捗はキャッシュへの書き込みを示す場合がある。conv=fsync完了まで待つ。約3.9GBの古いUSBは同期込みで13分ほどかかる場合がある。
- 過去のUSBが/dev/sdaでも今回/dev/sdbになり得る。内蔵ディスクを対象にしない。
- cmp前にデバイスのキャッシュを破棄し、マウント中のパーティションがあれば停止する。
- power-off後はブロックデバイスが消える。再検証には抜き差しが必要。

## Verification
1. 公式SHA256との一致。
2. USBシリアル・容量が許可対象に一致。
3. USB上の全ISO範囲がcmpで一致し、ラベルが選択したインストーラー種類に一致。
4. 安全なpower-off完了。実機起動を行っていなければ未検証と明記。