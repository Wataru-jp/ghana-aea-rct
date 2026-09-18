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

## 6. Git 早見表（覚えなくてよい。困ったらここを見る）

### 毎日使うのはこれだけ

```bash
cd ~/research/ghana-aea-rct
./sync.sh "Add labour table by operation"
```

記録 → 共著者の変更を取り込む → GitHub と Overleaf へ送信、まで自動。

### 見るだけのコマンド（何も壊さない）

| したいこと | コマンド |
|---|---|
| 今なにが変わっている？ | `git status` |
| これまで何をしてきた？ | `git log --oneline` |
| 記録前に差分を確認 | `git diff` |
| 昔のファイルを取り出す | `git show <コミットID>:<パス>` |

**履歴や差分を「読む」だけなら、GitHubのウェブ画面の方が見やすい。**
コミット一覧・行ごとの差分・誰がいつ変えたか（Blame）・行へのコメントが
コマンドなしで使える。

### 困ったとき

| 状況 | コマンド |
|---|---|
| 編集を捨てて元に戻したい | `git restore <ファイル>` |
| 共著者の変更を今すぐ取り込みたい | `git pull origin main` |
| 消したファイルを復活させたい | `git show <コミットID>:<パス> > <ファイル>` |

衝突（同じ箇所を2人が別々に直した）が起きたら `sync.sh` が止まって手順を表示する。
慌てて元に戻そうとせず、表示された手順どおりに進めること。

### 覚えておくべき考え方

- **Gitは自動同期しない。** 共著者の変更は `pull` した瞬間に初めて手元へ来る。
  自分の変更も `push` するまで誰にも見えない。Dropboxとはここが決定的に違う。
- **古いファイルを取っておく必要はない。** `slide2_old.tex` のような退避コピーは不要。
  消しても歴史に残っており、いつでも取り出せる。
- **記録していない変更は守られない。** 分析を流したら `./sync.sh` する習慣をつける。

## 7. 分析上の約束ごと

これまでの議論で決まった方針です。変更する場合は共著者間で合意してください。

- ANCOVA（エンドライン値 ~ 処置 + Stamp + ベースライン値 + province FE）、SEは郡クラスター
- クラスターが8つしかないため、**wild cluster bootstrap（Webb, 9,999回）と randomization inference（1,000回）を必ず併記**する。対照群は2郡しかないので、クラスターSEは楽観的な下限として読む
- **winsorize は一切しない**
- Revenue = 産出額 / Income = Revenue − 支払費用（土地支払いを含む） / Profit = Income − 家族労働の帰属費用（郡中央値の雇用賃金で評価）
- 灌漑2郡（Kpong, Weta）は全推定から除外
- 農家の知識指標は「4項目すべて正答で1」のall-or-nothing方式

## 8. コミットメッセージの書き方

1行目は**英語で簡潔に**（50字程度、何をしたか）。本文が要るときだけ、1行空けて
「なぜそうしたか」を数行。何をしたかは差分を見れば分かるので、書くべきは理由です。

```
Drop irrigation districts from all estimations

They are 12 farmers and 2 AEAs, all in the control arm, and yields and
labour there are on a different scale. Leaves 8 district clusters.
```

箇条書きの作業ログや、差分を読めば分かる内容の列挙は書かないでください。

## 9. やってはいけないこと

- 生データをコミットする
- `tmp/` の `.tex` を手で編集する（次回の分析で上書きされます）
- `.gitignore` の許可リストを安易に増やす
