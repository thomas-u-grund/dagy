*! dagplot.ado 1.0.0 2026-09-15
*! dagy's own interactive DAG viewer - see dagplot.sthlp.
*!
*! dagplot, adjmatrix(matname) nodename(varname) nodexy(xvar yvar)
*!     [ lab arrows color(varname) colorpalette(colorlist)
*!       nodefactor(#) scheme(string) noopen ]
*!
*! Renders the dataset currently in memory (one observation per node, in
*! the same row order as adjmatrix's rows/columns) as an interactive
*! (cytoscape.js-based) graph viewer, via dagplot_template.html and the
*! native viewer launched by _dagplot_openviewer.ado.
*!
*! Originally forked from nwcommands_2016's nwplot (see this package's
*! git history) to fix two real bugs in its interactive view without
*! touching nwcommands itself. Rewritten from scratch at this version to
*! drop that ancestry entirely: dagy only ever calls this one fixed way
*! (a directed graph, one node-color grouping variable, a caller-supplied
*! layout, the interactive viewer, nothing else), and nwplot's own general
*! machinery - if/in filtering, size()/symbol()/edgecolor()/edgesize()
*! variation, movie export, the CSV edge-import/coordinate-import round
*! trip, every layout algorithm besides a caller-supplied one, and above
*! all the "current network" object model (nwset/nw_syntax/nw_datasync/
*! unw_defs, all from nwcommands' own adopath) it all sat on top of - was
*! never exercised through that one call shape. None of it is needed and
*! none of it is here anymore. What's left has no dependency on
*! nwcommands, or on any other external package, of any kind: adjmatrix()
*! is a plain Stata matrix, not a "network" object, and every remaining
*! helper program/Mata function below is this file's own.
*!
*! adjmatrix() names a plain Stata matrix (nodes x nodes, 0/1, directed:
*! row i, col j nonzero means an edge FROM node i TO node j), in the same
*! node order as the dataset's own observations - nodename() and
*! nodexy()'s two variables give that same node its display name and
*! plotted position. color() is optional and, if given, must be a string
*! or numeric variable - nodes sharing a value are grouped and colored
*! together (in ascending sort order of that value, same order as
*! levelsof), with colorpalette() supplying the fill colors in that same
*! order (recycled if shorter than the number of groups); without
*! color(), every node gets the first colorpalette() color (or "scheme
*! p1" if colorpalette() is empty too).
capture program drop dagplot
program dagplot, rclass
	version 14
	syntax , ADJmatrix(string) NODEname(varname) NODEXY(varlist numeric min=2 max=2) ///
		[ LAB ARROWS COLOR(varname) COLORpalette(string) NODEFACTOR(real 1) ///
		  SCHEME(string) NOOpen ]

	local nodes = _N
	if `nodes' == 0 {
		di as err "no observations (nodes) in the dataset"
		exit 2000
	}
	capture confirm matrix `adjmatrix'
	if _rc {
		di as err "matrix `adjmatrix' not found"
		exit 111
	}
	if rowsof(`adjmatrix') != `nodes' | colsof(`adjmatrix') != `nodes' {
		di as err "adjmatrix(`adjmatrix') must be `nodes' x `nodes' (one row/column per node, in dataset row order)"
		exit 503
	}
	// Stata's own s2color - always present, unlike nwcommands' own
	// custom-shipped s1network scheme (nwplot's original default,
	// meaningless once dagplot no longer sits on nwcommands' adopath).
	if "`scheme'" == "" local scheme "s2color"
	local doarrows = ("`arrows'" != "")
	local isdirected = `doarrows'
	local nodefactor = `nodefactor' / 50

	local nodex : word 1 of `nodexy'
	local nodey : word 2 of `nodexy'

	capture mata: mata drop plotmat Coord ncolor nsymbol nsize nlabel
	mata: plotmat = st_matrix("`adjmatrix'")
	mata: Coord = J(`nodes', 2, 0)
	mata: Coord[.,1] = st_data((1,`nodes'), "`nodex'")
	mata: Coord[.,2] = st_data((1,`nodes'), "`nodey'")
	// [0,1] -> pixel-style [5,95] rescale, matching what
	// _dagplot_buildjson()'s own inverse transform (nx/100-0.05)/0.9
	// expects - the range dagy's own layout already targets (see
	// _dagy_layout_compute).
	mata: Coord = Coord :* 100
	mata: Coord = (Coord :* 0.9) :+ 5

	if "`color'" != "" {
		tempvar colorgroup
		qui egen `colorgroup' = group(`color')
		mata: ncolor = st_data((1,`nodes'), st_varindex("`colorgroup'"))
		qui levelsof `color', local(colorlevels)
	}
	else {
		mata: ncolor = J(`nodes', 1, 1)
		local colorlevels ""
	}
	local ncolorgroups : word count `colorlevels'
	if `ncolorgroups' == 0 local ncolorgroups = 1

	mata: nsymbol = J(`nodes', 1, 1)
	mata: nsize = J(`nodes', 1, 80)
	if "`lab'" != "" {
		mata: nlabel = st_sdata((1,`nodes'), "`nodename'")
	}
	else {
		mata: nlabel = J(`nodes', 1, "")
	}

	// Resolve each color group's browser-facing RGB - Stata color names
	// ("orange", ...) or scheme-relative tokens ("scheme p1") don't mean
	// anything to a browser; _dagplot_getcolorstyle/
	// _dagplot_resolvecolorstylebatch render a throwaway marker per group
	// and parse its real RGB back out of an EPS export (there is no
	// documented Stata API to resolve a color name to RGB directly).
	local _dp_pending_n = 0
	local _dp_plots ""
	forvalues g = 1/`ncolorgroups' {
		_dagplot_getcolorstyle, i(`g') colorpalette(`colorpalette')
		local _dp_pending_n = `_dp_pending_n' + 1
		local _dp_plots `"`_dp_plots' (scatter _dp_y _dp_x if _n==`_dp_pending_n', mcolor("`r(col_fill)'") msymbol(O) msize(large))"'
	}
	_dagplot_resolvecolorstylebatch, n(`_dp_pending_n') scheme(`scheme') plots(`"`_dp_plots'"')
	forvalues g = 1/`ncolorgroups' {
		local _nwedit_htmlcolor_`g' "`_dp_batchrgb`g''"
		if `"`colorlevels'"' != "" {
			local lvl : word `g' of `colorlevels'
			local _nwedit_colorlabel_`g' `"`lvl'"'
		}
	}
	// Node shape and edge color/style never vary in dagy's own usage
	// (there is no symbol()/edgecolor() option here at all) - fixed to a
	// plain circle node and a neutral solid edge instead of resolving
	// them through the same EPS trick as the real, caller-chosen node
	// colors.
	local _nwedit_htmlshape_1 "circle"
	local _nwedit_htmledgecolor_0 "90 90 90"
	local _nwedit_htmledgestyle_0 "solid"
	local _nwedit_hasnodelegend = (`ncolorgroups' > 1)
	local _nwedit_hasedgelegend = 0
	local _nwedit_hassizelegend = 0

	mata: st_numscalar("r(ties)", rows(dagplot_NumElist(plotmat)))
	local nties = `r(ties)'

	// Build the scratch plotting dataset _dagplot_buildjson() reads by
	// variable name - preserve/restore so a direct (non-dagy) caller's
	// own data, even a variable literally named "nx", is untouched.
	preserve
	qui drop _all
	qui set obs `nodes'
	qui gen double nx = .
	qui gen double ny = .
	qui gen double nsize = .
	qui gen double ncolor = .
	qui gen double nsymbol = .
	qui mata: st_addvar("str244", "nlabel")
	mata: st_store((1::`nodes'), ("nx","ny"), Coord)
	mata: st_store((1::`nodes'), "nsize", nsize)
	mata: st_store((1::`nodes'), "ncolor", ncolor)
	mata: st_store((1::`nodes'), "nsymbol", nsymbol)
	mata: st_sstore((1::`nodes'), "nlabel", nlabel)

	if `nties' > `nodes' {
		qui set obs `nties'
	}
	qui gen double edgecolor = .
	qui gen double recip = .
	if `nties' > 0 {
		mata: st_store((1::`nties'), "edgecolor", J(`nties', 1, 0))
		mata: st_store((1::`nties'), "recip", dagplot_NumElist(plotmat)[.,4])
	}

	di as txt "Preparing interactive view..."
	mata: st_local("_dp_pkgdir", _dagplot_installdir())
	local _dp_template = "`_dp_pkgdir'/dagplot_template.html"
	local _dp_vendorjs = "`_dp_pkgdir'/cytoscape.min.js"
	capture confirm file "`_dp_template'"
	if _rc {
		di as err "dagplot_template.html not found at `_dp_template'; reinstall the package."
		error 601
	}
	capture confirm file "`_dp_vendorjs'"
	if _rc {
		di as err "Vendored cytoscape.min.js not found at `_dp_vendorjs'; reinstall the package."
		error 601
	}

	// Not tempfile - Stata auto-erases a program-scoped tempfile the
	// moment this program returns, which here would mean the file could
	// vanish before the viewer has actually finished reading it. Built
	// manually in the OS temp dir instead, so its lifetime isn't tied to
	// this program's own scope.
	local _dp_out = "`c(tmpdir)'" + "dagplot_" + subinstr(subinstr("`c(current_time)'", ":", "", .), " ", "", .) + "_" + strofreal(int(runiform()*1000000)) + ".html"
	capture erase "`_dp_out'"
	mata: _dagplot_buildinteractivehtml("`_dp_template'", "`_dp_vendorjs'", "`_dp_out'", `nodes', `nties', `doarrows', `nodefactor', `isdirected', `_nwedit_hasnodelegend', `_nwedit_hasedgelegend', `_nwedit_hassizelegend', 0)

	restore

	if "`noopen'" == "" {
		di as txt "Opening interactive view..."
		_dagplot_openviewer "`_dp_out'"
	}

	return local scheme "`scheme'"
	return local interactive "`_dp_out'"

	capture mata: mata drop plotmat Coord ncolor nsymbol nsize nlabel
end

capture program drop _dagplot_getcolorstyle
program def _dagplot_getcolorstyle, rclass
	// Resolves color group `i' to a fill color spec: the i-th entry of
	// colorpalette() (cycling if there are more groups than colors given),
	// or a scheme-relative "scheme p<i>" token if colorpalette() is empty
	// (dagy itself always supplies colorpalette(), so this fallback only
	// matters for a caller invoking dagplot directly).
	syntax, i(int) [ colorpalette(string) ]
	if "`colorpalette'" != "" {
		local n : word count `colorpalette'
		local k = mod(`i' - 1, `n') + 1
		local col : word `k' of `colorpalette'
	}
	else {
		local col "scheme p`i'"
	}
	return local col_fill "`col'"
end

capture program drop _dagplot_resolvecolorstylebatch
program def _dagplot_resolvecolorstylebatch
	// Resolves every pending node-fill token in one batched draw+export+
	// parse pass (one throwaway graph per group would visibly flash
	// Stata's real graph window repeatedly in an interactive session) -
	// draws `n' markers, each colored via mcolor() by its own plots()
	// subcommand (built by the caller, referencing _dp_x/_dp_y - a called
	// ado program cannot see its caller's local macros, so the plot
	// specs themselves, not tokens for this program to resolve
	// internally, are what's passed in), exports to EPS, and parses each
	// marker's real RGB back out of the EPS's own "/Ssrgb {r g b} def"
	// color-state defs paired with the "Scc" circle-marker draw op that
	// consumes each one.
	syntax, n(int) scheme(string) plots(string)

	tempfile _dp_eps
	preserve
	qui drop _all
	qui set obs `n'
	qui set scheme `scheme'
	qui gen _dp_x = _n
	qui gen _dp_y = 1
	qui twoway `plots', legend(off) xlabel(none) ylabel(none) xtitle("") ytitle("") name(_dagplot_colorresolve, replace)
	qui graph export "`_dp_eps'", replace as(eps)
	capture graph close _dagplot_colorresolve
	restore

	tempname _dp_epsfh
	file open `_dp_epsfh' using "`_dp_eps'", read
	local _dp_current ""
	local _dp_idx = 0
	local _dp_recorded = 1
	file read `_dp_epsfh' _dp_line
	while r(eof) == 0 {
		if strpos(`"`_dp_line'"', "/Ssrgb {") > 0 {
			local _dp_start = strpos(`"`_dp_line'"', "{") + 1
			local _dp_close = strpos(`"`_dp_line'"', "}")
			local _dp_current = substr(`"`_dp_line'"', `_dp_start', `_dp_close' - `_dp_start')
			// Only marks a color "pending" here; the index itself only
			// advances where it's actually consumed by a real draw op
			// below - the EPS also carries incidental color-state defs
			// (e.g. a white background) that never get consumed by any
			// draw op at all, and counting those too would shift every
			// real element after one by one, dropping the last entirely.
			local _dp_recorded = 0
		}
		// substr(...)!="/" excludes the "/Scc {"-style PROCEDURE
		// DEFINITION line (PostScript boilerplate, appears once near the
		// top of every EPS this program exports) from matching this check
		// - a real draw call looks like "1568 11757 318 0 1 Scc ", numbers
		// first, never a leading "/".
		if strpos(`"`_dp_line'"', "Scc") > 0 & substr(`"`_dp_line'"', 1, 1) != "/" & `_dp_recorded' == 0 & "`_dp_current'" != "" {
			// Each marker draws 2 Scc calls (fill+stroke) off the same
			// Ssrgb def; `_dp_recorded' (reset only on a fresh color def,
			// not after each draw op) takes just the first of the pair.
			local _dp_idx = `_dp_idx' + 1
			local _dp_r : word 1 of `_dp_current'
			local _dp_g : word 2 of `_dp_current'
			local _dp_b : word 3 of `_dp_current'
			local _dp_r = round(`_dp_r' * 255)
			local _dp_g = round(`_dp_g' * 255)
			local _dp_b = round(`_dp_b' * 255)
			c_local _dp_batchrgb`_dp_idx' "`_dp_r' `_dp_g' `_dp_b'"
			local _dp_recorded = 1
		}
		file read `_dp_epsfh' _dp_line
	}
	file close `_dp_epsfh'
end

// Pure Mata below - no nwcommands dependency, no external state besides
// the Stata dataset/matrix conventions documented at this file's own top.
capture mata: mata drop dagplot_NumElist()
capture mata: mata drop _dagplot_installdir()
capture mata: mata drop _dagplot_buildjson()
capture mata: mata drop _dagplot_slurpfile()
capture mata: mata drop _dagplot_buildinteractivehtml()
mata:
// Enumerates every tie in an nodes x nodes adjacency matrix as a
// (from, to, value, recip) row list - recip flags a reciprocated pair
// (onenet[i,j]!=0 & onenet[j,i]!=0), which never actually occurs for an
// acyclic adjmatrix but is cheap to keep correct/general.
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
	// `res[.,1]' is a 0x1 selection when there are zero ties anywhere
	// (still expects 1 column even with 0 rows) - assigning the 0x0
	// `from'/`to' into it is itself a Mata conformability error even
	// though both sides have zero elements, so skip the assignment
	// entirely when there's nothing to assign; `res' is already the
	// correct (empty) result in that case.
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

// Deliberately its own lookup, not nwcommands' unw_core.do
// NativeGraphInstallDir() (which resolves via findfile("nwset.ado") -
// i.e. wherever nwcommands itself is installed, if at all): dagplot's
// template/vendored JS live next to THIS file. _dagplot_openviewer.ado
// uses this same lookup for its own plugins/*/dagplot_viewer binary.
string scalar _dagplot_installdir(){
	string scalar full, dir, fn

	full = findfile("dagplot.ado")
	if (full == "") return("")
	pathsplit(full, dir, fn)
	return(dir)
}

// Builds the interactive HTML page's inline node/edge JSON. nx/ny/nsize/
// ncolor/nsymbol/nlabel/edgecolor/recip are the scratch dataset variables
// dagplot's own main program just st_store'd; the _nwedit_htmlcolor_<g>/
// _nwedit_htmlshape_<g>/_nwedit_colorlabel_<g>/_nwedit_htmledgecolor_0/
// _nwedit_htmledgestyle_0 locals it also set are read back here by name.
string scalar _dagplot_buildjson(real scalar nn, real scalar nties,
		real scalar doarrows, real scalar htmlnodefactor, real scalar isdirected,
		real scalar hasnodelegend, real scalar hasedgelegend,
		real scalar hassizelegend, real scalar sizelegendn)
{
	real colvector nxv, nyv, nsizev, ncolorv, nsymbolv, edgecolorv, recipv
	string colvector nlabelv
	real matrix topology
	string scalar json, lbl, colorstr, shapestr, q, grouplbl, shapelbl, edgegrouplbl
	real scalar i, cg, sg, ecg, fromidx, toidx, sizepx, nemitted
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
		q+"size_legend"+q+":[]," +
		q + "nodes" + q + ":["
	for (i=1; i<=nn; i++) {
		cg = ncolorv[i]
		sg = nsymbolv[i]
		colorstr = st_local("_nwedit_htmlcolor_" + strofreal(cg))
		shapestr = st_local("_nwedit_htmlshape_" + strofreal(sg))
		grouplbl = st_local("_nwedit_colorlabel_" + strofreal(cg))
		if (grouplbl == "") grouplbl = "Group " + strofreal(cg)
		grouplbl = subinstr(subinstr(grouplbl, char(92), ""), q, "")
		shapelbl = "Group " + strofreal(sg)
		lbl = subinstr(subinstr(nlabelv[i], char(92), ""), q, "")
		// nsize*htmlnodefactor*2*7 mirrors the earlier nwplot-derived
		// formula this was ported from: nsize=80, nodefactor's own 1/50
		// default give ~22px, a comfortable CSS-pixel size empirically
		// tuned against a real browser view.
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
			// plotmat is symmetric for an undirected tie, so
			// dagplot_NumElist finds both (i,j) and (j,i) - skip the
			// fromidx>toidx half of each undirected pair rather than
			// draw it twice. Never actually triggers for a DAG's own
			// adjmatrix (always directed), kept for correctness/
			// generality since it's free.
			if (isdirected == 0 & fromidx > toidx) continue
			colorstr = st_local("_nwedit_htmledgecolor_" + strofreal(ecg))
			shapestr = st_local("_nwedit_htmledgestyle_" + strofreal(ecg))
			edgegrouplbl = "Group " + strofreal(ecg)
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
// no error at all).
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
end
