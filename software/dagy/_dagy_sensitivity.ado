*! _dagy_sensitivity.ado 0.4.0 2026-08-27
*! internal - see help dagy
*! dagy sensitivity <name> exposure outcome [, given(namelist)]
*!
*! Graphical robustness check (not the quantitative bias-formula
*! sensitivity analysis of, e.g., Cinelli & Hazlett 2020): for a back-door
*! adjustment set, tests whether a single hypothetical unmeasured
*! confounder linking exposure or outcome to one of the adjustment
*! variables - or exposure directly to outcome - would break the
*! adjustment set's sufficiency.
program _dagy_sensitivity
	version 14
	syntax [anything] [, GIVEN(string)]

	_dagy_resolve `anything'
	local name `r(name)'
	local rest `r(rest)'
	local nw : word count `rest'
	if `nw' != 2 {
		di as err "syntax: dagy sensitivity [name] exposure outcome [, given(namelist)]"
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

	local zset `"`given'"'
	if `"`zset'"' == "" {
		mata: dagexclude0 = daglatent
		mata: dagforced0 = J(rows(dagnodes),1,0)
		mata: dagy_m_adjust(dagA, dagnodes, "`x'", "`y'", dagforced0, dagexclude0, 18, dagsuff0=J(0,1,""), dagmin0=J(0,1,""), dagtoolarge0=.)
		mata: st_local("nmin", strofreal(rows(dagmin0)))
		if `nmin' == 0 {
			di as err "no back-door adjustment set exists for `x' -> `y' in DAG `name'; sensitivity of a nonexistent adjustment isn't meaningful - see {bf:dagy adjust}"
			exit 498
		}
		mata: st_local("zset", dagmin0[1])
	}
	else {
		foreach v of local zset {
			cap mata: dagy_m_idx(dagnodes, "`v'")
			if _rc {
				di as err "`v' is not a node of DAG `name'"
				exit 198
			}
		}
	}

	mata: dagX = dagy_m_indicator(dagnodes, "`x'")
	mata: dagY = dagy_m_indicator(dagnodes, "`y'")
	mata: dagZ = dagy_m_indicator(dagnodes, `"`zset'"')
	mata: st_local("xi", strofreal(dagy_m_idx(dagnodes,"`x'")))
	mata: st_local("yi", strofreal(dagy_m_idx(dagnodes,"`y'")))

	local zdisp `"`zset'"'
	if `"`zdisp'"' == "" local zdisp "(empty set)"

	di as txt "{hline 60}"
	di as txt "Sensitivity of the back-door adjustment set {" as res "`zdisp'" as txt "} for the effect of " as res "`x'" as txt " on " as res "`y'" as txt " in DAG " as res "`name'"
	di as txt "{hline 60}"
	di as txt "Checking robustness to a single hypothetical unmeasured confounder between:"

	foreach v of local zset {
		mata: st_local("vi", strofreal(dagy_m_idx(dagnodes,"`v'")))
		mata: st_local("robust", strofreal(dagy_m_sensitivity_check(dagA, dagX, dagY, dagZ, `xi', `vi')))
		if `robust' {
			di as txt "    `x' and `v': " as res "identification remains valid"
		}
		else {
			di as txt "    `x' and `v': " as res "identification would FAIL"
		}
	}
	foreach v of local zset {
		mata: st_local("vi", strofreal(dagy_m_idx(dagnodes,"`v'")))
		mata: st_local("robust", strofreal(dagy_m_sensitivity_check(dagA, dagX, dagY, dagZ, `yi', `vi')))
		if `robust' {
			di as txt "    `y' and `v': " as res "identification remains valid"
		}
		else {
			di as txt "    `y' and `v': " as res "identification would FAIL"
		}
	}
	mata: st_local("robust", strofreal(dagy_m_sensitivity_check(dagA, dagX, dagY, dagZ, `xi', `yi')))
	if `robust' {
		di as txt "    `x' and `y' (direct): " as res "identification remains valid"
	}
	else {
		di as txt "    `x' and `y' (direct): " as res "identification would FAIL"
	}

	di as txt "{hline 60}"
end
