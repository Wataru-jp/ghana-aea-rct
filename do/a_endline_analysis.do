*==============================================================================
* AEA endline treatment effects (ANCOVA), N=43, with robustness suite.
*Inference: (i) cluster-robust SE [reported], (ii) wild cluster bootstrap (Webb,
*9999 reps), (iii) randomization inference (randcmd, 1000 reps). 
* Requires: tmp/a_AEA_endline.dta (a_endline.do), tmp/AEA_base_tmp.dta (a_baseline.do).
*==============================================================================
global path "C:/Users/kaz-takahashi/Dropbox/Ghana/Data/"
global path "/Users/wkodama/Documents/research/ghana-aea-rct/"
global dta  "$path/Baseline"
global tmp  "$path/tmp"
global controls_extra ""             // treat/gps/lag for AEA (see sample note below)

*--- baseline scales -> *_bl (keyed on aeaID)
use "$tmp/AEA_base_tmp.dta", clear
gen a_prosocial  = a_proaction + a_profeeling
keep aid a_prosocial a_intrinsic a_extrinsic1 a_extrinsic2 a_locus_gen a_locus_spec ///
     a_knowledge a_seedcount a_knowledge8 a_avvisit a_satisfaction a_train a_train_jica
rename aid aeaID
rename a_prosocial   a_prosocial_bl
rename a_intrinsic   a_intrinsic_bl
rename a_extrinsic1  a_extrinsic1_bl
rename a_extrinsic2  a_extrinsic2_bl
rename a_locus_gen   a_locus_gen_bl
rename a_locus_spec  a_locus_spec_bl
rename a_knowledge   a_knowledge_bl
rename a_seedcount   a_seedcount_bl
rename a_knowledge8  a_knowledge8_bl
rename a_avvisit     a_avvisit_bl
rename a_satisfaction a_satisfaction_bl
rename a_train       a_train_bl
rename a_train_jica  a_train_jica_bl
save "$tmp/a_AEA_base_lags.dta", replace

*--- endline + baseline lags
use "$tmp/a_AEA_endline.dta", clear
merge 1:1 aeaID using "$tmp/a_AEA_base_lags.dta"
drop if _merge==2
drop _merge
label define trtlbl 0 "Control" 1 "T1 (Feedback)" 2 "T2 (Feedback+Training)"
label values treat_dis trtlbl

* the FULL 43-AEA file is kept for the district sample-size table only
save "$tmp/a_AEA_endline_full.dta", replace

* SAMPLE = RAINFED SITES ONLY (co-author decision, Sep 2026), matching the farmer
* analysis. The two irrigation-scheme districts hold 2 AEAs, both in the control
* arm, so this drops 43 -> 41 AEAs and 10 -> 8 districts.
drop if irrgsch==1
qui count
di as txt "AEA analysis sample after dropping the irrigation schemes: " r(N)

save "$tmp/a_AEA_endline_analysis.dta", replace

*------------------------------------------------------------------------------
* Program: ANCOVA + cluster-robust + wild bootstrap + randomization inference
*------------------------------------------------------------------------------
capture program drop ancova
program define ancova
    args y ylag
    qui sum `ylag' if treat_dis==0
    scalar bm = r(mean)                 // control-group BASELINE mean
    qui sum `y' if treat_dis==0
    scalar cm = r(mean)                 // control-group ENDLINE mean
    qui reg `y' i.treat_dis i.gps $controls_extra `ylag', cluster(district)
    * wild cluster bootstrap (Webb weights)
    qui boottest 1.treat_dis, reps(9999) weight(webb) nograph
    scalar wbt1 = r(p)
    qui boottest 2.treat_dis, reps(9999) weight(webb) nograph
    scalar wbt2 = r(p)
    * randomization inference
    qui gen t1m = (treat_dis==1)
    qui gen t2m = (treat_dis==2)
    set seed 12345
    qui randcmd ((t1m t2m) reg `y' t1m t2m gps $controls_extra `ylag', cluster(district)), ///
        reps(1000) treatvars(t1m t2m)
    matrix ripv = e(RCoef)
    scalar rit1 = ripv[1,6]
    scalar rit2 = ripv[2,6]
    drop t1m t2m
    * re-store clean reg with all added statistics
    eststo `y': reg `y' i.treat_dis i.gps $controls_extra `ylag', cluster(district)
    qui test 1.treat_dis = 2.treat_dis
    estadd scalar t12p = r(p)
    estadd scalar bmean = bm
    estadd scalar cmean = cm
    estadd scalar wb_t1 = wbt1
    estadd scalar wb_t2 = wbt2
    estadd scalar ri_t1 = rit1
    estadd scalar ri_t2 = rit2
end


*------------------------------------------------------------------------------
* Table 1: motivation & locus of control (the intervention mechanism)
*------------------------------------------------------------------------------
eststo clear
ancova a_intrinsic   a_intrinsic_bl
ancova a_extrinsic2  a_extrinsic2_bl
ancova a_prosocial   a_prosocial_bl
ancova a_locus_gen   a_locus_gen_bl
ancova a_locus_spec  a_locus_spec_bl
esttab a_intrinsic a_extrinsic2 a_prosocial a_locus_gen a_locus_spec ///
    using "$tmp/e_aea_attitude.tex", replace ///
    se nogap b(%9.3f) label booktabs nonotes ///
    keep(1.treat_dis 2.treat_dis 1.gps) ///
    coeflabels(1.treat_dis "T1: Feedback" 2.treat_dis "T2: Feedback+Training" 1.gps "Stamp (GPS)") ///
    stats(t12p bmean cmean wb_t1 wb_t2 ri_t1 ri_t2 N, fmt(%9.3f %9.3f %9.3f %9.3f %9.3f %9.3f %9.3f %9.0g) ///
          labels("T1=T2 [p]" "Ctrl mean (base)" "Ctrl mean (end)" "Wild-boot p (T1)" "Wild-boot p (T2)" "RI p (T1)" "RI p (T2)" "Obs")) ///
    mtitles("Intrinsic" "Extrinsic" "Prosocial" "Locus: gen" "Locus: agri") ///
    star(* 0.10 ** 0.05 *** 0.01)

*------------------------------------------------------------------------------
* Table 2: knowledge, self-reported effort, job satisfaction
*------------------------------------------------------------------------------
*
* Column (4) is the MEDIATION column asked for by the co-authors (Sep 2026):
* the same ANCOVA as column (1) but with the training-attendance dummy added, so
* the arm coefficient is the DIRECT effect of the arm on knowledge, net of the
* route that runs through attending a rice agronomic training. The indirect
* share reported in the slide note is (total - direct)/total. The mediator is
* attendance at ANY such training (a_train), not only JICA-provided courses
* (a_train_jica): the co-authors asked for the broader measure, whose first
* stage for T2 is the stronger of the two.
* CAVEAT: a_train is measured AFTER treatment, so it is a "bad control".
* The split is descriptive, not a causal mediation estimate.
*
capture program drop ancova_med
program define ancova_med
    args y ylag
    qui sum `ylag' if treat_dis==0
    scalar bm = r(mean)
    qui sum `y' if treat_dis==0
    scalar cm = r(mean)
    qui reg `y' i.treat_dis i.gps $controls_extra `ylag' a_train, cluster(district)
    qui boottest 1.treat_dis, reps(9999) weight(webb) nograph
    scalar wbt1 = r(p)
    qui boottest 2.treat_dis, reps(9999) weight(webb) nograph
    scalar wbt2 = r(p)
    qui gen t1m = (treat_dis==1)
    qui gen t2m = (treat_dis==2)
    set seed 12345
    qui randcmd ((t1m t2m) reg `y' t1m t2m gps $controls_extra `ylag' a_train, cluster(district)), ///
        reps(1000) treatvars(t1m t2m)
    matrix ripv = e(RCoef)
    scalar rit1 = ripv[1,6]
    scalar rit2 = ripv[2,6]
    drop t1m t2m
    eststo med_`y': reg `y' i.treat_dis i.gps $controls_extra `ylag' a_train, cluster(district)
    qui test 1.treat_dis = 2.treat_dis
    estadd scalar t12p = r(p)
    estadd scalar bmean = bm
    estadd scalar cmean = cm
    estadd scalar wb_t1 = wbt1
    estadd scalar wb_t2 = wbt2
    estadd scalar ri_t1 = rit1
    estadd scalar ri_t2 = rit2
end

label var a_train "Attended training (=1)"

eststo clear
ancova     a_knowledge     a_knowledge_bl
ancova     a_knowledge8    a_knowledge8_bl
ancova     a_train         a_train_bl
ancova_med a_knowledge     a_knowledge_bl
ancova     a_avvisit       a_avvisit_bl
ancova     a_satisfaction  a_satisfaction_bl
esttab a_knowledge a_knowledge8 a_train med_a_knowledge a_avvisit a_satisfaction ///
    using "$tmp/e_aea_effort.tex", replace ///
    se nogap b(%9.3f) label booktabs nonotes ///
    keep(1.treat_dis 2.treat_dis a_train 1.gps) ///
    order(1.treat_dis 2.treat_dis a_train 1.gps) ///
    coeflabels(1.treat_dis "T1: Feedback" 2.treat_dis "T2: Feedback+Training" a_train "Attended training (=1)" 1.gps "Stamp (GPS)") ///
    stats(t12p bmean cmean wb_t1 wb_t2 ri_t1 ri_t2 N, fmt(%9.3f %9.3f %9.3f %9.3f %9.3f %9.3f %9.3f %9.0g) ///
          labels("T1=T2 [p]" "Ctrl mean (base)" "Ctrl mean (end)" "Wild-boot p (T1)" "Wild-boot p (T2)" "RI p (T1)" "RI p (T2)" "Obs")) ///
    mtitles("Knowledge (0--5)" "Knowledge (0--8)" "Training attend." "Knowl. (0--5) direct" "Self-rep. visits" "Job satisf.") ///
    star(* 0.10 ** 0.05 *** 0.01)

* The manuscript prints this table without the mediation column. That column
* conditions on training attendance, which is itself an outcome of the
* treatment, and once it is gone no column carries a_train as a regressor, so
* esttab drops the "Attended training" row with it. The deck keeps the full
* version in e_aea_effort.tex.
esttab a_knowledge a_knowledge8 a_train a_avvisit a_satisfaction ///
    using "$tmp/e_aea_effort_ms.tex", replace ///
    se nogap b(%9.3f) label booktabs nonotes ///
    keep(1.treat_dis 2.treat_dis 1.gps) ///
    order(1.treat_dis 2.treat_dis 1.gps) ///
    coeflabels(1.treat_dis "T1: Feedback" 2.treat_dis "T2: Feedback+Training" 1.gps "Stamp (GPS)") ///
    stats(t12p bmean cmean wb_t1 wb_t2 ri_t1 ri_t2 N, fmt(%9.3f %9.3f %9.3f %9.3f %9.3f %9.3f %9.3f %9.0g) ///
          labels("T1=T2 [p]" "Ctrl mean (base)" "Ctrl mean (end)" "Wild-boot p (T1)" "Wild-boot p (T2)" "RI p (T1)" "RI p (T2)" "Obs")) ///
    mtitles("Knowledge (0--5)" "Knowledge (0--8)" "Training attend." "Self-rep. visits" "Job satisf.") ///
    star(* 0.10 ** 0.05 *** 0.01)

* indirect share of the knowledge effect that runs through training attendance
qui reg a_knowledge i.treat_dis i.gps $controls_extra a_knowledge_bl, cluster(district)
matrix TOT = r(table)
scalar tot1 = TOT[1,colnumb(TOT,"1.treat_dis")]
scalar tot2 = TOT[1,colnumb(TOT,"2.treat_dis")]
qui reg a_knowledge i.treat_dis i.gps $controls_extra a_knowledge_bl a_train, cluster(district)
matrix DIR = r(table)
scalar dir1 = DIR[1,colnumb(DIR,"1.treat_dis")]
scalar dir2 = DIR[1,colnumb(DIR,"2.treat_dis")]
di _n "===== Knowledge (0-5): training-attendance mediation ====="
di as txt "  total  T1 " %7.3f tot1 "   T2 " %7.3f tot2
di as txt "  direct T1 " %7.3f dir1 "   T2 " %7.3f dir2
di as txt "  indirect share T1 " %6.1f 100*(tot1-dir1)/tot1 "%   T2 " %6.1f 100*(tot2-dir2)/tot2 "%"

di _n "=== AEA ANCOVA done (see e_aea_attitude.tex, e_aea_effort.tex) ==="

*==============================================================================
* APPENDIX (co-author request, Jul 2026): FB/TR reparameterization.
* FB = 1{T1 or T2}, TR = 1{T2}: coef(FB) = feedback effect (T1 vs C),
* coef(TR) = incremental training effect (T2 - T1). Same fit as main ANCOVA.
*==============================================================================
use "$tmp/a_AEA_endline_analysis.dta", clear
gen fb = (treat_dis==1 | treat_dis==2)
gen tr = (treat_dis==2)

capture program drop ancova_fbtr
program define ancova_fbtr
    args y ylag
    qui sum `ylag' if treat_dis==0
    scalar bm = r(mean)
    qui sum `y' if treat_dis==0
    scalar cm = r(mean)
    qui reg `y' fb tr i.gps $controls_extra `ylag', cluster(district)
    qui boottest fb, reps(9999) weight(webb) nograph
    scalar wbf = r(p)
    qui boottest tr, reps(9999) weight(webb) nograph
    scalar wbt = r(p)
    set seed 12345
    qui randcmd ((fb tr) reg `y' fb tr gps $controls_extra `ylag', cluster(district)), ///
        reps(1000) treatvars(fb tr)
    matrix ripv = e(RCoef)
    scalar rifb = ripv[1,6]
    scalar ritr = ripv[2,6]
    eststo `y': reg `y' fb tr i.gps $controls_extra `ylag', cluster(district)
    estadd scalar bmean = bm
    estadd scalar cmean = cm
    estadd scalar wb_fb = wbf
    estadd scalar wb_tr = wbt
    estadd scalar ri_fb = rifb
    estadd scalar ri_tr = ritr
end

eststo clear
ancova_fbtr a_intrinsic   a_intrinsic_bl
ancova_fbtr a_extrinsic2  a_extrinsic2_bl
ancova_fbtr a_prosocial   a_prosocial_bl
ancova_fbtr a_locus_gen   a_locus_gen_bl
ancova_fbtr a_locus_spec  a_locus_spec_bl
esttab a_intrinsic a_extrinsic2 a_prosocial a_locus_gen a_locus_spec ///
    using "$tmp/e_aea_att_fbtr.tex", replace ///
    se nogap b(%9.3f) label booktabs nonotes ///
    keep(fb tr 1.gps) coeflabels(fb "FB: Feedback (T1 or T2)" tr "TR: Training increment (T2 vs T1)" 1.gps "Stamp (GPS)") ///
    stats(bmean cmean wb_fb wb_tr ri_fb ri_tr N, fmt(%9.3f %9.3f %9.3f %9.3f %9.3f %9.3f %9.0g) ///
          labels("Ctrl mean (base)" "Ctrl mean (end)" "Wild-boot p (FB)" "Wild-boot p (TR)" "RI p (FB)" "RI p (TR)" "Obs")) ///
    mtitles("Intrinsic" "Extrinsic" "Prosocial" "Locus: gen" "Locus: agri") ///
    star(* 0.10 ** 0.05 *** 0.01)

eststo clear
ancova_fbtr a_knowledge    a_knowledge_bl
ancova_fbtr a_avvisit      a_avvisit_bl
ancova_fbtr a_satisfaction a_satisfaction_bl
esttab a_knowledge a_avvisit a_satisfaction using "$tmp/e_aea_eff_fbtr.tex", replace ///
    se nogap b(%9.3f) label booktabs nonotes ///
    keep(fb tr 1.gps) coeflabels(fb "FB: Feedback (T1 or T2)" tr "TR: Training increment (T2 vs T1)" 1.gps "Stamp (GPS)") ///
    stats(bmean cmean wb_fb wb_tr ri_fb ri_tr N, fmt(%9.3f %9.3f %9.3f %9.3f %9.3f %9.3f %9.0g) ///
          labels("Ctrl mean (base)" "Ctrl mean (end)" "Wild-boot p (FB)" "Wild-boot p (TR)" "RI p (FB)" "RI p (TR)" "Obs")) ///
    mtitles("Knowledge" "Self-rep. visits" "Job satisf.") ///
    star(* 0.10 ** 0.05 *** 0.01)
