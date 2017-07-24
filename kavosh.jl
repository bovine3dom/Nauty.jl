# TODO:
#   - fix 0 indexing (all S[i] -> S[i+1])
#   - give variables sensible names

# S are parents?
function kavosh(G,k)
    # For each node u
    for u in G
        # "Global" variable Visited
        Visited[u] = true
        S[0] = u
        Enumerate_Vertex(G,u,S,k-1,1)
        Visited[u] = false
    end
end

function Enumerate_Vertex(G,u,S,Remainder,i)
    if Remainder == 0
        return
    else
        ValList = Validate(G,S[i-1],u)
        n = min(length(ValList),Remainder)
        for k = 1:n
            C = Initial_Comb(ValList,k)
            while C != nothing
                S[i] = C
                Enumerate_Vertex(G,u,S,Remainder-k,i+1)
                Next_Comb(ValList,k)
            end
        end
        for v in ValList
            Visited[v] = false
        end
    end
end

function Validate(G,Parents,u)
    ValList = []
    for v in Parents
        for w in Neighbour[u]
            if (label[u] < label[w]) && !Visited[w]
                Visited[w] = true
                push!(ValList, w)
            end
        end
    end
    return ValList
end

