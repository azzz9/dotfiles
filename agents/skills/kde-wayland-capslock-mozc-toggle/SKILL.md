---
name: "kde-wayland-capslock-mozc-toggle"
description: "KDE Plasma Wayland で CapsLock を Mozc の Direct とひらがなの切り替えキーにする"
version: 11
created: "2026-10-03"
updated: "2026-10-04"
---
## When to Use
KDE Plasma Wayland と fcitx5-mozc の環境で、CapsLock などのキーを Mozc 内部の Direct とひらがなの切り替えに使いたいとき。fcitx の入力メソッド切替では目的を満たさない場合。

## Procedure
1. `xkbcli dump-keymap-wayland` で実行中のキーマップを確認する。Wayland ではこれが唯一の正となる観測点になる。
2. `~/.config/xkb/symbols/<name>` にレイアウト定義を作る。`include "us(basic)"` と `name[Group1]` に加え、`replace key <CAPS> { type[Group1] = "ONE_LEVEL", symbols[Group1] = [ Zenkaku_Hankaku ], actions[Group1] = [ NoAction() ] }` と `modifier_map None { <CAPS> }` を書く。このキーに Caps_Lock を残さないことが重要。
3. Caps Lock の解除手段を別の空きキーへ置く。JIS キーボードなら `<AE13>`（半角/全角）が空いている。`key <AE13> { type[Group1] = "ONE_LEVEL", symbols[Group1] = [ Caps_Lock ], actions[Group1] = [ LockMods(modifiers = Lock) ] }`。
4. `~/.config/xkb/rules/evdev.xml` に同じ名前の configItem を書く。KDE の設定画面がレイアウトを認識するようになり、`kxkbrc` が `us` へ書き戻されなくなる。載ったかは `xkbcli list` で確認する。
5. ログイン時に `kxkbrc` が `us` へ戻る場合は、`~/.config/kdedefaults/kxkbrc` に `[Layout]` と `LayoutList[$i]=<name>` を書いて実効値を固定する。`kreadconfig6 --file kxkbrc --group Layout --key LayoutList` が `<name>` を返せば効いている。
6. `xkbcli compile-keymap --layout <name> --no-pretty` で symbols と actions を確認してから、`kwriteconfig6 --notify --file kxkbrc --group Layout --key LayoutList <name>` で KWin に適用する。
7. fcitx の TriggerKeys からそのキーを外す。`busctl --user call org.fcitx.Fcitx5 /controller org.fcitx.Fcitx.Controller1 SetConfig sv fcitx://config/global 'a{sv}' 1 Hotkey 'a{sv}' 1 TriggerKeys 'a{sv}' 2 0 s Control+space 1 s Hangul` の形で、Control+space だけ残す。
8. ログイン直後から使えるようにする。`DefaultIM=mozc` を `~/.config/fcitx5/profile` に保ち、`ActiveByDefault` を True にする（`busctl --user call org.fcitx.Fcitx5 /controller org.fcitx.Fcitx.Controller1 SetConfig sv fcitx://config/global 'a{sv}' 1 Behavior 'a{sv}' 1 ActiveByDefault s True`）。Mozc の初期モードはアドオン設定 `InitialMode` で決まり、既定は Hiragana。
9. Direct とひらがなの状態をウィンドウごとではなく全体で共有する。グローバル設定の `ShareInputState` を `All` にする（`busctl --user call org.fcitx.Fcitx5 /controller org.fcitx.Fcitx.Controller1 SetConfig sv fcitx://config/global 'a{sv}' 1 Behavior 'a{sv}' 1 ShareInputState s All`）。mozc アドオンの `InputState` は既定で `Follow Global Configuration` なので、これに従う（DBus からアドオン側の enum を直接 `All` に設定する呼び出しは無視された）。
10. Mozc 側のキーマップは変更しない。`grep -a -F $'DirectInput\tHankaku/Zenkaku\tIMEOn' <mozc_server のパス>` などで、既定キーマップが半角/全角キーを切り替えに使っていることを確認する。
## Pitfalls
- セッションが KDE Plasma 以外だと `kxkbrc` は効かない。`loginctl show-session <id> -p Desktop` で現在のデスクトップを確認する。niri は `~/.config/niri/config.kdl` の `input { keyboard { xkb { layout "<name>" } } }` を読み、そこが空なら systemd-localed の `X11Layout` を使う。config.kdl は保存で即時再読み込みされる。niri は `zwp_input_method_v2` と `zwp_text_input_v3` に対応しているので fcitx5 はそのまま動く。
- `busctl` で構造体の配列（`a(ss)` など）を渡すとき、引数の型を個別トークンで並べると `Too many parameters for signature.` になる。メソッド全体のシグネチャを 1 トークンで渡す（例 `ssa\(ss\)` のあとに `'デフォルト' 'us' 1 'mozc' ''`）。
- Plasma はログイン時に `kxkbrc` の `[Layout]` を systemd-localed の X11* の値で書き戻す。`busctl get-property org.freedesktop.locale1 /org/freedesktop/locale1 org.freedesktop.locale1 X11Layout` の値が書き戻される。対策は `~/.config/kdedefaults/kxkbrc` に `[Layout]` と `LayoutList[$i]=<name>` を書いて実効値を固定すること。副作用として KDE の設定画面でレイアウト一覧が変更できなくなる（戻すにはこのファイルを消す）。代替として NixOS の `services.xserver.xkb.layout` を対象名にし、`services.xserver.xkb.extraLayouts.<name>` でシステム登録する方法がある。
- Caps_Lock を同じキーの 2 段目に置いても安全にはならない。`pc` の `modifier_map Lock { Caps_Lock }` はキーシム単位で効くため、Caps_Lock を持つキーは 1 段目を押しても Lock 修飾として扱われる（X11 側で実測）。解除用の Caps_Lock は別の空きキーに移す。JIS キーボードなら `<AE13>` が空いている。
- KWin は keymap を読み直すとき、直前の Num Lock と Caps Lock のロック状態を復元する（`src/xkb.cpp` の `setLock(m_capsModifier, capsLockIsOn)`）。Caps_Lock を出さないキーへ変えた後は解除手段が無くなるので、別キーに Caps_Lock を用意するか、再ログインで解除する。
- <CAPS> を Hyper に割り当てると、KWin では Super と同じ挙動になった。修飾キーとして使えるキーを選ばない。
- fcitx の TriggerKeys にそのキーが入っていると fcitx が先に消費し、Mozc に届かない。設定ファイルと起動中の設定の両方を確認する。
- `kwriteconfig6 --notify` は値が変わらないと KConfigWatcher を発火させない。同じレイアウト名を再適用したいときは、別の値へ変えてから戻して再読み込みさせる。
- `xkbcli compile-keymap` の成功は実行中の反映を意味しない。必ず `xkbcli dump-keymap-wayland` で確認する。
- `~/.config/fcitx5/profile` を直接編集しても実行中の fcitx には反映されない（`ReloadConfig` でも読まれない）。グループの変更は DBus の `SetInputMethodGroupInfo` を使う。
- fcitx が keyboard-us などのキーボード用入力メソッドの間は、そのキーは何もしない。英字入力は Mozc の Direct に任せ、`keyboard-us` をグループから外すと迷いが減る。
## Verification
1. `xkbcli dump-keymap-wayland` の `key <CAPS>` が Zenkaku_Hankaku で、`modifier_map` に <CAPS> が出ないこと。
2. `verification_steps` 用のスクリプト（例 `~/.local/share/japanese-input/verify-capslock-ime-toggle.sh`）が、実行中キーマップ、fcitx の TriggerKeys、mozc_server バイナリ内の IMEOn/IMEOff の 3 点を検査して PASS すること。
3. テキスト欄で Ctrl+Space のあと CapsLock を押し、Mozc の表示が A と あ で切り替わること。