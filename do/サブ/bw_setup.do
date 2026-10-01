
global path "C:\Users\kaz-takahashi\Dropbox\Ghana\Data"
global path "/Users/wkodama/Documents/research/ghana-aea-rct/"
global base $path\Baseline
global bw "$path\Biweekly survey data"
global tmp $path\tmp
global do $path\do

****Baseline AEA****

use "$base\AEA baseline", clear

table panelE_A , statistic(percent) nformat(%10.0f) miss
table panelE_B, statistic(percent) nformat(%10.0f) miss
table panelE_C , statistic(percent) nformat(%10.0f) miss
table panelE_D , statistic(percent) nformat(%10.0f) miss
table panelE_E , statistic(percent) nformat(%10.0f) miss
table panelE_F , statistic(percent) nformat(%10.0f) miss

table panelF_A , statistic(percent) nformat(%10.0f) miss
table panelF_B, statistic(percent) nformat(%10.0f) miss
table panelF_C , statistic(percent) nformat(%10.0f) miss
table panelF_D, statistic(percent) nformat(%10.0f) miss
table panelF_E , statistic(percent) nformat(%10.0f) miss
table panelF_F , statistic(percent) nformat(%10.0f) miss
table panelF_G , statistic(percent) nformat(%10.0f) miss
table panelF_H , statistic(percent) nformat(%10.0f) miss

table panelG_1 , statistic(percent) nformat(%10.0f) miss
table panelG_2, statistic(percent) nformat(%10.0f) miss
table panelG_3 , statistic(percent) nformat(%10.0f) miss
table panelG_4, statistic(percent) nformat(%10.0f) miss
table panelG_5 , statistic(percent) nformat(%10.0f) miss

table panelG_A , statistic(percent) nformat(%10.0f) miss
table panelG_B, statistic(percent) nformat(%10.0f) miss
table panelG_C , statistic(percent) nformat(%10.0f) miss
table panelG_D, statistic(percent) nformat(%10.0f) miss
table panelG_E , statistic(percent) nformat(%10.0f) miss
table panelG_F , statistic(percent) nformat(%10.0f) miss
table panelG_G, statistic(percent) nformat(%10.0f) miss
table panelG_H , statistic(percent) nformat(%10.0f) miss
table panelG_I, statistic(percent) nformat(%10.0f) miss
table panelG_J , statistic(percent) nformat(%10.0f) miss

****Biweekly ****

program define evaluation
    gen n = 1 
	gen nvisit=Q1
	gen ncontact=Q2
	
    forvalues i = 1/5 {
        gen q4_`i' = (Q4 == `i')
    }

    collapse (sum) n q4_1-q4_5 (max) nvisit ncontact, by(aea) 

    egen nm = rsum(q4_1-q4_5)

   forvalues i = 1/5 {
        gen p4_`i' = q4_`i' / nm
		
    }
	gen av=(1*q4_1+2*q4_2+3*q4_3+4*q4_4+5*q4_5)/nm	

end

use "$bw\R1_April survey", clear 
    evaluation
    gen r=1
    save $tmp\r1, replace 

use "$bw\R2_May survey_1", clear 
    evaluation
    gen r=2
    save $tmp\r2, replace 
	
use "$bw\R3_May survey_2", clear  
	evaluation
    gen r=3
    save $tmp\r3, replace 

use "$bw\R4_June survey_1", clear 
	evaluation
    gen r=4
    save $tmp\r4, replace 	
	
use "$bw\R5_June survey_2", clear  
	evaluation
    gen r=5
    save $tmp\r5, replace 	

use "$bw\R6_July survey_1", clear 
	evaluation
    gen r=6
    save $tmp\r6, replace 		

use "$bw\R7_July survey_2", clear  
	evaluation
    gen r=7
    save $tmp\r7, replace 		
	
use "$bw\R8_August survey_1", clear  
	evaluation
    gen r=8
    save $tmp\r8, replace 		

use "$bw\R9_August survey_2", clear  
	evaluation
    gen r=9
    save $tmp\r9, replace 		


use "$bw\R10_Sept_survey_1", clear  
	evaluation
    gen r=10
    save $tmp\r10, replace 	

use "$bw\R11_Sept_survey_2", clear  
	evaluation
    gen r=11
    save $tmp\r11, replace 		

* 1. 最初のファイル（tmp\r1）を開く
use "$tmp\r1", clear

* 2. r2からr11までのファイルを順番にアペンド（結合）する
forvalues i = 2/11 {
    append using "$tmp\r`i'"
}

sort aea r

	