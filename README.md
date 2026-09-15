# Thinking Causally with Stata

A working software package, `dagy`, plus a draft Stata Journal article
about it: a Stata command family that lets you define a causal DAG and
compute with it - causal vs. backdoor paths, d-separation, minimal
sufficient back-door and front-door adjustment sets, instrumental-variable
candidates, and testable implications - with its own graph storage
(Stata frames + Mata) and its own interactive plotting engine. No
dependency on `nwcommands`, or on any other external package, of any
kind.

Named `dagy` rather than `dag` to avoid colliding with the existing,
unrelated SSC package literally called `dag` (Chunsen Wu, 2018 -
`ancestor`/`child` commands for DAG simulation).

- `docs/article/dagy.tex` - the Stata Journal article draft.
- `docs/PITCH.md` - background/positioning notes the article draws on
  (originally written for a book pitch; superseded by the article above).
- `docs/idea.docx` - original notes this was sketched from.
- `software/dagy/` - the `dagy` Stata package (source).
- `software/dagplot/` - `dagplot`, dagy's own minimal, self-contained
  interactive (cytoscape.js-based) graph viewer that `dagy draw` plots
  through (see `software/dagplot/dagplot.ado`'s own header). No "network
  object" model, no static-plot output, no if/in filtering - just what
  `dagy draw` needs: a directed adjacency matrix, node colors/labels, a
  caller-supplied layout, and the interactive viewer (rendering
  (`dagplot_template.html`), launcher (`_dagplot_openviewer.ado`), and
  native viewer binary (`native/dagplot_viewer.mm` /
  `plugins/macos/dagplot_viewer`)).
- `examples/` - runnable `.do` files.

## Requirements

- Stata 16+ (uses frames).
- `software/dagy/` and `software/dagplot/` on your `adopath`. Nothing
  else - no `nwcommands`, no SSC packages.

## Try it

```stata
adopath ++ "/path/to/2026 DAG/software/dagy"
adopath ++ "/path/to/2026 DAG/software/dagplot"

do "/path/to/2026 DAG/examples/ex1_confounding.do"
do "/path/to/2026 DAG/examples/ex2_extensions.do"
do "/path/to/2026 DAG/examples/ex3_roadmap.do"
```

## Status

Working v1.0 prototype - the full original roadmap is implemented: back-
door and front-door adjustment, instrumental-variable candidates,
testable implications (optionally checked against real data), an
automatic layered graph layout with manual overrides, Markov-equivalence
classes (CPDAGs), simulating data from the DAG's structural model,
translating an identification result into a Stata estimation command, and
a graphical sensitivity check for back-door adjustment sets. See
`docs/article/dagy.tex` for the full writeup (currently still describing
the earlier `nwcommands`-based version - due for an update to match).

`dagy draw`'s interactive viewer now round-trips: add/delete nodes and
edges (and a Latent toggle) directly in the viewer, then its "Export
DAG" button writes a dagitty model file that `dagy import <name>,
file("...") replace` loads back for real - no separate Stata-side
importer needed, it reuses `dagy import`'s existing dagitty parser. A
node with no edges at all is dropped on import (`dagy`'s DAGs are
edge-lists only), so connect a new node to something before exporting.
