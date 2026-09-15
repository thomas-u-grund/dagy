*! _dagy_mag.ado 0.5.0 2026-08-27
*! internal - see help dagy
*! dagy mag [name] [, max(#)]
*!
*! Latent projection: collapses a DAG with latent nodes down to a MAG
*! over the observed nodes only, showing residual unmeasured confounding
*! as bidirected edges. No selection-variable / undirected-edge support.
program _dagy_mag
	version 14
	syntax [anything] [, max(integer 18)]

	_dagy_resolve `anything'
	local name `r(name)'
	if `"`r(rest)'"' != "" {
		di as err "syntax: dagy mag [name] [, max(#)]"
		exit 198
	}

	mata: dagy_m_readfr("dagy_`name'_n", "dagy_`name'_e", dagnodes=J(0,1,""), dagA=J(0,0,.), daglatent=J(0,1,.))
	mata: st_local("nlat", strofreal(sum(daglatent)))
	if `nlat' == 0 {
		di as txt "DAG {res:`name'} has no latent nodes; its MAG is itself (every edge keeps its DAG direction)."
	}

	mata: dagy_m_mag(dagA, dagnodes, daglatent, `max', dagedges=J(0,1,""), dagtoolarge=.)
	mata: st_local("nedge", strofreal(rows(dagedges)))
	mata: st_local("toolarge", strofreal(dagtoolarge))

	di as txt "{hline 60}"
	di as txt "MAG (latent projection onto observed nodes) of DAG " as res "`name'"
	di as txt "{hline 60}"

	if `nedge' == 0 {
		di as txt "(no edges among the observed nodes)"
	}
	else {
		forvalues i = 1/`nedge' {
			mata: st_local("s", dagedges[`i'])
			di as txt "    " as res "`s'"
		}
	}
	if `toolarge' {
		di as txt _n "{err}Note:{txt} some pairs had more than max(`max') other observed" as txt _n "nodes to search over and were skipped; raise {bf:max()} to include them."
	}
	di as txt "{hline 60}"
end
