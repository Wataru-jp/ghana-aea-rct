*==============================================================================
* Descriptive tables: baseline vs endline means of the REGRESSION outcomes,
* on the matched panel samples (farmers N=385, AEAs N=43).
*==============================================================================
global path "C:/Users/kaz-takahashi/Dropbox/Ghana/Data/"
global path "/Users/wkodama/Documents/research/ghana-aea-rct/"
global tmp  "$path/tmp"

capture program drop descrow
program define descrow
    args v
    tempvar tag d
    qui gen `tag' = (`v'<. & `v'_bl<.)
    qui summ `v'_bl if `tag'
    local mb = r(mean)
    local sb = r(sd)
    qui summ `v' if `tag'
    local me = r(mean)
    local se = r(sd)
    qui gen `d' = `v' - `v'_bl
    qui reg `d' if `tag', cluster(district)
    local diff = _b[_cons]
    local p    = 2*ttail(e(df_r), abs(_b[_cons]/_se[_cons]))
    local st = cond(`p'<.01,"\sym{***}",cond(`p'<.05,"\sym{**}",cond(`p'<.1,"\sym{*}","")))
    local lab : variable label `v'
    if `"`lab'"'=="" local lab "`v'"
    local fmt = cond(abs(`mb')>=100 | abs(`me')>=100, "%12.1fc", "%9.3f")
    file write H "`lab' & " `fmt' (`mb') " (" `fmt' (`sb') ") & " ///
                 `fmt' (`me') " (" `fmt' (`se') ") & " `fmt' (`diff') "`st' \\" _n
end

*---------------------------- AEA table ---------------------------------------
use "$tmp/a_AEA_endline_analysis.dta", clear
file open H using "$tmp/desc_be_aea.tex", write replace
file write H "\def\sym#1{\ifmmode^{#1}\else\(^{#1}\)\fi}" _n
file write H "\begin{tabular}{lccc}" _n "\toprule" _n
file write H " & Baseline & Endline & Diff (End--Base) \\" _n "\midrule" _n
file write H "\multicolumn{4}{l}{\textit{Attitudes / motivation}}\\" _n
foreach v in a_prosocial a_intrinsic a_extrinsic2 a_locus_spec a_locus_gen {
    descrow `v'
}
file write H "\multicolumn{4}{l}{\textit{Knowledge / self-reported effort}}\\" _n
foreach v in a_knowledge8 a_seedcount a_knowledge a_avvisit a_satisfaction {
    descrow `v'
}
file write H "\midrule" _n "Obs (panel AEAs) & 43 & 43 & \\" _n
file write H "\bottomrule" _n "\end{tabular}" _n
file close H

*---------------------------- Farmer table ------------------------------------
use "$tmp/farmer_e_analysis.dta", clear
keep if panel==1
file open H using "$tmp/desc_be_farmer.tex", write replace
file write H "\def\sym#1{\ifmmode^{#1}\else\(^{#1}\)\fi}" _n
file write H "\begin{tabular}{lccc}" _n "\toprule" _n
file write H " & Baseline & Endline & Diff (End--Base) \\" _n "\midrule" _n
file write H "\multicolumn{4}{l}{\textit{Production and income}}\\" _n
descrow yield
descrow yield_nf
descrow rev_ha
descrow rincome_ha
descrow finc_ha
descrow fincnb_ha
descrow u_fert
descrow fert_ha
descrow u_her
descrow u_machine
descrow nonprod
descrow hired_ha
descrow hired_ha_nf
descrow famd_ha
descrow famd_ha_nf
file write H "\multicolumn{4}{l}{\textit{Management-practice adoption}}\\" _n
foreach v in u_impany u_scertify u_seedtreat u_dib u_ptrans u_bunds u_level {
    descrow `v'
}
file write H "\midrule" _n "Obs (panel households) & 385 & 385 & \\" _n
file write H "\bottomrule" _n "\end{tabular}" _n
file close H

*==============================================================================
* APPENDIX: descriptives BY TREATMENT ARM, baseline & endline (6 columns)
*   tmp/desc_arm_aea.tex          AEA outcomes
*   tmp/desc_arm_farmer_noirr.tex farmer outcomes (endline sample, rainfed only)
* Cells: mean (SD); stars on T1/T2 = difference vs Control WITHIN the wave
* (district-clustered regression). Baseline cells use the *_bl lags.
*==============================================================================
capture program drop armrow6
program define armrow6
    args v
    local lab : variable label `v'
    if `"`lab'"'=="" local lab "`v'"
    file write H "`lab'"
    foreach sfx in "_bl" "" {
        qui sum `v'`sfx' if treat_dis==0
        local fmt = cond(abs(r(mean))>=100 | r(sd)>=100, "%12.1fc", "%9.3f")
        file write H " & " `fmt' (r(mean)) " (" `fmt' (r(sd)) ")"
        forvalues a = 1/2 {
            qui sum `v'`sfx' if treat_dis==`a'
            local m = r(mean)
            local sd = r(sd)
            local fmt = cond(abs(`m')>=100 | `sd'>=100, "%12.1fc", "%9.3f")
            tempvar d
            qui gen `d' = (treat_dis==`a')
            qui reg `v'`sfx' `d' if inlist(treat_dis,0,`a'), cluster(district)
            local p = 2*ttail(e(df_r), abs(_b[`d']/_se[`d']))
            local st = cond(`p'<.01,"\sym{***}",cond(`p'<.05,"\sym{**}",cond(`p'<.1,"\sym{*}","")))
            qui drop `d'
            file write H " & " `fmt' (`m') " (" `fmt' (`sd') ")`st'"
        }
    }
    file write H " \\" _n
end

capture program drop armhead6
program define armhead6
    file write H "\def\sym#1{\ifmmode^{#1}\else\(^{#1}\)\fi}" _n
    file write H "\begin{tabular}{lcccccc}" _n "\toprule" _n
    file write H " & \multicolumn{3}{c}{Baseline} & \multicolumn{3}{c}{Endline} \\" _n
    file write H "\cmidrule(lr){2-4}\cmidrule(lr){5-7}" _n
    file write H " & Control & T1 & T2 & Control & T1 & T2 \\" _n "\midrule" _n
end

capture program drop armobs6
program define armobs6
    args blvar
    file write H "\midrule" _n "Obs"
    forvalues a = 0/2 {
        qui count if treat_dis==`a' & `blvar'_bl<.
        file write H " & " %9.0f (r(N))
    }
    forvalues a = 0/2 {
        qui count if treat_dis==`a'
        file write H " & " %9.0f (r(N))
    }
    file write H " \\" _n
    file write H "\bottomrule" _n "\end{tabular}" _n
end

* ---- AEA: motivation / locus scales ----
use "$tmp/a_AEA_endline_analysis.dta", clear
file open H using "$tmp/desc_arm_aea.tex", write replace
armhead6
foreach v in a_prosocial a_intrinsic a_extrinsic2 a_locus_spec a_locus_gen {
    armrow6 `v'
}
armobs6 a_prosocial
file close H

* ---- AEA: knowledge, effort, satisfaction ----
file open H using "$tmp/desc_arm_aea_kes.tex", write replace
armhead6
armrow6 a_knowledge
armrow6 a_knowledge8
armrow6 a_train
armrow6 a_train_jica
armrow6 a_avvisit
armrow6 a_satisfaction
armobs6 a_knowledge
file close H

* ---- AEA: the two outcome blocks on one table (deck p.16) ----
* The research-seminar deck shows motivation/locus and knowledge/effort on a
* single slide; the two separate files above are still used by the full
* analysis deck.
file open H using "$tmp/desc_arm_aea_all.tex", write replace
armhead6
foreach v in a_prosocial a_intrinsic a_extrinsic2 a_locus_spec a_locus_gen {
    armrow6 `v'
}
file write H "\midrule" _n
foreach v in a_knowledge a_knowledge8 a_train a_train_jica a_avvisit a_satisfaction {
    armrow6 `v'
}
armobs6 a_prosocial
file close H

* ---- AEA: who the agents are, by arm (baseline only) ----------------------
* These attributes are recorded once, in the baseline AEA questionnaire, so the
* table has three columns rather than the six of the outcome tables. The sample
* is the same 41 rainfed-site AEAs the estimations use.
*
* Two rows need reading with the questionnaire in hand. "Studied agriculture" is
* a yes/no question asked after education level; the level itself is left out
* because all 44 AEAs answered college/university (none answered vocational), so
* the row carries no information. "Professional grade or above" is the civil
* service grade ladder, which tracks qualification rather than tenure:
* 1 technical class (certificate), 2 sub-professional (HND, diploma),
* 3 professional (degree holder), 4 expert (master's). Whether the post is a
* permanent one is the separate working-tenure question, reported above it.
capture program drop charrow3
program define charrow3
    args v lab
    file write H "`lab'"
    qui sum `v' if treat_dis==0
    local fmt = cond(abs(r(mean))>=100 | r(sd)>=100, "%12.1fc", "%9.3f")
    file write H " & " `fmt' (r(mean)) " (" `fmt' (r(sd)) ")"
    forvalues a = 1/2 {
        qui sum `v' if treat_dis==`a'
        local m  = r(mean)
        local sd = r(sd)
        local fmt = cond(abs(`m')>=100 | `sd'>=100, "%12.1fc", "%9.3f")
        tempvar d
        qui gen `d' = (treat_dis==`a')
        qui reg `v' `d' if inlist(treat_dis,0,`a'), cluster(discode)
        local p = 2*ttail(e(df_r), abs(_b[`d']/_se[`d']))
        local st = cond(`p'<.01,"\sym{***}",cond(`p'<.05,"\sym{**}",cond(`p'<.1,"\sym{*}","")))
        qui drop `d'
        file write H " & " `fmt' (`m') " (" `fmt' (`sd') ")`st'"
    }
    file write H " \\" _n
end

use "$path/Baseline/AEA baseline.dta", clear
rename aea aid
drop province district
merge 1:1 aid using "$path/Baseline/AEA.dta", keepusing(aea treat_dis discode) nogen
merge 1:1 aeaID using "$tmp/a_AEA_endline_analysis.dta", keepusing(aeaID) keep(3) nogen
qui count
di as txt "AEAs in the characteristics table: " r(N) "  (expected 41)"

gen byte c_female = (panelA_C == 2)
gen byte c_agedu  = (panelA_E1 == 1)
gen byte c_tenure = (panelA_F == 1)                     // vs fixed term / voluntary
gen byte c_prof   = (panelA_J >= 3) if panelA_J < .     // degree holder or above
clonevar c_age    = panelA_B
clonevar c_exp    = panelA_G
clonevar c_exphere= panelA_H
clonevar c_salary = panelA_K
clonevar c_groups = panelB_A

file open H using "$tmp/desc_arm_aea_char.tex", write replace
file write H "\def\sym#1{\ifmmode^{#1}\else\(^{#1}\)\fi}" _n
file write H "\begin{tabular}{lccc}" _n "\toprule" _n
file write H " & Control & T1 & T2 \\" _n "\midrule" _n
charrow3 c_age      "Age (years)"
charrow3 c_female   "Female (=1)"
charrow3 c_agedu    "Studied agriculture at college/university (=1)"
charrow3 c_tenure   "Tenured post (=1)"
charrow3 c_prof     "Professional grade or above, i.e. degree holder (=1)"
charrow3 c_exp      "Experience as an extension agent (years)"
charrow3 c_exphere  "\quad of which in this district (years)"
charrow3 c_groups   "Farmer groups assisted in 2024"
charrow3 c_salary   "Monthly gross salary (GHS)"
file write H "\midrule" _n "Obs"
forvalues a = 0/2 {
    qui count if treat_dis==`a'
    file write H " & " %9.0f (r(N))
}
file write H " \\" _n "\bottomrule" _n "\end{tabular}" _n
file close H
tempfile aeachar
save `aeachar'           // reused by the manuscript table at the foot of this file

* ---- baseline landsize/irrigated lags (for the by-arm tables) ----
use "$tmp/farmer.dta", clear
gen landsize2_bl = landsize*0.4047
gen hage_bl      = hage
gen hedu_bl      = hedu
gen hgen_bl      = hgen
gen hhsize_bl    = hhsize
gen o_total_bl   = o_total
gen o_equip_bl   = o_equip
keep hhID landsize2_bl hage_bl hedu_bl hgen_bl hhsize_bl o_total_bl o_equip_bl
tempfile landbl
save `landbl'

* ---- Farmer (endline sample; rainfed sites only, as in every estimation) ----
* farmer_e_analysis.dta already excludes the two irrigation schemes, so the
* separate "all sites" version of this table was retired in Sep 2026.
use "$tmp/farmer_e_analysis.dta", clear
merge 1:1 hhID using `landbl', keep(1 3) nogen
label var landsize2 "Landsize (ha)"
label var hage      "Head: age (years)"
label var hedu      "Head: education level"
label var hgen      "Head: female (=1)"
label var hhsize    "Household size"
* Two control households hold 1.6 and 2.0 million GHS at baseline (hhID 69 and
* 305) and on their own move the control mean; they are excluded from the asset
* rows only (co-author decision, Sep 2026). Everything else is left as reported.
foreach v in o_total o_equip o_total_bl o_equip_bl {
    replace `v' = . if inlist(hhID,69,305)
}
label var o_total   "Assets owned (GHS, market value)"
label var o_equip   "\quad of which productive equipment (GHS)"
file open H using "$tmp/desc_arm_farmer_noirr.tex", write replace
armhead6
file write H "\multicolumn{7}{l}{\textit{Farm and household characteristics}}\\" _n
armrow6 landsize2
armrow6 hage
armrow6 hedu
armrow6 hgen
armrow6 hhsize
armrow6 o_total
armrow6 o_equip
file write H "\multicolumn{7}{l}{\textit{Inputs}}\\" _n
armrow6 squant_ha
armrow6 u_fert
armrow6 fert_ha
armrow6 u_her
armrow6 u_machine
armrow6 u_tractor
armrow6 u_combine
armrow6 u_thresh
armrow6 u_other
armrow6 hired_ha
armrow6 hired_ha_nf
armrow6 famd_ha
armrow6 famd_ha_nf
armobs6 yield
file close H
tempfile farmprep
save `farmprep'          // reused by the manuscript table at the foot of this file

file open H using "$tmp/desc_arm_farmer_noirr_b.tex", write replace
armhead6
file write H "\multicolumn{7}{l}{\textit{Production and income}}\\" _n
armrow6 nonprod
armrow6 yield
armrow6 yield_nf
armrow6 rev_ha
armrow6 rincome_ha
armrow6 finc_ha
armrow6 fincnb_ha
file write H "\multicolumn{7}{l}{\textit{Technology adoption}}\\" _n
armrow6 u_impany
armrow6 u_scertify
armrow6 u_seedtreat
armrow6 u_dib
armrow6 u_ptrans
armrow6 u_bunds
armrow6 u_level
armobs6 yield
file close H

*==============================================================================
* District sample-size table, BASELINE vs ENDLINE -> tmp/obs_data2.tex
* (unified deck, Jul 2026). Farmers from the two Cover files; AEAs from
* Baseline/AEA.dta and tmp/a_AEA_endline_analysis.dta.
*==============================================================================
local keys pru sene achiase kpong manya biakoye krachi ketu bibiani sefwi

use "$path/Baseline/Cover_v2.dta", clear
decode district, gen(__dn)
replace __dn = lower(__dn)
foreach k of local keys {
    qui count if strpos(__dn,"`k'")>0
    scalar fb_`k' = r(N)
}
use "$path/Endline/Cover.dta", clear
decode district, gen(__dn)
replace __dn = lower(__dn)
foreach k of local keys {
    qui count if strpos(__dn,"`k'")>0
    scalar fe_`k' = r(N)
}
use "$path/Baseline/AEA.dta", clear
gen __dn = lower(district)
foreach k of local keys {
    qui count if strpos(__dn,"`k'")>0
    scalar ab_`k' = r(N)
}
* full 43-AEA file: this table describes what was SURVEYED, including the two
* irrigation districts that every estimation then drops.
use "$tmp/a_AEA_endline_full.dta", clear
gen __dn = ""
replace __dn="sene"    if district==1
replace __dn="pru"     if district==2
replace __dn="kpong"   if district==3
replace __dn="manya"   if district==4
replace __dn="achiase" if district==5
replace __dn="krachi"  if district==6
replace __dn="biakoye" if district==7
replace __dn="ketu"    if district==8
replace __dn="bibiani" if district==9
replace __dn="sefwi"   if district==10
foreach k of local keys {
    qui count if __dn=="`k'"
    scalar ae_`k' = r(N)
}

* ---- ANALYSIS sample: what the estimation tables actually use ----
* Farmers: the main production ANCOVA sample (rainfed sites, non-missing
* baseline lag) -- e(sample) of the first column of e_farmer_prod.tex.
* AEAs: the rainfed AEA file used by every AEA ANCOVA.
use "$tmp/farmer_e_analysis.dta", clear
qui reg rev_ha i.treat_dis i.gps rev_ha_bl i.prov, cluster(district)
gen byte inest = e(sample)
gen __dn = ""
replace __dn="sene"    if district==1
replace __dn="pru"     if district==2
replace __dn="kpong"   if district==3
replace __dn="manya"   if district==4
replace __dn="achiase" if district==5
replace __dn="krachi"  if district==6
replace __dn="biakoye" if district==7
replace __dn="ketu"    if district==8
replace __dn="bibiani" if district==9
replace __dn="sefwi"   if district==10
foreach k of local keys {
    qui count if __dn=="`k'" & inest==1
    scalar fa_`k' = r(N)
}
qui count if inest==1
scalar fa_tot = r(N)

use "$tmp/a_AEA_endline_analysis.dta", clear
gen __dn = ""
replace __dn="sene"    if district==1
replace __dn="pru"     if district==2
replace __dn="kpong"   if district==3
replace __dn="manya"   if district==4
replace __dn="achiase" if district==5
replace __dn="krachi"  if district==6
replace __dn="biakoye" if district==7
replace __dn="ketu"    if district==8
replace __dn="bibiani" if district==9
replace __dn="sefwi"   if district==10
foreach k of local keys {
    qui count if __dn=="`k'"
    scalar aa_`k' = r(N)
}
qui count
scalar aa_tot = r(N)

file open H using "$tmp/obs_data2.tex", write replace
file write H "Province & District & \multicolumn{2}{c}{Baseline} & \multicolumn{2}{c}{Endline} & \multicolumn{2}{c}{Analysis} & Treatment\\" _n
file write H " & & Farmers & AEAs & Farmers & AEAs & Farmers & AEAs & \\ \hline" _n
local R1 `""Bono East Region" "Pru West" pru C"'
local R2 `""Bono East Region" "Sene West" sene T1"'
local R3 `""Eastern Region" "Achiase" achiase T1"'
local R4 `""Eastern Region" "Kpong Irrigation" kpong C"'
local R5 `""Eastern Region" "Lower Manya" manya T2"'
local R6 `""Oti Region" "Biakoye" biakoye C"'
local R7 `""Oti Region" "Krachi West" krachi T2"'
local R8 `""Volta Region" "Ketu North" ketu C"'
local R9 `""Western North region" "Bibiani" bibiani T1"'
local R10 `""Western North region" "Sefwi Wiaoso" sefwi T2"'
forvalues r = 1/10 {
    tokenize `"`R`r''"'
    file write H "`1' & `2' & " %4.0f (fb_`3') " & " %3.0f (ab_`3') " & " %4.0f (fe_`3') " & " %3.0f (ae_`3') " & " %4.0f (fa_`3') " & " %3.0f (aa_`3') " & `4' \\" _n
}
file write H "\hline  & & 390 & 44 & 394 & 43 & " %4.0f (fa_tot) " & " %3.0f (aa_tot) " & \\ \hline" _n
file close H

*==============================================================================
* 6-col by-arm, both waves (Jul 2026): AEA locus-of-control ITEMS and
* farmer-reported AEA contact/satisfaction (replacing the baseline-only
* balance tables a_balance3 / b_balance1 on deck pp. 15-16).
*==============================================================================
* ---- AEA locus items + composite scales -> tmp/desc_arm_aea_locus.tex ----
use "$tmp/a_AEA_endline_analysis.dta", clear
preserve
use "$tmp/AEA_base_tmp.dta", clear
keep aid panelG_A panelG_B panelG_C panelG_D panelG_E ///
     panelG_F panelG_G panelG_H panelG_I panelG_J
foreach v in panelG_A panelG_B panelG_C panelG_D panelG_E ///
             panelG_F panelG_G panelG_H panelG_I panelG_J {
    local L_`v' : variable label `v'
    rename `v' `v'_bl
}
rename aid aeaID
tempfile locbl
save `locbl'
restore
merge 1:1 aeaID using `locbl', keep(1 3) nogen
foreach v in panelG_A panelG_B panelG_C panelG_D panelG_E ///
             panelG_F panelG_G panelG_H panelG_I panelG_J {
    label var `v' `"`L_`v''"'
}
file open H using "$tmp/desc_arm_aea_locus.tex", write replace
armhead6
file write H "\multicolumn{7}{l}{\textit{Agriculture / work-specific (items A--E, 1--5)}}\\" _n
foreach v in panelG_A panelG_B panelG_C panelG_D panelG_E {
    armrow6 `v'
}
file write H "\multicolumn{7}{l}{\textit{General (items F--J, 1--5)}}\\" _n
foreach v in panelG_F panelG_G panelG_H panelG_I panelG_J {
    armrow6 `v'
}
file write H "\multicolumn{7}{l}{\textit{Composite scales (5--25; internal-control items reverse-coded)}}\\" _n
armrow6 a_locus_spec   // A-E: agriculture / work-specific
armrow6 a_locus_gen    // F-J: general
armobs6 a_locus_gen
file close H

* ---- Farmer-reported contact with AEA -> tmp/desc_arm_contact.tex ----
* Built from the raw QY1-6 modules so the gate question (QY16_1: how often did
* you TRY to contact; 0 = never) can be used: successful contacts (QY16_1a) is
* recoded to 0 for never-tried farmers, and an any-contact dummy is added.
* Satisfaction level (1-5) remains conditional on contact; the satisfied dummy
* is 0 for no-contact farmers (pipeline convention, f_baseline/f_endline).
capture program drop mkcontact
program define mkcontact
    gen contact_n = QY16_1a
    replace contact_n = 0 if QY16_1==0
    gen anyc = (contact_n>0) if contact_n<.
    gen sat5 = 6-QY16_6
    gen satd = (sat5==4 | sat5==5)
    keep hhID contact_n anyc sat5 satd
end
use "$tmp/farmer_e_analysis.dta", clear
keep hhID district treat_dis
preserve
use "$path/Endline/QY1-6wet (Contact with extension worker 2025).dta", clear
mkcontact
tempfile ce
save `ce'
use "$path/Baseline/QY1-6wet (Contact with extension worker 2024).dta", clear
mkcontact
rename (contact_n anyc sat5 satd) (contact_n_bl anyc_bl sat5_bl satd_bl)
tempfile cb
save `cb'
restore
merge 1:1 hhID using `ce', keep(1 3) nogen
merge 1:1 hhID using `cb', keep(1 3) nogen
label var anyc      "Any contact with AEA (=1)"
label var contact_n "Number of contacts with AEA"
label var sat5      "Satisfaction with AEA service (1--5)"
label var satd      "Satisfied with AEA service (=1)"
file open H using "$tmp/desc_arm_contact.tex", write replace
armhead6
armrow6 anyc
armrow6 contact_n
armrow6 sat5
armrow6 satd
armobs6 satd
file close H
tempfile contactprep
save `contactprep'       // reused by the manuscript table at the foot of this file

*==============================================================================
* MANUSCRIPT TABLES. The same numbers as the by-arm tables above, collapsed
* into one AEA table and one farmer table with lettered panels, which is how
* Ghana_AEA_manuscript.tex shows them. Nothing is recomputed here: the prepared
* datasets come back from the tempfiles the blocks above left behind.
*   tmp/desc_ms_aea.tex     A characteristics, B motivation and performance
*   tmp/desc_ms_farmer.tex  A household characteristics and inputs,
*                           B production and technology, C contact with the AEA
* Panel A of the AEA table leaves the endline columns empty: those attributes
* are recorded once, in the baseline questionnaire.
*==============================================================================
capture program drop panlab
program define panlab
    args txt
    file write H "\midrule" _n "\multicolumn{7}{l}{\textbf{`txt'}} \\" _n
end

capture program drop charrow6
program define charrow6
    args v lab
    file write H "`lab'"
    qui sum `v' if treat_dis==0
    local fmt = cond(abs(r(mean))>=100 | r(sd)>=100, "%12.1fc", "%9.3f")
    file write H " & " `fmt' (r(mean)) " (" `fmt' (r(sd)) ")"
    forvalues a = 1/2 {
        qui sum `v' if treat_dis==`a'
        local m  = r(mean)
        local sd = r(sd)
        local fmt = cond(abs(`m')>=100 | `sd'>=100, "%12.1fc", "%9.3f")
        tempvar d
        qui gen `d' = (treat_dis==`a')
        qui reg `v' `d' if inlist(treat_dis,0,`a'), cluster(discode)
        local p = 2*ttail(e(df_r), abs(_b[`d']/_se[`d']))
        local st = cond(`p'<.01,"\sym{***}",cond(`p'<.05,"\sym{**}",cond(`p'<.1,"\sym{*}","")))
        qui drop `d'
        file write H " & " `fmt' (`m') " (" `fmt' (`sd') ")`st'"
    }
    file write H " &  &  &  \\" _n
end

capture program drop obsrow6
program define obsrow6
    args blvar
    file write H "\midrule" _n "Obs"
    forvalues a = 0/2 {
        qui count if treat_dis==`a' & `blvar'_bl<.
        file write H " & " %9.0f (r(N))
    }
    forvalues a = 0/2 {
        qui count if treat_dis==`a'
        file write H " & " %9.0f (r(N))
    }
    file write H " \\" _n
end

* ---- AEA ----
use `aeachar', clear
file open H using "$tmp/desc_ms_aea.tex", write replace
armhead6
file write H "\multicolumn{7}{l}{\textbf{Panel A. Agent characteristics}} \\" _n
charrow6 c_age      "Age (years)"
charrow6 c_female   "Female (=1)"
charrow6 c_agedu    "Studied agriculture at college/university (=1)"
charrow6 c_tenure   "Tenured post (=1)"
charrow6 c_prof     "Professional grade or above, i.e. degree holder (=1)"
charrow6 c_exp      "Experience as an extension agent (years)"
charrow6 c_exphere  "\quad of which in this district (years)"
charrow6 c_groups   "Farmer groups assisted in 2024"
charrow6 c_salary   "Monthly gross salary (GHS)"

use "$tmp/a_AEA_endline_analysis.dta", clear
panlab "Panel B. Motivation, knowledge and performance"
foreach v in a_prosocial a_intrinsic a_extrinsic2 a_locus_spec a_locus_gen ///
             a_knowledge a_knowledge8 a_train a_train_jica a_avvisit a_satisfaction {
    armrow6 `v'
}
armobs6 a_prosocial
file close H

* ---- Farmer ----
use `farmprep', clear
file open H using "$tmp/desc_ms_farmer.tex", write replace
armhead6
file write H "\multicolumn{7}{l}{\textbf{Panel A. Household characteristics and inputs}} \\" _n
foreach v in landsize2 hage hedu hgen hhsize o_total o_equip ///
             squant_ha u_fert fert_ha u_her u_machine u_tractor u_combine ///
             u_thresh u_other hired_ha hired_ha_nf famd_ha famd_ha_nf {
    armrow6 `v'
}
panlab "Panel B. Rice production and technology"
foreach v in nonprod yield yield_nf rev_ha rincome_ha finc_ha fincnb_ha ///
             u_impany u_scertify u_seedtreat u_dib u_ptrans u_bunds u_level {
    armrow6 `v'
}
obsrow6 yield

use `contactprep', clear
panlab "Panel C. Contact with the extension agent"
foreach v in anyc contact_n sat5 satd {
    armrow6 `v'
}
armobs6 satd
file close H

