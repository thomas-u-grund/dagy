*! _dagy_localtests.ado 0.5.0 2026-08-27
*! internal - see help dagy
*! dagy localtests [name] [, test max(#)]
*!
*! Comprehensive pairwise testable implications: for every pair of
*! non-adjacent nodes, one separating set (not necessarily minimal) -
*! more implications than `dagy testable`'s cheaper local-Markov
*! generating set, at the cost of a bounded 2^k search per pair.
program _dagy_localtests
	version 14
	syntax [anything] [, test max(integer 18)]

	_dagy_resolve `anything'
	local name `r(name)'
	if `"`r(rest)'"' != "" {
		di as err "syntax: dagy localtests [name] [, test max(#)]"
		exit 198
	}

	mata: dagy_m_readfr("dagy_`name'_n", "dagy_`name'_e", dagnodes=J(0,1,""), dagA=J(0,0,.), daglatent=J(0,1,.))
	mata: dagy_m_localtests(dagA, dagnodes, daglatent, `max', dagstmts=J(0,1,""), dagA_=J(0,1,""), dagB_=J(0,1,""), dagsep=J(0,1,""), dagtestable=J(0,1,.), dagtoolarge=.)
	mata: st_local("npair", strofreal(rows(dagstmts)))
	mata: st_local("toolarge", strofreal(dagtoolarge))

	di as txt "{hline 60}"
	di as txt "Comprehensive pairwise testable implications of DAG " as res "`name'"
	di as txt "{hline 60}"

	if `npair' == 0 {
		di as txt "(none - every pair of nodes is adjacent, or every non-adjacent pair" as txt _n "has more than max(`max') other nodes to search over)"
		di as txt "{hline 60}"
		exit
	}

	forvalues i = 1/`npair' {
		mata: st_local("s", dagstmts[`i'])
		mata: st_local("testable", strofreal(dagtestable[`i']))

		if !`testable' {
			di as txt "    " as res "`s'" as txt "  (not testable with observed data - involves a latent node)"
			continue
		}

		if "`test'" == "" {
			di as txt "    " as res "`s'"
			continue
		}

		mata: st_local("a", dagA_[`i'])
		mata: st_local("b", dagB_[`i'])
		mata: st_local("sep", dagsep[`i'])
		local allvars `"`a' `b' `sep'"'
		local havedata = 1
		foreach vv of local allvars {
			cap confirm variable `vv'
			if _rc local havedata = 0
		}
		if !`havedata' {
			di as txt "    " as res "`s'" as txt "  (no matching data loaded)"
			continue
		}
		qui regress `a' `b' `sep'
		qui test `b'
		local p = r(p)
		di as txt "    " as res "`s'" as txt "  (p = " as res %6.4f `p' as txt ")"
	}

	if `toolarge' {
		di as txt _n "{err}Note:{txt} some non-adjacent pairs had more than max(`max') other" as txt _n "nodes to search over and were skipped; raise {bf:max()} to include them."
	}
	di as txt "{hline 60}"
end
