*==============================================================================
* bw_aeactrl.do -- do the bi-weekly results (manuscript Tables 4 and 5) survive
* adding agent characteristics as controls? (co-author question, Oct 2026)
*
* The controls are Panel A of manuscript Table 2, i.e. the same variables and
* the same coding as the AEA block of do/desc_be_tables.do, with one exception:
* monthly gross salary is left out at the co-authors' request.
*     age, female, studied agriculture, tenured post, professional grade,
*     experience as an AEA, of which in this district, farmer groups assisted
* All come from the baseline AEA questionnaire (Panels A and B).
*
* Treatment is assigned at the district level, so these covariates cannot bias
* the arm coefficients; this is a precision check, not an identification one.
* With 8 clusters and 42 agents, eight agent-level covariates is a lot, so read
* the comparison as a stress test.
*
* Sample is the rainfed panel exactly as in the published tables: 8 districts,
* 42 AEAs, 4,120 farmer-round observations. The two irrigation schemes are not
* in tmp/bw_panel.dta at all.
*
* Specification is otherwise identical to do/bw_tables_v2.do.
* This is a side analysis; nothing in the deck or the manuscript reads it.
*==============================================================================
set more off
global path "/Users/wkodama/Documents/research/ghana-aea-rct"
global tmp  "$path/tmp"

* --- agent characteristics, coded exactly as in do/desc_be_tables.do ---------
use "$path/Baseline/AEA baseline.dta", clear
rename aea aid
gen byte c_female  = (panelA_C == 2)
gen byte c_agedu   = (panelA_E1 == 1)
gen byte c_tenure  = (panelA_F == 1)
gen byte c_prof    = (panelA_J >= 3) if panelA_J < .
clonevar c_age     = panelA_B
clonevar c_exp     = panelA_G
clonevar c_exphere = panelA_H
clonevar c_groups  = panelB_A
keep aid c_*
tempfile chars
save `chars'

use "$tmp/bw_panel.dta", clear
merge m:1 aid using `chars', keep(1 3) nogen

label var c_age     "Age (years)"
label var c_female  "Female (=1)"
label var c_agedu   "Studied agriculture (=1)"
label var c_tenure  "Tenured post (=1)"
label var c_prof    "Professional grade or above (=1)"
label var c_exp     "Experience as an AEA (years)"
label var c_exphere "\quad of which in this district (years)"
label var c_groups  "Farmer groups assisted in 2024"

global aeactl "c_age c_female c_agedu c_tenure c_prof c_exp c_exphere c_groups"
summarize $aeactl
qui count if missing(c_age, c_female, c_agedu, c_tenure, c_prof, c_exp, c_exphere, c_groups)
di as txt "rows missing any agent characteristic: " r(N) " of " _N
qui tab district
di as txt "districts in the estimation sample: " r(r) "   (irrigation is not in this panel)"

capture program drop bw_ctl
program define bw_ctl
    args y name addctl wcond
    local xctl ""
    if "`addctl'"=="yes" local xctl "Q1 Q2"
    local iff ""
    if "`wcond'"!="" local iff "if `wcond'"
    if "`wcond'"=="" qui sum `y' if treat_dis==0 & t==1
    else             qui sum `y' if treat_dis==0 & `wcond'
    scalar cm = r(mean)
    qui reg `y' i.treat_dis i.gps $aeactl `xctl' i.t i.province `iff', cluster(district)
    qui boottest 1.treat_dis, reps(9999) weight(webb) nograph
    scalar wbt1 = r(p)
    qui boottest 2.treat_dis, reps(9999) weight(webb) nograph
    scalar wbt2 = r(p)
    set seed 12345
    qui randcmd ((t1m t2m) reg `y' t1m t2m gps $aeactl `xctl' i.t i.province `iff', cluster(district)), ///
        reps(1000) treatvars(t1m t2m)
    matrix ripv = e(RCoef)
    scalar rit1 = ripv[1,6]
    scalar rit2 = ripv[2,6]
    eststo `name': reg `y' i.treat_dis i.gps $aeactl `xctl' i.t i.province `iff', cluster(district)
    qui test 1.treat_dis = 2.treat_dis
    estadd scalar t12p  = r(p)
    estadd scalar cmean = cm
    estadd scalar wb_t1 = wbt1
    estadd scalar wb_t2 = wbt2
    estadd scalar ri_t1 = rit1
    estadd scalar ri_t2 = rit2
end

* --- Table 4 outcomes --------------------------------------------------------
eststo clear
bw_ctl Q1 cQ1
bw_ctl Q2 cQ2
bw_ctl Q1 pQ1 "" inrange(t,4,6)
bw_ctl Q2 pQ2 "" inrange(t,4,6)
bw_ctl Q1 gQ1 "" inrange(t,7,9)
bw_ctl Q2 gQ2 "" inrange(t,7,9)
esttab cQ1 cQ2 pQ1 pQ2 gQ1 gQ2, se b(%9.3f) ///
    keep(1.treat_dis 2.treat_dis 1.gps $aeactl) ///
    stats(cmean wb_t1 wb_t2 ri_t1 ri_t2 N, fmt(%9.3f %9.3f %9.3f %9.3f %9.3f %9.0g)) ///
    mtitles("allQ1" "allQ2" "plantQ1" "plantQ2" "growQ1" "growQ2") ///
    title("TABLE 4 WITH AGENT CONTROLS")

* --- Table 5 outcomes --------------------------------------------------------
eststo clear
bw_ctl satisfy    s1
bw_ctl satisfy2   s2
bw_ctl satisfy    s3 yes
bw_ctl satisfy2   s4 yes
bw_ctl adv_yes    c1
bw_ctl adv_no     c2
bw_ctl adv_noprob c3
esttab s1 s2 s3 s4 c1 c2 c3, se b(%9.3f) ///
    keep(1.treat_dis 2.treat_dis 1.gps $aeactl) ///
    stats(cmean wb_t1 wb_t2 ri_t1 ri_t2 N, fmt(%9.3f %9.3f %9.3f %9.3f %9.3f %9.0g)) ///
    mtitles("Sat" "SatFull" "SatCtl" "SatFullCtl" "Advice" "NoAdvice" "NoProblem") ///
    title("TABLE 5 WITH AGENT CONTROLS")

di _n "=== done ==="
