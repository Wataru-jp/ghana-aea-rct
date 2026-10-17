*==============================================================================
* fig4_planting.do -- Figure 4 (farmer-reported against self-reported visits)
* restricted to the planting window, at the co-authors' request (Oct 2026).
*
* The published figure uses the whole season: farmer-reported visits per month
* is the mean cumulative count over the 11 bi-weekly rounds divided by 5.5
* months. This version counts only rounds 06-1, 06-2 and 07-1 (t = 4..6, three
* rounds = 1.5 months), the window in which the treatment effect on visits is
* concentrated. Mean Q1 per round times two gives visits per month either way.
*
* Self-reported visits are unchanged (panelB_H, visits per group per month, one
* figure for the whole season), so the comparison asks whether the agents'
* own number lines up better with what farmers report at the busiest time.
*
* This is a side analysis; nothing in the deck or the manuscript reads it.
* Output: tmp/サブ/fig_selfrep_farmer_planting.pdf
*==============================================================================
set more off
global path "/Users/wkodama/Documents/research/ghana-aea-rct"
global tmp  "$path/tmp"

* ---- farmer-reported visits per month, whole season and planting window -----
use "$tmp/bw_panel.dta", clear
gen byte plant = inrange(t,4,6)
collapse (mean) q_all=Q1 (mean) q_pl=Q1 if !missing(Q1), by(aid plant)
reshape wide q_all q_pl, i(aid) j(plant)
gen fv_month_all  = q_all0*0 + .          // placeholder, rebuilt below
drop fv_month_all q_pl0 q_pl1 q_all0 q_all1
tempfile dummy
save `dummy', replace

use "$tmp/bw_panel.dta", clear
qui sum Q1
collapse (mean) mq_all=Q1, by(aid)
gen fv_all = mq_all*2
tempfile allv
save `allv'

use "$tmp/bw_panel.dta", clear
keep if inrange(t,4,6)
collapse (mean) mq_pl=Q1, by(aid)
gen fv_pl = mq_pl*2
merge 1:1 aid using `allv', nogen
label var fv_all "Farmer-reported visits per month, Apr--Sep"
label var fv_pl  "Farmer-reported visits per month, planting window"
tempfile fv
save `fv'

* ---- self-reported visits ---------------------------------------------------
use "$tmp/a_AEA_endline_analysis.dta", clear
keep aeaID a_avvisit a_avvisit_bl treat_dis
rename aeaID aid
merge 1:1 aid using `fv', keep(3) nogen
label var a_avvisit    "Self-reported visits per group per month (endline)"
label var a_avvisit_bl "Self-reported visits per group per month (baseline)"

di _n "=== AEAs matched: " _N " ==="
summarize fv_all fv_pl a_avvisit_bl a_avvisit
di _n "=== correlations with the self-report ==="
corr fv_all fv_pl a_avvisit_bl a_avvisit
di _n "=== regression of farmer-reported on self-reported ==="
foreach y in fv_all fv_pl {
    foreach x in a_avvisit_bl a_avvisit {
        qui reg `y' `x'
        di %-8s "`y'" " on " %-14s "`x'" "  b=" %7.4f _b[`x'] "  se=" %7.4f _se[`x'] ///
           "  p=" %6.3f 2*ttail(e(df_r),abs(_b[`x']/_se[`x'])) "  R2=" %5.3f e(r2) "  N=" %3.0f e(N)
    }
}
di _n "=== how often does the agent claim more than farmers report? ==="
count if a_avvisit > fv_all & a_avvisit < .
di "  whole season: " r(N) " of " _N
count if a_avvisit > fv_pl & a_avvisit < .
di "  planting window: " r(N) " of " _N
