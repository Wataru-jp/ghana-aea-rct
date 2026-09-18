*==============================================================================
* f_labour_panel.do -- hhID x operation labour panel, both waves, per hectare.
* Family days = workers x days x hours / 8 (the module records hours only for
* family labour). Hired days = workers x days. Costs: family days valued at the
* district median hired wage (tmp/dwage_*), hired at the payment actually made
* (QY15_17). Output: tmp/labour_by_op.dta, used by f_labour_detail.do.
*==============================================================================
set more off
global path "/Users/wkodama/research/ghana-aea-rct"
global tmp  "$path/tmp"

* ---- areas and wages ----
use "$tmp/farmer_e_analysis.dta", clear
keep hhID treat_dis district landsize2 nonprod
tempfile ha_e
save `ha_e'
use "$tmp/farmer.dta", clear
gen ha_b = landsize*0.4047
keep hhID ha_b
merge 1:1 hhID using `ha_e', keepusing(district) keep(1 3) nogen
tempfile ha_b
save `ha_b'

* ---- one wave at a time ----
foreach w in e b {
    if "`w'"=="e" {
        use "$path/Endline/Revised data/QY1-5wet (Labor inputs-paddy)_rev2026Aug.dta", clear
        local areafile `ha_e'
        local areavar landsize2
        local wagefile "$tmp/dwage_e.dta"
    }
    else {
        use "$path/Baseline/QY1-5wet (Labor inputs-paddy)_V5.dta", clear
        local areafile `ha_b'
        local areavar ha_b
        local wagefile "$tmp/dwage_b.dta"
    }
    gen fam_m = (QY15_1b*QY15_1c*QY15_1)/8
    gen fam_f = (QY15_2a*QY15_2b*QY15_2)/8
    gen hir_m = QY15_4*QY15_5
    gen hir_f = QY15_7*QY15_8
    gen hcost = QY15_17
    foreach v in fam_m fam_f hir_m hir_f hcost {
        replace `v' = 0 if `v'==.
    }
    collapse (sum) fam_m fam_f hir_m hir_f hcost, by(hhID operation)
    merge m:1 hhID using `areafile', keep(3) nogen
    merge m:1 district using "`wagefile'", keep(1 3) nogen
    gen fam = fam_m + fam_f
    gen hir = hir_m + hir_f
    gen famcost = fam*dw
    foreach v in fam fam_m fam_f hir hir_m hir_f famcost hcost {
        replace `v' = `v'/`areavar'
    }
    keep hhID operation fam fam_m fam_f hir hir_m hir_f famcost hcost
    if "`w'"=="b" {
        foreach v in fam fam_m fam_f hir hir_m hir_f famcost hcost {
            rename `v' `v'_bl
        }
    }
    tempfile L`w'
    save `L`w''
}

use `Le', clear
merge 1:1 hhID operation using `Lb', keep(3) nogen
merge m:1 hhID using `ha_e', keepusing(treat_dis district nonprod) keep(3) nogen
label var fam   "Family labour (man-days/ha)"
label var hir   "Hired labour (man-days/ha)"
save "$tmp/labour_by_op.dta", replace
di _n "=== labour_by_op.dta: " _N " rows ==="
