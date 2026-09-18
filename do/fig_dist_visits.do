*==============================================================================
* fig_dist_visits.do -- three figures for the deck
*   tmp/fig_dist_visits.pdf    distance (AEA -> community centroid) vs visits
*   tmp/fig_selfrep_farmer.pdf self-reported vs farmer-reported visits, by wave
*   tmp/fig_stamp_visits.pdf   GPS-stamp visit log vs the two self-report measures
* AEA-level (N=41: rainfed sites only). Coordinates, the stamp log and all
* distances are built by
* do/aea_distance.do, which must run first (the master handles this).
*==============================================================================
set more off
global path "/Users/wkodama/research/ghana-aea-rct"
global tmp  "$path/tmp"

tempfile dist
use "$tmp/aea_dist.dta", clear
save `dist'

* ---- farmer-reported visits: bi-weekly panel ----
use "$tmp/bw_cum.dta", clear
merge 1:1 hhID using "$tmp/farmer_aid_xy.dta", keepusing(aid) keep(3) nogen
collapse (mean) f_visits=cumQ1, by(aid)
label var f_visits "Farmer-reported visits, Apr--Sep (per farmer)"
tempfile fvis
save `fvis'

* ---- farmer-reported contacts in the two household surveys ----
use "$path/Baseline/QY1-6wet (Contact with extension worker 2024).dta", clear
gen c_n = QY16_1a
replace c_n = 0 if QY16_1==0
keep hhID c_n
merge 1:1 hhID using "$path/Baseline/Cover_v2.dta", keepusing(aeaID) keep(3) nogen
rename aeaID aid
collapse (mean) f_contact_b=c_n, by(aid)
tempfile fcb
save `fcb'
use "$path/Endline/QY1-6wet (Contact with extension worker 2025).dta", clear
gen c_n = QY16_1a
replace c_n = 0 if QY16_1==0
keep hhID c_n
merge 1:1 hhID using "$tmp/farmer_aid_xy.dta", keepusing(aid) keep(3) nogen
collapse (mean) f_contact_e=c_n, by(aid)
tempfile fce
save `fce'

* ---- number of farmer groups assisted (panelB_A), both waves ----
use "$path/Baseline/AEA baseline.dta", clear
rename aea aid
keep aid panelB_A
rename panelB_A ngroup_bl
tempfile gb
save `gb'
use "$path/Endline/Revised data/AEA endline.dta", clear
capture rename aea aid
capture rename aeaID aid
keep aid panelB_A
rename panelB_A ngroup_e
merge 1:1 aid using `gb', nogen
tempfile grp
save `grp'

* ---- self-reported visits + treatment ----
use "$tmp/a_AEA_endline_analysis.dta", clear
keep aeaID treat_dis a_avvisit a_avvisit_bl
rename aeaID aid
merge 1:1 aid using `grp', keep(1 3) nogen
merge 1:1 aid using `dist',  keep(1 3) nogen
merge 1:1 aid using `fvis',  keep(1 3) nogen
merge 1:1 aid using `fcb',   keep(1 3) nogen
merge 1:1 aid using `fce',   keep(1 3) nogen
merge 1:1 aid using "$tmp/aea_stamp_xy.dta", keep(1 3) keepusing(st_wp st_days st_trips st_mon) nogen
replace st_wp    = 0 if st_wp==.
replace st_days  = 0 if st_days==.
replace st_trips = 0 if st_trips==.
replace st_mon   = 0 if st_mon==.
gen byte has_stamp = (st_wp>0)
label var has_stamp "Submitted at least one GPS-stamp visit record"
label define arml 0 "Control" 1 "T1" 2 "T2"
label values treat_dis arml
save "$tmp/aea_dist_visits.dta", replace

di _n "===== distance: baseline vs endline AEA coordinates ====="
tabstat d_b d_e, stat(mean p50 p90 max n) col(stat) format(%8.1f)
count if d_b>50 & d_b<.
count if d_e>50 & d_e<.
list aid treat_dis d_b d_e if d_b>50 & d_b<., noobs clean

*------------------------------------------------------------------------------
* Figures.
*  1) distance (AEA baseline GPS -> centroid of each community served) vs visits,
*     distance on a LOG scale so the two AEAs whose GPS was recorded away from
*     their duty station do not drive the fit;
*  2) self-reported vs farmer-reported visits, both expressed per farmer group
*     per week, with a 45-degree line.
* Farmer-reported effort is always the bi-weekly visit count (Apr-Sep 2025).
*------------------------------------------------------------------------------
use "$tmp/aea_dist_visits.dta", clear
gen lnd     = ln(d_b)
* Units (checked against the questionnaires, Sep 2026):
*   panelB_H asks "How often do you visit farmer group ON AVERAGE ... times per
*   month", so a_avvisit is ALREADY visits per group per MONTH -- it must NOT be
*   divided by the number of groups. NB the endline instrument changed the unit
*   to "times per week/per month" without recording which was used.
*   f_visits is the mean over the AEA's sample farmers of cumulative visits over
*   the 11 bi-weekly rounds (Apr-Sep, ~5.5 months), so /5.5 puts it per month.
gen fv_week    = f_visits/5.5
gen sv_week_bl = a_avvisit_bl
gen sv_week_e  = a_avvisit
label var fv_week    "Farmer-reported visits per month"
label var sv_week_bl "Self-reported visits per group per month (baseline)"
label var sv_week_e  "Self-reported visits per group per month (endline)"
* slope of y on x with significance stars, for the panel subtitles
capture program drop slopestar
program define slopestar, rclass
    args y x fmt
    if "`fmt'"=="" local fmt "%5.3f"
    qui reg `y' `x'
    local b = _b[`x']
    local p = 2*ttail(e(df_r), abs(_b[`x']/_se[`x']))
    local st = cond(`p'<.01,"***",cond(`p'<.05,"**",cond(`p'<.1,"*","")))
    return local txt = trim(string(`b',"`fmt'")) + "`st'"   // e.g. -0.543***
    return scalar b  = `b'
    return scalar a  = _b[_cons]
end

* shared graph styling (colours, marker and legend) used by all three figures --
* kept as locals only so the three panels cannot drift apart visually
local cC "gs7"
local c1 "230 120 0"
local c2 "0 130 60"
local opt "msize(medium) msymbol(O)"
local leg legend(order(1 "Control" 2 "T1" 3 "T2") rows(1) size(small) region(lstyle(none)))
* the x variable in BOTH the scatter and the fit is lnd (natural log of km);
* the axis is then labelled at round kilometre values -> edit this line to
* change the tick marks: position = ln(km), label = km
* after the Aug-2026 stamp relocation the range is 0.007--31 km (was 0.007--281)
local xl xlabel(-4.61 "0.01" -2.30 "0.1" 0 "1" 2.30 "10" 3.40 "30", labsize(small)) ylabel(, labsize(small))

* ---- Figure 1 ----
* the slope is printed in each panel title (floating text collided with the fit line)
slopestar a_avvisit lnd
local lab1 = r(txt)
slopestar f_visits lnd
local lab2 = r(txt)
twoway (scatter a_avvisit lnd if treat_dis==0, mcolor(`cC') `opt') ///
       (scatter a_avvisit lnd if treat_dis==1, mcolor("`c1'") `opt') ///
       (scatter a_avvisit lnd if treat_dis==2, mcolor("`c2'") `opt') ///
       (lfit a_avvisit lnd, lcolor(gs5) lpattern(dash)), ///
    `xl' ///
    xtitle("Distance to communities (km, log)", size(small)) ///
    ytitle("AEA self-reported visits", size(small)) ///
    title("Self-reported (slope `lab1')", size(medium)) `leg' ///
    graphregion(color(white)) name(g1, replace) nodraw
twoway (scatter f_visits lnd if treat_dis==0, mcolor(`cC') `opt') ///
       (scatter f_visits lnd if treat_dis==1, mcolor("`c1'") `opt') ///
       (scatter f_visits lnd if treat_dis==2, mcolor("`c2'") `opt') ///
       (lfit f_visits lnd, lcolor(gs5) lpattern(dash)), ///
    `xl' ///
    xtitle("Distance to communities (km, log)", size(small)) ///
    ytitle("Farmer-reported visits", size(small)) ///
    title("Farmer-reported (slope `lab2')", size(medium)) `leg' ///
    graphregion(color(white)) name(g2, replace) nodraw
* third panel: the GPS-stamp log, which exists only for the 19 stamp-arm AEAs
* that submitted records, so this panel has N=19 rather than 43.
preserve
    keep if has_stamp
    slopestar st_days lnd
    local lab5 = r(txt)
restore
twoway (scatter st_days lnd if treat_dis==0 & has_stamp, mcolor(`cC') `opt') ///
       (scatter st_days lnd if treat_dis==1 & has_stamp, mcolor("`c1'") `opt') ///
       (scatter st_days lnd if treat_dis==2 & has_stamp, mcolor("`c2'") `opt') ///
       (lfit st_days lnd if has_stamp, lcolor(gs5) lpattern(dash)), ///
    `xl' ///
    xtitle("Distance to communities (km, log)", size(small)) ///
    ytitle("Days with a logged visit", size(small)) ///
    title("GPS-stamp log, N=19 (slope `lab5')", size(medium)) `leg' ///
    graphregion(color(white)) name(g3, replace) nodraw
* NB grc1leg ignores xsize/ysize -- set the canvas on the combined graph instead,
* otherwise the three panels come out on Stata's default 5.5x4in square.
grc1leg g1 g2 g3, rows(1) graphregion(color(white)) legendfrom(g1) name(gcomb, replace)
graph display gcomb, xsize(16) ysize(6)
graph export "$tmp/fig_dist_visits.pdf", replace
di _n "=== Fig 1 panel 3: stamp log on ln(distance) ==="
regress st_days lnd if has_stamp

di _n "=== Fig 1: slope on ln(distance) ==="
regress a_avvisit lnd
display "self-reported : b=" _b[lnd] "  p=" 2*ttail(e(df_r),abs(_b[lnd]/_se[lnd])) "  N=" e(N)
regress a_avvisit lnd if relocate==0
display "   excl. the 2 corrected AEAs: b=" _b[lnd] "  p=" 2*ttail(e(df_r),abs(_b[lnd]/_se[lnd])) "  N=" e(N)

regress f_visits lnd
display "farmer-reported : b=" _b[lnd] "  p=" 2*ttail(e(df_r),abs(_b[lnd]/_se[lnd])) "  N=" e(N)
regress f_visits lnd if relocate==0
display "   excl. the 2 corrected AEAs: b=" _b[lnd] "  p=" 2*ttail(e(df_r),abs(_b[lnd]/_se[lnd])) "  N=" e(N)

* ---- Figure 2 ----
* axis fixed by hand (edit here): x ticks 0(5)15, y ticks 0(1)5
* Full x range (0-50) with the y axis opened to 0-5 (co-author request, Sep 2026).
local xmax = 50
local ymax = 5
slopestar fv_week sv_week_bl
local lab3 = r(txt)
slopestar fv_week sv_week_e
local lab4 = r(txt)
twoway (scatter fv_week sv_week_bl if treat_dis==0, msize(vtiny) mcolor(`cC') `opt') ///
       (scatter fv_week sv_week_bl if treat_dis==1, msize(tiny) mcolor("`c1'") `opt') ///
       (scatter fv_week sv_week_bl if treat_dis==2, msize(tiny) mcolor("`c2'") `opt') ///
       (lfit fv_week sv_week_bl, range(0 50) lcolor(gs5) lpattern(dash)) ///
       (function y=x, range(0 `ymax') lcolor(black)), ///
    xscale(range(0 50)) yscale(range(0 `ymax')) ///
    xlabel(0(10)50) ylabel(0(1)5) ///
    xtitle("AEA self-reported visits per group per month", size(small)) ///
    ytitle("Farmer-reported visits per month", size(small)) ///
    title("Self-Reported in Baseline (slope = `lab3')", size(medium)) `leg' ///
    graphregion(color(white)) name(h1, replace)
twoway (scatter fv_week sv_week_e if treat_dis==0, msize(vtiny) mcolor(`cC') `opt') ///
       (scatter fv_week sv_week_e if treat_dis==1, msize(vtiny) mcolor("`c1'") `opt') ///
       (scatter fv_week sv_week_e if treat_dis==2, msize(vtiny) mcolor("`c2'") `opt') ///
       (lfit fv_week sv_week_e, range(0 50) lcolor(gs5)  lpattern(dash)) ///
       (function y=x, range(0 `ymax') lcolor(black)), ///
    xscale(range(0 50)) yscale(range(0 `ymax')) ///
    xlabel(0(10)50) ylabel(0(1)5) ///
    xtitle("AEA self-reported visits per group per month", size(small)) ///
    ytitle("Farmer-reported visits per month", size(small)) ///
    title("Self-Reported in Endline (slope = `lab4')", size(medium)) `leg' ///
    graphregion(color(white)) name(h2, replace) nodraw
* NB grc1leg ignores xsize/ysize -- set the canvas on the combined graph.
* Each panel is twice as wide as before so the 45-degree reference reads closer
* to a diagonal (the axes still differ by a factor of ~17, see the log).
grc1leg h1 h2, rows(1) graphregion(color(white)) legendfrom(h1) name(hcomb, replace)
graph display hcomb, xsize(11) ysize(4)
graph export "$tmp/fig_selfrep_farmer.pdf", replace
di _n "=== Fig 2: scales and correlations ==="
tabstat sv_week_bl sv_week_e fv_week ngroup_bl ngroup_e, stat(mean p50 max n) col(stat) format(%8.2f)
corr fv_week sv_week_bl sv_week_e
count if sv_week_e>fv_week & sv_week_e<.

*------------------------------------------------------------------------------
* Figure 3. The GPS-stamp visit log as an independent third effort measure.
* Only the stamp arm keeps logs, so this is descriptive and cannot be compared
* across treatment arms. Logs are submitted by the AEA, not pinged automatically,
* so they are a LOWER BOUND on visits; the point is the rank correlation with the
* two self-report measures, which is scale-free and unaffected by that.
*------------------------------------------------------------------------------
keep if has_stamp
di _n "=== Fig 3: stamp log, N = " _N " AEAs (all gps==1) ==="
tabstat st_wp st_days st_trips st_mon a_avvisit f_visits, ///
    stat(n mean p50 min max) col(stat) format(%8.2f)
di _n "--- Pearson ---"
corr st_days st_trips st_wp a_avvisit f_visits
di _n "--- Spearman (st_days vs the two self-reports) ---"
spearman st_days a_avvisit
spearman st_days f_visits

slopestar a_avvisit st_days "%6.3f"
local s1 = r(txt)
slopestar f_visits st_days "%6.3f"
local s2 = r(txt)

twoway (scatter a_avvisit st_days if treat_dis==0, mcolor(`cC') `opt') ///
       (scatter a_avvisit st_days if treat_dis==1, mcolor("`c1'") `opt') ///
       (scatter a_avvisit st_days if treat_dis==2, mcolor("`c2'") `opt') ///
       (lfit a_avvisit st_days, lcolor(gs5) lpattern(dash)), ///
    xtitle("Days with a logged visit (Apr--Sep 2025)", size(small)) ///
    ytitle("AEA self-reported visits", size(small)) ///
    title("Self-reported (slope = `s1')", size(medsmall)) `leg' ///
    graphregion(color(white)) name(k1, replace)
twoway (scatter f_visits st_days if treat_dis==0, mcolor(`cC') `opt') ///
       (scatter f_visits st_days if treat_dis==1, mcolor("`c1'") `opt') ///
       (scatter f_visits st_days if treat_dis==2, mcolor("`c2'") `opt') ///
       (lfit f_visits st_days, lcolor(gs5) lpattern(dash)), ///
    xtitle("Days with a logged visit (Apr--Sep 2025)", size(small)) ///
    ytitle("Farmer-reported visits (Apr--Sep total)", size(small)) ///
    title("Farmer-reported (slope = `s2')", size(medsmall)) `leg' ///
    graphregion(color(white)) name(k2, replace) nodraw
grc1leg k1 k2, rows(1) xsize(9) ysize(4) graphregion(color(white)) legendfrom(k1)
graph export "$tmp/fig_stamp_visits.pdf", replace

*------------------------------------------------------------------------------
* Figure 4. What the logged extension activity looks like.
*   Panel A  how far the AEA travelled to each logged visit
*   Panel B  how unequally the logged contacts are spread across AEAs (Lorenz)
* Waypoint level for panel A (357 contacts), AEA level for panel B (19 AEAs).
*------------------------------------------------------------------------------
use "$tmp/aea_stamp_wp.dta", clear
di _n "=== Fig 4A: distance from duty station to the logged visit ==="
tabstat wp_km, stat(n mean p50 p90 max) col(stat) format(%8.2f)

* repeat visits: round the coordinates to ~110 m and count distinct spots
gen spot = string(round(slat,0.001)) + "_" + string(round(slon,0.001))
egen nspot = tag(spot)
count if nspot
di "distinct logged locations: `r(N)' for " _N " contacts"

histogram wp_km, width(1) start(0) percent fcolor(gs11) lcolor(gs6) ///
    xtitle("Distance from the AEA's duty station to the logged visit (km)", size(small)) ///
    ytitle("Per cent of logged contacts", size(small)) ///
    title("Distance travelled per visit", size(medium)) ///
    graphregion(color(white)) name(m1, replace) nodraw

* how the logged contacts are spread across the 19 AEAs
use "$tmp/aea_stamp_xy.dta", clear
keep if st_wp>0 & st_wp<.
histogram st_wp, width(10) start(0) frequency fcolor(gs11) lcolor(gs6) ///
    xtitle("Logged contacts per AEA (Apr--Sep 2025)", size(small)) ///
    ytitle("Number of AEAs", size(small)) ///
    title("Contacts per AEA", size(medium)) ///
    graphregion(color(white)) name(m2, replace) nodraw
graph combine m1 m2, rows(1) xsize(9) ysize(4) graphregion(color(white))
graph export "$tmp/fig_stamp_activity.pdf", replace

*------------------------------------------------------------------------------
* NOTE (Sep 2026): a "visits per group / per community" figure was built here and
* then removed. panelB_H already asks "How often did you visit farmers' groups ON
* AVERAGE", i.e. it is a PER-GROUP frequency, and f_visits is already a per-farmer
* mean, so dividing either by a group or community count double-normalises. The
* denominators themselves are still built (tmp/aea_groups.dta, ncomm in
* tmp/aea_dist.dta) if this is ever revisited.
*------------------------------------------------------------------------------
