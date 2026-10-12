---
name: "switch-pi-ollama-cloud-to-link"
description: "Pi の Ollama Cloud 導線 (npm:pi-ollama-cloud-link) をマシンで有効にする。1 台目から 2 台目へ同じ設定を広げるときも使う。「/ollama-setup が出ない」「ollama-cloud のモデルが 0 件」「別マシンでも使えるようにして」「ollama-cloud-link の設定をコピーして」がトリガー。"
version: 6
created: "2026-10-03"
updated: "2026-10-06"
---
## When to Use
対象マシンの Pi に ollama-cloud のモデルが出ない、/ollama-setup がコマンド一覧に無い、または既に動いている 1 台目の導線を別マシンへ広げるとき。拡張コードを書く作業ではなく、配布済みパッケージを有効にする作業。

## Procedure
1. このスキルの隣の probe.sh を対象マシンで実行し、変更前の出力を取る。ssh 越しなら ssh <host> 'bash -s' < probe.sh。discovery symlink の有無、ollama-setup の有無、ollama-cloud のモデル数が出る。
2. npm のインストール先にパッケージが無ければ pi install npm:pi-ollama-cloud-link を実行する。
3. ~/.pi/agent/extensions/pi-ollama-cloud-link から npm のインストール先へ symlink を張る。張る前に既存が無いことを確認し、上書きしない。
4. ~/.pi/agent/models.json の手動 ollama-cloud 定義だけを撤去する。他のプロバイダーは残し、全部撤去する場合も {"providers":{}} と書く。
5. probe.sh を再実行し、ollama-setup command: PRESENT と ollama-cloud のモデル数 1 以上を確認する。
6. probe.sh に --call --model <安いモデル> を付けて実推論を通す。
7. 対話中の Pi には /reload を、キー未登録なら /ollama-setup を案内する。

## Pitfalls
- キーはマシンごとに違ってよい。差を見つけたら両機で POST https://ollama.com/api/me を叩き、ID と Email が同じアカウントか確認する。同じなら既に 200 を返すキーを差し替えても機能は変わらないので触らない。
- 同じバージョンの拡張でも docs/ は spec re-sync でファイル単位に食い違う。ツリー全体の差分を拡張の有無と混同せず、判定は probe.sh に任せる。
- 拡張の合否は probe.sh が読む get_commands と get_available_models で判定する。pi list にローカル拡張は載らず、キーが無いと pi --list-models は No models matching になり得る。どちらも未登録の証拠にならない。
- この dotfiles の modules/pi.nix は provider 系パッケージを rows に持たず、activation ごとに settings.json の packages 配列を置換する。pi install の登録は次の apply で消えるので、常設の手段は extensions/ の symlink だけ。
- symlink が壊れるのは pi remove npm:pi-ollama-cloud-link と node_modules の手動削除のときだけ。pi install によるバージョン更新は同じパスに入るので symlink は生き続ける。
- 認証ファイルへの安全機構の拒否を別パスや隔離 HOME で迂回しない。キーをチャットや検証出力に出さない。
- 既存の dotfiles 差分をこの導入の変更として扱わない。既定モデルも依頼がない限り変えない。

## Verification
1. probe.sh が ollama-setup command: PRESENT と ollama-cloud のモデル数 1 以上を返す。
2. probe.sh の --call が実モデルからテキストを返す。
3. models.json のスキーマ警告がなく、手動 ollama-cloud 定義がない。
4. 複数マシンへ広げた場合は、各マシンの probe.sh 出力で symlink の行とモデル数が揃っている。認証付き推論は検証済みと未検証を区別して報告する。