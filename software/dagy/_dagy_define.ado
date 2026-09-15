*! _dagy_define.ado 0.1.0 2026-08-26
*! internal - see help dagy
*!
*! dagy define <name>: node -> node [-> node ...] [ ; node -> node ... ]
*!     [, latent(namelist) replace]
*!
*! Example:
*!     dagy define m1: age -> education -> earnings ; ability -> education ; ///
*!         ability -> earnings, latent(ability)
program _dagy_define
	version 14
	local stmt `"`0'"'

	local cpos = strpos(`"`stmt'"', ":")
	if `cpos' == 0 {
		di as err "syntax: dagy define <name>: node -> node [; node -> node ...] [, latent(namelist) replace]"
		exit 198
	}
	local name = trim(substr(`"`stmt'"', 1, `cpos' - 1))
	if `"`name'"' == "" {
		di as err "you must give the DAG a name, e.g. {bf:dagy define mydag: x -> y}"
		exit 198
	}
	confirm name `name'
	local rest = substr(`"`stmt'"', `cpos' + 1, .)

	local opos = strpos(`"`rest'"', ",")
	if `opos' > 0 {
		local edgespec = substr(`"`rest'"', 1, `opos' - 1)
		local optstr   = substr(`"`rest'"', `opos' + 1, .)
	}
	else {
		local edgespec `"`rest'"'
		local optstr ""
	}

	local 0 `", `optstr'"'
	syntax [, LATENT(string) REPLACE]

	cap confirm frame dagy__reg
	if _rc {
		frame create dagy__reg
		frame dagy__reg: qui gen str100 name = ""
	}
	local already 0
	frame dagy__reg {
		qui count if name == "`name'"
		local already = r(N) > 0
	}
	if `already' & "`replace'" == "" {
		di as err "DAG {bf:`name'} already exists; use the {bf:replace} option to overwrite it."
		exit 110
	}
	if `already' {
		_dagy_drop `name'
	}

	local edgespec = subinstr(`"`edgespec'"', "->", " -> ", .)
	local remaining `"`edgespec'"'
	local n1list ""
	local n2list ""
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
		local prevnode ""
		forvalues w = 1/`ntok' {
			local tok : word `w' of `seg'
			if "`tok'" == "->" continue
			if `"`prevnode'"' != "" {
				local n1list `"`n1list' `prevnode'"'
				local n2list `"`n2list' `tok'"'
			}
			local prevnode "`tok'"
		}
	}

	local nedges : word count `n1list'
	if `nedges' == 0 {
		di as err "no edges found in DAG definition"
		exit 198
	}

	local nodelist ""
	forvalues i = 1/`nedges' {
		local nfrom : word `i' of `n1list'
		local nto   : word `i' of `n2list'
		if !`: list nfrom in nodelist' {
			local nodelist `"`nodelist' `nfrom'"'
		}
		if !`: list nto in nodelist' {
			local nodelist `"`nodelist' `nto'"'
		}
	}
	local nnodes : word count `nodelist'

	foreach lv of local latent {
		if !`: list lv in nodelist' {
			di as err "latent variable {bf:`lv'} does not appear anywhere in the DAG's edges"
			exit 198
		}
	}

	frame create dagy_`name'_n
	frame dagy_`name'_n {
		qui gen str100 node = ""
		qui gen byte latent = 0
		qui set obs `nnodes'
		forvalues i = 1/`nnodes' {
			local nd : word `i' of `nodelist'
			qui replace node = "`nd'" in `i'
			local isl 0
			if `: list nd in latent' {
				local isl 1
			}
			qui replace latent = `isl' in `i'
		}
	}

	frame create dagy_`name'_e
	frame dagy_`name'_e {
		qui gen str100 n1 = ""
		qui gen str100 n2 = ""
		qui set obs `nedges'
		forvalues i = 1/`nedges' {
			local nfrom : word `i' of `n1list'
			local nto   : word `i' of `n2list'
			qui replace n1 = "`nfrom'" in `i'
			qui replace n2 = "`nto'" in `i'
		}
		qui duplicates drop n1 n2, force
	}

	mata: dagy_m_readfr("dagy_`name'_n", "dagy_`name'_e", dagnodes=J(0,1,""), dagA=J(0,0,.), daglatent=J(0,1,.))
	mata: st_local("hascycle", strofreal(dagy_m_hascycle(dagA)))
	if `hascycle' {
		di as err "this graph has a cycle - it is not a DAG. Fix the edges and try {bf:dagy define ..., replace} again."
		_dagy_drop `name'
		exit 198
	}

	frame dagy__reg {
		local N = _N + 1
		qui set obs `N'
		qui replace name = "`name'" in `N'
	}

	global DAGY_CURRENT "`name'"

	di as txt "DAG {res:`name'} defined: {res:`nnodes'} nodes, {res:`nedges'} edges."
	if `"`latent'"' != "" {
		di as txt "  latent (unobserved): {res:`latent'}"
	}
end
