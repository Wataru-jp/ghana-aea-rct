*==============================================================================
* Build endline AEA analysis dataset (N=43): re-measured scales + treatment.
* Mirrors do/a_baseline.do scale construction on Endline/AEA endline.dta.
* Output: tmp/a_AEA_endline.dta
*==============================================================================
global path "C:/Users/kaz-takahashi/Dropbox/Ghana/Data/"
global path "/Users/wkodama/Documents/research/ghana-aea-rct/"
global dta   "$path/Baseline"
global dta2  "$path/Endline"
global dta2r "$path/Endline/Revised data"   // contractor-revised files (Jul 2026)
global tmp   "$path/tmp"

*--- treatment / cluster crosswalk from the randomization source (Baseline/AEA)
use "$dta/AEA.dta", clear
keep aid gps treat_dis discode province
* irrigation-scheme AEAs = baseline discode 3 (Kpong) or 8 (Weta); both control.
* Defined from the AEA's own baseline record so it is consistent with treat_dis.
gen irrgsch = (discode==3 | discode==8)
rename aid aeaID
rename discode district
save "$tmp/aea_treat_xwalk.dta", replace

*--- NAME-based crosswalk: sorted-token name signature -> aid/treatment --------
* Linkage audit (Jul 2026): the ENDLINE FARMER Cover's aeaID/aea_name numeric
* codes were re-numbered by the endline CAPI for 10 AEAs and do NOT match the
* randomization aid (AEA endline.dta and all other files DO match). Files that
* need an AEA link from the endline Cover must therefore resolve the AEA by
* NAME through this crosswalk, never through the Cover's numeric code.
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

use "$dta/AEA.dta", clear
keep aid aea gps treat_dis
mksig aea sig
rename (aid treat_dis) (aid_true treat_aea)
* spelling-variant aliases observed in the endline files
expand 2 if aid_true==2,  gen(__d)   // master "Adodoadzi Tawia Maxwel" -> "..MAXWELL"
replace sig = "ADODOADZIMAXWELLTAWIA" if __d==1
drop __d
expand 2 if aid_true==15, gen(__d)   // master "Cynthia Manu" -> "CYNTHIA MANUA"
replace sig = "CYNTHIAMANUA" if __d==1
drop __d
expand 2 if aid_true==35, gen(__d)   // master "Ntoso Anane Dicksen" -> "..DICKSON"
replace sig = "ANANEDICKSONNTOSO" if __d==1
drop __d
expand 2 if aid_true==7,  gen(__d)   // master "Anane Kwabena Piani" -> "..PAINI"
replace sig = "ANANEKWABENAPAINI" if __d==1
drop __d
isid sig
keep sig aid_true treat_aea gps
save "$tmp/aea_name_xwalk.dta", replace

*--- endline AEA scales
* revised file: panelB_H reporting-period errors (aeaID 3/10/16) corrected
use "$dta2r/AEA endline.dta", clear

* Knowledge of improved rice cultivation (0-5), same correct-answer keys as baseline
* Seed selection (item A) is a MULTIPLE-response question: A1 good germination,
* A2 healthy growth, A3 minimise disease, A5 increase yield are all correct and
* A4 "avoid birds" is the distractor. The 0-5 index scores this item ALL-OR-
* NOTHING: 1 only for an AEA who named every correct purpose (co-author decision,
* Sep 2026). The old rule (A1==1 | A4!=1) was satisfied by every AEA in both
* waves and so carried no information. The 0-8 index instead gives partial credit
* through a_seedcount, the number of correct purposes named (0-4). The distractor
* is almost never chosen (1 AEA at baseline, 0 at endline), so requiring "no
* distractor" as well would change nothing.
gen a_seedselection = (panelD_A1==1 & panelD_A2==1 & panelD_A3==1 & panelD_A5==1)
gen a_level         = (panelD_B==1)
gen a_plant         = (panelD_C==5)
gen a_water         = (panelD_D==4)
gen a_dry           = (panelD_E==2)
egen a_knowledge = rsum(a_seedselection-a_dry)
* a_seedcount = how many of the four correct purposes the AEA names (0-4);
* a_knowledge8 puts the scale on 0-8 with partial credit for item A.
egen a_seedcount  = rowtotal(panelD_A1 panelD_A2 panelD_A3 panelD_A5)
egen a_knowledge8 = rowtotal(a_seedcount a_level a_plant a_water a_dry)

* Pro-socialness (6-30): items A-F
egen a_proaction  = rsum(panelE_A-panelE_D)
egen a_profeeling = rsum(panelE_E-panelE_F)
gen  a_prosocial  = a_proaction + a_profeeling

* Situational motivation (panel F)
gen a_intrinsic  = (panelF_A+panelF_G)
gen a_extrinsic1 = (panelF_B+panelF_C+panelF_D+panelF_F)
gen a_extrinsic2 = (panelF_D+panelF_F)

* Locus of control (panel G), general = A-E, specific(agri) = F-J; reverse as baseline
gen a=6-panelG_A
gen b=6-panelG_B
gen c=6-panelG_C
gen d=panelG_D
gen e=panelG_E
gen a_locus_spec = a+b+c+d+e   // items A-E: agriculture/work-specific
drop a-e
gen f=panelG_F
gen g=panelG_G
gen h=panelG_H
gen i=6-panelG_I
gen j=6-panelG_J
gen a_locus_gen = f+g+h+i+j   // items F-J: general (Rotter)
drop f-j

* Self-reported effort & job satisfaction
rename panelB_H a_avvisit         // avg. how often visited farmer groups
rename panelB_K a_satisfaction    // overall job satisfaction

label var a_prosocial   "Prosocialness (6-30)"
label var a_intrinsic   "Intrinsic motivation (2-10)"
label var a_extrinsic1  "Extrinsic motivation (4-20)"
label var a_extrinsic2  "Extrinsic motivation (2-10)"
label var a_locus_gen   "Locus: general (5-25)"
label var a_locus_spec  "Locus: agriculture (5-25)"
gen a_train = (panelC_A==1) if panelC_A<.
gen a_train_jica = (panelC_B3==1)
replace a_train_jica = 0 if a_train==0
label var a_train      "Attended rice agronomic training (=1)"
label var a_train_jica "\quad of which JICA was a provider (=1)"
label var a_knowledge   "Knowledge of rice production (0-5)"
label var a_seedcount   "Seed-selection purposes named (0-4)"
label var a_knowledge8  "Knowledge of rice production (0-8)"
label var a_avvisit     "Self-reported avg visits"
label var a_satisfaction "Job satisfaction (1-5)"

keep aeaID aea a_* panelE* panelF* panelG*

* attach treatment / cluster / irrigation flag (all from the baseline AEA record)
* (audit, Jul 2026: AEA endline.dta's aeaID DOES equal the randomization aid --
*  verified below by name -- so a direct aeaID merge is valid HERE. The endline
*  FARMER Cover's aeaID is a different numbering; farmer files must use
*  tmp/aea_name_xwalk.dta instead.)
merge 1:1 aeaID using "$tmp/aea_treat_xwalk.dta"
* _merge==2 would be the retired AEA (in baseline, not endline)
drop if _merge==2
drop _merge

* integrity check: aeaID must equal the aid resolved from the AEA's own name
preserve
capture confirm string variable aea
if _rc decode aea, gen(__aname)
else gen __aname = aea
mksig __aname sig
keep aeaID sig
merge 1:1 sig using "$tmp/aea_name_xwalk.dta", keep(1 3) keepusing(aid_true)
qui count if _merge==3 & aeaID != aid_true
if r(N)>0 {
    di as error "WARNING: AEA endline aeaID != name-resolved aid for " r(N) " AEAs"
    list aeaID aid_true if _merge==3 & aeaID != aid_true
    error 9
}
qui count if _merge==1
di as txt "AEA endline integrity: aeaID==aid confirmed; unresolved names = " r(N)
restore

save "$tmp/a_AEA_endline.dta", replace
di "a_AEA_endline built: N = " _N
