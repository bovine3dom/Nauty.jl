# Nauty canonical form wrapper for julia.

"Julia wrapper for the Nauty C library."
module nauty

import LightGraphs

const LIB_FILE = "$(@__DIR__)" * "/minnautywrap"

# {{{ Types and structs

# {{{ Julia versions of two important structs from nauty.h

"""
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

   output = Expr(:block, immutable_struct, mutable_struct, constructors)
   esc(output)
end

const Nboolean = Cint

@define_mutable struct optionblk
    getcanon::Cint             #  make canong and canonlab? 
    digraph::Nboolean          #  multiple edges or loops? 
    writeautoms::Nboolean      #  write automorphisms? 
    writemarkers::Nboolean     #  write stats on pts fixed, etc.? 
    defaultptn::Nboolean       #  set lab,ptn,active for single cell? 
    cartesian::Nboolean        #  use cartesian rep for writing automs? 
    linelength::Cint           #  max chars/line (excl. '\n') for output 
    outfile::Ptr{Void} #FILE *outfile;            #  file for output, if any 
    userrefproc::Ptr{Void} # void (*userrefproc)       #  replacement for usual refine procedure 
         #(graph*,int*,int*,int,int*,int*,set*,int*,int,int);
    userautomproc::Ptr{Void} # void (*userautomproc)     #  procedure called for each automorphism 
         # (int,int*,int*,int,int,int);
    userlevelproc::Ptr{Void} # void (*userlevelproc)     #  procedure called for each level 
         #(int*,int*,int,int*,statsblk*,int,int,int,int,int,int);
    usernodeproc::Ptr{Void} # void (*usernodeproc)      #  procedure called for each node 
         #(graph*,int*,int*,int,int,int,int,int,int);
    usercanonproc::Ptr{Void} # Cint  (*usercanonproc)     #  procedure called for better labellings 
         #(graph*,int*,graph*,int,int,int,int);
    invarproc::Ptr{Void} # void (*invarproc)         #  procedure to compute vertex-invariant 
         #(graph*,int*,int*,int,int,int,int*,int,Nboolean,int,int);
    tc_level::Cint             #  max level for smart target cell choosing 
    mininvarlevel::Cint        #  min level for invariant computation 
    maxinvarlevel::Cint        #  max level for invariant computation 
    invararg::Cint             #  value passed to (*invarproc)() 
    dispatch::Ptr{Void} # dispatchvec *dispatch;    #  vector of object-specific routines 
    schreier::Nboolean         #  use random schreier method 
    extra_options::Ptr{Void} # void *extra_options;      #  arbitrary extra options 
end

"""
# Constructor. Normally default options wouldn't be set by an inner
# constructor, but in this case the nauty manual requires that all
# optionblks be constructed by calling the macro.

Not an inner constructor any more because I don't want to override default constructor...
"""
const optionblk() = ccall((:defaultoptions_graph, LIB_FILE), optionblk, ())

struct statsblk
    grpsize1::Cdouble	#        /* size of group is */
    grpsize2::Cint	#           /*    grpsize1 * 10^grpsize2 */
    numorbits::Cint	#          /* number of orbits in group */
    numgenerators::Cint	#      /* number of generators found */
    errstatus::Cint	#          /* if non-zero : an error code */
    numnodes::Culong	#      /* total number of nodes */
    numbadleaves::Culong	#  /* number of leaves of no use */
    maxlevel::Cint	#                /* maximum depth of search */
    tctotal::Culong	#       /* total size of all target cells */
    canupdates::Culong	#    /* number of updates of best label */
    invapplics::Culong	#    /* number of applications of invarproc */
    invsuccesses::Culong	#  /* number of successful uses of invarproc() */
    invarsuclevel::Cint	#      /* least level where invarproc worked */
end

# }}}

"Julia automatically converts arrays to suitable Ptr{UInt64}s when passed in ccall."
const NautyGraph = Ptr{UInt64}

# }}}


# Interface:

"""
    canonical_form(g::LightGraphs.Graph)

Find the canonical graph, orbits, relabelling and orbits of `g`.

Returns:
- canonical_graph::NautyGraph
    - The canonical graph of the class of isomorphs that g is in
- labelling::Array{Cint}
    - How to relabel g such that it becomes canonical_graph
- orbits::Array{Cint}
    - See nauty documentation/automorphism theory
- partition::Array{Cint}
    - Probably garbage
"""
function canonical_form(g::GraphType) where GraphType <: LightGraphs.SimpleGraphs.AbstractSimpleGraph

    ingraph = lg_to_nauty(g)
    (num_vertices, num_setwords) = size(ingraph, 1, 2)

    # These don't need to be zero'd, I'm just doing it for debugging reasons.
    outgraph = similar(ingraph)
    labelling = Array{Cint}(num_vertices)
    partition = similar(labelling)
    orbits = similar(labelling)

    ccall((:canonical_form, LIB_FILE), Void,
          (NautyGraph, Cint, Cint, Ptr{Cint}, Ptr{Cint}, Ptr{Cint}, NautyGraph),
          ingraph, num_setwords, num_vertices, labelling, partition, orbits, outgraph)

    # Return everything nauty gives us.
    # I'm not sure that partition is meaningful...
    return outgraph, labelling, partition, orbits
end

# {{{ This doesn't work yet.

function densenauty(g, options::optionblk)
    # Return the canonical form in some way that is cheap to test equivalence of.

    ingraph = lg_to_nauty(g)
    (num_vertices, num_setwords) = size(ingraph, 1, 2)

    # These don't need to be zero'd, I'm just doing it for debugging reasons.
    outgraph = zeros(ingraph)
    labelling = zeros(Cint, num_vertices)
    partition = zeros(labelling)
    orbits = zeros(labelling)

    ccall((:densenauty_wrap, LIB_FILE), Void,
          (NautyGraph, Ptr{Cint}, Ptr{Cint}, Ptr{Cint},
           Ref{optionblk}, Cint, Cint, NautyGraph),
          ingraph, labelling, partition, orbits,
          Ref(options), num_setwords, num_vertices, outgraph)

    #= ccall((:densenauty_defaults_wrap, LIB_FILE), Void, =#
    #=       (NautyGraph, Ptr{Cint}, Ptr{Cint}, Ptr{Cint}, =#
    #=        Cint, Cint, NautyGraph), =#
    #=       ingraph, labelling, partition, orbits, =#
    #=       num_setwords, num_vertices, outgraph) =#

    # Return everything nauty gives us.
    # I'm not sure that partition is meaningful...
    return labelling, outgraph, partition, orbits
end
# }}}

# {{{ Helpers


"""
    lg_to_nauty(g::LightGraphs.SimpleGraphs.AbstractSimpleGraph)

Convert to nauty-compatible adjacency matrix (uint array).
"""
function lg_to_nauty(g::GraphType) where GraphType <: LightGraphs.SimpleGraphs.AbstractSimpleGraph
    # Nauty compatible adjacency matrix:
    #   An array of m*n WORDSIZE bitfields.
    #   Where n = num vertices, m = num_setwords = ((n-1) / WORDSIZE) + 1
    #   bitfields are boolean arrays packed from left. Only the first n bits of
    #   each m*WORDSIZE row are significant.

    # assume WORDSIZE = 64, can use nauty_check to confirm values are OK.
    WORDSIZE = 64
    num_vertices = LightGraphs.nv(g)
    num_setwords = div(num_vertices - 1, WORDSIZE) + 1

    # Initialise
    arr = BitArray(num_setwords * WORDSIZE, num_vertices)
    fill!(arr, false)

    # Columns and rows reversed because I care about the column/row layout of
    # arr.chunks, not arr.
    for (rowi, row) = enumerate(g.fadjlist)
        for value = row
            arr[end-value+1,rowi] = true
        end
    end

    # nauty_graph as a vector of UInt64s, just what Nauty wants.
    # For the purposes of ccall, an Array{T} can be reasonably safely treated as Ptr{T}
    return arr.chunks #, num_setwords, num_vertices
end

function label_to_adj(label)
    # change 64 to wordsize
    temp = BitArray(64,size(label,1))
    temp.chunks = label
    temparr = Array{Int64,2}(temp[end-size(label,1)+1:end,:])
    flipdim(temparr',2)
end


# }}}

# Experimental crap to remove...
function graph_receiver(g)
    ingraph = lg_to_nauty(g)
    (num_vertices, num_setwords) = size(ingraph, 1, 2)

    ccall((:graph_receiver, LIB_FILE), UInt64, (NautyGraph, Cint), ingraph, num_vertices * num_setwords)
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

#using Base.Test
#
#@testset begin
#	"Convert the adjacency matrix of a directed graph into an undirected graph."
#	helper(x) = LightGraphs.Graph(x .| x')
#
#	# Two simple isomorphic graphs.
#	iso1a = helper(Array([0 1 1; 0 0 0; 0 0 0]))
#	iso1b = helper(Array([0 0 0; 1 0 1; 0 0 0]))
#
#	@test lg_to_nauty(iso1a) == Array{UInt64,1}([0x6000000000000000, 0x8000000000000000, 0x8000000000000000])
#	@test lg_to_nauty(iso1b) == Array{UInt64,1}([0x4000000000000000, 0xa000000000000000, 0x4000000000000000])
#
#	# Two simple isomorphic digraphs.
#	diso1a = LightGraphs.DiGraph(Array([0 1 1; 0 0 0; 0 0 0]))
#	diso1b = LightGraphs.DiGraph(Array([0 0 0; 1 0 1; 0 0 0]))
#
#	@test lg_to_nauty(diso1a) == Array{UInt64,1}([0x6000000000000000, 0x0000000000000000, 0x0000000000000000])
#	@test lg_to_nauty(diso1b) == Array{UInt64,1}([0x0000000000000000, 0xa000000000000000, 0x0000000000000000])
#
#	@test canonical_form(iso1a)[1] == canonical_form(iso1b)[1]
#
#	@test canonical_form(diso1a)[1] == canonical_form(diso1b)[1]
#end

end
