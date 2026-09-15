*! dagplot.ado 0.1.0 2026-08-31
*! A standalone fork of nwcommands_2016's nwplot, forked specifically so
*! this package's `interactive` rendering pipeline (this file's own
*! interactive block + the two mata functions it calls, plus
*! dagplot_template.html and vendor/cytoscape.min.js sitting next to this
*! .ado) can be freely edited by dagy/dagplot's own maintainer without
*! any risk to nwcommands' own `nwplot` command, or vice versa.
*!
*! Forked as of nwcommands_2016's nwplot.ado at the point a real bug was
*! found in its `interactive` view (nodes invisible - a position/size
*! unit mismatch in the html/js template's cytoscape rendering; edges
*! rendered fine since canvas gives line strokes a minimum on-screen
*! width that a near-zero node diameter doesn't get) - fixed here in
*! dagplot_template.html's render().
*!
*! ALSO forks the viewer-launch path end to end, not just the rendering:
*! _dagplot_openviewer.ado (this package's own fork of nw_openviewer.ado)
*! launches native/dagplot_viewer.mm's compiled binary
*! (plugins/macos/dagplot_viewer), which carries a second real bug fix -
*! a persistent WKWebsiteDataStore whose default cache directory
*! collides with the staged binary's own temp-file path, leaving the
*! interactive window blank - switched to a nonPersistentDataStore.
*! nwcommands' own nwplot/nw_openviewer/nwedit_viewer were deliberately
*! reverted to their original (still-buggy on both counts) state per an
*! explicit request to keep nwcommands itself untouched while keeping
*! dagplot's own fixes; this is why dagplot needed its own copy of the
*! launcher and native binary too, not just the rendering template.
*!
*! Every Stata program and Mata function this file defines was renamed
*! from nwplot's own (nwplot -> dagplot, _getcolorstyle ->
*! _dagplot_getcolorstyle, sugiyamalayout -> dagplot_sugiyamalayout,
*! etc.) - Stata programs and Mata functions both live in a single
*! global namespace regardless of which file defined them, so an
*! unrenamed copy loaded in the same session as the real nwplot.ado
*! would silently overwrite (or be overwritten by) whichever loads
*! second, corrupting BOTH commands' behavior depending on load order.
*! Layout algorithms other than nodexy() (fruchtreinlayout, mmdslayout,
*! gridlayout, sugiyamalayout, bipartitelayout, ...) came along for the
*! ride from the full-file copy and still work, but dagy itself always
*! supplies its own pre-computed nodexy() and never exercises them.
*!
*! Depends on nwcommands_2016 being on adopath only for nwset (dagy
*! calls it directly before dagplot) - the interactive viewer's launcher
*! and native binary are dagplot's own now, not shared with nwcommands.
capture program drop dagplot
program dagplot, rclass
	version 9.0
	unw_defs
	
	set more off
	local 0_original = `"`0'"'
	local layout = ""
	syntax [anything(name=netname)][if/] [in/], [ ignorelgc lab  labelopt(string) _layoutfunction(string) arrows edgesize(string) ASPECTratio(string) components(string) arcstyle(string) arcbend(string) arcsplines(integer 10) nodexy(varlist numeric min=2 max=2) edgeforeground(string) GENerate(string) colorpalette(string) edgecolorpalette(string) edgepatternpalette(string) symbolpalette(string) lineopt(string) scatteropt(string) legendopt(string) size(string) color(string) symbol(string) edgecolor(string) label(varname) nodefactor(string) sizebin(string) edgefactor(string) arrowfactor(string) arrowgap(string) arrowbarbfactor(string) layout(string) iterations(integer 1000) scheme(string) EXPORT(string) replace EXPORTOPT(string) interactive IMPORTCOORDS(string) EDGEIMPORT(string) movieexport(string) NOOpen * ]
	// interactive/importcoords()/edgeimport() must ALSO be declared here
	// (not just in the real parse at line ~449) even though this parse is
	// otherwise a throwaway used only to extract layout() for re-parsing
	// below - this pass's own catchall `options' becomes `twowayopt',
	// which gets spliced verbatim into the final `graph twoway ...' call;
	// confirmed directly that omitting them here made `interactive' leak
	// into `twowayopt' and crash the final plot with "option interactive
	// not allowed" straight from `graph twoway' itself.
	local twowayopt `"`options'"'

	nw_datasync `netname'
	
	// filter out lgc and nodeclash
	local 0 "`layout'"
	syntax [anything(name=something)], [ lgc nodeclash(string) *]
	local nodeproximity : word 2 of `nodeclash'
	capture confirm number `nodeproximity'
	if _rc != 0 {
		local nodeproximity = 0.01
	}
	local nodeclashchange : word 1 of `nodeclash'
	capture confirm number `nodeclashchange'
	if _rc != 0 {
		local nodeclashchange= 1
	}

	tempvar lgc_var

	if "`ignorelgc'" != "" {
		local lgc = ""
	}
	local ignorelgc = ""
	
	if "`lgc'" != "" {
		// was "nwgen `lgc_var' = lgc(`netname')" - same broken-shortcut
		// bug as the mdsclassical block's own "components(")/"lgc("
		// calls further down this file (see that fix's own comment for
		// the full explanation); this is a second, independent call
		// site hitting the identical issue, fixed the same way.
		qui nwcomponents `netname', lgc generate(`lgc_var')
		local if_lgc = " `lgc_var' == 1"
	}
	
	local 0 = `"`0_original'"'
	syntax [anything(name=netname)][if/] [in/], [ lab  labelopt(string) _layoutfunction(string) arrows edgesize(string) ASPECTratio(string) components(string) arcstyle(string) arcbend(string) arcsplines(integer 10) nodexy(varlist numeric min=2 max=2) edgeforeground(string) GENerate(string) colorpalette(string) edgecolorpalette(string) edgepatternpalette(string) symbolpalette(string) lineopt(string) scatteropt(string) legendopt(string) size(string) color(string) symbol(string) edgecolor(string) label(varname) nodefactor(string) sizebin(string) edgefactor(string) arrowfactor(string) arrowgap(string) arrowbarbfactor(string) layout(string) iterations(integer 100) scheme(string) EXPORT(string) replace EXPORTOPT(string) interactive IMPORTCOORDS(string) EDGEIMPORT(string) movieexport(string) NOOpen * ]

	// Default node fill color and edge line color are both resolved as
	// "scheme p<n>" / "scheme p<n>line" further down (_dagplot_getcolorstyle) -
	// left at "" here, `scheme' previously fell through to whatever
	// graph scheme happened to be ambient (c(scheme), Stata's own
	// ordinary default being "stcolor"). Confirmed directly (rendered a
	// tiny two-point scatter+line graph with mfcolor("scheme p1") and
	// lcolor("scheme p1line") under stcolor and inspected the actual
	// pixels) that stcolor defines p1 and p1line as the identical blue -
	// reasonable for an ordinary statistical graph (a single series'
	// marker and connecting line usually SHOULD match), but wrong for a
	// network plot, where nodes and edges need to read as visually
	// distinct by default. Default to one of the package's own
	// network-oriented schemes instead, which deliberately give p1/
	// p1line different colors (see scheme-s1network.scheme) - already
	// packaged in _pkg_ado.txt, just never actually used unless a caller
	// remembered to pass scheme() explicitly.
	if "`scheme'" == "" {
		local scheme "s1network"
	}

	// importcoords() merges its x/y columns straight into nodexy()'s own
	// variables (see the merge right after the nodexy() block below), so
	// it has nothing to merge into without nodexy() also being given.
	if "`importcoords'" != "" & "`nodexy'" == "" {
		di "{err}Option {bf:importcoords()} requires {bf:nodexy(xvar yvar)} - it merges the imported x/y coordinates into those variables before they are read as the plot's layout."
		error 198
	}

	nw_syntax `netname', max(1)
	qui nwsummarize `netname'
	if `r(density)' == 0 {
		di "{txt}Network empty. Plotting does not make sense.{txt}"
		exit
	}
	
	local masternetname "`netname'"
	
	if "`if_lgc'" != "" {
		local if = "`if_lgc'"
	}
	
	gettoken edgecolor_original edgecolor_options : edgecolor, parse(",")
	gettoken edgesize_original edgesize_options : edgesize, parse(",")
	local edgecolor `edgecolor_original'
	local edgesize `edgesize_original'
	
	if "`labelopt'" != "" {
		local scatteropt "`scatteropt' `labelopt'"
	}

    if "`in'" != "" {
		capture nwdrop _temp_in
		nwduplicate `netname', name(__temp_in)
		nwkeep __temp_in in `in'
		if "`edgecolor'" != "" {
			capture nwdrop __temp_edgecolor_in
			nwgen __temp_edgecolor_in = `edgecolor'
			local edgecolor "__temp_edgecolor_in"
			if "`edgecolor'" != "`netname'" {
				nwkeep __temp_edgecolor_in in `in'
			}
		}
		if "`edgesize'" != "" {
			nwgen __temp_edgesize_in = `edgesize'
			local edgesize "__temp_edgesize_in"
			if "`edgesize'" != "`netname'" & "`edgesize'" != "`edgecolor'"{
				nwkeep __temp_edgesize_in in `in'
			}
		}
		local netname "__temp_in"
		nw_syntax `netname', max(1)
	}

     if "`if'"!="" {
		local ifmaster "if `if'"
		capture nwdrop __temp_if
		nwduplicate `netname', name(__temp_if)
		nwdrop __temp_if if (!(`if'))
		if "`edgecolor'" != "" {
			capture nwdrop _temp_edgecolor_if
			nwduplicate `edgecolor', name(__temp_edgecolor_if)
			local edgecolor "__temp_edgecolor_if"
			nwdrop __temp_edgecolor_if if (!(`if'))
		}
		if "`edgesize'" != "" {
			capture nwdrop _temp_edgesize_if
			nwduplicate `edgesize', name(__temp_edgesize_if)
			local edgesize "_temp_edgesize_if"
			nwdrop __temp_edgesize_if if (!(`if'))
		}
		
		local netname "__temp_if"
	}
	nw_syntax `netname', max(1)

	// interactive/importcoords() companion (nwedit_template.html). The
	// node-edit CSV importcoords() reads back is validated and captured
	// into Mata here -- before nodefactor()/edgefactor() get their
	// defaults below and before the NODE ATTRIBUTES preserve block (which
	// computes ncolor/nsymbol) further down. Mata objects created here
	// survive every later preserve/restore in this program exactly like
	// ncolor/nsize/nlabel already do (same idiom, not a new one).
	if "`importcoords'" != "" {
		preserve
		import delimited "`importcoords'", clear varnames(1) case(preserve)
		if _N != `nodes' {
			di "{err}importcoords() file `importcoords' has `=_N' rows but network `netname' has `nodes' nodes; re-export from the interactive view, or check if/in - importcoords() must be run against a network of the same size as the interactive export it came from."
			error 6056
		}
		capture assert node_row == _n
		if _rc {
			di "{err}importcoords() file `importcoords' is not in row order (node_row must read 1, 2, 3, ... in order) - re-export from the interactive view rather than hand-editing the file."
			error 6056
		}
		// color_group/shape_group columns are exported for possible future
		// diagnostic use but not consumed here - the actual join is by
		// physical row order against THIS call's own freshly-computed
		// ncolor/nsymbol (see _dagplot_buildgroupmap calls below), matching
		// how nodexy()/label() already key off row order with no separate
		// node-ID concept anywhere else in this file.
		mata: _nwedit_x = st_data(., "x")
		mata: _nwedit_y = st_data(., "y")
		mata: _nwedit_color = st_sdata(., "color")
		mata: _nwedit_shape = st_sdata(., "shape")
		local _nwedit_nodefactor = nodefactor[1]
		local _nwedit_edgefactor = edgefactor[1]
		restore
	}

	qui if "`lab'" != ""{
		local label "`nw_nodename'"
	}
	
	capture which labellist
	if _rc != 0 {
		ssc install labellist
	}

		
	if "`aspectratio'" == "" {
		local aspectratio = 1
	}
	local aspectratio = `aspectratio'*  0.67
	
	if "`sizebin'" == "" {
		local sizebin = 1
	}
	// BUGFIX: the top-level sizebin() option declared in this program's
	// own main `syntax' line was dead code - `size()'s own content is
	// re-parsed via a SECOND `syntax' call further down (which also
	// declares its own sizebin(integer 1) sub-option, for
	// `size(varname, sizebin(#))'-style calls), and that second call
	// unconditionally resets `sizebin' to its own default whenever
	// size()'s own text doesn't itself contain a sizebin() sub-option -
	// silently discarding whatever the caller passed to the separate
	// top-level option on every single call. Preserved here so it can
	// be restored afterward when size() didn't specify its own.
	local __sizebin_toplevel "`sizebin'"

	if "`arrowbarbfactor'" == "" {
		local arrowbarbfactor = 1
	}
	local arrowbarbfactor = `arrowbarbfactor' * 0.7
	
	// explicit nodefactor()/edgefactor() always wins if given; otherwise
	// fall back to the interactive view's own size/width-factor sliders
	// when importcoords()/edgeimport() supplied one - same "sub-option's
	// own value wins, else fall back to the top-level default" precedence
	// this file already uses for sizebin() (see the __sizebin_toplevel
	// comment above).
	if "`nodefactor'" == "" & "`_nwedit_nodefactor'" != "" {
		local nodefactor = `_nwedit_nodefactor'
	}
	if "`nodefactor'" == "" {
		local nodefactor = 1
	}
	local nodefactor = `nodefactor' / 50
	/*if `nodes' > 20 {
		local nodefactor = `nodefactor' / 1.5
	}*/

	if "`edgefactor'" == "" & "`_nwedit_edgefactor'" != "" {
		local edgefactor = `_nwedit_edgefactor'
	}
	if "`edgefactor'" == "" {
		local edgefactor = 1
	}
	if "`arrowfactor'" == "" {
		local arrowfactor = 1
	}
	
	if "`arrowgap'" == "" {
		local arrowgap = 0
	}
	local arrowgap = `arrowgap' + 0.5

	if "`arcstyle'" == "" {
		local arcstyle = "automatic"
	}
	_opts_oneof "automatic curved straight" "arcstyle" "`arcstyle'" 6556

	if "`arcbend'" == "" {
		local arcbend = 1
	}
	local arcbend = `arcbend' * 2
	
	nw_syntax `netname'
	
	local gridcols = ceil(sqrt(`nodes'))
	local 0 = "`layout'"
	syntax [anything][, nodeclash(string) lgc norescale iterations(integer 1000) columns(integer `gridcols') vertical ]
	
	if("`anything'"=="") {
		// kk (Kamada-Kawai) is the default layout - previously mds
		// (<50 nodes) or mdsclassical (>=50), chosen by node count.
		// kk's own cost scales with both node count and iterations()
		// (see layout(kk)'s own dispatch below for the adaptive
		// iteration-count scaling this relies on to stay fast on large
		// networks), so it no longer needs a node-count-based default
		// layout CHOICE the way mds/mdsclassical did.
		local anything "kk"
	}
	
	local layout_norescale "`rescale'"
	local layout_gridcols = "`columns'"
	local layout_components = "`components'"
	local layout_bipartite_vertical "`vertical'"
	local layout = "`anything'"
	_opts_oneof "mds mdsclassical frucht kk hierarchy bipartite grid circle nodexy _layoutfunction" "layout" "`layout'" 6556


	// Check matsize (because mds requires STATA matrix)
	if (c(matsize) <`nodes'& "`layout'" == "mds") {
		if "`c(flavor)'" == "Small" {
			di "{err}STATA Small can only use {it:layout(mds)} with networks with max. {bf:100} nodes; {it:layout(circle)} selected instead."
			local layout = "circle"
		}
		else {
			if (c(SE) == 0 & c(MP) == 0 & `nodes' > 800){
				di "{err}STATA/IC can only use {it:layout(mds)} with networks with max. {bf:800} nodes; {it:layout(circle)} selected instead."
				local layout = "circle"
			}
			else{ 
				if (`nodes' > 11000) {
					di "{err}Unfortunately, STATA can only use {it:layout(mds)} with networks with max. {bf:1100} nodes; {it:layout(circle)} selected instead."
					local layout = "circle"
				}
				else {
					set matsize `nodes'
				}
			}
		}
	}
	
	local dolabel  = ("`label'" !="")

	if "`directed'" == "false" & "`arcstyle'" == "automatic" {
		local arcstyle = "straight"
	}

	if "`directed'" == "true" {
		local arrows = "arrows"
	}
	if "`arrows'" != "" {
		local pc "pcarrow"
		local doarrows = 1
	}
	else {
		local pc "pcspike"
		local doarrows = 0
	}
	if "`scheme'" != "" {
		local schemetwoway "scheme(`scheme')"
	}
	
	///////////////////
	//
	// NODE ATTRIBUTES
	//
	///////////////////

	preserve
	if "`ifmaster'" != "" {
		keep `ifmaster'
	}
	
	// Color of nodes
	local colorkeys ""
	local colororder ""
	local colorlabels ""
	
	if ("`color'" != ""){
		local 0 = "`color'"
		// BUGFIX: colorpalette() couldn't be abbreviated here (unlike
		// the same-named, same-purpose option in the sibling command
		// nwplotmatrix, which declares it "COlorpalette" - a minimum
		// abbreviation of "co") because this declaration was plain
		// lowercase, which Stata's syntax parser never abbreviates.
		// Capitalized to match the sibling convention.
		syntax [varlist(default=none max=1)] [, foreground(string) norescale forcekeys(string) legendoff COlorpalette(string) mlcolor(string) mlwidth(string) *]
		
		local mlcolor_color = "`mlcolor'"
		local mlwidth_color = "`mlwidth'"
		local colorforeground = "`foreground'"
		
		if "`varlist'" == "" {
			tempvar dummy_col
			gen `dummy_col' = 1
			local varlist "`dummy_col'"
			local legendoff "legendoff"
		}
		tempvar color_numeric
		capture encode `varlist' , gen(`color_numeric')
		if _rc == 0 {
			local varlist "`color_numeric'"
		}
		
		local colorkeys = "`forcekeys'"
		local colorkeys_legendoff "`legendoff'"
		local fnum : word count `forcekeys'
				
		// Use forced keys
		local j = 1
		if "`forcekeys'" != "" {
			qui tab `varlist' if _n <= `nodes', matrow(colorkeysmap)
			foreach i in `forcekeys' {
				local colororder "`colororder' `j'"
				local ckey = colorkeysmap[`i', 1]
				_dagplot_getvaluelabel `varlist', key(`ckey')
				local colorlabels `"`colorlabels' label(`j' "`r(key_label)'")"'
				local j = `j' + 1
			}
		}
			
		// Rescale colors
		if "`rescale'" == "" {	
			tempvar __color
			egen `__color' = group(`varlist')
			mata: ncolor = st_data((1,`nodes'),st_varindex("`__color'"))
			if "`forcekeys'" == "" {
				qui tab `varlist' if _n <= `nodes', matrow(colorkeysmap)
				forvalues i = 1/`r(r)' {
					local ckey = colorkeysmap[`i', 1]
					local colorkeys "`colorkeys' `i'"
					local colororder "`colororder' `i'"
					_dagplot_getvaluelabel `varlist', key(`ckey')
					local key_label : label (`varlist') `i'
					local colorlabels `"`colorlabels' label(`i' "`r(key_label)'")"'
					local _nwedit_colorlabel_`i' "`r(key_label)'"
				}
			}
		}
		else {
			mata: ncolor = st_data((1,`nodes'),st_varindex("`varlist'"))
			if "`forcekeys'" == "" {
				qui tab `varlist' if _n <= `nodes', matrow(colorkeysmap)
				forvalues i = 1/`r(r)' {


					local ckey = colorkeysmap[`i', 1]
					local colorkeys "`colorkeys' `ckey'"
					local colororder "`colororder' `i'"
					_dagplot_getvaluelabel `varlist', key(`ckey')
					local colorlabels `"`colorlabels' label(`i' "`r(key_label)'")"'
					local _nwedit_colorlabel_`ckey' "`r(key_label)'"
				}
			}
		}
	}
	else {
		mata: ncolor = J(`nodes',1,1)
		local colorkeys = ""
	}
	if "`importcoords'" != "" {
		_dagplot_buildgroupmap, groupvec(ncolor) valuevec(_nwedit_color) prefix(_nwedit_colormap)
	}
	if "`colorkeys_legendoff'" == ""{
		local keysused : word count `colorkeys'
	}
	else {
		local keysused = 0
		local colororder = ""
		local colorlabels = ""
	}
	
	
	// Symbol of nodes
	local symbolkeys ""
	local symbolorder ""
	local symbollabels ""
	if ("`symbol'" != ""){
		// Check for known schemes without symbol support
		if "`scheme'" == "" {
			local scheme = c(scheme)
		}
		
		if ((strpos("s1color s2color economist", "`scheme'") > 0) & "`symbolpalette'" == "") {
			local symbolpalette "circle diamond square triangle smcircle smdiamond smsquare smtriangle"
		}
		
		local 0 = "`symbol'"
		syntax [varlist(default=none max=1)] [, norescale forcekeys(string) legendoff symbolpalette(string) mlcolor(string) mlwidth(string) *]
		local mlcolor_symbol = "`mlcolor'"
		local mlwidth_symbol = "`mlwidth'"
		
		if "`varlist'" == "" {
			tempvar dummy_symb
			gen `dummy_symb' = 1
			local varlist "`dummy_symb'"
			local legendoff "legendoff"
		}
		tempvar symbol_numeric
		capture encode `varlist', gen(`symbol_numeric')
		if _rc == 0 {
			local varlist "`symbol_numeric'"
		}
		
		local symbolkeys = "`forcekeys'"
		local symbolkeys_legendoff "`legendoff'"
		local fnum : word count `forcekeys'
				
		// Use forced keys
		forvalues i = 1/`fnum' {
			local j = `i' + `keysused' + 1
			local symbolorder "`symbolorder' `j'"
			_dagplot_getvaluelabel `varlist', key(`i')
			local symbollabels `"`symbollabels' label(`j' "`r(key_label)'")"'
		}
			
		// Rescale symbols
		if "`rescale'" == "" {	
			tempvar __symbol
			egen `__symbol' = group(`varlist')
			mata: nsymbol = st_data((1,`nodes'),st_varindex("`__symbol'"))
			if "`forcekeys'" == "" {
				qui tab `varlist' if _n <= `nodes', matrow(symbolkeysmap)
				forvalues i = 1/`r(r)' {
					local j = `i' + `keysused'
					local skey = symbolkeysmap[`i', 1]
					local symbolkeys "`symbolkeys' `i'"
					local symbolorder "`symbolorder' `j'"
					_dagplot_getvaluelabel `varlist', key(`skey')
					local symbollabels `"`symbollabels' label(`j' "`r(key_label)'")"'
					local _nwedit_symbollabel_`i' "`r(key_label)'"
				}
			}
		}
		else {
			mata: nsymbol = st_data((1,`nodes'),st_varindex("`varlist'"))
			if "`forcekeys'" == "" {
				qui tab `varlist' if _n <= `nodes', matrow(symbolkeysmap)
				forvalues i = 1/`r(r)' {
					local j = `i' + `keysused'
					local skey = symbolkeysmap[`i', 1]
					local symbolkeys "`symbolkeys' `skey'"
					local symbolorder "`symbolorder' `j'"
					_dagplot_getvaluelabel `varlist', key(`skey')
					local symbollabels `"`symbollabels' label(`j' "`r(key_label)'")"'
					local _nwedit_symbollabel_`skey' "`r(key_label)'"
				}
			}
		}
	}
	else {
		mata: nsymbol = J(`nodes',1,1)
	}
	if "`importcoords'" != "" {
		_dagplot_buildgroupmap, groupvec(nsymbol) valuevec(_nwedit_shape) prefix(_nwedit_shapemap)
	}

	local keysused_symbol : word count `symbolkeys'
	if "`symbolkeys_legendoff'" == "" & "`symbol'" != ""{
		local keysused = `keysused' + `keysused_symbol'
	}
	else{
		local symbolkeys = ""
		local symbolorder = ""
		local symbollabels = ""
	}
	
	local __size_raw "`size'"
	local 0 = "`size'"
	syntax [varlist(min=0 max=1 default=none)][, norescale legendoff forcekeys(string) sizebin(integer 1) mlcolor(string) mlwidth(string) *]
	// see the BUGFIX comment above `__sizebin_toplevel' - only fall back
	// to the top-level sizebin() value when size() itself didn't supply
	// its own; a genuine size(var, sizebin(#)) sub-option must still win.
	if !strpos(`"`__size_raw'"', "sizebin(") & "`__sizebin_toplevel'" != "1" {
		local sizebin "`__sizebin_toplevel'"
	}
	local mlcolor_size = "`mlcolor'"
	local mlwidth_size = "`mlwidth'"
	if "`mlcolor_size'" == "" {
		local mlcolor_size = "`mlcolor_color'"
	}
	
	local size "`varlist'"
	// Stashed under its own name because `varlist' itself gets clobbered by
	// every subsequent `syntax' call in this program (color/symbol/edgecolor/
	// edgesize each reuse it) -- the interactive-view size-legend build,
	// much further down, needs the real variable name for its labels and
	// can't rely on `varlist' still holding it by then.
	local _nwedit_sizevarname "`varlist'"
	// Size of nodes
	if ("`size'" != ""){
		local nodefactor = `nodefactor' / 2
		qui sum `varlist' if _n <= `nodes'
		local sizekeys_legendoff "`legendoff'"
		local sizekeys "`=round(`r(min)',0.01)' `=round(`r(max)',0.01)'"
		local sizekeys_size "`=round(`r(min)',0.01)' `=round(`r(max)',0.01)'"
		
		if "`forcekeys'" != "" {
			local sizekeys "`forcekeys'"
		}	
		capture drop __size
		gen __size = `varlist'
		// `_nwedit_sizekeys_rawnsize': the interactive canvas's own legend
		// (built much further down, in the `interactive' block) needs a
		// px-comparable magnitude for exactly the `sizekeys' values (2
		// representative points, e.g. min/max - the SAME count and values
		// the real static plot's own size legend shows) - NOT one entry
		// per distinct value actually in the data (an earlier version of
		// this fix used `nsizerow' for that instead, which is wrong: for a
		// continuous size() variable, nsizerow can have a dozen-plus
		// distinct rendered sizes, one per near-unique data value, while
		// dagplot's real legend has always shown just the representative
		// range). Deliberately NOT reusing `sizekeys_size' below for this -
		// that local is scaled for Stata's own msize() graph-legend units
		// (nodefactor baked in here, before its final /20 two lines below),
		// not comparable to the interactive canvas's CSS-px scale, which
		// the mata HTML builder derives from the RAW (pre-nodefactor)
		// magnitude of `nsize' via its own htmlnodefactor multiply. Mirrors
		// each branch's own per-node raw-magnitude formula immediately
		// below, evaluated at each sizekey instead of at each node's own
		// data value.
		local _nwedit_sizekeys_rawnsize ""
		if "`rescale'" == "" {
			local sizekeys_size ""
			if (`r(min)' != `r(max)') {
				qui replace __size = 1000 + 3000 * (`varlist') / (`r(max)')
				foreach szkey in `sizekeys' {
					local sizekeys_size_temp `= 1000 + 3000 * (`szkey' / (`r(max)'))'
					local _nwedit_sizekeys_rawnsize "`_nwedit_sizekeys_rawnsize' `sizekeys_size_temp'"
					local sizekeys_size_temp = `sizekeys_size_temp' * `nodefactor' * 2/20
					local sizekeys_size "`sizekeys_size' `sizekeys_size_temp'"
				}
			}
			else {
				qui replace __size = 1500
				local szkey = 1500
				local sizekeys "`r(min)'"
				local _nwedit_sizekeys_rawnsize "1000"
				local sizekeys_size_temp = 1000
				local sizekeys_size_temp = `sizekeys_size_temp' * `nodefactor' * 2/20
				local sizekeys_size "`sizekeys_size' `sizekeys_size_temp'"
			}
			mata: nsize = st_data((1,`nodes'),st_varindex("__size"))
		}
		else {
			local sizekeys_size ""
			foreach szkey in `sizekeys' {
				local sizekeys_size "`sizekeys_size' `= 0.04 * `szkey''"
				local _nwedit_sizekeys_rawnsize "`_nwedit_sizekeys_rawnsize' `= 40 * `szkey''"
			}
			mata: nsize = st_data((1,`nodes'),st_varindex("__size"))
			mata: nsize = nsize :*40
		}
		local nodefactor = `nodefactor' / 20
		capture drop __size
	}
	else {
		mata: nsize = J(`nodes',1,80)
		local sizekeys ""
	}
	
	local sizeorder = ""
	local sizelabels = ""	
	local keysused_size : word count `sizekeys'
	if "`sizekeys_legendoff'" == ""  & "`size'" != ""{
		forvalues i = 1/ `keysused_size' {
			local sizelabel_temp : word `i' of `sizekeys'
			local sizeorder "`sizeorder' `=`keysused' + `i''"
			local sizelabels `"`sizelabels' label(`=`keysused' + `i'' "`varlist' = `sizelabel_temp'")"'
		}
		local keysused = `keysused' + `keysused_size'
	}
	else {
		local sizekeys = ""
	}
	
	restore
	
	// Label of nodes
	qui if ("`label'" != ""){
		capture confirm string variable `label'
		if _rc != 0 {
			tempvar nlabel_string
			tostring `label', generate(`nlabel_string') force
			mata: nlabel = st_sdata((1,`nodes'),st_varindex("`nlabel_string'"))
		}
		else {
			mata: nlabel = st_sdata((1,`nodes'),st_varindex("`label'"))
		}
	}
	else {
		mata: nlabel = J(`nodes',1,"")
	}

	////////////////////
	//
	//   EDGE ATTRIBUTES
	//
	////////////////////
	
	// Get network data
	nwtomata `netname', mat(plotmat)
	mata: M = (plotmat + plotmat') :/ (plotmat + plotmat')
	mata: _editmissing(M,0)
	// Get edgesize network data
	if "`edgesize'" != "" {
		if "`edgesize'" == "," {
			nwrandom `nodes', prob(1) name(__temp_edgesize_dummy)
			local edgesize "__temp_edgesize_dummy,"
			if strpos("`edgesize_options'", "legendoff") == 0 {
				local edgesize_options `"`edgesize_options' legendoff"'
			}
		}
		local 0 "`edgesize'`edgesize_options'"
		capture noi syntax [anything] [, forcekeys(string) legendoff ]
		if _rc != 0 {
			nwdrop __temp_edgesize_dummy
			error 6088
		}
		
		// check and clean networks as edgecolor and edgesize
		local edgesizekeys_legendoff "`legendoff'"
		local edgesize "`anything'"			
		nw_syntax `edgesize', max(1) nocurrent other(other)
		local edgesize_directed = "`otherdirected'"	
		local edgesize = trim("`othernetname'")
		local siznodes `othernodes'
		
		if "`labs'" != "`otherlabs'" & "`force'" == ""{
			di "{err}{it:network} {bf:`edgesize'} has different labels than {it:network} {bf:`netname'}; use option {bf:force}"
			error 6056
		}
		
		if `nodes' != `siznodes' {
			di "{err}{it:network} {bf:`edgesize'} needs to be of the same size as {it:network} {bf:`netname'}"
			error 6056
		}
		local edgesizekeys "`forcekeys'"
		if "`forcekeys'" == "" {
			local edgesizekeys "`r(minval)' `r(maxval)'"
		}
		nwtomata `edgesize', mat(edgesizemat)
		nwname `edgesize', newdirected("`edgesize_directed'")
	}
	else {
		mata: edgesizemat = J(`nodes',`nodes',1)
		local edgesizekeys ""
	}
	
	local edgesizeorder = ""
	local edgesizelabels = ""	
	local keysused_edgesize : word count `edgesizekeys'
	if "`edgesizekeys_legendoff'" == ""  & "`edgesize'" != ""{
		forvalues i = 1/ `keysused_edgesize' {
			local edgesizelabel_temp : word `i' of `edgesizekeys'
			local edgesizeorder "`edgesizeorder' `=`keysused' + `i''"
			local edgesizelabels `"`edgesizelabels' label(`=`keysused' + `i'' "`edgesize_original' = `edgesizelabel_temp'")"'
		}
		local keysused = `keysused' + `keysused_edgesize'
	}
	else {
		local edgesizekeys = ""	
	}
	
	// Get edgecolor network data
	if "`edgecolor'" != ""  {
		if "`edgecolor'" == "," {
			capture nwdrop __temp_edgecol_dummy
			nwrandom `nodes', prob(0) name(__temp_edgecol_dummy)
			//nwreplace __temp_egdecol_dummy = .
			local edgecolor "__temp_edgecol_dummy,"
			if strpos("`edgecolor_options'", "legendoff") == 0 {
				local edgecolor_options `"`edgecolor_options' legendoff"'
			}
		}
		local 0 "`edgecolor'`edgecolor_options'"
		capture noi syntax [anything] [, foreground(string) forcekeys(string) legendoff edgecolorpalette(string) edgepatternpalette(string)]
		local edgeforeground = "`foreground'"
		if _rc != 0 {
			nwdrop __temp_edgecolor_dummy
			error 6088
		}
		// check and clean network 
		local edgecolorkeys_legendoff "`legendoff'"
		local edgecolor "`anything'"
		nw_syntax `edgecolor', max(1) nocurrent other(other)
		local edgecolor_directed = "`otherdirected'"	
		local edgecolor = trim("`othernetname'")
		local siznodes = `othernodes'
		
		if "`labs'" != "`otherlabs'" & "`force'" == ""{
			di "{err}{it:network} {bf:`edgecolor'} has different labels than {it:network} {bf:`netname'}; use option {bf:force}"
			error 6056
		}
		
		if `nodes' != `siznodes' {
			di "{err}{it:network} {bf:`edgecolor'} needs to be of the same size as {it:network} {bf:`netname'}"
			error 6056
		}
		local edgecolorkeys "`forcekeys'"

		qui if "`forcekeys'" == "" {
			nwtabulate `edgecolor', matrow(r)
			matrix edgecolor_mat = r
			
			local edgecolor_matrows = rowsof(edgecolor_mat)
			forvalues i = 1/`edgecolor_matrows'{
				local eckey = edgecolor_mat[`i',1]
				local edgecolorkeys "`edgecolorkeys' `=`eckey'+1'"
			}
		}
		nwtomata `edgecolor', mat(edgecolormat)
		mata: edgecolormat = edgecolormat :+ 1
		nwname `edgecolor', newdirected("`edgecolor_directed'")
	}
	else {
		mata: edgecolormat = J(`nodes',`nodes',0)
	}

	local edgecolororder = ""
	local edgecolorlabels = ""	
	local keysused_edgecolor : word count `edgecolorkeys'
	if "`edgecolorkeys_legendoff'" == ""  & "`edgecolor'" != ""{
		forvalues i = 1/ `keysused_edgecolor' {
			local edgecolorlabel_temp : word `i' of `edgecolorkeys'
			local edgecolororder "`edgecolororder' `=`keysused' + `i''"
			local edgecolorlabels `"`edgecolorlabels' label(`=`keysused' + `i'' "`edgecolor_original' = `=`edgecolorlabel_temp'-1'")"'
			local _nwedit_edgecolorlabel_`edgecolorlabel_temp' "`edgecolor_original' = `=`edgecolorlabel_temp'-1'"
		}
		local keysused = `keysused' + `keysused_edgecolor'
	}
	else {
		local edgecolorkeys = ""	
	}

	////////////////////
	//
	//   CALCULATE NODE COORDINATES
	//
	////////////////////
	
	
	if "`nodexy'" != "" {
		local layout = "nodexy"
		local nodex = word("`nodexy'", 1)
		local nodey = word("`nodexy'", 2)

		/*
		foreach nvar of varlist `nodex' `nodey' {
			qui sum `nvar'
			if (r(min) < 0 | r(max) >= 2) {
				di "{err}Node coordinates not between 0 and 1.5 Option {it:layout(mds)} selected instead."
				local layout = "mds"
			}
		}*/

		// importcoords() overrides nodexy()'s own variables with the
		// interactively dragged positions -- same "manual override beats
		// computed default" pattern dagplot already uses for nodexy()
		// itself overriding a computed Coord.
		if "`importcoords'" != "" {
			mata: st_store((1::rows(_nwedit_x)), "`nodex'", _nwedit_x)
			mata: st_store((1::rows(_nwedit_y)), "`nodey'", _nwedit_y)
		}
	}
	
	/*
	if "`nodexy'" != "" {
		tempvar xcor ycor
		local layout = "nodexy"
		local nodex = word("`nodexy'", 1)
		local nodey = word("`nodexy'", 2)
		local k = 1
		if "`layout_norescale'" == "" {
			gen `xcor' = `nodex'
			gen `ycor' = `nodey'
			qui sum `xcor'
			replace `xcor' =(1.25 * (`xcor' - r(min)) / (r(max) - r(min))) + 0.25
			qui sum `ycor'
			replace `ycor' = (`ycor' - r(min)) / (r(max) - r(min))
			local nodex "`xcor'"
			local nodey "`ycor'"
		}
		else {
			//qui sum `nodex'
			/*if (r(min) < 0.25 | r(max) >= 1.5) {
				di "{err}Node coordinates outside of valid range; {it:layout(mds)} selected instead."
				local layout = "mds"		
			}
			else {
				qui sum `nodey'
				if (r(min) < 0 | r(max) >= 1) {
					di "{err}Node coordinates outside of valid range; {it:layout(mds)} selected instead."
					local layout = "mds"
				}
			}*/
		}
	}*/
	
	
	local layout_gridcols "`columns'"
	local components = "`layout_components'"
	
	if ("`layout'"!="nodexy"){
		di "{text:Calculating node coordinates...}"
	}
	// BUGFIX: every layout below crashed outright on a single-node
	// network with a different raw error (mds: "dimension exceeds
	// #rows of dissimilarity matrix", r(498); circle/grid: a Mata
	// conformability error; mdsclassical: "_outdegree not found",
	// r(111)) - each layout algorithm needs at least 2 nodes to have
	// anything meaningful to compute (a distance matrix, a circle
	// arrangement, etc.), but none of them special-cased the trivial
	// n=1 case, where the only sensible answer is simply "the one node
	// goes somewhere". Placed at the center of this file's own
	// established [0,~1.5] x [0,1] plotting coordinate range (see the
	// nodexy rescale logic above) and every layout-specific computation
	// below skipped entirely for this case, rather than trying to make
	// each of the 7 different layout algorithms individually tolerate
	// a degenerate 1-node input.
	if (`nodes' == 1) {
		mata: Coord = J(1,2,0.5)
	}
	if ("`layout'"=="_layoutfunction" & `nodes' > 1) {
		gettoken _layoutfcn _layoutfcnopt: _layoutfunction, parse(",")
		mata: Coord = `_layoutfcn'(M`_layoutfcnopt')
	}
	if ("`layout'"== "mds" & `nodes' > 1){
		mata: Coord = dagplot_netplotmds(M, `iterations')
	}

	if ("`layout'"=="frucht" & `nodes' > 1){
		mata: Coord = dagplot_fruchtrein(M, `iterations')
	}

	if ("`layout'"=="kk" & `nodes' > 1){
		// `kk' is now the default layout (previously mds/mdsclassical,
		// chosen by node count) - but its own cost is quadratic in
		// nodes AND linear in iterations() (confirmed by direct timing:
		// 1.1s at 50 nodes, 11.8s at 200, 72s at 500, all at the plain
		// 1000-iteration default - already too slow by the time a
		// network reaches a few hundred nodes to keep as a silent
		// default). When the caller has not overridden iterations()
		// (still sitting at its own unmodified 1000 default), scale it
		// down as node count grows so a default `dagplot` call stays
		// around ~8 seconds regardless of network size, rather than
		// silently taking minutes on a large network - full quality
		// (1000 iterations) is kept for networks up to a few hundred
		// nodes, where it was already fast. An explicit
		// `iterations()' from the caller always overrides this.
		local kk_iter = `iterations'
		if `iterations' == 1000 {
			local kk_iter = min(1000, max(10, floor(28000000 / (`nodes'^2))))
		}
		mata: Coord = kklayout(M, `kk_iter')
	}

	if ("`layout'"=="hierarchy" & `nodes' > 1){
		// unlike every other layout() branch here, this one needs the
		// RAW, direction-preserving adjacency - `M' just above (line
		// ~1101) is `(plotmat + plotmat''):/(plotmat + plotmat'')', a
		// deliberately symmetrized 0/1 matrix every other layout uses
		// (frucht/mds/kk are all direction-agnostic by design), which
		// would silently discard the very edge-direction information
		// this layering algorithm depends on - confirmed directly via a
		// hand-built 5-node DAG that came out with sources and sinks in
		// the wrong order before this fix. `plotmat' itself (from
		// nwtomata just above) only has a missing diagonal, never
		// missing off-diagonal cells (confirmed directly) - cleared to
		// 0 here rather than left missing, since a Mata `!=0' comparison
		// on a missing value would otherwise evaluate as true.
		mata: Mdir = plotmat
		mata: _editmissing(Mdir, 0)
		mata: Coord = dagplot_sugiyamalayout(Mdir, `iterations')
		mata: mata drop Mdir
	}

	if ("`layout'"=="bipartite" & `nodes' > 1){
		if "`is2mode'" != "true" {
			di "{err}Option {bf:layout(bipartite)} requires a two-mode network; network `netname' is not two-mode."
			error 198
		}
		mata: Mdir2 = plotmat
		mata: _editmissing(Mdir2, 0)
		mata: modevec = `netobj'->get_modes()
		mata: Coord = dagplot_bipartitelayout(Mdir2, modevec, `=("`layout_bipartite_vertical'"!="")')
		mata: mata drop Mdir2 modevec
	}

    qui if ("`layout'"=="mdsclassical" & `nodes' > 1 ){
		// Coordinates matrix to be populated
		mata: Coord = J(`nodes', 2, 0)
		mata: Coord[.,1] = J(`nodes', 1, 1.5) 
		// Deal with isolates
		//
		// was "nwgen `_isolates' = isolates(`netname')" - "isolates(" is
		// listed in nwgenerate.ado's own recognized-keyword vocabulary
		// (so it parses without error) but has no actual dispatch branch
		// implementing it (nwgenerate.ado only implements the
		// NETWORK-producing shortcuts - large/duplicate/dyadprob/.../
		// transpose; "isolates(" is one of a separate, larger family of
		// VARIABLE-producing shortcuts - degree/outdegree/indegree/
		// isolates/components/lgc/clustering/closeness/farness/nearness/
		// between/evcent/context/addnodes/collapse/subset - that are all
		// recognized but silently no-op instead of erroring). This meant
		// the tempvar was never actually created, and the very next
		// line ("count if `_isolates' == 1") crashed with a "not found"
		// - meaning mdsclassical, the DEFAULT layout for any network
		// with more than 50 nodes, was completely broken for every
		// caller, not a rare edge case - confirmed via a minimal
		// "nwrandom 60, prob(.15)" + "dagplot" repro, traced to this
		// exact line via "set trace on". The general nwgen/nwgenerate
		// variable-shortcut gap is a separate, much larger pre-existing
		// issue (see docs/CERTIFICATION.md's Pending table) - out of
		// scope to fix generally here; this fix routes dagplot's own
		// internal isolates lookup through nwdegree's plain default
		// degree computation instead (its own "isolates" option turned
		// out to have a second, independent, genuine bug - confirmed
		// via "set trace on": with "isolates" given and no explicit
		// generate(), nwdegree.ado reserves only ONE output-variable
		// name ("_isolates"), but its directed-network branch
		// unconditionally needs TWO (outdegree and indegree storage) -
		// crashing with an empty target variable name on any directed
		// network, which "nwrandom" defaults to. Recorded as its own,
		// separate, not-yet-fixed bug in docs/CERTIFICATION.md's
		// Pending table rather than patched here, to keep this fix
		// narrowly scoped to dagplot.ado. nwdegree's plain default
		// behaviour - not the buggy "isolates" option - is exactly the
		// same well-tested, heavily-used code path every other caller
		// of nwdegree already relies on, so the isolate indicator is
		// simply derived from it directly afterward.
		// BUGFIX: a single compound "capture drop A B C D" is NOT
		// equivalent to dropping each variable independently - Stata's
		// drop command is all-or-nothing over its whole varlist, so if
		// even ONE named variable does not exist, the ENTIRE command
		// fails and drops NOTHING, not even the others that do exist
		// (confirmed via a direct, minimal probe: "capture drop a b c d"
		// with only a/b existing left both a and b undropped). Exactly
		// one of _degree (undirected) or _outdegree/_indegree (directed)
		// is ever actually created by nwdegree below - the other name(s)
		// never exist - so this compound drop always silently failed via
		// `capture', on every single call, for every network, leaving
		// _isolates and whichever of _degree/_outdegree/_indegree WAS
		// created stranded in the dataset after dagplot returned. That
		// stranded leftover then collided with nwdegree's own "variable
		// already exists" guard on the very next call that tried to
		// generate the same default variable name - dagplot's own next
		// invocation (this exact line, on ANY network), a later user
		// nwdegree call, or dagplot's internal isolates recomputation for
		// a second network, all indistinguishably, since these are
		// ordinary Stata dataset variables shared across the whole
		// session, not scoped to any one network. This is the actual
		// root cause of the "dagplot/nwdegree fail with a bare r(99)
		// after creating a second network" report - reproduces
		// identically on a single network (no second network needed),
		// confirmed via a direct repro before this fix. Splitting into
		// one drop per variable makes each one independent: a missing
		// variable is silently skipped (via `capture'), not treated as
		// a reason to abandon dropping the others.
		capture drop _isolates
		capture drop _degree
		capture drop _outdegree
		capture drop _indegree
		qui nwdegree `netname', silent
		capture confirm variable _degree
		if _rc == 0 {
			qui gen _isolates = (_degree == 0)
		}
		else {
			qui gen _isolates = (_outdegree == 0) & (_indegree == 0)
		}
		qui count if _isolates == 1
		local isol = `r(N)'
		// same fix as the pre-emptive cleanup above - one drop per
		// variable, not a single compound drop that silently fails
		// entirely (and drops nothing) the moment any one of these four
		// names doesn't exist, which is always true for at least one of
		// _degree vs _outdegree/_indegree.
		capture drop _isolates
		capture drop _degree
		capture drop _outdegree
		capture drop _indegree
		local nonisol = `nodes' - `isol'
		
		// Get number of components
		//
		// was "nwgenerate `_component' = components(`netname')" /
		// "nwgen `_component' = lgc(`netname')" - "components(" and
		// "lgc(" are two more instances of the exact same broken-
		// shortcut family as "isolates(" just above (recognized by
		// nwgenerate.ado's own keyword vocabulary, but with no actual
		// dispatch branch implementing either one) - both calls
		// silently left `_component' never created, which crashed the
		// very next real statement ("tab `_component', ...") with
		// "nothing found where name expected" / a Mata "invalid Stata
		// variable name" error. Routed through nwcomponents instead -
		// already well-tested (this session's own certification
		// history), and it directly provides both the per-node
		// component-id variable AND r(components) in one call, exactly
		// what this code already expected to have. Note "local compnum"/
		// "local compnum_nonisol" just below are otherwise-unused dead
		// locals (confirmed via a direct grep across the whole file -
		// nothing downstream ever references either one; the real
		// downstream driver is "comp_nonisol", computed independently a
		// few lines below from comp_freqid) - left in place rather than
		// removed, since deleting unrelated dead code is out of scope
		// for this fix.
		tempvar _component
		qui nwcomponents `netname', generate(`_component')
		if "`lgc'" != "" {
			qui nwcomponents `netname', lgc generate(`_component') replace
			replace `_component' = 1 - `_component'
			local components = 1
		}

		local compnum = r(components)
		local compnum_nonisol = `compnum' - `isol'
		qui tab `_component', matrow(comp_id) matcell(comp_freq)

		mata: comp_id = st_matrix("comp_id")
		mata: comp_freq = st_matrix("comp_freq")
		mata: comp_freqid = J(rows(comp_id), 2,0)
		mata: comp_freqid[.,1] = comp_freq
		mata: comp_freqid[.,2] = comp_id
		mata: comp_freqid = sort(comp_freqid, - 1)
		mata: comp_nonisol = sum((comp_freqid[.,1] :> 1))
		mata: st_numscalar("r(comp_nonisol)", comp_nonisol)
		local comp_nonisol = `r(comp_nonisol)'
		mata: st_matrix("comp_freqid", comp_freqid)

		// Find overall layout
		// Default = number of (non-isolates) components (undirected)
		if "`components'" == "" {
			local components = `comp_nonisol'
		}
		// Limit number of distinct boxes in graph
		if `components' > `comp_nonisol' {
			local components = `comp_nonisol'
		}
		if `components' > 5 {
			di "{txt}only the {bf:5} largest components are displayed"
			local components = 5
		}
		
		// Go through all (non-isolates) components (that should be plotted in boxes) from large to small
		qui forvalues i = 1/`components' {
			nwduplicate `netname', name(`netname'_comp`i')
			capture drop _id
			gen _id = _n

			nwdrop `netname'_comp`i' if `_component' != comp_freqid[`i', 2]
			nwtomata `netname'_comp`i', mat(compmat)
			// Original id's of selected nodes
			mata: original_id = st_data((1::rows(compmat)), "_id")

			// Calculate mds coordinates of network i
			mata: compM = (compmat :+ compmat') :/ (compmat :+ compmat')
			mata: _editmissing(compM,0)
			mata: Coord_comp = dagplot_mmdslayout(compM)
			//noi mata: Coord_comp = dagplot_correctCoordClash(Coord_comp, compM, (.05 * `nodeclashchange'), `nodeproximity') 
			// Adjust coordinates for position in layout
			// Deal with largest component
			if `i' == 1  & `components' != 1 {
				mata: Coord_comp[.,1] = Coord_comp[.,1] :* 0.9
				if `components' == 1 {
					mata: Coord_comp[.,1] = Coord_comp[.,1] :+ 0.125
				}
			}
			if `i' == 1  & `components' == 1 {
				mata: Coord_comp[.,1] = Coord_comp[.,1] :+ 0.125
			}
			
			// Deal with second largest component
			if `i' == 2 {
				mata: Coord_comp[.,1] = (Coord_comp[.,1] :*0.45):+ 1.1
				mata: Coord_comp[.,2] = (Coord_comp[.,2] :*0.45):+ .5
			}	
			
			// Assign adjusted coordinates to original network
			mata: Coord[original_id,.] = Coord_comp
			mata: mata drop original_id
			nwdrop `netname'_comp`i'
		}

		// REAL BUG FOUND AND FIXED: every node's own coordinate starts
		// at the SAME uniform default, `(1.5, 0)' (set near the top of
		// this block), and only nodes belonging to one of the
		// `components' DISPLAYED components (the loop just above) ever
		// get that default overwritten. Any component that did not
		// make the "top `components'" cut - true singleton isolates,
		// but also any small multi-node component once there are more
		// than 5 non-trivial components total, since display is capped
		// at 5 - is silently left at the identical default and renders
		// as one overlapping blob at a single point, not spread apart
		// the way dagplot_netplotmds()/kklayout() already correctly spread
		// their own isolates. Confirmed directly on `nwwebuse glasgow'
		// + `dagplot glasgow1' (50 nodes, the mdsclassical default
		// layout threshold, 8 real components but only 5 displayed):
		// all 11 nodes belonging to the 3 undisplayed components came
		// back at the exact same coordinate. Fixed by spreading every
		// left-out node's own y along that same x=1.5 column, matching
		// the k/num_isol convention dagplot_netplotmds()/kklayout() already use
		// for their own isolates.
		mata: __mdsc_dispcomp = comp_freqid[(1::`components'), 2]
		mata: __mdsc_allcomp = st_data(., "`_component'")
		mata: __mdsc_isdisp = J(rows(__mdsc_allcomp), 1, 0)
		mata: for (__mdsc_k=1; __mdsc_k<=rows(__mdsc_dispcomp); __mdsc_k++) __mdsc_isdisp = __mdsc_isdisp :| (__mdsc_allcomp :== __mdsc_dispcomp[__mdsc_k])
		mata: __mdsc_leftidx = selectindex(__mdsc_isdisp :== 0)
		mata: st_numscalar("r(mdsc_nleft)", rows(__mdsc_leftidx))
		if `r(mdsc_nleft)' > 0 {
			mata: Coord[__mdsc_leftidx, 2] = (1::rows(__mdsc_leftidx)) :/ rows(__mdsc_leftidx)
		}
		mata: mata drop __mdsc_dispcomp __mdsc_allcomp __mdsc_isdisp __mdsc_leftidx __mdsc_k

		capture drop _id
	}
	capture replace `label' = `_orig_label'
	
	if ("`layout'"=="circle" & `nodes' > 1){
		mata: Coord = circlelayout(rows(M))
	}
	if ("`layout'"=="grid" & `nodes' > 1){
		if "`layout_gridcols'" == "" {
			local layout_gridcols = ceil(sqrt(`nodes'))
		}
		mata: Coord = dagplot_gridlayout(rows(M), `layout_gridcols')
	}
	if ("`layout'"=="nodexy" & `nodes' > 1){
		// BUGFIX: layout(nodexy) without also specifying nodexy(xvar
		// yvar) used to crash with a raw Mata st_data() "varlist
		// required" error (r3598) - `nodex'/`nodey' are only ever
		// populated inside the nodexy() option's own parsing block
		// above, which layout(nodexy) alone does not trigger.
		if "`nodex'" == "" | "`nodey'" == "" {
			di "{err}Option {bf:nodexy(xvar yvar)} is required with {bf:layout(nodexy)}."
			error 198
		}
		mata: Coord = J(rows(M),2,0)
		mata: Coord[.,1] = st_data((1,rows(M)),"`nodex'")
		mata: Coord[.,2] = st_data((1,rows(M)),"`nodey'")
	}
	
	
	// Obtain tie coordinates
	mata: TC = dagplot_getTieCoordinates(Coord,nsize,dagplot_NumElist(plotmat), edgecolormat, edgesizemat, `nodefactor', `doarrows', `arrowgap')
	mata: st_numscalar("r(TC)", rows(TC))
	local minObs = max(`r(TC)', `nodes')
	local _nwedit_ties = `r(TC)'

	// edgeimport() companion to importcoords() (see nwedit_template.html) -
	// the edge-edit CSV is validated/captured here, once the tie count is
	// finally known (edges have no group/row concept before dagplot_getTieCoordinates
	// runs, unlike nodes) and before the plotting dataset below stores the
	// real per-tie edgecolor values.
	if "`edgeimport'" != "" {
		preserve
		import delimited "`edgeimport'", clear varnames(1) case(preserve)
		if _N != `_nwedit_ties' {
			di "{err}edgeimport() file `edgeimport' has `=_N' rows but network `netname' has `_nwedit_ties' ties; re-export from the interactive view, or check if/in - edgeimport() must be run against a network of the same size as the interactive export it came from."
			error 6056
		}
		capture assert edge_row == _n
		if _rc {
			di "{err}edgeimport() file `edgeimport' is not in row order (edge_row must read 1, 2, 3, ... in order) - re-export from the interactive view rather than hand-editing the file."
			error 6056
		}
		mata: _nwedit_edgecolor = st_sdata(., "color")
		mata: _nwedit_edgestyle = st_sdata(., "style")
		restore
	}

	// Prepare temporary Stata dataset for plotting
	preserve
	qui drop _all
	qui set obs `minObs'
	qui gen nx = .
	qui gen ny = .
	qui gen nsize = .
	
	qui gen ncolor = .
	qui gen nsymbol = .
	qui mata: st_addvar("str20", "nlabel")
	qui gen sx = .
	qui gen sy = .
	qui gen ex = .
	qui gen ey = .
	qui gen value = .
	qui gen recip = .
	qui gen edgecolor = .
	qui gen edgesize = .
	
	mata: st_numscalar("r(ties)", rows(TC))
	if `r(ties)' > 0 {
		mata: st_store((1::rows(TC)),("sx","sy","ex","ey","value","recip","edgecolor", "edgesize"),TC[.,.])
		if "`edgeimport'" != "" {
			mata: _nwedit_edgecolorvec = st_data((1::rows(TC)), "edgecolor")
			_dagplot_buildgroupmap, groupvec(_nwedit_edgecolorvec) valuevec(_nwedit_edgecolor) prefix(_nwedit_edgecolormap)
			_dagplot_buildgroupmap, groupvec(_nwedit_edgecolorvec) valuevec(_nwedit_edgestyle) prefix(_nwedit_edgestylemap)
		}
	}
	
	qui gen straight =  1 - recip
	qui replace straight = 0 if "`arcstyle'" == "curved"
	qui replace straight = 1 if "`arcstyle'" == "straight"
	qui gen arrow = straight
	
	if ("`arcstyle'" != "straight"){
		di "{txt}Generating splines..."
		//save raw.dta, replace
		qui dagplot_splines, unbend(straight) arrow(arrow) x1(sx) y1(sy) x2(ex) y2(ey) bend(`arcbend') splines(`arcsplines')
	}
	
	mata: st_store((1::rows(Coord)),("nx","ny"), Coord[.,.])
	mata: st_store((1::rows(nsize)),("nsize"), nsize[.,.])
	mata: st_store((1::rows(ncolor)),("ncolor"), ncolor[.,.])
	mata: st_store((1::rows(ncolor)),("nsymbol"), nsymbol[.,.])
	mata: st_sstore((1::rows(nlabel)),("nlabel"), nlabel[.,.])
	
	local binfactor = 1/`sizebin'
	qui replace nsize = (ceil(nsize * `binfactor'))* `sizebin'
	qui tab nsize, matrow(nsizerow)
	qui sum nsize
	local sizemin = r(min)
	local sizemax = r(max)	
	
	// Prepare plots and legend
	qui tab ncolor, matrow(ncolorrow)
	local ncols = rowsof(ncolorrow)
	if `ncols' == 0 { 
		local ncols = 1
	}
	
	qui tab nsymbol, matrow(nsymbolrow)
	local symbs = rowsof(nsymbolrow)
	
	qui tab nsize, matrow(nsizerow)	
	local sizs = rowsof(nsizerow)

	if "`interactive'" != "" {
		di "{text:Preparing interactive view...}"

		mata: st_local("_nwedit_pkgdir", _dagplot_installdir())
		local _nwedit_template = "`_nwedit_pkgdir'/dagplot_template.html"
		local _nwedit_vendorjs = "`_nwedit_pkgdir'/vendor/cytoscape.min.js"
		capture confirm file "`_nwedit_template'"
		if _rc {
			di "{err}dagplot_template.html not found at `_nwedit_template'; reinstall the package, or omit {bf:interactive}."
			error 601
		}
		capture confirm file "`_nwedit_vendorjs'"
		if _rc {
			di "{err}Vendored cytoscape.min.js not found at `_nwedit_vendorjs'; reinstall the package, or omit {bf:interactive}."
			error 601
		}

		// Resolve concrete node colors for the browser -- _dagplot_getcolorstyle's
		// own col_fill is a scheme-relative token ("scheme p1") whenever no
		// explicit colorpalette() was given, which Stata's own graph
		// renderer resolves internally at draw time but a browser cannot.
		// Every group needing resolution (not already covered by an
		// importcoords() override) is collected first and resolved in ONE
		// batched draw+export+parse pass (_dagplot_resolvecolorstylebatch)
		// rather than one throwaway graph per group - see that program's
		// own header comment for why (one-graph-per-group visibly flashed
		// Stata's real graph window repeatedly in an interactive session).
		local _nwedit_colorpending_n = 0
		local _nwedit_colorplots ""
		forvalues _nwedit_ci = 1/`ncols' {
			local _nwedit_cg = ncolorrow[`_nwedit_ci', 1]
			if "`importcoords'" != "" & "`_nwedit_colormap_`_nwedit_cg''" != "" {
				local _nwedit_htmlcolor_`_nwedit_cg' "`_nwedit_colormap_`_nwedit_cg''"
			}
			else {
				_dagplot_getcolorstyle, i(`_nwedit_cg') j(1) colorpalette(`colorpalette') symbolpalette(`symbolpalette') scheme(`scheme') mlcolor(`mlcolor_color') mlwidth(`mlwidth_color')
				local _nwedit_colorpending_n = `_nwedit_colorpending_n' + 1
				local _nwedit_colorplots `"`_nwedit_colorplots' (scatter _nwedit_y _nwedit_x if _n==`_nwedit_colorpending_n', mcolor("`r(col_fill)'") msymbol(O) msize(large))"'
				local _nwedit_colorpendinggroup`_nwedit_colorpending_n' = `_nwedit_cg'
			}
		}
		if `_nwedit_colorpending_n' > 0 {
			_dagplot_resolvecolorstylebatch, n(`_nwedit_colorpending_n') scheme(`scheme') plots(`"`_nwedit_colorplots'"')
			forvalues _nwedit_k = 1/`_nwedit_colorpending_n' {
				local _nwedit_htmlcolor_`_nwedit_colorpendinggroup`_nwedit_k'' "`_nwedit_batchrgb`_nwedit_k''"
			}
		}

		// Shape: map to the 4 shapes the interactive canvas supports;
		// unresolved scheme-relative tokens (never vary by group in any
		// nwcommands-shipped scheme, verified while building this feature)
		// and anything else fall back to circle, the same default Stata
		// itself uses for an unstyled marker.
		forvalues _nwedit_si = 1/`symbs' {
			local _nwedit_sg = nsymbolrow[`_nwedit_si', 1]
			if "`importcoords'" != "" & "`_nwedit_shapemap_`_nwedit_sg''" != "" {
				local _nwedit_htmlshape_`_nwedit_sg' "`_nwedit_shapemap_`_nwedit_sg''"
			}
			else {
				_dagplot_getcolorstyle, i(0) j(`_nwedit_sg') colorpalette(`colorpalette') symbolpalette(`symbolpalette') scheme(`scheme') mlcolor(`mlcolor_symbol') mlwidth(`mlwidth_symbol')
				local _nwedit_symtok = r(symbol)
				local _nwedit_shp "circle"
				if inlist("`_nwedit_symtok'", "S", "square", "smsquare") local _nwedit_shp "square"
				if inlist("`_nwedit_symtok'", "T", "triangle", "smtriangle") local _nwedit_shp "triangle"
				if inlist("`_nwedit_symtok'", "D", "diamond", "smdiamond") local _nwedit_shp "diamond"
				local _nwedit_htmlshape_`_nwedit_sg' "`_nwedit_shp'"
			}
		}

		// Edge colors/styles -- same resolution, only if there are ties.
		// Edge line pattern always defaults to solid on initial display
		// (no nwcommands-shipped scheme varies it by group either,
		// verified the same way) unless edgeimport() overrides it.
		if `_nwedit_ties' > 0 {
			qui tab edgecolor, matrow(_nwedit_ecrowmat)
			local _nwedit_ecn = rowsof(_nwedit_ecrowmat)
			local _nwedit_ecpending_n = 0
			local _nwedit_ecplots ""
			forvalues _nwedit_eci = 1/`_nwedit_ecn' {
				local _nwedit_ecg = _nwedit_ecrowmat[`_nwedit_eci', 1]
				if "`edgeimport'" != "" & "`_nwedit_edgecolormap_`_nwedit_ecg''" != "" {
					local _nwedit_htmledgecolor_`_nwedit_ecg' "`_nwedit_edgecolormap_`_nwedit_ecg''"
				}
				else {
					_dagplot_getcolorstyle, i(`_nwedit_ecg') edgecolorpalette(`edgecolorpalette') edgepatternpalette(`edgepatternpalette') scheme(`scheme')
					local _nwedit_ecpending_n = `_nwedit_ecpending_n' + 1
					local _nwedit_ecplots `"`_nwedit_ecplots' (pcspike _nwedit_y _nwedit_x1 _nwedit_y _nwedit_x2 if _n==`_nwedit_ecpending_n', lcolor("`r(edgecol)'") lwidth(thick))"'
					local _nwedit_ecpendinggroup`_nwedit_ecpending_n' = `_nwedit_ecg'
				}
				if "`edgeimport'" != "" & "`_nwedit_edgestylemap_`_nwedit_ecg''" != "" {
					local _nwedit_htmledgestyle_`_nwedit_ecg' "`_nwedit_edgestylemap_`_nwedit_ecg''"
				}
				else {
					local _nwedit_htmledgestyle_`_nwedit_ecg' "solid"
				}
			}
			if `_nwedit_ecpending_n' > 0 {
				_dagplot_resolvecolorstylebatch, n(`_nwedit_ecpending_n') scheme(`scheme') plots(`"`_nwedit_ecplots'"') mode(line)
				forvalues _nwedit_k = 1/`_nwedit_ecpending_n' {
					local _nwedit_htmledgecolor_`_nwedit_ecpendinggroup`_nwedit_k'' "`_nwedit_batchrgb`_nwedit_k''"
				}
			}
		}

		// NOT tempfile: Stata auto-erases a program-scoped tempfile the
		// moment the creating PROGRAM returns (documented behavior), which
		// here would mean the file could vanish before view browse's
		// non-blocking, asynchronously-launched browser has actually
		// finished reading it - confirmed directly (file existed at every
		// checkpoint inside this program's own execution, including right
		// before `restore', but was already gone by the time the caller's
		// next command ran). Built manually instead, in the OS temp dir,
		// so its lifetime isn't tied to this program's own scope.
		local _nwedit_out = "`c(tmpdir)'" + "nwedit_" + subinstr(subinstr("`c(current_time)'", ":", "", .), " ", "", .) + "_" + strofreal(int(runiform()*1000000)) + ".html"
		capture erase "`_nwedit_out'"
		local _nwedit_isdirected = ("`directed'" == "true")
		// The on-canvas legend should only appear when dagplot's own real
		// static plot would show one too -- i.e. keysused>0 territory
		// (dagplot.ado:1932's own legend(off) gate) -- plus a single-entry
		// legend conveys nothing, so require more than one distinct group,
		// not just "the option was passed" (colorkeys/symbolkeys/
		// edgecolorkeys are already "" whenever the corresponding option
		// was never given a real varlist, or legendoff was set - see the
		// dummy-variable/legendoff handling right after each section's own
		// _dagplot_getvaluelabel loop above).
		local _nwedit_colorkeys_n : word count `colorkeys'
		local _nwedit_symbolkeys_n : word count `symbolkeys'
		local _nwedit_edgecolorkeys_n : word count `edgecolorkeys'
		local _nwedit_hasnodelegend = (`_nwedit_colorkeys_n' > 1 | `_nwedit_symbolkeys_n' > 1)
		local _nwedit_hasedgelegend = (`_nwedit_edgecolorkeys_n' > 1)

		// Node SIZE legend entries -- same discrete-legend idea as color/
		// shape/edgecolor above, but keyed positionally rather than by a
		// _dagplot_getcolorstyle group id: `nsizerow' (from `qui tab nsize' earlier
		// in this program) gives the distinct SCALED node-size values
		// actually present in the rendered data, in the exact same units
		// as the per-node nsizev the mata function below reads -- reusing
		// it directly guarantees legend swatch sizes are pixel-consistent
		// with the real rendered nodes, with no unit-conversion risk
		// (unlike `sizekeys_size', which is baked for Stata's own msize()
		// graph-legend units and isn't comparable to the interactive
		// canvas's CSS-px scale). Labels are matched by ascending position
		// against dagplot's own already-computed `sizekeys' (the same
		// values feeding the real static plot's own size legend) - correct
		// for the common size()-with-no-sizebin()-collapsing case; falls
		// back to a generic "Size N" label (matching the existing color/
		// shape fallback style) whenever the counts don't line up
		// (sizebin() collapsing multiple sizekeys into fewer bins, or
		// forcekeys() specifying a different count). Deliberately kept
		// separate from `_nwedit_hasnodelegend' above (color/shape only,
		// unaffected by size variation) rather than folded in - the two
		// legends are independent dimensions on the real static plot too,
		// and merging them would make the on-canvas legend show a spurious
		// single-entry color/shape row whenever only size varies.
		// Exactly `sizekeys' entries (2 representative points by default -
		// min/max of the size() variable - or as many as forcekeys()
		// specifies): the same small representative set the real static
		// plot's own size legend shows, NOT one entry per distinct value
		// actually rendered (see the long comment above where
		// `_nwedit_sizekeys_rawnsize' is built, next to `sizekeys_size',
		// for why an earlier version of this fix got that wrong - it used
		// `nsizerow', which for a continuous size() variable can have a
		// dozen-plus distinct rendered sizes, one per near-unique data
		// value). `sizekeys' is already "" whenever no size legend should
		// show (sizekeys_legendoff set, or size() not given - the same
		// gate dagplot's own static-plot legend loop uses), so its word
		// count alone is the correct display gate.
		local _nwedit_sizelegend_n : word count `sizekeys'
		local _nwedit_hassizelegend = (`_nwedit_sizelegend_n' > 0)
		forvalues _nwedit_szi = 1/`_nwedit_sizelegend_n' {
			local _nwedit_szraw : word `_nwedit_szi' of `_nwedit_sizekeys_rawnsize'
			local _nwedit_sizelegend_px_`_nwedit_szi' = `_nwedit_szraw' * `nodefactor' * 2 * 7
			local _nwedit_szkeyval : word `_nwedit_szi' of `sizekeys'
			if "`_nwedit_sizevarname'" != "" {
				local _nwedit_sizelegend_label_`_nwedit_szi' "`_nwedit_sizevarname' = `_nwedit_szkeyval'"
			}
			else {
				local _nwedit_sizelegend_label_`_nwedit_szi' "Size `_nwedit_szi'"
			}
		}

		mata: _dagplot_buildinteractivehtml("`_nwedit_template'", "`_nwedit_vendorjs'", "`_nwedit_out'", `nodes', `_nwedit_ties', `doarrows', `nodefactor', `_nwedit_isdirected', `_nwedit_hasnodelegend', `_nwedit_hasedgelegend', `_nwedit_hassizelegend', `_nwedit_sizelegend_n')

		// movieexport(): nwmovie's own hook into this same resolved-color/
		// shape/position JSON, reusing every line of the resolution work
		// just above (batched color/shape/edgecolor lookups) instead of
		// duplicating it - nwmovie calls `dagplot <one network>, interactive
		// noopen movieexport(path)` once per network in its own sequence
		// and reads the plain JSON back, rather than nwmovie re-deriving
		// concrete hex colors/shapes from scratch. Writes the SAME json
		// string _dagplot_buildinteractivehtml() just embedded into the
		// full HTML page, as a standalone .json file - no template/
		// vendored-JS overhead, since nwmovie assembles its own page.
		if "`movieexport'" != "" {
			mata: _dagplot_writejson("`movieexport'", `nodes', `_nwedit_ties', `doarrows', `nodefactor', `_nwedit_isdirected', `_nwedit_hasnodelegend', `_nwedit_hasedgelegend', `_nwedit_hassizelegend', `_nwedit_sizelegend_n')
		}

		if "`noopen'" == "" {
			di "{text:Opening interactive view...}"
			// _dagplot_openviewer (this package's own fork of
			// nwcommands_2016's nw_openviewer.ado, launching this
			// package's own dagplot_viewer binary under plugins/ instead
			// of nwcommands' nwedit_viewer) - NOT nwcommands' shared
			// nw_openviewer/nwedit_viewer: those still carry a real bug
			// found while building this (a persistent WKWebsiteDataStore
			// whose cache dir collides with the staged binary's own temp
			// path, leaving the window blank) that nwcommands' own copy
			// was deliberately left unpatched, per an explicit request to
			// revert nwcommands itself while keeping dagplot's own fix -
			// see _dagplot_openviewer.ado/native/dagplot_viewer.mm.
			_dagplot_openviewer "`_nwedit_out'"
		}
	}

	// Prepare ghost plots for legend
	tempvar ghost1 ghost2
	local ghostcmd ""
	qui gen `ghost1' = .
	qui gen `ghost2' = .
	local sizekeys_num = 0
	local colorkeys_num = 0
	local symbolkeys_num = 0
	local colorkeys_num : word count `colorkeys'
	local symbolkeys_num : word count `symbolkeys'	
	local sizekeys_num : word count `sizekeys'
	local edgesizekeys_num : word count `edgesizekeys'
	local edgecolorkeys_num : word count `edgecolorkeys'
	local columns = max(`symbolkeys_num', `colorkeys_num', `sizekeys_num', `edgesizekeys_num', `edgecolorkeys_num')
	

	local cols_found =  strpos("`legendopt'", "cols")
	if `cols_found' == 0 {
		local legendopt "`legendopt' cols(`columns')"
	}
	else {
		local 0 `",`legendopt'"'
		syntax [, cols(string) *]
		local columns = `cols'
	}
	
	
	// Get the ident of the legend
	local colorident = ""
	local temp = mod(`=`colorkeys_num'+1', `columns')
	if "`temp'" == "." {	
		local temp = 1 
	}
	forvalues i = `temp' / `columns' {
		if `colorkeys_num' != 0 {
			local colorident = "`colorident' - "
		}
	}
	
	local symbolident = ""
	local temp = mod(`=`symbolkeys_num'+1', `columns')
	if "`temp'" == "." {	
		local temp = 1 
	}
	forvalues i = `temp' / `columns' {
		if `symbolkeys_num' != 0 {
			local symbolident = "`symbolident' - "	
		}
	}

	local sizeident = "" 
	local temp = mod(`=`sizekeys_num'+1', `columns')
	if "`temp'" == "." {	
		local temp = 1 
	}
	forvalues i = `temp' / `columns' {
		if `sizekeys_num' != 0 {
			local sizeident = "`sizeident' - "
		}
	}
	
	local edgesizeident = "" 
	local temp = mod(`=`edgesizekeys_num'+1', `columns')
	if "`temp'" == "." {	
		local temp = 1 
	}
	forvalues i = `temp' / `columns' {
		if `edgesizekeys_num' != 0 {
			local edgesizeident = "`edgesizeident' - "
		}
	}
	
	
	// Ghost plots for node color
	if "`colorkeys_legendoff'" == "" {
		if `colorkeys_num' >= 1 {	
			local ckey = 0
			foreach i in `colorkeys' {
				_dagplot_getcolorstyle, i(`i') j(0) colorpalette(`colorpalette') symbolpalette(`symbolpalette') scheme(`scheme') mlcolor(`mlcolor_color') mlwidth(`mlwidth_color')
				local tempcolstyle_fill = r(col_fill)
				local tempcolstyle_line = r(col_line)
				local tempwidth_line = r(line_width)
				if "`importcoords'" != "" & "`_nwedit_colormap_`i''" != "" {
					local tempcolstyle_fill "`_nwedit_colormap_`i''"
					local tempcolstyle_line "`_nwedit_colormap_`i''"
				}
				local ghostcmd `"`ghostcmd' || (scatter `ghost1' `ghost2' if `ghost1' !=.,  msymbol("scheme p0")  mfcolor("`tempcolstyle_fill'") mlwidth("`tempwidth_line'") mlcolor("`tempcolstyle_line'")   msize(2) `scatteropt') "'
			}
		}
	}
	else {
		local colorident ""
	}
	
	// Ghost plots for node symbol
	if "`symbolkeys_legendoff'" == "" {
		if `symbolkeys_num' >= 1 {	
			local skey = 0
			foreach j in `symbolkeys' {
				_dagplot_getcolorstyle, i(0) j(`j') colorpalette(`colorpalette') symbolpalette(`symbolpalette') scheme(`scheme') mlcolor(`mlcolor_symbol') mlwidth(`mlwidth_symbol')
				local tempsymbol = r(symbol)
				local tempcolstyle_line = r(col_line)
				local tempwidth_line = r(line_width)
				if "`importcoords'" != "" & "`_nwedit_shapemap_`j''" != "" {
					local tempsymbol "`_nwedit_shapemap_`j''"
				}
				local ghostcmd `"`ghostcmd' || (scatter `ghost1' `ghost2' if `ghost1' !=.,  msymbol("`tempsymbol'") mlwidth("`tempwidth_line'") mfcolor("scheme background") mlcolor("`tempcolstyle_line'") msize(2) `scatteropt') "'
			}
		}
	}
	else {
		local symbolident ""
	}
	
	// Ghost plots of size of nodes
	if "`size'" != "" & "`sizekeys_legendoff'" == ""{
		local i = 0
		_dagplot_getcolorstyle, i(0) j(1) colorpalette(`colorpalette') symbolpalette(`symbolpalette') scheme(`scheme') mlcolor(`mlcolor_size') mlwidth(`mlwidth_size')
		foreach szkey in `sizekeys' {
			local i = `i' + 1
			local szkey_size : word `i' of `sizekeys_size'
			local tempcolstyle_line = r(col_line)
			local tempwidth_line = r(line_width)
			local ghostcmd `"`ghostcmd' || (scatter `ghost1' `ghost2' if `ghost1' !=.,  msymbol("scheme p0")  mlcolor("`tempcolstyle_line'") mlwidth("`templine_width'") mfcolor("scheme p0")  msize(`szkey_size') `scatteropt') "'            		
		}
		local sizekeys_num : word count `sizekeys'
	}
	else {
		local sizeident ""
	}
	
	// Ghost plots of size of edges
	if "`edgesizekeys'" != "" & "`edgesizekeys_legendoff'" == ""{
		foreach eszkey in `edgesizekeys' {
			local tempval_line = (`eszkey' / 2) * `edgefactor' / 2
			local tempval_arrow = (`eszkey' + 1) * `arrowfactor' 
			local tempval_barb = `tempval_arrow' * `arrowbarbfactor'
			local ghostcmd `"`ghostcmd' || (`pc' `ghost1' `ghost2' `ghost2' `ghost1' if `ghost1' !=., lpattern(solid) lwidth(`tempval_line') lcolor("scheme p0") mcolor("scheme p0") msize(`tempval_arrow') barbsize(`tempval_barb') `lineopt') ||"'
		}
		local edgesizekeys_num : word count `edgesizekeys'
	}
	else {
		local edgesizeident ""
	}	
	
	// Ghost plots of color of edges
	if "`edgecolorkeys'" != "" & "`edgecolorkeys_legendoff'" == ""{
		foreach eckey in `edgecolorkeys' {
			_dagplot_getcolorstyle, i(`=`eckey'') edgecolorpalette(`edgecolorpalette') edgepatternpalette(`edgepatternpalette') scheme(`scheme')
			local temppattern = r(edgepattern)
			local tempcolstyle = r(edgecol)
			local _nwedit_eckey_val = `eckey'
			if "`edgeimport'" != "" & "`_nwedit_edgecolormap_`_nwedit_eckey_val''" != "" {
				local tempcolstyle "`_nwedit_edgecolormap_`_nwedit_eckey_val''"
			}
			if "`edgeimport'" != "" & "`_nwedit_edgestylemap_`_nwedit_eckey_val''" != "" {
				local temppattern "`_nwedit_edgestylemap_`_nwedit_eckey_val''"
			}
			local tempval_arrow = 3 * `arrowfactor'
			local tempval_barb = `tempval_arrow' * `arrowbarbfactor'
			local ghostcmd `"`ghostcmd' || (pcspike `ghost1' `ghost2' `ghost2' `ghost1' if `ghost1' !=., lpattern(`"`temppattern'"') lwidth(1) lcolor(`"`tempcolstyle'"') mcolor(`"`tempcolstyle'"')  `lineopt') ||"'
		}
		local edgesizekeys_num : word count `edgesizekeys'
	}
	else {
		local edgesizeident ""
	}	
	
	local arrowgap = `arrowgap' + 1.2
	if "`legendopt'" == "" | `keysused' == 0 {
		local legendcmd = "legend(off)"
		local arrowgap = `arrowgap' - 5.2
	}
	else {
		local legendcmd `"legend(order(`colororder' `colorident' `symbolorder' `symbolident' `sizeorder' `sizeident' `edgesizeorder' `edgesizeident' `edgecolororder' `edgecolorident') `colorlabels' `symbollabels' `sizelabels' `edgesizelabels' `edgecolorlabels' `legendopt')"'
	}

	// Prepare scatter commands to plot nodes
	local scattercmd ""	
	local scattercmdforeground ""
	local tempsize_rows = rowsof(nsizerow)
	
	// Size of nodes
	forvalues tempsiz_mat = 1/`tempsize_rows'{
		local tempsiz = nsizerow[`tempsiz_mat',1] 
		// Color of nodes
		forvalues i = 1/`ncols' {
			// Symbol of nodes
			forvalues j = 1/`symbs'{
				local tempcol = ncolorrow[`i', 1]
				local tempsymb = nsymbolrow[`j',1]
				_dagplot_getcolorstyle, i(`tempcol') j(`tempsymb') colorpalette(`colorpalette') symbolpalette(`symbolpalette') scheme(`scheme') mlcolor(`mlcolor_color') mlwidth(`mlwidth_color')
				local tempsiz_node = `tempsiz' * `nodefactor' * 2
				local tempcolstyle_fill = r(col_fill)
				local tempcolstyle_line = r(col_line)
				local tempsymbol = r(symbol)
				local tempwidth_line = r(line_width)
				if "`importcoords'" != "" & "`_nwedit_colormap_`tempcol''" != "" {
					local tempcolstyle_fill "`_nwedit_colormap_`tempcol''"
					local tempcolstyle_line "`_nwedit_colormap_`tempcol''"
				}
				if "`importcoords'" != "" & "`_nwedit_shapemap_`tempsymb''" != "" {
					local tempsymbol "`_nwedit_shapemap_`tempsymb''"
				}
				if "`label'" != "" {
					local scatterlabel "mlabel(nlabel)"
				}
				
				local foregroundcheck : list tempcol in colorforeground		
				if `foregroundcheck' == 0 {
					local scattercmd `"`scattercmd' (scatter ny nx if ncolor == `tempcol' & nsymbol == `tempsymb' & nsize == `tempsiz',  mlabcolor("scheme label") msymbol("`tempsymbol'") mlwidth("`tempwidth_line'") mlcolor("`tempcolstyle_line'") mfcolor("`tempcolstyle_fill'") msize(`tempsiz_node') `scatterlabel' `scatteropt') ||"' 
				}
				else {
					local scattercmdforeground `"`scattercmdforeground' (scatter ny nx if ncolor == `tempcol' & nsymbol == `tempsymb' & nsize == `tempsiz',  mlabcolor("scheme label") msymbol("`tempsymbol'") mlwidth("`tempwidth_line'") mlcolor("`tempcolstyle_line'") mfcolor("`tempcolstyle_fill'") msize(`tempsiz_node') `scatterlabel' `scatteropt') ||"' 
				}				
			}
		}
	}
	
	// Prepare pc command to plot arcs/edges
	local pccmd "||"
	local pccmdforeground ""

	// BUGFIX: a network with zero ties at all (e.g. any single-node
	// network - no off-diagonal pair can even exist) leaves `edgesize'/
	// `edgecolor' entirely missing for every observation in this
	// tie-level dataset - `tab' finds no categories to tabulate and
	// does not create `matrow(valuerow)'/`matrow(edgecolorrow)' at all
	// in that case (not merely empty matrices - the locals are left
	// completely undefined), crashing the very next line ("valuerow
	// not found", r(111)). There is nothing to draw on the edge side of
	// the plot when there are no edges, so this whole block is skipped
	// entirely rather than trying to make `tab' tolerate an all-missing
	// input - `pccmd'/`pccmdforeground' simply stay at their own
	// already-initialized "no edges" values ("||"/"").
	qui count if edgesize < .
	if r(N) > 0 {
		qui tab edgesize, matrow(valuerow)
		local tempvalue_rows = rowsof(valuerow)
		qui tab edgecolor, matrow(edgecolorrow)
		local tempecol_rows = rowsof(edgecolorrow)

		forvalues tempecol_mat = 1/`tempecol_rows'{
			local tempecol = edgecolorrow[`tempecol_mat',1]
			_dagplot_getcolorstyle, i(`tempecol') edgecolorpalette(`edgecolorpalette') edgepatternpalette(`edgepatternpalette') scheme(`scheme')
			local temppattern = r(edgepattern)
			local tempcolstyle = r(edgecol)
			if "`edgeimport'" != "" & "`_nwedit_edgecolormap_`tempecol''" != "" {
				local tempcolstyle "`_nwedit_edgecolormap_`tempecol''"
			}
			if "`edgeimport'" != "" & "`_nwedit_edgestylemap_`tempecol''" != "" {
				local temppattern "`_nwedit_edgestylemap_`tempecol''"
			}
			forvalues tempval_mat = 1/`tempvalue_rows'{
				local tempval = valuerow[`tempval_mat',1]
				local tempval_line = (`tempval' / 2) * `edgefactor' / 2
				local tempval_arrow = (`tempval' + 1) * `arrowfactor'
				local tempval_barb = `tempval_arrow' * `arrowbarbfactor'
				// BUGFIX: this formula assumes edgesize() ties are on a
				// small scale (tie counts, small integer weights) -
				// `edgesize()' passes the network's raw tie VALUES
				// through untouched (unlike node size, which does go
				// through a sizebin()-based rescale), so a genuinely
				// large-magnitude valued network (e.g. a food web's
				// carbon-flux weights running into the hundreds of
				// thousands) fed lwidth()/msize()/barbsize() an equally
				// enormous number. Stata's own twoway enforces a hard
				// ceiling on lwidth (1.0e+04) and errors "gm_linewidth
				// must be between 0.000 and 1.0e+04" once it's crossed;
				// other builds/graphics backends were reported to spend
				// a very long time instead of erroring at all - either
				// way, this is a genuine defect in this command, not a
				// caller error, since nothing in edgesize()'s own docs
				// warns that raw large-magnitude values need
				// pre-scaling. Clamped to a generous but sane visual
				// maximum rather than actually rescaling edgesize()'s
				// own display range (a larger redesign, matching how
				// node size's sizebin() option already works, deferred
				// as a separate enhancement) - confirmed this clamp
				// changes nothing for the small-magnitude values every
				// existing example/test already uses.
				local tempval_line = min(`tempval_line', 20)
				local tempval_arrow = min(`tempval_arrow', 20)
				local tempval_barb = min(`tempval_barb', 20)
				local tempecol_orig = `tempecol' - 1
				local foregroundcheck : list tempecol_orig in edgeforeground
				if `foregroundcheck' == 0 {
					local pccmd `"`pccmd' (pcspike sy sx ey ex if value != 0 & edgesize == `tempval' & edgecolor == `tempecol', lpattern(`temppattern') lwidth(`tempval_line') lcolor("`tempcolstyle'") mfcolor("`tempcolstyle'") mcolor("`tempcolstyle'") msize(`tempval_arrow') barbsize(`tempval_barb') `lineopt') || (`pc' sy sx ey ex if value != 0 & edgesize == `tempval'  & edgecolor == `tempecol' & arrow == 1,  lpattern(`temppattern') lwidth(`tempval_line') lcolor("`tempcolstyle'") mfcolor("`tempcolstyle'") mcolor("`tempcolstyle'") msize(`tempval_arrow') barbsize(`tempval_barb') `lineopt') ||"'
				}
				else {
					local pccmdforeground `"`pccmdforeground' (pcspike sy sx ey ex if value != 0 & edgesize == `tempval' & edgecolor == `tempecol', lpattern(`temppattern') lwidth(`tempval_line') lcolor("`tempcolstyle'") mfcolor("`tempcolstyle'") mcolor("`tempcolstyle'") msize(`tempval_arrow') barbsize(`tempval_barb') `lineopt') || (`pc' sy sx ey ex if value != 0 & edgesize == `tempval'  & edgecolor == `tempecol' & arrow == 1,  lpattern(`temppattern') lwidth(`tempval_line') lcolor("`tempcolstyle'") mfcolor("`tempcolstyle'") mcolor("`tempcolstyle'") msize(`tempval_arrow') barbsize(`tempval_barb') `lineopt') ||"'
				}
			}
		}
	}
	
	local pmargin = `nodefactor' * 3

	// interactive already opened its own browser/native-viewer window
	// above (well before this point - see the `interactive' block around
	// line 1650) from data prepared independently of this static plot, so
	// the two are not coupled: suppressing this one changes nothing about
	// the interactive view. We still draw it (not `nodraw' - see
	// _dagplot_resolvecolorstylebatch's own header comment for why that
	// option is unreliable in this codebase, breaking `graph export' with
	// r(693) in a headless/batch session), just under a fixed name so we
	// can immediately `graph close' it afterward - `graph close' only
	// hides the window, it does not drop the graph, so export()/graph
	// save/the Graph Editor via `graph display' all still work exactly as
	// documented above, and a user-supplied name() (rare, but possible
	// via a passthrough twoway_option) is respected instead of overridden.
	local _nwedit_autoname = 0
	if "`interactive'" != "" & strpos(`"`twowayopt'"', "name(") == 0 {
		local twowayopt `"`twowayopt' name(_dagplot_interactive, replace)"'
		local _nwedit_autoname = 1
	}
	local graphcmd `"twoway `ghostcmd' `pccmd' `scattercmd' `pccmdforeground' `scattercmdforeground' , ylabel(, nogrid) yscale(off range(0 100)) xscale(off range(0 150)) graphregion(color("scheme plotregion")) plotregion(color("scheme plotregion") margin(`pmargin' `pmargin' `pmargin' `pmargin')) aspectratio(`aspectratio') `legendcmd' `schemetwoway' `twowayopt'"'

	di "{text:Plotting network...}"
	//di `"`graphcmd'"'
	`graphcmd'

	// export() is a thin wrapper around Stata's own native "graph
	// export" - the just-drawn twoway graph above (`graphcmd') is an
	// ordinary Stata graph object, so exporting it is nothing more than
	// calling the same command a user would type by hand afterward;
	// this does not touch or replace that graph object, so it remains
	// fully available for graph editor/save/re-export use exactly as if
	// export() had never been given. The output format (SVG/PDF/PNG/...)
	// is inferred by "graph export" itself from the filename's own
	// extension, matching Stata's own established convention - no
	// separate format() option is added. exportopt() is a narrow,
	// explicit passthrough for the handful of "graph export" options
	// that are genuinely still useful to reach without leaving dagplot
	// (chiefly raster width()/height() for PNG/TIF quality); anything
	// more exotic is still one manual "graph export" call away.
	if "`export'" != "" {
		// SVG export needs Stata 16 or later - check explicitly rather
		// than let "graph export" itself fail with a generic error (or,
		// on an older Stata that silently accepts the option but
		// produces a broken/incomplete file, worse: fail silently).
		if substr(lower("`export'"), -4, .) == ".svg" & c(stata_version) < 16 {
			di "{err}SVG export requires Stata 16 or later (this is Stata `c(stata_version)'). Export to a different format (png/pdf/eps/...), or upgrade Stata."
			error 9
		}
		di "{text:Exporting graph to `export'...}"
		graph export "`export'", `replace' `exportopt'
		return local export "`export'"
	}

	// Suppress the static plot's own window once interactive is in play -
	// after export() above (if any), so export() still had a displayed
	// graph to work from. `capture': closing is best-effort, mirroring
	// every other `capture' around window/viewer handling in the
	// `interactive' block above - a failure here (e.g. no window server
	// at all in a genuinely headless run) should never abort the command.
	if `_nwedit_autoname' {
		capture graph close _dagplot_interactive
	}

	// the scheme actually used to render this plot - "s1network" unless
	// scheme() was given explicitly (see its own default assignment
	// above)
	return local scheme "`scheme'"
	return local interactive "`_nwedit_out'"
	return local importcoords "`importcoords'"

	restore

	if "`generate'" != "" {
		di "{text:Export coordinates...}"
		if (wordcount("`generate'") >= 2){
			local generate_x = word("`generate'", 1)
			local generate_y = word("`generate'", 2)
		}
		else {
			local generate_x = "_x_coord"
			local generate_y = "_y_coord"
		}
		
		capture drop `generate_x'
		capture drop `generate_y'
		if _N < `nodes' {
			set obs `nodes'
		}
		qui gen `generate_x' = .
		qui gen `generate_y' = .
		mata: st_store((1::rows(Coord)),("`generate_x'","`generate_y'"), (Coord[.,.]:/100))
		qui replace `generate_x' = (`generate_x' - 0.05) / 0.9
		qui replace `generate_y' = (`generate_y' - 0.05) / 0.9
	}
	mata: mata drop plotmat nsize ncolor nlabel Coord edgesizemat edgecolormat
	capture mata: mata drop Coord_comp compM comp_freq comp_id comp_freqid compmat comp_share comp_nonisol
	capture mata: mata drop TC M nsymbol
	capture nwdrop __temp* 
	
	capture mat drop edgecolorrow
	capture mat drop valuerow
	capture mat drop nsymbolrow
	capture mat drop ncolorrow
	capture mat drop nsizerow
	capture mat drop nsymblrow
	capture mat drop colorkeysmap
	capture mata drop symbolkeysmap

	//qui nwload `masternetname', labelonly

	// The cleanup captures just above (several of which legitimately
	// "fail" - e.g. the Coord_comp/compM/... Mata cluster only exists
	// when the lgc/component code path actually ran) leave _rc stale
	// at whatever the LAST one happened to return, since nothing
	// between here and the end of the program is a capture-wrapped
	// command that would refresh it (see nwcompressobs.ado's own
	// certified row for the fuller explanation of this Stata
	// behavior - quietly-prefixed commands, mata: blocks, and plain
	// local assignment never update _rc even when they succeed). That
	// stale _rc then survived all the way out to dagplot's own caller,
	// including after a genuinely successful plot/export - confirmed
	// directly while adding export() this unit, and previously worked
	// around rather than fixed in cscripts/test_nwplot.do's own
	// long-standing "assert _rc == 0 | _rc == 3000" pattern. The
	// preceding "mata: st_numscalar("_rc", 0)" line was an earlier,
	// ineffective attempt at this exact fix: st_numscalar("_rc", ...)
	// only creates an ordinary Stata scalar literally named "_rc" in
	// the dataset's own scalar namespace - it has no effect on the
	// interpreter's real _rc state, which only a capture-wrapped
	// command can deterministically set. Reset explicitly and silently.
	capture confirm number 1
end
	
capture program drop _dagplot_getvaluelabel
program _dagplot_getvaluelabel
	syntax varlist(min=1 max=1), key(string)
	
	qui labellist `varlist'
	local labkeys "`r(values)'"
	local lablabels `"`r(labels)'"'
	if ("`r(lblname)'"!= ""){
		local lnum = `r(`r(lblname)'_k)'
		local llab "`varlist' = `key'"
		forvalues j = 1 /`lnum' {
			local lkey : word `j' of `labkeys'
			if "`lkey'" == "`key'" {
				local llab : word `j' of `lablabels'
			}
		}
	}
	else{
		local llab "`varlist' = `key'"
	}
	mata: st_global("r(key_label)", "`llab'")
	mata: st_global("r(key)", "`key'")
end

capture program drop dagplot_splines
program dagplot_splines
	syntax, unbend(string) arrow(string) y1(string) x1(string) y2(string) x2(string) bend(string) splines(string) 

	tempvar l llid rad mult1 mult2 mult3 alpha beta x3n y3n x3 x4 y3 y4 xtemp ytemp r gamma delta lid alphaX
	gen `l' = sqrt((`x1' - `x2')^2 + (`y1' - `y2')^2)
	gen `rad' = `bend'* `l'

	gen `mult1' = 1 - 2 * (`x2' > `x1')
	replace `mult1' = 1 - 2 * (`y2' > `y1') if `x1' == `x2'
	gen `mult2' = 1 - 2 * (`y2' > `y1')
	replace `mult2' = 1 - 2 * (`x2' > `x1') if `y1' == `y2'

	gen `alpha' = (acos(abs(`x2' - `x1')/`l'))
	replace `alpha' = acos(1) if `alpha' == .
	gen `beta' = _pi / 2 + `alpha'

	gen `x3n' = (`x1' + 1/2 * (`x2' - `x1')) 
	gen `x3' = `x3n' + `mult1' * cos(`beta') * `rad'
	gen `y3n' = (`y1' + 1/2 * (`y2' - `y1'))  
	gen `y3' = `y3n' + `mult2' * sin(`beta') * `rad'

	gen `r' = sqrt(`rad'^2 + (1/2*`l')^2)	
	gen `mult3' = 2 * (`x3' > `x1') - 1
	gen `gamma' =  `beta' + `mult3' * acos(`rad'/`r') 
	gen `delta' =  `beta' - `mult3' * acos(`rad'/`r') 
	
	gen `lid'  = _n
	expand `splines' if `unbend' !=1
	bys `lid': gen `llid' = _n
	gen `alphaX' = `delta' + (`gamma' - `delta') * (`llid' - 1)/(`splines' -1)
	gen `x4' = `x3' + `mult1'* cos(`alphaX' + _pi) * `r'
	gen `y4' = `y3' + `mult2'*sin(`alphaX' + _pi) * `r' 

	replace `x2' = `x4' if `unbend' != 1
	replace `y2' = `y4' if `unbend' != 1
	replace `x1' = `x4'[_n-1] if `unbend' != 1
	replace `y1' = `y4'[_n-1] if `unbend' != 1
	drop if `llid' == 1 & `unbend'!=1
	replace `arrow' = (`llid' == `splines') if (`arrow' != 1) & (`mult1' == 1)
	replace `arrow' = 1 if (`llid' == 2) & (`mult1' == - 1)
	
	gen `xtemp' = `x1'
	gen `ytemp' = `y1'
	replace `x1' = `x2' if (`llid' == 2) & (`mult1' == - 1)
	replace `y1' = `y2' if (`llid' == 2) & (`mult1' == - 1)
	replace `x2' = `xtemp' if (`llid' == 2) & (`mult1' == - 1)
	replace `y2' = `ytemp' if (`llid' == 2) & (`mult1' == - 1)
end

capture mata: mata drop dagplot_fruchtrein()
capture mata: mata drop dagplot_getTieCoordinates()
mata:
real matrix function dagplot_getTieCoordinates(
	real matrix Coord, real matrix size, real matrix List, real matrix EColMat, real matrix ESizMat, real scalar sizefactor, real scalar doarrows, real scalar arrowgap)
{
	real matrix 	TC
	real scalar 	rad, i, radius, x1, y1, x2, y2, x3, y3, An, Op, Hy, cos_theta, sin_theta
	
	radius = ((size):* sizefactor) :+ arrowgap
	Coord = Coord :*100
	Coord = (Coord :*0.9) :+ 5
	TC = J(rows(List),8,.)

	for(i=1;i<=rows(TC);i++){
		rad = radius[List[i,2],1] 
		if (doarrows==0) {
			rad = 0
		}
		TC[i,1] = Coord[List[i,1],1] //start x of tie i
		TC[i,2] = Coord[List[i,1],2] //start y of tie i
		TC[i,3] = Coord[List[i,2],1] //end x of tie i
		TC[i,4] = Coord[List[i,2],2] //end y of tie i
		TC[i,5] = List[i,3] //value of tie
		TC[i,6] = List[i,4]
		TC[i,7] = EColMat[List[i,1],List[i,2]]
		TC[i,8] = ESizMat[List[i,1],List[i,2]] 
		
		//adjust end point of arrow for node size
		x1 = TC[i,1]
		y1 = TC[i,2]
		x2 = TC[i,3]
		y2 = TC[i,4]
		An = y2 - y1
		Op = x2 - x1
		Hy = sqrt(An*An + Op*Op)
		cos_theta = Op / Hy
		sin_theta = An / Hy
		x3 = x2 - (cos_theta*rad)
		y3 = y2 - (sin_theta*rad)
		TC[i,3] = x3
		TC[i,4] = y3
	}
	return(TC)	
}	
end

/*************************************
*	Obtain color for plotting
*************************************/
// interactive/importcoords()/edgeimport() companion helpers (nwedit_
// template.html). Builds one local macro per distinct value in Mata
// group-index vector `groupvec' (ncolor/nsymbol/edgecolor), named
// "<prefix>_<idx>", holding the corresponding row's value from Mata
// string vector `valuevec' -- c_local'd into the CALLING program's scope
// (same c_local convention unw_defs.ado already uses for its own
// constant-like locals). Any single representative row sharing a group
// index is used, since a legend edit in the browser is always applied to
// every node/edge sharing a group at once (buildLegend/applyLegendEdit in
// nwedit_template.html), so every row sharing a group already carries an
// identical override value.
capture program drop _dagplot_buildgroupmap
program def _dagplot_buildgroupmap
	syntax, groupvec(string) valuevec(string) prefix(string)
	mata: _nwedit_distinct = uniqrows(`groupvec')
	mata: st_numscalar("_nwedit_ngroups", rows(_nwedit_distinct))
	local ngroups = _nwedit_ngroups
	forvalues gi = 1/`ngroups' {
		mata: st_local("_nwedit_g", strofreal(_nwedit_distinct[`gi',1]))
		mata: st_local("_nwedit_repidx", strofreal(selectindex(`groupvec':==_nwedit_distinct[`gi',1])[1]))
		mata: st_local("_nwedit_val", `valuevec'[`_nwedit_repidx',1])
		c_local `prefix'_`_nwedit_g' `"`_nwedit_val'"'
	}
	mata: mata drop _nwedit_distinct
	scalar drop _nwedit_ngroups
end

// Resolves N arbitrary Stata colorstyle tokens (e.g. "scheme p1", a literal
// color name, a literal "r g b" triplet, ...) to literal "r g b" (0-255)
// triplets, by asking Stata's own graphics engine to actually draw and
// export them, then reading the RGB straight out of the resulting EPS
// (plain-text PostScript -- colors appear as "/Ssrgb {r g b} def"
// immediately before each marker's own draw ops). This is the only
// reliable way to resolve a scheme-relative token like "scheme p1" for ANY
// active scheme (including custom user schemes) without hand-parsing
// .scheme/.style files, which only works for schemes already known about.
//
// Batched into ONE combined draw+export+parse call for however many tokens
// are needed, rather than one throwaway graph per token (the original,
// simpler design) - one-graph-per-token visibly flashed Stata's real graph
// window once per distinct color/edgecolor group, in rapid succession,
// ahead of the real plot (confirmed directly: invisible in batch-mode
// testing, since there's no GUI graph window there at all; reported by the
// user as "several windows opening and closing quickly" once tested from a
// real interactive session). `nodraw` looked like the fix but broke graph
// export outright in batch mode ("could not find Graph window", r(693)) -
// nodraw apparently skips creating a renderable surface at all when
// there's no display, not just the on-screen show step, so it isn't a
// viable fix either alone or combined with an explicit name(). Batching
// sidesteps the conflict entirely: still one real (displayed) draw, but
// only ONE flash total regardless of how many tokens are being resolved,
// and it still works headless.
//
// Caller contract: stage the N input tokens into _nwedit_batchtok1..
// _nwedit_batchtok<n> before calling (matches this file's own
// _dagplot_buildgroupmap/_nwedit_colormap_<idx> indirect-local convention);
// resolved values come back the same way, in _nwedit_batchrgb1..
// _nwedit_batchrgb<n>, c_local'd into the caller's own scope.
capture program drop _dagplot_resolvecolorstylebatch
program def _dagplot_resolvecolorstylebatch
	// mode(marker) [default]: resolves node-fill tokens ("scheme p<n>")
	// via mcolor() on a scatter marker, parsing /Ssrgb {r g b} def + a
	// following "Scc" (Stata's circle-marker draw op) out of the EPS.
	//
	// mode(line): resolves edge-line tokens ("scheme p<n>line") via
	// lcolor() on an actual line segment (pcspike), parsing /Slrgb
	// {r g b} def + a following "Sln" (Stata's straight-line draw op)
	// instead. This split is NOT cosmetic - confirmed directly that
	// mcolor() does not correctly resolve "p<n>line" tokens at all (it
	// silently falls back to some other, wrong color - observed
	// concretely as edges coming out in the SAME red as node fill colors
	// whenever mode(marker) was used for edge tokens too, the earlier
	// version's actual bug). "p<n>line" is a line-context scheme
	// reference; it only resolves correctly when asked for in a
	// genuinely line-drawing context, matching how dagplot's own real
	// edge rendering already asks for it via lcolor(), never mcolor().
	// plots(): the FULLY-ASSEMBLED twoway subcommand string, built by the
	// CALLER (referencing whichever of _nwedit_x/_nwedit_y or _nwedit_x1/
	// _nwedit_x2/_nwedit_y this program generates below, per mode) - NOT
	// built from tokens staged into caller-side locals for this program
	// to read back internally, which was this program's own original
	// design and is fundamentally broken: a called ado program cannot see
	// its CALLER's local macros at all (confirmed directly - even a
	// single bare `_nwedit_batchtok1' reference, no indirection, no
	// nested quoting, came back completely empty inside this program).
	// That silently fed empty/invalid color specs to mcolor()/lcolor(),
	// which Stata quietly falls back to a POSITIONAL default color for
	// (matching "p<n>" by the marker's own sequence position) - a fallback
	// that happens to coincide with the correct answer for ordinary
	// sequential node-group resolution (indistinguishable from working),
	// but diverges for anything else, which is exactly how the edge-color
	// version of this same bug first surfaced (p1line's positional
	// fallback is p1's own red, not p1line's real gray). Building the
	// command text in the caller instead sidesteps the whole problem -
	// r(col_fill)/r(edgecol) are ordinary return values, not a cross-
	// program local reference, so there's no scope boundary to cross.
	syntax, n(int) scheme(string) plots(string) [mode(string)]
	if "`mode'" == "" local mode "marker"

	tempfile _nwedit_eps
	preserve
	qui drop _all
	qui set obs `n'
	qui set scheme `scheme'
	if "`mode'" == "line" {
		qui gen _nwedit_x1 = (_n - 1) * 3
		qui gen _nwedit_x2 = (_n - 1) * 3 + 2
		qui gen _nwedit_y = 1
	}
	else {
		qui gen _nwedit_x = _n
		qui gen _nwedit_y = 1
	}
	// name()'d and closed immediately below rather than left under Stata's
	// default graph name - before dagplot's own main plot was given its own
	// distinct name (_dagplot_interactive, see the `interactive' block),
	// that main plot happened to reuse/overwrite this same default-named
	// graph, so this throwaway one was never actually seen on its own.
	// Once the main plot got its own name, this one was left orphaned as a
	// separate, empty-looking leftover window - a real regression this
	// program introduced for anyone using {opt interactive}, since every
	// resolved color/edgecolor group runs through here.
	qui twoway `plots', legend(off) xlabel(none) ylabel(none) xtitle("") ytitle("") name(_dagplot_colorresolve, replace)
	qui graph export "`_nwedit_eps'", replace as(eps)
	capture graph close _dagplot_colorresolve
	restore

	if "`mode'" == "line" {
		local _nwedit_defpat "/Slrgb {"
		local _nwedit_drawop "Sln"
	}
	else {
		local _nwedit_defpat "/Ssrgb {"
		local _nwedit_drawop "Scc"
	}

	tempname _nwedit_epsfh
	file open `_nwedit_epsfh' using "`_nwedit_eps'", read
	local _nwedit_current ""
	local _nwedit_idx = 0
	local _nwedit_recorded = 1
	file read `_nwedit_epsfh' _nwedit_line
	while r(eof) == 0 {
		if strpos(`"`_nwedit_line'"', "`_nwedit_defpat'") > 0 {
			local _nwedit_start = strpos(`"`_nwedit_line'"', "{") + 1
			local _nwedit_close = strpos(`"`_nwedit_line'"', "}")
			local _nwedit_current = substr(`"`_nwedit_line'"', `_nwedit_start', `_nwedit_close' - `_nwedit_start')
			// NOT every color redefinition corresponds to one of this
			// program's own markers/lines - the EPS also carries
			// incidental ones (e.g. a white background-related color-
			// state set) that never get consumed by any following draw
			// op at all. Counting a "new element" here unconditionally
			// (this program's own prior version) silently ate an index
			// slot for such a phantom entry, shifting every real element
			// after it by one and dropping the last one's color entirely
			// (confirmed directly). Only mark a color "pending" here; the
			// index itself only advances where it's actually consumed,
			// below.
			local _nwedit_recorded = 0
		}
		// substr(...)!="/" excludes the "/Scc {"/"/Sln {"-style PROCEDURE
		// DEFINITION line (PostScript boilerplate, appears once near the
		// top of every EPS this program exports) from matching this check
		// - it contains the draw-op name as a substring same as a real
		// draw call does. Real draw calls look like "1568 11757 318 0 1
		// Scc " or "17171 12808 17171 12808 Sln" - numbers first, never a
		// leading "/".
		if strpos(`"`_nwedit_line'"', "`_nwedit_drawop'") > 0 & substr(`"`_nwedit_line'"', 1, 1) != "/" & `_nwedit_recorded' == 0 & "`_nwedit_current'" != "" {
			// mode(marker): each marker draws 2 Scc calls (fill+stroke)
			// off the SAME Ssrgb def; `_nwedit_recorded' (reset only on a
			// fresh color def, not after each draw op) takes just the
			// first of the pair. mode(line) draws exactly one Sln per
			// segment, so this guard is a no-op there but harmless.
			local _nwedit_idx = `_nwedit_idx' + 1
			local _nwedit_r : word 1 of `_nwedit_current'
			local _nwedit_g : word 2 of `_nwedit_current'
			local _nwedit_b : word 3 of `_nwedit_current'
			local _nwedit_r = round(`_nwedit_r' * 255)
			local _nwedit_g = round(`_nwedit_g' * 255)
			local _nwedit_b = round(`_nwedit_b' * 255)
			c_local _nwedit_batchrgb`_nwedit_idx' "`_nwedit_r' `_nwedit_g' `_nwedit_b'"
			local _nwedit_recorded = 1
		}
		file read `_nwedit_epsfh' _nwedit_line
	}
	file close `_nwedit_epsfh'
end

// Builds the interactive HTML page's inline node/edge data and assembles
// the final self-contained file. Done entirely in Mata, and specifically
// via fread()/fwrite() (byte-count based) rather than any line-oriented
// text function (Stata's own `file read`, or Mata's line-oriented fget()):
// confirmed directly, while building this feature, that cytoscape.min.js
// contains lines up to ~229,000 characters, and BOTH `file read` (aborts
// with "invalid syntax") and fget() (silently truncates at 32,768 chars,
// corrupting the file with no error at all) fail on lines that long.
// nsize/ncolor/nsymbol/nlabel/edgecolor read here are the same plotting-
// dataset variables the real twoway graph is built from a few lines below
// (st_store'd in by this same program a little earlier) - this renders
// what dagplot actually resolved, it does not recompute anything.
capture mata: mata drop _dagplot_installdir()
capture mata: mata drop _dagplot_buildjson()
capture mata: mata drop _dagplot_slurpfile()
capture mata: mata drop _dagplot_buildinteractivehtml()
capture mata: mata drop _dagplot_writejson()
mata:
// dagplot is a standalone fork of nwplot (see this file's own top header)
// specifically so its `interactive` rendering pipeline - this mata block,
// plus dagplot_template.html and vendor/cytoscape.min.js next to this
// .ado - can be edited freely without touching nwcommands' own nwplot.
// Deliberately its own lookup, NOT nwcommands' unw_core.do
// NativeGraphInstallDir() (which resolves via findfile("nwset.ado") -
// i.e. wherever nwcommands itself is installed): dagplot's template/
// vendor assets live next to THIS file instead, so a caller's adopath
// can point dagplot.ado and nwcommands at two entirely different
// directories (or nwcommands could vanish/move) without breaking this
// lookup. _dagplot_openviewer.ado (dagplot's own fork of nw_openviewer)
// uses this same lookup for its own plugins/macos/dagplot_viewer binary.
string scalar _dagplot_installdir(){
	string scalar full, dir, fn

	full = findfile("dagplot.ado")
	if (full == "") return("")
	pathsplit(full, dir, fn)
	return(dir)
}

// Split out of what used to be _dagplot_buildinteractivehtml()'s own body
// (harmonisation: nwmovie's own real-world-data movie player, see
// nw_openviewer.ado's header for the sibling refactor) - this half does
// only the resolved-node/edge JSON construction, with no template/
// vendored-JS/file-output concern at all, so nwmovie's movieexport()
// path (_dagplot_writejson() below) can reuse it directly without paying
// for or depending on the interactive HTML page's own assembly.
string scalar _dagplot_buildjson(real scalar nn, real scalar nties,
		real scalar doarrows, real scalar htmlnodefactor, real scalar isdirected,
		real scalar hasnodelegend, real scalar hasedgelegend,
		real scalar hassizelegend, real scalar sizelegendn)
{
	real colvector nxv, nyv, nsizev, ncolorv, nsymbolv, edgecolorv, recipv
	string colvector nlabelv
	real matrix topology
	string scalar json, lbl, colorstr, shapestr, q, grouplbl, shapelbl, edgegrouplbl, sizelbl
	real scalar i, cg, sg, ecg, fromidx, toidx, sizepx, nemitted
	// plotmat is created by ordinary top-level `mata: plotmat = ...` code
	// earlier in this same program (nw_tomata.ado's own assignment, called
	// from dagplot.ado's "Get network data" section) -- a compiled function
	// body does not automatically see a variable from that enclosing
	// interactive scope the way another top-level `mata:` block would;
	// it must be declared `external` here, or it resolves to an empty,
	// never-assigned local of the same name (confirmed directly: omitting
	// this crashed dagplot_NumElist() with a conformability error, since it was
	// being handed a 0x0 matrix).
	external real matrix plotmat

	q = char(34)

	nxv = st_data((1::nn), "nx")
	nyv = st_data((1::nn), "ny")
	nsizev = st_data((1::nn), "nsize")
	ncolorv = st_data((1::nn), "ncolor")
	nsymbolv = st_data((1::nn), "nsymbol")
	nlabelv = st_sdata((1::nn), "nlabel")

	json = "{" +
		q+"has_node_legend"+q+":"+(hasnodelegend==1 ? "true" : "false")+"," +
		q+"has_edge_legend"+q+":"+(hasedgelegend==1 ? "true" : "false")+"," +
		q+"has_size_legend"+q+":"+(hassizelegend==1 ? "true" : "false")+"," +
		q+"size_legend"+q+":["
	// Independent of the per-node loop below -- a fixed, small list of
	// {label, size_px} entries built from the `_nwedit_sizelegend_*' locals
	// dagplot.ado stashed just before this call (nsizerow-derived, so
	// already in the same CSS-px scale `sizepx' below computes per node).
	for (i=1; i<=sizelegendn; i++) {
		sizelbl = subinstr(subinstr(st_local("_nwedit_sizelegend_label_" + strofreal(i)), char(92), ""), q, "")
		json = json + "{" +
			q+"label"+q+":"+q+sizelbl+q+"," +
			q+"size_px"+q+":"+strofreal(strtoreal(st_local("_nwedit_sizelegend_px_" + strofreal(i)))) +
			"}"
		if (i < sizelegendn) json = json + ","
	}
	json = json + "]," +
		q + "nodes" + q + ":["
	for (i=1; i<=nn; i++) {
		cg = ncolorv[i]
		sg = nsymbolv[i]
		colorstr = st_local("_nwedit_htmlcolor_" + strofreal(cg))
		shapestr = st_local("_nwedit_htmlshape_" + strofreal(sg))
		// real Stata legend text (colorlabels'/symbollabels' own
		// _dagplot_getvaluelabel-resolved strings, captured into these locals
		// alongside dagplot's own legend construction) when the network has
		// a real color()/symbol() grouping variable; falls back to a plain
		// "Group N" when there isn't one (matching the case where dagplot's
		// own static plot shows no legend either, e.g. the default
		// single-dummy-group network).
		grouplbl = st_local("_nwedit_colorlabel_" + strofreal(cg))
		if (grouplbl == "") grouplbl = "Group " + strofreal(cg)
		grouplbl = subinstr(subinstr(grouplbl, char(92), ""), q, "")
		shapelbl = st_local("_nwedit_symbollabel_" + strofreal(sg))
		if (shapelbl == "") shapelbl = "Group " + strofreal(sg)
		shapelbl = subinstr(subinstr(shapelbl, char(92), ""), q, "")
		lbl = subinstr(subinstr(nlabelv[i], char(92), ""), q, "")
		// nsize*htmlnodefactor*2 mirrors the real plot's own tempsiz_node
		// formula (dagplot.ado's node-draw loop) exactly, giving a value
		// already on the same relative scale dagplot itself renders with;
		// *7 brings that into a comfortable CSS-pixel range for cytoscape
		// (empirically tuned against the default no-size()-option case:
		// nsize=80, nodefactor defaults to 1/50, giving ~22px -- an earlier
		// *4 gave ~13px, reported as visibly too small once actually
		// viewed in a real browser rather than just checked numerically).
		sizepx = nsizev[i] * htmlnodefactor * 2 * 7
		json = json + "{" +
			q+"id"+q+":"+q+"n"+strofreal(i)+q+"," +
			q+"label"+q+":"+q+lbl+q+"," +
			q+"group"+q+":"+q+"grp"+strofreal(cg)+q+"," +
			q+"group_label"+q+":"+q+grouplbl+q+"," +
			q+"shape_label"+q+":"+q+shapelbl+q+"," +
			q+"color"+q+":"+q+colorstr+q+"," +
			q+"shape"+q+":"+q+shapestr+q+"," +
			q+"size"+q+":"+strofreal(sizepx)+"," +
			q+"color_group"+q+":"+strofreal(cg)+"," +
			q+"shape_group"+q+":"+strofreal(sg)+"," +
			q+"x"+q+":"+strofreal((nxv[i]/100 - 0.05)/0.9)+"," +
			q+"y"+q+":"+strofreal((nyv[i]/100 - 0.05)/0.9) +
			"}"
		if (i < nn) json = json + ","
	}
	json = json + "]," + q+"edges"+q+":["

	if (nties > 0) {
		edgecolorv = st_data((1::nties), "edgecolor")
		recipv = st_data((1::nties), "recip")
		topology = dagplot_NumElist(plotmat)
		nemitted = 0
		for (i=1; i<=nties; i++) {
			ecg = edgecolorv[i]
			fromidx = topology[i,1]
			toidx = topology[i,2]
			// plotmat is symmetric for an undirected network (there's no
			// "direction" to store asymmetrically), so dagplot_NumElist finds BOTH
			// (i,j) and (j,i) for every undirected tie and marks both
			// recip=1 (since onenet[i,j]!=0 & onenet[j,i]!=0 is trivially
			// true whenever the matrix is symmetric) - confirmed directly:
			// a 10-node undirected test network exported 26 edges for 13
			// real ties, every single one flagged recip=true, rendering as
			// two overlapping curved arcs per tie. dagplot's own REAL static
			// plot has an explicit guard for exactly this (dagplot.ado:740:
			// arcstyle forced to "straight" whenever directed=="false",
			// regardless of the recip flag) - undirected ties never
			// curve, and the resulting doubled straight lines are
			// invisible on top of each other. Cytoscape has no equivalent
			// free pass for doubled edges, so here they're skipped
			// outright (fromidx>toidx half of each undirected pair) rather
			// than drawn twice and merely left uncurved.
			if (isdirected == 0 & fromidx > toidx) continue
			colorstr = st_local("_nwedit_htmledgecolor_" + strofreal(ecg))
			shapestr = st_local("_nwedit_htmledgestyle_" + strofreal(ecg))
			edgegrouplbl = st_local("_nwedit_edgecolorlabel_" + strofreal(ecg))
			if (edgegrouplbl == "") edgegrouplbl = "Group " + strofreal(ecg)
			edgegrouplbl = subinstr(subinstr(edgegrouplbl, char(92), ""), q, "")
			nemitted = nemitted + 1
			if (nemitted > 1) json = json + ","
			json = json + "{" +
				q+"id"+q+":"+q+"e"+strofreal(nemitted)+q+"," +
				q+"source"+q+":"+q+"n"+strofreal(fromidx)+q+"," +
				q+"target"+q+":"+q+"n"+strofreal(toidx)+q+"," +
				q+"edgegroup"+q+":"+q+"grp"+strofreal(ecg)+q+"," +
				q+"edgegroup_label"+q+":"+q+edgegrouplbl+q+"," +
				q+"color"+q+":"+q+colorstr+q+"," +
				q+"style"+q+":"+q+shapestr+q+"," +
				q+"width"+q+":3," +
				q+"arrow"+q+":"+(doarrows==1 ? "true" : "false")+"," +
				q+"recip"+q+":"+((isdirected==1 & recipv[i]==1) ? "true" : "false")+"," +
				q+"edgecolor_group"+q+":"+strofreal(ecg) +
				"}"
		}
	}
	json = json + "]}"
	return(json)
}

// Byte-based slurp (fread(), not fget()/`file read') - required for
// cytoscape.min.js, whose minified lines run up to ~229,000 characters;
// both Stata's own `file read' and Mata's line-oriented fget() fail on
// lines that long (the latter silently truncates at 32,768 chars, with
// no error at all). Shared by both wrappers below.
string scalar _dagplot_slurpfile(string scalar path)
{
	string scalar s, chunk
	transmorphic fh

	s = ""
	fh = fopen(path, "r")
	chunk = fread(fh, 1000000)
	while (chunk != J(0,0,"")) {
		s = s + chunk
		chunk = fread(fh, 1000000)
	}
	fclose(fh)
	return(s)
}

void _dagplot_buildinteractivehtml(string scalar tplpath, string scalar jspath,
		string scalar outpath, real scalar nn, real scalar nties,
		real scalar doarrows, real scalar htmlnodefactor, real scalar isdirected,
		real scalar hasnodelegend, real scalar hasedgelegend,
		real scalar hassizelegend, real scalar sizelegendn)
{
	string scalar json, tpl, vjs
	transmorphic fh

	json = _dagplot_buildjson(nn, nties, doarrows, htmlnodefactor, isdirected,
		hasnodelegend, hasedgelegend, hassizelegend, sizelegendn)
	tpl = _dagplot_slurpfile(tplpath)
	vjs = _dagplot_slurpfile(jspath)

	tpl = subinstr(tpl, "__NWEDIT_CYTOSCAPE__", vjs)
	tpl = subinstr(tpl, "__NWEDIT_DATA__", json)

	fh = fopen(outpath, "w")
	fwrite(fh, tpl)
	fclose(fh)
}

// nwmovie's own hook (movieexport() option, added alongside noopen) -
// writes just the resolved node/edge JSON _dagplot_buildjson() produces,
// with none of the template/vendored-JS/full-HTML-page overhead above;
// nwmovie calls `dagplot <net>, interactive noopen movieexport(path)` once
// per network in its own sequence and reads this file back directly.
void _dagplot_writejson(string scalar outpath, real scalar nn, real scalar nties,
		real scalar doarrows, real scalar htmlnodefactor, real scalar isdirected,
		real scalar hasnodelegend, real scalar hasedgelegend,
		real scalar hassizelegend, real scalar sizelegendn)
{
	string scalar json
	transmorphic fh

	json = _dagplot_buildjson(nn, nties, doarrows, htmlnodefactor, isdirected,
		hasnodelegend, hasedgelegend, hassizelegend, sizelegendn)
	fh = fopen(outpath, "w")
	fwrite(fh, json)
	fclose(fh)
}
end

capture program drop _dagplot_getcolorstyle
program def _dagplot_getcolorstyle
	syntax [, i(string) j(string) mlcolor(string) mlwidth(string) colorpalette(string) symbolpalette(string) edgecolorpalette(string) edgepatternpalette(string) scheme(string)]

	mata: st_rclear()
	local i = `i' - 1
	local j = `j' - 1
	
	// symbol of node
	if ("`symbolpalette'" != ""){
		local symbolpalette_length : word count `symbolpalette'
		local k  = mod(`j', `symbolpalette_length') + 1
		local symbol : word `k' of `symbolpalette' 
	}
	else {
		local symbol `"scheme p`=`j'+1'"'
	}


	if "`scheme'" == "sj" & "`edgepatternpalette'" == "" {
		local edgepatternpalette "dash solid dot dash solid"
	}
	
	// pattern of edge
	if "`edgepatternpalette'" != "" {
		local edgepatternpalette_length : word count `edgepatternpalette'
		local m  = mod(`i', `edgepatternpalette_length') + 1
		local edgepattern : word `m' of `edgepatternpalette'
	}
	else {
		//local edgepattern = "solid"	
		local edgepattern `"scheme p`=`i'+1'linepattern"'
	}
	
	// color of edge
	if "`edgecolorpalette'" != "" {
		local edgecolorpalette_length : word count `edgecolorpalette'
		local j  = mod(`i', `edgecolorpalette_length') + 1
		local edgecol : word `j' of `edgecolorpalette' 
	}
	else {
		local edgecol `"scheme p`=`i'+1'line"'
		/*
		if (strpos("s1mono s2mono sj s1manual s2manual", "") != 0){
			local edgecol `"scheme p`=`i'+2'"'
		}*/
	}
	
	// color of node
	if "`colorpalette'" != "" {
		local colorpalette_length : word count `colorpalette'
		local j  = mod(`i', `colorpalette_length') + 1
		local col_fill : word `j' of `colorpalette' 
	}
	else {
		local col_fill `"scheme p`=`i'+1'"'
	}

	
	if "`mlcolor'" == "" {
		local col_line = "`col_fill'"
	}
	else {
		local col_line "`mlcolor'"
	}
	
	if "`mlwidth'" == "" {
		mata: st_global("r(line_width)", "vthin")
	}
	else {
		mata: st_global("r(line_width)", "`mlwidth'")
	}
	mata: st_global("r(edgepattern)", "`edgepattern'")
	mata: st_global("r(edgecol)", "`edgecol'")
	mata: st_global("r(col_fill)", "`col_fill'")
	mata: st_global("r(col_line)", "`col_line'")
	mata: st_global("r(symbol)", "`symbol'")
end


/*************************************
*	Network layouts functions (Mata)
*************************************/

capture mata: mata drop dagplot_NumElist()
mata:
real matrix dagplot_NumElist(matrix onenet){
	real scalar nodes, i
	real matrix id, full, c1, c2, value, c3, from, to, res
	nodes = rows(onenet)
	id = range(1,nodes,1)
	full = J(nodes, nodes, 1)
	c1=colshape(full:* id,1)
	c2=colshape(full:*(id'),1)
	value=colshape(onenet,1)
	c3 = value:/value
	_editmissing(c3,0)
	
	from = select(c1,c3)
	to = select(c2,c3)
	res = J(rows(from),4,0)
	// BUGFIX: on a network with zero ties anywhere (e.g. a single-node
	// network, where no off-diagonal pair can even exist), `from'/`to'
	// are genuinely 0x0 empty matrices - but `res[.,1]' is a 0x1
	// selection (0 rows still expects 1 column), and assigning a 0x0
	// matrix into a 0x1 target is itself a Mata conformability error,
	// even though both sides have zero elements. `res' is already the
	// correct (empty) result in this case, so the assignment is both
	// unnecessary and unsafe - skipped entirely when there is nothing
	// to assign.
	if (rows(from) > 0) {
		res[.,1] = from
		res[.,2] = to
		res[.,3] = select(value, c3)

		for (i = 1; i <= rows(from); i++) {
			res[i,4] = onenet[res[i,1], res[i,2]] != 0 & onenet[res[i,2], res[i,1]] != 0
		}
	}
	return(res)
}
end

// Attempt to implement spring embedder... but sth does not work yet :-(
capture mata: mata drop dagplot_fruchtreinlayout()
mata:
real matrix function dagplot_fruchtreinlayout(real matrix M, real scalar Iter)
{
	real matrix Pos, Pos_up, v_disp
	real scalar F_repulsion, F_attraction, e1,e2, i, u, v, W, L, area, V, temperature, k ,v_pos ,e1_pos, e2_pos, delta
	
	W = 1
	L = 1
	area = W * L
	V = rows(M)
	Pos = runiform(V,2)
	F_repulsion = J(V,2,0)
	F_attraction = J(V,2,0)
	
	temperature = 1/10 * W	
	k = sqrt(area/V)
	
	temperature = 0
	
	for(i=1;i<= Iter;i++){
		// calculate repulsive force
		for(v=1;v<=V;v++){
			v_disp = J(1,2,0)
			for(u=1;u<=V;u++){
				if (v!=u) {
					delta = Pos[v,.] - Pos[u,.]
					v_disp = v_disp + (delta :/ abs(delta)) :* ((J(1,2,1):*(k,k)) :/ abs(delta))  
				}
			}

			F_repulsion[v,.] = v_disp
		}

		Pos_up = F_repulsion
		// calculate attractive force
		for(e1=1;e1<=V;e1++){
			for(e2=1;e2<=V;e2++){
				if (M[e1,e2]!=0){		
					delta = Pos[e1,.] - Pos[e2,.]
					//delta
					e1_pos = Pos_up[e1,.] - (delta :/abs(delta)) :* ( (abs(delta):* abs(delta)):/ k)
					e2_pos = Pos_up[e2,.] + (delta :/abs(delta)) :* ( (abs(delta):* abs(delta)):/ k)		
					Pos_up[e1,.] = e1_pos
					Pos_up[e2,.] = e2_pos
				
				}
			}
		}
		// limit displacement
		for (v=1;v<=V;v++){
			delta = Pos_up[v,.] - Pos[v,.]	
			Pos[v,1] = Pos[v,1] + (delta[1,1] / abs(delta[1,1])) * min((abs(delta[1,1]), temperature))
			Pos[v,2] = Pos[v,2] + (delta[1,2] / abs(delta[1,2])) * min((abs(delta[1,2]), temperature))
			
			
			Pos[v,1] = min(( W, max((- W, Pos[v,1]))))
			Pos[v,2] = min(( L, max(( - L, Pos[v,2]))))
			
		}
		
		// reduce temperature linerarly
		temperature = temperature - (1 / 3)*temperature
	}
	return(Pos)
}
end

capture mata: mata drop dagplot_mmdslayout()
mata:
real matrix function dagplot_mmdslayout(real matrix G)
{
	real matrix 	D, sCoord, Coord
	string scalar 	dMat, sMat
	real scalar ScaleFactor, rc, CoordMin1, CoordMin2, CoordMax1, CoordMax2

	Coord  =  circlelayout(rows(G))
	if (rows(G) == 2) {
		Coord[1,1] = 0.5
		Coord[2,1] = 0.5
		Coord[1,2] = 0.75
		Coord[2,2] = 0.25
	}

	D = distance(G) //compute distances
	_diag(D,0)
	
	/*
	// correct for two nodes having the same distance scores to all others
	for (i = 1; i< rows(D); i++) {
		for (j = i;j<=rows(D); j++){
			thisrow = J(1,cols(D),1)
			thisrow[1,i] = 0
			thisrow[1,j] = 0
			diff = select(D[i,.],thisrow) - select(D[j,.],thisrow)
			if ((sum(abs(diff)) == 0) & (i != j)){
				
				//dd_i = (J(1,i,1),J(1, (cols(D) - i),.5)) 
				//dd_j = (J(1,j,0),J(1, (cols(D) - j),.5))
				//D[i,j] = 3
				//D[j,i] = 3
				//D_i =  D[i,.] :* ((uniform(1,cols(D)):*0.5):+0.75)
				/*
				D[i,.] = D[i,.]:+ dd_i
				D[.,i] = D[.,i]:+ (dd_i)'
				D[j,.] = D[j,.]:+ dd_j
				D[.,j] = D[.,j]:+ (dd_j)'*/
				//D[i,j] = 3.2
				//D[j,i] = 3.2
				
				//D[i,.] = D[i,.] :+ J(1,cols(D), .5)
				//D[.,i] = D[.,i] :+ J(cols(D),1, .7)
				//D[j,.] = D[j,.] :+ J(1,cols(D), .8)
				//D[.,j] = D[.,j] :+ J(cols(D),1, .8)
				//D[i,.] = D_i
				//D[.,i] = D_i'
			}
		}
	}
	_diag(D,0)*/
	
	st_matrix("dMat",D) 	    //Distance mat to stata under tempname
	// compute MDS coordinates in stata
	rc = _stata( "  mdsmat dMat,  force noplot method(classical)", 1)
				//" di `test_rc")
	if (rc == 0) {
		Coord = st_matrix("e(Y)") 
		CoordMin1 = min(Coord[.,1])
		CoordMin2 = min(Coord[.,2])
		Coord[.,1] = (Coord[.,1] :- CoordMin1)
		Coord[.,2] = (Coord[.,2] :- CoordMin2)
	
		CoordMax1 = max(Coord[.,1])
		CoordMax2 = max(Coord[.,2])
		Coord[.,1] = (((Coord[.,1] :/ CoordMax1))) 
		Coord[.,2] = (((Coord[.,2] :/ CoordMax2)))
	}
	return(Coord)
}
end

capture mata: mata drop dagplot_correctCoordClash()
mata: 
real matrix function dagplot_correctCoordClash(real matrix Coord, real matrix net, real scalar b, real scalar prox){ 
	real matrix Coord_new, Ck, Ci
	real scalar i,j,k,x,y, angle
	Coord_new = Coord
	for(i = 1 ; i <= rows(Coord); i++) {
		for(j = (i + 1) ; j <= rows(Coord); j++) {
			//abs(Coord[i,1] - Coord[j,1])
			//abs(Coord[i,2] - Coord[j,2])
			//"next"
			if ((abs(Coord[i,1] - Coord[j,1]) <= prox) & (abs(Coord[i,2] - Coord[j,2]) <= prox)){
				Coord[i,1]
				Coord[j,1]				

			//& (Coord[i,2] == Coord[j,2])) {
				for (k = 1; k <= cols(net); k++) {
					if (net[k,i] != 0) {
						Ck = Coord[k,.]
						Ci = Coord[i,.]
						x = Ck[1,1] - Ci[1,1]
						y = Ck[1,2] - Ci[1,2]
						angle = atan2(y,x)
						Coord_new[i,2] = Coord_new[i,2] - sin(angle) * b
						Coord_new[i,1] = Coord_new[i,1] + cos(angle) * b
						Coord_new[j,2] = Coord_new[j,2] + sin(angle) * b
						Coord_new[j,1] = Coord_new[j,1] - cos(angle) * b
					}
				}
			}
		}
	}
	return(Coord_new)
}
end

capture mata: mata drop dagplot_netplotmds()
mata:
real matrix function dagplot_netplotmds(real matrix G, real scalar MaxIt)
{
        real matrix     D, sCoord, Coord
        string scalar   dMat, sMat
        real scalar ScaleFactor, rc, maxSX, maxSY, maxX, minX, maxY, minY, num_isol, maxYY, k,i, nonisolates 
        
		G = (G + G') :/ (G + G')
		_editmissing(G, 0)
		_diag(G,0)
		
        Coord  =  J(rows(G),2,.)
        sCoord = jumble(circlelayout(rows(G))) //circle coordinates as starting positions for mds
	    maxSX = max(sCoord[,1])
		maxSY = max(sCoord[,2])
		
        D = distance(G) //compute distances
        _diag(D,0)
		
        st_matrix(dMat=st_tempname(),D)         //Distance mat to stata under tempname
        st_matrix(sMat=st_tempname(),sCoord)    //Distance mat to stata under tempname

        // compute MDS coordinates in stata
        rc = _stata(  "qui mdsmat " + 
                dMat + 
                ", noplot method(modern) initialize(from(" + 
                sMat + 
                ")) iterate("+strofreal(MaxIt)+")" )
        
        if (rc!=0) {
                errprintf("mds computation failed \n")
                exit(rc)
        }

        Coord = st_matrix("e(Y)")       //pull coordinates back into mata
        
        // rescale coordinates to fit inside circle layout
		
		nonisolates = (rowsum(G):!= 0)
		
		maxX = max(select(Coord[.,1], nonisolates))
		minX = min(select(Coord[.,1], nonisolates))
		maxY = max(select(Coord[.,2], nonisolates))
		minY = min(select(Coord[.,2], nonisolates))

		Coord[,1] = (nonisolates :*(Coord[,1]:-minX) :* (1 / (maxX-minX)) :+ 0.25) :+ ((nonisolates:==0) :* Coord[,1])
		Coord[,2] = (nonisolates :*(Coord[,2]:-minY) :* (1 / (maxY-minY))) :+ ((nonisolates:==0):*Coord[,2])
		
		num_isol = sum( nonisolates:==0)
		maxYY = max(Coord[,2])
		
		k = 1
		for ( i = 1; i <= rows(G); i++) {
			if (nonisolates[i] == 0) {
			   Coord[i,1]=1.5
			   Coord[i,2]= (k / num_isol)
			   k = k + 1
			}
		}
		
        return(Coord)
}
end


// distance() and circlelayout() now live in unw_core.do, compiled into
// lib/lnwcommands.mlib - moved there so nwmovie.ado's own per-wave
// transitioning layout can reach kklayout() (which depends on both)
// reliably from a different .ado file. Calls below resolve against
// those shared definitions.

capture mata: mata drop dagplot_gridlayout()
mata:
real matrix function dagplot_gridlayout(real scalar N,  real scalar cols)
{
	real colvector 	V, C
	real matrix 	Coord
	real scalar CoordMax1, CoordMax2, rows

	V= (1::N)
	rows = ceil(N / cols)
	
	Coord=J(N,2,.)
	Coord[.,1] = J(N,1,100) :- floor((V:-1) :/rows) :* (100 / (cols - 1))
	
	Coord[.,2] = mod(V, rows)
	
	Coord[.,2] = editvalue(Coord[.,2],0,rows)
    Coord[.,2] = J(N,1,100) :- ((Coord[.,2] :- 1) :* (100 / (rows - 1)))
	
	if (rows == 1) {
		Coord[.,2] = J(cols, 1, 0.5)
	}
	CoordMax1 = max(Coord[.,1])
	CoordMax2 = max(Coord[.,2])
	Coord[.,1] = (((Coord[.,1] :/ CoordMax1)))
	Coord[.,2] = (((Coord[.,2] :/ CoordMax2)))
	Coord[.,1] = Coord[.,1] * 1.5
	
	return(Coord)
}



real matrix function dagplot_fruchtrein(real matrix M, real scalar Iter)
{
 real matrix Pos, Disp
 real vector delta
 real scalar radius, i, v,u,e1,e2,W, L, area, V, temperature, k, r
 W = 2
 L = 2
 area =  W*L
 radius= min((W,L))/2 
 V = rows(M)
 Pos = runiform(V,2):-.5  
 Pos[.,1]=floor(W):*runiform(V,1):-W/2 // Initial random position W
 Pos[.,2]=floor(L):*runiform(V,1):-L/2 // Initial random position L
 Disp = J(V,2,0)
 temperature = W/3
 k = sqrt(area/V)


	
 for(i=1;i<= Iter;i++){
 
// calculate repulsive force
	for(v=1;v<=V;v++){
	  for(u=1;u<=V;u++){
		if (v!=u) {
		 delta = Pos[v,.] - Pos[u,.]
		 Disp[v,.] = Disp[v,.] + (delta / norm(delta)) * ((k^2)/norm(delta))
		 }
	  }
	}

// calculate attractive force
	for(e1=1;e1<=V;e1++){
	   for(e2=e1+1;e2<=V;e2++){
		 if (M[e1,e2]!=0){		
		  delta = Pos[e1,.] - Pos[e2,.]
		  Disp[e1,.] = Disp[e1,.] - (delta /norm(delta)) * ( (norm(delta)* norm(delta))/ k)
		  Disp[e2,.] = Disp[e2,.] + (delta /norm(delta)) * ( (norm(delta)* norm(delta))/ k)		
		 }
	   }
	}

// Limit the maximum displacement to the temperature t
		for(v=1;v<=V;v++){
		   Pos[v,.]=Pos[v,.]+(Disp[v,.]/norm(Disp[v,.])*min((norm(Disp[v,.]),temperature)))
		   if (norm(Pos[v,.])>radius) Pos[v,.]=radius*Pos[v,.]/(norm(Pos[v,.]))
		   }
// Reduce temperature
    temperature = temperature - temperature/10
 }
return(Pos)
}

end

// Kamada-Kawai layout (layout(kk)): kklayout() itself, and its
// distance()/circlelayout() dependencies, now live in unw_core.do,
// compiled into lib/lnwcommands.mlib - moved there so nwmovie.ado's own
// per-wave transitioning layout can call kklayout() directly (with its
// optional warm-start `Start' argument) from a different .ado file. A
// Mata function defined inline inside one .ado file's own mata: block
// is not reliably callable from a different .ado file's own Mata code,
// even after the defining file has been auto-loaded via a real command
// call earlier in the same session - confirmed directly, and this is
// this package's own established fix for that (see NWdef and friends).

// Sugiyama-style hierarchical/layered layout (layout(hierarchy)),
// intended for directed, roughly DAG-shaped networks (organizational
// charts, citation/dependency graphs, event sequences). Three standard
// Sugiyama phases: (1) layer assignment via longest-path-from-sources
// ranking, with a documented cycle-tolerant fallback for networks that
// are not actually acyclic (this package does not require callers to
// pre-check acyclicity - true DAGs get an exact longest-path layering,
// networks with cycles get a deterministic, non-crashing "peel the
// current minimum-indegree node(s)" approximation instead of an error
// or an infinite loop); (2) a small fixed number of barycenter sweeps
// to reduce edge crossings within each layer; (3) evenly-spaced
// coordinates by final within-layer order and layer number. For an
// UNDIRECTED network (M symmetric), every active node's in-degree
// equals its own degree, so phase (1) has no true zero-indegree source
// to start from and immediately falls back to plain minimum-degree
// peeling order throughout - still a deterministic, valid, non-crashing
// coordinate assignment, just not a meaningful top-down hierarchy since
// undirected ties carry no hierarchy signal to layer by; this layout is
// only meaningful for directed input, matching how `frucht'/`kk' above
// are likewise agnostic to directedness without claiming to need it.
capture mata: mata drop dagplot_sugiyamalayout()
mata:
real matrix function dagplot_sugiyamalayout(real matrix M, real scalar Iter)
{
	real matrix Pos, sortmat
	real colvector active, indeg, remaining, ready, layer, xrank
	real scalar V, i, j, frontier, minindeg, sweeps, s, L, maxlayer, cnt, r, num_isol, k, bsum, bcnt

	V = rows(M)
	active = ((rowsum(M) :+ colsum(M)') :!= 0)

	// --- phase 1: layer assignment ---
	indeg = colsum(M)'
	remaining = active
	layer = J(V,1,-1)
	frontier = 0

	while (sum(remaining) > 0) {
		ready = remaining :& (indeg :== 0)
		if (sum(ready) == 0) {
			// no true source remains (a cycle, or an undirected
			// component) - force progress by peeling whichever
			// remaining node(s) currently have the smallest indegree,
			// same idea as a min-indegree feedback-arc-set heuristic
			minindeg = min(select(indeg, remaining))
			ready = remaining :& (indeg :== minindeg)
		}
		for (i=1; i<=V; i++) {
			if (ready[i]) layer[i] = frontier
		}
		for (i=1; i<=V; i++) {
			if (ready[i]) {
				for (j=1; j<=V; j++) {
					if (M[i,j] != 0 & remaining[j] == 1) indeg[j] = indeg[j] - 1
				}
			}
		}
		remaining = remaining :& (ready :== 0)
		frontier = frontier + 1
	}
	maxlayer = max(layer)
	if (maxlayer < 0) maxlayer = 0

	// initial within-layer order = plain node index order
	xrank = J(V,1,0)
	for (L=0; L<=maxlayer; L++) {
		cnt = 0
		for (i=1; i<=V; i++) {
			if (active[i] & layer[i]==L) {
				cnt = cnt + 1
				xrank[i] = cnt
			}
		}
	}

	// --- phase 2: barycenter crossing-reduction sweeps ---
	// a fixed small number of alternating downward/upward passes - this
	// heuristic converges (or starts cycling) within a handful of
	// sweeps regardless of network size, so unlike the stress-
	// majorization/force-directed layouts above, this one does not
	// scale its own work with iterations()
	sweeps = 8
	for (s=1; s<=sweeps; s++) {
		if (mod(s,2) == 1) {
			for (L=1; L<=maxlayer; L++) {
				cnt = 0
				for (i=1; i<=V; i++) if (active[i] & layer[i]==L) cnt++
				if (cnt > 1) {
					sortmat = J(cnt,2,0)
					r = 0
					for (i=1; i<=V; i++) {
						if (active[i] & layer[i]==L) {
							r++
							sortmat[r,1] = i
							bsum = 0
							bcnt = 0
							for (j=1; j<=V; j++) {
								if (active[j] & layer[j]==L-1 & (M[j,i]!=0 | M[i,j]!=0)) {
									bsum = bsum + xrank[j]
									bcnt = bcnt + 1
								}
							}
							if (bcnt > 0) sortmat[r,2] = bsum/bcnt
							else sortmat[r,2] = xrank[i]
						}
					}
					sortmat = sort(sortmat, 2)
					for (r=1; r<=cnt; r++) xrank[sortmat[r,1]] = r
				}
			}
		}
		else {
			for (L=maxlayer-1; L>=0; L--) {
				cnt = 0
				for (i=1; i<=V; i++) if (active[i] & layer[i]==L) cnt++
				if (cnt > 1) {
					sortmat = J(cnt,2,0)
					r = 0
					for (i=1; i<=V; i++) {
						if (active[i] & layer[i]==L) {
							r++
							sortmat[r,1] = i
							bsum = 0
							bcnt = 0
							for (j=1; j<=V; j++) {
								if (active[j] & layer[j]==L+1 & (M[j,i]!=0 | M[i,j]!=0)) {
									bsum = bsum + xrank[j]
									bcnt = bcnt + 1
								}
							}
							if (bcnt > 0) sortmat[r,2] = bsum/bcnt
							else sortmat[r,2] = xrank[i]
						}
					}
					sortmat = sort(sortmat, 2)
					for (r=1; r<=cnt; r++) xrank[sortmat[r,1]] = r
				}
			}
		}
	}

	// --- phase 3: coordinates - top layer at y=1, bottom at y=0,
	// evenly spaced x within [0.25,1.25] by final within-layer order,
	// same established plotting-box convention as kklayout()/
	// dagplot_netplotmds() above ---
	Pos = J(V,2,0.5)
	for (i=1; i<=V; i++) {
		if (active[i]) {
			cnt = 0
			for (j=1; j<=V; j++) if (active[j] & layer[j]==layer[i]) cnt++
			if (cnt > 1) Pos[i,1] = 0.25 + ((xrank[i]-1)/(cnt-1))
			else Pos[i,1] = 0.75
			if (maxlayer > 0) Pos[i,2] = 1 - (layer[i]/maxlayer)
			else Pos[i,2] = 0.5
		}
	}

	// isolates -> own column at x=1.5, same convention as kklayout()/dagplot_netplotmds()
	num_isol = sum(active:==0)
	k = 1
	for (i=1; i<=V; i++) {
		if (active[i] == 0) {
			Pos[i,1] = 1.5
			Pos[i,2] = (k / num_isol)
			k = k + 1
		}
	}

	return(Pos)
}
end

// Dedicated two-mode (bipartite) layout (layout(bipartite)): the two
// modes placed in two parallel bands - two rows by default (mode "1"
// along y=1, mode "2" along y=0), or two columns with `vertical' (mode
// "1" along x=0.25, mode "2" along x=1.25) - with nodes ordered within
// each band via a small number of barycenter sweeps (same crossing-
// reduction idea as dagplot_sugiyamalayout() above, simplified to exactly two
// bands instead of an arbitrary number of layers). Unlike every other
// layout function in this file, this one does NOT push isolates into
// their own x=1.5 column - an isolated node in a two-mode network still
// has a real, meaningful mode membership, and folding it into its own
// mode's band (rather than a generic third column) is the whole point
// of a mode-aware layout.
capture mata: mata drop dagplot_bipartitelayout()
mata:
real matrix function dagplot_bipartitelayout(real matrix M, string rowvector modevec, real scalar vertical)
{
	real matrix Pos, sortmat
	real colvector mode1, mode2, xrank
	real scalar V, i, j, cnt1, cnt2, r, cnt, bsum, bcnt, s

	V = rows(M)
	mode1 = J(V,1,0)
	mode2 = J(V,1,0)
	for (i=1; i<=V; i++) {
		if (modevec[i] == "1") mode1[i] = 1
		else mode2[i] = 1
	}

	// initial within-band order = plain node index order
	xrank = J(V,1,0)
	cnt = 0
	for (i=1; i<=V; i++) {
		if (mode1[i]) {
			cnt = cnt + 1
			xrank[i] = cnt
		}
	}
	cnt1 = cnt
	cnt = 0
	for (i=1; i<=V; i++) {
		if (mode2[i]) {
			cnt = cnt + 1
			xrank[i] = cnt
		}
	}
	cnt2 = cnt

	// alternating barycenter sweeps - only two bands exist, so a couple
	// of passes is enough to settle (no benefit from more, same
	// reasoning as dagplot_sugiyamalayout()'s own fixed sweep count)
	for (s=1; s<=2; s++) {
		if (cnt1 > 1) {
			sortmat = J(cnt1,2,0)
			r = 0
			for (i=1; i<=V; i++) {
				if (mode1[i]) {
					r = r + 1
					sortmat[r,1] = i
					bsum = 0
					bcnt = 0
					for (j=1; j<=V; j++) {
						if (mode2[j] & (M[i,j]!=0 | M[j,i]!=0)) {
							bsum = bsum + xrank[j]
							bcnt = bcnt + 1
						}
					}
					if (bcnt > 0) sortmat[r,2] = bsum/bcnt
					else sortmat[r,2] = xrank[i]
				}
			}
			sortmat = sort(sortmat, 2)
			for (r=1; r<=cnt1; r++) xrank[sortmat[r,1]] = r
		}
		if (cnt2 > 1) {
			sortmat = J(cnt2,2,0)
			r = 0
			for (i=1; i<=V; i++) {
				if (mode2[i]) {
					r = r + 1
					sortmat[r,1] = i
					bsum = 0
					bcnt = 0
					for (j=1; j<=V; j++) {
						if (mode1[j] & (M[i,j]!=0 | M[j,i]!=0)) {
							bsum = bsum + xrank[j]
							bcnt = bcnt + 1
						}
					}
					if (bcnt > 0) sortmat[r,2] = bsum/bcnt
					else sortmat[r,2] = xrank[i]
				}
			}
			sortmat = sort(sortmat, 2)
			for (r=1; r<=cnt2; r++) xrank[sortmat[r,1]] = r
		}
	}

	Pos = J(V,2,0.5)
	for (i=1; i<=V; i++) {
		if (mode1[i]) {
			if (vertical) {
				Pos[i,1] = 0.25
				if (cnt1 > 1) Pos[i,2] = (xrank[i]-1)/(cnt1-1)
				else Pos[i,2] = 0.5
			}
			else {
				Pos[i,2] = 1
				if (cnt1 > 1) Pos[i,1] = 0.25 + ((xrank[i]-1)/(cnt1-1))
				else Pos[i,1] = 0.75
			}
		}
		else {
			if (vertical) {
				Pos[i,1] = 1.25
				if (cnt2 > 1) Pos[i,2] = (xrank[i]-1)/(cnt2-1)
				else Pos[i,2] = 0.5
			}
			else {
				Pos[i,2] = 0
				if (cnt2 > 1) Pos[i,1] = 0.25 + ((xrank[i]-1)/(cnt2-1))
				else Pos[i,1] = 0.75
			}
		}
	}

	return(Pos)
}
end
