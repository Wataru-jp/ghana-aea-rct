*==============================================================================
* run_endline_all.do  --  master script: data -> all .tex tables -> slide deck
*
* Every analysis do-file below writes LaTeX fragments into $tmp, which
* Slide/JICA-Ghana_full-analysis.tex pulls in with \input{tmp/...}. Running this file therefore
* refreshes the whole deck: no table is maintained by hand.
*
* Fragments produced (all in $tmp):
*   balance / descriptives : desc_be_*.tex, desc_arm_*.tex, obs_data2.tex,
*                            a_balance*.tex, f_balance*.tex
*   bi-weekly              : bw_effort_v2.tex, bw_satisfy_v2.tex,
*                            bw_content_a/b.tex, bw_*_fbtr.tex,
*                            plus tmp/bw_panel.dta for the side analyses
*   endline farmer         : e_farmer_prod.tex, e_farmer_inputs.tex,
*                            e_farmer_practice.tex, e_farmer_know.tex,
*                            e_farmer_weighted.tex, e_farmer_prac_w.tex,
*                            e_farmer_*_fbtr.tex, e_farmer_disp.tex,
*                            e_farmer_bird.tex, e_farmer_famlab.tex,
*                            e_2sls_*.tex
*   labour detail          : e_labour_ops.tex, e_labour_sex.tex
*   endline AEA            : e_aea_attitude.tex, e_aea_effort.tex, e_aea_*_fbtr.tex
*   AEA effort figures     : fig_dist_visits.pdf, fig_selfrep_farmer.pdf
*   bi-weekly figures      : b_basic.eps, b_satisfy.eps
*   AEA answer figures     : prosocial_be.pdf, locus1_be.pdf, locus2_be.pdf
*   correlations           : f_result_table2*.tex, a_result_table3*.tex,
*                            f_result_pracadopt_b/e.tex
*
*------------------------------------------------------------------------------
* WHICH FILE IS "MAIN"?
*
* do/            every file here produces something the deck uses, and the
*                master below calls all of them. Nothing that the deck shows is
*                built by hand or left to a file the master skips.
*
* do/サブ/       side analyses. Nothing here feeds the deck and nothing here is
*                called by this master:
*                  het_motivation.do who responded more, by baseline AEA
*                                    intrinsic motivation
*                  a_mediation.do    retired: the single mediation column now
*                                    lives in a_endline_analysis.do as col (4)
*                                    of e_aea_effort.tex
*                  income_share.do   income/profit net of land payments, an
*                                    earlier variant of the accounting now used
*                                    in f_endline_analysis.do
*                  bw_setup.do       superseded bi-weekly panel builder
*                  bw_Feedback_k.do  superseded bi-weekly analysis; its two deck
*                                    figures are now built by do/bw_figures.do
*                  STYLE_DEMO.do     do-file style reference
*===============================================================================
clear all
set more off
global path "/Users/wkodama/research/ghana-aea-rct/"
global do   "$path/do"
global tmp  "$path/tmp"

* --- 1. data construction -----------------------------------------------------
do "$do/f_baseline.do"          // baseline farmer  -> tmp/farmer.dta
do "$do/a_baseline.do"          // baseline AEA     -> tmp/AEA_base_tmp.dta
do "$do/f_endline.do"           // endline farmer   -> tmp/farmer_e.dta
do "$do/a_endline.do"           // endline AEA      -> tmp/a_AEA_endline.dta

* --- 2. baseline tables (also builds tmp/a_AEA_sum.dta used for the lags) ------
do "$do/f_analysis.do"          // baseline farmer balance + correlation tables
do "$do/a_analysis.do"          // baseline AEA balance + correlation tables

* --- 2b. AEA coordinates, GPS/stamp log and AEA->community distances ----------
* must precede bw_tables_v2 (distance control) and fig_dist_visits (all figures)
do "$do/aea_distance.do"

* --- 3. bi-weekly panel (also builds tmp/bw_cum.dta needed by the 2SLS) --------
do "$do/bw_tables_v2.do"

* --- 4. endline treatment effects ---------------------------------------------
do "$do/f_endline_analysis.do"
do "$do/a_endline_analysis.do"

* --- 4b. labour detail: by farm operation and by who does the work -----------
* a_mediation.do was retired in Sep 2026 (moved to do/サブ/): the co-authors
* asked for a single mediation column, which now lives in a_endline_analysis.do
* as column (4) of e_aea_effort.tex.
do "$do/f_labour_panel.do"      // -> tmp/labour_by_op.dta
do "$do/f_labour_detail.do"     // -> tmp/e_labour_ops.tex, tmp/e_labour_sex.tex

* --- 5. descriptive and correlation tables for the deck -----------------------
do "$do/desc_be_tables.do"
do "$do/corr_endline.do"

* --- 5b. AEA effort figures (needs tmp/bw_cum.dta + tmp/a_AEA_endline_analysis.dta
*         and the distance/stamp files from aea_distance.do) ---
do "$do/f_advice_themes.do"     // -> tmp/fig_advice_themes.pdf
do "$do/bw_figures.do"          // -> tmp/b_basic.eps, tmp/b_satisfy.eps
do "$do/ae_dist_figs.do"        // -> tmp/prosocial_be.pdf, tmp/locus[12]_be.pdf
do "$do/fig_dist_visits.do"     // -> tmp/fig_dist_visits.pdf, tmp/fig_selfrep_farmer.pdf

* --- 6. compile the deck ------------------------------------------------------
* (comment out if TinyTeX/R is not available on this machine)
capture shell cd "$path/Slide" && Rscript -e 'tinytex::latexmk("JICA-Ghana_full-analysis.tex", engine="pdflatex")'

di _n "=== run_endline_all.do finished: tmp/*.tex refreshed, Slide/JICA-Ghana_full-analysis.pdf rebuilt ==="
