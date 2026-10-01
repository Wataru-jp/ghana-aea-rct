global path "C:\Users\kaz-takahashi\Dropbox\Ghana\Data"
global path "/Users/wkodama/Documents/research/ghana-aea-rct/"
global base $path\Baseline
global survey "$path\Biweekly survey data"
global do $path\do
global tmp $path\tmp

*global path "/Users/wkodama/Library/CloudStorage/Dropbox/JICA Ghana"
*global survey "/Users/wkodama/Library/CloudStorage/Dropbox/JICA Ghana/介入/Biweekly survey data"


// read files
use "$survey/R1_April survey.dta", clear
gen survey = "04-2"

tempfile temp
save `temp', replace 

use "$survey/R2_May survey_1.dta", clear
gen survey = "05-1"
tempfile temp1
save `temp1', replace 

use "$survey/R3_May survey_2.dta", clear
gen survey = "05-2"
tempfile temp2
save `temp2', replace 

use "$survey/R4_June survey_1.dta", clear
gen survey = "06-1"
tempfile temp3
save `temp3', replace

use "$survey/R5_June survey_2.dta", clear
gen survey = "06-2"
tempfile temp4
save `temp4', replace

use "$survey/R6_July survey_1.dta", clear
gen survey = "07-1"
tempfile temp5
save `temp5', replace

use "$survey/R7_July survey_2.dta", clear
gen survey = "07-2"
tempfile temp6
save `temp6', replace

use "$survey/R8_August survey_1.dta", clear
gen survey = "08-1"
tempfile temp7
save `temp7', replace

use "$survey/R9_August survey_2.dta", clear
gen survey = "08-2"
tempfile temp8
save `temp8', replace

use "$survey/R10_Sept_survey_1.dta", clear
gen survey = "09-1"
tostring Q3_1_oth, replace
tempfile temp9
save `temp9', replace

use "$survey/R11_Sept_survey_2.dta", clear
gen survey = "09-2"
tempfile temp10
save `temp10', replace

use "$base/AEA.dta", clear
replace aea = "Adodoadzi Tawia Maxwell" in 22
replace aea = "Ntoso Anane Dickson" in 24
replace aea = "Anane Kwabena Paini" in 27
replace aea = "Maxwell   Akakpo" in 28
replace aea = "Cynthia Manua" in 33
keep aea gps treat_dis discode aid
tempfile treat

rename discode district

save `treat', replace

use `temp', clear
append using `temp1'
append using `temp2'
append using `temp3'
append using `temp4'
append using `temp5'
append using `temp6'
append using `temp7'
append using `temp8'
append using `temp9'
append using `temp10'

encode survey, gen(t)
order survey t
label var t "Month-Half"

drop district

// merge
rename aea aid
merge m:1 aid using `treat'
drop _merge 


// observations
ta t
bysort district: ta aid /*unbalanced panel*/

gen Q4_2 = Q4
replace Q4_2 = . if Q1 == 0


gen visit = (Q1 > 0)
gen interact= (Q2 > 0)
gen satisfy = (Q4 == 4| Q4 == 5) 
replace satisfy = . if Q4_2 == .
gen satisfy2=satisfy
replace satisfy2=0 if satisfy2==.
label var t "Month-Half"

gen district2 = ""
replace district2 = "T1: Achiase" if district == 3
replace district2 = "C: Biakoye" if district == 4
replace district2 = "T1: Bibiani" if district == 5
replace district2 = "C: Weta" if district == 6
replace district2 = "C:Kpong" if district == 7
replace district2 = "T2: Krachi " if district == 8
replace district2 = "T2: Manya " if district == 9
replace district2 = "C: Pru West" if district == 1
replace district2 = "T2: Sefwi " if district == 10
replace district2 = "T1: Sene" if district == 2

gen t1m=(treat_dis==1)
gen t2m=(treat_dis==2)
dummies t

merge m:1 farmer using "$tmp/f_AEA.dta"
drop _merge 

gen irrgsch=(district== 6 | district==7) 


foreach var in Q1 visit Q2 interact satisfy satisfy2{

eststo m1_`var': reg `var' i.treat_dis i.gps i.irrgsch i.t i.province, r 
		qui sum `var' if treat_dis==0 & t==1
		estadd scalar ControlMean = r(mean)
	
eststo m2_`var': reg `var' i.treat_dis i.gps i.irrgsch i.t i.province, cluster(district)
		estadd local cl Yes

		set seed 12345
		randcmd ((t1m t2m) reg `var' t1m t2m gps i.irrg i.t i.province, cluster(district)), reps(1000) treatvars(t1m t2m)
		matrix ripv = e(RCoef)
		matlist ripv
		matrix pvalues_`var'_1=ripv[1,6] 
		mat colnames pvalues_`var'_1 = t1m
		matrix pvalues_`var'_2=ripv[2,6] 
		mat colnames pvalues_`var'_2 = t2m
		estimates restore m2_`var'
		
		scalar pvalue_treat_1 = pvalues_`var'_1[1,1]
		estadd scalar pvalue_treat_1=pvalue_treat_1  
		
		scalar pvalue_treat_2 = pvalues_`var'_2[1,1]
		estadd scalar pvalue_treat_2=pvalue_treat_2  
		estimates store m2_`var'
		
eststo m3_`var': reg `var' i.treat_dis i.gps i.irrgsch Q1 Q2 i.t i.province, cluster(district)
		estadd local cl Yes		
}

label define treatlbl 0 "Control" 1 "T1" 2 "T2"
label values treat_dis treatlbl

label var gps "GPS"
label var irrgsch "Irrigation"
label var Q1 "Number visits (2 weeks)"
label var Q2 "Number contacts (2 weeks)" 

esttab m1_Q1 m2_Q1 m1_visit m2_visit m1_Q2 m2_Q2 m1_interact m2_interact using "$tmp/result_table1.tex", ///
	se nogap b(%4.3f) nonotes label modelwidth(5) ///
	keep(1.treat_dis 2.treat_dis 1.gps 1.irrgsch) ///
	s(ControlMean cl pvalue_treat_1 pvalue_treat_2 N, fmt(%9.3g %9.0g %9.3f %9.3f %9.0g) labels("Control mean" "Clustered SE" "RI: p-value for T1" "RI: p-value for T2" "Obs"))  ///
	mlabel("Number visits" "Number visits" "At least 1 visits" "At least 1 visits" "Number contact" "Number contact" "At least 1 contact" "At least 1 contact") ///  
	star(* 0.10 ** 0.05 *** 0.01) replace 

	esttab m1_satisfy m2_satisfy m1_satisfy2 m2_satisfy2 m3_satisfy m3_satisfy2 using "$tmp/result_table2.tex", ///
    se nogap b(%4.3f) nonotes label modelwidth(10) ///
    keep(1.treat_dis 2.treat_dis 1.gps 1.irrgsch Q1 Q2) ///
    s(ControlMean cl pvalue_treat_1 pvalue_treat_2 N, fmt(%9.3g %9.0g %9.3f %9.3f %9.0g) labels("Control mean" "Clustered SE" "RI: p-value for T1" "RI: p-value for T2" "Obs"))  ///
    mlabel("\shortstack{Satisfy=1}" ///
           "\shortstack{Satisfy=1}" ///
           "\shortstack{Satisfy=1\\(full sample)}" ///
           "\shortstack{Satisfy=1\\(full sample)}" ///
           "\shortstack{Satisfy=1\\(add. control)}" ///
           "\shortstack{Satisfy=1\\(add. control, full)}") ///
    star(* 0.10 ** 0.05 *** 0.01) replace

	esttab m1_satisfy m2_satisfy m1_satisfy2 m2_satisfy2 m3_satisfy m3_satisfy2 using "$tmp/result_table2.tex", ///
	se nogap b(%4.3f) nonotes label modelwidth(5) ///
	keep(1.treat_dis 2.treat_dis 1.gps 1.irrgsch Q1 Q2) ///
	s(ControlMean cl N, fmt(%9.3g %9.0g %9.0g) labels("Control mean" "Clustered SE" "Obs"))  ///
	mlabel("Satisfy=1" "Satisfy=1" "Satisfy=1 (full sample)" "Satisfy=1 (full sample)" "Satisfy (additional control)"   "Satisfy (additional control, full)") ///  
	star(* 0.10 ** 0.05 *** 0.01) replace 

/*	

/*
eststo m2: reg Q1 i.treatment##i.gps i.irrg i.t i.province, cluster(district)
eststo m4: reg Q2 i.treatment##i.gps i.irrg i.t i.province, cluster(district)
eststo m5: reg satisfy i.treatment i.gps i.irrg i.t i.province, cluster(district)
eststo m6: reg satisfy i.treatment##i.gps i.irrg i.t i.province, cluster(district)
	
randcmd ((t1m t2m) reg Q1 t1m t2m gps i.irrg i.t i.province, cluster(district)), reps(1000) treatvars(t1m t2m)
randcmd ((t1m t2m gps) reg Q1 t1m t2m gps i.irrg i.t i.province, cluster(district)), reps(1000) treatvars(t1m t2m gps)*/


generate treat_A = (treat_dis==1)
generate treat_B = (treat_dis==2)

label var visit "At least 1 visit (=1 yes, in 2 weeks)"
label var interact "At least 1 contact (=1 yes, in 2 weeks)" 
label var satisfy "Satisfy (=1) if any contact"
label var satisfy2 "Satisfy (=1) all sample" 

balancetable (mean if treat_dis==0) (mean if treat_dis==1) (mean if treat_dis==2) (diff treat_A if treat_dis!=2) (diff treat_B if treat_dis!=1) Q1 visit Q2 interact satisfy satisfy2 using "$tmp\b_balance1.tex", ///
vce(cluster district) varlabels ctitles("Control" "T1" "T2" "T1 vs Control" "T2 vs Control") replace	


graph hbar (count) if (t == 2|t == 4|t == 6|t == 8| t==10), ///
	over(Q4) over(t) over(district2) percent stack asyvars ///
	bar(1, color(red*0.6)) bar(2, color(red*0.3)) ///
	bar(3, color(gs7*0.5)) bar(4, color(green*0.2)) ///
	bar(5, color(green*0.8)) ///
	scale(*.5) ytitle("% Households") ///
	legend(size(2.5) rows(1) pos(6)) scheme(s1mono)
    graph save $tmp\b_satisfy.gph, replace 
	graph export "$tmp\b_satisfy.eps" , replace as(eps) 

merge m:1 aid using $tmp\a_AEA_sum 

reg Q1 a_prosocial a_gender tenure a_exp a_salary a_bike a_knowledge a_intrinsic a_extrinsic a_locus_gen a_locus_spec i.t i.province, cluster(district)
reg Q2 a_prosocial a_gender tenure a_exp a_salary a_bike a_knowledge a_intrinsic a_extrinsic a_locus_gen a_locus_spec i.t i.province, cluster(district)
reg satisfy a_prosocial a_gender tenure a_exp a_salary a_bike a_knowledge a_intrinsic a_extrinsic a_locus_gen a_locus_spec i.t i.province, cluster(district)
	

	

	
/*

collapse (mean) Q1 Q2 Q4 visit interact satisfy, by(t treat_dis)
reshape wide Q1 Q2 Q4 visit interact satisfy, i(t) j(treat_dis)	


twoway ///
    scatter Q11 t, mcolor(red*0.8) msymbol(o) || ///
    scatter Q12 t, mcolor(blue*0.8) msymbol(triangle) || ///
    scatter Q10 t, mcolor(gs) msymbol(square) || ///
    line Q11 t, lc(red*0.8) || ///
    line Q12 t, lc(blue*0.8) || ///
    line Q10 t, lc(gs) ///
    legend(order(1 "T1" 2 "T2" 3 "C") col(3) position(6)) ///
    xlabel(1(1)11, valuelabel) ///
    title("Number Visit")
    graph save $tmp\b_visit.gph, replace 
	
twoway ///
    scatter Q21 t, mcolor(red*0.8) msymbol(o) || ///
    scatter Q22 t, mcolor(blue*0.8) msymbol(triangle) || ///
    scatter Q20 t, mcolor(gs) msymbol(square) || ///
    line Q21 t, lc(red*0.8) || ///
    line Q22 t, lc(blue*0.8) || ///
    line Q20 t, lc(gs) ///
    legend(order(1 "T1" 2 "T2" 3 "C") col(3) position(6)) ///
    xlabel(1(1)11, valuelabel)	///
    title("Number Contact")
	graph save $tmp\b_contact.gph, replace 
	

twoway ///
    scatter Q41 t, mcolor(red*0.8) msymbol(o) || ///
    scatter Q42 t, mcolor(blue*0.8) msymbol(triangle) || ///
    scatter Q40 t, mcolor(gs) msymbol(square) || ///
    line Q41 t, lc(red*0.8) || ///
    line Q42 t, lc(blue*0.8) || ///
    line Q40 t, lc(gs) ///
    legend(order(1 "T1" 2 "T2" 3 "C") col(3) position(6)) ///
    xlabel(1(1)11, valuelabel)	///
    title("Satisfaction")	
	graph save $tmp\b_satisfy.gph, replace 
	graph combine $tmp\b_visit.gph $tmp\b_contact.gph $tmp\b_satisfy.gph
	graph export "$tmp\b_basic.eps" , replace as(eps) 



/*
twoway ///
    scatter visit1 t, mcolor(red*0.8) || ///
    scatter visit2 t, mcolor(blue*0.8) || ///
    scatter visit0 t, mcolor(gs) || ///
    line visit1 t, lc(red*0.8) || ///
    line visit2 t, lc(blue*0.8) || ///
    line visit0 t, lc(gs)  ///
	legend(order(1 "T1" 2 "T2" 3 "C" ) col(3)) ///
	xlabel(1(1)11, valuelabel) msymbol()	


twoway ///
    scatter satisfy1 t, mcolor(red*0.8) || ///
    scatter satisfy2 t, mcolor(blue*0.8) || ///
    scatter satisfy0 t, mcolor(gs) || ///
    line satisfy1 t, lc(red*0.8) || ///
    line satisfy2 t, lc(blue*0.8) || ///
    line satisfy0 t, lc(gs) ///
	legend(order(1 "T1" 2 "T2" 3 "C") col(3)) ///
	xlabel(1(1)11, valuelabel) msymbol() ///
    title("Satisfaction (=1)")


/*
/*By GPS*/	
// analysis 3
drop if treatment == 4
collapse (mean) Q1 Q2 Q4 Q4_2 visit interation satisfy, by(t treat)
reshape wide Q1 Q2 Q4 Q4_2 visit interation satisfy, i(t) j(treat)

twoway ///
    scatter Q10 t, mcolor(gs*0.8) || ///
    scatter Q11 t, mcolor(blue*0.8) || ///
    line Q10 t, lc(gs*0.8) || ///
    line Q11 t, lc(blue*0.8) ///
	legend(order(2 "GPS Treatment" 1 "Control") col(4)) ///
	xlabel(1(1)11, valuelabel) msymbol()

twoway ///
    scatter visit0 t, mcolor(gs*0.8) || ///
    scatter visit1 t, mcolor(blue*0.8) || ///
    line visit0 t, lc(gs*0.8) || ///
    line visit1 t, lc(blue*0.8) ///
	legend(order(2 "GPS Treatment" 1 "Control") col(4)) ///
	xlabel(1(1)11, valuelabel) msymbol()

twoway ///
    scatter Q20 t, mcolor(gs*0.8) || ///
    scatter Q21 t, mcolor(blue*0.8) || ///
    line Q20 t, lc(gs*0.8) || ///
    line Q21 t, lc(blue*0.8) ///
	legend(order(2 "GPS Treatment" 1 "Control") col(4)) ///
	xlabel(1(1)11, valuelabel) msymbol()

twoway ///
    scatter satisfy0 t, mcolor(gs*0.8) || ///
    scatter satisfy1 t, mcolor(blue*0.8) || ///
    line satisfy0 t, lc(gs*0.8) || ///
    line satisfy1 t, lc(blue*0.8) ///
	legend(order(2 "GPS Treatment" 1 "Control") col(4)) ///
	xlabel(1(1)11, valuelabel) msymbol()


generate treat_A = (treat_dis==1)
generate treat_B = (treat_dis==2)
balancetable (mean if treat_dis==0) (mean if treat_dis==1) (mean if treat_dis==2) (diff treat_A if treat_dis!=2) (diff treat_B if treat_dis!=1) $vars using "$tmp\f_balance1.tex", ///
vce(cluster district) varlabels ctitles("Control" "T1" "T2" "T1 vs Control" "T2 vs Control") replace




	