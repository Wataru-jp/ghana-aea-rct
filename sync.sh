#!/usr/bin/env bash
# -----------------------------------------------------------------------------
# sync.sh -- 分析結果をコミットして GitHub と Overleaf の両方へ送る。
#
#   ./sync.sh "何を変えたかの一言"
#
# GitHub  = コードと履歴の正本（共著者と共有）
# Overleaf = スライドの表示・本文編集（共著者がLaTeXを直接触る場所）
# 同じ内容を両方に送るので、どちらを見ても中身は一致します。
# -----------------------------------------------------------------------------
set -uo pipefail
cd "$(dirname "$0")"

MSG="${1:-}"
if [ -z "$MSG" ]; then
    echo "使い方: ./sync.sh \"何を変えたかの一言\""
    echo "  例:   ./sync.sh \"灌漑地区を全分析から除外\""
    exit 1
fi

echo "=== 1. 変更内容 ==============================================="
git add -A
git status --short
if git diff --cached --quiet; then
    echo "  変更なし。コミットはスキップします。"
else
    git commit -q -m "$MSG"
    echo "  コミットしました: $MSG"
fi

echo
echo "=== 2. GitHub へ =============================================="
if git push origin main; then
    echo "  OK"
else
    echo "  失敗しました。GitHub側に新しい変更があるなら次を実行してください:"
    echo "      git pull origin main"
    exit 1
fi

echo
echo "=== 3. Overleaf へ ============================================"
# Overleaf 側のブランチ名も main（2026年時点）。master ではない。
if git push overleaf main; then
    echo "  OK"
else
    echo
    echo "  失敗しました。Overleaf側で誰かが編集した可能性が高いです。"
    echo "  次の順で取り込んでから、もう一度 ./sync.sh を実行してください:"
    echo "      git pull overleaf main"
    echo "  （衝突が出たら、対象ファイルを開いて <<<<<<< の行を手で整理し、"
    echo "    git add <ファイル> && git commit）"
    exit 1
fi

echo
echo "=== 完了 ======================================================"
echo "Overleaf を開いて再コンパイルすれば、新しい表と図が反映されます。"
