*! _dagy_list.ado 0.1.0 2026-08-26
*! internal - see help dagy
program _dagy_list
	version 14
	args name

	cap confirm frame dagy__reg
	if _rc {
		di as txt "(no DAGs defined yet - see {bf:help dagy})"
		exit
	}

	if `"`name'"' == "" {
		local names ""
		frame dagy__reg {
			qui count
			local N = r(N)
			forvalues i = 1/`N' {
				local nm = name[`i']
				local names `"`names' `nm'"'
			}
		}
		if `"`names'"' == "" {
			di as txt "(no DAGs defined yet - see {bf:help dagy})"
			exit
		}
		di as txt "{hline 40}"
		di as txt "Defined DAGs (" as res "`: word count `names''" as txt "):"
		foreach nm of local names {
			local star = ("`nm'" == "$DAGY_CURRENT") * 1
			if `star' di as res "  * `nm'" as txt "   (current)"
			else di as txt "    `nm'"
		}
		di as txt "{hline 40}"
		exit
	}

	cap confirm frame dagy_`name'_n
	if _rc {
		di as err "DAG {bf:`name'} not found."
		exit 111
	}

	mata: dagy_m_readfr("dagy_`name'_n", "dagy_`name'_e", dagnodes=J(0,1,""), dagA=J(0,0,.), daglatent=J(0,1,.))
	mata: st_local("nn", strofreal(rows(dagnodes)))
	mata: st_local("ne", strofreal(sum(dagA)))

	di as txt "{hline 50}"
	di as txt "DAG: " as res "`name'" _col(40) as txt "nodes: " as res "`nn'" as txt "  edges: " as res "`ne'"
	di as txt "{hline 50}"
	frame dagy_`name'_e {
		qui count
		forvalues i = 1/`r(N)' {
			local a = n1[`i']
			local b = n2[`i']
			di as txt "    `a' -> `b'"
		}
	}
	frame dagy_`name'_n {
		qui count if latent
		if r(N) {
			local lats ""
			qui levelsof node if latent, local(lats_q) clean
			di as txt "  latent (unobserved): " as res "`lats_q'"
		}
	}
end
