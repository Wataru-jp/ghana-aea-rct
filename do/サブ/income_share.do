*==============================================================================
* income_share.do -- Income and profit NET OF LAND PAYMENTS.
*
* The production module records three mutually exclusive ways of paying for a
* rented plot (QY1.1_5_rent):
*   1 Cash rent      QY11_5           GHS per acre
*   2 In-kind rent   QY11_6 x QY11_7  kg of paddy traded x price per kg
*   3 Share cropping QY11_8           per cent of GROSS rice production handed over
* None of the three is currently deducted anywhere in the pipeline, so income and
* profit are gross of what tenants pay for land. Share croppers are 14% of the
* sample in both waves and hand over a median 30% of output.
*
* Two variants are built, both applied to BOTH waves so the ANCOVA lag matches:
*   _s  share only          -- exactly the correction asked for
*   _l  all land payments   -- share + cash rent + in-kind rent (recommended:
*                              deducting only the share would penalise share
*                              croppers relative to cash tenants)
* Income and profit differ by the imputed family-labour cost, which is untouched
* here, so both variants shift income and profit by the SAME amount per farmer.
*
* Output: tmp/e_farmer_share.tex  (+ tmp/farmer_share.dta)
*==============================================================================
set more off
global path "/Users/wkodama/research/ghana-aea-rct"
global tmp  "$path/tmp"

* ---------- land payments, per wave ----------
foreach w in b e {
    if "`w'"=="b" local f "$path/Baseline/QY1-1wet (Rice production in wet season in 2024)_V2_rev2026Aug.dta"
    if "`w'"=="e" local f "$path/Endline/QY1-1wet (Rice production in wet season in 2025).dta"
    use "`f'", clear
    keep hhID QY11_3 QY11_5_rent QY11_5 QY11_6 QY11_7 QY11_8
    gen sharepct = QY11_8 if QY11_5_rent==3
    replace sharepct = 0 if sharepct==.
    replace sharepct = 0 if sharepct<0 | sharepct>100
    gen rentcash = QY11_5*QY11_3 if QY11_5_rent==1     // GHS/acre x acres
    replace rentcash = 0 if rentcash==.
    gen rentkind = QY11_6*QY11_7 if QY11_5_rent==2     // kg x GHS/kg
    replace rentkind = 0 if rentkind==.
    gen rentfix = rentcash + rentkind
    keep hhID sharepct rentfix
    rename (sharepct rentfix) (sharepct_`w' rentfix_`w')
    tempfile lp`w'
    save `lp`w''
}

* ---------- baseline gross output and area ----------
use "$tmp/farmer.dta", clear
keep hhID v_totalprod landsize
gen landsize2 = landsize*0.4047
rename v_totalprod vtp_b
keep hhID vtp_b landsize2
rename landsize2 ha_b
merge 1:1 hhID using `lpb', nogen
merge 1:1 hhID using "$tmp/famlab_bl.dta", keepusing(finc_ha_bl) keep(1 3) nogen
* guard: v_totalprod is missing for non-producers, and 0*. = . in Stata, so a
* farmer who pays NO share would otherwise be dropped from the regression.
gen sharegh_b = cond(sharepct_b>0 & vtp_b<., vtp_b*sharepct_b/100, 0)
gen landpay_b = sharegh_b + rentfix_b
tempfile bl
save `bl'

* ---------- endline: build the two variants ----------
use "$tmp/farmer_e_analysis.dta", clear
merge 1:1 hhID using `lpe', nogen
merge 1:1 hhID using `bl', keepusing(vtp_b ha_b sharepct_b rentfix_b sharegh_b landpay_b finc_ha_bl) keep(1 3) nogen

gen sharegh_e = cond(sharepct_e>0 & v_totalprod<., v_totalprod*sharepct_e/100, 0)
gen landpay_e = sharegh_e + rentfix_e

di _n "===== land payments, endline ====="
tabstat sharepct_e sharegh_e rentfix_e landpay_e, stat(n mean p50 max) col(stat) format(%9.1f)
count if sharepct_e>0
di "  share croppers (endline): `r(N)'"
count if rentfix_e>0
di "  fixed-rent tenants (endline): `r(N)'"

* endline outcomes, per hectare
gen inc_s_ha  = rincome_ha - sharegh_e/landsize2
gen prof_s_ha = finc_ha    - sharegh_e/landsize2
gen inc_l_ha  = rincome_ha - landpay_e/landsize2
gen prof_l_ha = finc_ha    - landpay_e/landsize2
foreach v in inc_s prof_s inc_l prof_l {
    gen l`v' = asinh(`v'_ha)
}
* matching baseline lags
gen inc_s_ha_bl  = rincome_ha_bl - sharegh_b/ha_b
gen prof_s_ha_bl = finc_ha_bl    - sharegh_b/ha_b
gen inc_l_ha_bl  = rincome_ha_bl - landpay_b/ha_b
gen prof_l_ha_bl = finc_ha_bl    - landpay_b/ha_b
foreach v in inc_s prof_s inc_l prof_l {
    gen l`v'_bl = asinh(`v'_ha_bl)
}

label var inc_s_ha   "Income/ha"
label var linc_s     "Log income"
label var prof_s_ha  "Profit/ha"
label var lprof_s    "Log profit"
label var inc_l_ha   "Income/ha"
label var linc_l     "Log income"
label var prof_l_ha  "Profit/ha"
label var lprof_l    "Log profit"
save "$tmp/farmer_share.dta", replace

*------------------------------------------------------------------------------
* ANCOVA, identical spec to f_endline_analysis.do
*------------------------------------------------------------------------------
capture program drop est_one
program define est_one
    args y ylag
    qui sum `ylag' if treat_dis==0
    scalar bm = r(mean)
    qui sum `y' if treat_dis==0
    scalar cm = r(mean)
    qui reg `y' i.treat_dis i.gps i.irrgsch `ylag' i.prov, cluster(district)
    qui boottest 1.treat_dis, reps(9999) weight(webb) nograph
    scalar wbt1 = r(p)
    qui boottest 2.treat_dis, reps(9999) weight(webb) nograph
    scalar wbt2 = r(p)
    qui gen t1m = (treat_dis==1)
    qui gen t2m = (treat_dis==2)
    set seed 12345
    qui randcmd ((t1m t2m) reg `y' t1m t2m gps i.irrgsch `ylag' i.prov, cluster(district)), ///
        reps(1000) treatvars(t1m t2m)
    matrix ripv = e(RCoef)
    scalar rit1 = ripv[1,6]
    scalar rit2 = ripv[2,6]
    drop t1m t2m
    eststo `y': reg `y' i.treat_dis i.gps i.irrgsch `ylag' i.prov, cluster(district)
    qui test 1.treat_dis = 2.treat_dis
    estadd scalar t12p = r(p)
    estadd scalar bmean = bm
    estadd scalar cmean = cm
    estadd scalar wb_t1 = wbt1
    estadd scalar wb_t2 = wbt2
    estadd scalar ri_t1 = rit1
    estadd scalar ri_t2 = rit2
end

local sstat t12p bmean cmean wb_t1 wb_t2 ri_t1 ri_t2 N
local sfmt  %9.3f %9.3f %9.3f %9.3f %9.3f %9.3f %9.3f %9.0g
local slab  `"Ctrl mean (base)"' `"Ctrl mean (end)"' `"Wild-boot p (T1)"' `"Wild-boot p (T2)"' `"RI p (T1)"' `"RI p (T2)"' `"Obs"'
local kcoef 1.treat_dis 2.treat_dis 1.gps 1.irrgsch
local clab  1.treat_dis "T1: Feedback" 2.treat_dis "T2: Feedback+Training" 1.gps "Stamp (GPS)" 1.irrgsch "Irrigation"

eststo clear
est_one inc_s_ha  inc_s_ha_bl
est_one linc_s    linc_s_bl
est_one prof_s_ha prof_s_ha_bl
est_one lprof_s   lprof_s_bl
est_one inc_l_ha  inc_l_ha_bl
est_one linc_l    linc_l_bl
est_one prof_l_ha prof_l_ha_bl
est_one lprof_l   lprof_l_bl
esttab inc_s_ha linc_s prof_s_ha lprof_s inc_l_ha linc_l prof_l_ha lprof_l ///
    using "$tmp/e_farmer_share.tex", replace ///
    se nogap b(%9.3f) label booktabs nonotes ///
    keep(`kcoef') order(`kcoef') coeflabels(`clab') ///
    stats(`sstat', fmt(`sfmt') labels(`"T1=T2 [p]"' `"Ctrl mean (base)"' `"Ctrl mean (end)"' `"Wild-boot p (T1)"' `"Wild-boot p (T2)"' `"RI p (T1)"' `"RI p (T2)"' `"Obs"')) ///
    mtitles("Income/ha" "Log income" "Profit/ha" "Log profit" ///
            "Income/ha" "Log income" "Profit/ha" "Log profit") ///
    mgroups("Net of the share only" "Net of all land payments", pattern(1 0 0 0 1 0 0 0) ///
            prefix(\multicolumn{@span}{c}{) suffix(}) span erepeat(\cmidrule(lr){@span})) ///
    star(* 0.10 ** 0.05 *** 0.01)
di _n "=== e_farmer_share.tex written ==="
