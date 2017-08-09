# TODO:
#   - give variables sensible names
#   - Figure out how to make it return
#   - Multithreading...
#       - Each root node is independent

module kavosh
    import LightGraphs
    const lg = LightGraphs
    # IterTools is 10x-2x faster than Combinatorics
    # Make sure it uses revolving door algorithm
    import IterTools
    const it = IterTools

    # Find all subgraphs of size k in G
    function getsubgraphs(G,k)
        # No speedup compared to []
        answers = Array{Array{Int64,1},1}()
        Visited = zeros(Bool,lg.nv(G))
        # For each node u
        for u in lg.vertices(G)
            # 3x speedup compared to Dict()
            S = Dict{Int64,Array{Int64,1}}()
            # "Global" variable Visited
            Visited .= false
            Visited[u] = true
            # S are parents?
            S[1] = [u]
            Enumerate_Vertex(G,u,S,k-1,1,Visited,answers)
        end
        answers
    end

    # Take graph, root vertex, "Selection": the vertices that are part of the current motif, the number of nodes left to choose
    function Enumerate_Vertex(G::lg.SimpleGraphs.AbstractSimpleGraph,u::Int64,S,Remainder::Int64,i::Int64,Visited::Array{Bool,1},answers)::Void
        # If there are no more nodes to choose, terminate
        s = deepcopy(S) # Stops shorter trees from accidentally sharing data. Must be a neater way of doing this.
        if Remainder == 0
            # TBH, this should probably return S.
            # Sometimes, there are too many nodes in the motif.
            # Next step: olieshomegrowncannonlabeller(lg.adjacency_matrix(lg.induced_subgraph(G,temp)))
            # oh god must I really nauty
            temp = vcat(values(s)...)
            push!(answers,temp)
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

    function arerepeats(array)
        return length(array) != length(Set(array))
    end

    # Take graph, selected vertices of previous layer, and the root vertex, return vertices that could form unique motifs
    # This is the bit where the labels are considered. Only labels bigger than root are considered. This is to stop double counting.
    function Validate(G,Parents,u,Visited)
        ValList = []
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
