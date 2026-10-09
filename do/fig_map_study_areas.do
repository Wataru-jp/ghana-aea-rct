*==============================================================================
* fig_map_study_areas.do -- the study-area map on the deck.
*
* Ghana's 260 districts in light grey with thin borders, the 16 regions drawn
* over them in a heavier line, the eight rainfed study districts filled by
* treatment arm and outlined in black, and the two irrigation schemes marked
* with triangles.
*
* WHY GADM AND NOT geoBoundaries. geoBoundaries does not publish a nested
* hierarchy for Ghana: its ADM1 is OpenStreetMap (2021, 16 regions) while its
* ADM2 is USAID Ghana HPNO / Ghana Statistical Service (2019, 260 districts).
* Drawn together the two share neither a coastline nor any internal border, and
* re-downloading does not help. GADM 4.1 derives level 1 from level 2, so the
* region lines fall exactly on district lines. GADM also carries the parent
* region on every district (NAME_1), which geoBoundaries does not.
*
* DISTRICT NAMES. GADM's spellings differ from ours; the names below are
* GADM's, verified against gadm41_GHA_2.dbf (260 records), Oct 2026. Note the
* trailing hyphen on Bibiani -- it is in the source, not a typo.
*     ours                      GADM NAME_2
*     Lower Manya Krobo      -> Lower Manya-Krobo
*     Bibiani-Ahwiaso-Bekwai -> Bibiani-Anhwiaso-Bekwai-
*     Sefwi Wiaoso           -> Sefwi-Wiawso
*
* THINNING. GADM is unsimplified: 662,153 vertices at level 2 and 214,137 at
* level 1, which makes a 4 MB figure. Both layers are therefore thinned to
* every third vertex (221,226 and 71,416; 1.4 MB) -- the first and last point
* of every part are always kept so polygons still close, and small parts are
* kept whole. Set $thin to 1 to draw the full geometry. Thinning harder is not
* worth it: at every tenth vertex the Lake Volta shoreline tears open. The two
* layers are thinned independently, so a shared border can shift by a few
* hundred metres between them -- about a tenth of a point here, i.e. invisible.
* Do not reuse the thinned files for anything but drawing.
*
* RUN THIS WITH stata-se, NOT stataSE. The Mac filesystem is case-insensitive,
* so .../MacOS/stataSE resolves to the GUI binary StataSE; in batch it can stop
* on a modal alert and then sleeps for ever using no CPU. The console binary
* .../MacOS/stata-se runs this file in about four seconds.
*
* Input : shp/gadm41_GHA_shp/gadm41_GHA_1.*   regions
*         shp/gadm41_GHA_shp/gadm41_GHA_2.*   districts
*           symlink to Dropbox; boundary data is not kept in the repository.
*           Source: GADM 4.1 (gadm.org), licensed for non-commercial use.
*         tmp/farmer_aid_xy.dta   farmer coordinates (do/aea_distance.do)
*         Baseline/AEA.dta        district code per AEA (3 = Kpong, 8 = Weta)
* Output: tmp/fig_map_study_areas.pdf
*==============================================================================
set more off
set graphics off          // batch runs can block on the graph window
capture noisily grmap, activate

global path "/Users/wkodama/Documents/research/ghana-aea-rct"
global tmp  "$path/tmp"
global gadm "$path/shp/gadm41_GHA_shp"
global thin 3             // keep every THINth vertex; 1 = no thinning

*------------------------------------------------------------------------------
* 1. Shapefiles -> Stata. spshape2dta writes <name>.dta (one row per unit,
*    already spset) and <name>_shp.dta (boundary vertices). grmap finds the
*    _shp file by name, so both must sit in the working directory.
*------------------------------------------------------------------------------
cd "$tmp"
spshape2dta "$gadm/gadm41_GHA_1", replace saving(gadm1)
spshape2dta "$gadm/gadm41_GHA_2", replace saving(gadm2)

*------------------------------------------------------------------------------
* 2. Thin both boundary files for drawing (see the header). A part starts at a
*    row with a missing coordinate, so the running count of those rows groups
*    the vertices into parts.
*------------------------------------------------------------------------------
foreach f in gadm1 gadm2 {
    use "$tmp/`f'_shp.dta", clear
    local before = _N
    gen long row  = _n
    gen long part = sum(missing(_X))
    bysort part (row): gen long v  = _n
    bysort part (row): gen long nv = _N
    keep if missing(_X) | nv < 60 | v == 1 | v == nv | mod(v, $thin) == 0
    * bysort left the data flagged as sorted on part; grmap refuses anything not
    * sorted on _ID. row keeps the vertices in their original order.
    sort _ID row
    drop row part v nv
    di as txt "`f': " `before' " vertices -> " _N
    save "$tmp/`f'_shp.dta", replace
}

*------------------------------------------------------------------------------
* 3. Label the eight rainfed study districts.
*------------------------------------------------------------------------------
use "$tmp/gadm2.dta", clear
qui count
di as txt "districts in the boundary file: " r(N) "  (expected 260)"

gen byte arm = .
replace arm = 1 if inlist(NAME_2, "Pru West", "Biakoye")
replace arm = 2 if inlist(NAME_2, "Sene West", "Achiase", "Bibiani-Anhwiaso-Bekwai-")
replace arm = 3 if inlist(NAME_2, "Lower Manya-Krobo", "Krachi West", "Sefwi-Wiawso")

* Legend labels are truncated at roughly 30 characters.
label define armlbl 1 "Control" 2 "T1: Feedback" 3 "T2: Feedback + Training"
label values arm armlbl

qui count if arm < .
if r(N) != 8 {
    di as error "matched " r(N) " districts, expected 8 -- check the spellings in the header"
    list NAME_2 if arm < ., noobs clean
    exit 459
}
di as txt "study districts matched: 8 of 8 (the two irrigation schemes are points)"
sort _ID
save "$tmp/gadm2.dta", replace

*------------------------------------------------------------------------------
* 4. Name labels: the mean of each district's boundary vertices. Good enough to
*    anchor a label on a slide; a true centroid is not needed.
*
*    Every label is drawn above its anchor (position 12), so collisions are
*    resolved by nudging the anchor -- Sefwi Wiaoso away from Bibiani, Lower
*    Manya away from the Kpong marker. The nudges are in degrees and were set
*    by eye against the drawn map.
*------------------------------------------------------------------------------
use "$tmp/gadm2_shp.dta", clear
collapse (mean) _X _Y, by(_ID)
merge 1:1 _ID using "$tmp/gadm2.dta", keepusing(NAME_2 arm) keep(3) nogen
keep if arm < .

gen str20 nm = NAME_2
replace nm = "Bibiani"      if NAME_2 == "Bibiani-Anhwiaso-Bekwai-"
replace nm = "Sefwi Wiaoso" if NAME_2 == "Sefwi-Wiawso"
replace nm = "Lower Manya"  if NAME_2 == "Lower Manya-Krobo"

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
* 5. The two irrigation schemes as points: the mean position of the farmers
*    sampled there. Neither is an administrative unit -- Weta sits inside Ketu
*    North district -- so colouring a whole district would overstate how much
*    of it the scheme covers. Their names are appended to the label file, with
*    the anchor moved off the marker so the name clears the triangle.
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
* 6. Draw. The region overlay carries no legend entry; the irrigation triangles
*    carry one shared entry.
*------------------------------------------------------------------------------
use "$tmp/gadm2.dta", clear
grmap arm, ///
    clmethod(unique) ///
    fcolor("130 130 130" "230 120 0" "0 130 60") ///
    ocolor(black black black) osize(0.28 0.28 0.28) ///
    ndfcolor(gs15) ndocolor(gs13) ndsize(0.04) ///
    polygon(data("$tmp/gadm1_shp.dta") fcolor(none) ocolor(gs7) osize(0.40) legenda(off)) ///
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
