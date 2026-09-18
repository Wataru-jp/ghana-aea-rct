*==============================================================================
* aea_distance.do -- AEA locations, the GPS/stamp visit log, and AEA->community
* distances. Runs BEFORE bw_tables_v2.do and fig_dist_visits.do, both of which
* consume its output, so the coordinate corrections live in exactly one place.
*
* Outputs (all in $tmp):
*   aea_stamp_xy.dta   aid, median stamp coords, log-intensity counts
*   farmer_aid_xy.dta  hhID, aid, community, farmer coords
*   aea_comm_dist.dta  aid x community, distance in km
*   farmer_dist.dta    hhID, dist_km  (this farmer's community, its AEA)
*   aea_dist.dta       aid, mean distance over communities served
*
* AEA LOCATION. The survey files record where the INTERVIEW happened, which for
* two AEAs (aid 12, 39) is >200 km from the farmers they serve. The survey firm
* obtained their actual coordinates (Adaku, Aug 2026); they are hard-coded below
* and put them 16.3 km / 9.1 km from their communities, in line with the AEAs'
* own reported travel distances.
*
* GPS/STAMP LOG. "Biweekly survey data/AEA Records.xlsx", sheet "Data 2025":
* 357 geo-tagged farmer contacts, 10 Apr - 26 Sep 2025, 19 AEAs, ALL in the
* stamp arm (gps==1). AEA-submitted logs, not automatic pings, so they bound
* visits from below and are used descriptively only.
*==============================================================================
set more off
global path "/Users/wkodama/research/ghana-aea-rct"
global tmp  "$path/tmp"

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

* ---- AEA coordinates, both waves, with the two corrections ----
use "$path/Baseline/AEA baseline.dta", clear
rename aea aid
keep aid latitude longitude
rename (latitude longitude) (blat blon)
tempfile axy
save `axy'
use "$path/Endline/AEA endline.dta", clear
capture rename aea aid
capture rename aeaID aid
keep aid latitude longitude
rename (latitude longitude) (elat elon)
merge 1:1 aid using `axy', nogen
replace blat =  8.0052140 if aid==12
replace blon = -0.9090190 if aid==12
replace blat =  6.4569186 if aid==39
replace blon = -2.3125100 if aid==39
replace elat = blat if inlist(aid,12,39)
replace elon = blon if inlist(aid,12,39)
gen byte relocate = inlist(aid,12,39)
label var relocate "Coordinates supplied by the survey firm, not the interview GPS"
save `axy', replace

* ---- GPS/stamp visit log, Apr-Sep 2025 ----
import excel using "$path/Biweekly survey data/AEA Records.xlsx", ///
    sheet("Data 2025") firstrow clear
keep if !missing(Date)
split WayPoints, parse(",") destring
rename (WayPoints1 WayPoints2) (slat slon)
mksig AEA sig
merge m:1 sig using "$tmp/aea_name_xwalk.dta", keep(3) keepusing(aid_true) nogen
rename aid_true aid
gen mon = mofd(Date)
egen __d = tag(aid Date)
egen __t = tag(aid Date CommunityVisited)
egen __m = tag(aid mon)
bysort aid: egen st_days  = total(__d)
bysort aid: egen st_trips = total(__t)
bysort aid: egen st_mon   = total(__m)

* keep the waypoint level too: one row per logged farmer contact, with the
* distance from the AEA's duty station to the point where the visit was logged.
* Used by the descriptive figures in fig_dist_visits.do.
preserve
    merge m:1 aid using `axy', keepusing(blat blon) keep(3) nogen
    gen dla = (slat-blat)*_pi/180
    gen dlo = (slon-blon)*_pi/180
    gen aa  = sin(dla/2)^2 + cos(slat*_pi/180)*cos(blat*_pi/180)*sin(dlo/2)^2
    gen wp_km = 6371*2*atan2(sqrt(aa), sqrt(1-aa))
    drop dla dlo aa
    gen month = month(Date)
    gen dow   = dow(Date)
    rename CommunityVisited comm
    rename Remarks remark
    keep aid Date month dow comm slat slon wp_km remark
    label var wp_km "Distance from the AEA's duty station to the logged visit (km)"
    label var month "Month of 2025"
    save "$tmp/aea_stamp_wp.dta", replace
    di _n "===== waypoint-level: distance travelled to a logged visit ====="
    tabstat wp_km, stat(n mean p50 p90 max) col(stat) format(%8.2f)
restore

collapse (median) slat slon (count) st_wp=slat (max) st_days st_trips st_mon, by(aid)
label var st_wp    "Geo-tagged farmer contacts logged (Apr--Sep 2025)"
label var st_days  "Days with a logged visit (Apr--Sep 2025)"
label var st_trips "Logged community-days (Apr--Sep 2025)"
save "$tmp/aea_stamp_xy.dta", replace
di _n "===== GPS/stamp log coverage ====="
tabstat st_wp st_days st_trips st_mon, stat(n mean p50 min max) col(stat) format(%8.1f)

* ---- AEA self-reported number of farmer groups assisted (denominator for Fig 5) ----
use "$path/Baseline/AEA baseline.dta", clear
rename aea aid
keep aid panelB_A
rename panelB_A groups
label var groups "Farmer groups assisted, AEA self-report (2024)"
save "$tmp/aea_groups.dta", replace

* ---- endline farmers with the name-resolved AEA ----
use "$path/Endline/Cover.dta", clear
decode aea_name, gen(__aname)
mksig __aname sig
merge m:1 sig using "$tmp/aea_name_xwalk.dta", keep(1 3) keepusing(aid_true) nogen
rename aid_true aid
keep hhID aid community latitude longitude
save "$tmp/farmer_aid_xy.dta", replace

* ---- distance: AEA -> centroid of each community it serves ----
collapse (mean) clat=latitude clon=longitude (count) nf=hhID, by(aid community)
merge m:1 aid using `axy', keep(3) nogen
* great-circle (haversine) distance in km, once per wave
gen dla = (clat-blat)*_pi/180
gen dlo = (clon-blon)*_pi/180
gen aa  = sin(dla/2)^2 + cos(clat*_pi/180)*cos(blat*_pi/180)*sin(dlo/2)^2
gen d_b = 6371*2*atan2(sqrt(aa), sqrt(1-aa))
drop dla dlo aa

gen dla = (clat-elat)*_pi/180
gen dlo = (clon-elon)*_pi/180
gen aa  = sin(dla/2)^2 + cos(clat*_pi/180)*cos(elat*_pi/180)*sin(dlo/2)^2
gen d_e = 6371*2*atan2(sqrt(aa), sqrt(1-aa))
drop dla dlo aa
label var d_b "Distance to community served (km)"
keep aid community nf d_b d_e relocate
save "$tmp/aea_comm_dist.dta", replace

* ---- farmer-level distance (this farmer's community, served by this AEA) ----
preserve
    use "$tmp/farmer_aid_xy.dta", clear
    merge m:1 aid community using "$tmp/aea_comm_dist.dta", keepusing(d_b) keep(1 3) nogen
    rename d_b dist_km
    gen lndist = ln(dist_km)
    label var dist_km "Distance AEA--community (km)"
    label var lndist  "ln distance AEA--community"
    keep hhID aid dist_km lndist
    save "$tmp/farmer_dist.dta", replace
    di _n "===== farmer-level distance ====="
    tabstat dist_km, stat(n mean p50 p90 max) col(stat) format(%8.2f)
restore

* ---- AEA-level mean distance ----
collapse (mean) d_b d_e (sum) nf (max) relocate (count) ncomm=d_b, by(aid)
label var ncomm "Sample communities tracked for this AEA (1-2)"
label var d_b "Distance to communities served (km)"
save "$tmp/aea_dist.dta", replace
di _n "===== distance: AEA-level, interview GPS corrected for aid 12 & 39 ====="
tabstat d_b d_e, stat(mean p50 p90 max n) col(stat) format(%8.1f)
