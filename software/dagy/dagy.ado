*! dagy.ado 1.0.0 2026-09-15
*! Thomas Grund
*! A causal-DAG workflow for Stata: define a directed acyclic graph,
*! draw it (via dagy's own dagplot, an interactive cytoscape-based
*! viewer - no external package required) with an automatic layered
*! layout, enumerate causal/backdoor paths, test d-separation, find back-door and
*! front-door adjustment sets (including the optimal variance-minimizing
*! set), search for instrumental-variable candidates, list testable
*! implications (local-Markov or comprehensive pairwise, optionally
*! tested against real data), report the DAG's Markov-equivalence class
*! (optionally with background-knowledge edges) and its MAG under
*! latent projection, simulate data from its structural model, translate
*! an identification result into a Stata estimation command and refute
*! it (placebo/random-common-cause/subsample checks), check adjustment-
*! set sensitivity to a hypothetical unmeasured confounder, and import a
*! DAG from dagitty.net or local dagitty-format text.
*!
*! dagy define      <name>: <edges> [, latent(varlist) replace]
*! dagy list        [name]
*! dagy drop         name | _all
*! dagy draw        [name] [, exposure(name) outcome(name) adjust(namelist)
*!                            nodesize(#)]
*! dagy layout      <name> [, orient(horizontal|vertical) replace]
*! dagy layout      <name>: node x y [; node x y ...]
*! dagy path        [name] exposure outcome [, max(#)]
*! dagy dsep        [name] varlist1 (varlist2) [, given(namelist)]
*! dagy adjust      [name] exposure outcome [, given(namelist) all max(#) optimal]
*! dagy frontdoor   [name] exposure outcome [, given(namelist) all max(#)]
*! dagy iv          [name] exposure outcome [candidate] [, given(namelist)]
*! dagy testable    [name] [, observed test]
*! dagy localtests  [name] [, test max(#)]
*! dagy cpdag       [name] [, given(edgespec)]
*! dagy mag         [name] [, max(#)]
*! dagy simulate    <name>, n(#) [beta(#) sd(#) coef(edgespec) seed(#) keeplatent clear]
*! dagy estimate    <name> exposure outcome, (adjust(namelist)|frontdoor(namelist)|instrument(name)) [given(namelist) run]
*! dagy refute      <name> exposure outcome, (adjust(namelist)|frontdoor(namelist)|instrument(name)) [given(namelist) reps(#) frac(#) seed(#)]
*! dagy sensitivity <name> exposure outcome [, given(namelist)]
*! dagy import      <name>, (id(graphid)|file(filename)) [replace]
*!
*! see help dagy

program dagy
	version 14

	// _dagy_mata.ado's mata block (dagy's graph engine) only needs to be
	// sourced once per session; a Stata global marks that it has been.
	if "$DAGY_MATA_LOADED" != "1" {
		qui findfile "_dagy_mata.ado"
		run "`r(fn)'"
		global DAGY_MATA_LOADED "1"
	}

	gettoken sub 0 : 0, parse(" ")
	local sub = lower("`sub'")

	if "`sub'" == "" {
		_dagy_list
		exit
	}

	if inlist("`sub'", "define", "def") {
		_dagy_define `0'
		exit
	}
	if inlist("`sub'", "list", "describe", "dir") {
		_dagy_list `0'
		exit
	}
	if inlist("`sub'", "drop") {
		_dagy_drop `0'
		exit
	}
	if inlist("`sub'", "draw", "plot") {
		_dagy_draw `0'
		exit
	}
	if inlist("`sub'", "layout") {
		_dagy_layout `0'
		exit
	}
	if inlist("`sub'", "path", "paths") {
		_dagy_path `0'
		exit
	}
	if inlist("`sub'", "dsep") {
		_dagy_dsep `0'
		exit
	}
	if inlist("`sub'", "adjust", "adjustset") {
		_dagy_adjust `0'
		exit
	}
	if inlist("`sub'", "frontdoor", "fdadjust") {
		_dagy_frontdoor `0'
		exit
	}
	if inlist("`sub'", "iv") {
		_dagy_iv `0'
		exit
	}
	if inlist("`sub'", "testable") {
		_dagy_testable `0'
		exit
	}
	if inlist("`sub'", "cpdag") {
		_dagy_cpdag `0'
		exit
	}
	if inlist("`sub'", "simulate", "simul") {
		_dagy_simulate `0'
		exit
	}
	if inlist("`sub'", "estimate") {
		_dagy_estimate `0'
		exit
	}
	if inlist("`sub'", "sensitivity") {
		_dagy_sensitivity `0'
		exit
	}
	if inlist("`sub'", "localtests") {
		_dagy_localtests `0'
		exit
	}
	if inlist("`sub'", "mag") {
		_dagy_mag `0'
		exit
	}
	if inlist("`sub'", "refute") {
		_dagy_refute `0'
		exit
	}
	if inlist("`sub'", "import") {
		_dagy_import `0'
		exit
	}

	di as err "unknown dagy subcommand: {bf:`sub'}"
	di as err "valid subcommands are: define, list, drop, draw, layout, path, dsep, adjust, frontdoor, iv, testable, localtests, cpdag, mag, simulate, estimate, refute, sensitivity, import"
	exit 198
end
