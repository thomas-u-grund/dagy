*! dagy_install.ado 1.0.0 2026-09-17
*! Thomas Grund
*! One-command finisher for `net install dagy`. Stata's own net/ado
*! system only downloads recognized program files (.ado/.sthlp/...) via
*! `net install` - anything else in a package ("ancillary files") needs
*! a separate `net get`, which drops them in the current directory (or
*! wherever `net set other` points), NOT next to the package's own .ado
*! files. dagplot.ado finds its runtime assets (dagplot_template.html,
*! cytoscape.min.js, the native viewer binary) by looking in its own
*! install directory (see _dagplot_installdir()/findfile), so `net get`
*! alone would leave them undiscoverable without extra manual setup.
*!
*! This command does the rest of the work in one step: `net install`s
*! the companion dagplot package (its own .ado/.sthlp), then downloads
*! its non-ado assets directly via `copy` (which, like `net`, fetches
*! plain https URLs, no external tool needed) straight into dagplot's
*! own install directory, so dagplot.ado finds them exactly where it
*! already expects to look. Nothing here changes how dagplot resolves
*! its own paths - see dagplot.ado/_dagplot_openviewer.ado.
*!
*! Usage: after `net install dagy, from(...) replace`, just run:
*!     dagy_install

capture program drop dagy_install
program dagy_install
	version 16

	local _di_base = "https://raw.githubusercontent.com/thomas-u-grund/dagy/main/software/dagplot"

	di as txt "Installing dagplot (dagy's interactive graph viewer)..."
	net install dagplot, from("`_di_base'/") replace

	qui findfile "dagplot.ado"
	local _di_dir = substr(`"`r(fn)'"', 1, strrpos(`"`r(fn)'"', "/") - 1)

	di as txt "Downloading dagplot's rendering assets..."
	foreach _di_f in dagplot_template.html cytoscape.min.js {
		capture copy "`_di_base'/`_di_f'" "`_di_dir'/`_di_f'", replace
		if _rc {
			di as err "Could not download `_di_f' from `_di_base'/`_di_f' (rc=`=_rc'). " ///
				"dagy draw will not work until this is retried - check your internet " ///
				"connection and rerun dagy_install."
			exit _rc
		}
	}

	local _di_viewerfn = "dagplot_viewer_macos"
	if "`c(os)'" == "Windows" local _di_viewerfn = "dagplot_viewer_windows.exe"
	if "`c(os)'" == "Unix" local _di_viewerfn = "dagplot_viewer_unix"
	capture copy "`_di_base'/`_di_viewerfn'" "`_di_dir'/`_di_viewerfn'", replace
	if _rc {
		di as txt "No native chromeless viewer binary is available yet for this " ///
			"platform (`c(os)''); dagy draw will open its interactive viewer in " ///
			"your default web browser instead - everything (drawing, editing, " ///
			"exporting) works the same way there."
	}
	else {
		capture shell chmod +x "`_di_dir'/`_di_viewerfn'"
	}

	di as txt "{p}Done. Try:{p_end}"
	di as txt `"    dagy define mydag: x -> y, replace"'
	di as txt `"    dagy draw mydag"'
end
