# Nauty canonical form wrapper for julia.

"Julia wrapper for the Nauty C library."
module Nauty

export has_isomorph, NautyAlg

@static if VERSION < v"0.7.0-DEV.2005"
    Cvoid = Base.Void
    Base.BitArray(x, y...) = BitArray(y...)
    undef = Base.Void
end

using Libdl: dlext
import LightGraphs

struct NautyAlg <: LightGraphs.Experimental.IsomorphismAlgorithm end

function depsdir(pkg::AbstractString)
    pkgdir = Base.find_package(pkg)
    pkgdir = abspath(joinpath(dirname(pkgdir), "..", "deps"))
    return pkgdir
end

const LIB_FILE = joinpath(depsdir("Nauty"), "minnautywrap." * dlext) 

const WORDSIZE = ccall((:wordsize, LIB_FILE), Int, ())

# {{{ Types and structs

# {{{ Julia versions of two important structs from nauty.h

"""
    define_mutable(immutable_struct)

Define a mutable copy of a struct at the same time as the immutable one and add constructors to both to allow easy conversion.

Required because mutable structs are not substitutable for C structs.

Author: Michael Eastwood
Source: https://discourse.julialang.org/t/passing-an-array-of-structures-through-ccall/5194/15
"""
macro define_mutable(immutable_struct)
    immutable_name = immutable_struct.args[2]
    mutable_name = Symbol(immutable_name, "_mutable")

    mutable_struct = copy(immutable_struct)
    mutable_struct.args[1] = true # set the mutability to true
    mutable_struct.args[2] = mutable_name

    constructors = quote
        function $mutable_name(x::$immutable_name)
            $mutable_name(ntuple(i->getfield(x, i), nfields($immutable_name))...)
        end
        function $immutable_name(x::$mutable_name)
            $immutable_name(ntuple(i->getfield(x, i), nfields($mutable_name))...)
        end
    end

    converters = quote
        function Base.convert(::Type{$immutable_name}, mut::$mutable_name)
          $immutable_name(mut)
        end
        function Base.convert(::Type{$mutable_name}, mut::$immutable_name)
          $mutable_name(mut)
        end
    end

    output = Expr(:block, immutable_struct, mutable_struct, constructors, converters)
    esc(output)
end

const Nboolean = Cint

@define_mutable struct optionblk
    getcanon::Nboolean        # make canong and canonlab?
    digraph::Nboolean         # multiple edges or loops?
    writeautoms::Nboolean     # write automorphisms?
    writemarkers::Nboolean    # write stats on pts fixed, etc.?
    defaultptn::Nboolean      # set lab,ptn,active for single cell?
    cartesian::Nboolean       # use cartesian rep for writing automs?
    linelength::Cint          # max chars/line (excl. '\n') for output
    outfile::Ptr{Cvoid}       # FILE *outfile;                                            # file for output, if any
    userrefproc::Ptr{Cvoid}   # void (*userrefproc)                                       # replacement for usual refine procedure
                              # (graph*,int*,int*,int,int*,int*,set*,int*,int,int);
    userautomproc::Ptr{Cvoid} # void (*userautomproc)                                     # procedure called for each automorphism
                              # (int,int*,int*,int,int,int);
    userlevelproc::Ptr{Cvoid} # void (*userlevelproc)                                     # procedure called for each level
                              # (int*,int*,int,int*,statsblk*,int,int,int,int,int,int);
    usernodeproc::Ptr{Cvoid}  # void (*usernodeproc)                                      # procedure called for each node
                              # (graph*,int*,int*,int,int,int,int,int,int);
    usercanonproc::Ptr{Cvoid} # Cint  (*usercanonproc)                                    # procedure called for better labellings
                              # (graph*,int*,graph*,int,int,int,int);
    invarproc::Ptr{Cvoid}     # void (*invarproc)                                         # procedure to compute vertex-invariant
                              # (graph*,int*,int*,int,int,int,int*,int,Nboolean,int,int);
    tc_level::Cint            # max level for smart target cell choosing
    mininvarlevel::Cint       # min level for invariant computation
    maxinvarlevel::Cint       # max level for invariant computation
    invararg::Cint            # value passed to (*invarproc)()
    dispatch::Ptr{Cvoid}      # dispatchvec *dispatch;                                    # vector of object-specific routines
    schreier::Nboolean        # use random schreier method
    extra_options::Ptr{Cvoid} # void *extra_options;                                      # arbitrary extra options
end

"""
# Constructor. Normally default options wouldn't be set by an inner
# constructor, but in this case the nauty manual requires that all
# optionblks be constructed by calling the macro.

Not an inner constructor any more because I don't want to override default constructor...
"""
const optionblk() = ccall((:defaultoptions_graph, LIB_FILE), optionblk, ())
const optionblk_mutable() = optionblk_mutable(optionblk())

function pprintobject(name, obj, sep=", ")
  print("$name(")
  print(join(map(fn -> "$fn=$(getfield(obj, fn))", fieldnames(obj)), sep))
  print(")")
end

function Base.show(io::IO, ::MIME"text/plain", options::Nauty.optionblk)
    pprintobject("optionblk", options)
end
function Base.show(io::IO, ::MIME"text/plain", options::Nauty.optionblk_mutable)
    pprintobject("optionblk_mutable", options)
end

struct statsblk
    grpsize1::Cdouble        # /* size of group is */
    grpsize2::Cint           # /* grpsize1 * 10^grpsize2 */
    numorbits::Cint          # /* number of orbits in group */
    numgenerators::Cint      # /* number of generators found */
    errstatus::Cint          # /* if non-zero : an error code */
    numnodes::Culong         # /* total number of nodes */
    numbadleaves::Culong     # /* number of leaves of no use */
    maxlevel::Cint           # /* maximum depth of search */
    tctotal::Culong          # /* total size of all target cells */
    canupdates::Culong       # /* number of updates of best label */
    invapplics::Culong       # /* number of applications of invarproc */
    invsuccesses::Culong     # /* number of successful uses of invarproc() */
    invarsuclevel::Cint      # /* least level where invarproc worked */
end

const statsblk() = statsblk(zeros(13)...)
function Base.show(io::IO, ::MIME"text/plain", stats::Nauty.statsblk)
    pprintobject("statsblk", stats)
end

# }}}

const NautyGraph = Array{UInt64}
const NautyGraphC = Ptr{UInt64}

# }}}

const DEFAULTOPTIONS_GRAPH = optionblk()

# Interface:

"""
    canong::NautyGraph

The canonical graph of the class of isomorphs that g is in. Only meaningful if
options.getcanon was 1

    labelling::Array{Cint}

if options.getcanon = 1, then this is the vertices of g in the order that they
should be relabelled to give canonical_graph.

    partition::Array{Cint}

colouring information for labels

    orbits::Array{Cint}

Orbits of the automorphism group

    stats::statsblk

stats related to the Nauty run
"""
struct nautyreturn
    canong::NautyGraph
    labels::Array{Cint}
    partition::Array{Cint}
    orbits::Array{Cint}
    stats::statsblk
end
function Base.show(io::IO, ::MIME"text/plain", stats::nautyreturn)
    pprintobject("nautyreturn", stats, "\n")
end

"""
    densenauty(g::NautyGraph
                    options = optionblk(),
                    labelling = zeros(Cint, size(g)),
                    partition = zeros(labelling))

Raw interface to nauty.c/densenauty. See section 6 (Calling nauty and Traces) of the nauty and Traces User's Guide for the authoritative definition of these parameters. Returns `nautyreturn`.

    densenauty(g::GraphType, options = optionblk()) where GraphType <: LightGraphs.AbstractGraph

Equivalent to densenauty(lg_to_nauty(g), options).
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

    # These don't need to be zero'd, I'm just doing it for debugging reasons.
    outgraph = zero(g)
    orbits = zero(labelling)

    ccall((:densenauty, LIB_FILE), Cvoid,
          (NautyGraphC, Ptr{Cint}, Ptr{Cint}, Ptr{Cint}, Ref{optionblk}, Ref{statsblk}, Cint, Cint, NautyGraphC), g, labelling, partition, orbits, options, stats, num_setwords, num_vertices, outgraph)

    # Return everything nauty gives us.
    return nautyreturn(outgraph, labelling, partition, orbits, stats)
end

function baked_canonical_form(g::GraphType) where GraphType <: LightGraphs.AbstractGraph
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
    return nautyreturn(outgraph, labelling, partition, orbits, stats)
end

function baked_canonical_form_color(g::GraphType,labelling, partition) where GraphType <: LightGraphs.AbstractGraph
    g = lg_to_nauty(g)
    (num_vertices, num_setwords) = size(g, 1, 2)
    stats = statsblk()

    # These don't need to be zero'd, I'm just doing it for debugging reasons.
    outgraph = zero(g)
    orbits = zero(labelling)

    ccall((:baked_options_color, LIB_FILE), Cvoid,
          (NautyGraphC, Ptr{Cint}, Ptr{Cint}, Ptr{Cint}, Ref{statsblk}, Cint, Cint, NautyGraphC), g, labelling, partition, orbits, stats, num_setwords, num_vertices, outgraph)

    # Return everything nauty gives us.
    return nautyreturn(outgraph, labelling, partition, orbits, stats)
end

function baked_canonical_form_and_stats(g::GraphType) where GraphType <: LightGraphs.AbstractGraph
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

function densenauty(g::GraphType, options = DEFAULTOPTIONS_GRAPH) where GraphType <: LightGraphs.AbstractGraph
    return densenauty(lg_to_nauty(g), options)
end

"""
    canonical_form(g)

Equivalent to:

    m = optionblk_mutable()
    m.getcanon = 1
    densenauty(g, m)

Find the canonical graph, orbits, relabelling and orbits of `g`.
"""
function canonical_form(g)
    m = optionblk_mutable(DEFAULTOPTIONS_GRAPH)
    m.getcanon = 1
    m.digraph = 1
    densenauty(g, optionblk(m))
end

# {{{ Helpers


"""
    lg_to_nauty(g::LightGraphs.AbstractGraph)

Convert to nauty-compatible adjacency matrix (uint array).
"""
function lg_to_nauty(g::GraphType) where GraphType <: LightGraphs.AbstractGraph
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
    return arr.chunks #, num_setwords, num_vertices
end

function fadjlist(g::GraphType) where GraphType <: LightGraphs.SimpleGraphs.AbstractSimpleGraph
    return g.fadjlist
end

import MetaGraphs

function fadjlist(g::GraphType) where GraphType <: MetaGraphs.AbstractMetaGraph
    return g.graph.fadjlist
end

"""
    label_to_adj(label)

Convert a nauty canonical label to an adjacency matrix.
"""
function label_to_adj(label)
    temp = BitArray(undef,WORDSIZE,size(label,1))
    temp.chunks = label
    temparr = Array{Int64,2}(temp[end-size(label,1)+1:end,:])
    flipdim(temparr',2)
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
