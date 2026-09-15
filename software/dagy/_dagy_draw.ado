*! _dagy_draw.ado 1.0.0 2026-09-15
*! internal - see help dagy
*! dagy draw [name] [, exposure(name) outcome(name) adjust(namelist)
*!     nodesize(#) dagplot_options]
*!
*! dagy's own job is (a) working out each node's causal role (exposure/
*! outcome/adjusted/mediator/confounder/.../unobserved) and turning that
*! into a color() for dagplot, and (b) a layered layout (see
*! _dagy_layout_compute.ado / `dagy layout`), passed through as nodexy().
*! Always opens dagplot's interactive (cytoscape-based) viewer - there is
*! no static-plot fallback; see dagplot.ado (software/dagplot/) for why.
*! dagplot is dagy's own minimal plotting engine, with no dependency on
*! nwcommands or on any other package.
program _dagy_draw
	version 14
	syntax [anything] [, EXPOSURE(string) OUTCOME(string) ADJUST(string) ///
		NODEFACTOR(string) NODESIZE(string) *]

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

	// nodesize() is a cosmetic alias for dagplot's own nodefactor() -
	// dagplot's own default (1) is sized for a general caller's own
	// layout; dagy's layered layout leaves nodes looking small and
	// cramped at that setting, so dagy draw defaults to a bigger size
	// instead unless the caller asks for a specific one.
	if `"`nodesize'"' != "" {
		if `"`nodefactor'"' != "" {
			di as err "specify only one of {bf:nodefactor()} or {bf:nodesize()}"
			exit 198
		}
		local nodefactor `"`nodesize'"'
	}
	if `"`nodefactor'"' == "" local nodefactor "1.6"

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

	// A layout is computed the first time a DAG is drawn and then reused
	// (stable across repeated `dagy draw` calls); `dagy layout` lets the
	// user recompute it or pin individual nodes afterward.
	cap confirm frame dagy_`name'_xy
	if _rc {
		_dagy_layout_compute `name' horizontal `outcome'
	}
	mata: dagy_m_readxy("dagy_`name'_xy", dagxynodes=J(0,1,""), dagx=J(0,1,.), dagy=J(0,1,.))
	// dagxynodes/dagx/dagy are stored in dagnodes' own order (both come
	// from the same layout computation over dagnodes/dagA) - a plain
	// count check catches a stale layout frame left over from a DAG
	// that has since gained/lost nodes (dagy layout doesn't otherwise
	// invalidate its own frame when the DAG definition changes).
	mata: st_local("nnxy", strofreal(rows(dagxynodes)))
	if `nnxy' != `nn' {
		di as err "DAG `name' has `nn' node(s) but its stored layout has `nnxy' - recompute it with {bf:dagy layout `name', replace}."
		exit 498
	}

	local haddata = (_N > 0 | c(k) > 0)
	if `haddata' {
		tempfile dagy_userdata
		qui save `dagy_userdata', replace
	}

	qui clear
	qui set obs `nn'
	qui gen str244 _dagnode = ""
	qui gen str32 _dagrole = ""
	qui gen double _dagx = .
	qui gen double _dagy = .
	mata: st_sstore((1::`nn'), "_dagnode", dagnodes)
	mata: st_sstore((1::`nn'), "_dagrole", dagrole)
	mata: st_store((1::`nn'), "_dagx", dagx)
	mata: st_store((1::`nn'), "_dagy", dagy)
	mata: st_matrix("_dagAplot", dagA)

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

	dagplot, adjmatrix(_dagAplot) nodename(_dagnode) nodexy(_dagx _dagy) ///
		lab arrows color(_dagrole) colorpalette(`palette') nodefactor(`nodefactor') `options'

	capture matrix drop _dagAplot

	if `haddata' {
		qui use `dagy_userdata', clear
	}
	else {
		qui clear
	}
end
