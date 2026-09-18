*==============================================================================
* ae_dist_figs.do -- baseline-vs-endline comparison of AEA answer distributions
*
*   tmp/prosocial_be.pdf  prosocialness items, panel E      (deck p. 44)
*   tmp/locus1_be.pdf     locus of control, items A-E       (deck p. 45)
*   tmp/locus2_be.pdf     locus of control, items F-J       (deck p. 46)
*
* SAMPLE = RAINFED SITES ONLY, as in every estimation: the two irrigation-scheme
* districts (3 Kpong, 8 Ketu North / Weta) are dropped from both waves. That is
* 44 -> 42 AEAs at baseline and 43 -> 41 at endline.
*
* The endline wave is read from tmp/a_AEA_endline_analysis.dta rather than the
* raw questionnaire file: that is the file every AEA table uses, it is already
* restricted to the rainfed sites, and it is built from the REVISED endline data
* (Jul 2026). The old version of this do-file read Endline/AEA endline.dta
* directly and therefore predated the revision.
*
* Input : tmp/AEA_base_tmp.dta (a_baseline.do)
*         tmp/a_AEA_endline_analysis.dta (a_endline_analysis.do)
*==============================================================================
set more off
global path "/Users/wkodama/research/ghana-aea-rct"
global tmp  "$path/tmp"

local items panelE_A panelE_B panelE_C panelE_D panelE_E panelE_F ///
            panelG_A panelG_B panelG_C panelG_D panelG_E ///
            panelG_F panelG_G panelG_H panelG_I panelG_J

* ---- baseline wave, rainfed sites only ----
use "$tmp/AEA_base_tmp.dta", clear
drop if district==3 | district==8
keep `items'
gen wave = 0
qui count
di as txt "baseline AEAs (rainfed): " r(N)
tempfile base
save `base'

* ---- endline wave: already rainfed-only, already on the revised data ----
use "$tmp/a_AEA_endline_analysis.dta", clear
keep `items'
gen wave = 1
qui count
di as txt "endline AEAs (rainfed): " r(N)

append using `base'
label define wavelbl 0 "Baseline" 1 "Endline"
label values wave wavelbl

tempfile stacked
save `stacked'

* ---- one grouped-bar panel per item: within-wave percent by answer ----
foreach v of local items {
    use `stacked', clear
    local ttl : variable label `v'
    keep wave `v'
    drop if `v'==.
    * within-wave percentages
    bysort wave: gen double Nw = _N
    gen double pct = 100/Nw
    collapse (sum) pct, by(wave `v')
    graph hbar (sum) pct, over(wave, gap(0)) over(`v', label(labsize(vsmall))) asyvars ///
        bar(1, color("230 120 0")) bar(2, color("0 130 60")) ///
        title("`ttl'", size(.2cm)) ytitle("") ///
        legend(order(1 "Baseline" 2 "Endline") rows(1) size(vsmall) symxsize(3))
    graph save "$tmp/be_`v'.gph", replace
}

* ---- combine into the three slide figures ----
graph combine "$tmp/be_panelE_A.gph" "$tmp/be_panelE_B.gph" "$tmp/be_panelE_C.gph" ///
              "$tmp/be_panelE_D.gph" "$tmp/be_panelE_E.gph" "$tmp/be_panelE_F.gph", ///
              xcommon ycommon
graph export "$tmp/prosocial_be.pdf", replace
graph export "$tmp/prosocial_be.eps", replace as(eps)

graph combine "$tmp/be_panelG_A.gph" "$tmp/be_panelG_B.gph" "$tmp/be_panelG_C.gph" ///
              "$tmp/be_panelG_D.gph" "$tmp/be_panelG_E.gph", ///
              xcommon
graph export "$tmp/locus1_be.pdf", replace
graph export "$tmp/locus1_be.eps", replace as(eps)

graph combine "$tmp/be_panelG_F.gph" "$tmp/be_panelG_G.gph" "$tmp/be_panelG_H.gph" ///
              "$tmp/be_panelG_I.gph" "$tmp/be_panelG_J.gph", ///
              xcommon
graph export "$tmp/locus2_be.pdf", replace
graph export "$tmp/locus2_be.eps", replace as(eps)
