*  Example 1: confounding and mediation, side by side
*  A classic "does education raise earnings?" DAG: ability confounds the
*  education -> earnings relationship, age is an instrument-flavoured
*  ancestor of education only.
*
*  Edit the adopath lines below to point at your own nwcommands, dagy,
*  and dagplot installs, then run the whole file.

* adopath ++ "/path/to/nwcommands"
* adopath ++ "/path/to/2026 DAG/software/dagy"
* adopath ++ "/path/to/2026 DAG/software/dagplot"
* run "/path/to/nwcommands/unw_core.do"   // only needed for this dev snapshot of nwcommands

dagy define wage: age -> education ; ability -> education ; ///
	ability -> earnings ; education -> earnings

dagy list
dagy list wage

* which paths connect education and earnings?
dagy path wage education earnings

* are they d-separated once we know ability?
dagy dsep wage education earnings
dagy dsep wage education earnings, given(ability)

* what do we need to control for to identify the effect of education?
dagy adjust wage education earnings
dagy adjust wage education earnings, all

* draw it (nointeractive: this script just wants the static PNG, not the
* interactive viewer that dagy draw otherwise opens by default)
dagy draw wage, exposure(education) outcome(earnings) export("wage_dag.png") replace nointeractive
