*==============================================================================
* STYLE DEMO -- three ways to write the SAME main production table.
* Nothing here is wired into the pipeline; it exists so we can agree on a style
* before rewriting do/f_endline_analysis.do (854 lines) and the rest.
*
* Pick A, B or C (or say what to change) and I will convert every do-file.
*==============================================================================


*==============================================================================
* WHAT THE CODE DOES TODAY  (current f_endline_analysis.do, lines ~328-390)
*==============================================================================
* A 40-line program hides the estimation; the outcome list is built by appending
* one macro onto another; the table options are themselves macros. To change one
* outcome you must read four places at once.
*
*     local prod rev_ha rincome_ha finc_ha lfinc yield lnyield nonprod ...
*     local prod `prod' lnrincome fincnb_ha lfincnb famdnb_ha
*     foreach y of local prod {
*         est_one `y' `y'_bl
*     }
*     local prod1 yield lnyield nonprod rincome_ha lnrincome finc_ha ...
*     local MT1 mtitles("Yield" "Log yield" ...)
*     esttab `prod1' using "$tmp/e_farmer_prod.tex", replace ///
*         keep(`kcoef') coeflabels(`clab') stats(`sstat', fmt(`sfmt') ...) `MT1'


*==============================================================================
* OPTION A -- fully explicit. No program, no loop, no outcome macros.
* Every regression is written out. Longest, but each block is self-contained:
* you can highlight one block, run it, and see exactly one column of the table.
*==============================================================================
use "$tmp/farmer_e_analysis.dta", clear

*--- column (1): yield --------------------------------------------------------
* control-group means printed at the foot of the table
summarize yield_bl if treat_dis==0
scalar bmean = r(mean)
summarize yield if treat_dis==0
scalar cmean = r(mean)

* ANCOVA: treatment arms, stamp, irrigation scheme, baseline yield, province FE
reg yield i.treat_dis i.gps i.irrgsch yield_bl i.prov, cluster(district)

* wild cluster bootstrap (Webb weights) -- only 10 districts, so cluster SEs alone
* are not reliable
boottest 1.treat_dis, reps(9999) weight(webb) nograph
scalar wb_t1 = r(p)
boottest 2.treat_dis, reps(9999) weight(webb) nograph
scalar wb_t2 = r(p)

* randomization inference: re-randomize the arms 1,000 times
gen t1m = (treat_dis==1)
gen t2m = (treat_dis==2)
set seed 12345
randcmd ((t1m t2m) reg yield t1m t2m gps i.irrgsch yield_bl i.prov, ///
    cluster(district)), reps(1000) treatvars(t1m t2m)
matrix ri = e(RCoef)
scalar ri_t1 = ri[1,6]
scalar ri_t2 = ri[2,6]
drop t1m t2m

* store the column and attach the numbers that go under it
eststo yield: reg yield i.treat_dis i.gps i.irrgsch yield_bl i.prov, cluster(district)
test 1.treat_dis = 2.treat_dis
estadd scalar t12p  = r(p)
estadd scalar bmean = bmean
estadd scalar cmean = cmean
estadd scalar wb_t1 = wb_t1
estadd scalar wb_t2 = wb_t2
estadd scalar ri_t1 = ri_t1
estadd scalar ri_t2 = ri_t2

*--- column (2): log yield ----------------------------------------------------
* ... the same 30 lines again with lnyield in place of yield ...

*--- column (3): crop failure -------------------------------------------------
* ... and again ...

* NOTE: 9 columns in this table x ~30 lines = ~270 lines for one table, and the
* file has 10 more tables. Honest cost: f_endline_analysis.do would grow from
* 854 lines to roughly 4,000. Every block is readable on its own, but a change
* to the specification has to be made 100+ times, which is where errors creep in.


*==============================================================================
* OPTION B -- one small program, everything else explicit.  <-- my suggestion
* The program holds ONLY the four inference steps, which are identical for every
* outcome and are the part you would not want to retype 100 times. Outcome lists
* and table options are written out literally at the point of use.
*==============================================================================

* ---------------------------------------------------------------------------
* ancova: run one outcome and store it as a table column.
*   y     = endline outcome
*   ylag  = its baseline value (the ANCOVA control)
* Specification: y on arms + stamp + irrigation scheme + ylag + province FE,
* SE clustered at district, plus wild bootstrap and randomization inference.
* ---------------------------------------------------------------------------
capture program drop ancova
program define ancova
    args y ylag

    summarize `ylag' if treat_dis==0
    scalar bmean = r(mean)
    summarize `y' if treat_dis==0
    scalar cmean = r(mean)

    reg `y' i.treat_dis i.gps i.irrgsch `ylag' i.prov, cluster(district)

    boottest 1.treat_dis, reps(9999) weight(webb) nograph
    scalar wb_t1 = r(p)
    boottest 2.treat_dis, reps(9999) weight(webb) nograph
    scalar wb_t2 = r(p)

    gen t1m = (treat_dis==1)
    gen t2m = (treat_dis==2)
    set seed 12345
    randcmd ((t1m t2m) reg `y' t1m t2m gps i.irrgsch `ylag' i.prov, ///
        cluster(district)), reps(1000) treatvars(t1m t2m)
    matrix ri = e(RCoef)
    scalar ri_t1 = ri[1,6]
    scalar ri_t2 = ri[2,6]
    drop t1m t2m

    eststo `y': reg `y' i.treat_dis i.gps i.irrgsch `ylag' i.prov, cluster(district)
    test 1.treat_dis = 2.treat_dis
    estadd scalar t12p  = r(p)
    estadd scalar bmean = bmean
    estadd scalar cmean = cmean
    estadd scalar wb_t1 = wb_t1
    estadd scalar wb_t2 = wb_t2
    estadd scalar ri_t1 = ri_t1
    estadd scalar ri_t2 = ri_t2
end

use "$tmp/farmer_e_analysis.dta", clear
eststo clear

* one line per column of the table, in the order they appear
ancova yield       yield_bl
ancova lnyield     lnyield_bl
ancova nonprod     nonprod_bl
ancova rincome_ha  rincome_ha_bl
ancova lnrincome   lnrincome_bl
ancova finc_ha     finc_ha_bl
ancova lfinc       lfinc_bl
ancova fincnb_ha   fincnb_ha_bl
ancova lfincnb     lfincnb_bl

* the table, written out in full -- no macros
esttab yield lnyield nonprod rincome_ha lnrincome finc_ha lfinc fincnb_ha lfincnb ///
    using "$tmp/e_farmer_prod.tex", replace ///
    se nogap b(%9.3f) label booktabs nonotes ///
    keep(1.treat_dis 2.treat_dis 1.gps 1.irrgsch) ///
    coeflabels(1.treat_dis  "T1: Feedback"           ///
               2.treat_dis  "T2: Feedback+Training"  ///
               1.gps        "Stamp (GPS)"            ///
               1.irrgsch    "Irrigation")            ///
    stats(t12p bmean cmean wb_t1 wb_t2 ri_t1 ri_t2 N, ///
          fmt(%9.3f %9.3f %9.3f %9.3f %9.3f %9.3f %9.3f %9.0g) ///
          labels("T1=T2 [p]" "Ctrl mean (base)" "Ctrl mean (end)" ///
                 "Wild-boot p (T1)" "Wild-boot p (T2)" ///
                 "RI p (T1)" "RI p (T2)" "Obs")) ///
    mtitles("Yield" "Log yield" "Crop fail" "Income/ha" "Log income" ///
            "Profit/ha" "Log profit" "Profit excl.\ bird" "Log profit excl.") ///
    star(* 0.10 ** 0.05 *** 0.01)


*==============================================================================
* OPTION C -- Option B, plus split the 854-line file into topic files.
* Same code as B; only the filing changes:
*
*   f_endline_main.do        main production / input / practice tables
*   f_endline_weighted.do    sampling-weighted robustness
*   f_endline_noirr.do       excluding the two irrigation schemes
*   f_endline_2sls.do        all 2SLS blocks
*   f_endline_appendix.do    FB/TR, Glejser, bird scaring, knowledge
*
* Co-authors then open the one file they care about instead of scrolling 854
* lines. run_endline_all.do calls them in order, exactly as it does now.
*==============================================================================
