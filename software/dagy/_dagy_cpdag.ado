*! _dagy_cpdag.ado 0.5.0 2026-08-27
*! internal - see help dagy
*! dagy cpdag [name] [, given(edgespec)]
program _dagy_cpdag
	version 14
	syntax [anything] [, given(string)]

	_dagy_resolve `anything'
	local name `r(name)'
	if `"`r(rest)'"' != "" {
		di as err "syntax: dagy cpdag [name] [, given(edgespec)]"
		exit 198
	}

	mata: dagy_m_readfr("dagy_`name'_n", "dagy_`name'_e", dagnodes=J(0,1,""), dagA=J(0,0,.), daglatent=J(0,1,.))
	mata: st_local("nn", strofreal(rows(dagnodes)))

	mata: dagbackground = J(`nn',`nn',0)

	if `"`given'"' != "" {
		local edgespec = subinstr(`"`given'"', "->", " -> ", .)
		local remaining `"`edgespec'"'
		while `"`remaining'"' != "" {
			local spos = strpos(`"`remaining'"', ";")
			if `spos' > 0 {
				local seg = substr(`"`remaining'"', 1, `spos' - 1)
				local remaining = substr(`"`remaining'"', `spos' + 1, .)
			}
			else {
				local seg `"`remaining'"'
				local remaining ""
			}
			local seg = trim(itrim(`"`seg'"'))
			if `"`seg'"' == "" continue

			local ntok : word count `seg'
			if `ntok' != 3 {
				di as err "each given() entry must be {bf:node1 -> node2}; got: `seg'"
				exit 198
			}
			local n1 : word 1 of `seg'
			local arrow : word 2 of `seg'
			local n2 : word 3 of `seg'
			if "`arrow'" != "->" {
				di as err "each given() entry must be {bf:node1 -> node2}; got: `seg'"
				exit 198
			}
			cap mata: dagy_m_idx(dagnodes, "`n1'")
			if _rc {
				di as err "`n1' is not a node of DAG `name'"
				exit 198
			}
			cap mata: dagy_m_idx(dagnodes, "`n2'")
			if _rc {
				di as err "`n2' is not a node of DAG `name'"
				exit 198
			}
			mata: st_local("i1", strofreal(dagy_m_idx(dagnodes,"`n1'")))
			mata: st_local("i2", strofreal(dagy_m_idx(dagnodes,"`n2'")))
			mata: st_local("fwd", strofreal(dagA[`i1',`i2']))
			mata: st_local("bwd", strofreal(dagA[`i2',`i1']))
			if !`fwd' & !`bwd' {
				di as err "`n1' and `n2' are not adjacent in DAG `name'"
				exit 198
			}
			if !`fwd' & `bwd' {
				di as err "given() asserts `n1' -> `n2', but DAG `name' actually has `n2' -> `n1'"
				exit 198
			}
			mata: dagbackground[`i1',`i2'] = 1
		}
	}

	mata: dagy_m_cpdag(dagA, dagnodes, dagbackground, dagdir=J(0,1,""), dagund=J(0,1,""))
	mata: st_local("ndir", strofreal(rows(dagdir)))
	mata: st_local("nund", strofreal(rows(dagund)))

	di as txt "{hline 60}"
	di as txt "CPDAG (Markov equivalence class) of DAG " as res "`name'"
	if `"`given'"' != "" {
		di as txt "(with background knowledge: " as res "`given'" as txt ")"
	}
	di as txt "{hline 60}"

	local bknote ""
	if `"`given'"' != "" local bknote " and background knowledge"
	di as txt _n "Directed edges (orientation determined by the independence structure`bknote'):"
	if `ndir' == 0 {
		di as txt "    (none)"
	}
	else {
		forvalues i = 1/`ndir' {
			mata: st_local("s", dagdir[`i'])
			di as txt "    " as res "`s'"
		}
	}

	di as txt _n "Undirected edges (either orientation is consistent with the same"
	di as txt "conditional-independence pattern):"
	if `nund' == 0 {
		di as txt "    (none)"
	}
	else {
		forvalues i = 1/`nund' {
			mata: st_local("s", dagund[`i'])
			di as txt "    " as res "`s'"
		}
	}
	di as txt "{hline 60}"
end
