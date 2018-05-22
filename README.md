# Nauty.jl

Simple wrapper for using `nauty` with `LightGraphs` in Julia. Requires `gcc` and a POSIX style build environment.

## Todo

 - Pass options to nauty
    - Eventually let us use coloured graphs
    - Other options might be useful to someone
 - Friendlier return types
 - isomorphOf() / congruence.jl
 - Documentation (documenter.jl)
 - Pick a licence
 - Tests if we feel like it
 - Build options
 - Test MAXN=WORDSIZE optimisation effect. Build nauty twice if it matters, once with MAXN=0 if not

## API

canonical_isomorph(g: LightGraph) -> g'
canonical_isomorph(g: ColouredGraph) -> g'
    - We'll have to use the relabelling information to make g'

isisomorph(g1, g2) -> bool
operator overload (congruence sign?)

nauty(g, options) -> all the stuff nauty gives
