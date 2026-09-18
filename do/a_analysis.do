global path "C:/Users/kaz-takahashi/Dropbox/Ghana/Data/"
global path "/Users/wkodama/research/ghana-aea-rct/"
global dta $path/Baseline
global do $path/do
global tmp $path/tmp

use "$tmp/AEA_base_tmp", clear

* SAMPLE = RAINFED SITES ONLY (co-author decision, Sep 2026): districts 3 (Kpong)
* and 8 (Ketu North / Weta) are the two irrigation schemes and are dropped from
* every estimation in the project. They hold 2 AEAs, both in the control arm.
drop if district==3 | district==8
qui count
di as txt "baseline AEA sample after dropping the irrigation schemes: " r(N)

drop a_edu 
drop a_seedselection
gen tenure=(a_tenure==1)

label var a_gender "Male (=1 yes)"  
label var a_knowledge "Knowledge of Rice Production (0-4)"
label var tenure "Tenured (=1 yes)"

global a_basic a_gender tenure a_exp-a_salary a_bike* a_avvisit a_mostvisit a_leastvisit a_ricetraining a_knowledge

generate treat_A = (treat_dis==1)
generate treat_B = (treat_dis==2)
balancetable (mean if treat_dis==0) (mean if treat_dis==1) (mean if treat_dis==2) (diff treat_A if treat_dis!=2) (diff treat_B if treat_dis!=1) $a_basic using "$tmp/a_balance1.tex", ///
vce(cluster district) varlabels ctitles("Control" "T1" "T2" "T1 vs Control" "T2 vs Control") replace

gen a_prosocial=a_proaction+a_profeeling
local prosocial 

global a_pros panelE* a_prosocial a_intrinsic a_extrinsic1 a_extrinsic2

label var a_prosocial "Total proscialness (6-30)"
label var a_intrinsic "Intrinsic motivation (2-10)"
label var a_extrinsic1 "Extrinsic motivation (4-20)"
label var a_extrinsic2 "Extrinsic motivation (2-10)"


balancetable (mean if treat_dis==0) (mean if treat_dis==1) (mean if treat_dis==2) (diff treat_A if treat_dis!=2) (diff treat_B if treat_dis!=1) $a_pros using "$tmp/a_balance2.tex", ///
vce(cluster district) varlabels ctitles("Control" "T1" "T2" "T1 vs Control" "T2 vs Control") replace





label var a_locus_gen "General (F-J) (5-25)"
label var a_locus_spec "Agriculture (A-E) (5-25)"
global a_loc panelG_A-panelG_J a_locus_spec a_locus_gen 

balancetable (mean if treat_dis==0) (mean if treat_dis==1) (mean if treat_dis==2) (diff treat_A if treat_dis!=2) (diff treat_B if treat_dis!=1) $a_loc using "$tmp/a_balance3.tex", ///
 varlabels ctitles("Control" "T1" "T2" "T1 vs Control" "T2 vs Control") replace




save "$tmp/a_AEA_sum", replace


/*Some correlation analysis*/
eststo c1: reg a_prosocial a_gender tenure a_exp a_salary a_bike a_knowledge a_intrinsic a_extrinsic2 a_locus_gen a_locus_spec, r
eststo c2: reg a_intrinsic a_prosocial a_gender tenure a_exp a_salary a_bike a_knowledge a_extrinsic2 a_locus_gen a_locus_spec, r
eststo c3: reg a_extrinsic2 a_intrinsic a_prosocial a_gender tenure a_exp a_salary a_bike a_knowledge a_locus_gen a_locus_spec, r
eststo c4: reg a_locus_gen a_extrinsic2 a_intrinsic a_prosocial a_gender tenure a_exp a_salary a_bike a_knowledge a_locus_spec, r
eststo c5: reg a_locus_spec a_locus_gen a_extrinsic2 a_intrinsic a_prosocial a_gender tenure a_exp a_salary a_bike a_knowledge, r

esttab c1 c2 c3 c4 c5 using "$tmp/a_result_table3.tex", ///
se nogap b(%4.3f) nonotes label modelwidth(5) ///
	mlabel("Prosocial" "Intrinsic" "Extrinsic" "Locus (Gen)" "Locus (Agri)") ///  
	star(* 0.10 ** 0.05 *** 0.01) replace 	



graph hbar (percent), over(panelE_A, label(labsize(vsmall))) title("Q1: `: variable label panelE_A'", size(.2cm)) ytitle("")
graph save "$tmp/ea.gph", replace 
 graph hbar (percent), over( panelE_B, label(labsize(vsmall))) title("Q2: `: variable label panelE_B'", size(.2cm)) ytitle("")
graph save "$tmp/eb.gph", replace 
graph hbar (percent), over( panelE_C, label(labsize(vsmall))) title("Q3: `: variable label panelE_C'", size(.2cm)) ytitle("")
graph save "$tmp/ec.gph", replace 
graph hbar (percent), over( panelE_D, label(labsize(vsmall))) title("Q4: `: variable label panelE_D'", size(.2cm)) ytitle("")
graph save "$tmp/ed.gph", replace 
 graph hbar (percent), over( panelE_E, label(labsize(vsmall))) title("Q5: `: variable label panelE_E'", size(.2cm)) ytitle("")
graph save "$tmp/ee.gph", replace 
graph hbar (percent), over( panelE_F, label(labsize(vsmall))) title("Q6: `: variable label panelE_F'", size(.2cm)) ytitle("")
graph save "$tmp/ef.gph", replace 

graph combine "$tmp/ea.gph" "$tmp/eb.gph" "$tmp/ec.gph" "$tmp/ed.gph" "$tmp/ee.gph" "$tmp/ef.gph", xcommon ycommon
graph export "$tmp/prosocial.eps" , replace as(eps) 
graph export "$tmp/prosocial.pdf", replace


/*intrinsic*/
*A.	Because this activity is fun 
*G.	Because I feel good when doing this activity 

/*extrinsic*/


*external regulation 
*D.	Because I am supposed to do it 
*F.	Because I don't have any choice 



*identified regulation
*B.	Because I am doing it for my own good 
*C.	Because I think that this activity is good for me. 	


graph hbar (percent), over(panelG_A, label(labsize(vsmall))) title("Q1: `: variable label panelG_A'", size(.2cm)) ytitle("")
graph save "$tmp/ga.gph", replace 
 graph hbar (percent), over( panelG_B, label(labsize(vsmall))) title("Q2: `: variable label panelG_B'", size(.2cm)) ytitle("")
graph save "$tmp/gb.gph", replace 
graph hbar (percent), over( panelG_C, label(labsize(vsmall))) title("Q3: `: variable label panelG_C'", size(.2cm)) ytitle("")
graph save "$tmp/gc.gph", replace 
graph hbar (percent), over( panelG_D, label(labsize(vsmall))) title("Q4: `: variable label panelG_D'", size(.2cm)) ytitle("")
graph save "$tmp/gd.gph", replace 
 graph hbar (percent), over( panelG_E, label(labsize(vsmall))) title("Q5: `: variable label panelG_E'", size(.2cm)) ytitle("")
graph save "$tmp/ge.gph", replace 
graph hbar (percent), over( panelG_F, label(labsize(vsmall))) title("Q6: `: variable label panelG_F'", size(.2cm)) ytitle("")
graph save "$tmp/gf.gph", replace 
graph hbar (percent), over( panelG_G, label(labsize(vsmall))) title("Q6: `: variable label panelG_G'", size(.2cm)) ytitle("")
graph save "$tmp/gg.gph", replace 
graph hbar (percent), over( panelG_H, label(labsize(vsmall))) title("Q6: `: variable label panelG_H'", size(.2cm)) ytitle("")
graph save "$tmp/gh.gph", replace 
graph hbar (percent), over( panelG_I, label(labsize(vsmall))) title("Q6: `: variable label panelG_I'", size(.2cm)) ytitle("")
graph save "$tmp/gi.gph", replace 
graph hbar (percent), over( panelG_J, label(labsize(vsmall))) title("Q6: `: variable label panelG_J'", size(.2cm)) ytitle("")
graph save "$tmp/gj.gph", replace 

graph combine "$tmp/ga.gph" "$tmp/gb.gph" "$tmp/gc.gph" "$tmp/gd.gph" "$tmp/ge.gph", xcommon 
graph export "$tmp/locus1.eps" , replace as(eps) 
graph combine "$tmp/gf.gph" "$tmp/gg.gph" "$tmp/gh.gph" "$tmp/gi.gph" "$tmp/gj.gph", xcommon 
graph export "$tmp/locus2.eps" , replace as(eps) 	
