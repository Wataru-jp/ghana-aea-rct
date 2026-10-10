*==============================================================================
* make_ms_tables.do -- fixed-width copies of the esttab fragments that the
* manuscript stacks into multi-panel tables.
*
* WHY. esttab writes \begin{tabular}{l*{k}{c}} and puts every header in a
* \multicolumn{1}{c}{}, so each panel sizes its columns to its own content.
* Stacked in one table, column (1) of Panel A then sits somewhere else than
* column (1) of Panel B. These copies replace the column types with the two
* fixed-width ones the manuscript preamble defines -- S for the stub, P for a
* data column -- so column (1) starts at the same point in every panel, whatever
* the panel's column count. Nothing else in the file is touched: the numbers,
* stars and statistics come straight from the originals.
*
* The manuscript must define, with the same widths used when these were made:
*     \newcolumntype{S}{>{\raggedright\arraybackslash}p{3.2cm}}
*     \newcolumntype{P}{>{\centering\arraybackslash}p{1.85cm}}
*
* Run after the analysis do-files that write the originals.
* Input : tmp/<name>.tex     Output: tmp/ms_<name>.tex
*==============================================================================
set more off
global path "/Users/wkodama/Documents/research/ghana-aea-rct/"
global tmp  "$path/tmp"

capture program drop fixcols
program define fixcols
    args src ncol
    tempname IN OUT
    file open `IN'  using "$tmp/`src'.tex",    read
    file open `OUT' using "$tmp/ms_`src'.tex", write replace
    local hits = 0
    file read `IN' line
    while r(eof) == 0 {
        local out `"`macval(line)'"'
        if strpos(`"`macval(out)'"', "\begin{tabular}{l*{`ncol'}{c}}") {
            local out "\begin{tabular}{@{}S*{`ncol'}{P}@{}}"
            local ++hits
        }
        local out : subinstr local out "\multicolumn{1}{c}{" "\multicolumn{1}{P}{", all
        file write `OUT' `"`macval(out)'"' _n
        file read `IN' line
    }
    file close `IN'
    file close `OUT'
    if `hits' != 1 {
        di as error "`src': expected one tabular preamble with `ncol' columns, found `hits'"
        exit 459
    }
    di as txt "ms_`src'.tex written (`ncol' columns)"
end

fixcols e_aea_attitude    5
fixcols e_aea_effort_ms   5
fixcols e_farmer_prod     9
fixcols e_farmer_inputs   7
fixcols e_farmer_practice 8
fixcols e_labour_sex      8
fixcols e_labour_ops     12

di _n "=== manuscript panel fragments written ==="
