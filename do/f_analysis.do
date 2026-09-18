
global path "C:\Users\kaz-takahashi\Dropbox\Ghana\Data\"
global path "/Users/wkodama/research/ghana-aea-rct/"
global dta $path/Baseline
global do $path/do
global tmp $path/tmp

* legacy block: writes tmp/obs_data.tex (the old district table). The deck now
* uses obs_data2.tex from desc_be_tables.do, and Baseline/treat_ds.dta is no
* longer in the repo, so run it only if that file happens to exist.
capture confirm file "$dta/treat_ds.dta"
if !_rc {
    use "$dta/treat_ds", clear
    listtab province district n_farmer n_aea treat_dis using "$tmp/obs_data.tex", ///
        replace ///
        delimiter("&") end("\\ ") ///
        headlines("Province & District & Farmers & AEAs & Treatment\\ \hline") ///
        footlines("\hline  & & 390 & 44 \\ \hline")
}

use "$tmp/farmer", clear

* SAMPLE = RAINFED SITES ONLY (co-author decision, Sep 2026): the two irrigation
* schemes (Kpong & Weta) are dropped from every estimation in the project.
drop if irrgsch==1
qui count
di as txt "baseline farmer sample after dropping the irrigation schemes: " r(N)

rename community communityid
merge m:1 communityid using "$dta/Population"
gen weight=baselinesamplesize/ricefarmerpopulation


dummies hedu
dummies hreligious

label var hhsize "Household size"
label var hage "Head age"
label var hedu1 "No education  (=1 yes)"
label var hedu2 "Primary education  (=1 yes)"
label var hedu3 "Junior high  (=1 yes)"
label var hedu4 "Senior high  (=1 yes)"
label var hedu5 "Tertiary edu  (=1 yes)"
label var hlit "Head literacy (=1 yes)" 
label var hgen "Head male (=1 yes)" 

label var hreligious1 "No religion (=1 yes)"
label var hreligious2 "Christian (=1 yes)"
label var hreligious3 "Islam (=1 yes)"

* リストを定義

global vars hhsize hgen hage hlit hedu1-hedu5 hreligious2-hreligious3

generate treat_A = (treat_dis==1)
generate treat_B = (treat_dis==2)
balancetable (mean if treat_dis==0) (mean if treat_dis==1) (mean if treat_dis==2) (diff treat_A if treat_dis!=2) (diff treat_B if treat_dis!=1) $vars using "$tmp/f_balance1.tex", ///
vce(cluster district) varlabels ctitles("Control" "T1" "T2" "T1 vs Control" "T2 vs Control") replace


/*
iebaltab hhsize hgen hage hlit hedu1-hedu5 hreligious1-hreligious3, ///
 grpvar(treat_dis) con(0) vce(cluster district) rowvarlabels stdev savetex("$tmp/f_balance1.tex") replace
*/


replace irrgland=0 if irrgland==2 
dummies ownership 
label var ownership1 "Owned (=1 yes)"
label var ownership2 "Leaseland (=1 yes)"
label var ownership3 "Sharecrop (=1 yes)"
label var irrgland "Irrigated (=1 yes)" 

global convert 0.4047

gen landsize2=landsize*$convert 

local cost "c_seed c_tractor c_combine c_thresh" 
foreach var of local cost {
    replace `var'=0 if `var'==.
}


gen rincome=v_totalprod-c_seed-c_tractor-c_combine-c_thresh-c_other-c_cfert-c_herbinsec-c_hire 
gen yield=totalprod_kg/1000/landsize2

local perha "fert c_seed c_cfert c_herbinsec c_hire rincome"
foreach var of local perha {
    gen `var'_ha=`var'/landsize2
}

* A stray block-comment opener used to sit here. Stata nests block comments, so
* it silently swallowed the rest of the file and left tmp/f_balance2/3.tex and
* tmp/f_result_table2.tex frozen at their February versions (removed Jul 2026).


gen u_fert=(fert!=0)
gen fert_ha2=fert_ha if fert_ha!=.
replace fert_ha2=. if fert_ha==0
gen u_her=(c_herbinsec!=0)
gen u_tractor=(c_tractor!=0)
gen u_combine=(c_combine!=0)
gen u_thresh=(c_thresh!=0)
gen u_other=(c_other!=0)

gen u_machine=(u_tractor!=0 | u_thresh!=0 | u_combine!=0 | u_other!=0) 

label var landsize2 "Landsize (ha)"
label var yield "Yield (ha)"
label var c_seed_ha "Fertilizer expenses (GHS/ha)" 
label var c_cfert_ha "Fertilizer expenses (GHS/ha)" 
label var fert_ha "Fertilizer quantity (kg/ha)" 
label var u_fert "Fertilizer use (=1 yes)"
label var fert_ha2 "Fertilizer quantity (kg/ha) if Use=1"   
label var u_machine "Machine use (=1 yes)" 
label var rincome_ha "Rice income (GHS/ha)" 
label var nonprod "Crop failure (=1 yes)" 
label var u_her "Herbicides/Insecticides use (=1 yes)" 



global var2 landsize2 ownership1-ownership3 u_fert fert_ha fert_ha2 u_her u_machine yield nonprod rincome_ha
balancetable (mean if treat_dis==0) (mean if treat_dis==1) (mean if treat_dis==2) (diff treat_A if treat_dis!=2) (diff treat_B if treat_dis!=1) $var2 using "$tmp/f_balance2.tex", ///
vce(cluster district) varlabels ctitles("Control" "T1" "T2" "T1 vs Control" "T2 vs Control") replace


/*

iebaltab landsize2 yield u_fert fert_ha fert_ha2 machine rincome_ha, ///
 grpvar(treat_dis) con(0) vce(cluster district) rowvarlabels stdev savetex("$tmp/f_balance2.tex") replace

*/
eststo clear
gen u_seedtreat=(t_seedtreat==1 | t_seedtreat==2)
gen u_simproved=(stype==1 | stype==2)
gen u_saroma=(stype==3 | stype==4 | stype==5)
gen u_stogo=(stype==8) 
gen u_scertify=(scertify==1) 
gen u_direct=(t_seedling==1)
gen u_dib=(t_seedling==2)
gen u_rtrans=(t_seedling==3)
gen u_ptrans=(t_seedling==4)
gen u_bunds=(t_bunds==1)
gen u_level=(t_levelling==1) 



label var u_seedtreat "Water/Salt treatment (=1 yes)" 
label var u_simproved "CSIR-AGRA/Exbaika (=1 yes)"
label var u_saroma "Jasmin/Aromatic (=1 yes)"
label var u_stogo "Togo Marshall (=1 yes)"
label var u_scertify "Certified seed (=1 yes)" 
label var u_direct "Direct seedling (=1 yes)"
label var u_dib "Dibbling (=1 yes)" 
label var u_rtrans "Random transplanting (=1 yes)"
label var u_ptrans "Transplanting in row (=1 yes)"
label var u_bunds "Bunds construction (=1 yes)"
label var u_level "Levelling the field (=1 yes)" 

global var3 u_seedtreat-u_level
balancetable (mean if treat_dis==0) (mean if treat_dis==1) (mean if treat_dis==2) (diff treat_A if treat_dis!=2) (diff treat_B if treat_dis!=1) $var3 using "$tmp/f_balance3.tex", ///
vce(cluster district) varlabels ctitles("Control" "T1" "T2" "T1 vs Control" "T2 vs Control") replace

gen lnyield=ln(yield) 
gen c_machine_ha=(c_combine+c_tractor+c_thresh+c_other)*$convert

* any-improved-variety dummy, defined as in do/f_endline_analysis.do (mkout)
capture confirm variable u_impany
if _rc gen u_impany = (inrange(stype,1,5) | stype==7) if stype<.
* RHS mirrors the endline correlation table (do/corr_endline.do): input and
* mechanization dummies PLUS the management practices shown in the adoption
* tables (improved variety, certified seed, dibbling, transplanting in row).
capture label var u_impany   "Any improved variety (=1 yes)"
capture label var u_scertify "Certified seed (=1 yes)"
capture label var u_dib      "Seed dibbling (=1 yes)"
capture label var u_ptrans   "Transplanting in row (=1 yes)"
global controls landsize2 hage i.hedu hgen u_fert u_her u_tractor u_combine u_thresh u_other u_seedtreat u_simproved u_bunds u_level ///
                u_impany u_scertify u_dib u_ptrans

eststo clear
local corrmods ""
foreach var in yield lnyield rincome_ha c_cfert_ha c_seed_ha c_hire_ha c_machine_ha {
 reg `var' $controls, cluster(district)
 eststo m_`var'
 local corrmods "`corrmods' m_`var'"
 }

 label var u_combine "Combine harvester (=1 yes)"
 label var u_thresh  "Thresher (=1 yes)"
 label var u_tractor "Tractor (=1 yes)" 
 label var u_other "Other machinery (=1 yes)"
 
 replace u_tractor=1 if hand==1
 replace u_tractor=1 if fourwheel==1

* NB: the model list must be spelled out -- `var' is empty once the loop ends,
* which is why this table used to be left stale.
esttab `corrmods' using "$tmp/f_result_table2.tex", replace ///
	se nogap b(%4.3f) nonotes label modelwidth(5) ///
	s(N, fmt(%9.0g) labels("Obs"))  ///
	mlabel("Yield" "Log (Yield)" "Rice income (ha)" "Fertilizer (ha)" "Seed (ha)" "Hired labor(ha)" "Machinery (ha)")
