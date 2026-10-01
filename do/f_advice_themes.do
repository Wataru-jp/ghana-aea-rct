*==============================================================================
* f_advice_themes.do -- what the extension advice was ABOUT.
*
* Source: Biweekly survey data/advice_texts.xlsx -- the open-ended reason for the
* satisfaction rating (Q5), hand-coded by the PI into nine topics for the 793
* responses that mention advice or training.
*
* Bars are COUNTS of mentions, POOLED over the three arms (co-author decision,
* Sep 2026): the arms differ in size (100/152/126 farmers) and response length is
* driven by enumerator, with three enumerators handling T1 farmers exclusively,
* so a treatment comparison here would be meaningless. What the figure is for is
* the composition of the advice farmers recall.
*
* Output: tmp/fig_advice_themes.pdf
*==============================================================================
set more off
global path "/Users/wkodama/Documents/research/ghana-aea-rct"
global tmp  "$path/tmp"

use "$tmp/advice_themes.dta", clear
* rainfed sites only, as in every other estimation (co-author decision, Sep 2026)
drop if irrgsch==1
keep if has_text==1
qui count
di as txt "text-carrying rounds after dropping the irrigation schemes: " r(N)
* per-arm share of text-carrying rounds in which each topic appears
gen all = 1
collapse (sum) th_fert th_plant th_harv th_weed th_land th_seed th_info th_plan, by(all)
reshape long th_, i(all) j(topic) string
rename th_ n_mentions
gen order = .
replace order = 1 if topic=="fert"
replace order = 2 if topic=="plant"
replace order = 3 if topic=="harv"
replace order = 4 if topic=="weed"
replace order = 5 if topic=="land"
replace order = 6 if topic=="seed"
replace order = 7 if topic=="info"
replace order = 8 if topic=="plan"
label define toplbl 1 "Fertilizer" 2 "Planting" 3 "Harvest" 4 "Weeding" 5 "Land preparation" ///
                    6 "Seed" 7 "Information access" 8 "Planning", replace
label values order toplbl
drop topic
list, sepby(order) noobs

graph hbar (asis) n_mentions, over(order, sort(n_mentions) descending label(labsize(medsmall))) ///
    bar(1, color("0 130 60")) blabel(bar, format(%9.0f) size(small)) ///
    ytitle("Number of times the topic was mentioned", size(small)) ///
    ylabel(0(20)120, labsize(small)) legend(off) ///
    graphregion(color(white)) plotregion(color(white)) name(adv, replace)
graph display adv, xsize(9) ysize(4.5)
graph export "$tmp/fig_advice_themes.pdf", replace
di _n "=== fig_advice_themes.pdf written ==="
