*==============================================================================
* ENDLINE analogs of the Feb-2026 "Preliminary results of Correlation" tables
* (baseline versions: f_analysis.do -> tmp/f_result_table2.tex,
*  a_analysis.do -> tmp/a_result_table3.tex). Same specifications on the
* endline data. AEA demographics (gender/tenure/experience/salary/bike) are
* time-invariant baseline characteristics merged from AEA_base_tmp.
*==============================================================================
global path "/Users/wkodama/research/ghana-aea-rct/"
global tmp  "$path/tmp"

* ------------------------------ farmer ---------------------------------------
use "$tmp/farmer_e_analysis.dta", clear
gen lny           = ln(yield)
gen c_cfert_ha2   = c_cfert/landsize2
gen c_seed_ha2    = c_seed/landsize2
gen c_hire_ha2    = c_hire/landsize2
gen c_machine_ha2 = (c_combine + c_tractor + c_thresh + c_other)/landsize2
label var landsize2   "Landsize (ha)"
label var hage        "Age of household head"
label var hgen        "Gender of household head"
label var u_fert      "Chemical fertilizer (=1 yes)"
label var u_her       "Herbicide/insecticide (=1 yes)"
label var u_tractor   "Tractor (=1 yes)"
label var u_combine   "Combine harvester (=1 yes)"
label var u_thresh    "Thresher (=1 yes)"
label var u_other     "Other machinery (=1 yes)"
label var u_seedtreat "Seed treatment (=1 yes)"
label var u_simproved "Improved seed (=1 yes)"
label var u_bunds     "Bunds construction (=1 yes)"
label var u_level     "Levelling the field (=1 yes)"
* RHS now also carries the management practices shown in the adoption tables
* (co-author request, Jul 2026): improved variety, certified seed, dibbling,
* transplanting in row -- on top of the input/mechanization dummies.
label var u_impany   "Any improved variety (=1 yes)"
label var u_scertify "Certified seed (=1 yes)"
label var u_dib      "Seed dibbling (=1 yes)"
label var u_ptrans   "Transplanting in row (=1 yes)"
global controls landsize2 hage i.hedu hgen u_fert u_her u_tractor ///
                u_combine u_thresh u_other u_seedtreat u_simproved u_bunds u_level ///
                u_impany u_scertify u_dib u_ptrans
eststo clear
eststo yield:          reg yield           $controls, cluster(district)
eststo lny:            reg lny             $controls, cluster(district)
eststo rev_ha:         reg rev_ha          $controls, cluster(district)
eststo rincome_ha:     reg rincome_ha      $controls, cluster(district)
eststo finc_ha:        reg finc_ha         $controls, cluster(district)
eststo c_cfert_ha2:    reg c_cfert_ha2     $controls, cluster(district)
eststo c_seed_ha2:     reg c_seed_ha2      $controls, cluster(district)
eststo c_hire_ha2:     reg c_hire_ha2      $controls, cluster(district)
eststo c_machine_ha2:  reg c_machine_ha2   $controls, cluster(district)
esttab yield lny rev_ha rincome_ha finc_ha c_cfert_ha2 c_seed_ha2 c_hire_ha2 c_machine_ha2 ///
    using "$tmp/f_result_table2_e.tex", replace ///
    se nogap b(%4.3f) nonotes label modelwidth(5) ///
    drop(0.hedu) ///
    s(N, fmt(%9.0g) labels("Obs")) ///
    mlabel("Yield" "Log (Yield)" "Revenue (ha)" "Income (ha)" "Profit (ha)" "Fertilizer (ha)" "Seed (ha)" "Hired labor(ha)" "Machinery (ha)") ///
    star(* 0.10 ** 0.05 *** 0.01)

* ------------------------------ AEA ------------------------------------------
use "$tmp/a_AEA_sum.dta", clear
keep aid a_gender a_tenure a_exp a_salary a_bike
rename aid aeaID
tempfile dem
save `dem'
use "$tmp/a_AEA_endline_analysis.dta", clear
merge 1:1 aeaID using `dem', keep(3) nogen
eststo clear
eststo c1: reg a_prosocial a_gender a_tenure a_exp a_salary a_bike a_knowledge a_intrinsic a_extrinsic2 a_locus_gen a_locus_spec, r
eststo c2: reg a_intrinsic a_prosocial a_gender a_tenure a_exp a_salary a_bike a_knowledge a_extrinsic2 a_locus_gen a_locus_spec, r
eststo c3: reg a_extrinsic2 a_intrinsic a_prosocial a_gender a_tenure a_exp a_salary a_bike a_knowledge a_locus_gen a_locus_spec, r
eststo c4: reg a_locus_gen a_extrinsic2 a_intrinsic a_prosocial a_gender a_tenure a_exp a_salary a_bike a_knowledge a_locus_spec, r
eststo c5: reg a_locus_spec a_locus_gen a_extrinsic2 a_intrinsic a_prosocial a_gender a_tenure a_exp a_salary a_bike a_knowledge, r
esttab c1 c2 c3 c4 c5 using "$tmp/a_result_table3_e.tex", ///
    se nogap b(%4.3f) nonotes label modelwidth(5) ///
    mlabel("Prosocial" "Intrinsic" "Extrinsic" "Locus (Gen)" "Locus (Agri)") ///
    star(* 0.10 ** 0.05 *** 0.01) replace

* ---------------- correlates of practice adoption (endline) ------------------
use "$tmp/farmer_e_analysis.dta", clear
label var landsize2 "Landsize (ha)"
label var hage      "Age of household head"
label var hgen      "Gender of household head"
capture label var hhsize  "Household size"
capture label var o_total "Total assets owned"
eststo clear
eststo u_impany:    reg u_impany     landsize2 hage i.hedu hgen hhsize o_total, cluster(district)
eststo u_scertify:  reg u_scertify   landsize2 hage i.hedu hgen hhsize o_total, cluster(district)
eststo u_seedtreat: reg u_seedtreat  landsize2 hage i.hedu hgen hhsize o_total, cluster(district)
eststo u_dib:       reg u_dib        landsize2 hage i.hedu hgen hhsize o_total, cluster(district)
eststo u_ptrans:    reg u_ptrans     landsize2 hage i.hedu hgen hhsize o_total, cluster(district)
eststo u_bunds:     reg u_bunds      landsize2 hage i.hedu hgen hhsize o_total, cluster(district)
eststo u_level:     reg u_level      landsize2 hage i.hedu hgen hhsize o_total, cluster(district)
eststo nprac:       reg nprac        landsize2 hage i.hedu hgen hhsize o_total, cluster(district)
esttab u_impany u_scertify u_seedtreat u_dib u_ptrans u_bunds u_level nprac ///
    using "$tmp/f_result_pracadopt_e.tex", replace ///
    se nogap b(%4.3f) nonotes label modelwidth(5) ///
    drop(0.hedu) ///
    s(N, fmt(%9.0g) labels("Obs")) ///
    mlabel("Any improved" "Certified" "Seed trt" "Dibbling" "Row trans" "Bunds" "Levelling" "No. practices") ///
    star(* 0.10 ** 0.05 *** 0.01)

* ------------- correlates of practice adoption (BASELINE) --------------------
* Same specification as the endline version above, on the baseline wave; the
* practice dummies come from the *_bl lags built by f_endline_analysis.do.
use "$tmp/farmer.dta", clear
drop if irrgsch==1        // rainfed sites only, as in every other estimation
merge 1:1 hhID using "$tmp/farmer_bl_out.dta", keep(3) nogen
gen landsize2 = landsize*0.4047
rename u_impany_bl u_impany
rename u_scertify_bl u_scertify
rename u_seedtreat_bl u_seedtreat
rename u_dib_bl u_dib
rename u_ptrans_bl u_ptrans
rename u_bunds_bl u_bunds
rename u_level_bl u_level
rename nprac_bl nprac
label var landsize2 "Landsize (ha)"
label var hage      "Age of household head"
label var hgen      "Gender of household head"
capture label var hhsize  "Household size"
capture label var o_total "Total assets owned"
label var u_impany    "Any improved variety (=1)"
label var u_scertify  "Certified seed (=1)"
label var u_seedtreat "Seed treatment (=1)"
label var u_dib       "Seed dibbling (=1)"
label var u_ptrans    "Transplanting in row (=1)"
label var u_bunds     "Bunds construction (=1)"
label var u_level     "Levelling (=1)"
label var nprac       "No. of practices adopted (0-7)"
eststo clear
eststo u_impany:    reg u_impany     landsize2 hage i.hedu hgen hhsize o_total, cluster(district)
eststo u_scertify:  reg u_scertify   landsize2 hage i.hedu hgen hhsize o_total, cluster(district)
eststo u_seedtreat: reg u_seedtreat  landsize2 hage i.hedu hgen hhsize o_total, cluster(district)
eststo u_dib:       reg u_dib        landsize2 hage i.hedu hgen hhsize o_total, cluster(district)
eststo u_ptrans:    reg u_ptrans     landsize2 hage i.hedu hgen hhsize o_total, cluster(district)
eststo u_bunds:     reg u_bunds      landsize2 hage i.hedu hgen hhsize o_total, cluster(district)
eststo u_level:     reg u_level      landsize2 hage i.hedu hgen hhsize o_total, cluster(district)
eststo nprac:       reg nprac        landsize2 hage i.hedu hgen hhsize o_total, cluster(district)
esttab u_impany u_scertify u_seedtreat u_dib u_ptrans u_bunds u_level nprac ///
    using "$tmp/f_result_pracadopt_b.tex", replace ///
    se nogap b(%4.3f) nonotes label modelwidth(5) ///
    drop(0.hedu) ///
    s(N, fmt(%9.0g) labels("Obs")) ///
    mlabel("Any improved" "Certified" "Seed trt" "Dibbling" "Row trans" "Bunds" "Levelling" "No. practices") ///
    star(* 0.10 ** 0.05 *** 0.01)
