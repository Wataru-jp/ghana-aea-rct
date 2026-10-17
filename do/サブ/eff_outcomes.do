*==============================================================================
* eff_outcomes.do -- input-efficiency outcomes for the "process innovation /
* management improvement" storyline (co-author request, Oct 2026).
*
* Three families, all estimated in ONE step so that no efficiency score has to
* be produced first:
*   (1) unit cost and the value-cost ratio
*   (2) partial factor productivity (output per unit of seed, labour, fertiliser)
*   (4) distance from a recommended seed rate
*
* Specification is the farmer ANCOVA of do/f_endline_analysis.do: endline value
* on the two arm dummies, the GPS-stamp indicator, the baseline value of the
* same outcome and region fixed effects, SE clustered on district, with wild
* cluster bootstrap and randomization inference alongside.
*
* NOTE ON THE SEED-RATE BENCHMARK. No recommended rate is recorded anywhere in
* the project files, so three benchmarks are reported side by side (60 and
* 80 kg/ha, and a 50-80 band). Confirm the right one against the GRIP
* extension guideline before using any of this in the paper.
*
* Ratios are left as computed: no winsorizing, per the project convention. The
* log shows the control mean and the maximum of each ratio so that outlier
* influence can be judged.
*
* This is a side analysis; nothing in the deck or the manuscript reads it.
*==============================================================================
set more off
global path "/Users/wkodama/Documents/research/ghana-aea-rct"
global tmp  "$path/tmp"

use "$tmp/farmer_e_analysis.dta", clear

* ---------------------------------------------------------------- (1) cost
gen cost_ha    = rev_ha    - rincome_ha
gen cost_ha_bl = rev_ha_bl - rincome_ha_bl
label var cost_ha "Paid-out cost (GHS/ha)"

gen unitcost    = cost_ha    / yield    if yield    > 0 & yield    < .
gen unitcost_bl = cost_ha_bl / yield_bl if yield_bl > 0 & yield_bl < .
label var unitcost "Cost per tonne (GHS/t)"

gen vcr    = rev_ha    / cost_ha    if cost_ha    > 0 & cost_ha    < .
gen vcr_bl = rev_ha_bl / cost_ha_bl if cost_ha_bl > 0 & cost_ha_bl < .
label var vcr "Value-cost ratio"

* ------------------------------------------- (2) partial factor productivity
gen seedprod    = yield*1000    / squant_ha    if squant_ha    > 0 & squant_ha    < .
gen seedprod_bl = yield_bl*1000 / squant_ha_bl if squant_ha_bl > 0 & squant_ha_bl < .
label var seedprod "Paddy per kg of seed (kg/kg)"

gen double lab    = hired_ha    + famd_ha
gen double lab_bl = hired_ha_bl + famd_ha_bl
gen labprod    = yield*1000    / lab    if lab    > 0 & lab    < .
gen labprod_bl = yield_bl*1000 / lab_bl if lab_bl > 0 & lab_bl < .
label var labprod "Paddy per labour-day (kg/day)"

gen fertprod    = yield*1000    / fert_ha    if fert_ha    > 0 & fert_ha    < .
gen fertprod_bl = yield_bl*1000 / fert_ha_bl if fert_ha_bl > 0 & fert_ha_bl < .
label var fertprod "Paddy per kg of fertiliser (kg/kg)"

* --------------------------------------------- (4) distance from the benchmark
foreach r in 60 80 {
    gen dev`r'    = abs(squant_ha    - `r')
    gen dev`r'_bl = abs(squant_ha_bl - `r')
    label var dev`r' "|seed rate - `r'| (kg/ha)"
}
gen byte inband    = inrange(squant_ha, 50, 80)    if squant_ha    < .
gen byte inband_bl = inrange(squant_ha_bl, 50, 80) if squant_ha_bl < .
label var inband "Seed rate within 50-80 kg/ha (=1)"
gen byte over100    = (squant_ha > 100)    if squant_ha    < .
gen byte over100_bl = (squant_ha_bl > 100) if squant_ha_bl < .
label var over100 "Seed rate above 100 kg/ha (=1)"

di _n "=== distributions (endline) ==="
summarize cost_ha unitcost vcr seedprod labprod fertprod squant_ha dev60 dev80 inband over100, sep(0)
di _n "=== control-group means and maxima of the ratios ==="
foreach v in unitcost vcr seedprod labprod fertprod {
    qui sum `v' if treat_dis==0
    local m = r(mean)
    qui sum `v'
    di %-10s "`v'" "   ctrl mean " %10.1f `m' "   max " %12.1f r(max) "   N " %4.0f r(N)
}

* ----------------------------------------------------------------- estimation
capture program drop anc
program define anc
    args y ylag
    qui sum `y' if treat_dis==0
    scalar cm = r(mean)
    qui reg `y' i.treat_dis i.gps `ylag' i.prov, cluster(district)
    qui boottest 1.treat_dis, reps(9999) weight(webb) nograph
    scalar wbt1 = r(p)
    qui boottest 2.treat_dis, reps(9999) weight(webb) nograph
    scalar wbt2 = r(p)
    set seed 12345
    qui randcmd ((t1m t2m) reg `y' t1m t2m gps `ylag' i.prov, cluster(district)), ///
        reps(1000) treatvars(t1m t2m)
    matrix ripv = e(RCoef)
    scalar rit1 = ripv[1,6]
    scalar rit2 = ripv[2,6]
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
anc cost_ha  cost_ha_bl
anc unitcost unitcost_bl
anc vcr      vcr_bl
esttab cost_ha unitcost vcr, se b(%9.3f) keep(1.treat_dis 2.treat_dis 1.gps) ///
    stats(cmean wb_t1 wb_t2 ri_t1 ri_t2 N, fmt(%12.3f %9.3f %9.3f %9.3f %9.3f %9.0g)) ///
    title("(1) COST")

eststo clear
anc seedprod seedprod_bl
anc labprod  labprod_bl
anc fertprod fertprod_bl
esttab seedprod labprod fertprod, se b(%9.3f) keep(1.treat_dis 2.treat_dis 1.gps) ///
    stats(cmean wb_t1 wb_t2 ri_t1 ri_t2 N, fmt(%12.3f %9.3f %9.3f %9.3f %9.3f %9.0g)) ///
    title("(2) PARTIAL FACTOR PRODUCTIVITY")

eststo clear
anc dev60   dev60_bl
anc dev80   dev80_bl
anc inband  inband_bl
anc over100 over100_bl
esttab dev60 dev80 inband over100, se b(%9.3f) keep(1.treat_dis 2.treat_dis 1.gps) ///
    stats(cmean wb_t1 wb_t2 ri_t1 ri_t2 N, fmt(%12.3f %9.3f %9.3f %9.3f %9.3f %9.0g)) ///
    title("(4) DISTANCE FROM THE SEED-RATE BENCHMARK")

di _n "=== done ==="
