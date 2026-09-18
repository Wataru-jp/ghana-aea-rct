*==============================================================================
* Bi-weekly (Apr-Sep 2025) farmer-reported AEA effort & satisfaction tables.
* Inference: cluster-SE, wild cluster bootstrap (Webb, 9,999), RI
*==============================================================================
global path "C:/Users/kaz-takahashi/Dropbox/Ghana/Data/"
global path "/Users/wkodama/research/ghana-aea-rct/"
global base   "$path/Baseline"
global survey "$path/Biweekly survey data"
global tmp    "$path/tmp"

*---------------- data assembly (mirrors bw_Feedback_k.do) --------------------
use "$survey/R1_April survey.dta", clear
gen survey = "04-2"
tempfile stack
save `stack', replace

* rounds 2-11, appended one by one onto R1 (April)
use "$survey/R2_May survey_1.dta", clear
gen survey = "05-1"
capture tostring Q3_1_oth, replace
append using `stack'
save `stack', replace

use "$survey/R3_May survey_2.dta", clear
gen survey = "05-2"
capture tostring Q3_1_oth, replace
append using `stack'
save `stack', replace

use "$survey/R4_June survey_1.dta", clear
gen survey = "06-1"
capture tostring Q3_1_oth, replace
append using `stack'
save `stack', replace

use "$survey/R5_June survey_2.dta", clear
gen survey = "06-2"
capture tostring Q3_1_oth, replace
append using `stack'
save `stack', replace

use "$survey/R6_July survey_1.dta", clear
gen survey = "07-1"
capture tostring Q3_1_oth, replace
append using `stack'
save `stack', replace

use "$survey/R7_July survey_2.dta", clear
gen survey = "07-2"
capture tostring Q3_1_oth, replace
append using `stack'
save `stack', replace

use "$survey/R8_August survey_1.dta", clear
gen survey = "08-1"
capture tostring Q3_1_oth, replace
append using `stack'
save `stack', replace

use "$survey/R9_August survey_2.dta", clear
gen survey = "08-2"
capture tostring Q3_1_oth, replace
append using `stack'
save `stack', replace

use "$survey/R10_Sept_survey_1.dta", clear
gen survey = "09-1"
capture tostring Q3_1_oth, replace
append using `stack'
save `stack', replace

use "$survey/R11_Sept_survey_2.dta", clear
gen survey = "09-2"
capture tostring Q3_1_oth, replace
append using `stack'
save `stack', replace

encode survey, gen(t)
label var t "Month-Half"
drop district

* treatment file. The biweekly files' `aea' is a NUMERIC code equal to the
* randomization aid (verified by name audit, Jul 2026), so the merge is on
* numeric IDs; bw_Feedback_k.do's in-row string name fixes were irrelevant
* to the merge and are dropped here.
preserve
use "$base/AEA.dta", clear
keep aea gps treat_dis discode aid
rename discode district
tempfile treat
save `treat', replace
restore

rename aea aid
merge m:1 aid using `treat'
qui count if treat_dis==.
di as txt "biweekly rows without treatment after merge (must be 0): " r(N)
assert treat_dis<.
drop _merge

* outcomes.
* any_int = the round had SOME contact with the AEA, either a visit (Q1) or an
* online/face-to-face interaction (Q2). Q1 and Q2 are separate questions and
* neither nests the other: of the 4,252 rounds, 791 have a visit but no logged
* interaction and 236 an interaction but no visit. Q3_2 (helpful advice?) and Q4
* (satisfaction) were both administered under exactly this union -- 2,221 rounds
* -- so conditioning on Q1>0 alone (satisfaction) or Q2>0 alone (advice) dropped
* valid answers and made the two tables rest on different samples. Unified on
* any_int at the co-authors' request (Sep 2026).
gen any_int  = (Q1 > 0 | Q2 > 0)
gen Q4_2 = Q4
replace Q4_2 = . if any_int == 0
gen visit    = (Q1 > 0)
gen interact = (Q2 > 0)
gen satisfy  = (Q4 == 4 | Q4 == 5)
replace satisfy = . if Q4_2 == .
* satisfy2 counts a round with no contact at all as "not satisfied", so it is
* defined on all 4,252 rounds.
gen satisfy2 = satisfy
replace satisfy2 = 0 if satisfy2==.
* irrigation schemes on the CURRENT AEA.dta discode: 3 = Kpong, 8 = Ketu North
* (Weta). bw_Feedback_k.do's (6|7) matched an OLDER discode numbering and on
* current data would wrongly flag Krachi West (6) and Biakoye (7).
gen irrgsch = (district==3 | district==8)
* SAMPLE = RAINFED SITES ONLY (co-author decision, Sep 2026), matching the farmer
* and AEA analyses: the two scheme districts hold 2 AEAs, both in the control
* arm. Drops 4,252 -> 4,120 farmer-rounds and 10 -> 8 clusters.
drop if irrgsch==1
qui count
di as txt "bi-weekly rows after dropping the irrigation schemes: " r(N)
gen t1m = (treat_dis==1)
gen t2m = (treat_dis==2)

* distance from the AEA to THIS farmer's community (do/aea_distance.do).
* ln(1+km) because 80 farmers sit within 50 m of the AEA's recorded point while
* the maximum is 62 km; raw km would be driven by the long right tail and plain
* ln by the near-zero mass.
preserve
    use "$tmp/farmer_dist.dta", clear
    rename hhID farmer
    keep farmer dist_km
    tempfile fdist
    save `fdist'
restore
merge m:1 farmer using `fdist', keep(1 3) nogen
gen dist = ln(1 + dist_km)
label var dist "Distance (log km)"
qui count if dist==.
di as txt "bi-weekly rows without a distance (dropped from the effort table): " r(N)

label var Q1 "Number visits (2 weeks)"
label var Q2 "Number contacts (2 weeks)"

*---------------- estimation: clustered SE + wild-boot + RI -------------------
* addctl: pass "yes" to add Q1 Q2 as controls (satisfaction spec m3)
capture program drop bw_one
program define bw_one
    args y name addctl wcond
    * wcond: optional sample window, e.g. inrange(t,2,5) = rounds 05-1..06-2
    * (t encodes survey chronologically: 1=04-2, 2=05-1, ..., 11=09-2)
    local xctl ""
    if "`addctl'"=="yes" local xctl "Q1 Q2"
    local iff ""
    if "`wcond'"!="" local iff "if `wcond'"
    if "`wcond'"=="" qui sum `y' if treat_dis==0 & t==1
    else             qui sum `y' if treat_dis==0 & `wcond'
    scalar cm = r(mean)
    qui reg `y' i.treat_dis i.gps `xctl' i.t i.province `iff', cluster(district)
    qui boottest 1.treat_dis, reps(9999) weight(webb) nograph
    scalar wbt1 = r(p)
    qui boottest 2.treat_dis, reps(9999) weight(webb) nograph
    scalar wbt2 = r(p)
    set seed 12345
    qui randcmd ((t1m t2m) reg `y' t1m t2m gps `xctl' i.t i.province `iff', cluster(district)), ///
        reps(1000) treatvars(t1m t2m)
    matrix ripv = e(RCoef)
    scalar rit1 = ripv[1,6]
    scalar rit2 = ripv[2,6]
    eststo `name': reg `y' i.treat_dis i.gps `xctl' i.t i.province `iff', cluster(district)
    qui test 1.treat_dis = 2.treat_dis
    estadd scalar t12p = r(p)
    estadd scalar cmean = cm
    estadd scalar wb_t1 = wbt1
    estadd scalar wb_t2 = wbt2
    estadd scalar ri_t1 = rit1
    estadd scalar ri_t2 = rit2
end

* bw_int: same spec plus distance interacted with T1, T2 and the stamp arm.
* RI is not reported here: randcmd permutes t1m/t2m but cannot rebuild the
* interaction terms from the permuted assignment, so the RI columns would be
* wrong. Cluster SE and wild-boot on the main effects are reported instead.
capture program drop bw_int
program define bw_int
    args y name addctl wcond
    local xctl ""
    if "`addctl'"=="yes" local xctl "Q1 Q2"
    local iff ""
    if "`wcond'"!="" local iff "if `wcond'"
    if "`wcond'"=="" qui sum `y' if treat_dis==0 & t==1
    else             qui sum `y' if treat_dis==0 & `wcond'
    scalar cm = r(mean)
    qui reg `y' i.treat_dis i.gps c.dist i.treat_dis#c.dist i.gps#c.dist ///
        `xctl' i.t i.province `iff', cluster(district)
    qui boottest 1.treat_dis, reps(9999) weight(webb) nograph
    scalar wbt1 = r(p)
    qui boottest 2.treat_dis, reps(9999) weight(webb) nograph
    scalar wbt2 = r(p)
    eststo `name': reg `y' i.treat_dis i.gps c.dist i.treat_dis#c.dist i.gps#c.dist ///
        `xctl' i.t i.province `iff', cluster(district)
    qui test 1.treat_dis = 2.treat_dis
    estadd scalar t12p = r(p)
    estadd scalar cmean = cm
    estadd scalar wb_t1 = wbt1
    estadd scalar wb_t2 = wbt2
end


* --- effort table: number of visits & contacts, three seasonal windows ---
* Distance was dropped from this table at the co-authors' request (Sep 2026);
* it is still built in the panel and can be re-added via bw_int if needed.
eststo clear
bw_one Q1  eQ1
bw_one Q2  eQ2
* planting/establishment window: rounds 05-1..06-2 (t = 2..5)
bw_one Q1  wQ1  "" inrange(t,2,5)
bw_one Q2  wQ2  "" inrange(t,2,5)
* growing/harvest window: rounds 07-1..09-2 (t = 6..11)
bw_one Q1  hQ1  "" inrange(t,6,9)
bw_one Q2  hQ2  "" inrange(t,6,9)
esttab eQ1 eQ2 wQ1 wQ2 hQ1 hQ2 using "$tmp/bw_effort_v2.tex", replace ///
    se nogap b(%9.3f) label booktabs nonotes ///
    keep(1.treat_dis 2.treat_dis 1.gps) ///
    order(1.treat_dis 2.treat_dis 1.gps) ///
    coeflabels(1.treat_dis "T1: Feedback" 2.treat_dis "T2: Feedback+Training" ///
               1.gps "Stamp (GPS)") ///
    stats(t12p cmean wb_t1 wb_t2 ri_t1 ri_t2 N, fmt(%9.3f %9.3f %9.3f %9.3f %9.3f %9.3f %9.0g) ///
          labels("T1=T2 [p]" "Control mean" "Wild-boot p (T1)" "Wild-boot p (T2)" "RI p (T1)" "RI p (T2)" "Obs")) ///
    mtitles("Visits" "Contacts" "Visits" "Contacts" "Visits" "Contacts") ///
    mgroups("All rounds (Apr--Sep)" "Planting window (05-1--06-2)" "Growing season (07-1--08-2)", ///
            pattern(1 0 1 0 1 0) prefix(\multicolumn{@span}{c}{) suffix(}) span erepeat(\cmidrule(lr){@span})) ///
    star(* 0.10 ** 0.05 *** 0.01)

* --- satisfaction table: base + full sample, each with/without add. controls,
*     across three seasonal windows ---
eststo clear
bw_one satisfy  esat
bw_one satisfy2 esat2
bw_one satisfy  asat  yes
bw_one satisfy2 asat2 yes
* planting/establishment window: rounds 05-1..06-2 (t = 2..5)
bw_one satisfy  wsat   ""  inrange(t,2,5)
bw_one satisfy2 wsat2  ""  inrange(t,2,5)
bw_one satisfy  wasat  yes inrange(t,2,5)
bw_one satisfy2 wasat2 yes inrange(t,2,5)
* growing/harvest window: rounds 07-1..09-2 (t = 6..11)
bw_one satisfy  hsat   ""  inrange(t,6,9)
bw_one satisfy2 hsat2  ""  inrange(t,6,9)
bw_one satisfy  hasat  yes inrange(t,6,9)
bw_one satisfy2 hasat2 yes inrange(t,6,9)
esttab esat esat2 asat asat2 wsat wsat2 wasat wasat2 hsat hsat2 hasat hasat2 ///
    using "$tmp/bw_satisfy_v2.tex", replace ///
    se nogap b(%9.3f) label booktabs nonotes ///
    keep(1.treat_dis 2.treat_dis 1.gps Q1 Q2) ///
    order(1.treat_dis 2.treat_dis 1.gps Q1 Q2) ///
    coeflabels(1.treat_dis "T1: Feedback" 2.treat_dis "T2: Feedback+Training" ///
               1.gps "Stamp (GPS)") ///
    stats(t12p cmean wb_t1 wb_t2 ri_t1 ri_t2 N, fmt(%9.3f %9.3f %9.3f %9.3f %9.3f %9.3f %9.0g) ///
          labels("T1=T2 [p]" "Control mean" "Wild-boot p (T1)" "Wild-boot p (T2)" "RI p (T1)" "RI p (T2)" "Obs")) ///
    mtitles("Satisfied" "Satisfied (full)" "Add.\ ctrl" "Full, add.\ ctrl" ///
            "Satisfied" "Satisfied (full)" "Add.\ ctrl" "Full, add.\ ctrl" ///
            "Satisfied" "Satisfied (full)" "Add.\ ctrl" "Full, add.\ ctrl") ///
    mgroups("All rounds (Apr--Sep)" "Planting window (05-1--06-2)" "Growing season (07-1--08-2)", ///
            pattern(1 0 0 0 1 0 0 0 1 0 0 0) prefix(\multicolumn{@span}{c}{) suffix(}) span erepeat(\cmidrule(lr){@span})) ///
    star(* 0.10 ** 0.05 *** 0.01)

*==============================================================================
* APPENDIX (co-author request, Jul 2026)
* A. FB/TR reparameterization: FB = 1{T1 or T2}, TR = 1{T2}.
*    Same regression as above, reparameterized: coef(FB) = T1 effect,
*    coef(TR) = incremental training effect (T2 - T1). Wild-boot p reported
*    (RI for FB equals the main tables' RI for T1).
* B. tmp/bw_cum.dta: farmer-level cumulative visits/contacts (for 2SLS).
*==============================================================================
gen fb = (treat_dis==1 | treat_dis==2)
gen tr = (treat_dis==2)

capture program drop bw_fbtr
program define bw_fbtr
    args y name addctl wcond
    local xctl ""
    if "`addctl'"=="yes" local xctl "Q1 Q2"
    local iff ""
    if "`wcond'"!="" local iff "if `wcond'"
    if "`wcond'"=="" qui sum `y' if treat_dis==0 & t==1
    else             qui sum `y' if treat_dis==0 & `wcond'
    scalar cm = r(mean)
    qui reg `y' fb tr i.gps `xctl' i.t i.province `iff', cluster(district)
    qui boottest fb, reps(9999) weight(webb) nograph
    scalar wbf = r(p)
    qui boottest tr, reps(9999) weight(webb) nograph
    scalar wbt = r(p)
    set seed 12345
    qui randcmd ((fb tr) reg `y' fb tr gps `xctl' i.t i.province `iff', cluster(district)), ///
        reps(1000) treatvars(fb tr)
    matrix ripv = e(RCoef)
    scalar rifb = ripv[1,6]
    scalar ritr = ripv[2,6]
    eststo `name': reg `y' fb tr i.gps `xctl' i.t i.province `iff', cluster(district)
    estadd scalar cmean = cm
    estadd scalar wb_fb = wbf
    estadd scalar wb_tr = wbt
    estadd scalar ri_fb = rifb
    estadd scalar ri_tr = ritr
end


eststo clear
bw_fbtr Q1       fQ1
bw_fbtr visit    fvisit
bw_fbtr Q2       fQ2
bw_fbtr interact finteract
bw_fbtr Q1       wfQ1       "" inrange(t,2,5)
bw_fbtr visit    wfvisit    "" inrange(t,2,5)
bw_fbtr Q2       wfQ2       "" inrange(t,2,5)
bw_fbtr interact wfinteract "" inrange(t,2,5)
esttab fQ1 fvisit fQ2 finteract wfQ1 wfvisit wfQ2 wfinteract using "$tmp/bw_effort_fbtr.tex", replace ///
    se nogap b(%9.3f) label booktabs nonotes ///
    keep(fb tr 1.gps) ///
    coeflabels(fb "FB: Feedback (T1 or T2)" tr "TR: Training increment (T2 vs T1)" 1.gps "Stamp (GPS)") ///
    stats(cmean wb_fb wb_tr ri_fb ri_tr N, fmt(%9.3f %9.3f %9.3f %9.3f %9.3f %9.0g) ///
          labels("Control mean" "Wild-boot p (FB)" "Wild-boot p (TR)" "RI p (FB)" "RI p (TR)" "Obs")) ///
    mtitles("Number visits" "At least 1 visit" "Number contacts" "At least 1 contact" ///
            "Number visits" "At least 1 visit" "Number contacts" "At least 1 contact") ///
    mgroups("All rounds (Apr--Sep)" "Planting window (05-1--06-2)", pattern(1 0 0 0 1 0 0 0) ///
            prefix(\multicolumn{@span}{c}{) suffix(}) span erepeat(\cmidrule(lr){@span})) ///
    star(* 0.10 ** 0.05 *** 0.01)

eststo clear
bw_fbtr satisfy  fsat
bw_fbtr satisfy2 fsat2
bw_fbtr satisfy  fasat  yes
bw_fbtr satisfy2 fasat2 yes
bw_fbtr satisfy  wfsat  ""  inrange(t,2,5)
bw_fbtr satisfy2 wfsat2 ""  inrange(t,2,5)
bw_fbtr satisfy  wfasat  yes inrange(t,2,5)
bw_fbtr satisfy2 wfasat2 yes inrange(t,2,5)
esttab fsat fsat2 fasat fasat2 wfsat wfsat2 wfasat wfasat2 using "$tmp/bw_satisfy_fbtr.tex", replace ///
    se nogap b(%9.3f) label booktabs nonotes ///
    keep(fb tr 1.gps Q1 Q2) ///
    coeflabels(fb "FB: Feedback (T1 or T2)" tr "TR: Training increment (T2 vs T1)" 1.gps "Stamp (GPS)") ///
    stats(cmean wb_fb wb_tr ri_fb ri_tr N, fmt(%9.3f %9.3f %9.3f %9.3f %9.3f %9.0g) ///
          labels("Control mean" "Wild-boot p (FB)" "Wild-boot p (TR)" "RI p (FB)" "RI p (TR)" "Obs")) ///
    mtitles("Satisfied" "Satisfied (full)" "Add.\ ctrl" "Full, add.\ ctrl" ///
            "Satisfied" "Satisfied (full)" "Add.\ ctrl" "Full, add.\ ctrl") ///
    mgroups("All rounds (Apr--Sep)" "Planting window (05-1--06-2)", pattern(1 0 0 0 1 0 0 0) ///
            prefix(\multicolumn{@span}{c}{) suffix(}) span erepeat(\cmidrule(lr){@span})) ///
    star(* 0.10 ** 0.05 *** 0.01)

* B. farmer-level cumulative extension intensity over the 11 rounds
preserve
gen Q1w = Q1 if inrange(t,2,5)
gen Q2w = Q2 if inrange(t,2,5)
* May-June satisfaction (rounds 05-1..06-2): level (1-5, rounds with a visit or
* an interaction only) and unconditional share of rounds satisfied (a round with
* no contact at all counts as 0)
gen satlvl_w = Q4_2     if inrange(t,2,5)
gen satsh_w  = satisfy2 if inrange(t,2,5)
collapse (sum) cumQ1=Q1 cumQ2=Q2 cumQ1w=Q1w cumQ2w=Q2w ///
         (mean) msat=satlvl_w msat2=satsh_w msatall=Q4_2, by(farmer)
drop if farmer==.
rename farmer hhID
label var cumQ1  "Cumulative visits (Apr--Sep)"
label var cumQ2  "Cumulative contacts (Apr--Sep)"
label var cumQ1w "Cumulative visits (05-1--06-2)"
label var cumQ2w "Cumulative contacts (05-1--06-2)"
label var msat   "Mean satisfaction level (05-1--06-2)"
label var msatall "Mean satisfaction level (Apr--Sep)"
label var msat2  "Share of rounds satisfied (05-1--06-2)"
save "$tmp/bw_cum.dta", replace
di "bw_cum saved: N farmers = " _N
restore

*==============================================================================
* CONTENT of the farmer-AEA interaction (Jul 2026). Two panels:
*   A. what the interaction produced / was about (rows with any contact)
*      Q3_2 = "did your AEA give you helpful advice?" (1 yes / 2 no /
*      3 I had no problem or question); Q3_1_a/_b = topic crop / livestock.
*   B. themes mentioned in the open-ended satisfaction reason (Q5), coded by
*      keyword search over the lower-cased text (rows with any text).
* Same specification and inference as the other bi-weekly tables.
*==============================================================================
gen interact_any = any_int
* the three answers are mutually exclusive and must sum to one, so the two rows
* that were asked Q3_2 but left it blank are excluded rather than coded 0/0/0.
gen adv_yes    = (Q3_2==1) if interact_any==1 & Q3_2<.
gen adv_no     = (Q3_2==2) if interact_any==1 & Q3_2<.
gen adv_noprob = (Q3_2==3) if interact_any==1 & Q3_2<.
gen topic_crop = (Q3_1_a==1) if interact_any==1
gen topic_live = (Q3_1_b==1) if interact_any==1
label var adv_yes    "Got helpful advice (=1)"
label var adv_no     "No helpful advice (=1)"
label var adv_noprob "Had no problem to raise (=1)"
label var topic_crop "Topic: crop production (=1)"
label var topic_live "Topic: livestock (=1)"

gen __s5 = lower(Q5)
gen has_text = (__s5!="" & __s5!=".")
gen m_advice = (strpos(__s5,"advi")>0 | strpos(__s5,"teach")>0 | strpos(__s5,"taught")>0 | ///
                strpos(__s5,"train")>0 | strpos(__s5,"practice")>0) if has_text
gen m_resp   = (strpos(__s5,"respond")>0 | strpos(__s5,"call")>0 | strpos(__s5,"phone")>0 | ///
                strpos(__s5,"available")>0 | strpos(__s5,"timely")>0 | strpos(__s5,"time")>0) if has_text
gen m_input  = (strpos(__s5,"fertili")>0 | strpos(__s5,"seed")>0 | strpos(__s5,"input")>0 | ///
                strpos(__s5,"chemical")>0 | strpos(__s5,"weedic")>0 | strpos(__s5,"herbic")>0) if has_text
gen m_pest   = (strpos(__s5,"pest")>0 | strpos(__s5,"disease")>0 | strpos(__s5,"army")>0 | ///
                strpos(__s5,"worm")>0 | strpos(__s5,"bird")>0) if has_text
gen m_attit  = (strpos(__s5,"friend")>0 | strpos(__s5,"affab")>0 | strpos(__s5,"hardworking")>0 | ///
                strpos(__s5,"hard working")>0 | strpos(__s5,"kind")>0 | strpos(__s5,"polite")>0 | ///
                strpos(__s5,"caring")>0) if has_text
gen m_visit  = (strpos(__s5,"visit")>0 | strpos(__s5,"come")>0) if has_text
gen m_neg    = (strpos(__s5,"not ")>0 | strpos(__s5,"n't")>0 | strpos(__s5,"never")>0 | ///
                strpos(__s5,"rare")>0 | strpos(__s5,"hardly")>0 | strpos(__s5,"seldom")>0) if has_text
label var m_advice "Advice/training"
label var m_resp   "Responsiveness"
label var m_input  "Inputs"
label var m_pest   "Pests/disease"
label var m_attit  "Attitude"
label var m_visit  "Visit frequency"
label var m_neg    "Negative wording"

eststo clear
bw_one adv_yes    cA1
bw_one adv_no     cA2
bw_one adv_noprob cA3
esttab cA1 cA2 cA3 using "$tmp/bw_content_a.tex", replace ///
    se nogap b(%9.3f) label booktabs nonotes ///
    keep(1.treat_dis 2.treat_dis 1.gps) ///
    order(1.treat_dis 2.treat_dis 1.gps) ///
    coeflabels(1.treat_dis "T1: Feedback" 2.treat_dis "T2: Feedback+Training" 1.gps "Stamp (GPS)" ///
               dist "Distance (log km)" ///
               1.treat_dis#c.dist "T1 $\times$ Distance" 2.treat_dis#c.dist "T2 $\times$ Distance" ///
               1.gps#c.dist "Stamp $\times$ Distance") ///
    stats(t12p cmean wb_t1 wb_t2 ri_t1 ri_t2 N, fmt(%9.3f %9.3f %9.3f %9.3f %9.3f %9.3f %9.0g) ///
          labels("T1=T2 [p]" "Ctrl mean" "Wild-boot p (T1)" "Wild-boot p (T2)" "RI p (T1)" "RI p (T2)" "Obs")) ///
    mtitles("Helpful advice (=1)" "No advice (=1)" "Had no problem (=1)") ///
    star(* 0.10 ** 0.05 *** 0.01)

eststo clear
bw_one m_advice cB1
bw_one m_resp   cB2
bw_one m_input  cB3
bw_one m_pest   cB4
bw_one m_attit  cB5
bw_one m_visit  cB6
bw_one m_neg    cB7
esttab cB1 cB2 cB3 cB4 cB5 cB6 cB7 using "$tmp/bw_content_b.tex", replace ///
    se nogap b(%9.3f) label booktabs nonotes ///
    keep(1.treat_dis 2.treat_dis 1.gps) ///
    order(1.treat_dis 2.treat_dis 1.gps) ///
    coeflabels(1.treat_dis "T1: Feedback" 2.treat_dis "T2: Feedback+Training" 1.gps "Stamp (GPS)" ///
               dist "Distance (log km)" ///
               1.treat_dis#c.dist "T1 $\times$ Distance" 2.treat_dis#c.dist "T2 $\times$ Distance" ///
               1.gps#c.dist "Stamp $\times$ Distance") ///
    stats(t12p cmean wb_t1 wb_t2 ri_t1 ri_t2 N, fmt(%9.3f %9.3f %9.3f %9.3f %9.3f %9.3f %9.0g) ///
          labels("T1=T2 [p]" "Ctrl mean" "Wild-boot p (T1)" "Wild-boot p (T2)" "RI p (T1)" "RI p (T2)" "Obs")) ///
    mtitles("Advice/training" "Responsive" "Inputs" "Pests" "Attitude" "Visits" "Negative") ///
    star(* 0.10 ** 0.05 *** 0.01)
di _n "=== bi-weekly interaction-content tables done ==="

* The estimation panel is saved so that side analyses (do/サブ/) can reuse it
* without rebuilding the 11 rounds. It carries every variable generated above:
* Q1, Q2, satisfy, satisfy2, adv_yes/_no/_noprob, the m_* keyword themes, t,
* province, district, gps, treat_dis -- rainfed sites only, 4,120 rows.
compress
save "$tmp/bw_panel.dta", replace
di "bw_panel saved, N = " _N
