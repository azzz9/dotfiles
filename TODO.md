# herdr-nvim 設定導入

- [x] 1. `how` over the affected subsystem.
  - 親の調査結果を採用。上流 README と setup の実装を再確認。
- [x] 2. `architect` for parallel design exploration. Skipping stays as `architect skipped: <reason>`. Do not fold the design decision silently into implementation.
  - architect skipped: 型や関数の設計は不要。既存のプラグイン一覧とコマンドレジストリへ追加。
- [x] 3. Write the throughput checkpoint as four todo items. A dimension that genuinely does not apply (single file, no fan-out) keeps its item with `n/a: <reason>` rather than being dropped:
  - [x] **Blocking first steps.** Gates run before fan-out.
    - スキル、既存差分、上流アクション、pin と upgrade の慣例を確認してから編集。
  - [x] **Independent workstreams.** Disjoint files, services, or layers parallelize. Shared writes serialize.
    - n/a: 委譲禁止。設定と Nix 検証を一人で担当。
  - [x] **Shared mutable state.** Default to splitting the target (the **separate-before-serializing-shared-state** principle skill). Serialize only for real invariants.
    - n/a: 親は実機操作、子は設定編集。既存差分と他人の未追跡ファイルは保持。
  - [x] **Smallest safe decomposition.** If one worker is best, name why.
    - pin、設定、parse、eval、build、headless nvim の順。小さい宣言変更なので一人で完結。
- [x] 4. Delegate code-writing to a subagent using your configured feature model (default inherit-parent) with a specific scope (file paths, named data shape and its organizing structure per **principle-model-the-domain**, a state machine over scattered booleans, a table/registry over branching, a typed model over repeated shape assumptions, chosen before the delegate writes logic, and success criteria). Review its diff yourself. When the implementation admits multiple valid shapes (error handling, abstraction layer, test structure), delegate via the **arena** skill instead so the runners surface the alternatives and the cross-judge guards the pick. Mandatory: no skip-with-reason escape, and Laziness Protocol does not override it (the gain is review separation, not lines saved). You can spawn a subagent even though you are one. "The app is small" and "a subagent cannot spawn one" are both wrong. A subagent forbidden to spawn satisfies this by owning the diff directly with the same review separation. No "standing by" reply that waits on a nested agent. Comments per **Comments**. Surgical edits, re-ground against the source for upstream-derived files. Port shared-primitive improvements to all consumers and verify each. Commit liberally.
  - 子として直接編集と自己レビューを担当。コミット禁止。
- [x] 5. Verify on the matching surface. "Inconclusive" or wrong-surface is not a pass. Flag it.
- [x] 6. Rebase into small, ordered commits. Stack follow-ups.
  - skip: コミットと PR は依頼範囲外で禁止。
- [x] 7. If the design is contested, `interrogate` before shipping.
  - skip: 設計の争点なし。
- [x] 8. Run **Opening a PR**.
  - skip: PR 禁止。

## データ形

`extraPlugins` のプラグイン一覧、`luaFiles` の順序付きレジストリ、`keys.command` のコマンドレジストリを使う。`herdrNvim` は既存の pinned-packages の derivation 形に従う。

## 作業

- [x] v1.1.0 のソース hash を取得。
- [x] pin、upgrade、Lua setup と Herdr キーを追加。
- [x] parse、eval、dry-run、build、headless 検証。
- [x] 自己レビューと証拠を implementation.md に記録。

## 検証結果

- desktop/mac の activationPackage eval、desktop nixvim と herdr-nvim の build が成功。
- path: フレークの flake check は all checks passed。macOS 実ビルドは未実施。
- headless nvim で :Herdr、7 マップ、既存 <leader>ar、補完、範囲と現在行の annotations と装飾を確認。
- 生成 TOML の 2 アクションと既存 worktree キーを確認。
- 実機適用と Herdr plugin install は親が担当。子は activation を実行していない。
- 自己レビューに blocker なし。新規コードコメントなし。既存コメント変更なし。
