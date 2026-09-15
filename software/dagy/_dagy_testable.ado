*! _dagy_testable.ado 0.4.0 2026-08-27
*! internal - see help dagy
*! dagy testable [name] [, observed test]
program _dagy_testable
	version 14
	syntax [anything] [, observed test]

	_dagy_resolve `anything'
	local name `r(name)'
	local rest `r(rest)'

	if `"`rest'"' != "" {
		di as err "syntax: dagy testable [name] [, observed test]"
		exit 198
	}

	mata: dagy_m_readfr("dagy_`name'_n", "dagy_`name'_e", dagnodes=J(0,1,""), dagA=J(0,0,.), daglatent=J(0,1,.))
	mata: dagy_m_testable(dagA, dagnodes, daglatent, dagstmts=J(0,1,""), dagtestable=J(0,1,.), dagvarnode=J(0,1,""), dagvanish=J(0,1,""), dagparent=J(0,1,""))
	mata: st_local("nstmt", strofreal(rows(dagstmts)))

	di as txt "{hline 60}"
	di as txt "Testable implications of DAG " as res "`name'" as txt " (local Markov property)"
	di as txt "{hline 60}"

	if `nstmt' == 0 {
		di as txt "(none - the DAG implies no conditional-independence restrictions)"
		exit
	}

	local any 0
	forvalues i = 1/`nstmt' {
		mata: st_local("s", dagstmts[`i'])
		mata: st_local("testable", strofreal(dagtestable[`i']))

		if !`testable' {
			if "`observed'" == "" {
				di as txt "    " as res "`s'" as txt "  (not testable with observed data - involves a latent node)"
				local any 1
			}
			continue
		}
		local any 1

		if "`test'" == "" {
			di as txt "    " as res "`s'"
			continue
		}

		mata: st_local("v", dagvarnode[`i'])
		mata: st_local("vanish", dagvanish[`i'])
		mata: st_local("pa", dagparent[`i'])
		local allvars `"`v' `pa' `vanish'"'
		local havedata = 1
		foreach vv of local allvars {
			cap confirm variable `vv'
			if _rc {
				local havedata = 0
			}
		}
		if !`havedata' {
			di as txt "    " as res "`s'" as txt "  (no matching data loaded)"
			continue
		}
		qui regress `v' `pa' `vanish'
		qui testparm `vanish'
		local p = r(p)
		di as txt "    " as res "`s'" as txt "  (p = " as res %6.4f `p' as txt ")"
	}
	if !`any' {
		di as txt "    (none - every implication involves a latent node; use {bf:dagy testable `name'} without {bf:observed} to see them)"
	}
	di as txt "{hline 60}"
end
