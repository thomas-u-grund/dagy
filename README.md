# Thinking Causally with Stata

A working software package, `dagy`, plus a draft Stata Journal article
about it: a Stata command family that lets you define a causal DAG and
compute with it - causal vs. backdoor paths, d-separation, minimal
sufficient back-door and front-door adjustment sets, instrumental-variable
candidates, and testable implications - built on top of `nwcommands` for
graph storage and plotting.

Named `dagy` rather than `dag` to avoid colliding with the existing,
unrelated SSC package literally called `dag` (Chunsen Wu, 2018 -
`ancestor`/`child` commands for DAG simulation).

- `docs/article/dagy.tex` - the Stata Journal article draft.
- `docs/PITCH.md` - background/positioning notes the article draws on
  (originally written for a book pitch; superseded by the article above).
- `docs/idea.docx` - original notes this was sketched from.
- `software/dagy/` - the `dagy` Stata package (source).
- `software/dagplot/` - `dagplot`, a standalone fork of nwcommands'
  `nwplot` (see `software/dagplot/dagplot.ado`'s own header) that `dagy
  draw` plots through instead of `nwplot` directly. Forks the whole
  interactive-viewer pipeline end to end - rendering (`dagplot_template.html`),
  launcher (`_dagplot_openviewer.ado`), and native viewer binary
  (`native/dagplot_viewer.mm` / `plugins/macos/dagplot_viewer`) - so all
  of it can be fixed/edited here without touching `nwcommands` itself.
- `examples/` - runnable `.do` files.

## Requirements

- Stata 16+ (uses frames).
- [`nwcommands`](http://nwcommands.org) installed and on your `adopath`.
  `dagy draw` calls `nwset` directly and `dagplot` (above) for drawing;
  the rest of `dagy` (`define`, `list`, `drop`, `layout`, `path`, `dsep`,
  `adjust`, `frontdoor`, `iv`, `testable`, `cpdag`, `simulate`,
  `estimate`, `sensitivity`) has no dependency on it.
- `software/dagplot/` on your `adopath` too. Unlike an earlier version of
  this fork, `dagplot` no longer depends on any specific `nwcommands`
  build for its interactive viewer - the rendering, launcher, and native
  viewer binary are all bundled with `dagplot` itself; pass
  `nointeractive` to `dagy draw` for a plain static graph instead.

## Try it

```stata
adopath ++ "/path/to/nwcommands"
adopath ++ "/path/to/2026 DAG/software/dagy"
adopath ++ "/path/to/2026 DAG/software/dagplot"

do "/path/to/2026 DAG/examples/ex1_confounding.do"
do "/path/to/2026 DAG/examples/ex2_extensions.do"   // no nwcommands needed
do "/path/to/2026 DAG/examples/ex3_roadmap.do"      // no nwcommands needed
```

## Status

Working v0.4 prototype - the full original roadmap is implemented: back-
door and front-door adjustment, instrumental-variable candidates,
testable implications (optionally checked against real data), an
automatic layered graph layout with manual overrides, Markov-equivalence
classes (CPDAGs), simulating data from the DAG's structural model,
translating an identification result into a Stata estimation command, and
a graphical sensitivity check for back-door adjustment sets. See
`docs/article/dagy.tex` for the full writeup.
