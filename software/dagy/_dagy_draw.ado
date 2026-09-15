*! _dagy_draw.ado 0.4.0 2026-08-31
*! internal - see help dagy
*! dagy draw [name] [, exposure(name) outcome(name) adjust(namelist)
*!     labsize(#) nodesize(#) arrowsize(#) nointeractive nwplot_options]
*!
*! Builds an ordinary nwcommands network from the DAG's edges and hands
*! it to dagplot; dagy's own job is (a) working out each node's causal role
*! (exposure/outcome/adjusted/mediator/confounder/.../unobserved) and
*! turning that into a color() for dagplot, and (b) a layered layout (see
*! _dagy_layout_compute.ado / `dagy layout`) passed through as nodexy(),
*! unless the caller supplies their own layout(). Defaults to dagplot's
*! interactive (cytoscape-based) viewer; nointeractive draws a plain
*! static graph instead. dagplot (software/dagplot/dagplot.ado) is a
*! standalone fork of nwcommands' own nwplot, kept alongside dagy so its
*! interactive rendering (and, as of this version, its own viewer
*! launcher/native binary too) can be edited freely; it only needs
*! nwcommands on adopath for nwset.
program _dagy_draw
	version 14
	syntax [anything] [, EXPOSURE(string) OUTCOME(string) ADJUST(string) ///
		LAYOUT(string) LABELOPT(string) NODEFACTOR(string) ARROWFACTOR(string) ///
		ARCSTYLE(string) LABSIZE(string) NODESIZE(string) ARROWSIZE(string) ///
		NOInteractive *]

	_dagy_resolve `anything'
	local name `r(name)'
	if `"`r(rest)'"' != "" {
		di as err "dagy draw takes no positional arguments besides the DAG name; use exposure()/outcome()/adjust() instead."
		exit 198
	}

	mata: dagy_m_readfr("dagy_`name'_n", "dagy_`name'_e", dagnodes=J(0,1,""), dagA=J(0,0,.), daglatent=J(0,1,.))

	foreach opt in exposure outcome {
		if `"``opt''"' != "" {
			cap mata: dagy_m_idx(dagnodes, "``opt''")
			if _rc {
				di as err "``opt'' is not a node of DAG `name'"
				exit 198
			}
		}
	}
	foreach v of local adjust {
		cap mata: dagy_m_idx(dagnodes, "`v'")
		if _rc {
			di as err "`v' is not a node of DAG `name'"
			exit 198
		}
	}

	// cosmetic convenience options merge into their dagplot equivalents;
	// giving both the raw dagplot option and the convenience option at
	// once is almost always a mistake (which one wins?), so refuse it.
	if `"`labsize'"' != "" {
		if `"`labelopt'"' != "" {
			local labelopt `"`labelopt' mlabsize(`labsize')"'
		}
		else {
			local labelopt `"mlabsize(`labsize')"'
		}
	}
	if `"`nodesize'"' != "" {
		if `"`nodefactor'"' != "" {
			di as err "specify only one of {bf:nodefactor()} or {bf:nodesize()}"
			exit 198
		}
		local nodefactor `"`nodesize'"'
	}
	if `"`arrowsize'"' != "" {
		if `"`arrowfactor'"' != "" {
			di as err "specify only one of {bf:arrowfactor()} or {bf:arrowsize()}"
			exit 198
		}
		local arrowfactor `"`arrowsize'"'
	}
	// dagplot's own default nodefactor (1) is sized for its force-directed/
	// mds layouts; dagy's layered layout leaves nodes looking small
	// and cramped at that setting, so dagy draw defaults to a bigger
	// size instead unless the caller asks for a specific one. arrowfactor
	// must scale together with it: dagplot's own arrowfactor default (1)
	// is a fixed value, not computed relative to nodefactor, and the
	// line-trim radius that clears space for the arrowhead *does* grow
	// with nodefactor - so a bigger nodefactor with arrowfactor left at
	// dagplot's default trims the line back far enough that the
	// still-tiny default arrowhead becomes imperceptible (confirmed as a
	// real defect this way: every arrowhead in the drawn DAGs had
	// silently vanished, leaving plain undirected-looking lines, because
	// this default nodefactor bump was added without a matching
	// arrowfactor default alongside it).
	if `"`nodefactor'"' == "" local nodefactor "1.6"
	if `"`arrowfactor'"' == "" local arrowfactor "2"

	local cosmeticopts ""
	if `"`labelopt'"' != "" local cosmeticopts `"`cosmeticopts' labelopt(`labelopt')"'
	if `"`nodefactor'"' != "" local cosmeticopts `"`cosmeticopts' nodefactor(`nodefactor')"'
	if `"`arrowfactor'"' != "" local cosmeticopts `"`cosmeticopts' arrowfactor(`arrowfactor')"'

	mata: dagrole = dagy_m_roles(dagA, dagnodes, daglatent, "`exposure'", "`outcome'", `"`adjust'"')
	mata: st_local("nn", strofreal(rows(dagnodes)))

	local colormap_adjusted             "orange"
	local colormap_ancestor_of_exposure "ltblue"
	local colormap_ancestor_of_outcome  "pink"
	local colormap_ancestor_of_both     "navy"
	local colormap_exposure             "green"
	local colormap_mediator             "purple"
	local colormap_other                "gs8"
	local colormap_outcome              "red"
	local colormap_unobserved           "gs12"

	// a layout is computed the first time a DAG is drawn and then
	// reused (stable across repeated `dagy draw` calls); `dagy layout`
	// lets the user recompute it or pin individual nodes afterward.
	local usenodexy = (`"`layout'"' == "")
	if `usenodexy' {
		cap confirm frame dagy_`name'_xy
		if _rc {
			_dagy_layout_compute `name' horizontal `outcome'
		}
		mata: dagy_m_readxy("dagy_`name'_xy", dagxynodes=J(0,1,""), dagx=J(0,1,.), dagy=J(0,1,.))
	}
	if `"`arcstyle'"' != "" local cosmeticopts `"`cosmeticopts' arcstyle(`arcstyle')"'

	// nwset's mat() path doesn't accept its own clear option cleanly
	// in this nwcommands build, so clear by hand - and save/restore
	// whatever the user had in memory around that.
	local haddata = (_N > 0 | c(k) > 0)
	if `haddata' {
		tempfile dagy_userdata
		qui save `dagy_userdata', replace
	}

	qui clear
	nwset, mat(dagA) name(dagy_`name') nodenames(dagnodes') replace

	qui gen str32 _dagrole = ""
	if `usenodexy' {
		qui gen double _dagx = .
		qui gen double _dagy = .
	}
	forvalues i = 1/`nn' {
		mata: st_local("nm", dagnodes[`i'])
		mata: st_local("rl", dagrole[`i'])
		qui replace _dagrole = "`rl'" if _nwnode == "`nm'"
		if `usenodexy' {
			mata: st_local("xi", strofreal(dagx[`i']))
			mata: st_local("yi", strofreal(dagy[`i']))
			qui replace _dagx = `xi' if _nwnode == "`nm'"
			qui replace _dagy = `yi' if _nwnode == "`nm'"
		}
	}

	// note: no `clean' - some role names (e.g. "ancestor of both")
	// contain spaces, and `clean' strips the quoting that keeps a
	// multi-word value together as one token in `present'; without it,
	// `foreach ... of local present' would split such a role into
	// several bogus one-word iterations and silently drop its color.
	qui levelsof _dagrole, local(present)
	local palette ""
	foreach rv of local present {
		local key = subinstr(`"`rv'"', " ", "_", .)
		local palette `"`palette' `colormap_`key''"'
	}

	local layoutopt ""
	if `usenodexy' local layoutopt "nodexy(_dagx _dagy)"
	else local layoutopt "layout(`layout')"

	// dagy draw defaults to dagplot's interactive (cytoscape-based) viewer
	// rather than a plain static graph; nointeractive restores the old
	// static-only behavior, e.g. for unattended figure-export scripts
	// that shouldn't pop a browser/native-viewer window on every run.
	// Note: `interactive' is deliberately NOT declared as dagy's own
	// option above - Stata's `syntax` auto-recognizes a bare flag's
	// no-form (a flag named X silently also accepts noX), so declaring
	// both `interactive' and `nointeractive' here would make Stata's
	// built-in noX handling swallow "nointeractive" as the auto-negation
	// of `interactive' before it ever reaches our own NOInteractive local
	// (confirmed directly - it came back empty, not an error, and never
	// reached `options' either). Leaving `interactive' undeclared means
	// a caller typing it explicitly just falls through to `options'
	// instead - checked for below so it isn't also added a second time
	// via `cosmeticopts' (confirmed directly that dagplot, unlike a
	// plain flag option in isolation, rejects "interactive" given twice
	// in one call with "option interactive not allowed").
	local _dagy_hasinteractive = 0
	foreach _dagy_opt of local options {
		if "`_dagy_opt'" == "interactive" local _dagy_hasinteractive = 1
	}
	if `"`nointeractive'"' == "" & !`_dagy_hasinteractive' {
		local cosmeticopts `"`cosmeticopts' interactive"'
	}

	// note: not "dagplot dagy_`name'" - nwset silently renames on a name
	// clash (e.g. redrawing the same DAG twice in one session), so we
	// rely on the network it just created being the current network.
	// dagplot (software/dagplot/dagplot.ado), not nwcommands' own nwplot:
	// a standalone fork so its `interactive` rendering (and viewer
	// launcher/native binary) can be fixed/edited here without touching
	// nwcommands - see dagplot.ado's own header.
	dagplot, lab arrows color(_dagrole, colorpalette(`palette')) `layoutopt' `cosmeticopts' `options'

	if `haddata' {
		qui use `dagy_userdata', clear
	}
	else {
		qui clear
	}
end
