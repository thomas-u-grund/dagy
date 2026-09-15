*! _dagy_resolve.ado 0.1.0 2026-08-26
*! internal - see help dagy
*! Resolves an optional leading DAG name out of `anything'. If the
*! first token names a defined DAG, it is consumed and returned as
*! r(name); otherwise the current DAG ($DAGY_CURRENT) is used and
*! `anything' is returned untouched as r(rest).
program _dagy_resolve, rclass
	version 14
	local anything `"`0'"'

	local first : word 1 of `anything'
	local isdag 0
	cap confirm frame dagy__reg
	if !_rc & `"`first'"' != "" {
		frame dagy__reg {
			qui count if name == "`first'"
			if r(N) local isdag 1
		}
	}

	if `isdag' {
		gettoken name rest : anything
	}
	else {
		local name `"$DAGY_CURRENT"'
		local rest `"`anything'"'
	}

	if `"`name'"' == "" {
		di as err "no DAG name given and no current DAG defined; use {bf:dagy define} first."
		exit 198
	}
	cap confirm frame dagy_`name'_n
	if _rc {
		di as err "DAG {bf:`name'} not found; see {bf:dagy list}."
		exit 111
	}

	global DAGY_CURRENT "`name'"
	return local name "`name'"
	return local rest `"`rest'"'
end
