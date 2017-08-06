push!(LOAD_PATH,pwd())

# Motif finder

## State of the art

### Kavosh
- Exact
- Source code is free (GPL)
https://github.com/allrod5/Kavosh

### FANMOD
- Inexact
- Source is non-free but open
http://theinf1.informatik.uni-jena.de/motifs/

Both of these use something called auty\ to find the subgraphs. I think.


There's a python wrapper for nauty.

There's also a function called \atlas\ in NetworkX that will work for smaller graphs.

https://networkx.github.io/documentation/networkx-1.9/examples/graph/atlas.html

Other poeople talk about http://www.maths.qmul.ac.uk/~leonard/grape/grape4r7/manual/CHAP008.htm - what are colours?

https://stackoverflow.com/questions/41014549/interface-julia-with-nauty

---

My current plan is to use Cxx to inline as much Kavosh as possible.

Other people have tried python:

# Kavosh

## Outline

- Enumeration
    - Find all subgraphs of given size in input graph
    - magic tree makes it quick
- Classification
    - Classify subgraphs into isomorphic groups
    - Use NAUTY
- Random graph generation
    - Do we care? Don't think so
- Motif identification
    - Work out motifs in subgraphs
    
## Enumeration

- All (k-size?) subgraphs that include a particular vertex are discovered
- This vertex is removed from the network
- Repeat process for each successive vertex

---

To extract subgraphs of size $k$, all compositions of the integer $k - 1$ are considered, where the compositions are all possible positive summations of integers that equal $k-1=\\Sigma_{i=2}^m{k_i}$. 

$k_i$ vertices are selected from the $i$th level of the tree to be vertices of the subgraphs $(i=2,3,...,m)$. The $k-1$ selected verices along with the vertex at the root define a subgraph in the network.

E.g, to find subgraphs of size $k=4$, we consider $(1,1,1),(1,2),(2,1),(3)$: i.e, a node at each level; a node at level 1 and 2 and two nodes at level 3... etc.

$$3 = 1+1+1 = 1+2 = 2+1 = 3$$

$$(1,1,1);(1,2);(2;1);(3)$$

- It is possible that, for a particular level, there will be fewer nodes than we are trying to choose (so... just give up? right?)

- At level $i$, there are $n_i C k_i$ selections of vertices to be considered, where $n_i$ is the number of nodes at each level - all possible nodes at that level, not just ones whose parents have been chosen

    - Kavosh uses the \revolving door\ algorithm to consider them all. *Look at what Julia uses and see if it's quicker*
    
- the node $u$ defines the root of a tree. Each vertex is marked as visited iff it has been observed as an adjacent of any selected vertex in the upper levels.

- $S-i (i=0,...,m,m\\leq-1)$ is the set of all vertices from the $i^{th}$ level included in a particular subgraph. 
**todo: work out what trees they're talking about**

---
Take 2:

- Figure out all ways of summing to make motif: 1+(other levels) (e.g: 1+(1,2,1) for a 5 motif
- Choose vertex as root node
- Neighbours are children
- for each summation possibility
    - for each variation of chosen stuff
        - Pick neighbours in 2nd level of tree (e.g. 1)
            - pick two out of all their neighbours
            - pick 1 out of all of their neighbours
        - at each step, mark all immediate neighbours as visited... paper has nice details on pages 6.5-7.5 with figure
        
## Classification

- Each subgraph is passed to NAUTY, which returns a canonical version of the graph using lexicographic size.

## Faffing
- It's basically done at this point. Biologists like to do some stats.
- It might actually be nice to do the z-score stuff / normalise by chance of appearing in random graph / some other sort of entropy thing
    
# Pseudo code

## Kavosh

    for each u in G do
        Visited[u] = true
        S_0 = u
        Enumerate_Vertex(G,u,S,k-1,1)
        Visited[u] = false
    end

## Enumerate vertex (G,u,S,Remainder,i)

    if Remainder = 0 then
        return
    else
        ValList = Validate(G, S_{i-1}, u)
        n = Min(|ValList|, Remainder)
        for k_i = 1 to n_i do
            C = Initial_Comb(ValList,k_i)
            repeat
                S_i = c
                Enumerate_Vertex(G,u,S,Remainder-k_i,i+1)
                Next_Comb(ValList,k_i)
            until C = NILL
        end
        for each v in ValList do
            Visited[v] = false
        end
    end

## Validate(G,Parents,u)

    ValList = NILL
    for each v in Parents do
        for each w in Neighbour[u] do
            if label[u] < label[w] and not Visited[w] then
                Visited[w] = true
                ValList = ValList + w
            end
        end
    end
    return ValList

---

# Nauty

## Compilation

- Apparently, setting MAXN <= WORDSIZE makes it much faster for tiny graphs
    - (from nauty.h)

- Make sure to configure with O4 and fPIC
- then compile with gcc -shared -o -fPIC nauty.so nauty.o nauty.so nauty.o nautil.o nautinv.o naututil.o gtnauty.o gtools.o gutil1.o gutil2.o naugraph.o naugroup.o naurng.o nausparse.o schreier.o traces.o

## Use

For example:

    ccall((:nauty_check, "./nauty.so"), Void,(Cint,Cint,Cint,Cint),64,1,1,26040)

## Notes

WORDSIZE is 64 on my work PC.

Supposedly, can get global variables with

    cglobal(("WORDSIZE","./nauty.so"),Cint)

But it doesn't seem to work for #define's, for me. Maybe ask on the gitter. Same with macro functions.

## Making a graph 

### pynauty's approach

*GRAPH_PTR is a kind of NyGraph

number of set words: no_setwords = (no_verticies + WORDSIZE - 1) / WORDSIZE;

    g->matrix = malloc(
        (size_t g->no_setwords * size_t no_vertices * sizeof(setword)))

    EMPTYSET -> EMPTYSET0(setadd,m) ->
    "{setword *es;
    for(
        es=(setword*)(setadd)+(m);
        --es>=(setword*)(setadd);
    )
    *es=0;
    }"

make an empty set
    EMPTYSET(GRAPHROW(g->matrix, i, g->no_setwords)), g->no_setwords)

### Todo
- what's a setword
- what's a set
