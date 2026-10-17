*==============================================================================
* aea_regionfe.do -- the AEA ANCOVA (manuscript Table 6) with region fixed
* effects added, at the co-authors' request (Oct 2026).
*
* The published table has no region fixed effects. Three of the four regions
* are missing at least one arm among the 41 agents:
*     Bono East     Control 4  T1 4  T2 0
*     Eastern       Control 0  T1 4  T2 2
*     Oti           Control 6  T1 0  T2 7
*     Western North Control 0  T1 8  T2 6
* so with region dummies the treatment contrast is identified off Bono East
* (Control vs T1) and Oti (Control vs T2) only. This file quantifies what that
* does; it is a diagnostic, not a proposed specification.
*
* Everything else follows do/a_endline_analysis.do.
* This is a side analysis; nothing in the deck or the manuscript reads it.
*==============================================================================
set more off
global path "/Users/wkodama/Documents/research/ghana-aea-rct"
global tmp  "$path/tmp"

use "$tmp/a_AEA_endline_analysis.dta", clear
capture confirm numeric variable province
if _rc {
    encode province, gen(prov)
}
else {
    clonevar prov = province
}
di "AEAs = " _N
tab prov treat_dis

capture program drop ancfe
program define ancfe
    args y ylag
    qui sum `y' if treat_dis==0
    scalar cm = r(mean)
    qui reg `y' i.treat_dis i.gps `ylag' i.prov, cluster(district)
    qui boottest 1.treat_dis, reps(9999) weight(webb) nograph
    scalar wbt1 = r(p)
    qui boottest 2.treat_dis, reps(9999) weight(webb) nograph
    scalar wbt2 = r(p)
    set seed 12345
    capture noisily {
        qui randcmd ((t1m t2m) reg `y' t1m t2m gps `ylag' i.prov, cluster(district)), ///
            reps(1000) treatvars(t1m t2m)
        matrix ripv = e(RCoef)
        scalar rit1 = ripv[1,6]
        scalar rit2 = ripv[2,6]
    }
    if _rc {
        scalar rit1 = .
        scalar rit2 = .
    }
    eststo `y': reg `y' i.treat_dis i.gps `ylag' i.prov, cluster(district)
    estadd scalar cmean = cm
    estadd scalar wb_t1 = wbt1
    estadd scalar wb_t2 = wbt2
    estadd scalar ri_t1 = rit1
    estadd scalar ri_t2 = rit2
end

capture gen t1m = (treat_dis==1)
capture gen t2m = (treat_dis==2)

eststo clear
ancfe a_intrinsic   a_intrinsic_bl
ancfe a_extrinsic2  a_extrinsic2_bl
ancfe a_prosocial   a_prosocial_bl
ancfe a_locus_gen   a_locus_gen_bl
ancfe a_locus_spec  a_locus_spec_bl
esttab a_intrinsic a_extrinsic2 a_prosocial a_locus_gen a_locus_spec, ///
    se b(%9.3f) keep(1.treat_dis 2.treat_dis 1.gps) ///
    stats(cmean wb_t1 wb_t2 ri_t1 ri_t2 N, fmt(%9.3f %9.3f %9.3f %9.3f %9.3f %9.0g)) ///
    mtitles("Intrinsic" "Extrinsic" "Prosocial" "Locus gen" "Locus agri") ///
    title("PANEL A WITH REGION FE")

eststo clear
ancfe a_knowledge    a_knowledge_bl
ancfe a_knowledge8   a_knowledge8_bl
ancfe a_train        a_train_bl
ancfe a_avvisit      a_avvisit_bl
ancfe a_satisfaction a_satisfaction_bl
esttab a_knowledge a_knowledge8 a_train a_avvisit a_satisfaction, ///
    se b(%9.3f) keep(1.treat_dis 2.treat_dis 1.gps) ///
    stats(cmean wb_t1 wb_t2 ri_t1 ri_t2 N, fmt(%9.3f %9.3f %9.3f %9.3f %9.3f %9.0g)) ///
    mtitles("Know 0-5" "Know 0-8" "Training" "Self-rep visits" "Job satisf") ///
    title("PANEL B WITH REGION FE")

di _n "=== done ==="
