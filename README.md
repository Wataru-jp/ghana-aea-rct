# Ghana AEA RCT — analysis code and slide deck

農業普及員（AEA）へのフィードバックと研修の効果を測るRCTの、分析コードとスライド一式。

- **T1** = Feedback / **T2** = Feedback + Training / **C** = Control
- 割付は郡（district）単位。**推定サンプルは天水地区のみ**（灌漑2郡 Kpong・Weta は全推定から除外）
- 農家 N=373（主要ANCOVA）、AEA N=41、Bi-weekly 4,120 farmer-rounds、**クラスターは8郡**（C:2 / T1:3 / T2:3）

---

## 1. このリポジトリに入っているもの・入っていないもの

| | 場所 | Git管理 |
|---|---|---|
| Stataコード | `do/` | する |
| スライド原稿 | `JICA-Ghana_full-analysis.tex`（リポジトリ直下） | する |
| 分析結果（表・図） | `tmp/*.tex` `*.pdf` `*.eps` | する |
| 中間データ | `tmp/*.dta` `*.gph` | **しない**（再生成可能） |
| **生データ（個票）** | Dropbox `JICA Ghana/Data/` | **絶対にしない** |

生データは世帯IDとGPS座標を含むため、リポジトリには**シンボリックリンクしか置いていません**。
`.gitignore` は「全部無視 → 必要なものだけ許可」方式なので、`git add -A` しても生データは入りません。
この方針は変えないでください。

## 2. 最初のセットアップ

```bash
git clone <このリポジトリのURL>
cd ghana-aea-rct
```

生データへのリンクを自分の環境に合わせて作ります（Dropboxの共有フォルダが必要）:

```bash
DATA="$HOME/Library/CloudStorage/Dropbox/JICA Ghana/Data"   # ← 自分のパスに直す
ln -sfn "$DATA/Baseline"             Baseline
ln -sfn "$DATA/Endline"              Endline
ln -sfn "$DATA/Biweekly survey data" "Biweekly survey data"
```

各do-fileの冒頭にある `global path` を自分のクローン先に直します（Windowsの方は既存のWindows行を使ってください）。

**必要なソフト**
- Stata 17 以上 + `estout` `balancetable` `randcmd` `boottest` `dummies` `ritest` `grc1leg`（すべて `ssc install`）
- LaTeX（ローカルでデッキを組む場合のみ。Overleafだけ使うなら不要）

## 3. 分析の回し方

```stata
do "do/run_endline_all.do"
```

これ1本で、データ構築 → 全推定 → `tmp/` に表と図を出力 → デッキのコンパイル、まで通ります。所要およそ1時間。
**デッキが表示するものはすべてこのマスターから再生成されます。**手作業で作った表は1つもありません。

## 4. フォルダの役割

```
JICA-Ghana_full-analysis.tex   スライド原稿（メインファイル）
tmp/                           分析の出力先。デッキが \input{tmp/...} で読む
do/                            デッキに載る結果を作るコード。run_endline_all.do が実行順の正本
do/サブ/                       デッキに載らない副次分析（機動的な検証用）
archive_slides/                旧バージョンのスライド。現在は使っていない
```

**メインの `.tex` と `tmp/` を同じ階層に置いているのは意図的です。** Overleafは
シンボリックリンクを辿れず、また相対パスの基準が「プロジェクト最上位」か
「メインファイルの場所」かが環境で変わりうるため、両者を同階層にしておくと
手元でもOverleafでも同じように解決されます。この配置は崩さないでください。

どのファイルが何を作るかは `do/run_endline_all.do` の冒頭コメントに一覧があります。

## 5. 結果を更新して共有する

```bash
./sync.sh "何を変えたかの一言"
```

コミット → GitHub → Overleaf へ、まとめて反映されます。
Overleaf側で誰かが本文を編集した場合は、先に取り込んでから送ります:

```bash
git pull overleaf main
./sync.sh "Overleafの編集を取り込み"
```

## 6. 分析上の約束ごと

これまでの議論で決まった方針です。変更する場合は共著者間で合意してください。

- ANCOVA（エンドライン値 ~ 処置 + Stamp + ベースライン値 + province FE）、SEは郡クラスター
- クラスターが8つしかないため、**wild cluster bootstrap（Webb, 9,999回）と randomization inference（1,000回）を必ず併記**する。対照群は2郡しかないので、クラスターSEは楽観的な下限として読む
- **winsorize は一切しない**
- Revenue = 産出額 / Income = Revenue − 支払費用（土地支払いを含む） / Profit = Income − 家族労働の帰属費用（郡中央値の雇用賃金で評価）
- 灌漑2郡（Kpong, Weta）は全推定から除外
- 農家の知識指標は「4項目すべて正答で1」のall-or-nothing方式

## 7. やってはいけないこと

- 生データをコミットする
- `tmp/` の `.tex` を手で編集する（次回の分析で上書きされます）
- `.gitignore` の許可リストを安易に増やす
