*! _dagy_refute.ado 0.5.0 2026-08-27
*! internal - see help dagy
*! dagy refute <name> exposure outcome, ///
*!     (adjust(namelist) | frontdoor(namelist) | instrument(name)) ///
*!     [given(namelist) reps(#) frac(#) seed(#)]
*!
*! Three refutation checks for an already-validated identification
*! strategy (DoWhy's signature feature): placebo treatment (permute the
*! exposure - the effect should vanish), random common cause (add a
*! fresh noise covariate - the effect should barely move), and subsample
*! validation (re-estimate on random subsamples - the effect should be
*! stable). Requires real data in memory matching the DAG's node names;
*! reuses `dagy estimate`'s validation and r(effect) for the
*! baseline rather than re-deriving which command matches which
*! strategy.
program _dagy_refute
	version 14
	syntax [anything] [, ADJUST(string) FRONTDOOR(string) INSTRUMENT(string) ///
		GIVEN(string) REPS(integer 100) FRAC(real 0.9) SEED(string)]

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
		di as err "syntax: dagy refute [name] exposure outcome, (adjust(namelist)|frontdoor(namelist)|instrument(name)) [given(namelist) reps(#) frac(#) seed(#)]"
		exit 198
	}
	local x : word 1 of `rest'
	local y : word 2 of `rest'

	if `"`seed'"' != "" {
		set seed `seed'
	}

	qui dagy estimate `name' `x' `y', adjust(`adjust') frontdoor(`frontdoor') instrument(`instrument') given(`given') run
	local baseline = r(effect)

	di as txt "{hline 60}"
	di as txt "Refutation tests for the effect of " as res "`x'" as txt " on " as res "`y'" as txt " in DAG " as res "`name'"
	di as txt "Baseline estimate: " as res %9.5g `baseline'
	di as txt "{hline 60}"

	tempfile dagy_refute_orig
	qui save `dagy_refute_orig', replace

	tempname peff rceff sseff

	*-------------------------------------------------------------
	* 1. Placebo treatment: permuted (random) exposure
	*-------------------------------------------------------------
	mata: `peff' = J(`reps',1,.)
	forvalues r = 1/`reps' {
		qui use `dagy_refute_orig', clear
		tempvar placebo
		qui gen double `placebo' = .
		// jumble() randomly permutes rows - this is what actually breaks
		// the x-y relationship (a `sort` on a random key reorders every
		// variable together, so exposure stays perfectly aligned with
		// outcome and nothing is actually permuted - confirmed as a real
		// bug this way during verification: it silently reproduced the
		// baseline estimate instead of a null one).
		mata: st_store(., "`placebo'", jumble(st_data(.,"`x'")))
		local effect = .
		if `"`adjust'"' != "" {
			qui regress `y' `placebo' `adjust' `given'
			local effect = _b[`placebo']
		}
		else if `"`frontdoor'"' != "" {
			qui regress `frontdoor' `placebo' `given'
			local b1 = _b[`placebo']
			qui regress `y' `frontdoor' `placebo' `given'
			local b2 = _b[`frontdoor']
			local effect = `b1' * `b2'
		}
		else {
			qui ivregress 2sls `y' `given' (`placebo' = `instrument')
			local effect = _b[`placebo']
		}
		mata: `peff'[`r'] = `effect'
	}
	qui use `dagy_refute_orig', clear
	mata: st_local("pmean", strofreal(mean(`peff')))
	mata: st_local("psd", strofreal(sqrt(variance(`peff'))))
	mata: st_local("ppval", strofreal(mean(abs(`peff') :>= abs(`baseline'))))

	di as txt _n "1. Placebo treatment (exposure randomly permuted, `reps' reps):"
	di as txt "   mean placebo effect = " as res %9.5g `pmean' as txt ", sd = " as res %9.5g `psd'
	di as txt "   share of reps with |placebo effect| >= |baseline effect| = " as res %5.3f `ppval'
	di as txt "   (a small share here is reassuring; a large share suggests the" as txt _n "   baseline effect could arise even with no real exposure effect)"

	*-------------------------------------------------------------
	* 2. Random common cause: add a fresh noise covariate
	*-------------------------------------------------------------
	mata: `rceff' = J(`reps',1,.)
	forvalues r = 1/`reps' {
		qui use `dagy_refute_orig', clear
		tempvar randomcause
		qui gen double `randomcause' = rnormal()
		local effect = .
		if `"`adjust'"' != "" {
			qui regress `y' `x' `adjust' `given' `randomcause'
			local effect = _b[`x']
		}
		else if `"`frontdoor'"' != "" {
			qui regress `frontdoor' `x' `given' `randomcause'
			local b1 = _b[`x']
			qui regress `y' `frontdoor' `x' `given' `randomcause'
			local b2 = _b[`frontdoor']
			local effect = `b1' * `b2'
		}
		else {
			qui ivregress 2sls `y' `given' `randomcause' (`x' = `instrument')
			local effect = _b[`x']
		}
		mata: `rceff'[`r'] = `effect'
	}
	qui use `dagy_refute_orig', clear
	mata: st_local("rcmean", strofreal(mean(`rceff')))
	mata: st_local("rcsd", strofreal(sqrt(variance(`rceff'))))

	di as txt _n "2. Random common cause (fresh N(0,1) covariate added, `reps' reps):"
	di as txt "   mean effect with extra covariate = " as res %9.5g `rcmean' as txt ", sd = " as res %9.5g `rcsd'
	di as txt "   (should stay close to the baseline estimate of " as res %9.5g `baseline' as txt ")"

	*-------------------------------------------------------------
	* 3. Subsample validation
	*-------------------------------------------------------------
	mata: `sseff' = J(`reps',1,.)
	qui count
	local n = r(N)
	local nsub = round(`n' * `frac')
	forvalues r = 1/`reps' {
		qui use `dagy_refute_orig', clear
		tempvar sortkey
		qui gen double `sortkey' = runiform()
		sort `sortkey'
		qui keep in 1/`nsub'
		local effect = .
		if `"`adjust'"' != "" {
			qui regress `y' `x' `adjust' `given'
			local effect = _b[`x']
		}
		else if `"`frontdoor'"' != "" {
			qui regress `frontdoor' `x' `given'
			local b1 = _b[`x']
			qui regress `y' `frontdoor' `x' `given'
			local b2 = _b[`frontdoor']
			local effect = `b1' * `b2'
		}
		else {
			qui ivregress 2sls `y' `given' (`x' = `instrument')
			local effect = _b[`x']
		}
		mata: `sseff'[`r'] = `effect'
	}
	qui use `dagy_refute_orig', clear
	mata: st_local("ssmean", strofreal(mean(`sseff')))
	mata: st_local("sssd", strofreal(sqrt(variance(`sseff'))))

	di as txt _n "3. Subsample validation (random " as res %3.0f `=`frac'*100' as txt "% subsamples, `reps' reps):"
	di as txt "   mean effect across subsamples = " as res %9.5g `ssmean' as txt ", sd = " as res %9.5g `sssd'
	di as txt "   (should stay close to the baseline estimate of " as res %9.5g `baseline' as txt ")"
	di as txt "{hline 60}"
end
