*! _dagy_simulate.ado 0.4.0 2026-08-27
*! internal - see help dagy
*! dagy simulate <name>, n(#) [beta(#) sd(#) coef(edgespec) seed(#)
*!     keeplatent clear]
*!
*! Draws data from a linear-Gaussian structural model implied by the
*! DAG: every node's value is a coefficient-weighted sum of its parents
*! plus N(0, sd) noise, generated in topological order so a parent
*! always exists before its children need it. Node names become the
*! actual Stata variable names.
program _dagy_simulate
	version 14
	syntax [anything] [, N(integer 0) BETA(real 1) SD(real 1) COEF(string) ///
		SEED(string) KEEPLATENT CLEAR]

	_dagy_resolve `anything'
	local name `r(name)'
	if `"`r(rest)'"' != "" {
		di as err "syntax: dagy simulate <name>, n(#) [beta(#) sd(#) coef(edgespec) seed(#) keeplatent clear]"
		exit 198
	}
	if `n' <= 0 {
		di as err "syntax: dagy simulate <name>, n(#) ... - n() is required and must be positive"
		exit 198
	}

	mata: dagy_m_readfr("dagy_`name'_n", "dagy_`name'_e", dagnodes=J(0,1,""), dagA=J(0,0,.), daglatent=J(0,1,.))
	mata: st_local("nn", strofreal(rows(dagnodes)))
	mata: dagorder = dagy_m_toporder(dagA)
	mata: dagcoef = dagA :* `beta'

	if `"`coef'"' != "" {
		local edgespec = subinstr(`"`coef'"', "->", " -> ", .)
		local remaining `"`edgespec'"'
		while `"`remaining'"' != "" {
			local spos = strpos(`"`remaining'"', ";")
			if `spos' > 0 {
				local seg = substr(`"`remaining'"', 1, `spos' - 1)
				local remaining = substr(`"`remaining'"', `spos' + 1, .)
			}
			else {
				local seg `"`remaining'"'
				local remaining ""
			}
			local seg = trim(itrim(`"`seg'"'))
			if `"`seg'"' == "" continue

			local ntok : word count `seg'
			if `ntok' != 4 {
				di as err "each coef() entry must be {bf:node1 -> node2 value}; got: `seg'"
				exit 198
			}
			local n1 : word 1 of `seg'
			local arrow : word 2 of `seg'
			local n2 : word 3 of `seg'
			local val : word 4 of `seg'
			if "`arrow'" != "->" {
				di as err "each coef() entry must be {bf:node1 -> node2 value}; got: `seg'"
				exit 198
			}
			cap mata: dagy_m_idx(dagnodes, "`n1'")
			if _rc {
				di as err "`n1' is not a node of DAG `name'"
				exit 198
			}
			cap mata: dagy_m_idx(dagnodes, "`n2'")
			if _rc {
				di as err "`n2' is not a node of DAG `name'"
				exit 198
			}
			cap confirm number `val'
			if _rc {
				di as err "the coef() value for `n1' -> `n2' must be a number; got: `val'"
				exit 198
			}
			mata: st_local("i1", strofreal(dagy_m_idx(dagnodes,"`n1'")))
			mata: st_local("i2", strofreal(dagy_m_idx(dagnodes,"`n2'")))
			mata: st_local("hasedge", strofreal(dagA[`i1',`i2']))
			if !`hasedge' {
				di as err "there is no edge `n1' -> `n2' in DAG `name'"
				exit 198
			}
			mata: dagcoef[`i1',`i2'] = `val'
		}
	}

	local haddata = (_N > 0 | c(k) > 0)
	if `haddata' & "`clear'" == "" {
		di as err "current data in memory would be replaced by the simulated dataset; use the {bf:clear} option"
		exit 4
	}

	if `"`seed'"' != "" {
		set seed `seed'
	}

	qui clear
	qui set obs `n'

	forvalues k = 1/`nn' {
		mata: st_local("ki", strofreal(dagorder[`k']))
		mata: st_local("nm", dagnodes[dagorder[`k']])
		mata: st_local("expr", dagy_m_simexpr(dagcoef, dagnodes, dagorder[`k']))
		if `"`expr'"' == "" {
			qui gen double `nm' = rnormal(0,`sd')
		}
		else {
			qui gen double `nm' = `expr' + rnormal(0,`sd')
		}
	}

	if "`keeplatent'" == "" {
		forvalues i = 1/`nn' {
			mata: st_local("nm", dagnodes[`i'])
			mata: st_local("islat", strofreal(daglatent[`i']))
			if `islat' {
				qui drop `nm'
			}
		}
	}

	local coefnote ""
	if `"`coef'"' != "" local coefnote " with coef() overrides"
	di as txt "DAG {res:`name'}: simulated `n' observations (linear-Gaussian SEM, beta=`beta' sd=`sd'`coefnote')."
end
