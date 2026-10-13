---
name: "nixos-kde-mime-associations"
description: "NixOS の非 Plasma セッション (niri / Hyprland) で KDE アプリが MIME 関連付けを解決できない症状の診断と修正。「Dolphin が毎回アプリケーションを選択と聞く」「関連付けを保存しても反映されない」「Dolphin のアプリ選択に候補が1つも出ない」「~/.local/share/applications に haruna-N.desktop のようなファイルが増え続ける」「xdg-open では開くのにダブルクリックでは聞かれる」がトリガー。kbuildsycoca6 が applications.menu を見つけられずサービステータベースが空になるのが原因。"
version: 1
created: "2026-10-04"
updated: "2026-10-04"
---
## When to Use
KDE アプリ (Dolphin, Kate, Haruna など) のファイル関連付けが効かない、または保存しても毎回アプリ選択を聞かれるときに使う。プラットフォームは NixOS で、セッションが Plasma 以外 (niri, Hyprland, sway など)。Plasma セッションでは起きない。GNOME/GTK アプリの関連付け問題には使わない (GTK は xdg-open 経由で mimeapps.list を直接読むため)。

## Procedure
1. 症状を確定する。Dolphin の「アプリケーションを選択」ダイアログを開き、候補リストに項目が並ぶか見る。候補が空なら KDE のサービステータベースそのものが空。
2. ksycoca データベースを数える。`C=$(ls ~/.cache/ksycoca6* | head -1); tr -d '\000' < "$C" | tr -c '[:print:]' '\n' | grep -c 'xdgdata-mime|'` と `tr -d '\000' < "$C" | grep -ac haruna` を実行する。MIME 項目が数百件あるのにアプリ名が 0 件ならサービステータベースが空で確定。
3. メニューファイルの有無を確認する。`ls -la /run/current-system/sw/etc/xdg/menus/`。plasma-applications.menu しか無く applications.menu が無ければ原因確定。kbuildsycoca6 は <XDG_MENU_PREFIX>applications.menu を探し、見つからないとサービスファクトリを空のまま書く。
4. 修正を入れる。NixOS で plasma のメニューファイルを既定名でも見せる: environment.etc."xdg/menus/applications.menu".source = "${pkgs.kdePackages.plasma-workspace}/etc/xdg/menus/plasma-applications.menu"; を desktop 向けモジュールに追加し、nixos-rebuild switch。
5. 関連付けを書き直す。Dolphin が自動生成した合成エントリ (~/.local/share/applications/<app>-N.desktop) は解決できないため退避して消し、~/.config/mimeapps.list の [Default Applications] を本来の <app>.desktop ID に向ける。
6. 検証する。rm -f ~/.cache/ksycoca6* の後に kbuildsycoca6 --noincremental を流し、データベースにアプリ名が入ることを確認する。次に kioclient exec <file> を実行し、ダイアログ無しで対象アプリのウィンドウが開くことを実画面で見る。kioclient は Dolphin と同じ KRun / KApplicationTrader 経路を通る。

## Pitfalls
- ksycoca のバイナリを grep で調べるとき、素の grep -a "haruna" では当たらない。文字列は UTF-16BE で格納される。tr -d '\000' で NUL を落としてから grep する。この確認を怠ると「データベースが空」と「観測方法が壊れている」を区別できない。
- 最小環境での再現実験では XDG_CONFIG_DIRS も渡す。渡さないと Qt の既定 (/etc/xdg) しか見ず、XDG_DATA_DIRS を正しく設定してもアプリが入らない。環境のせいだと誤診する。
- update-desktop-database は NixOS の既定に無いことがあり、~/.local/share/applications/mimeinfo.cache が生成されない。これは症状の原因ではない。ここを直しても関連付けは解決しない。
- XDG_MENU_PREFIX=plasma- を一時的に設定すると同じ効果が出るが、恒久化に使わない。セッションごとに環境変数を配る必要があり、メニューファイルを1行置く方が確実。
- 修正前に起動していた KDE アプリは古いアプリ一覧を握っている。Dolphin などを再起動させる。
- kbuildsycoca6 の stderr を tail で切ると applications.menu が見つからないという警告を読み飛ばす。head も含めて確認する。

## Verification
1. ls -l /etc/xdg/menus/applications.menu が存在し、plasma-workspace のメニューを指している。
2. rm -f ~/.cache/ksycoca6* の後に kbuildsycoca6 --noincremental を実行し、生成されたデータベースにアプリ名 (例: haruna, firefox) が入っている。MIME 項目だけではない。
3. kreadconfig6 --file mimeapps.list --group "Default Applications" --key <mime> が対象の desktop ID を返す。KDE 自身のファイルパーサで読めることの確認。
4. kioclient exec <file> がアプリ選択ダイアログを出さずに対象アプリのウィンドウを開く。プロセスの存在だけでなく niri msg windows などでウィンドウのタイトルを確認する。