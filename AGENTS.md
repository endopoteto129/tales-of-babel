# AGENTS.md — テイルズオブバベル 開発ガイド（AIエージェント向け）

このファイルは、このプロジェクトを触るAI（Codexなど）と人間向けの「仕組みの説明書」です。作業の前に全部読んでください。

## 0. まず守ること

- エンジンは **Godot 4.5.1（標準版、GDScript）** です。レンダラーは GL Compatibility（ブラウザ版も同じ）。C# やアドオンは使いません。
- **画像・音のファイルを使わずに動くこと**が前提です。キャラ、背景、エフェクトはコードで描き、効果音は実行時に合成しています（`scripts/autoload/sfx.gd`）。立ち絵・スチル・ドット絵は「置けば差し替わる、なければ図形のまま」の任意ファイルです。この作りを壊さないでください。
- 文章（台詞、説明、コメント）は日本語です。コードのコメントも日本語で書きます。
- 変更したら、必ず **6章のテスト** を通してから終えてください。
- このPCのフォルダは、Claude（別のAI）も直接ファイルを書き込んで更新しています。上書き事故を防ぐため、**変更したファイルは必ず `CHANGES_CODEX.md` に記録**してください（7章）。

## 1. 全体の流れ

```
タイトル → 序章 → [層の探索マップ ⇄ 戦闘 / 焚火 / ショップ / イベント / メニュー] × 7層 → エンディング
```

- 主人公たちがバベルの塔を一層ずつ登るJRPGです。各層は見下ろし型の探索マップ（テイルズ オブ エターニア風）で、敵のシンボルに触れるとリアルタイム戦闘（LMBS風）に入ります。戦闘は奥行きのある **2.5D が正式仕様**です（`Game.battle_25d`。比較用に `--2d` で従来の2Dにできます）。
- 共鳴秘技（絆ゲージ）は第三層ボス後の物語（フラグ `link_unlocked`）、オーバーリミッツと秘奥義は第五層ボス戦の途中の強制イベント（`f5_ovl`、フラグ `ovl_unlocked`）で解放されます。解放前はゲージ、ボタン、操作表示を出しません。
- 層の途中で中盤ストーリーが流れて門が開き、最後にボス戦があります。層に入るたびに、その層の間だけ効く「加護」（ローグライク強化）を選びます。
- 売りは仲間との掛け合いです。本編ストーリー、マップで見るスキット、焚火の会話、戦闘中のショートチャット、ボス大技の予告ボイス（callouts）があります。

## 2. フォルダ構成

| 場所 | 中身 |
|---|---|
| `project.godot` | 設定。オートロード `DB` `Game` `Sfx`、画面 1280×720 |
| `scenes/main.tscn` | 唯一のシーン。`scripts/main.gd` をつけたルートノードだけ |
| `scripts/main.gd` | 画面遷移、フェード、通知、会話の重ね表示、テスト用の起動引数 |
| `scripts/autoload/game.gd` | **ゲームの状態すべて**（パーティ、所持品、フラグ、マップ状態、セーブとロード、成長計算） |
| `scripts/autoload/db.gd` | `data/*.gd` への窓口（`DB.enemy(id)` `DB.arte(id)` `DB.floor_data(n)` など） |
| `scripts/autoload/sfx.gd` | 効果音の合成 |
| `scripts/screens/` | 各画面（title / map / camp / shop / event / menu / gameover / ending） |
| `scripts/battle/` | 戦闘（battle 本体、fighter、描画、HUD、背景、飛び道具、範囲攻撃、エフェクト、応援役） |
| `scripts/field/field_art.gd` | 探索マップのタイルとキャラの描画 |
| `scripts/ui/` | 会話ウィンドウ（dialogue）、立ち絵（portrait）、共通UI部品（ui）、ドット絵の読み込み（pixel_art） |
| `data/` | **ゲームの中身のデータ**（キャラ、術技、敵、層、ストーリー、スキット、マップ…）。ほとんどの調整はここだけで済みます |
| `art_src/maps/` | 探索マップの設計スクリプト（Python）。`data/fieldmaps.gd` を生成します |
| `art_src/pixel/` | ドット絵の仕様に関する道具（検査スクリプト、依頼文） |
| `assets/` | フォント、任意の立ち絵（portraits）、スチル（stills）、ドット絵（pixel） |
| `shaders/outline.gdshader` | 戦闘キャラの輪郭線 |
| `scripts/autotest.gd` `validate.gd` `balance.gd` `fieldtest.gd` `fieldbot.gd` `shots.gd` `gallery.gd` `repro.gd` | テストと検証の道具（6章） |

シーンファイル（.tscn）はほぼ使っていません。画面はすべてスクリプトの中でノードを組み立てています。UIを足すときも、エディタで .tscn を作るのではなく、コードで組み立ててください。

## 3. 画面遷移と状態

- 画面の切り替えは `Main.inst.goto("画面名", {パラメータ})` で行います。画面名は `main.gd` の `SCREENS` にあります。新しい画面はスクリプトを作り、`SCREENS` に登録します。各画面は `setup(params)` を持てます。
- 戦闘の開始：`Main.inst.goto("battle", {"enemies": ["slime","wolf"], "kind": "battle"})`。`kind` は `battle` / `elite` / `boss`。
- 戦闘からの戻り：battle.gd が `goto("map", {"after_battle": kind, "won": true})`、逃げたときは `{"won": false, "escaped": true}` を渡します。map.gd の `_arrive()` がこれを受けて、倒した敵を消す、ボス後の処理をする、などを行います。
- 会話の再生：`Main.inst.play_story("f1_mid", 終わったら呼ぶCallable)`。任意の会話は `Main.inst.play_dialogue({"lines": [...]}, ...)`。
- 通知：`Main.inst.toast("文字")`。チュートリアル：`Game.should_tutorial(id)` → `Main.inst.show_tutorial(id)`。
- 状態はすべて `Game`（game.gd）が持ちます。主なもの：`party`（各メンバーの Dictionary）、`gald`、`items`、`floor_num`、`map`、`floor_buffs`、`flags`、`counters`、`bond`、`seen_skits`。
- セーブは `user://save.json`（`Game.to_dict()` / `from_dict()`）。**セーブに残す値を足したら、両方に追加し、古いセーブに値がないときの初期値も入れてください。**

## 4. データファイルの書き方（`data/`）

ほとんどのファイルの先頭に、書式の説明コメントがあります。書き足すときは同じ書式に合わせてください。どのファイルも `extends RefCounted` で、`const DATA := {...}` を持ちます。

| ファイル | 中身 | メモ |
|---|---|---|
| `characters.gd` | 仲間とNPCの名前、色、ステータス、成長、通常攻撃のコンボ、初期術技 | `LIST` が戦闘に出る5人 |
| `artes.gd` | 術技（特技 tech / 奥義 arcane / 術 spell・heal・support） | 発生、持続、硬直（秒）、威力、飛び道具 `projectile`、範囲 `aoe` |
| `enemies.gd` | 敵とボスのステータス、AI、技 | 数値は第一層の基準。層ごとの倍率は floors.gd |
| `floors.gd` | 7層の設定（名前、背景の種類 deco、敵の倍率、敵の組み合わせ、ボス） | 全体の難易度倍率 `ENEMY_HP_MULT` などと経験値倍率 `EXP_MULT` も |
| `fieldmaps.gd` | 探索マップ（**生成ファイル**。5章） | |
| `story.gd` | 本編の会話。`FLOORS` で層ごとに intro / mid / camp / boss_pre / boss_post を割り当て | 行は `[話者id, 本文, 表情]`。演出は `["@bg", ...]` などの命令行 |
| `skits.gd` | スキットと焚火の会話。`trigger` と条件で発生 | `award` で称号をもらえる |
| `chats.gd` | 戦闘中のショートチャット | イベント名ごとの候補から条件に合うものを選ぶ |
| `callouts.gd` | ボス大技の前に仲間がかける声 | |
| `events.gd` | イベントの場所で起きる出来事と選択肢 | result のキーは先頭コメントを参照 |
| `buffs.gd` | 加護 | `effects` の `*_mult` は掛け算、それ以外は足し算 |
| `items.gd` | アイテムと焚火の料理 | |
| `titles.gd` | 称号 | |
| `skilltree.gd` | スキルツリー | effect は stat / arte / skill |
| `links.gd` `mystics.gd` `finishers.gd` | 共鳴秘技、秘奥義、ボスのとどめ演出 | |
| `tutorials.gd` | チュートリアルの本文 | `{attack}` などはボタン名に置き換わる |
| `depth_attacks.gd` | 2.5D戦闘用の敵の技（床に予告が出る横一列・縦一列・円） | |

- 話者idは `characters.gd` のキー、表情は `validate.gd` の `EXPRS` にあるもの（`""` `smile` `laugh` `angry` `sad` `cry` `surprise` `serious` `cold` `think` `sweat` `blush` `blank`）だけが使えます。
- 会話の演出命令は `scripts/ui/dialogue.gd` が処理します：`@title_card` `@bg` `@cg`（スチル）`@join` `@leave` `@title` `@flag` `@unflag` `@buff` `@item` `@recipe` `@shake` `@flash` `@sfx` `@clear` `@caption`。
- データを足したら `--validate-only`（6章）で、話者や参照先の間違いがないか確かめてください。
- **シナリオ台本（Excel）**：プロジェクト直下の `シナリオ台本.xlsx` は、本編・スキット・焚火・戦闘チャット・イベントの台詞を1行ずつ並べた表で、ユキさんが直接書き換えます。
  - 台本 → ゲーム：`python art_src/scenario/import_scenario.py`（または `シナリオを反映.bat`）。`data/story.gd` などの `"lines"` の中身だけを書き換えます。`--check` を付けると確認だけします。
  - ゲーム → 台本：`python art_src/scenario/export_scenario.py`。**台本の未反映の書き換えは消えるので、必ず先に import してから** export してください。
  - 台詞をコードで足したり直したりしたときは、import → コードを編集 → export の順にして、台本とゲームをそろえてください。

## 5. 探索マップ（`scripts/screens/map.gd`）

- 1マスは64ピクセル。文字でマップを書きます。
  - 地形：`#` 壁、`T` 背の高い飾り（木・柱）、`o` 小さな障害物、`. , : "` 床、`~` 水、`=` 橋、`+` 門（中盤ストーリーの後に開く）、`^` 階段、空白はマップの外
  - 物：`P` 開始位置、`E` 敵、`L` 強敵、`C` 宝箱、`M` 行商人、`N` 住人、`F` 焚火（1層1回）、`?` イベント、`B` ボス、`G` 中盤ストーリーが始まる場所
  - 物の中身は `objects` の `"x,y": {...}` で決めます（敵の群れ `g`、動き方 `move`: wander / guard、宝箱の中身、住人の台詞など）。
- **`data/fieldmaps.gd` は生成ファイルです。** マップを直すときは `art_src/maps/f1.py`〜`f7.py` を書き換え、`art_src/maps` の中で `python build_fieldmaps.py` を実行してください。このスクリプトは、全体の地図、たどり着けない場所、必ず戦う敵の一覧を表示します。`gen.py` が書き方の道具（rect / blob / hline / vline / maze / put / scatter）です。`exp_proj.py` は、戦う数ごとにボス戦の時点のレベルを見積もります。
- 敵シンボルは「うろつく → 見つけると追う → 離れると戻る」の4つの状態で動きます。見張り型（guard）は通路をふさぎ、近づくと飛びかかります。数値は map.gd の先頭の定数です。
- マップの状態は `Game.map`（`floor`, `pos`, `dir`, `done`（倒した敵・開けた宝箱）, `fog`（ミニマップの霧）, `shop_stock`）に入ります。

## 6. テストの方法（変更後は必ず実行）

Windows では、このフォルダの1つ上にあるコンソール版を使います（結果がターミナルに出ます）。

```
cd C:\Users\endop\Documents\Godot\tales_of_babel
..\Godot_v4.5.1-stable_win64_console.exe --headless --path . -- --autotest --validate-only
```

| 引数（`--` の後ろ） | 内容 | 合格の条件 |
|---|---|---|
| `--autotest --validate-only` | データの整合性チェックだけ（数秒） | `[validate] errors=0` |
| `--autotest` | 全画面を開き、各層の戦闘をAI同士で回す（数分） | 最後に `[autotest] done`、出力に `SCRIPT ERROR` が0件 |
| `--fieldtest --play` | ボットが全層のマップを歩き、ボスまで行けるか確かめる | 各層 `boss=OK stuck=0 unreachable=[]` |
| `--fieldtest --flow` | 戦闘に入る、逃げる、宝箱、焚火、セーブとロードの流れ | エラーなし |
| `--balance [--floors=1,2] [--boss-only]` | 各層を想定レベルにしてAI同士で戦わせる | 雑魚と強敵には勝つ。ボスもおおむね勝つ |
| `--shots` `--fieldtest` | スクリーンショットを撮る（ヘッドレスではなく画面ありで実行） | 目で確認 |
| `--uitest` | ゲームパッドだけで店を開き、カーソル移動・購入・Bで退店できるか（画面ありで実行） | 購入後もカーソルが残り、Bで map に戻る |
| `--touchtest` | タッチだけでマップ移動、調べる、戦闘の攻撃、ポーズができるか（画面ありで実行） | 各行が true / shop |
| `--ovltest` | 絆・OVLの解放前は出ないこと、第五層ボス戦の途中でOVL解放イベントが流れること（画面ありで実行） | 最後に `ovl_unlocked=true` |

- `--headless` で起動したときの終了時の `ObjectDB instances leaked` / `resources still in use` の警告は、以前から出ているもので問題ありません。
- GDScript の型推論には注意してください。`var x := 辞書["key"]` のように型が決まらない書き方はエラーになります。`var x: float = 辞書["key"]` のように型を書いてください。
- Control を継承したスクリプトで `theme` という名前の変数を作ると、組み込みのプロパティとぶつかります（マップでは `ftheme` にしています）。

- **スマホ対応**：`scripts/ui/touch_controls.gd` が、画面に触れたときだけタッチ用のスティックとボタンを出します（`Game.touch_mode`）。ボタンは `attack` や `ui_accept` などの入力アクションを送るだけなので、新しい操作を足したら、ここにボタンを足してください。右下にはボタンが並ぶので、タッチ時は絆・OVLゲージとスキットボタンを上へ動かしています。新しく右下に何か置くときは重ならないよう注意してください。
- **カーソル（フォーカス）**：コントローラーでは、ボタンにカーソルがないと何も操作できません。画面を作り直したら `UI.focus_first()` でカーソルを置き、キャンセル（`ui_cancel`）で戻れるようにしてください。

## 7. 変更の記録と共同作業のルール

- このフォルダは Claude も更新しています。Codex が変更したファイルは、プロジェクト直下の `CHANGES_CODEX.md` に、日付、ファイル名、何をしたかを1行ずつ追記してください。Claude は次に更新する前にこれを読んで、変更を取り込みます。
- ブラウザ版（GitHub Pages）への反映は Claude が行います。Codex は書き出し（Web export）や git への push をしないでください。
- `.godot/` フォルダ、`*.import`、`*.uid` は Godot が自動で作るファイルです。手で編集しないでください。
- 大きな仕組みの変更（戦闘の方式、セーブの形式、画面構成）は、始める前にユキさんに確認してください。

## 8. ドット絵と立ち絵の差し替え

- ドット絵：`assets/pixel/` にPNGを置くと、マップと戦闘の絵が自動で差し替わります。仕様は `assets/pixel/SPEC.md`、検査は `python art_src/pixel/check_pixel.py`。読み込みは `scripts/ui/pixel_art.gd`（`PixelArt.tex("field/chara_ren.png")` のように使い、ファイルがなければ `null` を返すので、そのときは図形で描きます）。
- 立ち絵：`assets/portraits/<キャラid>/<表情>.png`（`portrait.<id>.<表情>.png` でも可）。表情の画像がなければ `normal.png` を使います。
  - 立ち絵は **幅600ピクセル** に縮めて置いてください（ブラウザ版が重くならないように）。大きい元画像は `art_src/portraits/<キャラid>/` に保管します（`art_src/` はゲームに読み込まれません）。
- スチル：`assets/stills/<名前>.png`。ストーリーの `["@cg", "名前"]` で表示されます。
- 新しく絵を差し替えられる場所を作るときも、「ファイルがなければ今までどおり図形で描く」形にしてください。
