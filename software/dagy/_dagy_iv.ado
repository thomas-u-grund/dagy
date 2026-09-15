*! _dagy_iv.ado 0.2.0 2026-08-27
*! internal - see help dagy
*! dagy iv [name] exposure outcome [candidate] [, given(namelist)]
program _dagy_iv
	version 14
	syntax [anything] [, given(string)]

	_dagy_resolve `anything'
	local name `r(name)'
	local rest `r(rest)'

	local nw : word count `rest'
	if `nw' != 2 & `nw' != 3 {
		di as err "syntax: dagy iv [name] exposure outcome [candidate] [, given(namelist)]"
		exit 198
	}
	local x : word 1 of `rest'
	local y : word 2 of `rest'
	local z : word 3 of `rest'

	mata: dagy_m_readfr("dagy_`name'_n", "dagy_`name'_e", dagnodes=J(0,1,""), dagA=J(0,0,.), daglatent=J(0,1,.))

	foreach v in x y {
		cap mata: dagy_m_idx(dagnodes, "``v''")
		if _rc {
			di as err "``v'' is not a node of DAG `name'"
			exit 198
		}
	}
	foreach v of local given {
		cap mata: dagy_m_idx(dagnodes, "`v'")
		if _rc {
			di as err "`v' is not a node of DAG `name'"
			exit 198
		}
	}

	mata: dagX = dagy_m_indicator(dagnodes, "`x'")
	mata: dagY = dagy_m_indicator(dagnodes, "`y'")
	mata: dagGiven = dagy_m_indicator(dagnodes, `"`given'"')

	if `"`z'"' != "" {
		cap mata: dagy_m_idx(dagnodes, "`z'")
		if _rc {
			di as err "`z' is not a node of DAG `name'"
			exit 198
		}
		mata: st_local("islat", strofreal(daglatent[dagy_m_idx(dagnodes,"`z'")]))
		if `islat' {
			di as err "`z' is marked latent (unobserved) in DAG `name' and cannot be an instrument"
			exit 198
		}
		mata: st_local("isdescx", strofreal(dagy_m_desc(dagA, dagX)[dagy_m_idx(dagnodes,"`z'")]))
		if `isdescx' {
			di as err "`z' is a descendant of `x' in DAG `name' and cannot be an instrument (it is caused by the exposure)"
			exit 198
		}

		mata: dagZc = dagy_m_indicator(dagnodes, "`z'")
		mata: dagres = dagy_m_ivcheck(dagA, dagX, dagY, dagZc, dagGiven)
		mata: st_local("relevant", strofreal(dagres[1]))
		mata: st_local("exclrestr", strofreal(dagres[2]))

		local cond ""
		if `"`given'"' != "" local cond " given {`given'}"

		di as txt "{hline 60}"
		di as txt "Instrumental-variable check: " as res "`z'" as txt " for the effect of " as res "`x'" as txt " on " as res "`y'" as txt "`cond' in DAG " as res "`name'"
		di as txt "{hline 60}"
		if `relevant' {
			di as txt "`z' and `x' are " as res "NOT d-separated" as txt "`cond' - relevance holds."
		}
		else {
			di as txt "`z' and `x' are " as res "d-separated" as txt "`cond' - relevance FAILS (`z' carries no information about `x')."
		}
		if `exclrestr' {
			di as txt "`z' and `y' are " as res "d-separated" as txt "`cond' once `x''s own outgoing edges are removed - exclusion restriction holds."
		}
		else {
			di as txt "`z' and `y' are " as res "NOT d-separated" as txt "`cond' once `x''s own outgoing edges are removed - exclusion restriction FAILS (`z' may affect `y' by a route other than through `x')."
		}
		di as txt "{hline 60}"
		if `relevant' & `exclrestr' {
			di as txt "`z' " as res "IS" as txt " a valid instrument for `x' -> `y'`cond'."
		}
		else {
			di as txt "`z' is " as res "NOT" as txt " a valid instrument for `x' -> `y'`cond'."
		}
		di as txt "{hline 60}"
		exit
	}

	mata: dagexclude = daglatent
	mata: dagy_m_ivsearch(dagA, dagnodes, "`x'", "`y'", dagexclude, dagGiven, dagcand=J(0,1,""), dagrel=J(0,1,.), dagexcl=J(0,1,.))
	mata: st_local("ncand", strofreal(rows(dagcand)))

	local cond ""
	if `"`given'"' != "" local cond " given {`given'}"

	di as txt "{hline 60}"
	di as txt "Instrumental-variable candidates for the effect of " as res "`x'" as txt " on " as res "`y'" as txt "`cond' in DAG " as res "`name'"
	di as txt "{hline 60}"

	local any 0
	forvalues i = 1/`ncand' {
		mata: st_local("cn", dagcand[`i'])
		mata: st_local("rel", strofreal(dagrel[`i']))
		mata: st_local("excl", strofreal(dagexcl[`i']))
		if `rel' & `excl' {
			di as txt "    " as res "`cn'" as txt "  (relevant, satisfies exclusion restriction)"
			local any 1
		}
	}
	if !`any' {
		di as txt "    (none found among observed non-descendants of `x'; use {bf:dagy iv `name' `x' `y' candidate}`cond' to see why a specific candidate fails)"
	}
	di as txt "{hline 60}"
end
