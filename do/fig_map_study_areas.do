*==============================================================================
* fig_map_study_areas.do -- the study-area map on the deck.
*
* Ghana's 260 ADM2 districts in light grey with thin borders, the 10 ADM1
* regions drawn over them in a heavier line, and the study districts filled by
* treatment arm. In Ghana ADM1 = region and ADM2 = district.
*
* THE TWO IRRIGATION SCHEMES. Kpong and Weta are irrigation schemes, both in
* the control arm, and every estimation drops them. Neither is an administrative
* unit -- Weta sits inside Ketu North district -- so colouring a whole district
* would overstate how much of it the scheme covers. Both are therefore
* drawn as triangles at the mean GPS location of the farmers sampled there, and
* share one legend entry.
*
* DISTRICT NAMES. The boundary file spells two of ours differently. The names
* used below are the BOUNDARY FILE's spellings, verified against its .dbf
* (260 records), Oct 2026:
*     ours                      boundary file
*     Lower Manya Krobo      -> Lower Manya
*     Bibiani-Ahwiaso-Bekwai -> Bibiani-anhwiaso-bekwai Municipal
*     Sefwi Wiaoso           -> Sefwi-wiawso
*
* WHY spshape2dta AND NOT shp2dta. shp2dta (ssc) cannot read these files: it
* reads the one-byte dBASE field type with fbufget(..., "%5s"), i.e. the type
* byte plus the four "field data address" bytes after it, and compares the
* result with "C". Most shapefiles leave those four bytes zero so the comparison
* happens to work; geoBoundaries writes the real address (0x01, 0x26, ...) and
* shp2dta aborts with "invalid dBASE data type". Stata's official spshape2dta
* reads the same file without complaint, so we use that and grmap instead. Do
* not switch back to shp2dta/spmap without re-testing.
*
* THREE grmap TRAPS, all hit while building this map:
*   - grmap ships deactivated and refuses to run until `grmap, activate'.
*   - label() may NOT be repeated. A second label() makes grmap hang silently
*     -- no error, no output, no CPU. Label positions are therefore handled with
*     one label() plus hand-tuned coordinate nudges.
*   - position() inside label() takes a constant, not a variable, and legend
*     labels are truncated at roughly 30 characters.
*   - ndlabel("") does NOT drop the "No data" key; grmap substitutes the default
*     whenever the string is empty. The key is removed by overriding grmap's own
*     legend order: with three classes plus one point overlay the keys are
*     1 = no data, 2-4 = the classes, 6 = the point overlay, hence order(2 3 4 6).
* Drawing takes about three minutes.
*
* Input : shp/geoBoundaries-GHA-ADM1-all/geoBoundaries-GHA-ADM1_simplified.*
*         shp/geoBoundaries-GHA-ADM2-all/geoBoundaries-GHA-ADM2_simplified.*
*           symlink to Dropbox; boundary data is not kept in the repository.
*           Source: geoBoundaries (www.geoboundaries.org).
*         tmp/farmer_aid_xy.dta   farmer coordinates (do/aea_distance.do)
*         Baseline/AEA.dta        district code per AEA (3 = Kpong, 8 = Weta)
* Output: tmp/fig_map_study_areas.pdf
*==============================================================================
set more off
capture noisily grmap, activate

global path "/Users/wkodama/Documents/research/ghana-aea-rct"
global tmp  "$path/tmp"
global shp1 "$path/shp/geoBoundaries-GHA-ADM1-all"
global shp2 "$path/shp/geoBoundaries-GHA-ADM2-all"

*------------------------------------------------------------------------------
* 1. Shapefiles -> Stata. spshape2dta writes <name>.dta (one row per unit,
*    already spset) and <name>_shp.dta (boundary vertices). grmap finds the
*    _shp file by name, so both must sit in the working directory.
*------------------------------------------------------------------------------
cd "$tmp"
spshape2dta "$shp2/geoBoundaries-GHA-ADM2_simplified", replace saving(gha_adm2)
spshape2dta "$shp1/geoBoundaries-GHA-ADM1_simplified", replace saving(gha_adm1)

use "$tmp/gha_adm2.dta", clear
qui count
di as txt "districts in the boundary file: " r(N) "  (expected 260)"

*------------------------------------------------------------------------------
* 2. Label the eight rainfed study districts.
*------------------------------------------------------------------------------
gen byte arm = .
replace arm = 1 if inlist(shapeName, "Pru West", "Biakoye")
replace arm = 2 if inlist(shapeName, "Sene West", "Achiase", "Bibiani-anhwiaso-bekwai Municipal")
replace arm = 3 if inlist(shapeName, "Lower Manya", "Krachi West", "Sefwi-wiawso")

* Legend labels are truncated at roughly 30 characters.
label define armlbl 1 "Control" 2 "T1: Feedback" 3 "T2: Feedback + Training"
label values arm armlbl

qui count if arm < .
if r(N) != 8 {
    di as error "matched " r(N) " districts, expected 8 -- check the spellings in the header"
    list shapeName if arm < ., noobs clean
    exit 459
}
di as txt "study districts matched: 8 of 8 (the two irrigation schemes are points)"
save "$tmp/gha_adm2.dta", replace

*------------------------------------------------------------------------------
* 3. Name labels: the mean of each district's boundary vertices. Good enough to
*    anchor a label on a slide; a true centroid is not needed.
*
*    Every label is drawn above its anchor (position 12), so collisions are
*    resolved by nudging the anchor -- Sefwi Wiaoso away from Bibiani, Lower
*    Manya away from the Kpong marker. The nudges are in degrees and were set
*    by eye against the drawn map.
*------------------------------------------------------------------------------
use "$tmp/gha_adm2_shp.dta", clear
collapse (mean) _X _Y, by(_ID)
merge 1:1 _ID using "$tmp/gha_adm2.dta", keepusing(shapeName arm) keep(3) nogen
keep if arm < .

gen str20 nm = shapeName
replace nm = "Bibiani"      if shapeName == "Bibiani-anhwiaso-bekwai Municipal"
replace nm = "Sefwi Wiaoso" if shapeName == "Sefwi-wiawso"

replace _X = _X - 0.24 if nm == "Sefwi Wiaoso"
replace _Y = _Y + 0.20 if nm == "Sefwi Wiaoso"
replace _X = _X + 0.38 if nm == "Bibiani"
replace _Y = _Y - 0.22 if nm == "Bibiani"
replace _X = _X - 0.45 if nm == "Lower Manya"
replace _Y = _Y + 0.08 if nm == "Lower Manya"
keep _X _Y nm
tempfile dislab
save `dislab'

*------------------------------------------------------------------------------
* 4. The two irrigation schemes as points: the mean position of the farmers
*    sampled there. Their names are appended to the label file, with the anchor
*    dropped below the marker so the name clears the triangle.
*------------------------------------------------------------------------------
use "$tmp/farmer_aid_xy.dta", clear
merge m:1 aid using "$path/Baseline/AEA.dta", keepusing(discode) keep(3) nogen
keep if inlist(discode, 3, 8)
gen str20 nm = cond(discode == 3, "Kpong", "Weta")
collapse (mean) latitude longitude (count) n = latitude, by(nm)
list nm n, noobs clean
if _N != 2 {
    di as error "expected both irrigation schemes, found " _N
    exit 459
}
save "$tmp/map_points.dta", replace

replace longitude = longitude - 0.26
replace latitude  = latitude  - 0.30
rename (longitude latitude) (_X _Y)
keep _X _Y nm
append using `dislab'
save "$tmp/map_labels.dta", replace

*------------------------------------------------------------------------------
* 5. Draw. The ADM1 overlay carries no legend entry; the irrigation triangles
*    carry one shared entry.
*------------------------------------------------------------------------------
use "$tmp/gha_adm2.dta", clear
grmap arm, ///
    clmethod(unique) ///
    fcolor("130 130 130" "230 120 0" "0 130 60") ///
    ocolor(gs12 gs12 gs12) osize(0.06 0.06 0.06) ///
    ndfcolor(gs15) ndocolor(gs13) ndsize(0.04) ///
    polygon(data("$tmp/gha_adm1_shp.dta") fcolor(none) ocolor(gs7) osize(0.45) legenda(off)) ///
    point(data("$tmp/map_points.dta") x(longitude) y(latitude) ///
          fcolor("205 205 205") ocolor(black) osize(0.35) size(3.0) shape(triangle) ///
          legenda(on) leglabel("Irrigation scheme")) ///
    label(data("$tmp/map_labels.dta") x(_X) y(_Y) label(nm) ///
          size(2.7) position(12) gap(0.5) length(40)) ///
    legenda(on) legend(order(2 3 4 6) pos(5) size(2.9) symy(3.4) symx(3.4) ///
            region(lstyle(none))) ///
    plotregion(margin(zero))

graph export "$tmp/fig_map_study_areas.pdf", replace
cd "$path"
di _n "=== fig_map_study_areas.pdf written ==="
