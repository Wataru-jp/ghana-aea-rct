
global path "C:/Users/kaz-takahashi/Dropbox/Ghana/Data/"
global path "/Users/wkodama/Documents/research/ghana-aea-rct/"
global dta $path/Baseline
global do $path/do
global tmp $path/tmp

use "$dta/AEA baseline", clear
rename aea aid
merge 1:1 aid using "$dta/AEA", force
drop _merge

rename panelA_C a_gender
rename panelA_E a_edu
rename panelA_F a_tenure
rename panelA_G a_exp
rename panelA_H a_exp_here
rename panelA_K a_salary
rename panelA_L a_international

rename panelB_C a_nearest
rename panelB_D a_farthest
rename panelB_E a_bike
rename panelB_G a_bikeexp
rename panelB_H a_avvisit
rename panelB_I3 a_mostvisit
rename panelB_I2 a_mostvisit_km
rename panelB_J3 a_leastvisit
rename panelB_J2 a_leastvisit_km
rename panelB_K  a_satisfaction

rename panelC_A  a_ricetraining
rename panelC_E2 a_ricemostvisit_km
rename panelC_E a_ricemostvisit
rename panelC_F a_ricemostfieldday
rename panelC_H a_ricemosttraining

rename panelC_I2 a_riceleastvisit_km
rename panelC_I a_riceleasttvisit
rename panelC_J a_riceleastfieldday
rename panelC_L a_riceleasttraining

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
gen a_level=(panelD_B==1)
gen a_plant=(panelD_C==5)
gen a_water=(panelD_D==4)
gen a_dry=(panelD_E==2)

egen a_knowledge=rsum(a_seedselection-a_dry)
* a_seedcount = how many of the four correct purposes the AEA names (0-4);
* a_knowledge8 puts the scale on 0-8 with partial credit for item A.
egen a_seedcount  = rowtotal(panelD_A1 panelD_A2 panelD_A3 panelD_A5)
egen a_knowledge8 = rowtotal(a_seedcount a_level a_plant a_water a_dry) 

egen a_proaction=rsum(panelE_A-panelE_D)
egen a_profeeling=rsum(panelE_E-panelE_F)

gen a_intrinsic=(panelF_A+panelF_G)
gen a_extrinsic1=(panelF_B+panelF_C+panelF_D+panelF_F)
gen a_extrinsic2=(panelF_D+panelF_F)

gen a_locus1=(panelG_1==1)
gen a_locus2=(panelG_2==2)
gen a_locus3=(panelG_3==2)
gen a_locus4=(panelG_4==2)
gen a_locus5=(panelG_5==2)
egen a_locus_over=rsum(a_locus1-a_locus5)

drop a_locus1-a_locus5 

gen a=6-panelG_A
gen b=6-panelG_B
gen c=6-panelG_C
gen d=panelG_D
gen e=panelG_E
gen a_locus_spec=a+b+c+d+e   // items A-E: agriculture/work-specific

drop a-e

gen f=panelG_F
gen g=panelG_G
gen h=panelG_H
gen i=6-panelG_I
gen j=6-panelG_J

gen a_locus_gen=f+g+h+i+j   // items F-J: general (Rotter)

drop f-j

gen a_train = (a_ricetraining==1) if a_ricetraining<.   // panelC_A, renamed above
gen a_train_jica = (panelC_B3==1)
replace a_train_jica = 0 if a_train==0
label var a_train      "Attended rice agronomic training (=1)"
label var a_train_jica "\quad of which JICA was a provider (=1)"

keep aid area a_* gps treat* discode province panelE* panelF* panelG*
rename discode district
order province district gps treat_dis


replace a_international=0 if a_international==2
replace a_bike=0 if a_bike==2
replace a_ricetraining=0 if a_ricetraining==2
replace a_gender=0 if a_gender==2 

save "$tmp/AEA_base_tmp", replace 




/*
iebaltab hhsize hage hreligious hlit hedu hocc landsize productivity_ha v_totalprod_ha if irrigsch==0, grpvar(treat_dis) savex($tmp/balance) ft replace
