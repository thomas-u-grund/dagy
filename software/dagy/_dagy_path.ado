*! _dagy_path.ado 0.1.0 2026-08-26
*! internal - see help dagy
*! dagy path [name] exposure outcome [, max(#)]
program _dagy_path
	version 14
	syntax [anything] [, max(integer 200)]

	_dagy_resolve `anything'
	local name `r(name)'
	local rest `r(rest)'

	local nw : word count `rest'
	if `nw' != 2 {
		di as err "syntax: dagy path [name] exposure outcome [, max(#)]"
		exit 198
	}
	local x : word 1 of `rest'
	local y : word 2 of `rest'

	mata: dagy_m_readfr("dagy_`name'_n", "dagy_`name'_e", dagnodes=J(0,1,""), dagA=J(0,0,.), daglatent=J(0,1,.))
	cap mata: dagy_m_idx(dagnodes, "`x'")
	if _rc {
		di as err "`x' is not a node of DAG `name'"
		exit 198
	}
	cap mata: dagy_m_idx(dagnodes, "`y'")
	if _rc {
		di as err "`y' is not a node of DAG `name'"
		exit 198
	}

	mata: dagy_m_paths(dagA, dagnodes, "`x'", "`y'", `max', dagpaths=J(0,1,""), dagkinds=J(0,1,.), dagtrunc=.)
	mata: st_local("npaths", strofreal(rows(dagpaths)))
	mata: st_local("trunc", strofreal(dagtrunc))

	di as txt "{hline 60}"
	di as txt "Paths between " as res "`x'" as txt " and " as res "`y'" as txt " in DAG " as res "`name'"
	di as txt "{hline 60}"

	if `npaths' == 0 {
		di as txt "(no paths found)"
		exit
	}

	di as txt _n "Causal paths:"
	local any 0
	forvalues i = 1/`npaths' {
		mata: st_local("kind", strofreal(dagkinds[`i']))
		mata: st_local("pstr", dagpaths[`i'])
		if `kind' == 1 {
			di as txt "    " as res "`pstr'"
			local any 1
		}
	}
	if !`any' di as txt "    (none)"

	di as txt _n "Backdoor paths (start with an arrow into `x'):"
	local any 0
	forvalues i = 1/`npaths' {
		mata: st_local("kind", strofreal(dagkinds[`i']))
		mata: st_local("pstr", dagpaths[`i'])
		if `kind' == 2 {
			di as txt "    " as res "`pstr'"
			local any 1
		}
	}
	if !`any' di as txt "    (none)"

	di as txt _n "Other non-causal paths (through a collider on `x''s side):"
	local any 0
	forvalues i = 1/`npaths' {
		mata: st_local("kind", strofreal(dagkinds[`i']))
		mata: st_local("pstr", dagpaths[`i'])
		if `kind' == 3 {
			di as txt "    " as res "`pstr'"
			local any 1
		}
	}
	if !`any' di as txt "    (none)"

	if `trunc' {
		di as txt _n "{err}Warning:{txt} stopped after `max' paths; there may be more. Use the {bf:max()} option to see them."
	}
end
