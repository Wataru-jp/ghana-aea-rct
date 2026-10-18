*==============================================================================
* practice_logit.do -- Table 7 Panel C re-estimated by logit (co-author
* question, Oct 2026).
*
* The published panel is a linear probability ANCOVA:
*     y_endline on T1, T2, stamp, y_baseline, region FE, SE clustered on district
* Here the same specification is fitted by logit and reported as average
* marginal effects, so the numbers sit on the same scale as the LPM
* coefficients. Column (8) of the panel, the count of practices, is not a
* binary outcome and is left out.
*
* With 8 clusters and three region dummies, separation is a real risk; any
* outcome that fails to converge or drops observations is reported as such.
*
* This is a side analysis; nothing in the deck or the manuscript reads it.
*==============================================================================
set more off
global path "/Users/wkodama/Documents/research/ghana-aea-rct"
global tmp  "$path/tmp"

use "$tmp/farmer_e_analysis.dta", clear
di "farmers = " _N

capture program drop cmp
program define cmp
    args y
    di _n as txt "==== `y' ===="
    qui sum `y' if treat_dis==0
    local cm = r(mean)
    qui sum `y'
    local n0 = r(N)
    * ---- linear probability model, as published ----
    qui reg `y' i.treat_dis i.gps `y'_bl i.prov, cluster(district)
    local l1 = _b[1.treat_dis]
    local s1 = _se[1.treat_dis]
    local l2 = _b[2.treat_dis]
    local s2 = _se[2.treat_dis]
    local lN = e(N)
    * ---- logit, average marginal effects ----
    capture noisily logit `y' i.treat_dis i.gps `y'_bl i.prov, cluster(district)
    if _rc {
        di as error "   logit failed (rc=" _rc ") -- LPM only"
        di as txt "   LPM   T1 " %8.3f `l1' " (" %6.3f `s1' ")   T2 " %8.3f `l2' " (" %6.3f `s2' ")   N " `lN'
        exit
    }
    local gN = e(N)
    capture noisily margins, dydx(i.treat_dis) post
    if _rc {
        di as error "   margins failed -- LPM only"
        exit
    }
    local m1 = _b[1.treat_dis]
    local e1 = _se[1.treat_dis]
    local m2 = _b[2.treat_dis]
    local e2 = _se[2.treat_dis]
    local p1 = 2*normal(-abs(`m1'/`e1'))
    local p2 = 2*normal(-abs(`m2'/`e2'))
    di as txt "   ctrl mean " %5.3f `cm' "    LPM N " `lN' "    logit N " `gN'
    di as txt "   T1   LPM " %8.3f `l1' " (" %6.3f `s1' ")      logit AME " %8.3f `m1' " (" %6.3f `e1' ")  p=" %5.3f `p1'
    di as txt "   T2   LPM " %8.3f `l2' " (" %6.3f `s2' ")      logit AME " %8.3f `m2' " (" %6.3f `e2' ")  p=" %5.3f `p2'
end

foreach v in u_impany u_scertify u_seedtreat u_dib u_ptrans u_bunds u_level {
    cmp `v'
}

di _n "=== done ==="
