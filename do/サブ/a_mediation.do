*==============================================================================
* a_mediation.do -- how much of the AEA knowledge effect runs through JICA
* training and through contact with farmers (co-author request, Sep 2026).
*
* Column (1) is the total effect: the ANCOVA already on the deck.
* Column (2) adds the candidate mediators -- attended JICA-provided training,
* the AEA's own reported visits per group, and the farmer-reported visits and
* contacts aggregated to the AEA -- so the arm coefficient becomes the DIRECT
* effect. The indirect share is (total - direct)/total.
*
* CAVEAT: every mediator is measured AFTER treatment, so these are "bad
* controls". The decomposition is descriptive and requires no unobserved
* mediator-outcome confounding; it is not a causal mediation estimate.
*
* Output: tmp/e_aea_mediation.tex
*==============================================================================
set more off
global path "/Users/wkodama/Documents/research/ghana-aea-rct"
global tmp  "$path/tmp"
global controls_extra "i.irrgsch"

* farmer-reported visits and contacts, aggregated to the AEA
use "$tmp/bw_cum.dta", clear
merge 1:1 hhID using "$tmp/farmer_aid_xy.dta", keepusing(aid) keep(3) nogen
collapse (mean) fvis=cumQ1 fcon=cumQ2, by(aid)
rename aid aeaID
tempfile FV
save `FV'

use "$tmp/a_AEA_endline_analysis.dta", clear
merge 1:1 aeaID using `FV', keep(1 3) nogen
label var a_train_jica "JICA training (=1)"
label var a_avvisit    "Self-rep. visits"
label var fvis         "Farmer-rep. visits"
label var fcon         "Farmer-rep. contacts"

capture program drop medpair
program define medpair
    args y ylag
    * (1) total
    eststo t_`y': reg `y' i.treat_dis i.gps $controls_extra `ylag', cluster(district)
    matrix T = r(table)
    local t1 = T[1,colnumb(T,"1.treat_dis")]
    local t2 = T[1,colnumb(T,"2.treat_dis")]
    * (2) direct, conditioning on the mediators
    eststo d_`y': reg `y' i.treat_dis i.gps $controls_extra `ylag' ///
        a_train_jica a_avvisit fvis fcon, cluster(district)
    matrix D = r(table)
    local d1 = D[1,colnumb(D,"1.treat_dis")]
    local d2 = D[1,colnumb(D,"2.treat_dis")]
    estadd scalar ind1 = 100*(`t1'-`d1')/`t1' : d_`y'
    estadd scalar ind2 = 100*(`t2'-`d2')/`t2' : d_`y'
    estadd scalar ind1 = . : t_`y'
    estadd scalar ind2 = . : t_`y'
end

eststo clear
medpair a_knowledge  a_knowledge_bl
medpair a_knowledge8 a_knowledge8_bl
esttab t_a_knowledge d_a_knowledge t_a_knowledge8 d_a_knowledge8 ///
    using "$tmp/e_aea_mediation.tex", replace ///
    se nogap b(%9.3f) label booktabs nonotes ///
    keep(1.treat_dis 2.treat_dis a_train_jica a_avvisit fvis fcon) ///
    order(1.treat_dis 2.treat_dis a_train_jica a_avvisit fvis fcon) ///
    coeflabels(1.treat_dis "T1: Feedback" 2.treat_dis "T2: Feedback+Training") ///
    stats(ind1 ind2 N, fmt(%9.1f %9.1f %9.0g) ///
          labels("Indirect share, T1 (\%)" "Indirect share, T2 (\%)" "Obs")) ///
    mtitles("Total" "Direct" "Total" "Direct") ///
    mgroups("Knowledge (0--5)" "Knowledge (0--8)", pattern(1 0 1 0) ///
            prefix(\multicolumn{@span}{c}{) suffix(}) span erepeat(\cmidrule(lr){@span})) ///
    star(* 0.10 ** 0.05 *** 0.01)
di _n "=== e_aea_mediation.tex written ==="
