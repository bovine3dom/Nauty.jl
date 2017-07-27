# TODO:
#   - give variables sensible names
#   - Figure out where it returns
#   - Multithreading...
#       - Each root node is independent

import LightGraphs
const lg = LightGraphs
import Combinatorics
const cb = Combinatorics

# Find all subgraphs of size k in G
function kavosh(G,k)
    Visited = zeros(Bool,lg.nv(G))
    # For each node u
    for u in lg.vertices(G)
        S = Dict()
        # "Global" variable Visited
        Visited .= false
        Visited[u] = true
        # S are parents?
        S[1] = u
        Enumerate_Vertex(G,u,S,k-1,1,Visited)
    end
end

# Take graph, root vertex, "Selection": the vertices that are part of the current motif, the number of nodes left to choose
function Enumerate_Vertex(G,u,S,Remainder,i,Visited)
    # If there are no more nodes to choose, terminate
    if Remainder == 0
        # TBH, this should probably return S.
        temp = filter(x -> x!=0,vcat(values(S)...))
        # Rarely, nodes are repeated. Why? Fixed - S wasn't being wiped.
        arerepeats(temp) && println(S)
        return
    else
        # Find vertices that could be part of unique motifs
        ValList = Validate(G,S[i],u,Visited)
        # Make sure we don't try to pick more than we can
        n = min(length(ValList),Remainder)
        # Pick k nodes from our current depth
        for k = 1:n
            for combination in cb.combinations(ValList,k)
                # Set the current selection at the current depth to them nodes
                # Might get a performance boost if S was just a list of numbers, and Parents was stored separately.
                S[i+1] = combination
                # and Remainder-k from other depths
                Enumerate_Vertex(G,u,S,Remainder-k,i+1,Visited)
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
        # Original paper has this as the neighbours of U. 90% sure that it's a typo.
        for w in lg.neighbors(G,v)
            # If the label of the neighbour is greater than the parent, and the neighbour has not yet been visited,
            if (v < w) && !Visited[w]
                # Mark it as visited and add it to our list of candidates
                Visited[w] = true
                push!(ValList, w)
            end
        end
    end
    return ValList
end

# Questions: what's the difference between ValList and Visited?
