{smcl}
{* *! version 1.0.0  15sep2026}{...}
{title:Title}

{p2colset 9 17 22 2}{...}
{p2col :{bf:dagplot} {hline 2}}dagy's own minimal, self-contained interactive graph viewer{p_end}
{p2colreset}{...}

{title:Syntax}

{p 8 17 2}
{cmd:dagplot ,} {opt adjmatrix(matname)} {opt nodename(varname)} {opt nodexy(xvar yvar)} [{opt lab} {opt arrows} {opt color(varname)} {opt colorpalette(colorlist)} {opt nodefactor(#)} {opt scheme(schemename)} {opt noopen}]

{title:Description}

{pstd}
{cmd:dagplot} renders the dataset currently in memory - one observation
per node, in the same row order as {opt adjmatrix()}'s rows/columns - as
an interactive (cytoscape.js-based) graph you can pan, zoom, and drag
nodes in, in a browser tab or (on macOS) a small native viewer window.
It has no dependency on {cmd:nwcommands}, or on any other package, of any
kind: {opt adjmatrix()} is a plain Stata matrix, not a "network" object
from some other command.

{pstd}
It is {cmd:dagy draw}'s own plotting engine (see {help dagy##draw:dagy
draw}) and is deliberately narrow: one node-color grouping variable, a
caller-supplied layout, the interactive viewer, nothing else. There is no
static-plot output, no if/in filtering, no movie export, and no CSV
edge-import round trip - if you need any of those, look at
{cmd:nwcommands}' own {cmd:nwplot} instead.

{title:Options}

{phang}{opt adjmatrix(matname)} names a square Stata matrix, {it:nodes} x
{it:nodes}, giving the directed adjacency: a nonzero entry at row i,
column j means an edge from node i to node j. Required.

{phang}{opt nodename(varname)} the string (or numeric) variable holding
each node's display name, used when {opt lab} is given. Required.

{phang}{opt nodexy(xvar yvar)} each node's plotted position. Required -
{cmd:dagplot} computes no layout of its own; see {cmd:dagy layout} for
how {cmd:dagy draw} supplies one.

{phang}{opt lab} labels each node with {opt nodename()}'s value.

{phang}{opt arrows} draws directed arrowheads (omit for an undirected
look).

{phang}{opt color(varname)} nodes sharing a value of this variable are
grouped and colored together, in ascending sort order of that value.
Without it, every node gets the same color.

{phang}{opt colorpalette(colorlist)} a space-separated list of Stata
color names (e.g. {cmd:orange navy ltblue ...}), one per {opt color()}
group in ascending order (recycled if there are more groups than
colors given). Without it, colors fall back to the ambient graph
{opt scheme()}'s own sequence.

{phang}{opt nodefactor(#)} scales node (and arrowhead-trim) size;
default 1.

{phang}{opt scheme(schemename)} the Stata graph scheme used to resolve
{opt colorpalette()} entries (and, without one, the fallback
scheme-relative colors) to concrete RGB for the browser. Default
{cmd:s2color}, Stata's own built-in scheme.

{phang}{opt noopen} builds the interactive HTML file (see
{cmd:return list}'s {cmd:r(interactive)}) but does not launch a viewer
for it - e.g. for scripted/headless runs.

{title:Example}

{phang2}{cmd:. matrix A = (0,1 \ 0,0)}{p_end}
{phang2}{cmd:. clear}{p_end}
{phang2}{cmd:. set obs 2}{p_end}
{phang2}{cmd:. gen name = cond(_n==1,"x","y")}{p_end}
{phang2}{cmd:. gen x = cond(_n==1,0,1)}{p_end}
{phang2}{cmd:. gen y = 0.5}{p_end}
{phang2}{cmd:. dagplot, adjmatrix(A) nodename(name) nodexy(x y) lab arrows}{p_end}

{title:Also see}

{psee}
{help dagy}
{p_end}
