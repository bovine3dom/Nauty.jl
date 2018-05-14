# TODO:
#   - give variables sensible names
#   - give functions sensible names
#       - follow Julia convention
#   - remove superfluous type annotaitons
#   - Multithreading...
#       - Each root node is independent

# Notes
# canonical labelling -> graph: (where nodes is number of nodes in subgraph)
# a = BitArray(64,[nodes])
# a.chunks = nauty.canonical_labelling(g)[1]
# Array{Int64,2}(a[end-nodes+1:end,:])
include("nauty.jl")

module kavosh
    import LightGraphs
    import nauty
    const lg = LightGraphs
    # IterTools is 10x-2x faster than Combinatorics
    # Make sure it uses revolving door algorithm
    import IterTools
    const it = IterTools

    # Find all subgraphs of size k in G
    # mild breaking change below: verbose now a keyword argument
    function getsubgraphs(G,k;norm=true, verbose=false)::Dict{Array{UInt64,1},Float64}
        # No speedup compared to []
        answers = Dict{Array{UInt64,1},Int64}()
        Visited = zeros(Bool,lg.nv(G))
        # For each node u
        for u in lg.vertices(G)
            if verbose #&& (mod(u,10) == 0)
                print("\r", round(u/lg.nv(G)*100), "% done")
            end
            # 3x speedup compared to Dict(). UInt8 uses ~5% less memory but is ~7% slower.
            S = Dict{Int64,Array{Int64,1}}()
            # "Global" variable Visited
            Visited .= false
            Visited[u] = true
            # S are parents?
            S[1] = [u]
            Enumerate_Vertex(G,u,S,k-1,1,Visited,answers)
        end
        if !norm return answers end
        normalisation = sum(values(answers))
        d = Dict()
        for (key,v) in answers
            d[key] = v/normalisation
        end
        d
    end

    # Take graph, root vertex, "Selection": the vertices that are part of the current motif, the number of nodes left to choose
    function Enumerate_Vertex(G::GraphType,u::Int64,S,Remainder::Int64,i::Int64,Visited::Array{Bool,1},answers)::Void where GraphType <: lg.SimpleGraphs.AbstractSimpleGraph
        # If there are no more nodes to choose, terminate
        s = copy(S) # Stops shorter trees from accidentally sharing data. Must be a neater way of doing this.
        if Remainder == 0
            # Next step: olieshomegrowncannonlabeller(lg.adjacency_matrix(lg.induced_subgraph(G,temp)))
            # This vcat line makes programme ~20% slower
            #temp = vcat(values(s)...)
            #push!(answers,temp)
            temp = vcat(values(s)...)
            # Most of memory usage is in the G[temp] call
            k = nauty.canonical_form(G[temp])[1]
            # Human readable alternative
            #k = nauty.label_to_adj(nauty.canonical_form(G[temp])[1],3)
            answers[k] = get(answers,k,0) + 1
            return
        else
            # Find vertices that could be part of unique motifs
            ValList = Validate(G,s[i],u,Visited)
            # Make sure we don't try to pick more than we can
            n = min(length(ValList),Remainder)
            # Pick k nodes from our current depth
            for k = 1:n
                for combination in it.subsets(ValList,k)
                    # set the current selection at the current depth to them nodes
                    # Might get a performance boost if s was just a list of numbers, and Parents was stored separately.
                    s[i+1] = combination
                    # and Remainder-k from other depths
                    Enumerate_Vertex(G,u,s,Remainder-k,i+1,Visited,answers)
                    # Repeat for all combinations of k nodes at current depth
                end
            end
            # Tidy up
            for v in ValList
                Visited[v] = false
            end
        end
    end

    # Take graph, selected vertices of previous layer, and the root vertex, return vertices that could form unique motifs
    # This is the bit where the labels are considered. Only labels bigger than root are considered. This is to stop double counting.
    function Validate(G::GraphType,Parents::Array{Int64,1},u::Int64,Visited::Array{Bool,1})::Array{Int64,1} where GraphType <: lg.SimpleGraphs.AbstractSimpleGraph
        ValList = Array{Int64,1}()
        # For all of the immediate neighbours of the parents
        for v in Parents
            # Original paper has this as the neighbours of U. 100% sure that it's a typo.
            for w in lg.all_neighbors(G,v)
                # If the label of the neighbour is greater than the parent, and the neighbour has not yet been visited,
                # I think perhaps it should be the root node, actually
                if (u < w) && !Visited[w]
                    # Mark it as visited and add it to our list of candidates
                    Visited[w] = true
                    push!(ValList, w)
                end
            end
        end
        return ValList
    end

    # Questions: what's the difference between ValList and Visited?
end
