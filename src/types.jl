# Types required for Nauty

# Aliases for Nauty's types

const Nboolean = Cint
const NautyGraph = Array{UInt64}
const NautyGraphC = Ptr{UInt64}

# Helper macro

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
            $mutable_name(ntuple(i->getfield(x, i), fieldcount($immutable_name))...)
        end
        function $immutable_name(x::$mutable_name)
            $immutable_name(ntuple(i->getfield(x, i), fieldcount($mutable_name))...)
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

# Julia versions of two important structs from nauty.h
# (optionblk and statsblk)

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

defaultoptions_graph() = optionblk_mutable(ccall((:defaultoptions_graph, LIB_FILE), optionblk, ()))
defaultoptions_digraph() = optionblk_mutable(ccall((:defaultoptions_digraph, LIB_FILE), optionblk, ()))

@deprecate optionblk() defaultoptions_graph()
@deprecate optionblk_mutable() defaultoptions_graph()

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

statsblk() = statsblk(zeros(fieldcount(statsblk))...)

# Print them

"""
    pprintobject(io, obj::T) where T

Print `obj` to `io` showing its fieldnames.
"""
function pprintobject(io, obj::T) where T
  println(io, T, '(')
  println(io, join(map(fn -> "    $fn=$(getfield(obj, fn))", fieldnames(T)), ",\n"))
  println(io, ')')
end

function Base.show(io::IO, ::MIME"text/plain", options::Nauty.optionblk)
    pprintobject(io, options)
end
function Base.show(io::IO, ::MIME"text/plain", options::Nauty.optionblk_mutable)
    pprintobject(io, options)
end
function Base.show(io::IO, ::MIME"text/plain", stats::Nauty.statsblk)
    pprintobject(io, stats)
end

# Our types (rather than nauty.h's)

struct NautyAlg <: LightGraphs.Experimental.IsomorphismAlgorithm end

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
struct NautyReturn
    canong::NautyGraph
    labels::Array{Cint}
    partition::Array{Cint}
    orbits::Array{Cint}
    stats::statsblk
end

function Base.show(io::IO, ::MIME"text/plain", stats::NautyReturn)
    pprintobject(io, stats)
end
