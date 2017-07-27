# TODO:
#   - fix 0 indexing (all S[i] -> S[i+1])
#   - give variables sensible names
#   - Figure out where it returns

# Find all subgraphs of size k in G
function kavosh(G,k)
    Visited .= false
    # For each node u
    for u in G
        # "Global" variable Visited
        Visited[u] = true
        # S are parents?
        S[0] = u
        Enumerate_Vertex(G,u,S,k-1,1)
        Visited[u] = false
    end
end

# Take graph, root vertex, "Selection": the vertices that are part of the current motif, the number of nodes left to choose
function Enumerate_Vertex(G,u,S,Remainder,i)
    # If there are no more nodes to choose, terminate
    if Remainder == 0
        # TBH, this should probably return S.
        return
    else
        # Find vertices that could be part of unique motifs
        ValList = Validate(G,S[i-1],u)
        # Make sure we don't try to pick more than we can
        n = min(length(ValList),Remainder)
        # Pick k nodes from our current depth
        for k = 1:n
            C = Initial_Comb(ValList,k)
            while C != nothing
                # Set the current selection at the current depth to them nodes
                S[i] = C
                # and Remainder-k from other depths
                Enumerate_Vertex(G,u,S,Remainder-k,i+1)
                # Repeat for all combinations of k nodes at current depth
                Next_Comb(ValList,k)
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
function Validate(G,Parents,u)
    ValList = []
    # For all of the immediate neighbours of the parents
    for v in Parents
        for w in Neighbour[u]
            # If the label of the neighbour is greater than the parent, and the neighbour has not yet been visited,
            if (label[u] < label[w]) && !Visited[w]
                # Mark it as visited and add it to our list of candidates
                Visited[w] = true
                push!(ValList, w)
            end
        end
    end
    return ValList
end

# Questions: what's the difference between ValList and Visited?
