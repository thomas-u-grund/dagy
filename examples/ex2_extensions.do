*  Example 2: front-door adjustment, instrumental variables, testable
*  implications.
*
*  Edit the adopath line below to point at your own dagy install, then
*  run the whole file. Unlike ex1, nothing here calls `dagy draw`, so
*  no nwcommands install is required.

* adopath ++ "/path/to/2026 DAG/software/dagy"

*----------------------------------------------------------------------
* Part 1: front-door adjustment. Classic Pearl smoking/tar/cancer set-up -
* an unmeasured genotype confounds smoking and cancer directly, so no
* back-door adjustment set exists; tar mediates all of smoking's effect
* on cancer and is unconfounded with either, so it identifies the effect
* by the front-door criterion instead.
*----------------------------------------------------------------------
dagy define smoking: smoking -> tar -> cancer ; ///
	genotype -> smoking ; genotype -> cancer, latent(genotype)

dagy adjust smoking smoking cancer
dagy frontdoor smoking smoking cancer

*----------------------------------------------------------------------
* Part 2: instrumental variables. Distance to college affects education
* but not wage directly; unmeasured ability confounds education and wage.
*----------------------------------------------------------------------
dagy define wage2: distance -> education -> wage ; ///
	ability -> education ; ability -> wage, latent(ability)

* search every eligible node
dagy iv wage2 education wage

* test one candidate in detail
dagy iv wage2 education wage distance

* ability is latent and cannot be an instrument; education itself cannot
* be its own instrument. Try a variable that fails the exclusion
* restriction by adding a direct effect on wage:
dagy define wage3: distance -> education -> wage ; distance -> wage ; ///
	ability -> education ; ability -> wage, latent(ability)

dagy iv wage3 education wage distance

*----------------------------------------------------------------------
* Part 3: testable implications, using ex1's confounding/mediation DAG.
*----------------------------------------------------------------------
dagy define wage: age -> education ; ability -> education ; ///
	ability -> earnings ; education -> earnings

dagy testable wage
dagy testable wage, observed
