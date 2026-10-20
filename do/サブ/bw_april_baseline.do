*==============================================================================
* bw_april_baseline.do -- round-by-round ANCOVA on the bi-weekly panel, using
* the APRIL round (04-2) as the pre-intervention baseline (co-author request,
* Oct 2026).
*
* WHY THIS IS A VALID BASELINE
*   R1 was fielded 25 Apr - 1 May 2025 and asks about "the last two weeks", so
*   its recall window is roughly 11-30 April. The T2 sensitisation training was
*   held on 29 April, and the first feedback report could not exist before the
*   first survey had been run. R1 is therefore pre-treatment for both arms,
*   except for the last day or two of the window for T2.
*   WHEN DID EACH ARM BECOME EXPOSED? Checked against the report files
*   themselves (Dropbox 介入/Feedback Report, Oct 2026). The earliest report is
*   "Feedback Report on Extension Service: First Half of May", and it reports
*   each AEA's visits for the first half of May against "last month" (April).
*   So the first report was built from R2, not from R1, and was shared within
*   two weeks of it. Exposure therefore runs:
*       04-2  nothing (baseline)
*       05-1  T2 training only; NO feedback report has been delivered yet, so
*             T1 is still untreated -- treat the 05-1 T1 estimate as a placebo
*       05-2  the first report lands during this window
*       06-1  onwards: both arms fully exposed
*
* THE FARMER ID TRAP (checked Oct 2026, do not remove the decode)
*   `farmer' and `community' are numeric Kobo codes whose VALUE LABELS are
*   built per file from that round's name list. April's list is shorter (377
*   names vs 389), so the codes drift: of the 374 farmers present in both R1
*   and R11, 368 carry a DIFFERENT numeric code in the two files, by up to 12.
*   Appending first and keying on the number silently mixes people. Every file
*   is therefore decoded to strings BEFORE the append, and the person key is
*   the decoded name within the decoded community.
*
* Outcomes (all defined on every farmer-round, so the panel stays balanced):
*   Q1       number of visits in the past two weeks
*   Q2       number of successful contacts in the past two weeks
*   satisfy2 satisfied (Q4 = 4 or 5); a round with no contact counts as 0
*   adv_any  got helpful advice (Q3_2 = 1); no contact counts as 0
*
* Output: tmp/fig_bw_dynamic.pdf  and  tmp/bw_dynamic_res.dta
*==============================================================================
clear all
set more off
global path "/Users/wkodama/Documents/research/ghana-aea-rct/"
global base   "$path/Baseline"
global survey "$path/Biweekly survey data"
global tmp    "$path/tmp"

*---------------- assembly: decode the per-file labels, THEN append -----------
tempfile stack
local first = 1
local k = 1
foreach f in "R1_April survey"     "R2_May survey_1"    "R3_May survey_2"   ///
             "R4_June survey_1"    "R5_June survey_2"   "R6_July survey_1"  ///
             "R7_July survey_2"    "R8_August survey_1" "R9_August survey_2" ///
             "R10_Sept_survey_1"   "R11_Sept_survey_2" {
    use "$survey/`f'.dta", clear
    gen t = `k'
    foreach v in farmer community district province {
        capture confirm numeric variable `v'
        if !_rc {
            decode `v', gen(`v'_s)
            drop `v'
            rename `v'_s `v'
        }
    }
    capture tostring Q3_1_oth, replace
    rename aea aid
    keep t farmer community district province aid Q1 Q2 Q3_2 Q4
    if `first' save `stack', replace
    else {
        append using `stack'
        save `stack', replace
    }
    local first = 0
    local ++k
}
use `stack', clear
label define tlbl 1 "04-2" 2 "05-1" 3 "05-2" 4 "06-1" 5 "06-2" 6 "07-1" ///
                  7 "07-2" 8 "08-1" 9 "08-2" 10 "09-1" 11 "09-2"
label values t tlbl

* person key = decoded name within decoded community
egen pid = group(farmer community)
di _n "=== person key ==="
qui duplicates report pid t
di "farmer-rounds: " _N "   distinct persons: " r(unique_value)
qui duplicates tag pid t, gen(__dup)
qui count if __dup > 0
di "rows that are not unique within (person, round): " r(N)
* The April file holds one farmer twice (same name, same community, two
* different answer sets). Keep one record, deterministically.
bysort pid t (Q1 Q2 Q3_2 Q4): keep if _n == 1
drop __dup
qui count
di "farmer-rounds after de-duplication: " r(N)

*---------------- treatment ---------------------------------------------------
* The AEA code, unlike the farmer code, IS stable: all 44 names carry the same
* number in R1 and R11, so the numeric merge is safe here (re-checked Oct 2026).
preserve
    use "$base/AEA.dta", clear
    keep aid gps treat_dis discode
    rename discode dcode
    tempfile treat
    save `treat', replace
restore
merge m:1 aid using `treat', keep(1 3)
qui count if treat_dis == .
assert r(N) == 0
drop _merge

* rainfed sites only, as in every other table (3 = Kpong, 8 = Ketu North/Weta)
drop if dcode == 3 | dcode == 8
qui count
di "farmer-rounds after dropping the irrigation schemes: " r(N)

encode province, gen(prov)
gen t1m = (treat_dis == 1)
gen t2m = (treat_dis == 2)

*---------------- outcomes ----------------------------------------------------
gen any_int  = (Q1 > 0 | Q2 > 0)
gen satisfy2 = (Q4 == 4 | Q4 == 5) if any_int == 1
replace satisfy2 = 0 if satisfy2 == .
gen adv_any  = (Q3_2 == 1) if any_int == 1
replace adv_any = 0 if adv_any == .
label var Q1       "Visits (per 2 weeks)"
label var Q2       "Contacts (per 2 weeks)"
label var satisfy2 "Satisfied (=1)"
label var adv_any  "Got helpful advice (=1)"

*---------------- April values as the ANCOVA lag ------------------------------
preserve
    keep if t == 1
    keep pid Q1 Q2 satisfy2 adv_any
    foreach v in Q1 Q2 satisfy2 adv_any {
        rename `v' `v'_bl
    }
    tempfile apr
    save `apr'
restore
merge m:1 pid using `apr', keep(1 3)
di _n "=== April baseline coverage ==="
qui count if _merge == 3 & t > 1
di "farmer-rounds (05-1 .. 09-2) with an April value: " r(N)
qui count if _merge == 1 & t > 1
di "farmer-rounds (05-1 .. 09-2) WITHOUT an April value (dropped): " r(N)
drop _merge

*---------------- round-by-round ANCOVA ---------------------------------------
tempname R
postfile `R' str10 outcome int round str2 arm double b se lo hi wbp cmean ///
    using "$tmp/bw_dynamic_res.dta", replace

foreach y in Q1 Q2 satisfy2 adv_any {
    forvalues r = 2/11 {
        qui reg `y' t1m t2m gps `y'_bl i.prov if t == `r', cluster(dcode)
        local df = e(df_r)
        local crit = invttail(`df', 0.025)
        qui sum `y' if t == `r' & treat_dis == 0 & e(sample)
        local cm = r(mean)
        foreach a in t1m t2m {
            local b  = _b[`a']
            local se = _se[`a']
            qui boottest `a', reps(9999) weight(webb) nograph
            local p = r(p)
            local nm = cond("`a'" == "t1m", "T1", "T2")
            post `R' ("`y'") (`r') ("`nm'") (`b') (`se') ///
                (`b' - `crit'*`se') (`b' + `crit'*`se') (`p') (`cm')
            qui reg `y' t1m t2m gps `y'_bl i.prov if t == `r', cluster(dcode)
        }
    }
}
postclose `R'

*---------------- plot --------------------------------------------------------
use "$tmp/bw_dynamic_res.dta", clear
gen x = round + cond(arm == "T1", -0.12, 0.12)
local xlab 2 "05-1" 3 "05-2" 4 "06-1" 5 "06-2" 6 "07-1" 7 "07-2" 8 "08-1" 9 "08-2" 10 "09-1" 11 "09-2"

local ttl1 "(a) Visits per 2 weeks"
local ttl2 "(b) Contacts per 2 weeks"
local ttl3 "(c) Satisfied with the service (=1)"
local ttl4 "(d) Got helpful advice (=1)"
local i = 0
foreach y in Q1 Q2 satisfy2 adv_any {
    local ++i
    twoway ///
        (rcap lo hi x if outcome=="`y'" & arm=="T1", lcolor("230 120 0") lwidth(0.4)) ///
        (scatter b x if outcome=="`y'" & arm=="T1", mcolor("230 120 0") msymbol(O) msize(1.6)) ///
        (rcap lo hi x if outcome=="`y'" & arm=="T2", lcolor("0 130 60") lwidth(0.4)) ///
        (scatter b x if outcome=="`y'" & arm=="T2", mcolor("0 130 60") msymbol(S) msize(1.6)) ///
        , yline(0, lcolor(gs8) lpattern(dash) lwidth(0.3)) ///
          xlabel(`xlab', angle(45) labsize(2.4)) ///
          xtitle("") ytitle("ANCOVA estimate", size(2.4)) ///
          title("`ttl`i''", size(3.4) margin(b=2) color(black)) ///
          legend(order(2 "T1: Feedback" 4 "T2: Feedback + Training") ///
                 rows(1) size(2.4) region(lstyle(none))) ///
          graphregion(color(white)) plotregion(margin(small)) ///
          name(g`i', replace) nodraw
}
* No note inside the graph: the deck and the manuscript carry their own, and a
* Stata-rendered note does not scale with \adjustbox.
grc1leg2 g1 g2 g3 g4, rows(2) graphregion(color(white)) name(gall, replace)
graph display gall, xsize(9.5) ysize(5.2)
graph export "$tmp/fig_bw_dynamic.pdf", replace
di _n "=== fig_bw_dynamic.pdf written ==="
