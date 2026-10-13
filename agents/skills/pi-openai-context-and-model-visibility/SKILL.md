---
name: "pi-openai-context-and-model-visibility"
description: "Pi の OpenAI コンテキスト上限を変更し、/model の古いモデルを非表示にする。modelOverrides、enabledModels、filterModels、filterAllModels、openai と openai-codex の認証経路の違いを検証する。"
version: 1
created: "2026-10-05"
updated: "2026-10-05"
---
## When to Use
Pi の登録コンテキストが実際の上限より小さいとき、または特定の OpenAI モデルだけをモデル選択画面に残したいとき。対象機の Pi バージョンと公開 API を確認して適用する。

## Procedure
1. 対象機で Pi の models.md と settings.md を読む。認証済みプロバイダー、対象モデルの API と接続先を確認する。openai と openai-codex を機械間で同一と仮定しない。
2. models.json、既定モデル、他プロバイダーのモデル集合を保存して差分比較に使う。秘密を出力しない。期限切れ OAuth は Pi の正規更新を使い、invalid_grant なら再ログインを依頼する。
3. 拡張予定の入力を実際の認証経路で一度検証する。response usage、HTTP 結果、正常完了を記録する。既存の有効な成功証跡は再利用し、大容量入力を反復しない。
4. 成功した対象だけ models.json の providers 内に modelOverrides を追加する。表示制限は正式な設定を優先する。enabledModels が選択画面の全モデル表示を制限しない場合、公開 Provider の filterModels と filterAllModels をラップする最小ローカル拡張を使う。
5. 新規 Pi を PTY で起動する。/reload 後に /model を開き、OpenAI の検索結果、選択後の上限表示、他プロバイダーと既定モデルの維持を確認する。

## Pitfalls
- カタログの上限値を書き換えてもサーバー側の上限は増えない。検証した入力サイズと未検証の境界を区別する。
- Provider ラップでは元の認証、stream、カタログ更新、既存フィルタを維持する。非公開 API、monkeypatch、カタログやキャッシュの削除を使わない。
- pi --list-models は session_start より前に動くため、セッション開始時のフィルタを反映しない場合がある。成功判定は /model の実画面で行う。
- 機械ごとの認証や既存設定を維持する。資格情報をコピーせず、OAuth refresh token を手動 HTTP で更新しない。
- 検証用の大容量入力も利用枠を消費する。担当エージェントの利用上限と検証対象の認証エラーを別々に扱う。

## Verification
1. 保存した実 usage が以前の登録上限を超え、正常完了している。
2. 新規 PTY の /reload 後の /model に許可した OpenAI モデルだけが表示される。
3. 選択後のコンテキスト表示が設定値と一致する。
4. 他プロバイダーの利用可能モデル集合、既定モデル、既存設定が変更されていない。外部変更は担当の差分と分けて報告する。