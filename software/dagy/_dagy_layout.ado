*! _dagy_layout.ado 0.3.0 2026-08-27
*! internal - see help dagy
*! dagy layout <name> [, orient(horizontal|vertical) replace]
*! dagy layout <name>: node x y [; node x y ...]
program _dagy_layout
	version 14
	local stmt `"`0'"'

	local cpos = strpos(`"`stmt'"', ":")
	if `cpos' > 0 {
		local name = trim(substr(`"`stmt'"', 1, `cpos' - 1))
		if `"`name'"' == "" {
			di as err "syntax: dagy layout <name>: node x y [; node x y ...]"
			exit 198
		}
		cap confirm frame dagy_`name'_n
		if _rc {
			di as err "DAG {bf:`name'} not found; see {bf:dagy list}."
			exit 111
		}
		local rest = substr(`"`stmt'"', `cpos' + 1, .)

		cap confirm frame dagy_`name'_xy
		if _rc {
			_dagy_layout_compute `name' horizontal
		}

		mata: dagy_m_readfr("dagy_`name'_n", "dagy_`name'_e", dagnodes=J(0,1,""), dagA=J(0,0,.), daglatent=J(0,1,.))

		local remaining `"`rest'"'
		local npinned 0
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
				di as err "each layout pin must be {bf:node x y}; got: `seg'"
				exit 198
			}
			local nd : word 1 of `seg'
			local xx : word 2 of `seg'
			local yy : word 3 of `seg'

			cap mata: dagy_m_idx(dagnodes, "`nd'")
			if _rc {
				di as err "`nd' is not a node of DAG `name'"
				exit 198
			}
			cap confirm number `xx'
			if _rc {
				di as err "x coordinate for `nd' must be a number; got: `xx'"
				exit 198
			}
			cap confirm number `yy'
			if _rc {
				di as err "y coordinate for `nd' must be a number; got: `yy'"
				exit 198
			}

			frame dagy_`name'_xy {
				qui replace x = `xx' if node == "`nd'"
				qui replace y = `yy' if node == "`nd'"
				qui replace fixed = 1 if node == "`nd'"
			}
			local npinned = `npinned' + 1
		}

		di as txt "DAG {res:`name'}: pinned `npinned' node position(s)."
		exit
	}

	syntax [anything] [, ORIENT(string) REPLACE]
	local name `"`anything'"'
	if `"`name'"' == "" {
		di as err "syntax: dagy layout <name> [, orient(horizontal|vertical) replace]"
		exit 198
	}
	cap confirm frame dagy_`name'_n
	if _rc {
		di as err "DAG {bf:`name'} not found; see {bf:dagy list}."
		exit 111
	}
	if `"`orient'"' != "" & !inlist(`"`orient'"', "horizontal", "vertical") {
		di as err "orient() must be {bf:horizontal} or {bf:vertical}"
		exit 198
	}

	cap confirm frame dagy_`name'_xy
	if !_rc {
		local nfixed = 0
		frame dagy_`name'_xy {
			qui count if fixed
			local nfixed = r(N)
		}
		if `nfixed' > 0 & "`replace'" == "" {
			di as err "DAG {bf:`name'} has `nfixed' manually pinned node position(s); use the {bf:replace} option to discard them and recompute from scratch."
			exit 110
		}
	}

	_dagy_layout_compute `name' `orient'
	di as txt "DAG {res:`name'}: automatic layout computed."
end
