* fig_gps_submissions.do -- how many GPS-stamp records each of the 20 stamp-arm
* AEAs submitted (Apr-Sep 2025), for the seminar deck appendix.
* Output: tmp/fig_gps_submissions.pdf (seminar deck appendix). Not called by the master.
set linesize 200
global R "/Users/wkodama/Documents/research/ghana-aea-rct"
local cC "gs7"
local c1 "230 120 0"
local c2 "0 130 60"

* the 20 AEAs asked to stamp, with their arm
use "$R/tmp/bw_panel.dta", clear
collapse (first) treat_dis gps, by(aid)
keep if gps==1
tempfile arms
save `arms'

* records and record-days per AEA
use "$R/tmp/aea_stamp_wp.dta", clear
egen dtag = tag(aid Date)
collapse (count) n_rec=slat (sum) n_days=dtag, by(aid)
merge 1:1 aid using `arms', keep(2 3) nogen
replace n_rec  = 0 if n_rec==.
replace n_days = 0 if n_days==.

* rank AEAs by records (1 = most)
gsort -n_rec -n_days
gen rank = _n
egen tot = total(n_rec)
gen sh = 100*n_rec/tot
list rank aid treat_dis n_rec n_days sh, sep(0)
sum n_rec, detail
qui sum sh if rank==1
local top = string(round(r(mean)))
qui sum n_rec if rank==1
local topn = r(mean)
qui sum tot
local tot = r(mean)
count if n_rec<=5
local few = r(N)
qui sum n_rec, detail
local med = string(r(p50))

* panel A: records per AEA, sorted, coloured by arm
twoway (bar n_rec rank if treat_dis==0, barw(0.75) color(`cC')) ///
       (bar n_rec rank if treat_dis==1, barw(0.75) color("`c1'")) ///
       (bar n_rec rank if treat_dis==2, barw(0.75) color("`c2'")), ///
    ytitle("Records submitted, Apr-Sep 2025") xtitle("AEAs in the GPS-stamp arm, ranked") ///
    xlabel(1(1)20, labsize(small)) ylabel(, angle(0) labsize(small)) ///
    title("Records per AEA (total = `tot', median = `med')", size(medium)) ///
    text(`=`topn'-8' 4.6 "One AEA: `topn' records (`top'% of all)", place(e) size(small)) ///
    legend(order(1 "Control" 2 "T1" 3 "T2") rows(1) size(small)) ///
    graphregion(color(white)) plotregion(color(white)) name(a, replace)

* panel B: histogram of records per AEA
gen bin = cond(n_rec==0,0,cond(n_rec<=5,1,cond(n_rec<=10,2,cond(n_rec<=25,3,4))))
label define binl 0 "0" 1 "1-5" 2 "6-10" 3 "11-25" 4 ">25"
label values bin binl
preserve
contract bin, freq(nAEA)
twoway bar nAEA bin, barw(0.75) color(gs9) ///
    xlabel(0 "0" 1 "1-5" 2 "6-10" 3 "11-25" 4 ">25", labsize(small)) ///
    ylabel(0(2)8, angle(0) labsize(small)) ///
    ytitle("Number of AEAs") xtitle("Records submitted per AEA") ///
    title("Distribution (`few' of 20 AEAs submitted 5 or fewer)", size(medium)) ///
    graphregion(color(white)) plotregion(color(white)) name(b, replace)
restore

graph combine a b, rows(1) xsize(11) ysize(4.5) graphregion(color(white))
graph export "$R/tmp/fig_gps_submissions.pdf", replace
