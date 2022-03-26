"Julia wrapper for the Nauty C library."
module Nauty

using Libdl: dlext
import LightGraphs
import MetaGraphs

export has_isomorph, NautyAlg

@static if VERSION < v"0.7.0-DEV.2005"
    Cvoid = Base.Void
    Base.BitArray(x, y...) = BitArray(y...)
    undef = Base.Void
end

function depsdir(pkg::AbstractString)
    pkgdir = Base.find_package(pkg)
    return abspath(joinpath(dirname(pkgdir), "..", "deps"))
end

const LIB_FILE = joinpath(depsdir("Nauty"), "minnautywrap." * dlext) 

include("types.jl")

const WORDSIZE = ccall((:wordsize, LIB_FILE), Int, ())

# For small graphs, creating the optionblk may take as long as finding the
# canonical form, so we do that work in advance.
const DEFAULTOPTIONS_GRAPH = optionblk(defaultoptions_graph())
const DEFAULTOPTIONS_DIGRAPH = optionblk(defaultoptions_digraph())
const GETCANON_OPTIONS_GRAPH = let
  o = defaultoptions_graph()
  o.getcanon = 1
  optionblk(o)
end
const GETCANON_OPTIONS_DIGRAPH = let
  o = defaultoptions_digraph()
  o.getcanon = 1
  optionblk(o)
end

# Julia interface:

"""
    densenauty(g::NautyGraph
               options = DEFAULTOPTIONS_GRAPH,
               labelling = zeros(Cint, size(g)),
               partition = zeros(labelling))

Raw interface to nauty.c/densenauty. See section 6 (Calling nauty and Traces) of the nauty and Traces User's Guide for the authoritative definition of these parameters. Returns `NautyReturn`.

    densenauty(g::LightGraphs.SimpleGraph, options = DEFAULTOPTIONS_GRAPH)
    densenauty(g::LightGraphs.SimpleDiGraph, options = DEFAULTOPTIONS_DIGRAPH)

Equivalent to densenauty(lg_to_nauty(g), options).

# Usage notes

If you are calling this multiple times with smaller graphs, you may benefit from computing your `optionblk` just once:

```julia
o = Nauty.defaultoptions_graph()
o.getcanon = 1
o.writeautoms = 1
o = optionblk(o) # This converts o from optionblk_mutable to optionblk

results = [ Nauty.densenauty(g, o) for g in many_graphs ]
```

Note: Nauty is threadsafe, at least for normal use, so if you are calling it repeatedly with small graphs you may want to call it from multiple threads for a further speedup.
"""
function densenauty(g::NautyGraph,
                    options = DEFAULTOPTIONS_GRAPH,
                    labelling = nothing::Union{Cvoid, Array{Cint}},
                    partition = nothing::Union{Cvoid, Array{Cint}})

    #= @static if VERSION < v"0.7.0-DEV.2005" =#
    #=     (num_vertices, num_setwords) = size(g, 1, 2) =#
    #= else =#
        (num_vertices, num_setwords) = (size(g, 1),size(g, 2))
    #= end =#
    stats = statsblk()

    # labelling and partition must be defined if defaultptn is not set and must not be defined if they are.
    @assert (labelling == nothing) == (options.defaultptn == 1)
    @assert (partition == nothing) == (options.defaultptn == 1)

    # Create some empty arrays for nauty
    if options.defaultptn == 1
        #= labelling = Array{Cint}(size(num_vertices)) =#
        #= partition = Array{Cint}(size(num_vertices)) =#
        labelling = zeros(Cint, size(g))
        partition = zero(labelling)
    end

    #  don't need to be zero'd, I'm just doing it for debugging reasons.
    outgraph = zero(g)
    orbits = zero(labelling)

    ccall((:densenauty, LIB_FILE), Cvoid,
          (NautyGraphC, Ptr{Cint}, Ptr{Cint}, Ptr{Cint}, Ref{optionblk}, Ref{statsblk}, Cint, Cint, NautyGraphC), g, labelling, partition, orbits, options, stats, num_setwords, num_vertices, outgraph)

    # Return everything nauty gives us.
    return NautyReturn(outgraph, labelling, partition, orbits, stats)
end

function densenauty(g::LightGraphs.SimpleGraph, options = DEFAULTOPTIONS_GRAPH)
    return densenauty(lg_to_nauty(g), options)
end

function densenauty(g::LightGraphs.SimpleDiGraph, options = DEFAULTOPTIONS_DIGRAPH)
    return densenauty(lg_to_nauty(g), options)
end


# Older stuff
# The baked functions are still slightly faster, but the difference is not very noticeable any more.

function baked_canonical_form(g::LightGraphs.AbstractGraph)
    g = lg_to_nauty(g)
    (num_vertices, num_setwords) = (size(g, 1),size(g, 2))
    stats = statsblk()

    labelling = zeros(Cint, size(g))
    partition = zero(labelling)

    # These don't need to be zero'd, I'm just doing it for debugging reasons.
    outgraph = zero(g)
    orbits = zero(labelling)

    ccall((:baked_options, LIB_FILE), Cvoid,
          (NautyGraphC, Ptr{Cint}, Ptr{Cint}, Ptr{Cint}, Ref{statsblk}, Cint, Cint, NautyGraphC), g, labelling, partition, orbits, stats, num_setwords, num_vertices, outgraph)

    # Return everything nauty gives us.
    return NautyReturn(outgraph, labelling, partition, orbits, stats)
end

function baked_canonical_form_color(g::LightGraphs.AbstractGraph,labelling, partition)
    g = lg_to_nauty(g)
    (num_vertices, num_setwords) = size(g, 1, 2)
    stats = statsblk()

    # These don't need to be zero'd, I'm just doing it for debugging reasons.
    outgraph = zero(g)
    orbits = zero(labelling)

    ccall((:baked_options_color, LIB_FILE), Cvoid,
          (NautyGraphC, Ptr{Cint}, Ptr{Cint}, Ptr{Cint}, Ref{statsblk}, Cint, Cint, NautyGraphC), g, labelling, partition, orbits, stats, num_setwords, num_vertices, outgraph)

    # Return everything nauty gives us.
    return NautyReturn(outgraph, labelling, partition, orbits, stats)
end

function baked_canonical_form_and_stats(g::LightGraphs.AbstractGraph)
    g = lg_to_nauty(g)
    (num_vertices, num_setwords) = size(g, 1, 2)

    labelling = zeros(Cint, size(g))
    partition = zero(labelling)

    # These don't need to be zero'd, I'm just doing it for debugging reasons.
    outgraph = zero(g)
    orbits = zero(labelling)

    ccall((:baked_options_and_stats, LIB_FILE), Cvoid,
          (NautyGraphC, Ptr{Cint}, Ptr{Cint}, Ptr{Cint}, Cint, Cint, NautyGraphC), g, labelling, partition, orbits, num_setwords, num_vertices, outgraph)

    # Return everything nauty gives us.
    return outgraph, labelling, partition, orbits
end

# Can probably remove this
"""
    canonical_form(g)

Equivalent to:

    o = defaultoptions_graph()
    o.getcanon = 1
    densenauty(g, o)

Or:

    densenauty(g, GETCANON_OPTIONS_GRAPH)

Find the canonical graph, orbits, relabelling and orbits of `g`.
"""
canonical_form(g) = densenauty(g, GETCANON_OPTIONS_GRAPH)

# {{{ Helpers


"""
    lg_to_nauty(g::LightGraphs.AbstractGraph)

Convert to nauty-compatible adjacency matrix (uint array).
"""
function lg_to_nauty(g::LightGraphs.AbstractGraph)
    # Nauty compatible adjacency matrix:
    #   An array of m*n WORDSIZE bitfields.
    #   Where n = num vertices, m = num_setwords = ((n-1) / WORDSIZE) + 1
    #   bitfields are boolean arrays packed from left. Only the first n bits of
    #   each m*WORDSIZE row are significant.

    # assume WORDSIZE = 64, can use nauty_check to confirm values are OK.
    num_vertices = LightGraphs.nv(g)
    num_setwords = div(num_vertices - 1, WORDSIZE) + 1

    # Initialise
    arr = BitArray(undef, num_setwords * WORDSIZE, num_vertices)
    fill!(arr, false)

    # Columns and rows reversed because I care about the column/row layout of
    # arr.chunks, not arr.
    for (rowi, row) in enumerate(fadjlist(g))
        for value in row
            arr[end-value+1,rowi] = true
        end
    end

    # nauty_graph as a vector of UInt64s, just what Nauty wants.
    # For the purposes of ccall, an Array{T} can be reasonably safely treated as Ptr{T}
    return arr.chunks
end

function fadjlist(g::LightGraphs.SimpleGraphs.AbstractSimpleGraph)
    return LightGraphs.SimpleGraphs.fadj(g)
end

function fadjlist(g::MetaGraphs.AbstractMetaGraph)
    fadjlist(g.graph)
end

# These are mislabeled, they actually take graphs
"""
    label_to_adj(g)

Convert a nauty graph to an adjacency matrix.
"""
function label_to_adj(g::NautyGraph)
    temp = BitArray(undef,WORDSIZE,size(g,1))
    temp.chunks = g
    temparr = Array{Int64,2}(temp[end-size(g,1)+1:end,:])
    reverse(temparr', dims=2)
end

"""
    label_to_humanreadable(g::NautyGraph)

Convert a nauty graph (an array of little-endian UInt64s) to something more readable.
"""
function label_to_humanreadable(g::NautyGraph)
    return @. Int128(hton(g))
end


# }}}

function LightGraphs.Experimental.has_isomorph(alg::NautyAlg, g1::LightGraphs.AbstractGraph, g2::LightGraphs.AbstractGraph;
                         vertex_relation::Union{Cvoid, Function}=nothing,
                         edge_relation::Union{Cvoid, Function}=nothing)::Bool
    !LightGraphs.Experimental.could_have_isomorph(g1, g2) && return false
    
    baked_canonical_form(g1).canong == baked_canonical_form(g2).canong
end

end
