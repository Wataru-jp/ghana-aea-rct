*==============================================================================
* het_motivation.do -- WHAT KIND OF AEA RESPONDED MORE TO THE INTERVENTIONS?
*
* SIDE ANALYSIS (Sep 2026). Nothing here feeds the deck.
*
* Question: do the treatment effects differ by the AEA's BASELINE intrinsic
* motivation? Every outcome is regressed on
*
*     y = T1 + T2 + imot + T1*imot + T2*imot + Stamp + (baseline y) + FE
*
* where imot is the AEA's baseline intrinsic motivation (panelF_A + panelF_G,
* 2-10) CENTERED at its mean, so the T1 and T2 coefficients are the effects for
* an AEA of average motivation and the interactions say how the effect changes
* per one point of motivation.
*
* IDENTIFICATION. Treatment is assigned at the district level, so the
* interaction is identified off variation in motivation BETWEEN AEAs WITHIN a
* district. Section 0 shows that 92% of the standard deviation of motivation is
* within-district, so this is not a district-composition artefact.
*
* WHAT IT IS NOT. Baseline motivation is not randomized. These are descriptive
* moderator estimates, not causal. Any pre-treatment characteristic correlated
* with motivation (experience, caseload) could be the real moderator.
*
* INFERENCE. Only 8 districts, and no wild bootstrap or randomization inference
* is applied to the interaction terms, so the p-values below are an optimistic
* bound. 24 interactions are tested; treat anything outside hired labour,
* satisfaction and contacts as supporting evidence only.
*
* Requires (run do/run_endline_all.do first):
*   tmp/a_AEA_base_lags.dta       baseline AEA scales
*   tmp/a_AEA_endline_analysis.dta AEA panel, rainfed sites
*   tmp/farmer_e_analysis.dta     farmer endline, rainfed sites
*   tmp/farmer_aid_xy.dta         hhID -> aid crosswalk
*   tmp/bw_panel.dta              bi-weekly panel, rainfed sites
*
* Output: printed to the log only.
*==============================================================================
set more off
set linesize 250
global path "/Users/wkodama/Documents/research/ghana-aea-rct"
global tmp  "$path/tmp"

* the one thing every section needs: baseline motivation keyed on the AEA id
use "$tmp/a_AEA_base_lags.dta", clear
keep aeaID a_intrinsic_bl
rename aeaID aid
label var a_intrinsic_bl "Intrinsic motivation, baseline (2-10)"
save "$tmp/aea_mot.dta", replace


*==============================================================================
* 0. Is the moderator usable? Balance across arms and where its variance sits.
*==============================================================================
use "$tmp/a_AEA_endline_analysis.dta", clear
rename aeaID aid
merge 1:1 aid using "$tmp/aea_mot.dta", keep(3) nogen

di _n "===== (0a) baseline intrinsic motivation by arm (rainfed AEAs) ====="
tabstat a_intrinsic_bl, by(treat_dis) stat(n mean sd min max) col(stat)

di _n "===== (0b) is it balanced across arms? ====="
reg a_intrinsic_bl i.treat_dis, cluster(district)

di _n "===== (0c) by district ====="
tabstat a_intrinsic_bl, by(district) stat(n mean sd) col(stat)

di _n "===== (0d) within- vs between-district variation ====="
egen district_mean = mean(a_intrinsic_bl), by(district)
gen within = a_intrinsic_bl - district_mean
qui sum within
scalar sd_within = r(sd)
qui sum a_intrinsic_bl
scalar sd_total = r(sd)
di as txt "  within-district SD " %5.3f sd_within "   total SD " %5.3f sd_total ///
   "   share within " %4.2f sd_within/sd_total


*==============================================================================
* 1. FARM LEVEL
*==============================================================================
use "$tmp/farmer_e_analysis.dta", clear
merge 1:1 hhID using "$tmp/farmer_aid_xy.dta", keepusing(aid) keep(1 3) nogen
merge m:1 aid using "$tmp/aea_mot.dta", keep(1 3) nogen
qui count if a_intrinsic_bl==.
di _n "farmers with no baseline-motivation match (should be 0): " r(N)

qui sum a_intrinsic_bl
scalar mot_sd = r(sd)
gen imot = a_intrinsic_bl - r(mean)
label var imot "Intrinsic motivation (baseline, centered)"
di as txt "farmer-level SD of the moderator: " %5.3f mot_sd

* One program, and it only does the printing: run the regression, then read the
* five coefficients of interest out of r(table). Nothing else is hidden.
capture program drop show_het
program define show_het
    args y ylag
    qui reg `y' i.treat_dis##c.imot i.gps `ylag' i.prov, cluster(district)
    matrix A = r(table)
    di as txt %-13s "`y'" ///
       " | T1 "    %10.3f A[1,colnumb(A,"1.treat_dis")]        " (" %5.3f A[4,colnumb(A,"1.treat_dis")]        ")" ///
       " | T2 "    %10.3f A[1,colnumb(A,"2.treat_dis")]        " (" %5.3f A[4,colnumb(A,"2.treat_dis")]        ")" ///
       " | imot "  %9.3f  A[1,colnumb(A,"imot")]               " (" %5.3f A[4,colnumb(A,"imot")]               ")" ///
       " | T1xI "  %9.3f  A[1,colnumb(A,"1.treat_dis#c.imot")] " (" %5.3f A[4,colnumb(A,"1.treat_dis#c.imot")] ")" ///
       " | T2xI "  %9.3f  A[1,colnumb(A,"2.treat_dis#c.imot")] " (" %5.3f A[4,colnumb(A,"2.treat_dis#c.imot")] ")" ///
       " | N " %5.0f e(N)
end

di _n "===== (1) FARM LEVEL: coefficient (p-value) ====="
di as txt "  T1/T2 are the effects at the MEAN of motivation; T1xI/T2xI are per point of motivation"
show_het rev_ha       rev_ha_bl
show_het rincome_ha   rincome_ha_bl
show_het finc_ha      finc_ha_bl
show_het lfinc        lfinc_bl
show_het yield        yield_bl
show_het lnyield      lnyield_bl
show_het nonprod      nonprod_bl
show_het u_fert       u_fert_bl
show_het u_her        u_her_bl
show_het u_machine    u_machine_bl
show_het hired_ha     hired_ha_bl
show_het famd_ha      famd_ha_bl
show_het u_impany     u_impany_bl
show_het u_seedtreat  u_seedtreat_bl
show_het nprac        nprac_bl

* The interaction is easier to read as two effects: one for an AEA a standard
* deviation BELOW the mean, one for an AEA a standard deviation ABOVE it.
capture program drop show_lowhigh
program define show_lowhigh
    args y ylag
    qui reg `y' i.treat_dis##c.imot i.gps `ylag' i.prov, cluster(district)
    foreach arm in 1 2 {
        qui lincom `arm'.treat_dis + `arm'.treat_dis#c.imot*(-mot_sd)
        local low   = r(estimate)
        local low_p = 2*ttail(r(df), abs(r(estimate)/r(se)))
        qui lincom `arm'.treat_dis + `arm'.treat_dis#c.imot*(mot_sd)
        local high   = r(estimate)
        local high_p = 2*ttail(r(df), abs(r(estimate)/r(se)))
        di as txt %-13s "`y'" " | T`arm'" ///
           " | low motivation "  %10.3f `low'  " (" %5.3f `low_p'  ")" ///
           " | high motivation " %10.3f `high' " (" %5.3f `high_p' ")"
    }
end

di _n "===== (1b) FARM LEVEL: effect at mean -1 SD vs mean +1 SD of motivation ====="
show_lowhigh hired_ha  hired_ha_bl
show_lowhigh u_her     u_her_bl
show_lowhigh u_impany  u_impany_bl
show_lowhigh finc_ha   finc_ha_bl


*==============================================================================
* 2. BI-WEEKLY LEVEL (farmer x round)
*==============================================================================
use "$tmp/bw_panel.dta", clear
merge m:1 aid using "$tmp/aea_mot.dta", keep(1 3) nogen
qui count if a_intrinsic_bl==.
di _n "bi-weekly rows with no baseline-motivation match (should be 0): " r(N)

qui sum a_intrinsic_bl
scalar mot_sd_bw = r(sd)
gen imot = a_intrinsic_bl - r(mean)
label var imot "Intrinsic motivation (baseline, centered)"

* Same idea as show_het, but the bi-weekly spec uses round and province FE and
* no baseline lag. `window' is an optional single-token sample restriction,
* e.g. inrange(t,6,9) for the growing season.
capture program drop show_het_bw
program define show_het_bw
    args y window
    if "`window'"=="" qui reg `y' i.treat_dis##c.imot i.gps i.t i.province, cluster(district)
    else              qui reg `y' i.treat_dis##c.imot i.gps i.t i.province if `window', cluster(district)
    matrix A = r(table)
    di as txt %-9s "`y'" %-18s " `window'" ///
       " | T1 "   %8.3f A[1,colnumb(A,"1.treat_dis")]        " (" %5.3f A[4,colnumb(A,"1.treat_dis")]        ")" ///
       " | T2 "   %8.3f A[1,colnumb(A,"2.treat_dis")]        " (" %5.3f A[4,colnumb(A,"2.treat_dis")]        ")" ///
       " | imot " %8.3f A[1,colnumb(A,"imot")]               " (" %5.3f A[4,colnumb(A,"imot")]               ")" ///
       " | T1xI " %8.3f A[1,colnumb(A,"1.treat_dis#c.imot")] " (" %5.3f A[4,colnumb(A,"1.treat_dis#c.imot")] ")" ///
       " | T2xI " %8.3f A[1,colnumb(A,"2.treat_dis#c.imot")] " (" %5.3f A[4,colnumb(A,"2.treat_dis#c.imot")] ")" ///
       " | N " %6.0f e(N)
end

di _n "===== (2) BI-WEEKLY: coefficient (p-value) ====="
show_het_bw Q1
show_het_bw Q2
show_het_bw satisfy
show_het_bw satisfy2
show_het_bw adv_yes
show_het_bw Q1       inrange(t,2,5)
show_het_bw Q2       inrange(t,2,5)
show_het_bw Q1       inrange(t,6,9)
show_het_bw satisfy  inrange(t,6,9)

capture program drop show_lowhigh_bw
program define show_lowhigh_bw
    args y
    qui reg `y' i.treat_dis##c.imot i.gps i.t i.province, cluster(district)
    foreach arm in 1 2 {
        qui lincom `arm'.treat_dis + `arm'.treat_dis#c.imot*(-mot_sd_bw)
        local low   = r(estimate)
        local low_p = 2*ttail(r(df), abs(r(estimate)/r(se)))
        qui lincom `arm'.treat_dis + `arm'.treat_dis#c.imot*(mot_sd_bw)
        local high   = r(estimate)
        local high_p = 2*ttail(r(df), abs(r(estimate)/r(se)))
        di as txt %-9s "`y'" " | T`arm'" ///
           " | low motivation "  %8.3f `low'  " (" %5.3f `low_p'  ")" ///
           " | high motivation " %8.3f `high' " (" %5.3f `high_p' ")"
    }
end

di _n "===== (2b) BI-WEEKLY: effect at mean -1 SD vs mean +1 SD of motivation ====="
show_lowhigh_bw satisfy
show_lowhigh_bw Q2
show_lowhigh_bw adv_yes

di _n "=== het_motivation.do done ==="
