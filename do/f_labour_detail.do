*==============================================================================
* f_labour_detail.do -- family and hired labour, broken out by FARM OPERATION
* and by WHO DOES THE WORK (male / female). Outcome: man-days per hectare.
*
* Same ANCOVA as the main tables: endline days/ha on arms + stamp + the SAME
* outcome measured at baseline + province FE, SE clustered at district. The two
* irrigation-scheme districts are dropped, exactly as in f_endline_analysis.do. The labour module records male and female only -- there is no child
* category. Hired labour has no hours question, so hired days = workers x days
* while family days = workers x days x hours / 8.
*
* Input : tmp/labour_by_op.dta   (hhID x operation, built by f_labour_panel.do)
* Output: tmp/e_labour_ops.tex   tmp/e_labour_sex.tex
*==============================================================================
set more off
global path "/Users/wkodama/Documents/research/ghana-aea-rct"
global tmp  "$path/tmp"

use "$tmp/labour_by_op.dta", clear
merge m:1 hhID using "$tmp/farmer_e_analysis.dta", keepusing(gps irrgsch prov) keep(3) nogen
drop if irrgsch==1            // main-analysis sample: rainfed only

label define opl 1 "Nursery" 2 "Land prep" 3 "Transplant/sowing" 4 "Weeding" 5 "Irrigation" ///
                 6 "Spraying" 7 "Bird scaring" 8 "Harvest" 9 "Thresh/dry", replace
label values operation opl

*------------------------------------------------------------------------------
* one ANCOVA per cell, stored as a column
*------------------------------------------------------------------------------
capture program drop lab_one
program define lab_one
    args y o name
    qui sum `y' if treat_dis==0 & operation==`o'
    scalar cm = r(mean)
    eststo `name': reg `y' i.treat_dis i.gps `y'_bl i.prov if operation==`o', cluster(district)
    qui test 1.treat_dis = 2.treat_dis
    estadd scalar t12p  = r(p)
    estadd scalar cmean = cm
end

* ---- Table 1: by operation, family and hired ----
eststo clear
lab_one fam 2 f2
lab_one fam 3 f3
lab_one fam 4 f4
lab_one fam 7 f7
lab_one fam 8 f8
lab_one fam 9 f9
lab_one hir 2 h2
lab_one hir 3 h3
lab_one hir 4 h4
lab_one hir 7 h7
lab_one hir 8 h8
lab_one hir 9 h9
esttab f2 f3 f4 f7 f8 f9 h2 h3 h4 h7 h8 h9 using "$tmp/e_labour_ops.tex", replace ///
    se nogap b(%9.2f) label booktabs nonotes ///
    keep(1.treat_dis 2.treat_dis) ///
    coeflabels(1.treat_dis "T1: Feedback" 2.treat_dis "T2: Feedback+Training") ///
    stats(t12p cmean N, fmt(%9.3f %9.2f %9.0g) labels("T1=T2 [p]" "Ctrl mean" "Obs")) ///
    mtitles("Land prep" "Transpl./sow" "Weeding" "Bird" "Harvest" "Thresh" ///
            "Land prep" "Transpl./sow" "Weeding" "Bird" "Harvest" "Thresh") ///
    mgroups("Family labour (man-days/ha)" "Hired labour (man-days/ha)", pattern(1 0 0 0 0 0 1 0 0 0 0 0) ///
            prefix(\multicolumn{@span}{c}{) suffix(}) span erepeat(\cmidrule(lr){@span})) ///
    star(* 0.10 ** 0.05 *** 0.01)

* ---- Table 2: totals by who does the work ----
preserve
collapse (sum) fam fam_m fam_f hir hir_m hir_f fam_bl fam_m_bl fam_f_bl hir_bl hir_m_bl hir_f_bl, ///
         by(hhID treat_dis district gps prov nonprod)
capture program drop sex_one
program define sex_one
    args y name cond
    * cond must be a single token (no spaces), e.g. nonprod==0
    local iff ""
    if "`cond'"!="" local iff "if `cond'"
    qui sum `y' if treat_dis==0 & (`=cond("`cond'"=="", "1", "`cond'")')
    scalar cm = r(mean)
    eststo `name': reg `y' i.treat_dis i.gps `y'_bl i.prov `iff', cluster(district)
    qui test 1.treat_dis = 2.treat_dis
    estadd scalar t12p  = r(p)
    estadd scalar cmean = cm
end
eststo clear
sex_one fam   s1
sex_one fam_m s2
sex_one fam_f s3
sex_one hir   s4
sex_one hir_m s5
sex_one hir_f s6
sex_one fam   s7 nonprod==0
sex_one hir   s9 nonprod==0
esttab s1 s2 s3 s4 s5 s6 s7 s9 using "$tmp/e_labour_sex.tex", replace ///
    se nogap b(%9.2f) label booktabs nonotes ///
    keep(1.treat_dis 2.treat_dis) ///
    coeflabels(1.treat_dis "T1: Feedback" 2.treat_dis "T2: Feedback+Training") ///
    stats(t12p cmean N, fmt(%9.3f %9.2f %9.0g) labels("T1=T2 [p]" "Ctrl mean" "Obs")) ///
    mtitles("All" "Male" "Female" "All" "Male" "Female" "Family" "Hired") ///
    mgroups("Family labour" "Hired labour" "Excl.\ crop failure", pattern(1 0 0 1 0 0 1 0) ///
            prefix(\multicolumn{@span}{c}{) suffix(}) span erepeat(\cmidrule(lr){@span})) ///
    star(* 0.10 ** 0.05 *** 0.01)
restore

*------------------------------------------------------------------------------
* How much of the hired-FEMALE increase is harvest labour? (co-author request)
* Total effect = the s6 column above; harvest-only = the same ANCOVA on
* operation 8. Share = harvest effect / total effect.
*------------------------------------------------------------------------------
preserve
    collapse (sum) hir_f hir_f_bl, by(hhID treat_dis district gps prov)
    qui reg hir_f i.treat_dis i.gps hir_f_bl i.prov, cluster(district)
    matrix T = r(table)
    scalar tot1 = T[1,colnumb(T,"1.treat_dis")]
    scalar tot2 = T[1,colnumb(T,"2.treat_dis")]
restore
qui reg hir_f i.treat_dis i.gps hir_f_bl i.prov if operation==8, cluster(district)
matrix H = r(table)
scalar h1 = H[1,colnumb(H,"1.treat_dis")]
scalar h2 = H[1,colnumb(H,"2.treat_dis")]
di _n "===== hired-female: harvest share of the total effect ====="
di as txt "  total    T1 " %7.2f tot1 "   T2 " %7.2f tot2
di as txt "  harvest  T1 " %7.2f h1   "   T2 " %7.2f h2
di as txt "  share    T1 " %6.1f 100*h1/tot1 "%   T2 " %6.1f 100*h2/tot2 "%"

di _n "=== e_labour_ops.tex and e_labour_sex.tex written ==="
