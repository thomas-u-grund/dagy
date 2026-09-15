*! _dagy_drop.ado 0.3.0 2026-08-27
*! internal - see help dagy
program _dagy_drop
	version 14
	gettoken name 0 : 0
	if `"`name'"' == "" {
		di as err "syntax: dagy drop <name> | _all"
		exit 198
	}

	if lower(`"`name'"') == "_all" {
		cap frame dir
		local allframes `r(frames)'
		foreach f of local allframes {
			if substr("`f'",1,10) == "dagy_" & "`f'" != "dagy__reg" {
				cap frame drop `f'
			}
		}
		cap frame drop dagy__reg
		global DAGY_CURRENT ""
		di as txt "all DAGs dropped."
		exit
	}

	cap frame drop dagy_`name'_n
	cap frame drop dagy_`name'_e
	cap frame drop dagy_`name'_xy

	cap confirm frame dagy__reg
	if !_rc {
		frame dagy__reg {
			qui drop if name == "`name'"
		}
	}

	if `"$DAGY_CURRENT"' == "`name'" {
		global DAGY_CURRENT ""
	}
end
