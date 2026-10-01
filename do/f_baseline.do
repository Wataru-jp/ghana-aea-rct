
global path "C:/Users/kaz-takahashi/Dropbox/Ghana/Data/"
global path "/Users/wkodama/Documents/research/ghana-aea-rct/"
global dta $path/Baseline
global do $path/do
global tmp $path/tmp


***SETUP***
*Cover*
use "$dta/Cover_v2.dta", clear
keep region district community hhID hhpeople aea_name
rename hhpeople hhsize 
gen aid=aea_name
gen irrgsch=(district==3 | district==8)

merge m:1 aid using "$dta/AEA_ds" 
drop _merge
save "$tmp/cover_tmp", replace 


*Roster*
use "$dta/QH1 (household roster-CURRENT MEMBERS)_v2.dta", clear
replace QH1_7=0 if QH1_7==. & QH1_3!=.
keep if QH1_7==0
gen hgen=(QH1_3==0)
rename QH1_4 hage 
rename QH1_9 hreligious
gen hedu=0
replace hedu=1 if QH1_12a>=1 & QH1_12a<=6
replace hedu=2 if QH1_12a>=7 & QH1_12a<=9
replace hedu=3 if QH1_12a>=10 & QH1_12a<=12
replace hedu=4 if QH1_12a>=13 
label define mylabel 0 "no edu" 1 "primary" 2 "junior high" 3 "senior high" 4"tertiary"
label values hedu mylabel
rename QH1_11 hlit
rename QH1_14 hocc
keep h* 
merge 1:1 hhID using "$tmp/cover_tmp" 
drop _merge
order region district community 
save "$tmp/roster_tmp", replace 

/*plot*/
use  "$dta/QY1-0wet (All cultivated land in wet season in 2024)", clear
gen plotID=hhID*10+QY1_0
keep hhID QY1_0 plotID QY1_6 QY1_8
drop if QY1_6==.
save "$tmp/plot1", replace 



*Production*
use "$dta/QY1-1wet (Rice production in wet season in 2024)_V2_rev2026Aug.dta", clear   // Adaku "Revised data v2" (Aug 2026): hhID 117 bags 98 -> 9 

merge 1:1 hhID using "$tmp/cover_tmp"
drop _merge
gen plotID=hhID*10+QY11_1id
merge 1:1 plotID using "$tmp/plot1"
drop if _merge==2
drop _merge


rename QY11_3 landsize
rename QY11_4 ownership
rename QY11_9 irrgland
replace irrgland=0 if irrgland==2
rename QY11_12 unit 
rename QY11_13 conversion
rename QY11_11  production_bags
rename QY11_11kg production_kg


gen totalprod_kg=conversion*production_bags if unit==1
replace totalprod_kg=production_kg if unit==2
replace totalprod_kg=. if totalprod_kg==0
gen nonprod=(totalprod_kg==.)
gen paddyprice_kg=QY11_15_pricepad/conversion if QY11_12_sldpady==1
replace paddyprice_kg=QY11_15_pady if QY11_12_sldpady==2


gen milprice_kg=QY11_14HowmuchinGhanacedi if QY11_12_sldmill==1
replace QY11_12_sldmill=1 if hhID==162 | hhID==90 | hhID==97 | hhID==101
replace QY11_12_sldmill=4 if hhID==85 | hhID==148 | hhID==320 | hhID==354

replace milprice_kg=QY11_14HowmuchinGhanacedi/25 if QY11_12_sldmill==3
replace milprice_kg=QY11_14HowmuchinGhanacedi/50 if QY11_12_sldmill==4

egen md_paddyprice_kg=median(paddyprice_kg), by(district)
egen md_milprice_kg=median(milprice_kg), by(district)

gen v_totalprod=totalprod_kg*md_paddyprice_kg

* ---- land payments for a rented plot (QY1.1_5_rent): 1 cash, 2 in-kind, 3 share --
* None of these was deducted from income before Aug 2026. NB Stata's 0*.=. , so a
* farmer paying no share must not inherit the missingness of v_totalprod.
gen sharepct = QY11_8 if QY11_5_rent==3
replace sharepct = 0 if sharepct==. | sharepct<0 | sharepct>100
gen landshare = cond(sharepct>0 & v_totalprod<., v_totalprod*sharepct/100, 0)
gen landcash  = cond(QY11_5_rent==1 & QY11_5<., QY11_5*landsize, 0)
gen landkind  = cond(QY11_5_rent==2 & QY11_6<. & QY11_7<., QY11_6*QY11_7, 0)
gen landpay   = landshare + landcash + landkind
label var sharepct  "Share of gross output paid to the landlord (%)"
label var landpay   "Land payment: share + cash rent + in-kind rent (GHS)"


drop QY*

save "$tmp/production", replace 






/*seedling*/
use "$dta/QY1-2b Seedling and Transplanting.dta", clear 
rename QY12b_8 stype
rename QY12b_9 squant
rename QY12b_2 t_seedling  
replace squant=. if squant<0
rename QY12b_11 sprice
replace sprice=0 if QY12b_10==3
replace sprice=. if sprice<0
rename QY12b_1 t_seedtreat 
rename QY12b_10 scertify
replace sprice=0 if sprice==.
gen c_seed=squant*sprice

keep hhID s* t_s* c_*
drop statecomm 
save "$tmp/seed_tmp", replace

/* Land preparation Animal/Machine*/
use "$dta/QY1-2a Land Prep(Machine-Animal).dta", clear

keep if QY12a_4b==1 
rename QY12a_6 c_tractor
gen hand=(QY12a_4==1)
gen fourwheel=(QY12a_4==2)
collapse (sum) c_tractor (max) hand fourwheel, by(hhID)
save "$tmp/machine1", replace

use "$dta/QY1-2a land prep (levelling-bunds-any animal or machine).dta", clear
rename QY12a_1 t_levelling
rename QY12a_2 t_bunds
drop QY*
keep hhID t_levelling t_bunds
save "$tmp/landprep", replace

/*Combine harvester/thresher*/
use "$dta/harvest_labor_use.dta", clear
gen combine=(QY15_3a_hir_harv==1)
gen thresh=(QY15_3a_hir_thres==1)
rename QY15_3c_hir_harv c_combine
rename QY15_3c_hir_thres c_thresh
drop QY*
save "$tmp/machine2", replace


/*chemicals*/
use "$dta/QY1_3wet Use of agri-chemicals and organics in wet season in 2024.dta", clear
drop if QY13_6==.
replace QY13_9=23 if hhID==334 & QY13_6==2
gen fert=QY13_8*50 if (QY13_6==1 | QY13_6==2 | QY13_6==3) &  (QY13_9==23 | QY13_9==9) 
replace fert=QY13_8*25 if (QY13_6==1 | QY13_6==2 | QY13_6==3) &  (QY13_9==24)
* unit code 18 = "Kilogram": kg as recorded (no baseline rows; kept for
* symmetry with the endline file)
replace fert=QY13_8 if (QY13_6==1 | QY13_6==2 | QY13_6==3) & QY13_9==18

replace QY13_8=120 if hhID==121 & QY13_6==4
gen c_cfert=QY13_8*QY13_10 if fert!=.

replace QY13_6=5 if QY13_6==4 & QY13_9==19
gen ofert=(QY13_6==4 & QY13_9!=19) 

gen herbinsec=QY13_8 if QY13_6==5 | QY13_6==6
gen c_herbinsec=QY13_8*QY13_10 if herbinsec!=.

gen c_other=QY13_8*QY13_10 if QY13_6==8 | QY13_6==7

collapse (sum) c* fert (max) ofert, by(hhID)
save "$tmp/chemical", replace


/*other tech adoption*/
use "$dta/QY1-4  Other agronomic practices in the wetseason 2024.dta", clear 
rename QY14_1 w_growth
rename QY14_2 w_reprod
rename QY14_3 w_mature
rename QY14_4 drying
rename QY14_5 harv
rename QY14_6 moisture
rename QY14_7 thre

gen y_w_growth=(w_growth==3)
gen y_w_repod=(w_reprod==4)
gen y_w_mature=(w_mature==2)
gen y_drying=(drying==2)
gen y_harvest=(harv==4)
gen y_moisture=(moisture==3)
gen y_thresh=(thre==1)
drop QY*
save "$tmp/ricepractice1", replace

/*asset*/
use "$dta/QT3 Asset Ownership.dta", clear
keep if asset_type>4

* Asset types (QT3, label "asset"): 1-4 Land, 5 Pumpset(diesel), 6 Pumpset(electric),
* 7 House and residential lot, 8 Tractor, 9 Thresher, 10 Motorcycle/scooter,
* 11 Mobile phone, 12 Horse, 13 Cow, 14 Sheep/goats, 15 Chicken, 16 Other.
* REBUILT Sep 2026. The old code (a) counted type 10 TWICE -- once in o_machine
* (8|9|10) and again in o_mobile (10) -- and (b) dropped type 7 (house) entirely,
* which is the largest single asset for many households. Together these made the
* control group look as though its assets collapsed between the waves when in
* fact its median rose; the "fall" was three households whose big asset moved
* between categories. Each type is now counted exactly once.
gen o_irrg    = QT3_4 if inlist(asset_type,5,6)          // irrigation pumpsets
gen o_house   = QT3_4 if asset_type==7                   // house and residential lot
gen o_machine = QT3_4 if inlist(asset_type,8,9)          // tractor, thresher
gen o_moto    = QT3_4 if asset_type==10                  // motorcycle/scooter
gen o_mobile  = QT3_4 if asset_type==11                  // mobile phone
gen o_animal  = QT3_4 if inrange(asset_type,12,15)       // livestock
gen o_other   = QT3_4 if asset_type==16

collapse (sum) o_*, by(hhID)
* productive equipment only: pumpsets, tractor, thresher
egen o_equip = rowtotal(o_irrg o_machine)
* all non-land assets, each counted once
egen o_total = rowtotal(o_irrg o_house o_machine o_moto o_mobile o_animal o_other)
save "$tmp/asset", replace


*Labor Input*
/*Total*/
use "$dta/QY1-5wet (Labor inputs-paddy)_V5.dta", clear   // Adaku Aug-2026 rev.2: hhID 260 irrig hrs 24->3, hhID 353 land-prep hrs 21->8 


gen l_male=QY15_1b*QY15_1c*QY15_1/8
gen l_female=QY15_2a*QY15_2b*QY15_2/8
replace QY15_10=0 if QY15_10==-99 
replace QY15_16=0 if QY15_16==. | QY15_16<0

gen c_hire=QY15_10+QY15_16 
gen c_hire2=QY15_17 
* bird scaring is a distinct operation (co-author request, Jul 2026): keep the
* family days spent on it so profit can be recomputed excluding that item
gen bird_male   = l_male   if operation==7
gen bird_female = l_female if operation==7
collapse (sum) l_female l_male c_hire bird_male bird_female, by(hhID)
gen famdays_bird = bird_male + bird_female
drop bird_male bird_female

save "$tmp/labor", replace


/*AEA satisfaction*/
use "$dta/QY1-6wet (Contact with extension worker 2024).dta", clear
gen bq_satisfy=6-QY16_6
gen bd_satisfy=(bq_satisfy==5 | bq_satisfy==4)
gen bq_contact=QY16_1a

keep bq* bd* hhID
rename hhID farmer

save "$tmp/f_AEA", replace


/*merge*/

use "$tmp/roster_tmp", clear
merge 1:1 hhID using "$tmp/production"
drop _merge
merge 1:1 hhID using "$tmp/seed_tmp"
drop _merge
merge 1:1 hhID using "$tmp/machine1"
 drop _merge
merge 1:1 hhID using "$tmp/machine2"
drop _merge
merge 1:1 hhID using "$tmp/landprep"
drop _merge
merge 1:1 hhID using "$tmp/ricepractice1"
drop _merge
merge 1:1 hhID using "$tmp/chemical" 
drop _merge
merge 1:1 hhID using "$tmp/labor" 
drop _merge
merge 1:1 hhID using "$tmp/asset" 
drop _merge


save "$tmp/farmer", replace 
