*! _dagy_estimate.ado 0.5.0 2026-08-27
*! internal - see help dagy
*! dagy estimate <name> exposure outcome, ///
*!     (adjust(namelist) | frontdoor(namelist) | instrument(name)) ///
*!     [given(namelist) run]
*!
*! Translates an already-identified strategy into the Stata estimation
*! command it implies, validating the strategy against the DAG first
*! (reusing the same graph primitives dagy adjust/dagy frontdoor/dagy iv
*! use, applied directly to the one set/candidate given rather than
*! enumerating). Prints the command by default; `run` executes it.
program _dagy_estimate, rclass
	version 14
	syntax [anything] [, ADJUST(string) FRONTDOOR(string) INSTRUMENT(string) ///
		GIVEN(string) RUN]

	local nstrat = (`"`adjust'"' != "") + (`"`frontdoor'"' != "") + (`"`instrument'"' != "")
	if `nstrat' != 1 {
		di as err "specify exactly one of {bf:adjust()}, {bf:frontdoor()}, or {bf:instrument()}"
		exit 198
	}

	_dagy_resolve `anything'
	local name `r(name)'
	local rest `r(rest)'
	local nw : word count `rest'
	if `nw' != 2 {
		di as err "syntax: dagy estimate [name] exposure outcome, (adjust(namelist)|frontdoor(namelist)|instrument(name)) [given(namelist) run]"
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

	mata: dagX = dagy_m_indicator(dagnodes, "`x'")
	mata: dagY = dagy_m_indicator(dagnodes, "`y'")
	mata: dagGiven = dagy_m_indicator(dagnodes, `"`given'"')
	mata: st_local("nn", strofreal(rows(dagnodes)))

	di as txt "{hline 60}"

	if `"`adjust'"' != "" {
		foreach v of local adjust {
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
		mata: dagZ = dagy_m_indicator(dagnodes, `"`adjust'"')
		mata: dagdescX = dagy_m_desc(dagA, dagX)
		mata: st_local("baddesc", strofreal(sum(dagZ :* dagdescX)))
		if `baddesc' > 0 {
			di as err "the adjust() set includes a descendant of `x'; that is not a valid back-door adjustment set - see {bf:dagy adjust}"
			exit 198
		}
		mata: dagAxX = dagy_m_cutfrom(dagA, dagX)
		mata: st_local("dsep", strofreal(dagy_m_dsep(dagAxX, dagX, dagY, dagZ)))
		if !`dsep' {
			di as err "adjust(`adjust') does not satisfy the back-door criterion for `x' -> `y' in DAG `name' - see {bf:dagy adjust} for valid sets"
			exit 198
		}

		local allvars = trim("`adjust' `given'")
		di as txt "Back-door adjustment identifies the effect of " as res "`x'" as txt " on " as res "`y'" as txt " in DAG " as res "`name'"
		di as txt "{hline 60}"
		di as txt "Suggested command:"
		di as txt "    " as res "regress `y' `x' `allvars'"
		di as txt "{hline 60}"
		if "`run'" != "" {
			regress `y' `x' `allvars'
			return scalar effect = _b[`x']
		}
		exit
	}

	if `"`frontdoor'"' != "" {
		foreach v of local frontdoor {
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
		mata: dagM = dagy_m_indicator(dagnodes, `"`frontdoor'"')
		mata: dagAdel = dagy_m_delnodes(dagA, dagM)
		mata: dagdescXdel = dagy_m_desc(dagAdel, dagX)
		mata: st_local("yi", strofreal(dagy_m_idx(dagnodes,"`y'")))
		mata: st_local("ok1", strofreal(!dagdescXdel[`yi']))
		mata: dagAxX2 = dagy_m_cutfrom(dagA, dagX)
		mata: st_local("ok2", strofreal(dagy_m_dsep(dagAxX2, dagX, dagM, J(`nn',1,0))))
		mata: dagAxM = dagy_m_cutfrom(dagA, dagM)
		mata: st_local("ok3", strofreal(dagy_m_dsep(dagAxM, dagM, dagY, dagX)))
		if !`ok1' | !`ok2' | !`ok3' {
			di as err "frontdoor(`frontdoor') does not satisfy the front-door criterion for `x' -> `y' in DAG `name' - see {bf:dagy frontdoor} for valid sets"
			exit 198
		}

		di as txt "Front-door adjustment identifies the effect of " as res "`x'" as txt " on " as res "`y'" as txt " in DAG " as res "`name'" as txt " (linear product-of-coefficients estimator)"
		di as txt "{hline 60}"
		di as txt "Suggested commands:"
		di as txt "    Step 1:  " as res "regress `frontdoor' `x' `given'"
		di as txt "    Step 2:  " as res "regress `y' `frontdoor' `x' `given'"
		di as txt "    effect = (coefficient of `x' in step 1) x (coefficient of `frontdoor' in step 2)"
		di as txt "{hline 60}"
		if "`run'" != "" {
			qui regress `frontdoor' `x' `given'
			local b1 = _b[`x']
			qui regress `y' `frontdoor' `x' `given'
			local b2 = _b[`frontdoor']
			di as txt "Step 1: regress `frontdoor' `x' `given'"
			regress `frontdoor' `x' `given'
			di as txt "Step 2: regress `y' `frontdoor' `x' `given'"
			regress `y' `frontdoor' `x' `given'
			di as txt "{hline 60}"
			di as txt "Front-door point estimate of the effect of `x' on `y': " as res %9.5g `b1'*`b2'
			return scalar effect = `b1'*`b2'
		}
		exit
	}

	// instrument()
	local z `"`instrument'"'
	cap mata: dagy_m_idx(dagnodes, "`z'")
	if _rc {
		di as err "`z' is not a node of DAG `name'"
		exit 198
	}
	mata: st_local("islat", strofreal(daglatent[dagy_m_idx(dagnodes,"`z'")]))
	if `islat' {
		di as err "`z' is marked latent (unobserved) in DAG `name' and cannot be an instrument"
		exit 198
	}
	mata: st_local("isdescx", strofreal(dagy_m_desc(dagA, dagX)[dagy_m_idx(dagnodes,"`z'")]))
	if `isdescx' {
		di as err "`z' is a descendant of `x' in DAG `name' and cannot be an instrument"
		exit 198
	}
	mata: dagZc = dagy_m_indicator(dagnodes, "`z'")
	mata: dagres = dagy_m_ivcheck(dagA, dagX, dagY, dagZc, dagGiven)
	mata: st_local("relevant", strofreal(dagres[1]))
	mata: st_local("exclrestr", strofreal(dagres[2]))
	if !`relevant' | !`exclrestr' {
		di as err "instrument(`z') is not a valid instrument for `x' -> `y' in DAG `name' - see {bf:dagy iv} for why"
		exit 198
	}

	di as txt "Instrumental-variable estimation identifies the effect of " as res "`x'" as txt " on " as res "`y'" as txt " in DAG " as res "`name'"
	di as txt "{hline 60}"
	di as txt "Suggested command:"
	di as txt "    " as res "ivregress 2sls `y' `given' (`x' = `z')"
	di as txt "{hline 60}"
	if "`run'" != "" {
		ivregress 2sls `y' `given' (`x' = `z')
		return scalar effect = _b[`x']
	}
end
