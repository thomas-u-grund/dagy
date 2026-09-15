*! _dagy_adjust.ado 0.5.0 2026-08-27
*! internal - see help dagy
*! dagy adjust [name] exposure outcome [, given(namelist) all max(#) optimal]
program _dagy_adjust
	version 14
	syntax [anything] [, given(string) all max(integer 18) optimal]

	_dagy_resolve `anything'
	local name `r(name)'
	local rest `r(rest)'

	local nw : word count `rest'
	if `nw' != 2 {
		di as err "syntax: dagy adjust [name] exposure outcome [, given(namelist) all max(#)]"
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
			di as err "`v' is marked latent (unobserved) in DAG `name' and cannot be adjusted for"
			exit 198
		}
	}

	mata: dagforced  = dagy_m_indicator(dagnodes, `"`given'"')
	mata: dagexclude = daglatent
	mata: st_local("nn", strofreal(rows(dagnodes)))
	mata: st_local("ncand_est", strofreal(sum(1 :- (dagy_m_desc(dagA, dagy_m_indicator(dagnodes,"`x'")) :| dagy_m_indicator(dagnodes,"`x'") :| dagy_m_indicator(dagnodes,"`y'") :| dagforced :| daglatent))))

	mata: dagy_m_adjust(dagA, dagnodes, "`x'", "`y'", dagforced, dagexclude, `max', dagsuff=J(0,1,""), dagmin=J(0,1,""), dagtoolarge=.)
	mata: st_local("toolarge", strofreal(dagtoolarge))

	if `toolarge' {
		di as err "DAG `name' has `ncand_est' candidate adjustment variables outside {`x' `y' `given''s descendants}; that is more than max(`max')."
		di as err "Increase {bf:max()} (2^k sets are enumerated) or fix some variables with {bf:given()}."
		exit 498
	}

	di as txt "{hline 60}"
	di as txt "Back-door adjustment sets for the effect of " as res "`x'" as txt " on " as res "`y'" as txt " in DAG " as res "`name'"
	if `"`given'"' != "" {
		di as txt "(always including: " as res "`given'" as txt ")"
	}
	di as txt "{hline 60}"

	mata: st_local("nmin", strofreal(rows(dagmin)))
	di as txt _n "Minimal sufficient adjustment sets:"
	if `nmin' == 0 {
		di as txt "    (none - the effect of `x' on `y' is not identified by back-door adjustment in this DAG)"
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
		di as txt _n "All sufficient adjustment sets (`nsuf'):"
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

	if "`optimal'" != "" {
		mata: dagy_m_optadjust(dagA, dagnodes, "`x'", "`y'", daglatent, dagoptset="", dagfeasible=.)
		mata: st_local("optset", dagoptset)
		mata: st_local("feasible", strofreal(dagfeasible))
		local optdisp `"`optset'"'
		if `"`optdisp'"' == "" local optdisp "(empty set)"
		di as txt _n "Optimal adjustment set (minimizes asymptotic estimator variance among valid sets):"
		if `feasible' {
			di as txt "    {" as res "`optdisp'" as txt "}"
		}
		else {
			di as txt "    {" as res "`optdisp'" as txt "}  " as err "(not usable - contains a latent node)"
		}
	}
	di as txt "{hline 60}"
end
