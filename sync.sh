#!/usr/bin/env bash
# -----------------------------------------------------------------------------
# sync.sh -- 分析結果を共著者と同期する。
#
#   ./sync.sh "何を変えたかの一言（英語）"
#
# 動作: 自分の変更を記録 → 他の人の変更を取り込む → 両方へ送る
#
#   GitHub   = コードと履歴の正本
#   Overleaf = スライドの表示・本文編集（LaTeXだけ触る共著者の入口）
#
# Gitは自動同期しない。他の人の変更は、このスクリプトが pull した瞬間に
# 初めて手元へ入る。逆に、自分の変更も push するまで誰にも見えない。
# -----------------------------------------------------------------------------
set -uo pipefail
cd "$(dirname "$0")"

MSG="${1:-}"
if [ -z "$MSG" ]; then
    echo "使い方: ./sync.sh \"何を変えたかの一言（英語）\""
    echo "  例:   ./sync.sh \"Drop irrigation districts from all estimations\""
    exit 1
fi

fail_on_conflict () {
    echo
    echo "  取り込みで衝突が起きました。同じ箇所を2人が別々に直した状態です。"
    echo "  1) git status で衝突しているファイルを確認"
    echo "  2) そのファイルを開き、<<<<<<< ======= >>>>>>> の印を手で整理"
    echo "  3) git add <ファイル> && git commit"
    echo "  4) もう一度 ./sync.sh を実行"
    exit 1
}

echo "=== 1. 自分の変更を記録 ========================================"
git add -A
git status --short
if git diff --cached --quiet; then
    echo "  変更なし。"
else
    git commit -q -m "$MSG" && echo "  コミットしました: $MSG"
fi

echo
echo "=== 2. 他の人の変更を取り込む =================================="
echo "--- GitHub から ---"
git pull --no-rebase --no-edit origin main || fail_on_conflict
if git remote | grep -qx overleaf; then
    echo "--- Overleaf から（共著者の本文編集） ---"
    git pull --no-rebase --no-edit overleaf main || fail_on_conflict
fi

echo
echo "=== 3. 送る ===================================================="
echo "--- GitHub へ ---"
git push origin main || exit 1
if git remote | grep -qx overleaf; then
    echo "--- Overleaf へ ---"
    git push overleaf main || exit 1
else
    echo "  (overleaf リモート未設定のためスキップ)"
fi

echo
echo "=== 完了 ======================================================"
echo "Overleaf を開いて Recompile すれば、新しい表と図が反映されます。"
