*! _dagy_import.ado 0.5.0 2026-08-27
*! internal - see help dagy
*! dagy import <name>, id(graphid) [replace]
*! dagy import <name>, file(filename) [replace]
*!
*! Loads a DAG from dagitty model text, either fetched live from
*! dagitty.net (id()) or read from a local file (file()) containing
*! model text already copied/exported from the dagitty.net UI. Only
*! plain `dag { }' models are supported (not `pdag'/`mag' - those have
*! undirected/bidirected edges this package doesn't represent). Node
*! attributes `exposure'/`outcome'/`latent' and `pos="x,y"' position
*! hints are read where present; a position is imported into the new
*! DAG's layout only if every node has one.
program _dagy_import
	version 14
	gettoken name 0 : 0, parse(",")
	local name = trim(`"`name'"')
	if `"`name'"' == "" {
		di as err "syntax: dagy import <name>, (id(graphid)|file(filename)) [replace]"
		exit 198
	}
	syntax [, ID(string) FILE(string) REPLACE]

	local nmode = (`"`id'"' != "") + (`"`file'"' != "")
	if `nmode' != 1 {
		di as err "specify exactly one of {bf:id()} or {bf:file()}"
		exit 198
	}

	if `"`id'"' != "" {
		if regexm(`"`id'"', "dagitty\.net/m(.+)$") {
			local gid = regexs(1)
		}
		else if regexm(`"`id'"', "dagitty\.net/(.+)$") {
			local gid = regexs(1)
		}
		else {
			local gid `"`id'"'
		}
		tempfile dagy_fetchfile
		cap copy "http://dagitty.net/dags/load.php?id=`gid'" `"`dagy_fetchfile'"', replace
		if _rc {
			di as err "could not reach dagitty.net (network error, or the site is unreachable from here); try {bf:file()} with locally-saved model text instead"
			exit 631
		}
		mata: st_local("modeltext", dagy_m_base64decode(invtokens(cat(st_local("dagy_fetchfile"))', char(10))))
	}
	else {
		cap confirm file `"`file'"'
		if _rc {
			di as err "file `file' not found"
			exit 601
		}
		mata: st_local("modeltext", invtokens(cat(st_local("file"))', char(10)))
	}

	if !regexm(`"`modeltext'"', "(dag|pdag|mag)[ \t]*\{") {
		di as err "could not find a dag { ... } block in the model text"
		exit 198
	}
	local kind = regexs(1)
	if "`kind'" != "dag" {
		di as err "dagy import only supports plain dag { } models, not `kind' { } (MAGs/PDAGs have undirected/bidirected edges this package doesn't represent)"
		exit 198
	}

	local opos = strpos(`"`modeltext'"', "{")
	local cpos = strrpos(`"`modeltext'"', "}")
	local inner = substr(`"`modeltext'"', `opos'+1, `cpos'-`opos'-1)

	local nodelist ""
	local latentlist ""
	local n1list ""
	local n2list ""
	local exposurevar ""
	local outcomevar ""
	local posnodelist ""
	local posxlist ""
	local posylist ""

	local remaining `"`inner'"'
	while `"`remaining'"' != "" {
		local nlpos = strpos(`"`remaining'"', char(10))
		if `nlpos' > 0 {
			local ln = substr(`"`remaining'"', 1, `nlpos'-1)
			local remaining = substr(`"`remaining'"', `nlpos'+1, .)
		}
		else {
			local ln `"`remaining'"'
			local remaining ""
		}
		local ln = trim(`"`ln'"')
		if `"`ln'"' == "" continue
		if regexm(`"`ln'"', "^bb[ \t]*=") continue

		if regexm(`"`ln'"', "^([A-Za-z_][A-Za-z0-9_.]*)[ \t]*(<->|->|<-|--)[ \t]*([A-Za-z_][A-Za-z0-9_.]*)") {
			local nn1 = regexs(1)
			local op = regexs(2)
			local nn2 = regexs(3)
			if "`op'" == "->" {
				local n1list `"`n1list' `nn1'"'
				local n2list `"`n2list' `nn2'"'
			}
			else if "`op'" == "<-" {
				local n1list `"`n1list' `nn2'"'
				local n2list `"`n2list' `nn1'"'
			}
			else {
				di as err "edge `nn1' `op' `nn2' uses an unsupported operator; dagy import only handles -> and <- edges (plain DAGs)"
				exit 198
			}
			if !`: list nn1 in nodelist' local nodelist `"`nodelist' `nn1'"'
			if !`: list nn2 in nodelist' local nodelist `"`nodelist' `nn2'"'
			continue
		}

		if regexm(`"`ln'"', "^([A-Za-z_][A-Za-z0-9_.]*)") {
			local nd = regexs(1)
			if !`: list nd in nodelist' local nodelist `"`nodelist' `nd'"'
			if regexm(`"`ln'"', "\[([^]]*)\]") {
				local attrs = regexs(1)
				if strpos(`"`attrs'"', "latent") > 0 & !`: list nd in latentlist' {
					local latentlist `"`latentlist' `nd'"'
				}
				if strpos(`"`attrs'"', "exposure") > 0 local exposurevar "`nd'"
				if strpos(`"`attrs'"', "outcome") > 0 local outcomevar "`nd'"
				if regexm(`"`attrs'"', `"pos="([0-9.eE+-]+),([0-9.eE+-]+)""') {
					local posnodelist `"`posnodelist' `nd'"'
					local posxlist `"`posxlist' `=regexs(1)'"'
					local posylist `"`posylist' `=regexs(2)'"'
				}
			}
		}
	}

	local nedges : word count `n1list'
	if `nedges' == 0 {
		di as err "no edges found in the imported model"
		exit 198
	}

	local edgespec ""
	forvalues i = 1/`nedges' {
		local a : word `i' of `n1list'
		local b : word `i' of `n2list'
		local edgespec `"`edgespec' `a' -> `b' ;"'
	}
	local edgespec = trim(`"`edgespec'"')
	local elen = strlen(`"`edgespec'"')
	if substr(`"`edgespec'"', `elen', 1) == ";" {
		local edgespec = trim(substr(`"`edgespec'"', 1, `elen'-1))
	}

	local opts ""
	if `"`latentlist'"' != "" local opts `"`opts' latent(`latentlist')"'
	if "`replace'" != "" local opts `"`opts' replace"'
	local opts = trim(`"`opts'"')

	local calltail `"`name': `edgespec'"'
	if `"`opts'"' != "" local calltail `"`calltail', `opts'"'
	_dagy_define `calltail'

	if `"`exposurevar'"' != "" | `"`outcomevar'"' != "" {
		di as txt "  (dagitty model marked exposure: `exposurevar', outcome: `outcomevar')"
	}

	local nnodes : word count `nodelist'
	local nposnodes : word count `posnodelist'
	if `nposnodes' == `nnodes' & `nnodes' > 0 {
		_dagy_layout_compute `name' horizontal
		forvalues i = 1/`nnodes' {
			local nd : word `i' of `posnodelist'
			local px : word `i' of `posxlist'
			local py : word `i' of `posylist'
			frame dagy_`name'_xy {
				qui replace x = `px' if node == "`nd'"
				qui replace y = -`py' if node == "`nd'"
			}
		}
		di as txt "  (imported node positions from the source model)"
	}
end
