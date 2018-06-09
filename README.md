# Nauty.jl

Simple wrapper for using `nauty`, a graph isomorphism package, with `LightGraphs` in Julia. Requires `gcc` and a POSIX style build environment.

## Example usage

Check if two graphs are isomorphs of each other:

```julia
baked_canonical_form(g1).canong == baked_canonical_form(g2).canong
```

If you need to provide custom options to nauty, use `densenauty(g, optionblk(optionblk_mutable(DEFAULTOPTIONS_GRAPH)))`, but be aware that it is around 2-4x slower than using baked in options as Julia cannot optimise across the `C` boundary. Consider baking your own. 

## Todo

 - Friendlier return types
 - NautyGraph -> LightGraph
 - MetaGraph -> (NautyGraph, labels, partition)
 - isomorphOf() / congruence operator
 - Documentation (documenter.jl)
 - Pick a licence
 - More comprehensive tests if we feel like it
 - Build options
    - Test `MAXN=WORDSIZE` optimisation effect. Build nauty twice if it matters, once with MAXN=0 if not
 - Use baked_canonical_form automatically

## API

canonical_isomorph(g: LightGraph) -> g'
canonical_isomorph(g: ColouredGraph) -> g'
    - We'll have to use the relabelling information to make g'

isisomorph(g1, g2) -> bool
operator overload (congruence sign?)

nauty(g, options) -> all the stuff nauty gives
