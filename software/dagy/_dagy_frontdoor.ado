*! _dagy_frontdoor.ado 0.2.0 2026-08-27
*! internal - see help dagy
*! dagy frontdoor [name] exposure outcome [, given(namelist) all max(#)]
program _dagy_frontdoor
	version 14
	syntax [anything] [, given(string) all max(integer 18)]

	_dagy_resolve `anything'
	local name `r(name)'
	local rest `r(rest)'

	local nw : word count `rest'
	if `nw' != 2 {
		di as err "syntax: dagy frontdoor [name] exposure outcome [, given(namelist) all max(#)]"
		exit 198
	}
	local x : word 1 of `rest'
	local y : word 2 of `rest'

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
		mata: st_local("islat", strofreal(daglatent[dagy_m_idx(dagnodes,"`v'")]))
		if `islat' {
			di as err "`v' is marked latent (unobserved) in DAG `name' and cannot be part of a front-door set"
			exit 198
		}
	}

	mata: dagforced  = dagy_m_indicator(dagnodes, `"`given'"')
	mata: dagexclude = daglatent
	mata: st_local("nn", strofreal(rows(dagnodes)))
	mata: st_local("ncand_est", strofreal(sum((dagy_m_desc(dagA, dagy_m_indicator(dagnodes,"`x'")) :& dagy_m_anc(dagA, dagy_m_indicator(dagnodes,"`y'"))) :* (1 :- (dagy_m_indicator(dagnodes,"`x'") :| dagy_m_indicator(dagnodes,"`y'") :| dagforced :| daglatent)))))

	mata: dagy_m_frontdoor(dagA, dagnodes, "`x'", "`y'", dagforced, dagexclude, `max', dagsuff=J(0,1,""), dagmin=J(0,1,""), dagtoolarge=.)
	mata: st_local("toolarge", strofreal(dagtoolarge))

	if `toolarge' {
		di as err "DAG `name' has `ncand_est' candidate mediator variables on paths from `x' to `y'; that is more than max(`max')."
		di as err "Increase {bf:max()} (2^k sets are enumerated) or fix some variables with {bf:given()}."
		exit 498
	}

	di as txt "{hline 60}"
	di as txt "Front-door adjustment sets for the effect of " as res "`x'" as txt " on " as res "`y'" as txt " in DAG " as res "`name'"
	if `"`given'"' != "" {
		di as txt "(always including: " as res "`given'" as txt ")"
	}
	di as txt "{hline 60}"

	mata: st_local("nmin", strofreal(rows(dagmin)))
	di as txt _n "Minimal sufficient front-door sets:"
	if `nmin' == 0 {
		di as txt "    (none - no set of observed mediators intercepts every causal path from `x' to `y' while satisfying the front-door criterion; e.g. a direct edge `x' -> `y' always causes this)"
	}
	else {
		forvalues i = 1/`nmin' {
			mata: st_local("s", dagmin[`i'])
			local full = trim(`"`given' `s'"')
			if `"`full'"' == "" local full "(empty set)"
			di as txt "    {" as res "`full'" as txt "}"
		}
	}

	if "`all'" != "" {
		mata: st_local("nsuf", strofreal(rows(dagsuff)))
		di as txt _n "All sufficient front-door sets (`nsuf'):"
		if `nsuf' == 0 {
			di as txt "    (none)"
		}
		else {
			forvalues i = 1/`nsuf' {
				mata: st_local("s", dagsuff[`i'])
				local full = trim(`"`given' `s'"')
				if `"`full'"' == "" local full "(empty set)"
				di as txt "    {" as res "`full'" as txt "}"
			}
		}
	}
	di as txt "{hline 60}"
end
