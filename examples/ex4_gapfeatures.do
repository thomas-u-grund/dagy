*  Example 4: refutation tests, dagitty import, optimal adjustment,
*  MAG conversion, comprehensive local tests, background-knowledge CPDAG.
*
*  Edit the adopath line below to point at your own dagy install,
*  then run the whole file. Nothing here calls `dagy draw`, so no
*  nwcommands install is required. Part 2 reads a local file shipped
*  alongside this example (adjust the path if you moved it) rather than
*  fetching from dagitty.net live, so it works with no network access.

* adopath ++ "/path/to/2026 DAG/software/dagy"

*----------------------------------------------------------------------
* Part 1: refutation tests for an already-identified estimate. Simulate
* from the DAG's own structural model, then check the back-door
* estimate survives a placebo (randomly permuted) exposure, a random
* extra covariate, and subsampling.
*----------------------------------------------------------------------
dagy define wage: age -> education ; ability -> education ; ///
	ability -> earnings ; education -> earnings

dagy simulate wage, n(3000) seed(99) clear
dagy refute wage education earnings, adjust(ability) reps(50) seed(1)

*----------------------------------------------------------------------
* Part 2: import a DAG from dagitty model text. dagitty.net's own
* "Model code" panel produces exactly this format; here it's read from
* a local file (no network needed) - the same file() option also
* accepts model text copied straight from that panel and saved to disk.
* A live fetch by graph id is also supported: `dagy import <name>,
* id(graphid)`, fetching http://dagitty.net/dags/load.php?id=<id> (the
* same endpoint dagitty's own R package uses) and base64-decoding the
* response.
*----------------------------------------------------------------------
* file wage_dagitty.txt (same folder as this .do file) contains:
*   dag {
*   bb="0,0,1,1"
*   age [pos="0.1,0.1"]
*   ability [pos="0.1,0.9"]
*   education [exposure,pos="0.5,0.5"]
*   earnings [outcome,pos="0.9,0.5"]
*   age -> education
*   ability -> education
*   ability -> earnings
*   education -> earnings
*   }
dagy import wageimp, file("wage_dagitty.txt")
dagy list wageimp
dagy adjust wageimp education earnings

*----------------------------------------------------------------------
* Part 3: optimal adjustment set. wage has two sufficient back-door
* sets, {ability} and {age ability}; the optimal one (minimizing
* asymptotic estimator variance, not just smallest) is {ability}.
*----------------------------------------------------------------------
dagy adjust wage education earnings, all optimal

*----------------------------------------------------------------------
* Part 4: MAG conversion. smoking's latent genotype still lets smoking
* be a true ancestor of cancer (via tar), so that edge stays directed;
* a DAG where a latent variable confounds two otherwise-unconnected
* nodes shows the bidirected case instead.
*----------------------------------------------------------------------
dagy define smoking: smoking -> tar -> cancer ; ///
	genotype -> smoking ; genotype -> cancer, latent(genotype)
dagy mag smoking

dagy define confound: U -> A ; U -> B, latent(U)
dagy mag confound

*----------------------------------------------------------------------
* Part 5: comprehensive pairwise local tests, contrasted with
* testable's cheaper local-Markov set on the same DAG.
*----------------------------------------------------------------------
dagy testable wage
dagy localtests wage

*----------------------------------------------------------------------
* Part 6: background-knowledge CPDAG orientation. A plain 3-chain has no
* v-structure, so its CPDAG is fully undirected; asserting just one edge
* direction is enough for Meek's rules to recover the other.
*----------------------------------------------------------------------
dagy define chain: a -> b -> c
dagy cpdag chain
dagy cpdag chain, given(a -> b)
