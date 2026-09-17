# dagy

A Stata command family for computing with causal DAGs: causal vs.
backdoor paths, d-separation, minimal sufficient back-door and
front-door adjustment sets, instrumental-variable candidates, and
testable implications - with its own graph storage (Stata frames +
Mata) and its own interactive plotting engine, `dagplot`.

No dependency on `nwcommands`, or on any other external package, of
any kind.

Named `dagy` rather than `dag` to avoid colliding with the existing,
unrelated SSC package literally called `dag` (Chunsen Wu, 2018 -
`ancestor`/`child` commands for DAG simulation).

## What's in this repo

- `software/dagy/` - the `dagy` Stata package (source): define a DAG,
  compute paths/adjustment sets/d-separation, simulate data from it,
  check testable implications, translate an identification result
  into a Stata estimation command, sensitivity analysis, CPDAGs. Also
  ships `dagy_install`, a one-time setup helper (see Installation).
- `software/dagplot/` - `dagy`'s own minimal, self-contained
  interactive (cytoscape.js-based) graph viewer that `dagy draw`
  plots through. No "network object" model, no static-plot output,
  no if/in filtering - just what `dagy draw` needs: a directed
  adjacency matrix, node colors/labels, a caller-supplied layout, and
  an interactive viewer you can edit in (add/delete nodes and edges,
  export back to `dagy` as a real DAG).
- `examples/` - runnable `.do` files demonstrating the package.

## Requirements

- Stata 16 or later (the package uses frames).
- No other Stata packages required - no `nwcommands`, no SSC
  installs.

## Installation

Run these two lines once, from within Stata:

```stata
net install dagy, from("https://raw.githubusercontent.com/thomas-u-grund/dagy/main/software/dagy/") replace
dagy_install
```

The second line is a bundled helper command, not a separate package -
plain `net install` only fetches recognized Stata program files
(`.ado`/`.sthlp`), not the `dagplot` viewer's HTML/JS/binary rendering
assets, so `dagy_install` installs the companion `dagplot` package and
then downloads those assets to exactly where it expects to find them
(see `software/dagy/dagy_install.ado`'s own header for why that needs
a real command rather than Stata's own `net get`). Everything lands in
your personal Stata `ado` directory, already on your `adopath` - no
manual `adopath` line to add or remember in future sessions. Confirm
it worked:

```stata
which dagy
which dagplot
```

To update later, re-run `net install dagy, ... replace` followed by
`dagy_install`.

### Alternative: run from a local clone

If you'd rather work from a local copy of this repo instead (e.g. to
read or edit the source):

```stata
adopath ++ "/path/to/dagy/software/dagy"
adopath ++ "/path/to/dagy/software/dagplot"
```

Replace `/path/to/dagy` with wherever you cloned this repository. On
Windows, forward slashes work fine in `adopath` too, e.g.
`adopath ++ "C:/Users/you/dagy/software/dagy"`.

## Try it

```stata
do "/path/to/dagy/examples/ex1_confounding.do"
do "/path/to/dagy/examples/ex2_extensions.do"
do "/path/to/dagy/examples/ex3_roadmap.do"
```

(Adjust the path, or skip the `do` prefix and just run the examples
directly, if you installed via `net install` rather than a local
clone - you'll need to download the `examples/` folder separately in
that case, since installation only fetches the Stata packages.)

`dagy draw` opens an interactive viewer window. On macOS this is a
self-contained native chromeless window; on Windows and Linux (no
native viewer binary shipped yet) it opens the same interactive
viewer in your default web browser instead - drawing, editing, and
exporting all work the same way there, just inside a browser tab
rather than a standalone window.

## Status

Working v1.0 prototype - the full original roadmap is implemented:
back-door and front-door adjustment, instrumental-variable
candidates, testable implications (optionally checked against real
data), an automatic layered graph layout with manual overrides,
Markov-equivalence classes (CPDAGs), simulating data from the DAG's
structural model, translating an identification result into a Stata
estimation command, and a graphical sensitivity check for back-door
adjustment sets.

`dagy draw`'s interactive viewer round-trips: add/delete nodes and
edges (and a Latent toggle) directly in the viewer, then its "Export
DAG" button writes a dagitty model file that `dagy import <name>,
file("...") replace` loads back for real - no separate importer
needed, it reuses `dagy import`'s own dagitty parser. A node with no
edges at all is dropped on import (`dagy`'s DAGs are edge-lists
only), so connect a new node to something before exporting.
