*==============================================================================
* Farmer endline treatment effects (ANCOVA).
* Main outcomes: yield, income (revenue), profit, input use, practice adoption.
* Requires: tmp/farmer_e.dta (from f_endline.do), tmp/farmer.dta (from f_baseline.do).
* Robustness: wild bootstrap, RI, sampling weights.
*==============================================================================
global path "C:/Users/kaz-takahashi/Dropbox/Ghana/Data/"
global path "/Users/wkodama/research/ghana-aea-rct/"
global dta  "$path/Baseline"
global tmp  "$path/tmp"

*------------------------------------------------------------------------------
* Program: construct farmer outcomes (identical formulas for baseline & endline)
* Mirrors do/f_analysis.do (with fixes: fert missing->0; correct per-ha income).
*------------------------------------------------------------------------------
capture program drop mkout
program define mkout
    global convert 0.4047
    * costs: treat "no expense" (missing) as zero
    foreach var in c_seed c_tractor c_combine c_thresh c_other c_cfert c_herbinsec c_hire {
        capture confirm variable `var'
        if !_rc replace `var' = 0 if `var'==.
    }
    replace fert = 0 if fert==.

    * crop failure = realized ZERO output (kept in sample, not dropped): a farmer
    * who harvested nothing still incurred input costs, so net income = -costs.
    replace v_totalprod = 0 if nonprod==1
    * where a district has no observed paddy price (baseline Achiase & Kpong:
    * nobody sold), value output at the wave-median price instead of missing
    qui sum md_paddyprice_kg, detail
    replace v_totalprod = totalprod_kg*r(p50) if v_totalprod==. & totalprod_kg<.

    gen landsize2 = landsize*$convert                 // acres -> hectares
    * net rice income = value of production - all measured cash costs (incl. hired
    * labor) - what tenants pay for the land (share of output, cash or in-kind rent).
    * Land payments were NOT deducted before Aug 2026; they are a paid-out cost like
    * any other, so income and profit were gross of them for the ~1/3 of the sample
    * that rents. Built in f_baseline.do / f_endline.do.
    capture confirm variable landpay
    if _rc gen landpay = 0
    replace landpay = 0 if landpay==.
    gen rincome = v_totalprod - landpay - c_seed - c_tractor - c_combine - c_thresh ///
                  - c_other - c_cfert - c_herbinsec - c_hire
    * yield (t/ha); crop failure -> 0
    gen yield   = totalprod_kg/1000/landsize2
    replace yield = 0 if nonprod==1
    * revenue = value of product (co-author terminology, Jul 2026):
    *   revenue - paid-out cost = income;  income - imputed own resources = profit
    gen rev_ha  = v_totalprod/landsize2

    foreach var in rincome fert c_seed c_cfert c_herbinsec c_hire squant {
        gen `var'_ha = `var'/landsize2
    }
    * input-use indicators
    gen u_fert    = (fert>0) if fert<.
    gen fert_ha2  = fert_ha
    replace fert_ha2 = . if fert_ha==0
    gen u_her     = (c_herbinsec>0)
    gen u_tractor = (c_tractor>0)
    capture replace u_tractor = 1 if hand==1
    capture replace u_tractor = 1 if fourwheel==1
    gen u_combine = (c_combine>0)
    gen u_thresh  = (c_thresh>0)
    gen u_other   = (c_other>0)
    gen u_machine = (u_tractor==1 | u_thresh==1 | u_combine==1 | u_other==1)
    * seed & agronomic practice adoption
    gen u_seedtreat = (t_seedtreat==1 | t_seedtreat==2)
    gen u_simproved = (stype==1 | stype==2)
    * any improved variety (original endline coding, PI decision Jul 2026;
    * code 7 = Amankwatia does not occur in the original endline file)
    gen u_impany    = (inrange(stype,1,5) | stype==7) if stype<.
    gen u_saroma    = (stype==3 | stype==4 | stype==5)
    gen u_stogo     = (stype==8)
    gen u_scertify  = (scertify==1)
    gen u_direct    = (t_seedling==1)
    gen u_dib       = (t_seedling==2)
    gen u_rtrans    = (t_seedling==3)
    gen u_ptrans    = (t_seedling==4)
    gen u_bunds     = (t_bunds==1)
    gen u_level     = (t_levelling==1)
    * count of adopted practices (0-7; missing components counted as 0)
    egen nprac = rowtotal(u_impany u_scertify u_seedtreat u_dib u_ptrans u_bunds u_level)

    * no winsorization (PI decision Jul 2026): outcomes enter raw
    * log using log(1+x) so zero-output (crop failure) households are retained
    gen lnyield = ln(1+yield)
    * income can be negative (failure => -costs): use inverse hyperbolic sine,
    * which behaves like log for large values but is defined for x<=0
    gen lnrincome = asinh(rincome_ha)
end

* Outcome list carried from baseline (for the ANCOVA lag terms).
*------------------------------------------------------------------------------
* 1. Baseline outcomes -> tmp/farmer_bl_out.dta (keyed on hhID, *_bl suffix)
*------------------------------------------------------------------------------
use "$tmp/farmer.dta", clear
mkout
keep hhID yield lnyield rev_ha rincome_ha lnrincome squant_ha u_fert fert_ha u_her u_machine u_tractor u_combine u_thresh u_other nonprod u_simproved u_impany u_scertify u_seedtreat u_dib u_ptrans u_bunds u_level nprac y_w_growth y_w_repod y_w_mature y_drying y_harvest y_moisture y_thresh

rename yield yield_bl
rename lnyield lnyield_bl
rename rev_ha rev_ha_bl
rename rincome_ha rincome_ha_bl
rename lnrincome lnrincome_bl
rename squant_ha squant_ha_bl
rename u_fert u_fert_bl
rename fert_ha fert_ha_bl
rename u_her u_her_bl
rename u_machine u_machine_bl
rename u_tractor u_tractor_bl
rename u_combine u_combine_bl
rename u_thresh u_thresh_bl
rename u_other u_other_bl
rename nonprod nonprod_bl
rename u_simproved u_simproved_bl
rename u_impany u_impany_bl
rename u_scertify u_scertify_bl
rename u_seedtreat u_seedtreat_bl
rename u_dib u_dib_bl
rename u_ptrans u_ptrans_bl
rename u_bunds u_bunds_bl
rename u_level u_level_bl
rename nprac nprac_bl
rename y_w_growth y_w_growth_bl
rename y_w_repod y_w_repod_bl
rename y_w_mature y_w_mature_bl
rename y_drying y_drying_bl
rename y_harvest y_harvest_bl
rename y_moisture y_moisture_bl
rename y_thresh y_thresh_bl

save "$tmp/farmer_bl_out.dta", replace

*------------------------------------------------------------------------------
* 2. AEA name-signature program (for the gps merge in step 3)
*    The endline Cover's numeric aeaID was RE-NUMBERED by the endline CAPI for
*    10 AEAs and does not match the randomization aid (linkage audit, Jul 2026),
*    so the farmer's AEA is resolved by NAME via tmp/aea_name_xwalk.dta
*    (built in do/a_endline.do -- run that first).
*------------------------------------------------------------------------------
capture program drop mksig
program define mksig
    args namevar sigvar
    tempvar w
    gen `w' = trim(itrim(ustrregexra(upper(`namevar'), "[^A-Z ]", " ")))
    forvalues k=1/6 {
        gen __tk`k' = word(`w', `k')
    }
    forvalues p=1/5 {
        forvalues j=1/5 {
            local jn = `j'+1
            gen __a = __tk`j'
            gen __b = __tk`jn'
            replace __tk`j'  = cond(__b!="" & (__b<__a | __a==""), __b, __a)
            replace __tk`jn' = cond(__b!="" & (__b<__a | __a==""), __a, __b)
            drop __a __b
        }
    }
    gen `sigvar' = __tk1+__tk2+__tk3+__tk4+__tk5+__tk6
    drop __tk*
end

*------------------------------------------------------------------------------
* 3. Endline analysis file
*------------------------------------------------------------------------------
use "$tmp/farmer_e.dta", clear
mkout

* baseline outcome lags (panel merge on hhID)
merge 1:1 hhID using "$tmp/farmer_bl_out.dta"
drop if _merge==2                 // baseline-only (attrited from endline)
gen panel = (_merge==3)           // 1 = matched panel hh, 0 = endline-only
drop _merge

* stamp (gps) treatment: resolve the farmer's AEA by NAME (see step 2 header)
decode aea_name, gen(__aname)
mksig __aname sig
merge m:1 sig using "$tmp/aea_name_xwalk.dta", keep(1 3) keepusing(aid_true gps treat_aea)
qui count if _merge!=3
di as txt "farmers with unresolved AEA name (must be 0): " r(N)
assert _merge==3
drop _merge
* integrity: the assigned AEA's arm must equal the district-based arm (audit: holds for all)
assert treat_aea == treat_dis
replace aid = aid_true          // overwrite the Cover's re-numbered code with the true aid
drop __aname sig treat_aea aid_true

* sampling weight = inverse selection prob = pop / sampled  (population-representative)
rename community communityid
* Kpong Irrigation Scheme: the frame lists only Asutsuare -- per the survey firm
* (Jul 2026) all scheme farms are at Asutsuare; the one farmer residing in
* Volivo (communityid 76) therefore takes the Asutsuare weight.
qui levelsof communityid if district==3 & communityid!=76, local(__asu)
replace communityid = `: word 1 of `__asu'' if communityid==76
merge m:1 communityid using "$dta/Population.dta", keepusing(ricefarmerpopulation baselinesamplesize)
drop if _merge==2
drop _merge
gen sw = ricefarmerpopulation/baselinesamplesize

* strata (province/region) FE  (region is a labelled numeric)
gen prov = region

* labels for table rows
label define trtlbl 0 "Control" 1 "T1 (Feedback)" 2 "T2 (Feedback+Training)"
label values treat_dis trtlbl
label var yield          "Yield (t/ha)"
label var lnyield        "Log(1+yield)"
label var rev_ha         "Revenue (GHS/ha)"
label var rincome_ha     "Income (GHS/ha)"
label var lnrincome      "Log income (IHS)"
label var squant_ha      "Seed quantity (kg/ha)"
label var u_fert         "Fertilizer use (=1)"
label var fert_ha        "Fertilizer qty (kg/ha)"
label var u_her          "Herb/Insecticide use (=1)"
label var u_machine      "Machine use (=1)"
label var u_tractor      "\quad Tractor / power tiller (=1)"
label var u_combine      "\quad Combine harvester (=1)"
label var u_thresh       "\quad Thresher (=1)"
label var u_other        "\quad Other machinery (=1)"
label var nonprod        "Crop failure (=1)"
label var u_simproved    "CSIR-AGRA/Exbaika (=1)"
label var u_impany       "Any improved variety (=1)"
label var nprac          "No. of practices adopted (0-7)"
label var u_scertify     "Certified seed (=1)"
label var u_seedtreat    "Seed treatment (=1)"
label var u_dib          "Dibbling (=1)"
label var u_ptrans       "Transplant in row (=1)"
label var u_bunds        "Bunds construction (=1)"
label var u_level        "Levelling (=1)"

*------------------------------------------------------------------------------
* SAMPLE = RAINFED SITES ONLY (co-author decision, Sep 2026).
* The two irrigation schemes (Kpong & Weta) are 12 households, ALL of them in the
* control arm, and they are not comparable to the rainfed sites: yields, seed
* rates and labour are on a different scale. Controlling with an `irrgsch` dummy
* shifts the level but still lets them pull the other coefficients and, above
* all, the reported control means. They are dropped HERE, before the analysis
* file is saved, so that every table, figure and panel built downstream rests on
* the same 382 households. The dummy is removed from every specification.
* Estimates barely move; the only change is T1 profit going from 5% to 10%.
* NOTE: this leaves 8 districts (2 control, 3 T1, 3 T2) -- see the deck note on
* few-cluster inference.
*------------------------------------------------------------------------------
drop if irrgsch==1
qui count
di as txt "analysis sample after dropping the irrigation schemes: " r(N)

save "$tmp/farmer_e_analysis.dta", replace

*------------------------------------------------------------------------------
* 3b. Family- and hired-labor variables (built here so the MAIN and WEIGHTED
*     tables can include full-cost income and the labor-use outcomes).
*     Wage (revised Jul 2026, co-author spec): district MEDIAN of
*     (cash + in-kind payment) / hired man-days, with genders pooled and a
*     missing gender field treated as zero hiring, household-task rows trimmed
*     to [1,500] GHS/day. A district with no wage observation gets the wave's
*     pooled median (currently none binds: Kpong has own rows under this
*     definition). famdays = workers x days x hours/8 (male + female).
*     Hired man-days aggregated per household from the same module.
*------------------------------------------------------------------------------
preserve
use "$path/Endline/Revised data/QY1-5wet (Labor inputs-paddy)_rev2026Aug.dta", clear
gen md_m = QY15_4*QY15_5
gen md_f = QY15_7*QY15_8
replace md_m = 0 if md_m==.
replace md_f = 0 if md_f==.
gen md  = md_m + md_f
gen pay = cond(QY15_10==. | QY15_10<0, 0, QY15_10) + cond(QY15_16==. | QY15_16<0, 0, QY15_16)
gen w   = pay/md if md>0 & pay>0
tempfile __labe
save `__labe'
collapse (sum) hdays=md, by(hhID)
save "$tmp/hlab_e.dta", replace
use `__labe', clear
keep if inrange(w,1,500)
merge m:1 hhID using "$path/Endline/Cover.dta", keepusing(district) keep(3) nogen
qui sum w, detail
scalar __pmed_e = r(p50)
collapse (median) dw=w, by(district)
save "$tmp/dwage_e.dta", replace
use "$path/Baseline/QY1-5wet (Labor inputs-paddy)_V5.dta", clear
gen md_m = QY15_4*QY15_5
gen md_f = QY15_7*QY15_8
replace md_m = 0 if md_m==.
replace md_f = 0 if md_f==.
gen md  = md_m + md_f
gen pay = cond(QY15_10==. | QY15_10<0, 0, QY15_10) + cond(QY15_16==. | QY15_16<0, 0, QY15_16)
gen w   = pay/md if md>0 & pay>0
tempfile __labb
save `__labb'
collapse (sum) hdays=md, by(hhID)
save "$tmp/hlab_b.dta", replace
use `__labb', clear
keep if inrange(w,1,500)
merge m:1 hhID using "$path/Baseline/Cover_v2.dta", keepusing(district) keep(3) nogen
qui sum w, detail
scalar __pmed_b = r(p50)
collapse (median) dw=w, by(district)
save "$tmp/dwage_b.dta", replace
use "$tmp/farmer.dta", clear
foreach var in c_seed c_tractor c_combine c_thresh c_other c_cfert c_herbinsec c_hire {
    capture confirm variable `var'
    if !_rc replace `var' = 0 if `var'==.
}
replace v_totalprod = 0 if nonprod==1
qui sum md_paddyprice_kg, detail
replace v_totalprod = totalprod_kg*r(p50) if v_totalprod==. & totalprod_kg<.
gen landsize2 = landsize*0.4047
capture confirm variable landpay
if _rc gen landpay = 0
replace landpay = 0 if landpay==.
gen rincome = v_totalprod - landpay - c_seed - c_tractor - c_combine - c_thresh ///
              - c_other - c_cfert - c_herbinsec - c_hire
merge m:1 district using "$tmp/dwage_b.dta", keep(1 3) nogen
replace dw = __pmed_b if dw==.
merge 1:1 hhID using "$tmp/hlab_b.dta", keep(1 3) nogen
replace hdays = 0 if hdays==.
gen famdays = l_male + l_female
gen finc_ha  = (rincome - famdays*dw)/landsize2
gen famd_ha  = famdays/landsize2
gen famdm_ha = l_male/landsize2
gen famdf_ha = l_female/landsize2
gen famc_ha  = famdays*dw/landsize2
gen hired_ha = hdays/landsize2
gen lfinc = asinh(finc_ha)
* profit excluding the family labor spent on BIRD SCARING (co-author request):
* bird scaring absorbs many low-intensity days spent guarding the field
replace famdays_bird = 0 if famdays_bird==.
gen fincnb_ha = (rincome - (famdays - famdays_bird)*dw)/landsize2
gen bird_ha   = famdays_bird/landsize2
gen lfincnb   = asinh(fincnb_ha)
gen famdnb_ha = (famdays - famdays_bird)/landsize2
keep hhID finc_ha lfinc fincnb_ha lfincnb bird_ha famdnb_ha famd_ha famdm_ha famdf_ha famc_ha hired_ha
foreach v in finc_ha lfinc fincnb_ha lfincnb bird_ha famdnb_ha famd_ha famdm_ha famdf_ha famc_ha hired_ha {
    rename `v' `v'_bl
}
save "$tmp/famlab_bl.dta", replace
restore
merge m:1 district using "$tmp/dwage_e.dta", keep(1 3) nogen
replace dw = __pmed_e if dw==.
merge 1:1 hhID using "$tmp/hlab_e.dta", keep(1 3) nogen
replace hdays = 0 if hdays==.
gen famdays = l_male + l_female
gen finc_ha  = (rincome - famdays*dw)/landsize2
gen famd_ha  = famdays/landsize2
gen famdm_ha = l_male/landsize2
gen famdf_ha = l_female/landsize2
gen famc_ha  = famdays*dw/landsize2
gen hired_ha = hdays/landsize2
gen lfinc = asinh(finc_ha)
* profit excluding the family labor spent on BIRD SCARING (co-author request):
* bird scaring absorbs many low-intensity days spent guarding the field
replace famdays_bird = 0 if famdays_bird==.
gen fincnb_ha = (rincome - (famdays - famdays_bird)*dw)/landsize2
gen bird_ha   = famdays_bird/landsize2
gen lfincnb   = asinh(fincnb_ha)
gen famdnb_ha = (famdays - famdays_bird)/landsize2
merge 1:1 hhID using "$tmp/famlab_bl.dta", keep(1 3) nogen
label var finc_ha  "Profit (GHS/ha)"
label var lfinc    "Log profit (IHS)"
label var famd_ha  "Family labor (days/ha)"
label var famdm_ha "Male family labor (days/ha)"
label var famdf_ha "Female family labor (days/ha)"
label var famc_ha  "Family labor cost (GHS/ha)"
label var hired_ha "Hired labor (days/ha)"
label var fincnb_ha "Profit excl. bird scaring (GHS/ha)"
label var lfincnb   "Log profit excl. bird scaring (IHS)"
label var bird_ha   "Bird-scaring family labor (days/ha)"
label var famdnb_ha "Family labor excl. bird scaring (days/ha)"
* Yield and labour EXCLUDING households that lost the crop (co-author request,
* Sep 2026). A failed crop means no harvesting or threshing labour and zero
* yield, so an arm with more crop failure looks like it used less labour even if
* the farmers who did harvest worked the same. These variables are missing for a
* household that failed IN THAT WAVE, so the baseline and endline columns are
* each conditioned on that wave's own outcome.
gen yield_nf    = yield    if nonprod==0
gen hired_ha_nf = hired_ha if nonprod==0
gen famd_ha_nf  = famd_ha  if nonprod==0
gen yield_nf_bl    = yield_bl    if nonprod_bl==0
gen hired_ha_nf_bl = hired_ha_bl if nonprod_bl==0
gen famd_ha_nf_bl  = famd_ha_bl  if nonprod_bl==0
* For the ANCOVA columns the sample is fixed on the ENDLINE failure indicator, so
* outcome and lag are defined on the same households (co-author request, Sep 2026).
gen hired_ha_e     = hired_ha    if nonprod==0
gen famd_ha_e      = famd_ha     if nonprod==0
gen hired_ha_e_bl  = hired_ha_bl if nonprod==0
gen famd_ha_e_bl   = famd_ha_bl  if nonprod==0
label var hired_ha_e "Hired lab, excl. crop fail"
label var famd_ha_e  "Family lab, excl. crop fail"
label var yield_nf    "\quad Yield, excl. crop failure (t/ha)"
label var hired_ha_nf "\quad Hired labor, excl. crop failure (days/ha)"
label var famd_ha_nf  "\quad Family labor, excl. crop failure (days/ha)"

save "$tmp/farmer_e_analysis.dta", replace   // incl. labor vars + lags



*------------------------------------------------------------------------------
* 4. ANCOVA: production / income outcomes
*------------------------------------------------------------------------------
*------------------------------------------------------------------------------
* Program: ANCOVA + cluster-robust + wild bootstrap + randomization inference
* RHS: i.treat_dis i.gps <baseline lag> i.prov ; cluster(district)
*------------------------------------------------------------------------------
capture program drop ancova
program define ancova
    args y ylag
    qui sum `ylag' if treat_dis==0
    scalar bm = r(mean)                 // control-group BASELINE mean of the outcome
    qui sum `y' if treat_dis==0
    scalar cm = r(mean)                 // control-group ENDLINE mean of the outcome
    qui reg `y' i.treat_dis i.gps `ylag' i.prov, cluster(district)
    qui boottest 1.treat_dis, reps(9999) weight(webb) nograph
    scalar wbt1 = r(p)
    qui boottest 2.treat_dis, reps(9999) weight(webb) nograph
    scalar wbt2 = r(p)
    qui gen t1m = (treat_dis==1)
    qui gen t2m = (treat_dis==2)
    set seed 12345
    qui randcmd ((t1m t2m) reg `y' t1m t2m gps `ylag' i.prov, cluster(district)), ///
        reps(1000) treatvars(t1m t2m)
    matrix ripv = e(RCoef)
    scalar rit1 = ripv[1,6]
    scalar rit2 = ripv[2,6]
    drop t1m t2m
    eststo `y': reg `y' i.treat_dis i.gps `ylag' i.prov, cluster(district)
    qui test 1.treat_dis = 2.treat_dis
    estadd scalar t12p = r(p)
    estadd scalar bmean = bm
    estadd scalar cmean = cm
    estadd scalar wb_t1 = wbt1
    estadd scalar wb_t2 = wbt2
    estadd scalar ri_t1 = rit1
    estadd scalar ri_t2 = rit2
end


* 4. Production / income outcomes
* One line per outcome: the endline variable and its baseline value.
eststo clear
ancova rev_ha       rev_ha_bl
ancova rincome_ha   rincome_ha_bl
ancova finc_ha      finc_ha_bl
ancova lfinc        lfinc_bl
ancova yield        yield_bl
ancova lnyield      lnyield_bl
ancova nonprod      nonprod_bl
ancova u_fert       u_fert_bl
ancova u_her        u_her_bl
ancova u_machine    u_machine_bl
ancova hired_ha     hired_ha_bl
ancova famd_ha      famd_ha_bl
ancova lnrincome    lnrincome_bl
ancova fincnb_ha    fincnb_ha_bl
ancova lfincnb      lfincnb_bl
ancova famdnb_ha    famdnb_ha_bl
ancova squant_ha    squant_ha_bl

* main slide 1: production, income and profit
esttab yield lnyield nonprod rincome_ha lnrincome finc_ha lfinc fincnb_ha lfincnb using "$tmp/e_farmer_prod.tex", replace ///
    se nogap b(%9.3f) label booktabs nonotes ///
    keep(1.treat_dis 2.treat_dis 1.gps) ///
    coeflabels(1.treat_dis "T1: Feedback" 2.treat_dis "T2: Feedback+Training" 1.gps "Stamp (GPS)") ///
    stats(t12p bmean cmean wb_t1 wb_t2 ri_t1 ri_t2 N, ///
          fmt(%9.3f %9.3f %9.3f %9.3f %9.3f %9.3f %9.3f %9.0g) ///
          labels("T1=T2 [p]" "Ctrl mean (base)" "Ctrl mean (end)" "Wild-boot p (T1)" "Wild-boot p (T2)" "RI p (T1)" "RI p (T2)" "Obs")) ///
    mtitles("Yield" "Log yield" "Crop fail" "Income/ha" "Log income" "Profit/ha" "Log profit" "Profit excl.\ bird" "Log profit excl.") ///
    star(* 0.10 ** 0.05 *** 0.01)

* main slide 2: input use and labor
esttab squant_ha u_fert u_her u_machine hired_ha famd_ha famdnb_ha using "$tmp/e_farmer_inputs.tex", replace ///
    se nogap b(%9.3f) label booktabs nonotes ///
    keep(1.treat_dis 2.treat_dis 1.gps) ///
    coeflabels(1.treat_dis "T1: Feedback" 2.treat_dis "T2: Feedback+Training" 1.gps "Stamp (GPS)") ///
    stats(t12p bmean cmean wb_t1 wb_t2 ri_t1 ri_t2 N, ///
          fmt(%9.3f %9.3f %9.3f %9.3f %9.3f %9.3f %9.3f %9.0g) ///
          labels("T1=T2 [p]" "Ctrl mean (base)" "Ctrl mean (end)" "Wild-boot p (T1)" "Wild-boot p (T2)" "RI p (T1)" "RI p (T2)" "Obs")) ///
    mtitles("Seed qty" "Fert use" "Herb use" "Machine" "Hired lab" "Family lab" "Family excl.\ bird") ///
    star(* 0.10 ** 0.05 *** 0.01)

* 5. Management-practice adoption
eststo clear
ancova u_impany      u_impany_bl
ancova u_scertify    u_scertify_bl
ancova u_seedtreat   u_seedtreat_bl
ancova u_dib         u_dib_bl
ancova u_ptrans      u_ptrans_bl
ancova u_bunds       u_bunds_bl
ancova u_level       u_level_bl
ancova nprac         nprac_bl

esttab u_impany u_scertify u_seedtreat u_dib u_ptrans u_bunds u_level nprac using "$tmp/e_farmer_practice.tex", replace ///
    se nogap b(%9.3f) label booktabs nonotes ///
    keep(1.treat_dis 2.treat_dis 1.gps) ///
    coeflabels(1.treat_dis "T1: Feedback" 2.treat_dis "T2: Feedback+Training" 1.gps "Stamp (GPS)") ///
    stats(t12p bmean cmean wb_t1 wb_t2 ri_t1 ri_t2 N, ///
          fmt(%9.3f %9.3f %9.3f %9.3f %9.3f %9.3f %9.3f %9.0g) ///
          labels("T1=T2 [p]" "Ctrl mean (base)" "Ctrl mean (end)" "Wild-boot p (T1)" "Wild-boot p (T2)" "RI p (T1)" "RI p (T2)" "Obs")) ///
    mtitles("Any improved" "Certified" "Seed trt" "Dibbling" "Row trans" "Bunds" "Levelling" "No. practices") ///
    star(* 0.10 ** 0.05 *** 0.01)

* 6. Sampling-weighted robustness (population-representative), production outcomes
*    Weights only: no wild bootstrap or RI here, so the loop body is written out.
eststo clear
eststo rev_ha: reg rev_ha i.treat_dis i.gps rev_ha_bl i.prov [pw=sw], cluster(district)
test 1.treat_dis = 2.treat_dis
estadd scalar t12p = r(p)
summarize rev_ha_bl if treat_dis==0 [aw=sw]
estadd scalar bmean = r(mean)
summarize rev_ha if treat_dis==0 [aw=sw]
estadd scalar cmean = r(mean)

eststo rincome_ha: reg rincome_ha i.treat_dis i.gps rincome_ha_bl i.prov [pw=sw], cluster(district)
test 1.treat_dis = 2.treat_dis
estadd scalar t12p = r(p)
summarize rincome_ha_bl if treat_dis==0 [aw=sw]
estadd scalar bmean = r(mean)
summarize rincome_ha if treat_dis==0 [aw=sw]
estadd scalar cmean = r(mean)

eststo finc_ha: reg finc_ha i.treat_dis i.gps finc_ha_bl i.prov [pw=sw], cluster(district)
test 1.treat_dis = 2.treat_dis
estadd scalar t12p = r(p)
summarize finc_ha_bl if treat_dis==0 [aw=sw]
estadd scalar bmean = r(mean)
summarize finc_ha if treat_dis==0 [aw=sw]
estadd scalar cmean = r(mean)

eststo lfinc: reg lfinc i.treat_dis i.gps lfinc_bl i.prov [pw=sw], cluster(district)
test 1.treat_dis = 2.treat_dis
estadd scalar t12p = r(p)
summarize lfinc_bl if treat_dis==0 [aw=sw]
estadd scalar bmean = r(mean)
summarize lfinc if treat_dis==0 [aw=sw]
estadd scalar cmean = r(mean)

eststo yield: reg yield i.treat_dis i.gps yield_bl i.prov [pw=sw], cluster(district)
test 1.treat_dis = 2.treat_dis
estadd scalar t12p = r(p)
summarize yield_bl if treat_dis==0 [aw=sw]
estadd scalar bmean = r(mean)
summarize yield if treat_dis==0 [aw=sw]
estadd scalar cmean = r(mean)

eststo lnyield: reg lnyield i.treat_dis i.gps lnyield_bl i.prov [pw=sw], cluster(district)
test 1.treat_dis = 2.treat_dis
estadd scalar t12p = r(p)
summarize lnyield_bl if treat_dis==0 [aw=sw]
estadd scalar bmean = r(mean)
summarize lnyield if treat_dis==0 [aw=sw]
estadd scalar cmean = r(mean)

eststo nonprod: reg nonprod i.treat_dis i.gps nonprod_bl i.prov [pw=sw], cluster(district)
test 1.treat_dis = 2.treat_dis
estadd scalar t12p = r(p)
summarize nonprod_bl if treat_dis==0 [aw=sw]
estadd scalar bmean = r(mean)
summarize nonprod if treat_dis==0 [aw=sw]
estadd scalar cmean = r(mean)

eststo u_fert: reg u_fert i.treat_dis i.gps u_fert_bl i.prov [pw=sw], cluster(district)
test 1.treat_dis = 2.treat_dis
estadd scalar t12p = r(p)
summarize u_fert_bl if treat_dis==0 [aw=sw]
estadd scalar bmean = r(mean)
summarize u_fert if treat_dis==0 [aw=sw]
estadd scalar cmean = r(mean)

eststo u_her: reg u_her i.treat_dis i.gps u_her_bl i.prov [pw=sw], cluster(district)
test 1.treat_dis = 2.treat_dis
estadd scalar t12p = r(p)
summarize u_her_bl if treat_dis==0 [aw=sw]
estadd scalar bmean = r(mean)
summarize u_her if treat_dis==0 [aw=sw]
estadd scalar cmean = r(mean)

eststo u_machine: reg u_machine i.treat_dis i.gps u_machine_bl i.prov [pw=sw], cluster(district)
test 1.treat_dis = 2.treat_dis
estadd scalar t12p = r(p)
summarize u_machine_bl if treat_dis==0 [aw=sw]
estadd scalar bmean = r(mean)
summarize u_machine if treat_dis==0 [aw=sw]
estadd scalar cmean = r(mean)

eststo hired_ha: reg hired_ha i.treat_dis i.gps hired_ha_bl i.prov [pw=sw], cluster(district)
test 1.treat_dis = 2.treat_dis
estadd scalar t12p = r(p)
summarize hired_ha_bl if treat_dis==0 [aw=sw]
estadd scalar bmean = r(mean)
summarize hired_ha if treat_dis==0 [aw=sw]
estadd scalar cmean = r(mean)

eststo famd_ha: reg famd_ha i.treat_dis i.gps famd_ha_bl i.prov [pw=sw], cluster(district)
test 1.treat_dis = 2.treat_dis
estadd scalar t12p = r(p)
summarize famd_ha_bl if treat_dis==0 [aw=sw]
estadd scalar bmean = r(mean)
summarize famd_ha if treat_dis==0 [aw=sw]
estadd scalar cmean = r(mean)

eststo lnrincome: reg lnrincome i.treat_dis i.gps lnrincome_bl i.prov [pw=sw], cluster(district)
test 1.treat_dis = 2.treat_dis
estadd scalar t12p = r(p)
summarize lnrincome_bl if treat_dis==0 [aw=sw]
estadd scalar bmean = r(mean)
summarize lnrincome if treat_dis==0 [aw=sw]
estadd scalar cmean = r(mean)

eststo fincnb_ha: reg fincnb_ha i.treat_dis i.gps fincnb_ha_bl i.prov [pw=sw], cluster(district)
test 1.treat_dis = 2.treat_dis
estadd scalar t12p = r(p)
summarize fincnb_ha_bl if treat_dis==0 [aw=sw]
estadd scalar bmean = r(mean)
summarize fincnb_ha if treat_dis==0 [aw=sw]
estadd scalar cmean = r(mean)

eststo lfincnb: reg lfincnb i.treat_dis i.gps lfincnb_bl i.prov [pw=sw], cluster(district)
test 1.treat_dis = 2.treat_dis
estadd scalar t12p = r(p)
summarize lfincnb_bl if treat_dis==0 [aw=sw]
estadd scalar bmean = r(mean)
summarize lfincnb if treat_dis==0 [aw=sw]
estadd scalar cmean = r(mean)

eststo famdnb_ha: reg famdnb_ha i.treat_dis i.gps famdnb_ha_bl i.prov [pw=sw], cluster(district)
test 1.treat_dis = 2.treat_dis
estadd scalar t12p = r(p)
summarize famdnb_ha_bl if treat_dis==0 [aw=sw]
estadd scalar bmean = r(mean)
summarize famdnb_ha if treat_dis==0 [aw=sw]
estadd scalar cmean = r(mean)

esttab rev_ha rincome_ha finc_ha lfinc yield lnyield nonprod u_fert u_her u_machine hired_ha famd_ha lnrincome fincnb_ha lfincnb famdnb_ha using "$tmp/e_farmer_weighted.tex", replace ///
    se nogap b(%9.3f) label booktabs nonotes ///
    keep(1.treat_dis 2.treat_dis 1.gps) ///
    coeflabels(1.treat_dis "T1: Feedback" 2.treat_dis "T2: Feedback+Training" 1.gps "Stamp (GPS)") ///
    stats(t12p bmean cmean N, fmt(%9.3f %9.3f %9.3f %9.0g) ///
          labels("T1=T2 [p]" "Ctrl mean (base, wtd)" "Ctrl mean (end, wtd)" "Obs")) ///
    mtitles("Revenue/ha" "Income/ha" "Profit/ha" "Log profit" "Yield" "Log yield" "Crop fail" "Fert use" "Herb use" "Machine" "Hired lab" "Family lab") ///
    star(* 0.10 ** 0.05 *** 0.01)

* 7. Sampling-weighted robustness, management-practice outcomes
eststo clear
eststo u_impany: reg u_impany i.treat_dis i.gps u_impany_bl i.prov [pw=sw], cluster(district)
test 1.treat_dis = 2.treat_dis
estadd scalar t12p = r(p)
summarize u_impany_bl if treat_dis==0 [aw=sw]
estadd scalar bmean = r(mean)
summarize u_impany if treat_dis==0 [aw=sw]
estadd scalar cmean = r(mean)

eststo u_scertify: reg u_scertify i.treat_dis i.gps u_scertify_bl i.prov [pw=sw], cluster(district)
test 1.treat_dis = 2.treat_dis
estadd scalar t12p = r(p)
summarize u_scertify_bl if treat_dis==0 [aw=sw]
estadd scalar bmean = r(mean)
summarize u_scertify if treat_dis==0 [aw=sw]
estadd scalar cmean = r(mean)

eststo u_seedtreat: reg u_seedtreat i.treat_dis i.gps u_seedtreat_bl i.prov [pw=sw], cluster(district)
test 1.treat_dis = 2.treat_dis
estadd scalar t12p = r(p)
summarize u_seedtreat_bl if treat_dis==0 [aw=sw]
estadd scalar bmean = r(mean)
summarize u_seedtreat if treat_dis==0 [aw=sw]
estadd scalar cmean = r(mean)

eststo u_dib: reg u_dib i.treat_dis i.gps u_dib_bl i.prov [pw=sw], cluster(district)
test 1.treat_dis = 2.treat_dis
estadd scalar t12p = r(p)
summarize u_dib_bl if treat_dis==0 [aw=sw]
estadd scalar bmean = r(mean)
summarize u_dib if treat_dis==0 [aw=sw]
estadd scalar cmean = r(mean)

eststo u_ptrans: reg u_ptrans i.treat_dis i.gps u_ptrans_bl i.prov [pw=sw], cluster(district)
test 1.treat_dis = 2.treat_dis
estadd scalar t12p = r(p)
summarize u_ptrans_bl if treat_dis==0 [aw=sw]
estadd scalar bmean = r(mean)
summarize u_ptrans if treat_dis==0 [aw=sw]
estadd scalar cmean = r(mean)

eststo u_bunds: reg u_bunds i.treat_dis i.gps u_bunds_bl i.prov [pw=sw], cluster(district)
test 1.treat_dis = 2.treat_dis
estadd scalar t12p = r(p)
summarize u_bunds_bl if treat_dis==0 [aw=sw]
estadd scalar bmean = r(mean)
summarize u_bunds if treat_dis==0 [aw=sw]
estadd scalar cmean = r(mean)

eststo u_level: reg u_level i.treat_dis i.gps u_level_bl i.prov [pw=sw], cluster(district)
test 1.treat_dis = 2.treat_dis
estadd scalar t12p = r(p)
summarize u_level_bl if treat_dis==0 [aw=sw]
estadd scalar bmean = r(mean)
summarize u_level if treat_dis==0 [aw=sw]
estadd scalar cmean = r(mean)

eststo nprac: reg nprac i.treat_dis i.gps nprac_bl i.prov [pw=sw], cluster(district)
test 1.treat_dis = 2.treat_dis
estadd scalar t12p = r(p)
summarize nprac_bl if treat_dis==0 [aw=sw]
estadd scalar bmean = r(mean)
summarize nprac if treat_dis==0 [aw=sw]
estadd scalar cmean = r(mean)

esttab u_impany u_scertify u_seedtreat u_dib u_ptrans u_bunds u_level nprac using "$tmp/e_farmer_prac_w.tex", replace ///
    se nogap b(%9.3f) label booktabs nonotes ///
    keep(1.treat_dis 2.treat_dis 1.gps) ///
    coeflabels(1.treat_dis "T1: Feedback" 2.treat_dis "T2: Feedback+Training" 1.gps "Stamp (GPS)") ///
    stats(t12p bmean cmean N, fmt(%9.3f %9.3f %9.3f %9.0g) ///
          labels("T1=T2 [p]" "Ctrl mean (base, wtd)" "Ctrl mean (end, wtd)" "Obs")) ///
    mtitles("Any improved" "Certified" "Seed trt" "Dibbling" "Row trans" "Bunds" "Levelling" "No. practices") ///
    star(* 0.10 ** 0.05 *** 0.01)

* 8. (removed Sep 2026) The "excluding irrigation schemes" robustness block used
*    to sit here. It is now redundant: the MAIN analysis above already runs on
*    the rainfed sites only.

* 9. ANCOVA that also controls for technology adoption (co-author request,
*    Jul 2026): same specification plus the management-practice and input
*    dummies, so the treatment coefficients are conditional on adoption and the
*    practice coefficients show how each technology correlates with output.
*    NB: adoption is measured after the intervention, so these are potentially
*    "bad controls" -- read the practice rows as correlations, not effects.
global techctl u_impany u_scertify u_seedtreat u_dib u_ptrans u_bunds u_level u_fert u_her u_machine
capture program drop ancova_tech
program define ancova_tech
    args y ylag
    qui sum `ylag' if treat_dis==0
    scalar bm = r(mean)
    qui sum `y' if treat_dis==0
    scalar cm = r(mean)
    qui reg `y' i.treat_dis i.gps `ylag' i.prov $techctl, cluster(district)
    qui boottest 1.treat_dis, reps(9999) weight(webb) nograph
    scalar wbt1 = r(p)
    qui boottest 2.treat_dis, reps(9999) weight(webb) nograph
    scalar wbt2 = r(p)
    qui gen t1m = (treat_dis==1)
    qui gen t2m = (treat_dis==2)
    set seed 12345
    qui randcmd ((t1m t2m) reg `y' t1m t2m gps `ylag' i.prov $techctl, cluster(district)), ///
        reps(1000) treatvars(t1m t2m)
    matrix ripv = e(RCoef)
    scalar rit1 = ripv[1,6]
    scalar rit2 = ripv[2,6]
    drop t1m t2m
    eststo `y': reg `y' i.treat_dis i.gps `ylag' i.prov $techctl, cluster(district)
    qui test 1.treat_dis = 2.treat_dis
    estadd scalar t12p = r(p)
    estadd scalar bmean = bm
    estadd scalar cmean = cm
    estadd scalar wb_t1 = wbt1
    estadd scalar wb_t2 = wbt2
    estadd scalar ri_t1 = rit1
    estadd scalar ri_t2 = rit2
end
eststo clear
ancova_tech yield        yield_bl
ancova_tech lnyield      lnyield_bl
ancova_tech nonprod      nonprod_bl
ancova_tech rincome_ha   rincome_ha_bl
ancova_tech lnrincome    lnrincome_bl
ancova_tech finc_ha      finc_ha_bl
ancova_tech lfinc        lfinc_bl
ancova_tech fincnb_ha    fincnb_ha_bl
ancova_tech lfincnb      lfincnb_bl

esttab yield lnyield nonprod rincome_ha lnrincome finc_ha lfinc fincnb_ha lfincnb using "$tmp/e_farmer_prod_tech.tex", replace ///
    se nogap b(%9.3f) label booktabs nonotes ///
    keep(1.treat_dis 2.treat_dis 1.gps $techctl) ///
    coeflabels(1.treat_dis "T1: Feedback" 2.treat_dis "T2: Feedback+Training" 1.gps "Stamp (GPS)") ///
    stats(t12p bmean cmean wb_t1 wb_t2 ri_t1 ri_t2 N, ///
          fmt(%9.3f %9.3f %9.3f %9.3f %9.3f %9.3f %9.3f %9.0g) ///
          labels("T1=T2 [p]" "Ctrl mean (base)" "Ctrl mean (end)" "Wild-boot p (T1)" "Wild-boot p (T2)" "RI p (T1)" "RI p (T2)" "Obs")) ///
    mtitles("Yield" "Log yield" "Crop fail" "Income/ha" "Log income" "Profit/ha" "Log profit" "Profit excl.\ bird" "Log profit excl.") ///
    star(* 0.10 ** 0.05 *** 0.01)

di _n "=== farmer ANCOVA + robustness done ==="

*==============================================================================
* APPENDIX BLOCKS (co-author requests, Jul 2026)
*==============================================================================
* A1. FB/TR reparameterization: FB = 1{T1 or T2}, TR = 1{T2}.
*     Identical fit to the main ANCOVA, reparameterized so that
*     coef(FB) = feedback effect (T1 vs C) and coef(TR) = incremental
*     training effect (T2 - T1). Wild-boot p for both; RI for FB equals
*     the main tables' RI for T1.
gen fb = (treat_dis==1 | treat_dis==2)
gen tr = (treat_dis==2)

capture program drop ancova_fbtr
program define ancova_fbtr
    args y ylag
    qui sum `ylag' if treat_dis==0
    scalar bm = r(mean)
    qui sum `y' if treat_dis==0
    scalar cm = r(mean)
    qui reg `y' fb tr i.gps `ylag' i.prov, cluster(district)
    qui boottest fb, reps(9999) weight(webb) nograph
    scalar wbf = r(p)
    qui boottest tr, reps(9999) weight(webb) nograph
    scalar wbt = r(p)
    set seed 12345
    qui randcmd ((fb tr) reg `y' fb tr gps `ylag' i.prov, cluster(district)), ///
        reps(1000) treatvars(fb tr)
    matrix ripv = e(RCoef)
    scalar rifb = ripv[1,6]
    scalar ritr = ripv[2,6]
    eststo `y': reg `y' fb tr i.gps `ylag' i.prov, cluster(district)
    estadd scalar bmean = bm
    estadd scalar cmean = cm
    estadd scalar wb_fb = wbf
    estadd scalar wb_tr = wbt
    estadd scalar ri_fb = rifb
    estadd scalar ri_tr = ritr
end


eststo clear
ancova_fbtr rev_ha       rev_ha_bl
ancova_fbtr rincome_ha   rincome_ha_bl
ancova_fbtr finc_ha      finc_ha_bl
ancova_fbtr lfinc        lfinc_bl
ancova_fbtr yield        yield_bl
ancova_fbtr lnyield      lnyield_bl
ancova_fbtr nonprod      nonprod_bl
ancova_fbtr u_fert       u_fert_bl
ancova_fbtr u_her        u_her_bl
ancova_fbtr u_machine    u_machine_bl
ancova_fbtr hired_ha     hired_ha_bl
ancova_fbtr famd_ha      famd_ha_bl
ancova_fbtr lnrincome    lnrincome_bl
ancova_fbtr fincnb_ha    fincnb_ha_bl
ancova_fbtr lfincnb      lfincnb_bl
ancova_fbtr famdnb_ha    famdnb_ha_bl

esttab rev_ha rincome_ha finc_ha lfinc yield lnyield nonprod u_fert u_her u_machine hired_ha famd_ha lnrincome fincnb_ha lfincnb famdnb_ha using "$tmp/e_farmer_prod_fbtr.tex", replace ///
    se nogap b(%9.3f) label booktabs nonotes ///
    keep(fb tr 1.gps) ///
    coeflabels(fb "FB: Feedback (T1 or T2)" tr "TR: Training increment (T2 vs T1)" 1.gps "Stamp (GPS)") ///
    stats(bmean cmean wb_fb wb_tr ri_fb ri_tr N, fmt(%9.3f %9.3f %9.3f %9.3f %9.3f %9.3f %9.0g) ///
          labels("Ctrl mean (base)" "Ctrl mean (end)" "Wild-boot p (FB)" "Wild-boot p (TR)" "RI p (FB)" "RI p (TR)" "Obs")) ///
    mtitles("Revenue/ha" "Income/ha" "Profit/ha" "Log profit" "Yield" "Log yield" "Crop fail" "Fert use" "Herb use" "Machine" "Hired lab" "Family lab") ///
    star(* 0.10 ** 0.05 *** 0.01)

eststo clear
ancova_fbtr u_impany      u_impany_bl
ancova_fbtr u_scertify    u_scertify_bl
ancova_fbtr u_seedtreat   u_seedtreat_bl
ancova_fbtr u_dib         u_dib_bl
ancova_fbtr u_ptrans      u_ptrans_bl
ancova_fbtr u_bunds       u_bunds_bl
ancova_fbtr u_level       u_level_bl
ancova_fbtr nprac         nprac_bl

esttab u_impany u_scertify u_seedtreat u_dib u_ptrans u_bunds u_level nprac using "$tmp/e_farmer_prac_fbtr.tex", replace ///
    se nogap b(%9.3f) label booktabs nonotes ///
    keep(fb tr 1.gps) ///
    coeflabels(fb "FB: Feedback (T1 or T2)" tr "TR: Training increment (T2 vs T1)" 1.gps "Stamp (GPS)") ///
    stats(bmean cmean wb_fb wb_tr ri_fb ri_tr N, fmt(%9.3f %9.3f %9.3f %9.3f %9.3f %9.3f %9.0g) ///
          labels("Ctrl mean (base)" "Ctrl mean (end)" "Wild-boot p (FB)" "Wild-boot p (TR)" "RI p (FB)" "RI p (TR)" "Obs")) ///
    mtitles("Any improved" "Certified" "Seed trt" "Dibbling" "Row trans" "Bunds" "Levelling" "No. practices") ///
    star(* 0.10 ** 0.05 *** 0.01)

* A2. 2SLS: bi-weekly extension intensity / satisfaction -> endline outcomes.
*     Endogenous regressors (one at a time), instrumented by T1/T2 assignment:
*       cumQ1    cumulative visits   (Apr-Sep)
*       cumQ2    cumulative contacts (Apr-Sep)
*       msatall  mean 1-5 satisfaction level, rounds with a visit or an
*                interaction (Apr-Sep)
*       msat     the same for 05-1..06-2
*                (early-season: predates harvest, limits reverse causality)
*     Outcomes: O1 = production (main-table set excl. log income);
*               O2 = technology adoption.
*     Requires tmp/bw_cum.dta from do/bw_tables_v2.do (run that first).
*     KP F = Kleibergen-Paap weak-ID F. Hansen J from the het.-robust VCE
*     (the district-clustered J is not computable with ~10 clusters).
capture confirm file "$tmp/bw_cum.dta"
if _rc {
    di as error "tmp/bw_cum.dta not found -- run do/bw_tables_v2.do first; skipping 2SLS"
}
else {
    merge 1:1 hhID using "$tmp/bw_cum.dta", keep(1 3)
    qui count if _merge==3
    di as txt "farmers matched to bi-weekly data: " r(N) " of " _N
    drop _merge
    gen t1m = (treat_dis==1)
    gen t2m = (treat_dis==2)
    label var cumQ1   "Cumulative visits (Apr--Sep)"
    label var cumQ2   "Cumulative contacts (Apr--Sep)"
    label var msatall "Mean satisfaction level (Apr--Sep)"
    label var msat    "Mean satisfaction level (05-1--06-2)"
    local O1 finc_ha lfinc yield lnyield nonprod u_fert u_her u_machine hired_ha famd_ha
    local O1mt mtitles("Profit/ha" "Log profit" "Yield" "Log yield" "Crop fail" "Fert use" "Herb use" "Machine" "Hired lab" "Family lab")
    local O2 u_impany u_scertify u_seedtreat u_dib u_ptrans u_bunds u_level nprac
    local O2mt mtitles("Any improved" "Certified" "Seed trt" "Dibbling" "Row trans" "Bunds" "Levelling" "No. practices")
    local ivstats stats(cmean kpf hjp N, fmt(%9.3f %9.2f %9.3f %9.0g) labels(`"Ctrl mean (end)"' `"KP weak-ID F"' `"Hansen J p"' `"Obs"'))
    foreach en in cumQ1 cumQ2 msatall msat {
        foreach oset in O1 O2 {
            eststo clear
            local mods ""
            foreach y of local `oset' {
                qui ivreg2 `y' (`en' = t1m t2m) i.gps `y'_bl i.prov, robust
                local jp = e(jp)
                eststo iv_`y': ivreg2 `y' (`en' = t1m t2m) i.gps `y'_bl i.prov, cluster(district)
                estadd scalar kpf = e(widstat)
                estadd scalar hjp = `jp'
                qui sum `y' if treat_dis==0
                estadd scalar cmean = r(mean)
                local mods "`mods' iv_`y'"
            }
            local lcoset = lower("`oset'")
            esttab `mods' using "$tmp/e_2sls_`lcoset'_`en'.tex", replace ///
                se nogap b(%9.3f) label booktabs nonotes ///
                keep(`en') ``oset'mt' `ivstats' ///
                star(* 0.10 ** 0.05 *** 0.01)
        }
    }
    drop t1m t2m   // ancova in A4/A5 re-creates these; leaving them aborts the run
}

* A5. Family-labor detail table (gender decomposition; generated for reference)
eststo clear
foreach y in finc_ha lfinc famd_ha famdm_ha famdf_ha famc_ha {
    ancova `y' `y'_bl
}
esttab finc_ha lfinc famd_ha famdm_ha famdf_ha famc_ha using "$tmp/e_farmer_famlab.tex", replace ///
    se nogap b(%9.3f) label booktabs nonotes ///
    keep(1.treat_dis 2.treat_dis 1.gps) coeflabels(1.treat_dis "T1: Feedback" 2.treat_dis "T2: Feedback+Training" 1.gps "Stamp (GPS)") ///
    stats(t12p bmean cmean wb_t1 wb_t2 ri_t1 ri_t2 N, fmt(%9.3f %9.3f %9.3f %9.3f %9.3f %9.3f %9.3f %9.0g) labels("T1=T2 [p]" "Ctrl mean (base)" "Ctrl mean (end)" "Wild-boot p (T1)" "Wild-boot p (T2)" "RI p (T1)" "RI p (T2)" "Obs")) ///
    mtitles("Profit/ha" "Log profit" "Fam.\ days/ha" "Male days/ha" "Female days/ha" "Fam.\ cost/ha") ///
    star(* 0.10 ** 0.05 *** 0.01)

* A6. Dispersion (Glejser): |ANCOVA residual| regressed on treatment (Mano
*     hypothesis, Jul 2026). Wild-boot p for T1/T2; no RI.
eststo clear
foreach y in yield lnyield finc_ha lfinc {
    qui reg `y' i.treat_dis i.gps `y'_bl i.prov, cluster(district)
    capture drop __e __ae
    qui predict __e if e(sample), resid
    qui gen __ae = abs(__e)
    qui sum __ae if treat_dis==0
    scalar cm = r(mean)
    qui reg __ae i.treat_dis i.gps i.prov, cluster(district)
    qui boottest 1.treat_dis, reps(9999) weight(webb) nograph
    scalar wbt1 = r(p)
    qui boottest 2.treat_dis, reps(9999) weight(webb) nograph
    scalar wbt2 = r(p)
    eststo d_`y': reg __ae i.treat_dis i.gps i.prov, cluster(district)
    qui test 1.treat_dis = 2.treat_dis
    estadd scalar t12p = r(p)
    estadd scalar cmean = cm
    estadd scalar wb_t1 = wbt1
    estadd scalar wb_t2 = wbt2
    drop __e __ae
}
esttab d_yield d_lnyield d_finc_ha d_lfinc using "$tmp/e_farmer_disp.tex", replace ///
    se nogap b(%9.3f) label booktabs nonotes ///
    keep(1.treat_dis 2.treat_dis 1.gps) coeflabels(1.treat_dis "T1: Feedback" 2.treat_dis "T2: Feedback+Training" 1.gps "Stamp (GPS)") ///
    stats(t12p cmean wb_t1 wb_t2 N, fmt(%9.3f %9.3f %9.3f %9.3f %9.0g) ///
        labels(`"T1=T2 [p]"' `"Ctrl mean |resid|"' `"Wild-boot p (T1)"' `"Wild-boot p (T2)"' `"Obs"')) ///
    mtitles("Yield" "Log yield" "Income/ha" "Log income") ///
    star(* 0.10 ** 0.05 *** 0.01)

* A7. Farmer knowledge proxies: correct-practice responses (QY1-4)
eststo clear
label var y_w_growth "Water: growth stage"
label var y_w_repod  "Water: reproductive"
label var y_w_mature "Water: maturity"
label var y_drying   "Drying practice"
label var y_harvest  "Harvest timing"
label var y_moisture "Moisture check"
label var y_thresh   "Threshing method"
foreach y in y_w_growth y_w_repod y_w_mature y_drying y_harvest y_moisture y_thresh {
    ancova `y' `y'_bl
}
esttab y_w_growth y_w_repod y_w_mature y_drying y_harvest y_moisture y_thresh ///
    using "$tmp/e_farmer_know.tex", replace ///
    se nogap b(%9.3f) label booktabs nonotes ///
    keep(1.treat_dis 2.treat_dis 1.gps) coeflabels(1.treat_dis "T1: Feedback" 2.treat_dis "T2: Feedback+Training" 1.gps "Stamp (GPS)") ///
    stats(t12p bmean cmean wb_t1 wb_t2 ri_t1 ri_t2 N, fmt(%9.3f %9.3f %9.3f %9.3f %9.3f %9.3f %9.3f %9.0g) labels("T1=T2 [p]" "Ctrl mean (base)" "Ctrl mean (end)" "Wild-boot p (T1)" "Wild-boot p (T2)" "RI p (T1)" "RI p (T2)" "Obs")) ///
    mtitles("Water: grow" "Water: repr" "Water: mat" "Drying" "Harvest" "Moisture" "Threshing") ///
    star(* 0.10 ** 0.05 *** 0.01)

* A8. 2SLS variants (co-author requests, Jul 2026):
*     (a) pooled single instrument T = T1 or T2 (just-identified, no Hansen J);
*     (b) practice count as the endogenous regressor (first stage = null ITT
*         on nprac -> weak instruments by construction; KP F reported).
capture confirm file "$tmp/bw_cum.dta"
if !_rc {
    preserve
    merge 1:1 hhID using "$tmp/bw_cum.dta", keep(1 3) nogen
    gen t1m = (treat_dis==1)
    gen t2m = (treat_dis==2)
    gen fbp = (treat_dis>=1)
    local O1 finc_ha lfinc yield lnyield nonprod u_fert u_her u_machine hired_ha famd_ha
    local O1mt mtitles("Profit/ha" "Log profit" "Yield" "Log yield" "Crop fail" "Fert use" "Herb use" "Machine" "Hired lab" "Family lab")
    local O2 u_impany u_scertify u_seedtreat u_dib u_ptrans u_bunds u_level nprac
    local O2mt mtitles("Any improved" "Certified" "Seed trt" "Dibbling" "Row trans" "Bunds" "Levelling" "No. practices")
    local ivstatsP stats(cmean kpf N, fmt(%9.3f %9.2f %9.0g) labels(`"Ctrl mean (end)"' `"KP weak-ID F"' `"Obs"'))
    foreach oset in O1 O2 {
        local lcoset = lower("`oset'")
        foreach en in cumQ1 cumQ2 msatall msat {
            eststo clear
            local mods ""
            foreach y of local `oset' {
                eststo pv_`y': ivreg2 `y' (`en' = fbp) i.gps `y'_bl i.prov, cluster(district)
                estadd scalar kpf = e(widstat)
                qui sum `y' if treat_dis==0
                estadd scalar cmean = r(mean)
                local mods "`mods' pv_`y'"
            }
            esttab `mods' using "$tmp/e_2sls_p_`lcoset'_`en'.tex", replace ///
                se nogap b(%9.3f) label booktabs nonotes ///
                keep(`en') ``oset'mt' `ivstatsP' ///
                star(* 0.10 ** 0.05 *** 0.01)
        }
    }
    eststo clear
    label var nprac "No. of practices adopted"
    local mods ""
    foreach y of local O1 {
        qui ivreg2 `y' (nprac = t1m t2m) i.gps nprac_bl i.prov, robust
        local jp = e(jp)
        eststo np_`y': ivreg2 `y' (nprac = t1m t2m) i.gps nprac_bl i.prov, cluster(district)
        estadd scalar kpf = e(widstat)
        estadd scalar hjp = `jp'
        qui sum `y' if treat_dis==0
        estadd scalar cmean = r(mean)
        local mods "`mods' np_`y'"
    }
    esttab `mods' using "$tmp/e_2sls_nprac.tex", replace ///
        se nogap b(%9.3f) label booktabs nonotes ///
        keep(nprac) `O1mt' ///
        stats(cmean kpf hjp N, fmt(%9.3f %9.2f %9.3f %9.0g) labels(`"Ctrl mean (end)"' `"KP weak-ID F"' `"Hansen J p"' `"Obs"')) ///
        star(* 0.10 ** 0.05 *** 0.01)
    * same, with the combined instrument T = 1{T1 or T2}
    eststo clear
    local mods ""
    foreach y of local O1 {
        eststo pn_`y': ivreg2 `y' (nprac = fbp) i.gps nprac_bl i.prov, cluster(district)
        estadd scalar kpf = e(widstat)
        qui sum `y' if treat_dis==0
        estadd scalar cmean = r(mean)
        local mods "`mods' pn_`y'"
    }
    esttab `mods' using "$tmp/e_2sls_p_nprac.tex", replace ///
        se nogap b(%9.3f) label booktabs nonotes ///
        keep(nprac) `O1mt' `ivstatsP' ///
        star(* 0.10 ** 0.05 *** 0.01)
    restore
}

* A9. Profit excluding bird-scaring family labor (co-author request, Jul 2026).
eststo clear
foreach y in fincnb_ha lfincnb bird_ha {
    ancova `y' `y'_bl
}
esttab fincnb_ha lfincnb bird_ha using "$tmp/e_farmer_bird.tex", replace ///
    se nogap b(%9.3f) label booktabs nonotes ///
    keep(1.treat_dis 2.treat_dis 1.gps) coeflabels(1.treat_dis "T1: Feedback" 2.treat_dis "T2: Feedback+Training" 1.gps "Stamp (GPS)") ///
    stats(t12p bmean cmean wb_t1 wb_t2 ri_t1 ri_t2 N, fmt(%9.3f %9.3f %9.3f %9.3f %9.3f %9.3f %9.3f %9.0g) labels("T1=T2 [p]" "Ctrl mean (base)" "Ctrl mean (end)" "Wild-boot p (T1)" "Wild-boot p (T2)" "RI p (T1)" "RI p (T2)" "Obs")) ///
    mtitles("Profit excl. bird" "Log profit excl. bird" "Bird days/ha") ///
    star(* 0.10 ** 0.05 *** 0.01)
