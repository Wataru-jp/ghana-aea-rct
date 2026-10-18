*==============================================================================
* sales_ancova.do -- actual sales as outcomes (co-author question, Oct 2026).
*
* The published production table uses the VALUE OF OUTPUT (production times the
* district median price), not what the household actually sold. This file uses
* the sales questions instead. Households that sold nothing are kept and coded
* zero, as requested.
*
* WHAT CAN AND CANNOT BE AN ANCOVA. The endline module asks how much was sold
* (QY11_15a_paddysold in bags, QY11_15b_kilopadsold in kg, QY11_14_kilomillsold
* for milled rice). The baseline module asks only WHETHER paddy and milled rice
* were sold -- there is no baseline quantity. So:
*   - the extensive margin (any sale) is a proper ANCOVA, with the baseline
*     dummy as the lag;
*   - the intensive margin has no lag. It is reported twice: without any lag,
*     and with baseline yield as a covariate for precision. Both are unbiased
*     because assignment is random; the first is simply less precise.
*
* Units follow do/f_endline.do: QY11_13 is the household's kg per bag, and
* prices are converted to GHS per kg before being applied.
*
* This is a side analysis; nothing in the deck or the manuscript reads it.
*==============================================================================
set more off
global path "/Users/wkodama/Documents/research/ghana-aea-rct"
global tmp  "$path/tmp"

*--- endline sales ------------------------------------------------------------
use "$path/Endline/QY1-1wet (Rice production in wet season in 2025).dta", clear
keep hhID QY11_13 QY11_12_sldpady QY11_15_pady QY11_15_mill ///
     QY11_15a_paddysold QY11_15b_kilopadsold QY11_14_kilomillsold ///
     QY11_15_pricepad QY11_15_pricpad_kg QY11_14_pricemill QY11_12_sldmill

gen paddy_kg = .
replace paddy_kg = QY11_13*QY11_15a_paddysold if QY11_12_sldpady==1
replace paddy_kg = QY11_15b_kilopadsold        if QY11_12_sldpady==2
replace paddy_kg = 0 if QY11_15_pady==0          // the dummies are 0 = No, 1 = Yes
replace paddy_kg = 0 if paddy_kg==.

gen mill_kg = QY11_14_kilomillsold
replace mill_kg = 0 if QY11_15_mill==0
replace mill_kg = 0 if mill_kg==.

* prices per kg, own where reported, district median otherwise
gen ppad_kg = QY11_15_pricepad/QY11_13 if QY11_12_sldpady==1
replace ppad_kg = QY11_15_pricpad_kg   if QY11_12_sldpady==2
gen pmil_kg = QY11_14_pricemill        if QY11_12_sldmill==1
replace pmil_kg = QY11_14_pricemill/25 if QY11_12_sldmill==3
replace pmil_kg = QY11_14_pricemill/50 if QY11_12_sldmill==4
keep hhID paddy_kg mill_kg ppad_kg pmil_kg QY11_15_pady QY11_15_mill
tempfile sales
save `sales'

*--- baseline: the extensive margin only ---------------------------------------
use "$path/Baseline/QY1-1wet (Rice production in wet season in 2024)_V2_rev2026Aug.dta", clear
keep hhID QY11_15_pady QY11_15_mill
rename (QY11_15_pady QY11_15_mill) (bl_pady bl_mill)
tempfile salesbl
save `salesbl'

*--- join to the estimation sample ---------------------------------------------
use "$tmp/farmer_e_analysis.dta", clear
merge 1:1 hhID using `sales',   keep(1 3) nogen
merge 1:1 hhID using `salesbl', keep(1 3) nogen
di "estimation sample = " _N

egen md_ppad = median(ppad_kg), by(district)
egen md_pmil = median(pmil_kg), by(district)
replace ppad_kg = md_ppad if ppad_kg==.
replace pmil_kg = md_pmil if pmil_kg==.

gen anysale    = (paddy_kg>0 | mill_kg>0)
gen anysale_bl = (bl_pady==1 | bl_mill==1)
label var anysale "Any rice sale (=1)"

gen landha = landsize2
gen paddy_ha = paddy_kg/landha
gen mill_ha  = mill_kg /landha
gen salesval_ha = (paddy_kg*ppad_kg + mill_kg*pmil_kg)/landha
label var paddy_ha    "Paddy sold (kg/ha)"
label var mill_ha     "Milled rice sold (kg/ha)"
label var salesval_ha "Value of sales (GHS/ha)"
gen salesshare = salesval_ha/rev_ha if rev_ha>0 & rev_ha<.
label var salesshare "Sales value / value of output"

di _n "=== who sells ==="
tab anysale_bl anysale, row
di _n "=== distributions ==="
summarize paddy_ha mill_ha salesval_ha salesshare rev_ha, sep(0)
bysort treat_dis: summarize anysale paddy_ha mill_ha salesval_ha

*--- estimation ---------------------------------------------------------------
capture program drop run1
program define run1
    args y lag label
    qui sum `y' if treat_dis==0
    local cm = r(mean)
    qui reg `y' i.treat_dis i.gps `lag' i.prov, cluster(district)
    local b1 = _b[1.treat_dis]
    local s1 = _se[1.treat_dis]
    local b2 = _b[2.treat_dis]
    local s2 = _se[2.treat_dis]
    local n  = e(N)
    qui boottest 1.treat_dis, reps(9999) weight(webb) nograph
    local w1 = r(p)
    qui boottest 2.treat_dis, reps(9999) weight(webb) nograph
    local w2 = r(p)
    set seed 12345
    qui randcmd ((t1m t2m) reg `y' t1m t2m gps `lag' i.prov, cluster(district)), ///
        reps(1000) treatvars(t1m t2m)
    matrix R = e(RCoef)
    di as txt "`label'"
    di as txt "   ctrl mean " %10.2f `cm' "   N " `n'
    di as txt "   T1 " %10.3f `b1' " (" %8.3f `s1' ")   wild-boot " %5.3f `w1' "   RI " %5.3f R[1,6]
    di as txt "   T2 " %10.3f `b2' " (" %8.3f `s2' ")   wild-boot " %5.3f `w2' "   RI " %5.3f R[2,6]
end

capture gen t1m = (treat_dis==1)
capture gen t2m = (treat_dis==2)

di _n "=== (1) extensive margin: ANCOVA with the baseline dummy ==="
run1 anysale anysale_bl "Any rice sale (=1)"

di _n "=== (2) intensive margin, NO lag available ==="
run1 paddy_ha    "" "Paddy sold (kg/ha)"
run1 mill_ha     "" "Milled rice sold (kg/ha)"
run1 salesval_ha "" "Value of sales (GHS/ha)"
run1 salesshare  "" "Sales value / value of output"

di _n "=== (3) same, with baseline yield as a covariate ==="
run1 paddy_ha    yield_bl "Paddy sold (kg/ha), + baseline yield"
run1 mill_ha     yield_bl "Milled rice sold (kg/ha), + baseline yield"
run1 salesval_ha yield_bl "Value of sales (GHS/ha), + baseline yield"
run1 salesshare  yield_bl "Sales share, + baseline yield"

di _n "=== done ==="

*==============================================================================
* Is the extensive margin usable? Four checks (Oct 2026).
*==============================================================================
di _n "=== (a) how the dummy is built: missingness and non-producers ==="
count if QY11_15_pady==. & QY11_15_mill==.
di "  both sale-form questions missing: " r(N)
tab nonprod anysale, row
di _n "  among households with zero output, do any report a sale?"
count if nonprod==1 & anysale==1
di "  " r(N)

di _n "=== (b) baseline balance of the sales dummy ==="
qui reg anysale_bl i.treat_dis i.gps i.prov, cluster(district)
di "  T1 " %7.3f _b[1.treat_dis] " (" %6.3f _se[1.treat_dis] ")   T2 " ///
   %7.3f _b[2.treat_dis] " (" %6.3f _se[2.treat_dis] ")"
tabstat anysale_bl anysale, by(treat_dis) stat(mean n) format(%6.3f)

di _n "=== (c) is it just the crop-failure effect? ==="
run1 anysale anysale_bl "  baseline: ANCOVA as before"
qui reg anysale i.treat_dis i.gps anysale_bl nonprod i.prov, cluster(district)
di "  + controlling for zero output:   T1 " %7.3f _b[1.treat_dis] " (" %6.3f _se[1.treat_dis] ///
   ")   T2 " %7.3f _b[2.treat_dis] " (" %6.3f _se[2.treat_dis] ")   N " e(N)
qui reg anysale i.treat_dis i.gps anysale_bl i.prov if nonprod==0, cluster(district)
di "  producers only:                  T1 " %7.3f _b[1.treat_dis] " (" %6.3f _se[1.treat_dis] ///
   ")   T2 " %7.3f _b[2.treat_dis] " (" %6.3f _se[2.treat_dis] ")   N " e(N)

di _n "=== (d) sensitivity of the specification ==="
qui reg anysale i.treat_dis i.gps anysale_bl, cluster(district)
di "  no region FE:                    T1 " %7.3f _b[1.treat_dis] " (" %6.3f _se[1.treat_dis] ///
   ")   T2 " %7.3f _b[2.treat_dis] " (" %6.3f _se[2.treat_dis] ")"
qui reg anysale i.treat_dis i.gps i.prov, cluster(district)
di "  no baseline lag:                 T1 " %7.3f _b[1.treat_dis] " (" %6.3f _se[1.treat_dis] ///
   ")   T2 " %7.3f _b[2.treat_dis] " (" %6.3f _se[2.treat_dis] ")"
qui reg anysale i.treat_dis i.gps anysale_bl yield_bl landsize2 i.prov, cluster(district)
di "  + baseline yield and landsize:   T1 " %7.3f _b[1.treat_dis] " (" %6.3f _se[1.treat_dis] ///
   ")   T2 " %7.3f _b[2.treat_dis] " (" %6.3f _se[2.treat_dis] ")   N " e(N)
qui reg anysale i.treat_dis i.gps anysale_bl i.prov, cluster(district)
qui test 1.treat_dis = 2.treat_dis
di "  T1 = T2 p = " %5.3f r(p)
