*! _dagy_dsep.ado 0.1.0 2026-08-26
*! internal - see help dagy
*! dagy dsep [name] x y [, given(namelist)]
program _dagy_dsep
	version 14
	syntax [anything] [, given(string)]

	_dagy_resolve `anything'
	local name `r(name)'
	local rest `r(rest)'

	local nw : word count `rest'
	if `nw' != 2 {
		di as err "syntax: dagy dsep [name] x y [, given(namelist)]"
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
	}
	if `: list x in given' | `: list y in given' {
		di as err "the conditioning set cannot contain `x' or `y'"
		exit 198
	}

	mata: st_local("nn", strofreal(rows(dagnodes)))
	mata: dagX = dagy_m_indicator(dagnodes, "`x'")
	mata: dagY = dagy_m_indicator(dagnodes, "`y'")
	mata: dagZ = dagy_m_indicator(dagnodes, `"`given'"')
	mata: st_local("dsep", strofreal(dagy_m_dsep(dagA, dagX, dagY, dagZ)))

	local cond ""
	if `"`given'"' != "" local cond " given {`given'}"

	di as txt "{hline 60}"
	if `dsep' {
		di as txt "`x' and `y' are " as res "d-separated" as txt "`cond' in DAG `name'."
		di as txt "  -> the model implies `x' {&perp}{&perp} `y'`cond'."
	}
	else {
		di as txt "`x' and `y' are " as res "NOT d-separated" as txt "`cond' in DAG `name'."
		di as txt "  -> the model implies `x' and `y' may be associated`cond'."
	}
	di as txt "{hline 60}"
end
