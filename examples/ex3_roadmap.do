*  Example 3: CPDAG, simulation, identification -> estimator, sensitivity.
*
*  Edit the adopath line below to point at your own dagy install,
*  then run the whole file. dagy has no external dependency of any kind.

* adopath ++ "/path/to/2026 DAG/software/dagy"

*----------------------------------------------------------------------
* Part 1: CPDAG. wage's two unshielded colliders at `education' (age,
* ability -> education, with age/ability not adjacent) pin down every
* edge's direction - contrast with a plain chain, which has none.
*----------------------------------------------------------------------
dagy define wage: age -> education ; ability -> education ; ///
	ability -> earnings ; education -> earnings

dagy cpdag wage

dagy define chain: a -> b -> c
dagy cpdag chain

*----------------------------------------------------------------------
* Part 2: simulate data from wage's structural model, then show the
* confounding `ability' causes when you forget to control for it - and
* that dagy testable's own implications actually hold in the simulated
* data.
*----------------------------------------------------------------------
dagy simulate wage, n(5000) seed(42) clear

regress earnings education            // biased: omits the confounder
regress earnings education ability     // recovers the true effect

dagy testable wage, test

*----------------------------------------------------------------------
* Part 3: identification -> estimator, for all three strategies.
*----------------------------------------------------------------------
dagy estimate wage education earnings, adjust(ability) run

dagy define smoking: smoking -> tar -> cancer ; ///
	genotype -> smoking ; genotype -> cancer, latent(genotype)
dagy simulate smoking, n(5000) seed(7) clear keeplatent
dagy estimate smoking smoking cancer, frontdoor(tar) run

dagy define wage2: distance -> education -> wage ; ///
	ability -> education ; ability -> wage, latent(ability)
dagy simulate wage2, n(5000) seed(11) clear keeplatent
dagy estimate wage2 education wage, instrument(distance) run

*----------------------------------------------------------------------
* Part 4: sensitivity of wage's {ability} adjustment set. A hypothetical
* confounder of education and earnings directly always breaks back-door
* identification, no matter what else you control for.
*----------------------------------------------------------------------
dagy sensitivity wage education earnings
