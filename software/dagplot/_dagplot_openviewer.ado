*! _dagplot_openviewer: dagplot's own fork of nwcommands_2016's shared
*! nw_openviewer.ado, forked alongside dagplot.ado/dagplot_template.html
*! (see dagplot.ado's own top header) so its viewer-launch path - not
*! just the rendering - is fully independent of nwcommands. Opens a
*! self-contained local HTML file in the chromeless native viewer
*! (native/dagplot_viewer.mm, compiled to a flat per-platform binary -
*! dagplot_viewer_macos/dagplot_viewer_windows.exe/dagplot_viewer_unix,
*! not a plugins/<platform>/ subdirectory, so `net install`'s flat file
*! layout can ship it), falling back to `view browse` when that binary
*! isn't available for the current platform or fails to launch.
*!
*! Differs from nw_openviewer.ado in exactly one respect: where the
*! binary comes from. nw_openviewer.ado resolves nwcommands' own
*! nwedit_viewer via unw_core.do's NweditViewerAvailable()/
*! NweditViewerPath() (which key off wherever nwcommands itself is
*! installed - findfile("nwset.ado")); this resolves dagplot_viewer
*! relative to THIS FILE's own directory instead, via a plain
*! `findfile "_dagplot_openviewer.ado"' (no Mata), so dagplot's launcher
*! never depends on nwcommands' own layout, and dagplot_viewer can carry
*! its own bug fixes without touching nwcommands' copy (see
*! native/dagplot_viewer.mm's own header for the fix this fork exists to
*! carry).
*!
*! Deliberately NOT using dagplot.ado's own _dagplot_installdir() mata
*! function here, even though it does the same lookup - confirmed
*! directly that an interpreted Mata function defined via a top-level
*! `mata: ... end' block inside one auto-loaded ado file is NOT visible
*! to a *different*, separately auto-loaded ado file's own execution,
*! even when that second file is invoked as a plain subroutine call from
*! within the first file's own running command (dagplot calling
*! _dagplot_openviewer mid-execution): the call worked every time from
*! inside dagplot.ado's own body, but "_dagplot_installdir() not found"
*! the moment _dagplot_openviewer.ado's own code tried the identical
*! call. unw_core.do's own NweditViewerAvailable()/NweditViewerPath()
*! avoid this because unw_core.do is loaded via an explicit top-level
*! `run', not ado auto-load - genuinely session-global, unlike an
*! ado-embedded interpreted Mata function. Simplest fix: don't share a
*! Mata function across ado files this way - resolve the path again
*! here, in plain Stata.
*!
*! Everything else - including the macOS winexec space-in-path staging
*! fix and the quote-stripping fix below - is unchanged from
*! nw_openviewer.ado; both bugs it fixed apply equally here.

capture program drop _dagplot_openviewer
program _dagplot_openviewer, rclass
	syntax anything(name=htmlpath)

	// `anything' captures the caller's raw argument text VERBATIM,
	// including any literal double quotes typed at the call site (see
	// nw_openviewer.ado's own header for the full account of this bug -
	// unlike a `string'/`varname' syntax element, `anything' does no
	// quote-stripping of its own). Strip one matching pair of enclosing
	// double quotes here, once, rather than at every later use site.
	if substr(`"`htmlpath'"', 1, 1) == char(34) & substr(`"`htmlpath'"', -1, 1) == char(34) {
		local htmlpath = substr(`"`htmlpath'"', 2, length(`"`htmlpath'"') - 2)
	}

	qui findfile "_dagplot_openviewer.ado"
	local _nwov_fullpath `"`r(fn)'"'
	local _nwov_pkgdir = substr(`"`_nwov_fullpath'"', 1, strrpos(`"`_nwov_fullpath'"', "/") - 1)
	// Flat filenames, not a plugins/<platform>/ subdirectory: `net install`
	// puts every listed file into one flat directory (no subfolders), so
	// the per-platform binary is distinguished by filename instead - same
	// idiom other Stata packages shipping compiled platform binaries use.
	local _nwov_fn = "dagplot_viewer_macos"
	if "`c(os)'" == "Windows" local _nwov_fn = "dagplot_viewer_windows.exe"
	if "`c(os)'" == "Unix" local _nwov_fn = "dagplot_viewer_unix"
	local _nwov_viewerpath = "`_nwov_pkgdir'/`_nwov_fn'"
	capture confirm file "`_nwov_viewerpath'"
	if _rc local _nwov_viewerpath ""

	local _nwov_usedviewer = 0
	if "`_nwov_viewerpath'" != "" {
		// Stage BOTH the viewer binary AND the html file it is told to
		// open into c(tmpdir) (guaranteed space-free) before calling
		// `winexec' - see nw_openviewer.ado's own header for why this is
		// unconditional rather than assuming either path is already
		// space-free.
		local _nwov_viewercopy = "`c(tmpdir)'" + "dagplot_viewer_" + strofreal(int(runiform()*1000000))
		local _nwov_htmlcopy = "`c(tmpdir)'" + "dagplot_view_" + strofreal(int(runiform()*1000000)) + ".html"
		capture erase "`_nwov_viewercopy'"
		capture erase "`_nwov_htmlcopy'"
		capture copy "`_nwov_viewerpath'" "`_nwov_viewercopy'", replace
		local _nwov_copyrc1 = _rc
		capture copy "`htmlpath'" "`_nwov_htmlcopy'", replace
		local _nwov_copyrc2 = _rc
		if `_nwov_copyrc1' == 0 & `_nwov_copyrc2' == 0 {
			capture shell chmod +x "`_nwov_viewercopy'"
			capture winexec `_nwov_viewercopy' `_nwov_htmlcopy'
			if _rc == 0 local _nwov_usedviewer = 1
		}
	}
	if !`_nwov_usedviewer' {
		view browse "`htmlpath'"
	}
	return local usedviewer = `_nwov_usedviewer'
end
