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

# Julia interface:

"""
    densenauty(g::NautyGraph
               options = defaultoptions_graph(),
               labelling = zeros(Cint, size(g)),
               partition = zeros(labelling))

Raw interface to nauty.c/densenauty. See section 6 (Calling nauty and Traces) of the nauty and Traces User's Guide for the authoritative definition of these parameters. Returns `NautyReturn`.

    densenauty(g::LightGraphs.AbstractGraph, options = defaultoptions_graph())

Equivalent to densenauty(lg_to_nauty(g), options).
"""
function densenauty(g::NautyGraph,
                    options = defaultoptions_graph(),
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

function densenauty(g::LightGraphs.AbstractGraph, options = defaultoptions_graph())
    return densenauty(lg_to_nauty(g), options)
end

"""
    canonical_form(g)

Equivalent to:

    o = defaultoptions_graph()
    o.getcanon = 1
    densenauty(g, o)

Find the canonical graph, orbits, relabelling and orbits of `g`.
"""
function canonical_form(g)
    o = defaultoptions_graph()
    o.getcanon = 1
    densenauty(g, o)
end

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

"""
    label_to_adj(label)

Convert a nauty canonical label to an adjacency matrix.
"""
function label_to_adj(label)
    temp = BitArray(undef,WORDSIZE,size(label,1))
    temp.chunks = label
    temparr = Array{Int64,2}(temp[end-size(label,1)+1:end,:])
    reverse(temparr', dims=2)
end

"""
    label_to_humanreadable(label::Array{UInt64})

Convert a nauty label (an array of little-endian UInt64s) to something more readable.
"""
function label_to_humanreadable(label::Array{UInt64})
    return @. Int128(hton(label))
end


# }}}

# Experimental crap to remove...
function graph_receiver(g)
    ingraph = lg_to_nauty(g)
    (num_vertices, num_setwords) = size(ingraph, 1, 2)

    ccall((:graph_receiver, LIB_FILE), UInt64, (NautyGraphC, Cint), ingraph, num_vertices * num_setwords)
end

#= # Fields =#

#= type Field{K} end =#

#= Base.convert{K}(::Type{Symbol}, ::Field{K}) = K =#
#= Base.convert(::Type{Field}, s::Symbol) = Field{s}() =#

#= macro f_str(s) =#
#=   :(Field{$(Expr(:quote, symbol(s)))}()) =#
#= end =#

#= typealias FieldPair{F<:Field, T} Pair{F, T} =#
#= const FieldPair{F<:Field, T} = Pair{F, T} =#

#= # Immutable `with` =#

#= for nargs = 1:5 =#
#=   args = [symbol("p$i") for i = 1:nargs] =#
#=   @eval with(x, $([:($p::FieldPair) for p = args]...), p::FieldPair) = =#
#=       with(with(x, $(args...)), p) =#
#= end =#

#= @generated function with{F, T}(x, p::Pair{Field{F}, T}) =#
#=   :($(x.name.primary)($([name == F ? :(p.second) : :(x.$name) =#
#=                          for name in fieldnames(x)]...))) =#
#= end =#

function LightGraphs.Experimental.has_isomorph(alg::NautyAlg, g1::LightGraphs.AbstractGraph, g2::LightGraphs.AbstractGraph;
                         vertex_relation::Union{Cvoid, Function}=nothing,
                         edge_relation::Union{Cvoid, Function}=nothing)::Bool
    !LightGraphs.Experimental.could_have_isomorph(g1, g2) && return false
    
    baked_canonical_form(g1).canong == baked_canonical_form(g2).canong
end

end
