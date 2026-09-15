{smcl}
{* *! version 1.0.0  15sep2026}{...}
{title:Title}

{p2colset 9 15 22 2}{...}
{p2col :{bf:dagy} {hline 2}}A causal-DAG workflow for Stata: define, draw, and reason from directed acyclic graphs{p_end}
{p2colreset}{...}

{title:Syntax}

{p 8 17 2}
{cmd:dagy define} {it:name}{cmd::} {it:edges} [{cmd:,} {opt latent(namelist)} {opt replace}]

{p 8 17 2}
{cmd:dagy list} [{it:name}]

{p 8 17 2}
{cmd:dagy drop} {it:name} {it:|} {cmd:_all}

{p 8 17 2}
{cmd:dagy draw} [{it:name}] [{cmd:,} {opt exposure(name)} {opt outcome(name)} {opt adjust(namelist)} {opt nodesize(#)}]

{p 8 17 2}
{cmd:dagy layout} {it:name} [{cmd:,} {opt orient(horizontal|vertical)} {opt replace}]

{p 8 17 2}
{cmd:dagy layout} {it:name}{cmd::} {it:node x y} [{cmd:;} {it:node x y} {it:...}]

{p 8 17 2}
{cmd:dagy path} [{it:name}] {it:exposure} {it:outcome} [{cmd:,} {opt max(#)}]

{p 8 17 2}
{cmd:dagy dsep} [{it:name}] {it:x} {it:y} [{cmd:,} {opt given(namelist)}]

{p 8 17 2}
{cmd:dagy adjust} [{it:name}] {it:exposure} {it:outcome} [{cmd:,} {opt given(namelist)} {opt all} {opt max(#)} {opt optimal}]

{p 8 17 2}
{cmd:dagy frontdoor} [{it:name}] {it:exposure} {it:outcome} [{cmd:,} {opt given(namelist)} {opt all} {opt max(#)}]

{p 8 17 2}
{cmd:dagy iv} [{it:name}] {it:exposure} {it:outcome} [{it:candidate}] [{cmd:,} {opt given(namelist)}]

{p 8 17 2}
{cmd:dagy testable} [{it:name}] [{cmd:,} {opt observed} {opt test}]

{p 8 17 2}
{cmd:dagy localtests} [{it:name}] [{cmd:,} {opt test} {opt max(#)}]

{p 8 17 2}
{cmd:dagy cpdag} [{it:name}] [{cmd:,} {opt given(edgespec)}]

{p 8 17 2}
{cmd:dagy mag} [{it:name}] [{cmd:,} {opt max(#)}]

{p 8 17 2}
{cmd:dagy simulate} {it:name}{cmd:,} {opt n(#)} [{opt beta(#)} {opt sd(#)} {opt coef(edgespec)} {opt seed(#)} {opt keeplatent} {opt clear}]

{p 8 17 2}
{cmd:dagy estimate} {it:name} {it:exposure} {it:outcome}{cmd:,} ({opt adjust(namelist)} {c |} {opt frontdoor(namelist)} {c |} {opt instrument(name)}) [{opt given(namelist)} {opt run}]

{p 8 17 2}
{cmd:dagy refute} {it:name} {it:exposure} {it:outcome}{cmd:,} ({opt adjust(namelist)} {c |} {opt frontdoor(namelist)} {c |} {opt instrument(name)}) [{opt given(namelist)} {opt reps(#)} {opt frac(#)} {opt seed(#)}]

{p 8 17 2}
{cmd:dagy sensitivity} {it:name} {it:exposure} {it:outcome} [{cmd:,} {opt given(namelist)}]

{p 8 17 2}
{cmd:dagy import} {it:name}{cmd:,} ({opt id(graphid)} {c |} {opt file(filename)}) [{opt replace}]

{title:Description}

{pstd}
{cmd:dagy} lets you write down a causal model as a directed acyclic graph (DAG),
then ask the graph questions that normally require a whiteboard and a copy of
Pearl: which paths between two variables are causal, which are biasing
back-door paths, whether two variables are d-separated given a conditioning
set, which sets of covariates are sufficient (and minimal) to identify a
causal effect by back-door or front-door adjustment, which observed
variables are valid instruments, and which conditional-independence
statements the model implies and could in principle be checked against data.

{pstd}
It is deliberately a thin layer: the graph itself - nodes, directed edges,
ancestors, descendants, reachability, layouts - is represented directly by
{cmd:dagy} itself (as two hidden Stata frames per DAG, plus Mata), with no
dependency on any other package. {cmd:dagy draw} hands that representation
straight to {cmd:dagplot} for drawing - dagy's own minimal, self-contained
interactive (cytoscape.js-based) DAG viewer, bundled alongside {cmd:dagy}
(see {cmd:software/dagplot/}). The causal-inference-specific work
(d-separation, back-door adjustment sets, path classification) is graph
theory implemented directly on top of that representation. {cmd:dagy} never
requires you to know any of this - you never see a {cmd:dagplot} call
directly.

{pstd}
A {cmd:dagy} is identified by a name and stored (as two hidden Stata frames)
for the rest of the session. If you omit {it:name} from {cmd:draw}/
{cmd:path}/{cmd:dsep}/{cmd:adjust}, the most recently defined (or
referenced) DAG is used.

{marker define}{...}
{title:dagy define}

{pstd}
Declares a DAG from an arrow-notation edge list.

{phang2}{cmd:. dagy define m1: age -> education -> earnings ; ability -> education ; ability -> earnings, latent(ability)}{p_end}

{pstd}
Rules:

{phang2}- edges are written {cmd:node -> node}; a chain like {cmd:a -> b -> c} declares two edges, {cmd:a -> b} and {cmd:b -> c}.{p_end}
{phang2}- separate independent edges/chains with a semicolon {cmd:;}.{p_end}
{phang2}- node names follow ordinary Stata name rules and need not exist as variables in the current dataset - a DAG is a theory, not a dataset.{p_end}
{phang2}- {opt latent(namelist)} marks nodes as unobserved; they are drawn hollow/grey and are never offered as candidates by {cmd:dagy adjust}.{p_end}
{phang2}- {opt replace} allows redefining a DAG that already exists.{p_end}
{phang2}- the graph is checked for cycles at definition time; a cyclic graph is refused (it would not be a DAG).{p_end}

{marker list}{...}
{title:dagy list}

{pstd}
With no argument, lists all defined DAGs and marks the current one. With a
name, lists that DAG's edges and any latent nodes.

{marker drop}{...}
{title:dagy drop}

{pstd}
Drops one DAG, or (with {cmd:_all}) every DAG defined this session.

{marker draw}{...}
{title:dagy draw}

{pstd}
Plots the DAG via {cmd:dagplot} (dagy's own minimal, self-contained
interactive viewer - see {cmd:software/dagplot/dagplot.ado}). Nodes are
colored by their role relative to the exposure/outcome/adjustment set you
specify:

{p2colset 9 32 34 2}{...}
{p2col:{it:role}}{it:meaning}{p_end}
{p2col:exposure}the {opt exposure()} variable{p_end}
{p2col:outcome}the {opt outcome()} variable{p_end}
{p2col:adjusted}a variable in {opt adjust()}{p_end}
{p2col:mediator}on a directed path from exposure to outcome{p_end}
{p2col:ancestor of both}an ancestor of both exposure and outcome - a candidate confounder, though not every such ancestor need lie on an open back-door path{p_end}
{p2col:ancestor of exposure}an ancestor of the exposure only{p_end}
{p2col:ancestor of outcome}an ancestor of the outcome only{p_end}
{p2col:unobserved}marked {opt latent()} in {cmd:dagy define}{p_end}
{p2col:other}none of the above{p_end}
{p2colreset}{...}

{phang2}{cmd:. dagy draw m1, exposure(education) outcome(earnings)}{p_end}

{pstd}
Nodes are placed with an automatic layered layout the first time a DAG is
drawn (see {bf:dagy layout} below) - sources near one side, sinks near the
other, with edges flowing consistently instead of a generic force-directed
scramble. That layout is then reused on later {cmd:dagy draw} calls for the
same DAG, so redrawing (e.g. to change colors) doesn't reshuffle the
picture; use {bf:dagy layout} to recompute it or nudge individual nodes.

{pstd}
{opt nodesize(#)} is a convenience shortcut for {cmd:dagplot}'s own
{cmd:nodefactor(#)} (specifying both at once is an error - pick one).

{pstd}
{cmd:dagy draw} always opens {cmd:dagplot}'s interactive viewer - an
in-browser/native cytoscape.js canvas you can pan, zoom, and drag nodes in.
Its toolbar's "Export PNG" button saves a static image of the current view
if you want one for a paper or slide deck; there is no scripted/unattended
static-export path.

{marker layout}{...}
{title:dagy layout}

{pstd}
Computes or adjusts where {cmd:dagy draw} places each node. With no colon
spec, (re)computes an automatic layered ("Sugiyama-style") layout for
every node: each node's rank is its longest path from a source (so causes
consistently precede their effects); a named {opt outcome()} with no
outgoing edges is pinned to the final rank (always safe, since it has no
children to stay left of), so it lands on the right of the picture and is
later centered exactly on the main axis regardless of what else shares
its rank. Edges spanning more than one rank are routed through a chain of
dummy nodes at the intermediate ranks (the standard full-Sugiyama device),
so within a rank, nodes (real and dummy alike) can be ordered by a
barycenter heuristic run over a few passes to reduce - not guarantee-
minimize - edge crossings against the neighboring rank, including such
"skip" edges. Dummy nodes only inform that ordering, though - each
rank's real nodes are then spaced and centered among themselves alone,
so (for instance) a mediator with two same-rank parents sits exactly
halfway between them regardless of any skip edge passing through its
rank; a real node is nudged off that natural position only if it would
otherwise sit almost exactly on some skip edge's own rendered line (the
case a long run of single-node ranks needs, so such an edge stays
visible instead of hiding underneath them). {opt orient(horizontal)}
(the default) lays ranks out
left-to-right; {opt orient(vertical)} lays them out top-to-bottom.

{phang2}{cmd:. dagy layout m1}{p_end}
{phang2}{cmd:. dagy layout m1, orient(vertical)}{p_end}

{pstd}
{cmd:dagy draw} computes this automatically the first time a DAG is drawn,
so this command is only needed to recompute it (e.g. after switching
{opt orient()}) or to override specific node positions:

{phang2}{cmd:. dagy layout m1: ability 0 2}{p_end}
{phang2}{cmd:. dagy layout m1: ability 0 2 ; age -1 -2}{p_end}

{pstd}
Each {it:node x y} pins that one node's coordinates and marks it as fixed;
every other node keeps its current (automatic or previously pinned)
position. Re-running {cmd:dagy layout {it:name}} with no colon spec
refuses to discard existing pinned positions unless {opt replace} is
given.

{marker path}{...}
{title:dagy path}

{pstd}
Lists every simple path between {it:exposure} and {it:outcome} in the DAG's
skeleton (edges considered undirected), grouped into:

{phang2}- {bf:causal paths}: directed paths from exposure to outcome.{p_end}
{phang2}- {bf:backdoor paths}: paths that begin with an arrow pointing into the exposure.{p_end}
{phang2}- {bf:other non-causal paths}: paths that leave the exposure along a causal edge but do not reach the outcome directly (they run through a collider).{p_end}

{phang2}{cmd:. dagy path m1 education earnings}{p_end}

{marker dsep}{...}
{title:dagy dsep}

{pstd}
Tests whether {it:x} and {it:y} are d-separated given the (possibly empty)
{opt given()} set - i.e. whether the DAG implies they are conditionally
independent.

{phang2}{cmd:. dagy dsep m1 education earnings, given(ability)}{p_end}

{marker adjust}{...}
{title:dagy adjust}

{pstd}
Searches for back-door adjustment sets: sets of variables Z such that (a) no
member of Z is a descendant of the exposure and (b) Z blocks every back-door
path from exposure to outcome. Reports the minimal sufficient sets by
default; {opt all} also lists every sufficient set found.

{phang2}{cmd:. dagy adjust m1 education earnings}{p_end}

{pstd}
{opt given(namelist)} fixes variables that must be in every set considered
(e.g. covariates you will adjust for on substantive grounds regardless);
{cmd:dagy adjust} then searches the remaining candidates for what else, if
anything, is needed. {opt max(#)} (default 18) caps the number of free
candidate variables that will be enumerated (2{superscript:k} sets are
tested); raise it for larger DAGs at the cost of runtime, or use
{opt given()} to fix known covariates and shrink the search.

{pstd}
{opt optimal} additionally reports the optimal adjustment set - the
valid back-door set that minimizes asymptotic estimator variance, not
merely one with the fewest variables (the DAG-only case of Perkovic et
al.'s / Henckel-Perkovic-Maathuis's result): the parents of every
mediator plus the outcome, excluding the exposure and its own
descendants. Flagged as not usable if it contains a latent node.

{marker frontdoor}{...}
{title:dagy frontdoor}

{pstd}
Searches for front-door adjustment sets: sets of mediators M such that (a) M
intercepts every directed path from {it:exposure} to {it:outcome}, (b) there
is no unblocked back-door path from {it:exposure} to M, and (c)
{it:exposure} blocks every back-door path from M to {it:outcome}. When these
hold, the causal effect of {it:exposure} on {it:outcome} is identified even
if {it:exposure} and {it:outcome} share unmeasured confounders, provided the
mediator(s) in M are fully observed. Reports the minimal sufficient sets by
default; {opt all} also lists every sufficient set found. {opt given()} and
{opt max()} behave exactly as in {cmd:dagy adjust}.

{phang2}{cmd:. dagy frontdoor m1 smoking cancer}{p_end}

{pstd}
A direct edge {it:exposure} {cmd:->} {it:outcome} always makes this report
no valid set, since no mediator set can intercept a path that skips it.

{marker iv}{...}
{title:dagy iv}

{pstd}
Searches for instrumental-variable candidates for the effect of
{it:exposure} on {it:outcome}: observed, non-descendants-of-{it:exposure}
nodes Z satisfying the graphical instrumental-variable criterion (the same
mutilated-graph test used by the dagitty software's
{cmd:instrumentalVariables()} function): Z must be associated with {it:exposure}
({bf:relevance}), and Z must be d-separated from {it:outcome} once
{it:exposure}'s own outgoing edges are removed ({bf:exclusion restriction} -
Z's only route of association with {it:outcome} runs through {it:exposure}).
{opt given(namelist)} conditions both tests on a fixed covariate set.

{phang2}{cmd:. dagy iv m1 education wage}{p_end}

{pstd}
With a third positional argument, {cmd:dagy iv} instead tests one named
candidate and reports which of the two conditions holds or fails, e.g.:

{phang2}{cmd:. dagy iv m1 education wage distance}{p_end}

{marker testable}{...}
{title:dagy testable}

{pstd}
Lists the conditional-independence implications entailed by the DAG: for
every node, its independence from its non-descendants (excluding its own
parents) given its parents - the standard "local Markov" generating set,
which together with the semigraphoid axioms entails every other
d-separation implied by the model. Statements involving a latent node are
marked as not directly testable against observed data; {opt observed}
restricts the listing to fully testable statements only.

{phang2}{cmd:. dagy testable m1}{p_end}

{pstd}
{opt test} additionally checks each testable implication against the
current dataset in memory: for {cmd:v _||_ \{vanish\} | \{pa\}}, it runs
{cmd:regress v pa vanish} and reports the p-value from a joint test that
the vanishing set's coefficients are zero. Requires variables named like
the DAG's nodes to be loaded (e.g. from {cmd:dagy simulate}); an
implication is reported as "(no matching data loaded)" if they are not.

{phang2}{cmd:. dagy testable m1, test}{p_end}

{marker localtests}{...}
{title:dagy localtests}

{pstd}
The comprehensive counterpart to {cmd:dagy testable}: for every pair
of non-adjacent nodes, searches for a separating set (any one that
works, not necessarily minimal - {opt max(#)}, default 18, bounds the
search the same way it does in {cmd:dagy adjust}) rather than only
the cheaper local-Markov generating set {cmd:dagy testable} reports.
More implications, at the cost of a bounded search per pair. {opt test}
checks each one against the current dataset exactly as
{cmd:dagy testable, test} does.

{phang2}{cmd:. dagy localtests m1}{p_end}
{phang2}{cmd:. dagy localtests m1, test}{p_end}

{marker cpdag}{...}
{title:dagy cpdag}

{pstd}
Reports the DAG's Markov-equivalence class (its CPDAG): which edges are
compelled to a specific direction by the conditional-independence
structure alone, and which could point either way and still imply the
exact same pattern of independencies. An edge is compelled if it takes
part in an unshielded collider (two non-adjacent parents of a common
child) or if Meek's propagation rules R1-R2 force it given the
compelled edges already found; everything else is reported as
undirected. R3/R4 (rarer four-node patterns) are not implemented, so the
result is correct but can occasionally be more conservative than a
complete implementation - an edge a complete version would also orient
may be left undirected here.

{phang2}{cmd:. dagy cpdag m1}{p_end}

{pstd}
{opt given(edgespec)} supplies background knowledge - edge directions
you already know for some other reason - in the same arrow notation as
{cmd:dagy define} (e.g. {cmd:given(a->b)}, or several separated by
{cmd:;}). Each must already be an edge of the DAG's skeleton in that
direction. These are seeded as compelled before v-structure detection
runs, so Meek's rules can propagate from a larger starting set than the
v-structures alone would give (mirroring dagitty's {cmd:orientPDAG}) -
occasionally orienting edges that would otherwise be left undirected.

{phang2}{cmd:. dagy cpdag m1, given(a -> b)}{p_end}

{marker mag}{...}
{title:dagy mag}

{pstd}
Latent projection: collapses a DAG with latent nodes down to a MAG
(Maximal Ancestral Graph) over only the observed nodes, the
representation of "what the causal structure looks like from the data
you actually have." Two observed nodes are MAG-adjacent iff no subset
of the other observed nodes d-separates them in the full original graph
(latents included) - tested directly, bounded by {opt max(#)} (default
18) the same way {cmd:dagy adjust} bounds its own search, but here
over the number of other observed variables. An adjacent pair is
directed (a -> b) if one is a true ancestor of the other in the full
graph; otherwise it is bidirected (a <-> b), meaning unmeasured
confounding survives the projection. No selection-variable / undirected-
edge support.

{phang2}{cmd:. dagy mag m1}{p_end}

{marker simulate}{...}
{title:dagy simulate}

{pstd}
Draws data from a linear-Gaussian structural model implied by the DAG:
every node's value is a coefficient-weighted sum of its parents plus
{cmd:N(0,sd)} noise, generated in topological order. Node names become
the actual Stata variable names, so the result is immediately usable
with ordinary estimation commands. {opt beta(#)} (default 1) sets the
coefficient on every edge; {opt coef(edgespec)} overrides specific edges
in the same arrow notation as {cmd:dagy define}, e.g.
{cmd:coef(ability->education 2 ; ability->earnings 3)}. {opt sd(#)}
(default 1) sets every node's noise standard deviation. Latent nodes are
simulated internally - so they still induce confounding among the
observed variables - but dropped from the final dataset by default,
matching "unobserved"; {opt keeplatent} keeps them. {opt seed(#)} sets
the random-number seed. Replaces the dataset in memory, refusing to do
so unless {opt clear} is given (same convention as {help clear}).

{phang2}{cmd:. dagy simulate m1, n(1000) clear}{p_end}
{phang2}{cmd:. regress earnings education ability}{p_end}

{marker estimate}{...}
{title:dagy estimate}

{pstd}
Translates an already-identified strategy into the Stata estimation
command it implies, after checking that the strategy is actually valid
for this DAG (using the same graphical tests {cmd:dagy adjust}/
{cmd:dagy frontdoor}/{cmd:dagy iv} use, applied directly to the
one set or candidate given rather than searching). Exactly one of
{opt adjust()}, {opt frontdoor()}, or {opt instrument()} must be given:

{p2colset 9 28 30 2}{...}
{p2col:{opt adjust(namelist)}}back-door adjustment - suggests {cmd:regress outcome exposure namelist}{p_end}
{p2col:{opt frontdoor(namelist)}}front-door adjustment - suggests the two-regression linear product-of-coefficients estimator{p_end}
{p2col:{opt instrument(name)}}instrumental variables - suggests {cmd:ivregress 2sls outcome (exposure = name)}{p_end}
{p2colreset}{...}

{pstd}
{opt given(namelist)} adds extra covariates to the suggested command(s).
By default the command is only printed; {opt run} executes it (or, for
{opt frontdoor()}, both regressions) against the current dataset and, for
{opt frontdoor()}, also computes and displays the product-of-coefficients
point estimate.

{phang2}{cmd:. dagy estimate m1 education earnings, adjust(ability) run}{p_end}

{marker refute}{...}
{title:dagy refute}

{pstd}
Three refutation checks for an already-identified strategy (mirroring
DoWhy's signature feature), each run {opt reps(#)} times (default 100)
against the current dataset in memory - the same strategy options
({opt adjust()}/{opt frontdoor()}/{opt instrument()}, plus
{opt given()}) as {cmd:dagy estimate}, which supplies the baseline
estimate and validates the strategy once up front:

{p2colset 9 22 24 2}{...}
{p2col:placebo}the exposure is randomly permuted (breaking any real
relationship to the outcome) and re-estimated; the resulting effect
should be small - a p-value is the share of reps whose |placebo effect|
matches or exceeds the real |baseline effect|{p_end}
{p2col:random common cause}a fresh {cmd:N(0,1)} covariate is added and
re-estimated; the effect should barely move{p_end}
{p2col:subsample}re-estimated on a random {opt frac(#)} (default 0.9)
subsample; the effect should stay stable{p_end}
{p2colreset}{...}

{phang2}{cmd:. dagy refute m1 education earnings, adjust(ability) reps(100)}{p_end}

{pstd}
For {opt instrument()}, the placebo check can show a very large, noisy
effect by construction: a purely random placebo exposure is (correctly)
almost uncorrelated with the instrument, so the first stage is weak and
the resulting 2SLS ratio is numerically unstable - this reflects a real
property of the estimator, not a bug in the check.

{marker sensitivity}{...}
{title:dagy sensitivity}

{pstd}
A graphical robustness check for a back-door adjustment set - not the
quantitative bias-formula sensitivity analysis of, e.g., Cinelli and
Hazlett (2020). For {opt given()} (or, if omitted, the first minimal
sufficient set {cmd:dagy adjust} finds), tests whether a single
hypothetical unmeasured confounder linking {it:exposure} or {it:outcome}
to one of the adjustment variables - or {it:exposure} directly to
{it:outcome} - would break that set's sufficiency.

{phang2}{cmd:. dagy sensitivity m1 education earnings}{p_end}

{marker import}{...}
{title:dagy import}

{pstd}
Loads a DAG from dagitty model text - the format dagitty.net's own
"Model code" panel produces - rather than typing out {cmd:dagy
define}'s arrow syntax by hand. Only plain {cmd:dag { }} models are
supported, not {cmd:pdag { }}/{cmd:mag { }} (those have undirected or
bidirected edges this package doesn't represent). Exactly one of:

{p2colset 9 20 22 2}{...}
{p2col:{opt id(graphid)}}fetches the model live from dagitty.net (the
same {cmd:http://dagitty.net/dags/load.php?id=} endpoint dagitty's own R
package uses); accepts a bare id or a pasted {cmd:dagitty.net/m...} URL{p_end}
{p2col:{opt file(filename)}}reads model text already saved to a local
file (e.g. pasted from the dagitty.net UI) - no network needed{p_end}
{p2colreset}{...}

{phang2}{cmd:. dagy import m1, file(mymodel.txt)}{p_end}
{phang2}{cmd:. dagy import m1, id(z-Tuw9) replace}{p_end}

{pstd}
Node attributes {cmd:exposure}/{cmd:outcome} are read and reported
(informationally - they aren't stored as part of the DAG itself, since
{cmd:dagy}'s other subcommands take exposure/outcome as arguments
each time); {cmd:latent} sets {opt latent()} exactly as
{cmd:dagy define} would. A {cmd:pos="x,y"} position, if present for
every node, is imported as the DAG's layout (see {cmd:dagy layout}),
preserving the source model's arrangement instead of computing a new
one. A node with no edges at all is silently dropped, matching
{cmd:dagy define}'s own edge-list-only model.

{title:Examples}

{pstd}Classic confounding vs. mediation set-up:{p_end}

{phang2}{cmd:. dagy define wage: ability -> education, ability -> earnings ; education -> earnings, latent(ability)}{p_end}
{phang2}{cmd:. dagy path wage education earnings}{p_end}
{phang2}{cmd:. dagy adjust wage education earnings}{p_end}
{phang2}{cmd:. dagy draw wage, exposure(education) outcome(earnings)}{p_end}

{title:Also see}

{psee}
{cmd:dagplot} (dagy's own bundled interactive viewer - see
{cmd:software/dagplot/dagplot.ado})
{p_end}
