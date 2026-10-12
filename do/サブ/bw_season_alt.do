*==============================================================================
* bw_season_alt.do -- the bi-weekly effort regressions (deck Table 4 /
* manuscript Table 4) re-cut into different seasonal windows, at the
* co-authors' request (Oct 2026).
*
* Deck/manuscript windows        this file's windows
*   planting  05-1 .. 06-2  (t 2-5)   planting  06-1 .. 07-1  (t 4-6)
*   growing   07-1 .. 08-2  (t 6-9)   growing   07-2 .. 08-2  (t 7-9)
*   --                                harvest   09-1 .. 09-2  (t 10-11)
*
* Specification is identical to do/bw_tables_v2.do: farmer x round panel, OLS
* with round and province fixed effects, SE clustered on district, plus wild
* cluster bootstrap (Webb, 9,999) and randomization-inference p-values.
*
* This is a side analysis; nothing in the deck or the manuscript reads it.
* Output: tmp/サブ/bw_effort_season_alt.tex, tmp/サブ/bw_satisfy_season_alt.tex
*         and the log.
*==============================================================================
set more off
global path "/Users/wkodama/Documents/research/ghana-aea-rct"
global tmp  "$path/tmp"

use "$tmp/bw_panel.dta", clear
di "rounds in the panel:"
tab t

capture program drop bw_one
program define bw_one
    args y name addctl wcond
    local xctl ""
    if "`addctl'"=="yes" local xctl "Q1 Q2"
    local iff ""
    if "`wcond'"!="" local iff "if `wcond'"
    if "`wcond'"=="" qui sum `y' if treat_dis==0 & t==1
    else             qui sum `y' if treat_dis==0 & `wcond'
    scalar cm = r(mean)
    qui reg `y' i.treat_dis i.gps `xctl' i.t i.province `iff', cluster(district)
    qui boottest 1.treat_dis, reps(9999) weight(webb) nograph
    scalar wbt1 = r(p)
    qui boottest 2.treat_dis, reps(9999) weight(webb) nograph
    scalar wbt2 = r(p)
    set seed 12345
    qui randcmd ((t1m t2m) reg `y' t1m t2m gps `xctl' i.t i.province `iff', cluster(district)), ///
        reps(1000) treatvars(t1m t2m)
    matrix ripv = e(RCoef)
    scalar rit1 = ripv[1,6]
    scalar rit2 = ripv[2,6]
    eststo `name': reg `y' i.treat_dis i.gps `xctl' i.t i.province `iff', cluster(district)
    qui test 1.treat_dis = 2.treat_dis
    estadd scalar t12p  = r(p)
    estadd scalar cmean = cm
    estadd scalar wb_t1 = wbt1
    estadd scalar wb_t2 = wbt2
    estadd scalar ri_t1 = rit1
    estadd scalar ri_t2 = rit2
end

eststo clear
bw_one Q1 aQ1
bw_one Q2 aQ2
bw_one Q1 pQ1 "" inrange(t,4,6)
bw_one Q2 pQ2 "" inrange(t,4,6)
bw_one Q1 gQ1 "" inrange(t,7,9)
bw_one Q2 gQ2 "" inrange(t,7,9)
bw_one Q1 hQ1 "" inrange(t,10,11)
bw_one Q2 hQ2 "" inrange(t,10,11)

capture mkdir "$tmp/サブ"
esttab aQ1 aQ2 pQ1 pQ2 gQ1 gQ2 hQ1 hQ2 using "$tmp/サブ/bw_effort_season_alt.tex", replace ///
    se nogap b(%9.3f) label booktabs nonotes ///
    keep(1.treat_dis 2.treat_dis 1.gps) ///
    order(1.treat_dis 2.treat_dis 1.gps) ///
    coeflabels(1.treat_dis "T1: Feedback" 2.treat_dis "T2: Feedback+Training" ///
               1.gps "Stamp (GPS)") ///
    stats(t12p cmean wb_t1 wb_t2 ri_t1 ri_t2 N, fmt(%9.3f %9.3f %9.3f %9.3f %9.3f %9.3f %9.0g) ///
          labels("T1=T2 [p]" "Control mean" "Wild-boot p (T1)" "Wild-boot p (T2)" "RI p (T1)" "RI p (T2)" "Obs")) ///
    mtitles("Visits" "Contacts" "Visits" "Contacts" "Visits" "Contacts" "Visits" "Contacts") ///
    mgroups("All rounds" "Planting (06-1--07-1)" "Growing (07-2--08-2)" "Harvest (09-1--09-2)", ///
            pattern(1 0 1 0 1 0 1 0) prefix(\multicolumn{@span}{c}{) suffix(}) span erepeat(\cmidrule(lr){@span})) ///
    star(* 0.10 ** 0.05 *** 0.01)

esttab aQ1 aQ2 pQ1 pQ2 gQ1 gQ2 hQ1 hQ2, ///
    se b(%9.3f) keep(1.treat_dis 2.treat_dis 1.gps) ///
    stats(cmean wb_t1 wb_t2 ri_t1 ri_t2 N, fmt(%9.3f %9.3f %9.3f %9.3f %9.3f %9.0g)) ///
    mtitles("allQ1" "allQ2" "plantQ1" "plantQ2" "growQ1" "growQ2" "harvQ1" "harvQ2")

*------------------------------------------------------------------------------
* Satisfaction, same windows. "Satisfied" is the dummy on rounds with a visit or
* a contact; "Satisfied (full)" counts a round with neither as not satisfied.
*------------------------------------------------------------------------------
eststo clear
bw_one satisfy  as1
bw_one satisfy2 as2
bw_one satisfy  ps1 "" inrange(t,4,6)
bw_one satisfy2 ps2 "" inrange(t,4,6)
bw_one satisfy  gs1 "" inrange(t,7,9)
bw_one satisfy2 gs2 "" inrange(t,7,9)
bw_one satisfy  hs1 "" inrange(t,10,11)
bw_one satisfy2 hs2 "" inrange(t,10,11)

esttab as1 as2 ps1 ps2 gs1 gs2 hs1 hs2 using "$tmp/サブ/bw_satisfy_season_alt.tex", replace ///
    se nogap b(%9.3f) label booktabs nonotes ///
    keep(1.treat_dis 2.treat_dis 1.gps) ///
    order(1.treat_dis 2.treat_dis 1.gps) ///
    coeflabels(1.treat_dis "T1: Feedback" 2.treat_dis "T2: Feedback+Training" ///
               1.gps "Stamp (GPS)") ///
    stats(t12p cmean wb_t1 wb_t2 ri_t1 ri_t2 N, fmt(%9.3f %9.3f %9.3f %9.3f %9.3f %9.3f %9.0g) ///
          labels("T1=T2 [p]" "Control mean" "Wild-boot p (T1)" "Wild-boot p (T2)" "RI p (T1)" "RI p (T2)" "Obs")) ///
    mtitles("Satisfied" "Satisfied (full)" "Satisfied" "Satisfied (full)" ///
            "Satisfied" "Satisfied (full)" "Satisfied" "Satisfied (full)") ///
    mgroups("All rounds" "Planting (06-1--07-1)" "Growing (07-2--08-2)" "Harvest (09-1--09-2)", ///
            pattern(1 0 1 0 1 0 1 0) prefix(\multicolumn{@span}{c}{) suffix(}) span erepeat(\cmidrule(lr){@span})) ///
    star(* 0.10 ** 0.05 *** 0.01)

esttab as1 as2 ps1 ps2 gs1 gs2 hs1 hs2, ///
    se b(%9.3f) keep(1.treat_dis 2.treat_dis 1.gps) ///
    stats(cmean wb_t1 wb_t2 ri_t1 ri_t2 N, fmt(%9.3f %9.3f %9.3f %9.3f %9.3f %9.0g)) ///
    mtitles("allS" "allSf" "plantS" "plantSf" "growS" "growSf" "harvS" "harvSf")

di _n "=== done ==="
