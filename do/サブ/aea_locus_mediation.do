*==============================================================================
* aea_locus_mediation.do -- does the Panel B effect run through locus of
* control? (co-author question, Oct 2026)
*
* Panel B of manuscript Table 6 is re-estimated with the ENDLINE
* agriculture-specific locus of control added as a control. Comparing that
* "direct" coefficient with the published "total" one is the same total-versus-
* direct device the project already uses for training attendance
* (ancova_med in do/a_endline_analysis.do).
*
* Specification matches the current Table 6, i.e. WITH region fixed effects:
*   y_endline on T1, T2, stamp, y_baseline, region FE [, a_locus_spec]
* SE clustered on district, wild cluster bootstrap and randomization inference
* as elsewhere.
*
* CAVEAT. a_locus_spec is measured at endline and is itself moved by the
* treatment (Table 6 Panel A: T1 2.36, T2 3.00), so it is a bad control. The
* difference between the two coefficients is suggestive of a channel; it is not
* a causally identified mediation effect, and the randomization-inference
* p-values on the direct effect permute treatment while holding a
* post-treatment variable fixed, so read them with that in mind.
*
* This is a side analysis; nothing in the deck or the manuscript reads it.
*==============================================================================
set more off
global path "/Users/wkodama/Documents/research/ghana-aea-rct"
global tmp  "$path/tmp"

use "$tmp/a_AEA_endline_analysis.dta", clear
capture confirm numeric variable province
if _rc  encode province, gen(prov)
else    clonevar prov = province
gen t1m = (treat_dis==1)
gen t2m = (treat_dis==2)
di "AEAs = " _N

capture program drop pair
program define pair
    args y ylag
    * ---- total effect: the published Table 6 Panel B specification ----
    qui reg `y' i.treat_dis i.gps `ylag' i.prov, cluster(district)
    scalar tot1 = _b[1.treat_dis]
    scalar tot2 = _b[2.treat_dis]
    scalar se1  = _se[1.treat_dis]
    scalar se2  = _se[2.treat_dis]
    qui boottest 1.treat_dis, reps(9999) weight(webb) nograph
    scalar wb1 = r(p)
    qui boottest 2.treat_dis, reps(9999) weight(webb) nograph
    scalar wb2 = r(p)
    * ---- direct effect: locus of control (endline) added ----
    qui reg `y' i.treat_dis i.gps `ylag' a_locus_spec i.prov, cluster(district)
    scalar dir1 = _b[1.treat_dis]
    scalar dir2 = _b[2.treat_dis]
    scalar dse1 = _se[1.treat_dis]
    scalar dse2 = _se[2.treat_dis]
    scalar bmed = _b[a_locus_spec]
    scalar smed = _se[a_locus_spec]
    scalar pmed = 2*ttail(e(df_r), abs(_b[a_locus_spec]/_se[a_locus_spec]))
    qui boottest 1.treat_dis, reps(9999) weight(webb) nograph
    scalar dwb1 = r(p)
    qui boottest 2.treat_dis, reps(9999) weight(webb) nograph
    scalar dwb2 = r(p)
    di _n as txt "==== `y' ===="
    di as txt "            total            direct           indirect share"
    di as txt "  T1   " %8.3f tot1 " (" %6.3f se1 ")   " %8.3f dir1 " (" %6.3f dse1 ")   " ///
       %7.1f 100*(tot1-dir1)/tot1 "%"
    di as txt "       wild-boot " %5.3f wb1 "              " %5.3f dwb1
    di as txt "  T2   " %8.3f tot2 " (" %6.3f se2 ")   " %8.3f dir2 " (" %6.3f dse2 ")   " ///
       %7.1f 100*(tot2-dir2)/tot2 "%"
    di as txt "       wild-boot " %5.3f wb2 "              " %5.3f dwb2
    di as txt "  locus (agri, endline) coefficient " %8.4f bmed " (" %6.4f smed ")  p=" %5.3f pmed
end

pair a_knowledge    a_knowledge_bl
pair a_train        a_train_bl
pair a_avvisit      a_avvisit_bl
pair a_satisfaction a_satisfaction_bl

di _n "=== done ==="
