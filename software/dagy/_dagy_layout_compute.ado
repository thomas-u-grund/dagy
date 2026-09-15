*! _dagy_layout_compute.ado 0.3.0 2026-08-27
*! internal - see help dagy
*! Computes the automatic layered (Sugiyama-style) layout for a DAG and
*! (re)stores it as dagy_<name>_xy (node/x/y/fixed, all fixed=0). Called
*! both by `dagy layout`'s bare (recompute) form and by `dagy draw` to
*! lazily populate a layout the first time a DAG is drawn. A separate
*! file (rather than a helper program inside _dagy_layout.ado) so Stata's
*! ado autoloader can find it regardless of which subcommand runs first
*! - the same reason _dagy_resolve.ado is its own file. The optional
*! third argument names a node to center at the rightmost rank (used by
*! `dagy draw` to pass its own outcome() through); a lone terminal
*! outcome is otherwise just placed wherever its longest path happens to
*! land, which need not be the last rank or the centerline.
program _dagy_layout_compute
	version 14
	args name orient outcome

	if `"`orient'"' == "" local orient "horizontal"

	mata: dagy_m_readfr("dagy_`name'_n", "dagy_`name'_e", dagnodes=J(0,1,""), dagA=J(0,0,.), daglatent=J(0,1,.))
	mata: dagy_m_layout(dagA, dagnodes, "`orient'", "`outcome'", dagx=J(0,1,.), dagy=J(0,1,.))
	mata: st_local("nn", strofreal(rows(dagnodes)))

	cap frame drop dagy_`name'_xy
	frame create dagy_`name'_xy
	frame dagy_`name'_xy {
		qui set obs `nn'
		qui gen str100 node = ""
		qui gen double x = .
		qui gen double y = .
		qui gen byte fixed = 0
		forvalues i = 1/`nn' {
			mata: st_local("nm", dagnodes[`i'])
			mata: st_local("xx", strofreal(dagx[`i']))
			mata: st_local("yy", strofreal(dagy[`i']))
			qui replace node = "`nm'" in `i'
			qui replace x = `xx' in `i'
			qui replace y = `yy' in `i'
		}
	}
end
