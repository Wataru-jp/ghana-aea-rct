*==============================================================================
* bw_figures.do -- the two descriptive bi-weekly figures on the deck.
*
*   tmp/b_basic.eps    visits, contacts and the 1-5 satisfaction level, mean by
*                      round and arm                             (deck p. 18)
*   tmp/b_satisfy.eps  distribution of the 1-5 satisfaction rating by district
*                      and round, stacked percentages            (deck p. 19)
*
* Replaces the figure blocks of the retired bw_Feedback_k.do (now in do/サブ/),
* which (i) drew on an OBSOLETE district numbering, so every district label on
* the satisfaction figure named the wrong district, (ii) flagged districts 6 and
* 7 -- Krachi West and Biakoye -- as the irrigation schemes instead of 3 and 8,
* and (iii) had the b_basic block commented out, so that figure had not been
* rebuilt since Feb 2026.
*
* Input : tmp/bw_panel.dta  (built at the end of do/bw_tables_v2.do; rainfed
*                            sites only, 4,120 farmer-rounds, 8 districts)
* Output: tmp/b_basic.eps, tmp/b_satisfy.eps
*==============================================================================
set more off
global path "/Users/wkodama/Documents/research/ghana-aea-rct"
global tmp  "$path/tmp"

use "$tmp/bw_panel.dta", clear
qui count
di as txt "bi-weekly rows (rainfed sites only): " r(N)

* District names on the CURRENT AEA.dta discode, each prefixed by its arm.
* Kpong (3) and Ketu North / Weta (8) are the irrigation schemes and are already
* gone from bw_panel.dta, so they have no row here.
gen str16 district2 = ""
replace district2 = "T1: Sene"      if district==1
replace district2 = "C: Pru West"   if district==2
replace district2 = "T2: Manya"     if district==4
replace district2 = "T1: Achiase"   if district==5
replace district2 = "T2: Krachi"    if district==6
replace district2 = "C: Biakoye"    if district==7
replace district2 = "T1: Bibiani"   if district==9
replace district2 = "T2: Sefwi"     if district==10
assert district2 != ""
di as txt "district labels check (each cell must sit in one arm):"
tab district2 treat_dis

*------------------------------------------------------------------------------
* Figure 1: means by round and arm
*------------------------------------------------------------------------------
preserve
collapse (mean) Q1 Q2 Q4, by(t treat_dis)
reshape wide Q1 Q2 Q4, i(t) j(treat_dis)

twoway ///
    scatter Q11 t, mcolor(red*0.8) msymbol(o)        || ///
    scatter Q12 t, mcolor(blue*0.8) msymbol(triangle)|| ///
    scatter Q10 t, mcolor(gs7) msymbol(square)       || ///
    line    Q11 t, lcolor(red*0.8)                   || ///
    line    Q12 t, lcolor(blue*0.8)                  || ///
    line    Q10 t, lcolor(gs7)                          ///
    legend(order(1 "T1" 2 "T2" 3 "C") col(3) position(6)) ///
    xlabel(1(1)11, valuelabel angle(45) labsize(vsmall)) xtitle("") ///
    title("Number of visits")
graph save "$tmp/b_visit.gph", replace

twoway ///
    scatter Q21 t, mcolor(red*0.8) msymbol(o)        || ///
    scatter Q22 t, mcolor(blue*0.8) msymbol(triangle)|| ///
    scatter Q20 t, mcolor(gs7) msymbol(square)       || ///
    line    Q21 t, lcolor(red*0.8)                   || ///
    line    Q22 t, lcolor(blue*0.8)                  || ///
    line    Q20 t, lcolor(gs7)                          ///
    legend(order(1 "T1" 2 "T2" 3 "C") col(3) position(6)) ///
    xlabel(1(1)11, valuelabel angle(45) labsize(vsmall)) xtitle("") ///
    title("Number of contacts")
graph save "$tmp/b_contact.gph", replace

twoway ///
    scatter Q41 t, mcolor(red*0.8) msymbol(o)        || ///
    scatter Q42 t, mcolor(blue*0.8) msymbol(triangle)|| ///
    scatter Q40 t, mcolor(gs7) msymbol(square)       || ///
    line    Q41 t, lcolor(red*0.8)                   || ///
    line    Q42 t, lcolor(blue*0.8)                  || ///
    line    Q40 t, lcolor(gs7)                          ///
    legend(order(1 "T1" 2 "T2" 3 "C") col(3) position(6)) ///
    xlabel(1(1)11, valuelabel angle(45) labsize(vsmall)) xtitle("") ///
    title("Satisfaction level (1-5)")
graph save "$tmp/b_satisfy_line.gph", replace

grc1leg "$tmp/b_visit.gph" "$tmp/b_contact.gph" "$tmp/b_satisfy_line.gph", ///
    rows(1) legendfrom("$tmp/b_visit.gph") position(6)
graph display, xsize(9) ysize(3.6)
graph export "$tmp/b_basic.eps", replace as(eps)
restore

*------------------------------------------------------------------------------
* Figure 2: the satisfaction distribution by district and round
* Every other round only (04-2, 05-2, 06-2, 07-2, 08-2), as before, so the
* district-by-round grid stays readable.
*------------------------------------------------------------------------------
graph hbar (count) if inlist(t,2,4,6,8,10), ///
    over(Q4) over(t) over(district2) percent stack asyvars ///
    bar(1, color(red*0.6)) bar(2, color(red*0.3)) ///
    bar(3, color(gs7*0.5)) bar(4, color(green*0.2)) ///
    bar(5, color(green*0.8)) ///
    scale(*.5) ytitle("% Households") ///
    legend(size(2.5) rows(1) pos(6)) scheme(s1mono)
graph export "$tmp/b_satisfy.eps", replace as(eps)

di _n "=== b_basic.eps and b_satisfy.eps written (rainfed sites only) ==="
